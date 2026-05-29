/// Identifies the vendor/hardware source of a biometric sample.
///
/// Today only [neiry] is wired; other values are declared so consumers can
/// pattern-match exhaustively without future churn.
enum SensorSource { neiry, garmin, polar, appleHealth }
