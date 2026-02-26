import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class EclipseOrb extends StatefulWidget {
  const EclipseOrb({
    super.key,
    this.size = 280.0,
    this.progress = 1.0,
    this.glowColor = const Color(0xFF00C8E0),
    this.maskColor = Colors.black,
    this.rFrac = 1.0,
    this.blurRMult = 0.74,
    this.deltaMult = 0.16,
    this.eMult = 0.17,
    this.maskPulseMult = 0.19,
    this.pulseScale = 0.2,
  });

  final double size;

  /// 0 = минимальный радиус маски (80 % от R),  1 = полный радиус
  final double progress;

  final Color glowColor;

  /// Цвет центрального диска-маски (обычно совпадает с цветом фона)
  final Color maskColor;

  /// Базовый радиус орба как доля от R (применяется ко всем орбам)
  final double rFrac;

  /// Множитель размера пятна свечения (blurR = r * blurRMult)
  final double blurRMult;

  /// Множитель спирографического смещения (delta = r * deltaMult)
  final double deltaMult;

  /// Множитель выглядывания за маску (E = R * eMult)
  final double eMult;

  /// Насколько маска растёт при пульсе (maskedR = R * (1 + maskPulseMult * pulseExtra))
  final double maskPulseMult;

  /// Общий множитель интенсивности пульса (масштабирует pulseExtra для всех эффектов)
  final double pulseScale;

  @override
  State<EclipseOrb> createState() => _EclipseOrbState();
}

class _EclipseOrbState extends State<EclipseOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsedSeconds = 0.0;
  Duration _lastTickTime = Duration.zero;

  // ── параметры орбов ──────────────────────────────────────────────
  // rFrac здесь — относительный коэффициент (умножается на widget.rFrac)
  // Значение 1.0 = базовый rFrac, < 1.0 = меньше, > 1.0 = больше
  static const List<_OrbDef> _orbDefs = [
    _OrbDef(rFrac: 0.90, omega1:  0.15, omega2: -0.31, phase1: 0.00, phase2: 1.0),
    _OrbDef(rFrac: 1.00, omega1:  0.11, omega2: -0.27, phase1: 1.20, phase2: 0.5),
    _OrbDef(rFrac: 0.84, omega1:  0.19, omega2: -0.23, phase1: 2.40, phase2: 2.1),
    _OrbDef(rFrac: 1.10, omega1:  0.08, omega2: -0.37, phase1: 3.80, phase2: 3.3),
    _OrbDef(rFrac: 0.76, omega1:  0.22, omega2: -0.18, phase1: 5.10, phase2: 4.7),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _lastTickTime).inMicroseconds / 1e6;
      _lastTickTime = elapsed;
      setState(() => _elapsedSeconds += dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── pulse API ────────────────────────────────────────────────────
  double _pulseExtra = 0.0; // дополнительный E при pulse

  /// Вызови этот метод чтобы запустить пульс
  void pulse() {
    setState(() => _pulseExtra = 1.0);
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return false;
      setState(() {
        _pulseExtra *= 0.92;
      });
      return _pulseExtra > 0.01;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pulse,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _EclipsePainter(
            t: _elapsedSeconds,
            progress: widget.progress.clamp(0.0, 1.0),
            pulseExtra: _pulseExtra,
            glowColor: widget.glowColor,
            maskColor: widget.maskColor,
            orbDefs: _orbDefs,
            rFrac: widget.rFrac,
            blurRMult: widget.blurRMult,
            deltaMult: widget.deltaMult,
            eMult: widget.eMult,
            maskPulseMult: widget.maskPulseMult,
            pulseScale: widget.pulseScale,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Painter
// ─────────────────────────────────────────────
class _EclipsePainter extends CustomPainter {
  _EclipsePainter({
    required this.t,
    required this.progress,
    required this.pulseExtra,
    required this.glowColor,
    required this.maskColor,
    required this.orbDefs,
    required this.rFrac,
    required this.blurRMult,
    required this.deltaMult,
    required this.eMult,
    required this.maskPulseMult,
    required this.pulseScale,
  });

  final double t;
  final double progress;
  final double pulseExtra;
  final Color glowColor;
  final Color maskColor;
  final List<_OrbDef> orbDefs;
  final double rFrac;
  final double blurRMult;
  final double deltaMult;
  final double eMult;
  final double maskPulseMult;
  final double pulseScale;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Параметры маски ──────────────────────────────────────────
    const double rMinFrac = 0.80;
    const double rMaxFrac = 0.94;
    final double R = size.width / 2 *
        _lerp(rMinFrac, rMaxFrac, progress); // радиус CoreMask

    // ── Масштабированный пульс ───────────────────────────────────
    final double p = pulseExtra * pulseScale;

    // ── Величина выглядывания ────────────────────────────────────
    final double E = R * (eMult + 0.04 * p);

    // ── Рисуем орбы ──────────────────────────────────────────────
    for (final def in orbDefs) {
      final double r = R * def.rFrac * rFrac * (1 + 0.06 * p);
      final double d = R + E - r;

      final double delta = r * deltaMult;
      final double angle1 = def.omega1 * t + def.phase1;
      final double angle2 = def.omega2 * t + def.phase2;

      final double orbX = cx + cos(angle1) * d + cos(angle2) * delta;
      final double orbY = cy + sin(angle1) * d + sin(angle2) * delta;

      // ── Радиальный градиент ──────────────────────────────────
      final double blurR = r * (blurRMult + 0.3 * p);
      final double alpha = _lerp(0.55, 0.85, progress) + 0.2 * p;

      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: alpha * 0.9),
          glowColor.withValues(alpha: alpha),
          glowColor.withValues(alpha: alpha * 0.5),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 0.62, 0.80, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(orbX, orbY), radius: blurR),
        )
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          R * (0.07 + 0.05 * p),
        );

      canvas.drawCircle(Offset(orbX, orbY), blurR, paint);
    }

    // ── CoreMask — чёрный диск поверх всего ─────────────────────
    final maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;

    final double maskedR = R * (1 + maskPulseMult * p);
    canvas.drawCircle(Offset(cx, cy), maskedR, maskPaint);

    // ── Тонкое атмосферное свечение вокруг маски ─────────────────
    final atmosphereGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        glowColor.withValues(alpha: 0.0),
        glowColor.withValues(alpha: 0.12 + 0.1 * p),
        glowColor.withValues(alpha: 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.88, 0.96, 1.0, 1.0],
    );

    final atmPaint = Paint()
      ..shader = atmosphereGradient.createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: R * 1.12),
      )
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(Offset(cx, cy), R * 1.12, atmPaint);
  }

  @override
  bool shouldRepaint(_EclipsePainter old) => true;
}

// ─────────────────────────────────────────────
//  Вспомогательные типы
// ─────────────────────────────────────────────
class _OrbDef {
  const _OrbDef({
    required this.rFrac,
    required this.omega1,
    required this.omega2,
    required this.phase1,
    required this.phase2,
  });

  final double rFrac;   // радиус орба / R
  final double omega1;  // угловая скорость орбиты  (рад/с)
  final double omega2;  // угловая скорость "луны"  (рад/с)
  final double phase1;  // начальная фаза орбиты
  final double phase2;  // начальная фаза луны
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
