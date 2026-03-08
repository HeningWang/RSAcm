# 06_bayesian_contrasts.R
#
# Posterior expected predictions and preregistered contrasts for the
# comprehension experiment.
#
# Outputs:
#   data/comprehension_posterior_predictions_goal.csv
#   data/comprehension_posterior_predictions_adoption.csv
#   data/comprehension_posterior_contrasts.csv
#   plots/fig5_comprehension_posterior_predictions.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(brms)
library(aida)

UTILS_PATH <- if (file.exists("00_utils.R")) "00_utils.R" else file.path("analysis", "comprehension_exp", "00_utils.R")
source(UTILS_PATH)

SCRIPT_DIR <- get_script_dir()
DATA_DIR <- file.path(SCRIPT_DIR, "data")
dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)

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

crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = FALSE)

fit_goal <- readRDS(file.path(DATA_DIR, "fit_brms_goal_zoib_full.rds"))
fit_adopt <- readRDS(file.path(DATA_DIR, "fit_brms_adoption_zoib_full.rds"))

newdata <- make_prediction_grid(crit)

summarise_epred <- function(fit, outcome_name) {
  ep <- posterior_epred(fit, newdata = newdata, re_formula = NA)
  pred <- tibble(
    outcome = outcome_name,
    marker = newdata$marker,
    pc_prag = newdata$pc_prag,
    mean = colMeans(ep),
    lower = apply(ep, 2, quantile, probs = 0.025),
    upper = apply(ep, 2, quantile, probs = 0.975)
  )
  list(draws = ep, summary = pred)
}

goal_pred <- summarise_epred(fit_goal, "Inferred goal strength")
adopt_pred <- summarise_epred(fit_adopt, "Adoption likelihood")

predictions <- bind_rows(goal_pred$summary, adopt_pred$summary) |>
  mutate(
    mean = mean * 100,
    lower = lower * 100,
    upper = upper * 100,
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high"))
  )

write.csv(goal_pred$summary,
          file.path(DATA_DIR, "comprehension_posterior_predictions_goal.csv"),
          row.names = FALSE)
write.csv(adopt_pred$summary,
          file.path(DATA_DIR, "comprehension_posterior_predictions_adoption.csv"),
          row.names = FALSE)

contrast_summary <- function(draws, outcome_name) {
  colnames(draws) <- paste(newdata$marker, newdata$pc_prag, sep = "__")

  weak_low <- draws[, "soviel ich weiß__low"]
  strong_low <- draws[, "bekanntlich__low"]
  weak_high <- draws[, "soviel ich weiß__high"]
  strong_high <- draws[, "bekanntlich__high"]
  mid_low <- draws[, "ja__low"]
  mid_high <- draws[, "ja__high"]

  contrasts <- list(
    H_strong_vs_weak_low = strong_low - weak_low,
    H_strong_vs_weak_high = strong_high - weak_high,
    mid_vs_weak_low = mid_low - weak_low,
    mid_vs_weak_high = mid_high - weak_high,
    strong_vs_mid_low = strong_low - mid_low,
    strong_vs_mid_high = strong_high - mid_high,
    credibility_discount = (strong_high - weak_high) - (strong_low - weak_low)
  )

  bind_rows(lapply(names(contrasts), function(name) {
    x <- contrasts[[name]]
    tibble(
      outcome = outcome_name,
      contrast = name,
      mean = mean(x) * 100,
      lower = quantile(x, 0.025) * 100,
      upper = quantile(x, 0.975) * 100,
      p_gt_0 = mean(x > 0),
      p_lt_0 = mean(x < 0)
    )
  }))
}

contrasts_out <- bind_rows(
  contrast_summary(goal_pred$draws, "Inferred goal strength"),
  contrast_summary(adopt_pred$draws, "Adoption likelihood")
)
write.csv(contrasts_out,
          file.path(DATA_DIR, "comprehension_posterior_contrasts.csv"),
          row.names = FALSE)

p_pred <- ggplot(predictions,
                 aes(x = marker, y = mean, colour = marker, group = pc_prag)) +
  geom_point(size = 2.8) +
  geom_line(aes(group = pc_prag), linewidth = 0.75, colour = "#444444") +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.08, linewidth = 0.7) +
  facet_grid(outcome ~ pc_prag) +
  scale_colour_manual(values = marker_colors) +
  labs(x = NULL, y = "Posterior expected rating", colour = "Marker") +
  theme_comp() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(angle = 18, hjust = 1),
    panel.grid.major.x = element_blank()
  )

save_plot(p_pred, "fig5_comprehension_posterior_predictions", SCRIPT_DIR, width = 10, height = 6)

cat("Saved:\n")
cat("  data/comprehension_posterior_predictions_goal.csv\n")
cat("  data/comprehension_posterior_predictions_adoption.csv\n")
cat("  data/comprehension_posterior_contrasts.csv\n")
cat("  plots/fig5_comprehension_posterior_predictions\n")
