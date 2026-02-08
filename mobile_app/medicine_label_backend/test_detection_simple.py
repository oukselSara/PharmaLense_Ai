# -*- coding: utf-8 -*-
"""
Simple test script to check if YOLO detection is working
"""
import sys
import io
import requests
import cv2
import numpy as np
from pathlib import Path

# Fix console encoding for Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Create a simple test image with a white rectangle (simulating a label)
print("Creating test image...")
test_img = np.zeros((640, 480, 3), dtype=np.uint8)
# Draw a white rectangle (simulating a medicine label)
cv2.rectangle(test_img, (100, 150), (400, 450), (255, 255, 255), -1)
# Add some noise to make it more realistic
noise = np.random.randint(0, 50, test_img.shape, dtype=np.uint8)
test_img = cv2.add(test_img, noise)

# Save test image
test_path = Path("test_label.jpg")
cv2.imwrite(str(test_path), test_img)
print(f"[OK] Test image saved: {test_path}")

# Test backend connection
print("\n" + "="*50)
print("Testing backend server...")
print("="*50)

try:
    # Test root endpoint
    response = requests.get("http://localhost:8000")
    print(f"\n[OK] Server is running")
    print(f"Response: {response.json()}")

    # Test detection endpoint
    print("\n" + "="*50)
    print("Testing detection...")
    print("="*50)

    with open(test_path, 'rb') as f:
        files = {'file': ('test.jpg', f, 'image/jpeg')}
        response = requests.post("http://localhost:8000/detect-live", files=files)

    result = response.json()
    print(f"\nDetection result:")
    print(f"  Detected: {result.get('detected', False)}")

    if result.get('detected'):
        print(f"  Confidence: {result.get('confidence', 0):.2%}")
        print(f"  Box: {result.get('box', [])}")
        print("\n[OK] YOLO detection is WORKING!")
    else:
        print("\n[FAIL] No detection - Model might need lower confidence threshold")
        print("   Or the model was not trained on synthetic images like this")

    print("\n" + "="*50)
    print("RECOMMENDATION:")
    print("="*50)
    print("Try testing with a REAL medicine label image:")
    print("1. Take a photo of a medicine box/label")
    print("2. Save it as 'real_test.jpg' in this folder")
    print("3. Run this command:")
    print('   curl -X POST -F "file=@real_test.jpg" http://localhost:8000/detect-live')

except requests.exceptions.ConnectionError:
    print("[ERROR] Cannot connect to backend server")
    print("   Make sure the server is running: python backend_server.py")
except Exception as e:
    print(f"[ERROR] {e}")
finally:
    # Cleanup
    if test_path.exists():
        test_path.unlink()
        print(f"\n[CLEANUP] Removed test file")
