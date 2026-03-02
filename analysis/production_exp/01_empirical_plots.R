# 01_empirical_plots.R
#
# Visualises the distribution of consensus-marker choices across the
# 2 (pc_prag) × 2 (g / speaker goal) design cells.
# pc_prop_rating is treated as a continuous covariate from the norming study
# (not dichotomised into an experiment factor).
#
# Source the dummy data first:
#   source("generate_dummy_data.R")   # writes data/dummy_data.csv
#
# Or point DAT_PATH at real magpie output (same column names).
#
# Output: plots/ directory (PDF + PNG for each figure)

library(dplyr)
library(tidyr)
library(ggplot2)
library(forcats)
library(aida)

# ── Config ─────────────────────────────────────────────────────────────────────
DAT_PATH  <- "data/dummy_data.csv"
PLOTS_DIR <- "plots"
dir.create(PLOTS_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c(
  "sofern ich weiß",
  "wie du ja weißt",
  "wie wir wissen",
  "ja",
  "bekanntlich"
)

##################################################
## CSP-colors
##################################################
CSP_colors <- c(
  "#7581B3", "#99C2C2", "#C65353", "#E2BA78", "#5C7457", "#575463",
  "#B0B7D4", "#66A3A3", "#DB9494", "#D49735", "#9BB096", "#D4D3D9",
  "#414C76", "#993333"
)

scale_colour_discrete <- function(...) {
  scale_colour_manual(..., values = CSP_colors)
}
scale_fill_discrete <- function(...) {
  scale_fill_manual(..., values = CSP_colors)
}

marker_colors <- setNames(CSP_colors[seq_along(MARKERS_ORDERED)], MARKERS_ORDERED)

# ── Theme ───────────────────────────────────────────────────
theme_set(theme_aida())
theme_model <- function() {
  theme_aida() +
    theme(
      axis.text.y  = element_text(size = 14),
      axis.text.x  = element_text(size = 14),
      axis.title.y = element_text(size = 16),
      axis.title.x = element_text(size = 16),
      legend.text  = element_text(size = 14),
      legend.title = element_text(size = 14)
    )
}

save_plot <- function(p, name, w = 8, h = 5) {
  ggsave(file.path(PLOTS_DIR, paste0(name, ".pdf")), p, width = w, height = h)
  ggsave(file.path(PLOTS_DIR, paste0(name, ".png")), p, width = w, height = h,
         dpi = 180)
  invisible(p)
}

# ── Load & prep ────────────────────────────────────────────────────────────────
dat <- read.csv(DAT_PATH, stringsAsFactors = FALSE)

crit <- dat |>
  filter(!is_filler) |>
  mutate(
    selected_marker = factor(selected_marker, levels = MARKERS_ORDERED),
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("pc_prag: low", "pc_prag: high")),
    g       = factor(g,       levels = c("low", "high"),
                     labels = c("g: low", "g: high"))
  )

# ── Figure 1: Stacked bar — marker proportions per condition ────────────────────
# 4 conditions: pc_prag (low/high) × g / speaker goal (low/high)
cond_props <- crit |>
  count(pc_prag, g, selected_marker, .drop = FALSE) |>
  group_by(pc_prag, g) |>
  mutate(prop = n / sum(n)) |>
  ungroup() |>
  mutate(condition = paste0(
    sub("pc_prag: ", "pc_prag:", pc_prag), "\n",
    sub("g: ",       "g:",       g)
  ))

p1 <- ggplot(cond_props,
             aes(x = condition, y = prop, fill = selected_marker)) +
  geom_col(width = 0.6, colour = "white", linewidth = 0.25) +
  scale_fill_manual(values = marker_colors,
                    name   = "Consensus marker",
                    guide  = guide_legend(reverse = TRUE)) +
  scale_y_continuous(labels = scales::percent_format(), expand = c(0, 0),
                     limits = c(0, 1.02)) +
  labs(
    title    = "Marker choice proportions per condition",
    subtitle = "Conditions: pc_prag (low/high) × speaker goal g (low/high)",
    x        = "Condition",
    y        = "Proportion"
  ) +
  theme_model() +
  theme(
    axis.text.x        = element_text(angle = 0, hjust = 0.5),
    legend.position    = "right",
    panel.grid.major.x = element_blank()
  )
save_plot(p1, "fig1_stacked_bar", w = 7, h = 5.5)

# ── Figure 2: Tile / heatmap — mean marker index by pc_prag × g ──────────────
# Mean marker index (1 = sofern, 5 = bekanntlich) as fill
mean_idx <- crit |>
  mutate(marker_index = as.integer(selected_marker)) |>
  group_by(pc_prag, g) |>
  summarise(mean_marker = mean(marker_index), .groups = "drop")

