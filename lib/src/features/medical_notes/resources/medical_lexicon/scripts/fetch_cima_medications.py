#!/usr/bin/env python3
"""
Fetch active substances (principios activos) from AEMPS CIMA REST API.

CIMA API Documentation:
https://cima.aemps.es/cima/rest/medicamentos
https://sede.aemps.gob.es/docs/CIMA-REST-API.pdf

This script fetches medication data from the official Spanish Agency for
Medicines and Health Products (AEMPS) open API. The data is public and
freely available for non-commercial use.

Usage:
    python fetch_cima_medications.py

Output:
    ../meds_cima_principios_activos.json
"""

import json
import time
import re
from pathlib import Path
from typing import Set
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

# CIMA REST API base URL
CIMA_BASE_URL = "https://cima.aemps.es/cima/rest"

# Common active substances to ensure we capture (fallback if API fails)
CORE_ACTIVE_SUBSTANCES = [
    # Cardiovascular
    "ácido acetilsalicílico", "atenolol", "amlodipino", "atorvastatina",
    "bisoprolol", "carvedilol", "clopidogrel", "digoxina", "diltiazem",
    "enalapril", "eplerenona", "espironolactona", "furosemida", "hidroclorotiazida",
    "irbesartán", "lisinopril", "losartán", "metoprolol", "nifedipino",
    "nitroglicerina", "olmesartán", "perindopril", "ramipril", "simvastatina",
    "telmisartán", "valsartán", "verapamilo", "warfarina", "acenocumarol",
    "rivaroxabán", "apixabán", "dabigatrán", "rosuvastatina", "pravastatina",

    # Diabetes
    "metformina", "glibenclamida", "glimepirida", "gliclazida", "insulina",
    "sitagliptina", "vildagliptina", "linagliptina", "empagliflozina",
    "dapagliflozina", "canagliflozina", "liraglutida", "semaglutida",
    "dulaglutida", "pioglitazona", "repaglinida",

    # Gastrointestinal
    "omeprazol", "pantoprazol", "esomeprazol", "lansoprazol", "rabeprazol",
    "ranitidina", "famotidina", "metoclopramida", "domperidona", "ondansetrón",
    "loperamida", "lactulosa", "mesalazina", "sulfasalazina",

    # Pain and inflammation
    "paracetamol", "ibuprofeno", "naproxeno", "diclofenaco", "metamizol",
    "ketorolaco", "dexketoprofeno", "celecoxib", "etoricoxib", "meloxicam",
    "tramadol", "morfina", "fentanilo", "oxicodona", "codeína", "buprenorfina",
    "tapentadol", "pregabalina", "gabapentina",

    # Antibiotics
    "amoxicilina", "amoxicilina/ácido clavulánico", "azitromicina",
    "claritromicina", "ciprofloxacino", "levofloxacino", "moxifloxacino",
    "clindamicina", "metronidazol", "doxiciclina", "cefalexina", "cefuroxima",
    "ceftriaxona", "cefixima", "trimetoprim/sulfametoxazol", "fosfomicina",
    "nitrofurantoína", "gentamicina", "vancomicina", "linezolid",

    # Respiratory
    "salbutamol", "formoterol", "salmeterol", "tiotropio", "ipratropio",
    "budesonida", "fluticasona", "beclometasona", "mometasona",
    "montelukast", "teofilina", "acetilcisteína", "bromhexina", "dextrometorfano",

    # Neuropsychiatry
    "diazepam", "lorazepam", "alprazolam", "clonazepam", "bromazepam",
    "zolpidem", "lormetazepam", "sertralina", "escitalopram", "fluoxetina",
    "paroxetina", "venlafaxina", "duloxetina", "mirtazapina", "trazodona",
    "amitriptilina", "quetiapina", "olanzapina", "risperidona", "aripiprazol",
    "haloperidol", "clozapina", "levodopa", "carbidopa", "pramipexol",
    "ropinirol", "rasagilina", "memantina", "donepezilo", "rivastigmina",
    "carbamazepina", "valproato", "lamotrigina", "levetiracetam", "topiramato",

    # Corticosteroids
    "prednisona", "prednisolona", "metilprednisolona", "dexametasona",
    "hidrocortisona", "betametasona", "triamcinolona",

    # Antihistamines
    "loratadina", "cetirizina", "ebastina", "desloratadina", "bilastina",
    "difenhidramina", "hidroxizina", "dexclorfeniramina",

    # Thyroid
    "levotiroxina", "liotironina", "carbimazol", "metimazol", "propiltiouracilo",

    # Urology
    "tamsulosina", "alfuzosina", "silodosina", "finasterida", "dutasterida",
    "solifenacina", "tolterodina", "mirabegrón", "sildenafilo", "tadalafilo",

    # Ophthalmology/ENT
    "timolol", "latanoprost", "dorzolamida", "brimonidina", "tropicamida",
    "ciprofloxacino oftálmico", "tobramicina", "dexametasona oftálmica",

    # Dermatology
    "mupirocina", "ácido fusídico", "clotrimazol", "miconazol", "ketoconazol",
    "terbinafina", "aciclovir", "permetrina", "ivermectina tópica",

    # Immunosuppressants
    "metotrexato", "azatioprina", "ciclosporina", "tacrolimus", "micofenolato",

    # Others
    "alopurinol", "colchicina", "febuxostat", "hierro", "ácido fólico",
    "vitamina B12", "vitamina D", "calcio", "potasio", "magnesio",
    "enoxaparina", "heparina", "fondaparinux", "alteplasa",
]

