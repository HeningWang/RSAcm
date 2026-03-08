# 07_bayesian_pairwise_full.R
#
# Posterior pairwise comparisons for the full Bayesian production model.
# Uses posterior expected predictions from the full brms model and reports
# prereg-relevant contrasts at centred propositional controversy (pc_prop_c = 0).
#
# Outputs:
#   data/bayesian_full_pairwise_summary.csv
#   data/bayesian_full_condition_predictions.csv

library(dplyr)
library(tidyr)
library(brms)

DATA_DIR <- "data"
dir.create(DATA_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c(
  "soviel ich weiß",
  "ja",
  "bekanntlich"
)

fit_path <- file.path(DATA_DIR, "fit_brms_full_3markers.rds")
stopifnot(file.exists(fit_path))

fit_full <- readRDS(fit_path)

newdata <- expand.grid(
  pc_prop_c = 0,
  pc_prag_c = c(-0.5, 0.5),
  g_c = c(-0.5, 0.5)
) |>
  as_tibble() |>
  mutate(
    pc_prag = ifelse(pc_prag_c < 0, "low", "high"),
    g = ifelse(g_c < 0, "low", "high"),
    condition = factor(
      paste0("pc_prag:", pc_prag, " | g:", g),
      levels = c(
        "pc_prag:low | g:low",
        "pc_prag:low | g:high",
        "pc_prag:high | g:low",
        "pc_prag:high | g:high"
      )
    )
  )

epred <- posterior_epred(fit_full, newdata = newdata, re_formula = NA)

# draws x conditions x categories
marker_values <- array(rep(1:3, each = dim(epred)[1] * dim(epred)[2]), dim = dim(epred))
expected_strength <- apply(epred * marker_values, c(1, 2), sum)
prob_stronger <- epred[, , 2] + epred[, , 3]  # P(marker >= ja)
prob_strongest <- epred[, , 3]                # P(marker = bekanntlich)

condition_summary <- tibble(
  condition = newdata$condition,
  pc_prag = newdata$pc_prag,
  g = newdata$g,
  mean_strength = colMeans(expected_strength),
  mean_strength_low = apply(expected_strength, 2, quantile, probs = 0.025),
  mean_strength_high = apply(expected_strength, 2, quantile, probs = 0.975),
  p_ge_ja = colMeans(prob_stronger),
  p_ge_ja_low = apply(prob_stronger, 2, quantile, probs = 0.025),
  p_ge_ja_high = apply(prob_stronger, 2, quantile, probs = 0.975),
  p_bek = colMeans(prob_strongest),
  p_bek_low = apply(prob_strongest, 2, quantile, probs = 0.025),
  p_bek_high = apply(prob_strongest, 2, quantile, probs = 0.975)
) |>
  arrange(condition)

idx_ll <- which(newdata$pc_prag == "low" & newdata$g == "low")
idx_lh <- which(newdata$pc_prag == "low" & newdata$g == "high")
idx_hl <- which(newdata$pc_prag == "high" & newdata$g == "low")
idx_hh <- which(newdata$pc_prag == "high" & newdata$g == "high")

contrast_draws <- tibble(
  g_effect_low_pc_prag = expected_strength[, idx_lh] - expected_strength[, idx_ll],
  g_effect_high_pc_prag = expected_strength[, idx_hh] - expected_strength[, idx_hl],
  pc_prag_effect_low_g = expected_strength[, idx_hl] - expected_strength[, idx_ll],
  pc_prag_effect_high_g = expected_strength[, idx_hh] - expected_strength[, idx_lh],
  interaction_h3 = (expected_strength[, idx_hh] - expected_strength[, idx_hl]) -
    (expected_strength[, idx_lh] - expected_strength[, idx_ll]),
  ll_vs_lh = expected_strength[, idx_ll] - expected_strength[, idx_lh],
  ll_vs_hl = expected_strength[, idx_ll] - expected_strength[, idx_hl],
  ll_vs_hh = expected_strength[, idx_ll] - expected_strength[, idx_hh],
  lh_vs_hl = expected_strength[, idx_lh] - expected_strength[, idx_hl],
  lh_vs_hh = expected_strength[, idx_lh] - expected_strength[, idx_hh],
  hl_vs_hh = expected_strength[, idx_hl] - expected_strength[, idx_hh]
)

summarise_contrast <- function(x, label, predicted = NA_character_) {
  tibble(
    contrast = label,
    predicted_direction = predicted,
    mean = mean(x),
    median = median(x),
    conf.low = quantile(x, 0.025),
    conf.high = quantile(x, 0.975),
    p_gt_0 = mean(x > 0),
    p_lt_0 = mean(x < 0)
  )
}

contrast_summary <- bind_rows(
  summarise_contrast(contrast_draws$g_effect_low_pc_prag,
                     "g effect at low pc_prag (H1 slice)", "> 0"),
  summarise_contrast(contrast_draws$g_effect_high_pc_prag,
                     "g effect at high pc_prag (H1 slice)", "> 0"),
  summarise_contrast(contrast_draws$pc_prag_effect_low_g,
                     "pc_prag effect at low g (H2 slice)", "< 0"),
  summarise_contrast(contrast_draws$pc_prag_effect_high_g,
                     "pc_prag effect at high g (H2 slice)", "< 0"),
  summarise_contrast(contrast_draws$interaction_h3,
                     "difference in g effect between high and low pc_prag (H3)", "< 0"),
  summarise_contrast(contrast_draws$ll_vs_lh, "pairwise: low/low - low/high", "< 0"),
  summarise_contrast(contrast_draws$ll_vs_hl, "pairwise: low/low - high/low", NA_character_),
  summarise_contrast(contrast_draws$ll_vs_hh, "pairwise: low/low - high/high", "< 0"),
  summarise_contrast(contrast_draws$lh_vs_hl, "pairwise: low/high - high/low", NA_character_),
  summarise_contrast(contrast_draws$lh_vs_hh, "pairwise: low/high - high/high", "< 0"),
  summarise_contrast(contrast_draws$hl_vs_hh, "pairwise: high/low - high/high", "< 0")
)

write.csv(condition_summary,
          file.path(DATA_DIR, "bayesian_full_condition_predictions.csv"),
          row.names = FALSE)
write.csv(contrast_summary,
          file.path(DATA_DIR, "bayesian_full_pairwise_summary.csv"),
          row.names = FALSE)

cat("\n=== Bayesian full-model condition predictions ===\n")
print(condition_summary)

cat("\n=== Bayesian full-model pairwise contrasts ===\n")
print(contrast_summary)