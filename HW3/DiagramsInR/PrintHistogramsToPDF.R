# Script for plot Histograms

if (!require('tidyverse')) install.packages('tidyverse')
if (!require('gridExtra')) install.packages('gridExtra')

library(readr)
library(dplyr)
library(ggplot2)
library(gridExtra)


# Manual settings:
n_bins = 14
data <- read_csv('../creditcard.csv')[,-1] # Without the Time column

# Set A4 dimensions in inches (in album orientation):
a4_width <- 11.69
a4_height <- 8.27

pdf("../creditcard_Histograms.pdf", width = a4_width, height = a4_height)

plots <- list()
plot_count <- 0
# Loop through all columns except label column
for (col in names(data)) {
  if (is.numeric(data[[col]])) { 
    min_value = min(data[[col]])
    max_value = max(data[[col]])
    p_total <- ggplot(data, aes(x = .data[[col]])) +
      geom_histogram(binwidth = (max_value - min_value) / n_bins, fill='#34b334') +
      labs(title = col, x = col, y = "")
    
    plots <- c(plots, list(p_total))
    plot_count <- plot_count + 1
    
    if (plot_count == 4) {
      grid.arrange(grobs = plots, ncol = 2, nrow = 2)
      plot_count <- 0
      plots <- list()
    }
    
  }
}

# Print any remaining plot if there's any left
if (plot_count > 0) {
  grid.arrange(grobs = plots, ncol = 2, nrow = 2)
}

dev.off()   # Close the PDF device