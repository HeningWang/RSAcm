# Manuscript-ready statistics table — Production experiment

Derived from the full Bayesian ordinal model (brms, cumulative probit) and RSA soft-threshold model.

## Hypothesis contrasts (brms full model)

Expected marker strength on a 1–3 ordinal scale (soviel=1, ja=2, bekanntlich=3). Contrasts computed at centred pc_prop_c = 0.

| Section | Hypothesis | Contrast | Predicted | Estimate | 95% CrI | P(>0) | P(<0) |
| --- | --- | --- | --- | ---: | --- | ---: | ---: |
| Goal effect | H1 | g effect at low pc_prag | > 0 | 0.276 | [0.112, 0.442] | 1.000 | 0.000 |
| Goal effect | H1 | g effect at high pc_prag | > 0 | 0.057 | [-0.110, 0.230] | 0.742 | 0.258 |
| Pragmatic controversy | H2 | pc_prag effect at low g | < 0 | 0.052 | [-0.122, 0.228] | 0.724 | 0.276 |
| Pragmatic controversy | H2 | pc_prag effect at high g | < 0 | -0.167 | [-0.331, -0.005] | 0.022 | 0.978 |
| Interaction | H3 | g effect difference (high − low pc_prag) | < 0 | -0.219 | [-0.456, 0.018] | 0.034 | 0.966 |

## Pairwise condition comparisons (brms full model)

| Comparison | Estimate | 95% CrI | P(>0) | P(<0) |
| --- | ---: | --- | ---: | ---: |
| low/low − low/high | -0.276 | [-0.442, -0.112] | 0.000 | 1.000 |
| low/low − high/low | -0.052 | [-0.228, 0.122] | 0.276 | 0.724 |
| low/low − high/high | -0.109 | [-0.282, 0.062] | 0.103 | 0.897 |
| low/high − high/low | 0.224 | [0.061, 0.386] | 0.996 | 0.004 |
| low/high − high/high | 0.167 | [0.005, 0.331] | 0.978 | 0.022 |
| high/low − high/high | -0.057 | [-0.230, 0.110] | 0.258 | 0.742 |

## Condition-level predictions (brms full model)

| Condition | Mean strength | 95% CrI | P(marker >= ja) | P(bekanntlich) |
| --- | ---: | --- | ---: | ---: |
| pc_prag:low, g:low | 2.106 | [1.981, 2.228] | 0.731 | 0.375 |
| pc_prag:low, g:high | 2.382 | [2.266, 2.495] | 0.847 | 0.535 |
| pc_prag:high, g:low | 2.158 | [2.029, 2.278] | 0.755 | 0.403 |
| pc_prag:high, g:high | 2.215 | [2.089, 2.337] | 0.780 | 0.435 |

## RSA soft-threshold model parameters

| Parameter | Estimate | 95% CI |
| --- | ---: | --- |
| w_pc | 0.406 | [0.152, 1.113] |
| w_g | 0.247 | [0.121, 0.501] |
| w_int | 0.617 | [0.244, 1.572] |
| pc_prag_low | 0.552 | [0.270, 0.807] |
| threshold (soviel) | -1.278 | [-1.965, -0.618] |
| threshold (ja) | -0.503 | [-0.755, -0.049] |
| threshold (bekanntlich) | -0.002 | [-0.175, 0.520] |
| sigma | 0.410 | [0.190, 0.902] |
| cost (ja) | 0.563 | [0.164, 1.918] |
| cost (bekanntlich) | 0.456 | [0.139, 1.522] |
