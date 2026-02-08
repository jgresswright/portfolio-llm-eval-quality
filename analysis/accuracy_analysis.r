# Accuracy Analysis
# Compare rater judgments to ground truth quality scores

library(tidyverse)

# Use production data (frozen for reproducibility)
DATA_DIR <- "data/production/"

# Load data
ratings_long <- read_csv(paste0(DATA_DIR, "evaluations_long.csv"))
rater_summary <- read_csv(paste0(DATA_DIR, "rater_summary.csv"))
rater_profiles <- read_csv(paste0(DATA_DIR, "rater_profiles.csv"))

cat("\n=== ACCURACY ANALYSIS ===\n\n")

# ============================================================================
# 1. OVERALL ACCURACY
# ============================================================================

cat("1. OVERALL ACCURACY METRICS\n")
cat("---------------------------\n\n")

# Exact match accuracy
exact_accuracy <- mean(ratings_long$rating == ratings_long$true_quality) * 100
cat("Exact match accuracy:", round(exact_accuracy, 1), "%\n")

# Within 1 point accuracy
within_one <- mean(abs(ratings_long$rating - ratings_long$true_quality) <= 1) * 100
cat("Within ±1 accuracy:", round(within_one, 1), "%\n\n")

# Distribution of errors
errors <- ratings_long %>%
  mutate(error = rating - true_quality)

cat("Error distribution:\n")
print(table(errors$error))
cat("\n")

cat("Mean error (bias):", round(mean(errors$error), 3), "\n")
cat("Mean absolute error:", round(mean(abs(errors$error)), 3), "\n\n")

# ============================================================================
# 2. ACCURACY BY EVALUATION CHARACTERISTICS
# ============================================================================

cat("2. ACCURACY BY EVALUATION TYPE\n")
cat("------------------------------\n\n")

# Accuracy by domain
accuracy_by_domain <- ratings_long %>%
  group_by(domain) %>%
  summarize(
    n = n(),
    exact_accuracy = mean(rating == true_quality) * 100,
    within_one = mean(abs(rating - true_quality) <= 1) * 100,
    mean_absolute_error = mean(abs(rating - true_quality)),
    .groups = "drop"
  ) %>%
  arrange(desc(exact_accuracy))

cat("Accuracy by domain:\n")
print(accuracy_by_domain, n = Inf)
cat("\n")

# Accuracy by complexity
accuracy_by_complexity <- ratings_long %>%
  mutate(query_complexity = factor(query_complexity, 
                                   levels = c("simple", "moderate", "complex"))) %>%
  group_by(query_complexity) %>%
  summarize(
    n = n(),
    exact_accuracy = mean(rating == true_quality) * 100,
    within_one = mean(abs(rating - true_quality) <= 1) * 100,
    mean_absolute_error = mean(abs(rating - true_quality)),
    .groups = "drop"
  )

cat("Accuracy by query complexity:\n")
print(accuracy_by_complexity, n = Inf)
cat("\n")

# Accuracy by response length
accuracy_by_length <- ratings_long %>%
  group_by(response_length) %>%
  summarize(
    n = n(),
    exact_accuracy = mean(rating == true_quality) * 100,
    within_one = mean(abs(rating - true_quality) <= 1) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(exact_accuracy))

cat("Accuracy by response length:\n")
print(accuracy_by_length, n = Inf)
cat("\n")

# ============================================================================
# 3. INDIVIDUAL RATER ACCURACY
# ============================================================================

cat("3. INDIVIDUAL RATER PERFORMANCE\n")
cat("-------------------------------\n\n")

# Detailed rater accuracy with profiles
rater_accuracy_detailed <- ratings_long %>%
  group_by(rater_id) %>%
  summarize(
    n_ratings = n(),
    exact_accuracy = mean(rating == true_quality) * 100,
    within_one = mean(abs(rating - true_quality) <= 1) * 100,
    mean_error = mean(rating - true_quality),
    mean_absolute_error = mean(abs(rating - true_quality)),
    .groups = "drop"
  ) %>%
  left_join(rater_profiles, by = "rater_id") %>%
  arrange(desc(exact_accuracy))

cat("Top 5 most accurate raters:\n")
print(head(rater_accuracy_detailed %>% 
            select(rater_id, exact_accuracy, tendency, expertise_domain, consistency), 5), 
      n = Inf)
cat("\n")

cat("Bottom 5 least accurate raters:\n")
print(tail(rater_accuracy_detailed %>% 
            select(rater_id, exact_accuracy, tendency, expertise_domain, consistency), 5), 
      n = Inf)
cat("\n")

# ============================================================================
# 4. ACCURACY BY RATER CHARACTERISTICS
# ============================================================================

cat("4. ACCURACY BY RATER PROFILE\n")
cat("----------------------------\n\n")

