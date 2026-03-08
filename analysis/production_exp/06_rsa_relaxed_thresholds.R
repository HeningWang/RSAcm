# 06_rsa_relaxed_thresholds.R
#
# Refit the RSA soft-threshold model with RELAXED threshold ordering.
#
# Key change from 04_rsa_soft_thresholds.R:
#   - Thresholds are unconstrained (3 free parameters) instead of
#     cumulative-exp (which forces strict thr1 < thr2 < thr3).
#   - A soft ordering penalty encourages but does not enforce ordering.
#   - This allows the optimizer to explore near-tied or overlapping
#     thresholds for ja and bekanntlich, which the data suggest.
#
# Outputs:
#   data/fit_rsa_relaxed_thresholds.rds
#   data/rsa_relaxed_threshold_summary.csv
#   data/rsa_relaxed_vs_strict_comparison.csv
#   plots/fig17_rsa_relaxed_thresholds.pdf/png
#   plots/fig18_rsa_relaxed_vs_strict.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(aida)

PLOTS_DIR <- "plots"
DATA_DIR  <- "data"
dir.create(PLOTS_DIR, showWarnings = FALSE)
dir.create(DATA_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c("soviel ich weiß", "ja", "bekanntlich")

CSP_colors <- c(
  "#7581B3", "#99C2C2", "#C65353", "#E2BA78", "#5C7457", "#575463",
  "#B0B7D4", "#66A3A3", "#DB9494", "#D49735", "#9BB096", "#D4D3D9",
  "#414C76", "#993333"
)
marker_colors <- setNames(CSP_colors[seq_along(MARKERS_ORDERED)], MARKERS_ORDERED)

theme_set(theme_aida())
theme_model <- function() {
  theme_aida() +
    theme(
      axis.text.y  = element_text(size = 14),
      axis.text.x  = element_text(size = 14),
      axis.title.y = element_text(size = 16),
      axis.title.x = element_text(size = 16),
      legend.text  = element_text(size = 13),
      legend.title = element_text(size = 14)
    )
}

save_plot <- function(p, name, w = 8, h = 5) {
  ggsave(file.path(PLOTS_DIR, paste0(name, ".pdf")), p, width = w, height = h)
  ggsave(file.path(PLOTS_DIR, paste0(name, ".png")), p, width = w, height = h, dpi = 180)
  invisible(p)
}

as_logical_flag <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "t", "1")
}

# ── Model functions (shared with 04) ────────────────────────────────────
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

# ── Data ────────────────────────────────────────────────────────────────
lambda_fixed <- 6

dat <- read.csv(file.path(DATA_DIR, "dummy_data.csv"), stringsAsFactors = FALSE) |>
  mutate(is_filler = as_logical_flag(is_filler), is_training = as_logical_flag(is_training))

norming <- read.csv(file.path(DATA_DIR, "norming_means.csv"), stringsAsFactors = FALSE) |>
  mutate(consensus_prop = mean_pc_prop_rating / 100, pc_prop = 1 - consensus_prop)

crit <- dat |>
  filter(!is_filler, !is_training) |>
  left_join(norming |> select(topic, consensus_prop, pc_prop), by = "topic") |>
  mutate(
    y = match(selected_marker, MARKERS_ORDERED),
    pc_prag_high = ifelse(pc_prag == "high", 1, 0),
    g_high = ifelse(g == "high", 1, 0)
  )

stopifnot(!any(is.na(crit$y)), !any(is.na(crit$pc_prop)))

# ── Relaxed parametrization ─────────────────────────────────────────────
# par[1:3]  = log(w_pc, w_g, w_int)
# par[4]    = logit(pc_prag_low)
# par[5:7]  = thr1, thr2, thr3  (UNCONSTRAINED — no cumulative-exp)
# par[8]    = log(sigma)
# par[9:10] = log(cost_ja, cost_bek)

