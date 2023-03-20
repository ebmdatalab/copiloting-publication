library(tidyverse)
library(RSQLite)
library(DBI)
library(lubridate)
library(here)
library(glue)
library(data.table)

load(here::here("dat", "report_variables.Rdat"))
sqlite_file = here::here("dat", "jobserver.sqlite")

con <- dbConnect(drv = RSQLite::SQLite(), dbname = sqlite_file)

## list all tables
## tables <- dbListTables(con)

#####################################################################
### FINDING ALL THE PROJECTS AND WORKSPACES                       ###
#####################################################################

workspace_table.query <- "
SELECT p.id AS project_id,
    p.name AS project_name,
    p.org_id as organisation_id,
    p.created_at as project_creation_date,
    p.status as project_status,
    w.name AS workspace_name,
    w.id AS workspace_id,
    w.created_at AS workspace_start_date,
    w.repo_id AS repo
FROM jobserver_project p,
    jobserver_workspace w
WHERE w.project_id = p.id
"

workspace_table.results = dbSendQuery(con, workspace_table.query)
workspace_table <- dbFetch(workspace_table.results) %>%
    mutate(workspace_start_date = ymd(substr(workspace_start_date, 1, 10))) %>%
    mutate(project_creation_date = ymd(substr(project_creation_date, 1, 10)))
dbClearResult(workspace_table.results)

#####################################################################
### FINDING ALL THE COPILOTS AND THEIR PROJECTS                   ###
#####################################################################

copilot_table.query = "
SELECT u.username AS copilot_name,
    p.copilot_id AS copilot_id,
    p.id AS project_id
FROM jobserver_project p,
    jobserver_user u
WHERE p.copilot_id = u.id
"

copilot_table.results = dbSendQuery(con, copilot_table.query)
copilot_table = dbFetch(copilot_table.results) 
dbClearResult(copilot_table.results)

#####################################################################
### FINDING ALL THE ORGANISATIONS                                 ###
#####################################################################

org_table.query <- "
SELECT o.id AS organisation_id,
    o.name AS organisation_name
FROM jobserver_org o
"

org_table.results = dbSendQuery(con, org_table.query)
org_table <- dbFetch(org_table.results)
dbClearResult(org_table.results)

#####################################################################
### FINDING ALL JOBS                                              ###
#####################################################################

jobs_table.query <- "
SELECT jr.id AS job_id,
    jr.created_at,
    j.id,
    j.status as job_status,
    j.job_request_id,
    j.started_at as job_start_time,
    j.completed_at as job_stop_time,
    jr.workspace_id,
    jr.created_by_id
FROM jobserver_job j,
    jobserver_jobrequest jr
WHERE j.job_request_id = jr.id
"

jobs_table.results = dbSendQuery(con, jobs_table.query)
jobs_table <- dbFetch(jobs_table.results) %>%
    ### Variable reformatting
    mutate(job_created_time = lubridate::as_datetime(created_at)) %>%
    mutate(job_start_time = lubridate::as_datetime(job_start_time)) %>%
    mutate(job_stop_time = lubridate::as_datetime(job_stop_time)) %>%
    mutate(job_duration = difftime(job_stop_time, job_start_time, units = "secs")) %>%
    ### Some tidying
    select(-created_at) %>%
    mutate(job_status = ifelse(job_status == "0", "Did not start", stringr::str_to_sentence(job_status)))
dbClearResult(jobs_table.results)

#####################################################################
### FINDING ALL RELEASES                                          ###
#####################################################################

releases_table.query = "
SELECT r.id,
    r.created_at,
    w.name as workspace_name,
    w.project_id,
    COUNT(rf.id) AS files
FROM jobserver_workspace w
JOIN jobserver_release r ON w.id = r.workspace_id
JOIN jobserver_releasefile rf ON r.id = rf.release_id
GROUP BY r.id, r.created_at, w.name
ORDER BY r.created_at
"

releases_table.results = dbSendQuery(con, releases_table.query)
releases_table = dbFetch(releases_table.results) %>%
    mutate(release_created_at = lubridate::as_date(created_at)) %>%
    rename(num_files_in_release = files) %>%
    select(-id, -created_at)
dbClearResult(releases_table.results)


#####################################################################
### APPLICATION DATA                                              ###
#####################################################################

