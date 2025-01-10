options(repos = c(CRAN="https://cran.rstudio.com/"))

if (!require("plumber")) install.packages("plumber")

library(plumber)

r <- plumb("predict.R")
r$run(port=5762, host="0.0.0.0")
