# =============================================================================
#                    SPATIAL BIAS ANALYSIS - EXPERIMENT 2 (v3)
#                         Created: February 24, 2026
# =============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

# =============================================================================
#                           CONFIGURATION
# =============================================================================

data_dir <- "/Users/jmar3294/Documents/MATLAB/E2_2026_FLE/EXPERIMENT 2 (JAN 2026)/E2 DATA"
output_pdf <- "/Users/jmar3294/Documents/MATLAB/E2_2026_FLE/EXPERIMENT 2 (JAN 2026)/E2 ANALYSIS CODE/spatial_biases_E2_report.pdf"

# =============================================================================
#                        HELPER FUNCTIONS
# =============================================================================

ste <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))

format_p <- function(p) {
  if (p < 0.001) return("p < .001")
  if (p < 0.01) return(sprintf("p = %.3f", p))
  return(sprintf("p = %.2f", p))
}

# =============================================================================
#                          READ DATA
# =============================================================================

csv_files <- list.files(path = data_dir, pattern = "^\\d{3}_FLE_E2_.*\\.csv$", full.names = TRUE)
cat(sprintf("Found %d data files\n", length(csv_files)))

all_data <- do.call(rbind, lapply(csv_files, function(f) {
  d <- read_csv(f, show_col_types = FALSE)
  d$subject <- substr(basename(f), 1, 3)
  d
}))

data_valid <- all_data %>% filter(valid == "valid")
cat(sprintf("Valid trials: %d / %d\n", nrow(data_valid), nrow(all_data)))

# =============================================================================
#                     COMPUTE BIAS MEASURES
# =============================================================================

data_valid <- data_valid %>%
  mutate(
    vertical_hemifield   = ifelse(target_y_dva > 0, "upper", "lower"),
    horizontal_hemifield = ifelse(target_x_dva > 0, "right", "left"),
    y_toward_horiz_meridian = ifelse(vertical_hemifield   == "upper", -y_offset, y_offset),
    x_toward_vert_meridian  = ifelse(horizontal_hemifield == "right", -x_offset, x_offset)
  )

# Per-participant means by quadrant, condition, and motion direction
participant_by_quadrant_cond <- data_valid %>%
  group_by(subject, quadrant, condition, motion_direction) %>%
  summarise(
    mean_x_offset = mean(x_offset, na.rm = TRUE),
    mean_y_offset = mean(y_offset, na.rm = TRUE),
    n = n(),
    .groups = 'drop'
  ) %>%
  mutate(quadrant_label = gsub("_", " ", quadrant))

# Per-participant meridian biases (overall)
participant_means <- data_valid %>%
  group_by(subject) %>%
  summarise(
    mean_toward_horiz_meridian = mean(y_toward_horiz_meridian, na.rm = TRUE),
    mean_toward_vert_meridian  = mean(x_toward_vert_meridian,  na.rm = TRUE),
    .groups = 'drop'
  )

# =============================================================================
#                         STATISTICAL TESTS
# =============================================================================

test_horiz_meridian <- t.test(participant_means$mean_toward_horiz_meridian, mu = 0)
test_vert_meridian  <- t.test(participant_means$mean_toward_vert_meridian,  mu = 0)

# =============================================================================
#                         CREATE PDF
# =============================================================================

max_abs    <- max(c(abs(participant_by_quadrant_cond$mean_x_offset),
                    abs(participant_by_quadrant_cond$mean_y_offset)), na.rm = TRUE)
axis_limit <- max_abs + 0.15

foveal_lines <- data.frame(
  quadrant_label = c("upper left", "upper right", "lower left", "lower right"),
  x_end = c(1, -1,  1, -1) * axis_limit,
  y_end = c(-1, -1, 1,  1) * axis_limit
)

condition_labels <- c(
  "flashbaseline" = "Flash Baseline",
  "centralcue"    = "Central Cue",
  "flash_motion"  = "Flash + Motion",
  "motion_flash"  = "Motion + Flash"
)

pdf(output_pdf, width = 10, height = 8)

# ----- PAGE 1: All conditions averaged -----
plot_data_all <- data_valid %>%
  group_by(subject, quadrant) %>%
  summarise(
    mean_x_offset = mean(x_offset, na.rm = TRUE),
    mean_y_offset = mean(y_offset, na.rm = TRUE),
    n = n(),
    .groups = 'drop'
  ) %>%
  mutate(quadrant_label = gsub("_", " ", quadrant))

