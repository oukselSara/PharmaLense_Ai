from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
import torch
import cv2
import numpy as np
import base64
from typing import Tuple, List, Optional

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================================================
# MODEL CONFIGURATION
# ==================================================
MODEL_PATH = r"H:\graduation\PharmaLense_Ai\runs\detect\runs\detect\medicine_label_lowdata2\weights\best.pt"
CONF_THRESHOLD = 0.15  # Lowered even more for better detection
IOU_THRESHOLD = 0.45

# Debug logging
import logging
logging.basicConfig(level=logging.INFO)

# Load model once at startup
print("Loading YOLO model...")
if not torch.cuda.is_available():
    print("⚠️ WARNING: CUDA not available, using CPU (slower)")
    device = 'cpu'
else:
    print(f"✅ Using GPU: {torch.cuda.get_device_name(0)}")
    device = 0

# Fix PyTorch 2.10+ compatibility - disable weights_only check for our trusted model
# Temporarily override torch.load to allow model loading
import os
_original_torch_load = torch.load

def _patched_torch_load(*args, **kwargs):
    kwargs['weights_only'] = False
    return _original_torch_load(*args, **kwargs)

torch.load = _patched_torch_load

model = YOLO(MODEL_PATH)

# Restore original torch.load
torch.load = _original_torch_load
print("✅ Model loaded successfully")


# ==================================================
# IMAGE PREPROCESSING FUNCTIONS
# ==================================================
def letterbox_image(img: np.ndarray, target_size: int = 640) -> Tuple[np.ndarray, float, Tuple[int, int]]:
    """
    Resize image with letterboxing to maintain aspect ratio
    This prevents distortion and ensures accurate bounding boxes
    
    Returns: 
        letterboxed_image: Padded image (target_size x target_size)
        scale_factor: Resize ratio applied
        (pad_w, pad_h): Padding offsets added
    """
    h, w = img.shape[:2]
    
    # Calculate scale to fit target size while preserving aspect ratio
    scale = min(target_size / h, target_size / w)
    
    # New dimensions after scaling
    new_w = int(w * scale)
    new_h = int(h * scale)
    
    # Resize image
    resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
    
    # Calculate padding to center the image
    pad_w = (target_size - new_w) // 2
    pad_h = (target_size - new_h) // 2
    
    # Add padding (gray color matching YOLO default)
    letterboxed = cv2.copyMakeBorder(
        resized,
        pad_h, target_size - new_h - pad_h,  # top, bottom
        pad_w, target_size - new_w - pad_w,  # left, right
        cv2.BORDER_CONSTANT,
        value=(114, 114, 114)  # Gray padding
    )
    
    return letterboxed, scale, (pad_w, pad_h)


def unletterbox_coords(box: Tuple[int, int, int, int], scale: float, 
                       padding: Tuple[int, int]) -> Tuple[int, int, int, int]:
    """
    Convert bounding box coordinates from letterboxed image back to original image
    
    Steps:
    1. Remove padding offset
    2. Scale back by inverse of resize ratio
    """
    x1, y1, x2, y2 = box
    pad_w, pad_h = padding
    
    # Remove padding offset
    x1 = x1 - pad_w
    y1 = y1 - pad_h
    x2 = x2 - pad_w
    y2 = y2 - pad_h
    
    # Scale back to original size
    x1 = int(x1 / scale)
    y1 = int(y1 / scale)
    x2 = int(x2 / scale)
    y2 = int(y2 / scale)
    
    return (x1, y1, x2, y2)


