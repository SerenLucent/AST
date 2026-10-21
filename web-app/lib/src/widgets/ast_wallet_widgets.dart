import 'package:flutter/material.dart';

import '../services/ast_wallet_controller.dart';

class AstCoin extends StatefulWidget {
  const AstCoin({super.key, this.size = 64, this.shining = false});
  final double size;
  final bool shining;

  @override
  State<AstCoin> createState() => _AstCoinState();
}

class _AstCoinState extends State<AstCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(AstCoin oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    final animate =
        widget.shining &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_shine.isAnimating) {
      _shine.repeat();
    } else if (!animate) {
      _shine.stop();
      _shine.value = 0;
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _shine,
      child: Image.asset(
        'assets/images/ast_coin_v1.png',
        width: widget.size,
        height: widget.size,
        // Share one decoded image while the reward coin shrinks in flight.
        // A size-dependent cache key would decode again on every frame.
        cacheWidth: 192,
        filterQuality: FilterQuality.medium,
      ),
      builder: (context, coin) {
        final position = -2.5 + _shine.value * 5;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow:
                widget.shining
                    ? [
                      BoxShadow(
                        color: const Color(0xFFFFD56A).withValues(
                          alpha: .25 + .15 * (1 - (_shine.value * 2 - 1).abs()),
                        ),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child:
              widget.shining
                  ? ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback:
                        (rect) => LinearGradient(
                          begin: Alignment(position - .6, -1),
                          end: Alignment(position + .6, 1),
                          colors: const [
                            Colors.transparent,
                            Color(0xAAFFF5D5),
                            Colors.transparent,
                          ],
                          stops: const [.3, .5, .7],
                        ).createShader(rect),
                    child: coin,
                  )
                  : coin,
        );
      },
    ),
  );
}

class AstBalanceBadge extends StatelessWidget {
  const AstBalanceBadge({
    super.key,
    required this.controller,
    this.displayedBalance,
    this.coinAnchorKey,
  });
  final AstWalletController controller;
  final int? displayedBalance;
  final GlobalKey? coinAnchorKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final amount = displayedBalance ?? controller.wallet?.balance;
      final formatted =
          amount?.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          ) ??
          '—';
      return Semantics(
        label: amount == null ? '아스트 잔액 확인 중' : '보유 아스트 $amount',
        child: Tooltip(
          message: amount == null ? '서버 연결 후 잔액이 표시돼요' : '$formatted 아스트',
          child: Container(
            key: const ValueKey('ast-balance'),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE5C26A)),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(key: coinAnchorKey, child: const AstCoin(size: 23)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatted,
                        style: const TextStyle(
                          color: Color(0xFF75531B),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AstWelcomeCard extends StatelessWidget {
  const AstWelcomeCard({
    super.key,
    required this.nickname,
    required this.controller,
    this.onClaim,
    this.coinAnchorKey,
    this.hideCoin = false,
  });
  final String nickname;
  final AstWalletController controller;
  final Future<void> Function()? onClaim;
  final GlobalKey? coinAnchorKey;
  final bool hideCoin;

  Future<void> _claim(BuildContext context) async {
    final received = await controller.claim();
    if (received && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('10 아스트를 받았어요!')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final seconds = controller.remainingSeconds;
      final time =
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';
      final ready = controller.ready;
      return Container(
        key: const ValueKey('ast-welcome-card'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6750A4), Color(0xFF8D72C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x336750A4),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$nickname님, 안녕하세요!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '오늘도 멋진 하모니를 만들어볼까요?',
                        style: TextStyle(color: Color(0xFFECE5FA), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Opacity(
                  key: coinAnchorKey,
                  opacity: hideCoin ? 0 : 1,
                  child: AstCoin(
                    key: const ValueKey('ast-reward-coin'),
                    size: 62,
                    shining:
                        ready && !controller.claiming && !controller.loading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              ready ? '하모니가 쌓였어요 · 10 아스트' : '1시간마다 10 아스트',
              style: const TextStyle(
                color: Color(0xFFFFE7AB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      key: const ValueKey('ast-progress'),
                      value: controller.progress,
                      minHeight: 9,
                      backgroundColor: const Color(0x406750A4),
                      color: const Color(0xFFFFD775),
                      semanticsLabel:
                          ready ? '아스트 수령 가능' : '아스트 수령까지 $seconds초 남음',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 98,
                  height: 42,
                  child:
                      ready
                          ? FilledButton(
                            key: const ValueKey('ast-claim'),
                            onPressed:
                                controller.claiming || controller.loading
                                    ? null
                                    : onClaim ?? () => _claim(context),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              backgroundColor: const Color(0xFFFFDA7A),
                              foregroundColor: const Color(0xFF503718),
                              disabledBackgroundColor: const Color(0xCCFFDA7A),
                              disabledForegroundColor: const Color(0xFF503718),
                              textStyle: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Text(
                              controller.claiming ? '받는 중…' : '아스트 받기',
                            ),
                          )
                          : Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              controller.wallet == null
                                  ? (controller.loading ? '연결 중…' : '연결 필요')
                                  : time,
                              key: const ValueKey('ast-countdown'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                ),
              ],
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 6),
              Text(
                controller.error!,
                style: const TextStyle(
                  color: Color(0xFFFFE7AB),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              TextButton(
                onPressed:
                    controller.loading || controller.claiming
                        ? null
                        : controller.refresh,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('연결 다시 시도'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
