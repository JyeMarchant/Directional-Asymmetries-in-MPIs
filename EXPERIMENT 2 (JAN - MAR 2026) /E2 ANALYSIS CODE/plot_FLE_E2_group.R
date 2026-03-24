# =============================================================================
#                     FLE EXPERIMENT 2 - GROUP ANALYSIS
#                           plot_FLE_E2_group.R
# =============================================================================

rm(list = ls())

library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)
library(afex)
library(emmeans)
library(gridExtra)
library(grid)

# =============================================================================
# Locate data folder
# =============================================================================

data_folder <- file.path(dirname(rstudioapi::getSourceEditorContext()$path), "../E2 DATA")

# =============================================================================
# Load and combine all participant data
# =============================================================================

csv_files <- list.files(data_folder, pattern = "^\\d{3}_FLE_E2_.*\\.csv$", full.names = TRUE)
if (length(csv_files) == 0) stop("No data files found in: ", data_folder)

all_data <- lapply(csv_files, function(f) {
  df <- read.csv(f)
  df$participant <- substr(basename(f), 1, 3)
  df
}) %>% bind_rows()

write.csv(all_data, file.path(data_folder, "E2_combined_long_format.csv"), row.names = FALSE)

# =============================================================================
# Derive grouping variables and condition labels
# =============================================================================

cond_dir_levels_short <- c("Flash BL", "CC Petal", "CC Fugal",
                           "F+M Petal", "F+M Fugal", "M+F Petal", "M+F Fugal")

cond_dir_levels <- c("Flash\nBaseline",
                     "Central Cue\nPetal", "Central Cue\nFugal",
                     "Flash+Mot\nPetal",   "Flash+Mot\nFugal",
                     "Motion+Fl\nPetal",   "Motion+Fl\nFugal")

all_data <- all_data %>%
  mutate(
    hemifield = case_when(
      quadrant %in% c("upper_left",  "lower_left")  ~ "Left",
      quadrant %in% c("upper_right", "lower_right") ~ "Right"
    ),
    vertical_field = case_when(
      quadrant %in% c("upper_left",  "upper_right") ~ "Upper",
      quadrant %in% c("lower_left",  "lower_right") ~ "Lower"
    ),
    ecc_band = case_when(
      eccentricity_dva == 7  ~ "Inner",
      eccentricity_dva == 11 ~ "Outer"
    ),
    cond_dir = factor(case_when(
      condition == "flashbaseline"                               ~ "Flash\nBaseline",
      condition == "centralcue"   & motion_direction == "petal" ~ "Central Cue\nPetal",
      condition == "centralcue"   & motion_direction == "fugal" ~ "Central Cue\nFugal",
      condition == "flash_motion" & motion_direction == "petal" ~ "Flash+Mot\nPetal",
      condition == "flash_motion" & motion_direction == "fugal" ~ "Flash+Mot\nFugal",
      condition == "motion_flash" & motion_direction == "petal" ~ "Motion+Fl\nPetal",
      condition == "motion_flash" & motion_direction == "fugal" ~ "Motion+Fl\nFugal"
    ), levels = cond_dir_levels),
    cond_dir_short = factor(case_when(
      condition == "flashbaseline"                               ~ "Flash BL",
      condition == "centralcue"   & motion_direction == "petal" ~ "CC Petal",
      condition == "centralcue"   & motion_direction == "fugal" ~ "CC Fugal",
      condition == "flash_motion" & motion_direction == "petal" ~ "F+M Petal",
      condition == "flash_motion" & motion_direction == "fugal" ~ "F+M Fugal",
      condition == "motion_flash" & motion_direction == "petal" ~ "M+F Petal",
      condition == "motion_flash" & motion_direction == "fugal" ~ "M+F Fugal"
    ), levels = cond_dir_levels_short)
  )

N <- length(unique(all_data$participant))

# =============================================================================
# Helper functions
# =============================================================================

sem <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))

