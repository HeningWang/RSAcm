# 04_rsa_soft_thresholds.R
#
# Fit the cost-augmented noisy-threshold RSA model directly to production data
# and infer soft marker thresholds along the latent utility landscape.
#
# Outputs:
#   data/fit_rsa_soft_thresholds.rds
#   data/rsa_soft_threshold_summary.csv
#   plots/fig11_rsa_soft_thresholds.pdf/png
#   plots/fig12_rsa_utility_landscape.pdf/png
#   plots/fig13_rsa_observed_vs_predicted.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(aida)

PLOTS_DIR <- "plots"
DATA_DIR  <- "data"
dir.create(PLOTS_DIR, showWarnings = FALSE)
dir.create(DATA_DIR, showWarnings = FALSE)

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

marker_colors <- setNames(CSP_colors[seq_along(MARKERS_ORDERED)], MARKERS_ORDERED)

theme_set(theme_aida())
theme_model <- function() {
  theme_aida() +
    theme(
      axis.text.y  = element_text(size = 18),
      axis.text.x  = element_text(size = 18),
      axis.title.y = element_text(size = 20),
      axis.title.x = element_text(size = 20),
      legend.text  = element_text(size = 17),
      legend.title = element_text(size = 18)
    )
}

save_plot <- function(p, name, w = 8, h = 5) {
  ggsave(file.path(PLOTS_DIR, paste0(name, ".pdf")), p, width = w, height = h)
  ggsave(file.path(PLOTS_DIR, paste0(name, ".png")), p, width = w, height = h,
         dpi = 180)
  invisible(p)
}

as_logical_flag <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "t", "1")
}

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

fit_path <- file.path(DATA_DIR, "fit_rsa_soft_thresholds.rds")
summary_path <- file.path(DATA_DIR, "rsa_soft_threshold_summary.csv")
lambda_fixed <- 6

dat <- read.csv(file.path(DATA_DIR, "dummy_data.csv"), stringsAsFactors = FALSE) |>
  mutate(
    is_filler = as_logical_flag(is_filler),
    is_training = as_logical_flag(is_training)
  )

norming <- read.csv(file.path(DATA_DIR, "norming_means.csv"), stringsAsFactors = FALSE) |>
  mutate(
    consensus_prop = mean_pc_prop_rating / 100,
    pc_prop = 1 - consensus_prop
  )

crit <- dat |>
  filter(!is_filler, !is_training) |>
  left_join(norming |> select(topic, consensus_prop, pc_prop), by = "topic") |>
  mutate(
    y = match(selected_marker, MARKERS_ORDERED),
    pc_prag_high = ifelse(pc_prag == "high", 1, 0),
    g_high = ifelse(g == "high", 1, 0)
  )

stopifnot(!any(is.na(crit$y)))
stopifnot(!any(is.na(crit$pc_prop)))

decode_par <- function(par) {
  thr1 <- par[5]
  thr2 <- thr1 + exp(par[6])
  thr3 <- thr2 + exp(par[7])
  list(
    w_pc = exp(par[1]),
    w_g = exp(par[2]),
    w_int = exp(par[3]),
    pc_prag_low = plogis(par[4]),
    thr = c(thr1, thr2, thr3),
    sigma = exp(par[8]),
    costs = c(0, exp(par[9]), exp(par[10]))
  )
}

neg_log_lik <- function(par, data, lambda = lambda_fixed) {
  pars <- decode_par(par)

  pc_prag_val <- ifelse(data$pc_prag_high == 1, 1, pars$pc_prag_low)
  pc <- PC(data$pc_prop, pc_prag_val)
  util <- U(pc, data$g_high, pars$w_pc, pars$w_g, pars$w_int)

  probs <- choice_prob_matrix(
    util = util,
    thr = pars$thr,
    uthr = c(pars$thr[-1], Inf),
    sig = rep(pars$sigma, 3),
    usig = c(pars$sigma, pars$sigma, 0),
    lambda = lambda,
    costs = pars$costs
  )

  p_obs <- probs[cbind(seq_len(nrow(data)), data$y)]
  -sum(log(pmax(p_obs, 1e-12)))
}

neg_log_post <- function(par, data, lambda = lambda_fixed) {
  nll <- neg_log_lik(par, data = data, lambda = lambda)

  log_prior <-
    dnorm(par[1], log(1.2), 0.8, log = TRUE) +
    dnorm(par[2], log(1.0), 0.8, log = TRUE) +
    dnorm(par[3], log(0.8), 0.8, log = TRUE) +
    dnorm(par[4], qlogis(0.5), 1.0, log = TRUE) +
    dnorm(par[5], -0.9, 0.7, log = TRUE) +
    dnorm(par[6], log(0.9), 0.5, log = TRUE) +
    dnorm(par[7], log(0.8), 0.5, log = TRUE) +
    dnorm(par[8], log(0.18), 0.45, log = TRUE) +
    dnorm(par[9], log(0.4), 0.7, log = TRUE) +
    dnorm(par[10], log(0.6), 0.7, log = TRUE)

  nll - log_prior
}

