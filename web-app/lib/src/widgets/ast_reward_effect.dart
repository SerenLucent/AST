import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ast_wallet.dart';
import '../services/ast_reward_sound.dart';
import '../services/ast_wallet_controller.dart';
import 'ast_wallet_widgets.dart';

/// Display-only state. No balance is ever credited by the animation itself.
class AstRewardPresentation extends ChangeNotifier {
  AstRewardPresentation(this.claim);
  final Future<void> Function() claim;
  final sourceKey = GlobalKey(debugLabel: 'ast-coin-source');
  final targetKey = GlobalKey(debugLabel: 'ast-coin-target');
  int? balance;
  double badgeScale = 1;
  bool hideSource = false;

  void _update(int? amount, {double scale = 1, bool hide = false}) {
    balance = amount;
    badgeScale = scale;
    hideSource = hide;
    notifyListeners();
  }
}

class AstRewardEffect extends StatefulWidget {
  const AstRewardEffect({
    super.key,
    required this.controller,
    required this.builder,
    this.sound,
  });
  final AstWalletController controller;
  final AstRewardSound? sound;
  final Widget Function(BuildContext, AstRewardPresentation) builder;
  static const duration = Duration(milliseconds: 1300);
  static const arrival = .64;

  @override
  State<AstRewardEffect> createState() => _AstRewardEffectState();
}

class _AstRewardEffectState extends State<AstRewardEffect>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _layerKey = GlobalKey();
  late final _animation =
      AnimationController(vsync: this, duration: AstRewardEffect.duration)
        ..addListener(_tick)
        ..addStatusListener(_status);
  late final _presentation = AstRewardPresentation(_claim);
  late AstRewardSound _sound;
  Offset? _start;
  Offset? _end;
  int _from = 0;
  int _to = 0;
  int _generation = 0;
  bool _pending = false;
  bool _arrived = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _sound = widget.sound ?? CoinStackRewardSound();
    _presentation.balance = widget.controller.wallet?.balance;
    widget.controller.addListener(_walletChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(AstRewardEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_walletChanged);
      _cancel(rebuild: false);
      widget.controller.addListener(_walletChanged);
    }
    if (oldWidget.sound != widget.sound) {
      unawaited(_sound.dispose());
      _sound = widget.sound ?? CoinStackRewardSound();
    }
  }

  void _walletChanged() {
    if (!_pending && _start == null) {
      _presentation._update(widget.controller.wallet?.balance);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _cancel();
  }

  @override
  void didChangeMetrics() => _cancel();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _cancel(rebuild: false);
    }
  }

  void _cancel({bool rebuild = true}) {
    _generation++;
    _pending = false;
    _animation.stop();
    _start = null;
    _end = null;
    unawaited(_sound.stop());
    _presentation._update(widget.controller.wallet?.balance);
    if (rebuild && mounted) setState(() {});
  }

  Offset? _center(GlobalKey key, RenderBox layer) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final point = layer.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
    return (Offset.zero & layer.size).contains(point) ? point : null;
  }

  Future<void> _claim() async {
    final wallet = widget.controller;
    if (_pending ||
        _start != null ||
        !wallet.ready ||
        wallet.loading ||
        wallet.claiming) {
      return;
    }
    final generation = ++_generation;
    _pending = true;
    _presentation._update(wallet.wallet?.balance);
    unawaited(_sound.prepare());
    final credited = await wallet.claim();
    if (!mounted || generation != _generation) return;
    _pending = false;
    if (!credited || !_foreground || !TickerMode.valuesOf(context).enabled) {
      _walletChanged();
      return;
    }
    final balance = wallet.wallet!.balance;
    _to = balance;
    _from = math.max(0, balance - AstWallet.reward);
    final layer = _layerKey.currentContext?.findRenderObject();
    final start =
        layer is RenderBox ? _center(_presentation.sourceKey, layer) : null;
    final end =
        layer is RenderBox ? _center(_presentation.targetKey, layer) : null;
    if (MediaQuery.disableAnimationsOf(context) ||
        start == null ||
        end == null) {
      _presentation._update(balance);
      unawaited(_sound.play());
      return;
    }
    setState(() {
      _start = start;
      _end = end;
      _arrived = false;
    });
    _presentation._update(_from, hide: true);
    _animation.forward(from: 0);
  }

  void _tick() {
    if (_start == null) return;
    final t = _animation.value;
    if (!_arrived && t >= AstRewardEffect.arrival) {
      _arrived = true;
      unawaited(_sound.play());
    }
    final settle = ((t - AstRewardEffect.arrival) /
            (1 - AstRewardEffect.arrival))
        .clamp(0.0, 1.0);
    final count = Curves.easeOut.transform(settle);
    _presentation._update(
      _from + ((_to - _from) * count).floor(),
      scale: 1 + math.sin(settle * math.pi) * .14,
      hide: !_arrived,
    );
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _presentation._update(widget.controller.wallet?.balance);
    setState(() {
      _start = null;
      _end = null;
    });
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_walletChanged);
    _animation.dispose();
    _presentation.dispose();
    unawaited(_sound.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    // The home/schedule tree is NOT rebuilt on every animation frame.
    child: widget.builder(context, _presentation),
    builder:
        (context, child) => Stack(
          key: _layerKey,
          fit: StackFit.expand,
          children: [
            child!,
            if (_start != null && _end != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: _FlightFrame(
                      start: _start!,
                      end: _end!,
                      t: _animation.value,
                    ),
                  ),
                ),
              ),
          ],
        ),
  );
}

