import 'dart:async';
import 'dart:convert';
import 'player_localizations.dart';
import 'review_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

/// One non-consumable Play product. Create this exact ID in Play Console.
const proProductId = 'nwc_player_pro_unlock';
const proVerificationUrl = String.fromEnvironment('NWC_PRO_VERIFY_URL');
const proOfflineGrace = Duration(days: 7);

const _proTokenKey = 'nwc_pro_purchase_token_v1';
const _proVerifiedAtKey = 'nwc_pro_verified_at_v1';
const _proLastSeenKey = 'nwc_pro_last_seen_at_v1';

bool isWithinProOfflineGrace(DateTime? verifiedAt, DateTime now) =>
    verifiedAt != null &&
    !verifiedAt.isAfter(now) &&
    now.difference(verifiedAt) <= proOfflineGrace;

enum _VerificationResult { active, inactive, unavailable }

/// The server, not a locally saved flag, decides whether Pro is active.
class ProAccess extends ChangeNotifier with WidgetsBindingObserver {
  ProAccess({
    InAppPurchase? store,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    this.verificationUrl = proVerificationUrl,
    this.productQueryTimeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _providedStore = store,
       _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _now = now ?? DateTime.now;

  // Embedded/VIP players do not initialize Pro billing. Do not start the native
  // Play connection merely because the shared player constructs this object.
  final InAppPurchase? _providedStore;
  late final InAppPurchase _store = _providedStore ?? InAppPurchase.instance;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final String verificationUrl;
  final Duration productQueryTimeout;
  final DateTime Function() _now;
  late final ReviewAccess reviewAccess = ReviewAccess(
    client: _client,
    secureStorage: _secureStorage,
    verificationUrl: verificationUrl,
    now: _now,
  )..addListener(notifyListeners);
  Timer? _timer;
  Timer? _expiryTimer;
  DateTime? _lastSeenAt;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  DateTime? _lastAttempt;
  final _leaseWatch = Stopwatch();
  Duration _leaseRemaining = Duration.zero;
  bool get verificationConfigured {
    final uri = Uri.tryParse(verificationUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? product;
  bool available = false;
  bool loading = true;
  bool purchasing = false;
  bool _purchaseUnlocked = false;
  bool get unlocked => _purchaseUnlocked || reviewAccess.unlocked;
  LocalizedText? message;
  // Catalog failures are separate from purchase/verification messages. A
  // missing query result does not prove that a Console product is unregistered.
  LocalizedText? productMessage;
  String? productDiagnostic;
  Future<void>? _productRequest;
  String? _cachedToken;
  DateTime? _verifiedAt;

  Future<void> initialize() async {
    unawaited(reviewAccess.initialize());
    await _loadCachedEntitlement();
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkOfflineExpiry();
      reviewAccess.tick();
      if (_lastAttempt == null ||
          _now().difference(_lastAttempt!) >= const Duration(hours: 1)) {
        unawaited(refresh());
      }
    });
    _subscription ??= _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        message = (s) => s.proInfoFailed;
        purchasing = false;
        notifyListeners();
      },
    );
    // Do not let a slow Play connection delay refund/revocation checks.
    unawaited(refresh());
    await refreshProduct();
    if (!_disposed && available) {
      try {
        await _store.restorePurchases().timeout(productQueryTimeout);
      } catch (_) {
        message = (s) => s.proRestoreFailed;
        notifyListeners();
      }
    }
  }

  /// Refresh on opening the offer, retry, restore, or resume after a failure.
  /// Share simultaneous requests and do not use stale ProductDetails to buy.
  Future<void> refreshProduct() {
    if (_disposed || purchasing) return Future.value();
    final current = _productRequest;
    if (current != null) return current;
    loading = true;
    product = null;
    productMessage = null;
    productDiagnostic = null;
    final request = _loadProduct().whenComplete(() {
      _productRequest = null;
      if (_disposed) return;
      loading = false;
      notifyListeners();
    });
    _productRequest = request;
    notifyListeners();
    return request;
  }

