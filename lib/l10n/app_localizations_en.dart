// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get voiceHelpTitle => 'Voice Test Instructions';

  @override
  String get voiceHelpFirstMain => '1. Prepare Your Environment';

  @override
  String get voiceHelpFirstMainFirstSubTitle => 'Find a Quiet Space:';

  @override
  String get voiceHelpFirstMainFirstSubDesc => 'Choose a room with no background noise or distractions.';

  @override
  String get voiceHelpFirstMainSecondSubTitle => 'Position Your Phone:';

  @override
  String get voiceHelpFirstMainSecondSubDesc => 'Hold the device approximately 20 cm (8 inches) from your mouth.';

  @override
  String get voiceHelpSecondMainTitle => '2. Perform the Test';

  @override
  String get voiceHelpSecondMainFirstSubTitle => 'Step 1:';

  @override
  String get voiceHelpSecondMainFirstSubDesc => 'Sustained \"AAA\", Take a deep breath and make a steady \"AAA\" sound (as in \"apple\") for 3 seconds.';

  @override
  String get voiceHelpSecondMainSecondSubTitle => 'Step 2:';

  @override
  String get voiceHelpSecondMainSecondSubDesc => 'Sustained \"OOO\", The app will transition automatically. Make a steady \"OOO\" sound (as in \"boot\") for another 3 seconds.';

  @override
  String get voiceHelpThirdMain => '3. Important Tips for Accuracy';

  @override
  String get voiceHelpThirdMainFirstSubTitle => 'Be Natural:';

  @override
  String get voiceHelpThirdMainFirstSubDesc => 'Use your normal speaking volume and pitch. Do not try to \"fix\" your voice; the AI needs to hear your natural tone to provide an objective truth.';

  @override
  String get voiceHelpThirdMainSecondSubTitle => 'Don\'t Worry About Tremors:';

  @override
  String get voiceHelpThirdMainSecondSubDesc => 'If your voice shakes or breaks, do not restart. These subtle changes are exactly what the AI uses to quantify your symptoms accurately.';

  @override
  String get noNameError => 'Error, no name for this route';

  @override
  String get uploadingLoading => 'Uploading';

  @override
  String get analyezedSuccessfully => 'Analysed successfully';

  @override
  String get uploadFailed => 'Upload failed, please try again later';

  @override
  String get errorOccured => 'Error occured, please make sure you are connected to the internet.';

  @override
  String get failedRecording => 'Failed to start recording, permission needed';

  @override
  String get recordOrder => 'Say the Pronounce';

  @override
  String get toneA => '“AAA”';

  @override
  String get toneO => '“OOO”';

  @override
  String get landingTagline => 'Your AI Assistant for Detecting\nParkinson’s Disease';

  @override
  String get getStarted => 'Get Started';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Log Out';

  @override
  String get chooseMethod => 'Choose the method\nof detection';

  @override
  String get voiceTest => 'Voice Test';

  @override
  String get handwrittenTest => 'HandWritten Test';

  @override
  String get smartPenTest => 'Smart Pen Test';

  @override
  String get next => 'Next';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get smartPenTitle => 'NeuroVive Smart Pen';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get startRecording => 'Start Recording';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get selectTask => 'Select Task:';

  @override
  String get spiralTest => 'Spiral Test';

  @override
  String get pressure => 'Pressure (kpa)';

  @override
  String get acceleration => 'Acceleration (g)';

  @override
  String get motionTremor => 'Motion Tremor (Hz)';

  @override
  String get pressureStability => 'Pressure Stability';

  @override
  String get tremorScore => 'Tremor Score';

  @override
  String get motionSmoothness => 'Motion Smoothness';

  @override
  String get pressureIndex => 'Pressure Irregularity Index';

  @override
  String get viewFullReport => 'View Full Report';

  @override
  String get connecting => 'Connecting...';
}
