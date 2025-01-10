# Load necessary packages
packages <- c("plumber", "randomForest", "quanteda", "irr", "stringr", "dplyr", "caret", "SnowballC")
for (package in packages) {
  if (!require(package)) install.packages(package)
  library(package, character.only = TRUE)
}

#print(sessionInfo())

#* @apiTitle DetectorForFilterShares
#* @apiDescription API for inference DetectorForFilterShares

example_texts <- list("TICKET sector description"
)


#* version
#* @serializer unboxedJSON
#* @get /api/version
function() {
  version_info <- list(
    actualData = "2025-01-06",
    dateModel =  "2025-01-05",
    version =    "1.0.1"
  )
  return(version_info)
}


#* inference
#* @post /api/inference
function(req, texts = example_texts) {
  if (!is.null(req$body$texts)) {
    df <- as.data.frame(req$body$texts)
    colnames(df) <- "text"
    serviceInference(df)
  }
  else {
    stop("Request body must contain 'texts' field.")
  }
}


serviceInference <- function(df) {
  fGag <- FALSE
  results <- c()
  
  # Приложение требует, чтобы в списке было больше одного элемента.
  # Если на вход подан 1 элемент, то добавляем элемент-заглушку.
  if (nrow(df) < 2) {
    df[nrow(df) + 1,] <- c("ЗАГЛУШКА materials")
    fGag <- TRUE
  }
  
  df$predicts <- execPredict(df)
  
  for (i in seq_along(df$predicts)) {
    if (df$predicts[i] == "1") {
      results <- c(results, df$text[i])
    }
  }
  
  if (fGag)
    head(results, -1)
  else
    results
}


toTokens <- function(text, stop_words) {
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


createDTMDF <- function(textVector, stop_words) {
  tokenList <- vector("list", length(textVector))
  for (i in seq_along(textVector)) {
    tokenList[i] <- list(toTokens(textVector[i], stop_words))
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

# For debug purposes
loadData <- function() {
  data = read.csv("shares_predict_detector_work.csv",
                        stringsAsFactors = FALSE,
                        sep = "\t",
                        quote= "")
  data
}

runPredict <- function(model, dtm_df) {
  print("Predict:")
  predicts <- predict(model, newdata = dtm_df)
  print(predicts)
  print("Ok")
  predicts
}  

prepareDf <- function(data_texts, columnNames, stop_words) {
  dtm_df <- createDTMDF(data_texts$text, stop_words)
  query_df = adjustDF(columnNames, dtm_df)
  query_df
}


execPredict <- function(data_texts) {
  
  set.seed(1)
  load("20250105model_R4.3.3_randomForest4.7-1.1.RData")
  columnNames <- readLines("dtm_df_columns.csv")
  stop_words <- readLines("stopWords.txt")
  #data_texts <- loadData() # For Debug purposes
  
  query_df <- prepareDf(data_texts, columnNames, stop_words)
  
  runPredict(model, query_df)
}
