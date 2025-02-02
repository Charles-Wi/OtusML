# Load necessary packages
packages <- c(
  "plumber",
  "devtools",
  "catboost",
  "quanteda",
  "irr",
  "stringr",
  "dplyr",
  "caret",
  "SnowballC"
)

for (package in packages) {
  if (!require(package)) install.packages(package)
  library(package, character.only = TRUE)
}


#* @apiTitle DetectorForFilterShares
#* @apiDescription API for inference DetectorForFilterShares

example_texts <- list("TICKET sector description")


#* version
#* @serializer unboxedJSON
#* @get /api/version
function() {
  version_info <- list(
    actualData = "2025-02-02",
    dateModel = "2025-02-02",
    version = "1.0.3"
  )
  return(version_info)
}


#* inference
#* @post /api/inference
function(req, texts = example_texts) {
  if (!is.null(req$body$texts)) {
    df <- as.data.frame(req$body$texts)
    colnames(df) <- "text"
    service_inference(df)
  } else {
    stop("Request body must contain 'texts' field.")
  }
}


service_inference <- function(df) {
  f_gag <- FALSE
  results <- c()

  # Приложение требует, чтобы в списке было больше одного элемента.
  # Если на вход подан 1 элемент, то добавляем элемент-заглушку.
  if (nrow(df) < 2) {
    df[nrow(df) + 1, ] <- c("ЗАГЛУШКА materials")
    f_gag <- TRUE
  }

  df$predicts <- exec_predict(df)

  for (i in seq_along(df$predicts)) {
    if (df$predicts[i] == "1") {
      results <- c(results, df$text[i])
    }
  }

  if (f_gag) {
    head(results, -1)
  } else {
    results
  }
}


to_tokens <- function(text, stop_words) {
  tokens <- tokens(text,
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


create_dtmdf <- function(text_vector, stop_words) {
  token_list <- vector("list", length(text_vector))
  for (i in seq_along(text_vector)) {
    token_list[i] <- list(to_tokens(text_vector[i], stop_words))
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

# For debug purposes
load_data <- function() {
  data <- read.csv("shares_predict_detector_work.csv",
    stringsAsFactors = FALSE,
    sep = "\t",
    quote = ""
  )
  data
}

run_predict <- function(model, dtm_df) {
  print("Predict:")
  
  data_pool <- catboost.load_pool(
    data = dtm_df
  )
  
  predicts <- catboost.predict(
    model,
    data_pool
  )
  
  predicts <- ifelse(predicts > 0.5, 1, 0)
  
  print(predicts)
  print("Ok")
  predicts
}

prepare_df <- function(data_texts, column_names, stop_words) {
  dtm_df <- create_dtmdf(data_texts$text, stop_words)
  query_df <- adjust_df(column_names, dtm_df)
  query_df
}


exec_predict <- function(data_texts) {
  set.seed(1)
  model <- catboost.load_model(
    "20250202model_R4.3.3_catboost-R-windows-x86_64-1.2.7.RData"
  )
  column_names <- readLines("dtm_df_columns.csv")
  stop_words <- readLines("stopWords.txt")

  query_df <- prepare_df(data_texts, column_names, stop_words)

  run_predict(model, query_df)
}