compute_fle <- function(data, group_var = NULL) {
  grp_vars <- c("participant", group_var, "condition", "motion_direction")
  data %>%
    filter(valid == "valid", if (!is.null(group_var)) !is.na(.data[[group_var]]) else TRUE) %>%
    group_by(across(all_of(grp_vars))) %>%
    summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(names_from = c(condition, motion_direction),
                values_from = mean_offset, names_sep = "_") %>%
    mutate(
      fle_petal = flash_motion_petal - motion_flash_petal,
      fle_fugal = motion_flash_fugal - flash_motion_fugal
    ) %>%
    select(participant, all_of(group_var), fle_petal, fle_fugal) %>%
    pivot_longer(c(fle_petal, fle_fugal), names_to = "measure", values_to = "fle") %>%
    mutate(direction = factor(ifelse(measure == "fle_petal", "Petal", "Fugal"),
                              levels = c("Petal", "Fugal")))
}

# =============================================================================
# Section header bar
# Built as a standalone ggplot with 4 coloured boxes + labels.
# Stacked above each offset plot via patchwork with a small height ratio.
# The title sits ABOVE this bar (in the main plot's title, with margin pushing
# it up), so the order from top to bottom is:
#   [plot title] → [header bar] → [panel border + data]
#
# Proportional widths: section 1 = 1 bar, sections 2-4 = 2 bars each
# We encode this by making the bar x positions span 1..7 matching the data plot.
# =============================================================================

make_header_bar <- function(title_text = NULL, title_size = 11, yaxis_size = 9) {
  
  hdf <- data.frame(
    xmin  = c(0.5, 1.5, 3.5, 5.5),
    xmax  = c(1.5, 3.5, 5.5, 7.5),
    xmid  = c(1.00, 2.50, 4.50, 6.50),
    label = c(
      "Baseline Flash",
      "Moving Object Position\n(Central Cue)",
      "Flash Position\n(Paired)",
      "Moving Object Position\n(Paired)"
    ),
    fill  = c("#D6E8F8", "#D6F4E4", "#FCE0E0", "#FEE8D6"),
    stringsAsFactors = FALSE
  )
  
  p <- ggplot(hdf) +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = 0.05, ymax = 0.95, fill = fill),
              color = "black", linewidth = 0.8) +
    geom_text(aes(x = xmid, y = 0.5, label = label),
              size = 2.8, fontface = "bold", color = "grey15",
              lineheight = 0.85, vjust = 0.5) +
    scale_fill_identity() +
    scale_x_continuous(limits = c(0.5, 7.5), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1),     expand = c(0, 0),
                       name = "Foveal Offset (DVA)") +
    theme_void() +
    theme(
      plot.margin  = margin(2, 4, 0, 4),
      axis.title.y = element_text(size = yaxis_size, color = "transparent",
                                  angle = 90, vjust = 0.5)
    )
  
  if (!is.null(title_text)) {
    p <- p +
      labs(title = title_text) +
      theme(plot.title = element_text(size = title_size, face = "bold",
                                      hjust = 0.5, margin = margin(b = 3)))
  }
  p
}

# =============================================================================
# Shared base theme — no top margin needed now (title lives in header bar)
# =============================================================================

theme_fle <- function(...) {
  theme_minimal() +
    theme(
      axis.text.y        = element_text(size = 8),
      legend.position    = "none",
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 0.8),
      plot.margin        = margin(0, 4, 4, 4),
      plot.title         = element_blank(),   # title handled by header bar
      ...
    )
}

legend_inset <- list(
  legend.position      = c(0.01, 0.99),
  legend.justification = c(0, 1),
  legend.title         = element_text(size = 7, face = "bold"),
  legend.text          = element_text(size = 7),
  legend.key.size      = unit(0.4, "cm"),
  legend.background    = element_rect(fill = alpha("white", 0.8), color = NA)
)

# =============================================================================
# Color palettes
# =============================================================================

