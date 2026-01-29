#!/usr/bin/env python3
"""
Main script for Medication Label Detection and Text Extraction
This script coordinates between label detection and text extraction modules
"""

import os
import sys

# Add modules to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'label_detection'))
sys.path.append(os.path.join(os.path.dirname(__file__), 'text_extraction'))

from label_detector import LabelDetector
from text_extractor import TextExtractor


def main():
    """Main function that asks for image path and processes it"""
    
    print("=" * 60)
    print("MEDICATION LABEL DETECTOR & TEXT EXTRACTOR")
    print("=" * 60)
    print()
    
    # Ask user for image path
    image_path = input("Please enter the path to your image: ").strip()
    
    # Remove quotes if user wrapped path in quotes
    image_path = image_path.strip('"').strip("'")
    
    # Check if file exists
    if not os.path.exists(image_path):
        print(f"\n❌ Error: Image file not found: {image_path}")
        print("Please check the path and try again.")
        sys.exit(1)
    
    # Check if it's a valid image file
    valid_extensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tiff']
    file_ext = os.path.splitext(image_path)[1].lower()
    if file_ext not in valid_extensions:
        print(f"\n❌ Error: Invalid image format: {file_ext}")
        print(f"Supported formats: {', '.join(valid_extensions)}")
        sys.exit(1)
    
    print(f"\n✅ Image found: {image_path}")
    print(f"Processing...\n")
    
    # Step 1: Detect labels
    print("STEP 1: DETECTING LABELS")
    print("-" * 60)
    
    detector = LabelDetector()
    labels, vis_image = detector.detect_labels(image_path, visualize=True)
    
    print(f"✅ Found {len(labels)} label(s)\n")
    
    if len(labels) == 0:
        print("❌ No labels detected in the image.")
        print("Tips:")
        print("  - Ensure the label is clearly visible")
        print("  - Check lighting and focus")
        print("  - Try a different angle")
        sys.exit(0)
    
    # Step 2: Extract text from each label
    print("STEP 2: EXTRACTING TEXT FROM LABELS")
    print("-" * 60)
    
    extractor = TextExtractor()
    results = []
    
    for idx, bbox in enumerate(labels, 1):
        print(f"\nProcessing Label {idx}/{len(labels)}...")
        
        # Extract text and parse information
        result = extractor.extract_and_parse(image_path, bbox)
        result['label_number'] = idx
        results.append(result)
        
        # Print extracted information
        print(f"  ✓ Medication: {result['name'] or 'Not detected'}")
        print(f"  ✓ Dosage: {result['dosage'] or 'Not detected'}")
        print(f"  ✓ Lot Number: {result['lot_number'] or 'Not detected'}")
        print(f"  ✓ Expiry Date: {result['expiry_date'] or 'Not detected'}")
        print(f"  ✓ Price: {result['price'] or 'Not detected'}")
    
    # Step 3: Save visualization
    print("\n" + "=" * 60)
    print("SAVING RESULTS")
    print("=" * 60)
    
    # Save visualization image
    output_dir = os.path.dirname(image_path) or '.'
    base_name = os.path.splitext(os.path.basename(image_path))[0]
    output_image_path = os.path.join(output_dir, f"{base_name}_detected.jpg")
    
    detector.save_visualization(vis_image, output_image_path)
    print(f"✅ Visualization saved: {output_image_path}")
    
    # Save text results
    output_text_path = os.path.join(output_dir, f"{base_name}_results.txt")
    save_results_to_file(results, output_text_path)
    print(f"✅ Text results saved: {output_text_path}")
    
    # Final summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total labels detected: {len(results)}")
    print(f"Visualization: {output_image_path}")
    print(f"Text results: {output_text_path}")
    print("\n✅ Processing complete!")


def save_results_to_file(results, filepath):
    """Save extracted results to a text file"""
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write("MEDICATION LABEL EXTRACTION RESULTS\n")
        f.write("=" * 60 + "\n\n")
        
        for result in results:
            f.write(f"Label {result['label_number']}:\n")
            f.write("-" * 40 + "\n")
            f.write(f"Medication Name: {result['name'] or 'Not detected'}\n")
            f.write(f"Dosage/Strength: {result['dosage'] or 'Not detected'}\n")
            f.write(f"Lot Number: {result['lot_number'] or 'Not detected'}\n")
            f.write(f"Expiry Date: {result['expiry_date'] or 'Not detected'}\n")
            f.write(f"Price: {result['price'] or 'Not detected'}\n")
            f.write(f"Manufacturer: {result['manufacturer'] or 'Not detected'}\n")
            f.write(f"\nFull Text:\n{result['full_text']}\n")
            f.write("\n" + "=" * 60 + "\n\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Process interrupted by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ An error occurred: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)