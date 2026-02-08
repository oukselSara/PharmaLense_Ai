from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
import torch
import cv2
import numpy as np
import base64
from typing import Tuple

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
CONF_THRESHOLD = 0.25  # Lowered for better detection
IOU_THRESHOLD = 0.45

# Load model once at startup
print("Loading YOLO model...")
if not torch.cuda.is_available():
    print("⚠️ WARNING: CUDA not available, using CPU (slower)")
    device = 'cpu'
else:
    print(f"✅ Using GPU: {torch.cuda.get_device_name(0)}")
    device = 0

model = YOLO(MODEL_PATH)
print("✅ Model loaded successfully")


# ==================================================
# LIGHTWEIGHT PREPROCESSING FOR SPEED
# ==================================================
def quick_preprocess(img: np.ndarray) -> np.ndarray:
    """
    Lightweight preprocessing to avoid freezing
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
    """
    x1, y1, x2, y2 = box
    
    # Add padding
    h, w = img.shape[:2]
    pad = 10
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(w, x2 + pad)
    y2 = min(h, y2 + pad)
    
    # Crop
    cropped = img[y1:y2, x1:x2]
    
    # Convert to grayscale
    gray = cv2.cvtColor(cropped, cv2.COLOR_BGR2GRAY)
    
    # Quick denoising
    denoised = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)
    
    # Apply CLAHE for better contrast
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    enhanced = clahe.apply(denoised)
    
    # Sharpen
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
        "model": "YOLO Medicine Label Detector (Optimized)",
        "device": "GPU" if torch.cuda.is_available() else "CPU",
        "version": "2.1"
    }


@app.post("/detect")
async def detect_label(file: UploadFile = File(...)):
    """
    Detect medicine label in uploaded image
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

        # Quick preprocessing
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


@app.post("/detect-and-crop")
async def detect_and_crop(file: UploadFile = File(...)):
    """
    Detect medicine label, crop it, and return enhanced version for OCR
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

        # Quick preprocess
        preprocessed = quick_preprocess(img)

        # Detect
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

        # Enhance label region for OCR
        enhanced = enhance_label_for_ocr(preprocessed, (x1, y1, x2, y2))

        # Get cropped original
        h, w = preprocessed.shape[:2]
        pad = 10
        x1_crop = max(0, x1 - pad)
        y1_crop = max(0, y1 - pad)
        x2_crop = min(w, x2 + pad)
        y2_crop = min(h, y2 + pad)
        cropped = preprocessed[y1_crop:y2_crop, x1_crop:x2_crop]

        # Convert to base64
        _, buffer_enhanced = cv2.imencode('.jpg', enhanced, [cv2.IMWRITE_JPEG_QUALITY, 90])
        enhanced_base64 = base64.b64encode(buffer_enhanced).decode('utf-8')

        _, buffer_crop = cv2.imencode('.jpg', cropped, [cv2.IMWRITE_JPEG_QUALITY, 90])
        cropped_base64 = base64.b64encode(buffer_crop).decode('utf-8')

        return {
            "detected": True,
            "confidence": confidence,
            "box": {
                "x1": x1,
                "y1": y1,
                "x2": x2,
                "y2": y2
            },
            "cropped_image": cropped_base64,
            "enhanced_image": enhanced_base64,
            "crop_size": {
                "width": cropped.shape[1],
                "height": cropped.shape[0]
            }
        }

    except Exception as e:
        print(f"Processing error: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": f"Processing failed: {str(e)}"}
        )


@app.post("/detect-live")
async def detect_live(file: UploadFile = File(...)):
    """
    FAST lightweight detection for live camera feed
    Returns coordinates in ORIGINAL image dimensions
    """
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            return {"detected": False}

        # Store original dimensions
        original_h, original_w = img.shape[:2]

        # Resize for faster inference
        max_size = 640
        scale = 1.0
        
        if max(original_h, original_w) > max_size:
            scale = max_size / max(original_h, original_w)
            new_w = int(original_w * scale)
            new_h = int(original_h * scale)
            img_resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
        else:
            img_resized = img

        # Run detection on resized image
        results = model(
            img_resized,
            conf=CONF_THRESHOLD,
            iou=IOU_THRESHOLD,
            device=device,
            verbose=False
        )[0]

        if results.boxes is None or len(results.boxes) == 0:
            return {"detected": False}

        # Get best detection
        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()
        
        best_idx = scores.argmax()
        x1, y1, x2, y2 = boxes[best_idx]
        
        # Scale coordinates back to ORIGINAL image size
        if scale != 1.0:
            x1 = int(x1 / scale)
            y1 = int(y1 / scale)
            x2 = int(x2 / scale)
            y2 = int(y2 / scale)
        else:
            x1, y1, x2, y2 = map(int, [x1, y1, x2, y2])

        return {
            "detected": True,
            "box": [x1, y1, x2, y2],
            "confidence": float(scores[best_idx]),
            "original_size": {
                "width": original_w,
                "height": original_h
            }
        }

    except Exception as e:
        print(f"Live detection error: {str(e)}")
        return {"detected": False, "error": str(e)}


if __name__ == "__main__":
    import uvicorn
    
    print("\n" + "="*60)
    print("🚀 Starting Optimized Medicine Label Detection Server")
    print("="*60)
    print(f"📱 Server URL: http://0.0.0.0:8000")
    print(f"📱 Local: http://localhost:8000")
    print(f"📱 Network: http://<YOUR_IP>:8000")
    print(f"🔧 Confidence Threshold: {CONF_THRESHOLD}")
    print(f"🔧 IoU Threshold: {IOU_THRESHOLD}")
    print(f"⚡ Device: {'GPU - ' + torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}")
    print("="*60 + "\n")
    
    uvicorn.run(app, host="0.0.0.0", port=8000)