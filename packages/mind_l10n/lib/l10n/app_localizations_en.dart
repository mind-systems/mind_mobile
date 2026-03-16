// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get error => 'Error';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get account => 'Account';

  @override
  String get appearance => 'Appearance';

  @override
  String get session => 'Session';

  @override
  String get name => 'Name';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get profile => 'Profile';

  @override
  String get email => 'Email';

  @override
  String get login => 'Login';

  @override
  String get logOut => 'Log out';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get onboardingHello => 'Hello';

  @override
  String get onboardingWelcome => 'Welcome to your mind';

  @override
  String get loginCheckEmailTitle => 'Check your email';

  @override
  String get loginCheckEmailDescription =>
      'We sent you a one-time sign-in link. Click the link on the same device.';

  @override
  String get loginCodeHint => 'Or paste your code here';

  @override
  String get loginSendCodeError => 'Failed to send code';

  @override
  String get loginCodeInvalidError => 'Code is invalid or expired';

  @override
  String get logOutDescription => 'Come back again soon';

  @override
  String get breathPhaseInhale => 'Inhale';

  @override
  String get breathPhaseHold => 'Hold';

  @override
  String get breathPhaseExhale => 'Exhale';

  @override
  String get breathPhaseRest => 'Rest';

  @override
  String get breathSessionListLoadFailed => 'Failed to load sessions';

  @override
  String get breathSessionListPagingFailed => 'Failed to load more sessions';

  @override
  String get breathSessionListSyncFailed => 'Failed to sync sessions';

  @override
  String get breathSessionListMySessions => 'My Sessions';

  @override
  String get breathSessionListStarredSessions => '★ Starred';

  @override
  String get breathSessionListSharedSessions => 'Shared Sessions';

  @override
  String get breathConstructorDeletedSuccess => 'Session deleted';

  @override
  String breathConstructorDeleteError(String error) {
    return 'Error deleting session: $error';
  }

  @override
  String get breathConstructorValidationError =>
      'Please configure at least one valid exercise';

  @override
  String get breathConstructorSavedSuccess => 'Session saved';

  @override
  String breathConstructorSaveError(String error) {
    return 'Error saving session: $error';
  }

  @override
  String get breathConstructorDeleteConfirmTitle => 'Delete Session';

  @override
  String get breathConstructorDeleteConfirmDescription =>
      'This action cannot be undone.';

  @override
  String get breathConstructorAddExercise => 'Add exercise';

  @override
  String get breathConstructorTotal => 'Total';

  @override
  String get breathConstructorRepeat => 'Repeat';

  @override
  String get homeTabBreath => 'Breath';

  @override
  String get homeTabMind => 'Mind';
}
