# 03_hierarchical_regression.R
#
# Hierarchical regression on condition effects using the cumulative-probit
# family (ordered outcome, markers treated as an ordinal scale).
#
# Model A — Additive:
#   marker ~ pc_prop + pc_prag + g + (1 | submission_id)
#
# Model B — Full interactions:
#   marker ~ pc_prop * pc_prag * g + (1 | submission_id)
#
# Both fitted via brms (which compiles a Stan program internally).
# Model comparison via approximate leave-one-out cross-validation (LOO).
#
# Outputs:
#   data/fit_brms_additive.rds
#   data/fit_brms_full.rds
#   plots/fig8_coef_plot.pdf/png      — fixef coefficient plot
#   plots/fig9_cond_effects.pdf/png   — conditional effects on marker scale
#   plots/fig10_loo_compare.pdf/png   — LOO comparison

library(dplyr)
library(tidyr)
library(ggplot2)
library(brms)
library(posterior)
library(ggdist)       # for stat_halfeye()
library(aida)

n_cores <- suppressWarnings(parallel::detectCores())
if (!is.finite(n_cores) || is.na(n_cores) || n_cores < 1) n_cores <- 1L
n_cores <- as.integer(n_cores)

options(mc.cores = n_cores, brms.backend = "cmdstanr")

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

# ── Load data ──────────────────────────────────────────────────────────────────
dat <- read.csv("data/dummy_data.csv", stringsAsFactors = FALSE)

# Load norming means and compute centred predictor (mean = 0, SD ≈ 1)
norming <- read.csv("data/norming_means.csv", stringsAsFactors = FALSE) |>
  mutate(pc_prop_c = as.numeric(scale(mean_pc_prop_rating)))

crit <- dat |>
  filter(!is_filler) |>
  left_join(norming |> select(topic, pc_prop_c), by = "topic") |>
  mutate(
    marker    = ordered(selected_marker, levels = MARKERS_ORDERED),
    pc_prag   = factor(pc_prag, levels = c("low", "high")),
    g         = factor(g,       levels = c("low", "high")),
    # pc_prop_c: centred norming rating (already computed above)
    pc_prag_c = ifelse(pc_prag == "high",  0.5, -0.5),
    g_c       = ifelse(g       == "high",  0.5, -0.5)
  )

# ── Priors (shared) ────────────────────────────────────────────────────────────
# Weakly informative; effects on the latent probit scale
shared_priors <- c(
  prior(normal(0, 1.5), class = b),
  prior(normal(0, 1.5), class = Intercept),
  prior(exponential(1), class = sd)
)

# ── Model A: Additive ──────────────────────────────────────────────────────────
path_a <- "data/fit_brms_additive.rds"

if (file.exists(path_a)) {
  message("Loading cached Model A from ", path_a)
  fit_a <- readRDS(path_a)
} else {
  message("Fitting Model A (additive) …")
  fit_a <- brm(
    formula = marker ~ pc_prop_c + pc_prag_c + g_c + (1 | submission_id),
    family  = cumulative("probit"),
    data    = crit,
    prior   = shared_priors,
    chains  = 4, iter = 3000, warmup = 1000,
    seed    = 42, refresh = 500,
    file    = path_a   # brms also caches via this argument
  )
}

# ── Model B: Full interactions ─────────────────────────────────────────────────
path_b <- "data/fit_brms_full.rds"

if (file.exists(path_b)) {
  message("Loading cached Model B from ", path_b)
  fit_b <- readRDS(path_b)
} else {
  message("Fitting Model B (full interactions) …")
  fit_b <- brm(
    formula = marker ~ pc_prop_c * pc_prag_c * g_c + (1 | submission_id),
    family  = cumulative("probit"),
    data    = crit,
    prior   = shared_priors,
    chains  = 4, iter = 3000, warmup = 1000,
    seed    = 42, refresh = 500,
    file    = path_b
  )
}

# ── Print summaries ────────────────────────────────────────────────────────────
cat("\n=== Model A (additive) ===\n")
print(summary(fit_a))

cat("\n=== Model B (full interactions) ===\n")
print(summary(fit_b))

# ── LOO comparison ─────────────────────────────────────────────────────────────
loo_a <- loo(fit_a, cores = n_cores)
loo_b <- loo(fit_b, cores = n_cores)
loo_comp <- loo_compare(loo_a, loo_b)
cat("\n=== LOO comparison (positive ELPD diff favours row 1) ===\n")
print(loo_comp)

