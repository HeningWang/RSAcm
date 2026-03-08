# 10_rsa_listener_relaxed.R
#
# RSA listener analysis using RELAXED production thresholds.
#
# Two models are fit:
#   1. Base adoption link (preregistered):
#      logit(P_adopt) = eta_0 + eta_g * E[g|u,pc] - eta_pc * pc - eta_int * E[g|u,pc] * pc
#
#   2. Reactance adoption link (new):
#      logit(P_adopt) = eta_0 + eta_g * E[g|u,pc] - eta_pc * pc
#                        - eta_int * E[g|u,pc] * pc - eta_r * E[g|u,pc]^2
#      The quadratic penalty on E[g] creates an inverse-U: moderate g boosts
#      adoption, very high g triggers resistance.
#
# Outputs:
#   data/rsa_listener_relaxed_condition_summary.csv
#   data/rsa_listener_relaxed_parameter_summary.csv
#   plots/fig10_rsa_listener_relaxed.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(aida)

UTILS_PATH <- if (file.exists("00_utils.R")) "00_utils.R" else file.path("analysis", "comprehension_exp", "00_utils.R")
source(UTILS_PATH)

SCRIPT_DIR <- get_script_dir()
DATA_DIR <- file.path(SCRIPT_DIR, "data")
PLOTS_DIR <- file.path(SCRIPT_DIR, "plots")
dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(PLOTS_DIR, showWarnings = FALSE, recursive = TRUE)

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

# ── Model functions ─────────────────────────────────────────────────────
PC <- function(pc_prop, pc_prag) pc_prop * pc_prag

U <- function(pc, g, w_pc, w_g, w_int) {
  -w_pc * pc + w_g * g - w_int * pc * g
}

PROBIT_C <- sqrt(pi / 8)

interval_lik <- function(util, mu_lo, sig_lo, mu_hi, sig_hi, lambda) {
  lo_z <- lambda * (util - mu_lo) * PROBIT_C /
    sqrt(1 + (lambda * sig_lo * PROBIT_C)^2)
  lo <- pnorm(lo_z)
  if (is.finite(mu_hi)) {
    hi_z <- -lambda * (util - mu_hi) * PROBIT_C /
      sqrt(1 + (lambda * sig_hi * PROBIT_C)^2)
    hi <- pnorm(hi_z)
  } else {
    hi <- 1
  }
  lo * hi
}

choice_prob_matrix <- function(util, thr, uthr, sig, usig, lambda, costs) {
  weights <- vapply(seq_along(thr), function(i) {
    interval_lik(util, thr[i], sig[i], uthr[i], usig[i], lambda) * exp(-costs[i])
  }, numeric(length(util)))
  row_sums <- rowSums(weights)
  bad <- !is.finite(row_sums) | row_sums <= 0
  row_sums[bad] <- 1
  probs <- sweep(weights, 1, row_sums, "/")
  if (any(bad)) probs[bad, ] <- 1 / ncol(probs)
  probs
}

logistic <- function(x) 1 / (1 + exp(-x))

# ── Load data ───────────────────────────────────────────────────────────
crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = FALSE)

# Load RELAXED production parameters
prod_fit_path <- file.path(SCRIPT_DIR, "../production_exp/data/fit_rsa_relaxed_thresholds.rds")
if (!file.exists(prod_fit_path)) {
  stop("Relaxed production fit not found. Run analysis/production_exp/06_rsa_relaxed_thresholds.R first.")
}
prod_fit <- readRDS(prod_fit_path)
prod_par <- prod_fit$transformed
lambda_fixed <- prod_fit$lambda

# Also load strict fit for comparison
strict_fit <- readRDS(file.path(SCRIPT_DIR, "../production_exp/data/fit_rsa_soft_thresholds.rds"))
strict_par <- strict_fit$transformed

cat("\n=== Production parameters ===\n")
cat("Strict thresholds:  ", round(strict_par$thr, 3), "\n")
cat("Relaxed thresholds: ", round(prod_par$thr, 3), "\n")
cat("Strict sigma:       ", round(strict_par$sigma, 3), "\n")
cat("Relaxed sigma:      ", round(prod_par$sigma, 3), "\n")

# ── Compute E[g|marker, pc] for each cell ───────────────────────────────
grid_g <- seq(0, 1, length.out = 401)

