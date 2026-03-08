# 05_bayesian_beta_models.R
#
# Confirmatory Bayesian zero/one-inflated beta models for the comprehension experiment.
#
# Outputs:
#   data/fit_brms_goal_zoib_full.rds
#   data/fit_brms_adoption_zoib_full.rds
#   data/brms_goal_zoib_fixef.csv
#   data/brms_adoption_zoib_fixef.csv
#   plots/fig4_zoib_model_coefficients.pdf/png

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

crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = TRUE)

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

formula_goal <- bf(
  inferred_goal_strength_prop ~ marker_strength_c * pc_prag_c + (1 | submission_id) + (1 | topic),
  phi ~ 1,
  zoi ~ 1,
  coi ~ 1
)
formula_adopt <- bf(
  adoption_likelihood_prop ~ marker_strength_c * pc_prag_c + (1 | submission_id) + (1 | topic),
  phi ~ 1,
  zoi ~ 1,
  coi ~ 1
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
    control = list(adapt_delta = 0.95, max_treedepth = 12)
  )
  saveRDS(fit, path)
  fit
}

fit_goal <- fit_with_cache(
  formula_goal,
  crit,
  file.path(DATA_DIR, "fit_brms_goal_zoib_full.rds"),
  seed = 321
)

fit_adopt <- fit_with_cache(
  formula_adopt,
  crit,
  file.path(DATA_DIR, "fit_brms_adoption_zoib_full.rds"),
  seed = 654
)

fixef_to_csv <- function(fit, outcome_name, out_path) {
  fx <- as.data.frame(fixef(fit, probs = c(0.025, 0.975))) |>
    tibble::rownames_to_column("term") |>
    mutate(outcome = outcome_name)
  write.csv(fx, out_path, row.names = FALSE)
  fx
}

goal_fixef <- fixef_to_csv(fit_goal, "Inferred goal strength",
                           file.path(DATA_DIR, "brms_goal_zoib_fixef.csv"))
adopt_fixef <- fixef_to_csv(fit_adopt, "Adoption likelihood",
                            file.path(DATA_DIR, "brms_adoption_zoib_fixef.csv"))

coef_terms <- c(
  b_marker_strength_c = "Marker strength",
  b_pc_prag_c = "Prag. controversy",
  `b_marker_strength_c:pc_prag_c` = "Marker × Prag. controversy"
)

coef_draws <- bind_rows(
  lapply(names(coef_terms), function(term) {
    tibble(
      outcome = "Inferred goal strength",
      parameter = coef_terms[[term]],
      value = as_draws_df(fit_goal)[[term]]
    )
  }),
  lapply(names(coef_terms), function(term) {
    tibble(
      outcome = "Adoption likelihood",
      parameter = coef_terms[[term]],
      value = as_draws_df(fit_adopt)[[term]]
    )
  })
) |>
  mutate(parameter = factor(parameter,
                            levels = c("Marker strength", "Prag. controversy", "Marker × Prag. controversy")))

p_coef <- ggplot(coef_draws, aes(x = value, y = parameter, fill = parameter)) +
  stat_halfeye(.width = c(0.8, 0.95), point_interval = mean_qi, normalize = "panels") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  facet_wrap(~outcome, ncol = 1) +
  scale_fill_manual(values = c(CSP_colors[1], CSP_colors[2], CSP_colors[4])) +
  labs(x = "Coefficient on logit mean scale", y = NULL) +
  theme_comp() +
  theme(legend.position = "none")

save_plot(p_coef, "fig4_zoib_model_coefficients", SCRIPT_DIR, width = 8.6, height = 5.8)

cat("Saved:\n")
cat("  data/fit_brms_goal_zoib_full.rds\n")
cat("  data/fit_brms_adoption_zoib_full.rds\n")
cat("  data/brms_goal_zoib_fixef.csv\n")
cat("  data/brms_adoption_zoib_fixef.csv\n")
cat("  plots/fig4_zoib_model_coefficients\n")
