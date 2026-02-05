import cv2
import numpy as np
import os

def enhance_label_text(img):
    # 1. Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 2. Estimate background (smooth illumination)
    background = cv2.GaussianBlur(gray, (31, 31), 0)

    # 3. Enhance text by background subtraction
    enhanced = cv2.subtract(background, gray)
    enhanced = cv2.normalize(enhanced, None, 0, 255, cv2.NORM_MINMAX)

    # 4. Invert so text becomes dark
    enhanced = cv2.bitwise_not(enhanced)

    # 5. Contrast stretching
    p2, p98 = np.percentile(enhanced, (2, 98))
    enhanced = np.clip(
        (enhanced - p2) * 255.0 / (p98 - p2),
        0, 255
    ).astype(np.uint8)

    # 6. Very mild sharpening (OCR-safe)
    kernel = np.array([[0, -0.5, 0],
                       [-0.5, 3, -0.5],
                       [0, -0.5, 0]])
    enhanced = cv2.filter2D(enhanced, -1, kernel)

    return enhanced


def main():
    img_path = input("Enter cropped label image path: ").strip().strip('"')

    if not os.path.exists(img_path):
        raise FileNotFoundError("❌ Image not found")

    img = cv2.imread(img_path)
    if img is None:
        raise RuntimeError("❌ Failed to load image")

    enhanced = enhance_label_text(img)

    base, ext = os.path.splitext(img_path)
    out_path = base + "_ocr_ready" + ext

    cv2.imwrite(out_path, enhanced)

    print(f"✅ OCR-ready image saved at:\n{out_path}")


if __name__ == "__main__":
    main()
