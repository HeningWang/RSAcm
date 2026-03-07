# 05_frequentist_ordinal.R
#
# Frequentist ordinal analysis for the production experiment using the
# `ordinal` package.
#
# Models:
#   Model A — additive:
#     marker ~ pc_prop + pc_prag + g + (1 | submission_id)
#   Model B — full interactions:
#     marker ~ pc_prop * pc_prag * g + (1 | submission_id)
#
# Outputs:
#   data/fit_clmm_additive.rds
#   data/fit_clmm_full.rds
#   data/frequentist_ordinal_model_compare.csv
#   data/frequentist_ordinal_coef_additive.csv
#   data/frequentist_ordinal_coef_full.csv
#   plots/fig14_freq_coef_plot.pdf/png
#   plots/fig15_freq_cond_effects.pdf/png
#   plots/fig16_freq_model_compare.pdf/png

library(dplyr)
library(tidyr)
library(ggplot2)
library(ordinal)
library(aida)

PLOTS_DIR <- "plots"
DATA_DIR  <- "data"
dir.create(PLOTS_DIR, showWarnings = FALSE)
dir.create(DATA_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c(
  "soviel ich weiß",
  "ja",
  "bekanntlich"
)

##################################################
## CSP-colors
##################################################
CSP_colors <- c(
  "#7581B3", "#99C2C2", "#C65353", "#E2BA78", "#5C7457", "#575463",
  "#B0B7D4", "#66A3A3", "#DB9494", "#D49735", "#9BB096", "#D4D3D9",
  "#414C76", "#993333"
)

marker_colors <- setNames(CSP_colors[seq_along(MARKERS_ORDERED)], MARKERS_ORDERED)

theme_set(theme_aida())
theme_model <- function() {
  theme_aida() +
    theme(
      axis.text.y  = element_text(size = 14),
      axis.text.x  = element_text(size = 14),
      axis.title.y = element_text(size = 16),
      axis.title.x = element_text(size = 16),
      legend.text  = element_text(size = 13),
      legend.title = element_text(size = 14)
    )
}

save_plot <- function(p, name, w = 8, h = 5) {
  ggsave(file.path(PLOTS_DIR, paste0(name, ".pdf")), p, width = w, height = h)
  ggsave(file.path(PLOTS_DIR, paste0(name, ".png")), p, width = w, height = h,
         dpi = 180)
  invisible(p)
}

as_logical_flag <- function(x) {
  tolower(trimws(as.character(x))) %in% c("true", "t", "1")
}

coef_table <- function(fit, model_name) {
  sm <- summary(fit)
  tab <- as.data.frame(sm$coefficients)
  tab$term <- rownames(tab)
  rownames(tab) <- NULL

  est_col <- intersect(c("Estimate", "estimate"), names(tab))[1]
  se_col  <- intersect(c("Std. Error", "Std..Error", "Std.error"), names(tab))[1]
  z_col   <- intersect(c("z value", "z.value"), names(tab))[1]
  p_col   <- intersect(c("Pr(>|z|)", "Pr...z.."), names(tab))[1]

  estimate <- tab[[est_col]]
  std_error <- tab[[se_col]]

  out <- tibble(
    model = model_name,
    term = tab$term,
    estimate = estimate,
    std.error = std_error,
    statistic = tab[[z_col]],
    p.value = tab[[p_col]],
    conf.low = estimate - qnorm(0.975) * std_error,
    conf.high = estimate + qnorm(0.975) * std_error
  )
  out
}

# ── Load data ─────────────────────────────────────────────────────────────────
dat <- read.csv(file.path(DATA_DIR, "dummy_data.csv"), stringsAsFactors = FALSE) |>
  mutate(
    is_filler = as_logical_flag(is_filler),
    is_training = as_logical_flag(is_training)
  )

norming <- read.csv(file.path(DATA_DIR, "norming_means.csv"), stringsAsFactors = FALSE) |>
  mutate(pc_prop_c = as.numeric(scale(-mean_pc_prop_rating)))

crit <- dat |>
  filter(!is_filler, !is_training) |>
  left_join(norming |> select(topic, pc_prop_c), by = "topic") |>
  mutate(
    marker = ordered(selected_marker, levels = MARKERS_ORDERED),
    submission_id = factor(submission_id),
    pc_prag = factor(pc_prag, levels = c("low", "high")),
    g = factor(g, levels = c("low", "high")),
    pc_prag_c = ifelse(pc_prag == "high", 0.5, -0.5),
    g_c = ifelse(g == "high", 0.5, -0.5)
  )

# ── Fit models ────────────────────────────────────────────────────────────────
path_add <- file.path(DATA_DIR, "fit_clmm_additive.rds")
path_full <- file.path(DATA_DIR, "fit_clmm_full.rds")

message("Fitting frequentist additive CLMM …")
fit_add <- clmm(
  marker ~ pc_prop_c + pc_prag_c + g_c + (1 | submission_id),
  data = crit,
  link = "probit",
  Hess = TRUE,
  nAGQ = 10
)
saveRDS(fit_add, path_add)

message("Fitting frequentist full CLMM …")
fit_full <- clmm(
  marker ~ pc_prop_c * pc_prag_c * g_c + (1 | submission_id),
  data = crit,
  link = "probit",
  Hess = TRUE,
  nAGQ = 10
)
saveRDS(fit_full, path_full)

# Fixed-effect-only CLMs for probability prediction
fit_add_pred <- clm(
  marker ~ pc_prop_c + pc_prag_c + g_c,
  data = crit,
  link = "probit"
)

# ── Summaries and tables ──────────────────────────────────────────────────────
cat("\n=== Frequentist ordinal Model A (additive) ===\n")
print(summary(fit_add))

cat("\n=== Frequentist ordinal Model B (full interactions) ===\n")
print(summary(fit_full))

coef_add <- coef_table(fit_add, "additive")
coef_full <- coef_table(fit_full, "full")
write.csv(coef_add, file.path(DATA_DIR, "frequentist_ordinal_coef_additive.csv"), row.names = FALSE)
write.csv(coef_full, file.path(DATA_DIR, "frequentist_ordinal_coef_full.csv"), row.names = FALSE)

cmp <- tibble(
  model = c("additive", "full"),
  logLik = c(as.numeric(logLik(fit_add)), as.numeric(logLik(fit_full))),
  AIC = c(AIC(fit_add), AIC(fit_full)),
  BIC = c(BIC(fit_add), BIC(fit_full)),
  df = c(attr(logLik(fit_add), "df"), attr(logLik(fit_full), "df"))
)

lr <- anova(fit_add, fit_full)
cmp$lr_statistic <- c(NA_real_, unname(lr$LR.stat[2]))
cmp$lr_df <- c(NA_real_, unname(lr$df[2]))
cmp$lr_pvalue <- c(NA_real_, unname(lr$`Pr(>Chisq)`[2]))
write.csv(cmp, file.path(DATA_DIR, "frequentist_ordinal_model_compare.csv"), row.names = FALSE)

cat("\n=== Frequentist model comparison ===\n")
print(cmp)

# ── Figure 14: Coefficient plot (additive model) ─────────────────────────────
plot_coef <- coef_add |>
  filter(term %in% c("pc_prop_c", "pc_prag_c", "g_c")) |>
  mutate(
    term = factor(term,
                  levels = c("pc_prop_c", "pc_prag_c", "g_c"),
                  labels = c("pc_prop", "pc_prag", "g"))
  )

p14 <- ggplot(plot_coef, aes(x = estimate, y = term, colour = term)) +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.15,
                 linewidth = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  scale_colour_manual(values = CSP_colors[1:3], guide = "none") +
  labs(
    title = "Frequentist ordinal effects (additive CLMM)",
    subtitle = "Point estimates with Wald 95% confidence intervals",
    x = "Estimate on latent probit scale",
    y = NULL
  ) +
  theme_model()

save_plot(p14, "fig14_freq_coef_plot", w = 8, h = 4)

# ── Figure 15: Predicted probabilities by condition ───────────────────────────
newdata <- expand.grid(
  pc_prop_c = 0,
  pc_prag_c = c(-0.5, 0.5),
  g_c = c(-0.5, 0.5)
)

pred_probs <- predict(fit_add_pred, newdata = newdata, type = "prob")
prob_mat <- as.data.frame(pred_probs$fit)
colnames(prob_mat) <- MARKERS_ORDERED

pred_df <- bind_cols(newdata, prob_mat) |>
  mutate(
    pc_prag = ifelse(pc_prag_c < 0, "low", "high"),
    g = ifelse(g_c < 0, "low", "high")
  ) |>
  pivot_longer(cols = all_of(MARKERS_ORDERED), names_to = "marker", values_to = "prob") |>
  mutate(
    marker = factor(marker, levels = MARKERS_ORDERED),
    condition = factor(
      paste0("pc_prag:", pc_prag, "\n", "g:", g),
      levels = c(
        "pc_prag:low\ng:low",
        "pc_prag:low\ng:high",
        "pc_prag:high\ng:low",
        "pc_prag:high\ng:high"
      )
    )
  )

p15 <- ggplot(pred_df, aes(x = condition, y = prob, fill = marker)) +
  geom_col(position = "stack", width = 0.65, colour = "white", linewidth = 0.2) +
  scale_fill_manual(values = marker_colors, name = "Marker") +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Frequentist predicted marker probabilities",
    subtitle = "Additive CLM predictions at centred propositional controversy (pc_prop = 0)",
    x = "Condition",
    y = "Predicted probability"
  ) +
  theme_model() +
  theme(
    axis.text.x = element_text(angle = 30, hjust = 1, vjust = 1, size = 12),
    legend.position = "right",
    panel.grid.major.x = element_blank()
  )

save_plot(p15, "fig15_freq_cond_effects", w = 8.5, h = 5.5)

# ── Figure 16: Model comparison ───────────────────────────────────────────────
cmp_plot <- cmp |>
  mutate(model = factor(model, levels = c("additive", "full")))

p16 <- ggplot(cmp_plot, aes(x = model, y = AIC, fill = model)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f", AIC)), vjust = -0.5, size = 4) +
  scale_fill_manual(values = c(CSP_colors[1], CSP_colors[4]), guide = "none") +
  labs(
    title = "Frequentist model comparison",
    subtitle = "Lower AIC indicates better fit",
    x = NULL,
    y = "AIC"
  ) +
  theme_model()

save_plot(p16, "fig16_freq_model_compare", w = 6, h = 4)

cat("\nFiles saved:\n")
cat("  fit_clmm_additive.rds\n")
cat("  fit_clmm_full.rds\n")
cat("  frequentist_ordinal_coef_additive.csv\n")
cat("  frequentist_ordinal_coef_full.csv\n")
cat("  frequentist_ordinal_model_compare.csv\n")
cat("  fig14_freq_coef_plot\n")
cat("  fig15_freq_cond_effects\n")
cat("  fig16_freq_model_compare\n")