# Analysis pipeline — Comprehension experiment item selection

This folder implements the preregistered comprehension item-selection step:

- fit the production model first
- compute posterior predictive marker probabilities for each of the 32 critical cells
  (8 items × 4 conditions)
- assign the modal marker in each cell for use in the comprehension experiment

## Quick start

```r
# from within analysis/comprehension_exp/
source("01_item_selection_from_production.R")
```

## Inputs

- `../production_exp/data/fit_brms_full_3markers.rds`
- `../production_exp/data/norming_means.csv`
- `../../experiments/item/items.csv`

## Outputs

- `data/comprehension_condition_predictions.csv`
- `data/comprehension_marker_assignment_long.csv`
- `data/comprehension_marker_assignment_matrix.csv`
- `data/comprehension_marker_assignment.json`

The script also writes the canonical assignment file used by the experiment
generator at:

- `../../experiments/item/comprehension_marker_assignment.csv`

After the assignment file is written, rerun:

```bash
python ../../experiments/item/generate_stimuli.py
```

to update `experiments/comprehension_exp/src/stimuli.js`.

## Exploratory balanced assignment

An exploratory follow-up script creates a near-balanced marker assignment while
staying as close as possible to the posterior probabilities from the production
model:

- `02_balanced_item_selection.R`

This script writes:

- `data/comprehension_balanced_assignment_long.csv`
- `data/comprehension_balanced_assignment_matrix.csv`
- `data/comprehension_balanced_assignment_summary.csv`
- `../../experiments/item/comprehension_marker_assignment_balanced.csv`

When the balanced assignment file exists, the stimuli generator prefers it over
the strict preregistered modal assignment.

For documentation of both procedures, see:

- [item_selection_writeup.md](item_selection_writeup.md)
