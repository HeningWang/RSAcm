# Comprehension experiment results

## Overview

The current comprehension dataset contains 80 participants, 640 critical trials, 640 filler trials, and 80 training trials. All confirmatory analyses were run on the 640 critical, non-training trials only.

Primary analysis scripts:

- [analysis/comprehension_exp/04_empirical_plots.R](analysis/comprehension_exp/04_empirical_plots.R)
- [analysis/comprehension_exp/05_bayesian_beta_models.R](analysis/comprehension_exp/05_bayesian_beta_models.R)
- [analysis/comprehension_exp/06_bayesian_contrasts.R](analysis/comprehension_exp/06_bayesian_contrasts.R)
- [analysis/comprehension_exp/07_random_effects_sensitivity.R](analysis/comprehension_exp/07_random_effects_sensitivity.R)
- [analysis/comprehension_exp/07_rsa_listener_fit.R](analysis/comprehension_exp/07_rsa_listener_fit.R)

## Which model is used for hypothesis testing?

The hypothesis tests now use the main Bayesian zero/one-inflated beta model fit in [analysis/comprehension_exp/05_bayesian_beta_models.R](analysis/comprehension_exp/05_bayesian_beta_models.R), not the earlier beta-regression version.

For each dependent variable, the confirmatory model is:

$$
y \sim \texttt{marker\_strength\_c} * pc_{\mathrm{prag},c} + (1 \mid \texttt{submission\_id}) + (1 \mid \texttt{topic})
$$

with a `zero_one_inflated_beta()` likelihood in `brms`, plus intercept-only submodels for `phi`, `zoi`, and `coi`.

This is the main inferential model because the rating scales contain genuine boundary responses:

- inferred goal strength includes 30 responses at 100
- adoption likelihood includes 21 responses at 0 and 13 responses at 100

So the ZOIB model is preferable to the earlier transformed-beta approximation because it models the boundary mass directly rather than forcing all observations into $(0,1)$.

Saved confirmatory fits:

- [analysis/comprehension_exp/data/fit_brms_goal_zoib_full.rds](analysis/comprehension_exp/data/fit_brms_goal_zoib_full.rds)
- [analysis/comprehension_exp/data/fit_brms_adoption_zoib_full.rds](analysis/comprehension_exp/data/fit_brms_adoption_zoib_full.rds)

## Relation to the preregistration