fit_one_start <- function(par0, data) {
  tryCatch(
    optim(
      par = par0,
      fn = neg_log_post,
      data = data,
      method = "L-BFGS-B",
      hessian = TRUE,
      lower = c(log(0.1), log(0.1), log(0.01), qlogis(0.05), -3.0, log(0.15), log(0.15), log(0.03), log(0.01), log(0.01)),
      upper = c(log(8.0), log(8.0), log(8.0), qlogis(0.95),  1.0, log(3.0),  log(3.0),  log(0.7),  log(3.0),  log(3.0)),
      control = list(maxit = 5000, factr = 1e7)
    ),
    error = function(e) NULL
  )
}

set.seed(42)
base_start <- c(
  log(5.0),
  log(1.0),
  log(0.8),
  qlogis(0.45),
  -1.25,
  log(0.6),
  log(0.5),
  log(0.18),
  log(0.45),
  log(0.55)
)

starts <- c(
  list(base_start),
  replicate(19, base_start + rnorm(length(base_start), sd = 0.35), simplify = FALSE)
)

fits <- Filter(Negate(is.null), lapply(starts, fit_one_start, data = crit))
stopifnot(length(fits) > 0)

best_fit <- fits[[which.min(vapply(fits, `[[`, numeric(1), "value"))]]
best_par <- decode_par(best_fit$par)

vcov_ok <- FALSE
draws <- NULL
if (all(is.finite(best_fit$hessian))) {
  vcov_mat <- tryCatch(solve(best_fit$hessian), error = function(e) NULL)
  if (!is.null(vcov_mat) && all(is.finite(vcov_mat))) {
    eig <- eigen(vcov_mat, symmetric = TRUE, only.values = TRUE)$values
    if (all(eig > 0) && requireNamespace("MASS", quietly = TRUE)) {
      draws_raw <- MASS::mvrnorm(4000, mu = best_fit$par, Sigma = vcov_mat)
      draws <- as.data.frame(t(apply(draws_raw, 1, function(x) {
        p <- decode_par(x)
        c(
          w_pc = p$w_pc,
          w_g = p$w_g,
          w_int = p$w_int,
          pc_prag_low = p$pc_prag_low,
          threshold_soviel = p$thr[1],
          threshold_ja = p$thr[2],
          threshold_bekanntlich = p$thr[3],
          sigma = p$sigma,
          cost_ja = p$costs[2],
          cost_bekanntlich = p$costs[3]
        )
      })))
      vcov_ok <- TRUE
    }
  }
}

summary_tbl <- tibble(
  parameter = c(
    "w_pc", "w_g", "w_int", "pc_prag_low",
    "threshold_soviel", "threshold_ja", "threshold_bekanntlich",
    "sigma", "cost_ja", "cost_bekanntlich"
  ),
  estimate = c(
    best_par$w_pc,
    best_par$w_g,
    best_par$w_int,
    best_par$pc_prag_low,
    best_par$thr[1],
    best_par$thr[2],
    best_par$thr[3],
    best_par$sigma,
    best_par$costs[2],
    best_par$costs[3]
  )
)

if (vcov_ok) {
  summary_tbl <- summary_tbl |>
    mutate(
      conf.low = vapply(parameter, function(p) quantile(draws[[p]], 0.025), numeric(1)),
      conf.high = vapply(parameter, function(p) quantile(draws[[p]], 0.975), numeric(1))
    )
} else {
  summary_tbl <- summary_tbl |>
    mutate(conf.low = NA_real_, conf.high = NA_real_)
}

write.csv(summary_tbl, summary_path, row.names = FALSE)

pc_prag_val_obs <- ifelse(crit$pc_prag_high == 1, 1, best_par$pc_prag_low)
pc_obs <- PC(crit$pc_prop, pc_prag_val_obs)
util_obs <- U(pc_obs, crit$g_high, best_par$w_pc, best_par$w_g, best_par$w_int)
pred_obs <- choice_prob_matrix(
  util = util_obs,
  thr = best_par$thr,
  uthr = c(best_par$thr[-1], Inf),
  sig = rep(best_par$sigma, 3),
  usig = c(best_par$sigma, best_par$sigma, 0),
  lambda = lambda_fixed,
  costs = best_par$costs
)

saveRDS(
  list(
    fit = best_fit,
    transformed = best_par,
    lambda = lambda_fixed,
    summary = summary_tbl,
    observed_utility = util_obs
  ),
  fit_path
)

