import re
import json
from typing import Dict, List
from datetime import datetime
import os

class ClassificateurMedicamentsAlgerien:
    """Classificateur robuste pour OCR pharmaceutique algérien - gère n'importe quel ordre de texte et formats multi-lignes"""
    
    def __init__(self):
        print("🇩🇿 Classificateur Algérien initialisé\n")
        
        # Entreprises algériennes connues
        self.entreprises_algeriennes = {
            'SAIDAL', 'BIOCARE', 'BIOPHARM', 'HIKMA', 'PFIZER', 
            'SANOFI', 'BAYER', 'NOVARTIS', 'GSK', 'GLAXOSMITHKLINE',
            'BIOGALENIC', 'NADPHARMA', 'NADPHARMAGIC', 'VIGNETTE'
        }
        
        # Formes pharmaceutiques (français)
        self.formes_pharmaceutiques = {
            'comprimés', 'comprimé', 'comprimée', 'gélules', 'gélule', 
            'sirop', 'solution', 'suspension', 'crème', 'pommade', 
            'gel', 'injection', 'suppositoires', 'suppositoire', 
            'sachets', 'sachet', 'unidoses', 'quadrispersible',
            'pommade', 'collyre', 'gouttes'
        }
        
        # Mots-clés des principes actifs courants
        self.mots_cles_principes = {
            'sodique', 'chlorhydrate', 'sulfate', 'phosphate', 'base',
            'acide', 'sel', 'ester', 'sodium', 'potassium'
        }
    
    def normaliser_texte(self, texte: str) -> str:
        """Normaliser le texte multi-ligne en une seule ligne pour un meilleur parsing"""
        # Remplacer les espaces/sauts de ligne multiples par un espace simple
        texte = re.sub(r'\s+', ' ', texte)
        return texte.strip()
    
    def analyser_format_algerian(self, texte: str) -> Dict[str, List[str]]:
        """Analyser l'étiquette pharmaceutique algérienne - robuste à n'importe quel ordre et format"""
        
        entites = {
            'nom_medicament': [],
            'principe_actif': [],
            'dosage': [],
            'forme_pharmaceutique': [],
            'entreprise': [],
            'numero_lot': [],
            'date_fabrication': [],
            'date_peremption': [],
            'prix': [],
            'numero_enregistrement': []
        }
        
        # Normaliser le texte (gère l'entrée multi-ligne)
        texte_original = texte
        texte = self.normaliser_texte(texte)
        texte_maj = texte.upper()
        
        # ==================== ENTREPRISE ====================
        entreprise_trouvee = None
        for entreprise in self.entreprises_algeriennes:
            modeles = [
                rf'\b{entreprise}\b',
                rf'VIGNETTE[-\s]*{entreprise}',
                rf'{entreprise}[-\s]*VIGNETTE',
                rf'\b{entreprise}[-\s]+[A-Z]',
            ]
            for modele in modeles:
                if re.search(modele, texte_maj):
                    entites['entreprise'].append(entreprise)
                    entreprise_trouvee = entreprise
                    break
            if entreprise_trouvee:
                break
        
        # ==================== NOM DU MÉDICAMENT ====================
        nom_medicament = None
        
        # Stratégie 1: modèle ENTREPRISE-MEDICAMENT
        if entreprise_trouvee:
            modele = rf'{entreprise_trouvee}[-\s]+([A-Z][A-Z\s&\.]+?)(?:\s+\d+(?:\.\d+)?(?:mg|g|%)|(?:\s+-\s+)|(?:\s+L\.?P\.?))'
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                nom_medicament = correspondance.group(1).strip()
        
        # Stratégie 2: chercher le mot en majuscules avant le dosage
        if not nom_medicament:
            modele = r'\b([A-Z][A-Z]+(?:\s+[A-Z\.&LP]+)*)\s+\d+(?:\.\d+)?(?:mg|g|%)'
            correspondance = re.search(modele, texte)
            if correspondance:
                nom_potentiel = correspondance.group(1).strip()
                if nom_potentiel.upper() not in self.entreprises_algeriennes:
                    nom_medicament = nom_potentiel
        
        # Stratégie 3: chercher le modèle "dosage MEDICAMENT" ou "dosage MEDICAMENT"
        if not nom_medicament:
            modele = r'\d+(?:\.\d+)?\s*(?:mg|g|%|ml)\s+([A-Z][A-Z]+(?:\s+[A-Z\.&LP]+)*)'
            correspondance = re.search(modele, texte)
            if correspondance:
                nom_potentiel = correspondance.group(1).strip()
                if nom_potentiel.upper() not in self.entreprises_algeriennes and nom_potentiel.upper() not in ['VIGNETTE', 'PRIX', 'LOT', 'FAB', 'EXP', 'PER']:
                    nom_medicament = nom_potentiel
        
        # Stratégie 4: chercher un mot en majuscules à la FIN (format mélangé comme "... - CLAMOXYL")
        if not nom_medicament:
            modele = r'-\s+([A-Z]{3,}(?:\s+[A-Z\.&LP]+)*)\s*$'
            correspondance = re.search(modele, texte)
            if correspondance:
                nom_potentiel = correspondance.group(1).strip()
                if nom_potentiel.upper() not in self.entreprises_algeriennes and nom_potentiel.upper() not in ['VIGNETTE', 'PRIX', 'LOT', 'FAB', 'EXP', 'PER']:
                    nom_medicament = nom_potentiel
        
        # Stratégie 5: premier mot en majuscules qui n'est pas une entreprise
        if not nom_medicament:
            modele = r'\b([A-Z]{3,}(?:\s+[A-Z\.&LP]+)*)\b'
            correspondances = re.findall(modele, texte)
            for correspondance in correspondances:
                if correspondance.upper() not in self.entreprises_algeriennes and correspondance.upper() not in ['VIGNETTE', 'PRIX', 'LOT', 'FAB', 'EXP', 'PER']:
                    nom_medicament = correspondance
                    break
        
        if nom_medicament:
            entites['nom_medicament'].append(nom_medicament)
        
        # ==================== PRINCIPE ACTIF ====================
        modele_principe = r'-\s+([A-Z][a-zéèêàç]+(?:\s+[A-Z]?[a-zéèêàç]+)*)\s+-'
        correspondances_principe = re.findall(modele_principe, texte)
        for principe in correspondances_principe:
            if nom_medicament and principe.upper() != nom_medicament.upper():
                entites['principe_actif'].append(principe.strip())
        
        # Modèle 2: mots avec "mg" ou dosage contenant des mots-clés de principes
        if not entites['principe_actif']:
            modele = r'\d+(?:\.\d+)?\s*(?:mg|g|%|ml)\s*[–-]\s*([a-zéèêàç\s]+(?:sodique|chlorhydrate|sulfate|phosphate|base|acide))'
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                entites['principe_actif'].append(correspondance.group(1).strip())
        
        # Modèle 3: chercher le modèle "dosage PRINCIPE" (ex: "1g AMOXICILLINE")
        if not entites['principe_actif']:
            modele = r'\d+(?:\.\d+)?\s*(?:mg|g|%|ml)\s+([A-Z][A-Z]+)'
            correspondance = re.search(modele, texte)
            if correspondance:
                principe_potentiel = correspondance.group(1).strip()
                if principe_potentiel.upper() not in self.entreprises_algeriennes and (not nom_medicament or principe_potentiel != nom_medicament):
                    entites['principe_actif'].append(principe_potentiel)
        
        # Modèle 4: mots en casse mixte contenant des mots-clés de principes
        if not entites['principe_actif']:
            modele = r'\b([A-Z][a-zéèêàç]+(?:\s+[a-zéèêàç]+)?)\b'
            correspondances = re.findall(modele, texte)
            for correspondance in correspondances:
                correspondance_min = correspondance.lower()
                if any(mot in correspondance_min for mot in self.mots_cles_principes):
                    entites['principe_actif'].append(correspondance)
                    break
        
        # ==================== DOSAGE ====================
        modeles_dosage = [
            r'\b(\d+(?:\.\d+)?\s*mg(?:/\d+(?:\.\d+)?mg)?)\b',
            r'\b(\d+(?:\.\d+)?\s*g)\b',
            r'\b(\d+(?:\.\d+)?\s*ml)\b',
            r'\b(\d+(?:\.\d+)?\s*%)\b',
            r'\b(\d+(?:\.\d+)?\s*mcg)\b',
            r'\b(\d+(?:\.\d+)?\s*µg)\b',
        ]
        for modele in modeles_dosage:
            correspondances = re.findall(modele, texte, re.IGNORECASE)
            for correspondance in correspondances:
                correspondance_normalisee = re.sub(r'\s+', '', correspondance)
                if correspondance_normalisee not in entites['dosage']:
                    entites['dosage'].append(correspondance_normalisee)
        
        # ==================== FORME PHARMACEUTIQUE ====================
        modeles_forme = [
            (r'([A-Za-zéèêàç]+)\s*/?\s*[BbEe]/?(\d+)', lambda m: f"{m.group(2)} {m.group(1).lower()}"),
            (r'[Bb]o[iî]te\s+de\s+(\d+)\s+([A-Za-zéèêàç]+)', lambda m: f"{m.group(1)} {m.group(2).lower()}"),
            (r'([A-Za-zéèêàç]+)\s+boîte\s+de\s+(\d+)', lambda m: f"{m.group(2)} {m.group(1).lower()}"),
            (r'[BbEe]/?(\d+)\s+([A-Za-zéèêàç]+)', lambda m: f"{m.group(1)} {m.group(2).lower()}"),
        ]
        
        for modele, formateur in modeles_forme:
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                try:
                    mot_forme = correspondance.group(2) if len(correspondance.groups()) >= 2 else correspondance.group(1)
                except:
                    continue
                    
                if any(f in mot_forme.lower() for f in self.formes_pharmaceutiques):
                    entites['forme_pharmaceutique'].append(formateur(correspondance))
                    break
        
        # Modèle pour les formes autonomes (ex: "Comprimés" sur sa propre ligne)
        if not entites['forme_pharmaceutique']:
            for forme in self.formes_pharmaceutiques:
                modele = rf'\b({forme})\b'
                correspondance = re.search(modele, texte, re.IGNORECASE)
                if correspondance:
                    entites['forme_pharmaceutique'].append(correspondance.group(1).lower())
                    break
        
        # ==================== NUMÉRO DE LOT ====================
        modeles_lot = [
            r'LOT\s*[n°:]*\s*:?\s*([A-Z0-9]+(?:\s*/?\s*\d+)?)',
            r'N°?\s*LOT\s*:?\s*([A-Z0-9\s/]+?)(?:\s+-|\s+FAB|\s+PER|\s+EXP|$)',
            r'Lot\s+n°?\s*:?\s*([A-Z0-9\s]+?)(?:\s+-|\s+FAB|$)',
            r'LOT\s+([A-Z0-9]+)',
        ]
        for modele in modeles_lot:
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                lot = correspondance.group(1).strip()
                lot = re.sub(r'\s+', ' ', lot)
                entites['numero_lot'].append(lot)
                break
        
        # ==================== DATE DE FABRICATION ====================
        modeles_fab = [
            r'FAB(?:RICATO?)?\s*[B:]?\s*:?\s*(\d{1,2}[-/]\d{2,4})',
            r'Date\s+Fab(?:rication)?\s*:?\s*(\d{1,2}[-/]\d{2,4})',
            r'Fab\s*:?\s*(\d{1,2}[-/]\d{2,4})',
            r'FAB\s+(\d{2}-\d{4})',
            r'FAB\s+(\d{2}-\d{2})',
            r'\bFAB\s+(\d{2}/\d{4})',
        ]
        for modele in modeles_fab:
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                entites['date_fabrication'].append(correspondance.group(1))
                break
        
        # ==================== DATE DE PÉREMPTION ====================
        modeles_exp = [
            r'(?:PER(?:IOD[OI])?|EXP(?:IRATION)?)\s*:?\s*(\d{1,2}[-/]\d{2,4})',
            r'Date\s+Exp(?:iration)?\s*:?\s*(\d{1,2}[-/]\d{2,4})',
            r'Péremption\s*:?\s*(\d{1,2}[-/]\d{2,4})',
            r'EXP\s+(\d{2}-\d{4})',
            r'EXP:\s*(\d{2}-\d{2})',
            r'\bEXP\s+(\d{2}/\d{4})',
        ]
        for modele in modeles_exp:
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                entites['date_peremption'].append(correspondance.group(1))
                break
        
        # ==================== PRIX ====================
        modeles_prix = [
            r'TR\s*[=:]\s*(\d+(?:\.\d+)?)\s*DA',
            r'T\.R\s*[=:]\s*(\d+(?:\.\d+)?)\s*DA',
            r'Tarif\s+de\s+Réf?(?:érence)?\s*[=:]\s*(\d+(?:\.\d+)?)\s*DA',
            r'PPA\s*[=:+]?\s*(\d+(?:\.\d+)?)\s*DA',
            r'Prix\s*[+]?\s*SHP\s*[=:]\s*(\d+(?:\.\d+)?)',
            r'PRIX\s*[=:]\s*(\d+(?:\.\d+)?)',
            r'PRIX\s+(\d+(?:\.\d+)?)DA',
            r'TR\s+(\d+(?:\.\d+)?)DA',
            r'T\.R\s+(\d+(?:\.\d+)?)DA',
        ]
        for modele in modeles_prix:
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                prix = correspondance.group(1)
                entites['prix'].append(prix + ' DA')
                break
        
        # ==================== NUMÉRO D'ENREGISTREMENT (D.E) ====================
        modeles_de = [
            r'D\.?E\s*[n°]*\s*:?\s*([\d/A-Z\s]+?)(?:\s+-|\s+LOT|\s+FAB|\s+\d{4}/\d{4}|$)',
            r'N°\s*D\.?E\s*:?\s*([\d/A-Z\s]+?)(?:\s+-|$)',
        ]
        for modele in modeles_de:
            correspondance = re.search(modele, texte, re.IGNORECASE)
            if correspondance:
                num_de = correspondance.group(1).strip()
                num_de = re.sub(r'\s+', ' ', num_de)
                num_de = re.sub(r'\s+\d{4}$', '', num_de)
                if num_de:
                    entites['numero_enregistrement'].append(num_de)
                    break
        
        return entites
    
    def predire(self, texte: str):
        """Méthode de prédiction principale"""
        print(f"\n{'='*60}")
        print("🔍 ANALYSE")
        print('='*60)
        
        entites = self.analyser_format_algerian(texte)
        
        total = sum(len(v) for v in entites.values())
        print(f"✓ {total} éléments extraits\n")
        
        return entites
    
    def formater_sortie(self, entites: dict) -> str:
        """Formater la sortie joliment"""
        
        etiquettes = {
            'nom_medicament': '💊 Nom du Médicament',
            'principe_actif': '🧪 Principe Actif',
            'dosage': '⚖️  Dosage',
            'forme_pharmaceutique': '💊 Forme Pharmaceutique',
            'entreprise': '🏭 Laboratoire/Fabricant',
            'numero_lot': '🔢 Numéro de Lot',
            'date_fabrication': '📅 Date de Fabrication',
            'date_peremption': '⏰ Date de Péremption',
            'prix': '💰 Prix',
            'numero_enregistrement': '📋 N° Enregistrement (D.E)'
        }
        
        non_trouve = "❌ Non trouvé"
        
        sortie = "\n" + "="*60 + "\n"
        sortie += "RÉSULTATS DE L'EXTRACTION\n"
        sortie += "="*60 + "\n\n"
        
        for cle, etiquette in etiquettes.items():
            sortie += f"{etiquette}:\n"
            if entites[cle]:
                for element in entites[cle]:
                    sortie += f"   ✅ {element}\n"
            else:
                sortie += f"   {non_trouve}\n"
            sortie += "\n"
        
        return sortie
    
    def enregistrer_dans_fichier(self, entites: dict, nom_fichier: str = "medicaments.json"):
        """Enregistrer les entités dans un fichier JSON - ajoute les données existantes"""
        
        # Ajouter un horodatage à l'entrée
        entree = {
            'horodatage': datetime.now().isoformat(),
            'donnees': entites
        }
        
        # Charger les données existantes si le fichier existe
        donnees_existantes = []
        if os.path.exists(nom_fichier):
            try:
                with open(nom_fichier, 'r', encoding='utf-8') as f:
                    donnees_existantes = json.load(f)
                    # S'assurer que c'est une liste
                    if not isinstance(donnees_existantes, list):
                        donnees_existantes = [donnees_existantes]
            except json.JSONDecodeError:
                print(f"   ⚠️  Fichier corrompu, création d'un nouveau")
                donnees_existantes = []
        
        # Ajouter la nouvelle entrée
        donnees_existantes.append(entree)
        
        # Enregistrer dans le fichier
        try:
            with open(nom_fichier, 'w', encoding='utf-8') as f:
                json.dump(donnees_existantes, f, indent=2, ensure_ascii=False)
            print(f"   ✅ Enregistré: {nom_fichier}")
            print(f"   📊 Nombre total d'entrées: {len(donnees_existantes)}\n")
            return True
        except Exception as e:
            print(f"   ❌ Erreur: {e}\n")
            return False


