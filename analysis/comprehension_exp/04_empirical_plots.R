# 04_empirical_plots.R
#
# Descriptive summaries for the comprehension experiment.
#
# Outputs:
#   data/comprehension_empirical_condition_summary.csv
#   data/comprehension_empirical_marker_summary.csv
#   plots/fig1_goal_by_condition_marker.pdf/png
#   plots/fig2_adoption_by_condition_marker.pdf/png
#   plots/fig3_comprehension_pcprop_scatter.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
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

crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = TRUE)

condition_summary <- crit |>
  group_by(condition, pc_prag, g_implied, marker) |>
  summarise(
    n = n(),
    mean_goal = mean(inferred_goal_strength),
    mean_adoption = mean(adoption_likelihood),
    .groups = "drop"
  )

marker_summary <- crit |>
  group_by(marker, pc_prag) |>
  summarise(
    n = n(),
    mean_goal = mean(inferred_goal_strength),
    mean_adoption = mean(adoption_likelihood),
    .groups = "drop"
  )

set.seed(42)
subj_ids <- unique(crit$submission_id)
B <- 2000L

template_condition <- tidyr::expand_grid(
  condition = levels(crit$condition),
  marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED, ordered = TRUE)
) |>
  left_join(
    distinct(crit, condition, pc_prag, g_implied),
    by = "condition"
  )

template_marker <- tidyr::expand_grid(
  marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED, ordered = TRUE),
  pc_prag = factor(c("low", "high"), levels = c("low", "high"))
)

boot_condition_df <- bind_rows(lapply(seq_len(B), function(b) {
  sampled <- sample(subj_ids, length(subj_ids), replace = TRUE)
  boot_dat <- bind_rows(lapply(sampled, function(id) crit |> filter(submission_id == id)))
  boot_dat |>
    group_by(condition, pc_prag, g_implied, marker) |>
    summarise(
      mean_goal = mean(inferred_goal_strength),
      mean_adoption = mean(adoption_likelihood),
      .groups = "drop"
    ) |>
    mutate(.draw = b)
}))

condition_boot_summary <- boot_condition_df |>
  group_by(condition, pc_prag, g_implied, marker) |>
  summarise(
    goal_low = quantile(mean_goal, probs = 0.025, na.rm = TRUE),
    goal_high = quantile(mean_goal, probs = 0.975, na.rm = TRUE),
    adoption_low = quantile(mean_adoption, probs = 0.025, na.rm = TRUE),
    adoption_high = quantile(mean_adoption, probs = 0.975, na.rm = TRUE),
    .groups = "drop"
  )

boot_marker_df <- bind_rows(lapply(seq_len(B), function(b) {
  sampled <- sample(subj_ids, length(subj_ids), replace = TRUE)
  boot_dat <- bind_rows(lapply(sampled, function(id) crit |> filter(submission_id == id)))
  boot_dat |>
    group_by(marker, pc_prag) |>
    summarise(
      mean_goal = mean(inferred_goal_strength),
      mean_adoption = mean(adoption_likelihood),
      .groups = "drop"
    ) |>
    mutate(.draw = b)
}))

marker_boot_summary <- boot_marker_df |>
  group_by(marker, pc_prag) |>
  summarise(
    goal_low = quantile(mean_goal, probs = 0.025, na.rm = TRUE),
    goal_high = quantile(mean_goal, probs = 0.975, na.rm = TRUE),
    adoption_low = quantile(mean_adoption, probs = 0.025, na.rm = TRUE),
    adoption_high = quantile(mean_adoption, probs = 0.975, na.rm = TRUE),
    .groups = "drop"
  )

condition_summary_out <- condition_summary |>
  left_join(condition_boot_summary, by = c("condition", "pc_prag", "g_implied", "marker"))
marker_summary_out <- marker_summary |>
  left_join(marker_boot_summary, by = c("marker", "pc_prag"))

write.csv(condition_summary_out,
          file.path(DATA_DIR, "comprehension_empirical_condition_summary.csv"),
          row.names = FALSE)
write.csv(marker_summary_out,
          file.path(DATA_DIR, "comprehension_empirical_marker_summary.csv"),
          row.names = FALSE)

marker_summary_plot <- template_marker |>
  left_join(marker_summary_out, by = c("marker", "pc_prag")) |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high")),
    missing_cell = is.na(n)
  )

zoom_limits <- function(lower, upper, pad = 4, min_span = 14) {
  lo <- min(lower, na.rm = TRUE)
  hi <- max(upper, na.rm = TRUE)

  if (!is.finite(lo) || !is.finite(hi)) {
    return(c(0, 100))
  }

  lo <- lo - pad
  hi <- hi + pad

  if ((hi - lo) < min_span) {
    mid <- (lo + hi) / 2
    lo <- mid - min_span / 2
    hi <- mid + min_span / 2
  }

  lo <- max(0, floor(lo / 5) * 5)
  hi <- min(100, ceiling(hi / 5) * 5)

  c(lo, hi)
}