cat("\n=== RSA soft-threshold fit ===\n")
cat("Converged:", best_fit$convergence == 0, "\n")
cat("Neg. log-posterior:", round(best_fit$value, 3), "\n")
print(summary_tbl)

# ── Figure 11: marker probabilities along utility axis ───────────────────────
util_grid <- seq(min(util_obs) - 0.4, max(util_obs) + 0.4, length.out = 500)
prob_grid <- choice_prob_matrix(
  util = util_grid,
  thr = best_par$thr,
  uthr = c(best_par$thr[-1], Inf),
  sig = rep(best_par$sigma, 3),
  usig = c(best_par$sigma, best_par$sigma, 0),
  lambda = lambda_fixed,
  costs = best_par$costs
)

plot_df <- tibble(
  utility = rep(util_grid, times = 3),
  marker = factor(rep(MARKERS_ORDERED, each = length(util_grid)), levels = MARKERS_ORDERED),
  prob = c(prob_grid[, 1], prob_grid[, 2], prob_grid[, 3])
)

thr_band_df <- tibble(
  marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED),
  xmin = best_par$thr - best_par$sigma,
  xmax = best_par$thr + best_par$sigma,
  x = best_par$thr,
  ymin = 0,
  ymax = 1
)

# Build overlap bands: where two or more sigma-bands intersect, draw a darker fill
overlap_pairs <- list()
for (i in seq_len(nrow(thr_band_df) - 1)) {
  for (j in (i + 1):nrow(thr_band_df)) {
    ol_min <- max(thr_band_df$xmin[i], thr_band_df$xmin[j])
    ol_max <- min(thr_band_df$xmax[i], thr_band_df$xmax[j])
    if (ol_min < ol_max) {
      overlap_pairs[[length(overlap_pairs) + 1]] <- tibble(
        xmin = ol_min, xmax = ol_max, ymin = 0, ymax = 1,
        label = paste(thr_band_df$marker[i], "&", thr_band_df$marker[j])
      )
    }
  }
}
overlap_df <- bind_rows(overlap_pairs)

p11 <- ggplot(plot_df, aes(x = utility, y = prob, colour = marker)) +
  geom_rect(data = thr_band_df,
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = marker),
            inherit.aes = FALSE, alpha = 0.15, colour = NA) +
  {if (nrow(overlap_df) > 0)
    geom_rect(data = overlap_df,
              aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
              inherit.aes = FALSE, fill = "grey50", alpha = 0.18, colour = NA)} +
  geom_vline(data = thr_band_df, aes(xintercept = x, colour = marker),
             linetype = "dashed", linewidth = 0.8, show.legend = FALSE) +
  geom_line(linewidth = 1.15) +
  scale_colour_manual(values = marker_colors, name = "Marker") +
  scale_fill_manual(values = marker_colors, guide = "none") +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    x = "Latent utility U(pc, g)",
    y = "Predicted marker probability"
  ) +
  theme_model() +
  theme(legend.position = "top")

save_plot(p11, "fig11_rsa_soft_thresholds", w = 9, h = 5)

# ── Figure 12: marker probability landscape with noisy thresholds ─────────────
# Compute predicted P(marker | pc, g) across the (pc, g) space to directly
# visualise how the noisy thresholds partition the landscape.

n_grid <- 200
grid12 <- expand.grid(
  pc = seq(0, 0.5, length.out = n_grid),
  g = seq(0, 1, length.out = n_grid)
)
grid12$utility <- U(grid12$pc, grid12$g, best_par$w_pc, best_par$w_g, best_par$w_int)

prob_grid12 <- choice_prob_matrix(
  util = grid12$utility,
  thr = best_par$thr,
  uthr = c(best_par$thr[-1], Inf),
  sig = rep(best_par$sigma, 3),
  usig = c(best_par$sigma, best_par$sigma, 0),
  lambda = lambda_fixed,
  costs = best_par$costs
)

grid12_long <- bind_rows(lapply(seq_along(MARKERS_ORDERED), function(i) {
  grid12 |>
    mutate(
      marker = factor(MARKERS_ORDERED[i], levels = MARKERS_ORDERED),
      prob = prob_grid12[, i]
    )
}))

# Threshold contour lines in (pc, g) space
pc_seq <- seq(0, 0.5, length.out = 600)
denom <- best_par$w_g - best_par$w_int * pc_seq