# Accuracy by rater tendency
accuracy_by_tendency <- rater_accuracy_detailed %>%
  group_by(tendency) %>%
  summarize(
    n_raters = n(),
    mean_accuracy = mean(exact_accuracy),
    sd_accuracy = sd(exact_accuracy),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_accuracy))

cat("Accuracy by rater tendency:\n")
print(accuracy_by_tendency, n = Inf)
cat("\n")

# Accuracy by expertise match
accuracy_by_expertise <- ratings_long %>%
  left_join(rater_profiles, by = "rater_id") %>%
  mutate(
    expertise_match = (expertise_domain == domain) | (expertise_domain == "general")
  ) %>%
  group_by(expertise_match) %>%
  summarize(
    n = n(),
    exact_accuracy = mean(rating == true_quality) * 100,
    within_one = mean(abs(rating - true_quality) <= 1) * 100,
    .groups = "drop"
  )

cat("Accuracy by expertise match:\n")
print(accuracy_by_expertise, n = Inf)
cat("\n")

# Correlation between consistency and accuracy
cat("Correlation between rater consistency and accuracy:\n")
consistency_accuracy_cor <- cor(rater_accuracy_detailed$consistency, 
                                 rater_accuracy_detailed$exact_accuracy)
cat("Correlation coefficient:", round(consistency_accuracy_cor, 3), "\n\n")

# ============================================================================
# 5. SYSTEMATIC BIAS DETECTION
# ============================================================================

cat("5. SYSTEMATIC BIAS PATTERNS\n")
cat("---------------------------\n\n")

# Bias by true quality level
bias_by_true_quality <- ratings_long %>%
  group_by(true_quality) %>%
  summarize(
    n = n(),
    mean_rating = mean(rating),
    mean_error = mean(rating - true_quality),
    pct_overrated = mean(rating > true_quality) * 100,
    pct_underrated = mean(rating < true_quality) * 100,
    .groups = "drop"
  )

cat("Bias patterns by true quality level:\n")
print(bias_by_true_quality, n = Inf)
cat("\n")

# Identify raters with systematic bias
biased_raters <- rater_accuracy_detailed %>%
  filter(abs(mean_error) > 0.3) %>%
  select(rater_id, mean_error, tendency, exact_accuracy) %>%
  arrange(desc(abs(mean_error)))

cat("Raters with potential systematic bias (|error| > 0.3):\n")
if (nrow(biased_raters) > 0) {
  print(biased_raters, n = Inf)
} else {
  cat("No raters with systematic bias detected.\n")
}
cat("\n")

# ============================================================================
# 6. CONFUSION MATRIX ANALYSIS
# ============================================================================

cat("6. RATING CONFUSION PATTERNS\n")
cat("----------------------------\n\n")

# Create confusion matrix
confusion_matrix <- ratings_long %>%
  count(true_quality, rating) %>%
  pivot_wider(names_from = rating, values_from = n, values_fill = 0, names_prefix = "rated_")

cat("Confusion matrix (rows = true quality, columns = given rating):\n")
print(confusion_matrix)
cat("\n")

# ============================================================================
# 7. KEY INSIGHTS SUMMARY
# ============================================================================

cat("7. KEY ACCURACY INSIGHTS\n")
cat("------------------------\n\n")

cat("• Overall exact accuracy:", round(exact_accuracy, 1), "%\n")
cat("• Within ±1 accuracy:", round(within_one, 1), "%\n")
cat("• Most accurate domain:", accuracy_by_domain$domain[1],
    "(", round(accuracy_by_domain$exact_accuracy[1], 1), "%)\n")
cat("• Least accurate domain:", tail(accuracy_by_domain$domain, 1),
    "(", round(tail(accuracy_by_domain$exact_accuracy, 1), 1), "%)\n")
cat("• Most accurate complexity:", accuracy_by_complexity$query_complexity[1],
    "(", round(accuracy_by_complexity$exact_accuracy[1], 1), "%)\n")
cat("• Expertise match benefit:", 
    round(accuracy_by_expertise$exact_accuracy[accuracy_by_expertise$expertise_match == TRUE] -
          accuracy_by_expertise$exact_accuracy[accuracy_by_expertise$expertise_match == FALSE], 1),
    "percentage points\n")
cat("• Best performing tendency:", accuracy_by_tendency$tendency[1], "\n")

cat("\n=== Accuracy Analysis Complete ===\n\n")

# Save results
accuracy_results <- list(
  overall_accuracy = exact_accuracy,
  within_one_accuracy = within_one,
  accuracy_by_domain = accuracy_by_domain,
  accuracy_by_complexity = accuracy_by_complexity,
  rater_accuracy = rater_accuracy_detailed,
  accuracy_by_tendency = accuracy_by_tendency,
  accuracy_by_expertise = accuracy_by_expertise,
  confusion_matrix = confusion_matrix
)

saveRDS(accuracy_results, "output/accuracy_analysis_results.rds")
cat("Results saved to output/accuracy_analysis_results.rds\n")