goal_limits <- zoom_limits(marker_summary_plot$goal_low, marker_summary_plot$goal_high)
adoption_limits <- zoom_limits(marker_summary_plot$adoption_low, marker_summary_plot$adoption_high)

goal_missing_y <- goal_limits[1] + 0.08 * diff(goal_limits)
adoption_missing_y <- adoption_limits[1] + 0.08 * diff(adoption_limits)

pc_prag_colors <- c(
  "Prag. Controversy: low" = "#7581B3",
  "Prag. Controversy: high" = "#C65353"
)

plot_goal <- ggplot(marker_summary_plot,
                    aes(x = marker, y = mean_goal, colour = pc_prag, group = pc_prag)) +
  geom_text(data = marker_summary_plot |> filter(missing_cell),
            aes(x = marker, y = goal_missing_y, label = sub("Prag. Controversy: ", "", pc_prag)),
            inherit.aes = FALSE,
            size = 3.1,
            colour = "#999999",
            fontface = "italic") +
  geom_errorbar(aes(ymin = goal_low, ymax = goal_high),
                width = 0.08,
                linewidth = 0.8,
                position = position_dodge(width = 0.35),
                na.rm = TRUE) +
  geom_point(size = 3.2,
             alpha = 0.95,
             position = position_dodge(width = 0.35),
             na.rm = TRUE) +
  scale_colour_manual(values = pc_prag_colors) +
  scale_y_continuous(limits = goal_limits,
                     breaks = scales::breaks_pretty(n = 5),
                     expand = expansion(mult = c(0.02, 0.04))) +
  labs(
    x = NULL,
    y = "Mean inferred goal strength",
    colour = NULL
  ) +
  theme_comp() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(angle = 18, hjust = 1),
    panel.grid.major.x = element_blank()
  )

plot_adoption <- ggplot(marker_summary_plot,
                        aes(x = marker, y = mean_adoption, colour = pc_prag, group = pc_prag)) +
  geom_text(data = marker_summary_plot |> filter(missing_cell),
            aes(x = marker, y = adoption_missing_y, label = sub("Prag. Controversy: ", "", pc_prag)),
            inherit.aes = FALSE,
            size = 3.1,
            colour = "#999999",
            fontface = "italic") +
  geom_errorbar(aes(ymin = adoption_low, ymax = adoption_high),
                width = 0.08,
                linewidth = 0.8,
                position = position_dodge(width = 0.35),
                na.rm = TRUE) +
  geom_point(size = 3.2,
             alpha = 0.95,
             position = position_dodge(width = 0.35),
             na.rm = TRUE) +
  scale_colour_manual(values = pc_prag_colors) +
  scale_y_continuous(limits = adoption_limits,
                     breaks = scales::breaks_pretty(n = 5),
                     expand = expansion(mult = c(0.02, 0.04))) +
  labs(
    x = NULL,
    y = "Mean adoption likelihood",
    colour = NULL
  ) +
  theme_comp() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(angle = 18, hjust = 1),
    panel.grid.major.x = element_blank()
  )

scatter_long <- crit |>
  transmute(
    pc_prop_c,
    pc_prag,
    g_implied,
    condition,
    marker,
    `Inferred goal strength` = inferred_goal_strength,
    `Adoption likelihood` = adoption_likelihood
  ) |>
  pivot_longer(c(`Inferred goal strength`, `Adoption likelihood`),
               names_to = "outcome", values_to = "rating")

plot_scatter <- ggplot(scatter_long,
                       aes(x = pc_prop_c, y = rating, colour = marker)) +
  geom_point(alpha = 0.55, size = 1.7) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8) +
  facet_grid(outcome ~ condition) +
  scale_colour_manual(values = marker_colors) +
  labs(x = "Propositional controversy (centered)", y = "Rating", colour = "Marker") +
  theme_comp() +
  theme(legend.position = "top")

save_plot(plot_goal, "fig1_goal_by_condition_marker", SCRIPT_DIR, width = 10, height = 3.4)
save_plot(plot_adoption, "fig2_adoption_by_condition_marker", SCRIPT_DIR, width = 10, height = 3.4)
save_plot(plot_scatter, "fig3_comprehension_pcprop_scatter", SCRIPT_DIR, width = 12, height = 6.4)

cat("Saved:\n")
cat("  data/comprehension_empirical_condition_summary.csv\n")
cat("  data/comprehension_empirical_marker_summary.csv\n")
cat("  plots/fig1_goal_by_condition_marker\n")
cat("  plots/fig2_adoption_by_condition_marker\n")
cat("  plots/fig3_comprehension_pcprop_scatter\n")