# ── Figure 8: Coefficient plot (Model A) ──────────────────────────────────────
# Extract population-level (fixef) draws excluding intercepts (Intercept[k])
fixef_draws <- as_draws_df(fit_a) |>
  select(starts_with("b_pc_prop_c"),
         starts_with("b_pc_prag_c"),
         starts_with("b_g_c")) |>
  pivot_longer(everything(),
               names_to  = "parameter",
               values_to = "value") |>
  mutate(
    parameter = recode(parameter,
      b_pc_prop_c = "β[pc_prop]",
      b_pc_prag_c = "β[pc_prag]",
      b_g_c       = "β[g]"
    ),
    parameter = factor(parameter,
                       levels = c("β[pc_prop]", "β[pc_prag]", "β[g]"))
  )

p8 <- ggplot(fixef_draws,
             aes(x = value, y = parameter, fill = parameter)) +
  stat_halfeye(.width = c(0.80, 0.95), point_interval = mean_qi,
               normalize = "panels") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  scale_fill_manual(values = CSP_colors[1:3]) +
  scale_y_discrete(labels = scales::label_parse()) +
  labs(
    title    = "Posterior estimates of condition effects",
    subtitle = "Model A (additive) — cumulative probit, ±80%/95% CrI",
    x        = "Coefficient on latent marker scale (probit units)",
    y        = NULL
  ) +
  theme_model() +
  theme(legend.position = "none")

ggsave(file.path(PLOTS_DIR, "fig8_coef_plot.pdf"), p8, width = 8, height = 4)
ggsave(file.path(PLOTS_DIR, "fig8_coef_plot.png"), p8, width = 8, height = 4,
       dpi = 180)

# ── Figure 9: Conditional effects ─────────────────────────────────────────────
# Predicted probability of each marker across pc_prop × pc_prag, faceted by g
# Use brms::conditional_effects() on the categorical response scale

ce <- conditional_effects(
  fit_a,
  effects    = "pc_prop_c",
  conditions = expand.grid(g_c = c(-0.5, 0.5), pc_prag_c = c(-0.5, 0.5)),
  categorical = TRUE
)

# Convert to tidy tibble for custom plot
ce_df <- as.data.frame(ce[[1]]) |>
  mutate(
    pc_prop  = ifelse(pc_prop_c < 0, "low", "high"),
    g        = ifelse(g_c       < 0, "low", "high"),
    pc_prag  = ifelse(pc_prag_c < 0, "low", "high"),
    marker   = factor(cats__, levels = MARKERS_ORDERED)
  )

p9 <- ggplot(ce_df, aes(x = pc_prop, y = estimate__,
                         colour = marker, group = marker)) +
  geom_line(linewidth = 1) +
  geom_ribbon(aes(ymin = lower__, ymax = upper__, fill = marker),
              alpha = 0.15, colour = NA) +
  scale_colour_manual(values = marker_colors, name = "Marker") +
  scale_fill_manual(values = marker_colors, name = "Marker") +
  facet_grid(pc_prag ~ g,
             labeller = labeller(
               pc_prag = c(low = "pc_prag: low", high = "pc_prag: high"),
               g       = c(low = "g: low",       high = "g: high")
             )) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title    = "Predicted marker probabilities (Model A)",
    subtitle = "Facets: pc_prag (rows) × g (columns)",
    x        = "pc_prop",
    y        = "P(marker)"
  ) +
  theme_model()

ggsave(file.path(PLOTS_DIR, "fig9_cond_effects.pdf"), p9, width = 10, height = 6)
ggsave(file.path(PLOTS_DIR, "fig9_cond_effects.png"), p9, width = 10, height = 6,
       dpi = 180)

# ── Figure 10: LOO comparison bar chart ───────────────────────────────────────
loo_df <- as.data.frame(loo_comp) |>
  tibble::rownames_to_column("model") |>
  mutate(model = c("Model B (full)", "Model A (additive)"))

p10 <- ggplot(loo_df, aes(x = elpd_diff, y = reorder(model, elpd_diff))) +
  geom_col(fill = CSP_colors[1], width = 0.5) +
  geom_errorbarh(aes(xmin = elpd_diff - 2 * se_diff,
                     xmax = elpd_diff + 2 * se_diff),
                 height = 0.15) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(
    title    = "Model comparison via approximate LOO-CV",
    subtitle = "ELPD difference relative to best model (larger = better)",
    x        = "ΔELPD (± 2 SE)",
    y        = NULL
  ) +
  theme_model()

ggsave(file.path(PLOTS_DIR, "fig10_loo_compare.pdf"), p10, width = 6, height = 3)
ggsave(file.path(PLOTS_DIR, "fig10_loo_compare.png"), p10, width = 6, height = 3,
       dpi = 180)

cat("\nFigures saved:\n")
cat("  fig8_coef_plot    — coefficient plot for Model A\n")
cat("  fig9_cond_effects — conditional effects (pc_prop × pc_prag × g)\n")
cat("  fig10_loo_compare — LOO model comparison\n")
