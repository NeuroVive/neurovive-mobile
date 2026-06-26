import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @voiceHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Test Instructions'**
  String get voiceHelpTitle;

  /// No description provided for @voiceHelpFirstMain.
  ///
  /// In en, this message translates to:
  /// **'1. Prepare Your Environment'**
  String get voiceHelpFirstMain;

  /// No description provided for @voiceHelpFirstMainFirstSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a Quiet Space:'**
  String get voiceHelpFirstMainFirstSubTitle;

  /// No description provided for @voiceHelpFirstMainFirstSubDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose a room with no background noise or distractions.'**
  String get voiceHelpFirstMainFirstSubDesc;

  /// No description provided for @voiceHelpFirstMainSecondSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Position Your Phone:'**
  String get voiceHelpFirstMainSecondSubTitle;

  /// No description provided for @voiceHelpFirstMainSecondSubDesc.
  ///
  /// In en, this message translates to:
  /// **'Hold the device approximately 20 cm (8 inches) from your mouth.'**
  String get voiceHelpFirstMainSecondSubDesc;

  /// No description provided for @voiceHelpSecondMainTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Perform the Test'**
  String get voiceHelpSecondMainTitle;

  /// No description provided for @voiceHelpSecondMainFirstSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 1:'**
  String get voiceHelpSecondMainFirstSubTitle;

  /// No description provided for @voiceHelpSecondMainFirstSubDesc.
  ///
  /// In en, this message translates to:
  /// **'Sustained \"AAA\", Take a deep breath and make a steady \"AAA\" sound (as in \"apple\") for 3 seconds.'**
  String get voiceHelpSecondMainFirstSubDesc;

  /// No description provided for @voiceHelpSecondMainSecondSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 2:'**
  String get voiceHelpSecondMainSecondSubTitle;

  /// No description provided for @voiceHelpSecondMainSecondSubDesc.
  ///
  /// In en, this message translates to:
  /// **'Sustained \"OOO\", The app will transition automatically. Make a steady \"OOO\" sound (as in \"boot\") for another 3 seconds.'**
  String get voiceHelpSecondMainSecondSubDesc;

  /// No description provided for @voiceHelpThirdMain.
  ///
  /// In en, this message translates to:
  /// **'3. Important Tips for Accuracy'**
  String get voiceHelpThirdMain;

  /// No description provided for @voiceHelpThirdMainFirstSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Be Natural:'**
  String get voiceHelpThirdMainFirstSubTitle;

  /// No description provided for @voiceHelpThirdMainFirstSubDesc.
  ///
  /// In en, this message translates to:
  /// **'Use your normal speaking volume and pitch. Do not try to \"fix\" your voice; the AI needs to hear your natural tone to provide an objective truth.'**
  String get voiceHelpThirdMainFirstSubDesc;

  /// No description provided for @voiceHelpThirdMainSecondSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Worry About Tremors:'**
  String get voiceHelpThirdMainSecondSubTitle;

  /// No description provided for @voiceHelpThirdMainSecondSubDesc.
  ///
  /// In en, this message translates to:
  /// **'If your voice shakes or breaks, do not restart. These subtle changes are exactly what the AI uses to quantify your symptoms accurately.'**
  String get voiceHelpThirdMainSecondSubDesc;

  /// No description provided for @noNameError.
  ///
  /// In en, this message translates to:
  /// **'Error, no name for this route'**
  String get noNameError;

  /// No description provided for @uploadingLoading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploadingLoading;

  /// No description provided for @analyezedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Analysed successfully'**
  String get analyezedSuccessfully;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed, please try again later'**
  String get uploadFailed;

  /// No description provided for @errorOccured.
  ///
  /// In en, this message translates to:
  /// **'Error occured, please make sure you are connected to the internet.'**
  String get errorOccured;

  /// No description provided for @failedRecording.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording, permission needed'**
  String get failedRecording;

  /// No description provided for @recordOrder.
  ///
  /// In en, this message translates to:
  /// **'Say the Pronounce'**
  String get recordOrder;

  /// No description provided for @toneA.
  ///
  /// In en, this message translates to:
  /// **'“AAA”'**
  String get toneA;

  /// No description provided for @toneO.
  ///
  /// In en, this message translates to:
  /// **'“OOO”'**
  String get toneO;

  /// No description provided for @landingTagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI Assistant for Detecting\nParkinson’s Disease'**
  String get landingTagline;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @chooseMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose the method\nof detection'**
  String get chooseMethod;

  /// No description provided for @voiceTest.
  ///
  /// In en, this message translates to:
  /// **'Voice Test'**
  String get voiceTest;

  /// No description provided for @handwrittenTest.
  ///
  /// In en, this message translates to:
  /// **'HandWritten Test'**
  String get handwrittenTest;

  /// No description provided for @smartPenTest.
  ///
  /// In en, this message translates to:
  /// **'Smart Pen Test'**
  String get smartPenTest;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @smartPenTitle.
  ///
  /// In en, this message translates to:
  /// **'NeuroVive Smart Pen'**
  String get smartPenTitle;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @selectTask.
  ///
  /// In en, this message translates to:
  /// **'Select Task:'**
  String get selectTask;

  /// No description provided for @spiralTest.
  ///
  /// In en, this message translates to:
  /// **'Spiral Test'**
  String get spiralTest;

  /// No description provided for @pressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure (kpa)'**
  String get pressure;

  /// No description provided for @acceleration.
  ///
  /// In en, this message translates to:
  /// **'Acceleration (g)'**
  String get acceleration;

  /// No description provided for @motionTremor.
  ///
  /// In en, this message translates to:
  /// **'Motion Tremor (Hz)'**
  String get motionTremor;

  /// No description provided for @pressureStability.
  ///
  /// In en, this message translates to:
  /// **'Pressure Stability'**
  String get pressureStability;

  /// No description provided for @tremorScore.
  ///
  /// In en, this message translates to:
  /// **'Tremor Score'**
  String get tremorScore;

  /// No description provided for @motionSmoothness.
  ///
  /// In en, this message translates to:
  /// **'Motion Smoothness'**
  String get motionSmoothness;

  /// No description provided for @pressureIndex.
  ///
  /// In en, this message translates to:
  /// **'Pressure Irregularity Index'**
  String get pressureIndex;

  /// No description provided for @viewFullReport.
  ///
  /// In en, this message translates to:
  /// **'View Full Report'**
  String get viewFullReport;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
