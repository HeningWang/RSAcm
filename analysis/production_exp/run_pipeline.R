# run_pipeline.R
#
# Executes the full analysis pipeline in order.
# Run from the analysis/production_exp/ directory:
#
#   Rscript run_pipeline.R            # use dummy data
#   Rscript run_pipeline.R real       # use data/real_data.csv (rename file first)
#
# Stages:
#   0. generate_dummy_data.R  — simulate N=80 participants (skipped if 'real')
#   1. 01_empirical_plots.R   — figures 1–4
#   2. 02_bayesian_thresholds.R — Stan threshold model, figures 5–7
#   3. 03_hierarchical_regression.R — brms regression, figures 8–10
#   4. 04_rsa_soft_thresholds.R — RSA soft-threshold fit, figures 11–13
#   5. 05_frequentist_ordinal.R — ordinal::clmm analysis, figures 14–16

# Resolve the directory containing this script so source() calls work
# regardless of the working directory when the script is invoked.
script_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),  # works when source()'d
  error = function(e) {
    # works when run via Rscript
    args0 <- commandArgs(FALSE)
    file_arg <- grep("--file=", args0, value = TRUE)
    if (length(file_arg)) dirname(normalizePath(sub("--file=", "", file_arg)))
    else getwd()
  }
)

run_stage <- function(f) source(file.path(script_dir, f), chdir = TRUE)

args <- commandArgs(trailingOnly = TRUE)
use_real <- length(args) > 0 && args[1] == "real"
real_data_candidates <- c(
  file.path(script_dir, "../../data/production_exp.csv"),
  file.path(script_dir, "data/real_data.csv")
)

if (use_real) {
  real_data_path <- real_data_candidates[file.exists(real_data_candidates)][1]
  stopifnot(!is.na(real_data_path), file.exists(real_data_path))
  target_real_path <- file.path(script_dir, "data/real_data.csv")
  if (normalizePath(real_data_path) != normalizePath(target_real_path, mustWork = FALSE)) {
    file.copy(real_data_path,
              target_real_path,
              overwrite = TRUE)
  }
  # Copy to dummy_data.csv so downstream scripts use the current dataset.
  file.copy(target_real_path,
            file.path(script_dir, "data/dummy_data.csv"),
            overwrite = TRUE)
  message("Using real data from ", normalizePath(real_data_path))
} else {
  message("Generating dummy data …")
  run_stage("generate_dummy_data.R")
}

message("\n── Stage 1: Empirical plots ──────────────────────────────────────")
run_stage("01_empirical_plots.R")

message("\n── Stage 2: Bayesian threshold model ────────────────────────────")
run_stage("02_bayesian_thresholds.R")

message("\n── Stage 3: Hierarchical regression ─────────────────────────────")
run_stage("03_hierarchical_regression.R")

message("\n── Stage 4: RSA soft thresholds ─────────────────────────────────")
run_stage("04_rsa_soft_thresholds.R")

message("\n── Stage 5: Frequentist ordinal model ──────────────────────────")
run_stage("05_frequentist_ordinal.R")

message("\n✓ Pipeline complete. Figures are in the plots/ directory.")