application_table.query = "
SELECT project_id,
    submitted_at as application_submitted_at,
    approved_at as application_approved_at,
    completed_at as application_completed_at,
    created_at as application_created_at,
    status as application_status
FROM applications_application
"

application_table.results = dbSendQuery(con, application_table.query)
application_table = dbFetch(application_table.results) %>%
    filter(!is.na( project_id )) %>%
    filter( application_status == "approved_fully" ) %>%
    select(project_id, application_submitted_at, application_approved_at, application_completed_at, application_created_at) %>%
    mutate(application_approved_at = ymd(substr(application_approved_at, 1, 10))) %>%
    mutate(application_submitted_at = ymd(substr(application_submitted_at, 1, 10))) %>%
    mutate(application_completed_at = ymd(substr(application_completed_at, 1, 10))) %>%
    mutate(application_created_at = ymd(substr(application_created_at, 1, 10))) %>%
    mutate( days_to_approve_application = application_approved_at - application_submitted_at)
dbClearResult(application_table.results)

#####################################################################
### USER DATA                                                     ###
#####################################################################

external_users_on_projects.query <- "
SELECT DISTINCT pm.id as project_id, pm.user_id as user_id, u.username as user_name
FROM jobserver_projectmembership pm,
jobserver_user u
WHERE u.id = pm.user_id AND
u.is_staff != 1
"

external_users_on_projects.results = dbSendQuery(con, external_users_on_projects.query)
external_users_on_projects_table = dbFetch(external_users_on_projects.results)
dbClearResult(external_users_on_projects.results)

### Disconnect the connection

dbDisconnect(con)

#####################################################################
### CREATING A MERGED JOBS DATASET                                ###
#####################################################################

base_table = workspace_table %>%
    ### Add copilots
    left_join(copilot_table, by = "project_id") %>%
    select(-copilot_id) %>%
    ### Add real organisation names
    left_join(org_table, by = "organisation_id") %>%
    select(-organisation_id) %>%
    ### Work out project start date
    group_by(project_id, project_name) %>%
    mutate( first_workspace_start_date = min( workspace_start_date) ) %>%
    ### Some tidying
    replace_na(list(copilot_name = "None provided"))

saveRDS(base_table, here::here("dat", "base_table.Rds"))


annotated_jobs = base_table %>%
    ### Add all jobs
    left_join(jobs_table, by = "workspace_id") %>%
    select(-workspace_id)

saveRDS(annotated_jobs, here::here("dat", "annotated_jobs.Rds"))


#####################################################################
### CREATING A MERGED RELEASE DATASET                             ###
#####################################################################

annotated_releases = base_table %>%
    ### Add all jobs
    left_join(releases_table, by = c("project_id", "workspace_name")) %>%
    select(-project_id) %>%
    ### Variable reformatting
    mutate( workspace_to_release_time = difftime(release_created_at, workspace_start_date) )

saveRDS(annotated_releases, here::here("dat", "annotated_releases.Rds"))

#####################################################################
### SAVING THE COPILOT TABLE                                      ###
#####################################################################

saveRDS(copilot_table, here::here("dat", "copilot_table.Rds"))

#####################################################################
### SAVING THE USERS TABLE                                        ###
#####################################################################

saveRDS(external_users_on_projects_table, here::here("dat", "external_users_on_projects_table.Rds"))

#####################################################################
### SAVING SOME VARIABLES                                         ###
#####################################################################

sqlite_file_last_modified = fs::file_info(sqlite_file)$modification_time %>%
    substr(1, 10) %>%
    ymd()

workspace_creation_range = base_table %>%
    pull(workspace_start_date) %>%
    range(na.rm = TRUE)

job_start_range = jobs_table %>%
    pull(job_start_time) %>%
    range(na.rm = TRUE)

job_stop_range = jobs_table %>%
    pull(job_stop_time) %>%
    range(na.rm = TRUE)

release_range = releases_table %>%
    pull(release_created_at) %>%
    range(na.rm = TRUE)

application_submitted_range = application_table %>%
    pull( application_submitted_at ) %>% 
    range( na.rm = TRUE )

application_approved_range = application_table %>%
    pull( application_approved_at ) %>%
    range( na.rm = TRUE )

save(
    sqlite_file_last_modified,
    workspace_creation_range,
    job_start_range,
    job_stop_range,
    release_range,
    file = here::here("dat", "sqlite_variables.Rdat")
)
