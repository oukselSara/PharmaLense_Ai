# -*- coding: utf-8 -*-
import sys
import io
import requests
import json

# Fix console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("Testing detection with real screenshot...")
print("=" * 50)

# Test with the real screenshot
image_path = "H:/graduation/PharmaLense_Ai/mobile_app/results/Screenshot_20260208_203652.jpg"

try:
    with open(image_path, 'rb') as f:
        files = {'file': ('test.jpg', f, 'image/jpeg')}
        response = requests.post("http://localhost:8000/detect-live", files=files)

    result = response.json()

    print("\nDetection Result:")
    print(json.dumps(result, indent=2))

    if result.get('detected'):
        print("\n[SUCCESS] Detection is working!")
        print(f"Confidence: {result.get('confidence', 0):.2%}")
        print(f"Box coordinates: {result.get('box', [])}")
        print(f"Image size: {result.get('original_size', {})}")
    else:
        print("\n[FAILED] No detection")
        if 'error' in result:
            print(f"Error: {result['error']}")

except Exception as e:
    print(f"[ERROR] {e}")