bar_colors <- c(
  "Flash\nBaseline"    = "#4A90D9",
  "Central Cue\nPetal" = "#2ECC71", "Central Cue\nFugal" = "#1A7A44",
  "Flash+Mot\nPetal"   = "#FF6B6B", "Flash+Mot\nFugal"   = "#C0000A",
  "Motion+Fl\nPetal"   = "#FF9966", "Motion+Fl\nFugal"   = "#CC4400"
)
fle_colors  <- c("Petal" = "#9B7FE8", "Fugal" = "#5B2DC2")
hemi_colors <- c("Left"  = "#FF5555", "Right" = "#5599FF")
vert_colors <- c("Upper" = "#44CC44", "Lower" = "#CC44CC")
ecc_colors  <- c("Inner" = "#FF9500", "Outer" = "#00AEEF")

# Tick labels: Petal / Fugal / em-dash only
p1_tick_labels <- c(
  "Flash\nBaseline"    = "\u2014",
  "Central Cue\nPetal" = "Petal", "Central Cue\nFugal" = "Fugal",
  "Flash+Mot\nPetal"   = "Petal", "Flash+Mot\nFugal"   = "Fugal",
  "Motion+Fl\nPetal"   = "Petal", "Motion+Fl\nFugal"   = "Fugal"
)
short_tick_labels <- c(
  "Flash BL"  = "\u2014",
  "CC Petal"  = "Petal", "CC Fugal"  = "Fugal",
  "F+M Petal" = "Petal", "F+M Fugal" = "Fugal",
  "M+F Petal" = "Petal", "M+F Fugal" = "Fugal"
)

# Vertical dividers at section boundaries only
section_divs <- c(1.5, 3.5, 5.5)

# =============================================================================
# FIGURE 1: Condition Offsets — Group Average
# =============================================================================

participant_means <- all_data %>%
  filter(valid == "valid") %>%
  group_by(participant, cond_dir) %>%
  summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop")

group_summary <- participant_means %>%
  group_by(cond_dir) %>%
  summarise(grand_mean = mean(mean_offset, na.rm = TRUE), sem = sem(mean_offset), .groups = "drop")

baseline_stats <- group_summary %>% filter(cond_dir == "Flash\nBaseline")

p1_data <- ggplot(group_summary, aes(x = cond_dir, y = grand_mean, fill = cond_dir)) +
  annotate("rect",
           xmin = -Inf, xmax = Inf,
           ymin = baseline_stats$grand_mean - baseline_stats$sem,
           ymax = baseline_stats$grand_mean + baseline_stats$sem,
           fill = "red", alpha = 0.12) +
  geom_col(width = 0.7, color = "grey30", linewidth = 0.4, alpha = 0.85) +
  geom_point(data = participant_means, aes(y = mean_offset),
             color = "grey40",
             position = position_jitter(width = 0.15), size = 1.5, alpha = 0.5) +
  geom_errorbar(aes(ymin = grand_mean - sem, ymax = grand_mean + sem),
                width = 0.2, linewidth = 0.6) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.6) +
  geom_vline(xintercept = section_divs, color = "grey70", linewidth = 0.4) +
  scale_fill_manual(values = bar_colors) +
  scale_x_discrete(labels = p1_tick_labels) +
  labs(x = "", y = "Foveal Offset (DVA)") +
  theme_fle(axis.text.x  = element_text(size = 9),
            axis.title.y = element_text(size = 9)) +
  coord_cartesian(clip = "off") +
  guides(fill = "none")

# Header bar carries the plot title
p1_header <- make_header_bar(title_text = paste0("Condition Offsets (N = ", N, ")"),
                             title_size = 13, yaxis_size = 9)

# Stack: title+header on top, data panel below
# axes = "l" tells patchwork to align left axes across rows so the header
# x-range lines up with the data panel's actual plot area
p1 <- p1_header / p1_data + plot_layout(heights = c(0.11, 1))

