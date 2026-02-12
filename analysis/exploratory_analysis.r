# Exploratory Data Analysis
# Initial exploration of evaluation patterns and distributions

library(tidyverse)

# Use production data (frozen for reproducibility)
DATA_DIR <- "data/production/"

# Load frozen production data to ensure reproducibility
# (regenerating synthetic data would invalidate README findings)
ratings_wide <- read_csv(paste0(DATA_DIR, "evaluations_wide.csv"))
ratings_long <- read_csv(paste0(DATA_DIR, "evaluations_long.csv"))
rater_summary <- read_csv(paste0(DATA_DIR, "rater_summary.csv"))
rater_profiles <- read_csv(paste0(DATA_DIR, "rater_profiles.csv"))

cat("\n=== EXPLORATORY DATA ANALYSIS ===\n\n")

# ============================================================================
# 1. DATASET OVERVIEW
# ============================================================================

cat("1. DATASET OVERVIEW\n")
cat("-------------------\n")
cat("Total evaluations:", nrow(ratings_wide), "\n")
cat("Total raters:", length(unique(rater_profiles$rater_id)), "\n")
cat("Total individual ratings:", nrow(ratings_long), "\n\n")

# ============================================================================
# 2. EVALUATION CHARACTERISTICS DISTRIBUTION
# ============================================================================

cat("2. EVALUATION CHARACTERISTICS\n")
cat("------------------------------\n\n")

cat("Domain distribution:\n")
domain_dist <- table(ratings_wide$domain)
print(domain_dist)
cat("\nPercentages:\n")
print(round(prop.table(domain_dist) * 100, 1))
cat("\n")

cat("Query complexity distribution:\n")
complexity_dist <- table(ratings_wide$query_complexity)
print(complexity_dist)
cat("\nPercentages:\n")
print(round(prop.table(complexity_dist) * 100, 1))
cat("\n")

cat("Response length distribution:\n")
length_dist <- table(ratings_wide$response_length)
print(length_dist)
cat("\nPercentages:\n")
print(round(prop.table(length_dist) * 100, 1))
cat("\n")

# ============================================================================
# 3. RATING DISTRIBUTION ANALYSIS
# ============================================================================

cat("3. RATING DISTRIBUTIONS\n")
cat("-----------------------\n\n")

cat("Overall rating distribution (all ratings):\n")
rating_dist <- table(ratings_long$rating)
print(rating_dist)
cat("\nPercentages:\n")
print(round(prop.table(rating_dist) * 100, 1))
cat("\n")

cat("Mean rating:", round(mean(ratings_long$rating), 2), "\n")
cat("Median rating:", median(ratings_long$rating), "\n")
cat("Std deviation:", round(sd(ratings_long$rating), 2), "\n\n")

# Rating distribution by position
cat("Rating distribution by rater position:\n")
position_ratings <- ratings_long %>%
  group_by(rater_position) %>%
  summarize(
    mean_rating = mean(rating),
    median_rating = median(rating),
    sd_rating = sd(rating),
    .groups = "drop"
  )
print(position_ratings)
cat("\n")

# ============================================================================
# 4. GROUND TRUTH ANALYSIS
# ============================================================================

cat("4. GROUND TRUTH DISTRIBUTION\n")
cat("----------------------------\n\n")

cat("True quality distribution:\n")
true_quality_dist <- table(ratings_wide$true_quality)
print(true_quality_dist)
cat("\nPercentages:\n")
print(round(prop.table(true_quality_dist) * 100, 1))
cat("\n")

# ============================================================================
# 5. RATING VARIANCE PATTERNS
# ============================================================================

cat("5. RATING VARIANCE ANALYSIS\n")
cat("---------------------------\n\n")

# Calculate variance across three raters for each evaluation
rating_variance <- ratings_wide %>%
  mutate(
    rating_sd = apply(select(., rater_1, rater_2, rater_3), 1, sd),
    rating_range = pmax(rater_1, rater_2, rater_3) - pmin(rater_1, rater_2, rater_3)
  )

cat("Mean standard deviation across raters:", round(mean(rating_variance$rating_sd), 2), "\n")
cat("Mean rating range:", round(mean(rating_variance$rating_range), 2), "\n\n")

cat("Distribution of rating ranges:\n")
print(table(rating_variance$rating_range))
cat("\n")

# Variance by evaluation characteristics
variance_by_domain <- rating_variance %>%
  group_by(domain) %>%
  summarize(
    n = n(),
    mean_sd = mean(rating_sd),
    mean_range = mean(rating_range),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_sd))

cat("Rating variance by domain:\n")
print(variance_by_domain, n = Inf)
cat("\n")

variance_by_complexity <- rating_variance %>%
  group_by(query_complexity) %>%
  summarize(
    n = n(),
    mean_sd = mean(rating_sd),
    mean_range = mean(rating_range),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_sd))

cat("Rating variance by complexity:\n")
print(variance_by_complexity, n = Inf)
cat("\n")

# ============================================================================
# 6. RATER PROFILE ANALYSIS
# ============================================================================

cat("6. RATER CHARACTERISTICS\n")
cat("------------------------\n\n")

cat("Rater tendency distribution:\n")
print(table(rater_profiles$tendency))
cat("\n")

cat("Rater expertise distribution:\n")
print(table(rater_profiles$expertise_domain))
cat("\n")

# Parameter verification (not a discovery - just confirming data generation)
cat("Consistency scores:\n")
cat("Mean:", round(mean(rater_profiles$consistency), 3), "\n")
cat("Range:", round(min(rater_profiles$consistency), 3), "to", 
    round(max(rater_profiles$consistency), 3), "\n\n")

# ============================================================================
# 7. CROSS-TABULATIONS
# ============================================================================

cat("7. EVALUATION TYPE COMBINATIONS\n")
cat("-------------------------------\n\n")

cat("Domain × Complexity distribution:\n")
domain_complexity <- table(ratings_wide$domain, ratings_wide$query_complexity)
print(domain_complexity)
cat("\n")

# ============================================================================
# 8. KEY INSIGHTS SUMMARY
# ============================================================================

cat("8. KEY EXPLORATORY INSIGHTS\n")
cat("---------------------------\n\n")

cat("• Most common domain:", names(which.max(domain_dist)), "\n")
cat("• Most common complexity:", names(which.max(complexity_dist)), "\n")
cat("• Most common rating:", names(which.max(rating_dist)), "\n")
cat("• Domain with highest variance:", variance_by_domain$domain[1], 
    "(SD =", round(variance_by_domain$mean_sd[1], 2), ")\n")
cat("• Complexity with highest variance:", variance_by_complexity$query_complexity[1],
    "(SD =", round(variance_by_complexity$mean_sd[1], 2), ")\n")

cat("\n=== Exploratory Analysis Complete ===\n\n")

# Save key statistics
exploratory_results <- list(
  domain_dist = domain_dist,
  complexity_dist = complexity_dist,
  rating_dist = rating_dist,
  variance_by_domain = variance_by_domain,
  variance_by_complexity = variance_by_complexity,
  rater_profiles_summary = rater_profiles
)

saveRDS(exploratory_results, "output/exploratory_analysis_results.rds")
cat("Results saved to output/exploratory_analysis_results.rds\n")