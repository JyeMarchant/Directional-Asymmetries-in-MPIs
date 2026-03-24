# =============================================================================
#                         BLOCK DRIFT ANALYSIS - E2
#                         Last modified: March 9, 2026
# =============================================================================
#
# This script analyzes trial-by-trial drift in foveal offset for specific
# conditions: flash baseline, central petal, and central fugal.
#
# For each condition, trial number is counted within that condition (not overall).
#
# OUTPUT: One figure per participant showing foveal offset vs trial number

# =============================================================================
#                              LOAD LIBRARIES
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

# =============================================================================
#                           CONFIGURATION
# =============================================================================

# Specify the directory containing CSV files
data_dir <- "/Users/jmar3294/Documents/MATLAB/E2_2026_FLE/EXPERIMENT 2 (JAN 2026)/E2 DATA"

# Output directory for figures
output_dir <- "/Users/jmar3294/Documents/MATLAB/E2_2026_FLE/EXPERIMENT 2 (JAN 2026)/E2 ANALYSIS CODE/block_drift_figures"

# =============================================================================
#                          READ AND PROCESS DATA
# =============================================================================

# List all CSV files matching the pattern
csv_files <- list.files(
  path = data_dir,
  pattern = "^\\d{3}_FLE_E2_.*\\.csv$",
  full.names = TRUE
)

if (length(csv_files) == 0) {
  stop("No CSV files found in the specified directory!")
}

cat(sprintf("Found %d data files\n", length(csv_files)))

# Initialize list to store all participant data for group analysis
all_participant_data <- list()

