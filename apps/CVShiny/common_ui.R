library(googleVis)
library(jsonlite)
# list of default google chart colours for plotting, http://there4.io/2012/05/02/google-chart-color-list/
google_colors = c(
  "#3366CC",
  "#DC3912",
  "#FF9900",
  "#109618",
  "#990099",
  "#0099C6",
  "#DD4477",
  "#66AA00",
  "#B82E2E",
  "#316395",
  "#994499",
  "#22AA99",
  "#AAAA11",
  "#6633CC",
  "#E67300",
  "#8B0707",
  "#329262",
  "#5574A6",
  "#3B3EAC"
)
# default styles for easier plotting
colorCodeToString <- function(colors) {
  colors_string <- colors %>%
  {paste0("'", ., "'")} %>%
    paste(collapse = ", ") %>%
    {paste0("[", ., "]")}
}
gvisBarChart_HCSC <- function(data, xvar, yvar, colors = google_colors) {
  gvisBarChart(data = data,
               xvar = xvar,
               yvar = yvar,
               options = list(
                 legend = "{position: 'none'}",
                 hAxis = "{title: 'Number of Reports'}",
                 colors = colorCodeToString(colors),
                 height = 600,
                 chartArea = "{top: 20, height: '90%', left: 250, width: '60%'}",
                 bar = "{groupWidth: '80%'}"
               )
  )
}
gvisPieChart_HCSC <- function(data, labelvar, numvar, colors = google_colors) {
  gvisPieChart(data = data,
               labelvar = labelvar,
               numvar = numvar,
               options = list(
                 colors = colorCodeToString(colors),
                 chartArea = "{top: 15, height: '80%', width: '90%'}",
                 pieHole = 0.4,
                 fontSize = 11,
                 sliceVisibilityThreshold = 1e-7
               )
  )
}


titleWarning <- function(title) {
  list(title, span(
  "WARNING: This is a beta product. DO NOT use", br(),
  "as sole evidence to support regulatory decisions."))
}

customCSS <- function() {
  tags$head(tags$style(HTML('
.main-header .logo span {
  display: inline-block;
  line-height: normal;
  vertical-align: middle;
  font-size: smaller;
  padding-left: inherit;
}

h2, h3 {
  text-align: center;
}

/*
Text colour is greyed out
http://stackoverflow.com/questions/36314780/shinydashboard-grayed-out-downloadbutton
*/
.skin-blue .sidebar .btn {
  color: #444;
}

/* minor thing to get results table to fill sidebar fully */
.table {
  width: 100% !important;
}
')))
}

aboutAuthors <- function() {list(
  tags$strong("Authors:"),
  fluidRow(
    box(
      "Daniel Buijs, MSc", br(),
      "Data Scientist, Health Products and Food Branch", br(),
      "Data Science Unit / Business Informatics / Resource Management and Operations Directorate / Health Porducts and Food Branch / Health Canada", br(),
      "daniel.buijs@hc-sc.gc.ca",
      width = 4
    ),
    box(
      "Sophia He, BSc (in progress)", br(),
      "Jr. Data Scientist Co-op, Health Products and Food Branch", br(),
      "Data Science Unit / Business Informatics / Resource Management and Operations Directorate / Health Porducts and Food Branch / Health Canada", br(),
      "yunqingh@sfu.ca",
      width = 4
    ),
    box(
      "Kevin Thai, BSc (in progress)", br(),
      "Jr. Data Scientist Co-op, Health Products and Food Branch", br(),
      "Data Science Unit / Business Informatics / Resource Management and Operations Directorate / Health Porducts and Food Branch / Health Canada", br(),
      "kthai@uwaterloo.ca",
      width = 4
    )),
  fluidRow(
    box(
      "Bryce Claughton, BMath (in progress)", br(),
      "Jr. Data Scientist Co-op, Health Products and Food Branch", br(),
      "Data Science Unit / Business Informatics / Resource Management and Operations Directorate / Health Porducts and Food Branch / Health Canada", br(),
      "bclaught@uwaterloo.ca",
      width = 4
    ),
    box(
      "Nanqing Zhu, MSc (in progress)", br(),
      "Jr. Data Scientist, Health Products and Food Branch", br(),
      "Data Science Unit / Business Informatics / Resource Management and Operations Directorate / Health Porducts and Food Branch / Health Canada", br(),
      "nanqing.zhu@mail.mcgill.ca",
      width = 4
    ),
    box(
      "Jason Jiang, BSc (in progress)", br(),
      "Jr. Data Scientist Co-op, Health Products and Food Branch", br(),
      "Data Science Unit / Business Informatics / Resource Management and Operations Directorate / Health Porducts and Food Branch / Health Canada", br(),
      "haiyangj@sfu.ca",
      width = 4
    )
  )
)}
