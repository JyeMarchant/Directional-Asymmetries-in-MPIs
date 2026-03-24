# Flash Grab Experiment - Statistical Analysis
# Author: Research Team
# Date: 2025-10-16
# 
# Analyzes psychophysical data from radial and orthogonal motion experiments
# Generates comprehensive HTML report with psychometric functions and statistics

# ====================================================================
# IMPORTANT: RSTUDIO SETUP INSTRUCTIONS
# ====================================================================
# 1. SET WORKING DIRECTORY: In RStudio, set working directory to the 'analysis' folder
#    Session > Set Working Directory > Choose Directory... > Select 'analysis' folder
#    OR use: setwd("~/Documents/MATLAB/FGE_UNIFORM_CONTROL/analysis")
# 
# 2. CHANGE PARTICIPANT ID: Modify the PARTICIPANT_ID below to analyze different participants
#    This ID controls which CSV files are loaded (e.g., "010" loads 010_FGE_R_*.csv and 010_FGE_O_*.csv)
# ====================================================================

# Configuration
PARTICIPANT_ID <- "666"  # Change this to analyze different participants (e.g., "010", "020", etc.)

# Setup
library(dplyr)
library(ggplot2) 
library(gridExtra)
library(readr)
library(base64enc)

# Ensure working directory
if (basename(getwd()) != "analysis") {
  if (dir.exists("analysis")) setwd("analysis")
}

# Core Functions
calculate_PSE <- function(data, condition_name, min_trials = 10) {
  cat("Processing", condition_name, "\n")
  
  valid_data <- data %>%
    filter(
      valid_trial == "valid",
      response %in% c("inner", "outer")
    )
  
  if (nrow(valid_data) < min_trials) {
    return(list(PSE = NA, slope = NA, n_trials = nrow(valid_data), 
                r_squared = NA, p_value = NA, condition = condition_name))
  }
  
  cat("Valid trials:", nrow(valid_data), "\n")
  valid_data$response_binary <- ifelse(valid_data$response == "outer", 1, 0)
  
  if (length(unique(valid_data$response_binary)) < 2) {
    return(list(PSE = NA, slope = NA, n_trials = nrow(valid_data), 
                r_squared = NA, p_value = NA, condition = condition_name))
  }
  
  cat("Probe offset range:", round(min(valid_data$probe_offset_dva), 2), 
      "to", round(max(valid_data$probe_offset_dva), 2), "DVA\n")
  
  tryCatch({
    model <- glm(response_binary ~ probe_offset_dva, 
                 family = binomial(link = "logit"), 
                 data = valid_data)
    
    PSE <- -coef(model)[1] / coef(model)[2]
    slope <- coef(model)[2] / 4
    
    null_deviance <- model$null.deviance
    residual_deviance <- model$deviance
    r_squared <- (null_deviance - residual_deviance) / null_deviance
    
    model_summary <- summary(model)
    p_value <- model_summary$coefficients[2, 4]
    
    cat("PSE (50% threshold):", round(PSE, 3), "DVA\n")
    cat("Slope parameter:", round(slope, 3), "\n")
    cat("R-squared:", round(r_squared, 3), "\n")
    cat("Slope p-value:", format(p_value, scientific = TRUE, digits = 3), "\n")
    
    return(list(
      PSE = PSE,
      slope = slope,
      n_trials = nrow(valid_data),
      r_squared = r_squared,
      p_value = p_value,
      condition = condition_name,
      data = valid_data,
      model = model
    ))
    
  }, error = function(e) {
    cat("Error fitting model for", condition_name, ":", e$message, "\n")
    return(list(PSE = NA, slope = NA, n_trials = nrow(valid_data), 
                r_squared = NA, p_value = NA, condition = condition_name))
  })
}

create_psychometric_plot <- function(result, title, color = "blue") {
  if (is.na(result$PSE) || is.null(result$data)) {
    return(ggplot() + ggtitle(paste("No data:", title)))
  }
  
  data <- result$data
  model <- result$model
  
  pred_data <- data.frame(
    probe_offset_dva = seq(min(data$probe_offset_dva), max(data$probe_offset_dva), length.out = 100)
  )
  pred_data$predicted <- predict(model, newdata = pred_data, type = "response")
  
  summary_data <- data %>%
    group_by(probe_offset_dva) %>%
    summarise(
      prop_outer = mean(response_binary),
      n = n(),
      .groups = 'drop'
    )
  
  ggplot() +
    geom_point(data = summary_data, 
               aes(x = probe_offset_dva, y = prop_outer, size = n), 
               color = color, alpha = 0.7) +
    geom_line(data = pred_data, 
              aes(x = probe_offset_dva, y = predicted), 
              color = color, size = 1) +
    geom_hline(yintercept = 0.5, linetype = "dashed", alpha = 0.6) +
    geom_vline(xintercept = result$PSE, linetype = "dashed", alpha = 0.6) +
    scale_x_continuous("Probe Offset (DVA)") +
    scale_y_continuous("Proportion 'Outer' Response", limits = c(0, 1)) +
    scale_size_continuous(name = "Number of\nTrials", 
                         range = c(1, 6),
                         guide = guide_legend(override.aes = list(alpha = 1))) +
    ggtitle(paste(title, sprintf("(PSE: %.2f DVA, N: %d)", result$PSE, result$n_trials))) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 10, hjust = 0.5),
      axis.title = element_text(size = 9),
      legend.position = "right",
      legend.text = element_text(size = 8),
      legend.title = element_text(size = 9)
    )
}

