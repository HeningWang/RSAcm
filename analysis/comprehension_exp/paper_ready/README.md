# Paper-ready comprehension bundle

This folder collects the final comprehension-side materials currently intended for the paper:

- Figure 7: RSA base vs. enhanced comparison
- categorical-beta fixed-effect summaries
- categorical-beta posterior predictions and hypothesis contrasts
- a minimal script bundle to refresh these outputs

## Refresh command

From the repository root:

```bash
Rscript analysis/comprehension_exp/paper_ready/reproduce_paper_ready.R
```

This reruns:

- `07_rsa_listener_fit.R`
- `08_categorical_beta_models.R`
- `09_categorical_beta_contrasts.R`

and then copies the current outputs into this folder.

It also rebuilds:

- `manuscript_stats_table.md`
- `data/manuscript_stats_table.csv`

## Folder contents

### `plots/`

- `fig7_rsa_base_vs_enhanced.{png,pdf}`
- `fig8_cat_beta_coefficients.{png,pdf}`
- `fig9_cat_beta_posterior_predictions.{png,pdf}`

### `data/`

- `comprehension_exp.csv` — raw comprehension export used in the analysis
- `analysis_data.csv` — cleaned analysis dataset
- `comprehension_rsa_listener_condition_summary.csv`
- `comprehension_rsa_listener_parameter_summary.csv`
- `comprehension_rsa_enhanced_summary.csv`
- `brms_goal_cat_beta_fixef.csv`
- `brms_adoption_cat_beta_fixef.csv`
- `cat_beta_posterior_contrasts.csv`
- `cat_beta_posterior_predictions_goal.csv`
- `cat_beta_posterior_predictions_adoption.csv`
- `manuscript_stats_table.csv`

### `scripts/`

Snapshot copies of the main scripts used to generate the paper-facing outputs:

- `00_utils.R`
- `run_pipeline.R`
- `07_rsa_listener_fit.R`
- `08_categorical_beta_models.R`
- `09_categorical_beta_contrasts.R`
- `make_manuscript_stats_table.R`

### Root files

- `manuscript_stats_table.md` — compact manuscript-ready table for reporting

## Notes

- `fig7_rsa_base_vs_enhanced` is the current paper figure.
- Hypothesis-testing statistics for the paper are summarized in `manuscript_stats_table.md`.
- The script copies are archival snapshots; the refresh script reruns the originals in the parent analysis folder.
