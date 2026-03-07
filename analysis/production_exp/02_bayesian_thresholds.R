# 02_bayesian_thresholds.R
#
# Fits the hierarchical cumulative-probit (noisy-threshold) model to the
# critical trials and estimates:
#   - Ordinal thresholds  μ_1 < μ_2
#   - Utility weights     β_pc_prop, β_pc_prag, β_g
#   - Marker costs        c_ja, c_bekanntlich
#   - Between-participant SD  σ_u
#
# Requires: rstan  (≥ 2.21)  or  cmdstanr  (preferred)
# Stan model: models/noisy_threshold.stan
#
# Outputs:
#   - fit object cached at data/fit_threshold_3markers.rds
#   - plots/fig5_posteriors.pdf/png   — posterior densities of key parameters
#   - plots/fig6_thresholds.pdf/png   — threshold estimates on utility axis
#   - plots/fig7_ppc.pdf/png          — posterior predictive check

library(dplyr)
library(tidyr)
library(ggplot2)
library(posterior)   # for as_draws_df(), summarise_draws()
library(bayesplot)   # for mcmc_areas(), ppc_bars()
library(aida)

# Choose backend: "rstan" or "cmdstanr"
BACKEND <- "cmdstanr"

if (BACKEND == "cmdstanr") {
  library(cmdstanr)
} else {
  library(rstan)
  options(mc.cores = parallel::detectCores())
  rstan_options(auto_write = TRUE)
}

PLOTS_DIR <- "plots"
dir.create(PLOTS_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c(
  "soviel ich weiß",
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

as_logical_flag <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "t", "1")
}

# ── Load data ──────────────────────────────────────────────────────────────────
dat <- read.csv("data/dummy_data.csv", stringsAsFactors = FALSE)
dat <- dat |>
  mutate(
    is_filler = as_logical_flag(is_filler),
    is_training = as_logical_flag(is_training)
  )

# Load norming means and compute centred controversy predictor (mean = 0, SD ≈ 1)
norming <- read.csv("data/norming_means.csv", stringsAsFactors = FALSE) |>
  mutate(pc_prop_c = as.numeric(scale(-mean_pc_prop_rating)))

crit <- dat |>
  filter(!is_filler, !is_training) |>
  left_join(norming |> select(topic, pc_prop_c), by = "topic") |>
  mutate(
    y         = match(selected_marker, MARKERS_ORDERED),   # 1–3
    pc_prag_n = ifelse(pc_prag == "high", 1L, 0L),
    g_n       = ifelse(g       == "high", 1L, 0L),
    subj      = as.integer(factor(submission_id))
  )

stopifnot(!any(is.na(crit$y)))

stan_data <- list(
  N       = nrow(crit),
  N_subj  = length(unique(crit$subj)),
  y       = crit$y,
  pc_prop = crit$pc_prop_c,    # continuous centred controversy rating
  pc_prag = crit$pc_prag_n,
  g       = crit$g_n,
  subj    = crit$subj
)

# ── Fit or load cached model ───────────────────────────────────────────────────
cache_path <- "data/fit_threshold_3markers.rds"

if (file.exists(cache_path)) {
  message("Loading cached draws from ", cache_path)
  draws <- readRDS(cache_path)
} else {
  message("Fitting Stan model …")

  if (BACKEND == "cmdstanr") {
    mod <- cmdstan_model("models/noisy_threshold.stan")
    fit <- mod$sample(
      data            = stan_data,
      chains          = 4,
      parallel_chains = 4,
      iter_warmup     = 1000,
      iter_sampling   = 2000,
      seed            = 123,
      refresh         = 500,
      adapt_delta     = 0.99,
      max_treedepth   = 12
    )
  } else {
    fit <- stan(
      file    = "models/noisy_threshold.stan",
      data    = stan_data,
      chains  = 4,
      iter    = 3000,
      warmup  = 1000,
      seed    = 123,
      refresh = 500,
      control = list(adapt_delta = 0.99, max_treedepth = 12)
    )
  }

  # Save draws (not the fit object) so the cache is portable across sessions
  draws <- as_draws_df(fit)
  saveRDS(draws, cache_path)
  message("Saved draws to ", cache_path)
}

# ── Diagnostics ───────────────────────────────────────────────────────────────
key_pars <- c("mu[1]", "mu[2]",
              "beta_pc_prop", "beta_pc_prag", "beta_g",
              "cost_ja", "cost_bek", "sigma_u")

cat("\n=== Posterior summary ===\n")
print(summarise_draws(draws, mean, sd, ~quantile(.x, c(0.025, 0.975)),
                      rhat, ess_bulk) |>
        filter(variable %in% key_pars))

# ── Figure 5: Posterior densities ─────────────────────────────────────────────
beta_draws <- draws |>
  select(all_of(c("beta_pc_prop", "beta_pc_prag", "beta_g", "cost_ja", "cost_bek"))) |>
  pivot_longer(everything(), names_to = "parameter", values_to = "value") |>
  mutate(parameter = factor(parameter,
                            levels = c("beta_pc_prop", "beta_pc_prag", "beta_g", "cost_ja", "cost_bek"),
                            labels = c("β[pc_prop]", "β[pc_prag]", "β[g]", "c[ja]", "c[bek]")))