  Future<void> _loadProduct() async {
    try {
      final connected = await _store.isAvailable().timeout(productQueryTimeout);
      if (_disposed) return;
      available = connected;
      if (!connected) {
        productMessage = (s) => s.proBillingUnavailable;
        productDiagnostic = 'BILLING_UNAVAILABLE';
        return;
      }
      final response = await _store
          .queryProductDetails({proProductId})
          .timeout(productQueryTimeout);
      if (_disposed) return;
      if (response.error != null) {
        productMessage = (s) => s.proInfoFailed;
        // Only the error code, never arbitrary platform details or tokens.
        final code = response.error!.code.replaceAll(
          RegExp(r'[^a-zA-Z0-9_.-]'),
          '_',
        );
        productDiagnostic =
            'QUERY_ERROR: ${code.substring(0, code.length.clamp(0, 80))}';
        return;
      }
      for (final item in response.productDetails) {
        if (item.id == proProductId) {
          product = item;
          break;
        }
      }
      if (product == null) {
        productMessage = (s) => s.proProductUnavailable;
        // The plugin may also return an empty list for native billing failures.
        // This is an observed result, not a diagnosis of Console registration.
        productDiagnostic = 'QUERY_EMPTY';
      }
    } on TimeoutException {
      if (_disposed) return;
      productMessage = (s) => s.proProductTimeout;
      productDiagnostic = 'QUERY_TIMEOUT';
    } catch (_) {
      if (_disposed) return;
      productMessage = (s) => s.proConnectionError;
      productDiagnostic = 'QUERY_EXCEPTION';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkOfflineExpiry();
      unawaited(refresh());
      unawaited(reviewAccess.refresh());
      if (!unlocked && product == null && !purchasing) {
        unawaited(refreshProduct());
      }
    }
  }

  void _startLease() {
    _leaseRemaining = proOfflineGrace - _now().toUtc().difference(_verifiedAt!);
    _leaseWatch
      ..reset()
      ..start();
    _expiryTimer?.cancel();
    _expiryTimer = Timer(
      _leaseRemaining + const Duration(milliseconds: 1),
      checkOfflineExpiry,
    );
  }

  void checkOfflineExpiry() {
    final now = _now().toUtc();
    final rolledBack = _lastSeenAt != null && now.isBefore(_lastSeenAt!);
    if (_purchaseUnlocked &&
        (rolledBack ||
            !isWithinProOfflineGrace(_verifiedAt, now) ||
            _leaseWatch.elapsed > _leaseRemaining)) {
      _purchaseUnlocked = false;
      message = (s) => s.proInternetRequired;
      notifyListeners();
    }
    if (!rolledBack && _cachedToken != null) {
      _lastSeenAt = now;
      unawaited(
        _secureStorage
            .write(key: _proLastSeenKey, value: now.toIso8601String())
            .catchError((Object _) {}),
      );
    }
  }

  Future<void> _serial(Future<void> Function() action) {
    _queue = _queue
        .then((_) async {
          if (!_disposed) await action();
        })
        .catchError((Object _) {
          purchasing = false;
          message = (s) => s.proConfirmFailed;
          notifyListeners();
        });
    return _queue;
  }

  Future<void> refresh() => _serial(() async {
    checkOfflineExpiry();
    final token = _cachedToken;
    if (token != null) await _refreshCachedEntitlement(token);
  });

  Future<void> _loadCachedEntitlement() async {
    try {
      _cachedToken = await _secureStorage.read(key: _proTokenKey);
      final rawVerifiedAt = await _secureStorage.read(key: _proVerifiedAtKey);
      _verifiedAt = DateTime.tryParse(rawVerifiedAt ?? '')?.toUtc();
      _lastSeenAt =
          DateTime.tryParse(
            await _secureStorage.read(key: _proLastSeenKey) ?? '',
          )?.toUtc();
      _purchaseUnlocked =
          _cachedToken?.isNotEmpty == true &&
          verificationConfigured &&
          (_lastSeenAt == null || !_now().toUtc().isBefore(_lastSeenAt!)) &&
          isWithinProOfflineGrace(_verifiedAt, _now().toUtc());
      if (_purchaseUnlocked) _startLease();
    } catch (_) {
      _purchaseUnlocked = false;
    }
  }

