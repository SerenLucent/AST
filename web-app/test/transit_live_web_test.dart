@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:ast_team_web/src/models/ast_wallet.dart';
import 'package:ast_team_web/src/screens/home_screen.dart';
import 'package:ast_team_web/src/screens/transit_live_screen.dart';
import 'package:ast_team_web/src/services/ast_wallet_repository.dart';
import 'package:ast_team_web/src/services/web_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

class _Wallet extends AstWalletRepository {
  int reads = 0, claims = 0;
  final value = const AstWallet(
    loginId: 'tester',
    balance: 120,
    cycleStartedAt: 0,
    availableAt: 3600000,
    serverNow: 0,
    lastClaimedAt: 0,
  );
  @override
  Future<AstWallet> fetch(String loginId) async {
    reads++;
    return value;
  }

  @override
  Future<AstClaimResult> claim(
    String loginId, {
    required String requestId,
    required int expectedAvailableAt,
  }) async {
    claims++;
    throw StateError('No purchase or claim is expected');
  }
}

void main() {
  test('public iframe has no AST query or same-origin storage permission', () {
    final frame = web.HTMLIFrameElement();
    configureTransitFrame(frame);
    expect(frame.src, transitLiveUrl);
    expect(frame.referrerPolicy, 'no-referrer');
    expect(frame.sandbox.contains('allow-scripts'), isTrue);
    expect(frame.sandbox.contains('allow-same-origin'), isFalse);
    expect(frame.sandbox.contains('allow-top-navigation'), isFalse);
  });

  test(
    'sandbox actually prevents access to AST parent login storage',
    () async {
      final frame = web.HTMLIFrameElement();
      configureTransitFrame(frame);
      final result = Completer<String>();
      final listener =
          ((web.MessageEvent event) {
            if (event.source != null &&
                (event.source as JSObject)
                    .strictEquals(frame.contentWindow)
                    .toDart &&
                event.data.isA<JSString>()) {
              result.complete((event.data as JSString).toDart);
            }
          }).toJS;
      web.window.addEventListener('message', listener);
      // Local fixture: no live API calls, no real login tokens.
      frame.srcdoc =
          '''<script>
      let state = 'exposed';
      try { void parent.localStorage; } catch (_) { state = 'isolated'; }
      parent.postMessage(state, '*');
    </script>'''.toJS;
      web.document.body!.append(frame);
      try {
        expect(
          await result.future.timeout(const Duration(seconds: 10)),
          'isolated',
        );
      } finally {
        web.window.removeEventListener('message', listener);
        frame.remove();
      }
    },
  );

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('Transit menu and back preserve session and wallet at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        WebApi.tokenKey: 'fixture-session',
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final wallet = _Wallet();
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: HomeScreen(
                loginId: 'tester',
                nickname: '테스터',
                isAdmin: false,
                onLogout: () async {},
                onNicknameChanged: (_) async {},
                walletRepository: wallet,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          final menu = find.byKey(const ValueKey('menu-Transit Live'));
          await tester.scrollUntilVisible(
            menu,
            350,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 300));
          const subtitle = '모임의 시간을 지켜주는 실시간 지하철 정보';
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(subtitle))
                .didExceedMaxLines,
            isFalse,
          );
          final reads = wallet.reads;
          await tester.tap(menu);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(TransitLiveScreen), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(TransitLiveScreen), findsNothing);
          expect(wallet.reads, reads);
          expect(wallet.claims, 0);
          expect(wallet.value.balance, 120);
          expect(
            (await SharedPreferences.getInstance()).getString(WebApi.tokenKey),
            'fixture-session',
          );
          expect(requests.every((r) => r.method == 'GET'), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );
    });
  }
}