analyze_catch_trials <- function(data, experiment_name) {
  catch_trials <- data %>%
    filter(
      valid_trial == "valid",
      staircase_trial == "C" | staircase_identity == "catch_trial"
    )
  
  if (nrow(catch_trials) == 0) return(NULL)
  
  catch_trials <- catch_trials %>%
    mutate(
      expected_response = ifelse(probe_offset_dva < 0, "inner", "outer"),
      correct = case_when(
        response == "inner" & expected_response == "inner" ~ TRUE,
        response == "outer" & expected_response == "outer" ~ TRUE,
        TRUE ~ FALSE
      )
    )
  
  total_trials <- nrow(catch_trials)
  correct_trials <- sum(catch_trials$correct)
  accuracy <- correct_trials / total_trials * 100
  
  cat("=== CATCH TRIAL ANALYSIS ===\n")
  cat("Found", total_trials, "catch trials in", experiment_name, "data\n\n")
  
  cat("--- CATCH TRIAL PERFORMANCE SUMMARY ---\n")
  cat("Experiment:", experiment_name, "\n")
  cat("Total catch trials:", total_trials, "\n")
  cat("Correct responses:", correct_trials, "\n")
  cat("Overall accuracy:", sprintf("%.1f%%", accuracy), "\n")
  cat("Performance status:", ifelse(accuracy >= 80, "PASS", "FAIL"), "(threshold: 80%)\n\n")
  
  breakdown <- catch_trials %>%
    group_by(probe_offset_dva) %>%
    summarise(
      total = n(),
      correct = sum(correct),
      accuracy = mean(correct) * 100,
      .groups = 'drop'
    )
  
  cat("Detailed breakdown:\n")
  for (i in 1:nrow(breakdown)) {
    offset <- breakdown$probe_offset_dva[i]
    expected <- ifelse(offset < 0, "inner", "outer")
    cat(sprintf("  %+.0f DVA offset (expect '%s'): %d/%d correct (%.1f%%)\n", 
                offset, expected, breakdown$correct[i], breakdown$total[i], breakdown$accuracy[i]))
  }
  cat("\n")
  
  return(list(
    total_trials = total_trials,
    correct_trials = correct_trials,
    accuracy = accuracy,
    pass = accuracy >= 80,
    breakdown = breakdown
  ))
}

calculate_combined_fge <- function(radial_results, orthogonal_results) {
  cat("Calculating Combined FGE...\n")
  
  extract_pse_value <- function(results, condition) {
    if (!is.null(results[[condition]])) {
      return(results[[condition]]$PSE)
    }
    return(NA)
  }
  
  radial_petal <- extract_pse_value(radial_results, "petal")
  radial_fugal <- extract_pse_value(radial_results, "fugal")
  orthogonal_petal <- extract_pse_value(orthogonal_results, "petal")
  orthogonal_fugal <- extract_pse_value(orthogonal_results, "fugal")
  
  combined_fge_radial <- mean(c(abs(radial_petal), abs(radial_fugal)), na.rm = TRUE)
  combined_fge_orthogonal <- mean(c(abs(orthogonal_petal), abs(orthogonal_fugal)), na.rm = TRUE)
  
  cat("Combined FGE (Radial):", sprintf("%.3f", combined_fge_radial), "\n")
  cat("Combined FGE (Orthogonal):", sprintf("%.3f", combined_fge_orthogonal), "\n")
  
  return(list(
    radial = combined_fge_radial,
    orthogonal = combined_fge_orthogonal
  ))
}

create_psychometric_grid <- function(radial_results, orthogonal_results) {
  motion_colors <- c("petal" = "#E31A1C", "fugal" = "#1F78B4", "uniform_control" = "#33A02C")
  
  plots <- list()
  
  # Radial plots
  for (condition in c("petal", "fugal", "uniform_control")) {
    if (!is.null(radial_results[[condition]])) {
      plots[[paste0("radial_", condition)]] <- 
        create_psychometric_plot(radial_results[[condition]], 
                                paste("Radial", stringr::str_to_title(condition)), 
                                motion_colors[condition])
    }
  }
  
  # Orthogonal plots  
  for (condition in c("petal", "fugal", "uniform_control")) {
    if (!is.null(orthogonal_results[[condition]])) {
      plots[[paste0("orthogonal_", condition)]] <- 
        create_psychometric_plot(orthogonal_results[[condition]], 
                                paste("Orthogonal", stringr::str_to_title(condition)), 
                                motion_colors[condition])
    }
  }
  
  grid_plot <- do.call(grid.arrange, c(plots, ncol = 3, nrow = 2))
  
  ggsave("temp_psychometric_grid.png", grid_plot, width = 15, height = 8, dpi = 150)
  
  img_base64 <- base64enc::base64encode("temp_psychometric_grid.png")
  file.remove("temp_psychometric_grid.png")
  
  return(paste0('<img src="data:image/png;base64,', img_base64, 
                '" alt="Psychometric Functions Grid" style="width: 100%; max-width: 1200px;">'))
}

