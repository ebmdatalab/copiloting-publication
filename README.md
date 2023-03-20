# copiloting-publication

This repo contains R scripts carrying out data wrangling and RMarkdown reports of our co-piloting service, in relation to upcoming publications.

Note that no data has been uploaded but a jobserver dump containing the relevant tables should be saved to `dat/`.

`how-have-we-grown`
-------------------

This report was compiled to inform a blog post about how our co-piloting programme has grown since it was launched.

To recreate this report:
1. Clone this repo
1. Save the jobserver dump file to `dat/`
1. Create a file `dat/users_and_organisations.txt` containing two columns:
   1. `user_name`: job site user name 
   1. `type`: the organisation to which `user_name` belongs
1. Amend this line in `prepare-data.R`:

   `sqlite_file = here::here("dat", "jobserver.sqlite")`

   replacing `jobserver.sqlite` with the name of your file.

1. In the `how-have-we-grown` direcctory, start an interactive R console (`R`)
1. Run the pipeline by typing `source("build-reports.R")`

All being well, this will generate an output file called `how-we-have-grown.html`.

If errors occur it may be that the schema has changed.