decode_par_relaxed <- function(par) {
  list(
    w_pc = exp(par[1]),
    w_g = exp(par[2]),
    w_int = exp(par[3]),
    pc_prag_low = plogis(par[4]),
    thr = c(par[5], par[6], par[7]),  # unconstrained
    sigma = exp(par[8]),
    costs = c(0, exp(par[9]), exp(par[10]))
  )
}

neg_log_lik_relaxed <- function(par, data, lambda = lambda_fixed) {
  pars <- decode_par_relaxed(par)
  pc_prag_val <- ifelse(data$pc_prag_high == 1, 1, pars$pc_prag_low)
  pc <- PC(data$pc_prop, pc_prag_val)
  util <- U(pc, data$g_high, pars$w_pc, pars$w_g, pars$w_int)

  # Sort thresholds for the interval likelihood computation
  # (the interval_lik needs ordered boundaries to define intervals)
  thr_sorted <- sort(pars$thr)

  probs <- choice_prob_matrix(
    util = util,
    thr = thr_sorted,
    uthr = c(thr_sorted[-1], Inf),
    sig = rep(pars$sigma, 3),
    usig = c(pars$sigma, pars$sigma, 0),
    lambda = lambda,
    costs = pars$costs
  )

  # Map sorted thresholds back to marker identity:
  # The marker assigned to each interval depends on which threshold is which.
  # If thresholds stay ordered (soviel < ja < bek), mapping is standard.
  # If ja and bek swap, the middle interval becomes bek and top becomes ja.
  rank_order <- order(pars$thr)  # which original marker gets which sorted position

  # Remap columns: probs columns are in sorted-threshold order,
  # but data$y refers to original marker ordering
  probs_remapped <- probs[, order(rank_order)]

  p_obs <- probs_remapped[cbind(seq_len(nrow(data)), data$y)]
  -sum(log(pmax(p_obs, 1e-12)))
}

neg_log_post_relaxed <- function(par, data, lambda = lambda_fixed) {
  nll <- neg_log_lik_relaxed(par, data = data, lambda = lambda)

  # Priors on utility weights, pc_prag_low, sigma, costs (same as original)
  log_prior <-
    dnorm(par[1], log(1.2), 0.8, log = TRUE) +
    dnorm(par[2], log(1.0), 0.8, log = TRUE) +
    dnorm(par[3], log(0.8), 0.8, log = TRUE) +
    dnorm(par[4], qlogis(0.5), 1.0, log = TRUE) +
    dnorm(par[8], log(0.18), 0.45, log = TRUE) +
    dnorm(par[9], log(0.4), 0.7, log = TRUE) +
    dnorm(par[10], log(0.6), 0.7, log = TRUE)

  # Priors on thresholds: weakly regularized toward the strict-ordering estimates
  log_prior <- log_prior +
    dnorm(par[5], -1.3, 0.7, log = TRUE) +  # thr_soviel
    dnorm(par[6], -0.5, 0.7, log = TRUE) +  # thr_ja
    dnorm(par[7], 0.0, 0.7, log = TRUE)     # thr_bek

  # Soft ordering penalty: encourage thr1 < thr2 < thr3 but don't enforce
  # penalty_strength controls how much violation costs
  penalty_strength <- 2.0
  ordering_penalty <- penalty_strength * (
    max(0, par[5] - par[6])^2 +   # thr_soviel should be < thr_ja
    max(0, par[6] - par[7])^2     # thr_ja should be < thr_bek
  )

  nll - log_prior + ordering_penalty
}

# ── Fit ─────────────────────────────────────────────────────────────────
fit_one_start <- function(par0, data) {
  tryCatch(
    optim(
      par = par0,
      fn = neg_log_post_relaxed,
      data = data,
      method = "L-BFGS-B",
      hessian = TRUE,
      lower = c(log(0.1), log(0.1), log(0.01), qlogis(0.05), -3.0, -3.0, -3.0, log(0.03), log(0.01), log(0.01)),
      upper = c(log(8.0), log(8.0), log(8.0),  qlogis(0.95),  1.0,  1.0,  1.0, log(0.7),  log(3.0),  log(3.0)),
      control = list(maxit = 5000, factr = 1e7)
    ),
    error = function(e) NULL
  )
}

