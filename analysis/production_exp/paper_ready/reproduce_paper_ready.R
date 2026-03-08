# reproduce_paper_ready.R
#
# Rebuild the paper-ready production bundle used for the manuscript.
# This refreshes:
#   - Figure 11 (RSA soft thresholds along utility axis)
#   - Figure 17 (Empirical vs model marker proportions by condition)
#   - Bayesian hypothesis contrasts (H1, H2, H3)
#   - RSA soft-threshold parameter summary
#   - manuscript_stats_table.md / .csv
#
# Run from repo root or from analysis/production_exp/paper_ready/ via:
#   Rscript analysis/production_exp/paper_ready/reproduce_paper_ready.R

get_script_dir <- function() {
  tryCatch(
    dirname(normalizePath(sys.frame(1)$ofile)),
    error = function(e) {
      args0 <- commandArgs(FALSE)
      file_arg <- grep("--file=", args0, value = TRUE)
      if (length(file_arg)) dirname(normalizePath(sub("--file=", "", file_arg)))
      else getwd()
    }
  )
}

paper_dir <- get_script_dir()
prod_dir <- normalizePath(file.path(paper_dir, ".."), mustWork = TRUE)
repo_dir <- normalizePath(file.path(prod_dir, "..", ".."), mustWork = TRUE)

source(file.path(paper_dir, "scripts", "make_manuscript_stats_table.R"))

source_stage <- function(file_name) {
  source(file.path(prod_dir, file_name), chdir = TRUE)
}

message("Refreshing production paper-ready bundle...")

# ── Stage 1: RSA soft-threshold model (produces fig 11, 12, 13) ──────────────
message("  running 04_rsa_soft_thresholds.R ...")
source_stage("04_rsa_soft_thresholds.R")

# ── Stage 2: Bayesian hypothesis contrasts ────────────────────────────────────
message("  running 07_bayesian_pairwise_full.R ...")
source_stage("07_bayesian_pairwise_full.R")

# ── Stage 3: Final paper figures (fig 17, 18, 19) ────────────────────────────
message("  running 08_final_paper_plots.R ...")
source_stage("08_final_paper_plots.R")

# ── Copy outputs into bundle ──────────────────────────────────────────────────
for (subdir in c("data", "plots", "scripts")) {
  dir.create(file.path(paper_dir, subdir), recursive = TRUE, showWarnings = FALSE)
}

copy_into_bundle <- function(paths, dest_subdir) {
  src <- file.path(repo_dir, paths)
  missing <- src[!file.exists(src)]
  if (length(missing)) {
    stop("Missing files while refreshing paper_ready bundle:\n",
         paste(missing, collapse = "\n"))
  }
  ok <- file.copy(src, file.path(paper_dir, dest_subdir), overwrite = TRUE)
  if (!all(ok)) stop("Failed to copy some files into paper_ready/", dest_subdir)
}

# Scripts
copy_into_bundle(c(
  "analysis/production_exp/04_rsa_soft_thresholds.R",
  "analysis/production_exp/07_bayesian_pairwise_full.R",
  "analysis/production_exp/08_final_paper_plots.R"
), "scripts")

# Data
copy_into_bundle(c(
  "analysis/production_exp/data/dummy_data.csv",
  "analysis/production_exp/data/norming_means.csv",
  "analysis/production_exp/data/rsa_soft_threshold_summary.csv",
  "analysis/production_exp/data/bayesian_full_pairwise_summary.csv",
  "analysis/production_exp/data/bayesian_full_condition_predictions.csv"
), "data")

# Plots — fig 11 (RSA thresholds) and fig 17 (empirical vs model)
copy_into_bundle(c(
  "analysis/production_exp/plots/fig11_rsa_soft_thresholds.pdf",
  "analysis/production_exp/plots/fig11_rsa_soft_thresholds.png",
  "analysis/production_exp/plots/fig17_empirical_vs_model_by_condition.pdf",
  "analysis/production_exp/plots/fig17_empirical_vs_model_by_condition.png"
), "plots")

# Build stats table CSV
make_manuscript_stats_table(paper_dir, prod_dir)

message("paper_ready bundle refreshed at: ", paper_dir)
