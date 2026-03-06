# 01_norming_analysis.R
#
# Analyse the norming-study ratings exported from magpie.
#
# Expected input (place in data/):
#   - real_data.csv   # magpie export with at least: item_id, topic, claim, pc_prop_rating
#
# Run from within analysis/norming_exp/:
#   source("01_norming_analysis.R")
#
# Outputs:
#   - data/norming_summary.csv
#   - data/norming_means.csv
#   - plots/norming_topic_means.png / .pdf
#   - plots/norming_topic_distributions.png / .pdf

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(forcats)
library(aida)

# ── Config ───────────────────────────────────────────────────────────────────
DAT_PATH  <- "data/real_data.csv"
PLOTS_DIR <- "plots"
OUT_SUMMARY <- "data/norming_summary.csv"
OUT_MEANS   <- "data/norming_means.csv"

dir.create("data", showWarnings = FALSE)
dir.create(PLOTS_DIR, showWarnings = FALSE)

# ── Theme ───────────────────────────────────────────────────
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

# ── Helpers ──────────────────────────────────────────────────────────────────
save_plot_both <- function(plot_obj, stem, width = 9, height = 6) {
  ggsave(file.path(PLOTS_DIR, paste0(stem, ".png")), plot_obj,
         width = width, height = height, dpi = 300)
  ggsave(file.path(PLOTS_DIR, paste0(stem, ".pdf")), plot_obj,
         width = width, height = height)
}

se <- function(x) {
  stats::sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))
}

# ── Read + validate ─────────────────────────────────────────────────────────
if (!file.exists(DAT_PATH)) {
  stop(
    "Could not find ", DAT_PATH, ". Place the magpie export there and rerun.",
    call. = FALSE
  )
}

raw_dat <- readr::read_csv(DAT_PATH, show_col_types = FALSE)

required_cols <- c("item_id", "topic", "claim", "pc_prop_rating")
missing_cols <- setdiff(required_cols, names(raw_dat))
if (length(missing_cols) > 0) {
  stop(
    "Missing required column(s): ", paste(missing_cols, collapse = ", "),
    call. = FALSE
  )
}

dedup_cols <- intersect(
  c("participant_id", "prolific_id", "submission_id", "trial_id", "item_id"),
  names(raw_dat)
)

norm_dat <- raw_dat %>%
  mutate(
    item_id = suppressWarnings(as.integer(item_id)),
    pc_prop_rating = suppressWarnings(as.numeric(pc_prop_rating))
  ) %>%
  filter(!is.na(item_id), !is.na(topic), !is.na(pc_prop_rating)) %>%
  filter(pc_prop_rating >= 0, pc_prop_rating <= 100)

if (length(dedup_cols) > 1) {
  norm_dat <- norm_dat %>%
    distinct(across(all_of(dedup_cols)), .keep_all = TRUE)
}

if (nrow(norm_dat) == 0) {
  stop("No usable norming rows found after cleaning.", call. = FALSE)
}

# ── Summaries ────────────────────────────────────────────────────────────────
topic_summary <- norm_dat %>%
  group_by(item_id, topic) %>%
  summarise(
    claim = dplyr::first(claim),
    n = dplyr::n(),
    mean_pc_prop_rating = mean(pc_prop_rating, na.rm = TRUE),
    sd_pc_prop_rating = sd(pc_prop_rating, na.rm = TRUE),
    se_pc_prop_rating = se(pc_prop_rating),
    ci_low = mean_pc_prop_rating - 1.96 * se_pc_prop_rating,
    ci_high = mean_pc_prop_rating + 1.96 * se_pc_prop_rating,
    .groups = "drop"
  ) %>%
  mutate(
    topic_label = dplyr::recode(
      as.character(topic),
      klimawandel = "Climate change (Klimawandel)",
      ernaehrung = "Nutrition (Ernährung)",
      stadtverkehr = "Urban transport (Stadtverkehr)",
      digitalisierung = "Digital skills (Digitalisierung)",
      schlaf = "Sleep (Schlaf)",
      plastik = "Plastic waste (Plastik)",
      sport = "Exercise (Sport)",
      lokalkauf = "Local shopping (Lokalkauf)"
    ),
    claim_wrapped = gsub("(.{1,45})(\\s|$)", "\\1\n", claim)
  ) %>%
  arrange(mean_pc_prop_rating) %>%
  mutate(
    topic = factor(topic, levels = topic),
    topic_label = factor(topic_label, levels = topic_label)
  )

label_map <- setNames(as.character(topic_summary$topic_label), as.character(topic_summary$topic))

norm_dat <- norm_dat %>%
  mutate(
    topic = factor(topic, levels = levels(topic_summary$topic)),
    topic_label = factor(label_map[as.character(topic)], levels = levels(topic_summary$topic_label))
  )

means_only <- topic_summary %>%
  transmute(topic = as.character(topic), mean_pc_prop_rating = round(mean_pc_prop_rating, 2))

readr::write_csv(topic_summary, OUT_SUMMARY)
readr::write_csv(means_only, OUT_MEANS)

# ── Plot: topic distributions + means ───────────────────────────────────────
p_combined <- ggplot(
  norm_dat,
  aes(x = pc_prop_rating, y = topic_label, fill = topic, colour = topic)
) +
  geom_violin(alpha = 0.20, linewidth = 0.4, width = 0.9, show.legend = FALSE) +
  geom_jitter(height = 0.10, width = 0, alpha = 0.22, size = 1.8, show.legend = FALSE) +
  geom_errorbar(
    data = topic_summary,
    aes(
      x = mean_pc_prop_rating,
      xmin = pmax(ci_low, 0),
      xmax = pmin(ci_high, 100),
      y = topic_label
    ),
    inherit.aes = FALSE,
    width = 0.18,
    linewidth = 0.7,
    show.legend = FALSE
  ) +
  geom_point(
    data = topic_summary,
    aes(x = mean_pc_prop_rating, y = topic_label, fill = topic),
    inherit.aes = FALSE,
    shape = 21,
    size = 3.5,
    stroke = 0.5,
    colour = "black",
    show.legend = FALSE
  ) +
  scale_x_continuous(limits = c(0, 100)) +
  labs(
    x = "Propositional controversy",
    y = NULL
  ) +
  theme_model()

save_plot_both(p_combined, "norming_topic_distributions", width = 10, height = 6.5)
save_plot_both(p_combined, "norming_topic_means", width = 10, height = 6.5)

# ── Console output ───────────────────────────────────────────────────────────
cat("\nNorming analysis complete.\n")
cat("Rows analysed: ", nrow(norm_dat), "\n", sep = "")
cat("Topics: ", n_distinct(norm_dat$topic), "\n\n", sep = "")
print(topic_summary %>% select(item_id, topic, n, mean_pc_prop_rating, sd_pc_prop_rating))
