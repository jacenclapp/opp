source("common.R")

# VALIDATION: [YELLOW] We only have partial data in 2012; the PD doesn't seem
# to issue annual reports to validate these figures, but the data seems
# reasonable for the size of the city
load_raw <- function(raw_data_dir, n_max) {
  # TODO(phoebe): how do we join these sets of files? 
  # stop_files contain date, time, location, officer demographics
  # https://app.asana.com/0/456927885748233/523125532932048 
  stop_files <- c(
    "jenna_fowler_013117_-_stocktonpd_cad_tstops_2012_2013.csv",
    "jenna_fowler_013117_-_stocktonpd_cad_tstops__2014_july_2016.csv",
    "jenna_fowler_013117_-_stocktonpd_tstops_aug_dec2016.csv"
  )
  # survey_files contain date, outcome, subject demographics
  d <- load_regex(
    raw_data_dir,
    str_c(
      "jenna_fowler_013117_-_stocktonpd_trafficstopsurvey_2012_july_2016.csv",
      "jenna_fowler_013117_-_stocktonpd_trafficstopsurvey_aug_dec2016.csv",
      sep = "|"
    ),
    n_max
  )
  bundle_raw(d$data, d$loading_problems)
}


clean <- function(d, helpers) {

  tr_race <- c(
    "Asian" = "asian/pacific islander",
    "Black/African American" = "black",
    "Hispanic" = "hispanic",
    "Others" = "other/unknown",
    "White/Caucasian" = "white"
  )

  tr_outcome <- c(
    "1-In-Custody Arrest" = "arrest",
    "2-Citation Issued" = "citation",
    "3-Verbal Warning" = "warning"
    # 4-Public Service
  )

  tr_search_basis <- c(
    # 1-No Search Conducted
    "2-Consent" = "consent",
    "3-Probable Cause (Terry)" = "probable cause",
    "4-Tow Inventory Search" = "other",
    "5-Incidental to Lawful Arrest" = "other",
    "6-Pursuant to Lawful Search Warrant" = "other",
    "7-Probation/Parole Search" = "other"
  )

  names(d$data) <- tolower(names(d$data))
  d$data %>%
    # TODO(danj): location is in the stop files, but let's wait to
    # geocode until we are sure we are going to use those files
    # (currently we can't join them to the survey_files)
    # helpers$add_lat_lng(
    #   "address"
    # ) %>%
    rename(
      date = in_date,   
      subject_age = age,
      reason_for_stop = probcause
    ) %>%
    mutate(
      # NOTE: all stops are traffic stops as per reply letter
      type = "vehicular",
      outcome = tr_outcome[result],
      search_conducted = !startsWith(search, "1-No Search"),
      search_basis = tr_search_basis[search],
      subject_sex = tr_sex[gender],
      subject_race = tr_race[race],
      arrest_made = result == "1-In-Custody Arrest",
      citation_issued = result == "2-Citation Issued",
      warning_issued = result == "3-Verbal Warning",
      # NOTE: officer_id is ~90% null; officer2_id is ~50% null;
      # coalescing, there are 2,151 instances where both officers are listed
      # and we only take the first
      officer_id = coalesce(officer_id, officer2_id)
    ) %>%
    # TODO(danj): add shapefile data after we figure out how to join the files
    # https://app.asana.com/0/456927885748233/722199186603264  
    standardize(d$metadata)
}
