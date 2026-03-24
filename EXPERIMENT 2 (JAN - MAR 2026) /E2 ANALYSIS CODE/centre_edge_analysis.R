# =============================================================================
#               FLE EXPERIMENT 2 - CONDITION OFFSETS BY PROBE START POSITION
#                         plot_FLE_E2_probe_start.R
# =============================================================================
#
# Replicates the group-level condition offset plot (Figure 1 from
# plot_FLE_E2_group.R) but splits trials by whether the probe started
# at centre or at a peripheral position.
#
# OUTPUT:
#   Condition offsets (group mean ± SEM) × probe start position
#   Saved as PDF and PNG to the data folder.
#
# =============================================================================

rm(list = ls())

if (!requireNamespace("afex",    quietly = TRUE)) install.packages("afex")
if (!requireNamespace("emmeans", quietly = TRUE)) install.packages("emmeans")

library(ggplot2)
library(dplyr)
library(tidyr)
library(afex)
library(emmeans)

# =============================================================================
# Locate data folder — mirrors logic in plot_FLE_E2_group.R
# =============================================================================

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  data_folder <- file.path(dirname(rstudioapi::getSourceEditorContext()$path), "../E2 DATA")
} else if (file.exists("../E2 DATA")) {
  data_folder <- "../E2 DATA"
} else if (file.exists("EXPERIMENT 2 (JAN 2026)/E2 DATA")) {
  data_folder <- "EXPERIMENT 2 (JAN 2026)/E2 DATA"
} else {
  data_folder <- "/Users/jmar3294/Documents/MATLAB/E2_2026_FLE/EXPERIMENT 2 (JAN 2026)/E2 DATA"
}

# =============================================================================
# Load and combine all participant data
# =============================================================================

csv_files <- list.files(data_folder, pattern = "^\\d{3}_FLE_E2_.*\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) stop("No data files found in: ", data_folder)

cat("Found", length(csv_files), "participant files:\n")
cat(paste(" -", basename(csv_files)), sep = "\n")

all_data <- lapply(csv_files, function(f) {
  df <- read.csv(f)
  df$participant <- substr(basename(f), 1, 3)
  df
}) %>% bind_rows()

cat("\nTotal trials loaded:", nrow(all_data), "\n")
cat("Participants:", paste(unique(all_data$participant), collapse = ", "), "\n")

N <- length(unique(all_data$participant))

# =============================================================================
# Derive condition labels and probe start grouping
# =============================================================================

cond_dir_levels <- c(
  "Flash\nBaseline",
  "Central Cue\nPetal", "Central Cue\nFugal",
  "Flash+Mot\nPetal",   "Flash+Mot\nFugal",
  "Motion+Fl\nPetal",   "Motion+Fl\nFugal"
)

all_data <- all_data %>%
  mutate(
    cond_dir = factor(case_when(
      condition == "flashbaseline"                               ~ "Flash\nBaseline",
      condition == "centralcue"   & motion_direction == "petal" ~ "Central Cue\nPetal",
      condition == "centralcue"   & motion_direction == "fugal" ~ "Central Cue\nFugal",
      condition == "flash_motion" & motion_direction == "petal" ~ "Flash+Mot\nPetal",
      condition == "flash_motion" & motion_direction == "fugal" ~ "Flash+Mot\nFugal",
      condition == "motion_flash" & motion_direction == "petal" ~ "Motion+Fl\nPetal",
      condition == "motion_flash" & motion_direction == "fugal" ~ "Motion+Fl\nFugal"
    ), levels = cond_dir_levels),
    
    # Classify probe start as Centre vs Peripheral
    probe_start = factor(
      ifelse(probe_initial == "centre", "Centre Start", "Peripheral Start"),
      levels = c("Centre Start", "Peripheral Start")
    )
  )

# =============================================================================
# Helper
# =============================================================================

sem <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))

# =============================================================================
# Compute participant means, then group summary — split by probe_start
# =============================================================================