analyze_experiment <- function(csv_file_path) {
  cat("Analyzing:", basename(csv_file_path), "\n")
  
  if (!file.exists(csv_file_path)) {
    stop("File not found: ", csv_file_path)
  }
  
  data_raw <- read_csv(csv_file_path, show_col_types = FALSE)
  cat("Successfully loaded", nrow(data_raw), "rows of data\n")
  
  # Clean data
  data <- data_raw %>%
    filter(
      valid_trial == "valid",
      !is.na(motion_direction),
      !is.na(probe_offset_dva),
      response %in% c("inner", "outer", "invalid"),
      motion_direction %in% c("petal", "fugal", "uniform_control", "catch_trial")
    ) %>%
    mutate(
      visual_field = case_when(
        grepl("upper", quadrant) ~ "upper",
        grepl("lower", quadrant) ~ "lower",
        TRUE ~ "unknown"
      ),
      horizontal = case_when(
        grepl("left", quadrant) ~ "left",
        grepl("right", quadrant) ~ "right", 
        TRUE ~ "unknown"
      ),
      eccentricity = tolower(trimws(eccentricity))
    )
  
  cat("Clean data:", nrow(data), "valid trials\n")
  cat("Motion conditions:", paste(unique(data$motion_direction), collapse = ", "), "\n")
  
  # Motion condition analysis
  cat("Motion condition analysis:\n")
  results <- list()
  
  for (condition in c("petal", "fugal", "uniform_control")) {
    condition_data <- data %>% filter(motion_direction == condition)
    results[[condition]] <- calculate_PSE(condition_data, condition)
  }
  
  # Motion × Visual Field analysis (separate by motion type)
  cat("Motion × Visual Field analysis:\n")
  
  for (motion in c("petal", "fugal", "uniform_control")) {
    cat("\n", toupper(motion), "MOTION:\n")
    for (field in c("left", "right", "upper", "lower")) {
      field_motion_data <- data %>% 
        filter(
          motion_direction == motion,
          !!sym(ifelse(field %in% c("left", "right"), "horizontal", "visual_field")) == field
        )
      result <- calculate_PSE(field_motion_data, paste(motion, field))
      results[[paste0(motion, "_", field)]] <- result
      
      # Store for summary tables
      if (!is.na(result$PSE)) {
        cat("  ", field, "field PSE:", round(result$PSE, 3), "DVA (n =", result$n_trials, "trials)\n")
      }
    }
  }
  
  # Motion × Eccentricity analysis (separate by motion type)
  cat("\nMotion × Eccentricity analysis:\n")
  
  for (motion in c("petal", "fugal", "uniform_control")) {
    cat("\n", toupper(motion), "MOTION:\n")
    for (ecc in c("inner", "outer")) {
      interaction_data <- data %>% 
        filter(
          motion_direction == motion,
          eccentricity == ecc
        )
      result <- calculate_PSE(interaction_data, paste(motion, ecc))
      results[[paste0(motion, "_", ecc)]] <- result
      
      # Store for summary tables
      if (!is.na(result$PSE)) {
        cat("  ", ecc, "eccentricity PSE:", round(result$PSE, 3), "DVA (n =", result$n_trials, "trials)\n")
      }
    }
  }
  
  # Summary tables
  cat("Creating summary tables:\n")
  
  motion_summary <- data.frame(
    condition = c("fugal", "petal", "uniform_control"),
    PSE = sapply(c("fugal", "petal", "uniform_control"), function(x) results[[x]]$PSE %||% NA),
    slope = sapply(c("fugal", "petal", "uniform_control"), function(x) results[[x]]$slope %||% NA),
    n_trials = sapply(c("fugal", "petal", "uniform_control"), function(x) results[[x]]$n_trials %||% NA),
    r_squared = sapply(c("fugal", "petal", "uniform_control"), function(x) results[[x]]$r_squared %||% NA),
    p_value = sapply(c("fugal", "petal", "uniform_control"), function(x) results[[x]]$p_value %||% NA)
  )
  
  cat("\nMOTION CONDITIONS SUMMARY:\n")
  print(motion_summary)
  
  return(list(
    data = data,
    data_raw = data_raw,  # Include raw data with ALL trials
    results = results,
    summary = motion_summary,
    experiment_name = if (grepl("_R_", basename(csv_file_path))) "Radial" else "Orthogonal"
  ))
}

# File Detection
data_dir <- "../data"
csv_files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)

radial_pattern <- paste0("^", PARTICIPANT_ID, "_FGE_R_.*\\.csv$")
orthogonal_pattern <- paste0("^", PARTICIPANT_ID, "_FGE_O_.*\\.csv$") 

radial_files <- csv_files[grepl(radial_pattern, basename(csv_files))]
orthogonal_files <- csv_files[grepl(orthogonal_pattern, basename(csv_files))]

cat("Found files:\n")
if (length(radial_files) > 0) cat("- Radial:", basename(radial_files[1]), "\n")
if (length(orthogonal_files) > 0) cat("- Orthogonal:", basename(orthogonal_files[1]), "\n")

# Analysis
radial_results <- NULL
orthogonal_results <- NULL

if (length(radial_files) > 0) {
  cat("\n", rep("-", 80), "\n")
  cat("ANALYZING RADIAL EXPERIMENT\n")
  cat(rep("-", 80), "\n")
  radial_results <- analyze_experiment(radial_files[1])
}

