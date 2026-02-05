# Technical Documentation - Medicine Label Scanner

## Architecture Overview

### Design Pattern: Provider + Service Layer

```
┌─────────────────────────────────────────────┐
│              Presentation Layer              │
│  ┌─────────────┐      ┌──────────────────┐  │
│  │   Camera    │      │  Confirmation    │  │
│  │   Screen    │─────▶│     Screen       │  │
│  └─────────────┘      └──────────────────┘  │
│         │                      │             │
│         └──────────┬───────────┘             │
└────────────────────│─────────────────────────┘
                     │ Provider (State Management)
┌────────────────────│─────────────────────────┐
│              Service Layer                    │
│  ┌──────────────────────────────────────┐    │
│  │       CameraService                   │    │
│  │  - Camera initialization              │    │
│  │  - Frame capture & streaming          │    │
│  │  - Scan orchestration                 │    │
│  └──────────────────┬───────────────────┘    │
│                     │                         │
│  ┌──────────────────▼───────────────────┐    │
│  │       OcrService                      │    │
│  │  - Image preprocessing                │    │
│  │  - ML Kit integration                 │    │
│  │  - Text extraction & filtering        │    │
│  └───────────────────────────────────────┘    │
└───────────────────────────────────────────────┘
```

## Component Details

### 1. CameraService

**Responsibilities:**
- Manage camera lifecycle (initialize, pause, resume, dispose)
- Handle camera permissions
- Coordinate continuous scanning
- Process frames at regular intervals
- Orchestrate the scanning workflow

**Key Methods:**
```dart
Future<bool> initialize()           // Setup camera with permissions
void startScanning(callback)        // Begin continuous frame processing
void stopScanning()                 // Halt scanning
void pause() / resume()             // Handle app lifecycle
```

**State Management:**
- Uses `ChangeNotifier` to notify UI of state changes
- Tracks: initialization status, scanning status, status messages
- Provider pattern ensures single instance across app

**Frame Processing Strategy:**
```dart
Timer → Every 500ms → Capture Frame → Process with OCR → 
  If text found → Stop scanning → Callback → Navigate
  If no text → Continue scanning
```

### 2. OcrService

**Responsibilities:**
- Convert camera frames to ML Kit compatible format
- Execute text recognition
- Filter and validate detected text
- Extract structured text from recognition results

**Key Methods:**
```dart
Future<ScannedLabel?> processImage(CameraImage)  // Main OCR pipeline
InputImage? _convertCameraImage(CameraImage)     // Format conversion
String _extractTextFromBlocks(RecognizedText)    // Text extraction
Future<bool> hasDetectableText(CameraImage)      // Quick detection
```

**Image Processing Pipeline:**
```
CameraImage (YUV420/NV21)
    ↓
Convert to InputImage format
    ↓
ML Kit Text Recognition
    ↓
Filter small/noise blocks
    ↓
Extract text with formatting
    ↓
Return ScannedLabel model
```

### 3. Camera Screen Flow

**Lifecycle:**
```
App Launch
    ↓
Request Permissions → Initialize Camera → Start Preview
    ↓
Auto-start Scanning
    ↓
[Continuous Loop: Capture → Process → Check]
    ↓
Text Detected → Navigate to Confirmation
    ↓
User Decision:
  - Confirm → Return to Camera → Resume Scanning
  - Retry → Return to Camera → Resume Scanning
```

**State Handling:**
```dart
_isInitializing     // Show loading UI
_cameraService.isInitialized  // Enable camera preview
_cameraService.isScanning     // Show scanning indicator
```

### 4. Confirmation Screen

**Purpose:**
- Display extracted text for user review
- Provide confirm/retry actions
- Enable text copying
- Smooth transition back to camera

**User Actions:**
```
View Text → Decision Point
    ├─ Confirm → Save → Return to scanning
    └─ Retry → Discard → Return to scanning
```

## Data Flow

### Complete Scan Cycle