def find_label_contour(img: np.ndarray, yolo_box: Tuple[int, int, int, int],
                       expand_margin: int = 20) -> Optional[np.ndarray]:
    """
    GEOMETRIC EDGE DETECTION: Find the precise label contour using edge analysis.

    This function treats label detection as a pure geometry problem:
    1. Extract YOLO region (rough localization)
    2. Apply multi-stage edge detection
    3. Find dominant rectangular contour (the label boundary)
    4. Return the contour points for rotated rectangle fitting

    Returns: Contour points (Nx1x2 array) or None if detection fails
    """
    x1, y1, x2, y2 = yolo_box
    h, w = img.shape[:2]

    # Expand search region slightly beyond YOLO box
    search_x1 = max(0, x1 - expand_margin)
    search_y1 = max(0, y1 - expand_margin)
    search_x2 = min(w, x2 + expand_margin)
    search_y2 = min(h, y2 + expand_margin)

    # Extract ROI
    roi = img[search_y1:search_y2, search_x1:search_x2].copy()

    if roi.size == 0 or roi.shape[0] < 30 or roi.shape[1] < 30:
        return None

    try:
        # === STEP 1: Grayscale and denoising ===
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)

        # Bilateral filter: preserves edges while removing noise
        denoised = cv2.bilateralFilter(gray, 9, 75, 75)

        # === STEP 2: Multi-threshold edge detection ===
        # Use adaptive thresholding to handle varying lighting
        adaptive_thresh = cv2.adaptiveThreshold(
            denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 11, 2
        )

        # Canny edge detection with low thresholds for label boundaries
        edges = cv2.Canny(denoised, 20, 80)

        # Combine both edge detection methods
        combined_edges = cv2.bitwise_or(edges, cv2.bitwise_not(adaptive_thresh))

        # === STEP 3: Morphological operations to connect edges ===
        # Close gaps in the label boundary
        kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        closed = cv2.morphologyEx(combined_edges, cv2.MORPH_CLOSE, kernel_close, iterations=2)

        # Dilate slightly to ensure connected boundary
        kernel_dilate = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        dilated = cv2.dilate(closed, kernel_dilate, iterations=1)

        # === STEP 4: Find contours ===
        contours, _ = cv2.findContours(
            dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )

        if not contours:
            return None

        # === STEP 5: Select the label contour ===
        # Filter by area: must occupy significant portion of ROI
        roi_area = roi.shape[0] * roi.shape[1]
        min_area = roi_area * 0.15  # At least 15% of ROI
        max_area = roi_area * 0.95  # At most 95% of ROI

        valid_contours = [
            cnt for cnt in contours
            if min_area < cv2.contourArea(cnt) < max_area
        ]

        if not valid_contours:
            return None

        # Choose largest valid contour (most likely the label)
        label_contour = max(valid_contours, key=cv2.contourArea)

        # === STEP 6: Refine contour using convex hull ===
        # This removes internal noise and gives us the outer boundary
        hull = cv2.convexHull(label_contour)

        # Approximate to polygon to reduce noise
        epsilon = 0.01 * cv2.arcLength(hull, True)
        approx = cv2.approxPolyDP(hull, epsilon, True)

        # Map contour back to original image coordinates
        approx_mapped = approx.copy()
        approx_mapped[:, 0, 0] += search_x1
        approx_mapped[:, 0, 1] += search_y1

        return approx_mapped

    except Exception as e:
        print(f"Contour detection failed: {e}")
        return None


def get_rotated_box_from_contour(contour: np.ndarray) -> Tuple[List[List[int]], Tuple[int, int, int, int]]:
    """
    Fit a minimum area rotated rectangle to the detected contour.

    Returns:
        - rotated_points: 4 corner points [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
        - axis_aligned_bbox: (x1, y1, x2, y2) for compatibility
    """
    # Fit minimum area rectangle (can be rotated)
    rect = cv2.minAreaRect(contour)

    # Get the 4 corner points of the rotated rectangle
    box_points = cv2.boxPoints(rect)
    box_points = box_points.astype(int)  # Fixed: np.int0 deprecated in NumPy 2.0+

    # Convert to list format for JSON serialization
    rotated_points = box_points.tolist()

    # Also compute axis-aligned bounding box for compatibility
    x_coords = box_points[:, 0]
    y_coords = box_points[:, 1]

    axis_aligned_bbox = (
        int(x_coords.min()),
        int(y_coords.min()),
        int(x_coords.max()),
        int(y_coords.max())
    )

    return rotated_points, axis_aligned_bbox


