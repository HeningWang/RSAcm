# Analysis pipeline — Production experiment

## Quick start

```r
# from within analysis/production_exp/
source("run_pipeline.R")          # dummy data (default)
# Rscript run_pipeline.R real     # real magpie CSV (place in data/real_data.csv first)
```

## Directory layout

```text
analysis/production_exp/
├── generate_dummy_data.R     # Stage 0 — simulate N=80 participants
├── 01_empirical_plots.R      # Stage 1 — exploratory visualisations
├── 02_bayesian_thresholds.R  # Stage 2 — Stan noisy-threshold model
├── 03_hierarchical_regression.R  # Stage 3 — brms hierarchical regression
├── run_pipeline.R            # Orchestrator
├── models/
│   └── noisy_threshold.stan  # Stan program
├── data/                     # auto-created; CSV + cached .rds fits
└── plots/                    # auto-created; PDF + PNG figures
```

## Stages

### Stage 0 — Dummy data (`generate_dummy_data.R`)

Simulates `N = 80` participants assigned across 8 Latin-square lists.
Uses a cumulative-probit generative model with:

| Parameter | True value | Interpretation |
| --- | --- | --- |
| β\_pc\_prop | −0.8 | higher propositional controversy → weaker marker |
| β\_pc\_prag | −0.6 | higher pragmatic controversy → weaker marker |
| β\_g | +1.4 | stronger persuasive goal → stronger marker |
| costs | (0.0, 0.25, 0.6) | marker-specific sufficiency / markedness costs |
| σ\_u | 0.4 | between-participant SD |
| μ | (−0.6, 0.8) | ordinal thresholds for 3 ordered markers |

Writes `data/dummy_data.csv` (1 280 rows: 80 participants × 16 trials).

### Stage 1 — Empirical plots (`01_empirical_plots.R`)

| Figure | Content |
| --- | --- |
| fig1\_stacked\_bar | Marker proportions per condition (8 bars) |
| fig2\_heatmap | Mean marker strength heatmap (pc\_prop × pc\_prag, faceted by g) |
| fig3\_marginals | Marginal distributions for each factor |
| fig4\_marker\_curves | Marker proportions along the 1-D utility proxy axis |

### Stage 2 — Bayesian threshold inference (`02_bayesian_thresholds.R`)

Fits `models/noisy_threshold.stan` — a hierarchical cumulative-probit model:

```text
η_t = β_pc_prop · pc_prop + β_pc_prag · pc_prag + β_g · g + u_s
P(Y_t = k | η_t) ∝ P_base(Y_t = k | η_t, μ) · exp(-cost_k)
```

| Figure | Content |
| --- | --- |
| fig5\_posteriors | Posterior densities of βs and μs |
| fig6\_thresholds | Threshold CIs on utility axis with marker labels |
| fig7\_ppc | Posterior predictive check (observed vs. replicated frequencies) |

The fit is cached at `data/fit_threshold_3markers.rds`.

### Stage 3 — Hierarchical regression (`03_hierarchical_regression.R`)

Fits two `brms` models (family `cumulative("probit")`):

- **Model A** — additive: `marker ~ pc_prop + pc_prag + g + (1 | participant)`
- **Model B** — full: `marker ~ pc_prop * pc_prag * g + (1 | participant)`

Models compared via LOO-CV.

| Figure | Content |
| --- | --- |
| fig8\_coef\_plot | Posterior estimates of condition effects (Model A) |
| fig9\_cond\_effects | Predicted probabilities per condition × marker |
| fig10\_loo\_compare | LOO ELPD comparison of Models A and B |

## R package requirements

```r
install.packages(c(
  "dplyr", "tidyr", "ggplot2", "forcats",  # data wrangling + plotting
  "scales", "patchwork", "ggdist",          # plot helpers
  "posterior", "bayesplot",                  # MCMC diagnostics
  "rstan",                                   # Stan backend (or cmdstanr)
  "brms"                                     # hierarchical regression
))
```

Tested with R ≥ 4.2, rstan ≥ 2.21, brms ≥ 2.20.
