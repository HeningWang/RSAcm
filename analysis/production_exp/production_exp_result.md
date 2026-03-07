# Production experiment results

## Where the Bayesian models are

### Confirmatory Bayesian ordinal models

Main analysis script:
- [analysis/production_exp/03_hierarchical_regression.R](analysis/production_exp/03_hierarchical_regression.R)

Saved fits:
- [analysis/production_exp/data/fit_brms_additive_3markers.rds](analysis/production_exp/data/fit_brms_additive_3markers.rds)
- [analysis/production_exp/data/fit_brms_full_3markers.rds](analysis/production_exp/data/fit_brms_full_3markers.rds)

### Confirmatory full Bayesian model

The main full Bayesian model is:

$\texttt{marker} \sim pc\_prop\_c * pc\_prag\_c * g\_c + (1 \mid submission\_id)$

implemented in [analysis/production_exp/03_hierarchical_regression.R](analysis/production_exp/03_hierarchical_regression.R).

Notes:
- family: cumulative probit
- outcome: ordinal marker choice with 3 levels
- coding:
  - higher `pc_prop_c` = higher propositional controversy
  - higher `pc_prag_c` = higher pragmatic controversy
  - higher `g_c` = stronger speaker goal

### Bayesian sensitivity model

Robustness script:
- [analysis/production_exp/06_sensitivity_random_slopes.R](analysis/production_exp/06_sensitivity_random_slopes.R)

Saved fit:
- [analysis/production_exp/data/fit_brms_sensitivity_topic_slopes.rds](analysis/production_exp/data/fit_brms_sensitivity_topic_slopes.rds)

Sensitivity model:

$\texttt{marker} \sim pc\_prop\_c * pc\_prag\_c * g\_c + (1 + pc\_prag\_c + g\_c \mid submission\_id) + (1 \mid topic)$

This is the stricter robustness model, but not the primary confirmatory model.

## Which model is used for which plot

- [analysis/production_exp/plots/fig17_empirical_vs_model_by_condition.png](analysis/production_exp/plots/fig17_empirical_vs_model_by_condition.png): empirical proportions plus posterior predictions from the best-fitting additive `brms` cumulative-probit model.
- [analysis/production_exp/plots/fig18_posteriors_and_thresholds.png](analysis/production_exp/plots/fig18_posteriors_and_thresholds.png):
  - top panel = coefficients from the primary full `brms` cumulative-probit model
  - bottom panel = thresholds `mu[1]` and `mu[2]` from the Bayesian noisy-threshold Stan model in [analysis/production_exp/02_bayesian_thresholds.R](analysis/production_exp/02_bayesian_thresholds.R)
- [analysis/production_exp/plots/fig11_rsa_soft_thresholds.png](analysis/production_exp/plots/fig11_rsa_soft_thresholds.png): soft thresholds from the separate RSA model in [analysis/production_exp/04_rsa_soft_thresholds.R](analysis/production_exp/04_rsa_soft_thresholds.R)

So the paper figures currently combine two model families:
- cumulative-probit ordinal models (`brms`) for regression effects and posterior predictions
- noisy-threshold model (Stan) for the threshold plot in Fig. 18

The RSA model is a separate complementary analysis. It is not the source of the Fig. 18 threshold panel.

## How thresholds are inferred

There are two different threshold analyses in this project.

### 1. Noisy-threshold cumulative-probit model

This is the threshold model used for the threshold panel in Fig. 18.

Code:
- [analysis/production_exp/02_bayesian_thresholds.R](analysis/production_exp/02_bayesian_thresholds.R)
- [analysis/production_exp/models/noisy_threshold.stan](analysis/production_exp/models/noisy_threshold.stan)

Inference logic:

1. Each trial gets a latent score

$$
\eta_t = \beta_{pc\_prop} \, pc\_prop_t + \beta_{pc\_prag} \, pc\_prag_t + \beta_g \, g_t + u_{s(t)}
$$

2. Two ordered thresholds `mu[1] < mu[2]` divide that latent scale into three marker regions.
3. Base cumulative-probit probabilities are computed from those thresholds.
4. Marker-specific costs downweight `ja` and `bekanntlich`.
5. Stan infers the posterior over thresholds, coefficients, costs, and participant intercepts jointly from the observed marker choices.

Interpretation:
- values below the first threshold favor `soviel ich weiß`
- values between the thresholds favor `ja`
- values above the second threshold favor `bekanntlich`

These thresholds are therefore inferred as part of an ordinal latent-variable model, not by fitting the RSA utility directly.

### 2. RSA soft-threshold model

This is the separate RSA analysis.

Code:
- [analysis/production_exp/04_rsa_soft_thresholds.R](analysis/production_exp/04_rsa_soft_thresholds.R)

Inference logic:

