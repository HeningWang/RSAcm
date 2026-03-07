# 02_balanced_item_selection.R
#
# Exploratory, uncertainty-aware balancing of comprehension marker assignments.
#
# Starting from the preregistered posterior cell probabilities, this script
# selects a near-balanced marker assignment that maximizes total posterior
# support subject to balanced marker counts across the 32 critical cells.
#
# Outputs:
#   data/comprehension_balanced_assignment_long.csv
#   data/comprehension_balanced_assignment_matrix.csv
#   data/comprehension_balanced_assignment.json
#   data/comprehension_balanced_assignment_summary.csv
#   ../../experiments/item/comprehension_marker_assignment_balanced.csv

library(dplyr)
library(tidyr)
library(jsonlite)

SCRIPT_DIR <- normalizePath(getwd(), mustWork = FALSE)
if (basename(SCRIPT_DIR) != "comprehension_exp") {
  SCRIPT_DIR <- normalizePath(file.path(getwd(), "analysis/comprehension_exp"), mustWork = TRUE)
}

DATA_DIR <- file.path(SCRIPT_DIR, "data")
ITEM_DIR <- normalizePath(file.path(SCRIPT_DIR, "../../experiments/item"), mustWork = TRUE)

pred_path <- file.path(DATA_DIR, "comprehension_condition_predictions.csv")
stopifnot(file.exists(pred_path))

MARKERS <- c("soviel ich weiß", "ja", "bekanntlich")
count_targets <- list(
  c(10L, 11L, 11L),
  c(11L, 10L, 11L),
  c(11L, 11L, 10L)
)

pred <- read.csv(pred_path, stringsAsFactors = FALSE, check.names = FALSE) |>
  arrange(as.integer(item_id), condition_index)

prob_mat <- as.matrix(pred[, MARKERS])
log_prob_mat <- log(pmax(prob_mat, 1e-12))
n <- nrow(log_prob_mat)

solve_balanced_assignment <- function(log_probs, target_counts) {
  target_a <- target_counts[1]
  target_b <- target_counts[2]
  target_c <- target_counts[3]

  dp <- array(-Inf, dim = c(n + 1, target_a + 1, target_b + 1))
  back <- array(NA_integer_, dim = c(n + 1, target_a + 1, target_b + 1))
  dp[1, 1, 1] <- 0

  for (i in seq_len(n)) {
    for (a in 0:target_a) {
      for (b in 0:target_b) {
        current <- dp[i, a + 1, b + 1]
        if (!is.finite(current)) next

        used_c <- (i - 1) - a - b
        if (used_c < 0 || used_c > target_c) next

        # assign marker 1
        if (a < target_a) {
          cand <- current + log_probs[i, 1]
          if (cand > dp[i + 1, a + 2, b + 1]) {
            dp[i + 1, a + 2, b + 1] <- cand
            back[i + 1, a + 2, b + 1] <- 1L
          }
        }

        # assign marker 2
        if (b < target_b) {
          cand <- current + log_probs[i, 2]
          if (cand > dp[i + 1, a + 1, b + 2]) {
            dp[i + 1, a + 1, b + 2] <- cand
            back[i + 1, a + 1, b + 2] <- 2L
          }
        }

        # assign marker 3
        if (used_c < target_c) {
          cand <- current + log_probs[i, 3]
          if (cand > dp[i + 1, a + 1, b + 1]) {
            dp[i + 1, a + 1, b + 1] <- cand
            back[i + 1, a + 1, b + 1] <- 3L
          }
        }
      }
    }
  }

  best_score <- dp[n + 1, target_a + 1, target_b + 1]
  if (!is.finite(best_score)) return(NULL)

  assignment <- integer(n)
  a <- target_a
  b <- target_b
  for (i in seq(n, 1)) {
    choice <- back[i + 1, a + 1, b + 1]
    assignment[i] <- choice
    if (choice == 1L) a <- a - 1L
    if (choice == 2L) b <- b - 1L
  }

  list(score = best_score, assignment = assignment, target = target_counts)
}

solutions <- lapply(count_targets, solve_balanced_assignment, log_probs = log_prob_mat)
solutions <- Filter(Negate(is.null), solutions)
best <- solutions[[which.max(vapply(solutions, `[[`, numeric(1), "score"))]]

balanced <- pred |>
  mutate(
    selected_marker = MARKERS[best$assignment],
    selected_prob = prob_mat[cbind(seq_len(n), best$assignment)],
    modal_marker = modal_marker,
    modal_prob = modal_prob,
    deviation_from_modal = selected_marker != modal_marker,
    log_prob_loss = log(modal_prob) - log(selected_prob)
  )

balanced_matrix <- balanced |>
  transmute(
    item_id,
    topic,
    condition_label = c("low_low", "low_high", "high_low", "high_high")[condition_index + 1],
    selected_marker
  ) |>
  pivot_wider(names_from = condition_label, values_from = selected_marker) |>
  arrange(as.integer(item_id))

summary_tbl <- tibble(
  metric = c(
    "target_counts",
    "total_log_posterior_support",
    "mean_selected_probability",
    "mean_modal_probability",
    "cells_deviating_from_modal",
    "mean_log_prob_loss",
    "max_log_prob_loss"
  ),
  value = c(
    paste(best$target, collapse = "/"),
    round(best$score, 3),
    round(mean(balanced$selected_prob), 3),
    round(mean(balanced$modal_prob), 3),
    sum(balanced$deviation_from_modal),
    round(mean(balanced$log_prob_loss), 3),
    round(max(balanced$log_prob_loss), 3)
  )
)

write.csv(balanced, file.path(DATA_DIR, "comprehension_balanced_assignment_long.csv"), row.names = FALSE)
write.csv(balanced_matrix, file.path(DATA_DIR, "comprehension_balanced_assignment_matrix.csv"), row.names = FALSE)
write.csv(summary_tbl, file.path(DATA_DIR, "comprehension_balanced_assignment_summary.csv"), row.names = FALSE)
write.csv(
  balanced |>
    select(item_id, topic, condition_index, modal_marker = selected_marker),
  file.path(ITEM_DIR, "comprehension_marker_assignment_balanced.csv"),
  row.names = FALSE
)
write_json(
  setNames(lapply(split(balanced$selected_marker, balanced$item_id), unname), unique(balanced$item_id)),
  path = file.path(DATA_DIR, "comprehension_balanced_assignment.json"),
  auto_unbox = TRUE,
  pretty = TRUE
)

cat("\n=== Balanced comprehension item selection ===\n")
cat("Target counts:", paste(best$target, collapse = "/"), "\n")
cat("Total log posterior support:", round(best$score, 3), "\n")
cat("\nMarker counts:\n")
print(table(balanced$selected_marker))
cat("\nCells deviating from prereg modal assignment:", sum(balanced$deviation_from_modal), "\n")
cat("\nBalanced assignment matrix:\n")
print(balanced_matrix)