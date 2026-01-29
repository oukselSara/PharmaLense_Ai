"""
Label Detection Module (Updated)
Detects medication labels in images and saves results to results folder
"""

import cv2
import numpy as np
from typing import List, Tuple
from pathlib import Path
from datetime import datetime
import json


class LabelDetector:
    """Detects rectangular labels in images and saves results"""
    
    def __init__(self, min_area=5000, max_area=500000, results_dir="results"):
        """
        Initialize the label detector
        
        Args:
            min_area: Minimum area for label detection (in pixels)
            max_area: Maximum area for label detection (in pixels)
            results_dir: Directory where results will be saved
        """
        self.min_area = min_area
        self.max_area = max_area
        
        # Create results directory structure
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        (self.results_dir / "detections").mkdir(exist_ok=True)
        (self.results_dir / "visualizations").mkdir(exist_ok=True)
        (self.results_dir / "json").mkdir(exist_ok=True)
        
        print(f"📁 Résultats seront sauvegardés dans: {self.results_dir.absolute()}")
    
    def load_image(self, image_path: str) -> np.ndarray:
        """
        Load an image from file
        
        Args:
            image_path: Path to the image file
            
        Returns:
            Loaded image as numpy array
        """
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Could not read image: {image_path}")
        return img
    
    def preprocess_for_detection(self, img: np.ndarray) -> np.ndarray:
        """
        Preprocess image for better label detection
        
        Args:
            img: Input image
            
        Returns:
            Preprocessed binary image
        """
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply bilateral filter to reduce noise while preserving edges
        filtered = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Apply adaptive thresholding
        thresh = cv2.adaptiveThreshold(
            filtered, 255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV, 11, 2
        )
        
        # Morphological operations to clean up and connect components
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        morph = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        return morph
    
    def find_label_contours(self, binary_img: np.ndarray) -> List[Tuple[int, int, int, int]]:
        """
        Find contours that likely represent labels
        
        Args:
            binary_img: Binary preprocessed image
            
        Returns:
            List of bounding boxes (x, y, w, h) for detected labels
        """
        # Find contours
        contours, _ = cv2.findContours(
            binary_img, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )
        
        labels = []
        
        for contour in contours:
            # Calculate contour area
            area = cv2.contourArea(contour)
            
            # Filter by area
            if self.min_area < area < self.max_area:
                # Get bounding rectangle
                x, y, w, h = cv2.boundingRect(contour)
                
                # Check aspect ratio (labels are usually rectangular)
                aspect_ratio = w / float(h)
                
                # Accept labels that are wider than tall or roughly square
                # Typical range for medication labels
                if 0.3 < aspect_ratio < 5.0:
                    labels.append((x, y, w, h))
        
        return labels
    
    def draw_labels(self, img: np.ndarray, labels: List[Tuple[int, int, int, int]]) -> np.ndarray:
        """
        Draw bounding boxes around detected labels
        
        Args:
            img: Original image
            labels: List of bounding boxes
            
        Returns:
            Image with drawn bounding boxes
        """
        vis_img = img.copy()
        
        for idx, (x, y, w, h) in enumerate(labels, 1):
            # Draw rectangle
            cv2.rectangle(vis_img, (x, y), (x+w, y+h), (0, 255, 0), 3)
            
            # Add label number
            cv2.putText(
                vis_img, f"Label {idx}",
                (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX,
                0.8, (0, 255, 0), 2
            )
            
            # Add dimensions
            cv2.putText(
                vis_img, f"{w}x{h}",
                (x, y + h + 25), cv2.FONT_HERSHEY_SIMPLEX,
                0.5, (0, 255, 0), 1
            )
        
        return vis_img
    
    def extract_label_regions(self, img: np.ndarray, labels: List[Tuple[int, int, int, int]]) -> List[np.ndarray]:
        """
        Extract individual label regions from the image
        
        Args:
            img: Original image
            labels: List of bounding boxes
            
        Returns:
            List of extracted label images
        """
        extracted = []
        for (x, y, w, h) in labels:
            roi = img[y:y+h, x:x+w]
            extracted.append(roi)
        return extracted
    
    def save_detection_results(self, image_path: str, labels: List[Tuple[int, int, int, int]], 
                               vis_img: np.ndarray = None, extracted_labels: List[np.ndarray] = None):
        """
        Save detection results to the results folder
        
        Args:
            image_path: Path to original image
            labels: List of detected bounding boxes
            vis_img: Visualization image with drawn boxes
            extracted_labels: List of extracted label regions
        """
        # Generate timestamp-based filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        image_name = Path(image_path).stem
        base_name = f"{image_name}_{timestamp}"
        
        # Save JSON with detection information
        detection_data = {
            'timestamp': datetime.now().isoformat(),
            'source_image': str(image_path),
            'num_labels_detected': len(labels),
            'labels': [
                {
                    'id': idx,
                    'x': x,
                    'y': y,
                    'width': w,
                    'height': h,
                    'area': w * h
                }
                for idx, (x, y, w, h) in enumerate(labels, 1)
            ]
        }
        
        json_path = self.results_dir / "json" / f"{base_name}_detection.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(detection_data, f, indent=2, ensure_ascii=False)
        print(f"   ✅ JSON sauvegardé: {json_path}")
        
        # Save visualization image
        if vis_img is not None:
            vis_path = self.results_dir / "visualizations" / f"{base_name}_annotated.jpg"
            cv2.imwrite(str(vis_path), vis_img)
            print(f"   ✅ Visualisation sauvegardée: {vis_path}")
        
        # Save individual extracted labels
        if extracted_labels is not None:
            for idx, label_img in enumerate(extracted_labels, 1):
                label_path = self.results_dir / "detections" / f"{base_name}_label_{idx}.jpg"
                cv2.imwrite(str(label_path), label_img)
            print(f"   ✅ {len(extracted_labels)} étiquettes extraites sauvegardées dans: {self.results_dir / 'detections'}")
    
    def detect_labels(self, image_path: str, visualize: bool = True, extract: bool = True, 
                     save_results: bool = True) -> Tuple[List[Tuple[int, int, int, int]], np.ndarray, List[np.ndarray]]:
        """
        Main function to detect labels in an image
        
        Args:
            image_path: Path to input image
            visualize: Whether to create visualization
            extract: Whether to extract individual labels
            save_results: Whether to save results to disk
            
        Returns:
            Tuple of (list of bounding boxes, visualization image, extracted labels)
        """
        print(f"\n🔍 Traitement de: {image_path}")
        
        # Load image
        img = self.load_image(image_path)
        
        # Preprocess
        binary = self.preprocess_for_detection(img)
        
        # Find labels
        labels = self.find_label_contours(binary)
        print(f"   ✓ {len(labels)} étiquettes détectées")
        
        # Create visualization if requested
        vis_img = None
        if visualize:
            vis_img = self.draw_labels(img, labels)
        
        # Extract individual labels if requested
        extracted_labels = None
        if extract:
            extracted_labels = self.extract_label_regions(img, labels)
        
        # Save results if requested
        if save_results:
            self.save_detection_results(image_path, labels, vis_img, extracted_labels)
        
        return labels, vis_img, extracted_labels
    
    def save_visualization(self, vis_img: np.ndarray, output_path: str):
        """
        Save visualization image to file
        
        Args:
            vis_img: Visualization image
            output_path: Output file path
        """
        if vis_img is not None:
            cv2.imwrite(output_path, vis_img)
    
    def adjust_parameters(self, min_area: int = None, max_area: int = None):
        """
        Adjust detection parameters
        
        Args:
            min_area: New minimum area
            max_area: New maximum area
        """
        if min_area is not None:
            self.min_area = min_area
        if max_area is not None:
            self.max_area = max_area


# Standalone testing
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python label_detector.py <image_path>")
        sys.exit(1)
    
    detector = LabelDetector()
    labels, vis_img, extracted = detector.detect_labels(sys.argv[1])
    
    print(f"\n📊 Résumé:")
    print(f"   • Étiquettes détectées: {len(labels)}")
    for idx, (x, y, w, h) in enumerate(labels, 1):
        print(f"   • Étiquette {idx}: position=({x}, {y}), taille=({w}x{h})")