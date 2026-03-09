# 08_final_paper_plots.R
#
# Final paper figures for the production experiment.
#
# Figure 17:
#   Empirical marker proportions by condition with participant-bootstrap CIs,
#   compared against posterior predictions from the best-fitting additive model
#   in separate marker facets.
#
# Figure 18:
#   Posterior distributions of main effects and the key interaction effect.
#
# Figure 19:
#   Inferred thresholds from the noisy-threshold model.

library(dplyr)
library(tidyr)
library(ggplot2)
library(brms)
library(posterior)
library(ggdist)
library(aida)
library(patchwork)

PLOTS_DIR <- "plots"
DATA_DIR <- "data"
dir.create(PLOTS_DIR, showWarnings = FALSE)

MARKERS_ORDERED <- c(
  "soviel ich weiß",
  "ja",
  "bekanntlich"
)

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
      axis.text.y  = element_text(size = 13),
      axis.text.x  = element_text(size = 13),
      axis.title.y = element_text(size = 15),
      axis.title.x = element_text(size = 15),
      legend.text  = element_text(size = 12),
      legend.title = element_text(size = 13)
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

condition_levels <- c(
  "pc_prag:low\ng:low",
  "pc_prag:low\ng:high",
  "pc_prag:high\ng:low",
  "pc_prag:high\ng:high"
)

condition_key <- tibble(
  condition = factor(condition_levels, levels = condition_levels),
  pc_prag = factor(c("low", "low", "high", "high"), levels = c("low", "high")),
  g = factor(c("low", "high", "low", "high"), levels = c("low", "high"))
)

make_condition <- function(pc_prag, g) {
  factor(
    paste0("pc_prag:", pc_prag, "\n", "g:", g),
    levels = condition_levels
  )
}

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
    marker = factor(selected_marker, levels = MARKERS_ORDERED),
    submission_id = factor(submission_id),
    pc_prag = factor(pc_prag, levels = c("low", "high")),
    g = factor(g, levels = c("low", "high")),
    pc_prag_c = ifelse(pc_prag == "high", 0.5, -0.5),
    g_c = ifelse(g == "high", 0.5, -0.5),
    condition = make_condition(pc_prag, g)
  )

# ── Figure 17: empirical proportions + posterior predictions ─────────────────
template <- expand.grid(
  pc_prag = factor(c("low", "high"), levels = c("low", "high")),
  g = factor(c("low", "high"), levels = c("low", "high")),
  marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED)
)

empirical <- crit |>
  count(pc_prag, g, marker, .drop = FALSE) |>
  group_by(pc_prag, g) |>
  mutate(prop = n / sum(n)) |>
  ungroup() |>
  right_join(template, by = c("pc_prag", "g", "marker")) |>
  mutate(n = ifelse(is.na(n), 0L, n), prop = ifelse(is.na(prop), 0, prop))

set.seed(42)
subj_ids <- unique(crit$submission_id)
B <- 2000L

template_boot <- expand.grid(
  condition = factor(condition_levels, levels = condition_levels),
  marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED)
) |>
  left_join(condition_key, by = "condition")

boot_mat <- replicate(B, {
  sampled <- sample(subj_ids, length(subj_ids), replace = TRUE)
  boot_dat <- bind_rows(lapply(sampled, function(id) crit |> filter(submission_id == id)))
  tab <- xtabs(~ condition + marker, data = boot_dat)
  prop_tab <- sweep(tab, 1, rowSums(tab), "/")
  as.vector(prop_tab)
})

boot_summary <- template_boot |>
  mutate(
    emp_low = apply(boot_mat, 1, quantile, probs = 0.025),
    emp_high = apply(boot_mat, 1, quantile, probs = 0.975)
  ) |>
  select(-condition)

fit_a_path <- file.path(DATA_DIR, "fit_brms_additive_3markers.rds")
stopifnot(file.exists(fit_a_path))
fit_a <- readRDS(fit_a_path)

epred <- posterior_epred(fit_a, newdata = crit, re_formula = NA)
cond_indices <- split(seq_len(nrow(crit)), crit$condition)

pred_df <- bind_rows(lapply(names(cond_indices), function(cond) {
  idx <- cond_indices[[cond]]
  draw_mean <- apply(epred[, idx, , drop = FALSE], c(1, 3), mean)
  tibble(
    condition = factor(cond, levels = condition_levels),
    marker = factor(MARKERS_ORDERED, levels = MARKERS_ORDERED),
    pred = colMeans(draw_mean),
    pred_low = apply(draw_mean, 2, quantile, probs = 0.025),
    pred_high = apply(draw_mean, 2, quantile, probs = 0.975)
  )
})) |>
  left_join(condition_key, by = "condition") |>
  select(-condition)