# =============================================================================
# FIGURE 2: Flash-Lag Effect — Group Average
# (no section headers — keep standard theme with title)
# =============================================================================

fle_indiv <- compute_fle(all_data)

fle_summary <- fle_indiv %>%
  group_by(direction) %>%
  summarise(mean_fle = mean(fle, na.rm = TRUE), sem_fle = sem(fle), .groups = "drop") %>%
  mutate(axis_label = paste0(as.character(direction), "\n",
                             sprintf("%.2f \u00b1 %.2f", mean_fle, sem_fle)))

p2 <- ggplot(fle_summary, aes(x = direction, y = mean_fle, fill = direction)) +
  geom_col(width = 0.65, color = "grey30", linewidth = 0.4, alpha = 0.85) +
  geom_point(data = fle_indiv, aes(x = direction, y = fle),
             inherit.aes = FALSE, color = "grey40",
             position = position_jitter(width = 0.1, seed = 42), size = 1.5, alpha = 0.5) +
  geom_errorbar(aes(ymin = mean_fle - sem_fle, ymax = mean_fle + sem_fle),
                width = 0.25, linewidth = 1.0, color = "black") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.6) +
  scale_fill_manual(values = fle_colors) +
  scale_x_discrete(labels = setNames(fle_summary$axis_label, fle_summary$direction)) +
  labs(title = paste0("Flash-Lag Effect (N = ", N, ")"),
       x = "", y = "FLE (DVA)") +
  theme_minimal() +
  theme(
    plot.title         = element_text(size = 13, face = "bold", hjust = 0.5),
    axis.text.x        = element_text(size = 8, lineheight = 0.9),
    axis.text.y        = element_text(size = 8),
    axis.title.y       = element_text(size = 10),
    legend.position    = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.border       = element_rect(color = "black", fill = NA, linewidth = 0.8),
    plot.margin        = margin(4, 4, 4, 4)
  ) +
  coord_cartesian(clip = "off") +
  guides(fill = "none")

# =============================================================================
# FIGURES 3, 3b, 5: Condition Offsets broken down by grouping variable
# =============================================================================

make_offset_plot <- function(data, group_var, group_levels, colors, title, legend_title) {
  part_means <- data %>%
    filter(valid == "valid", !is.na(.data[[group_var]])) %>%
    group_by(participant, .data[[group_var]], cond_dir_short) %>%
    summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop") %>%
    mutate(across(all_of(group_var), ~ factor(.x, levels = group_levels)))
  
  grp_summary <- part_means %>%
    group_by(.data[[group_var]], cond_dir_short) %>%
    summarise(grand_mean = mean(mean_offset, na.rm = TRUE), sem = sem(mean_offset), .groups = "drop")
  
  p_data <- ggplot(grp_summary, aes(x = cond_dir_short, y = grand_mean,
                                    fill = .data[[group_var]])) +
    geom_col(position = position_dodge(0.8), width = 0.7,
             color = "grey30", linewidth = 0.3, alpha = 0.85) +
    geom_point(data = part_means, aes(y = mean_offset, group = .data[[group_var]]),
               color = "grey40",
               position = position_jitterdodge(jitter.width = 0.1, dodge.width = 0.8),
               size = 1.5, alpha = 0.5) +
    geom_errorbar(aes(ymin = grand_mean - sem, ymax = grand_mean + sem),
                  position = position_dodge(0.8), width = 0.2, linewidth = 0.5) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.6) +
    geom_vline(xintercept = section_divs, color = "grey70", linewidth = 0.4) +
    scale_fill_manual(values = colors) +
    scale_x_discrete(labels = short_tick_labels) +
    labs(x = "", y = "Foveal Offset (DVA)", fill = legend_title) +
    theme_fle(axis.text.x  = element_text(size = 8),
              axis.title.y = element_text(size = 8),
              !!!legend_inset) +
    coord_cartesian(clip = "off") +
    guides(fill = guide_legend(title = legend_title), color = "none")
  
  p_header <- make_header_bar(title_text = title, title_size = 11, yaxis_size = 8)
  
  p_header / p_data + plot_layout(heights = c(0.11, 1))
}

