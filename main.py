"""
Main Pipeline - Integrated Medication Label Processor
Detects labels, extracts text, classifies information, and saves all results
"""

import sys
from pathlib import Path
from datetime import datetime
import json

# Import the updated modules
from label_detection.label_detector import LabelDetector
from text_extraction.text_extractor import TextExtractor
from Classifier.reberta_med_classification import ClassificateurMedicamentsAlgerien

class MedicationLabelPipeline:
    """Complete pipeline for medication label processing"""
    
    def __init__(self, results_dir="results"):
        """
        Initialize the complete pipeline
        
        Args:
            results_dir: Directory where all results will be saved
        """
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        
        # Create subdirectory for complete results
        (self.results_dir / "complete").mkdir(exist_ok=True)
        
        print("="*70)
        print("  🏥 PIPELINE DE TRAITEMENT DES ÉTIQUETTES DE MÉDICAMENTS")
        print("="*70)
        print(f"\n📁 Dossier de résultats: {self.results_dir.absolute()}\n")
        
        # Initialize all components
        print("🔧 Initialisation des modules...")
        self.detector = LabelDetector(results_dir=results_dir)
        self.extractor = TextExtractor(results_dir=results_dir)
        self.classifier = ClassificateurMedicamentsAlgerien(results_dir=results_dir)
        print("✓ Tous les modules initialisés\n")
    
    def process_single_image(self, image_path: str, auto_save: bool = True):
        """
        Process a single image through the complete pipeline
        
        Args:
            image_path: Path to the medication label image
            auto_save: Whether to automatically save results
            
        Returns:
            Dictionary with all processed results
        """
        print("="*70)
        print(f"📸 TRAITEMENT: {Path(image_path).name}")
        print("="*70)
        
        results = {
            'image_path': str(image_path),
            'timestamp': datetime.now().isoformat(),
            'steps': {}
        }
        
        # Step 1: Detect labels
        print("\n[1/3] 🔍 DÉTECTION DES ÉTIQUETTES")
        print("-"*70)
        labels, vis_img, extracted = self.detector.detect_labels(
            image_path, 
            visualize=True, 
            extract=True, 
            save_results=auto_save
        )
        
        results['steps']['detection'] = {
            'num_labels': len(labels),
            'bounding_boxes': [
                {'x': x, 'y': y, 'width': w, 'height': h} 
                for x, y, w, h in labels
            ]
        }
        
        if len(labels) == 0:
            print("\n⚠️  Aucune étiquette détectée!")
            return results
        
        # Step 2: Extract text from each label
        print(f"\n[2/3] 📝 EXTRACTION DE TEXTE ({len(labels)} étiquettes)")
        print("-"*70)
        ocr_results = []
        
        for idx, bbox in enumerate(labels, 1):
            print(f"\n   Étiquette {idx}:")
            try:
                info = self.extractor.extract_and_parse(
                    image_path, 
                    bbox, 
                    save_results=auto_save
                )
                ocr_results.append(info)
                
                # Display extracted info
                print(f"      • Nom: {info.get('name', 'N/A')}")
                print(f"      • Dosage: {info.get('dosage', 'N/A')}")
                print(f"      • Lot: {info.get('lot_number', 'N/A')}")
                print(f"      • Exp: {info.get('expiry_date', 'N/A')}")
                
            except Exception as e:
                print(f"      ❌ Erreur OCR: {e}")
                ocr_results.append({'error': str(e)})
        
        results['steps']['ocr'] = ocr_results
        
        # Step 3: Classify with Algerian classifier
        print(f"\n[3/3] 🧬 CLASSIFICATION ALGÉRIENNE")
        print("-"*70)
        classified_results = []
        
        for idx, ocr_info in enumerate(ocr_results, 1):
            if 'error' in ocr_info:
                classified_results.append({'error': ocr_info['error']})
                continue
            
            print(f"\n   Étiquette {idx}:")
            text = ocr_info.get('full_text', '')
            
            if text:
                try:
                    entities = self.classifier.predire(text)
                    classified_results.append(entities)
                    
                    # Display key classified info
                    if entities.get('nom_medicament'):
                        print(f"      • Médicament: {entities['nom_medicament'][0]}")
                    if entities.get('entreprise'):
                        print(f"      • Fabricant: {entities['entreprise'][0]}")
                    if entities.get('dosage'):
                        print(f"      • Dosage: {', '.join(entities['dosage'])}")
                    
                except Exception as e:
                    print(f"      ❌ Erreur classification: {e}")
                    classified_results.append({'error': str(e)})
            else:
                classified_results.append({'error': 'No text to classify'})
        
        results['steps']['classification'] = classified_results
        
        # Save complete results
        if auto_save:
            self._save_complete_results(results, image_path)
        
        print("\n" + "="*70)
        print("✅ TRAITEMENT TERMINÉ")
        print("="*70)
        
        return results
    
    def _save_complete_results(self, results: dict, image_path: str):
        """
        Save complete pipeline results
        
        Args:
            results: Complete results dictionary
            image_path: Path to source image
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        image_name = Path(image_path).stem
        
        # Save as JSON
        json_path = self.results_dir / "complete" / f"{image_name}_{timestamp}_complete.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        print(f"\n💾 Résultats complets sauvegardés: {json_path}")
        
        # Save as formatted text report
        text_path = self.results_dir / "complete" / f"{image_name}_{timestamp}_report.txt"
        with open(text_path, 'w', encoding='utf-8') as f:
            f.write("="*70 + "\n")
            f.write("RAPPORT COMPLET D'ANALYSE DE MÉDICAMENT\n")
            f.write("="*70 + "\n\n")
            f.write(f"Image source: {results['image_path']}\n")
            f.write(f"Date d'analyse: {results['timestamp']}\n")
            f.write(f"Étiquettes détectées: {results['steps']['detection']['num_labels']}\n")
            f.write("\n" + "="*70 + "\n")
            
            # Write details for each label
            num_labels = results['steps']['detection']['num_labels']
            for idx in range(num_labels):
                f.write(f"\nÉTIQUETTE #{idx + 1}\n")
                f.write("-"*70 + "\n")
                
                # OCR results
                if idx < len(results['steps']['ocr']):
                    ocr = results['steps']['ocr'][idx]
                    if 'error' not in ocr:
                        f.write("\n📝 INFORMATIONS OCR:\n")
                        f.write(f"  Nom: {ocr.get('name', 'N/A')}\n")
                        f.write(f"  Dosage: {ocr.get('dosage', 'N/A')}\n")
                        f.write(f"  Lot: {ocr.get('lot_number', 'N/A')}\n")
                        f.write(f"  Expiration: {ocr.get('expiry_date', 'N/A')}\n")
                        f.write(f"  Prix: {ocr.get('price', 'N/A')}\n")
                        f.write(f"  Fabricant: {ocr.get('manufacturer', 'N/A')}\n")
                
                # Classification results
                if idx < len(results['steps']['classification']):
                    classified = results['steps']['classification'][idx]
                    if 'error' not in classified:
                        f.write("\n🧬 CLASSIFICATION ALGÉRIENNE:\n")
                        for key, values in classified.items():
                            if values:
                                f.write(f"  {key}: {', '.join(str(v) for v in values)}\n")
                
                f.write("\n")
        
        print(f"📄 Rapport textuel sauvegardé: {text_path}")
    
    def process_batch(self, image_paths: list):
        """
        Process multiple images
        
        Args:
            image_paths: List of image paths
        """
        print("\n" + "="*70)
        print(f"📦 TRAITEMENT PAR LOT: {len(image_paths)} images")
        print("="*70 + "\n")
        
        all_results = []
        
        for idx, image_path in enumerate(image_paths, 1):
            print(f"\n{'='*70}")
            print(f"Image {idx}/{len(image_paths)}")
            print('='*70)
            
            try:
                results = self.process_single_image(image_path, auto_save=True)
                all_results.append(results)
            except Exception as e:
                print(f"❌ Erreur lors du traitement: {e}")
                all_results.append({
                    'image_path': str(image_path),
                    'error': str(e)
                })
        
        # Save batch summary
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        batch_path = self.results_dir / "complete" / f"batch_summary_{timestamp}.json"
        
        batch_summary = {
            'timestamp': datetime.now().isoformat(),
            'total_images': len(image_paths),
            'successful': sum(1 for r in all_results if 'error' not in r),
            'failed': sum(1 for r in all_results if 'error' in r),
            'results': all_results
        }
        
        with open(batch_path, 'w', encoding='utf-8') as f:
            json.dump(batch_summary, f, indent=2, ensure_ascii=False)
        
        print("\n" + "="*70)
        print("📊 RÉSUMÉ DU LOT")
        print("="*70)
        print(f"Total d'images: {batch_summary['total_images']}")
        print(f"Réussi: {batch_summary['successful']}")
        print(f"Échoué: {batch_summary['failed']}")
        print(f"Résumé sauvegardé: {batch_path}")
        print("="*70 + "\n")
        
        return all_results


def main():
    """Main entry point"""
    
    print("\n" + "="*70)
    print("  🏥 PIPELINE DE TRAITEMENT DES ÉTIQUETTES DE MÉDICAMENTS")
    print("="*70 + "\n")
    
    # Check if image paths provided via command line
    if len(sys.argv) > 1:
        # Use command line arguments
        image_paths = sys.argv[1:]
        print(f"📋 Images fournies via ligne de commande: {len(image_paths)}")
    else:
        # Interactive mode - ask user for image paths
        print("📸 MODE INTERACTIF")
        print("-"*70)
        print("\nOptions:")
        print("  1. Traiter une seule image")
        print("  2. Traiter plusieurs images (batch)")
        print("  3. Quitter")
        
        while True:
            choice = input("\n➤ Votre choix (1/2/3): ").strip()
            
            if choice == '3':
                print("\n👋 Au revoir!")
                return
            
            if choice == '1':
                # Single image
                print("\n📁 Entrez le chemin de l'image:")
                image_path = input("➤ Chemin: ").strip()
                
                # Remove quotes if user added them
                image_path = image_path.strip('"').strip("'")
                
                if not image_path:
                    print("❌ Chemin vide! Réessayez.")
                    continue
                
                # Check if file exists
                if not Path(image_path).exists():
                    print(f"❌ Fichier introuvable: {image_path}")
                    retry = input("Réessayer? (o/n): ").strip().lower()
                    if retry != 'o':
                        continue
                    else:
                        continue
                
                image_paths = [image_path]
                break
                
            elif choice == '2':
                # Multiple images
                print("\n📁 Entrez les chemins des images (séparés par des virgules):")
                print("   Exemple: img1.jpg, img2.jpg, img3.jpg")
                paths_input = input("➤ Chemins: ").strip()
                
                if not paths_input:
                    print("❌ Aucun chemin fourni! Réessayez.")
                    continue
                
                # Split by comma and clean up
                image_paths = [p.strip().strip('"').strip("'") for p in paths_input.split(',')]
                
                # Check which files exist
                valid_paths = []
                invalid_paths = []
                
                for path in image_paths:
                    if Path(path).exists():
                        valid_paths.append(path)
                    else:
                        invalid_paths.append(path)
                
                if invalid_paths:
                    print(f"\n⚠️  Fichiers introuvables ({len(invalid_paths)}):")
                    for p in invalid_paths:
                        print(f"   • {p}")
                
                if not valid_paths:
                    print("\n❌ Aucun fichier valide trouvé!")
                    retry = input("Réessayer? (o/n): ").strip().lower()
                    if retry == 'o':
                        continue
                    else:
                        return
                
                print(f"\n✓ Fichiers valides trouvés: {len(valid_paths)}")
                confirm = input("Continuer avec ces fichiers? (o/n): ").strip().lower()
                
                if confirm == 'o':
                    image_paths = valid_paths
                    break
                else:
                    continue
            else:
                print("❌ Choix invalide! Entrez 1, 2 ou 3.")
    
    # Initialize pipeline
    print("\n🔧 Initialisation du pipeline...")
    pipeline = MedicationLabelPipeline(results_dir="results")
    
    # Process single or multiple images
    if len(image_paths) == 1:
        pipeline.process_single_image(image_paths[0], auto_save=True)
    else:
        pipeline.process_batch(image_paths)
    
    print("\n" + "="*70)
    print("✅ TERMINÉ!")
    print(f"📁 Tous les résultats sont dans le dossier: results/")
    print("="*70)


if __name__ == "__main__":
    main()