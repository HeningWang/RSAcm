# make_manuscript_stats_table.R
#
# Build the manuscript_stats_table.md and .csv for the production experiment
# from the bayesian contrast summary and RSA parameter summary.

make_manuscript_stats_table <- function(paper_dir, prod_dir) {
  contrasts <- read.csv(
    file.path(prod_dir, "data", "bayesian_full_pairwise_summary.csv"),
    stringsAsFactors = FALSE
  )
  conditions <- read.csv(
    file.path(prod_dir, "data", "bayesian_full_condition_predictions.csv"),
    stringsAsFactors = FALSE
  )
  rsa <- read.csv(
    file.path(prod_dir, "data", "rsa_soft_threshold_summary.csv"),
    stringsAsFactors = FALSE
  )

  all_rows <- rbind(
    data.frame(
      source = "brms_contrast",
      label = contrasts$contrast,
      predicted_direction = ifelse(is.na(contrasts$predicted_direction), "",
                                   contrasts$predicted_direction),
      estimate = round(contrasts$mean, 3),
      ci_low = round(contrasts$conf.low, 3),
      ci_high = round(contrasts$conf.high, 3),
      p_gt_0 = round(contrasts$p_gt_0, 4),
      p_lt_0 = round(contrasts$p_lt_0, 4),
      stringsAsFactors = FALSE
    ),
    data.frame(
      source = "brms_condition",
      label = paste0(conditions$pc_prag, "/", conditions$g),
      predicted_direction = "",
      estimate = round(conditions$mean_strength, 3),
      ci_low = round(conditions$mean_strength_low, 3),
      ci_high = round(conditions$mean_strength_high, 3),
      p_gt_0 = NA_real_,
      p_lt_0 = NA_real_,
      stringsAsFactors = FALSE
    ),
    data.frame(
      source = "rsa_parameter",
      label = rsa$parameter,
      predicted_direction = "",
      estimate = round(rsa$estimate, 3),
      ci_low = round(rsa$conf.low, 3),
      ci_high = round(rsa$conf.high, 3),
      p_gt_0 = NA_real_,
      p_lt_0 = NA_real_,
      stringsAsFactors = FALSE
    )
  )

  write.csv(all_rows,
            file.path(paper_dir, "data", "manuscript_stats_table.csv"),
            row.names = FALSE)
  message("  wrote manuscript_stats_table.csv")
}
