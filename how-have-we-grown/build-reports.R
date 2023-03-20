library(rmarkdown)

source("report-variables.R")
source("prepare-data.R")

rmarkdown::render( "how-have-we-grown.Rmd", clean = TRUE )
