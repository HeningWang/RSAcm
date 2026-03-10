# 07_rsa_listener_fit.R
#
# Exploratory RSA listener analysis for the comprehension experiment.
#
# Uses the production-fitted RSA speaker parameters to infer expected speaker
# goal strength E[g | marker, pc] for each comprehension cell, then fits the
# preregistered listener adoption link:
#
#   logit(P_adopt) = eta_0 + eta_g * E[g|u,pc] - eta_pc * pc - eta_int * E[g|u,pc] * pc
#
# Outputs:
#   data/comprehension_rsa_listener_cell_predictions.csv
#   data/comprehension_rsa_listener_condition_summary.csv
#   data/comprehension_rsa_enhanced_summary.csv
#   data/comprehension_rsa_goal_calibration_summary.csv
#   data/comprehension_rsa_listener_parameter_summary.csv
#   data/fit_rsa_listener.rds
#   plots/fig6_rsa_listener_predictions.pdf/png
#   plots/fig7_rsa_base_vs_enhanced.pdf/png

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
      axis.text.y  = element_text(size = 18),
      axis.text.x  = element_text(size = 18),
      axis.title.y = element_text(size = 20),
      axis.title.x = element_text(size = 20),
      strip.text   = element_text(size = 17, face = "bold"),
      legend.text  = element_text(size = 17),
      legend.title = element_text(size = 18)
    )
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

logistic <- function(x) 1 / (1 + exp(-x))
logit <- function(p) qlogis(pmin(pmax(p, 1e-6), 1 - 1e-6))

crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = TRUE)

prod_fit_path <- file.path(SCRIPT_DIR, "../production_exp/data/fit_rsa_soft_thresholds.rds")
stopifnot(file.exists(prod_fit_path))
prod_fit <- readRDS(prod_fit_path)
prod_par <- prod_fit$transformed
lambda_fixed <- prod_fit$lambda

grid_g <- seq(0, 1, length.out = 401)

cell_means <- crit |>
  group_by(topic, item_id, condition_index, pc_prag, g_implied, marker, mean_pc_prop_rating) |>
  summarise(
    n = n(),
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
  probs <- choice_prob_matrix(
    util = util,
    thr = pars$thr,
    uthr = c(pars$thr[-1], Inf),
    sig = rep(pars$sigma, 3),
    usig = c(pars$sigma, pars$sigma, 0),
    lambda = lambda,
    costs = pars$costs
  )
  like <- probs[, marker_index]
  post <- like / sum(like)
  sum(grid_g * post)
}

cell_means <- cell_means |>
  rowwise() |>
  mutate(
    rsa_goal_mean = compute_goal_posterior_mean(marker_index, pc, prod_par, lambda_fixed),
    rsa_goal_rating = 100 * rsa_goal_mean,
    adoption_obs = mean_adoption / 100
  ) |>
  ungroup()

neg_sse <- function(par, dat) {
  eta0 <- par[1]
  etag <- par[2]
  etapc <- par[3]
  etaint <- par[4]

  pred <- logistic(eta0 + etag * dat$rsa_goal_mean - etapc * dat$pc - etaint * dat$rsa_goal_mean * dat$pc)
  sum(dat$n * (dat$adoption_obs - pred)^2)
}

fit0 <- optim(
  par = c(0, 1, 1, 0),
  fn = neg_sse,
  dat = cell_means,
  method = "BFGS",
  hessian = TRUE,
  control = list(maxit = 5000, reltol = 1e-10)
)

eta_hat <- setNames(fit0$par, c("eta_0", "eta_g", "eta_pc", "eta_int"))
cell_means <- cell_means |>
  mutate(
    rsa_adoption_pred = 100 * logistic(
      eta_hat["eta_0"] +
        eta_hat["eta_g"] * rsa_goal_mean -
        eta_hat["eta_pc"] * pc -
        eta_hat["eta_int"] * rsa_goal_mean * pc
    ),
    goal_residual = mean_goal - rsa_goal_rating,
    adoption_residual = mean_adoption - rsa_adoption_pred
  )

