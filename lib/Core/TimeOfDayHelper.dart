enum DayPeriod {
  morning,
  midday,
  evening;

  String get queryValue => name;
}

DayPeriod getDayPeriod(DateTime dateTime) {
  final hour = dateTime.hour;
  if (hour >= 5 && hour < 12) return DayPeriod.morning;
  if (hour >= 12 && hour < 17) return DayPeriod.midday;
  return DayPeriod.evening;
}
