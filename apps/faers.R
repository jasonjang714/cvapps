# data manip + utils
library(magrittr)
library(lubridate)
library(dplyr)
library(utils)
library(zoo)
library(pool)

# data visualizations
library(plotly)
library(ggplot2)
library(googleVis)

# Shiny libraries
library(shiny)
library(shinydashboard)
library(shinyBS)
library(DT)

library(openfda)
source("common_ui.R")

####### for an overview of this code, try clicking the arrow at the side of the editor
#< so you understand what are all the high-level functions and outputs in the server fxn
# https://github.com/FDA/openfda/issues/29

# not possible to do searching for only suspect or concomitant drugs in openFDA
# http://opendata.stackexchange.com/questions/6157

topdrugs <- fda_query("/drug/event.json") %>%
  fda_count("patient.drug.openfda.generic_name.exact") %>% 
  fda_limit(1000) %>% 
  fda_exec() %>%
  .$term %>%
  sort() %>%
  grep("[%,]", ., value = TRUE, invert = TRUE) # https://github.com/FDA/openfda/issues/29
topdrugs <- c("Start typing to search..." = "", topdrugs)
topbrands <- fda_query("/drug/event.json") %>%
  fda_count("patient.drug.openfda.brand_name.exact") %>% 
  fda_limit(1000) %>% 
  fda_exec() %>%
  .$term %>%
  sort() %>%
  grep("[%,]", ., value = TRUE, invert = TRUE) # https://github.com/FDA/openfda/issues/29
topbrands <- c("Start typing to search..." = "", topbrands)
hcopen <- src_postgres(host = "shiny.hc.local", user = "hcreader", dbname = "hcopen", password = "canada1")
meddra <- tbl(hcopen, "meddra") %>%
  filter(Primary_SOC_flag == "Y") %>%
  select(PT_Term, HLT_Term, Version = MEDDRA_VERSION) %>%
  mutate(term = toupper(PT_Term)) %>%
  as.data.frame()

age_code <- data.frame(term = 800:805,
                       label = c("Decade",
                                 "Year",
                                 "Month",
                                 "Week",
                                 "Day",
                                 "Hour"),
                       stringsAsFactors = FALSE)