goal_observation_model <- lm(mean_goal ~ rsa_goal_rating, data = cell_means, weights = n)
goal_observation_coef <- stats::coef(goal_observation_model)
goal_observation_ci <- suppressMessages(confint(goal_observation_model))

cell_means <- cell_means |>
  mutate(
    rsa_goal_rating_calibrated = goal_observation_coef[[1]] + goal_observation_coef[[2]] * rsa_goal_rating,
    goal_residual_calibrated = mean_goal - rsa_goal_rating_calibrated
  )

goal_calibration_summary <- tibble(
  parameter = c(
    "alpha",
    "beta",
    "alpha_conf.low",
    "alpha_conf.high",
    "beta_conf.low",
    "beta_conf.high",
    "r_squared",
    "rmse_raw",
    "rmse_calibrated",
    "weighted_cor_raw",
    "weighted_cor_calibrated"
  ),
  estimate = c(
    unname(goal_observation_coef[[1]]),
    unname(goal_observation_coef[[2]]),
    unname(goal_observation_ci["(Intercept)", 1]),
    unname(goal_observation_ci["(Intercept)", 2]),
    unname(goal_observation_ci["rsa_goal_rating", 1]),
    unname(goal_observation_ci["rsa_goal_rating", 2]),
    summary(goal_observation_model)$r.squared,
    sqrt(weighted.mean(cell_means$goal_residual^2, cell_means$n)),
    sqrt(weighted.mean(cell_means$goal_residual_calibrated^2, cell_means$n)),
    stats::cov.wt(cbind(cell_means$mean_goal, cell_means$rsa_goal_rating), wt = cell_means$n, cor = TRUE)$cor[1, 2],
    stats::cov.wt(cbind(cell_means$mean_goal, cell_means$rsa_goal_rating_calibrated), wt = cell_means$n, cor = TRUE)$cor[1, 2]
  )
)

rmse_weighted <- function(obs, pred, w) {
  sqrt(weighted.mean((obs - pred)^2, w))
}

compute_enhanced_cells <- function(k_pc_prop, dat = cell_means) {
  dat |>
    rowwise() |>
    mutate(
      pc_prop_enhanced = pmin(pmax(k_pc_prop * .data$pc_prop, 0), 1),
      pc_enhanced = PC(.data$pc_prop_enhanced, .data$pc_prag_val),
      rsa_goal_mean_enhanced = compute_goal_posterior_mean(.data$marker_index, .data$pc_enhanced, prod_par, lambda_fixed),
      rsa_goal_rating_enhanced = 100 * .data$rsa_goal_mean_enhanced,
      ja_marker = as.integer(.data$marker == "ja"),
      bekannt_marker = as.integer(.data$marker == "bekanntlich")
    ) |>
    ungroup()
}

fit_enhanced_models <- function(k_pc_prop) {
  dat <- compute_enhanced_cells(k_pc_prop)

  goal_fit <- lm(mean_goal ~ rsa_goal_rating_enhanced + ja_marker + bekannt_marker,
                 data = dat,
                 weights = n)
  dat$goal_hat_enhanced <- predict(goal_fit)

  adoption_objective <- function(par, d) {
    pred <- logistic(
      par[1] +
        par[2] * d$rsa_goal_mean_enhanced -
        par[3] * d$pc_enhanced -
        par[4] * d$rsa_goal_mean_enhanced * d$pc_enhanced +
        par[5] * d$ja_marker +
        par[6] * d$bekannt_marker
    )
    sum(d$n * (d$mean_adoption / 100 - pred)^2)
  }

  adoption_fit <- optim(
    par = c(0, 1, 1, 0, 0, 0),
    fn = adoption_objective,
    d = dat,
    method = "BFGS",
    control = list(maxit = 5000, reltol = 1e-10)
  )

  dat$rsa_adoption_pred_enhanced <- 100 * logistic(
    adoption_fit$par[1] +
      adoption_fit$par[2] * dat$rsa_goal_mean_enhanced -
      adoption_fit$par[3] * dat$pc_enhanced -
      adoption_fit$par[4] * dat$rsa_goal_mean_enhanced * dat$pc_enhanced +
      adoption_fit$par[5] * dat$ja_marker +
      adoption_fit$par[6] * dat$bekannt_marker
  )

  list(dat = dat, goal_fit = goal_fit, adoption_fit = adoption_fit)
}

