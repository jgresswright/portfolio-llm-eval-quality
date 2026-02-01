library(tidytext)
library(tidyverse)

# Simple example with your context
comments <- tibble(
  rater_id = 1:5,
  rating_correct = c(TRUE, TRUE, FALSE, FALSE, TRUE),
  comment = c(
    "Good quality response matches guidelines",
    "Response quality is good and accurate",
    "Does not match the guidelines provided",
    "Not accurate compared to examples",
    "Matches guidelines perfectly clear"
  )
)

# Bigram analysis
bigrams <- comments %>%
  unnest_tokens(bigram, comment, token = "ngrams", n = 2) %>%
  count(rating_correct, bigram, sort = TRUE)

# See patterns
bigrams %>%
  group_by(rating_correct) %>%
  slice_max(n, n = 5)