plot17_df <- empirical |>
  left_join(boot_summary, by = c("pc_prag", "g", "marker")) |>
  left_join(pred_df, by = c("pc_prag", "g", "marker"))

plot17_long <- bind_rows(
  plot17_df |>
    transmute(pc_prag, g, marker,
              series = "Empirical",
              value = prop,
              low = emp_low,
              high = emp_high),
  plot17_df |>
    transmute(pc_prag, g, marker,
              series = "Model",
              value = pred,
              low = pred_low,
              high = pred_high)
) |>
  mutate(
    marker = factor(marker, levels = MARKERS_ORDERED),
    series = factor(series, levels = c("Empirical", "Model")),
    pc_prag = factor(pc_prag, levels = c("low", "high"),
                     labels = c("Prag. Controversy: low", "Prag. Controversy: high")),
    g = factor(g, levels = c("low", "high"),
               labels = c("Goal: low", "Goal: high"))
  )

# --- Version A: 2x2 facet (original) ---
p17 <- ggplot(
  plot17_long,
  aes(x = marker, y = value, colour = series, shape = series, group = series)
) +
  geom_line(linewidth = 0.7, position = position_dodge(width = 0.25), alpha = 0.9) +
  geom_errorbar(aes(ymin = low, ymax = high),
                width = 0.08,
                linewidth = 0.75,
                position = position_dodge(width = 0.25)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.25)) +
  facet_grid(pc_prag ~ g) +
  scale_colour_manual(values = c("Empirical" = CSP_colors[1], "Model" = CSP_colors[2])) +
  scale_shape_manual(values = c("Empirical" = 16, "Model" = 18)) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 0.75)) +
  labs(
    x = NULL,
    y = "Marker proportion",
    colour = NULL,
    shape = NULL
  ) +
  theme_model() +
  theme(
    axis.text.x = element_text(angle = 18, hjust = 1, vjust = 1),
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    strip.text = element_text(size = 12.5, face = "bold")
  )

save_plot(p17, "fig17_empirical_vs_model_by_condition", w = 9.2, h = 6.2)

# --- Version B: facet by marker, conditions overlaid, empirical + model ---
# Each marker gets its own panel; conditions encoded by color/linetype;
# both empirical (circles) and model (triangles) shown
plot17b_data <- plot17_long |>
  mutate(
    condition = interaction(
      gsub("Prag\\. Controversy: ", "", pc_prag),
      gsub("Goal: ", "", g),
      sep = ", "
    ),
    condition = factor(condition,
                       levels = c("low, low", "low, high",
                                  "high, low", "high, high"),
                       labels = c("low pc, low g",
                                  "low pc, high g",
                                  "high pc, low g",
                                  "high pc, high g")),
    pc_prag_level = gsub("Prag\\. Controversy: ", "", pc_prag)
  )

p17b <- ggplot(
  plot17b_data,
  aes(x = condition, y = value, colour = series, shape = series, group = series)
) +
  geom_line(linewidth = 0.7, position = position_dodge(width = 0.25), alpha = 0.9) +
  geom_errorbar(aes(ymin = low, ymax = high),
                width = 0.12,
                linewidth = 0.6,
                position = position_dodge(width = 0.25)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.25)) +
  facet_wrap(~ marker, nrow = 1) +
  scale_colour_manual(values = c("Empirical" = CSP_colors[1], "Model" = CSP_colors[2])) +
  scale_shape_manual(values = c("Empirical" = 16, "Model" = 17)) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 0.75)) +
  labs(
    x = "Pragmatic controversy, Goal strength",
    y = "Marker proportion",
    colour = NULL,
    shape = NULL
  ) +
  theme_model() +
  theme(
    axis.text.x = element_text(size = 11, angle = 25, hjust = 1),
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    strip.text = element_text(size = 13, face = "bold")
  )

save_plot(p17b, "fig17b_facet_by_marker", w = 10, h = 5)

# --- Version C: facet by marker, conditions on x-axis (empirical + model) ---
# Each marker gets its own panel; easy to see how conditions shift proportions
plot17_facet_marker <- plot17_long |>
  mutate(
    condition = interaction(
      gsub("Prag\\. Controversy: ", "", pc_prag),
      gsub("Goal: ", "", g),
      sep = "\n"
    ),
    condition = factor(condition,
                       levels = c("low\nlow", "low\nhigh",
                                  "high\nlow", "high\nhigh"))
  )