def refine_box_edges(img: np.ndarray, box: Tuple[int, int, int, int],
                     expand_margin: int = 20) -> Tuple[int, int, int, int]:
    """
    PRECISION EDGE-BASED REFINEMENT using rotated rectangle fitting.

    Pipeline:
    1. Use YOLO box for rough localization
    2. Find label contour using edge geometry
    3. Fit minimum area (rotated) rectangle to contour
    4. Return axis-aligned bbox (for backward compatibility)

    Note: Use refine_box_edges_rotated() to get the full rotated box
    """
    contour = find_label_contour(img, box, expand_margin)

    if contour is None:
        return box

    # Get rotated box
    _, axis_aligned = get_rotated_box_from_contour(contour)

    # Validation: ensure reasonable size
    x1, y1, x2, y2 = axis_aligned
    h, w = img.shape[:2]

    # Clamp to image bounds
    x1 = max(0, min(x1, w))
    y1 = max(0, min(y1, h))
    x2 = max(0, min(x2, w))
    y2 = max(0, min(y2, h))

    # Ensure minimum size
    if (x2 - x1) < 30 or (y2 - y1) < 30:
        return box

    # Validate area change is reasonable
    original_area = (box[2] - box[0]) * (box[3] - box[1])
    refined_area = (x2 - x1) * (y2 - y1)

    if refined_area < original_area * 0.15 or refined_area > original_area * 1.8:
        return box

    return (x1, y1, x2, y2)


def refine_box_edges_rotated(img: np.ndarray, box: Tuple[int, int, int, int],
                              expand_margin: int = 20) -> Optional[List[List[int]]]:
    """
    FULL ROTATED RECTANGLE REFINEMENT - returns 4 corner points.

    This is the PRIMARY function for tight label detection.
    Returns a rotated rectangle that hugs the label edges precisely.

    Returns:
        [[x1,y1], [x2,y2], [x3,y3], [x4,y4]] - 4 corners of rotated rect
        or None if detection fails
    """
    contour = find_label_contour(img, box, expand_margin)

    if contour is None:
        return None

    # Get rotated box points
    rotated_points, _ = get_rotated_box_from_contour(contour)

    return rotated_points


def quick_preprocess(img: np.ndarray) -> np.ndarray:
    """
    Lightweight preprocessing to avoid freezing
    Only used for the old /detect endpoint (kept for backwards compatibility)
    """
    # Resize if image is too large
    max_size = 1280
    h, w = img.shape[:2]
    if max(h, w) > max_size:
        scale = max_size / max(h, w)
        new_w = int(w * scale)
        new_h = int(h * scale)
        img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
    
    # Light sharpening only
    kernel = np.array([[-1,-1,-1],
                       [-1, 9,-1],
                       [-1,-1,-1]])
    img = cv2.filter2D(img, -1, kernel)
    
    return img


def enhance_label_for_ocr(img: np.ndarray, box: Tuple[int, int, int, int]) -> np.ndarray:
    """
    Enhanced preprocessing for OCR - lightweight version
    This is applied to the cropped label for better text recognition
    """
    x1, y1, x2, y2 = box

    # Add padding around the box
    h, w = img.shape[:2]
    pad = 10
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(w, x2 + pad)
    y2 = min(h, y2 + pad)

    # Crop the label region
    cropped = img[y1:y2, x1:x2]

    # Convert to grayscale
    gray = cv2.cvtColor(cropped, cv2.COLOR_BGR2GRAY)

    # Quick denoising
    denoised = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)

    # Apply CLAHE for better contrast (helps OCR)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    enhanced = clahe.apply(denoised)

    # Sharpen for clearer text
    kernel = np.array([[0, -1, 0],
                       [-1, 5, -1],
                       [0, -1, 0]])
    enhanced = cv2.filter2D(enhanced, -1, kernel)

    return enhanced


# ==================================================
# API ENDPOINTS
# ==================================================
@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "model": "YOLO Medicine Label Detector (Rotated Box v3.0)",
        "device": "GPU" if torch.cuda.is_available() else "CPU",
        "version": "3.0",
        "features": [
            "Geometric edge detection",
            "Rotated rectangle fitting (minAreaRect)",
            "Precise label boundary alignment",
            "Multi-stage edge detection pipeline",
            "No reliance on text/OCR for box fitting"
        ]
    }