def principale():
    """Fonction principale"""
    
    print("\n" + "="*70)
    print("  🇩🇿  CLASSIFICATEUR DE MÉDICAMENTS ALGÉRIENS")
    print("="*70)
    
    classificateur = ClassificateurMedicamentsAlgerien()
    
    # Cas de test complets
    cas_tests = [
        # ============ TESTS FORMAT MULTI-LIGNE ============
        {
            "nom": "TEST 1: Format Multi-ligne - PARACETAMOL",
            "texte": """LOT 77A  
BIOCARE  
500 mg PARACETAMOL  
EXP 04-2026  
Comprimés  
FAB 02-2024  
TR: 62.5DA"""
        },
        {
            "nom": "TEST 2: Format Multi-ligne - CLOFENAL LP",
            "texte": """75mg – diclofénac sodique  
EXP:11-25  
VIGNETTE SAIDAL  
B/20 gélules LP  
CLOFENAL LP  
LOT 605  
FAB 10-24  
PPA 366.60DA"""
        },
        
        # ============ TESTS FORMAT UNE SEULE LIGNE ============
        {
            "nom": "TEST 3: Une seule ligne - BIOFENAC (Mélangé)",
            "texte": "Biopharm-BIOFENAC 100mg - Diclofénac Sodique - Suppositoires/B10 - TR=87.80DA - PPA+SHP=107.40+1.50 - 108.90DA - LOT: 77/23 - FAB: 12/26 - PER: 11/05/04 B - DE:16.05/04 B - 0409/2063"
        },
        {
            "nom": "TEST 4: Une seule ligne - CLOFENAL L.P",
            "texte": "VIGNETTE-SAIDAL CLOFENAL & L.P 75 mg - Diclofénac sodique - Boîte de 30 Gélules L.P - PRIX: 365.10 + SHP: 1.5 - PPA: 366.60 DA - T.R: 366.60 DA - DE: 18/07/04B 037/003 - LOT: 605 - FAB: 10/2024 - EXP: 11/2024"
        },
        {
            "nom": "TEST 5: Une seule ligne - PREDNICORT",
            "texte": "Nadpharmagic-Vignette- PREDNICORT 20 mg - prednisolone - comprimé quadrispersible B/20 - Prix: 389.5 + SHP 2.50 - PPA=392.00 DA - TR: 392.00 DA - D.E n° 15/09H 144/468 - Date Exp: 12/2024 - Date Fab: 12/2024 - Lot n°: F10 0162"
        },
        {
            "nom": "TEST 6: Une seule ligne - EXPANDOL",
            "texte": "VIGNETTE BIOGALENIC EXPANDOL 500mg - Paracétamol - Comprimée boîte de 20 - Prix+SHP=98.19+0.00 - PPA=98.19 DA - Tarif de Réf = 50.00 DA - LOT: 235 - PERIODO: 06/2026 - FABRICATO B: 06/2025 - DE:24004 B 003235"
        },
        {
            "nom": "TEST 7: Une seule ligne - STERDEX",
            "texte": "STERDEX 0.267mg/1.336mg - Dexaméthasone - Oxytétracycline - Pde Opht B/12 - récipients unidoses - PPA=256.73+2.50 - 258.23 DA - LOT: 3030 - FAB: 10/2022 - PER: 130/022 - DE: 117/022 - T/D"
        },
        
        # ============ CAS LIMITES ============
        {
            "nom": "TEST 8: Dosage avant nom du médicament",
            "texte": """500mg ASPIRIN
BIOCARE
LOT: ABC123
FAB: 01-2024
EXP: 01-2026
TR: 45.00DA"""
        },
        {
            "nom": "TEST 9: Format mixte avec LP",
            "texte": "SAIDAL VOLTAREN L.P 100mg - diclofénac sodique - gélules B/30 - PPA 425.00 DA - LOT: X789 - FAB: 03/2024 - EXP: 03/2026"
        },
        {
            "nom": "TEST 10: Information minimale",
            "texte": "AMOXICILLIN 500mg Comprimés LOT: 12345 EXP: 12-2025"
        },
        
        # ============ FORMAT COMPLÈTEMENT MÉLANGÉ ============
        {
            "nom": "TEST 11: Complètement mélangé - CLAMOXYL",
            "texte": "EXP 03/2027 - 1g AMOXICILLINE - B/12 gélules - LOT 77C - FAB 04/2024 - BIOPHARM - PRIX 340DA - CLAMOXYL"
        },
        {
            "nom": "TEST 12: Ordre aléatoire - DOLIPRANE",
            "texte": "LOT X999 - PRIX 125.50DA - SANOFI - 500mg PARACETAMOL - EXP 12/2026 - FAB 01/2025 - DOLIPRANE - Comprimés B/20"
        },
        
        # ============ VARIATIONS DE FORMAT DE PRIX ============
        {
            "nom": "TEST 13: Prix sans séparateur - CETIRIZINE",
            "texte": "SAIDAL - 10mg CETIRIZINE - FAB 08/23 - TR 115DA - B/20 comprimés - EXP 08/26 - LOT A55 - VIGNETTE"
        }
    ]
    
    # Exécuter les tests
    print("\n" + "="*70)
    print("🧪 TESTS AUTOMATIQUES")
    print("="*70)
    
    for i, test in enumerate(cas_tests, 1):
        print(f"\n{'─'*70}")
        print(f"{test['nom']}")
        print('─'*70)
        print(f"📝 Entrée:\n{test['texte']}\n")
        
        entites = classificateur.predire(test['texte'])
        print(classificateur.formater_sortie(entites))
    
    # Mode interactif
    print("\n" + "="*70)
    print("💬 MODE INTERACTIF")
    print("="*70)
    print("\n📋 Collez votre texte OCR de médicament algérien")
    print("   (Format multi-lignes supporté)")
    print("\n💡 Le classificateur est maintenant robuste:")
    print("   ✓ Format multi-lignes et une seule ligne")
    print("   ✓ Ordre des éléments flexible")
    print("   ✓ Formats multiples supportés")
    print("   ✓ Extraction intelligente")
    print("   ✓ Sauvegarde cumulative (les résultats s'ajoutent)")
    print("\n⌨️  Collez votre texte et appuyez sur ENTRÉE 2 fois (ligne vide) pour terminer")
    print("⌨️  Tapez 'quit' ou 'q' pour quitter\n")
    
    while True:
        print("─"*70)
        print("\n➤ Texte:\n")
        
        lignes = []
        compte_ligne_vide = 0
        
        while True:
            try:
                ligne = input()
            except EOFError:
                break
            
            # Vérifier les commandes de quitter
            if ligne.strip().lower() in ['quit', 'exit', 'q'] and len(lignes) == 0:
                print("\n👋 Au revoir!")
                return
            
            # Si la ligne est vide, incrémenter le compteur
            if not ligne.strip():
                compte_ligne_vide += 1
                # Si deux lignes vides consécutives
                if compte_ligne_vide >= 1 and len(lignes) > 0:
                    break
            else:
                compte_ligne_vide = 0
                lignes.append(ligne)
        
        entree_utilisateur = '\n'.join(lignes).strip()
        
        if not entree_utilisateur:
            print("\n👋 Au revoir!")
            break
        
        entites = classificateur.predire(entree_utilisateur)
        
        print(classificateur.formater_sortie(entites))
        
        # Option d'enregistrement
        enregistrer = input("💾 Enregistrer? (o/n): ").strip().lower()
        if enregistrer == 'o':
            nom_fichier = input("   📄 Nom du fichier [medicaments.json]: ").strip() or "medicaments.json"
            
            if not nom_fichier.endswith('.json'):
                nom_fichier += '.json'
            
            classificateur.enregistrer_dans_fichier(entites, nom_fichier)


if __name__ == "__main__":
    principale()