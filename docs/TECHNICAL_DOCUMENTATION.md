# NeuroVive Mobile Application - Technical Documentation

This document describes the current Flutter application structure, runtime flow, feature flows, services, data contracts, and platform requirements for the NeuroVive mobile application.

The application is an AI-assisted Parkinson's disease screening app. It supports three detection methods:

- Voice recording test
- Handwriting spiral image test
- Smart pen sensor test

All three methods ultimately produce or request an AI prediction and display the output in a shared medical report screen.

## 1. Technology Stack

### Framework and Language

- Flutter application
- Dart SDK constraint: `^3.9.2`
- Package version: `0.7.0+2`

### Main Packages

- `go_router`: declarative routing and navigation
- `flutter_riverpod`: application state management
- `shared_preferences`: local persistence for first-open, auth state, and help-screen flags
- `record`: microphone recording
- `path_provider`: local application document paths
- `http`: backend API calls
- `camera`: live camera preview and image capture
- `image_picker`: gallery image selection
- `image`: image decoding, cropping, and JPEG encoding
- `opencv_dart`: contour and spiral detection
- `universal_ble`: Bluetooth Low Energy scanning, connection, and notifications
- `ffi`: native smart-pen feature extraction through `libSmartPen.so`
- `flutter_localizations` and generated `l10n`: English and Arabic localization

### Assets

Configured in `pubspec.yaml`:

- `assets/images/`
- `assets/liberaries/`

Fonts:

- `Neurovive`: custom icon font from `fonts/Neurovive.ttf`
- `Roboto`: app text font from `fonts/Roboto/Roboto-VariableFont_wdth,wght.ttf`

## 2. High-Level Architecture

The app is organized around these layers:

- `lib/main.dart`: application bootstrap, router, localization provider, and shared shell layout
- `lib/screens/`: user-facing screens and feature workflows
- `lib/services/`: platform services, API clients, auth, BLE, recording, and smart-pen native integration
- `lib/notifiers/`: Riverpod state objects for uploads and smart-pen processing
- `lib/widgets/`: reusable UI components and custom painters
- `lib/l10n/`: ARB localization sources and generated localization classes
- `lib/themes/`: named `ThemeData` configurations
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Flutter platform shells

The application uses a route-driven workflow. The user selects a detection method on the landing choice screen, completes a modality-specific test, uploads or processes data, then lands on `/results`.

## 3. Application Startup

Entry point: `lib/main.dart`

Startup steps:

1. `WidgetsFlutterBinding.ensureInitialized()` initializes Flutter bindings.
2. The app locks orientation to portrait with `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`.
3. BLE logging is set to verbose with `UniversalBle.setLogLevel(BleLogLevel.verbose)`.
4. `ProviderScope` is created for Riverpod.
5. `MyApp` builds `MaterialApp.router`.

`MyApp` watches `localProvider`, which stores the current `Locale`. The default locale is English:

```dart
final localProvider = StateProvider<Locale>((ref) {
  return const Locale('en');
});
```

Localization delegates and supported locales come from the generated `AppLocalizations` class.

## 4. Routing and Navigation

Router provider: `routerProvider` in `lib/main.dart`

The app uses `GoRouter` with:

- A top-level landing route
- A top-level login route
- A top-level settings route
- A `ShellRoute` wrapping the main app pages in a shared `Scaffold` and `AppBar`

### First-Open Redirect

The router checks `SharedPreferences` key `first_open`.

```dart
final bool firstOpen = prefs.getBool('first_open') ?? true;
if (firstOpen && state.uri.path != '/landing') {
  return '/landing';
}
```

Important behavior:

- First app launch redirects to `/landing`.
- Pressing "Get Started" stores `first_open = false` and navigates to `/login`.
- After this flag is false, the router no longer redirects users to the landing page.
- Authentication is not enforced globally by the router. The `/login` screen redirects already logged-in users to `/`, but other routes are not protected by a global auth guard.

### Route Table

