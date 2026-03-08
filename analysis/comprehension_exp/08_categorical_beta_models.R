# 08_categorical_beta_models.R
#
# Improved confirmatory analysis: categorical marker coding + standard beta
# regression.  This addresses two limitations of the preregistered ordinal-
# linear ZOIB specification:
#
#   1. Marker strength is now a 3-level categorical factor (treatment-coded,
#      reference = "soviel ich weiß") rather than a linear numeric predictor.
#      This drops the equal-spacing assumption and yields direct pairwise
#      coefficients (ja vs soviel, bekanntlich vs soviel).
#
#   2. The likelihood is standard Beta (with logit link) instead of ZOIB.
#      Boundary responses (exact 0 or 100) are rare (~5%) and are squished
#      into (0, 1) via the established (x*(n-1)+0.5)/n transform.  This
#      removes 3 nuisance submodel parameters and tightens posteriors.
#
# The preregistered ZOIB + ordinal-linear model (05_bayesian_beta_models.R)
# is retained as the primary analysis; this script serves as an improved
# supplementary / sensitivity analysis.
#
# Outputs:
#   data/fit_brms_goal_cat_beta.rds
#   data/fit_brms_adoption_cat_beta.rds
#   data/brms_goal_cat_beta_fixef.csv
#   data/brms_adoption_cat_beta_fixef.csv
#   plots/fig8_cat_beta_coefficients.pdf/png

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

# ── Load and prepare data ───────────────────────────────────────────────
crit <- load_comprehension_analysis_data(SCRIPT_DIR, write_csv = FALSE)

# Treatment-coded categorical marker (reference = soviel ich weiß)
crit <- crit |>
  mutate(
    marker_cat = factor(as.character(marker), levels = MARKERS_ORDERED, ordered = FALSE),
    # Beta-squeezed responses for standard beta regression
    inferred_goal_strength_beta = make_beta_response(inferred_goal_strength, n()),
    adoption_likelihood_beta = make_beta_response(adoption_likelihood, n())
  )

# ── Priors ──────────────────────────────────────────────────────────────
priors_beta <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 1), class = "b"),
  prior(student_t(3, 0, 2.5), class = "Intercept", dpar = "phi"),
  prior(exponential(1), class = "sd")
)

# ── Formulas ────────────────────────────────────────────────────────────
formula_goal <- bf(
  inferred_goal_strength_beta ~ marker_cat * pc_prag_c + pc_prop_c + (1 | submission_id) + (1 | topic),
  phi ~ 1
)
formula_adopt <- bf(
  adoption_likelihood_beta ~ marker_cat * pc_prag_c + pc_prop_c + (1 | submission_id) + (1 | topic),
  phi ~ 1
)

# ── Fit helper ──────────────────────────────────────────────────────────
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
    family = Beta(link = "logit"),
    prior = priors_beta,
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

# ── Fit models ──────────────────────────────────────────────────────────
fit_goal <- fit_with_cache(
  formula_goal, crit,
  file.path(DATA_DIR, "fit_brms_goal_cat_beta.rds"),
  seed = 421
)

fit_adopt <- fit_with_cache(
  formula_adopt, crit,
  file.path(DATA_DIR, "fit_brms_adoption_cat_beta.rds"),
  seed = 754
)

# ── Extract fixed effects ───────────────────────────────────────────────
fixef_to_csv <- function(fit, outcome_name, out_path) {
  fx <- as.data.frame(fixef(fit, probs = c(0.025, 0.975))) |>
    tibble::rownames_to_column("term") |>
    mutate(outcome = outcome_name)
  write.csv(fx, out_path, row.names = FALSE)
  fx
}

goal_fixef <- fixef_to_csv(fit_goal, "Inferred goal strength",
                           file.path(DATA_DIR, "brms_goal_cat_beta_fixef.csv"))
adopt_fixef <- fixef_to_csv(fit_adopt, "Adoption likelihood",
                            file.path(DATA_DIR, "brms_adoption_cat_beta_fixef.csv"))

# ── Coefficient plot ────────────────────────────────────────────────────
coef_terms <- c(
  b_marker_catja = "ja vs soviel",
  b_marker_catbekanntlich = "bekanntlich vs soviel",
  b_pc_prag_c = "Prag. controversy",
  `b_marker_catja:pc_prag_c` = "ja × Prag. contr."
)

coef_draws <- bind_rows(
  lapply(names(coef_terms), function(term) {
    vals <- as_draws_df(fit_goal)[[term]]
    if (is.null(vals)) return(NULL)
    tibble(outcome = "Inferred goal strength",
           parameter = coef_terms[[term]], value = vals)
  }),
  lapply(names(coef_terms), function(term) {
    vals <- as_draws_df(fit_adopt)[[term]]
    if (is.null(vals)) return(NULL)
    tibble(outcome = "Adoption likelihood",
           parameter = coef_terms[[term]], value = vals)
  })
) |>
  mutate(parameter = factor(parameter, levels = rev(unname(coef_terms))))

p_coef <- ggplot(coef_draws, aes(x = value, y = parameter, fill = parameter)) +
  stat_halfeye(.width = c(0.8, 0.95), point_interval = mean_qi, normalize = "panels") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  facet_wrap(~outcome, ncol = 1) +
  scale_fill_manual(values = rep_len(CSP_colors, length(coef_terms))) +
  labs(x = "Coefficient (logit scale)", y = NULL) +
  theme_comp() +
  theme(legend.position = "none")

save_plot(p_coef, "fig8_cat_beta_coefficients", SCRIPT_DIR, width = 9, height = 6.5)

# ── Print summary ──────────────────────────────────────────────────────
cat("\n=== Inferred goal strength (categorical beta) ===\n")
print(goal_fixef)
cat("\n=== Adoption likelihood (categorical beta) ===\n")
print(adopt_fixef)

cat("\nSaved:\n")
cat("  data/fit_brms_goal_cat_beta.rds\n")
cat("  data/fit_brms_adoption_cat_beta.rds\n")
cat("  data/brms_goal_cat_beta_fixef.csv\n")
cat("  data/brms_adoption_cat_beta_fixef.csv\n")
cat("  plots/fig8_cat_beta_coefficients\n")