thresh_list <- lapply(seq_along(best_par$thr), function(i) {
  mu <- best_par$thr[i]
  s <- best_par$sigma
  g_mean <- (mu + best_par$w_pc * pc_seq) / denom
  g_lo <- (mu - s + best_par$w_pc * pc_seq) / denom
  g_hi <- (mu + s + best_par$w_pc * pc_seq) / denom
  ok_mean <- denom > 0.01 & g_mean >= 0 & g_mean <= 1
  ok_band <- denom > 0.01 & !(g_lo > 1 | g_hi < 0)
  list(
    mean = if (sum(ok_mean) >= 2) {
      data.frame(pc = pc_seq[ok_mean], g = g_mean[ok_mean], marker = MARKERS_ORDERED[i])
    } else NULL,
    band = if (sum(ok_band) >= 2) {
      data.frame(
        pc = pc_seq[ok_band],
        g_lo = pmax(0, g_lo[ok_band]),
        g_hi = pmin(1, g_hi[ok_band]),
        marker = MARKERS_ORDERED[i]
      )
    } else NULL
  )
})

thresh_df <- bind_rows(lapply(thresh_list, `[[`, "mean"))
if (nrow(thresh_df) > 0) {
  thresh_df <- thresh_df |>
    mutate(marker = factor(marker, levels = MARKERS_ORDERED))
}

band_df <- bind_rows(lapply(thresh_list, `[[`, "band"))
if (nrow(band_df) > 0) {
  band_df <- band_df |>
    mutate(marker = factor(marker, levels = MARKERS_ORDERED))
}

# Replicate threshold/band data across all facets so contours appear in every panel
thresh_all <- bind_rows(lapply(MARKERS_ORDERED, function(m) {
  thresh_df |> mutate(facet_marker = factor(m, levels = MARKERS_ORDERED))
}))
band_all <- bind_rows(lapply(MARKERS_ORDERED, function(m) {
  band_df |> mutate(facet_marker = factor(m, levels = MARKERS_ORDERED))
}))

# Also compute equal-probability contours (where P = 0.5) per marker
contour_df <- grid12_long |>
  group_by(marker) |>
  mutate(above = prob >= 0.5) |>
  ungroup()

p12 <- ggplot(grid12_long, aes(x = pc, y = g)) +
  geom_raster(aes(fill = prob)) +
  geom_contour(aes(z = prob), breaks = c(0.25, 0.5), colour = "grey30",
               linewidth = 0.45, linetype = "dashed") +
  {if (nrow(band_all) > 0)
    geom_ribbon(data = band_all,
                aes(x = pc, ymin = g_lo, ymax = g_hi, group = marker),
                inherit.aes = FALSE, fill = "white", alpha = 0.35)} +
  {if (nrow(thresh_all) > 0)
    geom_line(data = thresh_all,
              aes(x = pc, y = g, group = marker),
              inherit.aes = FALSE, colour = "white", linewidth = 1.1)} +
  facet_wrap(~ marker, nrow = 1) +
  scale_fill_viridis_c(
    option = "inferno", direction = 1,
    limits = c(0, 1),
    labels = scales::percent_format(),
    name = "P(marker)"
  ) +
  coord_cartesian(xlim = c(0, 0.5), ylim = c(0, 1)) +
  labs(
    x = "Overall perceived controversy (pc)",
    y = "Speaker goal strength (g)"
  ) +
  theme_model() +
  theme(
    legend.position = "right",
    strip.text = element_text(size = 13, face = "bold"),
    panel.spacing = unit(0.8, "lines")
  )

save_plot(p12, "fig12_rsa_utility_landscape", w = 12, h = 4.5)

# ── Figure 13: observed vs predicted by condition and marker ─────────────────
colnames(pred_obs) <- MARKERS_ORDERED

pred_long <- as_tibble(pred_obs, .name_repair = "minimal") |>
  mutate(
    pc_prag = crit$pc_prag,
    g = crit$g
  ) |>
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
    series = factor(series, levels = c("obs", "pred"), labels = c("Observed", "Predicted")),
    condition = paste0("pc_prag:", pc_prag, "\n", "g:", g)
  )

p13 <- ggplot(compare_df, aes(x = condition, y = prop, fill = marker)) +
  geom_col(position = position_dodge2(width = 0.75, preserve = "single"), width = 0.65) +
  facet_wrap(~series, nrow = 1) +
  scale_fill_manual(values = marker_colors, name = "Marker") +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Observed vs. RSA-predicted marker proportions",
    subtitle = "Aggregated over critical trials within each experimental condition",
    x = "Condition",
    y = "Proportion"
  ) +
  theme_model() +
  theme(legend.position = "top")

save_plot(p13, "fig13_rsa_observed_vs_predicted", w = 10, h = 5.5)

cat("\nFigures saved:\n")
cat("  fig11_rsa_soft_thresholds      — marker probabilities along utility axis\n")
cat("  fig12_rsa_utility_landscape   — inferred soft thresholds on utility landscape\n")
cat("  fig13_rsa_observed_vs_predicted — observed vs predicted condition means\n")