p2 <- ggplot(mean_idx,
             aes(x = g, y = pc_prag, fill = mean_marker)) +
  geom_tile(colour = "white", linewidth = 1.5) +
  geom_text(aes(label = round(mean_marker, 2)), size = 5.5, fontface = "bold") +
  scale_fill_distiller(palette = "RdYlBu", direction = 1,
                       limits = c(1, 5), name = "Mean marker\n(1=sofern, 5=bekanntlich)") +
  scale_x_discrete(drop = FALSE) +
  scale_y_discrete(drop = FALSE) +
  labs(
    title    = "Mean consensus-marker strength by condition",
    subtitle = "pc_prag: pragmatic controversy; g: speaker goal strength",
    x        = "Speaker goal (g)",
    y        = "Pragmatic controversy (pc_prag)"
  ) +
  theme_model() +
  theme(legend.position = "right")
save_plot(p2, "fig2_heatmap", w = 5.5, h = 3.5)

# ── Figure 3: Faceted bar — distribution per factor, marginalised ───────────────
# Marginalise over the other factor to show main effects (2 factors: pc_prag, g)

marg_pc_prag <- crit |>
  count(pc_prag, selected_marker, .drop = FALSE) |>
  group_by(pc_prag) |>
  mutate(prop = n / sum(n), factor = "pc_prag (pragmatic controversy)",
         level = as.character(pc_prag)) |>
  ungroup()

marg_g <- crit |>
  count(g, selected_marker, .drop = FALSE) |>
  group_by(g) |>
  mutate(prop = n / sum(n), factor = "g (speaker goal)",
         level = as.character(g)) |>
  ungroup()

marginals <- bind_rows(
  select(marg_pc_prag, factor, level, selected_marker, prop),
  select(marg_g,       factor, level, selected_marker, prop)
) |>
  mutate(
    factor = factor(factor, levels = c("pc_prag (pragmatic controversy)",
                                        "g (speaker goal)")),
    level  = factor(level,
                    levels = c("pc_prag: low", "pc_prag: high",
                               "g: low", "g: high"))
  )

p3 <- ggplot(marginals, aes(x = level, y = prop, fill = selected_marker)) +
  geom_col(width = 0.65, colour = "white", linewidth = 0.25) +
  scale_fill_manual(values = marker_colors, name = "Consensus marker",
                    guide  = guide_legend(reverse = TRUE)) +
  scale_y_continuous(labels = scales::percent_format(), expand = c(0, 0),
                     limits = c(0, 1.02)) +
  facet_wrap(~factor, scales = "free_x", nrow = 1) +
  labs(
    title    = "Marginal marker distributions",
    subtitle = "Each factor marginalised over the other",
    x = NULL, y = "Proportion"
  ) +
  theme_model() +
  theme(
    axis.text.x        = element_text(angle = 20, hjust = 1),
    panel.grid.major.x = element_blank(),
    legend.position    = "right"
  )
save_plot(p3, "fig3_marginals", w = 8, h = 5)

# ── Figure 4: Individual marker curves across utility (pc_prag, g) ─────────────
# Collapse the 2×2 conditions to a 1-D utility score and plot marker proportions.
# Utility proxy = −pc_prag + 2·g  (ranges -1 to 2 over the 4 conditions)
crit_util <- dat |>
  filter(!is_filler) |>
  mutate(
    pc_prag_n = ifelse(pc_prag == "high", 1, 0),
    g_n       = ifelse(g       == "high", 1, 0),
    util_bin  = -pc_prag_n + 2 * g_n,   # -1 = high/low, 0 = low/low, 1 = high/high, 2 = low/high
    selected_marker = factor(selected_marker, levels = MARKERS_ORDERED)
  ) |>
  count(util_bin, selected_marker, .drop = FALSE) |>
  group_by(util_bin) |>
  mutate(prop = n / sum(n)) |>
  ungroup()

# Build readable x-axis labels: show pc_prag/g levels for each bin value
util_labels <- c(
  "-1" = "-1\n(pc_prag:high\ng:low)",
  "0"  = "0\n(pc_prag:low\ng:low)",
  "1"  = "1\n(pc_prag:high\ng:high)",
  "2"  = "2\n(pc_prag:low\ng:high)"
)

p4 <- ggplot(crit_util,
             aes(x = util_bin, y = prop, colour = selected_marker,
                 group = selected_marker)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  scale_colour_manual(values = marker_colors, name = "Consensus marker") +
  scale_x_continuous(breaks = c(-1, 0, 1, 2), labels = util_labels) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title    = "Marker proportions along utility axis",
    subtitle = "Utility proxy = −pc_prag + 2·g  (pc_prag: pragmatic controversy; g: speaker goal)",
    x        = "Utility proxy (−pc_prag + 2·g)",
    y        = "Proportion"
  ) +
  theme_model() +
  theme(legend.position = "right")
save_plot(p4, "fig4_marker_curves", w = 9, h = 5)

cat("Figures saved to", PLOTS_DIR, "\n")
cat("  fig1_stacked_bar   — proportions per condition (4 conditions: pc_prag × g)\n")
cat("  fig2_heatmap       — mean marker index heatmap (pc_prag × g)\n")
cat("  fig3_marginals     — main-effect marginals (pc_prag, g)\n")
cat("  fig4_marker_curves — proportions along utility axis (−pc_prag + 2·g)\n")
