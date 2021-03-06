#_______________________________________________________________________________
read_wq_pars <- function(cf, writeCsv = TRUE) { 
  
  # Synopsis ----
  # Reads control file and populates control object passed to other functions
  
  # READ IN WQ CONTROL FILE VARIABLES 
  v <- readLines(cf)
  
  # Process out comment lines and blank lines:
  v <- v[-grep('#{3}', v)]
  
  v <- v[lapply(v, length) > 0]
  
  v <- strsplit(v, ',')
  
  # Name element (from first item in element)
  for (i in 1 : length(v)) {
    names(v)[i] = v[[i]][1]; v[[i]] <- v[[i]][2 : length(v[[i]])]
  }
  
  # Coerce to numeric if applicable
  for (el in which(names(v) == 'SURO') : length(v)) {v[[el]] <- as.numeric(v[[el]])}
  
  v[['add_ts']] <- as.numeric(v[['add_ts']])

  # Create the emcdwc file for output
  v$emcFil <- paste0('D:/siletz/emcdwc_', v$pars, '.csv')
  
  # Overwrite Harmonic parameters ----
  if (v$ovwr == 1) {
    
    # Read and process the ambient water quality data file
    wqDF <- read.csv(paste0(v$wqDir, '/', v$pars, '_', v$stns, '.csv'),
                     stringsAsFactors = F)
    
    wqDF <- wqDF[, c(1, 2)]
    
    wqDF$Date <- as.Date(wqDF$Date, '%Y-%m-%d')
    
    # Calculate the seasonal harmonic concentration coefficients
    fit <- seasonal_wq_conc(wqDF = wqDF, par = v$pars, lo = v$lo, hi = v$hi,
                            ts = 'none')
    
    # Calculate interflow components
    v$IFWC = fit$f90[1] * v$IFM # Base Interflow concentration
    v$IFW1 = fit$f90[2]; v$IFW2 = fit$f90[3]; v$IFW3 = fit$f90[4] # Remaining
    v$IFW4 = fit$f90[5]; v$IFW5 = fit$f90[6]; v$IFW6 = fit$f90[7] # Harmonics
    
    # Calculate groundwater components
    v$AGWC = fit$f10[1] * v$GWM # Base GW concentration
    v$AGW1 = fit$f10[2]; v$AGW2 = fit$f10[3]; v$AGW3 = fit$f10[4] # Remaining
    v$AGW4 = fit$f10[5]; v$AGW5 = fit$f10[6]; v$AGW6 = fit$f10[7] # Harmonics
    
  }
  
  if (writeCsv) {
    
    # Write wq parameters & seasonality to .csv ----
    df <- write_wq_2_csv(pars = v$pars, tmat = v$tmat, SURO = v$SURO,
                         IFWC = v$IFWC, IFW1 = v$IFW1, IFW2 = v$IFW2,
                         IFW3 = v$IFW3, IFW4 = v$IFW4, IFW5 = v$IFW5,
                         IFW6 = v$IFW6, AGWC = v$AGWC, AGW1 = v$AGW1,
                         AGW2 = v$AGW2, AGW3 = v$AGW3, AGW4 = v$AGW4,
                         AGW5 = v$AGW5, AGW6 = v$AGW6)
    
  }
  
  return(v)
  
}