| Path | Name | Screen | Purpose |
| --- | --- | --- | --- |
| `/landing` | `Landing` | `LandingScreen` | First-run branding screen |
| `/login` | `Login` | `AuthScreen` | Login/register flow |
| `/settings` | `Settings` | `SettingsScreen` | Language switch and logout |
| `/` | `Choose the method\nof detection` | `LandScreen` | Detection method selection |
| `/voice` | `Voice Record` | `RecordScreen2` | Voice recording flow |
| `/handwriting` | `Handwriting Test` | `LiveShapeDetectionScreen` | Camera/gallery spiral capture |
| `/pen` | `Pen` | `BluetoothConnectionPage` | BLE smart-pen flow |
| `/sendvoice` | `#` | `SendVoiceScreen` | Upload voice or image file |
| `/results` | `Medical Report` | `ResultScreen` | AI result report |

### Shared Shell

The `ShellRoute` provides the shared `Scaffold`, app bar, back button behavior, dynamic page title, and help icon.

Dynamic theme selection:

- `/voice` and `/handwriting`: `Mainthemes.blueBackgroundTheme`
- Other shell pages: `Mainthemes.whiteBackgroundTheme`

App bar behavior:

- On `/`, the leading icon opens settings.
- On most child pages, the leading icon calls `handleBack`.
- On `/sendvoice`, the leading icon is hidden.
- `/voice` and `/handwriting` show an info icon that opens instructions.

### Back Navigation

Implemented in `lib/utils.dart`:

- From `/results`, `handleBack` returns to `/`.
- From `/`, `handleBack` exits the app with `exit(0)`.
- If the router can pop, it pops.
- Otherwise it returns false.

Several screens wrap content in `PopScope` and delegate system-back handling to `handleBack`.

## 5. First-Run, Auth, and Settings Flow

### Landing Screen

File: `lib/screens/landing/landing_screen.dart`

The landing screen shows a logo and tagline. Pressing "Get Started":

1. Stores `first_open = false` in `SharedPreferences`.
2. Navigates to `/login`.

### Auth Screen

File: `lib/screens/auth_screen.dart`

The auth screen supports login and registration with the same form:

- Username
- Password
- Password visibility toggle
- Login/register mode toggle

On initialization:

1. Calls `AuthService.isLoggedIn()`.
2. If logged in, redirects to `/`.
3. Otherwise shows the login form.

On successful login or registration, it navigates to `/`.

### Auth Service

File: `lib/services/auth_service.dart`

Keys stored in `SharedPreferences`:

- `auth_logged_in`
- `auth_token`

Production authentication sends requests to:

- `POST {baseUrl}/register`
- `POST {baseUrl}/login`

Payload:

```json
{
  "username": "string",
  "password": "string"
}
```

The auth flow stores `token` or `access_token` from the response when present. Logout sets `auth_logged_in = false` and removes the stored token.

### Settings Screen

File: `lib/screens/settings_screen.dart`

Settings supports:

- Switching locale between English and Arabic using `localProvider`
- Logging out through `AuthService.logout()`

Locale selection is currently in-memory only. It is not persisted to `SharedPreferences`, so the locale resets to English when the app restarts.

## 6. Detection Method Selection

File: `lib/screens/land_screen.dart`

The main choice screen lets the user choose one of:

- Voice Test
- HandWritten Test
- Smart Pen Test

Internal enum:

```dart
enum DetectionMethod { voice, handwriting, smartPen }
```

Navigation:

- Voice -> `/voice`
- Handwriting -> `/handwriting`
- Smart pen -> `/pen`

The user must select a card before the "Next" button becomes active.

## 7. Voice Test Flow

Primary files:

- `lib/screens/record_screen2.dart`
- `lib/services/audio_recorder.dart`
- `lib/screens/send_voice_screen.dart`
- `lib/services/api.dart`
- `lib/notifiers/voice_upload_notifier.dart`

### User Flow

1. User selects Voice Test on `/`.
2. App navigates to `/voice`.
3. User starts recording with the large control button.
4. The app records two phases:
   - Phase 1: "AAA" for 3 seconds
   - Phase 2: "OOO" for 3 seconds
5. Recording can be paused/resumed, with cooldown logic to avoid rapid toggling.
6. After both phases finish, the confirm button becomes active.
7. Confirm navigates to `/sendvoice` with extra data:

```dart
(filePath, FileType.voice)
```

8. `SendVoiceScreen` uploads the file through `Api.sendVoice`.
9. On success, the app navigates to `/results`.
10. On failure, the user is returned to `/`.

