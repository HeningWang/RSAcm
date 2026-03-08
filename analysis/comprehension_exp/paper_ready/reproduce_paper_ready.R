# reproduce_paper_ready.R
#
# Rebuild the paper-ready comprehension bundle used for the manuscript.
# This refreshes:
#   - Figure 7 (RSA base vs enhanced)
#   - categorical-beta fixed effects and hypothesis contrasts
#   - the copied paper_ready/ data, plots, and script snapshots
#
# Run from repo root or from analysis/comprehension_exp/paper_ready/ via:
#   Rscript analysis/comprehension_exp/paper_ready/reproduce_paper_ready.R

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
comp_dir <- normalizePath(file.path(paper_dir, ".."), mustWork = TRUE)
repo_dir <- normalizePath(file.path(comp_dir, "..", ".."), mustWork = TRUE)

source(file.path(paper_dir, "scripts", "make_manuscript_stats_table.R"))

source_stage <- function(file_name) {
  source(file.path(comp_dir, file_name), chdir = TRUE)
}

message("Refreshing figure/statistics from comprehension analysis scripts...")
source_stage("07_rsa_listener_fit.R")
source_stage("08_categorical_beta_models.R")
source_stage("09_categorical_beta_contrasts.R")

for (subdir in c("data", "plots", "scripts")) {
  dir.create(file.path(paper_dir, subdir), recursive = TRUE, showWarnings = FALSE)
}

copy_into_bundle <- function(paths, dest_subdir) {
  src <- file.path(repo_dir, paths)
  missing <- src[!file.exists(src)]
  if (length(missing)) {
    stop("Missing files while refreshing paper_ready bundle:\n", paste(missing, collapse = "\n"))
  }
  ok <- file.copy(src, file.path(paper_dir, dest_subdir), overwrite = TRUE)
  if (!all(ok)) stop("Failed to copy some files into paper_ready/", dest_subdir)
}

copy_into_bundle(c(
  "analysis/comprehension_exp/00_utils.R",
  "analysis/comprehension_exp/run_pipeline.R",
  "analysis/comprehension_exp/07_rsa_listener_fit.R",
  "analysis/comprehension_exp/08_categorical_beta_models.R",
  "analysis/comprehension_exp/09_categorical_beta_contrasts.R"
), "scripts")

copy_into_bundle(c(
  "data/comprehension_exp.csv",
  "analysis/comprehension_exp/data/analysis_data.csv",
  "analysis/comprehension_exp/data/comprehension_rsa_listener_condition_summary.csv",
  "analysis/comprehension_exp/data/comprehension_rsa_listener_parameter_summary.csv",
  "analysis/comprehension_exp/data/comprehension_rsa_enhanced_summary.csv",
  "analysis/comprehension_exp/data/brms_goal_cat_beta_fixef.csv",
  "analysis/comprehension_exp/data/brms_adoption_cat_beta_fixef.csv",
  "analysis/comprehension_exp/data/cat_beta_posterior_contrasts.csv",
  "analysis/comprehension_exp/data/cat_beta_posterior_predictions_goal.csv",
  "analysis/comprehension_exp/data/cat_beta_posterior_predictions_adoption.csv"
), "data")

copy_into_bundle(c(
  "analysis/comprehension_exp/plots/fig7_rsa_base_vs_enhanced.png",
  "analysis/comprehension_exp/plots/fig7_rsa_base_vs_enhanced.pdf",
  "analysis/comprehension_exp/plots/fig8_cat_beta_coefficients.png",
  "analysis/comprehension_exp/plots/fig8_cat_beta_coefficients.pdf",
  "analysis/comprehension_exp/plots/fig9_cat_beta_posterior_predictions.png",
  "analysis/comprehension_exp/plots/fig9_cat_beta_posterior_predictions.pdf"
), "plots")

make_manuscript_stats_table(paper_dir, comp_dir)

message("paper_ready bundle refreshed at: ", paper_dir)
