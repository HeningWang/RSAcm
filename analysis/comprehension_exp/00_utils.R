# 00_utils.R
#
# Shared helpers for comprehension-experiment analysis scripts.

get_script_dir <- function() {
  script_dir <- getwd()
  if (!basename(script_dir) %in% c("comprehension_exp", "analysis")) {
    ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
    if (is.null(ofile)) {
      ofile <- getwd()
    }
    script_dir <- dirname(normalizePath(ofile, mustWork = FALSE))
  }
  if (basename(script_dir) != "comprehension_exp") {
    script_dir <- normalizePath(file.path(getwd(), "analysis/comprehension_exp"), mustWork = FALSE)
  }
  normalizePath(script_dir, mustWork = FALSE)
}

MARKERS_ORDERED <- c("soviel ich weiß", "ja", "bekanntlich")

as_logical_flag <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "t", "1")
}

make_beta_response <- function(x, n) {
  scaled <- x / 100
  ((scaled * (n - 1)) + 0.5) / n
}

make_unit_interval_response <- function(x) {
  as.numeric(x) / 100
}

resolve_paths <- function(script_dir = get_script_dir()) {
  list(
    script_dir = script_dir,
    data_dir = file.path(script_dir, "data"),
    plots_dir = file.path(script_dir, "plots"),
    raw_candidates = c(
      file.path(script_dir, "../../data/comprehension_exp.csv"),
      file.path(script_dir, "data/real_data.csv")
    ),
    norming_path = normalizePath(file.path(script_dir, "../production_exp/data/norming_means.csv"), mustWork = FALSE)
  )
}

load_comprehension_analysis_data <- function(script_dir = get_script_dir(), write_csv = TRUE) {
  paths <- resolve_paths(script_dir)
  dir.create(paths$data_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(paths$plots_dir, showWarnings = FALSE, recursive = TRUE)

  raw_path <- paths$raw_candidates[file.exists(paths$raw_candidates)][1]
  stopifnot(!is.na(raw_path), file.exists(raw_path), file.exists(paths$norming_path))

  raw <- read.csv(raw_path, stringsAsFactors = FALSE)
  norming <- read.csv(paths$norming_path, stringsAsFactors = FALSE) |>
    dplyr::mutate(pc_prop_c = as.numeric(scale(-mean_pc_prop_rating)))

  dat <- raw |>
    dplyr::mutate(
      is_filler = as_logical_flag(is_filler),
      is_training = as_logical_flag(is_training),
      is_critical = as_logical_flag(is_critical)
    )

  crit <- dat |>
    dplyr::filter(trial_type == "critical", !is_filler, !is_training) |>
    dplyr::left_join(norming |> dplyr::select(topic, mean_pc_prop_rating, pc_prop_c), by = "topic") |>
    dplyr::mutate(
      submission_id = factor(submission_id),
      topic = factor(topic),
      marker = factor(marker, levels = MARKERS_ORDERED, ordered = TRUE),
      marker_strength = dplyr::case_when(
        marker == "soviel ich weiß" ~ 1,
        marker == "ja" ~ 2,
        marker == "bekanntlich" ~ 3,
        TRUE ~ NA_real_
      ),
      marker_strength_c = marker_strength - 2,
      pc_prag = factor(pc_prag_analysis, levels = c("low", "high")),
      g_implied = factor(g_implied_analysis, levels = c("low", "high")),
      pc_prag_c = ifelse(pc_prag == "high", 0.5, -0.5),
      inferred_goal_strength = as.numeric(inferred_goal_strength),
      adoption_likelihood = as.numeric(adoption_likelihood),
      inferred_goal_strength_prop = make_unit_interval_response(inferred_goal_strength),
      adoption_likelihood_prop = make_unit_interval_response(adoption_likelihood),
      inferred_goal_strength_beta = make_beta_response(inferred_goal_strength, dplyr::n()),
      adoption_likelihood_beta = make_beta_response(adoption_likelihood, dplyr::n()),
      condition = factor(
        paste0("Prag. Controversy: ", pc_prag, "\nGoal: ", g_implied),
        levels = c(
          "Prag. Controversy: low\nGoal: low",
          "Prag. Controversy: low\nGoal: high",
          "Prag. Controversy: high\nGoal: low",
          "Prag. Controversy: high\nGoal: high"
        )
      )
    ) |>
    dplyr::arrange(submission_id, display_order)

  stopifnot(!any(is.na(crit$marker_strength)), !any(is.na(crit$pc_prag_c)))

  if (write_csv) {
    utils::write.csv(crit, file.path(paths$data_dir, "analysis_data.csv"), row.names = FALSE)
  }

  crit
}

make_prediction_grid <- function(crit) {
  base_topic <- levels(crit$topic)[1]
  base_subj <- levels(crit$submission_id)[1]

  tidyr::expand_grid(
    marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED, ordered = TRUE),
    pc_prag = factor(c("low", "high"), levels = c("low", "high"))
  ) |>
    dplyr::mutate(
      marker_strength = c(1, 1, 2, 2, 3, 3),
      marker_strength_c = marker_strength - 2,
      pc_prag_c = ifelse(pc_prag == "high", 0.5, -0.5),
      topic = factor(base_topic, levels = levels(crit$topic)),
      submission_id = factor(base_subj, levels = levels(crit$submission_id))
    )
}

save_plot <- function(p, name, script_dir = get_script_dir(), width = 8, height = 5) {
  plots_dir <- file.path(script_dir, "plots")
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)
  ggplot2::ggsave(file.path(plots_dir, paste0(name, ".pdf")), p, width = width, height = height)
  ggplot2::ggsave(file.path(plots_dir, paste0(name, ".png")), p, width = width, height = height, dpi = 180)
  invisible(p)
}