  Future<void> buy() async {
    if (!verificationConfigured ||
        !available ||
        product == null ||
        loading ||
        purchasing) {
      return;
    }
    purchasing = true;
    message = null;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product!),
      );
      if (!started) {
        purchasing = false;
        message = (s) => s.proStartFailed;
        notifyListeners();
      }
    } catch (_) {
      purchasing = false;
      message = (s) => s.proWindowFailed;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    unawaited(refreshProduct());
    message = (s) => s.proRestoring;
    notifyListeners();
    try {
      await refresh();
      if (_disposed) return;
      await _store.restorePurchases().timeout(productQueryTimeout);
    } catch (_) {
      message = (s) => s.proRestoreFailed;
      notifyListeners();
    }
  }

  Future<void> _onPurchases(
    List<PurchaseDetails> purchases,
  ) => _serial(() async {
    for (final purchase in purchases) {
      // Play can report a canceled/failed billing flow without a product ID
      // when its purchase list is empty. Finish only our active attempt; an
      // unidentified successful/pending purchase must never grant access.
      if (purchasing &&
          purchase.productID.isEmpty &&
          (purchase.status == PurchaseStatus.canceled ||
              purchase.status == PurchaseStatus.error)) {
        purchasing = false;
        message =
            purchase.status == PurchaseStatus.error
                ? (s) => s.proIncomplete
                : null;
        continue;
      }
      if (purchase.productID != proProductId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        message = (s) => s.proPending;
      } else if (purchase.status == PurchaseStatus.error) {
        purchasing = false;
        message = (s) => s.proIncomplete;
      } else if (purchase.status == PurchaseStatus.canceled) {
        purchasing = false;
        message = null;
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final token = purchase.verificationData.serverVerificationData;
        final result = await _verifyToken(
          token,
          source: purchase.verificationData.source,
        );
        if (result == _VerificationResult.active) {
          await _saveEntitlement(token);
          _purchaseUnlocked = true;
          message = (s) => s.proUnlocked;
          if (purchase.pendingCompletePurchase) {
            // Server acknowledgement is authoritative; also finish the client
            // transaction so the store does not keep reporting it as pending.
            try {
              await _store.completePurchase(purchase);
            } catch (_) {}
          }
        } else if (result == _VerificationResult.inactive) {
          // A restored old/refunded token must not erase a newer valid purchase.
          if (_cachedToken == null || _cachedToken == token) {
            await _clearEntitlement();
            message = (s) => s.proInvalid;
          }
        } else {
          checkOfflineExpiry();
          message =
              _purchaseUnlocked
                  ? (s) => s.proOffline
                  : (s) => s.proServerUnavailable;
        }
        purchasing = false;
        // The verifier acknowledges the purchase on Play before returning active.
      }
    }
    notifyListeners();
  });

  Future<void> _refreshCachedEntitlement(String token) async {
    final result = await _verifyToken(token, source: 'google_play');
    if (result == _VerificationResult.active) {
      await _saveEntitlement(token);
      _purchaseUnlocked = true;
      message = null;
    } else if (result == _VerificationResult.inactive) {
      await _clearEntitlement();
      message = (s) => s.proRevoked;
    } else {
      checkOfflineExpiry();
    }
    notifyListeners();
  }

  Future<_VerificationResult> _verifyToken(
    String token, {
    required String source,
  }) async {
    if (!verificationConfigured || token.isEmpty) {
      return _VerificationResult.unavailable;
    }
    try {
      _lastAttempt = _now();
      final response = await _client
          .post(
            Uri.parse(verificationUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'packageName': 'com.lucentylabs.nwcplayer',
              'productId': proProductId,
              'purchaseToken': token,
              'source': source,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return _VerificationResult.unavailable;
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (result['active'] is! bool || result['productId'] != proProductId) {
        return _VerificationResult.unavailable;
      }
      return result['active'] == true
          ? _VerificationResult.active
          : _VerificationResult.inactive;
    } catch (_) {
      return _VerificationResult.unavailable;
    }
  }

  Future<void> _saveEntitlement(String token) async {
    if (_disposed) return;
    final verifiedAt = _now().toUtc();
    _cachedToken = token;
    _verifiedAt = verifiedAt;
    _lastSeenAt = verifiedAt;
    _startLease();
    try {
      await _secureStorage.write(key: _proTokenKey, value: token);
      await _secureStorage.write(
        key: _proLastSeenKey,
        value: verifiedAt.toIso8601String(),
      );
      await _secureStorage.write(
        key: _proVerifiedAtKey,
        value: verifiedAt.toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _clearEntitlement() async {
    _purchaseUnlocked = false;
    _cachedToken = null;
    _verifiedAt = null;
    _lastSeenAt = null;
    _expiryTimer?.cancel();
    try {
      await _secureStorage.delete(key: _proTokenKey);
      await _secureStorage.delete(key: _proVerifiedAtKey);
      await _secureStorage.delete(key: _proLastSeenKey);
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _expiryTimer?.cancel();
    _leaseWatch.stop();
    _subscription?.cancel();
    reviewAccess.dispose();
    _client.close();
    super.dispose();
  }
}

class ProOfferSheet extends StatefulWidget {
  const ProOfferSheet({super.key, required this.access});
  final ProAccess access;

  @override
  State<ProOfferSheet> createState() => _ProOfferSheetState();
}

class _ProOfferSheetState extends State<ProOfferSheet> {
  ProAccess get access => widget.access;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !access.unlocked) unawaited(access.refreshProduct());
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: access,
    builder:
        (context, _) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'NWC Player Pro',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(playerStrings(context).proDescription),
                const SizedBox(height: 14),
                if (access.message != null && !access.reviewAccess.unlocked)
                  Text(access.message!(playerStrings(context))),
                if (!access.reviewAccess.unlocked)
                  Text(playerStrings(context).proTerms),
                if (access.reviewAccess.unlocked)
                  Text(playerStrings(context).reviewActive)
                else if (access.unlocked)
                  Text(playerStrings(context).proUnlocked)
                else if (!access.verificationConfigured)
                  Text(playerStrings(context).proNotConfigured)
                else if (access.loading) ...[
                  const LinearProgressIndicator(),
                  Text(playerStrings(context).proProductLoading),
                ] else if (access.product != null)
                  FilledButton(
                    onPressed: access.purchasing ? null : access.buy,
                    child: Text(
                      playerStrings(context).buyPro(access.product!.price),
                    ),
                  )
                else ...[
                  Text(
                    (access.productMessage ?? (s) => s.proProductUnavailable)(
                      playerStrings(context),
                    ),
                  ),
                  if (access.productDiagnostic != null)
                    SelectableText(
                      '${access.productDiagnostic}\n$proProductId',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
                if (!access.unlocked && access.verificationConfigured)
                  OutlinedButton.icon(
                    key: const ValueKey('refresh-pro-product'),
                    onPressed:
                        access.loading || access.purchasing
                            ? null
                            : access.refreshProduct,
                    icon: const Icon(Icons.refresh),
                    label: Text(playerStrings(context).proRefreshProduct),
                  ),
                TextButton(
                  onPressed: access.purchasing ? null : access.restore,
                  child: Text(playerStrings(context).restorePurchases),
                ),
                const Divider(),
                ReviewAccessPanel(access: access.reviewAccess),
              ],
            ),
          ),
        ),
  );
}

/// Visible, documented access for review. No hidden gestures or reviewer detection.
class ReviewAccessPanel extends StatefulWidget {
  const ReviewAccessPanel({super.key, required this.access});
  final ReviewAccess access;

  @override
  State<ReviewAccessPanel> createState() => _ReviewAccessPanelState();
}

class _ReviewAccessPanelState extends State<ReviewAccessPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final success = await widget.access.activate(_controller.text);
    if (success && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.access,
    builder: (context, _) {
      final s = playerStrings(context);
      final access = widget.access;
      return ExpansionTile(
        title: Text(s.reviewAccess),
        tilePadding: EdgeInsets.zero,
        children: [
          Text(s.reviewDescription),
          if (access.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(access.message!(s)),
            ),
          if (!access.unlocked) ...[
            TextField(
              key: const ValueKey('review-code'),
              controller: _controller,
              enabled: !access.busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 64,
              decoration: InputDecoration(labelText: s.reviewCode),
              onSubmitted: (_) => _activate(),
            ),
            OutlinedButton(
              onPressed: access.busy ? null : _activate,
              child: Text(access.busy ? s.reviewChecking : s.reviewActivate),
            ),
          ],
          if (access.hasCode)
            TextButton(
              onPressed: access.busy ? null : access.clear,
              child: Text(s.reviewEnd),
            ),
        ],
      );
    },
  );
}