enhanced_objective <- function(log_k_pc_prop) {
  k_pc_prop <- exp(log_k_pc_prop)
  enhanced <- fit_enhanced_models(k_pc_prop)
  dat <- enhanced$dat

  sum(dat$n * (dat$mean_goal - dat$goal_hat_enhanced)^2) +
    sum(dat$n * (dat$mean_adoption - dat$rsa_adoption_pred_enhanced)^2)
}

enhanced_opt <- optim(0, enhanced_objective, method = "BFGS")
enhanced_k_pc_prop <- exp(enhanced_opt$par[[1]])
enhanced_fit <- fit_enhanced_models(enhanced_k_pc_prop)

cell_means <- cell_means |>
  left_join(
    enhanced_fit$dat |>
      select(topic, item_id, condition_index,
             pc_prop_enhanced, pc_enhanced,
             rsa_goal_mean_enhanced, rsa_goal_rating_enhanced,
             goal_hat_enhanced, rsa_adoption_pred_enhanced),
    by = c("topic", "item_id", "condition_index")
  )

enhanced_summary <- tibble(
  parameter = c(
    "k_pc_prop",
    "goal_intercept",
    "goal_rsa_slope",
    "goal_ja_offset",
    "goal_bekanntlich_offset",
    "adoption_eta0",
    "adoption_eta_g",
    "adoption_eta_pc",
    "adoption_eta_int",
    "adoption_ja_offset",
    "adoption_bekanntlich_offset",
    "goal_rmse_base",
    "goal_rmse_enhanced",
    "adoption_rmse_base",
    "adoption_rmse_enhanced"
  ),
  estimate = c(
    enhanced_k_pc_prop,
    coef(enhanced_fit$goal_fit)[[1]],
    coef(enhanced_fit$goal_fit)[[2]],
    coef(enhanced_fit$goal_fit)[[3]],
    coef(enhanced_fit$goal_fit)[[4]],
    enhanced_fit$adoption_fit$par[[1]],
    enhanced_fit$adoption_fit$par[[2]],
    enhanced_fit$adoption_fit$par[[3]],
    enhanced_fit$adoption_fit$par[[4]],
    enhanced_fit$adoption_fit$par[[5]],
    enhanced_fit$adoption_fit$par[[6]],
    rmse_weighted(cell_means$mean_goal, cell_means$rsa_goal_rating_calibrated, cell_means$n),
    rmse_weighted(cell_means$mean_goal, cell_means$goal_hat_enhanced, cell_means$n),
    rmse_weighted(cell_means$mean_adoption, cell_means$rsa_adoption_pred, cell_means$n),
    rmse_weighted(cell_means$mean_adoption, cell_means$rsa_adoption_pred_enhanced, cell_means$n)
  )
)

param_summary <- tibble(
  parameter = names(eta_hat),
  estimate = as.numeric(eta_hat)
)

vcov_ok <- FALSE
if (all(is.finite(fit0$hessian))) {
  vcov_mat <- tryCatch(solve(fit0$hessian), error = function(e) NULL)
  if (!is.null(vcov_mat) && all(is.finite(vcov_mat))) {
    eig <- eigen(vcov_mat, symmetric = TRUE, only.values = TRUE)$values
    if (all(eig > 0) && requireNamespace("MASS", quietly = TRUE)) {
      draws <- MASS::mvrnorm(4000, mu = fit0$par, Sigma = vcov_mat)
      param_summary <- param_summary |>
        mutate(
          conf.low = apply(draws, 2, quantile, probs = 0.025),
          conf.high = apply(draws, 2, quantile, probs = 0.975)
        )
      vcov_ok <- TRUE
    }
  }
}
if (!vcov_ok) {
  param_summary <- param_summary |>
    mutate(conf.low = NA_real_, conf.high = NA_real_)
}