p3  <- make_offset_plot(all_data, "hemifield",      c("Left", "Right"),  hemi_colors, "Left vs Right Hemifield",                             "Hemifield")
p3b <- make_offset_plot(all_data, "vertical_field", c("Upper", "Lower"), vert_colors, "Upper vs Lower Visual Field",                         "Visual Field")
p5  <- make_offset_plot(all_data, "ecc_band",       c("Inner", "Outer"), ecc_colors,  "Inner vs Outer Eccentricity \u2014 Condition Offsets", "Eccentricity")

# =============================================================================
# FIGURES 4, 4b, 5b: FLE broken down by grouping variable
# =============================================================================

make_fle_plot <- function(fle_long, group_var, group_levels, colors, title, legend_title) {
  fle_long <- fle_long %>%
    mutate(across(all_of(group_var), ~ factor(.x, levels = group_levels)))
  
  fle_sum <- fle_long %>%
    group_by(.data[[group_var]], direction) %>%
    summarise(mean_fle = mean(fle, na.rm = TRUE), sem = sem(fle), .groups = "drop")
  
  axis_labels <- fle_sum %>%
    group_by(direction) %>%
    summarise(m = mean(mean_fle), s = mean(sem), .groups = "drop") %>%
    mutate(axis_label = paste0(as.character(direction), "\n",
                               sprintf("%.2f \u00b1 %.2f", m, s)))
  
  ggplot(fle_sum, aes(x = direction, y = mean_fle, fill = .data[[group_var]])) +
    geom_col(position = position_dodge(0.8), width = 0.7,
             color = "grey30", linewidth = 0.3, alpha = 0.85) +
    geom_point(data = fle_long, aes(y = fle, group = .data[[group_var]]),
               color = "grey40",
               position = position_jitterdodge(jitter.width = 0.1, dodge.width = 0.8),
               size = 1.5, alpha = 0.5) +
    geom_errorbar(aes(ymin = mean_fle - sem, ymax = mean_fle + sem),
                  position = position_dodge(0.8), width = 0.2, linewidth = 0.5) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40", linewidth = 0.6) +
    scale_fill_manual(values = colors) +
    scale_x_discrete(labels = setNames(axis_labels$axis_label, axis_labels$direction)) +
    labs(title = title, x = "Motion Direction", y = "FLE (DVA)", fill = legend_title) +
    theme_minimal() +
    theme(
      plot.title         = element_text(size = 11, face = "bold", hjust = 0.5),
      axis.text.x        = element_text(size = 8, lineheight = 0.9),
      axis.text.y        = element_text(size = 8),
      axis.title         = element_text(size = 9),
      legend.position    = c(0.01, 0.99),
      legend.justification = c(0, 1),
      legend.title       = element_text(size = 7, face = "bold"),
      legend.text        = element_text(size = 7),
      legend.key.size    = unit(0.4, "cm"),
      legend.background  = element_rect(fill = alpha("white", 0.8), color = NA),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.border       = element_rect(color = "black", fill = NA, linewidth = 0.8),
      plot.margin        = margin(4, 4, 4, 4)
    ) +
    coord_cartesian(clip = "off") +
    guides(fill = guide_legend(title = legend_title), color = "none")
}

p4  <- make_fle_plot(compute_fle(all_data, "hemifield"),      "hemifield",      c("Left", "Right"),  hemi_colors, "FLE by Left/Right Hemifield",         "Hemifield")
p4b <- make_fle_plot(compute_fle(all_data, "vertical_field"), "vertical_field", c("Upper", "Lower"), vert_colors, "FLE by Upper/Lower Visual Field",      "Visual Field")
p5b <- make_fle_plot(compute_fle(all_data, "ecc_band"),       "ecc_band",       c("Inner", "Outer"), ecc_colors,  "FLE by Eccentricity (Inner vs Outer)",  "Eccentricity")

