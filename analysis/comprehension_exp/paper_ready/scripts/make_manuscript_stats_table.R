make_manuscript_stats_table <- function(paper_dir, comp_dir) {
  data_dir <- file.path(paper_dir, "data")

  fixef_goal <- read.csv(file.path(data_dir, "brms_goal_cat_beta_fixef.csv"), stringsAsFactors = FALSE)
  fixef_adopt <- read.csv(file.path(data_dir, "brms_adoption_cat_beta_fixef.csv"), stringsAsFactors = FALSE)
  contrasts <- read.csv(file.path(data_dir, "cat_beta_posterior_contrasts.csv"), stringsAsFactors = FALSE)

  suppressPackageStartupMessages({
    library(brms)
    library(posterior)
  })

  fit_goal <- readRDS(file.path(comp_dir, "data", "fit_brms_goal_cat_beta.rds"))
  fit_adopt <- readRDS(file.path(comp_dir, "data", "fit_brms_adoption_cat_beta.rds"))

  coef_sign_support <- function(fit, term, direction) {
    draws <- posterior::as_draws_df(fit)[[paste0("b_", term)]]
    if (direction == ">0") sprintf("P(>0)=%.3f", mean(draws > 0))
    else sprintf("P(<0)=%.3f", mean(draws < 0))
  }

  coef_spec <- data.frame(
    outcome = c(
      "Inferred goal strength", "Inferred goal strength", "Inferred goal strength",
      "Adoption likelihood", "Adoption likelihood", "Adoption likelihood"
    ),
    term = c(
      "marker_catja", "marker_catbekanntlich", "marker_catja:pc_prag_c",
      "marker_catja", "marker_catbekanntlich", "marker_catja:pc_prag_c"
    ),
    direction = c(">0", ">0", ">0", ">0", ">0", "<0"),
    hypothesis = c("H4", "H4", "H6", "H5", "H5", "H6"),
    label = c(
      "Goal model: ja vs soviel coefficient",
      "Goal model: bekanntlich vs soviel coefficient",
      "Goal model: ja × pragmatic controversy interaction",
      "Adoption model: ja vs soviel coefficient",
      "Adoption model: bekanntlich vs soviel coefficient",
      "Adoption model: ja × pragmatic controversy interaction"
    ),
    stringsAsFactors = FALSE
  )

  coef_rows <- dplyr::bind_rows(fixef_goal, fixef_adopt) |>
    dplyr::inner_join(coef_spec, by = c("outcome", "term")) |>
    dplyr::rowwise() |>
    dplyr::transmute(
      section = "Model coefficient",
      hypothesis,
      outcome,
      label,
      estimate = round(Estimate, 3),
      interval = sprintf("[%.3f, %.3f]", Q2.5, Q97.5),
      support = if (outcome == "Inferred goal strength") {
        coef_sign_support(fit_goal, term, direction)
      } else {
        coef_sign_support(fit_adopt, term, direction)
      }
    ) |>
    dplyr::ungroup()

  contrast_spec <- data.frame(
    outcome = c(
      "Inferred goal strength", "Inferred goal strength", "Inferred goal strength", "Inferred goal strength",
      "Adoption likelihood", "Adoption likelihood", "Adoption likelihood", "Adoption likelihood", "Adoption likelihood"
    ),
    contrast = c(
      "ja_vs_soviel_low", "ja_vs_soviel_high", "bek_vs_soviel_low", "bek_vs_soviel_high",
      "ja_vs_soviel_low", "ja_vs_soviel_high", "bek_vs_ja_low", "credibility_discount", "pc_prag_effect"
    ),
    hypothesis = c("H4", "H4", "H4", "H4", "H5", "H5", "H5", "H6", "H6"),
    label = c(
      "Goal contrast: ja − soviel at low pragmatic controversy",
      "Goal contrast: ja − soviel at high pragmatic controversy",
      "Goal contrast: bekanntlich − soviel at low pragmatic controversy",
      "Goal contrast: bekanntlich − soviel at high pragmatic controversy",
      "Adoption contrast: ja − soviel at low pragmatic controversy",
      "Adoption contrast: ja − soviel at high pragmatic controversy",
      "Adoption contrast: bekanntlich − ja at low pragmatic controversy",
      "Adoption contrast: credibility discount",
      "Adoption contrast: pragmatic controversy main effect"
    ),
    direction = c(
      ">0", ">0", ">0", ">0",
      ">0", ">0", "<0", "<0", "<0"
    ),
    stringsAsFactors = FALSE
  )

  contrast_rows <- contrasts |>
    dplyr::inner_join(contrast_spec, by = c("outcome", "contrast")) |>
    dplyr::mutate(
      support = dplyr::if_else(
        direction == ">0",
        sprintf("P(>0)=%.3f", p_gt_0),
        sprintf("P(<0)=%.3f", p_lt_0)
      )
    ) |>
    dplyr::transmute(
      section = "Posterior contrast",
      hypothesis,
      outcome,
      label,
      estimate = round(mean, 2),
      interval = sprintf("[%.2f, %.2f]", lower, upper),
      support
    )

  out <- dplyr::bind_rows(coef_rows, contrast_rows)

  write.csv(out, file.path(data_dir, "manuscript_stats_table.csv"), row.names = FALSE)

  md_lines <- c(
    "# Manuscript-ready statistics table",
    "",
    "Derived from the categorical beta comprehension model and posterior contrasts.",
    "",
    "| Section | Hypothesis | Outcome | Statistic | Estimate | 95% CrI | Posterior support |",
    "| --- | --- | --- | --- | ---: | --- | --- |"
  )

  row_lines <- apply(out, 1, function(row) {
    sprintf(
      "| %s | %s | %s | %s | %s | %s | %s |",
      row[["section"]],
      row[["hypothesis"]],
      row[["outcome"]],
      row[["label"]],
      row[["estimate"]],
      row[["interval"]],
      ifelse(is.na(row[["support"]]) || row[["support"]] == "", "—", row[["support"]])
    )
  })

  writeLines(c(md_lines, row_lines, ""), file.path(paper_dir, "manuscript_stats_table.md"))

  invisible(out)
}
