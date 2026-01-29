"""
Text Extraction Module
Extracts and parses text from medication labels using OCR
"""

import cv2
import numpy as np
from typing import Tuple, Dict
import pytesseract
from PIL import Image
import re
import os

# Configure pytesseract to use the Tesseract executable
pytesseract.pytesseract.pytesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


class TextExtractor:
    """Extracts text from image regions and parses medication information"""
    
    def __init__(self, languages='fra+ara+eng'):
        """
        Initialize the text extractor
        
        Args:
            languages: Languages for OCR (default: French, Arabic, English)
        """
        self.languages = languages
        self.ocr_config = '--psm 6'  # Assume uniform text block
        self._verify_tesseract()
    
    def _verify_tesseract(self):
        """Verify that Tesseract is properly installed"""
        try:
            pytesseract.pytesseract.pytesseract_cmd
        except Exception as e:
            raise RuntimeError(
                f"Tesseract-OCR is not properly installed. "
                f"Please install it from: https://github.com/UB-Mannheim/tesseract/wiki\n"
                f"Error: {e}"
            )
    
    def extract_roi(self, image_path: str, bbox: Tuple[int, int, int, int]) -> np.ndarray:
        """
        Extract region of interest from image
        
        Args:
            image_path: Path to the image
            bbox: Bounding box (x, y, w, h)
            
        Returns:
            Extracted ROI as numpy array
        """
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Could not read image: {image_path}")
        
        x, y, w, h = bbox
        roi = img[y:y+h, x:x+w]
        
        return roi
    
    def preprocess_for_ocr(self, roi: np.ndarray) -> np.ndarray:
        """
        Preprocess ROI for better OCR results
        
        Args:
            roi: Region of interest
            
        Returns:
            Preprocessed image
        """
        # Convert to grayscale
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
        
        # Apply denoising
        denoised = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)
        
        # Apply OTSU thresholding
        _, thresh = cv2.threshold(
            denoised, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
        )
        
        # Get dimensions
        h, w = thresh.shape
        
        # Resize if too small (helps OCR accuracy)
        if w < 300 or h < 300:
            scale_factor = max(300 / w, 300 / h)
            new_w = int(w * scale_factor)
            new_h = int(h * scale_factor)
            thresh = cv2.resize(thresh, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
        
        return thresh
    
    def perform_ocr(self, preprocessed_img: np.ndarray) -> str:
        """
        Perform OCR on preprocessed image
        
        Args:
            preprocessed_img: Preprocessed image
            
        Returns:
            Extracted text
        """
        # Convert to PIL Image
        pil_img = Image.fromarray(preprocessed_img)
        
        # Perform OCR
        text = pytesseract.image_to_string(
            pil_img,
            lang=self.languages,
            config=self.ocr_config
        )
        
        return text.strip()
    
    def parse_medication_name(self, text: str) -> str:
        """Extract medication name from text"""
        # Try to find capitalized medication name at the start
        lines = text.split('\n')
        for line in lines[:5]:  # Check first 5 lines
            line = line.strip()
            # Look for words that are mostly uppercase or capitalized
            if line and len(line) > 2:
                # Check if it looks like a medication name
                if line[0].isupper() and any(c.isalpha() for c in line):
                    # Clean up the name
                    name = re.sub(r'[^\w\s\-]', '', line)
                    if name and len(name) > 2:
                        return name.strip()
        return ''
    
    def parse_dosage(self, text: str) -> str:
        """Extract dosage/strength information"""
        patterns = [
            r'(\d+[,.]?\d*\s*mg(?:/\s*\d+[,.]?\d*\s*mg)?)',  # mg dosage
            r'(\d+[,.]?\d*\s*ml)',  # ml volume
            r'(\d+[,.]?\d*\s*g)',   # grams
            r'(\d+[,.]?\d*\s*%)',   # percentage
            r'(\d+[,.]?\d*\s*mcg)', # micrograms
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        return ''
    
    def parse_lot_number(self, text: str) -> str:
        """Extract lot/batch number"""
        patterns = [
            r'LOT\s*[:\s]*([A-Z0-9\-]+)',
            r'Lot\s*[:\s]*([A-Z0-9\-]+)',
            r'N°\s*CODE\s*[:\s]*([A-Z0-9\-]+)',
            r'BATCH\s*[:\s]*([A-Z0-9\-]+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                lot_num = match.group(1).strip()
                if len(lot_num) > 2:  # Valid lot numbers are usually longer
                    return lot_num
        
        return ''
    
    def parse_expiry_date(self, text: str) -> str:
        """Extract expiry date"""
        patterns = [
            r'EXP\s*[:\s]*(\d{2}[/\-]\d{2}[/\-]?\d{2,4})',
            r'DE\s*[:\s]*(\d{2}[/\-]\d{2}[/\-]?\d{2,4})',
            r'DDP\s*[:\s]*(\d{2}[/\-]\d{2}[/\-]?\d{2,4})',
            r'Exp\s*[:\s]*(\d{2}[/\-]\d{2}[/\-]?\d{2,4})',
            r'(\d{2}[/\-]\d{4})',  # MM/YYYY format
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        return ''
    
    def parse_price(self, text: str) -> str:
        """Extract price in Algerian Dinar (DA)"""
        patterns = [
            r'(\d+[,.]?\d*)\s*DA',
            r'PPA\s*[:\s]*(\d+[,.]?\d*)',
            r'Prix\s*[:\s]*(\d+[,.]?\d*)',
            r'P\.P\.A\s*[:\s]*(\d+[,.]?\d*)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                price = match.group(1).strip()
                return f"{price} DA"
        
        return ''
    
    def parse_manufacturer(self, text: str) -> str:
        """Extract manufacturer information"""
        # Common Algerian pharmaceutical manufacturers
        manufacturers = [
            'SAIDAL', 'Biopharm', 'Antibiotical', 'LAPROPHAN',
            'Sanofi', 'Hikma', 'Pfizer', 'Novartis'
        ]
        
        for manufacturer in manufacturers:
            if manufacturer.lower() in text.lower():
                return manufacturer
        
        # Try to find company names with S.P.A or similar
        match = re.search(r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+S\.P\.A', text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
        
        return ''
    
    def parse_all_info(self, text: str) -> Dict[str, str]:
        """
        Parse all medication information from text
        
        Args:
            text: OCR extracted text
            
        Returns:
            Dictionary with all parsed information
        """
        return {
            'name': self.parse_medication_name(text),
            'dosage': self.parse_dosage(text),
            'lot_number': self.parse_lot_number(text),
            'expiry_date': self.parse_expiry_date(text),
            'price': self.parse_price(text),
            'manufacturer': self.parse_manufacturer(text),
            'full_text': text
        }
    
    def extract_and_parse(self, image_path: str, bbox: Tuple[int, int, int, int]) -> Dict[str, str]:
        """
        Main function to extract text and parse medication information
        
        Args:
            image_path: Path to the image
            bbox: Bounding box of the label (x, y, w, h)
            
        Returns:
            Dictionary with parsed medication information
        """
        # Extract ROI
        roi = self.extract_roi(image_path, bbox)
        
        # Preprocess for OCR
        preprocessed = self.preprocess_for_ocr(roi)
        
        # Perform OCR
        text = self.perform_ocr(preprocessed)
        
        # Parse information
        info = self.parse_all_info(text)
        
        return info
    
    def set_languages(self, languages: str):
        """
        Change OCR languages
        
        Args:
            languages: Language codes separated by '+' (e.g., 'fra+ara+eng')
        """
        self.languages = languages
    
    def set_ocr_config(self, config: str):
        """
        Change OCR configuration
        
        Args:
            config: Tesseract configuration string
        """
        self.ocr_config = config


# Standalone testing
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 5:
        print("Usage: python text_extractor.py <image_path> <x> <y> <w> <h>")
        print("Example: python text_extractor.py image.jpg 100 100 200 150")
        sys.exit(1)
    
    image_path = sys.argv[1]
    x, y, w, h = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    bbox = (x, y, w, h)
    
    extractor = TextExtractor()
    result = extractor.extract_and_parse(image_path, bbox)
    
    print("Extracted Information:")
    print("-" * 40)
    print(f"Name: {result['name']}")
    print(f"Dosage: {result['dosage']}")
    print(f"Lot Number: {result['lot_number']}")
    print(f"Expiry Date: {result['expiry_date']}")
    print(f"Price: {result['price']}")
    print(f"Manufacturer: {result['manufacturer']}")
    print(f"\nFull Text:\n{result['full_text']}")