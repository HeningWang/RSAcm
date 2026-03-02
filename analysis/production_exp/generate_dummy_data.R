# generate_dummy_data.R
#
# Generates synthetic data that mimics the magpie output of the production
# experiment (Latin square design, 8 critical items × 4 conditions, 8 fillers).
# Also writes a dummy norming_means.csv that stands in for the real norming
# study results until actual data are collected.
#
# Generative model:
#   Utility  η  =  β_pc_prop · pc_prop_c + β_pc_prag · pc_prag + β_g · g + u_s
#     where:
#       pc_prop_c  – centred norming mean (perceived consensus, 0–100 scale,
#                    centred and scaled to SD ≈ 1); higher = more accepted
#       pc_prag    – 0 (social circle shares view) or 1 (opinions diverge)
#       g          – 0 (low persuasive goal) or 1 (high persuasive goal)
#       u_s        ~ Normal(0, σ_u)  by-participant random intercept
#
#   Marker k is chosen whenever a latent score  z = η + ε  (ε ~ Normal(0,1))
#   falls in the k-th threshold interval (cumulative probit ordering):
#     k = 1  if  z ≤ μ_1
#     k = j  if  μ_{j-1} < z ≤ μ_j   (j = 2,3,4)
#     k = 5  if  z > μ_4
#
# True parameters (recoverable by 02_bayesian_thresholds.R):
#   Thresholds:  μ = (-1.5, -0.5, 0.5, 1.5)
#   β_pc_prop =  0.8   (more consensus → stronger marker)
#   β_pc_prag = -0.6   (diverging social circle → weaker marker)
#   β_g       =  1.4   (stronger persuasive goal → stronger marker)
#   σ_u       =  0.4   (between-participant SD)
#
# Output:
#   data/norming_means.csv   — dummy norming means per topic
#   data/dummy_data.csv      — production experiment trials

set.seed(42)

library(dplyr)

# ── True parameters ────────────────────────────────────────────────────────────
MU           <- c(-1.5, -0.5, 0.5, 1.5)   # ordinal thresholds
BETA_PC_PROP <-  0.8   # effect per SD of centred pc_prop_rating (positive: more consensus → stronger marker)
BETA_PC_PRAG <- -0.6
BETA_G       <-  1.4
SIGMA_U      <-  0.4

N_SUBJ        <- 80     # total participants
N_LISTS       <- 4      # Latin square lists
SUBJ_PER_LIST <- N_SUBJ / N_LISTS   # 20

MARKERS <- c(
  "sofern ich weiß",
  "wie du ja weißt",
  "wie wir wissen",
  "ja",
  "bekanntlich"
)

TOPICS <- c("klimawandel", "ernaehrung", "stadtverkehr", "digitalisierung",
            "schlaf", "plastik", "sport", "lokalkauf")

# ── Dummy norming means ────────────────────────────────────────────────────────
# Plausible perceived-consensus ratings (0–100) per topic.
# Replace with real norming_means.csv once the norming study is complete.
NORMING_MEANS <- tibble(
  topic              = TOPICS,
  mean_pc_prop_rating = c(88, 62, 71, 85, 74, 79, 83, 58)
)

out_norming <- "data/norming_means.csv"
write.csv(NORMING_MEANS, out_norming, row.names = FALSE)
cat("Saved dummy norming means to", out_norming, "\n")

# Centre and scale norming means (mean = 0, SD ≈ 1) for use as predictor
NORMING_MEANS <- NORMING_MEANS |>
  mutate(pc_prop_c = as.numeric(scale(mean_pc_prop_rating)))

# ── Latin square design ────────────────────────────────────────────────────────
# 4 conditions: pc_prag × g (pc_prop is now a topic-level continuous predictor)
CONDITIONS <- tibble(
  condition_index = 0:3,
  pc_prag = c("low", "low",  "high", "high"),
  g       = c("low", "high", "low",  "high")
)

CRITICAL_ITEMS <- tibble(
  trial_id = 1:8,
  topic    = TOPICS
)

FILLER_ITEMS <- tibble(
  trial_id = 101:108,
  topic = c("bahn", "leselicht", "kochen", "kaffee",
            "urlaub", "trinken", "frischluft", "laerm")
)

# ── Utility helper ─────────────────────────────────────────────────────────────
pc_num <- function(x) ifelse(x == "low", 0L, 1L)

