# 09_categorical_beta_contrasts.R
#
# Posterior expected predictions and hypothesis contrasts for the categorical-
# marker beta model (08_categorical_beta_models.R).
#
# Because marker is now categorical, we get full 3 × 2 cell predictions
# without any linearity assumption.  Contrasts are computed directly on the
# posterior expected values (response scale, 0–100).
#
# Outputs:
#   data/cat_beta_posterior_predictions_goal.csv
#   data/cat_beta_posterior_predictions_adoption.csv
#   data/cat_beta_posterior_contrasts.csv
#   plots/fig9_cat_beta_posterior_predictions.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(brms)
library(aida)

UTILS_PATH <- if (file.exists("00_utils.R")) "00_utils.R" else file.path("analysis", "comprehension_exp", "00_utils.R")
source(UTILS_PATH)

SCRIPT_DIR <- get_script_dir()
DATA_DIR <- file.path(SCRIPT_DIR, "data")

CSP_colors <- c(
  "#7581B3", "#99C2C2", "#C65353", "#E2BA78", "#5C7457", "#575463",
  "#B0B7D4", "#66A3A3", "#DB9494", "#D49735", "#9BB096", "#D4D3D9",
  "#414C76", "#993333"
)
marker_colors <- setNames(CSP_colors[seq_along(MARKERS_ORDERED)], MARKERS_ORDERED)

theme_set(theme_aida())

theme_comp <- function() {
  theme_aida() +
    theme(
      axis.text.y = element_text(size = 12),
      axis.text.x = element_text(size = 11),
      axis.title = element_text(size = 13),
      strip.text = element_text(size = 12, face = "bold"),
      legend.text = element_text(size = 11),
      legend.title = element_text(size = 12)
    )
}

# ── Load fits ───────────────────────────────────────────────────────────
fit_goal <- readRDS(file.path(DATA_DIR, "fit_brms_goal_cat_beta.rds"))
fit_adopt <- readRDS(file.path(DATA_DIR, "fit_brms_adoption_cat_beta.rds"))

# ── Prediction grid (categorical) ──────────────────────────────────────
crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = FALSE)

newdata <- tidyr::expand_grid(
  marker_cat = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED, ordered = FALSE),
  pc_prag = factor(c("low", "high"), levels = c("low", "high"))
) |>
  mutate(
    pc_prag_c = ifelse(pc_prag == "high", 0.5, -0.5),
    pc_prop_c = 0,  # evaluate at mean propositional controversy
    topic = factor(levels(crit$topic)[1], levels = levels(crit$topic)),
    submission_id = factor(levels(crit$submission_id)[1], levels = levels(crit$submission_id))
  )

# ── Posterior expected predictions ──────────────────────────────────────
summarise_epred <- function(fit, outcome_name) {
  ep <- posterior_epred(fit, newdata = newdata, re_formula = NA)
  pred <- tibble(
    outcome = outcome_name,
    marker = newdata$marker_cat,
    pc_prag = newdata$pc_prag,
    mean = colMeans(ep),
    lower = apply(ep, 2, quantile, probs = 0.025),
    upper = apply(ep, 2, quantile, probs = 0.975)
  )
  list(draws = ep, summary = pred)
}

goal_pred <- summarise_epred(fit_goal, "Inferred goal strength")
adopt_pred <- summarise_epred(fit_adopt, "Adoption likelihood")

# Scale to 0–100 for predictions
scale100 <- function(df) mutate(df, mean = mean * 100, lower = lower * 100, upper = upper * 100)

write.csv(scale100(goal_pred$summary),
          file.path(DATA_DIR, "cat_beta_posterior_predictions_goal.csv"), row.names = FALSE)
write.csv(scale100(adopt_pred$summary),
          file.path(DATA_DIR, "cat_beta_posterior_predictions_adoption.csv"), row.names = FALSE)

# ── Contrasts ───────────────────────────────────────────────────────────
contrast_summary <- function(draws, outcome_name) {
  # Column naming: marker__pc_prag
  colnames(draws) <- paste(newdata$marker_cat, newdata$pc_prag, sep = "__")

  weak_low  <- draws[, "soviel ich weiß__low"]
  mid_low   <- draws[, "ja__low"]
  strong_low  <- draws[, "bekanntlich__low"]
  weak_high <- draws[, "soviel ich weiß__high"]
  mid_high  <- draws[, "ja__high"]
  strong_high <- draws[, "bekanntlich__high"]

  contrasts <- list(
    # H4/H5: monotonic marker-strength effect within each pc_prag level
    ja_vs_soviel_low       = mid_low - weak_low,
    bek_vs_soviel_low      = strong_low - weak_low,
    bek_vs_ja_low          = strong_low - mid_low,
    ja_vs_soviel_high      = mid_high - weak_high,
    bek_vs_soviel_high     = strong_high - weak_high,
    bek_vs_ja_high         = strong_high - mid_high,
    # Overall strong vs weak (averaging over pc_prag)
    bek_vs_soviel_overall  = ((strong_low + strong_high) - (weak_low + weak_high)) / 2,
    # H6: credibility discounting — does the bek-vs-soviel difference shrink
    # under high pc_prag?
    credibility_discount   = (strong_high - weak_high) - (strong_low - weak_low),
    # pc_prag main effect (averaging over markers)
    pc_prag_effect         = ((weak_high + mid_high + strong_high) -
                              (weak_low + mid_low + strong_low)) / 3
  )

  bind_rows(lapply(names(contrasts), function(name) {
    x <- contrasts[[name]]
    tibble(
      outcome    = outcome_name,
      contrast   = name,
      mean       = mean(x) * 100,
      lower      = quantile(x, 0.025) * 100,
      upper      = quantile(x, 0.975) * 100,
      p_gt_0     = mean(x > 0),
      p_lt_0     = mean(x < 0)
    )
  }))
}

contrasts_out <- bind_rows(
  contrast_summary(goal_pred$draws, "Inferred goal strength"),
  contrast_summary(adopt_pred$draws, "Adoption likelihood")
)

write.csv(contrasts_out,
          file.path(DATA_DIR, "cat_beta_posterior_contrasts.csv"), row.names = FALSE)

cat("\n=== Posterior contrasts (categorical beta, 0-100 scale) ===\n")
print(contrasts_out, n = 40)

# ── Prediction plot ─────────────────────────────────────────────────────
predictions <- bind_rows(scale100(goal_pred$summary), scale100(adopt_pred$summary)) |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high"))
  )

p_pred <- ggplot(predictions,
                 aes(x = marker, y = mean, colour = marker, group = pc_prag)) +
  geom_point(size = 2.8) +
  geom_line(aes(group = pc_prag), linewidth = 0.75, colour = "#444444") +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.08, linewidth = 0.7) +
  facet_grid(outcome ~ pc_prag) +
  scale_colour_manual(values = marker_colors) +
  labs(x = NULL, y = "Posterior expected rating (0–100)", colour = "Marker") +
  theme_comp() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(angle = 18, hjust = 1),
    panel.grid.major.x = element_blank()
  )

save_plot(p_pred, "fig9_cat_beta_posterior_predictions", SCRIPT_DIR, width = 10, height = 6)

cat("\nSaved:\n")
cat("  data/cat_beta_posterior_predictions_goal.csv\n")
cat("  data/cat_beta_posterior_predictions_adoption.csv\n")
cat("  data/cat_beta_posterior_contrasts.csv\n")
cat("  plots/fig9_cat_beta_posterior_predictions\n")