# Initialize from the strict-ordering estimates
strict_fit <- readRDS(file.path(DATA_DIR, "fit_rsa_soft_thresholds.rds"))
strict_par <- strict_fit$transformed

set.seed(42)
base_start <- c(
  log(strict_par$w_pc),
  log(strict_par$w_g),
  log(strict_par$w_int),
  qlogis(strict_par$pc_prag_low),
  strict_par$thr[1],    # thr_soviel (free)
  strict_par$thr[2],    # thr_ja (free)
  strict_par$thr[3],    # thr_bek (free)
  log(strict_par$sigma),
  log(strict_par$costs[2]),
  log(strict_par$costs[3])
)

# Multiple starts: some from strict solution, some with ja/bek near-tied
starts <- c(
  list(base_start),
  # Starts with ja and bek thresholds closer together
  replicate(5, {
    s <- base_start
    s[6] <- s[6] + runif(1, 0, 0.3)   # push ja up
    s[7] <- s[7] - runif(1, 0, 0.3)   # push bek down
    s + rnorm(length(s), sd = 0.15)
  }, simplify = FALSE),
  # Starts with ja and bek thresholds swapped
  replicate(5, {
    s <- base_start
    tmp <- s[6]; s[6] <- s[7]; s[7] <- tmp  # swap
    s + rnorm(length(s), sd = 0.2)
  }, simplify = FALSE),
  # Random perturbations
  replicate(9, base_start + rnorm(length(base_start), sd = 0.3), simplify = FALSE)
)

fits <- Filter(Negate(is.null), lapply(starts, fit_one_start, data = crit))
stopifnot(length(fits) > 0)

best_fit <- fits[[which.min(vapply(fits, `[[`, numeric(1), "value"))]]
best_par <- decode_par_relaxed(best_fit$par)

# ── Uncertainty via Laplace approximation ───────────────────────────────
vcov_ok <- FALSE
draws <- NULL
if (all(is.finite(best_fit$hessian))) {
  vcov_mat <- tryCatch(solve(best_fit$hessian), error = function(e) NULL)
  if (!is.null(vcov_mat) && all(is.finite(vcov_mat))) {
    eig <- eigen(vcov_mat, symmetric = TRUE, only.values = TRUE)$values
    if (all(eig > 0) && requireNamespace("MASS", quietly = TRUE)) {
      draws_raw <- MASS::mvrnorm(4000, mu = best_fit$par, Sigma = vcov_mat)
      draws <- as.data.frame(t(apply(draws_raw, 1, function(x) {
        p <- decode_par_relaxed(x)
        c(w_pc = p$w_pc, w_g = p$w_g, w_int = p$w_int,
          pc_prag_low = p$pc_prag_low,
          threshold_soviel = p$thr[1],
          threshold_ja = p$thr[2],
          threshold_bekanntlich = p$thr[3],
          thr_gap_ja_bek = p$thr[3] - p$thr[2],
          sigma = p$sigma,
          cost_ja = p$costs[2],
          cost_bekanntlich = p$costs[3])
      })))
      vcov_ok <- TRUE
    }
  }
}

# ── Summary table ───────────────────────────────────────────────────────
summary_tbl <- tibble(
  parameter = c("w_pc", "w_g", "w_int", "pc_prag_low",
                "threshold_soviel", "threshold_ja", "threshold_bekanntlich",
                "thr_gap_ja_bek", "sigma", "cost_ja", "cost_bekanntlich"),
  estimate = c(best_par$w_pc, best_par$w_g, best_par$w_int, best_par$pc_prag_low,
               best_par$thr[1], best_par$thr[2], best_par$thr[3],
               best_par$thr[3] - best_par$thr[2],
               best_par$sigma, best_par$costs[2], best_par$costs[3])
)