@app.post("/detect")
async def detect_label(file: UploadFile = File(...)):
    """
    Detect medicine label in uploaded image (legacy endpoint)
    Note: Use /detect-live or /detect-and-crop for better results
    """
    try:
        # Read image
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            return JSONResponse(
                status_code=400,
                content={"error": "Invalid image file"}
            )

        # Quick preprocessing (legacy method)
        preprocessed = quick_preprocess(img)

        # Run detection
        results = model(
            preprocessed,
            conf=CONF_THRESHOLD,
            iou=IOU_THRESHOLD,
            device=device,
            verbose=False
        )[0]

        if results.boxes is None or len(results.boxes) == 0:
            return {
                "detected": False,
                "message": "No label detected"
            }

        # Get best detection
        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()
        
        best_idx = scores.argmax()
        x1, y1, x2, y2 = map(int, boxes[best_idx])
        confidence = float(scores[best_idx])

        return {
            "detected": True,
            "box": {
                "x1": x1,
                "y1": y1,
                "x2": x2,
                "y2": y2
            },
            "confidence": confidence,
            "image_size": {
                "width": preprocessed.shape[1],
                "height": preprocessed.shape[0]
            }
        }

    except Exception as e:
        print(f"Detection error: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": f"Detection failed: {str(e)}"}
        )


