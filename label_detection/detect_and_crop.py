from ultralytics import YOLO
import torch
import cv2
import os

def main():
    # ============================
    # CONFIG
    # ============================
    MODEL_PATH = r"C:/Users/oukse/runs/detect/runs/detect/medicine_label_mx3503/weights/best.pt"
    OUTPUT_DIR = "outputs"
    CONF_THRESHOLD = 0.4

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # ============================
    # GPU CHECK
    # ============================
    if not torch.cuda.is_available():
        raise RuntimeError("❌ CUDA not available. GPU is required.")

    print("✅ Using GPU:", torch.cuda.get_device_name(0))

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"❌ Model not found: {MODEL_PATH}")

    # ============================
    # LOAD MODEL
    # ============================
    model = YOLO(MODEL_PATH)

    # ============================
    # ASK USER FOR IMAGE
    # ============================
    img_path = input("Enter image path: ").strip().strip('"')

    if not os.path.exists(img_path):
        raise FileNotFoundError(f"❌ Image not found: {img_path}")

    image = cv2.imread(img_path)
    if image is None:
        raise RuntimeError("❌ Failed to read image")

    # ============================
    # RUN INFERENCE
    # ============================
    results = model(
        image,
        device=0,
        conf=CONF_THRESHOLD,
        verbose=False
    )[0]

    if results.boxes is None or len(results.boxes) == 0:
        print("❌ No label detected")
        return

    # ============================
    # SELECT BEST BOX
    # ============================
    boxes = results.boxes.xyxy.cpu().numpy()
    scores = results.boxes.conf.cpu().numpy()

    best_idx = scores.argmax()
    x1, y1, x2, y2 = map(int, boxes[best_idx])

    # ============================
    # DRAW BOX ON ORIGINAL
    # ============================
    annotated = image.copy()
    cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 255, 0), 2)
    cv2.putText(
        annotated,
        "medicine_label",
        (x1, max(y1 - 10, 20)),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 0),
        2
    )

    # ============================
    # CROP LABEL
    # ============================
    cropped = image[y1:y2, x1:x2]

    # ============================
    # SAVE RESULTS
    # ============================
    base_name = os.path.splitext(os.path.basename(img_path))[0]

    annotated_path = os.path.join(OUTPUT_DIR, f"{base_name}_detected.jpg")
    cropped_path = os.path.join(OUTPUT_DIR, f"{base_name}_cropped.jpg")

    cv2.imwrite(annotated_path, annotated)
    cv2.imwrite(cropped_path, cropped)

    print("✅ Detection complete")
    print("📦 Saved files:")
    print(" -", annotated_path)
    print(" -", cropped_path)


if __name__ == "__main__":
    main()
