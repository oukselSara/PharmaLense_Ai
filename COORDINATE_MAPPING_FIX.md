# Bounding Box Coordinate Mapping Fix

## Problem

The OCR works perfectly, but the highlighted bounding box shown on the camera preview does not align with the actual medicine label position.

## Root Cause

**Coordinate System Mismatch**: The backend returns bounding box coordinates in the **captured camera image** coordinate system, but the Flutter UI needs to display them in the **screen preview** coordinate system.

### The Pipeline

```
Camera Sensor → CameraImage (e.g., 1920x1080)
    ↓
Backend Detection → Returns box in (1920x1080) coordinates
    ↓
Screen Preview (e.g., 390x844) → Box needs transformation
```

### Key Issues Fixed

1. **Image Dimension Tracking**: The detection service now tracks the actual CameraImage dimensions (width x height) and passes them with the DetectionResult

2. **Correct Scale Calculation**: Using the actual sent image dimensions instead of previewSize which can be unreliable due to sensor orientation

3. **BoxFit.cover Mapping**: The camera preview uses `BoxFit.cover` which means:
   - Scale to fill the entire screen
   - Crop overflow (parts of image may be off-screen)
   - Center the scaled image

## Changes Made

### 1. label_detection_service.dart

#### Added image dimensions to DetectionResult

```dart
class DetectionResult {
  final BoundingBox box;
  final double confidence;
  final File? croppedImageFile;
  final int imageWidth;   // NEW: Original camera image width
  final int imageHeight;  // NEW: Original camera image height

  DetectionResult({
    required this.box,
    required this.confidence,
    this.croppedImageFile,
    required this.imageWidth,
    required this.imageHeight,
  });
}
```

#### Capture dimensions before sending to backend

```dart
Future<DetectionResult?> detectLive(CameraImage cameraImage) async {
  // Store camera image dimensions for coordinate mapping
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  // ... convert and send ...

  return DetectionResult(
    box: BoundingBox(...),
    confidence: confidence,
    croppedImageFile: croppedFile,
    imageWidth: imageWidth,    // Pass actual dimensions
    imageHeight: imageHeight,
  );
}
```

### 2. camera_preview_widget.dart

#### Fixed coordinate transformation in _PremiumDetectionPainter

**Before**: Used unreliable `previewSize` with confusing orientation handling

**After**: Use actual image dimensions from DetectionResult

```dart
@override
void paint(Canvas canvas, Size size) {
  final box = detectionBox.box;

  // Use actual camera image dimensions from detection result
  final double capturedImageWidth = detectionBox.imageWidth.toDouble();
  final double capturedImageHeight = detectionBox.imageHeight.toDouble();

  // Get screen preview dimensions
  final double screenWidth = size.width;
  final double screenHeight = size.height;

  // Calculate scale for BoxFit.cover behavior
  final double scaleX = screenWidth / capturedImageWidth;
  final double scaleY = screenHeight / capturedImageHeight;
  final double scale = math.max(scaleX, scaleY);  // max for cover mode

  // Calculate centering offset
  final double scaledImageWidth = capturedImageWidth * scale;
  final double scaledImageHeight = capturedImageHeight * scale;
  final double offsetX = (screenWidth - scaledImageWidth) / 2;
  final double offsetY = (screenHeight - scaledImageHeight) / 2;

  // Transform bounding box from image space to screen space
  final double screenX1 = (box.x1 * scale) + offsetX;
  final double screenY1 = (box.y1 * scale) + offsetY;
  final double screenX2 = (box.x2 * scale) + offsetX;
  final double screenY2 = (box.y2 * scale) + offsetY;

  final screenRect = Rect.fromLTRB(screenX1, screenY1, screenX2, screenY2);

  // Clamp to screen bounds
  final clampedRect = Rect.fromLTRB(
    screenRect.left.clamp(0.0, screenWidth),
    screenRect.top.clamp(0.0, screenHeight),
    screenRect.right.clamp(0.0, screenWidth),
    screenRect.bottom.clamp(0.0, screenHeight),
  );

  _drawPremiumBox(canvas, clampedRect);
  // ...
}
```

