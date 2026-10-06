import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
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
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ConsentLink'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Consent people understand.'**
  String get homeTitle;

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'Prepare clear consent forms and support participants throughout the consent process.'**
  String get homeDescription;

  /// No description provided for @workspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Your workspace'**
  String get workspaceTitle;

  /// No description provided for @workspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Your projects, field capture and insights will be available here as the app is developed.'**
  String get workspaceDescription;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Research projects'**
  String get projectsTitle;

  /// No description provided for @projectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Your research projects and consent forms will appear here.'**
  String get projectsDescription;

  /// No description provided for @captureTitle.
  ///
  /// In en, this message translates to:
  /// **'Field capture'**
  String get captureTitle;

  /// No description provided for @captureDescription.
  ///
  /// In en, this message translates to:
  /// **'The participant consent flow will be connected here in the field capture task.'**
  String get captureDescription;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Research insights'**
  String get insightsTitle;

  /// No description provided for @insightsDescription.
  ///
  /// In en, this message translates to:
  /// **'Consent records, feedback and exports will be connected here.'**
  String get insightsDescription;

  /// No description provided for @meTitle.
  ///
  /// In en, this message translates to:
  /// **'Your preferences'**
  String get meTitle;

  /// No description provided for @meDescription.
  ///
  /// In en, this message translates to:
  /// **'Account, language and accessibility preferences will be connected here.'**
  String get meDescription;

  /// No description provided for @foundationNotice.
  ///
  /// In en, this message translates to:
  /// **'App foundation preview'**
  String get foundationNotice;

  /// No description provided for @foundationDescription.
  ///
  /// In en, this message translates to:
  /// **'Navigation and theme styling are ready to test. Research services are not connected yet.'**
  String get foundationDescription;

  /// No description provided for @routeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Page unavailable'**
  String get routeErrorTitle;

  /// No description provided for @routeErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'This page could not be opened. Return to Home to continue.'**
  String get routeErrorDescription;

  /// No description provided for @returnHome.
  ///
  /// In en, this message translates to:
  /// **'Return to Home'**
  String get returnHome;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
