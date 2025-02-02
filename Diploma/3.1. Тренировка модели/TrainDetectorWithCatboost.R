if (!require("catboost")) install.packages("catboost")
if (!require("quanteda")) install.packages("quanteda")
if (!require("wordcloud")) install.packages("wordcloud")
if (!require("stringr")) install.packages("stringr")
if (!require("pROC")) install.packages("pROC")

# Installing caret package
if (!require("ipred")) install.packages("ipred")
if (!require("caret")) install.packages("caret")

# Installing devtools for additional functionality
# for use catboost
if (!require("devtools")) install.packages("devtools")

library(devtools) # For use catboost
library(catboost)

library(quanteda)
library(SnowballC)
library(irr)
library(wordcloud)
library(stringr)
library(dplyr)
library(caret)
library(pROC)


to_tokens <- function(text) {
  tokens <- tokens(
    text,
    remove_punct = TRUE,
    remove_symbols = TRUE,
    remove_numbers = TRUE
  )
  tokens <- tokens_tolower(tokens)
  tokens <- tokens %>% tokens_remove(pattern = stop_words)
  wordStem(tokens, language = "russian")
}


convert_counts <- function(x) {
  x <- ifelse(x >= 1, 1, 0)
}


create_dtmdf <- function(text_vector) {
  token_list <- vector("list", length(text_vector))
  for (i in seq_along(text_vector)) {
    token_list[i] <- list(to_tokens(text_vector[i]))
  }

  text_tokens <- token_list

  # Create document-term matrix for model building
  dtm <- dfm(tokens(text_tokens))

  # Convert the DTM to a data frame
  dtm_df <- convert(dtm, to = "data.frame")
  dtm_df <- apply(dtm_df, MARGIN = 2, convert_counts)
  dtm_df[, -1]
}


adjust_df <- function(column_names, df) {
  query_df <- data.frame(matrix(
    ncol = length(column_names),
    nrow = nrow(df)
  ))
  colnames(query_df) <- column_names
  query_df[] <- rep(0, times = nrow(df))

  for (col in column_names) {
    # Check if the column exists in df and has a value > 0
    if (col %in% colnames(df)) {
      for (i in 1:nrow(df)) {
        # If yes, copy values from df to query_df
        query_df[i, col] <- df[i, col]
      }
    }
  }

  query_df
}


create_word_cloud <- function(v, min_freq) {
  # Create a frequency table
  freq_table <- table(unlist(strsplit(v, "\\s+")))
  # Generate word cloud
  wordcloud(
    words = names(freq_table),
    freq = as.vector(freq_table),
    min.freq = min_freq
  )
}


print_metrics <- function(model, dtm_df, labels) {
  # Calculate metrics
  data_pool <- catboost.load_pool(
    data = dtm_df,
    label = as.integer(labels)
  )
  
  predicts <- catboost.predict(
    model,
    data_pool
  )
  
  predicts <- ifelse(predicts > 0.5, 1, 0)

  print(predicts)
  kappa_score <- kappa2(data.frame(
    Observed = labels,
    Predicted = predicts
  ))
  print(kappa_score)

  confusionMatrix(factor(predicts),
    factor(labels),
    positive = "1"
  )
}


load_data <- function() {
  data_train <- read.csv("shares_detector_train.csv",
    stringsAsFactors = FALSE,
    sep = ",",
    quote = "\""
  )
  data_train$label <- factor(data_train$label)

  data_important_words <- read.csv("importantWords.csv",
    stringsAsFactors = FALSE,
    sep = ",",
    quote = ""
  )
  data_important_words$label <- factor(data_important_words$label)

  data_test <- read.csv("shares_detector_test.csv",
    stringsAsFactors = FALSE,
    sep = ",",
    quote = "\""
  )
  data_test$label <- factor(data_test$label)

  stop_words <- readLines("stopWords.txt")

  data_train <- rbind(data_train, data_important_words)

  return_values <- list(
    "data_train" = data_train,
    "data_importantWords" = data_important_words,
    "data_test" = data_test,
    "stop_words" = stop_words
  )

  return_values
}

# Load data
data <- load_data()
data_train <- data$data_train
data_important_words <- data$data_importantWords
data_test <- data$data_test
stop_words <- data$stop_words

# Create WordCloud
data_train$textcloud <- sapply(data_train$text, function(x) {
  # Remove non-alphanumeric characters
  text_cleaned <- str_replace_all(x, "[^[:alnum:][:space:]]+", " ")
  # Split the text into words
  words_in_text <- strsplit(text_cleaned, "\\s+")[[1]]
  words_in_text <- tolower(words_in_text)
  # Remove stop words
  text_without_stops <- words_in_text[!words_in_text %in% stop_words]
  text_without_numbers <- text_without_stops[!grepl(
    "^[0-9]+$",
    text_without_stops
  )]

  # Join the remaining words
  paste(text_without_numbers, collapse = " ")
})


dtm_df <- create_dtmdf(data_train$text)

# Сохраняем колонки Document-Term-Matrix,
# чтобы воспроизвести матрицу при inference
cat(paste(colnames(dtm_df), collapse = "\n"),
  file = "dtm_df_columns.csv",
  sep = "\n"
)

column_names <- readLines("dtm_df_columns.csv")

dtm_df_test <- create_dtmdf(data_test$text)
dtm_df_test_tuned <- adjust_df(column_names, dtm_df_test)

train_pool <- catboost.load_pool(
  data = dtm_df,
  label = as.integer(data_train$label)
)
test_pool <- catboost.load_pool(
  data = dtm_df_test_tuned,
  label = as.integer(data_test$label)
)

set.seed(1)

params <- list(iterations = 300,
               learning_rate = 0.05,
               depth = 2,
               loss_function = "Logloss",
               random_seed = 1,
               od_type = "Iter",
               od_wait = 20,
               metric_period = 50,
               thread_count = 4,
               use_best_model = TRUE)

model <- catboost.train(
  train_pool,
  test_pool,
  params
)

# Get ROC-AUC
predictions_prob <- catboost.predict(
  model,
  train_pool,
  prediction_type = "Probability"
)
roc_obj <- roc(response = data_train$label, predictor = predictions_prob)

print(paste("Training AUC-ROC: ", auc(roc_obj)))

plot(
  roc_obj,
  main = "ROC Curve",
  lty = 1,
  print.auc = TRUE,
  legacy.axes = TRUE
)
#

save(model, file = "model_R4.3.3_catboost-R-windows-x86_64-1.2.7.RData")

print("Train results")
print_metrics(model, dtm_df, data_train$label)

print("Test results")
print_metrics(model, dtm_df_test_tuned, data_test$label)
