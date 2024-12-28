# Script for plot Boxplots

if (!require('tidyverse')) install.packages('tidyverse')
if (!require('gridExtra')) install.packages('gridExtra')

library(readr)
library(dplyr)
library(ggplot2)
library(gridExtra)

# Manual settings:
name_of_class_column <- 'Class' # Name of label column
data <- read_csv('../creditcard.csv')[,-1] # Without the Time column

# Set A4 dimensions in inches
a4_width <- 8.27
a4_height <- 11.69

pdf("../creditcard_BoxPlots.pdf", width = a4_width, height = a4_height)

plots <- list()
plot_count <- 0
# Loop through all columns except label column
for (col in names(data)) {
  # Skip the label column column
  if (col != name_of_class_column && is.numeric(data[[col]])) { 
    # Boxplot for total statistics
    p_total <- ggplot(data, aes(y = .data[[col]])) +
      geom_boxplot() +
      labs(title = paste("Total Statistics of", col), x = "", y = col) + 
      theme(axis.ticks.x=element_blank(), axis.text.x=element_blank())
    
    # Create the boxplot group by classes
    p_grouped <- ggplot(data, 
                        aes(x = factor(data[[name_of_class_column]]), y = .data[[col]])) +
      geom_boxplot() +
      labs(title = paste("Boxplot of", col, 'by', name_of_class_column), 
           x = name_of_class_column, 
           y = col)
    
    plots <- c(plots, list(p_total))
    
    plots <- c(plots, list(p_grouped))
    plot_count <- plot_count + 1
    
    
    # Print the plot to the PDF
    if (plot_count == 2) {
      # Arrange and print the two plots onto the PDF
      grid.arrange(grobs = plots, ncol = 2, nrow = 2)
      # Reset plot count and clear the list
      plot_count <- 0
      plots <- list()
    }
  }
}

# Print any remaining plot if there's any left
if (plot_count == 1) {
  grid.arrange(plots[[1]], plots[[2]], 
               empty_plot, empty_plot, 
               ncol = 2, nrow = 2)
}

# Close the PDF device
dev.off()