### Audio Recording Service

File: `lib/services/audio_recorder.dart`

`AudioRecorderService` wraps the `record` package.

Recording settings:

- Encoder: WAV
- Bit rate: 128000
- Sample rate: 44100
- Audio interruption mode: pause/resume
- Echo cancellation enabled
- Noise suppression enabled

On mobile/desktop, recordings are stored under the application documents directory:

```text
record_<timestamp>.wav
```

The service exposes an amplitude stream:

```dart
Stream<double> get amplitudeStream
```

The stream emits normalized audio amplitude values from roughly `-40..0 dB` mapped to `0.0..1.0`. `MicButton` uses this to animate the microphone indicator.

### Voice Upload

`Api.sendVoice(String path)`:

1. Loads dynamic `baseUrl`.
2. Reads the WAV file bytes.
3. Sends multipart `POST` to:

```text
{baseUrl}/voice
```

Multipart field:

```text
voice
```

Content type:

```text
audio/wav
```

The response is parsed into the shared `Response` model.

## 8. Handwriting Spiral Flow

Primary files:

- `lib/screens/handwriting_screen.dart`
- `lib/screens/send_voice_screen.dart`
- `lib/services/api.dart`
- `lib/notifiers/voice_upload_notifier.dart`

### User Flow

1. User selects HandWritten Test on `/`.
2. App navigates to `/handwriting`.
3. Camera initializes using the back camera.
4. The app streams camera frames and runs contour-based detection.
5. Capture button is enabled only after a spiral is detected in consecutive frames.
6. User captures the spiral image or selects an image from gallery.
7. The image is validated for a spiral shape.
8. Captured camera image is cropped to a 300x300 region around the scan area.
9. User confirms the image.
10. App navigates to `/sendvoice` with extra data:

```dart
(capturedFilePath, FileType.image)
```

11. `SendVoiceScreen` uploads the image through `Api.sendImage`.
12. On success, the app navigates to `/results`.

### Camera Initialization

The screen uses:

- `availableCameras()`
- Back camera preferred
- `ResolutionPreset.medium`
- Audio disabled
- `ImageFormatGroup.yuv420`

The app tries to enable torch mode after initialization through `_toggleFlash()`. If flash mode throws, the flash control is marked unavailable.

### Spiral Detection

Frame processing happens in `_processCameraImage(CameraImage image)`.

Main steps:

1. Skip processing when already processing or after an image has been captured.
2. Process every third frame.
3. Convert YUV420 camera frame to BGR bytes.
4. Create OpenCV `Mat`.
5. Rotate frame clockwise.
6. Convert to grayscale.
7. Apply Gaussian blur.
8. Run Canny edge detection.
9. Find external contours.
10. Filter small contours with area below 1000.
11. Approximate polygon with `approxPolyDP`.
12. Classify shape.
13. Treat the shape as a spiral when:
    - It is not a circle
    - Density is below `0.8`
    - Approximation length is at least `10`
14. Require exactly one detected shape for valid spiral state.

Detection stability:

- `REQUIRED_CONSECUTIVE_DETECTIONS = 2`
- Spiral state is cleared after a 500 ms disappearance timer.

Gallery validation uses `_checkSpiral(cv.Mat mat)` with a similar contour classification path.

### Capture and Crop

Captured images are decoded with the `image` package. The scan rectangle is converted from preview coordinates back to original image coordinates while accounting for `BoxFit.cover` scaling and crop offsets.

Output:

- Width: `300`
- Height: `300`
- Format: JPEG
- Path:

```text
spiral_<timestamp>.jpg
```

### Image Upload

`Api.sendImage(String path)`:

1. Loads dynamic `baseUrl`.
2. Reads image bytes.
3. Sends multipart `POST` to:

```text
{baseUrl}/image
```

Multipart field:

```text
image
```

Content type:

```text
image/jpeg
```

The response is parsed into the shared `Response` model.

## 9. Smart Pen Flow

Primary files:

- `lib/screens/pen_screen.dart`
- `lib/services/bluetooth_service.dart`
- `lib/services/smart_pen_service.dart`
- `lib/notifiers/smart_pen_notifier.dart`
- `lib/services/api.dart`