if (vcov_ok) {
  summary_tbl <- summary_tbl |>
    mutate(
      conf.low = vapply(parameter, function(p) quantile(draws[[p]], 0.025), numeric(1)),
      conf.high = vapply(parameter, function(p) quantile(draws[[p]], 0.975), numeric(1))
    )
  # Key diagnostic: P(thr_bek > thr_ja)
  p_ordered <- mean(draws$threshold_bekanntlich > draws$threshold_ja)
  cat("\nP(thr_bek > thr_ja) =", round(p_ordered, 3), "\n")
  cat("P(thr_gap < sigma) =", round(mean(draws$thr_gap_ja_bek < draws$sigma), 3), "\n")
} else {
  summary_tbl <- summary_tbl |>
    mutate(conf.low = NA_real_, conf.high = NA_real_)
}

write.csv(summary_tbl, file.path(DATA_DIR, "rsa_relaxed_threshold_summary.csv"), row.names = FALSE)

# ── Save fit ────────────────────────────────────────────────────────────
saveRDS(
  list(
    fit = best_fit,
    transformed = best_par,
    lambda = lambda_fixed,
    summary = summary_tbl,
    draws = draws,
    model_type = "relaxed_thresholds"
  ),
  file.path(DATA_DIR, "fit_rsa_relaxed_thresholds.rds")
)

# ── Comparison with strict model ────────────────────────────────────────
strict_summary <- read.csv(file.path(DATA_DIR, "rsa_soft_threshold_summary.csv"))

comparison <- tibble(
  parameter = summary_tbl$parameter,
  relaxed_estimate = summary_tbl$estimate,
  relaxed_low = summary_tbl$conf.low,
  relaxed_high = summary_tbl$conf.high
) |>
  left_join(
    strict_summary |> transmute(
      parameter,
      strict_estimate = estimate,
      strict_low = conf.low,
      strict_high = conf.high
    ),
    by = "parameter"
  )

write.csv(comparison, file.path(DATA_DIR, "rsa_relaxed_vs_strict_comparison.csv"), row.names = FALSE)

cat("\n=== Relaxed-threshold RSA fit ===\n")
cat("Converged:", best_fit$convergence == 0, "\n")
cat("Neg. log-posterior (relaxed):", round(best_fit$value, 3), "\n")
cat("Neg. log-posterior (strict): ", round(strict_fit$fit$value, 3), "\n")
print(summary_tbl)

cat("\n=== Comparison: strict vs relaxed ===\n")
print(comparison |> filter(parameter %in% c("threshold_ja", "threshold_bekanntlich", "thr_gap_ja_bek", "sigma")))

# ── Figure: marker probabilities along utility axis ─────────────────────
pc_prag_val_obs <- ifelse(crit$pc_prag_high == 1, 1, best_par$pc_prag_low)
pc_obs <- PC(crit$pc_prop, pc_prag_val_obs)
util_obs <- U(pc_obs, crit$g_high, best_par$w_pc, best_par$w_g, best_par$w_int)

thr_sorted <- sort(best_par$thr)
rank_order <- order(best_par$thr)

util_grid <- seq(min(util_obs) - 0.4, max(util_obs) + 0.4, length.out = 500)
prob_grid <- choice_prob_matrix(
  util = util_grid,
  thr = thr_sorted,
  uthr = c(thr_sorted[-1], Inf),
  sig = rep(best_par$sigma, 3),
  usig = c(best_par$sigma, best_par$sigma, 0),
  lambda = lambda_fixed,
  costs = best_par$costs
)
# Remap columns back to original marker ordering
prob_grid <- prob_grid[, order(rank_order)]