p5a <- ggplot(beta_draws, aes(x = value)) +
  geom_density(alpha = 0.35, linewidth = 0.8, fill = CSP_colors[1], colour = CSP_colors[1]) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40") +
  facet_wrap(~parameter, scales = "free", labeller = label_parsed) +
  labs(title = "Posterior distributions of speaker-side parameters",
       x = "Parameter value", y = "Density") +
  theme_model()

mu_draws <- draws |>
  select(starts_with("mu[")) |>
  pivot_longer(everything(), names_to = "threshold", values_to = "value") |>
  mutate(threshold = factor(threshold, levels = paste0("mu[", 1:2, "]"),
                            labels = paste0("μ[", 1:2, "]")))

p5b <- ggplot(mu_draws, aes(x = value)) +
  geom_density(alpha = 0.35, linewidth = 0.8, fill = CSP_colors[4], colour = CSP_colors[4]) +
  facet_wrap(~threshold, scales = "free_x", labeller = label_parsed) +
  labs(title = "Posterior distributions of ordinal thresholds",
       x = "Threshold value", y = "Density") +
  theme_model()

p5 <- patchwork::wrap_plots(p5a, p5b, ncol = 1) +
  patchwork::plot_annotation(title = "Bayesian noisy-threshold model — key parameters")

message("Saving fig5 …")
ggsave(file.path(PLOTS_DIR, "fig5_posteriors.pdf"), p5, width = 10, height = 8)
ggsave(file.path(PLOTS_DIR, "fig5_posteriors.png"), p5, width = 10, height = 8,
       dpi = 180)
message("fig5 done.")

# ── Figure 6: Threshold credible intervals on the utility axis ─────────────────
mu_summ <- summarise_draws(
  draws |> select(starts_with("mu[")),
  mean, ~quantile(.x, c(0.025, 0.10, 0.90, 0.975))
) |>
  mutate(
    k     = as.integer(sub("mu\\[(\\d)\\]", "\\1", variable)),
    label = paste0("μ[", k, "]")
  )

# Annotate with marker labels between thresholds
marker_labels <- tibble(
  marker = MARKERS_ORDERED,
  x = c(
    mu_summ$mean[1] - 0.8,                      # below μ_1
    (mu_summ$mean[1] + mu_summ$mean[2]) / 2,    # between μ_1 and μ_2
    mu_summ$mean[2] + 0.8                        # above μ_2
  ),
  y = 0.55
)

p6 <- ggplot(mu_summ, aes(x = mean, y = 0.5)) +
  # 95% CI ribbon
  geom_errorbarh(aes(xmin = `2.5%`, xmax = `97.5%`),
                 height = 0.06, colour = CSP_colors[1], linewidth = 1) +
  # 80% CI
  geom_errorbarh(aes(xmin = `10%`, xmax = `90%`),
                 height = 0, colour = CSP_colors[1], linewidth = 2.5, alpha = 0.5) +
  geom_point(size = 4, colour = CSP_colors[1]) +
  geom_text(aes(label = label), vjust = -1.5, size = 4.5,
            parse = TRUE) +
  # Marker labels
  geom_text(data = marker_labels,
            aes(x = x, y = y, label = marker),
            inherit.aes = FALSE, size = 3.2, colour = "#555555",
            fontface = "italic", vjust = 0) +
  scale_x_continuous(name = "Latent utility axis") +
  scale_y_continuous(limits = c(0.3, 0.8), name = NULL) +
  labs(title = "Estimated ordinal thresholds (posterior mean ± 80%/95% CI)",
       subtitle = "Markers occupy the intervals between thresholds") +
  theme_model() +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(),
        panel.grid.major.y = element_blank())

message("Saving fig6 …")
ggsave(file.path(PLOTS_DIR, "fig6_thresholds.pdf"), p6, width = 10, height = 3.5)
ggsave(file.path(PLOTS_DIR, "fig6_thresholds.png"), p6, width = 10, height = 3.5,
       dpi = 180)
message("fig6 done.")

# ── Figure 7: Posterior predictive check ──────────────────────────────────────
# Compare observed marker frequencies to replicated datasets
y_rep_mat <- as.matrix(draws[, grep("^y_rep\\[", colnames(draws))])
y_obs     <- crit$y

p7 <- ppc_bars(y_obs, y_rep_mat[1:200, ],
               freq = FALSE) +
  scale_x_continuous(breaks = 1:3, labels = MARKERS_ORDERED) +
  labs(title = "Posterior predictive check — marker frequency distribution",
       x = "Marker", y = "Proportion") +
  theme_model() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))

message("Saving fig7 …")
ggsave(file.path(PLOTS_DIR, "fig7_ppc.pdf"), p7, width = 8, height = 5)
ggsave(file.path(PLOTS_DIR, "fig7_ppc.png"), p7, width = 8, height = 5, dpi = 180)
message("fig7 done.")

cat("\nFigures saved:\n")
cat("  fig5_posteriors  — posterior densities of betas and thresholds\n")
cat("  fig6_thresholds  — threshold CIs on utility axis\n")
cat("  fig7_ppc         — posterior predictive check\n")
