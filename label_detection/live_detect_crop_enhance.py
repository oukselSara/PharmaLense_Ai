from ultralytics import YOLO
import torch
import cv2
import numpy as np
import os
import time

# ==================================================
# TEXT ENHANCEMENT (OCR-FRIENDLY, NO BINARIZATION)
# ==================================================
def enhance_label_text(img):
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
# MAIN LIVE CAMERA LOOP
# ==================================================
def main():
    # ============================
    # CONFIG
    # ============================
    MODEL_PATH = r"C:/Users/oukse/runs/detect/runs/detect/medicine_label_mx3503/weights/best.pt"
    CONF_THRESHOLD = 0.35
    CAMERA_ID = 0

    BASE_OUTPUT = "outputs"
    DETECTED_DIR = os.path.join(BASE_OUTPUT, "detected")
    CROPPED_DIR = os.path.join(BASE_OUTPUT, "cropped")
    ENHANCED_DIR = os.path.join(BASE_OUTPUT, "enhanced")

    for d in [DETECTED_DIR, CROPPED_DIR, ENHANCED_DIR]:
        os.makedirs(d, exist_ok=True)

    # ============================
    # GPU CHECK
    # ============================
    if not torch.cuda.is_available():
        raise RuntimeError("❌ CUDA not available")

    print("✅ Using GPU:", torch.cuda.get_device_name(0))

    # ============================
    # LOAD MODEL
    # ============================
    model = YOLO(MODEL_PATH)

    # ============================
    # OPEN CAMERA
    # ============================
    cap = cv2.VideoCapture(CAMERA_ID)
    if not cap.isOpened():
        raise RuntimeError("❌ Failed to open camera")

    print("🎥 Camera started")
    print("👉 Press C to capture | Press Q to quit")

    tracking_box = None
    last_seen = 0

    # ============================
    # LIVE LOOP
    # ============================
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        display = frame.copy()
        crop = None

        # ----------------------------------
        # DETECT (refresh if lost)
        # ----------------------------------
        if tracking_box is None or time.time() - last_seen > 1.0:
            results = model(
                frame,
                conf=CONF_THRESHOLD,
                device=0,
                verbose=False
            )[0]

            if results.boxes is not None and len(results.boxes) > 0:
                boxes = results.boxes.xyxy.cpu().numpy()
                scores = results.boxes.conf.cpu().numpy()

                best = scores.argmax()
                x1, y1, x2, y2 = map(int, boxes[best])

                tracking_box = (x1, y1, x2, y2)
                last_seen = time.time()

        # ----------------------------------
        # TRACK + ZOOM
        # ----------------------------------
        if tracking_box is not None:
            x1, y1, x2, y2 = tracking_box
            h, w, _ = frame.shape
            pad = 30

            x1 = max(0, x1 - pad)
            y1 = max(0, y1 - pad)
            x2 = min(w, x2 + pad)
            y2 = min(h, y2 + pad)

            crop = frame[y1:y2, x1:x2]

            cv2.rectangle(display, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(
                display,
                "LABEL DETECTED - Press C",
                (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2
            )

        # ----------------------------------
        # SHOW
        # ----------------------------------
        cv2.imshow("PharmaLense - Live Detection", display)

        key = cv2.waitKey(1) & 0xFF

        # ----------------------------------
        # CAPTURE ALL OUTPUTS
        # ----------------------------------
        if key == ord('c') and crop is not None:
            ts = time.strftime("%Y%m%d_%H%M%S")

            detected_path = os.path.join(DETECTED_DIR, f"{ts}_detected.jpg")
            cropped_path = os.path.join(CROPPED_DIR, f"{ts}_cropped.jpg")
            enhanced_path = os.path.join(ENHANCED_DIR, f"{ts}_enhanced.jpg")

            enhanced = enhance_label_text(crop)

            cv2.imwrite(detected_path, display)
            cv2.imwrite(cropped_path, crop)
            cv2.imwrite(enhanced_path, enhanced)

            print("✅ Saved:")
            print(" -", detected_path)
            print(" -", cropped_path)
            print(" -", enhanced_path)

        # ----------------------------------
        # QUIT
        # ----------------------------------
        if key == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("👋 Camera closed")


if __name__ == "__main__":
    main()
