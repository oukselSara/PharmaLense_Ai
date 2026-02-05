import cv2
import pytesseract
import numpy as np
import json
import os
from datetime import datetime

# If Windows:
# pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

def preprocess(image_path):
    img = cv2.imread(image_path)

    if img is None:
        raise ValueError("Unable to load image. Check the path.")

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Upscale (very important for small text)
    gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)

    # Denoise
    gray = cv2.fastNlMeansDenoising(gray, None, 30, 7, 21)

    # Adaptive threshold
    thresh = cv2.adaptiveThreshold(
        gray,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31,
        10
    )

    # Morphological closing
    kernel = np.ones((2, 2), np.uint8)
    processed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

    return processed

def extract_text_all_angles(img):
    results = []
    config = r'--oem 3 --psm 6 -l fra'

    rotations = {
        "0_deg": img,
        "90_deg": cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE),
        "180_deg": cv2.rotate(img, cv2.ROTATE_180),
        "270_deg": cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    }

    for angle, rotated in rotations.items():
        text = pytesseract.image_to_string(rotated, config=config)
        results.append({
            "orientation": angle,
            "text": text.strip()
        })

    return results

def clean_combined_text(results):
    combined = " ".join([r["text"] for r in results])
    return " ".join(combined.split())

if __name__ == "__main__":

    image_path = input("Enter the full path of the image: ").strip()

    if not os.path.exists(image_path):
        print("Invalid path. File does not exist.")
        exit()

    try:
        processed = preprocess(image_path)
        raw_results = extract_text_all_angles(processed)
        clean_text = clean_combined_text(raw_results)

        # ---- PRINT TO TERMINAL ----
        print("\n----- OCR RESULT (ONE LINE) -----\n")
        print(clean_text)
        print("\n---------------------------------\n")

        # ---- SAVE JSON ----
        output_json = "ocr_output.json"

        data = {
            "image": image_path,
            "timestamp": datetime.now().isoformat(),
            "clean_text_one_line": clean_text,
            "raw_orientations": raw_results
        }

        with open(output_json, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4)

        print(f"OCR complete. JSON saved to {output_json}")

    except Exception as e:
        print(f"Error: {e}")