Offset astRewardPosition(Offset start, Offset end, double progress) {
  final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
  final control = Offset(
    start.dx + 24,
    math.max(24, math.min(start.dy, end.dy) - 64),
  );
  return start * ((1 - t) * (1 - t)) +
      control * (2 * (1 - t) * t) +
      end * (t * t);
}

class _FlightFrame extends StatelessWidget {
  const _FlightFrame({required this.start, required this.end, required this.t});
  final Offset start;
  final Offset end;
  final double t;

  @override
  Widget build(BuildContext context) {
    final flight = (t / AstRewardEffect.arrival).clamp(0.0, 1.0);
    final settle = ((t - AstRewardEffect.arrival) /
            (1 - AstRewardEffect.arrival))
        .clamp(0.0, 1.0);
    final point = astRewardPosition(start, end, flight);
    final size = 62 - 39 * Curves.easeIn.transform(flight);
    return Stack(
      key: const ValueKey('ast-reward-flight'),
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _SparkleTrail(start, end, t)),
        ),
        if (flight < 1)
          Positioned(
            left: point.dx - size / 2,
            top: point.dy - size / 2,
            child: Transform.rotate(
              angle: math.sin(flight * math.pi) * -.38,
              child: AstCoin(
                key: const ValueKey('ast-flying-coin'),
                size: size,
              ),
            ),
          ),
        if (settle > 0)
          Positioned(
            left: end.dx - 5,
            top: end.dy + 20 - settle * 14,
            child: Opacity(
              opacity: (1 - settle * settle).clamp(0.0, 1.0),
              child: const Material(
                type: MaterialType.transparency,
                child: Text(
                  '+10',
                  key: ValueKey('ast-reward-plus-ten'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB57A00),
                    shadows: [Shadow(color: Color(0xFFFFE7A0), blurRadius: 10)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SparkleTrail extends CustomPainter {
  _SparkleTrail(this.start, this.end, this.t);
  final Offset start;
  final Offset end;
  final double t;

  void _star(Canvas canvas, Offset p, double radius, double alpha) {
    final color =
        Color.lerp(const Color(0xFFFFC444), const Color(0xFFFFFFE5), alpha)!;
    canvas.drawCircle(
      p,
      radius * 1.7,
      Paint()
        ..color = color.withValues(alpha: alpha * .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final path =
        Path()
          ..moveTo(p.dx, p.dy - radius)
          ..lineTo(p.dx + radius * .26, p.dy - radius * .26)
          ..lineTo(p.dx + radius, p.dy)
          ..lineTo(p.dx + radius * .26, p.dy + radius * .26)
          ..lineTo(p.dx, p.dy + radius)
          ..lineTo(p.dx - radius * .26, p.dy + radius * .26)
          ..lineTo(p.dx - radius, p.dy)
          ..lineTo(p.dx - radius * .26, p.dy - radius * .26)
          ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final flight = t / AstRewardEffect.arrival;
    for (var i = 0; i < 26; i++) {
      final progress = flight - .022 * i;
      if (progress < 0 || progress > 1) continue;
      final fade = (1 - i / 27) * (1 - ((flight - 1) * 3).clamp(0.0, 1.0));
      final point =
          astRewardPosition(start, end, progress) +
          Offset(math.sin(i * 2.4) * (5 + i * .4), math.cos(i * 1.8) * 7);
      _star(canvas, point, 2 + (i % 4) * 1.0, fade * .85);
    }
    if (flight >= 1) {
      final burst = ((t - AstRewardEffect.arrival) /
              (1 - AstRewardEffect.arrival))
          .clamp(0.0, 1.0);
      for (var i = 0; i < 10; i++) {
        final angle = i / 10 * math.pi * 2;
        _star(
          canvas,
          end + Offset(math.cos(angle), math.sin(angle)) * (13 + burst * 34),
          4 * (1 - burst) + 1,
          1 - burst,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparkleTrail old) =>
      t != old.t || start != old.start || end != old.end;
}
