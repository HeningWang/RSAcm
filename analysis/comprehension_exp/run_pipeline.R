# run_pipeline.R
#
# Executes the comprehension-analysis pipeline.
# Run from analysis/comprehension_exp/ or via:
#   Rscript analysis/comprehension_exp/run_pipeline.R
#
# Stages:
#   1. 04_empirical_plots.R        — descriptive plots and summaries
#   2. 05_bayesian_beta_models.R   — confirmatory Bayesian zero/one-inflated beta models
#   3. 06_bayesian_contrasts.R     — posterior predictions and preregistered contrasts
#   4. 07_random_effects_sensitivity.R — random-effects sensitivity analysis
#   5. 07_rsa_listener_fit.R       — exploratory RSA listener fit

script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args0 <- commandArgs(FALSE)
    file_arg <- grep("--file=", args0, value = TRUE)
    if (length(file_arg)) dirname(normalizePath(sub("--file=", "", file_arg)))
    else getwd()
  }
)

run_stage <- function(f) source(file.path(script_dir, f), chdir = TRUE)

dir.create(file.path(script_dir, "data"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(script_dir, "plots"), showWarnings = FALSE, recursive = TRUE)

real_data_candidates <- c(
  file.path(script_dir, "../../data/comprehension_exp.csv"),
  file.path(script_dir, "data/real_data.csv")
)
real_data_path <- real_data_candidates[file.exists(real_data_candidates)][1]
stopifnot(!is.na(real_data_path), file.exists(real_data_path))

target_real_path <- file.path(script_dir, "data/real_data.csv")
if (normalizePath(real_data_path) != normalizePath(target_real_path, mustWork = FALSE)) {
  file.copy(real_data_path, target_real_path, overwrite = TRUE)
}

message("Using comprehension data from ", normalizePath(real_data_path))

message("\n── Stage 1: Empirical plots ──────────────────────────────────────")
run_stage("04_empirical_plots.R")

message("\n── Stage 2: Bayesian ZOIB models ───────────────────────────────")
run_stage("05_bayesian_beta_models.R")

message("\n── Stage 3: Posterior contrasts ────────────────────────────────")
run_stage("06_bayesian_contrasts.R")

message("\n── Stage 4: Random-effects sensitivity ─────────────────────────")
run_stage("07_random_effects_sensitivity.R")

message("\n── Stage 5: RSA listener fit ───────────────────────────────────")
run_stage("07_rsa_listener_fit.R")

message("\n── Stage 6: Categorical beta models (improved) ────────────────")
run_stage("08_categorical_beta_models.R")

message("\n── Stage 7: Categorical beta contrasts ─────────────────────────")
run_stage("09_categorical_beta_contrasts.R")

message("\n✓ Comprehension pipeline complete. Outputs are in data/ and plots/.")
