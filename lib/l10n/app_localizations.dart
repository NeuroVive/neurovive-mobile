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

  /// No description provided for @voiceRecord.
  ///
  /// In en, this message translates to:
  /// **'Voice Record'**
  String get voiceRecord;

  /// No description provided for @handwritingTestPage.
  ///
  /// In en, this message translates to:
  /// **'Handwriting Test'**
  String get handwritingTestPage;

  /// No description provided for @penPage.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get penPage;

  /// No description provided for @medicalReport.
  ///
  /// In en, this message translates to:
  /// **'Medical Report'**
  String get medicalReport;

  /// No description provided for @landingPage.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get landingPage;

  /// No description provided for @loginPage.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginPage;

  /// No description provided for @registerPage.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerPage;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello!'**
  String get hello;

  /// No description provided for @welcomeToNeuroVive.
  ///
  /// In en, this message translates to:
  /// **'Welcome to neuroVive'**
  String get welcomeToNeuroVive;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get userName;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get enterUsername;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// No description provided for @invalidUsernameOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get invalidUsernameOrPassword;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectToSmartPen.
  ///
  /// In en, this message translates to:
  /// **'Connect to Smart Pen'**
  String get connectToSmartPen;

  /// No description provided for @valueAxis.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueAxis;

  /// No description provided for @timeAxis.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeAxis;

  /// No description provided for @handwritingInstructionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Handwriting Test Instructions'**
  String get handwritingInstructionsTitle;

  /// No description provided for @drawSpiral.
  ///
  /// In en, this message translates to:
  /// **'Draw a spiral'**
  String get drawSpiral;

  /// No description provided for @takePhotoForSpiral.
  ///
  /// In en, this message translates to:
  /// **'Take a photo for your spiral'**
  String get takePhotoForSpiral;

  /// No description provided for @preparationLabel.
  ///
  /// In en, this message translates to:
  /// **'Preparation:'**
  String get preparationLabel;

  /// No description provided for @drawingSpiralLabel.
  ///
  /// In en, this message translates to:
  /// **'Drawing the Spiral:'**
  String get drawingSpiralLabel;

  /// No description provided for @capturingPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Capturing the Photo:'**
  String get capturingPhotoLabel;

  /// No description provided for @preparationBullet1.
  ///
  /// In en, this message translates to:
  /// **'Use a blank, unlined white sheet of paper.'**
  String get preparationBullet1;

  /// No description provided for @preparationBullet2.
  ///
  /// In en, this message translates to:
  /// **'Use a dark pen (black or blue ink).'**
  String get preparationBullet2;

  /// No description provided for @preparationBullet3.
  ///
  /// In en, this message translates to:
  /// **'Place the paper on a flat surface.'**
  String get preparationBullet3;

  /// No description provided for @spiralDrawingBullet1.
  ///
  /// In en, this message translates to:
  /// **'Start from a dot in the center.'**
  String get spiralDrawingBullet1;

  /// No description provided for @spiralDrawingBullet2.
  ///
  /// In en, this message translates to:
  /// **'Draw 5 continuous outward rotations.'**
  String get spiralDrawingBullet2;

  /// No description provided for @spiralDrawingBullet3.
  ///
  /// In en, this message translates to:
  /// **'Draw naturally. Do not hide shakiness.'**
  String get spiralDrawingBullet3;

  /// No description provided for @capturePhotoBullet1.
  ///
  /// In en, this message translates to:
  /// **'Ensure good lighting.'**
  String get capturePhotoBullet1;

  /// No description provided for @capturePhotoBullet2.
  ///
  /// In en, this message translates to:
  /// **'Hold phone parallel to paper.'**
  String get capturePhotoBullet2;

  /// No description provided for @capturePhotoBullet3.
  ///
  /// In en, this message translates to:
  /// **'Align spiral inside guide.'**
  String get capturePhotoBullet3;

  /// No description provided for @spiralNotDetected.
  ///
  /// In en, this message translates to:
  /// **'No spirals detected in this photo'**
  String get spiralNotDetected;

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Capture failed'**
  String get captureFailed;

  /// No description provided for @aiRiskScore.
  ///
  /// In en, this message translates to:
  /// **'AI Risk Score'**
  String get aiRiskScore;

  /// No description provided for @highRisk.
  ///
  /// In en, this message translates to:
  /// **'High Risk'**
  String get highRisk;

  /// No description provided for @moderateRisk.
  ///
  /// In en, this message translates to:
  /// **'Moderate Risk'**
  String get moderateRisk;

  /// No description provided for @slightRisk.
  ///
  /// In en, this message translates to:
  /// **'Slight Risk'**
  String get slightRisk;

  /// No description provided for @noRisk.
  ///
  /// In en, this message translates to:
  /// **'No Risk'**
  String get noRisk;

  /// No description provided for @aiResult.
  ///
  /// In en, this message translates to:
  /// **'AI Result:'**
  String get aiResult;

  /// No description provided for @probability.
  ///
  /// In en, this message translates to:
  /// **'Probability:'**
  String get probability;

  /// No description provided for @aiError.
  ///
  /// In en, this message translates to:
  /// **'AI Error'**
  String get aiError;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @penProcessingError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while processing the pen data.'**
  String get penProcessingError;

  /// No description provided for @hasParkinson.
  ///
  /// In en, this message translates to:
  /// **'has Parkinson'**
  String get hasParkinson;

  /// No description provided for @doesNotHaveParkinson.
  ///
  /// In en, this message translates to:
  /// **'doesn\'t have Parkinson'**
  String get doesNotHaveParkinson;
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
