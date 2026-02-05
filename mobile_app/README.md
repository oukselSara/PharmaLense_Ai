# Medicine Label Scanner - Flutter App

A Flutter mobile application that continuously scans medicine box labels using the device camera and extracts text using OCR.

## Features

- **Continuous Camera Preview**: Real-time camera feed for label detection
- **Automatic Label Detection**: Uses Google ML Kit to detect text regions
- **OCR Text Extraction**: Extracts text from detected labels
- **Confirmation Flow**: User can review and confirm extracted text
- **Seamless Loop**: Automatically returns to scanning after confirmation

## Architecture

```
lib/
├── main.dart                    # App entry point
├── screens/
│   ├── camera_screen.dart       # Main scanning screen
│   └── confirmation_screen.dart # Text confirmation screen
├── services/
│   ├── camera_service.dart      # Camera handling logic
│   └── ocr_service.dart         # OCR processing logic
├── models/
│   └── scanned_label.dart       # Data model
└── widgets/
    ├── camera_preview_widget.dart
    └── detection_overlay.dart
```

## OCR Library Choice: Google ML Kit

**Why Google ML Kit (`google_mlkit_text_recognition`)?**

1. **On-Device Processing**: Works offline, fast processing
2. **Free**: No API costs or usage limits
3. **Optimized for Mobile**: Designed specifically for Flutter/mobile
4. **High Accuracy**: Excellent text recognition for printed labels
5. **Active Maintenance**: Well-supported by Google
6. **Easy Integration**: Simple Flutter plugin with good documentation

**Alternatives Considered:**
- **Tesseract OCR**: Larger model size, slower on mobile
- **Firebase ML Vision**: Deprecated in favor of ML Kit
- **Cloud Vision API**: Requires internet, has costs

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.5+5           # Camera access and preview
  google_mlkit_text_recognition: ^0.11.0  # OCR engine
  permission_handler: ^11.0.1  # Camera permissions
  provider: ^6.1.1             # State management
```

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (3.0 or higher)
- Android Studio or VS Code with Flutter plugins
- Android device or emulator (API level 21+)

### 2. Installation

```bash
# Clone or create project
flutter create medicine_label_scanner
cd medicine_label_scanner

# Copy the provided source files to lib/

# Get dependencies
flutter pub get
```

### 3. Android Configuration

**android/app/src/main/AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

**android/app/build.gradle:**
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // ML Kit requirement
    }
}
```

### 4. Run the App

```bash
# Check connected devices
flutter devices

# Run on connected device
flutter run

# Run in release mode for better performance
flutter run --release
```

## How It Works

### 1. Camera Initialization
- Requests camera permission on app start
- Initializes back camera with medium resolution
- Starts continuous preview stream

### 2. Text Detection
- Processes camera frames at intervals (every 500ms)
- Uses ML Kit to detect text regions in the frame
- Filters out small or low-confidence detections

### 3. OCR Processing
- When significant text is detected, captures the frame
- Processes the image through ML Kit OCR
- Extracts all text blocks with bounding boxes

### 4. User Confirmation
- Displays extracted text to user
- User can confirm (proceed) or reject (retry)
- On confirmation, returns to camera screen

### 5. Continuous Loop
- Camera remains initialized between scans
- No restart required
- Seamless transition back to scanning mode

## Performance Optimization

- **Frame Throttling**: Processes every 500ms instead of every frame
- **Resolution Control**: Uses medium resolution for balance
- **Async Processing**: OCR runs on separate isolate
- **Resource Management**: Properly disposes camera when not needed

## UI/UX Design

### Camera Screen
- Full-screen camera preview
- Semi-transparent overlay showing detection status
- Scanning indicator when processing
- Clear visual feedback

### Confirmation Screen
- Clean, readable text display
- Prominent confirm/retry buttons
- Medicine box icon for context
- Smooth transitions

## Troubleshooting

**Camera not working:**
- Ensure permissions are granted in device settings
- Check AndroidManifest.xml has camera permissions

**OCR not detecting text:**
- Ensure good lighting conditions
- Hold camera steady and close enough
- Make sure text is in focus
- Try adjusting detection threshold in camera_service.dart

**Performance issues:**
- Increase frame processing interval
- Reduce camera resolution
- Test on physical device (emulator is slower)

## Future Enhancements

- [ ] Save scan history to local database
- [ ] Support for barcode scanning
- [ ] Multi-language OCR support
- [ ] Export scanned data to CSV/PDF
- [ ] Image preprocessing for better accuracy
- [ ] Flashlight toggle for low-light conditions

## License

MIT License - Feel free to use and modify for your projects.