if (length(orthogonal_files) > 0) {
  cat("\n", rep("-", 80), "\n") 
  cat("ANALYZING ORTHOGONAL EXPERIMENT\n")
  cat(rep("-", 80), "\n")
  orthogonal_results <- analyze_experiment(orthogonal_files[1])
}

# Catch Trial Analysis
cat("\n", rep("-", 80), "\n")
cat("CATCH TRIAL PERFORMANCE ANALYSIS\n")
cat(rep("-", 80), "\n")

radial_catch <- NULL
orthogonal_catch <- NULL

if (!is.null(radial_results)) {
  radial_catch <- analyze_catch_trials(radial_results$data, "Radial")
}

if (!is.null(orthogonal_results)) {
  orthogonal_catch <- analyze_catch_trials(orthogonal_results$data, "Orthogonal")
}

# Eye Gaze Violation Analysis
cat("\n", rep("-", 80), "\n")
cat("EYE GAZE VIOLATION ANALYSIS\n")
cat(rep("-", 80), "\n")

if (!is.null(radial_results)) {
  # Use raw data (includes ALL trials: valid + invalid)
  radial_raw <- radial_results$data_raw
  radial_total <- nrow(radial_raw)
  radial_valid <- sum(radial_raw$valid_trial == "valid", na.rm = TRUE)
  radial_invalid <- sum(radial_raw$valid_trial == "invalid", na.rm = TRUE)
  # Calculate percentages based on expected 360 trials per version
  radial_invalid_pct <- round((radial_invalid / 360) * 100, 2)
  radial_valid_pct <- round((radial_valid / 360) * 100, 2)
  cat("RADIAL EXPERIMENT:\n")
  cat("  Total trials collected:", radial_total, "\n")
  cat("  Valid trials:", radial_valid, "\n")
  cat("  Invalid trials (eye gaze violations):", radial_invalid, "\n")
  cat("  Percentage of expected trials marked INVALID:", radial_invalid_pct, "% (out of 360)\n")
  cat("  Percentage of expected trials marked VALID:", radial_valid_pct, "% (out of 360)\n\n")
}

if (!is.null(orthogonal_results)) {
  # Use raw data (includes ALL trials: valid + invalid)
  orthogonal_raw <- orthogonal_results$data_raw
  orthogonal_total <- nrow(orthogonal_raw)
  orthogonal_valid <- sum(orthogonal_raw$valid_trial == "valid", na.rm = TRUE)
  orthogonal_invalid <- sum(orthogonal_raw$valid_trial == "invalid", na.rm = TRUE)
  # Calculate percentages based on expected 360 trials per version
  orthogonal_invalid_pct <- round((orthogonal_invalid / 360) * 100, 2)
  orthogonal_valid_pct <- round((orthogonal_valid / 360) * 100, 2)
  cat("ORTHOGONAL EXPERIMENT:\n")
  cat("  Total trials collected:", orthogonal_total, "\n")
  cat("  Valid trials:", orthogonal_valid, "\n")
  cat("  Invalid trials (eye gaze violations):", orthogonal_invalid, "\n")
  cat("  Percentage of expected trials marked INVALID:", orthogonal_invalid_pct, "% (out of 360)\n")
  cat("  Percentage of expected trials marked VALID:", orthogonal_valid_pct, "% (out of 360)\n\n")
}

if (!is.null(radial_results) && !is.null(orthogonal_results)) {
  combined_total <- radial_total + orthogonal_total
  combined_valid <- radial_valid + orthogonal_valid
  combined_invalid <- radial_invalid + orthogonal_invalid
  # Calculate percentages based on expected 720 trials total (360 per version)
  combined_invalid_pct <- round((combined_invalid / 720) * 100, 2)
  combined_valid_pct <- round((combined_valid / 720) * 100, 2)
  cat("COMBINED (RADIAL + ORTHOGONAL):\n")
  cat("  Total trials collected:", combined_total, "\n")
  cat("  Valid trials:", combined_valid, "\n")
  cat("  Invalid trials (eye gaze violations):", combined_invalid, "\n")
  cat("  Percentage of expected trials marked INVALID:", combined_invalid_pct, "% (out of 720)\n")
  cat("  Percentage of expected trials marked VALID:", combined_valid_pct, "% (out of 720)\n")
}

# Combined FGE
if (!is.null(radial_results) && !is.null(orthogonal_results)) {
  combined_fge <- calculate_combined_fge(radial_results$results, orthogonal_results$results)
}

# HTML Report Generation
output_dir <- "../data/analysis_output"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

html_file <- file.path(output_dir, paste0(PARTICIPANT_ID, "_FGE_Statistical_Analysis.html"))

# Helper function to safely extract values
safe_extract <- function(results, condition, field) {
  if (is.null(results) || is.null(results$results[[condition]])) return("N/A")
  value <- results$results[[condition]][[field]]
  if (is.na(value)) return("N/A")
  if (field == "p_value") return(format(value, scientific = TRUE, digits = 2))
  if (field == "n_trials") return(sprintf("%.0f", value))  # No decimals for trial counts
  if (is.numeric(value)) return(sprintf("%.3f", value))
  return(as.character(value))
}