```
1. User opens app
   └─▶ CameraService.initialize()
       └─▶ Request permissions
       └─▶ Setup camera controller
       └─▶ Notify UI (Provider)

2. Camera ready
   └─▶ Auto-start scanning
       └─▶ Timer fires every 500ms
           └─▶ Capture frame
           └─▶ OcrService.processImage()
               └─▶ Convert CameraImage
               └─▶ ML Kit recognition
               └─▶ Extract & filter text
               
3. Text detected
   └─▶ Stop scanning
   └─▶ Create ScannedLabel model
   └─▶ Callback to CameraScreen
   └─▶ Navigate to ConfirmationScreen

4. User confirms
   └─▶ Pop navigation
   └─▶ Show success snackbar
   └─▶ Delay 500ms
   └─▶ Resume scanning (back to step 2)

5. User retries
   └─▶ Pop navigation
   └─▶ Resume scanning immediately (back to step 2)
```

## Performance Considerations

### 1. Frame Processing Throttling

**Problem:** Processing every camera frame (30-60 fps) would overwhelm the device

**Solution:** 
```dart
static const Duration _scanInterval = Duration(milliseconds: 500);
// Process at 2 fps instead of 30-60 fps
```

**Tuning:**
- Faster (300ms): More responsive but higher CPU usage
- Slower (800ms): Better battery but less responsive

### 2. Resolution Management

```dart
ResolutionPreset.medium  // Balance between quality and performance
```

**Options:**
- `low`: 320x240 - Faster but may miss small text
- `medium`: 720x480 - Good balance (recommended)
- `high`: 1280x720 - Better accuracy but slower

### 3. Async Processing

```dart
// OCR runs on separate isolate automatically via ML Kit
final recognizedText = await _textRecognizer.processImage(inputImage);
```

**Benefits:**
- UI remains responsive during OCR
- No frame dropping in camera preview
- Smooth animations

### 4. Resource Management

```dart
@override
void dispose() {
  _scanTimer?.cancel();           // Stop timer
  _cameraController?.dispose();   // Release camera
  _ocrService.dispose();          // Close ML Kit
  super.dispose();
}
```

**Critical:** Always dispose resources to prevent memory leaks

## ML Kit Integration

### Why Google ML Kit?

**Advantages:**
1. **On-Device:** No internet required, instant results
2. **Optimized:** Designed for mobile processors
3. **Free:** No API costs or quotas
4. **Privacy:** Data never leaves device
5. **Accurate:** High quality text recognition

### Text Recognition Configuration

```dart
TextRecognizer(script: TextRecognitionScript.latin)
```

**Available Scripts:**
- `latin`: English, European languages (default)
- `chinese`: Simplified & Traditional Chinese
- `devanagari`: Hindi, Sanskrit, etc.
- `japanese`: Japanese
- `korean`: Korean

### Detection Quality Filters

```dart
// Filter out noise and small artifacts
if (block.boundingBox.width < 20 || block.boundingBox.height < 10) {
  continue;  // Skip tiny detections
}

// Only process if substantial text found
if (extractedText.trim().length > 5) {
  return ScannedLabel(...);
}
```

## Error Handling

### Permission Denied
```dart
final permissionStatus = await Permission.camera.request();
if (!permissionStatus.isGranted) {
  _updateStatus('Camera permission denied');
  // Show dialog to user
}
```

### Camera Initialization Failure
```dart
try {
  await _cameraController!.initialize();
} catch (e) {
  _updateStatus('Camera initialization failed: $e');
  // Show retry dialog
}
```

### OCR Processing Error
```dart
try {
  final recognizedText = await _textRecognizer.processImage(inputImage);
} catch (e) {
  print('Error processing image: $e');
  return null;  // Continue scanning
}
```

### Navigation Safety
```dart
Future.delayed(const Duration(milliseconds: 500), () {
  if (mounted) {  // Check widget is still in tree
    _startScanning();
  }
});
```

## Testing Strategy

### Unit Tests
```dart
test('ScannedLabel validates text length', () {
  final label = ScannedLabel(text: 'Hi', timestamp: DateTime.now());
  expect(label.hasValidText, false);  // Too short
});
```

### Widget Tests
```dart
testWidgets('Camera screen shows loading initially', (tester) async {
  await tester.pumpWidget(MyApp());
  expect(find.text('Initializing camera...'), findsOneWidget);
});
```