# Loop through each CSV file
for (file_path in csv_files) {
  
  # Extract subject ID from filename
  filename <- basename(file_path)
  subject_id <- substr(filename, 1, 3)
  
  cat(sprintf("Processing subject %s...\n", subject_id))
  
  # Read the data
  data <- read_csv(file_path, show_col_types = FALSE)
  
  # Filter valid trials only
  data_valid <- data %>%
    filter(valid == "valid")
  
  # -----------------------------------------------------------------------------
  # Create condition data with sequential trial numbers across blocks
  # -----------------------------------------------------------------------------
  
  # Flash baseline
  flash_baseline <- data_valid %>%
    filter(condition == "flashbaseline") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Flash Baseline",
      condition_trial = row_number()
    )
  
  # Central cue - Petal
  central_petal <- data_valid %>%
    filter(condition == "centralcue", motion_direction == "petal") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Central Petal",
      condition_trial = row_number()
    )
  
  # Central cue - Fugal
  central_fugal <- data_valid %>%
    filter(condition == "centralcue", motion_direction == "fugal") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Central Fugal",
      condition_trial = row_number()
    )
  
  # Flash Motion - Petal
  flash_motion_petal <- data_valid %>%
    filter(condition == "flash_motion", motion_direction == "petal") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Flash Motion Petal",
      condition_trial = row_number()
    )
  
  # Flash Motion - Fugal
  flash_motion_fugal <- data_valid %>%
    filter(condition == "flash_motion", motion_direction == "fugal") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Flash Motion Fugal",
      condition_trial = row_number()
    )
  
  # Motion Flash - Petal
  motion_flash_petal <- data_valid %>%
    filter(condition == "motion_flash", motion_direction == "petal") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Motion Flash Petal",
      condition_trial = row_number()
    )
  
  # Motion Flash - Fugal
  motion_flash_fugal <- data_valid %>%
    filter(condition == "motion_flash", motion_direction == "fugal") %>%
    arrange(block, trial) %>%
    mutate(
      condition_label = "Motion Flash Fugal",
      condition_trial = row_number()
    )
  
  # Combine all conditions
  plot_data <- bind_rows(flash_baseline, central_petal, central_fugal,
                         flash_motion_petal, flash_motion_fugal,
                         motion_flash_petal, motion_flash_fugal)
  
  # Add subject ID
  plot_data$subject_id <- subject_id
  
  # Store for group analysis
  all_participant_data[[subject_id]] <- plot_data
  
  # Set factor order
  plot_data$condition_label <- factor(
    plot_data$condition_label,
    levels = c("Flash Baseline", "Central Petal", "Central Fugal",
               "Flash Motion Petal", "Flash Motion Fugal",
               "Motion Flash Petal", "Motion Flash Fugal")
  )
  
  # -----------------------------------------------------------------------------
  # Calculate block boundaries for vertical lines
  # -----------------------------------------------------------------------------
  
  # For each condition, find where blocks change
  block_boundaries <- plot_data %>%
    group_by(condition_label) %>%
    arrange(condition_trial) %>%
    mutate(block_change = block != lag(block, default = first(block))) %>%
    filter(block_change) %>%
    select(condition_label, condition_trial, block) %>%
    ungroup()
  
  # -----------------------------------------------------------------------------
  # Calculate correlation stats for each condition
  # -----------------------------------------------------------------------------
  
  cor_stats <- plot_data %>%
    group_by(condition_label) %>%
    summarise(
      r = cor(condition_trial, foveal_offset, use = "complete.obs"),
      n = n(),
      .groups = 'drop'
    ) %>%
    mutate(
      t_stat = r * sqrt((n - 2) / (1 - r^2)),
      p_value = 2 * pt(-abs(t_stat), df = n - 2),
      sig = case_when(
        p_value < 0.001 ~ "***",
        p_value < 0.01 ~ "**",
        p_value < 0.05 ~ "*",
        TRUE ~ ""
      ),
      label = sprintf("r = %.3f%s", r, sig)
    )
  
  # Get y position for labels (top of each panel)
  label_pos <- plot_data %>%
    group_by(condition_label) %>%
    summarise(
      x_pos = max(condition_trial) * 0.95,
      y_pos = max(foveal_offset, na.rm = TRUE) * 0.9,
      .groups = 'drop'
    )
  
  cor_stats <- cor_stats %>%
    left_join(label_pos, by = "condition_label")
  
  # -----------------------------------------------------------------------------
  # Create the plot - faceted panels with connected points
  # -----------------------------------------------------------------------------
  
  p <- ggplot(plot_data, aes(x = condition_trial, y = foveal_offset)) +
    # Connected line showing evolution
    geom_line(alpha = 0.4, color = "gray40") +
    # Individual points
    geom_point(aes(color = condition_label), alpha = 0.6, size = 1.5) +
    # Trend line
    geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1) +
    # Zero reference line
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    # Block boundary lines
    geom_vline(data = block_boundaries, aes(xintercept = condition_trial - 0.5),
               linetype = "dotted", color = "red", linewidth = 0.8) +
    # Correlation labels
    geom_text(data = cor_stats, aes(x = x_pos, y = y_pos, label = label),
              hjust = 1, vjust = 1, size = 3.5, fontface = "bold") +
    # Facet by condition
    facet_wrap(~condition_label, scales = "free_x", ncol = 4, nrow = 2) +
    # Colors
    scale_color_manual(
      values = c("Flash Baseline" = "#1b9e77", 
                 "Central Petal" = "#d95f02", 
                 "Central Fugal" = "#fc8d62",
                 "Flash Motion Petal" = "#7570b3",
                 "Flash Motion Fugal" = "#a6a1d4",
                 "Motion Flash Petal" = "#e7298a",
                 "Motion Flash Fugal" = "#f49ac2")
    ) +
    labs(
      title = sprintf("Subject %s: Block Drift Analysis", subject_id),
      subtitle = "Foveal offset evolution across trials (red dotted lines = block boundaries)",
      x = "Trial Number (within condition)",
      y = "Foveal Offset (dva)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      legend.position = "none",
      strip.text = element_text(face = "bold", size = 10),
      panel.grid.minor = element_blank(),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 10)
    )
  
  # Save the plot
  output_file <- file.path(output_dir, sprintf("%s_block_drift.png", subject_id))
  ggsave(output_file, p, width = 16, height = 8, dpi = 300)
  
  cat(sprintf("  Saved: %s\n", output_file))
  
  # -----------------------------------------------------------------------------
  # Print correlation summaries
  # -----------------------------------------------------------------------------
  
  cat(sprintf("\n  Correlation summaries for subject %s:\n", subject_id))
  
  for (i in 1:nrow(cor_stats)) {
    cat(sprintf("    %s: r = %.4f, p = %.4f (n = %d)\n", 
                cor_stats$condition_label[i], 
                cor_stats$r[i], 
                cor_stats$p_value[i],
                cor_stats$n[i]))
  }
  cat("\n")
}

# =============================================================================
#                          GROUP AVERAGE ANALYSIS
# =============================================================================

cat("Creating group average plot...\n")

# Combine all participant data
group_data <- bind_rows(all_participant_data)

# Set factor order
group_data$condition_label <- factor(
  group_data$condition_label,
  levels = c("Flash Baseline", "Central Petal", "Central Fugal",
             "Flash Motion Petal", "Flash Motion Fugal",
             "Motion Flash Petal", "Motion Flash Fugal")
)

