#if (!require("e1071")) install.packages("e1071")
install.packages("quanteda")
install.packages("wordcloud")
install.packages("stringr")
install.packages("pROC")

install.packages("ipred") # For install caret
install.packages("caret")

#install.packages("tm") It is don't work in the Windows 10.
#library(e1071) # For naiveBayes
library(randomForest)
library(quanteda)
library(SnowballC)
library(irr)
library(wordcloud)
library(stringr)
library(dplyr)
library(caret)
library(pROC)


toTokens <- function(text) {
  tokens <- tokens(text, 
                   remove_punct = TRUE, 
                   remove_symbols = TRUE,
                   remove_numbers = TRUE)
  tokens <- tokens_tolower(tokens)
  tokens <- tokens %>% tokens_remove(pattern = stop_words)
  wordStem(tokens, language = "russian")
}


convert_counts <- function(x){
  # It is for Naive Bayes
  #x <- ifelse(x >= 1, "Yes", "No")
  # It is for Random Forest
  x <- ifelse(x >= 1, 1, 0)
}


createDTMDF <- function(textVector) {
  tokenList <- vector("list", length(textVector))
  for (i in seq_along(textVector)) {
    tokenList[i] <- list(toTokens(textVector[i]))
  }
  
  textTokens <- tokenList
  
  # Create document-term matrix for model building
  dtm <- dfm(tokens(textTokens))
  
  # Convert the DTM to a data frame
  dtm_df <- convert(dtm, to = "data.frame")
  dtm_df <- apply(dtm_df, MARGIN = 2, convert_counts)
  dtm_df[, -1]
}


adjustDF <- function(columnNames, df) {
  query_df <- data.frame(matrix(ncol = length(columnNames), 
                                nrow = nrow(df)))
  colnames(query_df) <- columnNames
  query_df[] <- rep(0, times = nrow(df))
  
  for (col in columnNames) {
    # Check if the column exists in df and has a value > 0
    if (col %in% colnames(df)) {
      for (i in 1: nrow(df)) {
        # If yes, copy values from df to query_df
        query_df[i ,col] <- df[i ,col]
      }
    }
  }
  
  query_df
}


createWordCloud <- function(v, minFreq) {
  # Create a frequency table
  freq_table <- table(unlist(strsplit(v, "\\s+")))
  # Generate word cloud
  wordcloud(words = names(freq_table), freq = as.vector(freq_table), min.freq = minFreq)
}


printMetrics <- function(model, dtm_df, labels) {
  # Calculate metrics
  predicts <- predict(model, newdata = dtm_df)
  print(predicts)
  kappa_score <- kappa2(data.frame(Observed = labels, 
                                   Predicted = predicts))
  print(kappa_score)
  
  confusionMatrix(factor(predicts), 
                  factor(labels),
                  positive = "1")
}


loadData <- function() {
  data_train = read.csv("shares_detector_train.csv",
                        stringsAsFactors = FALSE,
                        sep = ",",
                        quote= "\"")
  data_train$label = factor(data_train$label)
  
  data_importantWords = read.csv("importantWords.csv",
                                 stringsAsFactors = FALSE,
                                 sep = ",",
                                 quote= "")
  data_importantWords$label = factor(data_importantWords$label)
  
  data_test = read.csv("shares_detector_test.csv",
                        stringsAsFactors = FALSE,
                        sep = ",",
                        quote= "\"")
  data_test$label = factor(data_test$label)
  
  stop_words <- readLines("stopWords.txt")
  
  data_train <- rbind(data_train, data_importantWords)
  
  returnValues <- list("data_train" = data_train,
                       "data_importantWords" = data_importantWords,
                       "data_test" = data_test,
                       "stop_words" = stop_words)
}

# Load data
data <- loadData()
data_train = data$data_train
data_importantWords = data$data_importantWords
data_test = data$data_test
stop_words = data$stop_words

# Create WordCloud
data_train$textcloud <- sapply(data_train$text, function(x) {
  # Remove non-alphanumeric characters
  text_cleaned <- str_replace_all(x, "[^[:alnum:][:space:]]+", " ")
  # Split the text into words
  words_in_text <- strsplit(text_cleaned, "\\s+")[[1]]
  words_in_text <- tolower(words_in_text)
  # Remove stop words
  text_without_stops <- words_in_text[!words_in_text %in% stop_words]
  text_without_numbers <- text_without_stops[!grepl("^[0-9]+$", text_without_stops)]
  
  # Join the remaining words
  paste(text_without_numbers, collapse = " ")
})

# Исходный код (закомментирован) для отображения Word Cloud 
# для разных классов/общее.
#subsetYes = subset(data_train, label == "1")
#subsetNo = subset(data_train, label == "0")
#createWordCloud(data_train$textcloud, 5)
#createWordCloud(subsetYes$textcloud, 2)
#createWordCloud(subsetNo$textcloud)

dtm_df <- createDTMDF(data_train$text)

# Сохраняем колонки Document-Term-Matrix, 
# чтобы воспроизвести матрицу при inference
cat(paste(colnames(dtm_df), collapse = "\n"), 
    file = "dtm_df_columns.csv", 
    sep = "\n")

columnNames <- readLines("dtm_df_columns.csv")

# Build the naive bayes classifier
# Была попытка использовать Naive Bayes модель: неудачно, результат низкий.
#model <- naiveBayes(dtm_df, data_train$label)

set.seed(1) # ← Необходимо вызывать всегда перед randomForest (а не после)
model <- randomForest(dtm_df, data_train$label, 
                      ntree = 200, mtry = sqrt(ncol(dtm_df)))

# Get ROC-AUC
predictsProbs <- predict(model, newdata = dtm_df, type="prob")
yesColumn <- predictsProbs[,"1"]
data_train_roc <- roc(data_train$label, yesColumn)
plot(data_train_roc, 
     lwd = 2, 
     print.auc = TRUE, 
     legacy.axes = TRUE)
#

save(model, file = "model_R4.3.3_randomForest4.7-1.1.RData")

print("Train results")
printMetrics(model, dtm_df, data_train$label)

dtm_df_test <- createDTMDF(data_test$text)
query_df = adjustDF(columnNames, dtm_df_test)
print("Test results")
printMetrics(model, query_df, data_test$label)

