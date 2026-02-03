# Professional Visualizations for LLM Evaluation Quality Analysis

library(tidyverse)
library(scales)
library(patchwork)  # For combining plots

# Create output directory if it doesn't exist
if (!dir.exists("output/figures")) {
  dir.create("output/figures", recursive = TRUE)
}

# Load data
ratings_wide <- read_csv("data/evaluations_wide.csv")
ratings_long <- read_csv("data/evaluations_long.csv")
rater_summary <- read_csv("data/rater_summary.csv")
irr_results <- readRDS("output/irr_analysis_results.rds")

# Custom theme for professional plots
theme_professional <- theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    axis.title = element_text(size = 11),
    axis.text = element_text(size = 10),
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 9),
    panel.grid.minor = element_blank()
  )

# ============================================================================
# 1. AGREEMENT RATE BY EVALUATION TYPE
# ============================================================================

# Prepare agreement data
agreement_data <- ratings_wide %>%
  mutate(
    all_agree = (rater_1 == rater_2) & (rater_2 == rater_3),
    partial_agree = (rater_1 == rater_2) | (rater_2 == rater_3) | (rater_1 == rater_3)
  )

# By domain
p1 <- agreement_data %>%
  group_by(domain) %>%
  summarize(
    full_agreement = mean(all_agree) * 100,
    partial_agreement = mean(partial_agree) * 100,
    n = n(),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(full_agreement, partial_agreement),
               names_to = "agreement_type",
               values_to = "percentage") %>%
  mutate(agreement_type = recode(agreement_type,
                                 "full_agreement" = "Full Agreement (3/3)",
                                 "partial_agreement" = "Partial Agreement (2+/3)")) %>%
  ggplot(aes(x = reorder(domain, percentage), y = percentage, fill = agreement_type)) +
  geom_col(position = "dodge", width = 0.7) +
  geom_text(aes(label = paste0(round(percentage, 0), "%")),
            position = position_dodge(width = 0.7),
            hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(limits = c(0, 105), labels = percent_format(scale = 1)) +
  scale_fill_manual(values = c("#2E86AB", "#A23B72")) +
  labs(
    title = "Inter-Rater Agreement by Domain",
    subtitle = "Percentage of evaluations with full or partial agreement",
    x = NULL,
    y = "Agreement Rate (%)",
    fill = NULL
  ) +
  theme_professional +
  theme(legend.position = "bottom")

ggsave("output/figures/01_agreement_by_domain.png", p1, 
       width = 8, height = 5, dpi = 300)

# By complexity
p2 <- agreement_data %>%
  group_by(query_complexity) %>%
  summarize(
    full_agreement = mean(all_agree) * 100,
    n = n(),
    .groups = "drop"
  ) %>%
  mutate(query_complexity = factor(query_complexity, 
                                   levels = c("simple", "moderate", "complex"))) %>%
  ggplot(aes(x = query_complexity, y = full_agreement, fill = query_complexity)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(full_agreement, 1), "%")),
            vjust = -0.5, size = 4) +
  scale_y_continuous(limits = c(0, 70), labels = percent_format(scale = 1)) +
  scale_fill_manual(values = c("#06A77D", "#F1A208", "#D11149")) +
  labs(
    title = "Agreement Rate Decreases with Query Complexity",
    subtitle = "Full agreement (3/3 raters) by query complexity level",
    x = "Query Complexity",
    y = "Full Agreement Rate (%)",
    fill = NULL
  ) +
  theme_professional +
  theme(legend.position = "none")

ggsave("output/figures/02_agreement_by_complexity.png", p2,
       width = 7, height = 5, dpi = 300)

# ============================================================================
# 2. RATER ACCURACY COMPARISON
# ============================================================================

p3 <- rater_summary %>%
  arrange(desc(accuracy)) %>%
  mutate(rater_id = factor(rater_id, levels = rater_id)) %>%
  ggplot(aes(x = rater_id, y = accuracy * 100, fill = tendency)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = mean(rater_summary$accuracy) * 100, 
             linetype = "dashed", color = "gray30", linewidth = 0.8) +
  annotate("text", x = 2, y = mean(rater_summary$accuracy) * 100 + 2,
           label = "Mean Accuracy", size = 3, color = "gray30") +
  scale_y_continuous(limits = c(0, 100), labels = percent_format(scale = 1)) +
  scale_fill_manual(values = c("lenient" = "#F1A208", 
                               "moderate" = "#06A77D", 
                               "strict" = "#2E86AB")) +
  labs(
    title = "Rater Accuracy vs. Ground Truth",
    subtitle = "Percentage of ratings matching true quality score",
    x = "Rater ID",
    y = "Accuracy (%)",
    fill = "Rater Tendency"
  ) +
  theme_professional +
  theme(legend.position = "bottom")

ggsave("output/figures/03_rater_accuracy.png", p3,
       width = 9, height = 5, dpi = 300)

# ============================================================================
# 3. DISAGREEMENT HEATMAP
# ============================================================================

