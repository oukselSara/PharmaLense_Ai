from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from ultralytics import YOLO
import torch
import cv2
import numpy as np
from PIL import Image
import io
import base64

app = FastAPI()

# ==================================================
# MODEL CONFIGURATION
# ==================================================
MODEL_PATH = r"H:\graduation\PharmaLense_Ai\runs\detect\runs\detect\medicine_label_lowdata2\weights\last.pt"
CONF_THRESHOLD = 0.35

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
# TEXT ENHANCEMENT FUNCTION
# ==================================================
def enhance_label_text(img):
    """Enhance text on label for better OCR results"""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    background = cv2.GaussianBlur(gray, (31, 31), 0)
    enhanced = cv2.subtract(background, gray)
    enhanced = cv2.normalize(enhanced, None, 0, 255, cv2.NORM_MINMAX)
    enhanced = cv2.bitwise_not(enhanced)

    p2, p98 = np.percentile(enhanced, (2, 98))
    enhanced = np.clip(
        (enhanced - p2) * 255.0 / (p98 - p2),
        0, 255
    ).astype(np.uint8)

    kernel = np.array([[0, -0.5, 0],
                       [-0.5, 3, -0.5],
                       [0, -0.5, 0]])
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
        "model": "YOLO Medicine Label Detector",
        "device": "GPU" if torch.cuda.is_available() else "CPU"
    }


@app.post("/detect")
async def detect_label(file: UploadFile = File(...)):
    """
    Detect medicine label in uploaded image
    Returns: bounding box coordinates and confidence
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

        # Run YOLO detection
        results = model(
            img,
            conf=CONF_THRESHOLD,
            device=device,
            verbose=False
        )[0]

        # Check if any labels detected
        if results.boxes is None or len(results.boxes) == 0:
            return {
                "detected": False,
                "message": "No label detected"
            }

        # Get best detection (highest confidence)
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
                "width": img.shape[1],
                "height": img.shape[0]
            }
        }

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Detection failed: {str(e)}"}
        )


@app.post("/detect-and-crop")
async def detect_and_crop(file: UploadFile = File(...)):
    """
    Detect medicine label, crop it, and return enhanced image for OCR
    Returns: cropped and enhanced image as base64
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

        # Run YOLO detection
        results = model(
            img,
            conf=CONF_THRESHOLD,
            device=device,
            verbose=False
        )[0]

        # Check if any labels detected
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

        # Add padding to crop
        h, w = img.shape[:2]
        pad = 20
        x1 = max(0, x1 - pad)
        y1 = max(0, y1 - pad)
        x2 = min(w, x2 + pad)
        y2 = min(h, y2 + pad)

        # Crop label
        cropped = img[y1:y2, x1:x2]

        # Enhance for OCR
        enhanced = enhance_label_text(cropped)

        # Convert enhanced image to base64
        _, buffer = cv2.imencode('.jpg', enhanced)
        enhanced_base64 = base64.b64encode(buffer).decode('utf-8')

        # Also convert cropped (original) to base64
        _, buffer_crop = cv2.imencode('.jpg', cropped)
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
        return JSONResponse(
            status_code=500,
            content={"error": f"Processing failed: {str(e)}"}
        )


@app.post("/detect-live")
async def detect_live(file: UploadFile = File(...)):
    """
    Lightweight detection for live camera feed
    Returns only bounding box for real-time overlay
    """
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            return {"detected": False}

        # Run detection
        results = model(
            img,
            conf=CONF_THRESHOLD,
            device=device,
            verbose=False
        )[0]

        if results.boxes is None or len(results.boxes) == 0:
            return {"detected": False}

        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()
        
        best_idx = scores.argmax()
        x1, y1, x2, y2 = map(int, boxes[best_idx])

        return {
            "detected": True,
            "box": [x1, y1, x2, y2],
            "confidence": float(scores[best_idx])
        }

    except Exception as e:
        return {"detected": False, "error": str(e)}


if __name__ == "__main__":
    import uvicorn
    
    print("\n" + "="*50)
    print("🚀 Starting Medicine Label Detection Server")
    print("="*50)
    print(f"📱 Server will be available at: http://0.0.0.0:8000")
    print(f"📱 Local access: http://localhost:8000")
    print(f"📱 Network access: http://<YOUR_IP>:8000")
    print("="*50 + "\n")
    
    uvicorn.run(app, host="0.0.0.0", port=8000)