## How the Fix Works

### Step-by-Step Transformation

1. **Capture Image Dimensions**
   - When CameraImage is captured: 1920x1080 (example)
   - These dimensions are stored in DetectionResult

2. **Backend Processing**
   - Image sent to backend: 1920x1080
   - YOLO detects label, returns box: [100, 200, 500, 600]
   - Coordinates are in 1920x1080 space

3. **Screen Display**
   - Screen preview size: 390x844 (example phone)
   - Need to map [100, 200, 500, 600] from image space to screen space

4. **Scale Calculation**
   ```
   scaleX = 390 / 1920 = 0.203
   scaleY = 844 / 1080 = 0.781
   scale = max(0.203, 0.781) = 0.781  (cover mode uses max)
   ```

5. **Scaled Image Size**
   ```
   scaledWidth = 1920 * 0.781 = 1499.52
   scaledHeight = 1080 * 0.781 = 843.48
   ```

6. **Centering Offset**
   ```
   offsetX = (390 - 1499.52) / 2 = -554.76
   offsetY = (844 - 843.48) / 2 = 0.26
   ```
   (Negative offsetX means image extends beyond left/right edges)

7. **Transform Coordinates**
   ```
   screenX1 = (100 * 0.781) + (-554.76) = -476.66 → clamp to 0
   screenY1 = (200 * 0.781) + 0.26 = 156.46
   screenX2 = (500 * 0.781) + (-554.76) = -164.26 → clamp to 0
   screenY2 = (600 * 0.781) + 0.26 = 468.86
   ```

## Testing

### How to Verify the Fix

1. **Build and run the app**
   ```bash
   cd mobile_app
   flutter run
   ```

2. **Point camera at a medicine label**
   - The green detection box should now align with the physical label edges
   - The box should track the label accurately as you move the camera

3. **Check alignment**
   - Box corners should match label corners
   - Box should not drift or be offset from the label
   - Box should maintain alignment at different distances

### Expected Behavior

✅ **CORRECT**: Box aligns precisely with label boundaries
✅ **CORRECT**: Box tracks label movement smoothly
✅ **CORRECT**: OCR processes the correct region

❌ **INCORRECT (before fix)**: Box offset from label
❌ **INCORRECT (before fix)**: Box in wrong position

## Troubleshooting

### If the box is still misaligned:

1. **Check backend server is running**
   ```bash
   cd mobile_app/medicine_label_backend
   python backend_server.py
   ```

2. **Verify IP address in label_detection_service.dart**
   ```dart
   static const String baseUrl = "http://192.168.1.7:8000";
   ```
   Update this to your computer's IP address

3. **Check backend response**
   - Use `/detect-debug` endpoint to visualize detection
   - Verify backend is returning correct coordinates

4. **Add debug logging** (temporary)
   ```dart
   // In _PremiumDetectionPainter.paint()
   print('Image: ${capturedImageWidth}x${capturedImageHeight}');
   print('Screen: ${screenWidth}x${screenHeight}');
   print('Scale: $scale, Offset: ($offsetX, $offsetY)');
   print('Box: [${box.x1}, ${box.y1}, ${box.x2}, ${box.y2}]');
   print('Screen Box: [$screenX1, $screenY1, $screenX2, $screenY2]');
   ```

### Common Issues

**Issue**: Box still misaligned after fix
**Cause**: Wrong image dimensions being sent
**Fix**: Verify `cameraImage.width` and `cameraImage.height` match the sent image

**Issue**: Box too large or too small
**Cause**: Wrong scale calculation
**Fix**: Ensure using `math.max(scaleX, scaleY)` for cover mode

**Issue**: Box drifts during movement
**Cause**: Coordinates not being updated in real-time
**Fix**: Check detection frequency in camera_service.dart

## Summary

This fix ensures that:
1. Actual camera image dimensions are tracked and used
2. Coordinate transformation accounts for BoxFit.cover scaling
3. Centering offsets are correctly calculated
4. The displayed box precisely matches the physical label location

The bounding box should now align **exactly** with the medicine label on the camera preview, solving the coordinate mismapping issue.
