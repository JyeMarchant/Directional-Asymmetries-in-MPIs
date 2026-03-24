# =============================================================================
#                     FLE EXPERIMENT 2 - INDIVIDUAL SUMMARY PLOTS
#                           plot_FLE_E2_summary.R
# =============================================================================
#
# Loops over all participant CSV files and saves two plots per participant:
#   1. Condition offsets (mean ± SEM per condition)
#   2. Flash-Lag Effect — estimated petal and fugal only
#
# =============================================================================

rm(list = ls())

library(ggplot2)
library(dplyr)
library(patchwork)

# =============================================================================
# Locate data folder
# =============================================================================

if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  data_folder <- file.path(dirname(rstudioapi::getSourceEditorContext()$path), "../E2 DATA")
} else if (file.exists("../E2 DATA")) {
  data_folder <- "../E2 DATA"
} else {
  data_folder <- "/Users/jmar3294/Documents/MATLAB/E2_2026_FLE/EXPERIMENT 2 (JAN 2026)/E2 DATA"
}

csv_files <- list.files(data_folder, pattern = "^\\d{3}_FLE_E2_.*\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) stop("No data files found in: ", data_folder)

cat("Found", length(csv_files), "participant files\n")

# =============================================================================
# Shared settings
# =============================================================================

cond_dir_levels <- c("Flash\nBaseline",
                     "Central Cue\nPetal", "Central Cue\nFugal",
                     "Flash+Mot\nPetal",   "Flash+Mot\nFugal",
                     "Motion+Fl\nPetal",   "Motion+Fl\nFugal")

bar_colors <- c(
  "Flash\nBaseline"    = "#7EA8D9",
  "Central Cue\nPetal" = "#F4A5A5", "Central Cue\nFugal" = "#C75D5D",
  "Flash+Mot\nPetal"   = "#A8E6CF", "Flash+Mot\nFugal"   = "#56B88A",
  "Motion+Fl\nPetal"   = "#FFD89B", "Motion+Fl\nFugal"   = "#E6A84D"
)

fle_colors <- c("Petal" = "#B8A9E8", "Fugal" = "#7B5DC2")

sem <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))

theme_indiv <- function(...) {
  theme_minimal() +
    theme(
      axis.text.y        = element_text(size = 10),
      legend.position    = "none",
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 0.8),
      plot.margin        = margin(5, 5, 60, 5),
      ...
    )
}

# =============================================================================
# Loop over participants
# =============================================================================

