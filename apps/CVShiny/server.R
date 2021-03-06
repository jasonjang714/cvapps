library(plotly)
library(stringr)
shinyServer(function(input, output, session) {
  
  ### page loader setting ###
  Sys.sleep(5)
  hide(id="loading-content",anim=TRUE,animType="fade")
  show("main-content")
  
  updateSelectizeInput(session, 'search_brand', choices = topbrands, server = TRUE)
  updateSelectizeInput(session, 'search_ing', choices = topings_cv, server = TRUE)
  updateSelectizeInput(session, 'search_rxn', choices = pt_choices, server = TRUE)
  updateSelectizeInput(session, 'search_soc', choices = soc_choices, server = TRUE)
  
  # callModule(cvshiny_selectinput, 'search_soc', data = soc_choices)
  # callModule(cvshiny_selectinput, 'search_brand', data = topbrands)
  
  
  ##### Reactive data processing
  # Data structure to store current query info
  current_search <- reactiveValues()
  #subset_cv <- reactiveValues()
  selected_ids <- reactiveValues()
  report_tab <- reactiveValues()
  
  
  
  
  # We need to have a reactive structure here so that it activates upon loading
  reactiveSearchButton <- reactive(as.vector(input$searchButton))
  
  
  
  
  observeEvent(reactiveSearchButton(),
               withProgress(message = 'Calculation in progress', value = 0, {
                 
                 if (input$name_type == "brand") {
                   name <- input$search_brand
                 } else if (input$name_type == "ingredient") {
                   name <- input$search_ing
                 } else {
                   name <- input$search_ing2
                 }
                 
                 startDate <- input$daterange[1] %>% ymd(tz = 'EST')
                 endDate <- input$daterange[2] %>% ymd(tz = 'EST')
                 dateRange <- c(startDate, endDate)
                 
                 current_search$name_type <- input$name_type
                 current_search$name <- name
                 current_search$drug_inv <- input$drug_inv
                 current_search$seriousness_type <- input$seriousness_type
                 current_search$rxn <- input$search_rxn
                 current_search$gender <- input$search_gender
                 current_search$soc <- input$search_soc
                 current_search$age <- input$search_age
                 current_search$date_range <- dateRange
                 current_search$checkbox_filter <- input$filter_over_100
                 incProgress(1/9, detail = 'Filtering Report Date Range')
                 
                 if (month(input$daterange[2]) - month(input$daterange[1]) == 0)
                 {
                   endDate = input$daterange[2] + month(1)
                 }
                 startDate <- input$daterange[1] %>% ymd(tz = 'EST') %>% floor_date(unit="month")
                 endDate <- endDate %>% ymd(tz = 'EST') %>% floor_date(unit="month")
                 dateRange <- c(startDate, endDate)
                 
                 cv_reports_filtered_ids <- cv_reports %>%
                   filter(DATINTRECEIVED_CLEAN >= dateRange[1], DATINTRECEIVED_CLEAN <= dateRange[2])
                 incProgress(1/9, detail = 'Filtering Seriousness Type and Gender')
                 
                 if (current_search$seriousness_type == "Death") {cv_reports_filtered_ids %<>% filter(DEATH == '1')}
                 else if (current_search$seriousness_type == "Serious(Excluding Death)") {cv_reports_filtered_ids %<>% filter(SERIOUSNESS_ENG == 'Yes') %<>% filter(is.null(DEATH) || DEATH == 2)}
                 
                 if (current_search$gender == 'Male' | current_search$gender == 'Female') {
                   cv_reports_filtered_ids %<>% filter(GENDER_ENG == current_search$gender)
                 }
                 incProgress(1/9, detail = 'Applying Age Constraints')
                 
                 if (current_search$checkbox_filter & current_search$age[2] == 100) {
                   cv_reports_filtered_ids %<>% filter(AGE_Y >= current_search$age[1])
                 } else {
                   cv_reports_filtered_ids %<>% filter(AGE_Y >= current_search$age[1] & AGE_Y <= current_search$age[2])
                 }
                 cv_reports_filtered_ids %<>% select(REPORT_ID)
                 
                 
                 cv_report_drug_filtered <- cv_report_drug
                 if (current_search$name_type == "brand" & !is.null(current_search$name)) {
                   if (length(current_search$name) == 1) cv_report_drug_filtered %<>% filter(DRUGNAME == current_search$name)
                   else cv_report_drug_filtered %<>% filter(DRUGNAME %in% current_search$name)
                   
                   incProgress(1/9, detail = 'Filtering by Brand')
                   
                 } else if (current_search$name_type == "ingredient2" & !is.null(current_search$name) && current_search$name != "") {
                   related_drugs <- cv_substances %>% filter(ing == current_search$name)
                   cv_report_drug_filtered %<>% semi_join(related_drugs, by = "DRUGNAME")
                   
                 } else if (current_search$name_type == "ingredient" & !is.null(current_search$name)) {
                   if (length(current_search$name) == 1) related_drugs <- cv_drug_product_ingredients %>% filter(ACTIVE_INGREDIENT_NAME == current_search$name)
                   else related_drugs <- cv_drug_product_ingredients %>% filter(ACTIVE_INGREDIENT_NAME %in% current_search$name)
                   cv_report_drug_filtered %<>% semi_join(related_drugs, by = "DRUG_PRODUCT_ID")
                   
                   incProgress(1/9, detail = 'Filtering by Ingredient')
                   
                 }
                 if (current_search$drug_inv != "Any") cv_report_drug_filtered %<>% filter(DRUGINVOLV_ENG == current_search$drug_inv)
                 if (current_search$seriousness_type == "Death") {cv_report_drug_filtered %<>% filter(DEATH == '1')}
                 else if (current_search$seriousness_type == "Serious(Excluding Death)") {cv_report_drug_filtered %<>% filter(SERIOUSNESS_ENG == 'Yes') %<>% filter(is.null(DEATH) || DEATH == 2)}
                 
                 incProgress(2/9, detail = 'Filtering Reactions')
                 
                 
                 cv_reactions_filtered <- cv_reactions %>% filter(PT_NAME_ENG != "")
                 if (!is.null(current_search$rxn)) {
                   if (length(current_search$rxn) == 1) {
                     cv_reactions_filtered %<>% filter(PT_NAME_ENG == current_search$rxn | SMQ == current_search$rxn) %>% distinct()
                   } else {
                     cv_reactions_filtered %<>% filter(PT_NAME_ENG %in% current_search$rxn | SMQ %in% current_search$rxn) %>% distinct()
                   }
                 }
                 if (!is.null(current_search$soc)) {
                   if (length(current_search$soc) == 1) cv_reactions_filtered %<>% filter(SOC_NAME_ENG == current_search$soc)
                   else cv_reactions_filtered %<>% filter(SOC_NAME_ENG %in% current_search$soc)
                 }
                 
                 # cv_reports_filtered_ids %<>% as.data.frame()
                 # cv_report_drug_filtered %<>% as.data.frame()
                 # cv_reactions_filtered %<>% as.data.frame()
                 if (current_search$seriousness_type == "Death") {cv_reactions_filtered %<>% filter(DEATH == '1')}
                 else if (current_search$seriousness_type == "Serious(Excluding Death)") {cv_reactions_filtered %<>% filter(SERIOUSNESS_ENG == 'Yes') %<>% filter(is.null(DEATH) || DEATH == 2)}
                 
                 
                 selected_ids$ids <-  cv_reports_filtered_ids %>%
                   semi_join(cv_report_drug_filtered, "REPORT_ID" = "REPORT_ID") %>%
                   semi_join(cv_reactions_filtered, "REPORT_ID" = "REPORT_ID") %>% as.data.frame()
                 incProgress(1/9, detail = 'Checking for no reports...')
                 n_ids <- selected_ids$ids %>% nrow()
                 if (n_ids == 0) {
                   setProgress(1)
                   showModal(modalDialog(
                     title = list(icon("exclamation-triangle"), "No results found!"),
                     "There were no reports matching your query.",
                     size = "s",
                     easyClose = TRUE))
                   return()
                 }
                 
                 incProgress(1/9, detail = 'Fetching data...')
                 
                 # so then all data is polled upon search, not just when display corresponding plot
                 # subset_cv$report <- cv_reports %>%
                 #   semi_join(selected_ids, by = "REPORT_ID")
                 # subset_cv$drug <- cv_report_drug %>%
                 #   semi_join(selected_ids, by = "REPORT_ID") %>%
                 #   left_join(cv_report_drug_indication, by = c("REPORT_DRUG_ID", "REPORT_ID", "DRUG_PRODUCT_ID", "DRUGNAME")) 
                 # subset_cv$rxn <- cv_reactions %>%
                 #   semi_join(selected_ids, by = "REPORT_ID") %>%
                 #   left_join(meddra, by = c("PT_NAME_ENG" = "PT_Term", "MEDDRA_VERSION" = "Version"))
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 incProgress(1/9)
               })
  )
  
  strtrans <- function(input)
  {
    input <- as.character(input)
    input <- str_pad(input, 9, pad = "0")
    input <- paste0("\t",input)
    
    return(input)
  }
  
  cv_download_reports <- reactive({
    data_type <- ""
    
    if(input$search_dataset_type == "Report Data"){
      reports_tab_master <- mainDataSelection() %>% as.data.frame()
      reports_tab_master$REPORT_ID <- strtrans(reports_tab_master$REPORT_ID)
      reports_tab_master$REPORT_NO <- strtrans(reports_tab_master$REPORT_NO)
      reports_tab_master %<>% `[`(, input$column_select_report) %>% as.data.frame()
      colnames(reports_tab_master) <- input$column_select_report
      data_type <- "report"
    } 
    else if(input$search_dataset_type == "Drug Data"){
      reports_tab_master <- drugDataSelection() %>% as.data.frame()
      reports_tab_master$REPORT_ID <- strtrans(reports_tab_master$REPORT_ID)
      reports_tab_master$REPORT_NO <- strtrans(reports_tab_master$REPORT_NO)
      reports_tab_master %<>% `[`(, input$column_select_drug) %>% as.data.frame()
      colnames(reports_tab_master) <- input$column_select_drug
      data_type <- "drug"
    } 
    else if(input$search_dataset_type == "Reaction Data"){
      reports_tab_master <- rxnDataSelection() %>% as.data.frame()
      reports_tab_master$REPORT_ID <- strtrans(reports_tab_master$REPORT_ID)
      reports_tab_master$REPORT_NO <- strtrans(reports_tab_master$REPORT_NO)
      reports_tab_master %<>% `[`(, input$column_select_reaction) %>% as.data.frame()
      colnames(reports_tab_master) <- input$column_select_reaction
      data_type <- "rxn"
    }
    
    return(list(
      reports_tab_master = reports_tab_master,
      data_type = data_type
    ))
  })
  
  ##### Output ####
  ##### Construct Current_Query_Table for generic name, brand name, adverse reaction term & date range searched
  output$current_search <- renderTable({
    data <- current_search
    result <- data.frame(names = c("Name Type:",
                                   "Age Range:",
                                   "Gender:",
                                   "Name:",
                                   "Adverse Reaction Term:",
                                   "System Organ Class:",
                                   "Seriousness:",
                                   "Date Range:"),
                         values = c(data$name_type %>% toupper(),
                                    sprintf("%s to %s%s", data$age[1], data$age[2], ifelse(data$checkbox_filter & data$age[2] == 100, '+', '')),
                                    data$gender,
                                    paste0(data$name, collapse = ", "),
                                    paste0(data$rxn, collapse = ", "),
                                    paste0(data$soc, collapse = ", "),
                                    paste0(data$seriousness_type, collapse = ", "),
                                    paste(data$date_range, collapse = " to ")),
                         stringsAsFactors = FALSE)
    result$values["" == result$values] <- "Not Specified"
    result
  },
  include.colnames = FALSE
  )
  
  mainDataSelection <- reactive({
    # mychart_pool <- src_pool(hcopen_pool)
    # search_function(mychart_pool, current_search)
    n_ids <- selected_ids$ids %>% nrow()
    if (nrow(selected_ids$ids) > 0)
    {
      data <- semi_join(cv_reports, selected_ids$ids, by = "REPORT_ID", copy=T)
    }
    else
    {
      data <- NULL
      data <- cv_reports
      current_search$name = ""
      current_search$rxn = ""
    }
    data
  })
  
  ##### Create time plot  ###
  
  output$timeplot_title <- renderUI({
    data <- mainDataSelection()
    
    nreports <- data %>%
      distinct(REPORT_ID) %>%
      tally() %>%
      as.data.frame()
    drug_name <- paste0(current_search$name, collapse = ", ")
    rxn_name <- paste0(current_search$rxn, collapse = ", ")
    
    if ("" == drug_name) drug_name <- "All Drugs"
    if ("" == rxn_name) rxn_name <- "All Reactions"
    plottitle <- paste0("Drug Adverse Event Reports for ", drug_name, " and ", rxn_name, " (", nreports, " reports) from ",input$daterange[1], " to ",input$daterange[2])
    h3(strong(plottitle))
  })
  output$mychart <- renderLineChart({
    # adrplot_test <- reports_tab(current_generic="ampicillin",current_brand="PENBRITIN",current_rxn="Urticaria"))
    # report_tab$main_chart
    # mychart_pool <- src_pool(hcopen_pool)
    # cv_reports <- tbl(pool_src, paste0('cv_reports_', time_period))
    # cv_report_drug <- tbl(pool_src, paste0('cv_report_drug_', time_period))
    # cv_drug_product_ingredients <- tbl(pool_src, paste0('cv_drug_product_ingredients_', time_period))
    # cv_reactions <- tbl(pool_src, paste0('cv_reactions_', time_period))
    # search_function(mychart_pool, current_search)
    # data <- semi_join(cv_reports, selected_ids, by = "REPORT_ID")
    data <- mainDataSelection()
    
    
    
    dates <- data %>% select(DATINTRECEIVED_CLEAN) %>% summarize(date_min = min(DATINTRECEIVED_CLEAN),
                                                                 date_max = max(DATINTRECEIVED_CLEAN)) %>%
      as.data.frame()
    
    two_years <- 730
    
    if ((dates$date_max - dates$date_min) >= two_years) {
      time_period <- "year"
      time_function <- function(x) {years(x)}
    } else {
      time_period <- "month"
      time_function <- function(x) {months(x)}
    }
    
    data_r <- data %>% select(c(DATINTRECEIVED_CLEAN, SERIOUSNESS_ENG, DEATH)) %>%
      dplyr::mutate(time_p = date_trunc(time_period, DATINTRECEIVED_CLEAN))
    
    
    total_results <- data_r %>%
      group_by(time_p) %>%
      summarize(total = n())
    
    nonserious_results <- data_r %>%
      filter(SERIOUSNESS_ENG == "No") %>%
      group_by(time_p) %>%
      summarize(Nonserious = n())
    
    
    serious_results <- data_r %>%
      filter(SERIOUSNESS_ENG == "Yes") %>%
      filter(is.null(DEATH) || DEATH == 2) %>%
      group_by(time_p) %>%
      summarize("Serious(Excluding Death)" = n())
    
    
    
    death_results <- data_r %>%
      filter(DEATH == 1) %>%
      group_by(time_p) %>%
      summarize(Death = n())
    
    
    ntime_p <- interval(dates$date_min, dates$date_max) %/% time_function(1)
    time_list <- min(dates$date_min %>% floor_date(time_period)) + time_function(0:ntime_p)
    
    results_to_be_mapped <- full_join(serious_results, death_results, by = 'time_p') %>%
      full_join(nonserious_results, by = 'time_p') %>% as.data.frame() %>%
      mutate(time_p = ymd(time_p))
    
    results <- data.frame(time_p = time_list) %>%
      left_join(results_to_be_mapped, by = 'time_p')
    
    results[is.na(results)] <- 0
    results
  })
  
  ##### Data about Reports
  
  ### Reporterplot ###
  reportertable <- reactive({
    df <- mainDataSelection() %>%
      count(REPORTER_TYPE_ENG) %>%
      as.data.frame()
    
    df$REPORTER_TYPE_ENG[df$REPORTER_TYPE_ENG == ""] <- "Not reported"
    df$REPORTER_TYPE_ENG[df$REPORTER_TYPE_ENG == "Consumer Or Other Non Health Professional"] <- "Consumer or non-health professional"
    df$REPORTER_TYPE_ENG[df$REPORTER_TYPE_ENG == "Other Health Professional"] <- "Other health professional"
    
    return(df)
  })
  
  output$reporterchart <- renderGvis({
    x = "REPORTER_TYPE_ENG"
    y = "count"
    gvisPieChart_HCSC(as.data.frame(reportertable()),x,y)
  })
  
  output$reportertable    <- renderGvis({
    gvisTable(as.data.frame(reportertable()))
  })
  
  ### seriousplot ###
  seriousplot_data <- reactive({
    ser_eng <- mainDataSelection() %>%
      count(SERIOUSNESS_ENG) %>%
      select(SERIOUSNESS_ENG,n) %>%
      mutate(label = "SERIOUSNESS_ENG") %>%
      as.data.frame()
    
    death_count <- mainDataSelection() %>%
      count(DEATH) %>%
      select(DEATH,n) %>%
      mutate(label = "Death") %>%
      as.data.frame()
    
    colnames(ser_eng) <- c("content","n","label")
    colnames(death_count) <- c("content","n","label")  
    
    big_table <- rbind(ser_eng,death_count)
    big_table %<>% as.data.frame()
    no_row <- big_table[big_table$label=="SERIOUSNESS_ENG" & big_table$content=="No",]
    yes_row <- big_table[big_table$label=="SERIOUSNESS_ENG" & big_table$content=="Yes",]
    one_row <- big_table[big_table$label=="Death" & big_table$content=='1',]
    missing_row <- big_table[big_table$content=="",]
    big_table <- rbind(no_row,yes_row,one_row,missing_row)
    big_table <- na.omit(big_table)
    if (nrow(big_table[big_table$content==1,])==0 || is.null(big_table[big_table$content==1,]))
    {
      number = 0
    }
    else
    {
      number = big_table[big_table$content==1,]$n
    }
    
    for (i in 1:nrow(big_table))
    {
      if (big_table[i,1] == "") {big_table[i,3] <- "Not reported"}
      else if (big_table[i,1] == 'No') {big_table[i,3] <- "Non-serious"}
      else if (big_table[i,1] == 'Yes') 
      {
        big_table[i,3] <- "Serious(Excluding Death)"
        big_table[i,2] <- big_table[i,2] - number
      }
      else if (big_table[i,1] == 1) {big_table[i,3] <- "Death"}
    }
    
    big_table %<>%
      as.data.frame() %>%
      select(label,n)%>%
      slice(match(c("Serious(Excluding Death)", "Death", "Non-serious", "Not reported"), label))
    
    return(big_table)
  })
  
  output$seriouschart <- renderGvis({
    x = "label"
    y = "count"
    gvisPieChart_HCSC(as.data.frame(seriousplot_data()),x,y)
  })
  
  output$serioustable    <- renderGvis({
    gvisTable(as.data.frame(seriousplot_data()))
  })
  
  
  
  ### seriousreasonplot ###
  output$seriousreasonsplot <- renderGvis({
    data <- mainDataSelection() %>%
      filter(SERIOUSNESS_ENG == "Yes")
    
    n_congen <- data %>%
      filter(CONGENITAL_ANOMALY == 1) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    n_death <- data %>%
      filter(DEATH == 1) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    n_disab <- data %>%
      filter(DISABILITY == 1) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    n_lifethreat <- data %>%
      filter(LIFE_THREATENING == 1) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    n_hosp <- data %>%
      filter(HOSP_REQUIRED == 1) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    n_other <- data %>%
      filter(OTHER_MEDICALLY_IMP_COND == 1) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    ## Check for NotSpecified ##
    n_notspec <- data %>%
      filter(DEATH != 1 | is.na(DEATH)) %>%
      filter(DISABILITY != 1 | is.na(DISABILITY)) %>%
      filter(CONGENITAL_ANOMALY != 1 | is.na(CONGENITAL_ANOMALY)) %>%
      filter(LIFE_THREATENING != 1 | is.na(LIFE_THREATENING)) %>%
      filter(HOSP_REQUIRED != 1 | is.na(HOSP_REQUIRED)) %>%
      filter(OTHER_MEDICALLY_IMP_COND != 1 | is.na(OTHER_MEDICALLY_IMP_COND)) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    
    serious_reasons <- data.frame(label = c("Death",
                                            "Life-threatening",
                                            "Hospitalization",
                                            "Disability",
                                            "Congenital anomaly",
                                            "Other medically important condition",
                                            "Not specified"),
                                  count = c(n_death,
                                            n_lifethreat,
                                            n_hosp,
                                            n_disab,
                                            n_congen,
                                            n_other,
                                            n_notspec),
                                  stringsAsFactors = FALSE)
    
    gvisBarChart(serious_reasons,
                 xvar = "label",
                 yvar = "count",
                 options = list(
                   legend = "{position: 'none'}",
                   hAxis = "{title: 'Number of Reports'}",
                   chartArea = "{top: 0, height: '80%', left: 150, width: '60%'}",
                   bar = "{groupWidth: '90%'}",
                   colors = colorCodeToString(google_colors[5])
                 )
    )
  })
  
  ### Data about Patients
  sexplot_data <- reactive({
    data <- mainDataSelection() %>%
      count(GENDER_ENG) %>%
      as.data.frame()
    data$GENDER_ENG[data$GENDER_ENG == ""] <- "Not specified"
    sex_results <- count(data, GENDER_ENG, wt = n)
    sex_results
  })
  
  output$sexchart <- renderGvis({
    x = "GENDER_ENG"
    y = "n"
    gvisPieChart_HCSC(as.data.frame(sexplot_data()),x,y)
  })
  
  output$sextable    <- renderGvis({
    gvisTable(as.data.frame(sexplot_data()))
  })
  
  
  
  agegroup_data <-reactive({
    age_groups <- mainDataSelection() %>%
      count(AGE_GROUP_CLEAN) %>%
      as.data.frame()
    age_group_order <- data.frame(AGE_GROUP_CLEAN = c("Neonate",
                                                      "Infant",
                                                      "Child",
                                                      "Adolescent",
                                                      "Adult",
                                                      "Elderly",
                                                      "Unknown"),
                                  stringsAsFactors = FALSE)
    data <- left_join(age_group_order, age_groups, by = "AGE_GROUP_CLEAN")
    data[is.na(data)] <- 0 # always including empty rows means colour-scheme will be consistent
    data
  })
  output$agechart <- renderGvis({
    x = "AGE_GROUP_CLEAN"
    y = "n"
    gvisPieChart_HCSC(as.data.frame(agegroup_data()),x,y)
  })
  
  output$agetable    <- renderGvis({
    gvisTable(as.data.frame(agegroup_data()))
  })
  
  
  
  output$agehisttitle <- renderUI({
    excluded_count <- mainDataSelection() %>%
      filter(AGE_GROUP_CLEAN != "Unknown", AGE_Y > 100) %>%
      tally() %>% as.data.frame() %>% `$`(n)
    HTML(paste0("<h3>Histogram of Patient Ages ",
                tipify(
                  el = icon("info-circle"), trigger = "hover click",
                  title = "Distribution of number of reports per age, colour-coded by age group. Each bin groups 2 years."),
                "<br>(", excluded_count, " reports with age greater than 100 excluded)", "</h3>"))
  })
  output$agehist <- renderPlotly({
    age_groups <- mainDataSelection() %>% filter(AGE_GROUP_CLEAN != "Unknown", AGE_Y <= 100) %>%
      arrange(AGE_Y) %>% 
      select(c(AGE_Y, AGE_GROUP_CLEAN)) %>%
      as.data.frame()
    age_groups$AGE_GROUP_CLEAN %<>% factor(levels = c("Neonate", "Infant", "Child", "Adolescent", "Adult", "Elderly"))
    
    # joining by remaining terms so you can assign the right colours to the legend
    colours_df <- data.frame(
      AGE_GROUP_CLEAN = c("Neonate", "Infant", "Child", "Adolescent", "Adult", "Elderly"),
      colours = google_colors[1:6],
      stringsAsFactors = FALSE) %>%
      semi_join(age_groups, by = "AGE_GROUP_CLEAN")
    
    hist <- ggplot(age_groups, aes(x = AGE_Y, fill = AGE_GROUP_CLEAN)) +
      geom_histogram(breaks = seq(0, 100, by = 2)) +
      scale_fill_manual(values = colours_df$colours) +
      xlab("Age at onset (years)") +
      ylab("Number of Reports") +
      theme_bw()
    ggplotly(hist)
  })
  
  #### Data about Drugs
  drugDataSelection <- reactive({
    n_ids <- selected_ids$ids %>% nrow()
    if (nrow(selected_ids$ids) > 0)
    {
      data <- semi_join(cv_report_drug, selected_ids$ids, by = "REPORT_ID", copy = T)
      #%>%       left_join(cv_report_drug_indication, by = c("REPORT_DRUG_ID", "REPORT_ID", "DRUG_PRODUCT_ID", "DRUGNAME"))
    }
    else
    {
      data <- NULL
      data <- cv_report_drug
      current_search$name = ""
      current_search$rxn = ""
    }
    
    data
  })
  
  ### indication ###
  indication_data <- reactive({
    # Data frame used to obtain Top_25_indication bar chart: Indication is only associated with individual drug
    # When brand name is unspecified, chart shows top 25 indications associated with all drugs + date_range
    # When brand name is specified, chart shows top 25 indications associated with specified drug + date_range
    
    
    # NOTE ABOUT INDICATIONS STRUCTURE:
    # REPORT_ID -> multiple drugs per report
    # DRUG_ID -> multiple reports may use the same drugs
    # REPORT_DRUG_ID -> unique for each drug/report combination. count is less than total reports since drugs can have multiple indications
    # so distinct REPORT_DRUG_ID x INDICATION_NAME_ENG includes the entire set of reports
    data <- drugDataSelection() %>%
      count(INDICATION_NAME_ENG) %>%
      arrange(desc(n)) %>%
      as.data.frame() %>%
      filter(!is.na(INDICATION_NAME_ENG)) %>%
      head(25)
    if (nrow(data) == 0)
    {
      data <- data.frame(INDICATION_NAME_ENG = "None", n = 0)
    }
    data
  })
  
  output$indicationchart <- renderGvis({
    x = "INDICATION_NAME_ENG"
    y = "n"
    gvisBarChart_HCSC(as.data.frame(indication_data()),x,y,color = google_colors[1])
  })
  
  output$indicationtable    <- renderGvis({
    gvisTable(as.data.frame(indication_data()))
  })

  # output$indication_plot <- renderGvis({
  #   gvisBarChart_HCSC(indication_data(), "INDICATION_NAME_ENG", "n", google_colors[1])
  # })
  # output$indication_plot.table <- renderGvis({
  #   gvisTable(indication_data())
  # })
  # output$indication_plot.sus <- renderGvis({
  #   gvisBarChart_HCSC(indication_data(), "INDICATION_NAME_ENG", "n", google_colors[1])
  # })
  # output$indication_plot.table.sus <- renderGvis({
  #   gvisTable(indication_data())
  # })
  # output$indication_plot.con <- renderGvis({
  #   gvisBarChart_HCSC(indication_data(), "INDICATION_NAME_ENG", "n", google_colors[1])
  # })
  # output$indication_plot.table.con <- renderGvis({
  #   gvisTable(indication_data())
  # })
  
  all_data <- reactive({
    data <- drugDataSelection() %>%
      distinct(REPORT_ID, DRUGNAME) %>%
      count(DRUGNAME) %>%
      arrange(desc(n)) %>%
      head(25) %>%
      as.data.frame()
    data
  })
  
  output$alldrugchart <- renderGvis({
    x = "DRUGNAME"
    y = "n"
    gvisBarChart_HCSC(as.data.frame(all_data()),x,y,color = google_colors[2])
  })
  
  output$alldrugtable    <- renderGvis({
    gvisTable(as.data.frame(all_data()))
  })
  
  # output$drug_all <- renderUI({
  #   data <- all_data()
  #   
  #   switch(input$all_select,
  #          "barchart" = gvisBarChart_HCSC(data, "DRUGNAME", "n", google_colors[2]),
  #          "table" = gvisTable(data))
  # })
  
  ### suspected drug ###
  suspect_data <- reactive({
    data <- drugDataSelection() %>%
      filter(DRUGINVOLV_ENG == "Suspect") %>%
      dplyr::distinct(REPORT_ID, DRUGNAME) %>%
      count(DRUGNAME) %>%
      arrange(desc(n)) %>%
      head(25) %>%
      as.data.frame()
    if (nrow(data) == 0)
    {
      data <- data.frame(DRUGNAME = 'None', n = 0)
    }
    data
  })
  
  output$suspecteddrugchart <- renderGvis({
    # When generic, brand & reaction names are unspecified, count number of UNIQUE reports associated with each durg_name
    #    (some REPORT_ID maybe duplicated due to multiple REPORT_DRUG_ID & DRUG_PRODUCT_ID which means that patient has diff dosage/freq)
    # the top drugs reported here might be influenced by such drug is originally most reported among all reports
    gvisBarChart_HCSC(suspect_data(), "DRUGNAME", "n", google_colors[3])
  })
  
  output$suspecteddrugtable <- renderGvis({
    gvisTable(suspect_data())
  })
  
  ### concomitant drug ###
  concomitant_data <- reactive({
    data <- drugDataSelection() %>%
      filter(DRUGINVOLV_ENG == "Concomitant") %>%
      distinct(REPORT_ID, DRUGNAME) %>%
      count(DRUGNAME) %>%
      arrange(desc(n)) %>%
      head(25) %>%
      as.data.frame()
    if (nrow(data) == 0)
    {
      data <- data.frame(DRUGNAME = 'None', n = 0)
    }
    data
  })
  
  output$concomitantdrugchart <- renderGvis({
    # When generic, brand & reaction names are unspecified, count number of UNIQUE reports associated with each durg_name
    #    (some REPORT_ID maybe duplicated due to multiple REPORT_DRUG_ID & DRUG_PRODUCT_ID which means that patient has diff dosage/freq)
    # the top drugs reported here might be influenced by such drug is originally most reported among all reports
    gvisBarChart_HCSC(concomitant_data(), "DRUGNAME", "n", google_colors[4])
  })
  
  output$concomitantdrugtable <- renderGvis({
    data <- concomitant_data()
    gvisTable(data)
  })
  
  output$drugcounttitle <- renderUI({
    excluded_count <- drugDataSelection() %>%
      count(REPORT_ID) %>%
      filter(n > 20) %>%
      count() %>% as.data.frame() %>% `$`('nn')
    HTML(paste0("<h3>Number of Drugs per Report ",
                tipify(
                  el = icon("info-circle"), trigger = "hover click",
                  title = paste0(
                    "This plot indicates the number of drugs (e.g. suspect, concomitant, past, treatment, etc) included in each report. ",
                    "The search query filters unique reports, which may have one or more drugs associated with them.")),
                "<br>(", excluded_count, " reports with more than 20 drugs excluded)", "</h3>"))
  })
  
  drugcount_data <- reactive({
    data <- drugDataSelection() %>%
      count(REPORT_ID) %>%
      filter(n <= 20) %>%
      group_by(n) %>%
      count() %>%
      arrange(n) %>%
      as.data.frame() %>%
      mutate(`Number of Drugs` = as.factor(n),
             `Number of Drugs in Report` = nn) %>%
      select(-c(n,nn))
  })
  
  output$drugcount_plot <- renderGvis({
    # the top drugs reported here might be influenced by such drug is originally most reported among all reports
    gvisColumnChart(drugcount_data(), 'Number of Drugs', "Number of Drugs in Report", options = list(
      legend = "{ position: 'none' }",
      height = 600,
      vAxis = "{title: 'Number of Reports'}",
      hAxis = "{title: 'Number of Drugs in Report'}",
      chartArea = "{top: 20, height: '75%', left: 80, width: '90%'}")
    )
  })
  
  
  #### Data about Reactions
  
  rxnDataSelection <- reactive({
    n_ids <- selected_ids$ids %>% nrow()
    if (nrow(selected_ids$ids) > 0)
    {
      data <- cv_reactions %>% semi_join(selected_ids$ids, by = "REPORT_ID", copy = T) 
    }
    else
    {
      data <- NULL
      data <- cv_reactions
      current_search$name = ""
      current_search$rxn = ""
    }
    
    data
  })
  
  ### toppt ###
  top_pt_data <- reactive({
    data <- rxnDataSelection() %>%
      count(PT_NAME_ENG) %>%
      arrange(desc(n)) %>%
      head(15) %>%
      as.data.frame()
    data
  })
  
  output$topptchart <- renderGvis({
    x = "PT_NAME_ENG"
    y = "n"
    gvisBarChart_HCSC(as.data.frame(top_pt_data()),x,y,color = google_colors[1])
  })
  
  output$toppttable    <- renderGvis({
    gvisTable(as.data.frame(top_pt_data()))
  })
  
  ### tophlt ###
  top_hlt_data <- reactive({
    data <- rxnDataSelection() %>%
      filter(!is.na(HLT_Term)) %>%
      count(HLT_Term) %>%
      arrange(desc(n)) %>%
      head(15) %>%
      as.data.frame()
    data
  })
  
  output$tophltchart <- renderGvis({
    x = "HLT_Term"
    y = "n"
    gvisBarChart_HCSC(as.data.frame(top_hlt_data()),x,y,color = google_colors[2])
  })
  
  output$tophlttable    <- renderGvis({
    gvisTable(as.data.frame(top_hlt_data()))
  })
  
  ### outcome plot ###
  outcomeplot_data <- reactive({
    mainDataSelection() %>%
      count(OUTCOME_ENG) %>%
      as.data.frame()
  })
  output$outcomechart <- renderGvis({
    x = "OUTCOME_ENG"
    y = "n"
    gvisPieChart_HCSC(as.data.frame(outcomeplot_data()),x,y)
  })
  
  output$outcometable    <- renderGvis({
    gvisTable(as.data.frame(outcomeplot_data()))
  })
  
  
  ############# Download Tab
  output$download_reports <- downloadHandler(
    filename = function() {
      current_rxn <- paste0(current_search$rxn, collapse = "+")
      if (current_rxn == "") current_rxn <- "all"
      current_drug <- paste0(current_search$name, collapse = "+")
      if (current_drug == "") current_drug <- "all"
      current_drug <- gsub(" ", "_", current_drug)
      paste0(cv_download_reports()$data_type, '_', current_drug, '_', current_rxn, '.csv')
    },
    content = function(file){
      write.csv(cv_download_reports()$reports_tab_master,
                file,
                fileEncoding = "UTF-8",
                row.names = FALSE)
    }
  )
  
}
)