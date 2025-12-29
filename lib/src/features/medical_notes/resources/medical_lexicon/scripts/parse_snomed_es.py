#!/usr/bin/env python3
"""
Parse SNOMED CT Spanish Edition release files to extract clinical terms.

SNOMED CT Spanish Edition License Requirements:
- Requires Affiliate License through MLDS (Member Licensing and Distribution Service)
- Apply at: https://mlds.ihtsdotools.org/
- Free for healthcare/research use, but registration required

SNOMED CT Release File Structure:
After downloading the Spanish Edition release (e.g., SnomedCT_SpanishRelease-es_...),
the relevant files are:

  Snapshot/Terminology/
    sct2_Concept_Snapshot_*.txt       - Concept IDs and status
    sct2_Description_Snapshot_*.txt   - Terms (FSN, synonyms) per concept
    sct2_Relationship_Snapshot_*.txt  - Hierarchical relationships

  Snapshot/Refset/Language/
    der2_cRefset_LanguageSnapshot_*.txt - Preferred terms per language

This script extracts:
1. Preferred Spanish terms (PT) for clinical findings
2. Common synonyms that might be dictated
3. Filters to relevant semantic categories

Usage:
    python parse_snomed_es.py /path/to/SnomedCT_SpanishRelease-es_YYYYMMDD

Output:
    ../clinical_terms_es.json (overwrites fallback with SNOMED terms)
"""

import csv
import json
import sys
from pathlib import Path
from typing import Dict, Set, List

# SNOMED CT semantic tag filters (clinical relevance)
INCLUDED_SEMANTIC_TAGS = {
    "(trastorno)",          # disorders
    "(hallazgo)",           # clinical findings
    "(procedimiento)",      # procedures
    "(situación)",          # situations
    "(estructura corporal)",# body structures
    "(organismo)",          # organisms (pathogens)
    "(sustancia)",          # substances
    "(producto)",           # pharmaceutical products
    "(signo)",              # signs
    "(síntoma)",            # symptoms
    "(evento)",             # events
}

# Concept IDs for top-level hierarchies to include
# (Clinical finding, Procedure, Body structure, Pharmaceutical product)
RELEVANT_HIERARCHIES = {
    "404684003",  # Clinical finding
    "71388002",   # Procedure
    "123037004",  # Body structure
    "373873005",  # Pharmaceutical / biologic product
    "243796009",  # Situation with explicit context
    "363787002",  # Observable entity
    "78621006",   # Physical force
    "410607006",  # Organism
    "105590001",  # Substance
}


def parse_descriptions(snapshot_path: Path) -> Dict[str, List[str]]:
    """
    Parse sct2_Description_Snapshot file to get terms per concept.

    Returns:
        Dict mapping conceptId -> list of Spanish terms
    """
    descriptions_file = list(snapshot_path.glob("Terminology/sct2_Description_Snapshot_*.txt"))
    if not descriptions_file:
        print("ERROR: sct2_Description_Snapshot_*.txt not found")
        return {}

    terms_by_concept: Dict[str, List[str]] = {}

    with open(descriptions_file[0], 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            # Only active descriptions
            if row.get('active') != '1':
                continue

            # Only Spanish terms (languageCode = 'es')
            if row.get('languageCode') != 'es':
                continue

            concept_id = row.get('conceptId')
            term = row.get('term', '').strip()

            if concept_id and term:
                if concept_id not in terms_by_concept:
                    terms_by_concept[concept_id] = []
                terms_by_concept[concept_id].append(term)

    return terms_by_concept


def parse_language_refset(snapshot_path: Path) -> Dict[str, str]:
    """
    Parse language refset to identify preferred terms (PT).

    Returns:
        Dict mapping descriptionId -> acceptability
    """
    refset_file = list(snapshot_path.glob("Refset/Language/der2_cRefset_LanguageSnapshot_*.txt"))
    if not refset_file:
        print("WARNING: Language refset not found, using all terms")
        return {}

    preferred: Dict[str, str] = {}

    with open(refset_file[0], 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            if row.get('active') != '1':
                continue

            desc_id = row.get('referencedComponentId')
            acceptability = row.get('acceptabilityId')

            # 900000000000548007 = Preferred
            if desc_id and acceptability == '900000000000548007':
                preferred[desc_id] = 'preferred'

    return preferred


def filter_clinical_terms(terms_by_concept: Dict[str, List[str]]) -> Set[str]:
    """
    Filter terms to include only clinically relevant ones.
    Uses semantic tags in FSN to identify relevant concepts.
    """
    clinical_terms: Set[str] = set()

    for concept_id, terms in terms_by_concept.items():
        # Check if any term contains a relevant semantic tag (FSN format)
        has_relevant_tag = False
        for term in terms:
            for tag in INCLUDED_SEMANTIC_TAGS:
                if tag in term.lower():
                    has_relevant_tag = True
                    break
            if has_relevant_tag:
                break

        if has_relevant_tag:
            for term in terms:
                # Skip FSN (contains semantic tag in parentheses at end)
                if term.endswith(')') and '(' in term:
                    continue
                # Normalize and add
                normalized = term.strip().lower()
                if len(normalized) > 2:  # Skip very short terms
                    clinical_terms.add(normalized)

    return clinical_terms


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nUsage: python parse_snomed_es.py /path/to/SnomedCT_SpanishRelease-es_YYYYMMDD")
        print("\nTo obtain SNOMED CT Spanish Edition:")
        print("1. Register at https://mlds.ihtsdotools.org/")
        print("2. Request access to SNOMED CT Spanish Edition")
        print("3. Download the RF2 release package")
        print("4. Extract and run this script with the path to the extracted folder")
        sys.exit(1)

    release_path = Path(sys.argv[1])
    snapshot_path = release_path / "Snapshot"

    if not snapshot_path.exists():
        print(f"ERROR: Snapshot directory not found at {snapshot_path}")
        print("Ensure you've extracted the SNOMED CT release and provided the correct path")
        sys.exit(1)

    print("=" * 60)
    print("SNOMED CT Spanish Edition Parser")
    print("=" * 60)

    print("\n[1/3] Parsing descriptions...")
    terms_by_concept = parse_descriptions(snapshot_path)
    print(f"  Found {len(terms_by_concept)} concepts with Spanish terms")

    print("\n[2/3] Parsing language refset...")
    preferred_terms = parse_language_refset(snapshot_path)
    print(f"  Found {len(preferred_terms)} preferred term references")

    print("\n[3/3] Filtering clinical terms...")
    clinical_terms = filter_clinical_terms(terms_by_concept)
    print(f"  Extracted {len(clinical_terms)} clinical terms")

    # Sort and prepare output
    sorted_terms = sorted(clinical_terms)

    output = {
        "source": "SNOMED CT Spanish Edition",
        "source_url": "https://mlds.ihtsdotools.org/",
        "license": "SNOMED CT Affiliate License (IHTSDO)",
        "generated": __import__('datetime').datetime.now().strftime("%Y-%m-%d"),
        "release_path": str(release_path),
        "total_count": len(sorted_terms),
        "clinical_terms": sorted_terms
    }

    # Write output
    output_path = Path(__file__).parent.parent / "clinical_terms_es.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n{'=' * 60}")
    print(f"SUCCESS: Generated {output_path}")
    print(f"Total clinical terms: {len(sorted_terms)}")
    print(f"{'=' * 60}")

    # Show sample
    print("\nSample terms (first 20):")
    for term in sorted_terms[:20]:
        print(f"  - {term}")


if __name__ == "__main__":
    main()
