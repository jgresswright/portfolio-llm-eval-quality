# Generate Synthetic LLM Evaluation Data
# This creates realistic evaluation patterns without using any proprietary data

library(tidyverse)

set.seed(42)  # For reproducibility

# Configuration
n_evaluations <- 1000
n_raters <- 15
n_raters_per_eval <- 3

# Generate base evaluation characteristics
evaluations_base <- tibble(
  eval_id = 1:n_evaluations,
  
  # Response characteristics that affect evaluation difficulty
  response_length = sample(c("short", "medium", "long"), 
                          n_evaluations, 
                          replace = TRUE,
                          prob = c(0.3, 0.5, 0.2)),
  
  query_complexity = sample(c("simple", "moderate", "complex"), 
                           n_evaluations, 
                           replace = TRUE,
                           prob = c(0.25, 0.5, 0.25)),
  
  domain = sample(c("factual", "creative", "technical", "opinion"),
                 n_evaluations, 
                 replace = TRUE,
                 prob = c(0.3, 0.2, 0.3, 0.2)),
  
  # Ground truth quality score (1-5 scale)
  true_quality = sample(1:5, n_evaluations, replace = TRUE)
)

# Add difficulty score (affects disagreement likelihood)
evaluations_base <- evaluations_base %>%
  mutate(
    difficulty = case_when(
      query_complexity == "complex" & domain == "opinion" ~ 3,
      query_complexity == "complex" | domain == "opinion" ~ 2,
      TRUE ~ 1
    )
  )

# Generate rater assignments (3 raters per evaluation)
generate_rater_assignments <- function(n_eval, n_raters, n_per_eval) {
  map_dfr(1:n_eval, function(eval_id) {
    raters <- sample(1:n_raters, n_per_eval, replace = FALSE)
    tibble(
      eval_id = eval_id,
      rater_id = raters,
      rater_position = 1:n_per_eval
    )
  })
}

rater_assignments <- generate_rater_assignments(n_evaluations, n_raters, n_raters_per_eval)

# Generate individual rater characteristics (affects their rating patterns)
rater_profiles <- tibble(
  rater_id = 1:n_raters,
  # Rater tendency: lenient, moderate, strict
  tendency = sample(c("lenient", "moderate", "strict"), 
                   n_raters, 
                   replace = TRUE,
                   prob = c(0.2, 0.6, 0.2)),
  # Rater consistency (lower = more noise in ratings)
  consistency = runif(n_raters, min = 0.6, max = 0.95),
  # Domain expertise (affects accuracy in certain domains)
  expertise_domain = sample(c("factual", "creative", "technical", "opinion", "general"),
                           n_raters,
                           replace = TRUE)
)

# Generate ratings based on ground truth, rater profiles, and evaluation difficulty
generate_ratings <- function(eval_data, assignments, rater_profiles) {
  assignments %>%
    left_join(eval_data, by = "eval_id") %>%
    left_join(rater_profiles, by = "rater_id") %>%
    mutate(
      # Base rating starts from true quality
      base_rating = true_quality,
      
      # Apply rater tendency
      tendency_adjustment = case_when(
        tendency == "lenient" ~ 0.5,
        tendency == "strict" ~ -0.5,
        TRUE ~ 0
      ),
      
      # Apply rater consistency (random noise inversely proportional to consistency)
      consistency_noise = rnorm(n(), mean = 0, sd = (1 - consistency) * 1.5),
      
      # Apply difficulty factor (more difficult = more variance)
      difficulty_noise = rnorm(n(), mean = 0, sd = difficulty * 0.5),
      
      # Expertise bonus (more accurate in their domain)
      expertise_bonus = if_else(
        expertise_domain == domain | expertise_domain == "general",
        0.2,  # Slight accuracy boost
        -0.1  # Slight accuracy penalty
      ),
      
      # Calculate final rating
      raw_rating = base_rating + 
                   tendency_adjustment + 
                   consistency_noise + 
                   difficulty_noise + 
                   expertise_bonus,
      
      # Constrain to valid 1-5 range and round
      rating = pmax(1, pmin(5, round(raw_rating)))
    ) %>%
    select(eval_id, rater_id, rater_position, rating, 
           response_length, query_complexity, domain, true_quality, difficulty)
}

ratings_long <- generate_ratings(evaluations_base, rater_assignments, rater_profiles)

# Convert to wide format for easier IRR analysis
ratings_wide <- ratings_long %>%
  select(eval_id, rater_position, rating) %>%
  pivot_wider(
    names_from = rater_position,
    values_from = rating,
    names_prefix = "rater_"
  ) %>%
  left_join(
    evaluations_base %>% select(eval_id, response_length, query_complexity, domain, true_quality),
    by = "eval_id"
  )

# Create rater-level summary statistics
rater_summary <- ratings_long %>%
  group_by(rater_id) %>%
  summarize(
    n_evaluations = n(),
    mean_rating = mean(rating),
    sd_rating = sd(rating),
    accuracy = mean(rating == true_quality),
    within_one = mean(abs(rating - true_quality) <= 1),
    .groups = "drop"
  ) %>%
  left_join(rater_profiles, by = "rater_id")

# Save datasets
write_csv(ratings_wide, "data/evaluations_wide.csv")
write_csv(ratings_long, "data/evaluations_long.csv")
write_csv(rater_summary, "data/rater_summary.csv")
write_csv(rater_profiles, "data/rater_profiles.csv")

# Print summary statistics
cat("\n=== Synthetic Data Generation Complete ===\n\n")
cat("Total evaluations:", n_evaluations, "\n")
cat("Total raters:", n_raters, "\n")
cat("Raters per evaluation:", n_raters_per_eval, "\n\n")

cat("Domain distribution:\n")
print(table(evaluations_base$domain))

cat("\nComplexity distribution:\n")
print(table(evaluations_base$query_complexity))

cat("\nOverall rating distribution:\n")
print(table(ratings_long$rating))

cat("\nMean accuracy across raters:", 
    round(mean(ratings_long$rating == ratings_long$true_quality), 3), "\n")

cat("\nData saved to:\n")
cat("  - data/evaluations_wide.csv\n")
cat("  - data/evaluations_long.csv\n")
cat("  - data/rater_summary.csv\n")
cat("  - data/rater_profiles.csv\n")