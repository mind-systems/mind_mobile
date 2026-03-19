import 'dart:math';

import 'package:mind/Core/TimeOfDayHelper.dart';
import 'package:mind_l10n/mind_l10n.dart';

String getSuggestionsTitle(DayPeriod period, AppLocalizations l10n) {
  final index = Random().nextInt(4);
  switch (period) {
    case DayPeriod.morning:
      switch (index) {
        case 0: return l10n.homeSuggestionsMorning1;
        case 1: return l10n.homeSuggestionsMorning2;
        case 2: return l10n.homeSuggestionsMorning3;
        default: return l10n.homeSuggestionsMorning4;
      }
    case DayPeriod.midday:
      switch (index) {
        case 0: return l10n.homeSuggestionsMidday1;
        case 1: return l10n.homeSuggestionsMidday2;
        case 2: return l10n.homeSuggestionsMidday3;
        default: return l10n.homeSuggestionsMidday4;
      }
    case DayPeriod.evening:
      switch (index) {
        case 0: return l10n.homeSuggestionsEvening1;
        case 1: return l10n.homeSuggestionsEvening2;
        case 2: return l10n.homeSuggestionsEvening3;
        default: return l10n.homeSuggestionsEvening4;
      }
  }
}
