# 07_random_effects_sensitivity.R
#
# Sensitivity analysis for the comprehension experiment using the same
# zero/one-inflated beta likelihood with a richer random-effects structure.
#
# Outputs:
#   data/fit_brms_goal_zoib_sensitivity.rds
#   data/fit_brms_adoption_zoib_sensitivity.rds
#   data/comprehension_zoib_sensitivity_fixef_comparison.csv
#   data/comprehension_zoib_sensitivity_predictions.csv
#   plots/fig6_zoib_sensitivity_coefficients.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(brms)
library(ggdist)
library(posterior)
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

crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = FALSE)
newdata <- make_prediction_grid(crit)

priors <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 1), class = "b"),
  prior(normal(-1.5, 1.5), class = "Intercept", dpar = "zoi"),
  prior(normal(0, 1.5), class = "Intercept", dpar = "coi"),
  prior(student_t(3, 0, 2.5), class = "Intercept", dpar = "phi"),
  prior(exponential(1), class = "sd"),
  prior(exponential(1), class = "sd", group = "submission_id"),
  prior(exponential(1), class = "sd", group = "topic")
)

fit_with_cache <- function(formula, data, path, seed) {
  if (file.exists(path)) {
    cached <- readRDS(path)
    cached_n <- tryCatch(nrow(cached$data), error = function(e) NA_integer_)
    current_n <- nrow(data)
    if (!is.na(cached_n) && cached_n == current_n) {
      message("Loading cached fit: ", path)
      return(cached)
    }
    message("Refitting because cached fit has n=", cached_n, " but current data has n=", current_n)
  }

  backend_name <- if (requireNamespace("cmdstanr", quietly = TRUE)) "cmdstanr" else "rstan"

  fit <- brm(
    formula = formula,
    data = data,
    family = zero_one_inflated_beta(link = "logit", link_zoi = "logit", link_coi = "logit"),
    prior = priors,
    backend = backend_name,
    chains = 4,
    cores = min(4, parallel::detectCores()),
    iter = 2500,
    warmup = 1000,
    seed = seed,
    refresh = 500,
    control = list(adapt_delta = 0.97, max_treedepth = 13)
  )
  saveRDS(fit, path)
  fit
}

formula_goal_main <- bf(
  inferred_goal_strength_prop ~ marker_strength_c * pc_prag_c + (1 | submission_id) + (1 | topic),
  phi ~ 1,
  zoi ~ 1,
  coi ~ 1
)
formula_goal_sens <- bf(
  inferred_goal_strength_prop ~ marker_strength_c * pc_prag_c + (1 + marker_strength_c + pc_prag_c || submission_id) + (1 | topic),
  phi ~ 1,
  zoi ~ 1,
  coi ~ 1
)
formula_adopt_main <- bf(
  adoption_likelihood_prop ~ marker_strength_c * pc_prag_c + (1 | submission_id) + (1 | topic),
  phi ~ 1,
  zoi ~ 1,
  coi ~ 1
)
formula_adopt_sens <- bf(
  adoption_likelihood_prop ~ marker_strength_c * pc_prag_c + (1 + marker_strength_c + pc_prag_c || submission_id) + (1 | topic),
  phi ~ 1,
  zoi ~ 1,
  coi ~ 1
)

fit_goal_main <- readRDS(file.path(DATA_DIR, "fit_brms_goal_zoib_full.rds"))
fit_adopt_main <- readRDS(file.path(DATA_DIR, "fit_brms_adoption_zoib_full.rds"))

fit_goal_sens <- fit_with_cache(
  formula_goal_sens,
  crit,
  file.path(DATA_DIR, "fit_brms_goal_zoib_sensitivity.rds"),
  seed = 777
)

fit_adopt_sens <- fit_with_cache(
  formula_adopt_sens,
  crit,
  file.path(DATA_DIR, "fit_brms_adoption_zoib_sensitivity.rds"),
  seed = 888
)

