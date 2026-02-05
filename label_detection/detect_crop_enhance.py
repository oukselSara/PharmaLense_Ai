from ultralytics import YOLO
import torch
import cv2
import numpy as np
import os


# ==================================================
# TEXT ENHANCEMENT (OCR-FRIENDLY)
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
# ROTATION UTILS
# ==================================================
def rotate_image(img, angle):
    if angle == 90:
        return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    if angle == 180:
        return cv2.rotate(img, cv2.ROTATE_180)
    if angle == 270:
        return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return img


def map_box_back(box, angle, w, h):
    x1, y1, x2, y2 = box

    if angle == 90:
        return y1, w - x2, y2, w - x1
    if angle == 180:
        return w - x2, h - y2, w - x1, h - y1
    if angle == 270:
        return h - y2, x1, h - y1, x2

    return box


# ==================================================
# MAIN
# ==================================================
def main():
    MODEL_PATH = r"C:/Users/oukse/runs/detect/runs/detect/medicine_label_mx3503/weights/best.pt"
    BASE_OUTPUT = "outputs"
    CONF_THRESHOLD = 0.15  # LOWERED (important)

    DETECTED_DIR = os.path.join(BASE_OUTPUT, "detected")
    CROPPED_DIR = os.path.join(BASE_OUTPUT, "cropped")
    ENHANCED_DIR = os.path.join(BASE_OUTPUT, "enhanced")

    for d in [DETECTED_DIR, CROPPED_DIR, ENHANCED_DIR]:
        os.makedirs(d, exist_ok=True)

    if not torch.cuda.is_available():
        raise RuntimeError("❌ CUDA not available")

    print("✅ Using GPU:", torch.cuda.get_device_name(0))

    model = YOLO(MODEL_PATH)

    img_path = input("Enter image path: ").strip().strip('"')
    image = cv2.imread(img_path)
    if image is None:
        raise RuntimeError("❌ Failed to load image")

    h, w = image.shape[:2]

    best = None
    best_score = 0

    # 🔁 MULTI-ROTATION DETECTION
    for angle in [0, 90, 180, 270]:
        rotated = rotate_image(image, angle)

        results = model(
            rotated,
            device=0,
            conf=CONF_THRESHOLD,
            imgsz=1024,
            verbose=False
        )[0]

        if results.boxes is None:
            continue

        boxes = results.boxes.xyxy.cpu().numpy()
        scores = results.boxes.conf.cpu().numpy()

        for box, score in zip(boxes, scores):
            if score > best_score:
                mapped = map_box_back(box, angle, w, h)
                best = mapped
                best_score = score

    if best is None:
        print("❌ No label detected (even with rotation)")
        return

    x1, y1, x2, y2 = map(int, best)

    # ============================
    # DRAW
    # ============================
    annotated = image.copy()
    cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 255, 0), 2)
    cv2.putText(
        annotated,
        f"medicine_label {best_score:.2f}",
        (x1, max(y1 - 10, 20)),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 0),
        2
    )

    cropped = image[y1:y2, x1:x2]
    enhanced = enhance_label_text(cropped)

    base = os.path.splitext(os.path.basename(img_path))[0]

    cv2.imwrite(os.path.join(DETECTED_DIR, f"{base}_detected.jpg"), annotated)
    cv2.imwrite(os.path.join(CROPPED_DIR, f"{base}_cropped.jpg"), cropped)
    cv2.imwrite(os.path.join(ENHANCED_DIR, f"{base}_enhanced.jpg"), enhanced)

    print("✅ Detection succeeded")
    print("📦 Confidence:", round(best_score, 3))


if __name__ == "__main__":
    main()