plot_df <- tibble(
  utility = rep(util_grid, times = 3),
  marker = factor(rep(MARKERS_ORDERED, each = length(util_grid)), levels = MARKERS_ORDERED),
  prob = c(prob_grid[, 1], prob_grid[, 2], prob_grid[, 3])
)

thr_band_df <- tibble(
  marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED),
  x = best_par$thr,
  xmin = best_par$thr - best_par$sigma,
  xmax = best_par$thr + best_par$sigma,
  ymin = 0, ymax = 1
)

p17 <- ggplot(plot_df, aes(x = utility, y = prob, colour = marker)) +
  geom_rect(data = thr_band_df,
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = marker),
            inherit.aes = FALSE, alpha = 0.08, colour = NA) +
  geom_vline(data = thr_band_df, aes(xintercept = x, colour = marker),
             linetype = "dashed", linewidth = 0.8, show.legend = FALSE) +
  geom_line(linewidth = 1.15) +
  scale_colour_manual(values = marker_colors, name = "Marker") +
  scale_fill_manual(values = marker_colors, guide = "none") +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Relaxed-threshold RSA: marker probabilities along utility axis",
    subtitle = sprintf("Thresholds unconstrained; dashed = threshold means, shaded = ±sigma (n=%d)", nrow(crit)),
    x = "Latent utility U(pc, g)",
    y = "Predicted marker probability"
  ) +
  theme_model() +
  theme(legend.position = "top")

save_plot(p17, "fig17_rsa_relaxed_thresholds", w = 9, h = 5)

# ── Figure: observed vs predicted comparison ────────────────────────────
pred_obs <- choice_prob_matrix(
  util = util_obs,
  thr = thr_sorted,
  uthr = c(thr_sorted[-1], Inf),
  sig = rep(best_par$sigma, 3),
  usig = c(best_par$sigma, best_par$sigma, 0),
  lambda = lambda_fixed,
  costs = best_par$costs
)
pred_obs <- pred_obs[, order(rank_order)]
colnames(pred_obs) <- MARKERS_ORDERED

pred_long <- as_tibble(pred_obs, .name_repair = "minimal") |>
  mutate(pc_prag = crit$pc_prag, g = crit$g) |>
  pivot_longer(cols = all_of(MARKERS_ORDERED), names_to = "marker", values_to = "pred")

pred_cond <- pred_long |>
  group_by(pc_prag, g, marker) |>
  summarise(pred = mean(pred), .groups = "drop")

obs_cond <- crit |>
  count(pc_prag, g, selected_marker, .drop = FALSE) |>
  group_by(pc_prag, g) |>
  mutate(obs = n / sum(n)) |>
  ungroup() |>
  transmute(pc_prag, g, marker = selected_marker, obs)

compare_df <- left_join(obs_cond, pred_cond, by = c("pc_prag", "g", "marker")) |>
  pivot_longer(cols = c(obs, pred), names_to = "series", values_to = "prop") |>
  mutate(
    marker = factor(marker, levels = MARKERS_ORDERED),
    series = factor(series, levels = c("obs", "pred"), labels = c("Observed", "Predicted (relaxed)")),
    condition = paste0("pc_prag:", pc_prag, "\n", "g:", g)
  )

p18 <- ggplot(compare_df, aes(x = condition, y = prop, fill = marker)) +
  geom_col(position = position_dodge2(width = 0.75, preserve = "single"), width = 0.65) +
  facet_wrap(~series, nrow = 1) +
  scale_fill_manual(values = marker_colors, name = "Marker") +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Observed vs. relaxed-threshold RSA predictions",
    x = "Condition", y = "Proportion"
  ) +
  theme_model() +
  theme(legend.position = "top")

save_plot(p18, "fig18_rsa_relaxed_vs_strict", w = 10, h = 5.5)

cat("\nFigures saved:\n")
cat("  fig17_rsa_relaxed_thresholds\n")
cat("  fig18_rsa_relaxed_vs_strict\n")
