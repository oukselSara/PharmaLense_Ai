from ultralytics import YOLO
import torch
import os

def main():
    # =====================================================
    # PATHS
    # =====================================================
    DATA_YAML = r"C:/Users/oukse/OneDrive/Documents/Graduation/PharmaLense_Ai/medicine_dataset/data.yaml"
    PROJECT_DIR = "runs/detect"
    EXP_NAME = "medicine_label_mx350"
    CHECKPOINT_PATH = os.path.join(PROJECT_DIR, EXP_NAME, "weights", "last.pt")

    TOTAL_EPOCHS = 120
    SAVE_EVERY = 20

    # =====================================================
    # GPU CHECK
    # =====================================================
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is NOT available. Do not train on CPU.")

    print("✅ GPU detected:", torch.cuda.get_device_name(0))

    if not os.path.exists(DATA_YAML):
        raise FileNotFoundError(f"data.yaml not found: {DATA_YAML}")

    # =====================================================
    # AUTO-RESUME LOGIC
    # =====================================================
    if os.path.exists(CHECKPOINT_PATH):
        print(f"🔁 Resuming from checkpoint: {CHECKPOINT_PATH}")
        model = YOLO(CHECKPOINT_PATH)
        resume_training = True
        pretrained = False
    else:
        print("🆕 No checkpoint found → starting fresh from yolov8n.pt")
        model = YOLO("yolov8n.pt")
        resume_training = False
        pretrained = True

    # =====================================================
    # TRAIN (MX350 SAFE)
    # =====================================================
    model.train(
        data=DATA_YAML,
        epochs=TOTAL_EPOCHS,
        imgsz=640,
        batch=2,
        optimizer="AdamW",
        lr0=0.001,
        patience=20,
        degrees=10,
        scale=0.4,
        device=0,
        amp=True,
        workers=2,
        cache=False,
        save_period=SAVE_EVERY,     # ✅ save every 20 epochs
        resume=resume_training,     # ✅ auto resume
        project=PROJECT_DIR,
        name=EXP_NAME,
        pretrained=pretrained
    )

    print("🎉 Training finished!")
    print(f"📦 Best model: {PROJECT_DIR}/{EXP_NAME}/weights/best.pt")

if __name__ == "__main__":
    main()