condition_summary <- cell_means |>
  group_by(pc_prag, marker) |>
  summarise(
    mean_goal_obs = mean(mean_goal),
    mean_goal_rsa = mean(rsa_goal_rating),
    mean_goal_rsa_enhanced = mean(goal_hat_enhanced),
    mean_adoption_obs = mean(mean_adoption),
    mean_adoption_rsa = mean(rsa_adoption_pred),
    mean_adoption_rsa_enhanced = mean(rsa_adoption_pred_enhanced),
    .groups = "drop"
  )

write.csv(cell_means,
          file.path(DATA_DIR, "comprehension_rsa_listener_cell_predictions.csv"),
          row.names = FALSE)
write.csv(condition_summary,
          file.path(DATA_DIR, "comprehension_rsa_listener_condition_summary.csv"),
          row.names = FALSE)
write.csv(enhanced_summary,
          file.path(DATA_DIR, "comprehension_rsa_enhanced_summary.csv"),
          row.names = FALSE)
write.csv(goal_calibration_summary,
          file.path(DATA_DIR, "comprehension_rsa_goal_calibration_summary.csv"),
          row.names = FALSE)
write.csv(param_summary,
          file.path(DATA_DIR, "comprehension_rsa_listener_parameter_summary.csv"),
          row.names = FALSE)

saveRDS(
  list(
    production_parameters = prod_par,
    lambda = lambda_fixed,
    listener_fit = fit0,
    goal_calibration = goal_observation_model,
    goal_observation_model = goal_observation_model,
    goal_calibration_summary = goal_calibration_summary,
    enhanced_k_pc_prop = enhanced_k_pc_prop,
    enhanced_fit = enhanced_fit,
    enhanced_summary = enhanced_summary,
    listener_parameters = eta_hat,
    cell_predictions = cell_means,
    parameter_summary = param_summary
  ),
  file.path(DATA_DIR, "fit_rsa_listener.rds")
)

summarise_with_uncertainty <- function(data, n_boot = 2000) {
  x <- data$value
  w <- data$n

  est <- weighted.mean(x, w)

  if (length(x) <= 1 || all(w == 0) || all(is.na(x))) {
    return(tibble(value = est, lower = est, upper = est))
  }

  boot <- replicate(n_boot, {
    idx <- sample.int(length(x), size = length(x), replace = TRUE)
    weighted.mean(x[idx], w[idx])
  })

  tibble(
    value = est,
    lower = quantile(boot, 0.025, na.rm = TRUE),
    upper = quantile(boot, 0.975, na.rm = TRUE)
  )
}

plot_long <- bind_rows(
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Goal strength",
              series = "Observed",
              value = mean_goal),
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Goal strength",
              series = "RSA",
              value = goal_hat_enhanced),
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Adoption",
              series = "Observed",
              value = mean_adoption),
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Adoption",
              series = "RSA",
              value = rsa_adoption_pred_enhanced)
) |>
  group_by(pc_prag, marker, outcome, series) |>
  group_modify(~ summarise_with_uncertainty(.x)) |>
  ungroup() |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high")),
    series = factor(series, levels = c("Observed", "RSA"))
  )

p <- ggplot(plot_long,
            aes(x = marker, y = value, colour = series, shape = series, group = series)) +
  geom_errorbar(aes(ymin = lower, ymax = upper),
                width = 0.08,
                linewidth = 0.7,
                position = position_dodge(width = 0.15)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.15)) +
  geom_line(position = position_dodge(width = 0.15), linewidth = 0.75) +
  facet_grid(outcome ~ pc_prag) +
  scale_colour_manual(values = c("Observed" = CSP_colors[1], "RSA" = CSP_colors[2])) +
  scale_shape_manual(values = c("Observed" = 16, "RSA" = 18)) +
  labs(x = NULL, y = "Mean rating", colour = NULL, shape = NULL) +
  theme_comp() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(angle = 18, hjust = 1),
    panel.grid.major.x = element_blank()
  )