for (csv_file in csv_files) {
  
  participant <- substr(basename(csv_file), 1, 3)
  cat("Processing participant", participant, "...\n")
  
  data <- read.csv(csv_file) %>%
    mutate(
      cond_dir = factor(case_when(
        condition == "flashbaseline"                               ~ "Flash\nBaseline",
        condition == "centralcue"   & motion_direction == "petal" ~ "Central Cue\nPetal",
        condition == "centralcue"   & motion_direction == "fugal" ~ "Central Cue\nFugal",
        condition == "flash_motion" & motion_direction == "petal" ~ "Flash+Mot\nPetal",
        condition == "flash_motion" & motion_direction == "fugal" ~ "Flash+Mot\nFugal",
        condition == "motion_flash" & motion_direction == "petal" ~ "Motion+Fl\nPetal",
        condition == "motion_flash" & motion_direction == "fugal" ~ "Motion+Fl\nFugal"
      ), levels = cond_dir_levels)
    )
  
  # --- Figure 1: Condition offsets ---
  
  summary_data <- data %>%
    filter(valid == "valid") %>%
    group_by(cond_dir) %>%
    summarise(mean_offset = mean(foveal_offset, na.rm = TRUE),
              sem         = sem(foveal_offset),
              .groups = "drop")
  
  p1 <- ggplot(summary_data, aes(x = cond_dir, y = mean_offset, fill = cond_dir)) +
    geom_col(width = 0.7, color = "grey30", linewidth = 0.4, alpha = 0.85) +
    geom_errorbar(aes(ymin = mean_offset - sem, ymax = mean_offset + sem),
                  width = 0.2, linewidth = 0.6) +
    geom_text(aes(y = mean_offset + sem + 0.3,
                  label = sprintf("%.2f\n±%.2f", mean_offset, sem)),
              vjust = 0, size = 2.5, color = "grey20", lineheight = 0.85) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.6) +
    geom_vline(xintercept = c(1.5, 3.5, 5.5), color = "grey80", linewidth = 0.4) +
    scale_fill_manual(values = bar_colors) +
    labs(title = paste0("Condition Offsets — Subject ", participant),
         subtitle = "Light = Petal | Dark = Fugal",
         x = "", y = "Foveal Offset (DVA)") +
    theme_indiv(plot.title    = element_text(size = 14, face = "bold", hjust = 0.5),
                plot.subtitle = element_text(size = 9, hjust = 0.5, color = "grey50"),
                axis.text.x   = element_text(size = 8, lineheight = 0.9),
                axis.title.y  = element_text(size = 11)) +
    coord_cartesian(clip = "off")
  
  # --- Figure 2: Flash-Lag Effect (estimated only) ---
  
  cond_means <- data %>%
    filter(valid == "valid") %>%
    group_by(condition, motion_direction) %>%
    summarise(mean_offset = mean(foveal_offset, na.rm = TRUE),
              sem         = sem(foveal_offset),
              .groups = "drop")
  
  get_mean <- function(cond, dir) {
    cond_means$mean_offset[cond_means$condition == cond & cond_means$motion_direction == dir]
  }
  get_sem <- function(cond, dir) {
    cond_means$sem[cond_means$condition == cond & cond_means$motion_direction == dir]
  }
  
  fle_data <- data.frame(
    direction = factor(c("Petal", "Fugal"), levels = c("Petal", "Fugal")),
    fle = c(
      get_mean("flash_motion", "petal") - get_mean("motion_flash", "petal"),
      get_mean("motion_flash", "fugal") - get_mean("flash_motion", "fugal")
    ),
    sem = c(
      sqrt(get_sem("flash_motion", "petal")^2 + get_sem("motion_flash", "petal")^2),
      sqrt(get_sem("motion_flash", "fugal")^2 + get_sem("flash_motion", "fugal")^2)
    )
  )
  
  p2 <- ggplot(fle_data, aes(x = direction, y = fle, fill = direction)) +
    geom_col(width = 0.65, color = "grey30", linewidth = 0.4, alpha = 0.85) +
    geom_errorbar(aes(ymin = fle - sem, ymax = fle + sem),
                  width = 0.2, linewidth = 0.6) +
    geom_text(aes(y = fle + sem + 0.2,
                  label = sprintf("%.2f\n±%.2f", fle, sem)),
              vjust = 0, size = 2.8, color = "grey20", lineheight = 0.85) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.6) +
    scale_fill_manual(values = fle_colors) +
    labs(title = paste0("Flash-Lag Effect — Subject ", participant),
         subtitle = "+ve = lag | -ve = lead",
         x = "", y = "FLE (DVA)") +
    theme_indiv(plot.title    = element_text(size = 14, face = "bold", hjust = 0.5),
                plot.subtitle = element_text(size = 9, hjust = 0.5, color = "grey50"),
                axis.text.x   = element_text(size = 10),
                axis.title.y  = element_text(size = 11)) +
    coord_cartesian(clip = "off")
  
  # --- Combine and save ---
  
  combined <- p1 | p2
  
  output_file <- file.path(data_folder, paste0(participant, "_FLE_E2_summary.png"))
  ggsave(output_file, combined, width = 14, height = 6, dpi = 300)
  cat("  Saved:", output_file, "\n")
}

cat("\nDone. Plots saved for", length(csv_files), "participants.\n")