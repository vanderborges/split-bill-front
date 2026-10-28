import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Abertura do app (substitui o vídeo): o círculo verde do ícone aparece,
/// o ✓ se desenha, os tracinhos acendem em volta e "DividiAí" surge letra
/// por letra. Depois da entrada os tracinhos ficam pulsando — é o
/// "carregando" enquanto o login automático valida. Desenhado em código
/// (nítido em qualquer tela). O fundo creme é o mesmo do ícone e da splash
/// nativa (Android `launch_background.xml`, iOS `LaunchScreen.storyboard`),
/// pra a troca não piscar.
class SplashLoading extends StatefulWidget {
  const SplashLoading({super.key, this.playIntro = true, this.onIntroFinished});

  /// false: já começa montado (ex.: voltando pro login depois do "Sair").
  final bool playIntro;

  /// Chamado uma vez, quando a entrada termina.
  final VoidCallback? onIntroFinished;

  static const Color background = Color(0xFFFDF4E8);
  static const Color green = Color(0xFF22B455);
  static const Color greenLight = Color(0xFF45D274);
  static const Color navy = Color(0xFF1F2A4C);

  @override
  State<SplashLoading> createState() => _SplashLoadingState();
}

class _SplashLoadingState extends State<SplashLoading>
    with TickerProviderStateMixin {
  static const _name = 'DividiAí';

  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulse.repeat();
        widget.onIntroFinished?.call();
      }
    });
    if (widget.playIntro) {
      _intro.forward();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double _interval(double begin, double end, [Curve curve = Curves.easeOut]) =>
      Interval(begin, end, curve: curve).transform(_intro.value);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SplashLoading.background,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _pulse]),
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 200,
                child: CustomPaint(
                  painter: _BadgePainter(
                    circle: _interval(0, 0.35, Curves.easeOutBack),
                    check: _interval(0.3, 0.6),
                    rays: _interval(0.5, 0.75),
                    pulse: _pulse.isAnimating ? _pulse.value : 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _name.length; i++)
                    _letter(_name[i], _interval(0.55 + i * 0.04, 0.7 + i * 0.04)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _letter(String letter, double t) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: SplashLoading.navy,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
}

/// Círculo verde com ✓ branco e os tracinhos em volta (como no ícone).
/// Todos os valores vão de 0 a 1.
class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.circle,
    required this.check,
    required this.rays,
    required this.pulse,
  });

  final double circle;
  final double check;
  final double rays;
  final double pulse;

  // Ângulos dos tracinhos (graus, 0 = direita, sentido horário); sem o de
  // baixo, que bateria no nome.
  static const _rayAngles = [-90, -45, -135, 0, 180, 40, 140];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.27;

    if (rays > 0) {
      // Pulso: os tracinhos saem um pouco pra fora e voltam, com um leve
      // escalonamento entre eles pra parecer que "brilham" em volta.
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 0.12;
      for (var i = 0; i < _rayAngles.length; i++) {
        final wave = math.sin((pulse - i / _rayAngles.length) * 2 * math.pi);
        final push = pulse == 0 ? 0.0 : (wave + 1) / 2;
        final angle = _rayAngles[i] * math.pi / 180;
        final direction = Offset(math.cos(angle), math.sin(angle));
        final start = radius * (1.28 + 0.08 * push);
        final length = radius * 0.3 * rays * (1 + 0.15 * push);
        paint.color = SplashLoading.green.withValues(alpha: rays * (0.65 + 0.35 * push));
        canvas.drawLine(center + direction * start,
            center + direction * (start + length), paint);
      }
    }

    if (circle > 0) {
      final r = radius * circle;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [SplashLoading.greenLight, SplashLoading.green],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    if (check > 0) {
      final path = Path()
        ..moveTo(center.dx - radius * 0.42, center.dy + radius * 0.02)
        ..lineTo(center.dx - radius * 0.12, center.dy + radius * 0.32)
        ..lineTo(center.dx + radius * 0.45, center.dy - radius * 0.28);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * check),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.17
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.circle != circle ||
      old.check != check ||
      old.rays != rays ||
      old.pulse != pulse;
}
