library(rmarkdown)

source("00_static-variables.R")
source("01_extract-jobserver-data-from-sqlite.R")

rmarkdown::render( "02_quantitative-description.Rmd", clean = TRUE )
