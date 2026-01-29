# Inter-Rater Reliability Analysis
# Calculate agreement statistics across raters

library(tidyverse)
library(irr)  # For inter-rater reliability metrics

# Load data
ratings_wide <- read_csv("data/evaluations_wide.csv")
ratings_long <- read_csv("data/evaluations_long.csv")

# ============================================================================
# 1. OVERALL INTER-RATER RELIABILITY
# ============================================================================

# Prepare data for Fleiss' Kappa (multiple raters)
ratings_matrix <- ratings_wide %>%
  select(rater_1, rater_2, rater_3) %>%
  as.matrix()

# Calculate Fleiss' Kappa
fleiss_result <- kappam.fleiss(ratings_matrix)

cat("\n=== Overall Inter-Rater Reliability ===\n\n")
cat("Fleiss' Kappa:", round(fleiss_result$value, 3), "\n")
cat("Interpretation:", 
    case_when(
      fleiss_result$value < 0.20 ~ "Poor agreement",
      fleiss_result$value < 0.40 ~ "Fair agreement",
      fleiss_result$value < 0.60 ~ "Moderate agreement",
      fleiss_result$value < 0.80 ~ "Substantial agreement",
      TRUE ~ "Almost perfect agreement"
    ), "\n\n")

# Calculate overall agreement percentage
simple_agreement <- ratings_wide %>%
  mutate(
    all_agree = (rater_1 == rater_2) & (rater_2 == rater_3),
    two_agree = (rater_1 == rater_2) | (rater_2 == rater_3) | (rater_1 == rater_3)
  ) %>%
  summarize(
    pct_all_agree = mean(all_agree) * 100,
    pct_two_agree = mean(two_agree) * 100
  )

cat("Perfect agreement (all 3 raters):", 
    round(simple_agreement$pct_all_agree, 1), "%\n")
cat("Partial agreement (at least 2 raters):", 
    round(simple_agreement$pct_two_agree, 1), "%\n\n")

# ============================================================================
# 2. IRR BY EVALUATION CHARACTERISTICS
# ============================================================================

cat("=== Agreement by Evaluation Type ===\n\n")

# Agreement by domain
agreement_by_domain <- ratings_wide %>%
  mutate(
    all_agree = (rater_1 == rater_2) & (rater_2 == rater_3)
  ) %>%
  group_by(domain) %>%
  summarize(
    n = n(),
    agreement_rate = mean(all_agree) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(agreement_rate))

cat("Agreement by Domain:\n")
print(agreement_by_domain, n = Inf)
cat("\n")

# Agreement by complexity
agreement_by_complexity <- ratings_wide %>%
  mutate(
    all_agree = (rater_1 == rater_2) & (rater_2 == rater_3)
  ) %>%
  group_by(query_complexity) %>%
  summarize(
    n = n(),
    agreement_rate = mean(all_agree) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(agreement_rate))

cat("Agreement by Complexity:\n")
print(agreement_by_complexity, n = Inf)
cat("\n")

# ============================================================================
# 3. PAIRWISE RATER AGREEMENT
# ============================================================================

cat("=== Pairwise Rater Agreement ===\n\n")

# Calculate Cohen's Kappa for each rater pair
rater_pairs <- combn(1:3, 2)
pairwise_kappa <- map_dfr(1:ncol(rater_pairs), function(i) {
  r1 <- rater_pairs[1, i]
  r2 <- rater_pairs[2, i]
  
  ratings_pair <- ratings_wide %>%
    select(all_of(c(paste0("rater_", r1), paste0("rater_", r2)))) %>%
    na.omit()
  
  kappa_result <- kappa2(ratings_pair)
  
  tibble(
    pair = paste0("Rater ", r1, " vs Rater ", r2),
    kappa = kappa_result$value,
    agreement_pct = mean(ratings_pair[[1]] == ratings_pair[[2]]) * 100
  )
})

print(pairwise_kappa)
cat("\n")

# ============================================================================
# 4. DISAGREEMENT PATTERNS
# ============================================================================

cat("=== Disagreement Analysis ===\n\n")

# Calculate disagreement magnitude
disagreement_analysis <- ratings_wide %>%
  mutate(
    # Maximum distance between any two raters
    max_disagreement = pmax(
      abs(rater_1 - rater_2),
      abs(rater_2 - rater_3),
      abs(rater_1 - rater_3)
    ),
    # Standard deviation across three raters
    rating_sd = apply(select(., rater_1, rater_2, rater_3), 1, sd)
  )

cat("Disagreement magnitude distribution:\n")
print(table(disagreement_analysis$max_disagreement))
cat("\n")

# Disagreement by evaluation characteristics
disagreement_by_type <- disagreement_analysis %>%
  group_by(domain, query_complexity) %>%
  summarize(
    n = n(),
    mean_disagreement = mean(max_disagreement),
    sd_disagreement = sd(max_disagreement),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_disagreement))

cat("Mean disagreement by type (top 5):\n")
print(head(disagreement_by_type, 5), n = Inf)
cat("\n")

# ============================================================================
# 5. RATER-SPECIFIC AGREEMENT PATTERNS
# ============================================================================

cat("=== Individual Rater Agreement Patterns ===\n\n")

# For each rater in position 1, calculate agreement with positions 2 and 3
rater_agreement <- ratings_long %>%
  filter(rater_position == 1) %>%
  select(eval_id, rater_id, rating) %>%
  rename(rater1_id = rater_id, rater1_rating = rating) %>%
  left_join(
    ratings_long %>%
      filter(rater_position == 2) %>%
      select(eval_id, rating) %>%
      rename(rater2_rating = rating),
    by = "eval_id"
  ) %>%
  left_join(
    ratings_long %>%
      filter(rater_position == 3) %>%
      select(eval_id, rating) %>%
      rename(rater3_rating = rating),
    by = "eval_id"
  ) %>%
  group_by(rater1_id) %>%
  summarize(
    n_evaluations = n(),
    agreement_with_r2 = mean(rater1_rating == rater2_rating) * 100,
    agreement_with_r3 = mean(rater1_rating == rater3_rating) * 100,
    mean_agreement = mean(c(
      rater1_rating == rater2_rating,
      rater1_rating == rater3_rating
    )) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(mean_agreement))

cat("Top 5 most consistent raters:\n")
print(head(rater_agreement, 5), n = Inf)
cat("\n")

cat("Bottom 5 most inconsistent raters:\n")
print(tail(rater_agreement, 5), n = Inf)
cat("\n")

# ============================================================================
# 6. SAVE RESULTS
# ============================================================================

# Save all analysis results
irr_results <- list(
  overall_fleiss_kappa = fleiss_result$value,
  simple_agreement = simple_agreement,
  agreement_by_domain = agreement_by_domain,
  agreement_by_complexity = agreement_by_complexity,
  pairwise_kappa = pairwise_kappa,
  disagreement_summary = disagreement_by_type,
  rater_agreement = rater_agreement
)

saveRDS(irr_results, "output/irr_analysis_results.rds")

cat("Analysis complete. Results saved to output/irr_analysis_results.rds\n")