The smart-pen flow is the most complex path. It connects to a BLE device, listens for live packets, records a user-controlled session, extracts features with a native Android library, uploads the features, and then displays the AI result.

### Riverpod Providers

Defined in `lib/screens/pen_screen.dart`:

- `bluetoothServiceProvider`: owns `BluetoothSensorService`
- `scanResultsProvider`: exposes BLE scan results
- `connectionStateProvider`: exposes current and streamed connection state
- `sensorPacketProvider`: exposes live parsed packets

Defined in `lib/notifiers/smart_pen_notifier.dart`:

- `smartPenServiceProvider`: creates `SmartPenService`
- `smartPenNotifierProvider`: manages native feature extraction and upload state

### BLE Connection Flow

`BluetoothSensorService` states:

```dart
enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}
```

Connection sequence:

1. User presses "Scan".
2. `checkAndRequestPermissions()` verifies Bluetooth availability and permissions.
3. `UniversalBle.startScan()` begins scanning.
4. Discovered devices are streamed to the UI.
5. User selects a device.
6. App stops scanning and calls `device.connect()`.
7. App requests MTU 64.
8. App discovers services.
9. First characteristic with `notify` support is selected.
10. App subscribes to notifications.
11. Incoming bytes are buffered and parsed.

Scan automatically stops after 50 seconds if still active.

### Packet Parsing

Parser: `PacketParser` in `lib/services/bluetooth_service.dart`

Packet size:

```dart
static const int packetSize = 53;
```

Incoming BLE notifications may be split by MTU, so `_receiveBuffer` accumulates bytes until at least 53 bytes are available.

Each packet is parsed as big-endian values:

| Field | Type |
| --- | --- |
| packetType | uint8 |
| seqNumber | uint8 |
| timestamp | uint32 |
| axRaw, ayRaw, azRaw | int16 |
| gxRaw, gyRaw, gzRaw | int16 |
| pitchX100, rollX100 | int16 |
| tipFsr400Raw | uint16 |
| tipForceX10 | uint16 |
| gripARaw, gripBRaw | uint16 |
| gripMeanX10 | uint16 |
| tremorFreqX100 | uint16 |
| tremorRmsX1000 | uint16 |
| jerkMagX100 | uint16 |
| penState | uint8 |
| liftCount | uint8 |
| calAx, calAy, calAz | int16 |
| calGx, calGy, calGz | int16 |
| checkSum | uint8 |

Checksum:

- Computed as XOR of all bytes except the final checksum byte.
- Exposed as `isChecksumValid`.

Convenience getters expose scaled values:

- `pitchDegrees = pitchX100 / 100.0`
- `rollDegrees = rollX100 / 100.0`
- `tipForceGrams = tipForceX10 / 10.0`
- `gripMeanGrams = gripMeanX10 / 10.0`
- `tremorFreqHz = tremorFreqX100 / 100.0`
- `tremorRms = tremorRmsX1000 / 1000.0`
- `jerkMagnitude = jerkMagX100 / 100.0`

### Recording Session

Live packets can stream continuously, but samples are saved only while recording is active.

Start:

```dart
service.startRecordingSession();
```

Stop:

```dart
final recording = service.stopRecordingSession();
```

If no packets were recorded, stopping throws `StateError('No pen data was recorded.')`.

`PenRecordingData.fromPackets()` converts packets to feature-extraction inputs:

- `accX`: raw accelerometer X values
- `accY`: raw accelerometer Y values
- `x`: integrated accelerometer X signal
- `y`: integrated accelerometer Y signal
- `pressure`: normalized tip force
- `azimuth`: roll degrees
- `altitude`: pitch degrees

Important implementation note:

The code comments state that the current packet schema does not expose PMW3901 x/y coordinate channels directly, so x/y are approximated from integrated acceleration until firmware provides dedicated coordinate fields.

### Native Feature Extraction

File: `lib/services/smart_pen_service.dart`

`SmartPenService` loads Android native library:

```dart
DynamicLibrary.open('libSmartPen.so')
```

Supported platform:

- Android only

If initialized on another platform, it throws `UnsupportedError`.

Native libraries are included under:

- `android/app/src/main/jniLibs/armeabi-v7a/libSmartPen.so`
- `android/app/src/main/jniLibs/arm64-v8a/libSmartPen.so`
- `android/app/src/main/jniLibs/x86/libSmartPen.so`
- `android/app/src/main/jniLibs/x86_64/libSmartPen.so`

Also present:

- `assets/liberaries/libSmartPen.so`

Bound native functions:

- `compute_features`
- `free_features`
- `SmartPen_features_version`
- `SmartPen_features_last_error`
- `compute_statistical_single`
- `compute_button_status`

Constants:

```dart
penFeaturesCount = 354
penStatisticsCount = 11
penSamplingRate = 150.0
penDt = 1.0 / 150.0
penMinSamples = 150
penPressureThreshold = 0.05
```

`computeFeatures()` requires all input lists to have the same length and at least 150 samples.

Output:

- A list of native-computed feature values, expected to contain 354 floats.

### Smart Pen Upload

After feature extraction, `SmartPenNotifier.processRecording()` sends features to:

```text
{baseUrl}/pen
```

Method:

```text
POST
```

Headers:

```text
Content-Type: application/json
```

Body:

```json
{
  "features": [0.0, 1.0, 2.0]
}
```

The API response is parsed into the shared `Response` model.

On success, `/pen` navigates to `/results`.

## 10. Backend API Layer

Files:

- `lib/services/api_config.dart`
- `lib/services/api.dart`

### Dynamic Base URL

`ApiConfig.loadBaseUrl()` loads the backend base URL from a GitHub gist:

```text
<remote base-url configuration>?timestamp=<timestamp>
```

The timestamp query parameter avoids caching.

The response body is parsed with `html_parser.parse(response.body)`, and `document.body!.innerHtml.trim()` becomes the base URL.

If loading fails, `_baseUrl` is set to an empty string.

### Endpoints

| Method | Endpoint | Used By | Payload |
| --- | --- | --- | --- |
| `POST` | `/voice` | Voice flow | Multipart WAV file, field `voice` |
| `POST` | `/image` | Handwriting flow | Multipart JPEG file, field `image` |
| `POST` | `/pen` | Smart pen flow | JSON feature array |
| `POST` | `/register` | Real auth mode | JSON username/password |
| `POST` | `/login` | Real auth mode | JSON username/password |

### Response Model

File: `lib/notifiers/voice_upload_notifier.dart`

```dart
class Response {
  final JobStatus status;
  final String? prediction;
  final double? confidence;
  final String? message;
}
```

Status enum:

```dart
enum JobStatus {
  success,
  error,
}
```

JSON mapping:

- `status: "success"` -> `JobStatus.success`
- `status: "error"` -> `JobStatus.error`
- `label` or `prediction` -> `prediction`
- `probability` or `confidence` -> `confidence`
- `message` -> `message`

The API layer treats HTTP 200 and HTTP 500 as parseable responses. Other status codes return `Response(status: JobStatus.error)`. The comment explains that HTTP 500 may contain AI/model error details.

## 11. Upload State Management

File: `lib/notifiers/voice_upload_notifier.dart`

Provider:

```dart
final fileUploadProvider = AsyncNotifierProvider<FileUploadNotifier, Response?>(
  FileUploadNotifier.new,
);
```

Initial state:

- `null`, meaning idle

Upload flow:

1. State becomes `AsyncLoading`.
2. Calls the supplied production upload function.
3. Stores parsed `Response`.

`SendVoiceScreen` listens for provider state changes:

- Success -> snackbar -> `/results`
- Error response -> snackbar -> `/`
- Exception -> snackbar -> `/`

Despite the screen name, `SendVoiceScreen` handles both voice and image uploads through `FileType`.

## 12. Result Screen

File: `lib/screens/result_screen.dart`

`ResultScreen` receives a `Response` through `GoRouter` `state.extra`.

It displays:

- AI risk score gauge
- Prediction text
- Probability

Score:

```dart
int score = (result.confidence! * 100).toInt();
```

Risk buckets:

- `> 80`: High Risk
- `> 50`: moderate Risk
- `> 35`: slight Risk
- Otherwise: No Risk

Prediction output:

- If `prediction == "PD"`: `has Parkinson`
- Otherwise: `doesn't have Parkinson`

Important assumption:

The screen force-unwraps `result.confidence` and `result.prediction`. If the backend returns success without these fields, the screen will throw.

## 13. Help and Instruction Flow

File: `lib/utils.dart`

`showCurrentInstructions(context, currentPath)` dispatches:

- `/voice` -> voice instructions bottom sheet
- `/handwriting` -> handwriting instructions bottom sheet

The shell route watches:

```dart
showHelpOnceProvider(currentPath)
```

This provider uses `SharedPreferences` key:

```text
help_shown_<path>
```

On first visit to a supported route, it returns true and stores the flag so the sheet is shown only once.

Voice instructions are localized through `AppLocalizations`.

Handwriting instructions are currently hardcoded English strings in `lib/utils.dart`.

## 14. Localization

Files:

- `lib/l10n/app_en.arb`
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_ar.dart`

Supported locales:

- English
- Arabic

The app sets:

```dart
locale: ref.watch(localProvider)
```

Language is selected in settings by setting `localProvider`.

Current localization notes:

- Locale choice is not persisted after app restart.
- Some ARB content appears to contain mojibake/encoding artifacts in the working tree.
- Several screens still contain hardcoded English strings, especially auth, result, smart pen, and handwriting instructions.

## 15. Themes and UI System

File: `lib/themes/main_themes.dart`

Defined themes:

- `greenBackgroundTheme`
- `blueBackgroundTheme`
- `whiteBackgroundTheme`

The shell chooses a theme based on route. The app-level `MaterialApp.router` also sets the global font family to `Roboto`.

Custom icon font:

- `lib/icons/neurovive_icons.dart`
- Back arrow, close, microphone, info, and check icons are used across the app.

Reusable widgets include:

- `MicButton`: animated microphone button driven by amplitude stream
- `CircularLoadingIndicator`: custom segmented circular loading animation
- `AnimatedLoadingText`: animated upload text
- `GaugeWithCenterWidget`: AI result gauge wrapper
- `HorizontalEllipseGauge`: custom gauge painter

## 16. Platform Requirements

### Android

Android manifest permissions:

- `RECORD_AUDIO`
- `WRITE_EXTERNAL_STORAGE`
- `READ_EXTERNAL_STORAGE`
- `INTERNET`
- `BLUETOOTH_CONNECT`
- `BLUETOOTH`
- `BLUETOOTH_ADMIN`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`
- `BLUETOOTH_SCAN`

Android is the primary target for the full application because:

- Microphone recording is supported.
- Camera and OpenCV flow are mobile-oriented.
- BLE flow uses platform Bluetooth permissions.
- Smart-pen native library currently supports Android only.

### iOS

The iOS platform shell exists, but the smart-pen native library code explicitly supports Android only. Additional iOS permission descriptions may be required for camera, microphone, Bluetooth, and photo library use before production deployment.

### Web and Desktop

Flutter platform shells exist for web, Windows, macOS, and Linux, but the production feature set is mobile-focused. The complete smart-pen feature extraction flow requires Android because the native library is loaded as an Android `.so`.

## 17. Main Data Flow Summary

### Voice

```text
LandScreen
  -> RecordScreen2
  -> AudioRecorderService creates WAV
  -> SendVoiceScreen
  -> FileUploadNotifier
  -> Api.sendVoice
  -> POST /voice
  -> Response
  -> ResultScreen
```

### Handwriting

```text
LandScreen
  -> LiveShapeDetectionScreen
  -> Camera/gallery image
  -> OpenCV spiral validation
  -> 300x300 JPEG crop
  -> SendVoiceScreen
  -> FileUploadNotifier
  -> Api.sendImage
  -> POST /image
  -> Response
  -> ResultScreen
```

### Smart Pen

```text
LandScreen
  -> BluetoothConnectionPage
  -> BluetoothSensorService scans/connects/subscribes
  -> PacketParser parses 53-byte packets
  -> Recording session stores SensorPacket list
  -> PenRecordingData converts packets to signals
  -> SmartPenNotifier
  -> SmartPenService calls libSmartPen.so
  -> 354 features
  -> Api.sendPenFeatures
  -> POST /pen
  -> Response
  -> ResultScreen
```

### Auth