#_______________________________________________________________________________
write_wq_2_csv <- function(pars = NULL,  tmat = 1.000, SURO = 1.5, IFWC = 0,
                           IFW1 = 0, IFW2 = 0, IFW3 = 0, IFW4 = 0, IFW5 = 0,
                           IFW6 = 0, AGWC = 0, AGW1 = 0, AGW2 = 0, AGW3 = 0,
                           AGW4 = 0, AGW5 = 0, AGW6 = 0) {
  
  # Synopsis ----
  
  
  # Read the counter from file to get the run number ----
  countFil = file('D:/siletz/wqct.txt')
  
  n = as.numeric(readLines(countFil)) - 1
  
  close(countFil)
  
  # Create the data frame of WQ parameters ----
  df <- data.frame(HRU = c('FOR', 'DEV', 'GRS', 'CUL', 'IMPRV'),
                   SURO = c(rep(SURO, 5)),
                   IFWC = c(rep(IFWC, 5)),
                   IFW1 = c(rep(IFW1, 5)), IFW2 = c(rep(IFW2, 5)),  # 1st term
                   IFW3 = c(rep(IFW3, 5)), IFW4 = c(rep(IFW4, 5)),  # 2nd term
                   IFW5 = c(rep(IFW5, 5)), IFW6 = c(rep(IFW6, 5)),  # 3rd term
                   AGWC = c(rep(AGWC, 5)),
                   AGW1 = c(rep(AGW1, 5)), AGW2 = c(rep(AGW2, 5)),  # 1st term
                   AGW3 = c(rep(AGW3, 5)), AGW4 = c(rep(AGW4, 5)),  # 2nd term
                   AGW5 = c(rep(AGW5, 5)), AGW6 = c(rep(AGW6, 5)))  # 3rd term
  
  # Adjust parameters if specified ----
  if (length(tmat) != 1) {
    
    for (i in 1 : (nrow(df) - 1)) {
      
      df[i + 1, c(2, 3, 10)] <- tmat[i] * df[i + 1, c(2, 3, 10)]
      
    }
  }
  
  # Rename and move old WQ parm file to \calib ----
  base <- 'D:/siletz/'
  
  fils <- c(paste0(base, c(paste0('emcdwc_', pars, '.csv'),
                           paste0('emcdwc_', pars, '_', n, '.csv'),
                           paste0('calib/parms/wq/emcdwc_', pars, '_', n, '.csv'))))
  
  file.rename(fils[1], fils[2]) # RENAME
  
  file.rename(fils[2], fils[3]) # MOVE
  
  # Write new parameters to .csv ----
  write.csv(df, paste0('D:/siletz/emcdwc_', pars, '.csv'), row.names = F,
            quote = F)
  
  return(df)
  
}

#_______________________________________________________________________________
run_wq <- function(v = NULL) {
  
# run_wq <- function(strD = NULL, endD = NULL, wqDir = NULL, emcFil = NULL,
#                    basFil = NULL) {
  
  # This function is the over-arching call to run the water quality process. Its 
  # main purpose is to parse the Q and WQ data into years and run those
  # individually # to improve processing speed (proc time increase exponentially
  # as number of years increases). 
  
  # Libraries, scripts and options ----
  options(stringsAsFactors = FALSE)
  suppressMessages(library('lubridate'))
  suppressMessages(library('dplyr'))

  # Create a data frame of date iterations
  yrs <- year(v$strD) : year(v$endD)
  
  if (length(yrs) == 1) {
    
    dts <- data.frame(as.POSIXct(strD, '%Y-%m-%d', tz = 'America/Los_Angeles'),
                      as.POSIXct(endD, '%Y-%m-%d', tz = 'America/Los_Angeles'))
    
  } else {
    
    intDts <- paste0(yrs[2 : length(yrs)], '-01-01')
    
    dts <- data.frame(as.POSIXct(c(v$strD, intDts), '%Y-%m-%d',
                                 tz = 'America/Los_Angeles'),
                      as.POSIXct(c(intDts, v$endD), '%Y-%m-%d',
                                 tz = 'America/Los_Angeles'))
    
  }
  
  if (dts[nrow(dts), 1] == dts[nrow(dts), 2]) {dts <- dts[-nrow(dts), ]}
  
  # Initialize the restart (must be NA or proc_emcdwc will crash)
  restart <- NA
  
  qlcTmp <- list()
  
  tTime <- 0
  
  for (n in 1 : nrow(dts)) {
    
    a <- as.numeric(Sys.time())
    
    # Run the proc_emcdwc with calculates reach loads and concentrations
    qlcTmp <- proc_wq(restart = restart, strD = dts[n, 1], endD = dts[n, 2],
                      v = v)
    
    # qlcTmp <- proc_wq(restart = restart, strD = dts[n, 1], endD = dts[n, 2],
    #                   wqDir = wqDir, emcFil = emcFil, basFil = basFil)
    
    # Restart = list of last line of previous iteration of values for each item
    # In the case of RAT & ROS, only last line was passed back into run_wq()
    restart <- list(ldsRst = qlcTmp[[2]][nrow(qlcTmp[[2]]), ],
                    conRst = qlcTmp[[3]][nrow(qlcTmp[[3]]), ],
                    roCRst = qlcTmp[[4]][nrow(qlcTmp[[4]]), ],
                    RATRst = qlcTmp[[5]], ROSRst = qlcTmp[[6]])
    
    # Set the first instance of the output list if n = 1
    if (n == 1) {qlcOut <- qlcTmp} else { 
      
      for (o in 1 : 4) {# Ignore the RAT and ROS restarts
        
        qlcOut[[o]] <- rbind(qlcOut[[o]][-nrow(qlcOut[[o]]), ], qlcTmp[[o]])
        
      }
    }
    
    pTime <- round((as.numeric(Sys.time() - a)) / 60, 2) # time in minutes
    
    tTime <- tTime + pTime
    
    cat(paste0('Year: ', yrs[n], " processed in ", pTime, ' minutes\n'))
    
  }
  
  qlcOut[[5]] <- qlcOut[[6]] <- NULL
  
  cat(paste0('Total processing time: ', tTime, ' minutes\n'))
  
  return(qlcOut)
  
}

