# GESP Discourse Corpus (LiteratureHero)

This directory contains the evolving GESP discourse corpus used to train, validate, and benchmark LiteratureHero’s analysis tools. The corpus is designed to bridge fiction, news, social discussion, and historical documents under a common GESP and doom/agency annotation scheme.

## Goals

- Provide a shared, versioned dataset for:
  - Training and evaluating GESP taggers (Lua and higher-level models).
  - Estimating typical stress ranges for different narrative domains.
  - Validating doom/agency discourse metrics and d_D-like measures.
  - Studying how different case families (rapid shock, elite implosion, climate cascade, etc.) appear in text.

## File Structure

- `schema.json`  
  Formal description of fields, ranges, and allowed values for annotations.

- `fiction_samples.csv`  
  Placeholder fiction fragments with example annotations.

- `news_samples.csv`  
  Placeholder news fragments with example annotations.

- `social_samples.csv`  
  Placeholder social/discussion fragments with example annotations.

As the project matures, you can add:

- `historical_samples.csv` for archival texts.
- `auto_labeled/` for model-generated annotations.
- `gold_standard/` for adjudicated human-labeled subsets.

## Annotation Guidelines (Draft)

- Use `sG, sE, sS, sP` as normalized scores in [0, 1] based on observable stress in the fragment, not on global knowledge.
- Derive `hex_tag` from the four nibbles (0–15) mapped from `sD ≈ nibble_D / 15`.
- `doom_agency_label` reflects the rhetorical balance:
  - `doom_dominant`: strong emphasis on inevitability, helplessness, or terminal decline.
  - `balanced`: mixed risk recognition and agency.
  - `agency_dominant`: emphasis on options, solutions, or collective action.
- `case_family` should match archetypes defined in `docs/gesp_case_families.md` when applicable.

These placeholders are intentionally small and simple. They provide a starting template and can be replaced or expanded with real data, versioned over time.
