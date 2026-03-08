# Analysis pipeline — Comprehension experiment

This folder now contains both:

- the item-selection workflow used to construct the comprehension materials from
  the fitted production model, and
- the listener-side analysis pipeline for the collected comprehension ratings.

## Quick start

```r
# from within analysis/comprehension_exp/
source("01_item_selection_from_production.R")
source("run_pipeline.R")
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

## Listener-side analysis pipeline

The comprehension analysis pipeline uses the magpie export at:

- `../../data/comprehension_exp.csv`

and copies it to:

- `data/real_data.csv`

before running the analysis stages.

Run:

```r
# from within analysis/comprehension_exp/
source("run_pipeline.R")
```

or:

```bash
Rscript analysis/comprehension_exp/run_pipeline.R
```

### Stages

- `04_empirical_plots.R`
  - filters to critical non-training trials
  - joins propositional-controversy norming values
  - writes `data/analysis_data.csv`
  - writes descriptive summaries and plots

- `05_bayesian_beta_models.R`
  - fits preregistered Bayesian zero/one-inflated beta models for:
    - inferred goal strength
    - adoption likelihood
  - mean model: `y ~ marker_strength * pc_prag + (1 | submission_id) + (1 | topic)`
  - boundary mass handled directly through the ZOIB likelihood

- `06_bayesian_contrasts.R`
  - computes posterior expected predictions by marker and pragmatic controversy
  - writes preregistered direction tests / contrast summaries

- `07_random_effects_sensitivity.R`
  - refits the same ZOIB likelihood with a richer participant random-effects structure
  - uses population-level predictions (`re_formula = NA`) to compare the main and sensitivity specifications

- `07_rsa_listener_fit.R`
  - reuses the production-fitted RSA speaker parameters from
    `../production_exp/data/fit_rsa_soft_thresholds.rds`
  - computes $E[g \mid u, pc]$ for each comprehension cell
  - fits the exploratory listener adoption link from the preregistration
  - compares observed vs RSA-predicted goal/adoption ratings

### Main analysis outputs

- `data/analysis_data.csv`
- `data/comprehension_empirical_condition_summary.csv`
- `data/comprehension_empirical_marker_summary.csv`
- `data/fit_brms_goal_zoib_full.rds`
- `data/fit_brms_adoption_zoib_full.rds`
- `data/fit_brms_goal_zoib_sensitivity.rds`
- `data/fit_brms_adoption_zoib_sensitivity.rds`
- `data/comprehension_posterior_predictions_goal.csv`
- `data/comprehension_posterior_predictions_adoption.csv`
- `data/comprehension_posterior_contrasts.csv`
- `data/comprehension_zoib_sensitivity_fixef_comparison.csv`
- `data/comprehension_zoib_sensitivity_predictions.csv`
- `data/comprehension_rsa_listener_cell_predictions.csv`
- `data/comprehension_rsa_listener_condition_summary.csv`
- `data/comprehension_rsa_listener_parameter_summary.csv`
- `data/fit_rsa_listener.rds`
- `plots/fig1_goal_by_condition_marker.png`
- `plots/fig2_adoption_by_condition_marker.png`
- `plots/fig3_comprehension_pcprop_scatter.png`
- `plots/fig4_zoib_model_coefficients.png`
- `plots/fig5_comprehension_posterior_predictions.png`
- `plots/fig6_zoib_sensitivity_coefficients.png`
- `plots/fig6_rsa_listener_predictions.png`

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