# Generate HTML
html_content <- paste0('
<!DOCTYPE html>
<html>
<head>
    <title>Flash Grab Experiment Analysis</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        h3 { color: #7f8c8d; }
        .summary-stats { background-color: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .pse-table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        .pse-table th, .pse-table td { border: 1px solid #bdc3c7; padding: 8px; text-align: center; }
        .pse-table th { background-color: #34495e; color: white; }
        .pse-table tr:nth-child(even) { background-color: #f8f9fa; }
        .plot-section { margin: 30px 0; text-align: center; }
        .plot-title { font-size: 18px; font-weight: bold; margin-bottom: 15px; }
        .pass { color: #27ae60; font-weight: bold; }
        .fail { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Flash Grab Experiment Analysis</h1>
    <p><strong>Statistical Analysis Report | Participant ', PARTICIPANT_ID, ' | ', Sys.Date(), '</strong></p>')

# Catch Trial Performance
if (!is.null(radial_catch) || !is.null(orthogonal_catch)) {
  html_content <- paste0(html_content, '
    <h2>Catch Trial Performance Analysis</h2>
    <p><strong>Data Quality Check:</strong> Catch trials assess participant attention and task compliance.</p>
    <p><strong>Criteria:</strong> ≥80% correct responses required for inclusion</p>
    <p><strong>Task:</strong> -5 DVA offset → "Inner" response expected | +5 DVA offset → "Outer" response expected</p>
    
    <table class="pse-table">
        <thead>
            <tr>
                <th>Experiment</th>
                <th>Trials</th>
                <th>Correct</th>
                <th>Accuracy</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>')
  
  if (!is.null(radial_catch)) {
    status_class <- if (radial_catch$pass) "pass" else "fail"
    status_text <- if (radial_catch$pass) "✅ PASS" else "❌ FAIL"
    html_content <- paste0(html_content, '
            <tr>
                <td><strong>Radial</strong></td>
                <td>', radial_catch$total_trials, '</td>
                <td>', radial_catch$correct_trials, '</td>
                <td>', sprintf("%.1f%%", radial_catch$accuracy), '</td>
                <td class="', status_class, '">', status_text, '</td>
            </tr>')
  }
  
  if (!is.null(orthogonal_catch)) {
    status_class <- if (orthogonal_catch$pass) "pass" else "fail"
    status_text <- if (orthogonal_catch$pass) "✅ PASS" else "❌ FAIL"
    html_content <- paste0(html_content, '
            <tr>
                <td><strong>Orthogonal</strong></td>
                <td>', orthogonal_catch$total_trials, '</td>
                <td>', orthogonal_catch$correct_trials, '</td>
                <td>', sprintf("%.1f%%", orthogonal_catch$accuracy), '</td>
                <td class="', status_class, '">', status_text, '</td>
            </tr>')
  }
  
  overall_pass <- (!is.null(radial_catch) && radial_catch$pass) && 
                  (!is.null(orthogonal_catch) && orthogonal_catch$pass)
  
  html_content <- paste0(html_content, '
        </tbody>
    </table>
    
    <div class="summary-stats">
        <strong>', if (overall_pass) "✅ PARTICIPANT MEETS INCLUSION CRITERIA" else "❌ PARTICIPANT FAILS INCLUSION CRITERIA", '</strong><br><br>
        Catch trial performance ', if (overall_pass) "meets or exceeds" else "fails to meet", ' 80% threshold.
    </div>')
}

# Eye Gaze Violation Analysis HTML
if (!is.null(radial_results) || !is.null(orthogonal_results)) {
  html_content <- paste0(html_content, '
    <h2>Eye Gaze Violation Analysis</h2>
    <p><strong>Data Quality Check:</strong> Percentage of trials marked invalid due to eye gaze violations.</p>
    <p><strong>Criteria:</strong> Trials are marked invalid if gaze position exceeds fixation window during critical periods.</p>
    <p><strong>Note:</strong> Percentages are calculated based on expected trial counts (360 per version, 720 total).</p>
    
    <table class="pse-table">
        <thead>
            <tr>
                <th>Experiment</th>
                <th>Expected Trials</th>
                <th>Invalid Trials</th>
                <th>Invalid %</th>
                <th>Valid Trials</th>
                <th>Valid %</th>
            </tr>
        </thead>
        <tbody>')
  
  if (!is.null(radial_results)) {
    radial_raw <- radial_results$data_raw  # Use raw data with ALL trials
    radial_total <- nrow(radial_raw)
    radial_valid <- sum(radial_raw$valid_trial == "valid", na.rm = TRUE)
    radial_invalid <- sum(radial_raw$valid_trial == "invalid", na.rm = TRUE)
    # Calculate percentages based on expected 360 trials per version
    radial_invalid_pct <- round((radial_invalid / 360) * 100, 1)
    radial_valid_pct <- round((radial_valid / 360) * 100, 1)
    html_content <- paste0(html_content, '
            <tr>
                <td><strong>Radial</strong></td>
                <td>360 (expected)</td>
                <td>', radial_invalid, '</td>
                <td>', radial_invalid_pct, '%</td>
                <td>', radial_valid, '</td>
                <td>', radial_valid_pct, '%</td>
            </tr>')
  }
  
  if (!is.null(orthogonal_results)) {
    orthogonal_raw <- orthogonal_results$data_raw  # Use raw data with ALL trials
    orthogonal_total <- nrow(orthogonal_raw)
    orthogonal_valid <- sum(orthogonal_raw$valid_trial == "valid", na.rm = TRUE)
    orthogonal_invalid <- sum(orthogonal_raw$valid_trial == "invalid", na.rm = TRUE)
    # Calculate percentages based on expected 360 trials per version
    orthogonal_invalid_pct <- round((orthogonal_invalid / 360) * 100, 1)
    orthogonal_valid_pct <- round((orthogonal_valid / 360) * 100, 1)
    html_content <- paste0(html_content, '
            <tr>
                <td><strong>Orthogonal</strong></td>
                <td>360 (expected)</td>
                <td>', orthogonal_invalid, '</td>
                <td>', orthogonal_invalid_pct, '%</td>
                <td>', orthogonal_valid, '</td>
                <td>', orthogonal_valid_pct, '%</td>
            </tr>')
  }
  
  if (!is.null(radial_results) && !is.null(orthogonal_results)) {
    combined_total <- radial_total + orthogonal_total
    combined_valid <- radial_valid + orthogonal_valid
    combined_invalid <- radial_invalid + orthogonal_invalid
    # Calculate percentages based on expected 720 trials total (360 per version)
    combined_invalid_pct <- round((combined_invalid / 720) * 100, 1)
    combined_valid_pct <- round((combined_valid / 720) * 100, 1)
    html_content <- paste0(html_content, '
            <tr style="border-top: 2px solid #333; font-weight: bold;">
                <td><strong>Combined Total</strong></td>
                <td>720 (expected)</td>
                <td>', combined_invalid, '</td>
                <td>', combined_invalid_pct, '%</td>
                <td>', combined_valid, '</td>
                <td>', combined_valid_pct, '%</td>
            </tr>')
  }
  
  html_content <- paste0(html_content, '
        </tbody>
    </table>
    
    <div class="summary-stats">
        <strong>Eye Tracking Data Quality Summary</strong><br><br>
        Eye gaze violations indicate periods where participant fixation exceeded acceptable limits.
        Lower percentages indicate better fixation compliance and higher data quality.
    </div>')
}

# Motion Direction Analysis
html_content <- paste0(html_content, '
    <h2>Primary Analysis: Motion Direction Comparisons</h2>
    
    <h3>Motion Direction PSEs & Parameters</h3>
    <table class="pse-table">
        <thead>
            <tr>
                <th rowspan="2">Task</th>
                <th colspan="3">PSE Values (DVA)</th>
                <th colspan="3">Slope Parameters</th>
                <th colspan="3">Trial Counts</th>
            </tr>
            <tr>
                <th>Petal</th>
                <th>Fugal</th>
                <th>Control</th>
                <th>Petal</th>
                <th>Fugal</th>
                <th>Control</th>
                <th>Petal N</th>
                <th>Fugal N</th>
                <th>Control N</th>
            </tr>
        </thead>
        <tbody>')

if (!is.null(radial_results)) {
  html_content <- paste0(html_content, '
            <tr>
                <td><strong>Radial</strong></td>
                <td>', safe_extract(radial_results, "petal", "PSE"), '</td>
                <td>', safe_extract(radial_results, "fugal", "PSE"), '</td>
                <td>', safe_extract(radial_results, "uniform_control", "PSE"), '</td>
                <td>', safe_extract(radial_results, "petal", "slope"), '</td>
                <td>', safe_extract(radial_results, "fugal", "slope"), '</td>
                <td>', safe_extract(radial_results, "uniform_control", "slope"), '</td>
                <td>', safe_extract(radial_results, "petal", "n_trials"), '</td>
                <td>', safe_extract(radial_results, "fugal", "n_trials"), '</td>
                <td>', safe_extract(radial_results, "uniform_control", "n_trials"), '</td>
            </tr>')
}

if (!is.null(orthogonal_results)) {
  html_content <- paste0(html_content, '
            <tr>
                <td><strong>Orthogonal</strong></td>
                <td>', safe_extract(orthogonal_results, "petal", "PSE"), '</td>
                <td>', safe_extract(orthogonal_results, "fugal", "PSE"), '</td>
                <td>', safe_extract(orthogonal_results, "uniform_control", "PSE"), '</td>
                <td>', safe_extract(orthogonal_results, "petal", "slope"), '</td>
                <td>', safe_extract(orthogonal_results, "fugal", "slope"), '</td>
                <td>', safe_extract(orthogonal_results, "uniform_control", "slope"), '</td>
                <td>', safe_extract(orthogonal_results, "petal", "n_trials"), '</td>
                <td>', safe_extract(orthogonal_results, "fugal", "n_trials"), '</td>
                <td>', safe_extract(orthogonal_results, "uniform_control", "n_trials"), '</td>
            </tr>')
}

html_content <- paste0(html_content, '
        </tbody>
    </table>')

# Effect Sizes
if (!is.null(radial_results) && !is.null(orthogonal_results)) {
  # Calculate effect sizes
  r_petal <- as.numeric(safe_extract(radial_results, "petal", "PSE"))
  r_fugal <- as.numeric(safe_extract(radial_results, "fugal", "PSE"))
  r_control <- as.numeric(safe_extract(radial_results, "uniform_control", "PSE"))
  
  o_petal <- as.numeric(safe_extract(orthogonal_results, "petal", "PSE"))
  o_fugal <- as.numeric(safe_extract(orthogonal_results, "fugal", "PSE"))
  o_control <- as.numeric(safe_extract(orthogonal_results, "uniform_control", "PSE"))
  
  r_petal_fugal <- r_petal - r_fugal
  r_petal_control <- r_petal - r_control  
  r_fugal_control <- r_fugal - r_control
  r_combined_fge <- combined_fge$radial
  
  o_petal_fugal <- o_petal - o_fugal
  o_petal_control <- o_petal - o_control
  o_fugal_control <- o_fugal - o_control  
  o_combined_fge <- combined_fge$orthogonal
  
  html_content <- paste0(html_content, '
    <h3>Effect Sizes & Flash Grab Effects</h3>
    <table class="pse-table">
        <thead>
            <tr>
                <th>Task</th>
                <th>Petal-Fugal Δ</th>
                <th>Petal-Control Δ</th>
                <th>Fugal-Control Δ</th>
                <th>Combined FGE</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Radial</strong></td>
                <td>', sprintf("%.3f", r_petal_fugal), '</td>
                <td>', sprintf("%.3f", r_petal_control), '</td>
                <td>', sprintf("%.3f", r_fugal_control), '</td>
                <td>', sprintf("%.3f", r_combined_fge), '</td>
            </tr>
            <tr>
                <td><strong>Orthogonal</strong></td>
                <td>', sprintf("%.3f", o_petal_fugal), '</td>
                <td>', sprintf("%.3f", o_petal_control), '</td>
                <td>', sprintf("%.3f", o_fugal_control), '</td>
                <td>', sprintf("%.3f", o_combined_fge), '</td>
            </tr>
        </tbody>
    </table>')
}

# Psychometric Plots
html_content <- paste0(html_content, '
    <div class="plot-section">
        <h3 class="plot-title">Motion Direction Psychometric Curves</h3>
        <p><strong>Legend:</strong> Point size indicates the number of trials at each probe offset level. Larger points represent more trials at that offset.</p>')

if (!is.null(radial_results) && !is.null(orthogonal_results)) {
  psychometric_grid <- create_psychometric_grid(radial_results$results, orthogonal_results$results)
  html_content <- paste0(html_content, psychometric_grid)
}

html_content <- paste0(html_content, '
    </div>')

html_content <- paste0(html_content, '
    </div>')

html_content <- paste0(html_content, '
    <h3>Motion × Visual Field Effects Summary</h3>
    
    <h4>Radial Version</h4>
    <table class="pse-table">
        <thead>
            <tr>
                <th>Motion Type</th>
                <th>Left Field PSE (DVA)</th>
                <th>Right Field PSE (DVA)</th>
                <th>Upper Field PSE (DVA)</th>
                <th>Lower Field PSE (DVA)</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Petal</strong></td>
                <td>', safe_extract(radial_results, "petal_left", "PSE"), ' (n = ', safe_extract(radial_results, "petal_left", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "petal_right", "PSE"), ' (n = ', safe_extract(radial_results, "petal_right", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "petal_upper", "PSE"), ' (n = ', safe_extract(radial_results, "petal_upper", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "petal_lower", "PSE"), ' (n = ', safe_extract(radial_results, "petal_lower", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Fugal</strong></td>
                <td>', safe_extract(radial_results, "fugal_left", "PSE"), ' (n = ', safe_extract(radial_results, "fugal_left", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "fugal_right", "PSE"), ' (n = ', safe_extract(radial_results, "fugal_right", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "fugal_upper", "PSE"), ' (n = ', safe_extract(radial_results, "fugal_upper", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "fugal_lower", "PSE"), ' (n = ', safe_extract(radial_results, "fugal_lower", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Control</strong></td>
                <td>', safe_extract(radial_results, "uniform_control_left", "PSE"), ' (n = ', safe_extract(radial_results, "uniform_control_left", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "uniform_control_right", "PSE"), ' (n = ', safe_extract(radial_results, "uniform_control_right", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "uniform_control_upper", "PSE"), ' (n = ', safe_extract(radial_results, "uniform_control_upper", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "uniform_control_lower", "PSE"), ' (n = ', safe_extract(radial_results, "uniform_control_lower", "n_trials"), ')</td>
            </tr>
        </tbody>
    </table>
    
    <h4>Orthogonal Version</h4>
    <table class="pse-table">
        <thead>
            <tr>
                <th>Motion Type</th>
                <th>Left Field PSE (DVA)</th>
                <th>Right Field PSE (DVA)</th>
                <th>Upper Field PSE (DVA)</th>
                <th>Lower Field PSE (DVA)</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Petal</strong></td>
                <td>', safe_extract(orthogonal_results, "petal_left", "PSE"), ' (n = ', safe_extract(orthogonal_results, "petal_left", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "petal_right", "PSE"), ' (n = ', safe_extract(orthogonal_results, "petal_right", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "petal_upper", "PSE"), ' (n = ', safe_extract(orthogonal_results, "petal_upper", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "petal_lower", "PSE"), ' (n = ', safe_extract(orthogonal_results, "petal_lower", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Fugal</strong></td>
                <td>', safe_extract(orthogonal_results, "fugal_left", "PSE"), ' (n = ', safe_extract(orthogonal_results, "fugal_left", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "fugal_right", "PSE"), ' (n = ', safe_extract(orthogonal_results, "fugal_right", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "fugal_upper", "PSE"), ' (n = ', safe_extract(orthogonal_results, "fugal_upper", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "fugal_lower", "PSE"), ' (n = ', safe_extract(orthogonal_results, "fugal_lower", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Control</strong></td>
                <td>', safe_extract(orthogonal_results, "uniform_control_left", "PSE"), ' (n = ', safe_extract(orthogonal_results, "uniform_control_left", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "uniform_control_right", "PSE"), ' (n = ', safe_extract(orthogonal_results, "uniform_control_right", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "uniform_control_upper", "PSE"), ' (n = ', safe_extract(orthogonal_results, "uniform_control_upper", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "uniform_control_lower", "PSE"), ' (n = ', safe_extract(orthogonal_results, "uniform_control_lower", "n_trials"), ')</td>
            </tr>
        </tbody>
    </table>
    
    <h3>Motion × Eccentricity Effects Summary</h3>
    
    <h4>Radial Version</h4>
    <table class="pse-table">
        <thead>
            <tr>
                <th>Motion Type</th>
                <th>Inner PSE (DVA)</th>
                <th>Outer PSE (DVA)</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Petal</strong></td>
                <td>', safe_extract(radial_results, "petal_inner", "PSE"), ' (n = ', safe_extract(radial_results, "petal_inner", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "petal_outer", "PSE"), ' (n = ', safe_extract(radial_results, "petal_outer", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Fugal</strong></td>
                <td>', safe_extract(radial_results, "fugal_inner", "PSE"), ' (n = ', safe_extract(radial_results, "fugal_inner", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "fugal_outer", "PSE"), ' (n = ', safe_extract(radial_results, "fugal_outer", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Control</strong></td>
                <td>', safe_extract(radial_results, "uniform_control_inner", "PSE"), ' (n = ', safe_extract(radial_results, "uniform_control_inner", "n_trials"), ')</td>
                <td>', safe_extract(radial_results, "uniform_control_outer", "PSE"), ' (n = ', safe_extract(radial_results, "uniform_control_outer", "n_trials"), ')</td>
            </tr>
        </tbody>
    </table>
    
    <h4>Orthogonal Version</h4>
    <table class="pse-table">
        <thead>
            <tr>
                <th>Motion Type</th>
                <th>Inner PSE (DVA)</th>
                <th>Outer PSE (DVA)</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Petal</strong></td>
                <td>', safe_extract(orthogonal_results, "petal_inner", "PSE"), ' (n = ', safe_extract(orthogonal_results, "petal_inner", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "petal_outer", "PSE"), ' (n = ', safe_extract(orthogonal_results, "petal_outer", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Fugal</strong></td>
                <td>', safe_extract(orthogonal_results, "fugal_inner", "PSE"), ' (n = ', safe_extract(orthogonal_results, "fugal_inner", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "fugal_outer", "PSE"), ' (n = ', safe_extract(orthogonal_results, "fugal_outer", "n_trials"), ')</td>
            </tr>
            <tr>
                <td><strong>Control</strong></td>
                <td>', safe_extract(orthogonal_results, "uniform_control_inner", "PSE"), ' (n = ', safe_extract(orthogonal_results, "uniform_control_inner", "n_trials"), ')</td>
                <td>', safe_extract(orthogonal_results, "uniform_control_outer", "PSE"), ' (n = ', safe_extract(orthogonal_results, "uniform_control_outer", "n_trials"), ')</td>
            </tr>
        </tbody>
    </table>')

# Methods
html_content <- paste0(html_content, '
    <h2>Methods & Interpretation Guide</h2>
    <h3>Psychometric Function Fitting</h3>
    <p><strong>Model:</strong> Logistic regression: P(response = "outer") = 1 / (1 + exp(-(β₀ + β₁ × probe_offset)))</p>
    <p><strong>PSE Calculation:</strong> Point of Subjective Equality = -β₀/β₁ (50% threshold in DVA)</p>
    <p><strong>Slope:</strong> β₁ parameter (measure of sensitivity/discrimination threshold)</p>
    
    <h3>Statistical Testing Framework</h3>
    <p><strong>Primary Hypothesis Tests:</strong></p>
    <ul>
        <li><em>Within-task comparisons:</em> Paired t-tests for petal vs. fugal vs. control within each task</li>
        <li><em>Cross-task comparisons:</em> Independent t-tests for radial vs. orthogonal within each motion type</li>
    </ul>
    <p><strong>Secondary Analysis:</strong></p>
    <ul>
        <li>Eccentricity effects: Inner (6-8°) vs. outer (10-12°) PSE differences</li>
        <li>Visual field effects: Upper vs. lower and left vs. right hemifield differences</li>
        <li>Interaction analysis: Motion × spatial factor combinations</li>
    </ul>
    
    <hr>
    <p><em>Generated: ', Sys.time(), ' | Flash Grab Experiment Statistical Analysis Pipeline</em></p>
    <p><em>Analysis focused on within-subject comparisons for publication-ready results</em></p>
</body>
</html>')

writeLines(html_content, html_file)
cat("HTML report created:", html_file, "\n")

cat("\n", rep("=", 80), "\n")
cat("ANALYSIS COMPLETE\n") 
cat(rep("=", 80), "\n")