ui <- dashboardPage(
  dashboardHeader(title = titleWarning("Shiny FAERS (v0.18)"),
                  titleWidth = 700),
  
  dashboardSidebar(
    width = 280,
    sidebarMenu(
      menuItem("Reports", tabName = "reportdata", icon = icon("hospital-o")),
      menuItem("Patients", tabName = "patientdata", icon = icon("user-md")),
      menuItem("Drugs", tabName = "drugdata", icon = icon("flask")),
      menuItem("Reactions", tabName = "rxndata", icon = icon("heart-o")),
      menuItem("About", tabName = "aboutinfo", icon = icon("info"), selected = TRUE)
    ),
    conditionalPanel(
      condition = "input.name_type == 'generic'",
      selectizeInput("search_generic", 
                     "Generic Name", 
                     topdrugs,
                     multiple = TRUE)),
    conditionalPanel(
      condition = "input.name_type == 'brand'",
      selectizeInput("search_brand", 
                     "Brand Name (US Trade Name)",
                     topbrands,
                     multiple = TRUE)),
    radioButtons("name_type", "Drug name type:",
                 c("Generic" = "generic",
                   "Brand Name" = "brand")),
    selectizeInput("search_rxn",
                   "Preferred Term (PT)",
                   c("Loading..." = ""),
                   options = list(create = TRUE),
                   multiple = TRUE),
    dateRangeInput("searchDateRange", 
                   "Date Range", 
                   start = "2003-01-01",
                   end = "2016-06-30",
                   startview = "decade"),
    # hacky way to get borders correct
    tags$div(class="form-group shiny-input-container",
             actionButton("searchButton",
                          "Search",
                          width = '100%')
    ),
    tags$br(),
    tags$h3(strong("Current Query:")),
    tableOutput("current_search")
    # downloadButton(outputId = "hlt_data_dl",
    #                label = "Export data")
  ),
  
  dashboardBody(
    customCSS(),
    fluidRow(
      box(htmlOutput(outputId = "timeplot_title"),
          htmlOutput(outputId = "timeplot"),
          htmlOutput(outputId = "search_url"),
          width = 12
          )
      ),
    tabItems(
      tabItem(tabName = "reportdata",
              fluidRow(
                box(h3("Reporter Type",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = "Category of individual who submitted the report.")),
                    htmlOutput("reporterplot"),
                    width = 3),
                box(h3("Seriousness",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste0("Seriousness of the adverse event. An adverse event is marked serious if it ",
                                        "resulted in death, a life threatening condition, hospitalization, disability, ",
                                        "congenital anomaly, or other serious condition."))),
                    htmlOutput("seriousplot"),
                    width = 3),
                box(h3("Reason(s) for Seriousness",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste0("The serious condition which the adverse event resulted in. Total may sum to",
                                        " more than the total number of reports because reports can be marked serious for multiple reasons"))),
                    htmlOutput("seriousreasonsplot"),
                    width = 5)
              ),
              fluidRow(
                box(h3("Country of Occurrence",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = "The name of the country where the event occurred. This is not necessarily the same country the report was received from.")),
                    htmlOutput("countryplot"),
                    width = 6)
              )
      ),
      tabItem(tabName = "patientdata",
              fluidRow(
                box(h3("Sex",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = "The sex of the patient.")),
                    htmlOutput("sexplot"),
                    width = 3),
                box(h3("Age Group",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = HTML(paste0(
                           "Age group of the patient when the adverse effect occurred. ",
                           "Using the definitions from the Canada Vigilance Adverse Reaction Online Database.<br>",
                           "<br>Neonate: <= 25 days",
                           "<br>Infant: > 25 days to < 1 yr",
                           "<br>Child: >= 1 yr to < 13 yrs",
                           "<br>Adolescent: >= 13 yrs to < 18 yrs",
                           "<br>Adult: >= 18 yrs to <= 65 yrs",
                           "<br>Elderly: > 65 yrs")))),
                    htmlOutput("agegroupplot"),
                    width = 3),
                box(htmlOutput("agehisttitle"),
                    plotlyOutput("agehist"),
                    width = 6)
              )
      ),
      tabItem(tabName = "drugdata",
              fluidRow(
                box(h3("Reports per Indication (all reported drugs)",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste(
                           "This plot includes all indications for all drugs present in the matching reports.",
                           "It is not currently possible to search for only those indications associated with a specific drug",
                           "since the openFDA search API does not allow filtering of drug data.",
                           "The search query filters unique reports, which may have one or more drugs associated with them."))),
                    htmlOutput("indication_plot"),
                    width = 6),
                box(h3("Most Frequently Reported Drugs (Generic Name)",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste(
                           "This plot includes all drugs present in the matching reports.",
                           "The openFDA search API does not allow filtering of drug data.",
                           "The search query filters unique reports, which may have one or more drugs associated with them."))),
                    htmlOutput("all_drugs"),
                    width = 6)
              ),
              fluidRow(
                box(h3("Most Frequent Established Pharmaceutical Classes",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste(
                           "This plot includes established pharmacologic classes for all drugs present in the matching reports",
                           "The total number of instances for each class will be greater ",
                           "than the number of reports when reports include more than one drug of the same class.",
                           "The openFDA search API does not allow filtering of drug data."))),
                    htmlOutput("drugclassplot"),
                    width = 6)
              )
      ),
      tabItem(tabName = "rxndata",
              fluidRow(
                box(h3("Most Frequent Adverse Events (Preferred Terms)",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste0(
                           "Patient reactions, as MedDRA preferred terms, for all reactions present in ",
                           "the reports. For more rigorous analysis, use disproportionality statistics."))),
                    htmlOutput("top_pt"),
                    width = 6),
                box(h3("Most Frequent Adverse Events (High-Level Terms)",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = paste0(
                           "Patient reactions, as MedDRA high-level terms. Based on the counts ",
                           "for the top 1000 MedDRA preferred terms present in reports. ",
                           "For more rigorous analysis, use disproportionality statistics."))),
                    htmlOutput("top_hlt"),
                    width = 6)
              ),
              fluidRow(
                box(h3("Report Outcome",
                       tipify(
                         el = icon("info-circle"), trigger = "hover click",
                         title = "Outcome of the reaction at the time of last observation.")),
                    htmlOutput("outcomeplot"),
                    width = 4)
              )
      ),
      tabItem(tabName = "aboutinfo", box(
        width = 12,
        h2("About"),
        # using tags$p() and tags$a() inserts spaces between text and hyperlink...thanks R
        HTML(paste0(
          "<p>",
          "This is a beta product developed using Open FDA data. DO NOT use as sole evidence to support ",
          "regulatory decisions or making decisions regarding medical care.  We do not hold any responsibility ",
          "for the authenticity or legitimacy of data.",
          "</p>",
          "<p>",
          "This app has been developed by the Data Sciences Unit of RMOD at Health Canada. ",
          "This app is a prototype experiment that utilizes publically available data (openFDA) ",
          "and presents it in an interactive way for enhanced visualizations. This app allows users to ",
          "effortlessly interact with the reports database, conduct searches and view results in highly ",
          "interactive dashboards.",
          "</p>",
          "<br>",
          "<p>",
          "<strong>Data last updated: 2016-11-04</strong> (latest report in this update is 2016-06-30)<br>",
          "Data provided by the U.S. Food and Drug Administration (FDA), retrieved through the openFDA API (",
          "<a href = \"https://open.fda.gov\">",
          "https://open.fda.gov",
          "</a>",
          "). The recency of the data is therefore dependent on when the API data source is updated, ",
          "and Health Canada claims no responsibility for out-of-date information. This app uses US Trade Name ",
          "and Generic Name definitions, and therefore may not be relevant in a Canadian Context. The descriptions used in this ",
          "app are those defined in the openFDA reference, and are subject to change. For more information, please refer to ",
          "<a href = \"https://open.fda.gov/drug/event/reference/\">",
          "https://open.fda.gov/drug/event/reference/",
          "</a>. Due to ongoing issues with the openFDA API (",
          "<a href = \"https://github.com/FDA/openfda/issues/29\">https://github.com/FDA/openfda/issues/29</a>",
          "), some search terms with symbols may not be available for querying.",
          "</p>")),
        aboutAuthors()
      ))
    )
  )
)


