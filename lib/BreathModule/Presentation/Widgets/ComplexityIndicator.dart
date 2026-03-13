import 'package:flutter/material.dart';

class ComplexityIndicator extends StatelessWidget {
  static const _iconSize = 20.0;
  static const _count = 5;
  static const _totalWidth = _iconSize * _count;
  static const _maxComplexity = 500.0;
  static const _minFigures = 0.6;
  static const _maxFigures = 5.0;

  final double complexity;
  final double? width;

  const ComplexityIndicator({
    super.key,
    required this.complexity,
    this.width,
  });

  double get _revealWidth {
    final figures = _minFigures +
        (complexity / _maxComplexity).clamp(0.0, 1.0) * (_maxFigures - _minFigures);
    return (figures / _maxFigures) * _totalWidth;
  }

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    // 5 icons in a row, parent SizedBox controls how much is visible.
    // SingleChildScrollView accepts content wider than constraints
    // without throwing overflow errors. NeverScrollable prevents scrolling.
    final indicator = SizedBox(
      width: _revealWidth,
      height: _iconSize,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            _count,
            (_) => Icon(
              Icons.self_improvement,
              size: _iconSize,
              color: color,
            ),
          ),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(
        width: width,
        child: Align(alignment: Alignment.centerLeft, child: indicator),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: indicator,
    );
  }
}