# =============================================================================
# Statistical analysis helpers
# =============================================================================

fmt_p <- function(p) ifelse(p < .001, "< .001", sprintf("= %.3f", p))

clean_term <- function(x) {
  x <- gsub("cond_dir_short", "Condition", x)
  x <- gsub("hemifield",      "Hemifield", x)
  x <- gsub("vertical_field", "Visual Field", x)
  x <- gsub("ecc_band",       "Eccentricity", x)
  x <- gsub(":", " \u00d7 ", x)
  x
}

make_table_plot <- function(df, anova_header = NULL) {
  nc  <- ncol(df)
  nr  <- nrow(df)
  
  header_row <- setNames(as.data.frame(t(names(df)), stringsAsFactors = FALSE), names(df))
  all_rows   <- rbind(header_row, df)
  total_rows <- nrow(all_rows)
  row_height <- 1 / total_rows
  
  plot_df <- do.call(rbind, lapply(seq_len(total_rows), function(ri) {
    y_mid <- 1 - (ri - 0.5) * row_height
    data.frame(
      row   = ri,
      col   = seq_len(nc),
      lab   = as.character(unlist(all_rows[ri, ])),
      head  = ri == 1,
      odd   = ri %% 2 == 0,
      y_mid = y_mid,
      ymin  = y_mid - row_height / 2,
      ymax  = y_mid + row_height / 2,
      stringsAsFactors = FALSE
    )
  }))
  
  x_breaks <- seq(0, 1, length.out = nc + 1)
  x_mids   <- (x_breaks[-1] + x_breaks[-(nc+1)]) / 2
  plot_df$x_mid <- x_mids[plot_df$col]
  plot_df$xmin  <- x_breaks[plot_df$col]
  plot_df$xmax  <- x_breaks[plot_df$col + 1]
  
  p <- ggplot(plot_df) +
    geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                  fill = interaction(head, odd)), color = "white", linewidth = 0.2) +
    geom_text(aes(x = xmin + 0.01, y = y_mid, label = lab,
                  fontface = ifelse(head, "bold", "plain"),
                  size     = ifelse(head, 2.3, 2.1)),
              hjust = 0, color = ifelse(plot_df$head, "grey10", "grey20")) +
    scale_size_identity() +
    scale_fill_manual(values = c(
      "FALSE.FALSE" = "white",   "FALSE.TRUE"  = "#F2F2F2",
      "TRUE.FALSE"  = "#DDEEFF", "TRUE.TRUE"   = "#DDEEFF"
    )) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    theme_void() +
    theme(legend.position = "none", plot.margin = margin(4, 6, 4, 6))
  
  if (!is.null(anova_header)) {
    p <- p +
      labs(caption = anova_header) +
      theme(plot.caption = element_text(size = 5.5, color = "grey40", fontface = "italic",
                                        hjust = 0, margin = margin(t = 2)))
  }
  p
}

