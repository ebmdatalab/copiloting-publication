# copiloting-publication

This repo contains R scripts carrying out data wrangling and RMarkdown reports of our co-piloting service, in relation to upcoming publications.

Note that no data has been uploaded but a jobserver dump containing the relevant tables should be saved to `dat/`.

To recreate this report:
1. Clone this repo
1. Save the jobserver dump file to `dat/`
1. Amend this line in `01_extract-jobserver-data-from-sqlite.R`:

   `sqlite_file = here::here("dat", "jobserver.sqlite")`

   replacing `jobserver.sqlite` with the name of your file.

1. Start an interactive R console (`R`)
1. Run the pipeline by typing `source("DO.R")`

All being well, this will generate an output file called `02_quantitative-description.html`.

Note that there is NO checking that the content of the jobserver dump is as expected, as yet. If errors occur it may be that the schema has changed.
