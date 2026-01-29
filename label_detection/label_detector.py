"""
Label Detection Module
Detects medication labels in images using computer vision techniques
"""

import cv2
import numpy as np
from typing import List, Tuple


class LabelDetector:
    """Detects rectangular labels in images"""
    
    def __init__(self, min_area=5000, max_area=500000):
        """
        Initialize the label detector
        
        Args:
            min_area: Minimum area for label detection (in pixels)
            max_area: Maximum area for label detection (in pixels)
        """
        self.min_area = min_area
        self.max_area = max_area
    
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
    
    def detect_labels(self, image_path: str, visualize: bool = False) -> Tuple[List[Tuple[int, int, int, int]], np.ndarray]:
        """
        Main function to detect labels in an image
        
        Args:
            image_path: Path to input image
            visualize: Whether to create visualization
            
        Returns:
            Tuple of (list of bounding boxes, visualization image or None)
        """
        # Load image
        img = self.load_image(image_path)
        
        # Preprocess
        binary = self.preprocess_for_detection(img)
        
        # Find labels
        labels = self.find_label_contours(binary)
        
        # Create visualization if requested
        vis_img = None
        if visualize:
            vis_img = self.draw_labels(img, labels)
        
        return labels, vis_img
    
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
    labels, vis_img = detector.detect_labels(sys.argv[1], visualize=True)
    
    print(f"Detected {len(labels)} labels:")
    for idx, (x, y, w, h) in enumerate(labels, 1):
        print(f"  Label {idx}: position=({x}, {y}), size=({w}x{h})")
    
    if vis_img is not None:
        output_path = sys.argv[1].replace('.jpg', '_labels.jpg').replace('.png', '_labels.png')
        detector.save_visualization(vis_img, output_path)
        print(f"\nVisualization saved to: {output_path}")