#_______________________________________________________________________________
proc_wq <- function(restart = NULL, strD = NULL, endD = NULL, v = NULL) {
  
# proc_wq <- function(restart = NULL, strD = NULL, endD = NULL, wqDir = NULL,
#                     emcFil = NULL, basFil = NULL) {
  
  # Synopsis ----
  # This function takes lateral flows, specified concentrations or seasonal
  # concentrations (emc/dwc) and calculates lateral loads and concentrations based
  # on partitioned runoff components (i.e., surface, interflow, GW). It then uses
  # specified routing information, and flow routing data (reach flows) to route
  # loads and concentrations to downstream reaches, accepting upstream flows and
  # loads and lateral flows/loads/concentrations, and calculating downstream loads
  # and concentrations.
  
  # Libraries, scripts and options ----
  options(stringsAsFactors = FALSE)
  
  suppressMessages(library('dplyr'))
  
  sapply(paste0('C:/Users/rshojin/Desktop/006_scripts/github/hydroRMS/R/',
                c('hydro_year.R', 'day_of_hydro_year.R')), source)
  
  # Load and process lateral inflow data ----
  # qOut <- proc_flow_4_wq(wqDir) Not needed -> current qOut = whole hydro period
  qOut <- readRDS('D:/siletz/calib/wq/qOut.RData')
  
  # Reduce from qOut to lateral loads of specified dates 
  qLat <- reduce_qlc(strDte = strD, endDte = endD, df2Red = qOut[["qLat"]])
  
  # Pre-proces emcdwc table
  nmVec <- names(qOut[['qLat']])
  
  # SIB = Surface, interflow, baseflow runoff concentration parameters
  sib <- preproc_wq(nmVec = nmVec, emcFil = v$emcFil)
  
  lLat <- qLat # Initialize the df
  
  # Extract column indeces of SURO, IFWO and AGWO
  ind <- list(SURO = which(sib$ROC == 'SURO'), IFWO = which(sib$ROC == 'IFWO'),
              AGWO = which(sib$ROC == 'AGWO'))
  
  # Create a dataframe to calculate seasonality (periodicity) of the time series
  it <- data.frame(Date = lLat$Date)
  
  it <- it %>%
        mutate(hyr = hydro_year(Date), doy = day_of_hydro_year(Date)) %>%
        mutate(dys = ifelse((hyr %% 4) == 0, 366, 365), yr = hyr - hyr[1]) %>%
        mutate(p = yr + (doy + sib[2, length(sib)]) / dys)
  
  # ****************************************************************************
  # Calculate lateral loads ----
  # Catchment Inflows - calculates from all three RO components (SURO, IFWO & AGWO)
  for (i in 1 : 3) {
    
    if(names(ind)[i] == 'SURO') {
      
      # Calculate loads from surface rounoff
      for (j in ind[[i]]) {lLat[, j] <- qLat[, j] * sib[j, 'SURO'] * 3.6}
      
    } else {
      
      for (j in ind[[i]]) {
        
        # Select columns for seasonal variation function coefficients
        if (i == 2) {k <- 6 : 12} else {k <- 13 : 19}
        
        # Calculate the concentration for each HRU and baseQ/itfwQ component
        itCnc <- sib[j, k[1]] +
                 sib[j, k[2]] * sin(2*pi*it$p) + sib[j, k[3]] * cos(2*pi*it$p) + 
                 sib[j, k[4]] * sin(4*pi*it$p) + sib[j, k[5]] * cos(4*pi*it$p) + 
                 sib[j, k[6]] * sin(6*pi*it$p) + sib[j, k[7]] * cos(6*pi*it$p)
            
        # Break if any concentrations is less than 0
        if (length(which(itCnc < 0)) != 0) {
          
          print(paste0('Warning: negative concentrations in ', names(qLat)[j]))
          
        }
        
        # Apply to lateral flows
        lLat[, j] <- qLat[, j] * itCnc * 3.6
        
      }
    }
  }
  
  # ****************************************************************************
  if (v$mod_loads == 1) {
    
    x <- as.numeric(unique(sib$BAS[2 : length(sib$BAS)]))
    
    v$modB <- v$modB[order(x)]; v$modL <- v$modL[order(x)]
    
    # Process lateral Q&L ----
    # Modified loads (Red alder community multpliers)
    for (i in 1 : length(v$modB)) {
      
      # Modify for specific basins, only for forested and AGWO & IFWO
      cond <- which(sib$BAS == v$modB[i] &
                   (sib$HRU == 'FORHI' | sib$HRU == 'FORLO') &
                    sib$ROC != 'SURO')
      
      lLat[, cond] <- lLat[, cond] * v$modL[i]
      
    }
  }
  
  # Separate out flows, loads and concentrations
  qlcLat <- proc_qlc(emc = sib, parV = 'BAS', qLat, lLat) # Basin aggregate

  latL <- qlcLat[['load']]
  
  # ****************************************************************************
  # Added loads (OSSF or animal unit (livestock) feces) -- for scalar loads only
  if (v$add_loads == 1) { 
    
    basn <- paste0('Bas', v$addB)
    
    for (i in 1 : length(v$addB)) {latL[[basn[i]]] <- latL[[basn[i]]] + v$addL[i]}
    
  }
  
  # ****************************************************************************
  # Added time series loads (e.g., STP)
  if (v$add_ts == 1) {

    # Read in time series file; specify file time step: c('hour', 'day', 'month')
    tsLd <- read_ts_loads(tFil = v$tsFil, ts = v$tStep, strD = strD, endD = endD)
    
    # Extract the basins for time series load inputs
    basn <- as.numeric(gsub('BAS', '', names(tsLd)))

    for (i in 1 : length(basn)) {
      
      indx <- which(names(tsLd) == paste0('BAS', basn[i]))
      
      latL[[basn[i]]] <- latL[[basn[i]]] + tsLd[[indx]]$basn
      
    }
  }

  # ****************************************************************************
  # Output lateral flows and loads -- for general testing only
  # saveRDS(qlcLat[['load']], paste0('D:/siletz/calib/wq/latQLC_', v$pars,'.RData'))
  
  # ****************************************************************************
  # Pre-process reach flows & loads for reach processing ----
  qRch <- reduce_qlc(strDte = strD, endDte = endD, df2Red = qOut[['qRch']])
  
  # Storage volume in the reach at the start of thwe timestep 
  rchV <- qRch[, c(1, ((length(qRch) - 1) / 2 + 2) : length(qRch))] # Reach Vol 
  
  # Reach outflow (cubic meters per second)
  rchQ <- qRch[, 1 : ((length(qRch) - 1) / 2 + 1)] # Reach outflow
  
  # Reorder because HSPF puts them in a funny order
  nOrd <- unique(sib$BAS)
  
  # Initialize data frame for zeroed-out DFs
  # Reach outflow loads
  rchL <- initialize_QLC_df(nOrd = nOrd, modDF = rchV, zero = TRUE)

  rchQ <- initialize_QLC_df(nOrd = nOrd, modDF = rchQ, zero = FALSE)
  
  rchV <- initialize_QLC_df(nOrd = nOrd, modDF = rchV, zero = FALSE)

  # Basin lateral loads  
  latL <- initialize_QLC_df(nOrd = nOrd, modDF = latL, zero = FALSE)
  
  RAT <- JS <- COJS <- IMAT <- rchC <- rchS <- rchE <- rchO <- rchN <- rchL
  
  # Restart for rchC and rchL ----
  if (length(restart) > 1) {
    
    rchL[1, ] <- restart[['ldsRst']]; rchC[1, ] <- restart[['conRst']]
    
    rchN[1, ] <- restart[['roCRst']]; RAT[1, ] <- restart[['RATRst']]
    
    rchS[1, ] <- restart[['ROSRst']]

  }
  
  # ****************************************************************************
  # ADCALC SUBROUTINES ----
  # Process reach flows and volume; convert volumes from Mm3 to m3
  rchO[, 2 : length(rchQ)] <- rchQ[, 2 : length(rchQ)] * 3600 # Rch Out Vol (m3)
  
  # Need to set zero outflow volume to 1 (causes NaN otherwise)
  rchV[, 2 : length(rchV)] <- rchV[, 2 : length(rchV)] * 10^6 # Rch Vol (m3)

  # Calculate the adcalc variables
  for (s in 2 : length(RAT)) {

    rchO[, s] <- ifelse(rchO[, s] == 0, 1, rchO[, s])
    
    # RAT is the ratio of reach volume @ ivl start to reach outflow volume @ ivl
    RAT[2 : nrow(RAT), s] <- rchV[1 : (nrow(rchV) - 1), s] / 
                             rchO[1 : (nrow(rchO) - 1), s]  

    # Calculate JS and COJS; CRRAT defined as 1.5 as per default in HSPF
    # JS = RAT / CRRAT if less than 1, and 1 if greater than 1

    # RCH      *1*   2    3   *4*  *5*       6 : 16    17
    CRRAT <- c(2.0, 1.5, 1.5, 2.3, 2.1, rep(1.5, 11), 1.7)
    
    JS[, s] <- RAT[, s] / CRRAT[s - 1]
    
    JS[, s] <- ifelse(JS[, s] > 1, 1, JS[, s])
    
    COJS[, s] <- 1 - JS[, s]
    
    # Calculate Reach Outflow Volumes at start (S) and end (E) of timestep
    rchS[2 : nrow(rchS), s] <- JS[2 : nrow(rchS), s] *
                               rchQ[1 : (nrow(rchV) - 1), s] * 3600
    
    rchE[, s] <- COJS[, s] * rchQ[, s] * 3600

  }

  # ****************************************************************************
  # Import reach processing information ----
  lnks <- proc_network_linkage(v$basFil)
  
  # Calculate reach outflow loads and concentrations ----
  for (i in 2 : length(latL)) {
    
    bsn <- lnks[['pOrd']][i - 1, 2] # Retrieve the basin for processing
    
    bcl <- bsn + 1 # Processs basin column
    
    usb <- lnks[['cBas']][[bsn]] # Upstream basin(s)
    
    if (usb[1] != 0) {ucl <- usb + 1} else {ucl <- 0} # Upstream basin columns
    
    # Basin instance (vector) of mass inflows - LATERAL
    IMAT[, bcl] <- latL[, bcl]
    
    # Basin instance (vector) of mass inflows - LATERAL + UPSTREAM REACH(ES)
    if (usb[1] != 0) {
      
      for (k in 1 : length(usb)) IMAT[, bcl] = IMAT[, bcl] + rchL[, ucl[k]]
      
    }
    
    for (j1 in 2 : nrow(rchQ)) {
      
      j0 = j1 - 1 # Previous time step
      
      # PAR     PAR           O CONV    UNIT1   UNIT2  DESC
      xIMAT   = IMAT[j1, bcl]         # kg   -> kg     Inflow mass
      xCONCS  = rchC[j0, bcl] * 10^-3 # mg/L -> kg/m3  Concentration at ts start
      xVOLS   = rchV[j0, bcl]         # m3   -> m3     Reach Vol at ts start
      xSROVOL = rchS[j0, bcl]         # m3   -> m3     Reach outflow V at ts str
      xVOL    = rchV[j1, bcl]         # m3   -> m3     Reach vol at ts end
      xEROVOL = rchE[j1, bcl]         # m3   -> m3     Reach outflow V at ts end
      
      # Reach outflow concentration_____________________________________________
      # CONC = [IMAT + CONCS * (VOLS - SROVOL)] / (VOL + EROVOL); mg/L
      xCONC <- 10^3 * (xIMAT + xCONCS * (xVOLS - xSROVOL)) / (xVOL + xEROVOL)

      # First-order decay (mass loss - NOT CORRECTED FOR TEMP)__________________
      # DDQALT = DQAL * (1.0 - EXP(-KTOTD)) * VOL = loss of qual from decay
      # Volume not factored because using outflow concentration as 'mass' term
      xCONC <- xCONC * exp(-v$kGen / 24)
      
      # Reach outflow load______________________________________________________
      # ROMAT = SROVOL * CONCS + EROVOL * CONC
      xROMAT <- xSROVOL * xCONCS + xEROVOL * xCONC * 10^-3 # in kg
      
      # Assign reach concentration and load to the time-series data frame_______
      # Reach concentration
      rchC[j1, bcl] <- xCONC
      
      # Reach outflow loads
      rchL[j1, bcl] <- xROMAT

    } # j1 loops through the rows of the DFs
    
    # Warn if negative reach loads calculated; if so need to adjust CRRAT
    if (any(rchL[, bcl] < 0)) {
      
      print(paste0('Warning: negative concentrations in Reach ', bsn))

    }
    
    # Reach outflow concentration
    rchN[, bcl] <- rchL[, bcl] / (rchQ[, bcl] * 3.6)

  }   # i  loops through the basin lateral loads (n = number of basins)
  
  # ****************************************************************************
  # OPTIONAL: Outputs are for checking the model performance ----
  # dir <- 'D:/siletz/scripts/R/wVar/'
  # write.csv(rchL, paste0(dir, 'rchL.csv'), row.names = F)
  # write.csv(rchC, paste0(dir, 'rchC.csv'), row.names = F)
  # write.csv(rchN, paste0(dir, 'rchN.csv'), row.names = F)
  # write.csv(IMAT, paste0(dir, 'IMAT.csv'), row.names = F)
  # write.csv(RAT, paste0(dir, 'RAT.csv'), row.names = F)
  # write.csv(rchS, paste0(dir, 'rchS.csv'), row.names = F)
  # write.csv(rchE, paste0(dir, 'rchE.csv'), row.names = F)
  # write.csv(rchO, paste0(dir, 'rchO.csv'), row.names = F)
  # write.csv(rchV, paste0(dir, 'rchV.csv'), row.names = F)
  # write.csv(rchQ, paste0(dir, 'rchQ.csv'), row.names = F)
  # These outputs are for checking the model performance
  
  # ****************************************************************************
  # Prep outputs ----
  # Return a list of DFs with flows, loads and concentrations from each reach
  qlcOut <- list(reach_flows = rchQ,          # 1
                 reach_loads = rchL,          # 2
                 reach_conc = rchC,           # 3
                 rOut_conc = rchN,            # 4
                 RATRst = RAT[nrow(RAT), ],   # 5
                 ROSRst = rchS[nrow(rchS), ]) # 6

  return(qlcOut)
  
}

