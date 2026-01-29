"""
Text Extraction Module (Updated)
Extracts and parses text from medication labels using OCR and saves results
"""

import cv2
import numpy as np
from typing import Tuple, Dict
import pytesseract
from PIL import Image
import re
import os
from pathlib import Path
from datetime import datetime
import json

# Configure pytesseract to use the Tesseract executable
# This will need to be adjusted based on the system
try:
    pytesseract.pytesseract.pytesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
except:
    pass  # On Linux, tesseract should be in PATH


class TextExtractor:
    """Extracts text from image regions, parses medication information, and saves results"""
    
    def __init__(self, languages='fra+ara+eng', results_dir='results'):
        """
        Initialize the text extractor
        
        Args:
            languages: Languages for OCR (default: French, Arabic, English)
            results_dir: Directory where results will be saved
        """
        self.languages = languages
        self.ocr_config = '--psm 6'  # Assume uniform text block
        
        # Create results directory structure
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        (self.results_dir / "ocr").mkdir(exist_ok=True)
        (self.results_dir / "parsed").mkdir(exist_ok=True)
        (self.results_dir / "json").mkdir(exist_ok=True)
        (self.results_dir / "text").mkdir(exist_ok=True)
        
        print(f"📁 Résultats OCR seront sauvegardés dans: {self.results_dir.absolute()}")
        
        self._verify_tesseract()
    
    def _verify_tesseract(self):
        """Verify that Tesseract is properly installed"""
        try:
            version = pytesseract.get_tesseract_version()
            print(f"✓ Tesseract-OCR version: {version}")
        except Exception as e:
            print(f"⚠️  Tesseract-OCR may not be properly installed: {e}")
            print("   Install from: https://github.com/UB-Mannheim/tesseract/wiki")
    
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
    
    def save_ocr_results(self, info: Dict[str, str], image_name: str, bbox: Tuple[int, int, int, int]):
        """
        Save OCR and parsing results to files
        
        Args:
            info: Parsed medication information
            image_name: Name of source image
            bbox: Bounding box that was processed
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_name = f"{Path(image_name).stem}_{timestamp}"
        
        # Save raw OCR text
        text_path = self.results_dir / "ocr" / f"{base_name}_raw_ocr.txt"
        with open(text_path, 'w', encoding='utf-8') as f:
            f.write(info['full_text'])
        print(f"   ✅ OCR brut sauvegardé: {text_path}")
        
        # Save parsed information as formatted text
        parsed_text_path = self.results_dir / "text" / f"{base_name}_parsed.txt"
        with open(parsed_text_path, 'w', encoding='utf-8') as f:
            f.write("="*60 + "\n")
            f.write("INFORMATIONS EXTRAITES DU MÉDICAMENT\n")
            f.write("="*60 + "\n\n")
            f.write(f"Nom: {info['name'] or 'Non trouvé'}\n")
            f.write(f"Dosage: {info['dosage'] or 'Non trouvé'}\n")
            f.write(f"Numéro de lot: {info['lot_number'] or 'Non trouvé'}\n")
            f.write(f"Date de péremption: {info['expiry_date'] or 'Non trouvé'}\n")
            f.write(f"Prix: {info['price'] or 'Non trouvé'}\n")
            f.write(f"Fabricant: {info['manufacturer'] or 'Non trouvé'}\n")
            f.write(f"\n{'='*60}\n")
            f.write("TEXTE COMPLET\n")
            f.write("="*60 + "\n")
            f.write(info['full_text'])
        print(f"   ✅ Analyse formatée sauvegardée: {parsed_text_path}")
        
        # Save as JSON
        json_data = {
            'timestamp': datetime.now().isoformat(),
            'source_image': image_name,
            'bbox': {'x': bbox[0], 'y': bbox[1], 'width': bbox[2], 'height': bbox[3]},
            'extracted_info': {k: v for k, v in info.items() if k != 'full_text'},
            'raw_text': info['full_text']
        }
        
        json_path = self.results_dir / "json" / f"{base_name}_ocr.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, indent=2, ensure_ascii=False)
        print(f"   ✅ JSON sauvegardé: {json_path}")
    
    def extract_and_parse(self, image_path: str, bbox: Tuple[int, int, int, int], 
                         save_results: bool = True) -> Dict[str, str]:
        """
        Main function to extract text and parse medication information
        
        Args:
            image_path: Path to the image
            bbox: Bounding box of the label (x, y, w, h)
            save_results: Whether to save results to disk
            
        Returns:
            Dictionary with parsed medication information
        """
        print(f"\n🔍 Extraction de texte depuis: {image_path}")
        print(f"   • Zone: x={bbox[0]}, y={bbox[1]}, w={bbox[2]}, h={bbox[3]}")
        
        # Extract ROI
        roi = self.extract_roi(image_path, bbox)
        
        # Preprocess for OCR
        preprocessed = self.preprocess_for_ocr(roi)
        
        # Perform OCR
        text = self.perform_ocr(preprocessed)
        print(f"   ✓ Texte extrait ({len(text)} caractères)")
        
        # Parse information
        info = self.parse_all_info(text)
        
        # Save results if requested
        if save_results:
            self.save_ocr_results(info, image_path, bbox)
        
        return info
    
    def batch_extract(self, image_path: str, bboxes: list, save_results: bool = True) -> list:
        """
        Extract text from multiple regions in a single image
        
        Args:
            image_path: Path to the image
            bboxes: List of bounding boxes
            save_results: Whether to save results
            
        Returns:
            List of parsed information dictionaries
        """
        results = []
        
        print(f"\n📦 Traitement batch: {len(bboxes)} régions")
        
        for idx, bbox in enumerate(bboxes, 1):
            print(f"\n--- Région {idx}/{len(bboxes)} ---")
            try:
                info = self.extract_and_parse(image_path, bbox, save_results)
                results.append(info)
            except Exception as e:
                print(f"   ❌ Erreur: {e}")
                results.append({'error': str(e)})
        
        # Save batch summary
        if save_results and results:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            batch_path = self.results_dir / "json" / f"batch_{timestamp}.json"
            batch_data = {
                'timestamp': datetime.now().isoformat(),
                'source_image': image_path,
                'num_regions': len(bboxes),
                'results': results
            }
            with open(batch_path, 'w', encoding='utf-8') as f:
                json.dump(batch_data, f, indent=2, ensure_ascii=False)
            print(f"\n✅ Résumé batch sauvegardé: {batch_path}")
        
        return results
    
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
    
    print("\n" + "="*60)
    print("INFORMATIONS EXTRAITES")
    print("="*60)
    print(f"Nom: {result['name']}")
    print(f"Dosage: {result['dosage']}")
    print(f"Numéro de lot: {result['lot_number']}")
    print(f"Date de péremption: {result['expiry_date']}")
    print(f"Prix: {result['price']}")
    print(f"Fabricant: {result['manufacturer']}")
    print(f"\nTexte complet:\n{result['full_text']}")