1. Construct perceived controversy as

$$
PC = pc_{prop} \times pc_{prag}
$$

2. Construct utility as

$$
U(pc, g) = -w_{pc} \, pc + w_g \, g - w_{int} \, pcg
$$

3. Place soft intervals on the utility axis, with Gaussian threshold noise and marker costs.
4. Fit the resulting choice probabilities directly to observed production choices.

Interpretation:
- this model gives a more explicitly RSA-style account of how markers partition the utility landscape
- these are the thresholds shown in Fig. 11, not the thresholds shown in Fig. 18

## Main Bayesian statistics

### Additive model

Model:

$\texttt{marker} \sim pc\_prop\_c + pc\_prag\_c + g\_c + (1 \mid submission\_id)$

Key estimates:
- `pc_prop_c = -0.11`, 95% CrI [$-0.21$, $-0.02$]
- `pc_prag_c = -0.09`, 95% CrI [$-0.27$, $0.09$]
- `g_c = 0.24`, 95% CrI [$0.07$, $0.42$]

Interpretation:
- higher propositional controversy predicts weaker markers
- higher goal strength predicts stronger markers
- pragmatic controversy trends negative, but the main effect is uncertain

### Full model

Key fixed effects from [analysis/production_exp/data/fit_brms_full_3markers.rds](analysis/production_exp/data/fit_brms_full_3markers.rds):
- `pc_prop_c = -0.113`, 95% CrI [$-0.208$, $-0.018$]
- `pc_prag_c = -0.089`, 95% CrI [$-0.265$, $0.088$]
- `g_c = 0.245`, 95% CrI [$0.078$, $0.421$]
- `pc_prop_c:pc_prag_c = -0.075`, 95% CrI [$-0.262$, $0.105$]
- `pc_prop_c:g_c = -0.004`, 95% CrI [$-0.197$, $0.184$]
- `pc_prag_c:g_c = -0.327`, 95% CrI [$-0.674$, $0.020$]
- `pc_prop_c:pc_prag_c:g_c = -0.173`, 95% CrI [$-0.537$, $0.185$]

Model comparison:
- additive vs. full: $\Delta \mathrm{ELPD}_{\text{full}} = -1.3 \pm 2.3$
- conclusion: the additive model remains preferable as the primary descriptive summary

## Posterior pairwise comparisons from the full Bayesian model

Script:
- [analysis/production_exp/07_bayesian_pairwise_full.R](analysis/production_exp/07_bayesian_pairwise_full.R)

Outputs:
- [analysis/production_exp/data/bayesian_full_pairwise_summary.csv](analysis/production_exp/data/bayesian_full_pairwise_summary.csv)
- [analysis/production_exp/data/bayesian_full_condition_predictions.csv](analysis/production_exp/data/bayesian_full_condition_predictions.csv)

Condition means on the expected marker-strength scale:
- low `pc_prag`, low `g`: 2.11
- low `pc_prag`, high `g`: 2.38
- high `pc_prag`, low `g`: 2.16
- high `pc_prag`, high `g`: 2.21

Key contrasts:
- `g` effect at low `pc_prag`: mean $= 0.276$, 95% CrI [$0.112$, $0.442$], $P(>0)=0.9996$
- `g` effect at high `pc_prag`: mean $= 0.057$, 95% CrI [$-0.110$, $0.230$], $P(>0)=0.742$
- H3 interaction contrast: mean $= -0.219$, 95% CrI [$-0.456$, $0.018$], $P(<0)=0.966$

Interpretation:
- when pragmatic controversy is low, stronger speaker goal clearly increases marker strength
- when pragmatic controversy is high, the goal effect is much smaller
- this is the preregistered attenuation pattern

## Sensitivity model statistics

From [analysis/production_exp/data/brms_sensitivity_summary.csv](analysis/production_exp/data/brms_sensitivity_summary.csv):
- `pc_prop_c = -0.120`, 95% CrI [$-0.354$, $0.127$], $P(<0)=0.859$
- `pc_prag_c = -0.101`, 95% CrI [$-0.303$, $0.101$], $P(<0)=0.842$
- `g_c = 0.271`, 95% CrI [$0.036$, $0.506$], $P(>0)=0.988$
- `pc_prag_c:g_c = -0.360`, 95% CrI [$-0.717$, $0.000$], $P(<0)=0.975$

Interpretation:
- the key interaction remains negative even under a stricter random-effects structure
- this makes the interaction more credible as a directional effect

## Frequentist cross-check

Script:
- [analysis/production_exp/05_frequentist_ordinal.R](analysis/production_exp/05_frequentist_ordinal.R)