utility <- function(pc_prop_c, pc_prag, g, u_s) {
  BETA_PC_PROP * pc_prop_c +
    BETA_PC_PRAG * pc_num(pc_prag) +
    BETA_G       * pc_num(g) +
    u_s
}

# Ordered-probit choice: returns integer 1–5
sample_marker <- function(eta) {
  z    <- eta + rnorm(1)
  cuts <- c(-Inf, MU, Inf)
  findInterval(z, cuts[2:5]) + 1L   # 1-indexed
}

# ── Simulate participants ──────────────────────────────────────────────────────
rows <- vector("list", N_SUBJ)

for (s in seq_len(N_SUBJ)) {
  list_num <- (s - 1) %% N_LISTS           # 0-indexed list (0–3)
  u_s      <- rnorm(1, 0, SIGMA_U)

  # -- Critical trials --
  critical_rows <- vector("list", nrow(CRITICAL_ITEMS))
  for (i in seq_len(nrow(CRITICAL_ITEMS))) {
    item     <- CRITICAL_ITEMS[i, ]
    cond_idx <- (i - 1 + list_num) %% 4   # 0-indexed condition
    cond     <- CONDITIONS[cond_idx + 1, ] # 1-indexed row
    # Look up this item's centred pc_prop from norming means
    pc_c     <- NORMING_MEANS$pc_prop_c[NORMING_MEANS$topic == item$topic]
    eta      <- utility(pc_c, cond$pc_prag, cond$g, u_s)
    mk       <- sample_marker(eta)

    critical_rows[[i]] <- tibble(
      submission_id    = s,
      list_num         = list_num,
      trial_id         = item$trial_id,
      topic            = item$topic,
      is_filler        = FALSE,
      condition_index  = cond_idx,
      pc_prag          = cond$pc_prag,
      g                = cond$g,
      pc_prop_rating   = NORMING_MEANS$mean_pc_prop_rating[NORMING_MEANS$topic == item$topic],
      selected_marker  = MARKERS[mk],
      marker_index     = mk,
      rt               = round(abs(rnorm(1, mean = 4500, sd = 1500)))
    )
  }

  # -- Filler trials --
  filler_rows <- vector("list", nrow(FILLER_ITEMS))
  for (j in seq_len(nrow(FILLER_ITEMS))) {
    item <- FILLER_ITEMS[j, ]
    mk   <- sample(1:5, 1)
    filler_rows[[j]] <- tibble(
      submission_id    = s,
      list_num         = list_num,
      trial_id         = item$trial_id,
      topic            = item$topic,
      is_filler        = TRUE,
      condition_index  = NA_integer_,
      pc_prag          = NA_character_,
      g                = NA_character_,
      pc_prop_rating   = NA_real_,
      selected_marker  = MARKERS[mk],
      marker_index     = mk,
      rt               = round(abs(rnorm(1, mean = 3800, sd = 1200)))
    )
  }

  all_trials <- bind_rows(c(critical_rows, filler_rows))
  all_trials <- all_trials[sample(nrow(all_trials)), ]
  all_trials$trial_index <- seq_len(nrow(all_trials))

  rows[[s]] <- all_trials
}

dat <- bind_rows(rows) |>
  select(submission_id, list_num, trial_index, trial_id, topic,
         is_filler, condition_index, pc_prag, g, pc_prop_rating,
         selected_marker, marker_index, rt) |>
  arrange(submission_id, trial_index)

# ── Save ───────────────────────────────────────────────────────────────────────
out_path <- "data/dummy_data.csv"
write.csv(dat, out_path, row.names = FALSE)

cat(sprintf(
  "Saved %d rows (%d participants × %d trials) to %s\n",
  nrow(dat), N_SUBJ, nrow(dat) / N_SUBJ, out_path
))

# Quick sanity check
cat("\nMarker distribution (critical trials only):\n")
print(table(dat$selected_marker[!dat$is_filler]))

cat("\nMean marker index by g × pc_prag (critical trials):\n")
critical <- dat[!dat$is_filler, ]
print(with(critical,
  tapply(marker_index, list(g = g, pc_prag = pc_prag), mean)))

cat("\nMean marker index by topic (should reflect pc_prop_rating ordering):\n")
print(sort(tapply(critical$marker_index, critical$topic, mean), decreasing = TRUE))
