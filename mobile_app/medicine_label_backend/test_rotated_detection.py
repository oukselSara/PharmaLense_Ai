"""
Test script for rotated bounding box detection
Demonstrates the edge-based geometric alignment approach
"""

import cv2
import numpy as np
import requests
import base64
import sys
from pathlib import Path


def test_image(image_path: str, server_url: str = "http://localhost:8000"):
    """
    Test the rotated box detection on a single image
    """
    print(f"\n{'='*70}")
    print(f"Testing: {image_path}")
    print('='*70)

    # Read image
    img = cv2.imread(image_path)
    if img is None:
        print(f"❌ Could not read image: {image_path}")
        return

    print(f"📷 Image size: {img.shape[1]}x{img.shape[0]}")

    # Encode image for transmission
    _, buffer = cv2.imencode('.jpg', img)

    # Test /detect-debug endpoint
    print("\n🔍 Testing /detect-debug endpoint...")
    try:
        files = {'file': ('image.jpg', buffer.tobytes(), 'image/jpeg')}
        response = requests.post(f"{server_url}/detect-debug", files=files, timeout=30)

        if response.status_code != 200:
            print(f"❌ Server error: {response.status_code}")
            print(response.text)
            return

        result = response.json()

        if not result.get('detected', False):
            print("❌ No label detected")
            return

        print(f"✅ Label detected!")
        print(f"   Confidence: {result['confidence']:.3f}")

        # Display box info
        yolo_box = result.get('yolo_box', [])
        rotated_box = result.get('rotated_box', [])

        print(f"\n📦 YOLO Box (rough):")
        print(f"   [{yolo_box[0]}, {yolo_box[1]}] -> [{yolo_box[2]}, {yolo_box[3]}]")
        print(f"   Area: {(yolo_box[2]-yolo_box[0]) * (yolo_box[3]-yolo_box[1])} px²")

        if rotated_box:
            print(f"\n📐 Rotated Box (precise):")
            for i, point in enumerate(rotated_box):
                print(f"   Corner {i+1}: [{point[0]}, {point[1]}]")

            # Calculate area of rotated box
            pts = np.array(rotated_box, dtype=np.float32)
            rect_area = cv2.contourArea(pts)
            print(f"   Area: {int(rect_area)} px²")

            # Calculate tightness improvement
            yolo_area = (yolo_box[2]-yolo_box[0]) * (yolo_box[3]-yolo_box[1])
            improvement = ((yolo_area - rect_area) / yolo_area) * 100
            print(f"\n🎯 Improvement: {improvement:.1f}% tighter than YOLO box")

        # Save annotated image
        annotated_base64 = result.get('annotated_image', '')
        if annotated_base64:
            annotated_data = base64.b64decode(annotated_base64)
            annotated_img = cv2.imdecode(
                np.frombuffer(annotated_data, np.uint8),
                cv2.IMREAD_COLOR
            )

            output_path = Path(image_path).stem + "_annotated.jpg"
            cv2.imwrite(output_path, annotated_img)
            print(f"\n💾 Saved annotated image: {output_path}")
            print(f"   → Red box = YOLO (rough localization)")
            print(f"   → Green polygon = Rotated box (precise edges)")
            print(f"   → Blue contour = Detected edge contour")

        print("\n" + result.get('message', ''))

    except requests.exceptions.RequestException as e:
        print(f"❌ Connection error: {e}")
        print(f"   Make sure server is running at {server_url}")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()


def main():
    if len(sys.argv) < 2:
        print("Usage: python test_rotated_detection.py <image_path> [server_url]")
        print("\nExample:")
        print("  python test_rotated_detection.py medicine_label.jpg")
        print("  python test_rotated_detection.py medicine_label.jpg http://192.168.1.100:8000")
        sys.exit(1)

    image_path = sys.argv[1]
    server_url = sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8000"

    # Check if server is running
    try:
        response = requests.get(server_url, timeout=5)
        server_info = response.json()
        print(f"\n✅ Server online: {server_info.get('model', 'Unknown')}")
        print(f"   Version: {server_info.get('version', 'Unknown')}")
        print(f"   Device: {server_info.get('device', 'Unknown')}")
    except:
        print(f"\n⚠️  Warning: Could not connect to server at {server_url}")
        print("   Make sure to start the server first:")
        print("   python backend_server.py")
        sys.exit(1)

    test_image(image_path, server_url)
    print("\n" + "="*70 + "\n")


if __name__ == "__main__":
    main()
