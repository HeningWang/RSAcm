# 03_balanced_assignment_summary_plot.R
#
# Create compact, paper-ready summaries of the balanced comprehension
# assignment: a small summary table and a stacked proportion plot.
#
# Outputs:
#   data/comprehension_balanced_prediction_summary_by_condition.csv
#   data/comprehension_balanced_prediction_summary_by_marker.csv
#   data/comprehension_balanced_prediction_table.md
#   plots/fig_balanced_assignment_predictions.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(aida)

SCRIPT_DIR <- normalizePath(getwd(), mustWork = FALSE)
if (basename(SCRIPT_DIR) != "comprehension_exp") {
  SCRIPT_DIR <- normalizePath(file.path(getwd(), "analysis/comprehension_exp"), mustWork = TRUE)
}

DATA_DIR <- file.path(SCRIPT_DIR, "data")
PLOTS_DIR <- file.path(SCRIPT_DIR, "plots")
dir.create(PLOTS_DIR, showWarnings = FALSE)

MARKERS <- c("soviel ich weiß", "ja", "bekanntlich")
CSP_colors <- c(
  "#7581B3", "#99C2C2", "#C65353", "#E2BA78", "#5C7457", "#575463",
  "#B0B7D4", "#66A3A3", "#DB9494", "#D49735", "#9BB096", "#D4D3D9",
  "#414C76", "#993333"
)
marker_colors <- setNames(CSP_colors[seq_along(MARKERS)], MARKERS)

theme_set(theme_aida())

d <- read.csv(
  file.path(DATA_DIR, "comprehension_balanced_assignment_long.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
) |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high")),
    g_implied = factor(g_implied, levels = c("low", "high")),
    selected_marker = factor(selected_marker, levels = MARKERS)
  )

condition_summary <- d |>
  count(pc_prag, g_implied, selected_marker, .drop = FALSE) |>
  group_by(pc_prag, g_implied) |>
  mutate(
    total_cells = sum(n),
    prop = n / total_cells
  ) |>
  ungroup() |>
  left_join(
    d |>
      group_by(pc_prag, g_implied, selected_marker) |>
      summarise(mean_selected_prob = mean(selected_prob), .groups = "drop"),
    by = c("pc_prag", "g_implied", "selected_marker")
  ) |>
  mutate(
    mean_selected_prob = round(mean_selected_prob, 3),
    prop = round(prop, 3)
  )

marker_summary <- d |>
  group_by(selected_marker) |>
  summarise(
    cells = n(),
    mean_selected_prob = round(mean(selected_prob), 3),
    mean_modal_prob = round(mean(modal_prob), 3),
    mean_log_prob_loss = round(mean(log_prob_loss), 3),
    .groups = "drop"
  )

write.csv(
  condition_summary,
  file.path(DATA_DIR, "comprehension_balanced_prediction_summary_by_condition.csv"),
  row.names = FALSE
)
write.csv(
  marker_summary,
  file.path(DATA_DIR, "comprehension_balanced_prediction_summary_by_marker.csv"),
  row.names = FALSE
)

fmt_condition <- function(pc_prag, g) {
  paste0("Prag. Controversy: ", pc_prag, "; Goal: ", g)
}

condition_table <- condition_summary |>
  transmute(
    Condition = fmt_condition(as.character(pc_prag), as.character(g_implied)),
    Marker = as.character(selected_marker),
    Cells = n,
    Proportion = sprintf("%.2f", prop),
    `Mean selected P` = sprintf("%.3f", mean_selected_prob)
  )

marker_table <- marker_summary |>
  transmute(
    Marker = as.character(selected_marker),
    Cells = cells,
    `Mean selected P` = sprintf("%.3f", mean_selected_prob),
    `Mean modal P` = sprintf("%.3f", mean_modal_prob),
    `Mean log-loss vs modal` = sprintf("%.3f", mean_log_prob_loss)
  )

make_md_table <- function(df) {
  header <- paste(names(df), collapse = " | ")
  sep <- paste(rep("---", ncol(df)), collapse = " | ")
  rows <- apply(df, 1, function(x) paste(x, collapse = " | "))
  paste(c(paste0("| ", header, " |"),
          paste0("| ", sep, " |"),
          paste0("| ", rows, " |")), collapse = "\n")
}

md_lines <- c(
  "# Balanced comprehension assignment summary",
  "",
  "## By condition",
  "",
  make_md_table(condition_table),
  "",
  "## By assigned marker",
  "",
  make_md_table(marker_table),
  ""
)
writeLines(md_lines, file.path(DATA_DIR, "comprehension_balanced_prediction_table.md"))

plot_df <- condition_summary |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high")),
    g_implied = factor(g_implied, levels = c("low", "high"),
                       labels = c("Goal: low", "Goal: high"))
  )

p <- ggplot(plot_df, aes(x = g_implied, y = prop, fill = selected_marker)) +
  geom_col(width = 0.72, colour = "white", linewidth = 0.4) +
  geom_text(
    aes(label = ifelse(n > 0, n, "")),
    position = position_stack(vjust = 0.5),
    colour = "white",
    size = 4.2,
    fontface = "bold"
  ) +
  facet_wrap(~pc_prag, nrow = 1) +
  scale_fill_manual(values = marker_colors) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    x = NULL,
    y = "Assigned-cell proportion",
    fill = NULL
  ) +
  theme_aida() +
  theme(
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    axis.text.x = element_text(size = 12.5),
    strip.text = element_text(size = 12.5, face = "bold")
  )

ggsave(file.path(PLOTS_DIR, "fig_balanced_assignment_predictions.pdf"), p,
       width = 7.8, height = 4.6)
ggsave(file.path(PLOTS_DIR, "fig_balanced_assignment_predictions.png"), p,
       width = 7.8, height = 4.6, dpi = 180)

cat("Saved:\n")
cat("  data/comprehension_balanced_prediction_summary_by_condition.csv\n")
cat("  data/comprehension_balanced_prediction_summary_by_marker.csv\n")
cat("  data/comprehension_balanced_prediction_table.md\n")
cat("  plots/fig_balanced_assignment_predictions.png\n")