# Calculate pairwise disagreement matrix
disagreement_matrix <- ratings_long %>%
  select(eval_id, rater_id, rating) %>%
  pivot_wider(names_from = rater_id, values_from = rating, names_prefix = "rater_") %>%
  select(-eval_id)

# Create disagreement rate matrix
n_raters <- ncol(disagreement_matrix)
disagreement_rates <- matrix(NA, nrow = n_raters, ncol = n_raters)

for (i in 1:n_raters) {
  for (j in 1:n_raters) {
    if (i != j) {
      disagreement_rates[i, j] <- mean(disagreement_matrix[, i] != disagreement_matrix[, j], 
                                       na.rm = TRUE) * 100
    } else {
      disagreement_rates[i, j] <- 0
    }
  }
}

# Convert to long format for ggplot
disagreement_df <- as.data.frame(disagreement_rates) %>%
  mutate(rater1 = 1:n_raters) %>%
  pivot_longer(cols = -rater1, names_to = "rater2", values_to = "disagreement") %>%
  mutate(rater2 = as.numeric(str_remove(rater2, "V")))

p4 <- disagreement_df %>%
  ggplot(aes(x = factor(rater1), y = factor(rater2), fill = disagreement)) +
  geom_tile(color = "white", size = 0.5) +
  geom_text(aes(label = ifelse(disagreement > 0, round(disagreement, 0), "")),
            size = 2.5, color = "white") +
  scale_fill_gradient2(low = "#06A77D", mid = "#F1A208", high = "#D11149",
                      midpoint = 50, limits = c(0, 100),
                      labels = percent_format(scale = 1)) +
  labs(
    title = "Pairwise Rater Disagreement Matrix",
    subtitle = "Percentage of evaluations where rater pairs disagree",
    x = "Rater ID",
    y = "Rater ID",
    fill = "Disagreement\nRate (%)"
  ) +
  theme_professional +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_text(size = 8),
    axis.text.y = element_text(size = 8)
  ) +
  coord_equal()

ggsave("output/figures/04_disagreement_heatmap.png", p4,
       width = 8, height = 7, dpi = 300)

# ============================================================================
# 4. RATING DISTRIBUTION
# ============================================================================

p5 <- ratings_long %>%
  ggplot(aes(x = factor(rating), fill = factor(rating))) +
  geom_bar(width = 0.7) +
  geom_text(stat = "count", aes(label = after_stat(count)), vjust = -0.5) +
  scale_fill_manual(values = c("#D11149", "#F1A208", "#FFD23F", "#A2D729", "#06A77D")) +
  labs(
    title = "Overall Rating Distribution",
    subtitle = paste0("Distribution across all ", 
                     nrow(ratings_long), " individual ratings"),
    x = "Rating (1-5 Scale)",
    y = "Count",
    fill = "Rating"
  ) +
  theme_professional +
  theme(legend.position = "none")

ggsave("output/figures/05_rating_distribution.png", p5,
       width = 7, height = 5, dpi = 300)

# ============================================================================
# 5. ACCURACY BY DOMAIN (RATER PERFORMANCE)
# ============================================================================

accuracy_by_domain <- ratings_long %>%
  mutate(accurate = rating == true_quality) %>%
  group_by(domain) %>%
  summarize(
    accuracy = mean(accurate) * 100,
    n = n(),
    .groups = "drop"
  )

p6 <- accuracy_by_domain %>%
  ggplot(aes(x = reorder(domain, accuracy), y = accuracy, fill = domain)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(round(accuracy, 1), "%")), 
            hjust = -0.1, size = 4) +
  coord_flip() +
  scale_y_continuous(limits = c(0, 65), labels = percent_format(scale = 1)) +
  scale_fill_manual(values = c("#2E86AB", "#A23B72", "#06A77D", "#F1A208")) +
  labs(
    title = "Rater Accuracy by Evaluation Domain",
    subtitle = "Percentage of ratings matching ground truth",
    x = NULL,
    y = "Accuracy (%)",
    fill = NULL
  ) +
  theme_professional +
  theme(legend.position = "none")

ggsave("output/figures/06_accuracy_by_domain.png", p6,
       width = 7, height = 5, dpi = 300)

# ============================================================================
# 6. COMBINED SUMMARY PLOT
# ============================================================================

# Create a 2x2 summary dashboard
summary_plot <- (p2 + p5) / (p1 + p3) +
  plot_annotation(
    title = "LLM Evaluation Quality Analysis Summary",
    subtitle = "Key metrics across 1,000 evaluations by 15 raters",
    theme = theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 12, color = "gray30")
    )
  )

ggsave("output/figures/00_summary_dashboard.png", summary_plot,
       width = 14, height = 10, dpi = 300)

cat("\n=== Visualization Generation Complete ===\n\n")
cat("Generated visualizations:\n")
cat("  1. Agreement by domain\n")
cat("  2. Agreement by complexity\n")
cat("  3. Rater accuracy comparison\n")
cat("  4. Disagreement heatmap\n")
cat("  5. Rating distribution\n")
cat("  6. Accuracy by domain\n")
cat("  0. Combined summary dashboard\n\n")
cat("All plots saved to: output/figures/\n")