/// Layout value object for [BreathSessionScreen].
///
/// Call [BreathSessionLayout.compute] once at the top of [build] with
/// [MediaQuery] dimensions. Every field is already scaled — the screen
/// never performs any further arithmetic.
final class BreathSessionLayout {
  final double shapeDimension;
  final double shapePadding;
  final double itemHeight;
  final double timelineHeight;
  final double buttonSize;
  final double buttonPadding;
  final double iconSize;

  // ---------------------------------------------------------------------------
  // Private reference constants (scale 1.0 baseline)
  // ---------------------------------------------------------------------------

  static const double _kShapeWidthRatio        = 0.7;
  static const double _kShapePadding           = 20.0;
  static const double _kTimelineItems          = 4.5;
  static const double _kItemHeight             = 48.0;
  static const double _kButtonSize             = 80.0;
  static const double _kButtonPadding          = 32.0;
  static const double _kIconSize               = 28.0;
  static const double _kBottomBarVPadding      = 8.0;
  // Material enforced minimum: M2 _kMinButtonSize; M3 minimumSize 40 + tapTargetSize padded.
  static const double _kIconButtonMinTapTarget = 48.0;
  static const double _kMinScale               = 0.5;

  // ---------------------------------------------------------------------------
  // Public constants (single source of truth consumed by SessionBottomBar)
  // ---------------------------------------------------------------------------

  static const double kIconSize          = _kIconSize;
  static const double kBottomBarVPadding = _kBottomBarVPadding;
  // Matches Material's enforced 48dp tap target so the bar baseline holds even at min scale.
  static const double kBottomBarBaseHeight =
      _kIconButtonMinTapTarget + _kBottomBarVPadding * 2; // 64.0

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  const BreathSessionLayout._({
    required this.shapeDimension,
    required this.shapePadding,
    required this.itemHeight,
    required this.timelineHeight,
    required this.buttonSize,
    required this.buttonPadding,
    required this.iconSize,
  });

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  /// Derives a uniform [scale] from [availableHeight] / [_idealHeight] and
  /// returns a fully-scaled layout. [scale] is clamped to [_kMinScale, 1.0].
  factory BreathSessionLayout.compute(
    double screenWidth,
    double availableHeight,
  ) {
    final scale =
        (availableHeight / _idealHeight(screenWidth)).clamp(_kMinScale, 1.0);
    return BreathSessionLayout._(
      shapeDimension: screenWidth * _kShapeWidthRatio * scale,
      shapePadding:   _kShapePadding  * scale,
      itemHeight:     _kItemHeight    * scale,
      timelineHeight: _kItemHeight * _kTimelineItems * scale,
      buttonSize:     _kButtonSize    * scale,
      buttonPadding:  _kButtonPadding * scale,
      iconSize:       _kIconSize      * scale,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Reference content height at scale 1.0, derived from the same constants
  /// used to compute each field — no hardcoded 652 to keep in sync.
  static double _idealHeight(double screenWidth) =>
      (screenWidth * _kShapeWidthRatio + _kShapePadding * 2) +
      (_kItemHeight * _kTimelineItems) +
      (_kButtonSize + _kButtonPadding * 2);
}
