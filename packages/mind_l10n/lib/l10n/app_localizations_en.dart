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

  @override
  String get homeSuggestionsTitle => 'Suggestions for you';

  @override
  String get homeSuggestionsError => 'Could not load suggestions';

  @override
  String get homeSuggestionsMorning1 => 'Good morning';

  @override
  String get homeSuggestionsMorning2 => 'Morning energy';

  @override
  String get homeSuggestionsMorning3 => 'Start your day right';

  @override
  String get homeSuggestionsMorning4 => 'Wake up gently';

  @override
  String get homeSuggestionsMidday1 => 'Midday reset';

  @override
  String get homeSuggestionsMidday2 => 'Recharge your focus';

  @override
  String get homeSuggestionsMidday3 => 'Take a breath';

  @override
  String get homeSuggestionsMidday4 => 'A moment for yourself';

  @override
  String get homeSuggestionsEvening1 => 'Wind down';

  @override
  String get homeSuggestionsEvening2 => 'Evening calm';

  @override
  String get homeSuggestionsEvening3 => 'Prepare for rest';

  @override
  String get homeSuggestionsEvening4 => 'End the day well';

  @override
  String get mcpTitle => 'MCP';

  @override
  String get mcpIntegrations => 'Integrations';

  @override
  String get mcpDescription =>
      'Personal access tokens allow Claude Desktop to access your exercises.';

  @override
  String get mcpCreateToken => 'Create token';

  @override
  String get mcpRevealTitle => 'Copy your token';

  @override
  String get mcpRevealWarning => 'This is shown only once. Give it to your AI.';

  @override
  String get mcpCopy => 'Copy';

  @override
  String get mcpDone => 'Done';

  @override
  String get mcpRevokeConfirmTitle => 'Revoke token';

  @override
  String get mcpRevokeConfirmDescription =>
      'This token will stop working immediately.';

  @override
  String get mcpTokenName => 'Name';

  @override
  String get mcpNewToken => 'New token';

  @override
  String mcpCreatedAt(String date) {
    return 'Created $date';
  }
}
