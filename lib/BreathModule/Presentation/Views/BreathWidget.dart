import 'package:flutter/widgets.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathShapePainter.dart';

class BreathShapeController extends ChangeNotifier {
  double _progress = 0.0;
  Duration _animationDuration = const Duration(milliseconds: 100);

  double get progress => _progress;
  Duration get animationDuration => _animationDuration;

  void setProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _progress) return;
    _progress = clamped;
    notifyListeners();
  }

  void reset() {
    setProgress(0.0);
  }

  void animateToProgress(double targetProgress, Duration duration) {
    _animationDuration = duration;
    setProgress(targetProgress);
  }

  void setProgressImmediately(double value) {
    _animationDuration = Duration.zero;
    setProgress(value);
  }
}

class BreathShapeWidget extends StatefulWidget {
  final SetShape shape;
  final TriangleOrientation? triangleOrientation;
  final BreathShapeController controller;

  final Color? shapeColor;
  final Color? pointColor;
  final double? strokeWidth;
  final double? pointRadius;

  const BreathShapeWidget({
    super.key,
    required this.shape,
    required this.controller,
    this.triangleOrientation,
    this.shapeColor,
    this.pointColor,
    this.strokeWidth,
    this.pointRadius,
  });

  @override
  State<BreathShapeWidget> createState() => _BreathShapeWidgetState();
}

class _BreathShapeWidgetState extends State<BreathShapeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Animation<double>? _animation;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _currentProgress = widget.controller.progress;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(BreathShapeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    final targetProgress = widget.controller.progress;
    final duration = widget.controller.animationDuration;

    // Если duration == 0, устанавливаем мгновенно
    if (duration == Duration.zero) {
      setState(() {
        _currentProgress = targetProgress;
      });
      return;
    }

    // Иначе анимируем
    _animationController.duration = duration;

    _animation =
        Tween<double>(begin: _currentProgress, end: targetProgress).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear),
        )..addListener(() {
          setState(() {
            _currentProgress = _animation!.value;
          });
        });

    _animationController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BreathShapePainter(
        shape: widget.shape,
        normalizedTime: _currentProgress,
        triangleOrientation: widget.triangleOrientation,
        shapeColor: widget.shapeColor ?? const Color(0xFF00D9FF),
        pointColor: widget.pointColor ?? const Color(0xFFFFFFFF),
        shapeStrokeWidth: widget.strokeWidth ?? 3.0,
        pointRadius: widget.pointRadius ?? 8.0,
      ),
      child: const SizedBox.expand(),
    );
  }
}