participant_means <- all_data %>%
  filter(valid == "valid", !is.na(cond_dir), !is.na(probe_start)) %>%
  group_by(participant, probe_start, cond_dir) %>%
  summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop")

group_summary <- participant_means %>%
  group_by(probe_start, cond_dir) %>%
  summarise(
    mean = mean(mean_offset, na.rm = TRUE),
    se   = sem(mean_offset),
    .groups = "drop"
  )

# Numeric x positions — defined here so both stats and plot sections can use it
dodge_width <- 0.5

cond_x <- tibble(
  cond_dir = factor(cond_dir_levels, levels = cond_dir_levels),
  x_int    = seq_along(cond_dir_levels),
  x_centre = seq_along(cond_dir_levels) - dodge_width / 2,
  x_periph = seq_along(cond_dir_levels) + dodge_width / 2
)

# =============================================================================
# 2-way repeated-measures ANOVA: cond_dir × probe_start
# Then Bonferroni-corrected paired t-tests: centre vs peripheral within each condition
# =============================================================================

anova_fit <- afex::aov_ez(
  id      = "participant",
  dv      = "mean_offset",
  within  = c("cond_dir", "probe_start"),
  data    = participant_means
)

cat("\n=== ANOVA: cond_dir × probe_start ===\n")
print(anova_fit)

# Bonferroni pairwise contrasts: probe_start within each cond_dir
emm <- emmeans::emmeans(anova_fit, ~ probe_start | cond_dir)
contrasts_df <- as.data.frame(
  emmeans::contrast(emm, method = "pairwise", adjust = "bonferroni")
)

cat("\n=== Bonferroni contrasts: Centre vs Peripheral within each condition ===\n")
print(contrasts_df)

# Build significance label lookup keyed by cond_dir
sig_label <- function(p) {
  dplyr::case_when(
    p < .001 ~ "***",
    p < .01  ~ "**",
    p < .05  ~ "*",
    TRUE     ~ ""
  )
}

contrasts_df <- contrasts_df %>%
  mutate(star = sig_label(p.value))

# Position stars just above the higher of the two group means for each condition
star_positions <- group_summary %>%
  group_by(cond_dir) %>%
  summarise(y_pos = max(mean) + max(se) + 0.15, .groups = "drop") %>%
  left_join(contrasts_df %>% select(cond_dir, star), by = "cond_dir") %>%
  left_join(cond_x %>% select(cond_dir, x_int), by = "cond_dir") %>%
  filter(star != "")

# =============================================================================
# Color palette — matches plot_FLE_E2_group.R
# =============================================================================

bar_colors <- c(
  "Flash\nBaseline"    = "#7EA8D9",
  "Central Cue\nPetal" = "#F4A5A5", "Central Cue\nFugal" = "#C75D5D",
  "Flash+Mot\nPetal"   = "#A8E6CF", "Flash+Mot\nFugal"   = "#56B88A",
  "Motion+Fl\nPetal"   = "#FFD89B", "Motion+Fl\nFugal"   = "#E6A84D"
)

# =============================================================================
# Shared theme — matches plot_FLE_E2_group.R
# =============================================================================

theme_fle <- function() {
  theme_minimal() +
    theme(
      axis.text.x        = element_text(size = 8),
      axis.text.y        = element_text(size = 8),
      legend.position    = "none",
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 0.8),
      plot.margin        = margin(4, 4, 4, 4)
    )
}

# =============================================================================
# Build single plot with centre vs peripheral dodged within each condition
# =============================================================================

dodge_width <- 0.5

# ggplot places discrete factor levels at x = 1, 2, 3, ...
# position_dodge(0.5) offsets the two groups by ±0.25 around that integer
cond_x <- tibble(
  cond_dir = factor(cond_dir_levels, levels = cond_dir_levels),
  x_int    = seq_along(cond_dir_levels),
  x_centre = seq_along(cond_dir_levels) - dodge_width / 2,
  x_periph = seq_along(cond_dir_levels) + dodge_width / 2
)

