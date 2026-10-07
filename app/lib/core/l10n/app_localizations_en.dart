// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ConsentLink';

  @override
  String get home => 'Home';

  @override
  String get projects => 'Projects';

  @override
  String get capture => 'Capture';

  @override
  String get insights => 'Insights';

  @override
  String get me => 'Me';

  @override
  String get homeTitle => 'Consent people understand.';

  @override
  String get homeDescription =>
      'Prepare clear consent forms and support participants throughout the consent process.';

  @override
  String get workspaceTitle => 'Your workspace';

  @override
  String get workspaceDescription =>
      'Your projects, field capture and insights will be available here as the app is developed.';

  @override
  String get projectsTitle => 'Research projects';

  @override
  String get projectsDescription =>
      'Your research projects and consent forms will appear here.';

  @override
  String get captureTitle => 'Field capture';

  @override
  String get captureDescription =>
      'The participant consent flow will be connected here in the field capture task.';

  @override
  String get insightsTitle => 'Research insights';

  @override
  String get insightsDescription =>
      'Consent records, feedback and exports will be connected here.';

  @override
  String get meTitle => 'Your preferences';

  @override
  String get meDescription =>
      'Account, language and accessibility preferences will be connected here.';

  @override
  String get foundationNotice => 'App foundation preview';

  @override
  String get foundationDescription =>
      'Navigation and theme styling are ready to test. Research services are not connected yet.';

  @override
  String get routeErrorTitle => 'Page unavailable';

  @override
  String get routeErrorDescription =>
      'This page could not be opened. Return to Home to continue.';

  @override
  String get returnHome => 'Return to Home';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingLanguagesTitle =>
      'Consent in the language people live in';

  @override
  String get onboardingLanguagesBody =>
      'Choose a language familiar to the people you are researching.';

  @override
  String get onboardingOfflineTitle => 'Works where the signal doesn’t';

  @override
  String get onboardingOfflineBody =>
      'Collect consent offline. Sync when you reconnect.';

  @override
  String get onboardingAiTitle => 'AI drafts. You decide.';

  @override
  String get onboardingAiBody =>
      'Review, edit and approve every AI-drafted sections.';

  @override
  String get onboardingInstitutionTitle =>
      'Your institution’s look, automatically';

  @override
  String get onboardingInstitutionBody =>
      'JApply your institution’s templates, logo and colours.';

  @override
  String onboardingPageAnnouncement(int current, int total) {
    return 'Introduction, page $current of $total';
  }
}