Outputs:
- [analysis/production_exp/data/frequentist_ordinal_coef_additive.csv](analysis/production_exp/data/frequentist_ordinal_coef_additive.csv)
- [analysis/production_exp/data/frequentist_ordinal_coef_full.csv](analysis/production_exp/data/frequentist_ordinal_coef_full.csv)
- [analysis/production_exp/data/frequentist_ordinal_model_compare.csv](analysis/production_exp/data/frequentist_ordinal_model_compare.csv)

Additive CLMM:
- `pc_prop_c = -0.113`, $p = .018$
- `pc_prag_c = -0.087`, $p = .336$
- `g_c = 0.243`, $p = .007$

Full CLMM:
- `pc_prag_c:g_c = -0.335`, $p = .064$

Model comparison:
- additive AIC = 1359.2
- full AIC = 1362.3
- likelihood-ratio test: $p = .293$

## RSA / noisy-threshold results

Scripts:
- [analysis/production_exp/02_bayesian_thresholds.R](analysis/production_exp/02_bayesian_thresholds.R)
- [analysis/production_exp/04_rsa_soft_thresholds.R](analysis/production_exp/04_rsa_soft_thresholds.R)

Outputs:
- [analysis/production_exp/data/fit_threshold_3markers.rds](analysis/production_exp/data/fit_threshold_3markers.rds)
- [analysis/production_exp/data/rsa_soft_threshold_summary.csv](analysis/production_exp/data/rsa_soft_threshold_summary.csv)

RSA soft-threshold summary:
- `w_pc = 0.406`, 95% CI [$0.152$, $1.113$]
- `w_g = 0.247`, 95% CI [$0.121$, $0.501$]
- `w_int = 0.617`, 95% CI [$0.244$, $1.572$]
- `threshold_soviel = -1.278`, 95% CI [$-1.965$, $-0.618$]
- `threshold_ja = -0.503`, 95% CI [$-0.755$, $-0.049$]
- `threshold_bekanntlich = -0.002`, 95% CI [$-0.175$, $0.520$]
- `sigma = 0.410`, 95% CI [$0.190$, $0.902$]

Interpretation:
- thresholds are ordered
- boundaries are soft rather than hard
- stronger markers incur nonzero costs
- the fitted utility landscape is consistent with weakest-sufficient behavior

## Final write-up

We analyzed 640 critical trials from 80 participants using Bayesian cumulative-probit mixed models, frequentist cumulative-link mixed models, and a complementary noisy-threshold RSA analysis. In the primary Bayesian models, higher propositional controversy reliably predicted weaker marker choice, while stronger speaker goal predicted stronger marker choice. In the additive Bayesian model, `pc_prop_c = -0.11`, 95% CrI [$-0.21$, $-0.02$], and `g_c = 0.24`, 95% CrI [$0.07$, $0.42$], whereas the main effect of pragmatic controversy was negative but uncertain, `pc_prag_c = -0.09`, 95% CrI [$-0.27$, $0.09$]. In the full Bayesian model, the critical interaction between pragmatic controversy and goal strength was also negative, `pc_prag_c:g_c = -0.33`, 95% CrI [$-0.67$, $0.02$], indicating that the positive effect of goal strength on marker strength was attenuated under high pragmatic controversy.

Posterior pairwise comparisons clarified this interaction on the prediction scale. Under low pragmatic controversy, increasing goal strength clearly increased expected marker strength (mean contrast $= 0.276$, 95% CrI [$0.112$, $0.442$], $P(>0)=0.9996$). Under high pragmatic controversy, the same goal manipulation produced only a much smaller increase (mean contrast $= 0.057$, 95% CrI [$-0.110$, $0.230$], $P(>0)=0.742$). The difference between these simple goal effects was negative (mean $= -0.219$, 95% CrI [$-0.456$, $0.018$], $P(<0)=0.966$), consistent with the preregistered attenuation hypothesis.

A stricter Bayesian sensitivity model with topic random intercepts and by-participant random slopes for pragmatic controversy and goal strength preserved this qualitative pattern. In that model, the interaction remained negative, `pc_prag_c:g_c = -0.360`, 95% CrI [$-0.717$, $0.000$], with $P(<0)=0.975$, suggesting that the attenuation effect is robust as a directional pattern even under a more conservative random-effects structure. Frequentist cumulative-link mixed models converged on the same overall conclusions: propositional controversy negatively predicted marker strength, goal strength positively predicted marker strength, and the `pc_prag × g` interaction was suggestive but not definitive.

Finally, the noisy-threshold RSA analysis recovered ordered marker thresholds and nonzero marker costs, supporting the interpretation that the three markers occupy partially overlapping regions on a latent utility scale and are chosen under a weakest-sufficient trade-off. Overall, the production data show that stronger consensus markers are favored in lower-controversy contexts and under stronger speaker goals, while pragmatic controversy dampens the influence of speaker goal on marker choice.