# Wide format: one row per participant × condition, y for each probe_start
segments_df <- participant_means %>%
  pivot_wider(names_from = probe_start, values_from = mean_offset) %>%
  left_join(cond_x, by = "cond_dir") %>%
  rename(y_centre = `Centre Start`, y_periph = `Peripheral Start`) %>%
  filter(!is.na(y_centre), !is.na(y_periph))

# Add numeric x to group_summary and participant_means for consistent coordinates
group_summary <- group_summary %>%
  left_join(cond_x %>% select(cond_dir, x_int, x_centre, x_periph), by = "cond_dir") %>%
  mutate(x_num = ifelse(probe_start == "Centre Start", x_centre, x_periph))

participant_means <- participant_means %>%
  left_join(cond_x %>% select(cond_dir, x_int, x_centre, x_periph), by = "cond_dir") %>%
  mutate(x_num = ifelse(probe_start == "Centre Start", x_centre, x_periph))

combined <- ggplot(group_summary, aes(x = x_num, y = mean,
                                      color = cond_dir, shape = probe_start)) +
  
  # Zero reference line
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.5) +
  
  # Lines connecting each participant's centre dot to their peripheral dot
  geom_segment(
    data        = segments_df,
    aes(x = x_centre, xend = x_periph, y = y_centre, yend = y_periph),
    inherit.aes = FALSE,
    alpha       = 0.25, linewidth = 0.35, color = "grey40"
  ) +
  
  # Individual participant points
  geom_point(
    data  = participant_means,
    aes(x = x_num, y = mean_offset),
    size  = 1.5, alpha = 0.5
  ) +
  
  # Group mean points
  geom_point(size = 3.5) +
  
  # Error bars (± 1 SEM)
  geom_errorbar(
    aes(ymin = mean - se, ymax = mean + se),
    width = 0.1, linewidth = 0.7
  ) +
  
  # Significance stars (Bonferroni centre vs peripheral within condition)
  geom_text(
    data        = star_positions,
    aes(x = x_int, y = y_pos, label = star),
    inherit.aes = FALSE,
    size        = 5,
    color       = "black"
  ) +
  
  scale_x_continuous(
    breaks = cond_x$x_int,
    labels = gsub("\n", "\n", cond_dir_levels)
  ) +
  
  scale_color_manual(values = bar_colors, guide = "none") +
  scale_shape_manual(
    name   = "Probe Start",
    values = c("Centre Start" = 18, "Peripheral Start" = 16)
  ) +
  
  labs(
    x     = NULL,
    y     = "Foveal Offset (DVA)"
  ) +
  
  theme_fle() +
  theme(
    legend.position    = "bottom",
    legend.title       = element_text(size = 9, face = "bold"),
    legend.text        = element_text(size = 9)
  )

combined <- combined +
  labs(
    title   = paste0("Condition Offsets by Probe Start Position — Experiment 2 (N = ", N, ")"),
    caption = "Points = individual participants. Shape = probe start position. Group mean ± SEM. Stars = Bonferroni-corrected paired t-tests (centre vs peripheral within condition). *p < .05, **p < .01, ***p < .001."
  ) +
  theme(
    plot.title   = element_text(size = 13, face = "bold", hjust = 0.5),
    plot.caption = element_text(size = 7, color = "grey45", hjust = 0,
                                margin = margin(t = 6))
  )

output_pdf <- file.path(data_folder, "FLE_E2_by_probe_start.pdf")
output_png <- file.path(data_folder, "FLE_E2_by_probe_start.png")

ggsave(output_pdf, combined, width = 12, height = 6, device = "pdf")
ggsave(output_png, combined, width = 12, height = 6, dpi = 200)

cat("\nSaved to:\n", output_pdf, "\n", output_png, "\n")
cat("\n=== DONE ===\n")