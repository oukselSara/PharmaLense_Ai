# Medication Label Detector - Modular Version

A Python application that detects and extracts information from pharmaceutical labels in images. This version has separated modules for easy editing and maintenance.

## 📁 Project Structure

```
medication_label_detector/
├── main.py                          # Main script (asks for image path)
├── requirements.txt                 # Python dependencies
├── README.md                        # This file
│
├── label_detection/                 # Label detection module
│   ├── __init__.py
│   └── label_detector.py           # Detects labels in images
│
└── text_extraction/                 # Text extraction module
    ├── __init__.py
    └── text_extractor.py           # Extracts text and parses info
```

## 🎯 Features

### Label Detection Module (`label_detection/`)
- Detects rectangular medication labels in images
- Uses computer vision (OpenCV) techniques
- Adjustable detection parameters
- Visualization with bounding boxes
- Can be used independently

### Text Extraction Module (`text_extraction/`)
- Extracts text using Tesseract OCR
- Multi-language support (French, Arabic, English)
- Parses medication information:
  - Medication name
  - Dosage/strength
  - Lot number
  - Expiry date
  - Price (DA)
  - Manufacturer
- Can be used independently

## 🚀 Installation

### 1. Install System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y tesseract-ocr tesseract-ocr-fra tesseract-ocr-ara
```

**macOS:**
```bash
brew install tesseract tesseract-lang
```

**Windows:**
Download and install Tesseract from: https://github.com/UB-Mannheim/tesseract/wiki

### 2. Install Python Dependencies

```bash
pip install -r requirements.txt
```

**Recommended Python Version: 3.10 or 3.11**

## 📖 Usage

### Main Application (Interactive)

Simply run the main script and it will ask you for the image path:

```bash
python main.py
```

You'll be prompted:
```
Please enter the path to your image: 
```

Just paste the path to your image and press Enter!

### Example Output

```
MEDICATION LABEL DETECTOR & TEXT EXTRACTOR
============================================================

Please enter the path to your image: /home/user/medication.jpg

✅ Image found: /home/user/medication.jpg
Processing...

STEP 1: DETECTING LABELS
------------------------------------------------------------
✅ Found 1 label(s)

STEP 2: EXTRACTING TEXT FROM LABELS
------------------------------------------------------------

Processing Label 1/1...
  ✓ Medication: Doliprane
  ✓ Dosage: 500 mg
  ✓ Lot Number: 463DA
  ✓ Expiry Date: 03/2027
  ✓ Price: 258,23 DA

============================================================
SAVING RESULTS
============================================================
✅ Visualization saved: /home/user/medication_detected.jpg
✅ Text results saved: /home/user/medication_results.txt

============================================================
SUMMARY
============================================================
Total labels detected: 1
Visualization: /home/user/medication_detected.jpg
Text results: /home/user/medication_results.txt

✅ Processing complete!
```

## 🛠️ Using Modules Independently

### Label Detection Module Only

```python
from label_detection import LabelDetector

# Create detector
detector = LabelDetector(min_area=5000, max_area=500000)

# Detect labels
labels, vis_img = detector.detect_labels('image.jpg', visualize=True)

print(f"Found {len(labels)} labels")
for idx, (x, y, w, h) in enumerate(labels):
    print(f"Label {idx+1}: position=({x},{y}), size={w}x{h}")

# Save visualization
detector.save_visualization(vis_img, 'output.jpg')
```

**Or run standalone:**
```bash
cd label_detection
python label_detector.py ../path/to/image.jpg
```

### Text Extraction Module Only

```python
from text_extraction import TextExtractor

# Create extractor
extractor = TextExtractor(languages='fra+ara+eng')

# Extract from a specific region
bbox = (100, 100, 300, 200)  # (x, y, width, height)
result = extractor.extract_and_parse('image.jpg', bbox)

print(f"Medication: {result['name']}")
print(f"Dosage: {result['dosage']}")
print(f"Lot: {result['lot_number']}")
print(f"Expiry: {result['expiry_date']}")
print(f"Price: {result['price']}")
```

**Or run standalone:**
```bash
cd text_extraction
python text_extractor.py ../image.jpg 100 100 300 200
```

## ⚙️ Customization

### Adjusting Label Detection

Edit `label_detection/label_detector.py`:

```python
# In __init__ method, change these parameters:
self.min_area = 3000      # Smaller labels
self.max_area = 800000    # Larger labels
```

Or adjust at runtime:
```python
detector = LabelDetector()
detector.adjust_parameters(min_area=3000, max_area=800000)
```

### Changing OCR Languages

Edit `text_extraction/text_extractor.py`:

```python
# In __init__ method:
self.languages = 'fra+ara+eng'  # Change languages here
```

Or at runtime:
```python
extractor = TextExtractor()
extractor.set_languages('eng')  # English only
```

### Modifying Parsing Patterns

In `text_extraction/text_extractor.py`, you can edit the parsing methods:
- `parse_medication_name()` - Extract medication names
- `parse_dosage()` - Extract dosage patterns
- `parse_lot_number()` - Extract lot numbers
- `parse_expiry_date()` - Extract expiry dates
- `parse_price()` - Extract prices
- `parse_manufacturer()` - Extract manufacturer names

Each method uses regex patterns that you can customize.

## 📝 Output Files

When you run `main.py`, it creates:

1. **Visualization Image**: `<original_name>_detected.jpg`
   - Original image with green bounding boxes around detected labels
   - Numbered labels for easy reference

2. **Text Results**: `<original_name>_results.txt`
   - All extracted information in readable format
   - Full OCR text for each label

## 🐛 Troubleshooting

### "pytesseract not found" error
- Ensure Tesseract OCR is installed
- On Windows, set the path in `text_extractor.py`:
  ```python
  pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
  ```

### No labels detected
- Adjust `min_area` and `max_area` parameters
- Ensure good lighting and focus in photos
- Check that labels have clear edges

### Poor text extraction
- Make sure correct language packs are installed for Tesseract
- Take photos straight-on (not at angles)
- Ensure labels are in focus
- Good lighting helps significantly

### ModuleNotFoundError
Make sure you're running from the project root directory (where `main.py` is located)

## 📦 Requirements

- **Python**: 3.10 or 3.11 (recommended)
- **OpenCV**: For image processing
- **NumPy**: For array operations
- **Pytesseract**: Python wrapper for Tesseract
- **Pillow**: Image handling
- **Tesseract OCR**: System dependency for text recognition

## 🎓 Development Tips

1. **Testing label detection**: Run the module standalone first to verify detection
2. **Testing text extraction**: Use the standalone mode with known coordinates
3. **Debugging**: Check intermediate outputs (preprocessed images, raw OCR text)
4. **Adding features**: Each module is independent - modify without breaking the other

## 📄 License

MIT License

## 🤝 Contributing

Feel free to modify and enhance! The modular structure makes it easy to:
- Improve detection algorithms
- Add new parsing patterns
- Support additional languages
- Enhance preprocessing techniques