coef_terms <- c(
  b_marker_strength_c = "Marker strength",
  b_pc_prag_c = "Prag. controversy",
  `b_marker_strength_c:pc_prag_c` = "Marker × Prag. controversy"
)

collect_coef_draws <- function(fit, outcome_name, model_name) {
  draws <- as_draws_df(fit)
  bind_rows(lapply(names(coef_terms), function(term) {
    tibble(
      outcome = outcome_name,
      model = model_name,
      parameter = coef_terms[[term]],
      value = draws[[term]]
    )
  }))
}

coef_draws <- bind_rows(
  collect_coef_draws(fit_goal_main, "Inferred goal strength", "Main"),
  collect_coef_draws(fit_goal_sens, "Inferred goal strength", "Sensitivity"),
  collect_coef_draws(fit_adopt_main, "Adoption likelihood", "Main"),
  collect_coef_draws(fit_adopt_sens, "Adoption likelihood", "Sensitivity")
) |>
  mutate(
    parameter = factor(parameter,
                       levels = c("Marker strength", "Prag. controversy", "Marker × Prag. controversy")),
    model = factor(model, levels = c("Main", "Sensitivity"))
  )

coef_summary <- coef_draws |>
  dplyr::group_by(outcome, model, parameter) |>
  dplyr::summarise(
    mean = mean(value),
    lower = quantile(value, 0.025),
    upper = quantile(value, 0.975),
    .groups = "drop"
  )

write.csv(
  coef_summary,
  file.path(DATA_DIR, "comprehension_zoib_sensitivity_fixef_comparison.csv"),
  row.names = FALSE
)

predict_summary <- function(fit, outcome_name, model_name) {
  ep <- posterior_epred(fit, newdata = newdata, re_formula = NA)
  tibble(
    outcome = outcome_name,
    model = model_name,
    marker = newdata$marker,
    pc_prag = newdata$pc_prag,
    mean = colMeans(ep) * 100,
    lower = apply(ep, 2, quantile, probs = 0.025) * 100,
    upper = apply(ep, 2, quantile, probs = 0.975) * 100
  )
}

prediction_summary <- bind_rows(
  predict_summary(fit_goal_main, "Inferred goal strength", "Main"),
  predict_summary(fit_goal_sens, "Inferred goal strength", "Sensitivity"),
  predict_summary(fit_adopt_main, "Adoption likelihood", "Main"),
  predict_summary(fit_adopt_sens, "Adoption likelihood", "Sensitivity")
) |>
  mutate(
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high"))
  )

write.csv(
  prediction_summary,
  file.path(DATA_DIR, "comprehension_zoib_sensitivity_predictions.csv"),
  row.names = FALSE
)

p_coef <- ggplot(coef_draws, aes(x = value, y = parameter, fill = model)) +
  stat_halfeye(.width = c(0.8, 0.95), point_interval = mean_qi,
               position = position_dodge(width = 0.6), slab_alpha = 0.75) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  facet_wrap(~outcome, ncol = 1) +
  scale_fill_manual(values = c("Main" = CSP_colors[1], "Sensitivity" = CSP_colors[4])) +
  labs(x = "Coefficient on logit mean scale", y = NULL, fill = NULL) +
  theme_comp() +
  theme(legend.position = "top")

save_plot(p_coef, "fig6_zoib_sensitivity_coefficients", SCRIPT_DIR, width = 8.8, height = 6.1)

cat("Saved:\n")
cat("  data/fit_brms_goal_zoib_sensitivity.rds\n")
cat("  data/fit_brms_adoption_zoib_sensitivity.rds\n")
cat("  data/comprehension_zoib_sensitivity_fixef_comparison.csv\n")
cat("  data/comprehension_zoib_sensitivity_predictions.csv\n")
cat("  plots/fig6_zoib_sensitivity_coefficients\n")