#_______________________________________________________________________________
initialize_QLC_df <- function(nOrd, modDF, zero = FALSE) {
  
  # Synopsis ----
  
  
  # Pass a vector of the basins in model order and the DF to model on
  nOrd <- data.frame(BAS = as.numeric(nOrd[-1]))
  
  nOrd$ord <- as.numeric(row.names(nOrd)) + 1
  
  nOrd <- nOrd[order(nOrd$BAS), ]
  
  modDF <- modDF[, c(1, nOrd$ord)]
  
  names(modDF) <- c('Date', paste0('Bas', 1 : (length(modDF) - 1)))
  
  retDF <- modDF
  
  if (zero) {retDF[, 2 : length(modDF)] <- 0}
  
  # Return a DF with same dimensions and correct column order
  return(retDF)
  
}

#_______________________________________________________________________________
proc_wq_latQLC <- function(v = NULL) {

  # Synopsis ----
  # This function takes is identical to proc_wq up to the calculation of lateral
  # flows, concentrations and loads. It does not produce reach values.

  # Libraries, scripts and options ----
  options(stringsAsFactors = FALSE)

  suppressMessages(library('dplyr'))

  sapply(paste0('C:/Users/rshojin/Desktop/006_scripts/github/hydroRMS/R/',
                c('hydro_year.R', 'day_of_hydro_year.R')), source)

  # Load and process data ----
  qOut <- readRDS('D:/siletz/calib/wq/qOut.RData')

  # Reduce from qOut to lateral loads of specified dates
  qLat <- reduce_qlc(strDte = v$strD, endDte = v$endD, df2Red = qOut[["qLat"]])

  # Pre-proces emcdwc table
  nmVec <- names(qOut[['qLat']])

  # SIB = Surface, interflow, baseflow runoff concentration parameters
  sib <- preproc_wq(nmVec = nmVec, emcFil = v$emcFil)

  lLat <- qLat # Initialize the df

  # Extract column indeces of SURO, IFWO and AGWO
  ind <- list(SURO = which(sib$ROC == 'SURO'), IFWO = which(sib$ROC == 'IFWO'),
              AGWO = which(sib$ROC == 'AGWO'))

  # Create a dataframe to calculate seasonality (periodicity) of the time series
  it <- data.frame(Date = lLat$Date)

  it <- it %>%
        mutate(hyr = hydro_year(Date), doy = day_of_hydro_year(Date)) %>%
        mutate(dys = ifelse((hyr %% 4) == 0, 366, 365), yr = hyr - hyr[1]) %>%
        mutate(p = yr + (doy + sib[2, length(sib)]) / dys)

  # ****************************************************************************
  # Calculate lateral loads ----
  # Catchment Inflows - calculates from all three RO components (SURO, IFWO & AGWO)
  for (i in 1 : 3) {

    if(names(ind)[i] == 'SURO') {

      # Calculate loads from surface rounoff
      for (j in ind[[i]]) {lLat[, j] <- qLat[, j] * sib[j, 'SURO'] * 3.6}

    } else {

      for (j in ind[[i]]) {

        # Select columns for seasonal variation function coefficients
        if (i == 2) {k <- 6 : 12} else {k <- 13 : 19}

        # Calculate the concentration for each HRU and baseQ/itfwQ component
        itCnc <- sib[j, k[1]] +
                 sib[j, k[2]] * sin(2*pi*it$p) + sib[j, k[3]] * cos(2*pi*it$p) +
                 sib[j, k[4]] * sin(4*pi*it$p) + sib[j, k[5]] * cos(4*pi*it$p) +
                 sib[j, k[6]] * sin(6*pi*it$p) + sib[j, k[7]] * cos(6*pi*it$p)

        # Break if any concentrations is less than 0
        if (length(which(itCnc < 0)) != 0) {

          print(paste0('Warning: negative concentrations in ', names(qLat)[j]))

        }

        # Apply to lateral flows
        lLat[, j] <- qLat[, j] * itCnc * 3.6

      }
    }
  }

  # ****************************************************************************
  # Modify forest loads for red alder stands
  if (v$mod_loads == 1) {

    x <- as.numeric(unique(sib$BAS[2 : length(sib$BAS)]))

    v$modB <- v$modB[order(x)]; v$modL <- v$modL[order(x)]

    # Process lateral Q&L ----
    # Modified loads (Red alder community multpliers)
    for (i in 1 : length(v$modB)) {

      # Modify for specific basins, only for forested and AGWO & IFWO
      cond <- which(sib$BAS == v$modB[i] &
                    (sib$HRU == 'FORHI' | sib$HRU == 'FORLO') &
                    sib$ROC != 'SURO')

      lLat[, cond] <- lLat[, cond] * v$modL[i]

    }
  }

  # Separate out flows, loads and concentrations
  qlcLat <- proc_qlc(emc = sib, parV = 'BAS', qLat, lLat) # Basin aggregate

  latL <- qlcLat[['load']]; latC <- qlcLat[['conc']]; latQ <- qlcLat[['flow']]

  # ****************************************************************************
  # Added loads (OSSF or animal unit (livestock) feces); use Qual-2Kw for NPDES
  if (v$add_loads == 1) {

    basn <- paste0('Bas', v$addB)

    for (i in 1 : length(v$addB)) {
      latL[[basn[i]]] <- latL[[basn[i]]] + v$addL[i]
    }
  }
  
  # ****************************************************************************
  # Added time series loads (e.g., STP)
  v$strD <- as.POSIXct(v$strD, '%Y-%m-%d', tz = 'America/Los_Angeles')
  v$endD <- as.POSIXct(v$endD, '%Y-%m-%d', tz = 'America/Los_Angeles')
  
  if (v$add_ts == 1) {
    
    # Read in time series file; specify file time step: c('hour', 'day', 'month')
    tsLd <- read_ts_loads(tFil = v$tsFil, ts = v$tStep, strD = v$strD, endD = v$endD)
    
    # Extract the basins for time series load inputs
    basn <- as.numeric(gsub('BAS', '', names(tsLd)))
    
    for (i in 1 : length(basn)) {
      
      indx <- which(names(tsLd) == paste0('BAS', basn[i]))
      
      latL[[basn[i]]] <- latL[[basn[i]]] + tsLd[[indx]]$basn
      
    }
  }  
  # ****************************************************************************

  # Recalculate concentrations
  for (i in 2 : length(latL)) {latC[, i] <- latL[, i] / (latQ[, i] * 3.6)}
  
  latC[1, 2 : length(latL)] <- 0

  qlcLat[['load']] <- latL; qlcLat[['conc']] <- latC
  
  # Reorganize the columns
  nOrd <- unique(sib$BAS)

  for (k in 1 : 3) {
    qlcLat[[k]] <- initialize_QLC_df(nOrd = nOrd, modDF = qlcLat[[k]], zero = F)
  }

  # Output lateral flows and loads
  return(qlcLat)

}