### Integration Tests
```dart
testWidgets('Full scan cycle', (tester) async {
  // 1. Launch app
  // 2. Grant permissions
  // 3. Wait for camera
  // 4. Trigger detection
  // 5. Verify confirmation screen
  // 6. Tap confirm
  // 7. Verify back at camera
});
```

## Common Issues & Solutions

### Issue: Camera doesn't start
**Causes:**
- Permissions not granted
- Camera already in use by another app
- Invalid resolution preset

**Solutions:**
- Check AndroidManifest.xml permissions
- Close other camera apps
- Try different resolution preset

### Issue: OCR not detecting text
**Causes:**
- Poor lighting
- Blurry image (motion/focus)
- Text too small
- Wrong language script

**Solutions:**
- Improve lighting conditions
- Hold device steady
- Move closer to label
- Use correct TextRecognitionScript

### Issue: App crashes on navigation
**Causes:**
- Widget disposed during async operation
- Camera not properly disposed

**Solutions:**
- Check `mounted` before state updates
- Always dispose resources in dispose()
- Use `if (mounted)` guards

### Issue: Poor performance
**Causes:**
- Processing too frequently
- Resolution too high
- Multiple services running

**Solutions:**
- Increase scan interval
- Lower resolution preset
- Profile with DevTools
- Test on physical device

## Extending the App

### Add History Storage
```dart
class HistoryService {
  final List<ScannedLabel> _history = [];
  
  void addScan(ScannedLabel label) {
    _history.add(label);
    // Persist to local database (SQLite, Hive, etc.)
  }
}
```

### Add Barcode Scanning
```dart
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeService {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  
  Future<String?> scanBarcode(InputImage image) async {
    final barcodes = await _barcodeScanner.processImage(image);
    return barcodes.firstOrNull?.rawValue;
  }
}
```

### Add Image Enhancement
```dart
import 'package:image/image.dart' as img;

img.Image enhanceImage(img.Image image) {
  image = img.adjustColor(image, contrast: 1.2);
  image = img.grayscale(image);
  return image;
}
```

### Add Export Functionality
```dart
Future<void> exportToCSV(List<ScannedLabel> labels) async {
  final csv = labels.map((l) => 
    '${l.timestamp},${l.text.replaceAll(',', ';')}'
  ).join('\n');
  
  // Save to file using path_provider
}
```

## Security Considerations

### Permission Handling
- Request only required permissions
- Explain why permission is needed
- Handle denial gracefully
- Test on Android 6.0+ (runtime permissions)

### Data Privacy
- All processing is on-device
- No data sent to servers
- No analytics or tracking
- User controls all data

### Secure Storage
```dart
// If storing sensitive medical data:
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
await storage.write(key: 'scan', value: sensitiveText);
```

## Deployment Checklist

- [ ] Update `minSdkVersion` to 21 in build.gradle
- [ ] Add camera permissions to AndroidManifest.xml
- [ ] Test on multiple Android versions (6.0+)
- [ ] Test on different device sizes
- [ ] Test in low light conditions
- [ ] Test with various medicine labels
- [ ] Verify memory usage (no leaks)
- [ ] Test app lifecycle (pause/resume)
- [ ] Test permission denial scenarios
- [ ] Create app icon
- [ ] Update app name and package ID
- [ ] Build release APK
- [ ] Test release build thoroughly

## Performance Benchmarks

**Typical Performance (mid-range device):**
- Cold start: 2-3 seconds
- Camera initialization: 1-2 seconds
- Frame processing: 100-300ms per frame
- OCR processing: 200-500ms
- Memory usage: 150-250 MB
- Battery impact: Moderate (camera usage)

**Optimization Targets:**
- Keep frame rate at 2-3 fps for scanning
- OCR processing under 500ms
- Memory under 300 MB
- Smooth 60fps UI animations

## Conclusion

This architecture provides:
- ✅ Clean separation of concerns
- ✅ Efficient resource management
- ✅ Scalable and maintainable code
- ✅ Excellent performance
- ✅ Great user experience
- ✅ Easy to extend and customize