cell_means <- crit |>
  group_by(topic, item_id, condition_index, pc_prag, g_implied, marker, mean_pc_prop_rating) |>
  summarise(
    wt = n(),
    pc_prop = first(1 - mean_pc_prop_rating / 100),
    mean_goal = mean(inferred_goal_strength),
    mean_adoption = mean(adoption_likelihood),
    .groups = "drop"
  ) |>
  mutate(
    marker_index = match(as.character(marker), MARKERS_ORDERED),
    pc_prag_val = ifelse(pc_prag == "high", 1, prod_par$pc_prag_low),
    pc = PC(pc_prop, pc_prag_val)
  )

compute_goal_posterior_mean <- function(marker_index, pc, pars, lambda) {
  util <- U(pc, grid_g, pars$w_pc, pars$w_g, pars$w_int)

  # Sort thresholds for interval computation (relaxed model may not be ordered)
  thr_sorted <- sort(pars$thr)
  rank_order <- order(pars$thr)

  probs <- choice_prob_matrix(
    util = util,
    thr = thr_sorted,
    uthr = c(thr_sorted[-1], Inf),
    sig = rep(pars$sigma, 3),
    usig = c(pars$sigma, pars$sigma, 0),
    lambda = lambda,
    costs = pars$costs
  )
  # Remap columns back to original marker ordering
  probs <- probs[, order(rank_order)]

  like <- probs[, marker_index]
  post <- like / sum(like)
  sum(grid_g * post)
}

# Compute E[g|marker, pc] using both strict and relaxed parameters
cell_means$eg_relaxed <- vapply(seq_len(nrow(cell_means)), function(i) {
  compute_goal_posterior_mean(cell_means$marker_index[i], cell_means$pc[i], prod_par, lambda_fixed)
}, numeric(1))

cell_means$eg_strict <- vapply(seq_len(nrow(cell_means)), function(i) {
  compute_goal_posterior_mean(cell_means$marker_index[i], cell_means$pc[i], strict_par, lambda_fixed)
}, numeric(1))

cell_means$adoption_obs <- cell_means$mean_adoption / 100

# ── Compare E[g] across models ──────────────────────────────────────────
eg_comparison <- cell_means |>
  group_by(pc_prag, marker) |>
  summarise(
    eg_diff = weighted.mean(eg_relaxed - eg_strict, wt),
    mean_eg_strict = weighted.mean(eg_strict, wt),
    mean_eg_relaxed = weighted.mean(eg_relaxed, wt),
    .groups = "drop"
  )

cat("\n=== E[g|marker, pc] comparison: strict vs relaxed ===\n")
print(eg_comparison)

# ── Fit adoption links ──────────────────────────────────────────────────

# Model 1: Base adoption link (preregistered)
fit_base <- function(eg_col) {
  optim(
    par = c(0, 1, 1, 0),
    fn = function(par, dat) {
      pred <- logistic(par[1] + par[2] * dat[[eg_col]] - par[3] * dat$pc - par[4] * dat[[eg_col]] * dat$pc)
      sum(dat$wt * (dat$adoption_obs - pred)^2)
    },
    dat = cell_means,
    method = "BFGS",
    hessian = TRUE,
    control = list(maxit = 5000, reltol = 1e-10)
  )
}

# Model 2: Reactance adoption link (adds -eta_r * E[g]^2)
fit_reactance <- function(eg_col) {
  optim(
    par = c(0, 1, 1, 0, 0),
    fn = function(par, dat) {
      eg <- dat[[eg_col]]
      pred <- logistic(par[1] + par[2] * eg - par[3] * dat$pc - par[4] * eg * dat$pc - par[5] * eg^2)
      sum(dat$wt * (dat$adoption_obs - pred)^2)
    },
    dat = cell_means,
    method = "BFGS",
    hessian = TRUE,
    control = list(maxit = 5000, reltol = 1e-10)
  )
}

# Goal calibration
goal_lm_relaxed <- lm(mean_goal ~ I(100 * eg_relaxed), data = cell_means, weights = wt)
goal_lm_strict <- lm(mean_goal ~ I(100 * eg_strict), data = cell_means, weights = wt)

rmse_w <- function(obs, pred, w) sqrt(weighted.mean((obs - pred)^2, w))

# Fit all 4 combinations
base_strict <- fit_base("eg_strict")
base_relaxed <- fit_base("eg_relaxed")
react_strict <- fit_reactance("eg_strict")
react_relaxed <- fit_reactance("eg_relaxed")

