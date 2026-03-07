# 01_item_selection_from_production.R
#
# Implements the preregistered comprehension item-selection procedure:
# for each critical item × condition cell, compute the posterior predictive
# distribution from the fitted production model and assign the modal marker.

library(dplyr)
library(tidyr)
library(brms)
library(jsonlite)

`%||%` <- function(x, y) if (is.null(x)) y else x

SCRIPT_DIR <- getwd()
if (!basename(SCRIPT_DIR) %in% c("comprehension_exp", "analysis")) {
  SCRIPT_DIR <- dirname(normalizePath(sys.frame(1)$ofile %||% getwd(), mustWork = FALSE))
}
if (basename(SCRIPT_DIR) != "comprehension_exp") {
  SCRIPT_DIR <- normalizePath(file.path(getwd(), "analysis/comprehension_exp"), mustWork = FALSE)
}

DATA_DIR <- file.path(SCRIPT_DIR, "data")
dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)

PROD_DIR <- normalizePath(file.path(SCRIPT_DIR, "../production_exp"), mustWork = TRUE)
ITEM_DIR <- normalizePath(file.path(SCRIPT_DIR, "../../experiments/item"), mustWork = TRUE)

fit_path <- file.path(PROD_DIR, "data/fit_brms_full_3markers.rds")
norming_path <- file.path(PROD_DIR, "data/norming_means.csv")
items_path <- file.path(ITEM_DIR, "items.csv")
assignment_export_path <- file.path(ITEM_DIR, "comprehension_marker_assignment.csv")

MARKERS_ORDERED <- c("soviel ich weiß", "ja", "bekanntlich")

stopifnot(file.exists(fit_path), file.exists(norming_path), file.exists(items_path))

fit_full <- readRDS(fit_path)

norming <- read.csv(norming_path, stringsAsFactors = FALSE) |>
  mutate(pc_prop_c = as.numeric(scale(-mean_pc_prop_rating)))

items <- read.csv(items_path, stringsAsFactors = FALSE) |>
  filter(item_type == "critical") |>
  arrange(as.integer(item_id)) |>
  select(item_id, topic)

conditions <- tibble(
  condition_index = 0:3,
  pc_prag = c("low", "low", "high", "high"),
  g_implied = c("low", "high", "low", "high"),
  pc_prag_c = c(-0.5, -0.5, 0.5, 0.5),
  g_c = c(-0.5, 0.5, -0.5, 0.5)
)

newdata <- tidyr::crossing(items, conditions) |>
	left_join(norming |> select(topic, pc_prop_c, mean_pc_prop_rating), by = "topic") |>
	arrange(as.integer(item_id), condition_index)

epred <- posterior_epred(fit_full, newdata = newdata, re_formula = NA)
mean_probs <- apply(epred, c(2, 3), mean)
colnames(mean_probs) <- MARKERS_ORDERED

pred_tbl <- bind_cols(
  newdata,
  as_tibble(mean_probs, .name_repair = "minimal")
) |>
  mutate(
    modal_marker = MARKERS_ORDERED[max.col(mean_probs, ties.method = "first")],
    modal_prob = pmax(`soviel ich weiß`, ja, bekanntlich),
    runner_up_prob = apply(mean_probs, 1, function(x) sort(x, decreasing = TRUE)[2]),
    modal_margin = modal_prob - runner_up_prob
  )

assignment_long <- pred_tbl |>
  transmute(
    item_id,
    topic,
    condition_index,
    pc_prag,
    g_implied,
    pc_prop_c,
    mean_pc_prop_rating,
    prob_soviel = `soviel ich weiß`,
    prob_ja = ja,
    prob_bekanntlich = bekanntlich,
    modal_marker,
    modal_prob,
    modal_margin
  )

assignment_matrix <- assignment_long |>
	select(item_id, topic, condition_index, modal_marker) |>
	mutate(condition_label = c("low_low", "low_high", "high_low", "high_high")[condition_index + 1]) |>
	select(-condition_index) |>
	pivot_wider(names_from = condition_label, values_from = modal_marker) |>
	arrange(as.integer(item_id))

assignment_json <- assignment_long |>
	group_by(item_id, topic) |>
	summarise(marker_assignment = list(modal_marker), .groups = "drop")

write.csv(pred_tbl, file.path(DATA_DIR, "comprehension_condition_predictions.csv"), row.names = FALSE)
write.csv(assignment_long, file.path(DATA_DIR, "comprehension_marker_assignment_long.csv"), row.names = FALSE)
write.csv(assignment_matrix, file.path(DATA_DIR, "comprehension_marker_assignment_matrix.csv"), row.names = FALSE)
write.csv(assignment_long |> select(item_id, topic, condition_index, modal_marker),
          assignment_export_path, row.names = FALSE)
write_json(
  setNames(lapply(split(assignment_long$modal_marker, assignment_long$item_id), unname), unique(assignment_long$item_id)),
  path = file.path(DATA_DIR, "comprehension_marker_assignment.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

cat("\n=== Preregistered comprehension item selection ===\n")
cat("Using full Bayesian production model:", fit_path, "\n")
cat("\nModal marker assignment by item × condition:\n")
print(assignment_matrix)
cat("\nWrote assignment file for stimuli generator to:\n")
cat("  ", assignment_export_path, "\n", sep = "")