p_all <- ggplot(plot_data_all, aes(x = mean_x_offset, y = mean_y_offset, color = subject)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_segment(data = foveal_lines, aes(x = 0, y = 0, xend = x_end, yend = y_end),
               color = "red", linewidth = 0.5, inherit.aes = FALSE) +
  geom_point(size = 3, alpha = 0.8) +
  facet_wrap(~ factor(quadrant_label, levels = c("upper left", "upper right",
                                                 "lower left", "lower right")),
             nrow = 2) +
  labs(
    title    = "Spatial Bias by Quadrant: All Conditions",
    subtitle = sprintf("N = %d participants, %d trials (red line = foveal direction)",
                       length(unique(plot_data_all$subject)), nrow(data_valid)),
    x = "X Offset (dva)", y = "Y Offset (dva)", color = "Subject"
  ) +
  theme_bw(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    strip.background = element_rect(fill = "lightgray"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "right"
  ) +
  coord_fixed(ratio = 1, xlim = c(-axis_limit, axis_limit), ylim = c(-axis_limit, axis_limit))

print(p_all)

# ----- PAGE 2: Flash Baseline -----
plot_data_fb <- participant_by_quadrant_cond %>%
  filter(condition == "flashbaseline") %>%
  group_by(subject, quadrant, quadrant_label) %>%
  summarise(
    mean_x_offset = mean(mean_x_offset, na.rm = TRUE),
    mean_y_offset = mean(mean_y_offset, na.rm = TRUE),
    n = sum(n),
    .groups = 'drop'
  )

p_fb <- ggplot(plot_data_fb, aes(x = mean_x_offset, y = mean_y_offset)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_segment(data = foveal_lines, aes(x = 0, y = 0, xend = x_end, yend = y_end),
               color = "red", linewidth = 0.5, inherit.aes = FALSE) +
  geom_point(size = 3, alpha = 0.8, color = "#9B59B6") +
  facet_wrap(~ factor(quadrant_label, levels = c("upper left", "upper right",
                                                 "lower left", "lower right")),
             nrow = 2) +
  labs(
    title    = "Spatial Bias by Quadrant: Flash Baseline",
    subtitle = sprintf("N = %d participants, %d trials (red line = foveal direction)",
                       length(unique(plot_data_fb$subject)), sum(plot_data_fb$n)),
    x = "X Offset (dva)", y = "Y Offset (dva)"
  ) +
  theme_bw(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 14),
    strip.background = element_rect(fill = "lightgray"),
    strip.text       = element_text(face = "bold"),
    legend.position  = "none"
  ) +
  coord_fixed(ratio = 1, xlim = c(-axis_limit, axis_limit), ylim = c(-axis_limit, axis_limit))

print(p_fb)

# ----- PAGES 3-5: Motion conditions (petal vs fugal) -----
motion_conditions <- c("centralcue", "flash_motion", "motion_flash")

for (cond in motion_conditions) {
  
  plot_data     <- participant_by_quadrant_cond %>% filter(condition == cond)
  n_trials_cond <- sum(plot_data$n)
  
  p <- ggplot(plot_data, aes(x = mean_x_offset, y = mean_y_offset,
                             color = motion_direction)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_segment(data = foveal_lines, aes(x = 0, y = 0, xend = x_end, yend = y_end),
                 color = "red", linewidth = 0.5, inherit.aes = FALSE) +
    geom_point(size = 3, alpha = 0.8) +
    facet_wrap(~ factor(quadrant_label, levels = c("upper left", "upper right",
                                                   "lower left", "lower right")),
               nrow = 2) +
    scale_color_manual(values = c("petal" = "#E41A1C", "fugal" = "#377EB8"),
                       labels = c("petal" = "Petal",   "fugal" = "Fugal")) +
    labs(
      title    = sprintf("Spatial Bias by Quadrant: %s", condition_labels[cond]),
      subtitle = sprintf("N = %d participants, %d trials (red line = foveal direction)",
                         length(unique(plot_data$subject)), n_trials_cond),
      x = "X Offset (dva)", y = "Y Offset (dva)", color = "Motion"
    ) +
    theme_bw(base_size = 12) +
    theme(
      plot.title       = element_text(face = "bold", size = 14),
      strip.background = element_rect(fill = "lightgray"),
      strip.text       = element_text(face = "bold"),
      legend.position  = "right"
    ) +
    coord_fixed(ratio = 1, xlim = c(-axis_limit, axis_limit), ylim = c(-axis_limit, axis_limit))
  
  print(p)
}

dev.off()

cat(sprintf("\nPDF saved: %s\n", output_pdf))
cat("\n=== MERIDIAN ATTRACTION SUMMARY ===\n")
cat(sprintf("Horizontal: M = %.3f (SE = %.3f), t(%d) = %.2f, %s\n",
            mean(participant_means$mean_toward_horiz_meridian),
            ste(participant_means$mean_toward_horiz_meridian),
            test_horiz_meridian$parameter,
            test_horiz_meridian$statistic,
            format_p(test_horiz_meridian$p.value)))
cat(sprintf("Vertical:   M = %.3f (SE = %.3f), t(%d) = %.2f, %s\n",
            mean(participant_means$mean_toward_vert_meridian),
            ste(participant_means$mean_toward_vert_meridian),
            test_vert_meridian$parameter,
            test_vert_meridian$statistic,
            format_p(test_vert_meridian$p.value)))

# =============================================================================
# PER-PARTICIPANT PAGES: Real DVA space — arrow from target (flash) to probe
# One arrow per trial. Quadrants displayed in correct spatial positions.
# Layout: 2×2 grid of conditions, each with 4-quadrant facets inside.
# =============================================================================

output_pdf_indiv <- sub("\\.pdf$", "_individual.pdf", output_pdf)
pdf(output_pdf_indiv, width = 14, height = 12)

cond_info <- list(
  flashbaseline = list(label = "Flash (Baseline)",                     by_dir = FALSE, color = "#9B59B6"),
  flash_motion  = list(label = "Flash Position (Paired)",              by_dir = TRUE),
  centralcue    = list(label = "Moving Object Position (Central Cue)", by_dir = TRUE),
  motion_flash  = list(label = "Moving Object Position (Paired)",      by_dir = TRUE)
)
cond_order  <- c("flashbaseline", "flash_motion", "centralcue", "motion_flash")
dir_colors  <- c("petal" = "#E74C3C", "fugal" = "#3498DB")

# Quadrant factor with spatial layout:
# upper left  | upper right   (row 1)
# lower left  | lower right   (row 2)
# facet_wrap fills left-to-right, top-to-bottom — so this order gives correct geography
quadrant_levels <- c("upper left", "upper right", "lower left", "lower right")

# True target locations are fixed by design — compute once
true_locations <- data_valid %>%
  mutate(quadrant_label = gsub("_", " ", quadrant)) %>%
  group_by(quadrant_label, eccentricity_dva) %>%
  summarise(true_x = mean(target_x_dva, na.rm = TRUE),
            true_y = mean(target_y_dva, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(quadrant_label = factor(quadrant_label, levels = quadrant_levels))

subjects <- sort(unique(data_valid$subject))

for (subj in subjects) {
  
  subj_data <- data_valid %>%
    filter(subject == subj) %>%
    mutate(
      quadrant_label = factor(gsub("_", " ", quadrant), levels = quadrant_levels)
    )
  
  plot_list <- lapply(cond_order, function(cond) {
    
    info <- cond_info[[cond]]
    pd   <- subj_data %>% filter(condition == cond)
    
    hdr_fill <- switch(cond,
                       flashbaseline = "#D6E8F8",
                       centralcue    = "#D6F4E4",
                       flash_motion  = "#FCE0E0",
                       motion_flash  = "#FEE8D6"
    )
    
    # Base plot — free scales so each quadrant panel zooms to its own region
    p <- ggplot() +
      geom_hline(yintercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.3) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.3) +
      # True target location crosses (fixed across participants)
      geom_point(data = true_locations,
                 aes(x = true_x, y = true_y),
                 shape = 3, size = 4, stroke = 1.4, color = "grey20",
                 inherit.aes = FALSE) +
      facet_wrap(~ quadrant_label, nrow = 2, scales = "free") +
      labs(x = "X (dva)", y = "Y (dva)", title = info$label) +
      theme_bw(base_size = 10) +
      theme(
        plot.title       = element_text(face = "bold", size = 10, hjust = 0.5,
                                        margin = margin(b = 4), color = "grey15"),
        plot.background  = element_rect(fill = hdr_fill, color = "black", linewidth = 0.8),
        strip.background = element_rect(fill = "grey88"),
        strip.text       = element_text(size = 7, face = "bold"),
        axis.text        = element_text(size = 7),
        axis.title       = element_text(size = 8),
        legend.position  = if (info$by_dir) "right" else "none",
        legend.title     = element_text(size = 7, face = "bold"),
        legend.text      = element_text(size = 7),
        panel.grid.minor = element_blank()
      )
    
    if (info$by_dir) {
      p <- p +
        geom_segment(data = pd,
                     aes(x = target_x_dva, y = target_y_dva,
                         xend = probe_x_dva, yend = probe_y_dva),
                     color     = "black",
                     arrow     = arrow(length = unit(0.1, "cm"), type = "closed"),
                     linewidth = 0.35, alpha = 0.5) +
        geom_point(data = pd,
                   aes(x = probe_x_dva, y = probe_y_dva, color = motion_direction),
                   size = 1.2, alpha = 0.7) +
        scale_color_manual(values = dir_colors,
                           labels = c("petal" = "Petal", "fugal" = "Fugal"),
                           name   = "Motion")
    } else {
      p <- p +
        geom_segment(data = pd,
                     aes(x = target_x_dva, y = target_y_dva,
                         xend = probe_x_dva, yend = probe_y_dva),
                     color     = "black",
                     arrow     = arrow(length = unit(0.1, "cm"), type = "closed"),
                     linewidth = 0.35, alpha = 0.5) +
        geom_point(data = pd,
                   aes(x = probe_x_dva, y = probe_y_dva),
                   color = "#9B59B6", size = 1.2, alpha = 0.7)
    }
    
    p
  })
  
  page <- (plot_list[[1]] | plot_list[[2]]) /
    (plot_list[[3]] | plot_list[[4]]) +
    plot_annotation(
      title = sprintf("Participant %s — Individual Trials: Flash → Probe (Real DVA Space)", subj),
      theme = theme(plot.title = element_text(size = 13, face = "bold", hjust = 0.5,
                                              margin = margin(b = 8)))
    )
  
  print(page)
}

dev.off()
cat(sprintf("Individual PDF saved: %s\n", output_pdf_indiv))