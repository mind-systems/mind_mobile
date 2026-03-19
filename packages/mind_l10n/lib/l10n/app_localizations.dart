import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationsDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you'll need to edit this
/// file.
///
/// First, open your project's ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project's Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @onboardingHello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get onboardingHello;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your mind'**
  String get onboardingWelcome;

  /// No description provided for @loginCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get loginCheckEmailTitle;

  /// No description provided for @loginCheckEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'We sent you a one-time sign-in link. Click the link on the same device.'**
  String get loginCheckEmailDescription;

  /// No description provided for @loginCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Or paste your code here'**
  String get loginCodeHint;

  /// No description provided for @loginSendCodeError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send code'**
  String get loginSendCodeError;

  /// No description provided for @loginCodeInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Code is invalid or expired'**
  String get loginCodeInvalidError;

  /// No description provided for @logOutDescription.
  ///
  /// In en, this message translates to:
  /// **'Come back again soon'**
  String get logOutDescription;

  /// No description provided for @breathPhaseInhale.
  ///
  /// In en, this message translates to:
  /// **'Inhale'**
  String get breathPhaseInhale;

  /// No description provided for @breathPhaseHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get breathPhaseHold;

  /// No description provided for @breathPhaseExhale.
  ///
  /// In en, this message translates to:
  /// **'Exhale'**
  String get breathPhaseExhale;

  /// No description provided for @breathPhaseRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get breathPhaseRest;

  /// No description provided for @breathSessionListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sessions'**
  String get breathSessionListLoadFailed;

  /// No description provided for @breathSessionListPagingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more sessions'**
  String get breathSessionListPagingFailed;

  /// No description provided for @breathSessionListSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync sessions'**
  String get breathSessionListSyncFailed;

  /// No description provided for @breathSessionListMySessions.
  ///
  /// In en, this message translates to:
  /// **'My Sessions'**
  String get breathSessionListMySessions;

  /// No description provided for @breathSessionListStarredSessions.
  ///
  /// In en, this message translates to:
  /// **'★ Starred'**
  String get breathSessionListStarredSessions;

  /// No description provided for @breathSessionListSharedSessions.
  ///
  /// In en, this message translates to:
  /// **'Shared Sessions'**
  String get breathSessionListSharedSessions;

  /// No description provided for @breathConstructorDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get breathConstructorDeletedSuccess;

  /// No description provided for @breathConstructorDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting session: {error}'**
  String breathConstructorDeleteError(String error);

  /// No description provided for @breathConstructorValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please configure at least one valid exercise'**
  String get breathConstructorValidationError;

  /// No description provided for @breathConstructorSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get breathConstructorSavedSuccess;

  /// No description provided for @breathConstructorSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving session: {error}'**
  String breathConstructorSaveError(String error);

  /// No description provided for @breathConstructorDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get breathConstructorDeleteConfirmTitle;

  /// No description provided for @breathConstructorDeleteConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get breathConstructorDeleteConfirmDescription;

  /// No description provided for @breathConstructorAddExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get breathConstructorAddExercise;

  /// No description provided for @breathConstructorTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get breathConstructorTotal;

  /// No description provided for @breathConstructorRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get breathConstructorRepeat;

  /// No description provided for @homeTabBreath.
  ///
  /// In en, this message translates to:
  /// **'Breath'**
  String get homeTabBreath;

  /// No description provided for @homeTabMind.
  ///
  /// In en, this message translates to:
  /// **'Mind'**
  String get homeTabMind;

  /// No description provided for @homeSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions for you'**
  String get homeSuggestionsTitle;

  /// No description provided for @homeSuggestionsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load suggestions'**
  String get homeSuggestionsError;

  /// No description provided for @mcpTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get mcpTitle;

  /// No description provided for @mcpIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get mcpIntegrations;

  /// No description provided for @mcpDescription.
  ///
  /// In en, this message translates to:
  /// **'Personal access tokens allow Claude Desktop to access your exercises.'**
  String get mcpDescription;

  /// No description provided for @mcpCreateToken.
  ///
  /// In en, this message translates to:
  /// **'Create token'**
  String get mcpCreateToken;

  /// No description provided for @mcpRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy your token'**
  String get mcpRevealTitle;

  /// No description provided for @mcpRevealWarning.
  ///
  /// In en, this message translates to:
  /// **'This is shown only once. Give it to your AI.'**
  String get mcpRevealWarning;

  /// No description provided for @mcpCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get mcpCopy;

  /// No description provided for @mcpDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mcpDone;

  /// No description provided for @mcpRevokeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke token'**
  String get mcpRevokeConfirmTitle;

  /// No description provided for @mcpRevokeConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'This token will stop working immediately.'**
  String get mcpRevokeConfirmDescription;

  /// No description provided for @mcpTokenName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mcpTokenName;

  /// No description provided for @mcpNewToken.
  ///
  /// In en, this message translates to:
  /// **'New token'**
  String get mcpNewToken;

  /// No description provided for @mcpCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String mcpCreatedAt(String date);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