def fetch_cima_medicamentos(letter: str, max_retries: int = 3) -> list:
    """
    Fetch medications starting with a given letter from CIMA API.

    Args:
        letter: Single letter to search
        max_retries: Number of retry attempts

    Returns:
        List of medication records
    """
    url = f"{CIMA_BASE_URL}/medicamentos?nombre={letter}&pagina=1"

    for attempt in range(max_retries):
        try:
            req = Request(url, headers={
                'User-Agent': 'Docsoft-MedicalLexicon/1.0 (medical-app; contact@example.com)',
                'Accept': 'application/json'
            })
            with urlopen(req, timeout=30) as response:
                data = json.loads(response.read().decode('utf-8'))
                return data.get('resultados', [])
        except (HTTPError, URLError) as e:
            print(f"  Attempt {attempt + 1} failed for '{letter}': {e}")
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)  # Exponential backoff

    return []


def extract_principios_activos(medicamentos: list) -> Set[str]:
    """Extract unique active substances from medication records."""
    principios = set()

    for med in medicamentos:
        # CIMA returns 'vtm' field with active substance info
        vtm = med.get('vtm', {})
        if vtm and isinstance(vtm, dict):
            nombre = vtm.get('nombre', '')
            if nombre:
                principios.add(nombre.strip())

        # Also check 'principiosActivos' if available
        pas = med.get('principiosActivos', [])
        if pas:
            for pa in pas:
                if isinstance(pa, dict):
                    nombre = pa.get('nombre', '')
                    if nombre:
                        principios.add(nombre.strip())
                elif isinstance(pa, str):
                    principios.add(pa.strip())

    return principios


def normalize_substance(name: str) -> str:
    """Normalize substance name for consistency."""
    # Lowercase
    normalized = name.lower().strip()
    # Remove extra whitespace
    normalized = re.sub(r'\s+', ' ', normalized)
    return normalized


def main():
    print("=" * 60)
    print("CIMA Medications Fetcher - Phase 1")
    print("=" * 60)

    all_principios: Set[str] = set()

    # Start with core substances (guaranteed baseline)
    print("\n[1/2] Loading core active substances...")
    for substance in CORE_ACTIVE_SUBSTANCES:
        all_principios.add(normalize_substance(substance))
    print(f"  Loaded {len(all_principios)} core substances")

    # Attempt to fetch from CIMA API
    print("\n[2/2] Fetching from CIMA REST API...")
    print("  (This may take a few minutes due to rate limiting)")

    # Fetch by letter to get broader coverage
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    api_success = False

    for i, letter in enumerate(letters):
        print(f"  Fetching '{letter}' ({i+1}/{len(letters)})...", end=" ")
        try:
            meds = fetch_cima_medicamentos(letter)
            if meds:
                api_success = True
                nuevos = extract_principios_activos(meds)
                for p in nuevos:
                    all_principios.add(normalize_substance(p))
                print(f"found {len(nuevos)} substances")
            else:
                print("no results")
            time.sleep(0.5)  # Respectful rate limiting
        except Exception as e:
            print(f"error: {e}")

    if not api_success:
        print("\n  WARNING: CIMA API unreachable. Using core substances only.")
        print("  To retry, ensure network connectivity and run again.")

    # Sort and prepare output
    sorted_principios = sorted(all_principios)

    # Create output with both lowercase and title case versions
    output = {
        "source": "AEMPS CIMA REST API + curated core list",
        "source_url": "https://cima.aemps.es/cima/rest",
        "license": "Public data from Spanish Agency for Medicines (AEMPS)",
        "generated": time.strftime("%Y-%m-%d"),
        "total_count": len(sorted_principios),
        "principios_activos": sorted_principios
    }

    # Write output
    output_path = Path(__file__).parent.parent / "meds_cima_principios_activos.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n{'=' * 60}")
    print(f"SUCCESS: Generated {output_path}")
    print(f"Total active substances: {len(sorted_principios)}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