```text
LandingScreen
  -> SharedPreferences first_open=false
  -> AuthScreen
  -> AuthService sends login/register request
  -> SharedPreferences auth_logged_in=true
  -> LandScreen
```

## 18. Build and Run

Install dependencies:

```sh
flutter pub get
```

Run on a connected device or emulator:

```sh
flutter run
```

Run static analysis:

```sh
flutter analyze
```

For the complete smart-pen flow, use an Android device with:

- Bluetooth enabled
- Required Bluetooth permissions granted
- A compatible BLE smart pen sending 53-byte packets through a notifying characteristic
- `libSmartPen.so` available in the Android `jniLibs` folders
- Backend base URL available from the configured gist

## 19. Current Implementation Notes and Risks

These are not blockers for understanding the application, but they are important for maintenance.

### Auth Guard

Only the `/login` screen redirects logged-in users. The router does not globally prevent unauthenticated access to `/`, `/voice`, `/handwriting`, `/pen`, `/sendvoice`, or `/results`.

### Dynamic Backend URL

The app depends on a GitHub gist to resolve the backend base URL. If the gist is unavailable, malformed, or empty, API calls will fail.

### Result Screen Null Safety

`ResultScreen` force-unwraps `prediction` and `confidence`. Successful backend responses must include these fields.

### Localization Encoding

The ARB files in the current working tree show encoding artifacts for quotes and Arabic text. Generated localization output may reflect those artifacts.

### Hardcoded English Text

Several user-visible strings are not localized, especially in:

- `AuthScreen`
- `ResultScreen`
- `BluetoothConnectionPage`
- Handwriting instruction sheet
- Handwriting camera/gallery error messages

### Smart Pen Platform Limit

`SmartPenService.initialize()` throws on non-Android platforms. Production smart-pen feature extraction requires Android and the bundled native library.

### Smart Pen Coordinate Approximation

The current smart-pen packet data does not provide direct PMW3901 x/y channels. The app approximates x/y by integrating accelerometer values, which may not match final model expectations if the model was trained on true optical coordinates.

### BLE Characteristic Selection

The service subscribes to the first characteristic that supports notifications. If the device exposes multiple notify characteristics, the app may need service/characteristic UUID filtering.

### Resource Disposal

The audio recorder service closes its amplitude stream but has a TODO about timer cancellation. The recording timer in `RecordScreen2` is cancelled on dispose, but the service's internal periodic timer is managed by checking recording state.

## 20. Key Files Reference

| File | Responsibility |
| --- | --- |
| `lib/main.dart` | App bootstrap, router, shell, localization provider |
| `lib/app_constants.dart` | Runtime constants for production feature switches |
| `lib/utils.dart` | Back handling and instruction sheets |
| `lib/screens/landing/landing_screen.dart` | First-run landing screen |
| `lib/screens/auth_screen.dart` | Login/register screen |
| `lib/screens/settings_screen.dart` | Language and logout settings |
| `lib/screens/land_screen.dart` | Detection method selection |
| `lib/screens/record_screen2.dart` | Voice recording UI and timing flow |
| `lib/screens/handwriting_screen.dart` | Camera/gallery spiral detection and capture |
| `lib/screens/pen_screen.dart` | Smart-pen BLE and recording UI |
| `lib/screens/send_voice_screen.dart` | Shared upload screen for voice/image |
| `lib/screens/result_screen.dart` | Shared AI result report |
| `lib/services/audio_recorder.dart` | WAV recording and amplitude stream |
| `lib/services/api_config.dart` | Dynamic backend URL loading |
| `lib/services/api.dart` | Voice/image/pen API requests |
| `lib/services/auth_service.dart` | Authentication requests and logout |
| `lib/services/bluetooth_service.dart` | BLE scanning, connection, packet parsing, recording |
| `lib/services/smart_pen_service.dart` | Android FFI integration with smart-pen native library |
| `lib/notifiers/voice_upload_notifier.dart` | Shared upload state and response model |
| `lib/notifiers/smart_pen_notifier.dart` | Smart-pen feature extraction and upload state |
| `lib/l10n/app_en.arb` | English source strings |
| `lib/l10n/app_ar.arb` | Arabic source strings |
| `android/app/src/main/AndroidManifest.xml` | Android permissions and app metadata |