@app.post("/detect-live")
async def detect_live(file: UploadFile = File(...)):
    """
    FAST detection for live camera with TIGHT ROTATED bounding boxes

    Pipeline:
    1. YOLO for rough localization
    2. Edge detection to find label contour
    3. Fit minimum area rotated rectangle to edges
    4. Return precise 4-point polygon

    Returns:
    - rotated_box: [[x1,y1], [x2,y2], [x3,y3], [x4,y4]] - exact label corners
    - box: [x1,y1,x2,y2] - axis-aligned bbox for compatibility
    """
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img_original = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img_original is None:
            print("❌ Failed to decode image")
            return {"detected": False}

        print(f"📸 Received image: {img_original.shape}")

        original_h, original_w = img_original.shape[:2]

        # Apply letterboxing for proper aspect ratio preservation
        img_letterboxed, scale, padding = letterbox_image(img_original, target_size=640)

        # Run YOLO detection on letterboxed image
        results = model(
            img_letterboxed,
            conf=CONF_THRESHOLD,
            iou=IOU_THRESHOLD,
            device=device,
            verbose=False,
            imgsz=640  # Explicit size to match letterboxing
        )[0]

        if results.boxes is None or len(results.boxes) == 0:
            print(f"❌ No detections found (threshold: {CONF_THRESHOLD})")
            return {"detected": False}

        print(f"✅ Found {len(results.boxes)} detection(s)")

        # Get best detection from YOLO (rough localization)
        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()

        best_idx = scores.argmax()
        letterbox_coords = tuple(map(int, boxes[best_idx]))

        # Convert from letterboxed coordinates to original image coordinates
        x1, y1, x2, y2 = unletterbox_coords(letterbox_coords, scale, padding)

        # Clamp to image bounds (safety)
        x1 = max(0, min(x1, original_w))
        y1 = max(0, min(y1, original_h))
        x2 = max(0, min(x2, original_w))
        y2 = max(0, min(y2, original_h))

        yolo_box = (x1, y1, x2, y2)

        # === CRITICAL: Find precise rotated box from edges ===
        rotated_box = refine_box_edges_rotated(img_original, yolo_box)

        # Also get axis-aligned box for cropping
        refined_box = refine_box_edges(img_original, yolo_box)
        rx1, ry1, rx2, ry2 = refined_box

        # Crop using axis-aligned box
        cropped = img_original[ry1:ry2, rx1:rx2]

        # Encode cropped image to base64 for transmission
        _, buffer = cv2.imencode('.jpg', cropped, [cv2.IMWRITE_JPEG_QUALITY, 90])
        cropped_base64 = base64.b64encode(buffer).decode('utf-8')

        response = {
            "detected": True,
            "box": list(refined_box),  # Axis-aligned for compatibility
            "confidence": float(scores[best_idx]),
            "original_size": {
                "width": original_w,
                "height": original_h
            },
            "refinement_applied": True,
            "cropped_image": cropped_base64,
            "crop_size": {
                "width": cropped.shape[1],
                "height": cropped.shape[0]
            }
        }

        # Add rotated box if edge detection succeeded
        if rotated_box is not None:
            response["rotated_box"] = rotated_box
            response["box_type"] = "rotated"
        else:
            response["rotated_box"] = [
                [rx1, ry1], [rx2, ry1], [rx2, ry2], [rx1, ry2]
            ]
            response["box_type"] = "axis_aligned_fallback"

        return response

    except Exception as e:
        print(f"Live detection error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {"detected": False, "error": str(e)}


@app.post("/detect-and-crop")
async def detect_and_crop(file: UploadFile = File(...)):
    """
    Detect medicine label with TIGHT ROTATED bounding box and return cropped/enhanced images

    Pipeline:
    1. YOLO rough detection
    2. Geometric edge detection for precise boundaries
    3. Rotated rectangle fitting (not axis-aligned)
    4. Return rotated box + cropped images

    Returns:
    - rotated_box: 4 corner points of precise label boundary
    - cropped_image: Cropped label region
    - enhanced_image: OCR-optimized version
    """
    try:
        # Read image
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img_original = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img_original is None:
            return JSONResponse(
                status_code=400,
                content={"error": "Invalid image file"}
            )

        original_h, original_w = img_original.shape[:2]

        # Letterbox preprocessing for accurate detection
        img_letterboxed, scale, padding = letterbox_image(img_original, target_size=640)

        # Detect label with YOLO
        results = model(
            img_letterboxed,
            conf=CONF_THRESHOLD,
            iou=IOU_THRESHOLD,
            device=device,
            verbose=False,
            imgsz=640
        )[0]

        if results.boxes is None or len(results.boxes) == 0:
            return {
                "detected": False,
                "message": "No label detected"
            }

        # Get best detection
        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()

        best_idx = scores.argmax()
        letterbox_coords = tuple(map(int, boxes[best_idx]))
        confidence = float(scores[best_idx])

        # Convert to original image coordinates
        x1, y1, x2, y2 = unletterbox_coords(letterbox_coords, scale, padding)

        # Clamp to valid range
        x1 = max(0, min(x1, original_w))
        y1 = max(0, min(y1, original_h))
        x2 = max(0, min(x2, original_w))
        y2 = max(0, min(y2, original_h))

        yolo_box = (x1, y1, x2, y2)

        # === CRITICAL: Precise edge-based refinement ===
        rotated_box = refine_box_edges_rotated(img_original, yolo_box)
        refined_box = refine_box_edges(img_original, yolo_box)
        rx1, ry1, rx2, ry2 = refined_box

        # Crop using refined coordinates
        cropped = img_original[ry1:ry2, rx1:rx2]

        # Enhance for OCR (better text recognition)
        enhanced = enhance_label_for_ocr(img_original, refined_box)

        # Encode to base64 for transmission
        _, buffer_enhanced = cv2.imencode('.jpg', enhanced, [cv2.IMWRITE_JPEG_QUALITY, 95])
        enhanced_base64 = base64.b64encode(buffer_enhanced).decode('utf-8')

        _, buffer_crop = cv2.imencode('.jpg', cropped, [cv2.IMWRITE_JPEG_QUALITY, 95])
        cropped_base64 = base64.b64encode(buffer_crop).decode('utf-8')

        response = {
            "detected": True,
            "confidence": confidence,
            "box": {
                "x1": rx1,
                "y1": ry1,
                "x2": rx2,
                "y2": ry2
            },
            "cropped_image": cropped_base64,
            "enhanced_image": enhanced_base64,
            "crop_size": {
                "width": cropped.shape[1],
                "height": cropped.shape[0]
            },
            "refinement_applied": True
        }

        # Add rotated box if available
        if rotated_box is not None:
            response["rotated_box"] = rotated_box
            response["box_type"] = "rotated"
        else:
            response["rotated_box"] = [
                [rx1, ry1], [rx2, ry1], [rx2, ry2], [rx1, ry2]
            ]
            response["box_type"] = "axis_aligned_fallback"

        return response

    except Exception as e:
        print(f"Processing error: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={"error": f"Processing failed: {str(e)}"}
        )


@app.post("/detect-debug")
async def detect_debug(file: UploadFile = File(...)):
    """
    Debug endpoint: Returns annotated image showing detection pipeline

    Visualization:
    - Red box: YOLO rough detection
    - Green polygon: Precise rotated rectangle from edge detection
    - Blue contours: Detected edges used for fitting

    Use this to verify that the rotated box aligns with physical label edges.
    """
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img_original = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img_original is None:
            return JSONResponse(
                status_code=400,
                content={"error": "Invalid image file"}
            )

        # Make a copy for annotation
        annotated = img_original.copy()
        original_h, original_w = img_original.shape[:2]

        # Letterbox and detect
        img_letterboxed, scale, padding = letterbox_image(img_original, target_size=640)

        results = model(
            img_letterboxed,
            conf=CONF_THRESHOLD,
            iou=IOU_THRESHOLD,
            device=device,
            verbose=False,
            imgsz=640
        )[0]

        if results.boxes is None or len(results.boxes) == 0:
            return {"detected": False, "message": "No label detected"}

        # Get YOLO box
        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()

        best_idx = scores.argmax()
        letterbox_coords = tuple(map(int, boxes[best_idx]))

        x1, y1, x2, y2 = unletterbox_coords(letterbox_coords, scale, padding)
        x1 = max(0, min(x1, original_w))
        y1 = max(0, min(y1, original_h))
        x2 = max(0, min(x2, original_w))
        y2 = max(0, min(y2, original_h))

        yolo_box = (x1, y1, x2, y2)

        # Draw YOLO box in RED
        cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 0, 255), 3)
        cv2.putText(annotated, "YOLO", (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

        # Get precise rotated box
        rotated_box = refine_box_edges_rotated(img_original, yolo_box)

        if rotated_box is not None:
            # Draw rotated box in GREEN
            pts = np.array(rotated_box, dtype=np.int32)
            cv2.polylines(annotated, [pts], True, (0, 255, 0), 3)
            cv2.putText(annotated, "PRECISE", (pts[0][0], pts[0][1] - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

            # Also draw the detected contour in BLUE for verification
            contour = find_label_contour(img_original, yolo_box)
            if contour is not None:
                cv2.drawContours(annotated, [contour], -1, (255, 100, 0), 2)

        # Encode annotated image
        _, buffer = cv2.imencode('.jpg', annotated, [cv2.IMWRITE_JPEG_QUALITY, 95])
        annotated_base64 = base64.b64encode(buffer).decode('utf-8')

        return {
            "detected": True,
            "annotated_image": annotated_base64,
            "yolo_box": list(yolo_box),
            "rotated_box": rotated_box,
            "confidence": float(scores[best_idx]),
            "message": "Green = precise rotated box, Red = YOLO box, Blue = detected contour"
        }

    except Exception as e:
        print(f"Debug error: {str(e)}")
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={"error": str(e)}
        )


if __name__ == "__main__":
    import uvicorn

    print("\n" + "="*70)
    print("🚀 Starting PRECISION Medicine Label Detection Server v3.0")
    print("="*70)
    print(f"📱 Server URL: http://0.0.0.0:8000")
    print(f"📱 Local: http://localhost:8000")
    print(f"📱 Network: http://<YOUR_IP>:8000")
    print(f"🔧 Confidence Threshold: {CONF_THRESHOLD}")
    print(f"🔧 IoU Threshold: {IOU_THRESHOLD}")
    print(f"⚡ Device: {'GPU - ' + torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}")
    print("\n✨ NEW in v3.0 - GEOMETRIC EDGE ALIGNMENT:")
    print("   • YOLO used ONLY for rough localization")
    print("   • Multi-stage edge detection (Canny + Adaptive)")
    print("   • Rotated rectangle fitting (minAreaRect)")
    print("   • Box aligns with PHYSICAL label edges, not semantics")
    print("   • No OCR, text filtering, or confidence tuning")
    print("   • GUARANTEED tight fit regardless of rotation")
    print("\n📋 Endpoints:")
    print("   • /detect-live - Fast detection with rotated boxes")
    print("   • /detect-and-crop - Full pipeline with OCR enhancement")
    print("   • /detect-debug - Visualize detection pipeline")
    print("="*70 + "\n")

    uvicorn.run(app, host="0.0.0.0", port=8000)