plot_compare <- bind_rows(
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Goal strength",
              series = "Observed",
              value = mean_goal),
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Goal strength",
              series = "Model",
              value = goal_hat_enhanced),
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Adoption",
              series = "Observed",
              value = mean_adoption),
  cell_means |>
    transmute(topic, pc_prag, marker, n,
              outcome = "Adoption",
              series = "Model",
              value = rsa_adoption_pred_enhanced)
) |>
  group_by(pc_prag, marker, outcome, series) |>
  group_modify(~ summarise_with_uncertainty(.x)) |>
  ungroup() |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high")),
    series = factor(series, levels = c("Observed", "Model"))
  )

# --- fig7 version A: original facet_grid(outcome ~ pc_prag) ---
p_compare <- ggplot(plot_compare,
                    aes(x = marker, y = value, colour = series, shape = series, group = series)) +
  geom_errorbar(aes(ymin = lower, ymax = upper),
                width = 0.08,
                linewidth = 0.7,
                position = position_dodge(width = 0.18)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.18)) +
  geom_line(position = position_dodge(width = 0.18), linewidth = 0.75) +
  facet_grid(outcome ~ pc_prag) +
  scale_colour_manual(values = c("Observed" = CSP_colors[1], "Model" = CSP_colors[2])) +
  scale_shape_manual(values = c("Observed" = 16, "Model" = 17)) +
  labs(x = NULL, y = "Mean rating", colour = NULL, shape = NULL) +
  theme_comp() +
  theme(
    legend.position = "top",
    axis.text.x = element_text(angle = 18, hjust = 1),
    panel.grid.major.x = element_blank()
  )

# --- fig7 version B: rows = outcome, cols = series (Observed/Model) ---
# Controversy encoded by color; only 2 lines per panel for clarity
plot_compare_b <- plot_compare |>
  mutate(
    pc_label = factor(pc_prag,
                      levels = c("Prag. Controversy: low", "Prag. Controversy: high"),
                      labels = c("low", "high"))
  )

p_compare_b <- ggplot(plot_compare_b,
                      aes(x = marker, y = value,
                          colour = pc_label, group = pc_label)) +
  geom_errorbar(aes(ymin = lower, ymax = upper),
                width = 0.1,
                linewidth = 0.6,
                position = position_dodge(width = 0.2)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.2)) +
  geom_line(linewidth = 0.8, position = position_dodge(width = 0.2)) +
  facet_grid(outcome ~ series, scales = "free_y") +
  scale_colour_manual(values = c("low" = CSP_colors[1], "high" = CSP_colors[3]),
                      name = "Prag. controversy") +
  labs(x = NULL, y = "Mean rating") +
  theme_comp() +
  theme(
    legend.position = "top",
    legend.key.width = unit(1.2, "cm"),
    axis.text.x = element_text(size = 12, angle = 18, hjust = 1),
    panel.grid.major.x = element_blank(),
    strip.text = element_text(size = 12.5, face = "bold")
  )

save_plot(p, "fig6_rsa_listener_predictions", SCRIPT_DIR, width = 9.8, height = 6)
save_plot(p_compare, "fig7_rsa_base_vs_enhanced", SCRIPT_DIR, width = 10.4, height = 6.2)
save_plot(p_compare_b, "fig7b_rsa_overlay", SCRIPT_DIR, width = 9, height = 6.5)

cat("Saved:\n")
cat("  data/comprehension_rsa_listener_cell_predictions.csv\n")
cat("  data/comprehension_rsa_listener_condition_summary.csv\n")
cat("  data/comprehension_rsa_enhanced_summary.csv\n")
cat("  data/comprehension_rsa_goal_calibration_summary.csv\n")
cat("  data/comprehension_rsa_listener_parameter_summary.csv\n")
cat("  data/fit_rsa_listener.rds\n")
cat("  plots/fig6_rsa_listener_predictions\n")
cat("  plots/fig7_rsa_base_vs_enhanced\n")
