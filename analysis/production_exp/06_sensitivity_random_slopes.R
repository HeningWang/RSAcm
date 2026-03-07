# 06_sensitivity_random_slopes.R
#
# Sensitivity analysis for the production experiment:
# cumulative-probit model with topic random intercepts and
# by-participant random slopes for the within-participant manipulations.
#
# Model:
#   marker ~ pc_prop_c * pc_prag_c * g_c +
#            (1 + pc_prag_c + g_c | submission_id) +
#            (1 | topic)
#
# Outputs:
#   data/fit_brms_sensitivity_topic_slopes.rds
#   data/brms_sensitivity_summary.csv

library(dplyr)
library(brms)
library(posterior)

n_cores <- suppressWarnings(parallel::detectCores())
if (!is.finite(n_cores) || is.na(n_cores) || n_cores < 1) n_cores <- 1L
n_cores <- as.integer(n_cores)

options(mc.cores = n_cores, brms.backend = "cmdstanr")

DATA_DIR <- "data"
dir.create(DATA_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c(
  "soviel ich weiß",
  "ja",
  "bekanntlich"
)

as_logical_flag <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "t", "1")
}

dat <- read.csv(file.path(DATA_DIR, "dummy_data.csv"), stringsAsFactors = FALSE) |>
  mutate(
    is_filler = as_logical_flag(is_filler),
    is_training = as_logical_flag(is_training)
  )

norming <- read.csv(file.path(DATA_DIR, "norming_means.csv"), stringsAsFactors = FALSE) |>
  mutate(pc_prop_c = as.numeric(scale(-mean_pc_prop_rating)))

crit <- dat |>
  filter(!is_filler, !is_training) |>
  left_join(norming |> select(topic, pc_prop_c), by = "topic") |>
  mutate(
    marker = ordered(selected_marker, levels = MARKERS_ORDERED),
    submission_id = factor(submission_id),
    topic = factor(topic),
    pc_prag = factor(pc_prag, levels = c("low", "high")),
    g = factor(g, levels = c("low", "high")),
    pc_prag_c = ifelse(pc_prag == "high", 0.5, -0.5),
    g_c = ifelse(g == "high", 0.5, -0.5)
  )

shared_priors <- c(
  prior(normal(0, 1.5), class = b),
  prior(normal(0, 1.5), class = Intercept),
  prior(exponential(1), class = sd),
  prior(lkj(2), class = cor)
)

path_sens <- file.path(DATA_DIR, "fit_brms_sensitivity_topic_slopes.rds")

if (file.exists(path_sens)) {
  message("Loading cached sensitivity model from ", path_sens)
  fit_sens <- readRDS(path_sens)
} else {
  message("Fitting sensitivity model with topic intercepts and participant slopes …")
  fit_sens <- brm(
    formula = marker ~ pc_prop_c * pc_prag_c * g_c +
      (1 + pc_prag_c + g_c | submission_id) +
      (1 | topic),
    family = cumulative("probit"),
    data = crit,
    prior = shared_priors,
    chains = 4, iter = 3000, warmup = 1000,
    seed = 42, refresh = 500,
    control = list(adapt_delta = 0.97, max_treedepth = 12),
    file = path_sens
  )
}

cat("\n=== Sensitivity model summary ===\n")
print(summary(fit_sens))

draws <- as_draws_df(fit_sens)
target_terms <- c(
  "b_pc_prop_c",
  "b_pc_prag_c",
  "b_g_c",
  "b_pc_prop_c:pc_prag_c",
  "b_pc_prop_c:g_c",
  "b_pc_prag_c:g_c",
  "b_pc_prop_c:pc_prag_c:g_c"
)

summary_tbl <- summarise_draws(
  draws |> select(all_of(target_terms)),
  mean,
  sd,
  ~quantile(.x, c(0.025, 0.975)),
  rhat,
  ess_bulk
) |>
  mutate(
    p_lt_0 = vapply(variable, function(v) mean(draws[[v]] < 0), numeric(1)),
    p_gt_0 = vapply(variable, function(v) mean(draws[[v]] > 0), numeric(1)),
    parameter = recode(variable,
      `b_pc_prop_c` = "pc_prop_c",
      `b_pc_prag_c` = "pc_prag_c",
      `b_g_c` = "g_c",
      `b_pc_prop_c:pc_prag_c` = "pc_prop_c:pc_prag_c",
      `b_pc_prop_c:g_c` = "pc_prop_c:g_c",
      `b_pc_prag_c:g_c` = "pc_prag_c:g_c",
      `b_pc_prop_c:pc_prag_c:g_c` = "pc_prop_c:pc_prag_c:g_c"
    )
  ) |>
  select(parameter, mean, sd, `2.5%`, `97.5%`, p_lt_0, p_gt_0, rhat, ess_bulk)

write.csv(summary_tbl, file.path(DATA_DIR, "brms_sensitivity_summary.csv"), row.names = FALSE)

cat("\n=== Sensitivity fixed-effect summary ===\n")
print(summary_tbl)

cat("\nKey robustness quantity:\n")
interaction_row <- summary_tbl |> filter(parameter == "pc_prag_c:g_c")
cat("P(pc_prag_c:g_c < 0) = ", round(interaction_row[["p_lt_0"]], 3), "\n", sep = "")