# ── Compute predictions ─────────────────────────────────────────────────
cell_means <- cell_means |>
  mutate(
    # Base link predictions
    adopt_base_strict = 100 * logistic(
      base_strict$par[1] + base_strict$par[2] * eg_strict -
        base_strict$par[3] * pc - base_strict$par[4] * eg_strict * pc),
    adopt_base_relaxed = 100 * logistic(
      base_relaxed$par[1] + base_relaxed$par[2] * eg_relaxed -
        base_relaxed$par[3] * pc - base_relaxed$par[4] * eg_relaxed * pc),
    # Reactance link predictions
    adopt_react_strict = 100 * logistic(
      react_strict$par[1] + react_strict$par[2] * eg_strict -
        react_strict$par[3] * pc - react_strict$par[4] * eg_strict * pc -
        react_strict$par[5] * eg_strict^2),
    adopt_react_relaxed = 100 * logistic(
      react_relaxed$par[1] + react_relaxed$par[2] * eg_relaxed -
        react_relaxed$par[3] * pc - react_relaxed$par[4] * eg_relaxed * pc -
        react_relaxed$par[5] * eg_relaxed^2),
    # Goal calibrated predictions
    goal_calib_relaxed = predict(goal_lm_relaxed),
    goal_calib_strict = predict(goal_lm_strict)
  )

# ── Condition-level summary ─────────────────────────────────────────────
cond_summary <- cell_means |>
  group_by(pc_prag, marker) |>
  summarise(
    obs_goal = weighted.mean(mean_goal, wt),
    obs_adoption = weighted.mean(mean_adoption, wt),
    goal_strict = weighted.mean(100 * eg_strict, wt),
    goal_relaxed = weighted.mean(100 * eg_relaxed, wt),
    goal_calib_strict = weighted.mean(goal_calib_strict, wt),
    goal_calib_relaxed = weighted.mean(goal_calib_relaxed, wt),
    adopt_base_strict = weighted.mean(adopt_base_strict, wt),
    adopt_base_relaxed = weighted.mean(adopt_base_relaxed, wt),
    adopt_react_strict = weighted.mean(adopt_react_strict, wt),
    adopt_react_relaxed = weighted.mean(adopt_react_relaxed, wt),
    .groups = "drop"
  )

write.csv(cond_summary,
          file.path(DATA_DIR, "rsa_listener_relaxed_condition_summary.csv"),
          row.names = FALSE)

# ── RMSE comparison ─────────────────────────────────────────────────────
rmse_table <- tibble(
  model = c("base_strict", "base_relaxed", "react_strict", "react_relaxed"),
  goal_rmse_raw = c(
    rmse_w(cell_means$mean_goal, 100 * cell_means$eg_strict, cell_means$wt),
    rmse_w(cell_means$mean_goal, 100 * cell_means$eg_relaxed, cell_means$wt),
    rmse_w(cell_means$mean_goal, 100 * cell_means$eg_strict, cell_means$wt),
    rmse_w(cell_means$mean_goal, 100 * cell_means$eg_relaxed, cell_means$wt)
  ),
  goal_rmse_calib = c(
    rmse_w(cell_means$mean_goal, cell_means$goal_calib_strict, cell_means$wt),
    rmse_w(cell_means$mean_goal, cell_means$goal_calib_relaxed, cell_means$wt),
    rmse_w(cell_means$mean_goal, cell_means$goal_calib_strict, cell_means$wt),
    rmse_w(cell_means$mean_goal, cell_means$goal_calib_relaxed, cell_means$wt)
  ),
  adoption_rmse = c(
    rmse_w(cell_means$mean_adoption, cell_means$adopt_base_strict, cell_means$wt),
    rmse_w(cell_means$mean_adoption, cell_means$adopt_base_relaxed, cell_means$wt),
    rmse_w(cell_means$mean_adoption, cell_means$adopt_react_strict, cell_means$wt),
    rmse_w(cell_means$mean_adoption, cell_means$adopt_react_relaxed, cell_means$wt)
  ),
  n_adoption_params = c(4, 4, 5, 5),
  wsse_adoption = c(base_strict$value, base_relaxed$value, react_strict$value, react_relaxed$value)
)

cat("\n=== RMSE comparison ===\n")
print(rmse_table)

# ── Parameter summary ───────────────────────────────────────────────────
param_summary <- tibble(
  model = rep(c("base_relaxed", "react_relaxed"), c(4, 5)),
  parameter = c("eta_0", "eta_g", "eta_pc", "eta_int",
                "eta_0", "eta_g", "eta_pc", "eta_int", "eta_r"),
  estimate = c(base_relaxed$par, react_relaxed$par)
)

write.csv(param_summary,
          file.path(DATA_DIR, "rsa_listener_relaxed_parameter_summary.csv"),
          row.names = FALSE)