The current pipeline remains broadly aligned with the preregistered comprehension analysis in [writing/preregistration.tex](writing/preregistration.tex#L303-L345).

What is preserved:

- descriptive summaries for both dependent variables
- a confirmatory hierarchical model with marker strength, pragmatic controversy, and their interaction
- posterior expected predictions and directional contrasts for H4-H6
- an exploratory RSA listener analysis

What changed:

- the likelihood is now zero/one-inflated beta rather than ordinary beta, because the observed ratings include exact 0s and 100s
- the experiment materials used the documented balanced-assignment deviation rather than the strict preregistered modal assignment; see [analysis/comprehension_exp/item_selection_writeup.md](analysis/comprehension_exp/item_selection_writeup.md)

## Coding and prediction conventions

- `marker_strength` is coded ordinally: 1 = `soviel ich weiß`, 2 = `ja`, 3 = `bekanntlich`
- `marker_strength_c = marker_strength - 2`
- `pc_prag_c` is contrast-coded as $-0.5$ for low pragmatic controversy and $+0.5$ for high pragmatic controversy
- ratings are converted from 0-100 to 0-1 proportions for model fitting
- hypothesis-test predictions are population-level predictions computed with `re_formula = NA`

Thus the hypothesis tests are based on the population-level posterior predictions, not on participant- or item-specific random-effect predictions.

## Main confirmatory results

### Inferred goal strength

From [analysis/comprehension_exp/data/brms_goal_zoib_fixef.csv](analysis/comprehension_exp/data/brms_goal_zoib_fixef.csv):

- `marker_strength_c = 0.244`, 95% CrI [$0.156$, $0.331$]
- `pc_prag_c = 0.019`, 95% CrI [$-0.099$, $0.137$]
- `marker_strength_c:pc_prag_c = 0.053`, 95% CrI [$-0.116$, $0.214$]

Interpretation:

- stronger markers clearly increase inferred speaker goal strength
- pragmatic controversy shows no reliable main effect on inferred goal strength
- there is no clear evidence that pragmatic controversy modulates the marker-strength effect on inferred goal strength

Population-level posterior expected ratings from [analysis/comprehension_exp/data/comprehension_posterior_predictions_goal.csv](analysis/comprehension_exp/data/comprehension_posterior_predictions_goal.csv):

- low pragmatic controversy:
  - `soviel ich weiß`: 64.8
  - `ja`: 69.5
  - `bekanntlich`: 73.8
- high pragmatic controversy:
  - `soviel ich weiß`: 64.0
  - `ja`: 69.9
  - `bekanntlich`: 75.1

### Adoption likelihood

From [analysis/comprehension_exp/data/brms_adoption_zoib_fixef.csv](analysis/comprehension_exp/data/brms_adoption_zoib_fixef.csv):

- `marker_strength_c = 0.052`, 95% CrI [$-0.044$, $0.147$]
- `pc_prag_c = -0.142`, 95% CrI [$-0.276$, $-0.005$]
- `marker_strength_c:pc_prag_c = 0.028`, 95% CrI [$-0.155$, $0.209$]

Interpretation:

- the marker-strength effect on adoption is positive in direction but small and uncertain
- high pragmatic controversy lowers adoption likelihood overall
- there is no reliable interaction between marker strength and pragmatic controversy for adoption

Population-level posterior expected ratings from [analysis/comprehension_exp/data/comprehension_posterior_predictions_adoption.csv](analysis/comprehension_exp/data/comprehension_posterior_predictions_adoption.csv):

- low pragmatic controversy:
  - `soviel ich weiß`: 55.6
  - `ja`: 56.5
  - `bekanntlich`: 57.3
- high pragmatic controversy:
  - `soviel ich weiß`: 51.6
  - `ja`: 53.2
  - `bekanntlich`: 54.7

## Hypothesis evaluation

Posterior contrast summaries are in [analysis/comprehension_exp/data/comprehension_posterior_contrasts.csv](analysis/comprehension_exp/data/comprehension_posterior_contrasts.csv).

### H4: stronger markers imply stronger inferred speaker goal

Supported.

Key contrasts:

- strong vs weak, low pragmatic controversy: mean $= 8.95$, 95% CrI [$5.17$, $12.76$], $P(>0)=1.000$
- strong vs weak, high pragmatic controversy: mean $= 11.02$, 95% CrI [$5.19$, $16.54$], $P(>0)=0.9998$

Conclusion:

- listeners robustly infer stronger speaker goal from stronger consensus markers
- this is the clearest and most stable result in the comprehension data

### H5: stronger markers increase adoption likelihood

Not clearly supported.

Key contrasts:

- strong vs weak, low pragmatic controversy: mean $= 1.76$, 95% CrI [$-3.13$, $6.55$], $P(>0)=0.756$
- strong vs weak, high pragmatic controversy: mean $= 3.09$, 95% CrI [$-4.15$, $10.08$], $P(>0)=0.801$

Conclusion:

- the adoption data do not show a robust monotonic increase with marker strength
- any positive marker effect on adoption remains too uncertain for a confirmatory claim

### H6: credibility discounting under high pragmatic controversy

Not supported.

The preregistered prediction was that the strong-vs-weak adoption increase should be smaller under high pragmatic controversy than under low pragmatic controversy.

Observed contrast:

- `credibility_discount = 1.33`, 95% CrI [$-7.19$, $9.74$]
- $P(<0)=0.380$

Conclusion:

- the posterior does not support the predicted negative credibility-discount pattern
- the interaction is too weak and too uncertain to sustain the preregistered H6 claim

## Sensitivity analysis

The robustness check in [analysis/comprehension_exp/07_random_effects_sensitivity.R](analysis/comprehension_exp/07_random_effects_sensitivity.R) refits the same ZOIB likelihood with participant-level random slopes for `marker_strength_c` and `pc_prag_c`.

Comparison output:

- [analysis/comprehension_exp/data/comprehension_zoib_sensitivity_fixef_comparison.csv](analysis/comprehension_exp/data/comprehension_zoib_sensitivity_fixef_comparison.csv)
- [analysis/comprehension_exp/data/comprehension_zoib_sensitivity_predictions.csv](analysis/comprehension_exp/data/comprehension_zoib_sensitivity_predictions.csv)

Main vs sensitivity estimates:

- inferred goal strength, marker effect:
  - main: $0.244$ [$0.156$, $0.331$]
  - sensitivity: $0.240$ [$0.136$, $0.342$]
- adoption likelihood, pragmatic controversy effect:
  - main: $-0.142$ [$-0.276$, $-0.005$]
  - sensitivity: $-0.153$ [$-0.315$, $0.006$]

Interpretation:

- the goal-strength marker effect is highly stable across random-effects specifications
- the adoption-side pragmatic-controversy effect weakens slightly in certainty under the richer random-effects structure, but its direction stays the same
- the substantive conclusions are therefore unchanged

## Exploratory RSA listener analysis

Script:

- [analysis/comprehension_exp/07_rsa_listener_fit.R](analysis/comprehension_exp/07_rsa_listener_fit.R)

This stage reuses the production-fitted RSA speaker parameters from [analysis/production_exp/data/fit_rsa_soft_thresholds.rds](analysis/production_exp/data/fit_rsa_soft_thresholds.rds) and then fits the preregistered listener adoption link:

$$
  ext{logit}(P_{\mathrm{adopt}}) = \eta_0 + \eta_g E[g \mid u, pc] - \eta_{pc} pc - \eta_{int} E[g \mid u, pc]pc
$$

Parameter summary from [analysis/comprehension_exp/data/comprehension_rsa_listener_parameter_summary.csv](analysis/comprehension_exp/data/comprehension_rsa_listener_parameter_summary.csv):

- `eta_0 = 6.92`, 95% interval [$-9.31$, $22.71$]
- `eta_g = -13.12`, 95% interval [$-44.53$, $19.29$]
- `eta_pc = 46.08`, 95% interval [$-63.27$, $150.82$]
- `eta_int = -90.73`, 95% interval [$-301.86$, $126.78$]

Interpretation:

- the RSA listener parameters remain very weakly constrained
- the model captures some condition-level adoption variation but systematically underpredicts observed inferred-goal ratings
- this exploratory stage is therefore not strong enough for confirmatory theoretical conclusions

Goal-calibration summary from [analysis/comprehension_exp/data/comprehension_rsa_goal_calibration_summary.csv](analysis/comprehension_exp/data/comprehension_rsa_goal_calibration_summary.csv):

- `alpha = 8.69`
- `beta = 1.21`
- 95% CI for `alpha`: [$-50.64$, $68.02$]
- 95% CI for `beta`: [$0.02$, $2.40$]
- raw RMSE $= 20.26$
- calibrated RMSE $= 6.76$
- weighted correlation remains $0.355$

This goal-calibration step can be understood as an explicit observation model for inferred goal ratings:

$$
\hat g_{\mathrm{rating}} = \alpha + \beta \cdot E[g \mid u, pc].
$$

It shows that the RSA underprediction of inferred goal strength is largely a scale/intercept mismatch. The production-fitted latent $E[g \mid u, pc]$ carries some directional information, but it sits too low and is too compressed relative to the direct comprehension ratings. Adding this simple goal observation layer greatly improves absolute fit while leaving the correlation unchanged, which suggests that the main problem is misalignment of scales rather than a complete failure of ordinal structure.

An additional exploratory enhancement allows the comprehension-side RSA transfer to learn a weaker contribution of propositional controversy together with marker-specific listener offsets. The resulting summary is saved in [analysis/comprehension_exp/data/comprehension_rsa_enhanced_summary.csv](analysis/comprehension_exp/data/comprehension_rsa_enhanced_summary.csv).

Key enhanced parameters:

- `k_pc_prop = 0.466`
- goal-side `ja` offset $= 16.38$
- goal-side `bekanntlich` offset $= 20.43$
- adoption-side `ja` offset $= -2.55$
- adoption-side `bekanntlich` offset $= -6.20$

Fit improvement:

- goal RMSE: from $6.76$ to $4.04$
- adoption RMSE: from $7.54$ to $7.48$

This suggests that the production-fitted RSA transfer was indeed overweighting propositional controversy in comprehension, and that listeners treat markers, especially `ja`, with extra marker-specific structure beyond the original transported latent-goal model.

Condition-level summaries from [analysis/comprehension_exp/data/comprehension_rsa_listener_condition_summary.csv](analysis/comprehension_exp/data/comprehension_rsa_listener_condition_summary.csv):

- low pragmatic controversy, `soviel ich weiß`:
  - observed goal = 63.2, RSA goal = 46.6
  - observed adoption = 54.8, RSA adoption = 54.5
- low pragmatic controversy, `ja`:
  - observed goal = 72.1, RSA goal = 48.3
  - observed adoption = 60.8, RSA adoption = 59.9
- low pragmatic controversy, `bekanntlich`:
  - observed goal = 73.1, RSA goal = 52.5
  - observed adoption = 56.8, RSA adoption = 55.6
- high pragmatic controversy, `soviel ich weiß`:
  - observed goal = 58.7, RSA goal = 49.7
  - observed adoption = 49.4, RSA adoption = 51.3
- high pragmatic controversy, `ja`:
  - observed goal = 74.7, RSA goal = 49.3
  - observed adoption = 55.0, RSA adoption = 54.7
- high pragmatic controversy, `bekanntlich`:
  - observed goal = 71.0, RSA goal = 52.4
  - observed adoption = 51.8, RSA adoption = 56.4

## Improved analysis: categorical beta model

The preregistered analysis used ordinal-linear marker strength (1/2/3) with a ZOIB likelihood. An improved supplementary analysis uses:

1. **Categorical marker coding** (treatment-coded, reference = `soviel ich weiß`) — drops the equal-spacing assumption
2. **Standard beta regression** — removes 3 nuisance ZOIB parameters for rare boundary responses
3. **`pc_prop_c` as a covariate** — propositional controversy from the norming study

Scripts: [08_categorical_beta_models.R](analysis/comprehension_exp/08_categorical_beta_models.R), [09_categorical_beta_contrasts.R](analysis/comprehension_exp/09_categorical_beta_contrasts.R)

### Goal strength (categorical beta)

- `marker_catja = 0.486`, 95% CrI [$0.261$, $0.710$]
- `marker_catbekanntlich = 0.456`, 95% CrI [$0.246$, $0.661$]
- `pc_prag_c = -0.150`, 95% CrI [$-0.373$, $0.062$]
- `pc_prop_c = -0.072`, 95% CrI [$-0.196$, $0.054$]
- `marker_catja:pc_prag_c = 0.282`, 95% CrI [$-0.049$, $0.615$]

Key contrasts (0-100 scale):

- ja vs soviel, low pc_prag: $7.28$, P(>0)=0.988
- ja vs soviel, high pc_prag: $13.3$, P(>0)=1.000
- bek vs soviel, low pc_prag: $8.72$, P(>0)=1.000
- bek vs soviel, high pc_prag: $10.7$, P(>0)=0.998
- bek vs ja (both conditions): near zero, not reliable

### Adoption likelihood (categorical beta)

- `marker_catja = 0.416`, 95% CrI [$0.135$, $0.697$]
- `marker_catbekanntlich = 0.170`, 95% CrI [$-0.087$, $0.425$]
- `pc_prag_c = -0.191`, 95% CrI [$-0.474$, $0.094$]
- `pc_prop_c = 0.071`, 95% CrI [$-0.228$, $0.359$]
- `marker_catja:pc_prag_c = -0.313`, 95% CrI [$-0.752$, $0.112$], P(<0)=0.925

Key contrasts (0-100 scale):

- ja vs soviel, low pc_prag: $13.6$, P(>0)=0.998
- ja vs soviel, high pc_prag: $6.44$, P(>0)=0.944
- bek vs soviel, low pc_prag: $4.83$, P(>0)=0.935
- bek vs ja, low pc_prag: $-8.79$, P(<0)=0.986
- ja credibility discount: $-7.18$, P(<0)=0.917
- pc_prag main effect: $-7.54$, P(<0)=1.000

### Non-monotonic adoption pattern

The categorical model reveals that `ja` drives the strongest adoption effect, while `bekanntlich` produces weaker adoption despite equally strong inferred goal. Under low pragmatic controversy, `bekanntlich` is reliably *lower* than `ja` on adoption (P(<0)=0.986). This non-monotonic pattern was invisible to the preregistered linear model, which averaged over it.

Interpretation: `bekanntlich` may trigger pragmatic reactance — listeners infer strong speaker intent but resist adopting the action when the claim is presented as beyond dispute.

## Paper-ready summary

The primary analysis uses the preregistered ZOIB model with ordinal-linear marker strength (scripts 05–06). The improved categorical beta analysis (scripts 08–09) serves as a supplementary analysis that addresses two limitations: the equal-spacing assumption and ZOIB overparameterisation.

The central confirmatory result is that both `ja` and `bekanntlich` reliably increase inferred speaker goal strength relative to `soviel ich weiß` (H4). The categorical model further reveals a non-monotonic adoption pattern (H5): `ja` drives the strongest adoption boost, while `bekanntlich` does not reliably exceed `soviel ich weiß` on adoption. This dissociation between goal inference and action uptake suggests that consensus markers function primarily as epistemic signals, and that `bekanntlich` may trigger pragmatic reactance. High pragmatic controversy reliably reduces adoption across markers (H6 partial), and the ja-specific adoption advantage is attenuated under high pragmatic controversy (P(<0)=0.92), providing marginally credible evidence for credibility discounting.

## Key files

Main pipeline:

- [analysis/comprehension_exp/run_pipeline.R](analysis/comprehension_exp/run_pipeline.R)

Key outputs:

- [analysis/comprehension_exp/data/analysis_data.csv](analysis/comprehension_exp/data/analysis_data.csv)
- [analysis/comprehension_exp/data/brms_goal_zoib_fixef.csv](analysis/comprehension_exp/data/brms_goal_zoib_fixef.csv)
- [analysis/comprehension_exp/data/brms_adoption_zoib_fixef.csv](analysis/comprehension_exp/data/brms_adoption_zoib_fixef.csv)
- [analysis/comprehension_exp/data/comprehension_posterior_contrasts.csv](analysis/comprehension_exp/data/comprehension_posterior_contrasts.csv)
- [analysis/comprehension_exp/data/comprehension_zoib_sensitivity_fixef_comparison.csv](analysis/comprehension_exp/data/comprehension_zoib_sensitivity_fixef_comparison.csv)
- [analysis/comprehension_exp/data/comprehension_rsa_goal_calibration_summary.csv](analysis/comprehension_exp/data/comprehension_rsa_goal_calibration_summary.csv)
- [analysis/comprehension_exp/data/comprehension_rsa_listener_parameter_summary.csv](analysis/comprehension_exp/data/comprehension_rsa_listener_parameter_summary.csv)
- [analysis/comprehension_exp/plots/fig4_zoib_model_coefficients.png](analysis/comprehension_exp/plots/fig4_zoib_model_coefficients.png)
- [analysis/comprehension_exp/plots/fig5_comprehension_posterior_predictions.png](analysis/comprehension_exp/plots/fig5_comprehension_posterior_predictions.png)
- [analysis/comprehension_exp/plots/fig6_zoib_sensitivity_coefficients.png](analysis/comprehension_exp/plots/fig6_zoib_sensitivity_coefficients.png)
- [analysis/comprehension_exp/plots/fig6_rsa_listener_predictions.png](analysis/comprehension_exp/plots/fig6_rsa_listener_predictions.png)
- [analysis/comprehension_exp/plots/fig7_rsa_base_vs_enhanced.png](analysis/comprehension_exp/plots/fig7_rsa_base_vs_enhanced.png)
- [analysis/comprehension_exp/data/brms_goal_cat_beta_fixef.csv](analysis/comprehension_exp/data/brms_goal_cat_beta_fixef.csv)
- [analysis/comprehension_exp/data/brms_adoption_cat_beta_fixef.csv](analysis/comprehension_exp/data/brms_adoption_cat_beta_fixef.csv)
- [analysis/comprehension_exp/data/cat_beta_posterior_contrasts.csv](analysis/comprehension_exp/data/cat_beta_posterior_contrasts.csv)
- [analysis/comprehension_exp/data/cat_beta_posterior_predictions_goal.csv](analysis/comprehension_exp/data/cat_beta_posterior_predictions_goal.csv)
- [analysis/comprehension_exp/data/cat_beta_posterior_predictions_adoption.csv](analysis/comprehension_exp/data/cat_beta_posterior_predictions_adoption.csv)
- [analysis/comprehension_exp/plots/fig8_cat_beta_coefficients.png](analysis/comprehension_exp/plots/fig8_cat_beta_coefficients.png)
- [analysis/comprehension_exp/plots/fig9_cat_beta_posterior_predictions.png](analysis/comprehension_exp/plots/fig9_cat_beta_posterior_predictions.png)