anova_contrasts <- function(means_df, dv, within_var, alpha = 0.05) {
  means_df[[dv]]            <- as.numeric(means_df[[dv]])
  means_df[["participant"]] <- factor(means_df[["participant"]])
  means_df[[within_var]]    <- factor(means_df[[within_var]])
  
  fit    <- afex::aov_ez(id = "participant", dv = dv, within = within_var, data = means_df)
  at     <- fit$anova_table
  header <- sprintf("F(%.0f, %.0f) = %.2f, p %s",
                    at[1,"num Df"], at[1,"den Df"], at[1,"F"], fmt_p(at[1,"Pr(>F)"]))
  
  con_df <- as.data.frame(emmeans::contrast(
    emmeans::emmeans(fit, as.formula(paste0("~ ", within_var))),
    method = "pairwise", adjust = "bonferroni"
  ))
  sig <- con_df[con_df$p.value < alpha, , drop = FALSE]
  
  if (nrow(sig) == 0) {
    rows <- data.frame(Contrast = "No significant contrasts", t = "", df = "", p = "")
  } else {
    rows <- data.frame(
      Contrast = sig$contrast,
      `t*`     = sprintf("%.2f", sig$t.ratio),
      df       = sprintf("%.0f", sig$df),
      p        = sapply(sig$p.value, fmt_p),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  list(header = header, table = rows)
}

anova_contrasts_2way <- function(means_df, dv, within1, within2, alpha = 0.05) {
  means_df[[dv]]            <- as.numeric(means_df[[dv]])
  means_df[["participant"]] <- factor(means_df[["participant"]])
  means_df[[within1]]       <- factor(means_df[[within1]])
  means_df[[within2]]       <- factor(means_df[[within2]])
  
  fit  <- afex::aov_ez(id = "participant", dv = dv, within = c(within1, within2), data = means_df)
  at   <- fit$anova_table
  
  header_lines <- sapply(rownames(at), function(trm) {
    sprintf("%s: F(%.0f,%.0f) = %.2f, p %s",
            clean_term(trm), at[trm,"num Df"], at[trm,"den Df"],
            at[trm,"F"], fmt_p(at[trm,"Pr(>F)"]))
  })
  
  con_df <- as.data.frame(emmeans::contrast(
    emmeans::emmeans(fit, as.formula(paste0("~ ", within2, " | ", within1))),
    method = "pairwise", adjust = "bonferroni"
  ))
  sig <- con_df[con_df$p.value < alpha, , drop = FALSE]
  
  if (nrow(sig) == 0) {
    rows <- data.frame(Condition = "No significant contrasts", t = "", df = "", p = "")
  } else {
    rows <- data.frame(
      Condition = as.character(sig[[within1]]),
      `t*`      = sprintf("%.2f", sig$t.ratio),
      df        = sprintf("%.0f", sig$df),
      p         = sapply(sig$p.value, fmt_p),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  list(header = paste(header_lines, collapse = "\n"), table = rows)
}

fle_ttests <- function(fle_long, group_var = NULL, alpha = 0.05) {
  tests <- list()
  
  if (is.null(group_var)) {
    wide <- fle_long %>%
      select(participant, direction, fle) %>%
      pivot_wider(names_from = direction, values_from = fle)
    tests <- list(
      list(label = "Centripetal vs 0",           tt = t.test(wide$Petal)),
      list(label = "Centrifugal vs 0",           tt = t.test(wide$Fugal)),
      list(label = "Centripetal vs Centrifugal", tt = t.test(wide$Petal, wide$Fugal, paired = TRUE))
    )
  } else {
    lvls <- levels(factor(fle_long[[group_var]]))
    dirs <- c("Petal", "Fugal")
    for (dir in dirs) {
      sub  <- fle_long %>% filter(direction == dir)
      wide <- sub %>%
        select(participant, all_of(group_var), fle) %>%
        pivot_wider(names_from = all_of(group_var), values_from = fle)
      for (lv in lvls) {
        tests <- c(tests, list(
          list(label = sprintf("%s %s vs 0", dir, lv), tt = t.test(wide[[lv]]))
        ))
      }
      tests <- c(tests, list(
        list(label = sprintf("%s: %s vs %s", dir, lvls[1], lvls[2]),
             tt = t.test(wide[[lvls[1]]], wide[[lvls[2]]], paired = TRUE))
      ))
    }
  }
  
  rows <- lapply(tests, function(x) {
    data.frame(
      Comparison = x$label,
      t          = sprintf("%.2f", x$tt$statistic),
      df         = sprintf("%.0f", x$tt$parameter),
      p          = fmt_p(x$tt$p.value),
      sig        = x$tt$p.value < alpha,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

# =============================================================================
# Compute statistics
# =============================================================================

filter_sig <- function(df, alpha = 0.05) {
  out <- df[df$sig == TRUE, setdiff(names(df), "sig"), drop = FALSE]
  if (nrow(out) == 0) out <- data.frame(Comparison = "No significant results", t = "", df = "", p = "")
  out
}

stat_p1  <- anova_contrasts(participant_means, "mean_offset", "cond_dir")
stat_p2  <- filter_sig(fle_ttests(fle_indiv))

part_means_hemi <- all_data %>%
  filter(valid == "valid", !is.na(hemifield)) %>%
  group_by(participant, hemifield, cond_dir_short) %>%
  summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop")
stat_p3 <- anova_contrasts_2way(part_means_hemi, "mean_offset", "cond_dir_short", "hemifield")
stat_p4 <- filter_sig(fle_ttests(compute_fle(all_data, "hemifield"), "hemifield"))

part_means_vert <- all_data %>%
  filter(valid == "valid", !is.na(vertical_field)) %>%
  group_by(participant, vertical_field, cond_dir_short) %>%
  summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop")
stat_p3b <- anova_contrasts_2way(part_means_vert, "mean_offset", "cond_dir_short", "vertical_field")
stat_p4b <- filter_sig(fle_ttests(compute_fle(all_data, "vertical_field"), "vertical_field"))

part_means_ecc <- all_data %>%
  filter(valid == "valid", !is.na(ecc_band)) %>%
  group_by(participant, ecc_band, cond_dir_short) %>%
  summarise(mean_offset = mean(foveal_offset, na.rm = TRUE), .groups = "drop")
stat_p5  <- anova_contrasts_2way(part_means_ecc, "mean_offset", "cond_dir_short", "ecc_band")
stat_p5b <- filter_sig(fle_ttests(compute_fle(all_data, "ecc_band"), "ecc_band"))

# =============================================================================
# Build table grobs
# =============================================================================

anova_hdr <- function(stat) paste(strwrap(stat$header, width = 55), collapse = "\n")

tbl_p1  <- make_table_plot(stat_p1$table,  anova_hdr(stat_p1))
tbl_p2  <- make_table_plot(stat_p2)
tbl_p3  <- make_table_plot(stat_p3$table,  anova_hdr(stat_p3))
tbl_p4  <- make_table_plot(stat_p4)
tbl_p3b <- make_table_plot(stat_p3b$table, anova_hdr(stat_p3b))
tbl_p4b <- make_table_plot(stat_p4b)
tbl_p5  <- make_table_plot(stat_p5$table,  anova_hdr(stat_p5))
tbl_p5b <- make_table_plot(stat_p5b)

# =============================================================================
# Assemble and save
# =============================================================================

combined_all <-
  (p1  | tbl_p1  | p2  | tbl_p2)  /
  (p3  | tbl_p3  | p4  | tbl_p4)  /
  (p3b | tbl_p3b | p4b | tbl_p4b) /
  (p5  | tbl_p5  | p5b | tbl_p5b) +
  plot_layout(widths = c(3, 1.4, 3, 1.4), heights = c(1, 1, 1, 1)) +
  plot_annotation(
    title   = paste0("Flash-Lag Effect \u2014 Experiment 2 (N = ", N, ")"),
    caption = paste("Bars = group mean \u00b1 SEM. Points = individual participants.",
                    "Negative values = mislocalisation toward fovea.",
                    "Pairwise contrasts: Bonferroni-corrected."),
    theme   = theme(
      plot.title   = element_text(size = 15, face = "bold", hjust = 0.5,
                                  margin = margin(b = 4)),
      plot.caption = element_text(size = 7, color = "grey45", hjust = 0,
                                  margin = margin(t = 6))
    )
  )

output_pdf <- file.path(data_folder, "GROUP_FLE_E2_summary.pdf")
ggsave(output_pdf, combined_all, width = 24, height = 24, device = cairo_pdf)

output_png <- file.path(data_folder, "GROUP_FLE_E2_summary.png")
ggsave(output_png, combined_all, width = 24, height = 24, dpi = 200)