cat("\n=== Reactance model parameters (relaxed thresholds) ===\n")
cat("eta_0 =", round(react_relaxed$par[1], 3), "\n")
cat("eta_g =", round(react_relaxed$par[2], 3), "\n")
cat("eta_pc =", round(react_relaxed$par[3], 3), "\n")
cat("eta_int =", round(react_relaxed$par[4], 3), "\n")
cat("eta_r (reactance) =", round(react_relaxed$par[5], 3), "\n")

# ── Key diagnostic: does the reactance model predict ja > bek on adoption? ──
cat("\n=== Condition-level adoption predictions ===\n")
cond_summary |>
  select(pc_prag, marker, obs_adoption,
         adopt_base_strict, adopt_base_relaxed,
         adopt_react_relaxed) |>
  print(n = 20)

# Check if ja > bek in reactance model
for (pcp in c("low", "high")) {
  ja_adopt <- cond_summary |> filter(pc_prag == pcp, marker == "ja") |> pull(adopt_react_relaxed)
  bek_adopt <- cond_summary |> filter(pc_prag == pcp, marker == "bekanntlich") |> pull(adopt_react_relaxed)
  cat(sprintf("pc_prag=%s: react_relaxed ja=%.1f, bek=%.1f, ja>bek=%s\n",
              pcp, ja_adopt, bek_adopt, ja_adopt > bek_adopt))
}

# ── Plot: Observed vs all models ────────────────────────────────────────
summarise_with_uncertainty <- function(data, n_boot = 2000) {
  x <- data$value; w <- data$wt
  est <- weighted.mean(x, w)
  if (length(x) <= 1) return(tibble(value = est, lower = est, upper = est))
  boot <- replicate(n_boot, {
    idx <- sample.int(length(x), size = length(x), replace = TRUE)
    weighted.mean(x[idx], w[idx])
  })
  tibble(value = est, lower = quantile(boot, 0.025), upper = quantile(boot, 0.975))
}

plot_long <- bind_rows(
  cell_means |> transmute(pc_prag, marker, wt, outcome = "Inferred goal strength",
                           series = "Observed", value = mean_goal),
  cell_means |> transmute(pc_prag, marker, wt, outcome = "Inferred goal strength",
                           series = "RSA (relaxed, calib.)", value = goal_calib_relaxed),
  cell_means |> transmute(pc_prag, marker, wt, outcome = "Adoption likelihood",
                           series = "Observed", value = mean_adoption),
  cell_means |> transmute(pc_prag, marker, wt, outcome = "Adoption likelihood",
                           series = "Base (strict)", value = adopt_base_strict),
  cell_means |> transmute(pc_prag, marker, wt, outcome = "Adoption likelihood",
                           series = "Base (relaxed)", value = adopt_base_relaxed),
  cell_means |> transmute(pc_prag, marker, wt, outcome = "Adoption likelihood",
                           series = "Reactance (relaxed)", value = adopt_react_relaxed)
) |>
  group_by(pc_prag, marker, outcome, series) |>
  group_modify(~ summarise_with_uncertainty(.x)) |>
  ungroup() |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high")),
    series = factor(series, levels = c("Observed", "RSA (relaxed, calib.)",
                                       "Base (strict)", "Base (relaxed)", "Reactance (relaxed)"))
  )

p <- ggplot(plot_long,
            aes(x = marker, y = value, colour = series, shape = series, group = series)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.08, linewidth = 0.6,
                position = position_dodge(width = 0.22)) +
  geom_point(size = 2.5, position = position_dodge(width = 0.22)) +
  geom_line(position = position_dodge(width = 0.22), linewidth = 0.7) +
  facet_grid(outcome ~ pc_prag, scales = "free_y") +
  scale_colour_manual(values = c("Observed" = CSP_colors[1],
                                 "RSA (relaxed, calib.)" = CSP_colors[2],
                                 "Base (strict)" = CSP_colors[6],
                                 "Base (relaxed)" = CSP_colors[4],
                                 "Reactance (relaxed)" = CSP_colors[3])) +
  scale_shape_manual(values = c(16, 18, 4, 17, 15)) +
  labs(x = NULL, y = "Mean rating", colour = NULL, shape = NULL) +
  theme_comp() +
  theme(legend.position = "top", axis.text.x = element_text(angle = 18, hjust = 1),
        panel.grid.major.x = element_blank())

save_plot(p, "fig10_rsa_listener_relaxed", SCRIPT_DIR, width = 10.5, height = 6.5)

cat("\nSaved:\n")
cat("  data/rsa_listener_relaxed_condition_summary.csv\n")
cat("  data/rsa_listener_relaxed_parameter_summary.csv\n")
cat("  plots/fig10_rsa_listener_relaxed\n")
