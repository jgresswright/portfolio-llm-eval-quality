# Individual Rater Pair Agreement Analysis
# This analyzes agreement between SPECIFIC raters, not just positions

library(tidyverse)

# Load data
ratings_long <- read_csv("data/evaluations_long.csv")

# Create all possible rater pairs that actually evaluated together
rater_pairs_analysis <- ratings_long %>%
  select(eval_id, rater_id, rating) %>%
  # Self-join to get all rater pairs for each evaluation
  inner_join(
    ratings_long %>% select(eval_id, rater_id, rating),
    by = "eval_id",
    suffix = c("_1", "_2")
  ) %>%
  # Keep only unique pairs (remove duplicates and self-comparisons)
  filter(rater_id_1 < rater_id_2) %>%
  # Calculate agreement
  mutate(agree = rating_1 == rating_2) %>%
  group_by(rater_id_1, rater_id_2) %>%
  summarize(
    n_shared_evals = n(),
    agreement_rate = mean(agree) * 100,
    mean_difference = mean(abs(rating_1 - rating_2)),
    .groups = "drop"
  ) %>%
  arrange(desc(agreement_rate))

cat("\n=== Individual Rater Pair Analysis ===\n\n")

cat("Most agreeable rater pairs (top 10):\n")
print(head(rater_pairs_analysis, 10), n = Inf)

cat("\nLeast agreeable rater pairs (bottom 10):\n")
print(tail(rater_pairs_analysis, 10), n = Inf)

cat("\nSummary statistics:\n")
cat("Mean agreement across all pairs:", 
    round(mean(rater_pairs_analysis$agreement_rate), 1), "%\n")
cat("Range:", 
    round(min(rater_pairs_analysis$agreement_rate), 1), "% to",
    round(max(rater_pairs_analysis$agreement_rate), 1), "%\n")

# Identify raters who are consistently more agreeable
rater_agreeability <- bind_rows(
  rater_pairs_analysis %>% 
    select(rater_id = rater_id_1, agreement_rate, n_shared_evals),
  rater_pairs_analysis %>% 
    select(rater_id = rater_id_2, agreement_rate, n_shared_evals)
) %>%
  group_by(rater_id) %>%
  summarize(
    mean_agreement_with_others = mean(agreement_rate),
    total_comparisons = sum(n_shared_evals),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_agreement_with_others))

cat("\n=== Individual Rater Agreeability ===\n")
cat("(How much does each rater agree with others on average)\n\n")
print(rater_agreeability, n = Inf)

# Save results
saveRDS(list(
  rater_pairs = rater_pairs_analysis,
  rater_agreeability = rater_agreeability
), "output/individual_rater_analysis.rds")

cat("\nResults saved to output/individual_rater_analysis.rds\n")