# Calculate mean and SE for each trial position within each condition
group_summary <- group_data %>%
  group_by(condition_label, condition_trial) %>%
  summarise(
    mean_offset = mean(foveal_offset, na.rm = TRUE),
    se_offset = sd(foveal_offset, na.rm = TRUE) / sqrt(n()),
    n = n(),
    .groups = 'drop'
  )

# Calculate block boundaries (use first participant as reference)
first_participant <- all_participant_data[[1]]
block_boundaries_group <- first_participant %>%
  group_by(condition_label) %>%
  arrange(condition_trial) %>%
  mutate(block_change = block != lag(block, default = first(block))) %>%
  filter(block_change) %>%
  select(condition_label, condition_trial, block) %>%
  ungroup()

# Calculate correlation stats for group average
cor_stats_group <- group_summary %>%
  group_by(condition_label) %>%
  summarise(
    r = cor(condition_trial, mean_offset, use = "complete.obs"),
    n = n(),
    .groups = 'drop'
  ) %>%
  mutate(
    t_stat = r * sqrt((n - 2) / (1 - r^2)),
    p_value = 2 * pt(-abs(t_stat), df = n - 2),
    sig = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ ""
    ),
    label = sprintf("r = %.3f%s", r, sig)
  )

# Get y position for labels
label_pos_group <- group_summary %>%
  group_by(condition_label) %>%
  summarise(
    x_pos = max(condition_trial) * 0.95,
    y_pos = max(mean_offset + se_offset, na.rm = TRUE) * 0.9,
    .groups = 'drop'
  )

cor_stats_group <- cor_stats_group %>%
  left_join(label_pos_group, by = "condition_label")

# -----------------------------------------------------------------------------
# Create group average plot
# -----------------------------------------------------------------------------

p_group <- ggplot(group_summary, aes(x = condition_trial, y = mean_offset)) +
  # Error ribbon
  geom_ribbon(aes(ymin = mean_offset - se_offset, ymax = mean_offset + se_offset,
                  fill = condition_label), alpha = 0.3) +
  # Connected line showing evolution
  geom_line(aes(color = condition_label), linewidth = 0.8) +
  # Individual points
  geom_point(aes(color = condition_label), size = 1.5) +
  # Trend line
  geom_smooth(method = "lm", se = FALSE, color = "black", linewidth = 1, linetype = "dashed") +
  # Zero reference line
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  # Block boundary lines
  geom_vline(data = block_boundaries_group, aes(xintercept = condition_trial - 0.5),
             linetype = "dotted", color = "red", linewidth = 0.8) +
  # Correlation labels
  geom_text(data = cor_stats_group, aes(x = x_pos, y = y_pos, label = label),
            hjust = 1, vjust = 1, size = 3.5, fontface = "bold") +
  # Facet by condition
  facet_wrap(~condition_label, scales = "free_x", ncol = 4, nrow = 2) +
  # Colors
  scale_color_manual(
    values = c("Flash Baseline" = "#1b9e77", 
               "Central Petal" = "#d95f02", 
               "Central Fugal" = "#fc8d62",
               "Flash Motion Petal" = "#7570b3",
               "Flash Motion Fugal" = "#a6a1d4",
               "Motion Flash Petal" = "#e7298a",
               "Motion Flash Fugal" = "#f49ac2")
  ) +
  scale_fill_manual(
    values = c("Flash Baseline" = "#1b9e77", 
               "Central Petal" = "#d95f02", 
               "Central Fugal" = "#fc8d62",
               "Flash Motion Petal" = "#7570b3",
               "Flash Motion Fugal" = "#a6a1d4",
               "Motion Flash Petal" = "#e7298a",
               "Motion Flash Fugal" = "#f49ac2")
  ) +
  labs(
    title = sprintf("Group Average: Block Drift Analysis (N = %d)", length(all_participant_data)),
    subtitle = "Mean foveal offset (±SE) across trials (red dotted lines = block boundaries)",
    x = "Trial Number (within condition)",
    y = "Foveal Offset (dva)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    strip.text = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 10)
  )

# Save the group plot
output_file_group <- file.path(output_dir, "GROUP_block_drift.png")
ggsave(output_file_group, p_group, width = 16, height = 8, dpi = 300)

cat(sprintf("Saved group plot: %s\n", output_file_group))

# Print group correlation summaries
cat("\nGroup correlation summaries:\n")
for (i in 1:nrow(cor_stats_group)) {
  cat(sprintf("  %s: r = %.4f, p = %.4f\n", 
              cor_stats_group$condition_label[i], 
              cor_stats_group$r[i], 
              cor_stats_group$p_value[i]))
}

cat("\nBlock drift analysis complete!\n")