p17c <- ggplot(
  plot17_facet_marker,
  aes(x = condition, y = value, colour = series, shape = series, group = series)
) +
  geom_line(linewidth = 0.7, position = position_dodge(width = 0.25), alpha = 0.9) +
  geom_errorbar(aes(ymin = low, ymax = high),
                width = 0.12,
                linewidth = 0.6,
                position = position_dodge(width = 0.25)) +
  geom_point(size = 2.8, position = position_dodge(width = 0.25)) +
  facet_wrap(~ marker, nrow = 1) +
  scale_colour_manual(values = c("Empirical" = CSP_colors[1], "Model" = CSP_colors[2])) +
  scale_shape_manual(values = c("Empirical" = 16, "Model" = 18)) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 0.75)) +
  labs(
    x = "pc_prag / goal",
    y = "Marker proportion",
    colour = NULL,
    shape = NULL
  ) +
  theme_model() +
  theme(
    legend.position = "top",
    panel.grid.major.x = element_blank(),
    strip.text = element_text(size = 13, face = "bold")
  )

save_plot(p17c, "fig17c_facet_by_marker", w = 10, h = 5)

# ── Figure 18: posterior effects ─────────────────────────────────────────────
full_path <- file.path(DATA_DIR, "fit_brms_full_3markers.rds")
threshold_draws_path <- file.path(DATA_DIR, "fit_threshold_3markers.rds")

posterior_fit <- readRDS(full_path)
posterior_draws <- as_draws_df(posterior_fit)

effect_terms <- c(
  b_pc_prop_c = "pc_prop",
  b_pc_prag_c = "pc_prag",
  b_g_c = "g",
  `b_pc_prag_c:g_c` = "pc_prag:g"
)

top_df <- bind_rows(lapply(names(effect_terms), function(term) {
  tibble(
    parameter = effect_terms[[term]],
    value = posterior_draws[[term]]
  )
})) |>
  mutate(parameter = factor(parameter, levels = c("pc_prop", "pc_prag", "g", "pc_prag:g")))

p18_top <- ggplot(top_df, aes(x = value, y = parameter, fill = parameter)) +
  stat_halfeye(.width = c(0.8, 0.95), point_interval = mean_qi, normalize = "panels") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  scale_fill_manual(values = c(CSP_colors[1], CSP_colors[2], CSP_colors[3], CSP_colors[4])) +
  labs(
    x = "Coefficient on latent marker scale (probit units)",
    y = NULL
  ) +
  theme_model() +
  theme(legend.position = "none")

threshold_draws <- readRDS(threshold_draws_path)
mu_summ <- summarise_draws(
  threshold_draws |> select(starts_with("mu[")),
  mean,
  ~quantile(.x, c(0.025, 0.10, 0.90, 0.975))
) |>
  mutate(
    threshold = factor(variable,
                       levels = c("mu[1]", "mu[2]"),
                       labels = c("soviel -> ja", "ja -> bekanntlich"))
  )

marker_labels <- tibble(
  label = c("soviel ich weiß", "ja", "bekanntlich"),
  x = c(mu_summ$mean[1] - 0.85,
        mean(mu_summ$mean),
        mu_summ$mean[2] + 0.85),
  y = 0.55
)

p18_bottom <- ggplot(mu_summ, aes(x = mean, y = 0.5)) +
  geom_errorbarh(aes(xmin = `2.5%`, xmax = `97.5%`),
                 height = 0.06, colour = CSP_colors[1], linewidth = 1) +
  geom_errorbarh(aes(xmin = `10%`, xmax = `90%`),
                 height = 0, colour = CSP_colors[1], linewidth = 2.5, alpha = 0.55) +
  geom_point(size = 3.8, colour = CSP_colors[1]) +
  geom_text(aes(label = threshold), vjust = -1.3, size = 4.0) +
  geom_text(data = marker_labels,
            aes(x = x, y = y, label = label),
            inherit.aes = FALSE, colour = "#555555", fontface = "italic", size = 3.3) +
  labs(
    x = "Latent utility axis",
    y = NULL
  ) +
  scale_y_continuous(limits = c(0.3, 0.8)) +
  theme_model() +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = element_blank()
  )

save_plot(p18_top, "fig18_parameter_effects", w = 8.2, h = 4.8)
save_plot(p18_bottom, "fig19_thresholds", w = 8.2, h = 3.2)

cat("\nFinal paper figures saved:\n")
cat("  fig17_empirical_vs_model_by_condition\n")
cat("  fig18_parameter_effects\n")
cat("  fig19_thresholds\n")