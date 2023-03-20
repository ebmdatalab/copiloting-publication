rm(list = ls())
library(here)
library(tibble)
library(readr)

internal_organisations = c(
    "DataLab",
    "The London School of Hygiene & Tropical Medicine"
)

users_and_organisations = read_csv(here("dat", "users_and_organisation.txt"))

convert_cut = function( all_s, cuts ) {
    s_count = 0
    
    for ( s in all_s ) {
        s_count = s_count + 1
        first_value = s %>% str_split( "," ) %>% unlist %>% first %>% str_replace("[:punct:]","")
        break_i = which( cut_breaks == first_value )
        s_new = ""

        if (break_i == 1) {
            s_new = glue("≤{ cuts[break_i+1]} WD", )
        } else if (break_i == (length(cuts) - 1)) {
            s_new = glue("> {cuts[break_i]} WD")
        } else {
            s_new = glue("{cuts[break_i]+1} - {cuts[break_i+1]} WD")
        }
        
        all_s[ s_count ] = s_new
    }

    return( all_s )
}

convert_days_to_time_bin = function(days,cuts) {
    days_cut = cut(days,cuts)
    converted_levels = convert_cut( levels(days_cut), cuts)
    converted_data = convert_cut( as.character(days_cut), cuts )
    days_binned = factor( converted_data, levels = converted_levels, ordered=TRUE )
    return( days_binned ) 
}

save.image(here::here("dat", "report_variables.Rdat"))