#_______________________________________________________________________________
proc_wq_latQLC_by_HRU <- function(strD = NULL, endD = NULL, wqDir = NULL,
                                  emcFil = NULL) {
  
  # Synopsis ----
  # This function takes is identical to proc_wq up to the calculation of lateral
  # flows, concentrations and loads by HRU x basin. Does not produce reach values.
  
  # Libraries, scripts and options ----
  options(stringsAsFactors = FALSE)
  
  suppressMessages(library('dplyr'))
  
  sapply(paste0('C:/Users/rshojin/Desktop/006_scripts/github/hydroRMS/R/',
                c('hydro_year.R', 'day_of_hydro_year.R')), source)
  
  # Load and process data ----
  # qOut <- proc_flow_4_wq(wqDir) Not needed -> current qOut = whole hydro period
  qOut <- readRDS('D:/siletz/calib/wq/qOut.RData')
  
  # Reduce from qOut to lateral loads of specified dates
  qLat <- reduce_qlc(strDte = strD, endDte = endD, df2Red = qOut[["qLat"]])
  
  # Pre-proces emcdwc table
  nmVec <- names(qOut[['qLat']])
  
  # SIB = Surface, interflow, baseflow runoff concentration parameters
  sib <- preproc_wq(nmVec = nmVec, emcFil = emcFil)
  
  lLat <- qLat # Initialize the df
  
  # Extract column indeces of SURO, IFWO and AGWO
  ind <- list(SURO = which(sib$ROC == 'SURO'), IFWO = which(sib$ROC == 'IFWO'),
              AGWO = which(sib$ROC == 'AGWO'))
  
  # Create a dataframe to calculate seasonality (periodicity) of the time series
  it <- data.frame(Date = lLat$Date)
  
  it <- it %>%
        mutate(hyr = hydro_year(Date), doy = day_of_hydro_year(Date)) %>%
        mutate(dys = ifelse((hyr %% 4) == 0, 366, 365), yr = hyr - hyr[1]) %>%
        mutate(p = yr + (doy + sib[2, length(sib)]) / dys)

  # Calculate lateral loads ----
  # Catchment Inflows - calculates from all three RO components (SURO, IFWO & AGWO)
  for (i in 1 : 3) {
    
    if(names(ind)[i] == 'SURO') {
      
      # Calculate loads from surface rounoff
      for (j in ind[[i]]) {lLat[, j] <- qLat[, j] * sib[j, 'SURO'] * 3.6}
      
    } else {
      
      for (j in ind[[i]]) {
        
        # Select columns for seasonal variation function coefficients
        if (i == 2) {k <- 6 : 12} else {k <- 13 : 19}
        
        # Calculate the concentration for each HRU and baseQ/itfwQ component
        itCnc <- sib[j, k[1]] +
                 sib[j, k[2]] * sin(2*pi*it$p) + sib[j, k[3]] * cos(2*pi*it$p) +
                 sib[j, k[4]] * sin(4*pi*it$p) + sib[j, k[5]] * cos(4*pi*it$p) +
                 sib[j, k[6]] * sin(6*pi*it$p) + sib[j, k[7]] * cos(6*pi*it$p)
        
        # Break if any concentrations is less than 0
        if (length(which(itCnc < 0)) != 0) {
          
          print(paste0('Warning: negative concentrations in ', names(qLat)[j]))
          
        }
        
        # Apply to lateral flows
        lLat[, j] <- qLat[, j] * itCnc * 3.6
        
      }
    }
  }
  
  # Pull in the control file variables
  v <- read_wq_pars('D:/siletz/wq_confil.csv', writeCsv = FALSE)
  
  # Process modified loads if applicable
  if (v$mod_loads == 1) {
    
    x <- as.numeric(unique(sib$BAS[2 : length(sib$BAS)]))
    
    v$modB <- v$modB[order(x)]; v$modL <- v$modL[order(x)]
    
    # Process lateral Q&L ----
    # Modified loads (Red alder community multpliers)
    for (i in 1 : length(v$modB)) {
      
      # Modify for specific basins, only for forested and AGWO & IFWO
      cond <- which(sib$BAS == v$modB[i] &
                      (sib$HRU == 'FORHI' | sib$HRU == 'FORLO') &
                      sib$ROC != 'SURO')
      
      lLat[, cond] <- lLat[, cond] * v$modL[i]
      
    }
  }
  
  # Separate out flows, loads and concentrations
  qlcLat <- proc_qlc(emc = sib, parV = 'HRU', qLat, lLat) # Basin aggregate
  
  latL <- qlcLat[['load']]; latC <- qlcLat[['conc']]; latQ <- qlcLat[['flow']]
  
  # Added loads (OSSF or animal unit (livestock) feces); use Qual-2Kw for NPDES
  # Add loads post-process--first find where OSST on NLCD then add in.
  
  # Recalculate concentrations
  for (i in 1 : length(latL)) {
  
    for (j in 2 : length(latL[[i]])) {
      
      latC[[i]][, j] <- latL[[i]][, j] / (latQ[[i]][, j] * 3.6)

    }
  
    # Remove NaNs   
    latC[[i]][1, 2 : length(latL[[i]])] <- 0
    
  }

  qlcLat[['conc']] <- latC
  
  # Output lateral flows and loads
  return(qlcLat)
  
}