server <- function(input, output, session) {
  # Relabel PT dropdown menu based on selected name
  observe({
    input$search_generic
    input$search_brand
    input$name_type
    isolate({
      pt_selected <- input$search_rxn
      pt_choices <- fda_query("/drug/event.json")
      
      if (input$name_type == "generic" & !is.null(input$search_generic)) {
        query_str <- paste0('"', gsub(" ", "+", input$search_generic), '"')
        query_str <- sprintf('(%s)', paste0(query_str, collapse = '+'))
        pt_choices %<>% fda_filter("patient.drug.openfda.generic_name.exact", query_str)
      } else if (input$name_type == "brand" & !is.null(input$search_brand)) {
        query_str <- paste0('"', gsub(" ", "+", input$search_brand), '"')
        query_str <- sprintf('(%s)', paste0(query_str, collapse = '+'))
        pt_choices %<>% fda_filter("patient.drug.openfda.brand_name.exact", query_str)
      }
      
      pt_choices %<>%
        fda_count("patient.reaction.reactionmeddrapt.exact") %>%
        fda_limit(1000) %>%
        fda_exec() %>%
        .$term %>%
        sort() %>%
        grep("[%,']", ., value = TRUE, invert = TRUE) # https://github.com/FDA/openfda/issues/29
      
      if (is.null(pt_selected)) pt_selected = ""
      updateSelectizeInput(session, "search_rxn",
                           choices = c("Start typing to search..." = "", pt_choices),
                           selected = pt_selected)
    })
  })
  
  
  
  
  
  ########## Reactive data processing
  # Data structure to store current query info
  current_search <- reactiveValues()
  faers_query <- reactiveValues()
  
  # We need to have a reactive structure here so that it activates upon loading
  reactiveSearchButton <- reactive(as.vector(input$searchButton))
  observeEvent(reactiveSearchButton(), {
    
    withProgress(message = 'Calculation in progress', value = 0, {
    
    if (input$name_type == "generic") {
      name <- input$search_generic
    } else {
      name <- input$search_brand
    }
    incProgress(1/6)
    
    
    openfda_query <- fda_query("/drug/event.json")
    query_str <- paste0("[", input$searchDateRange[1], "+TO+", input$searchDateRange[2], "]")
    openfda_query %<>% fda_filter("receivedate", query_str)
    if(!is.null(name)) {
      query_str <- paste0('"', gsub(" ", "+", name), '"')
      query_str_combine <- sprintf('(%s)', paste0(query_str, collapse = '+'))

      if (input$name_type == "generic") {
        openfda_query %<>% fda_filter("patient.drug.openfda.generic_name.exact", query_str_combine)
      } else {
        openfda_query %<>% fda_filter("patient.drug.openfda.brand_name.exact", query_str_combine)
      }
    }
    incProgress(2/6)
    if(!is.null(input$search_rxn)) {
      query_str <- paste0('"', gsub(" ", "+", input$search_rxn), '"')
      query_str_combine <- sprintf('(%s)', paste0(query_str, collapse = '+'))
      openfda_query %<>% fda_filter("patient.reaction.reactionmeddrapt.exact", query_str_combine)
    }
    result <- openfda_query %>% fda_search() %>% fda_limit(1) %>% fda_exec()
    if (is.null(result)) {
      setProgress(1)
      showModal(modalDialog(
        title = list(icon("exclamation-triangle"), "No results found!"),
        "There were no reports matching your query.",
        size = "s",
        easyClose = TRUE))
      return()
    }
    incProgress(1/6)
    
    current_search$name_type<- input$name_type
    current_search$name<- name
    current_search$rxn <- input$search_rxn
    current_search$date_range <- input$searchDateRange
    faers_query$query <- openfda_query
    incProgress(2/6)
    })

  })
  ages <- reactive({
    query <- faers_query$query
    
    age_decades <- query %>% 
      fda_filter("patient.patientonsetageunit", "800") %>%
      fda_count("patient.patientonsetage") %>%
      fda_limit(1000) %>%
      fda_exec()
    if(is.null(age_decades)) age_decades <- data.frame(term = numeric(), count = numeric())
    age_decades %<>% mutate(term = term*10)
    
    age_years <- query %>% 
      fda_filter("patient.patientonsetageunit", "801") %>%
      fda_count("patient.patientonsetage") %>%
      fda_limit(1000) %>%
      fda_exec()
    if(is.null(age_years)) age_years <- data.frame(term = numeric(), count = numeric())
    
    age_months <- query %>% 
      fda_filter("patient.patientonsetageunit", "802") %>%
      fda_count("patient.patientonsetage") %>%
      fda_limit(1000) %>%
      fda_exec()
    if(is.null(age_months)) age_months <- data.frame(term = numeric(), count = numeric())
    age_months %<>% mutate(term = term/12)
    
    age_weeks <- query %>% 
      fda_filter("patient.patientonsetageunit", "803") %>%
      fda_count("patient.patientonsetage") %>%
      fda_limit(1000) %>%
      fda_exec()
    if(is.null(age_weeks)) age_weeks <- data.frame(term = numeric(), count = numeric())
    age_weeks %<>% mutate(term = term/52)
    
    age_days <- query %>% 
      fda_filter("patient.patientonsetageunit", "804") %>%
      fda_count("patient.patientonsetage") %>%
      fda_limit(1000) %>%
      fda_exec()
    if(is.null(age_days)) age_days <- data.frame(term = numeric(), count = numeric())
    age_days %<>% mutate(term = term/365)
    
    age_hours <- query %>% 
      fda_filter("patient.patientonsetageunit", "805") %>%
      fda_count("patient.patientonsetage") %>%
      fda_limit(1000) %>%
      fda_exec()
    
    if(is.null(age_hours)) age_hours <- data.frame(term = numeric(), count = numeric())
    age_hours %<>% mutate(term = term/(365*24))
    
    unknown <- query %>%
      fda_filter("_missing_", "patient.patientonsetage") %>%
      fda_url() %>%
      fda_fetch() %>%
      .$meta %>%
      .$results %>%
      .$total
    age_unknown <- data.frame(term = NA, count = unknown)
    
    ages <- bind_rows(age_decades,
                      age_years,
                      age_months,
                      age_weeks,
                      age_days,
                      age_hours,
                      age_unknown) %>%
      group_by(term) %>%
      summarise(count = sum(count)) %>%
      mutate(age_group = NA,
             age_group = ifelse(term <= 25/365, "Neonate", age_group),
             age_group = ifelse(term > 25/365 & term < 1, "Infant", age_group),
             age_group = ifelse(term >= 1 & term < 13, "Child", age_group),
             age_group = ifelse(term >= 13 & term < 18, "Adolescent", age_group),
             age_group = ifelse(term >= 18 & term <= 65, "Adult", age_group),
             age_group = ifelse(term > 65, "Elderly", age_group),
             age_group = ifelse(is.na(term), "Not reported", age_group))
  })
  
  ########## Output
  output$current_search <- renderTable({
    data <- current_search
    result <- data.frame(names = c("Name Type:", 
                                   "Name:", 
                                   "Adverse Reaction Term:",
                                   "Date Range:"),
                         values = c(toupper(data$name_type),
                                    ifelse(is.null(data$name), 'Not Specified', paste(data$name, collapse = ', ')),
                                    ifelse(is.null(data$rxn), 'Not Specified', paste(data$rxn, collapse = ', ')),
                                    paste(data$date_range, collapse = " to ")),
                         stringsAsFactors = FALSE)
    #result$values[result$values] <- "Not Specified"
    result
  }, include.colnames = FALSE)
  
  ### Create time plot
  output$timeplot_title <- renderUI({
    query <- faers_query$query
    nreports <- query %>%
      fda_search() %>%
      fda_url() %>%
      fda_fetch() %>%
      .$meta %>%
      .$results %>%
      .$total
    drug_name <- current_search$name
    rxn_name <- current_search$rxn
    
    if (is.null(drug_name)) drug_name <- "All Drugs"
    if (is.null(rxn_name)) rxn_name <- "All Reactions"
    plottitle <- paste0("Drug Adverse Event Reports for ", paste0(drug_name, collapse = ', '), " and ", paste0(rxn_name, collapse = ', '), " (", nreports, " reports)")
    h3(strong(plottitle))
  })
  output$timeplot <- renderGvis({
    query <- faers_query$query
    
    total_results <- query %>%
      fda_count("receivedate") %>%
      fda_limit(1000) %>%
      fda_exec() %>%
      mutate(month = floor_date(ymd(time), "month")) %>%
      count(month, wt = count) %>%
      rename(total = n)
    serious_results <- query %>%
      fda_filter("serious", "1") %>%
      fda_count("receivedate") %>%
      fda_limit(1000) %>%
      fda_exec() %>%
      mutate(month = floor_date(ymd(time), "month")) %>%
      count(month, wt = count) %>%
      rename(serious = n)
    death_results <- query %>%
      fda_filter("seriousnessdeath", "1") %>%
      fda_count("receivedate") %>%
      fda_limit(1000) %>%
      fda_exec() %>%
      mutate(month = floor_date(ymd(time), "month")) %>%
      count(month, wt = count) %>%
      rename(death = n)
    
    nmonths <- interval(min(total_results$month), max(total_results$month)) %/% months(1)
    time_list <- min(total_results$month) + months(0:nmonths)
    
    results <- data.frame(month = time_list) %>%
      left_join(total_results, by = "month") %>%
      left_join(serious_results, by = "month") %>%
      left_join(death_results, by = "month")
    results[is.na(results)] <- 0
    
    gvisLineChart(results,
                  xvar = "month",
                  yvar = c("total", "serious", "death"),
                  options = list(
                    height = 350,
                    vAxis = "{title: 'Number of Reports'}",
                    hAxis = "{title: 'Date Received (grouped by month)'}",
                    chartArea = "{top: 10, height: '80%', left: 120, width: '84%'}",
                    colors = colorCodeToString(google_colors[c(18, 13, 2)])
                  ))
  })
  output$search_url <- renderUI({
    url <- faers_query$query %>%
      fda_search() %>%
      fda_limit(100) %>%
      fda_url()
    HTML(paste0("Reports by month from US FDA FAERS (open.fda.gov). Search URL: <a href = ", url, ">", url, "</a>"))
  })
  
  ### Data about Reports
  output$reporterplot <- renderGvis({
    query <- faers_query$query
    
    reporter_results <- query %>%
      fda_count("primarysource.qualification") %>%
      fda_exec()
    if (is.null(reporter_results)) reporter_results <- data.frame(term = numeric(), count = numeric())
    reporter_code <- data.frame(term = 1:5,
                                label = c("Physician",
                                          "Pharmacist",
                                          "Other health professional",
                                          "Lawyer",
                                          "Consumer or non-health professional"),
                                stringsAsFactors = FALSE)
    reporter_results <- reporter_results %>%
      left_join(reporter_code, by = "term") %>%
      select(label, count)
    
    unknown <- query %>%
      fda_filter("_missing_", "primarysource.qualification") %>%
      fda_url() %>%
      fda_fetch() %>%
      .$meta %>%
      .$results %>%
      .$total
    if (!is.null(unknown)) reporter_results <- rbind(reporter_results, c("Not reported", unknown))
    reporter_results %<>% mutate(count = as.numeric(count))
    
    gvisPieChart_HCSC(reporter_results, "label", "count")
  })
  output$seriousplot <- renderGvis({
    query <- faers_query$query
    serious_results <- query %>%
      fda_count("serious") %>%
      fda_exec()
    if (is.null(serious_results)) serious_results <- data.frame(term = numeric(), count = numeric())
    
    serious_results <- serious_results %>%
      mutate(label = ifelse(term == 1, "Serious", "Non-serious")) %>%
      select(label, count) %>%
      slice(match(c("Serious", "Non-serious", "Not reported"), label))
    
    unknown <- query %>%
      fda_filter("_missing_", "serious") %>%
      fda_url() %>%
      fda_fetch() %>%
      .$meta %>%
      .$results %>%
      .$total
    if (!is.null(unknown)) serious_results <- rbind(serious_results, c("Not Reported", unknown))
    serious_results %<>% mutate(count = as.numeric(count))
    
    gvisPieChart_HCSC(serious_results, "label", "count")
  })
  output$seriousreasonsplot <- renderGvis({
    query <- faers_query$query
    
    congenital_results <- query %>%
      fda_count("seriousnesscongenitalanomali") %>%
      fda_exec()
    if (is.null(congenital_results)) congenital_results <- data.frame(term = 1, count = 0)
    
    death_results <-  query %>% 
      fda_count("seriousnessdeath") %>% 
      fda_exec()
    if (is.null(death_results)) death_results <- data.frame(term = 1, count = 0)
    
    disabling_results <-  query %>%
      fda_count("seriousnessdisabling") %>%
      fda_exec()
    if (is.null(disabling_results)) disabling_results <- data.frame(term = 1, count = 0)
    
    hospital_results <-  query %>%
      fda_count("seriousnesshospitalization") %>%
      fda_exec()
    if (is.null(hospital_results)) hospital_results <- data.frame(term = 1, count = 0)
    
    lifethreaten_results <-  query %>%
      fda_count("seriousnesslifethreatening") %>%
      fda_exec()
    if (is.null(lifethreaten_results)) lifethreaten_results <- data.frame(term = 1, count = 0)
    
    serother_results <-  query %>%
      fda_count("seriousnessother") %>%
      fda_exec()
    if (is.null(serother_results)) serother_results <- data.frame(term = 1, count = 0)
    
    serious_reasons <- bind_rows("Death" = death_results,
                                 "Life-threatening condition" = lifethreaten_results,
                                 "Hospitalization" = hospital_results,
                                 "Disabling" = disabling_results,
                                 "Congenital anomaly" = congenital_results,
                                 "Other serious condition" = serother_results,
                                 .id = "label")
    
    gvisBarChart(serious_reasons,
                 xvar = "label",
                 yvar = "count",
                 options = list(
                   legend = "{position: 'none'}",
                   hAxis = "{title: 'Percentage'}",
                   chartArea = "{top: 0, height: '80%', left: 150, width: '60%'}",
                   bar = "{groupWidth: '90%'}",
                   colors = colorCodeToString(google_colors[5])
                 )
    )
  })
  output$countryplot <- renderGvis({
    query <- faers_query$query
    
    country_results <- query %>%
      fda_count("occurcountry") %>%
      fda_limit(10) %>%
      fda_exec()
    if (is.null(country_results)) country_results <- data.frame(term = character(), count = numeric())
    
    unknown <- query %>%
      fda_filter("_missing_", "occurcountry") %>%
      fda_url() %>%
      fda_fetch() %>%
      .$meta %>%
      .$results %>%
      .$total
    
    if (!is.null(unknown)) country_results <- rbind(country_results, c("not reported", unknown))
    country_results %<>% mutate(count = as.numeric(count))
    
    gvisBarChart(data = country_results,
                 xvar = "term",
                 yvar = "count",
                 options = list(
                   legend = "{position: 'none'}",
                   hAxis = "{title: 'Number of Reports'}",
                   colors = colorCodeToString(google_colors[8]),
                   height = 300,
                   chartArea = "{top: 0, height: '80%', left: 100, width: '80%'}",
                   bar = "{groupWidth: '80%'}"
                 ))
  })
  
  ### Data about Patients
  output$sexplot <- renderGvis({
    query <- faers_query$query
    
    sex_code <- data.frame(term = 0:2,
                           label = c("Unknown",
                                     "Male",
                                     "Female"),
                           stringsAsFactors = FALSE)
    
    sex_results <- query %>% 
      fda_count("patient.patientsex") %>% 
      fda_exec() %>%
      left_join(sex_code, by = "term")
    if(is.null(sex_results)) sex_results <- data.frame(term = numeric(), count = numeric())
    
    unknown <- query %>%
      fda_filter("_missing_", "patient.patientsex") %>%
      fda_url() %>%
      fda_fetch() %>%
      .$meta %>%
      .$results %>%
      .$total
    if (!is.null(unknown)) sex_results %<>% rbind(c(3, unknown, "Not reported"))
    sex_results %<>% select(label, count) %>% mutate(count = as.numeric(count))
    
    gvisPieChart_HCSC(sex_results, "label", "count")
  })
  output$agegroupplot <- renderGvis({
    age_groups <- ages() %>%
      group_by(age_group) %>%
      summarise(count = sum(count))
    age_group_order <- data.frame(age_group = c("Neonate",
                                                "Infant",
                                                "Child",
                                                "Adolescent",
                                                "Adult",
                                                "Elderly",
                                                "Not reported"),
                                  stringsAsFactors = FALSE)
    data <- left_join(age_group_order, age_groups, by = "age_group")
    data[is.na(data)] <- 0 # always including empty rows means colour-scheme will be consistent
    
    gvisPieChart_HCSC(data, "age_group", "count")
  })
  output$agehisttitle <- renderUI({
    excluded_count <- ages() %>%
      filter(age_group != "Unknown", term > 100) %>%
      `$`('count') %>% sum()
    HTML(paste0("<h3>Histogram of Patient Ages ",
                tipify(
                  el = icon("info-circle"), trigger = "hover click",
                  title = "Distribution of number of reports per age, colour-coded by age group. Each bin groups 2 years."),
                "<br>(", excluded_count, " reports with age greater than 100 excluded)", "</h3>"))
  })
  output$agehist <- renderPlotly({
    age_groups <- ages() %>% filter(age_group != "Unknown", term <= 100) %>% rename(age = term)
    age_groups$age_group %<>% factor(levels = c("Neonate", "Infant", "Child", "Adolescent", "Adult", "Elderly"))
    
    # joining by remaining terms so you can assign the right colours to the legend
    colours_df <- data.frame(
      age_group = c("Neonate", "Infant", "Child", "Adolescent", "Adult", "Elderly"),
      colours = google_colors[1:6],
      stringsAsFactors = FALSE) %>%
      semi_join(distinct(age_groups, age_group), by = "age_group")
    
    hist <- ggplot(age_groups, aes(x = age, weight = count, fill = age_group)) +
      geom_histogram(breaks = seq(0, 100, by = 2)) +
      scale_fill_manual(values = colours_df$colours) +
      xlab("Age at onset (years)") + 
      ylab("Number of Reports") +
      theme_bw()
    ggplotly(hist)
  })
  
  ### Data about Drugs
  output$indication_plot <- renderGvis({
    query <- faers_query$query
    
    indications <- query %>%
      fda_count("patient.drug.drugindication.exact") %>%
      fda_limit(25) %>%
      fda_exec()
    
    if(is.null(indications)) indications <- data.frame(term = character(), count = numeric())
    gvisBarChart_HCSC(indications, "term", "count", google_colors[4])
  })
  output$all_drugs <- renderGvis({
    query <- faers_query$query
    
    drugs <- query %>%
      fda_count("patient.drug.openfda.generic_name.exact") %>%
      fda_limit(25) %>%
      fda_exec()
    
    if (is.null(drugs)) drugs <- data.frame(term = character(), count = numeric())
    gvisBarChart_HCSC(drugs, "term", "count", google_colors[5])
  })
  output$drugclassplot <- renderGvis({
    query <- faers_query$query
    
    drugclass <- query %>%
      fda_count("patient.drug.openfda.pharm_class_epc.exact") %>%
      fda_limit(25) %>%
      fda_exec()
    
    if(is.null(drugclass)) drugclass <- data.frame(term = character(), count = numeric())
    gvisBarChart_HCSC(drugclass, "term", "count", google_colors[3])
  })
  
  ### Data about Reactions
  output$top_pt <- renderGvis({
    query <- faers_query$query
    
    data <- query %>%
      fda_count("patient.reaction.reactionmeddrapt.exact") %>%
      fda_limit(25) %>%
      fda_exec()
    
    gvisBarChart_HCSC(data, "term", "count", google_colors[4])
    })
  output$top_hlt <- renderGvis({
    query <- faers_query$query
    
    data <- query %>%
      fda_count("patient.reaction.reactionmeddrapt.exact") %>%
      fda_limit(1000) %>%
      fda_exec() %>%
      inner_join(meddra, by = "term") %>%
      distinct(term, HLT_Term, count) %>%
      group_by(HLT_Term) %>%
      summarise(count = sum(count)) %>%
      top_n(25, count) %>%
      arrange(desc(count))
    
    gvisBarChart_HCSC(data, "HLT_Term", "count", google_colors[5])
    })
  output$outcomeplot <- renderGvis({
    query <- faers_query$query
    
    outcome_results <- query %>% 
      fda_count("patient.reaction.reactionoutcome") %>% 
      fda_exec()
    if(is.null(outcome_results)) outcome_results <- data.frame(term = numeric(), count = numeric())
    
    outcome_code <- data.frame(term = 1:6,
                               label = c("Recovered/resolved",
                                         "Recovering/resolving",
                                         "Not recovered/not resolved",
                                         "Recovered/resolved with sequelae (consequent health issues)",
                                         "Fatal",
                                         "Unknown"),
                               stringsAsFactors = FALSE)
    
    outcome_results <- outcome_results %>%  
      left_join(outcome_code, by = "term") %>%
      select(label, count)
    
    gvisPieChart_HCSC(outcome_results, "label", "count")
  })
  
}

shinyApp(ui, server)
