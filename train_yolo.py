from ultralytics import YOLO
import torch
import os
import sys

def main():
    # =====================================================
    # PATHS & BASIC CONFIG
    # =====================================================
    DATA_YAML = r"H:/graduation/PharmaLense_Ai/medicine_dataset/data.yaml"
    PROJECT_DIR = "runs/detect"
    EXP_NAME = "medicine_label_lowdata"
    WEIGHTS_DIR = os.path.join(PROJECT_DIR, EXP_NAME, "weights")
    LAST_CKPT = os.path.join(WEIGHTS_DIR, "last.pt")

    EPOCHS = 200
    SAVE_EVERY = 20
    IMG_SIZE = 640
    BATCH_SIZE = 2   # safe for GTX 1070 + low data

    # =====================================================
    # GPU CHECK (HARD FAIL)
    # =====================================================
    if not torch.cuda.is_available():
        print("❌ CUDA not available. Aborting.")
        sys.exit(1)

    print(f"✅ GPU detected: {torch.cuda.get_device_name(0)}")

    if not os.path.exists(DATA_YAML):
        raise FileNotFoundError(f"data.yaml not found: {DATA_YAML}")

    # =====================================================
    # AUTO-RESUME LOGIC
    # =====================================================
    if os.path.exists(LAST_CKPT):
        print(f"🔁 Resuming training from: {LAST_CKPT}")
        model = YOLO(LAST_CKPT)
        resume = True
        pretrained = False
    else:
        print("🆕 Starting fresh from yolov8n.pt")
        model = YOLO("yolov8n.pt")
        resume = False
        pretrained = True

    # =====================================================
    # TRAINING — OPTIMIZED FOR ~20 IMAGES
    # =====================================================
    model.train(
        data=DATA_YAML,
        epochs=EPOCHS,
        imgsz=IMG_SIZE,
        batch=BATCH_SIZE,

        optimizer="AdamW",
        lr0=0.0005,
        patience=50,

        # 🔒 freeze backbone (critical for tiny datasets)
        freeze=10,

        # 🔆 aggressive lighting augmentation
        hsv_h=0.02,
        hsv_s=0.9,
        hsv_v=0.9,
        degrees=10,
        scale=0.5,
        fliplr=0.5,

        mosaic=1.0,
        mixup=0.0,
        copy_paste=0.0,

        # hardware
        device=0,
        amp=False,          # Pascal-safe
        workers=2,
        cache=False,

        # saving & resume
        save_period=SAVE_EVERY,   # ✅ save every 20 epochs
        resume=resume,            # ✅ resume if stopped
        project=PROJECT_DIR,
        name=EXP_NAME,
        pretrained=pretrained
    )

    print("🎉 Training finished.")
    print(f"📦 Best model: {PROJECT_DIR}/{EXP_NAME}/weights/best.pt")

if __name__ == "__main__":
    main()
