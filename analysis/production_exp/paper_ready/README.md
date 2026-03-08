# Paper-ready production bundle

This folder collects the final production-side materials currently intended for the paper:

- Figure 11: RSA soft thresholds along the latent utility axis
- Figure 17: Empirical vs model-predicted marker proportions by condition
- Bayesian hypothesis contrasts (H1, H2, H3) from the full brms model
- RSA soft-threshold parameter estimates

## Refresh command

From the repository root:

```bash
Rscript analysis/production_exp/paper_ready/reproduce_paper_ready.R
```

This reruns:

- `04_rsa_soft_thresholds.R`
- `07_bayesian_pairwise_full.R`
- `08_final_paper_plots.R`

and then copies the current outputs into this folder.

It also rebuilds:

- `manuscript_stats_table.md`
- `data/manuscript_stats_table.csv`

## Folder contents

### `plots/`

- `fig11_rsa_soft_thresholds.{png,pdf}` — marker probabilities along the latent utility axis with noisy threshold bands
- `fig17_empirical_vs_model_by_condition.{png,pdf}` — empirical marker proportions with bootstrap CIs vs brms additive model predictions

### `data/`

- `dummy_data.csv` — production experiment data used in all analyses
- `norming_means.csv` — norming study means for propositional controversy
- `rsa_soft_threshold_summary.csv` — RSA model parameter estimates with 95% CIs
- `bayesian_full_pairwise_summary.csv` — posterior contrasts (H1, H2, H3) with CIs and posterior probabilities
- `bayesian_full_condition_predictions.csv` — condition-level posterior predictions
- `manuscript_stats_table.csv` — combined stats table for manuscript reporting

### `scripts/`

Snapshot copies of the main scripts used to generate the paper-facing outputs:

- `04_rsa_soft_thresholds.R`
- `07_bayesian_pairwise_full.R`
- `08_final_paper_plots.R`
- `make_manuscript_stats_table.R`

### Root files

- `manuscript_stats_table.md` — compact manuscript-ready table for reporting
- `reproduce_paper_ready.R` — refresh script

## Models

- **Hypothesis testing:** Full brms cumulative-probit model (`fit_brms_full_3markers.rds`) with all interaction terms. Contrasts report posterior probabilities and 95% credible intervals for H1 (goal effect), H2 (pragmatic controversy effect), H3 (interaction).
- **Figure 17 predictions:** Additive brms model (`fit_brms_additive_3markers.rds`) — used for cleaner visual comparison against empirical data.
- **Figure 11 / RSA:** Cost-augmented noisy-threshold RSA model (`fit_rsa_soft_thresholds.rds`) — MAP estimates with Laplace-approximation CIs.
