program RUNMESH

!>       MESH DRIVER
!>
!>       JAN 2013 - K.C.KORNELSEN
!>                - INCORPORATED LOCATION FLAG FOR INCREASING PRECISION
!>                - OF STREAMFLOW AND RESERVOIR INPUTS
!>                - INCLUDED NSE AND NEGATIVE NSE AS OBJFN'S
!>       JAN 2014 - M. MACDONALD.  INCORPORATED BLOWING SNOW ALGORITHMS
!>       AUG 2013 - M. MACDONALD
!>                - INCORPORATE OPTIONAL COUPLING OF CLASS WITH CTEM
!>                - MOVE SOME INITIALIZATION AND SCATTER OF CLASS
!>                  DIAGNOSTIC VARIABLES IN TO MESH_DRIVER
!>       JUN 2010 - F. SEGLENIEKS. 
!>                - ADDED CODE TO HAVE MESH ONLY RUN ON BASINS LISTED IN 
!>                  THE STREAMFLOW FILE, CALLED THE SUBBASIN FEATURE
!>       JUN 2010 - M.A.MEKONNEN/B.DAVIDSON/M.MacDONALD. 
!>                - BUG FIX FOR READING FORCING DATA IN CSV FORMAT 
!>                  WITH 1 HOUR INTERVAL
!>                - READING FORCING DATA WITH VARIOUS TIME STEPS
!>                - FORCING DATA INTERPOLATION TO 30 MINUTE INTERVALS
!>                  (CLASS MODEL TIME STEP)
!>                - PRE-EMPTION OPTION FOR AUTOCALIBRATION
!>                - CHECKING FOR PARAMETER MINIMUM AND MAXIMUM LIMITS
!>                - PATH SPECIFICATION THAT WORKS FOR BOTH WINDOWS AND 
!>                  UNIX SYSTEMS
!>
!>       AUG 2009 - B.DAVISON. CHANGES TO UPDATE TO SA_MESH 1.3
!>       APL 2009 - CLEAN COMMENTS AND REFINE STRUCTURE AFTER CODE REVIEW
!>       FEB 2009 - MESH12-01 BUG FIX AND ADDING NEW FEATURES
!>       AUG 28/07 - F.SEGLENIEKS. CHANGED FILENAMES AND REARRANGED THE CODE
!>       MAY 21/07 - B.DAVISON.    INITIAL VERSION BASED ON WORK OF E.D. SOULIS
!>       AND F. SEGLENIEKS AT THE UNIVERSITY OF WATERLOO
!>
!>=======================================================================
!>       DIMENSION STATEMENTS.
!>
!>       FIRST SET OF DEFINITIONS:
!>       BACKGROUND VARIABLES, AND PROGNOSTIC AND DIAGNOSTIC
!>       VARIABLES NORMALLY PROVIDED BY AND/OR USED BY THE GCM.
!>       THE SUFFIX "ROW" REFERS TO VARIABLES EXISTING ON THE
!>       MOSAIC GRID ON THE CURRENT LATITUDE CIRCLE.  THE SUFFIX
!>       "GAT" REFERS TO THE SAME VARIABLES AFTER THEY HAVE UNDERGONE
!>       A "GATHER" OPERATION IN WHICH THE TWO MOSAIC DIMENSIONS
!>       ARE COLLAPSED INTO ONE.  THE SUFFIX "GRD" REFERS BOTH TO
!>       GRID-CONSTANT INPUT VARIABLES. AND TO GRID-AVERAGED
!>       DIAGNOSTIC VARIABLES.
!>
!>       THE FIRST DIMENSION ELEMENT OF THE "ROW" VARIABLES
!>       REFERS TO THE NUMBER OF GRID CELLS ON THE CURRENT
!>       LATITUDE CIRCLE.  IN THIS STAND-ALONE VERSION, THIS
!>       NUMBER IS ARBITRARILY SET TO THREE, TO ALLOW UP TO THREE
!>       SIMULTANEOUS TESTS TO BE RUN.  THE SECOND DIMENSION
!>       ELEMENT OF THE "ROW" VARIABLES REFERS TO THE MAXIMUM
!>       NUMBER OF TILES IN THE MOSAIC.  IN THIS STAND-ALONE
!>       VERSION, THIS NUMBER IS SET TO EIGHT.  THE FIRST
!>       DIMENSION ELEMENT IN THE "GAT" VARIABLES IS GIVEN BY
!>       THE PRODUCT OF THE FIRST TWO DIMENSION ELEMENTS IN THE
!>       "ROW" VARIABLES.

!> Note, the internal comments are to be organised with 
!> the following symbols:
!>  -the symbols "!>" at the beginning of the line means that the 
!>  following comments are descriptive documentation.
!>  -the symbols "!*" means that the following comment is a variable
!>  definition.
!>  -the symbols "!+" means that the following comment contains code 
!>  that may be useful in the future and should not be deleted.
!>  -the symbols "!-" means that the following comment contains code
!>  that is basically garbage, and can be deleted safely at any time.
!>  -the symbol "!" or any number of exclamation marks can be used
!>  by the developers for various temporary code commenting.
!>  -the symbol "!todo" refers to places where the developers would 
!>  like to work on.
!>  -the symbol "!futuredo" refers to places where the developers
!>  would like to work on with a low priority.

    use sa_mesh_shared_variabletypes
    use sa_mesh_shared_variables

    use EF_MODULE
    use MESH_INPUT_MODULE
    use FLAGS

    use module_mpi_flags
    use module_mpi

    use sa_mesh_run_within_tile
    use sa_mesh_run_within_grid
    use sa_mesh_run_between_grid

    use MODEL_OUTPUT
    use climate_forcing
    use model_dates
    use SIMSTATS_config
    use SIMSTATS
    use model_files_variables
    use model_files
    use strings

    implicit none

    !> ierr: For status return from MPI
    !> istop: To stop all MPI process
    !* inp: Number of active tasks.
    !* ipid: Current process ID.
    integer :: ierr = 0, inp = 1, ipid = 0
    integer ipid_recv, itag, izero, ierrcode, istop
    logical lstat

    integer iun, u, invars

    !+ For split-vector approach
    integer il1, il2, ilen
    integer ii1, ii2, iilen

    integer, dimension(:), allocatable :: irqst
    integer, dimension(:, :), allocatable :: imstat

    type CLASSOUT_VARS
        real, dimension(:), allocatable :: &
            PREACC, GTACC, QEVPACC, EVAPACC, HFSACC, HMFNACC, &
            ROFACC, ROFOACC, ROFSACC, ROFBACC, WTBLACC, ALVSACC, ALIRACC, &
            RHOSACC, TSNOACC, WSNOACC, SNOARE, TCANACC, CANARE, SNOACC, &
            RCANACC, SCANACC, GROACC, FSINACC, FLINACC, FLUTACC, &
            TAACC, UVACC, PRESACC, QAACC
        real, dimension(:, :), allocatable :: &
            TBARACC, THLQACC, THICACC, THALACC, GFLXACC
    end type !CLASSOUT_VARS

!todo: Investigate what this is
    integer ireport

    !> Local variables.
    integer NA, NTYPE, NML, IGND, ik, jk

!> DAN  USE RTE SUBROUTINES FOR READING EVENT FILE AND SHD FILE, AND
!> DAN  WRITING R2C-FORMAT OUTPUT FILES      
!>  INTEGER CONSTANTS.
!INTEGER ILG
!INTEGER,PARAMETER :: ICAN=4, IGND=6, ICP1=ICAN+1
    integer, parameter :: ICAN = 4, ICP1 = ICAN + 1, ICTEM = 1 !Number of CTEM vegetation categories (set to 1 if not using CTEM)
    integer M_S, M_R
    integer, parameter :: M_C = 5
!INTEGER,PARAMETER :: M_S=290, M_R=7, M_C=5
!M_S and M_R are now read in and used to allocate the appropriate arrays - Frank S Jul 2013
!todo it should be read in from the shd file
!todo M_S could be removed as it is now just a surrogate of WF_NO (KCK)

!INTEGER IGND
    real IGND_TEST, IGND_DEEP

!> IOSTAT VARIABLE
    integer IOS

!> FOR OUTPUT
    character(450) GENDIR_OUT

    !> For R2C-format out
    integer rte_year_now, rte_month_now, rte_day_now, rte_hour_now

!todo clean up commets and arrange variables a bit better

!> SCA variables

!todo clean up comments and make sure the variables
!todo are in groups that make sense
    real basin_SCA
    real basin_SWE
!> STREAMFLOW VARIABLES
!* WF_GAGE: GAUGE IDENTIFIER (8 CHARACTER STRING)
!* WF_NO: NUMBER OF STREAMFLOW GAUGES
!* WF_NL: NUMBER OF DATA POINTS
!* WF_MHRD: NUMBER OF HOURS OF DATA PER MONTH
!* WF_KT: HOURLY INCREMENT FOR STREAMFLOW INPUT (24 = DAILY)
!* WF_IY: Y-DIRECTION GAUGE CO-ORDINATE (UTM OR LATLONG)
!* WF_JX: X-DIRECTION GAUGE CO-ORDINATE (UTM OR LATLONG)
!* WF_S: GAUGE'S PARENT GRID SQUARE
!* WF_QHYD: STREAMFLOW VALUE (_AVG = DAILY AVERAGE)
!* WF_QSYN: SIMULATED STREAFLOW VALUE (_AVG = DAILY AVERAGE)
!* WF_START_YEAR OBSERVED STREAMFLOW START YEAR
!* WF_START_DAY OBSERVED STREAMFLOW START DAY
!* WF_START_HOUR OBSERVED STREAMFLOW START HOUR
    integer WF_NO, WF_NL, WF_MHRD, WF_KT, WF_START_YEAR, &
        WF_START_DAY, WF_START_HOUR
    integer, dimension(:), allocatable :: WF_IY, WF_JX, WF_S
    real, dimension(:), allocatable :: WF_QHYD, WF_QHYD_AVG, WF_QHYD_CUM
    real, dimension(:), allocatable :: WF_QSYN, WF_QSYN_AVG, WF_QSYN_CUM
    character(8), dimension(:), allocatable :: WF_GAGE

!> RESERVOIR VARIABLES
    integer, dimension(:), allocatable :: WF_IRES, WF_JRES, WF_RES, WF_R
    real, dimension(:), allocatable :: WF_B1, WF_B2, WF_QREL, WF_RESSTORE
    character(8), dimension(:), allocatable :: WF_RESNAME

!> FOR BASEFLOW INITIALIZATION
    integer JAN
    integer imonth_now, imonth_old

!>     FOR ROUTING
!* WF_R1: MANNING'S N FOR RIVER CHANNEL
!* WF_R2: OPTIMIZED RIVER ROUGHNESS FACTOR
!* WF_QO2: SIMULATED STREAMFLOW VALUE
    real WF_R1(M_C), WF_R2(M_C)
    real, dimension(:), allocatable :: WF_NHYD, WF_QBASE, WF_QI2, &
        WF_QO1, WF_QO2, WF_QR, WF_STORE1, WF_STORE2, WF_QI1

! Saul=======
!* HOURLY_START_*: Start day/year for recording hourly averaged data
!* HOURLY_STOP_*: Stop day/year for recording hourly averaged data
!* DAILY_START_*: Start day/year for recording daily averaged data
!* DAILY_STOP_*: Stop day/year for recording daily averaged data
    integer HOURLY_START_DAY, HOURLY_STOP_DAY, DAILY_START_DAY, &
        DAILY_STOP_DAY
    integer HOURLY_START_YEAR, HOURLY_STOP_YEAR, DAILY_START_YEAR, &
        DAILY_STOP_YEAR
    integer JDAY_IND_STRM, JDAY_IND1, JDAY_IND2, JDAY_IND3
!*******************************************************************************

!> LAND SURFACE DIAGNOSTIC VARIABLES.

    real, dimension(:), allocatable :: SNOGRD

!>==========
!>
!> START ENSIM == FOR ENSIM == FOR ENSIM == FOR ENSIM ==
    character(10) wf_landclassname(10)
    integer(kind = 4) wfo_yy, wfo_mm, wfo_dd, wfo_hh, wfo_mi, wfo_ss, &
        wfo_ms, nj, ensim_month, ensim_day
    integer(kind = 4) WFO_SEQ, ENSIM_IOS
    integer(kind = 4) CURREC
!> End of ENSIM Changes 
!>== ENSIM == ENSIM == ENSIM == ENSIM == ENSIM ==

!>  CONSTANTS AND TEMPORARY VARIABLES.
    real DEGLAT, DEGLON, FSDOWN1, FSDOWN2, FSDOWN3, RDAY, &
        DECL, HOUR, COSZ, &
        ALTOT, FSSTAR, FLSTAR, QH, QE, BEG, SNOMLT, ZSN, TCN, TSN, TPN, GTOUT
    integer JLAT

!> *************************************************************
!> For reading in options information from MESH_run_options.ini
!> *************************************************************
    character(20) IRONAME
    integer IROVAL

!> *******************************************************************
!> For reading in the last information in mesh_paramters_hydrology.ini
!> *******************************************************************
    character(30) NMTESTFORMAT

!>=======================================================================
!>     * DIMENSION STATEMENTS

!> FIRST SET OF DEFINITIONS:

!> BACKGROUND VARIABLES, AND PROGNOSTIC AND DIAGNOSTIC
!> VARIABLES NORMALLY PROVIDED BY AND/OR USED BY THE GCM.
!> THE SUFFIX "ROW" REFERS TO VARIABLES EXISTING ON THE
!> MOSAIC GRID ON THE CURRENT LATITUDE CIRCLE.  THE SUFFIX
!> "GAT" REFERS TO THE SAME VARIABLES AFTER THEY HAVE UNDERGONE
!> A "GATHER" OPERATION IN WHICH THE TWO MOSAIC DIMENSIONS
!> ARE COLLAPSED INTO ONE.  THE SUFFIX "GRD" REFERS BOTH TO
!> GRID-CONSTANT INPUT VARIABLES. AND TO GRID-AVERAGED
!> DIAGNOSTIC VARIABLES.

!> THE FIRST DIMENSION ELEMENT OF THE "ROW" VARIABLES
!> REFERS TO THE NUMBER OF GRID CELLS ON THE CURRENT
!> LATITUDE CIRCLE.  IN THIS STAND-ALONE VERSION, THIS
!> NUMBER IS ARBITRARILY SET TO THREE, TO ALLOW UP TO THREE
!> SIMULTANEOUS TESTS TO BE RUN.  THE SECOND DIMENSION
!> ELEMENT OF THE "ROW" VARIABLES REFERS TO THE MAXIMUM
!> NUMBER OF TILES IN THE MOSAIC.  IN THIS STAND-ALONE
!> VERSION, THIS NUMBER IS SET TO EIGHT.  THE FIRST
!> DIMENSION ELEMENT IN THE "GAT" VARIABLES IS GIVEN BY
!> THE PRODUCT OF THE FIRST TWO DIMENSION ELEMENTS IN THE
!> "ROW" VARIABLES.

!>     * CONSTANTS (PARAMETER DEFINITIONS):

!* NA: MAXIMUM ALLOWABLE NUMBER OF GRID SQUARES
!* NTYPE: MAXIMUM ALLOWABLE NUMBER OF GRUS
!* ILG: MAXIMUM ALLOWABLE SINGLE-DIMENSION ARRAY LENGTH
!* ICAN: MAXIMUM ALLOWABLE NUMBER OF LAND COVER TYPES
!* ICP1: MAXIMUM ALLOWABLE NUMBER OF LAND COVER TYPES INCLUDING
!*       URBAN AREAS
!* IGND: MAXIMUM ALLOWABLE NUMBER OF SOIL LAYERS
!* M_X: MAXIMUM ALLOWABLE NUMBER OF GRID COLUMNS IN SHD FILE
!* M_Y: MAXIMUM ALLOWABLE NUMBER OF GRID ROWS IN SHD FILE
!* M_S: MAXIMUM ALLOWABLE NUMBER OF STREAMFLOW GAUGES
!* M_R: MAXIMUM ALLOWABLE NUMBER OF RESERVOIRS
!* M_C: MAXIMUM ALLOWABLE NUMBER OF RIVER CHANNELS
!* M_G: MAXIMUM ALLOWABLE NUMBER OF GRID OUTPUTS

!> DAN  * VERSION: MESH_DRIVER VERSION
!> DAN  * RELEASE: PROGRAM RELEASE VERSIONS
!> ANDY * VER_OK: IF INPUT FILES ARE CORRECT VERSION FOR PROGRAM
!> ANDY *    INTEGER, PARAMETER :: M_G = 5
    character(24) :: VERSION = 'TRUNK (901)'
!+CHARACTER :: VERSION*24 = 'TAG'
    character(8) RELEASE(7)
    logical VER_OK
!>
!>*******************************************************************
!>
!> OPERATIONAL VARIABLES:

!* IOS: IOSTAT (ERROR) RETURN ON READ EXTERNAL FILE
!* IY: Y-DIRECTION GRID CO-ORDINATE, USED TO READ FORCING DATA
!* JX: X-DIRECTION GRID CO-ORDINATE, USED TO READ FORCING DATA
!* NN: GRID SQUARE, USED TO READ DRAINAGE DATABASE
!* II: GRU, USED TO READ DRAINAGE DATABASE
!* JAN: IS USED TO INITIALISE BASEFLOW (WHEN JAN = 1)
!* N: COUNTER USED BY CLASS
!* NCOUNT: HALF-HOURLY BASED TIME STEP (200 LOOP)
!* NSUM: NUMBER OF ITERATIONS, TIME STEPS PASSED (200 LOOP)
!* NSUM_TOTAL: total number of iterations
!* i: COUNTER
!* j: COUNTER
!* k: COUNTER
!* l: COUNTER
!* m: COUNTER
!* CONFLAGS: NUMBER OF CONTROL FLAGS
!* OPTFLAGS: NUMBER OF OPTFLAGS
!* INDEPPAR: NUMBER OF GRU-INDEPENDENT VARIABLES
!* DEPPAR: NUMBER OF GRU-DEPENDENT VARIABLES
!* PAS: STAT (ERROR) RETURN ON ALLOCATE VARIABLE
!* OPN: OPENED RETURN ON INQUIRE STATEMENT (USED TO CHECK IF AN
!*      EXTERNAL FILE HAS BEEN OPENED BY THE PROGRAM)
!* FILE_VER: FILE VERSION USED TO SEEK INPUT FILE COMPATIBILITY
!*           (COMPARED TO "RELEASE")
    character(8) FILE_VER
    integer N, NCOUNT, NSUM, i, j, k, l, m, &
        INDEPPAR, DEPPAR, PAS, NSUM_TOTAL
!  CONFLAGS, OPTFLAGS, INDEPPAR, DEPPAR, PAS
    logical OPN
!>
!>*******************************************************************
!>
!>  BASIN INFORMATION AND COUNTS:
!* WF_NA: NUMBER OF GRID SQUARES
!* NAA: NUMBER OF GRID OUTLETS
!* WF_NTYPE: NUMBER OF GRUS
!* NRVR: NUMBER OF RIVER CLASSES
!* WF_IMAX: NUMBER OF GRID COLUMNS IN BASIN
!* WF_JMAX: NUMBER OF GRID ROWNS IN BASIN
!* AL: SINGLE-DIMENSION GRID SQUARE LENGTH
!* LAT/LONG, SITE LOCATION INFORMATION:
!* iyMin: MINIMUM Y-DIRECTION GRID CO-ORDINATE (UTM)
!* iyMax: MAXIMUM Y-DIRECTION GRID CO-ORDINATE (UTM)
!* jxMin: MINIMUM X-DIRECTION GRID CO-ORDINATE (UTM)
!* jxMax: MAXIMUM X-DIRECTION GRID CO-ORDINATE (UTM)
!* GRDN: GRID NORTHING
!* GRDE: GRID EASTING
!* LATLENGTH: SINGLE SIDE LENGTH OF GRID SQUARE IN DEGREES
!*            LATITUDE
!* LONGLENGTH: SINGLE SIDE LENGTH OF GRID SQUARE IN DEGREES
!*             LONGITUDE
!>************************************************************
!>
!> RESERVOIR MEASUREMENTS:
!* WF_RESNAME: RESERVOIR IDENTIFIER (8 CHARACTER STRING)
!* WF_NORESV: NUMBER OF RESERVOIRS
!* WR_NREL: NUMBER OF DATA POINTS
!* WF_KTR: HOURLY INCREMENT FOR RESERVOIR INPUR (24 = DAILY)
!* WF_IRES: Y-DIRECTION GAUGE CO-ORDINATE
!* WF_JRES: X-DIRECTION GAUGE CO-ORDINATE
!* WF_R: RESERVOIR'S PARENT GRID SQUARE
!* WF_QREL: RESERVOIR VALUE

    integer WF_NORESV, WF_NREL, WF_KTR, WF_NORESV_CTRL
    integer WF_ROUTETIMESTEP, WF_TIMECOUNT, DRIVERTIMESTEP
!>
    real I_G, J_G
!* I_G: REAL TEMPORARY IY COORDINATE FOR STREAM AND RESERVOIR GAUGES
!* J_G: REAL TEMPORARY JX COORDINATE FOR STREAM AND RESERVOIR GAUGES
!>*******************************************************************
!>
!-!* rte_frames_now: FRAME NUMBER BEING WRITTEN TO R2C-FORMAT FILE
!-!* rte_frames_total: TOTAL NUMBER OF FRAMES IN R2C-FORMAT FILE (TOTAL
!-!*            NUMBER OF FRAMES IS NEVER KNOWN, IS ALWAYS SET TO
!-!*            rte_frames_total + 1)
!-    integer rte_frames_now, rte_frames_total
    integer FRAME_NO_NEW
!-!* rte_runoff: HOURLY SIMULATED RUNOFF
!-!* rte_recharge: HOURLY SIMULATED RECHARGE
!-!* rte_leakage: UNKNOWN, BUT MAY BE USED IN THE FUTURE
!-    real, dimension(:, :), allocatable :: rte_runoff, rte_recharge, rte_leakage
!-!-* LEAKAGE: UNKNOWN, BUT MAY BE USED IN THE FUTURE

!> GRID OUTPUT POINTS
!* BNAM: TEMPORARY HOLD FOR OUTPUT DIRECTORY (12 CHARACTER STRING)
    character(12) BNAM
!* WF_NUM_POINTS: NUMBER OF GRID OUTPUTS
!* I_OUT: OUTPUT GRID SQUARE TEMPORARY STORE
    integer WF_NUM_POINTS, I_OUT
!>
!>*******************************************************************
!>
!>*******************************************************************
!>
!> LIMITING TIME STEPS (CLASS.INI):
!> DAN  NOT USED RIGHT NOW.  CONSIDER USING THEM TO LIMIT RUN INSTEAD
!> DAN  OF END OF FORCING.BIN FILE (IS ESPECIALLY USEFUL WHEN DEBUGGING).
!* JOUT1: DAILY-AVERAGED OUTPUT START DAY (JULIAN FROM YEAR START)
!* JOUT2: DAILY-AVERAGED OUTPUT STOP DAY (JULIAN FROM YEAR START)
!* JAV1: DAILY-AVERAGED OUTPUT START YEAR
!* JAV2: DAILY-AVERAGED OUTPUT STOP YEAR
!* KOUT1: YEARLY-AVERAGED OUTPUT START DAY (JULIAN FROM YEAR START)
!* KOUT2: YEARLY-AVERAGED OUTPUT STOP DAY (JULIAN FROM YEAR START)
!* KAV1: YEARLY-AVERAGED OUTPUT START YEAR
!* KAV2: YEARLY-AVERAGED OUTPUT STOP YEAR
    integer JOUT1, JOUT2, JAV1, JAV2, KOUT1, KOUT2, KAV1, KAV2
!>
!>*******************************************************************
!>
!> CLASS CONTROL FLAGS:
!> DAN  CONSIDER INCLUDING AS CONTROL FLAGS IN RUN_OPTIONS.INI FILE SO
!> DAN  THAT THEY ARE NO LONGER HARD-CODED.
!* ALL: DESCRIPTIONS ARE WRITTEN WHERE RUN_OPTIONS.INI IS READ
    integer IDISP, IZREF, ISLFD, IPCP, IWF, IPAI, IHGT, IALC, &
        IALS, IALG, ITG, ITC, ITCG

!> GRID SQUARE COUNTS:
!* NLTEST: NUMBER OF GRID SQUARES (CLASS.INI)
!* NMTEST: NUMBER OF GRUS (CLASS.INI)
!* IHOUR: CURRENT HOUR OF MET. FORCING DATA (0 TO 23) (CLASS.INI)
!* IMIN: CURRENT MINUTE OF MET. FORCING DATA (0 OR 30) (CLASS.INI)
!* IDAY: CURRENT DAY OF MET. FORCING DATA (JULIAN FROM YEAR START)
!*       (CLASS.INI)
!* IYEAR: CURRENT YEAR OF MET. FORCING DATA (CLASS.INI)
    integer NLTEST, NMTEST, NLANDCS, NLANDGS, NLANDC, NLANDG, NLANDI

!> LAND SURFACE PROGNOSTIC VARIABLES (CLASS.INI):
!* TBAR: INITIAL SOIL LAYER TEMPERATURE
!* THLQ: INITIAL SOIL LAYER LIQUID WATER CONTENT
!* THIC: INITIAL SOIL LAYER ICE WATER CONTENT
    real, dimension(:, :), allocatable :: TBARGAT, THLQGAT, THICGAT, &
        SANDGAT, CLAYGAT
    real, dimension(:, :), allocatable :: TBASROW, &
        CMAIROW, TACROW, QACROW, WSNOROW
     
!>PBSM VARIABLES (GRU)
!* DrySnow: 0 = air temperature above 0 degC
!*          1 = air temperature below 0 degC
!* SnowAge: hours since last snowfall
!* Drift: blowing snow transport (kg/m^2)
!* Subl: blowing snow sublimation (kg/m^2)
    real, dimension(:), allocatable :: DrySnowGAT, SnowAgeGAT, &
        TSNOdsGAT, RHOSdsGAT, DriftGAT, SublGAT, DepositionGAT
    real, dimension(:, :), allocatable :: DrySnowROW, SnowAgeROW, &
        TSNOdsROW, RHOSdsROW, DriftROW, SublROW, DepositionROW
!>CLASS SUBAREA VARIABLES NEEDED FOR PBSM
    real, dimension(:), allocatable :: ZSNOCS, ZSNOGS, ZSNOWC, ZSNOWG, &
        HCPSCS, HCPSGS, HCPSC, HCPSG, TSNOWC, TSNOWG, &
        RHOSC, RHOSG, XSNOWC, XSNOWG, XSNOCS, XSNOGS
!* TPND: INITIAL PONDING TEMPERATURE (CLASS.INI)
!* ZPND: INITIAL PONDING DEPTH (CLASS.INI)
!* ALBS: ALBEDO OF SNOWPACK (CLASS.INI)
!* TSNO: INITIAL SNOWPACK TEMPERATURE (CLASS.INI)
!* RHOS: DENSITY OF SNOWPACK (CLASS.INI)
!* SNO: SNOWPACK ON CANOPY LAYER (CLASS.INI)
!* TCAN: INITIAL CANOPY TEMPERATURE (CLASS.INI)
!* GRO: VEGETATION GROWTH INDEX (CLASS.INI)
    real, dimension(:), allocatable :: TPNDGAT, ZPNDGAT, TBASGAT, &
        ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, TCANGAT, RCANGAT, SCANGAT, &
        GROGAT, FRZCGAT, CMAIGAT, TACGAT, QACGAT, WSNOGAT
     
    real, dimension(:, :, :), allocatable :: TSFSROW
    real, dimension(:, :), allocatable :: TSFSGAT
!>
!>*******************************************************************
!>
!> CANOPY AND SOIL INFORMATION (CLASS):
!> THE LENGTH OF THESE ARRAYS IS DETERMINED BY THE NUMBER
!> OF SOIL LAYERS (3) AND THE NUMBER OF BROAD VEGETATION
!> CATEGORIES (4, OR 5 INCLUDING URBAN AREAS).
!* ALL: DEFINITIONS IN CLASS DOCUMENTATION (CLASS.INI)
    real, dimension(:, :), allocatable :: FCANGAT, LNZ0GAT, &
        ALVCGAT, ALICGAT
    real, dimension(:, :, :), allocatable :: &
        PAIDROW, HGTDROW, ACVDROW, ACIDROW
    real, dimension(:, :), allocatable :: PAMXGAT, PAMNGAT, &
        CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, VPDAGAT, VPDBGAT, PSGAGAT, &
        PSGBGAT, PAIDGAT, HGTDGAT, ACVDGAT, ACIDGAT
    real, dimension(:, :, :), allocatable :: THPROW, THRROW, THMROW, &
        BIROW, PSISROW, GRKSROW, THRAROW, HCPSROW, TCSROW, THFCROW, &
        PSIWROW, DLZWROW, ZBTWROW
    real, dimension(:, :), allocatable :: THPGAT, THRGAT, THMGAT, &
        BIGAT, PSISGAT, GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, THFCGAT, &
        PSIWGAT, DLZWGAT, ZBTWGAT, GFLXGAT
    real, dimension(:, :), allocatable :: &
        WFSFROW, ALGWROW, ALGDROW, ASVDROW, ASIDROW, AGVDROW, &
        AGIDROW
    real, dimension(:), allocatable :: DRNGAT, XSLPGAT, XDGAT, &
        WFSFGAT, KSGAT, ALGWGAT, ALGDGAT, ASVDGAT, ASIDGAT, AGVDGAT, &
        AGIDGAT, ZSNLGAT, ZPLGGAT, ZPLSGAT, SDEPGAT, FAREGAT
!* PBSM parameters
!  fetch: fetch distance (m)
!  Ht: vegetation height (m)
!  N_S:vegetation density (number/m^2)
!  A_S: vegetation width (m)
!  Distrib: Inter-GRU snow redistribution factor
    real, dimension(:), allocatable :: &
        fetchGAT, HtGAT, N_SGAT, A_SGAT, DistribGAT

!* SAND: PERCENT-CONTENT OF SAND IN SOIL LAYER (CLASS.INI)
!* CLAY: PERCENT-CONTENT OF CLAY IN SOIL LAYER (CLASS.INI)
!* ORGM: PERCENT-CONTENT OF ORGANIC MATTER IN SOIL LAYER (CLASS.INI)

!* MIDROW: DEFINITION IN CLASS DOCUMENTATION (CLASS.INI)

    integer, dimension(:, :, :), allocatable :: ISNDROW, IORG
    integer, dimension(:, :), allocatable :: ISNDGAT
    integer, dimension(:,:), allocatable :: IGDRROW
    integer, dimension(:), allocatable :: IGDRGAT
!>
!>*******************************************************************
!>
!> WATROF FLAGS AND VARIABLES:
!* VICEFLG: VERTICAL ICE FLAG OR LIMIT
!* HICEFLG: HORIZONTAL ICE FLAG OR LIMIT
    integer LZFFLG, EXTFLG, IWFICE, ERRFLG, IWFOFLW
    real VICEFLG, PSI_LIMIT, HICEFLG
!* DD (DDEN): DRAINAGE DENSITY (CLASS.INI)
!* MANN (WFSF): MANNING'S n (CLASS.INI)
    real, dimension(:), allocatable :: DDGAT, MANNGAT
    real, dimension(:, :), allocatable :: BTC, BCAP, DCOEFF, BFCAP, &
        BFCOEFF, BFMIN, BQMAX
!>
!>*******************************************************************
!>
!> ATMOSPHERIC AND GRID-CONSTANT INPUT VARIABLES:
    real, dimension(:), allocatable :: ZDMGRD, &
        ZDHGRD, RADJGRD, CSZGRD, &
        PADRGRD, VPDGRD, &
        TADPGRD, RHOAGRD, RPCPGRD, TRPCGRD, SPCPGRD, TSPCGRD, RHSIGRD, &
        FCLOGRD, DLONGRD, Z0ORGRD, GGEOGRD, UVGRD, XDIFFUS, &
        RPREGRD, SPREGRD, VMODGRD

!> MAM - logical variables to control simulation runs:
    logical ENDDATE, ENDDATA

    real, dimension(:), allocatable :: ZRFMGAT, ZRFHGAT, ZDMGAT, &
        ZDHGAT, ZBLDGAT, RADJGAT, CSZGAT, &
        RPREGAT, SPREGAT, &
        PADRGAT, VPDGAT, TADPGAT, RHOAGAT, RPCPGAT, TRPCGAT, SPCPGAT, &
        TSPCGAT, RHSIGAT, FCLOGAT, DLONGAT, Z0ORGAT, GGEOGAT, VMODGAT
!>
!>*******************************************************************
!>
!> LAND SURFACE DIAGNOSTIC VARIABLES:
    real, dimension(:, :), allocatable :: CDHROW, CDMROW, HFSROW, &
        TFXROW, QEVPROW, QFSROW, QFXROW, PETROW, GAROW, EFROW, GTROW, &
        QGROW, TSFROW, ALVSROW, ALIRROW, FSNOROW, SFCTROW, SFCUROW, &
        SFCVROW, SFCQROW, FSGVROW, FSGSROW, FSGGROW, FLGVROW, FLGSROW, &
        FLGGROW, HFSCROW, HFSSROW, HFSGROW, HEVCROW, HEVSROW, HEVGROW, &
        HMFCROW, HMFNROW, HTCCROW, HTCSROW, PCFCROW, PCLCROW, PCPNROW, &
        PCPGROW, QFGROW, QFNROW, QFCLROW, QFCFROW, ROFROW, ROFOROW, &
        ROFSROW, ROFBROW, ROFCROW, ROFNROW, ROVGROW, WTRCROW, WTRSROW, &
        WTRGROW, DRROW, WTABROW, ILMOROW, UEROW, HBLROW, TROFROW, &
        TROOROW, TROSROW, TROBROW
    real, dimension(:), allocatable :: CDHGAT, CDMGAT, HFSGAT, &
        TFXGAT, QEVPGAT, QFSGAT, QFXGAT, PETGAT, GAGAT, EFGAT, GTGAT, &
        QGGAT, ALVSGAT, ALIRGAT, FSNOGAT, SFRHGAT, SFCTGAT, SFCUGAT, &
        SFCVGAT, SFCQGAT, FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, &
        FLGGGAT, HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, HEVSGAT, HEVGGAT, &
        HMFCGAT, HMFNGAT, HTCCGAT, HTCSGAT, PCFCGAT, PCLCGAT, PCPNGAT, &
        PCPGGAT, QFGGAT, QFNGAT, QFCLGAT, QFCFGAT, ROFGAT, ROFOGAT, &
        ROFSGAT, ROFBGAT, ROFCGAT, ROFNGAT, ROVGGAT, WTRCGAT, WTRSGAT, &
        WTRGGAT, DRGAT, WTABGAT, ILMOGAT, UEGAT, HBLGAT, QLWOGAT, FTEMP, &
        FVAP, RIB, TROFGAT, TROOGAT, TROSGAT, TROBGAT
    real, dimension(:), allocatable :: CDHGRD, CDMGRD, HFSGRD, &
        TFXGRD, QEVPGRD, QFSGRD, QFXGRD, PETGRD, GAGRD, EFGRD, GTGRD, &
        QGGRD, TSFGRD, ALVSGRD, ALIRGRD, FSNOGRD, SFCTGRD, SFCUGRD, &
        SFCVGRD, SFCQGRD, FSGVGRD, FSGSGRD, FSGGGRD, FLGVGRD, FLGSGRD, &
        FLGGGRD, HFSCGRD, HFSSGRD, HFSGGRD, HEVCGRD, HEVSGRD, HEVGGRD, &
        HMFCGRD, HMFNGRD, HTCCGRD, HTCSGRD, PCFCGRD, PCLCGRD, PCPNGRD, &
        PCPGGRD, QFGGRD, QFNGRD, QFCLGRD, QFCFGRD, ROFGRD, ROFOGRD, &
        ROFSGRD, ROFBGRD, ROFCGRD, ROFNGRD, ROVGGRD, WTRCGRD, WTRSGRD, &
        WTRGGRD, DRGRD, WTABGRD, ILMOGRD, UEGRD, HBLGRD

    real, dimension(:, :, :), allocatable :: HMFGROW, HTCROW, QFCROW, &
        GFLXROW
    real, dimension(:, :), allocatable :: HMFGGAT, HTCGAT, QFCGAT
    real, dimension(:, :), allocatable :: HMFGGRD, HTCGRD, QFCGRD, GFLXGRD
    integer, dimension(:, :, :, :), allocatable :: ITCTROW
    integer, dimension(:, :, :), allocatable :: ITCTGAT

!* TITLE: PROJECT DESCRIPTOR (6 COLUMNS: 4 CHARACTER STRINGS)
!* NAME: AUTHOR, RESEARCHER (6 COLUMNS: 4 CHARACTER STRINGS)
!* PLACE: SITE LOCATION, BASIN (6 COLUMNS: 4 CHARACTER STRINGS)
    character(4) TITLE1, TITLE2, TITLE3, TITLE4, TITLE5, &
        TITLE6, NAME1, NAME2, NAME3, NAME4, NAME5, NAME6, &
        PLACE1, PLACE2, PLACE3, PLACE4, PLACE5, PLACE6
!>
!>*******************************************************************
!>*******************************************************************
!>
!> OUTPUT VARIABLES:
!> THE SUFFIX "ACC" REFERS TO THE ACCUMULATOR ARRAYS USED IN
!> CALCULATING TIME AVERAGES.
!* ALL: DEFINITIONS IN CLASS DOCUMENTATION
    real, dimension(:), allocatable :: PREACC, GTACC, QEVPACC, &
        HFSACC, ROFACC, SNOACC, ALVSACC, ALIRACC, FSINACC, FLINACC, &
        TAACC, UVACC, PRESACC, QAACC, EVAPACC, FLUTACC, ROFOACC, &
        ROFSACC, ROFBACC, HMFNACC, WTBLACC, WSNOACC, RHOSACC, TSNOACC, &
        TCANACC, RCANACC, SCANACC, GROACC, CANARE, SNOARE, ZPNDACC

!> FIELD OF DELTA STORAGE AND INITIAL STORAGE
    real, dimension(:), allocatable :: DSTG, STG_I

    real, dimension(:, :), allocatable :: TBARACC, THLQACC, THICACC, &
        THALACC , THLQ_FLD, THIC_FLD, GFLXACC

!* TOTAL_ROFACC: TOTAL RUNOFF
!* TOTAL_EVAPACC: TOTAL EVAPORATION
!* TOTAL_PREACC: TOTAL PRECIPITATION
!* INIT_STORE: INITIAL STORAGE
!* FINAL_STORE: FINAL STORAGE
!* TOTAL_AREA: TOTAL FRACTIONED DRAINAGE AREA
    real TOTAL_ROFACC, TOTAL_ROFOACC, TOTAL_ROFSACC, &
        TOTAL_ROFBACC, TOTAL_EVAPACC, TOTAL_PREACC, INIT_STORE, &
        FINAL_STORE, TOTAL_AREA, &
        TOTAL_PRE_ACC_M, TOTAL_EVAP_ACC_M, TOTAL_ROF_ACC_M, &
        TOTAL_ROFO_ACC_M, TOTAL_ROFS_ACC_M, TOTAL_ROFB_ACC_M, &
        TOTAL_PRE_M, TOTAL_EVAP_M, TOTAL_ROF_M, &
        TOTAL_ROFO_M, TOTAL_ROFS_M, TOTAL_ROFB_M, &
        TOTAL_SCAN_M, TOTAL_RCAN_M, &
        TOTAL_SNO_M, TOTAL_WSNO_M, &
        TOTAL_ZPND_M, &
        TOTAL_STORE_M, TOTAL_STORE_2_M, &
        TOTAL_STORE_ACC_M
  
!* TOTAL_HFS = TOTAL SENSIBLE HEAT FLUX
!* TOTAL_QEVP = TOTAL LATENT HEAT FLUX
    real TOTAL_HFSACC, TOTAL_QEVPACC

    real TOTAL_STORE, TOTAL_STORE_2, TOTAL_RCAN, TOTAL_SCAN, TOTAL_SNO, TOTAL_WSNO, TOTAL_ZPND
    real TOTAL_PRE, TOTAL_EVAP, TOTAL_ROF, TOTAL_ROFO, TOTAL_ROFS, TOTAL_ROFB
    real, dimension(:), allocatable :: TOTAL_THLQ, TOTAL_THIC, &
        TOTAL_THLQ_M, TOTAL_THIC_M

!> CROSS-CLASS VARIABLES (CLASS):
!> ARRAYS DEFINED TO PASS INFORMATION BETWEEN THE THREE MAJOR
!> SUBSECTIONS OF CLASS ("CLASSA", "CLASST" AND "CLASSW").
    real, dimension(:, :), allocatable :: TBARC, TBARG, TBARCS, &
        TBARGS, THLIQC, THLIQG, THICEC, THICEG, FROOT, HCPC, HCPG, &
        TCTOPC, TCBOTC, TCTOPG, TCBOTG

    real, dimension(:), allocatable :: FC, FG, FCS, FGS, RBCOEF, &
        ZSNOW, FSVF, FSVFS, ALVSCN, ALIRCN, ALVSG, &
        ALIRG, ALVSCS, ALIRCS, ALVSSN, ALIRSN, ALVSGC, ALIRGC, ALVSSC, &
        ALIRSC, TRVSCN, TRIRCN, TRVSCS, TRIRCS, RC, RCS, FRAINC, &
        FSNOWC, FRAICS, FSNOCS, CMASSC, CMASCS, DISP, DISPS, ZOMLNC, &
        ZOELNC, ZOMLNG, &
        ZOELNG, ZOMLCS, ZOELCS, ZOMLNS, ZOELNS, TRSNOW, CHCAP, CHCAPS, &
        GZEROC, GZEROG, GZROCS, GZROGS, G12C, G12G, G12CS, G12GS, G23C, &
        G23G, G23CS, G23GS, QFREZC, QFREZG, QMELTC, QMELTG, EVAPC, &
        EVAPCG, EVAPG, EVAPCS, EVPCSG, EVAPGS, TCANO, TCANS, RAICAN, &
        SNOCAN, RAICNS, SNOCNS, CWLCAP, CWFCAP, CWLCPS, CWFCPS, TSNOCS, &
        TSNOGS, RHOSCS, RHOSGS, WSNOCS, WSNOGS, TPONDC, TPONDG, TPNDCS, &
        TPNDGS, ZPLMCS, ZPLMGS, ZPLIMC, ZPLIMG

!> BALANCE ERRORS (CLASS):
!> DIAGNOSTIC ARRAYS USED FOR CHECKING ENERGY AND WATER
!> BALANCES.
    real, dimension(:), allocatable :: CTVSTP, CTSSTP, CT1STP, &
        CT2STP, CT3STP, WTVSTP, WTSSTP, WTGSTP

!> CTEM-RELATED FIELDS (NOT USED IN STANDARD OFFLINE CLASS RUNS).
    real, dimension(:), allocatable :: &
        CO2CONC, COSZS, XDIFFUSC, CFLUXCG, CFLUXCS
    real, dimension(:, :), allocatable :: &
        AILCG, AILCGS, FCANC, FCANCS, CO2I1CG, CO2I1CS, CO2I2CG, CO2I2CS, &
        SLAI, FCANCMX, ANCSVEG, ANCGVEG, RMLCSVEG, RMLCGVEG, &
        AILC, PAIC, &
        FIELDSM, WILTSM
    real, dimension(:, :, :), allocatable :: &
        RMATCTEM, RMATC
    integer, dimension(:), allocatable :: NOL2PFTS
    integer ICTEMMOD, L2MAX

!> COMMON BLOCK PARAMETERS (CLASS):
    integer K1, K2, K3, K4, K5, K6, K7, K8, K9, K10, K11
    real X1, X2, X3, X4, G, GAS, X5, X6, CPRES, GASV, X7, CPI, X8, &
        CELZRO, X9, X10, X11, X12, X13, X14, X15, SIGMA, X16, DELTIM, &
        DELT, TFREZ, RGAS, RGASV, GRAV, SBC, VKC, CT, VMIN, TCW, TCICE, &
        TCSAND, TCCLAY, TCOM, TCDRYS, RHOSOL, RHOOM, HCPW, HCPICE, &
        HCPSOL, HCPOM, HCPSND, HCPCLY, SPHW, SPHICE, SPHVEG, SPHAIR, &
        RHOW, RHOICE, TCGLAC, CLHMLT, CLHVAP, PI, ZOLNG, ZOLNS, ZOLNI, &
        ZORATG, ALVSI, ALIRI, ALVSO, ALIRO, ALBRCK, DELTA, CGRAV, &
        CKARM, CPD, AS, ASX, CI, BS, BETA, FACTN, HMIN, ANGMAX

!> DAN * CONFLICTS WITH COMMON BLOCK DEFINITIONS (APR 20/08)
    real, dimension(ICAN) :: CANEXT, XLEAF, ZORAT

    real, dimension(3) :: THPORG, THRORG, THMORG, BORG, PSISORG, &
        GRKSORG
    real, dimension(18, 4, 2) :: GROWYR

!> **********************************************************************
!>  For cacluating the subbasin grids
!> **********************************************************************

    integer SUBBASINCOUNT
    integer, dimension(:), allocatable :: SUBBASIN

!>=======================================================================
!> DAN * GLOBAL SUBROUTINES AND VARIABLES

!> DAN * SUBROUTINES AND MODULES:
!
!> READ_SHED_EF: SUBROUTINE USED TO READ THE BASIN SHD FILE
!> WRITE_R2C: SUBROUTINE USED TO WRITE R2C-FORMAT RTE.EXE INPUT
!>            FILES (RUNOFF, RECHARGE, AND LEAKAGE VALUES)
!> EF_MODULE: MODULE CONTAINING FORMATTING FUNCTIONS AND
!>            SUBROUTINES
!> EF_PARSEUTILITIES: MODULE CONTAINING FORMATTING FUNCTIONS AND
!>                    SUBROUTINES CALLED BY EF_MODULE
!> FIND_MONTH: SUBROUTINE USED TO CONVERT JULIAN DAY FROM YEAR
!>             START INTO MONTH FROM YEAR START (1 TO 12)
!> FIND_DAY: SUBROUTINE USED TO CONVERT JULIAN DAY FROM YEAR START
!>           INTO DAY FROM MONTH START (1 TO 31)

!> DAN * VARIABLES:

!* xCount: NUMBER OF GRID SQUARES IN X-DIRECTION OF
!*                      BASIN (COLUMNS) (JMAX)
!* yCount: NUMBER OF GRID SQUARES IN Y-DIRECTION OF
!*                      BASIN (ROWS) (IMAX)
!* AL: SINGLE GRID SIDE LENGTH IN METRES (AL)
!* NA: NUMBER OF GRID SQUARES IN BASIN (WF_NA)
!* NAA: NUMBER OF GRID SQUARE OUTLETS IN BASIN (NAA)
!* NTYPE: NUMBER OF GRUS (WF_NTYPE)
!* FRAC: GRID FRACTION (previously WF_FRAC)
!* ACLASS: PERCENT-GRU FRACTION FOR EACH GRID SQUARE
!* CoordSys: CO-ORDINATE SYSTEM (FROM BASIN SHD
!*                           FILE)
!* Zone: CO-ORDINATE SYSTEM (FROM BASIN SHD FILE)
!* Datum: CO-ORDINATE SYSTEM (FROM BASIN SHD FILE)
!* xOrigin: X-DIRECTION CO-ORDINATE OF BASIN GRID
!*                        (FROM BASIN SHD FILE)
!* yOrigin: Y-DIRECTION CO-ORDINATE OF BASIN GRID
!*                        (FROM BASIN SHD FILE)
!* xDelta: AVERAGE DIFFERENCE BETWEEN TWO X-DIRECTION
!*                      SIDES OF GRID SQUARE (FROM BASIN SHD FILE)
!* yDelta: AVERAGE DIFFERENCE BETWEEN TWO Y-DIRECTION
!*                      SIDES OF GRID SQUARE (FROM BASIN SHD FILE)
!* yyy: Y-DIRECTION GRID SQUARE CO-ORDINATE (YYY), aka column coordinate
!* xxx: X-DIRECTION GRID SQUARE CO-ORDIANTE (XXX), aka row coordinate

!> These are the types defined in mesh_input_module.f that contain arrays
!> that need to be allocated in read_initial_inputs.f.
    type(OutputPoints) :: op
!+    type(ShedInformation) :: si
    type(SoilLevels) :: sl
    type(ClassParameters) :: cp
    type(SoilValues) :: sv
    type(HydrologyParameters) :: hp
    type(fl_ids) :: fls

!>THESE ARE THTE TYPES DEFINED IN MODEL_OUTPUT.F95 NEED TO WRITE OUTPUT FIELD ACCUMULATED
!> OR AVERAGE FOR THE WATER BALANCE AND SOME OTHER STATES VARIABLES
    type(OUT_FLDS) :: VR
    type(ShedGridParams) :: shd
    type(dates_model) :: ts
    type(iter_counter) :: ic
    type(INFO_OUT) :: ifo
    type(CLIM_INFO) :: cm
    type(met_data) :: md
    type(CLASSOUT_VARS) :: co
    type(water_balance) :: wb, wb_h
    type(energy_balance) :: eng
    type(soil_statevars) :: sov

    logical R2COUTPUT
    integer, parameter :: R2CFILEUNITSTART = 500
    integer NR2C, DELTR2C, NR2CFILES, NR2CSTATES, NR2C_R, DELTR2C_R, NR2C_S, DELTR2C_S
    integer, allocatable, dimension(:) :: GRD, GAT, GRDGAT, GRD_R, GAT_R, GRDGAT_R, GRD_S, GAT_S, GRDGAT_S
    character(50), allocatable, dimension(:, :) :: R2C_ATTRIBUTES, R2C_ATTRIBUTES_R, R2C_ATTRIBUTES_S

    integer NMELT
    real SOIL_POR_MAX, SOIL_DEPTH, S0, T_ICE_LENS
    integer, dimension(:), allocatable :: INFILTYPE
    real, dimension(:), allocatable :: SI, TSI, SNOWMELTD, SNOWMELTD_LAST, &
        SNOWINFIL, CUMSNOWINFILCS, MELTRUNOFF, CUMSNOWINFILGS

!* PDMROF
    real ZPND, FSTR
    real, dimension(:), allocatable   :: CMINPDM, CMAXPDM, BPDM, K1PDM, K2PDM, &
        ZPNDPRECS, ZPONDPREC, ZPONDPREG, ZPNDPREGS, &
        UM1CS, UM1C, UM1G, UM1GS, &
        QM1CS, QM1C, QM1G, QM1GS, &
        QM2CS, QM2C, QM2G, QM2GS, UMQ, &
        FSTRCS, FSTRC, FSTRG, FSTRGS

! To use with variable format expressions in writing some output files
    character(20) IGND_CHAR
    character(2000) FMT

    character(500) WRT_900_1, WRT_900_2, WRT_900_3, WRT_900_4, WRT_900_f
    character(500) fl_listMesh
    character(5) strInt
!=======================================================================
!     * SET PHYSICAL CONSTANTS AND COMMON BLOCKS

    common /PARAMS/ X1, X2, X3, X4, G, GAS, X5, X6, CPRES, &
        GASV, X7
    common /PARAM1/ CPI, X8, CELZRO, X9, X10, X11
    common /PARAM3/ X12, X13, X14, X15, SIGMA, X16
    common /TIMES/ DELTIM, K1, K2, K3, K4, K5, K6, K7, K8, K9, &
        K10, K11

!> THE FOLLOWING COMMON BLOCKS ARE DEFINED SPECIFICALLY FOR USE
!> IN CLASS, VIA BLOCK DATA AND THE SUBROUTINE "CLASSD".
    common /CLASS1/ DELT, TFREZ
    common /CLASS2/ RGAS, RGASV, GRAV, SBC, VKC, CT, VMIN
    common /CLASS3/ TCW, TCICE, TCSAND, TCCLAY, TCOM, TCDRYS, &
        RHOSOL, RHOOM
    common /CLASS4/ HCPW, HCPICE, HCPSOL, HCPOM, HCPSND, &
        HCPCLY, SPHW, SPHICE, SPHVEG, SPHAIR, RHOW, &
        RHOICE, TCGLAC, CLHMLT, CLHVAP
    common /CLASS5/ THPORG, THRORG, THMORG, BORG, PSISORG, &
        GRKSORG
    common /CLASS6/ PI, GROWYR, ZOLNG, ZOLNS, ZOLNI, ZORAT, &
        ZORATG
    common /CLASS7/ CANEXT, XLEAF
    common /CLASS8/ ALVSI, ALIRI, ALVSO, ALIRO, ALBRCK
    common /PHYCON/ DELTA, CGRAV, CKARM, CPD
    common /CLASSD2/ AS, ASX, CI, BS, BETA, FACTN, HMIN, ANGMAX

!> THE FOLLOWING COMMON BLOCKS ARE DEFINED FOR WATROF
    data VICEFLG/3.0/, PSI_LIMIT/1.0/, HICEFLG/1.0/, LZFFLG/0/, &
        EXTFLG/0/, IWFICE/3/, ERRFLG/1/

    real :: startprog, endprog
    integer :: narg
!real :: alpharain
!character*50 :: alphCh

!> ((((((((((((((((((((((((((((((((((
!> Set the acceptable version numbers
!> ))))))))))))))))))))))))))))))))))
!> todo this should be input file dependant,
!>  because different files will work with different releases
!>  so, make them local variables inside each read subroutine.
    RELEASE(1) = '1.1.a01'
    RELEASE(2) = '1.1.a02'
    RELEASE(3) = '1.1.a04'
    RELEASE(4) = '1.2.000'
    RELEASE(5) = '1.2.a01'
    RELEASE(6) = '1.3.000'
    RELEASE(7) = '1.3.1'

    call cpu_time(startprog)
!>=======================================================================
!>      PROGRAM START

    !> Initialize MPI.
    call mpi_init(ierr)
    if (ierr /= mpi_success) then
        print *, 'Failed to initialize MPI.'
        call mpi_abort(mpi_comm_world, ierrcode, ierr)
        print *, 'ierrcode ', ierrcode, 'ierr ', ierr
    end if

    !> Grab number of total processes and current process ID.
    call mpi_comm_size(mpi_comm_world, inp, ierr)
    call mpi_comm_rank(mpi_comm_world, ipid, ierr)

    !> izero is active if the head node is used for booking and lateral flow
    !> processes.
    if (inp > 1) then
        izero = 1
    else
        izero = 0
    end if

    !> Reset verbose flag for worker nodes.
    if (ipid > 0) ro%VERBOSEMODE = 0

!>!TODO: UPDATE THIS (RELEASE(*)) WITH VERSION CHANGE
    if (ro%VERBOSEMODE > 0) print 951, trim(RELEASE(7)), trim(VERSION)

951 format(1x, 'MESH ', a, ' ---  (', a, ')', /)

!File handled for variable in/out names
!At the moment only class,hydro parameters and some outputs

    !> Check if any command line arguments are found.
    narg = command_argument_count()
    !print *, narg
    if (narg > 0) then
        VARIABLEFILESFLAG = 1
        if (narg >= 1) then
            call get_command_argument(1, fl_listMesh)
!            print *, fl_listMesh
!        else if (narg == 2) then
!            call get_command_argument(1, fl_listMesh)
!            print *, fl_listMesh
!todo: re-instate alpha
!            call get_command_argument(2, alphCh)
!            call value(alphCh, alpharain, ios)
!            cm%clin(8)%alpharain = alpharain
!            print *, cm%clin(8)%alpharain
        end if
        call Init_fls(fls, trim(adjustl(fl_listMesh)))
    else
!todo: Call this anyway, make loading values from file an alternate subroutine of module_files
        call Init_fls(fls)
    end if !(narg > 0) then

    !> Determine the value of IGND from MESH_input_soil_levels.txt
!todo: Move this to read_soil_levels
    shd%lc%IGND = 0

    !> Open soil levels file and check for IOSTAT errors.
    iun = fls%fl(mfk%f52)%iun
    open(iun, file = trim(adjustl(fls%fl(mfk%f52)%fn)), status = 'old', action = 'read', iostat = ios)
    if (ios /= 0) then
        print 1002
        stop
    end if

    !> Count the number of soil layers.
    IGND_TEST = 1.0
    do while (IGND_TEST /= 0.0 .and. ios == 0)
        read(52, *, iostat = ios) IGND_TEST, IGND_DEEP
        shd%lc%IGND = shd%lc%IGND + 1
    end do

    !> because IGND increments the first time that IGND_TEST = 0.0
    shd%lc%IGND = shd%lc%IGND - 1
    print *, 'IGND = ', shd%lc%IGND
    close(iun)

1002 format(/1x, 'MESH_input_soil_levels.txt could not be opened.', &
            /1x, 'Ensure that the file exists and restart the program.', /)

!>=======================================================================
!> INITIALIZE CLASS VARIABLES
!> SET COMMON CLASS PARAMETERS.
    call CLASSD
!>
!>*******************************************************************
!>
    call READ_INITIAL_INPUTS( &
!>GENERIC VARIABLES
                             RELEASE, &
!>VARIABLES FOR READ_RUN_OPTIONS
                             IDISP, IZREF, ISLFD, IPCP, IWF, &
                             IPAI, IHGT, IALC, IALS, IALG, ITG, ITC, ITCG, &
                             ICTEMMOD, IOS, PAS, N, IROVAL, WF_NUM_POINTS, &
!  IYEAR_START, IDAY_START, IHOUR_START, IMIN_START, &
!  IYEAR_END,IDAY_END, IHOUR_END, IMIN_END, &
                             IRONAME, GENDIR_OUT, &
!>variables for READ_PARAMETERS_CLASS
                             TITLE1, TITLE2, TITLE3, TITLE4, TITLE5, TITLE6, &
                             NAME1, NAME2, NAME3, NAME4, NAME5, NAME6, &
                             PLACE1, PLACE2, PLACE3, PLACE4, PLACE5, PLACE6, &
                             shd%wc%ILG, NLTEST, NMTEST, JLAT, ICAN, &
                             DEGLAT, DEGLON, &
                             HOURLY_START_DAY, HOURLY_STOP_DAY, &
                             DAILY_START_DAY, DAILY_STOP_DAY, &
                             HOURLY_START_YEAR, HOURLY_STOP_YEAR, &
                             DAILY_START_YEAR, DAILY_STOP_YEAR, &
 !>variables for READ_SOIL_INI
 !>variables for READ_PARAMETERS_HYDROLOGY
                             INDEPPAR, DEPPAR, WF_R2, M_C, &
 !>the types that are to be allocated and initialised
                             shd, op, sl, cp, sv, hp, ts, cm, &
                             SOIL_POR_MAX, SOIL_DEPTH, S0, T_ICE_LENS, fls)

!>
!>***********************************************************************
!> Forcing data time step should not be less than 30 min - there is no
!> any increase in accuracy as delt (CLASS model time step) is 30 min.
!>=======================================================================

!todo: Move this to climate module.
    if (HOURLYFLAG < 30) then
        print 1028
        stop
    end if

1028 format(/1x, 'FORCING DATA TIME STEP IS LESS THAN 30 MIN', &
            /1x, 'AGGREGATE THE FORCING DATA TO 30 MIN INTERVAL AND TRY AGAIN', /)

!>
!>***********************************************************************
!> MAM - Check for parameter values - all parameters should lie within the
!> specified ranges in the "minmax_parameters.txt" file.
!>=======================================================================
!>
    call check_parameters(WF_R2, M_C, NMTEST, cp, hp, soil_por_max, soil_depth, s0, t_ice_lens)

    call init_iter_counter(ic, YEAR_NOW, JDAY_NOW, HOUR_NOW, MINS_NOW, int(DELT))

    !> Assign shed values to local variables.
    NA = shd%NA
    NTYPE = shd%lc%NTYPE
    IGND = shd%lc%IGND

!> CLASS requires that each GRU for each grid square has its own parameter value,
!> for MESH the value read in from the parameter file is assumed to be valid for
!> all grid squares in the study area - Frank Seglenieks Aug 2007

!> bjd - This would be a good spot for setting pre-distributed values

    do i = 2, NA
        cp%ZRFMGRD(i) = cp%ZRFMGRD(1)
        cp%ZRFHGRD(i) = cp%ZRFHGRD(1)
        cp%ZBLDGRD(i) = cp%ZBLDGRD(1)
        cp%GCGRD(i) = cp%GCGRD(1)
        do m = 1, NMTEST
            do j = 1, ICP1
                cp%FCANROW(i, m, j) = cp%FCANROW(1, m, j)
                cp%LNZ0ROW(i, m, j) = cp%LNZ0ROW(1, m, j)
                cp%ALVCROW(i, m, j) = cp%ALVCROW(1, m, j)
                cp%ALICROW(i, m, j) = cp%ALICROW(1, m, j)
            end do
            do j = 1, ICAN
                cp%PAMXROW(i, m, j) = cp%PAMXROW(1, m, j)
                cp%PAMNROW(i, m, j) = cp%PAMNROW(1, m, j)
                cp%CMASROW(i, m, j) = cp%CMASROW(1, m, j)
                cp%ROOTROW(i, m, j) = cp%ROOTROW(1, m, j)
                cp%RSMNROW(i, m, j) = cp%RSMNROW(1, m, j)
                cp%QA50ROW(i, m, j) = cp%QA50ROW(1, m, j)
                cp%VPDAROW(i, m, j) = cp%VPDAROW(1, m, j)
                cp%VPDBROW(i, m, j) = cp%VPDBROW(1, m, j)
                cp%PSGAROW(i, m, j) = cp%PSGAROW(1, m, j)
                cp%PSGBROW(i, m, j) = cp%PSGBROW(1, m, j)
            end do
            do j = 1, IGND
                cp%SANDROW(i, m, j) = cp%SANDROW(1, m, j)
                cp%CLAYROW(i, m, j) = cp%CLAYROW(1, m, j)
                cp%ORGMROW(i, m, j) = cp%ORGMROW(1, m, j)
!> note333 see read_s_temperature_txt.f for more TBARROW information
                cp%TBARROW(i, m, j) = cp%TBARROW(1, m, j)
!> note444 see read_s_moisture_txt.f for more THLQROW information
                cp%THLQROW(i, m, j) = cp%THLQROW(1, m, j)
                cp%THICROW(i, m, j) = cp%THICROW(1, m, j)
            end do
            cp%TCANROW(i, m) = cp%TCANROW(1, m)
            cp%TSNOROW(i, m) = cp%TSNOROW(1, m)
            cp%DRNROW(i, m) = cp%DRNROW(1, m)
            cp%SDEPROW(i, m) = cp%SDEPROW(1, m)
!- FARE is set using
!-            cp%FAREROW(i, m) = cp%FAREROW(1, m)
            cp%MANNROW(i, m) = cp%MANNROW(1, m)
!> note, if drdn (drainage density) is provided from the Mesh_drainage_database.r2c
!> we give the same value for all the GRU that are in one cell
            if (allocated(shd%SLOPE_INT)) then
                cp%XSLPROW(i, m) = shd%SLOPE_INT(i)
                if (i == 2) then
                    cp%XSLPROW(i - 1, m) = shd%SLOPE_INT(i - 1)
                end if
            else
                cp%XSLPROW(i, m) = cp%XSLPROW(1, m)
            end if
            cp%XDROW(i, m) = cp%XDROW(1, m)
!> note, if drdn (drainage density) is provided from the Mesh_drainage_database.r2c
!> we give the same value for all the GRU that are in one cell
            if (allocated(shd%DRDN)) then
                if (i == 2) then
                    cp%DDROW(i - 1, m) = shd%DRDN(i - 1)
                end if
                cp%DDROW(i, m) = shd%DRDN(i)
            else
                cp%DDROW(i, m) = cp%DDROW(1, m)
            end if
!-            WFSFROW(i, m) = WFSFROW(1, m)
            cp%KSROW(i, m) = cp%KSROW(1, m)
            cp%MIDROW(i, m) = cp%MIDROW(1, m)
            cp%TPNDROW(i, m) = cp%TPNDROW(1, m)
            cp%ZPNDROW(i, m) = cp%ZPNDROW(1, m)
            cp%RCANROW(i, m) = cp%RCANROW(1, m)
            cp%SCANROW(i, m) = cp%SCANROW(1, m)
            cp%SNOROW(i, m) = cp%SNOROW(1, m)
            cp%ALBSROW(i, m) = cp%ALBSROW(1, m)
            cp%RHOSROW(i, m) = cp%RHOSROW(1, m)
            cp%GROROW(i, m) = cp%GROROW(1, m)
        end do !m = 1, NMTEST
    end do !i = 2, NA

!     * GATHER-SCATTER COUNTS:
    allocate(shd%lc%ILMOS(shd%lc%ILG), shd%lc%JLMOS(shd%lc%ILG), shd%wc%ILMOS(shd%wc%ILG), &
             shd%wc%JLMOS(shd%wc%ILG), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'gather-scatter count'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        stop
    end if

!> Set value of FAREROW:
!todo - flag this as an issue to explore later and hide basin average code
!todo - document the problem
    TOTAL_AREA = 0.0
    do i = 1, NA
        do m = 1, NTYPE
            cp%FAREROW(i, m) = shd%lc%ACLASS(i, m)*shd%FRAC(i)
            TOTAL_AREA = TOTAL_AREA + cp%FAREROW(i, m)
    !FUTUREDO: Bruce, FRAC is calculated by EnSim
    ! using Dan Princz's instructions for EnSim
    ! FRAC can be greater than 1.00
    ! So, we cannot use FAREROW in place of BASIN_FRACTION
        end do
    end do

    call GATPREP(shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, &
                 shd%lc%NML, shd%wc%NML, cp%GCGRD, cp%FAREROW, cp%MIDROW, &
                 NA, NTYPE, shd%lc%ILG, 1, NA, NMTEST)

    NML = shd%lc%NML

!todo+++: Perhaps land-unit indexing can be done prior in the sequence
!todo+++: of initialization, after reading the drainage database.
!todo+++: Then, variables could be allocated (il1:il2) instead of
!todo+++: (1:ILG) to reduce the memory footprint of the model per node.
!> *********************************************************************
!> Calculate Indices
!> *********************************************************************

    call GetIndices(inp, izero, ipid, shd%lc%NML, shd%lc%ILMOS, il1, il2, ilen)
    if (ro%DIAGNOSEMODE > 0) print 1062, ipid, shd%lc%NML, ilen, il1, il2

1062 format(/1x, 'Configuration and distribution of the domain', &
            /3x, 'Current process: ', i10, &
            /3x, 'Tile land elements: ', i10, &
            /3x, 'Length of single array: ', i10, &
            /3x, 'Starting index: ', i10, &
            /3x, 'Stopping index: ', i10, /)

!>
!>*******************************************************************
!>
!>=======================================================================
!> ALLOCATE ALL VARIABLES
!> DAN * IGND, ICAN, AND ICP1 HAVE BEEN INCLUDED IN CASE THEY WILL BE
!> DAN * CONFIGURABLE IN THE FUTURE (IF IN THE RUN_OPTIONS.INI FILE)
!> DAN * (APR 20/08).

!> ANDY * Allocate some variables
    allocate(WF_NHYD(NA), WF_QR(NA), &
             WF_QBASE(NA), WF_QI2(NA), WF_QO1(NA), WF_QO2(NA), &
             WF_STORE1(NA), WF_STORE2(NA), WF_QI1(NA), SNOGRD(NA))

    !> ANDY * Zero everything we just allocated
    WF_NHYD = 0.0
    WF_QBASE = 0.0
    WF_QI2 = 0.0
    WF_QO1 = 0.0
    WF_QO2 = 0.0
    WF_QR = 0.0
    WF_STORE1 = 0.0
    WF_STORE2 = 0.0
    WF_QI1 = 0.0

1114 format(/1x, 'Error allocating ', a, ' variables.', &
            /1x, 'Check that these bounds are within an acceptable range.', /)
1118 format(3x, a, ': ', i6)

!> MET. FORCING DATA:

!> LAND SURFACE PROGNOSTIC VARIABLES (CLASS.INI):
    allocate(TBARGAT(NML, IGND), &
             THLQGAT(NML, IGND), THICGAT(NML, IGND), &
             SANDGAT(NML, IGND), CLAYGAT(NML, IGND), &
             TBASROW(NA, NTYPE), &
             CMAIROW(NA, NTYPE), TACROW(NA, NTYPE), &
             QACROW(NA, NTYPE), WSNOROW(NA, NTYPE), &
             TPNDGAT(NML), ZPNDGAT(NML), TBASGAT(NML), &
             ALBSGAT(NML), TSNOGAT(NML), RHOSGAT(NML), &
             SNOGAT(NML), TCANGAT(NML), RCANGAT(NML), &
             SCANGAT(NML), &
             GROGAT(NML), FRZCGAT(NML), CMAIGAT(NML), TACGAT(NML), &
             QACGAT(NML), WSNOGAT(NML), &
             TSFSROW(NA, NTYPE, 4), &
             TSFSGAT(NML, 4), stat = PAS)

!> PBSM PROGNOSTIC VARIABLES
    allocate(DrySnowROW(NA, NTYPE), SnowAgeROW(NA, NTYPE), &
             DrySnowGAT(NML), SnowAgeGAT(NML), &
             TSNOdsROW(NA, NTYPE), RHOSdsROW(NA, NTYPE), &
             TSNOdsGAT(NML), RHOSdsGAT(NML), &
             DriftROW(NA, NTYPE), SublROW(NA, NTYPE), DepositionROW(NA, NTYPE), &
             DriftGAT(NML), SublGAT(NML), DepositionGAT(NML), &
             ZSNOCS(NML), ZSNOGS(NML), &
             ZSNOWC(NML), ZSNOWG(NML), &
             HCPSCS(NML), HCPSGS(NML), &
             HCPSC(NML), HCPSG(NML), &
             TSNOWC(NML), TSNOWG(NML), &
             RHOSC(NML), RHOSG(NML), &
             XSNOWC(NML), XSNOWG(NML), &
             XSNOCS(NML), XSNOGS(NML), stat = PAS)

!> LAND SURFACE PROGNOSTIC VARIABLES (for Basin_average_water_balance.csv):
    allocate(TOTAL_THLQ(IGND), TOTAL_THIC(IGND), &
             TOTAL_THLQ_M(IGND), TOTAL_THIC_M(IGND), stat = PAS)

    if (PAS /= 0) then
        print 1114, 'land surface prognostic'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Soil layers', IGND
        stop
    end if

!> **********************************************************************
!>  For cacluating the subbasin grids
!> **********************************************************************

    allocate(SUBBASIN(NML), stat = PAS)

    if (PAS /= 0) then
        print 1114, 'subbasin grid'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        stop
    end if

    allocate(FCANGAT(NML, ICP1), LNZ0GAT(NML, ICP1), &
             ALVCGAT(NML, ICP1), ALICGAT(NML, ICP1), &
             PAIDROW(NA, NTYPE, ICAN), &
             HGTDROW(NA, NTYPE, ICAN), ACVDROW(NA, NTYPE, ICAN), &
             ACIDROW(NA, NTYPE, ICAN), &
             PAMXGAT(NML, ICAN), PAMNGAT(NML, ICAN), &
             CMASGAT(NML, ICAN), ROOTGAT(NML, ICAN), &
             RSMNGAT(NML, ICAN), QA50GAT(NML, ICAN), &
             VPDAGAT(NML, ICAN), VPDBGAT(NML, ICAN), &
             PSGAGAT(NML, ICAN), &
             PSGBGAT(NML, ICAN), PAIDGAT(NML, ICAN), &
             HGTDGAT(NML, ICAN), ACVDGAT(NML, ICAN), &
             ACIDGAT(NML, ICAN), &
             THPROW(NA, NTYPE, IGND), THRROW(NA, NTYPE, IGND), &
             THMROW(NA, NTYPE, IGND), &
             BIROW(NA, NTYPE, IGND), PSISROW(NA, NTYPE, IGND), &
             GRKSROW(NA, NTYPE, IGND), THRAROW(NA, NTYPE, IGND), &
             HCPSROW(NA, NTYPE, IGND), TCSROW(NA, NTYPE, IGND), &
             THFCROW(NA, NTYPE, IGND), &
             PSIWROW(NA, NTYPE, IGND), DLZWROW(NA, NTYPE, IGND), &
             ZBTWROW(NA, NTYPE, IGND), &
             THPGAT(NML, IGND), THRGAT(NML, IGND), &
             THMGAT(NML, IGND), &
             BIGAT(NML, IGND), PSISGAT(NML, IGND), &
             GRKSGAT(NML, IGND), THRAGAT(NML, IGND), &
             HCPSGAT(NML, IGND), TCSGAT(NML, IGND), &
             THFCGAT(NML, IGND), &
             PSIWGAT(NML, IGND), DLZWGAT(NML, IGND), &
             ZBTWGAT(NML, IGND), GFLXGAT(NML, IGND), &
             WFSFROW(NA, NTYPE),  ALGWROW(NA, NTYPE), &
             ALGDROW(NA, NTYPE), ASVDROW(NA, NTYPE), ASIDROW(NA, NTYPE), &
             AGVDROW(NA, NTYPE), &
             AGIDROW(NA, NTYPE), &
             DRNGAT(NML), XSLPGAT(NML), XDGAT(NML), &
             WFSFGAT(NML), KSGAT(NML), ALGWGAT(NML), &
             ALGDGAT(NML), ASVDGAT(NML), ASIDGAT(NML), &
             AGVDGAT(NML), &
             AGIDGAT(NML), ZSNLGAT(NML), ZPLGGAT(NML), &
             ZPLSGAT(NML), SDEPGAT(NML), FAREGAT(NML), &
             ISNDROW(NA, NTYPE, IGND), IORG(NA, NTYPE, IGND), &
             ISNDGAT(NML, IGND), IGDRROW(NA,NTYPE), &
             IGDRGAT(NML), &
             fetchGAT(NML), HtGAT(NML), N_SGAT(NML), A_SGAT(NML), &
             DistribGAT(NML), stat = PAS)

    if (PAS /= 0) then
        print 1114, 'canopy and soil info.'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        print 1118, 'Canopy types with urban areas', ICP1
        print 1118, 'Canopy types', ICAN
        print 1118, 'Soil layers', IGND
        stop
    end if

!> WATROF FLAGS AND VARIABLES:
    allocate(DDGAT(NML), MANNGAT(NML), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'WATROF'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        stop
    end if

!> ATMOSPHERIC AND GRID-CONSTANT INPUT VARIABLES:
    allocate(ZDMGRD(NA), &
             ZDHGRD(NA), RADJGRD(NA), &
             CSZGRD(NA), &
             PADRGRD(NA), VPDGRD(NA), &
             TADPGRD(NA), RHOAGRD(NA), RPCPGRD(NA), TRPCGRD(NA), &
             SPCPGRD(NA), TSPCGRD(NA), RHSIGRD(NA), &
             FCLOGRD(NA), DLONGRD(NA), Z0ORGRD(NA), GGEOGRD(NA), UVGRD(NA), &
             XDIFFUS(NA), &
             RPREGRD(NA), SPREGRD(NA), VMODGRD(NA), &
             ZRFMGAT(NML), ZRFHGAT(NML), ZDMGAT(NML), &
             ZDHGAT(NML), ZBLDGAT(NML), &
             RADJGAT(NML), CSZGAT(NML), &
             RPREGAT(NML), SPREGAT(NML), &
             PADRGAT(NML), VPDGAT(NML), &
             TADPGAT(NML), RHOAGAT(NML), RPCPGAT(NML), &
             TRPCGAT(NML), SPCPGAT(NML), TSPCGAT(NML), &
             RHSIGAT(NML), &
             FCLOGAT(NML), DLONGAT(NML), Z0ORGAT(NML), &
             GGEOGAT(NML), VMODGAT(NML), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'atmospheric and grid-cst.'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        stop
    end if

!> LAND SURFACE DIAGNOSTIC VARIABLES:
    allocate(CDHROW(NA, NTYPE), CDMROW(NA, NTYPE), &
             HFSROW(NA, NTYPE), &
             TFXROW(NA, NTYPE), QEVPROW(NA, NTYPE), QFSROW(NA, NTYPE), &
             QFXROW(NA, NTYPE), PETROW(NA, NTYPE), GAROW(NA, NTYPE), &
             EFROW(NA, NTYPE), GTROW(NA, NTYPE), &
             QGROW(NA, NTYPE), TSFROW(NA, NTYPE), ALVSROW(NA, NTYPE), &
             ALIRROW(NA, NTYPE), FSNOROW(NA, NTYPE), SFCTROW(NA, NTYPE), &
             SFCUROW(NA, NTYPE), &
             SFCVROW(NA, NTYPE), SFCQROW(NA, NTYPE), FSGVROW(NA, NTYPE), &
             FSGSROW(NA, NTYPE), FSGGROW(NA, NTYPE), FLGVROW(NA, NTYPE), &
             FLGSROW(NA, NTYPE), &
             FLGGROW(NA, NTYPE), HFSCROW(NA, NTYPE), HFSSROW(NA, NTYPE), &
             HFSGROW(NA, NTYPE), HEVCROW(NA, NTYPE), HEVSROW(NA, NTYPE), &
             HEVGROW(NA, NTYPE), &
             HMFCROW(NA, NTYPE), HMFNROW(NA, NTYPE), HTCCROW(NA, NTYPE), &
             HTCSROW(NA, NTYPE), PCFCROW(NA, NTYPE), PCLCROW(NA, NTYPE), &
             PCPNROW(NA, NTYPE), &
             PCPGROW(NA, NTYPE), QFGROW(NA, NTYPE), QFNROW(NA, NTYPE), &
             QFCLROW(NA, NTYPE), QFCFROW(NA, NTYPE), ROFROW(NA, NTYPE), &
             ROFOROW(NA, NTYPE), &
             ROFSROW(NA, NTYPE), ROFBROW(NA, NTYPE), ROFCROW(NA, NTYPE), &
             ROFNROW(NA, NTYPE), ROVGROW(NA, NTYPE), WTRCROW(NA, NTYPE), &
             WTRSROW(NA, NTYPE), &
             WTRGROW(NA, NTYPE), DRROW(NA, NTYPE), WTABROW(NA, NTYPE), &
             ILMOROW(NA, NTYPE), UEROW(NA, NTYPE), HBLROW(NA, NTYPE), &
             TROFROW(NA, NTYPE), &
             TROOROW(NA, NTYPE), TROSROW(NA, NTYPE), TROBROW(NA, NTYPE), &
             CDHGAT(NML), CDMGAT(NML), HFSGAT(NML), &
             TFXGAT(NML), QEVPGAT(NML), QFSGAT(NML), &
             QFXGAT(NML), PETGAT(NML), GAGAT(NML), &
             EFGAT(NML), GTGAT(NML), &
             QGGAT(NML), ALVSGAT(NML), &
             ALIRGAT(NML), FSNOGAT(NML), SFRHGAT(NML), SFCTGAT(NML), &
             SFCUGAT(NML), &
             SFCVGAT(NML), SFCQGAT(NML), FSGVGAT(NML), &
             FSGSGAT(NML), FSGGGAT(NML), FLGVGAT(NML), &
             FLGSGAT(NML), &
             FLGGGAT(NML), HFSCGAT(NML), HFSSGAT(NML), &
             HFSGGAT(NML), HEVCGAT(NML), HEVSGAT(NML), &
             HEVGGAT(NML), &
             HMFCGAT(NML), HMFNGAT(NML), HTCCGAT(NML), &
             HTCSGAT(NML), PCFCGAT(NML), PCLCGAT(NML), &
             PCPNGAT(NML), &
             PCPGGAT(NML), QFGGAT(NML), QFNGAT(NML), &
             QFCLGAT(NML), QFCFGAT(NML), ROFGAT(NML), &
             ROFOGAT(NML), &
             ROFSGAT(NML), ROFBGAT(NML), ROFCGAT(NML), &
             ROFNGAT(NML), ROVGGAT(NML), WTRCGAT(NML), &
             WTRSGAT(NML), &
             WTRGGAT(NML), DRGAT(NML), WTABGAT(NML), &
             ILMOGAT(NML), UEGAT(NML), HBLGAT(NML), QLWOGAT(NML), &
             FTEMP(NML),   FVAP(NML),  RIB(NML), TROFGAT(NML), &
             TROOGAT(NML), TROSGAT(NML), TROBGAT(NML), &
             CDHGRD(NA), CDMGRD(NA), HFSGRD(NA), &
             TFXGRD(NA), QEVPGRD(NA), QFSGRD(NA), QFXGRD(NA), PETGRD(NA), &
             GAGRD(NA), EFGRD(NA), GTGRD(NA), &
             QGGRD(NA), TSFGRD(NA), ALVSGRD(NA), ALIRGRD(NA), FSNOGRD(NA), &
             SFCTGRD(NA), SFCUGRD(NA), &
             SFCVGRD(NA), SFCQGRD(NA), FSGVGRD(NA), FSGSGRD(NA), &
             FSGGGRD(NA), FLGVGRD(NA), FLGSGRD(NA), &
             FLGGGRD(NA), HFSCGRD(NA), HFSSGRD(NA), HFSGGRD(NA), &
             HEVCGRD(NA), HEVSGRD(NA), HEVGGRD(NA), &
             HMFCGRD(NA), HMFNGRD(NA), HTCCGRD(NA), HTCSGRD(NA), &
             PCFCGRD(NA), PCLCGRD(NA), PCPNGRD(NA), &
             PCPGGRD(NA), QFGGRD(NA), QFNGRD(NA), QFCLGRD(NA), QFCFGRD(NA), &
             ROFGRD(NA), ROFOGRD(NA), &
             ROFSGRD(NA), ROFBGRD(NA), ROFCGRD(NA), ROFNGRD(NA), &
             ROVGGRD(NA), WTRCGRD(NA), WTRSGRD(NA), &
             WTRGGRD(NA), DRGRD(NA), WTABGRD(NA), ILMOGRD(NA), UEGRD(NA), &
             HBLGRD(NA), &
             HMFGROW(NA, NTYPE, IGND), HTCROW(NA, NTYPE, IGND), &
             QFCROW(NA, NTYPE, IGND), GFLXROW(NA, NTYPE, IGND), &
             HMFGGAT(NML, IGND), HTCGAT(NML, IGND), &
             QFCGAT(NML, IGND), &
             HMFGGRD(NA, IGND), HTCGRD(NA, IGND), QFCGRD(NA, IGND), &
             GFLXGRD(NA, IGND), &
             ITCTROW(NA, NTYPE, 6, 50), &
             ITCTGAT(NML, 6, 50), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'land surface diagnostic'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        print 1118, 'Soil layers', IGND
        stop
    end if

!> OUTPUT VARIABLES:
    allocate(PREACC(NA), GTACC(NA), QEVPACC(NA), &
             HFSACC(NA), ROFACC(NA), SNOACC(NA), ALVSACC(NA), ALIRACC(NA), &
             FSINACC(NA), FLINACC(NA), &
             TAACC(NA), UVACC(NA), PRESACC(NA), QAACC(NA), EVAPACC(NA), &
             FLUTACC(NA), ROFOACC(NA), &
             ROFSACC(NA), ROFBACC(NA), HMFNACC(NA), WTBLACC(NA), ZPNDACC(NA), &
             WSNOACC(NA), RHOSACC(NA), TSNOACC(NA), &
             TCANACC(NA), RCANACC(NA), SCANACC(NA), GROACC(NA), CANARE(NA), &
             SNOARE(NA), &
             TBARACC(NA, IGND), THLQACC(NA, IGND), THICACC(NA, IGND), &
             THALACC(NA, IGND), GFLXACC(NA, IGND), &
             STG_I(NA), DSTG(NA), THLQ_FLD(NA, IGND), THIC_FLD(NA, IGND), &
             stat = PAS)
    if (PAS /= 0) then
        print 1114, 'accumulator'
        print 1118, 'Grid squares', NA
        print 1118, 'Soil layers', IGND
        stop
    end if

!> CROSS-CLASS VARIABLES (CLASS):
    allocate(TBARC(NML, IGND), TBARG(NML, IGND), &
             TBARCS(NML, IGND), &
             TBARGS(NML, IGND), THLIQC(NML, IGND), &
             THLIQG(NML, IGND), THICEC(NML, IGND), &
             THICEG(NML, IGND), FROOT(NML, IGND), &
             HCPC(NML, IGND), HCPG(NML, IGND), &
             TCTOPC(NML, IGND), TCBOTC(NML, IGND), &
             TCTOPG(NML, IGND), TCBOTG(NML, IGND), &
             FC(NML), FG(NML), FCS(NML), &
             FGS(NML), RBCOEF(NML), &
             ZSNOW(NML), &
             FSVF(NML), FSVFS(NML), ALVSCN(NML), &
             ALIRCN(NML), ALVSG(NML), &
             ALIRG(NML), ALVSCS(NML), ALIRCS(NML), &
             ALVSSN(NML), ALIRSN(NML), ALVSGC(NML), &
             ALIRGC(NML), ALVSSC(NML), &
             ALIRSC(NML), TRVSCN(NML), TRIRCN(NML), &
             TRVSCS(NML), TRIRCS(NML), RC(NML), &
             RCS(NML), FRAINC(NML), &
             FSNOWC(NML),FRAICS(NML),FSNOCS(NML), &
             CMASSC(NML), CMASCS(NML), &
             DISP(NML), DISPS(NML), ZOMLNC(NML), &
             ZOELNC(NML), ZOMLNG(NML), &
             ZOELNG(NML), ZOMLCS(NML), ZOELCS(NML), &
             ZOMLNS(NML), ZOELNS(NML), TRSNOW(NML), &
             CHCAP(NML), CHCAPS(NML), &
             GZEROC(NML), GZEROG(NML), GZROCS(NML), &
             GZROGS(NML), G12C(NML), G12G(NML), &
             G12CS(NML), G12GS(NML), G23C(NML), &
             G23G(NML), G23CS(NML), G23GS(NML), &
             QFREZC(NML), QFREZG(NML), QMELTC(NML), &
             QMELTG(NML), EVAPC(NML), &
             EVAPCG(NML), EVAPG(NML), EVAPCS(NML), &
             EVPCSG(NML), EVAPGS(NML), TCANO(NML), &
             TCANS(NML), RAICAN(NML), &
             SNOCAN(NML), RAICNS(NML), SNOCNS(NML), &
             CWLCAP(NML), CWFCAP(NML), CWLCPS(NML), &
             CWFCPS(NML), TSNOCS(NML), &
             TSNOGS(NML), RHOSCS(NML), RHOSGS(NML), &
             WSNOCS(NML), WSNOGS(NML), TPONDC(NML), &
             TPONDG(NML), TPNDCS(NML), &
             TPNDGS(NML), ZPLMCS(NML), ZPLMGS(NML), &
             ZPLIMC(NML), ZPLIMG(NML), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'cross-CLASS'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        print 1118, 'Soil layers', IGND
        stop
    end if

!> BALANCE ERRORS (CLASS):
    allocate(CTVSTP(NML), CTSSTP(NML), &
             CT1STP(NML), &
             CT2STP(NML), CT3STP(NML), WTVSTP(NML), &
             WTSSTP(NML), WTGSTP(NML), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'balance error diagnostic'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        stop
    end if

!> CTEM ERRORS (CLASS):
    allocate(CO2CONC(NML), COSZS(NML), XDIFFUSC(NML), CFLUXCG(NML), CFLUXCS(NML), &
             AILCG(NML, ICTEM), AILCGS(NML, ICTEM), FCANC(NML, ICTEM), FCANCS(NML, ICTEM), &
             CO2I1CG(NML, ICTEM), CO2I1CS(NML, ICTEM), CO2I2CG(NML, ICTEM), CO2I2CS(NML, ICTEM), &
             SLAI(NML, ICTEM), FCANCMX(NML, ICTEM), ANCSVEG(NML, ICTEM), ANCGVEG(NML, ICTEM), &
             RMLCSVEG(NML, ICTEM), RMLCGVEG(NML, ICTEM), &
             AILC(NML, ICAN), PAIC(NML, ICAN), FIELDSM(NML, IGND), WILTSM(NML, IGND), &
             RMATCTEM(NML, ICTEM, IGND), RMATC(NML, ICAN, IGND), NOL2PFTS(ICAN), stat = PAS)
    if (PAS /= 0) then
        print 1114, 'CTEM'
        print 1118, 'Grid squares', NA
        print 1118, 'GRUs', NTYPE
        print 1118, 'Total tile elements', NML
        print 1118, 'Canopy types', ICAN
        print 1118, 'Soil layers', IGND
        print 1118, 'CTEM flag', ICTEM
        stop
    end if

!> *********************************************************************
!>  Open additional output files
!> *********************************************************************

    if (ipid == 0 .and. BASINSWEOUTFLAG > 0) then
        open(85, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/basin_SCA_alldays.csv')
        open(86, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/basin_SWE_alldays.csv')
    end if !(BASINSWEOUTFLAG > 0) then

    if (ipid == 0) call run_between_grid_config(shd, ts, ic)

!> *********************************************************************
!>  Open and read in values from MESH_input_reservoir.txt file
!> *********************************************************************

    open(21, file = 'MESH_input_reservoir.txt', status = 'old', action = 'read')
    read(21, '(3i5)') WF_NORESV, WF_NREL, WF_KTR
    WF_NORESV_CTRL = 0

! allocate reservoir arrays
    M_R = WF_NORESV
    allocate(WF_IRES(M_R), WF_JRES(M_R), WF_RES(M_R), WF_R(M_R), WF_B1(M_R), WF_B2(M_R), &
             WF_QREL(M_R), WF_RESSTORE(M_R), WF_RESNAME(M_R))

    if (WF_NORESV > 0) then
        do i = 1, WF_NORESV
! KCK Added to allow higher precision gauge sites    
            if (LOCATIONFLAG == 1) then
                read(21, '(2f7.1, 2g10.3, 25x, a12, i2)') I_G, J_G, WF_B1(i), WF_B2(i), WF_RESNAME(i), WF_RES(i)
                WF_IRES(i) = nint((I_G - shd%yOrigin*60.0)/shd%GRDN)
                WF_JRES(i) = nint((J_G - shd%xOrigin*60.0)/shd%GRDE)
            else
                read(21, '(2i5, 2g10.3, 25x, a12, i2)') WF_IRES(i), WF_JRES(i), WF_B1(i), WF_B2(i), WF_RESNAME(i), WF_RES(i)
                WF_IRES(i) = int((real(WF_IRES(i)) - real(shd%iyMin))/shd%GRDN + 1.0)
                WF_JRES(i) = int((real(WF_JRES(i)) - real(shd%jxMin))/shd%GRDE + 1.0)
            end if
!> check if point is in watershed and in river reaches
            WF_R(i) = 0
            do j = 1, NA
                if (WF_IRES(i) == shd%yyy(j) .and. WF_JRES(i) == shd%xxx(j)) then
                    WF_R(i) = j
                end if
            end do
            if (WF_R(i) == 0) then
                print *, 'Reservoir Station: ', i, ' is not in the basin'
                print *, 'Up/Down Coordinate: ', wf_ires(i), shd%iyMin
                print *, 'Left/Right Coordinate: ', wf_jres(i), shd%jxMin
                stop
            end if
            if (shd%IREACH(WF_R(i)) /= i) then
                print *, 'Reservoir Station: ', i, ' is not in the correct reach'
                print *, 'Up/Down Coordinate: ', wf_ires(i)
                print *, 'Left/Right Coordinate: ', wf_jres(i)
                print *, 'ireach value at station: ', wf_iy(i)
                stop
            end if
            if (WF_B1(i) == 0.0) then
                WF_NORESV_CTRL = WF_NORESV_CTRL + 1
            end if
        end do
    end if
!> leave file open and read in the reservoir files when needed

!> *********************************************************************
!> Open and read in values from MESH_input_streamflow.txt file
!> *********************************************************************

    open(22, file = 'MESH_input_streamflow.txt', status = 'old', action = 'read')
    read(22, *)
    read(22, *) WF_NO, WF_NL, WF_MHRD, WF_KT, WF_START_YEAR, WF_START_DAY, WF_START_HOUR

! Allocate variable based on value from streamflow file
    M_S = WF_NO !todo M_S is same as WF_NO and could be removed.

    allocate(WF_IY(M_S), WF_JX(M_S), WF_S(M_S), WF_QHYD(M_S), WF_QHYD_AVG(M_S), WF_QHYD_CUM(M_S), &
             WF_QSYN(M_S), WF_QSYN_AVG(M_S), WF_QSYN_CUM(M_S), WF_GAGE(M_S))

    do i = 1, WF_NO
        if (LOCATIONFLAG == 1) then
            read(22, *) I_G, J_G, WF_GAGE(i)
            WF_IY(i) = nint((I_G - shd%yOrigin*60.0)/shd%GRDN)
            WF_JX(i) = nint((J_G - shd%xOrigin*60.0)/shd%GRDE)
        else
            read(22, *) WF_IY(i), WF_JX(i), WF_GAGE(i)
            WF_IY(i) = int((real(WF_IY(i)) - real(shd%iyMin))/shd%GRDN + 1.0)
            WF_JX(i) = int((real(WF_JX(i)) - real(shd%jxMin))/shd%GRDE + 1.0)
        end if
    end do
    do i = 1, WF_NO
        WF_S(i) = 0
        do j = 1, NA
            if (WF_JX(i) == shd%xxx(j) .and. WF_IY(i) == shd%yyy(j)) then
                WF_S(i) = j
            end if
        end do
        if (WF_S(i) == 0) then
            print *, 'STREAMFLOW GAUGE: ', i, ' IS NOT IN THE BASIN'
            print *, 'UP/DOWN', WF_IY(i), shd%iyMin, shd%yyy(j), shd%yCount
            print *, 'LEFT/RIGHT', WF_JX(i), shd%jxMin, shd%xxx(j), shd%xCount
            stop
        end if
    end do

!> ric     initialise smoothed variables
    wf_qsyn = 0.0
    WF_QSYN_AVG = 0.0
    wf_qhyd_avg = 0.0
    wf_qsyn_cum = 0.0
    wf_qhyd_cum = 0.0

!>MAM - The first stream flow record is used for flow initialization
    read(22, *, iostat = IOS) (WF_QHYD(i), i = 1, WF_NO)

      ! fixed streamflow start time bug. add in function to enable the
      ! correct start time. Feb2009 aliu.
    call Julian_Day_ID(WF_START_YEAR, WF_START_day, Jday_IND1)
    call Julian_Day_ID(YEAR_START, JDAY_START, Jday_IND2)
!    print *, WF_START_YEAR, WF_START_day, Jday_IND1
    if (YEAR_START == 0) then
        Jday_IND2 = Jday_IND1
    end if
    if (Jday_IND2 < Jday_IND1) then
        print *, 'ERROR: Simulation start date too early, check ', &
            ' MESH_input_streamflow.txt, The start date in ', &
            ' MESH_input_run_options.ini may be out of range'
        stop
    end if
    jday_ind_strm = (jday_ind2 - jday_ind1)*24/WF_KT

         !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
         !skip the unused streamflow records in streamflow.txt .
    do j = 1, jday_ind_strm
        read(22, *, iostat = IOS)
        if (IOS < 0) then
            print *, 'ERROR: end of file reached when reading ', &
                ' MESH_input_streamflow.txt, The start date in ', &
                ' MESH_input_run_options.ini may be out of range'
            stop
        end if
    end do
          !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    print *, 'Skipping', jday_ind_strm, 'Registers in streamflow file'
!> leave unit open and read new streamflow each hour

!todo - verify that all checks are needed and in the right spot
!> *********************************************************************
!> Check to make sure input values are consistent
!> *********************************************************************

!> compare land classes in class.ini and drainage database files
    if (NTYPE /= NMTEST .and. NTYPE > 0) then
        print *, 'land classes from MESH_parameters_CLASS.ini: ', NMTEST
        print *, 'land classes from MESH_drainage_database.txt:', NTYPE
        print *, 'Please adjust these values.'
        stop
    end if

!> check that run points are in the basin and that there are no repeats
    do i = 1, WF_NUM_POINTS
        if (op%N_OUT(i) > NA) then
            print *, 'No. of grids from MESH_drainage_database.txt:', NA
            print *, 'out point ', i, ' is: ', op%N_OUT(i)
            print *, 'please adjust MESH_run_options.ini file'
            stop
        end if
        if (i < WF_NUM_POINTS) then
            do j = i + 1, WF_NUM_POINTS
                if (op%N_OUT(i) == op%N_OUT(j) .and. op%II_OUT(i) == op%II_OUT(j)) then
                    print *, 'grid number ', op%N_OUT(i)
                    print *, 'is repeated in MESH_run_options.ini file'
                    print *, 'please adjust MESH_run_options.ini file'
                    stop
                end if
            end do
        end if
    end do

!> *********************************************************************
!> Set some more intial values and clear accumulators
!> *********************************************************************

    !> Read an intial value for geothermal flux from file.
    if (GGEOFLAG == 1) then
        iun = fls%fl(mfk%f18)%iun
        open(iun, file = trim(adjustl(fls%fl(mfk%f18)%fn)), status = 'old', action = 'read', iostat = ios)
        read(iun, *) GGEOGRD(1)
        close(iun)
    else
        GGEOGRD(1) = 0.0
    end if

!> ASSIGN VALUES OF LAT/LONG TO EACH SQUARE:
!> NOTE FROM FRANK
!> I got the equations to determine the actual length of a 
!> degree of latitude and longitude from this paper, thank you 
!> Geoff Kite (I have attached it):
!> http://www.agu.org/pubs/crossref/1994/94WR00231.shtml
!> This chunk of code is a way to put the actual values of 
!> longitude and latitude for each cell in a large basin.  
!> The original CLASS code just put in the same value for each cell.  
!> The problem is that the class.ini file only has a single value 
!> of long and lat (as it was only designed for a point).  So in order 
!> to get the values across the basin I assumed that the single value 
!> from the class.ini file is in the centre of the basin and then use 
!> information from the watflow.shd file to figure out the long/lat 
!> varies across the basin.  However, the watflod.shd file only gives 
!> information in kilometers not degrees of long/lat so I had 
!> to use the formulas from the above paper to go between the two.
!
!> The only value of DEGLAT is the one read in from the class.ini file, 
!> after that Diana uses RADJGRD (the value of latitude in radians) so 
!> after DEGLAT is used to calculate RADJGRD is it no longer used.  This 
!> is how it was in the original CLASS code.

	do i = 1, NA
        !LATLENGTH = shd%AL/1000.0/(111.136 - 0.5623*cos(2*(DEGLAT*PI/180.0)) + 0.0011*cos(4*(DEGLAT*PI/180.0)))
        !LONGLENGTH = shd%AL/1000.0/(111.4172*cos((DEGLAT*PI/180.0)) - 0.094*cos(3*(DEGLAT*PI/180.0)) + 0.0002*cos(5*(DEGLAT*PI/180.0)))
        RADJGRD(i) = ((shd%yOrigin + shd%yDelta*shd%yyy(i)) - shd%yDelta/2.0)*PI/180.0
        DLONGRD(i) = (shd%xOrigin + shd%xDelta*shd%xxx(i)) - shd%xDelta/2.0
        Z0ORGRD(i) = 0.0
        GGEOGRD(i) = GGEOGRD(1)
        ZDMGRD(i) = 10.0
        ZDHGRD(i) = 2.0
	end do

!> adjust NAA to the be number of outlet squares, as currently it is the
!> number of squares with outlets into other squares in the basin, and
!> we want it to be the number of squares with outlets to outside the
!> basin.
!todo - look into the logic of this and suggest how it could be changed
    shd%NAA = NA - shd%NAA

!> set initial values of ncount and nsum
! NCOUNT = which half-hour period the current time is:
! The first period (0:00-0:30) is #1, the last period (23:30-0:00) is #48
    NCOUNT = HOUR_NOW*2 + MINS_NOW/TIME_STEP_MINS + 1
    NSUM = 1
    NSUM_TOTAL = 1

!> **********************************************************************
!>  Start of section to only run on squares that make up the watersheds
!>  that are listed in the streamflow file (subbasin)
!> **********************************************************************

    if (SUBBASINFLAG > 0) then
        do i = 1, NA
            SUBBASIN(i) = 0
        end do

!> Set values at guages to 1
        do i = 1, WF_NO
            SUBBASIN(WF_S(i)) = 1
        end do

!> Set values of subbasin to 1 for all upstream grids
        SUBBASINCOUNT = 1
        do while (SUBBASINCOUNT > 0)
            SUBBASINCOUNT = 0
            do i = 1, NA - 1
                if (SUBBASIN(shd%NEXT(i)) == 1 .and. SUBBASIN(i) == 0) then
                    SUBBASIN(i) = 1
                    SUBBASINCOUNT = SUBBASINCOUNT + 1
                end if
            end do
        end do !while (SUBBASINCOUNT > 0)

!> Set values of frac to 0 for all grids non-upstream grids
        SUBBASINCOUNT = 0
        do i = 1, NA
            if (SUBBASIN(i) == 0) then
                shd%FRAC(i) = 0.0
            else
                SUBBASINCOUNT = SUBBASINCOUNT + 1
            end if
        end do

  !> MAM - Write grid number, grid fractional area and percentage of GRUs in each grid
        open(10, file = 'subbasin_info.txt')
        write(10, '(a7, 3x, a18, 3x, a58)') &
            'GRID NO', 'GRID AREA FRACTION', 'GRU FRACTIONS, GRU 1, GRU 2, GRU 3,... IN INCREASING ORDER'
        do i = 1, NA
            if (SUBBASIN(i) == 0) then
            else
                write(10, '(i5, 3x, f10.3, 8x, 50(f10.3, 3x))') i, shd%FRAC(i), (shd%lc%ACLASS(i, m), m = 1, NMTEST)
            end if
        end do
        close(10)

    end if !(SUBBASINFLAG > 0) then

!> **********************************************************************
!>  End of subbasin section
!> **********************************************************************

!> Initialize output variables.
    call init_water_balance(wb, shd)
    wb%grid_area = 0.0
    wb%basin_area = 0.0
    do i = 1, NA
        do m = 1, NMTEST
            wb%grid_area(i) = wb%grid_area(i) + cp%FAREROW(i, m)
        end do
        wb%basin_area = wb%basin_area + wb%grid_area(i)
    end do

    call climate_module_init(shd, ts, cm, NML, il1, il2, ENDDATA)
    if (ENDDATA) goto 999

!> *********************************************************************
!> Initialize water balance output fields
!> *********************************************************************

    if (ipid == 0) then
        call init_energy_balance(eng, shd)
        call init_soil_statevars(sov, shd)
        call init_met_data(md, shd)
        call init_water_balance(wb_h, shd)
        if (OUTFIELDSFLAG == 1) call init_out(shd, ts, ic, ifo, vr)
    end if !(ipid == 0) then

!> routing parameters
    WF_ROUTETIMESTEP = 900
    WF_TIMECOUNT = 0
    DRIVERTIMESTEP = DELT    ! Be sure it's REAL*8

!* JAN: The first time throught he loop, jan = 1. Jan will equal 2 after that.
    JAN = 1

!todo - check that this is compatible with Saul's pre-distributed soil moisture and soil temp.
    do i = 1, NA
        do m = 1, NMTEST
            do j = 1, IGND
                cp%TBARROW(i, m, j) = cp%TBARROW(i, m, j) + TFREZ
            end do
            cp%TSNOROW(i, m) = cp%TSNOROW(i, m) + TFREZ
            cp%TCANROW(i, m) = cp%TCANROW(i, m) + TFREZ
            cp%TPNDROW(i, m) = cp%TPNDROW(i, m) + TFREZ
            TBASROW(i, m) = cp%TBARROW(i, m, IGND)
            CMAIROW(i, m) = 0.0
            WSNOROW(i, m) = 0.0
            TSFSROW(i, m, 1) = TFREZ
            TSFSROW(i, m, 2) = TFREZ
            TSFSROW(i, m, 3) = cp%TBARROW(i, m, 1)
            TSFSROW(i, m, 4) = cp%TBARROW(i, m, 1)
            TACROW(i, m) = cp%TCANROW(i, m)
            QACROW(i, m) = 0.5e-2
            if (IGND > 3) then ! should stay this way to work with class

                !todo - if we have time, change this so that soil.ini can take more than 3 layers.
                if (NRSOILAYEREADFLAG == 0) then
                    do j = 4, IGND
                        cp%THLQROW(i, m, j) = cp%THLQROW(i, m, 3)
                        cp%THICROW(i, m, j) = cp%THICROW(i, m, 3)
                        cp%TBARROW(i, m, j) = cp%TBARROW(i, m, 3)
                        if (cp%SDEPROW(i, m) < (sl%ZBOT(j - 1) + 0.001) .and. cp%SANDROW(i, m, 3) > -2.5) then
                            cp%SANDROW(i, m, j) = -3.0
                            cp%CLAYROW(i, m, j) = -3.0
                            cp%ORGMROW(i, m, j) = -3.0
                        else
                            cp%SANDROW(i, m, j) = cp%SANDROW(i, m, 3)
                            cp%CLAYROW(i, m, j) = cp%CLAYROW(i, m, 3)
                            cp%ORGMROW(i, m, j) = cp%ORGMROW(i, m, 3)
                        end if
                    end do
                else
                    do j = 4, IGND
                        if (cp%SDEPROW(i, m) < (sl%ZBOT(j - 1) + 0.001) .and. cp%SANDROW(i, m, 3) > -2.5) then
                            cp%SANDROW(i, m, j) = -3.0
                            cp%CLAYROW(i, m, j) = -3.0
                            cp%ORGMROW(i, m, j) = -3.0
                        end if
                    end do
                end if !if (NRSOILAYEREADFLAG == 0) then
            end if !(IGND > 3) then
            do k = 1, 6
                do l = 1, 50
                    ITCTROW(i, m, k, l) = 0
                end do
            end do
        end do !m = 1, NMTEST
    end do !i = 1, NA

!> clear accumulating variables
    TOTAL_ROF = 0.0
    TOTAL_ROFO = 0.0
    TOTAL_ROFS = 0.0
    TOTAL_ROFB = 0.0
    TOTAL_EVAP = 0.0
    TOTAL_PRE = 0.0
    TOTAL_ROFACC = 0.0
    TOTAL_ROFOACC = 0.0
    TOTAL_ROFSACC = 0.0
    TOTAL_ROFBACC = 0.0
    TOTAL_EVAPACC = 0.0
    TOTAL_PREACC = 0.0
    TOTAL_HFSACC = 0.0
    TOTAL_QEVPACC = 0.0

    ! For monthly totals.
    TOTAL_ROF_M = 0.0
    TOTAL_ROFO_M = 0.0
    TOTAL_ROFS_M = 0.0
    TOTAL_ROFB_M = 0.0
    TOTAL_EVAP_M = 0.0
    TOTAL_PRE_M = 0.0
    TOTAL_ROF_ACC_M = 0.0
    TOTAL_ROFO_ACC_M = 0.0
    TOTAL_ROFS_ACC_M = 0.0
    TOTAL_ROFB_ACC_M = 0.0
    TOTAL_EVAP_ACC_M = 0.0
    TOTAL_PRE_ACC_M = 0.0

!> *********************************************************************
!> Set accumulation variables to zero.
!> *********************************************************************

  !> Grid Variables
    PREACC = 0.0
    GTACC = 0.0
    QEVPACC = 0.0
    EVAPACC = 0.0
    HFSACC = 0.0
    HMFNACC = 0.0
    ROFACC = 0.0
    ROFOACC = 0.0
    ROFSACC = 0.0
    ROFBACC = 0.0
    WTBLACC = 0.0
    ALVSACC = 0.0
    ALIRACC = 0.0
    RHOSACC = 0.0
    SNOACC = 0.0
    WSNOACC = 0.0
    CANARE = 0.0
    SNOARE = 0.0
    TSNOACC = 0.0
    TCANACC = 0.0
    RCANACC = 0.0
    SCANACC = 0.0
    GROACC = 0.0
    FSINACC = 0.0
    FLINACC = 0.0
    FLUTACC = 0.0
    TAACC = 0.0
    UVACC = 0.0
    PRESACC = 0.0
    QAACC = 0.0

    !> Soil variables
    TBARACC = 0.0
    THLQACC = 0.0
    THICACC = 0.0
    THALACC = 0.0
    GFLXACC = 0.0

    STG_I = 0.0
    DSTG = 0.0
    THLQ_FLD = 0.0
    THIC_FLD = 0.0

    FRAME_NO_NEW = 1

    if (ipid == 0) then

!> ******************************************************
!> echo print information to MESH_output_echo_print.txt
!> ******************************************************

        if (MODELINFOOUTFLAG > 0) then
            open(58, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/MESH_output_echo_print.txt')
            write(58, "('Number of Soil Layers (IGND) = ', i5)") IGND
            write(58, *)
            write(58, "('MESH_input_run_options.ini')")
            write(58, *)
            write(58, "('Configuration flags - specified by user or default values')")

        !todo: this list should be updated (dgp: 2015-01-09)
            write(58, *) 'BASINSHORTWAVEFLAG   = ', cm%clin(cfk%FB)%filefmt
            write(58, *) 'BASINLONGWAVEFLAG    = ', cm%clin(cfk%FI)%filefmt
            write(58, *) 'BASINRAINFLAG        = ', cm%clin(cfk%PR)%filefmt
            write(58, *) 'BASINTEMPERATUREFLAG = ', cm%clin(cfk%TT)%filefmt
            write(58, *) 'BASINWINDFLAG        = ', cm%clin(cfk%UV)%filefmt
            write(58, *) 'BASINPRESFLAG        = ', cm%clin(cfk%P0)%filefmt
            write(58, *) 'BASINHUMIDITYFLAG    = ', cm%clin(cfk%HU)%filefmt
            write(58, *) 'HOURLYFLAG           = ', HOURLYFLAG
            write(58, *) 'RESUMEFLAG           = ', RESUMEFLAG
            write(58, *) 'SAVERESUMEFLAG       = ', SAVERESUMEFLAG
            write(58, *) 'SHDFILEFLAG          = ', SHDFILEFLAG
            write(58, *) 'SOILINIFLAG          = ', SOILINIFLAG
            write(58, *) 'STREAMFLOWFLAG       = ', STREAMFLOWFLAG
            write(58, *) 'CONFLAGS             = ', CONFLAGS
            write(58, *) 'RELFLG               = ', RELFLG
            write(58, *) 'OPTFLAGS             = ', OPTFLAGS
            write(58, *) 'PREEMPTIONFLAG       = ', mtsflg%PREEMPTIONFLAG
            write(58, *) 'INTERPOLATIONFLAG    = ', INTERPOLATIONFLAG
            write(58, *) 'SUBBASINFLAG         = ', SUBBASINFLAG
            write(58, *) 'TESTCSVFLAG          = ', 'NOTSUPPORTED'
            write(58, *) 'R2COUTPUTFLAG        = ', R2COUTPUTFLAG
            write(58, *) 'OBJFNFLAG            = ', OBJFNFLAG
            write(58, *) 'AUTOCALIBRATIONFLAG  = ', mtsflg%AUTOCALIBRATIONFLAG
            write(58, *) 'WINDOWSIZEFLAG       = ', WINDOWSIZEFLAG
            write(58, *) 'WINDOWSPACINGFLAG    = ', WINDOWSPACINGFLAG
            write(58, *) 'FROZENSOILINFILFLAG  = ', FROZENSOILINFILFLAG
            write(58, *) 'LOCATIONFLAG         = ', LOCATIONFLAG

        !> MAM - ALLOCATE AND INITIALIZE INTERPOLATION VARIABLES:
        !> For 30 minute forcing data there is no need for interpolation and
        !> hence no need to assign PRE and PST variables
            if (INTERPOLATIONFLAG > 1 .or. (INTERPOLATIONFLAG == 1 .and. sum(cm%clin(:)%hf) == 210)) then
                print 9000
                write(58, 9000)
                INTERPOLATIONFLAG = 0
            end if !(INTERPOLATIONFLAG > 1 .or. (INTERPOLATIONFLAG == 1 .and. sum(cm%clin(:)%hf) == 210)) then
            write(58, "('WF_NUM_POINTS: ', i5)") WF_NUM_POINTS
            write(58, "('Out directory:', 5a10)") (op%DIR_OUT(i), i = 1, WF_NUM_POINTS)
            write(58, "('Grid number:  ', 5i10)") (op%N_OUT(i), i = 1, WF_NUM_POINTS)
            write(58, "('Land class:   ', 5i10)") (op%II_OUT(i), i = 1, WF_NUM_POINTS)
            write(58, *)
            write(58, "('MESH_parameters_hydrology.ini')")
            write(58, *)
            write(58, "('Option flags:')")
            if (OPTFLAGS > 0) then
                do i = 1, OPTFLAGS
                    write(58, '(a11, i2, a19)') 'PARAMETER ', i, ' NOT CURRENTLY USED'
                end do
            end if
            write(58, "('River roughnesses:')")
!todo: change this to use NRVR
            write(58, '(5f6.3)') (WF_R2(i), i = 1, 5)
            write(58, "('Land class independent hydrologic parameters:')")
            if (FROZENSOILINFILFLAG == 1) then
                write(58, *) 'SOIL_POR_MAX = ', SOIL_POR_MAX
                write(58, *) 'SOIL_DEPTH   = ', SOIL_DEPTH
                write(58, *) 'S0           = ', S0
                write(58, *) 'T_ICE_LENS   = ', T_ICE_LENS
                do i = 5, INDEPPAR
                    j = i - 4
                    write(58, '(a38, i2, a3, f6.2)') 'OPPORTUNITY TIME FOR SIMULATION YEAR ', j, ' = ', t0_ACC(j)
                end do
            else
                do i = 1, INDEPPAR
                    write(58, '(a36, i2, a19)') 'FROZEN SOIL INFILTRATION PARAMETER ', i, ' READ BUT NOT USED'
                end do
            end if !(FROZENSOILINFILFLAG == 1) then
            write(58, "('Land class dependent hydrologic parameters:')")
            write(NMTESTFORMAT, "(a10, i3, 'f10.2)')") "('ZSNLROW'", NMTEST
            write(58, NMTESTFORMAT) (hp%ZSNLROW(1, m), m = 1, NMTEST)
            write(NMTESTFORMAT, "(a10, i3, 'f10.2)')") "('ZPLSROW'", NMTEST
            write(58, NMTESTFORMAT) (hp%ZPLSROW(1, m), m = 1, NMTEST)
            write(NMTESTFORMAT, "(a10, i3, 'f10.2)')") "('ZPLGROW'", NMTEST
            write(58, NMTESTFORMAT) (hp%ZPLGROW(1, m), m = 1, NMTEST)
            if (DEPPAR >= 4) then
                write(NMTESTFORMAT, "(a10, i3, 'f10.2)')") "('FRZCROW'", NMTEST
                write(58, NMTESTFORMAT) (hp%FRZCROW(1, m), m = 1, NMTEST)
            end if
            write(58, *)
            write(58, "('MESH_parameters_CLASS.ini')")
            write(58, *)
            write(58, '(2x, 6a4)') TITLE1, TITLE2, TITLE3, TITLE4, TITLE5, TITLE6
            write(58, '(2x, 6a4)') NAME1, NAME2, NAME3, NAME4, NAME5, NAME6
            write(58, '(2x, 6a4)') PLACE1, PLACE2, PLACE3, PLACE4, PLACE5, PLACE6
            i = 1
            write(58, '(5f10.2, f7.1, 3i5)') &
                DEGLAT, DEGLON, cp%ZRFMGRD(i), cp%ZRFHGRD(i), cp%ZBLDGRD(i), cp%GCGRD(i), shd%wc%ILG, NA, NMTEST
            do m = 1, NMTEST
                write(58, '(9f8.3)') (cp%FCANROW(i, m, j), j = 1, ICAN + 1), (cp%PAMXROW(i, m, j), j = 1, ICAN)
                write(58, '(9f8.3)') (cp%LNZ0ROW(i, m, j), j = 1, ICAN + 1), (cp%PAMNROW(i, m, j), j = 1, ICAN)
                write(58, '(9f8.3)') (cp%ALVCROW(i, m, j), j = 1, ICAN + 1), (cp%CMASROW(i, m, j), j = 1, ICAN)
                write(58, '(9f8.3)') (cp%ALICROW(i, m, j), j = 1, ICAN + 1), (cp%ROOTROW(i, m, j), j = 1, ICAN)
                write(58, '(4f8.3, 8x, 4f8.3)') (cp%RSMNROW(i, m, j), j = 1, ICAN), (cp%QA50ROW(i, m, j), j = 1, ICAN)
                write(58, '(4f8.3, 8x, 4f8.3)') (cp%VPDAROW(i, m, j), j = 1, ICAN), (cp%VPDBROW(i, m, j), j = 1, ICAN)
                write(58, '(4f8.3, 8x, 4f8.3)') (cp%PSGAROW(i, m, j), j = 1, ICAN), (cp%PSGBROW(i, m, j), j = 1, ICAN)
                write(58, '(3f8.3, f8.4)') cp%DRNROW(i, m), cp%SDEPROW(i, m), cp%FAREROW(i, m), cp%DDROW(i, m)
                write(58, '(4e8.1, i8)') cp%XSLPROW(i, m), cp%XDROW(i, m), cp%MANNROW(i, m), cp%KSROW(i, m), cp%MIDROW(i, m)
                write(58, '(6f10.1)') (cp%SANDROW(i, m, j), j = 1, IGND)
                write(58, '(6f10.1)') (cp%CLAYROW(i, m, j), j = 1, IGND)
                write(58, '(6f10.1)') (cp%ORGMROW(i, m, j), j = 1, IGND)
                write(58, '(9f10.2)') (cp%TBARROW(i, m, j), j = 1, IGND), cp%TCANROW(i, m), cp%TSNOROW(i, m), cp%TPNDROW(i, m)
                write(58, '(10f10.3)') &
                    (cp%THLQROW(i, m, j), j = 1, IGND), (cp%THICROW(i, m, j), j = 1, IGND), cp%ZPNDROW(i, m)
                write(58, '(2f10.4, f10.2, f10.3, f10.4, f10.3, f10.3)') &
                    cp%RCANROW(i, m), cp%SCANROW(i, m), cp%SNOROW(i, m), cp%ALBSROW(i, m), cp%RHOSROW(i, m), cp%GROROW(i, m)
                write(58, *)
            end do !m = 1, NMTEST
        end if !(MODELINFOOUTFLAG > 0) then
    end if !(ipid == 0) then

    allocate(INFILTYPE(NML), SI(NML), TSI(NML), &
             SNOWMELTD(NML), SNOWMELTD_LAST(NML), SNOWINFIL(NML), &
             CUMSNOWINFILCS(NML), MELTRUNOFF(NML), CUMSNOWINFILGS(NML))
             
    NMELT = 1
    INFILTYPE = 2 !> INITIALIZED WITH UNLIMITED INFILTRATION
    SNOWMELTD = 0.0
    SNOWINFIL = 0.0
    CUMSNOWINFILCS = 0.0
    CUMSNOWINFILGS = 0.0
    MELTRUNOFF = 0.0
    SI = 0.20
    TSI = -0.10

!* PDMROF
    allocate(CMINPDM(NML), CMAXPDM(NML), BPDM(NML), K1PDM(NML), &
             K2PDM(NML), ZPNDPRECS(NML), ZPONDPREC(NML), ZPONDPREG(NML), &
             ZPNDPREGS(NML), &
             UM1CS(NML), UM1C(NML), UM1G(NML), UM1GS(NML), &
             QM1CS(NML), QM1C(NML), QM1G(NML), QM1GS(NML), &
             QM2CS(NML), QM2C(NML), QM2G(NML), QM2GS(NML), &
             UMQ(NML), &
             FSTRCS(NML), FSTRC(NML), FSTRG(NML), FSTRGS(NML))

!* PDMROF: INITIALIZE VARIABLES
    ZPNDPRECS = 0.0
    ZPONDPREC = 0.0
    ZPONDPREG = 0.0
    ZPNDPREGS = 0.0
    ZPND = 0.0
    UM1CS = 0.0
    UM1C = 0.0
    UM1G = 0.0
    UM1GS = 0.0
    QM1CS = 0.0
    QM1C = 0.0
    QM1G = 0.0
    QM1GS = 0.0
    QM2CS = 0.0
    QM2C = 0.0
    QM2G = 0.0
    QM2GS = 0.0
    UMQ = 0.0
    FSTRCS = 0.0
    FSTRC = 0.0
    FSTRG = 0.0
    FSTRGS = 0.0
    FSTR = 0.0

!>
!>****************CHECK RESUME FILE***************************************************
!>
    if (RESUMEFLAG == 1) then
!todo: can do this using inquire statement
        open(88, file = 'class_resume.txt', status = 'old', action = 'read', iostat = IOS)
        if (IOS /= 0) then
            if (ipid == 0 .and. MODELINFOOUTFLAG > 0) then
                write(58, *) "WARNING: You've specified a start time", ' without having a resume file. Now ending run.'
            end if
            print *, 'No class_resume.txt found.'
            print *, 'The RESUMEFLAG in MESH_input_run_options.ini is', &
                ' set to 1, which means that class_resume.txt should be here,', &
                ' but it is not here.'
            print *, 'Ending Run'
            stop
        end if
        close(88)
    end if

!> *********************************************************************
!> Open and print header information to the output files
!> *********************************************************************

    if (ipid == 0) then

    !> Streamflow output files.
        if (STREAMFLOWOUTFLAG > 0) then

        !> Daily streamflow file.
            open(fls%fl(mfk%f70)%iun, &
!todo: This creates a bug if a space doesn't exist in the name of the folder!
                 file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/' // trim(adjustl(fls%fl(mfk%f70)%fn)), &
                 iostat = ios)

        !> Hourly and cumulative daily streamflow files.
            if (STREAMFLOWOUTFLAG >= 2) then
                open(71, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/MESH_output_streamflow_all.csv')
                open(72, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/MESH_output_streamflow_cumulative.csv')
            end if

        end if !(STREAMFLOWOUTFLAG > 0) then

!> *********************************************************************
!> Open and read in values from r2c_output.txt file
!> *********************************************************************

        NR2CFILES = 0
        if (R2COUTPUTFLAG >= 1) then
            inquire(file = 'r2c_output.txt', exist = R2COUTPUT)
            if (R2COUTPUT) then
                open(56, file = 'r2c_output.txt', action = 'read')
                read(56, *, iostat = IOS) NR2C, DELTR2C
                if (IOS == 0) then
                    allocate(GRD(NR2C), GAT(NR2C), GRDGAT(NR2C), R2C_ATTRIBUTES(NR2C, 3), stat = PAS)
                    if (PAS /= 0) then
                        print *, 'ALLOCATION ERROR: CHECK THE VALUE OF THE FIRST ', &
                            'RECORD AT THE FIRST LINE IN THE r2c_output.txt FILE. ', &
                            'IT SHOULD BE AN INTEGER VALUE (GREATER THAN 0).'
                        stop
                    end if
                end if
                if (IOS /= 0 .or. mod(DELTR2C, 30) /= 0) then
                    print 9002
                    stop
                end if
                print *
                print *, 'THE FOLLOWING R2C OUTPUT FILES WILL BE WRITTEN:'
                do i = 1, NR2C
                    read(56, *, iostat = IOS) GRD(i), GAT(i), GRDGAT(i), (R2C_ATTRIBUTES(i, j), j = 1, 3)
                    if (IOS /= 0) then
                        print *, 'ERROR READING r2c_output.txt FILE AT LINE ', i + 1
                        stop
                    else
                        if (GRD(i) == 1) then
                            NR2CFILES = NR2CFILES + 1
                            print *, NR2CFILES, ' (GRD)    : ', R2C_ATTRIBUTES(i, 3)
                        end if
                        if (GAT(i) == 1) then
                            NR2CFILES = NR2CFILES + 1
                            print *, NR2CFILES, ' (GAT)    : ', R2C_ATTRIBUTES(i, 3)
                        end if
                        if (GRDGAT(i) == 1) then
                            NR2CFILES = NR2CFILES + 1
                            print *, NR2CFILES, ' (GRDGAT) : ', R2C_ATTRIBUTES(i, 3)
                        end if
                    end if
                end do
                close(56)
            else
                print *
                print *, "r2c_output.txt FILE DOESN'T EXIST. ", &
                    'R2COUTPUTFLAG SHOULD BE SET TO ZERO IF R2C OUTPUTS ARE NOT NEEDED.'
                print *
                stop
            end if
        end if

!> WRITE THE HEADER FOR R2C FILES:
        if (NR2CFILES > 0) then
            call WRITE_R2C_HEADER(NMTEST, NR2C, NR2CFILES, GRD, GAT, GRDGAT, R2C_ATTRIBUTES, &
                                  R2CFILEUNITSTART, NR2CSTATES, shd%CoordSys%Proj, shd%CoordSys%Ellips, shd%CoordSys%Zone, &
                                  shd%xOrigin, shd%yOrigin, shd%xDelta, shd%yDelta, shd%xCount, shd%yCount)
        end if

!> For the ENSIM timestamp
        wfo_seq = 0

    end if !(ipid == 0) then

!> End of ENSIM Changes

!> *********************************************************************
!> Output information to screen
!> *********************************************************************

    if (ro%VERBOSEMODE > 0) then
        print *, 'NUMBER OF GRID SQUARES: ', NA
        print *, 'NUMBER OF LAND CLASSES (WITH IMPERVIOUS): ', NMTEST
        print *, 'NUMBER OF RIVER CLASSES: ', shd%NRVR
        print *, 'MINIMUM NUMBER FOR ILG: ', shd%lc%ILG
        print *, 'NUMBER OF GRID SQUARES IN West-East DIRECTION: ', shd%xCount
        print *, 'NUMBER OF GRID SQUARES IN South-North DIRECTION: ', shd%yCount
        print *, 'LENGTH OF SIDE OF GRID SQUARE IN M: ', shd%AL
        print *, 'NUMBER OF DRAINAGE OUTLETS: ', shd%NAA
        print *, 'NUMBER OF STREAMFLOW GUAGES: ', WF_NO
        do i = 1, WF_NO
            print *, 'STREAMFLOW STATION: ', i, 'I: ', WF_IY(i), 'J: ', WF_JX(i)
        end do
        print *, 'NUMBER OF RESERVOIR STATIONS: ', WF_NORESV
        if (WF_NORESV > 0) then
            do i = 1, WF_NORESV
                print *, 'RESERVOIR STATION: ', i, 'I: ', WF_IRES(i), 'J: ', WF_JRES(i)
            end do
        end if
        print *
        print *, 'Found these output locations:'
        print *, 'Output Directory, grid number, land class number'
        do i = 1, WF_NUM_POINTS
            print *, op%DIR_OUT(i), op%N_OUT(i), op%II_OUT(i)
        end do
        print *
        print *
        print *
    end if !(ro%VERBOSEMODE > 0) then

    if (ipid == 0 .and. mtsflg%AUTOCALIBRATIONFLAG > 0) call stats_init(ts, wf_no)

!>
!>*******************************************************************
!>
!> Check if we are reading in a resume file
    if (RESUMEFLAG == 1) then
        print *, 'Reading saved state variables'
        call resume_state(HOURLYFLAG, MINS_NOW, TIME_STEP_NOW, &
                          cm%clin(cfk%FB)%filefmt, cm%clin(cfk%FI)%filefmt, &
                          cm%clin(cfk%PR)%filefmt, cm%clin(cfk%TT)%filefmt, &
                          cm%clin(cfk%UV)%filefmt, cm%clin(cfk%P0)%filefmt, cm%clin(cfk%HU)%filefmt, &
                          cm%clin(cfk%FB)%climvGrd, FSVHGRD, FSIHGRD, cm%clin(cfk%FI)%climvGrd, &
                          i, j, shd%xCount, shd%yCount, jan, &
                          VPDGRD, TADPGRD, PADRGRD, RHOAGRD, RHSIGRD, &
                          RPCPGRD, TRPCGRD, SPCPGRD, TSPCGRD, cm%clin(cfk%TT)%climvGrd, &
                          cm%clin(cfk%HU)%climvGrd, cm%clin(cfk%PR)%climvGrd, RPREGRD, SPREGRD, cm%clin(cfk%P0)%climvGrd, &

!> MAM - FOR FORCING DATA INTERPOLATION
                          FSVHGATPRE, FSIHGATPRE, FDLGATPRE, PREGATPRE, &
                          TAGATPRE, ULGATPRE, PRESGATPRE, QAGATPRE, &
                          IPCP, NA, NA, shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, &
                          shd%lc%NML, shd%wc%NML, &
                          cp%GCGRD, cp%FAREROW, cp%MIDROW, NTYPE, NML, NMTEST, &
                          TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                          TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                          TCANGAT, RCANGAT, SCANGAT, GROGAT, FRZCGAT, CMAIGAT, &
                          FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                          PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                          VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                          HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                          THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                          GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, THFCGAT, &
                          PSIWGAT, DLZWGAT, ZBTWGAT, ZSNLGAT, ZPLGGAT, &
                          ZPLSGAT, TACGAT, QACGAT, DRNGAT, XSLPGAT, &
                          XDGAT, WFSFGAT, KSGAT, ALGWGAT, ALGDGAT, &
                          ASVDGAT, ASIDGAT, AGVDGAT, AGIDGAT, ISNDGAT, &
                          RADJGAT, ZBLDGAT, Z0ORGAT, ZRFMGAT, ZRFHGAT, &
                          ZDMGAT, ZDHGAT, FSVHGAT, FSIHGAT, CSZGAT, &
                          FDLGAT, ULGAT, VLGAT, TAGAT, QAGAT, PRESGAT, &
                          PREGAT, PADRGAT, VPDGAT, TADPGAT, RHOAGAT, &
                          RPCPGAT, TRPCGAT, SPCPGAT, TSPCGAT, RHSIGAT, &
                          FCLOGAT, DLONGAT, GGEOGAT, CDHGAT, CDMGAT, &
                          HFSGAT, TFXGAT, QEVPGAT, QFSGAT, QFXGAT, &
                          PETGAT, GAGAT, EFGAT, GTGAT, QGGAT, &
                          ALVSGAT, ALIRGAT, SFCTGAT, SFCUGAT, SFCVGAT, &
                          SFCQGAT, FSNOGAT, FSGVGAT, FSGSGAT, FSGGGAT, &
                          FLGVGAT, FLGSGAT, FLGGGAT, HFSCGAT, HFSSGAT, &
                          HFSGGAT, HEVCGAT, HEVSGAT, HEVGGAT, HMFCGAT, &
                          HMFNGAT, HTCCGAT, HTCSGAT, PCFCGAT, PCLCGAT, &
                          PCPNGAT, PCPGGAT, QFGGAT, QFNGAT, QFCLGAT, &
                          QFCFGAT, ROFGAT, ROFOGAT, ROFSGAT, ROFBGAT, &
                          TROFGAT, TROOGAT, TROSGAT, TROBGAT, ROFCGAT, &
                          ROFNGAT, ROVGGAT, WTRCGAT, WTRSGAT, WTRGGAT, &
                          DRGAT, HMFGGAT, HTCGAT, QFCGAT, ITCTGAT, &
                          IGND, ICAN, ICP1, &
                          cp%TBARROW, cp%THLQROW, cp%THICROW, cp%TPNDROW, cp%ZPNDROW, &
                          TBASROW, cp%ALBSROW, cp%TSNOROW, cp%RHOSROW, cp%SNOROW, &
                          cp%TCANROW, cp%RCANROW, cp%SCANROW, cp%GROROW, CMAIROW, &
                          cp%FCANROW, cp%LNZ0ROW, cp%ALVCROW, cp%ALICROW, cp%PAMXROW, &
                          cp%PAMNROW, cp%CMASROW, cp%ROOTROW, cp%RSMNROW, cp%QA50ROW, &
                          cp%VPDAROW, cp%VPDBROW, cp%PSGAROW, cp%PSGBROW, PAIDROW, &
                          HGTDROW, ACVDROW, ACIDROW, TSFSROW, WSNOROW, &
                          THPROW, THRROW, THMROW, BIROW, PSISROW, &
                          GRKSROW, THRAROW, HCPSROW, TCSROW, THFCROW, &
                          PSIWROW, DLZWROW, ZBTWROW, hp%ZSNLROW, hp%ZPLGROW, &
                          hp%ZPLSROW, hp%FRZCROW, TACROW, QACROW, cp%DRNROW, cp%XSLPROW, &
                          cp%XDROW, WFSFROW, cp%KSROW, ALGWROW, ALGDROW, &
                          ASVDROW, ASIDROW, AGVDROW, AGIDROW, &
                          ISNDROW, RADJGRD, cp%ZBLDGRD, Z0ORGRD, &
                          cp%ZRFMGRD, cp%ZRFHGRD, ZDMGRD, ZDHGRD, CSZGRD, &
                          cm%clin(cfk%UV)%climvGrd, VLGRD, FCLOGRD, DLONGRD, GGEOGRD, &
                          cp%MANNROW, MANNGAT, cp%DDROW, DDGAT, &
                          IGDRROW, IGDRGAT, VMODGRD, VMODGAT, QLWOGAT, &
                          CTVSTP, CTSSTP, CT1STP, CT2STP, CT3STP, &
                          WTVSTP, WTSSTP, WTGSTP, &
                          sl%DELZ, FCS, FGS, FC, FG, N, &
                          ALVSCN, ALIRCN, ALVSG, ALIRG, ALVSCS, &
                          ALIRCS, ALVSSN, ALIRSN, ALVSGC, ALIRGC, &
                          ALVSSC, ALIRSC, TRVSCN, TRIRCN, TRVSCS, &
                          TRIRCS, FSVF, FSVFS, &
                          RAICAN, RAICNS, SNOCAN, SNOCNS, &
                          FRAINC, FSNOWC, FRAICS, FSNOCS, &
                          DISP, DISPS, ZOMLNC, ZOMLCS, ZOELNC, ZOELCS, &
                          ZOMLNG, ZOMLNS, ZOELNG, ZOELNS, &
                          CHCAP, CHCAPS, CMASSC, CMASCS, CWLCAP, &
                          CWFCAP, CWLCPS, CWFCPS, RC, RCS, RBCOEF, &
                          FROOT, ZPLIMC, ZPLIMG, ZPLMCS, ZPLMGS, &
                          TRSNOW, ZSNOW, JDAY_NOW, JLAT, IDISP, &
                          IZREF, IWF, IPAI, IHGT, IALC, IALS, IALG, &
                          TBARC, TBARG, TBARCS, TBARGS, THLIQC, THLIQG, &
                          THICEC, THICEG, HCPC, HCPG, TCTOPC, TCBOTC, &
                          TCTOPG, TCBOTG, &
                          GZEROC, GZEROG, GZROCS, GZROGS, G12C, G12G, &
                          G12CS, G12GS, G23C, G23G, G23CS, G23GS, &
                          QFREZC, QFREZG, QMELTC, QMELTG, &
                          EVAPC, EVAPCG, EVAPG, EVAPCS, EVPCSG, EVAPGS, &
                          TCANO, TCANS, TPONDC, TPONDG, TPNDCS, TPNDGS, &
                          TSNOCS, TSNOGS, WSNOCS, WSNOGS, RHOSCS, RHOSGS, &
                          WTABGAT, &
                          ILMOGAT, UEGAT, HBLGAT, &
                          shd%wc%ILG, ITC, ITCG, ITG, ISLFD, &
                          NLANDCS, NLANDGS, NLANDC, NLANDG, NLANDI, &
                          GFLXGAT, CDHROW, CDMROW, HFSROW, TFXROW, &
                          QEVPROW, QFSROW, QFXROW, PETROW, GAROW, &
                          EFROW, GTROW, QGROW, TSFROW, ALVSROW, &
                          ALIRROW, SFCTROW, SFCUROW, SFCVROW, SFCQROW, &
                          FSGVROW, FSGSROW, FSGGROW, FLGVROW, FLGSROW, &
                          FLGGROW, HFSCROW, HFSSROW, HFSGROW, HEVCROW, &
                          HEVSROW, HEVGROW, HMFCROW, HMFNROW, HTCCROW, &
                          HTCSROW, PCFCROW, PCLCROW, PCPNROW, PCPGROW, &
                          QFGROW, QFNROW, QFCLROW, QFCFROW, ROFROW, &
                          ROFOROW, ROFSROW, ROFBROW, TROFROW, TROOROW, &
                          TROSROW, TROBROW, ROFCROW, ROFNROW, ROVGROW, &
                          WTRCROW, WTRSROW, WTRGROW, DRROW, WTABROW, &
                          ILMOROW, UEROW, HBLROW, HMFGROW, HTCROW, &
                          QFCROW, FSNOROW, ITCTROW, NCOUNT, ireport, &
                          wfo_seq, YEAR_NOW, ensim_MONTH, ensim_DAY, &
                          HOUR_NOW, shd%xxx, shd%yyy, NA, &
                          NTYPE, DELT, TFREZ, UVGRD, SBC, RHOW, CURREC, &
                          M_C, M_S, M_R, &
                          WF_ROUTETIMESTEP, WF_R1, WF_R2, shd%NAA, shd%iyMin, &
                          shd%iyMax, shd%jxMin, shd%jxMax, shd%IAK, shd%IROUGH, &
                          shd%ICHNL, shd%NEXT, shd%IREACH, shd%AL, shd%GRDN, shd%GRDE, &
                          shd%DA, shd%BNKFLL, shd%SLOPE_CHNL, shd%ELEV, shd%FRAC, &
                          WF_NO, WF_NL, WF_MHRD, WF_KT, WF_IY, WF_JX, &
                          WF_QHYD, WF_RES, WF_RESSTORE, WF_NORESV_CTRL, WF_R, &
                          WF_NORESV, WF_NREL, WF_KTR, WF_IRES, WF_JRES, WF_RESNAME, &
                          WF_B1, WF_B2, WF_QREL, WF_QR, &
                          WF_TIMECOUNT, WF_NHYD, WF_QBASE, WF_QI1, WF_QI2, WF_QO1, WF_QO2, &
                          WF_STORE1, WF_STORE2, &
                          DRIVERTIMESTEP, ROFGRD, &
                          WF_S, &
                          TOTAL_ROFACC, TOTAL_ROFOACC, TOTAL_ROFSACC, &
                          TOTAL_ROFBACC, TOTAL_EVAPACC, TOTAL_PREACC, INIT_STORE, &
                          FINAL_STORE, TOTAL_AREA, TOTAL_HFSACC, TOTAL_QEVPACC, &
                          SOIL_POR_MAX, SOIL_DEPTH, S0, T_ICE_LENS, NMELT, t0_ACC, &
                          CO2CONC, COSZS, XDIFFUSC, CFLUXCG, CFLUXCS, &
                          AILCG, AILCGS, FCANC, FCANCS, CO2I1CG, CO2I1CS, CO2I2CG, CO2I2CS, &
                          SLAI, FCANCMX, ANCSVEG, ANCGVEG, RMLCSVEG, RMLCGVEG, &
                          AILC, PAIC, FIELDSM, WILTSM, &
                          RMATCTEM, RMATC, NOL2PFTS, ICTEMMOD, L2MAX, ICTEM, &
                          hp%fetchROW, hp%HtROW, hp%N_SROW, hp%A_SROW, hp%DistribROW, &
                          fetchGAT, HtGAT, N_SGAT, A_SGAT, DistribGAT)
    end if !(RESUMEFLAG == 1) then

!>
!>*******************************************************************
!>
!> Check if we are reading in a resume_state.r2c file
    if (RESUMEFLAG == 2) then
        print *, 'Reading saved state variables'

! Allocate arrays for resume_state_r2c
        open(54, file = 'resume_state_r2c.txt', action = 'read')
        read(54, *, iostat = IOS) NR2C_R, DELTR2C_R
        if (IOS == 0) then
            allocate(GRD_R(NR2C_R), GAT_R(NR2C_R), GRDGAT_R(NR2C_R), R2C_ATTRIBUTES_R(NR2C_R, 3), stat = PAS)
            if (PAS /= 0) then
                print *, 'ALLOCATION ERROR: CHECK THE VALUE OF THE FIRST ', &
                    'RECORD AT THE FIRST LINE IN THE resume_state_r2c.txt FILE. ', &
                    'IT SHOULD BE AN INTEGER VALUE (GREATER THAN 0).'
                stop
            end if
        end if
        close(54)

! start by gathering from ROW to GAT so as not to mess-up with CLASSS after call to save_state_r2c
        call CLASSG (TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                     TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                     TCANGAT, RCANGAT, SCANGAT, GROGAT, FRZCGAT, CMAIGAT, &
                     FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                     PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                     VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                     HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                     THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                     GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, IGDRGAT, &
                     THFCGAT, PSIWGAT, DLZWGAT, ZBTWGAT, VMODGAT, &
                     ZSNLGAT, ZPLGGAT, ZPLSGAT, TACGAT, QACGAT, &
                     DRNGAT, XSLPGAT, XDGAT, WFSFGAT, KSGAT, &
                     ALGWGAT, ALGDGAT, ASVDGAT, ASIDGAT, AGVDGAT, &
                     AGIDGAT, ISNDGAT, RADJGAT, ZBLDGAT, Z0ORGAT, &
                     ZRFMGAT, ZRFHGAT, ZDMGAT, ZDHGAT, FSVHGAT, &
                     FSIHGAT, CSZGAT, FDLGAT, ULGAT, VLGAT, &
                     TAGAT, QAGAT, PRESGAT, PREGAT, PADRGAT, &
                     VPDGAT, TADPGAT, RHOAGAT, RPCPGAT, TRPCGAT, &
                     SPCPGAT, TSPCGAT, RHSIGAT, FCLOGAT, DLONGAT, &
                     GGEOGAT, &
                     CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT, &
                     QFSGAT, QFXGAT, PETGAT, GAGAT, EFGAT, &
                     GTGAT, QGGAT, ALVSGAT, ALIRGAT, &
                     SFCTGAT, SFCUGAT, SFCVGAT, SFCQGAT, FSNOGAT, &
                     FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, &
                     FLGGGAT, HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, &
                     HEVSGAT, HEVGGAT, HMFCGAT, HMFNGAT, HTCCGAT, &
                     HTCSGAT, PCFCGAT, PCLCGAT, PCPNGAT, PCPGGAT, &
                     QFGGAT, QFNGAT, QFCLGAT, QFCFGAT, ROFGAT, &
                     ROFOGAT, ROFSGAT, ROFBGAT, TROFGAT, TROOGAT, &
                     TROSGAT, TROBGAT, ROFCGAT, ROFNGAT, ROVGGAT, &
                     WTRCGAT, WTRSGAT, WTRGGAT, DRGAT, GFLXGAT, &
                     HMFGGAT, HTCGAT, QFCGAT, ITCTGAT, &
!BEGIN: PDMROF
                     CMINPDM, CMAXPDM, BPDM, K1PDM, K2PDM, &
!END: PDMROF
                     shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, NA, NTYPE, &
                     NML, il1, il2, IGND, ICAN, ICP1, cp%TBARROW, cp%THLQROW, &
                     cp%THICROW, cp%TPNDROW, cp%ZPNDROW, TBASROW, cp%ALBSROW, &
                     cp%TSNOROW, cp%RHOSROW, cp%SNOROW, cp%TCANROW, &
                     cp%RCANROW, cp%SCANROW, cp%GROROW, CMAIROW, cp%FCANROW, &
                     cp%LNZ0ROW, cp%ALVCROW, cp%ALICROW, cp%PAMXROW, &
                     cp%PAMNROW, cp%CMASROW, cp%ROOTROW, cp%RSMNROW, &
                     cp%QA50ROW, cp%VPDAROW, cp%VPDBROW, cp%PSGAROW, &
                     cp%PSGBROW, PAIDROW, HGTDROW, ACVDROW, ACIDROW, TSFSROW, &
                     WSNOROW, THPROW, THRROW, THMROW, BIROW, PSISROW, &
                     GRKSROW, THRAROW, HCPSROW, TCSROW, IGDRROW, &
                     THFCROW, PSIWROW, DLZWROW, ZBTWROW, VMODGRD, &
                     hp%ZSNLROW, hp%ZPLGROW, hp%ZPLSROW, hp%FRZCROW, TACROW, QACROW, &
                     cp%DRNROW, cp%XSLPROW, cp%XDROW, WFSFROW, cp%KSROW, &
                     ALGWROW, ALGDROW, ASVDROW, ASIDROW, AGVDROW, &
                     AGIDROW, ISNDROW, RADJGRD, cp%ZBLDGRD, Z0ORGRD, &
                     cp%ZRFMGRD, cp%ZRFHGRD, ZDMGRD, ZDHGRD, FSVHGRD, &
                     FSIHGRD, CSZGRD, cm%clin(cfk%FI)%climvGrd, cm%clin(cfk%UV)%climvGrd, VLGRD, &
                     cm%clin(cfk%TT)%climvGrd, cm%clin(cfk%HU)%climvGrd, cm%clin(cfk%P0)%climvGrd, &
                     cm%clin(cfk%PR)%climvGrd, PADRGRD, &
                     VPDGRD, TADPGRD, RHOAGRD, RPCPGRD, TRPCGRD, &
                     SPCPGRD, TSPCGRD, RHSIGRD, FCLOGRD, DLONGRD, &
                     GGEOGRD, cp%MANNROW, MANNGAT, cp%DDROW, DDGAT, &
                     cp%SANDROW, SANDGAT, cp%CLAYROW, CLAYGAT, &
!BEGIN: PDMROF
                     hp%CMINROW, hp%CMAXROW, hp%BROW, hp%K1ROW, hp%K2ROW, &
!END: PDMROF
                     cp%FAREROW, FAREGAT, &
                     hp%fetchROW, hp%HtROW, hp%N_SROW, hp%A_SROW, hp%DistribROW, &
                     fetchGAT, HtGAT, N_SGAT, A_SGAT, DistribGAT, &
                     DrySnowRow, SnowAgeROW, DrySnowGAT, SnowAgeGAT, &
                     TSNOdsROW, RHOSdsROW, TSNOdsGAT, RHOSdsGAT, &
                     DriftROW, SublROW, DepositionROW, &
                     DriftGAT, SublGAT, DepositionGAT)
!>
!>   * INITIALIZATION OF DIAGNOSTIC VARIABLES SPLIT OUT OF CLASSG
!>   * FOR CONSISTENCY WITH GCM APPLICATIONS.
!>

!> *********************************************************************
!> Set variables arrays to zero.
!> *********************************************************************

        CDHGAT = 0.0
        CDMGAT = 0.0
        HFSGAT = 0.0
        TFXGAT = 0.0
        QEVPGAT = 0.0
        QFSGAT = 0.0
        QFXGAT = 0.0
        PETGAT = 0.0
        GAGAT = 0.0
        EFGAT = 0.0
        GTGAT = 0.0
        QGGAT = 0.0
        ALVSGAT = 0.0
        ALIRGAT = 0.0
        SFCTGAT = 0.0
        SFCUGAT = 0.0
        SFCVGAT = 0.0
        SFCQGAT = 0.0
        FSNOGAT = 0.0
        FSGVGAT = 0.0
        FSGSGAT = 0.0
        FSGGGAT = 0.0
        FLGVGAT = 0.0
        FLGSGAT = 0.0
        FLGGGAT = 0.0
        HFSCGAT = 0.0
        HFSSGAT = 0.0
        HFSGGAT = 0.0
        HEVCGAT = 0.0
        HEVSGAT = 0.0
        HEVGGAT = 0.0
        HMFCGAT = 0.0
        HMFNGAT = 0.0
        HTCCGAT = 0.0
        HTCSGAT = 0.0
        PCFCGAT = 0.0
        PCLCGAT = 0.0
        PCPNGAT = 0.0
        PCPGGAT = 0.0
        QFGGAT = 0.0
        QFNGAT = 0.0
        QFCFGAT = 0.0
        QFCLGAT = 0.0
        ROFGAT = 0.0
        ROFOGAT = 0.0
        ROFSGAT = 0.0
        ROFBGAT = 0.0
        TROFGAT = 0.0
        TROOGAT = 0.0
        TROSGAT = 0.0
        TROBGAT = 0.0
        ROFCGAT = 0.0
        ROFNGAT = 0.0
        ROVGGAT = 0.0
        WTRCGAT = 0.0
        WTRSGAT = 0.0
        WTRGGAT = 0.0
        DRGAT = 0.0
        HMFGGAT = 0.0
        HTCGAT = 0.0
        QFCGAT = 0.0
        GFLXGAT = 0.0
        ITCTGAT = 0

        call resume_state_r2c(shd%lc%NML, NLTEST, NMTEST, NCOUNT, &
                              MINS_NOW, shd%lc%ACLASS, NR2C_R, GRD_R, GAT_R, GRDGAT_R, R2C_ATTRIBUTES_R, &
                              NA, shd%xxx, shd%yyy, shd%xCount, shd%yCount, shd%lc%ILMOS, shd%lc%JLMOS, NML, ICAN, ICP1, IGND, &
                              TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                              TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                              TCANGAT, RCANGAT, SCANGAT, GROGAT, CMAIGAT, &
                              FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                              PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                              VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                              HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                              THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                              GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, &
                              THFCGAT, PSIWGAT, DLZWGAT, ZBTWGAT, &
                              ZSNLGAT, ZPLGGAT, ZPLSGAT, TACGAT, QACGAT, &
                              DRNGAT, XSLPGAT, XDGAT, WFSFGAT, KSGAT, &
                              ALGWGAT, ALGDGAT, ASVDGAT, ASIDGAT, AGVDGAT, &
                              AGIDGAT, ISNDGAT, RADJGAT, ZBLDGAT, Z0ORGAT, &
                              ZRFMGAT, ZRFHGAT, ZDMGAT, ZDHGAT, FSVHGAT, &
                              FSIHGAT, CSZGAT, FDLGAT, ULGAT, VLGAT, &
                              TAGAT, QAGAT, PRESGAT, PREGAT, PADRGAT, &
                              VPDGAT, TADPGAT, RHOAGAT, RPCPGAT, TRPCGAT, &
                              SPCPGAT, TSPCGAT, RHSIGAT, FCLOGAT, DLONGAT, &
                              GGEOGAT, &
                              CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT, &
                              QFSGAT, QFXGAT, PETGAT, GAGAT, EFGAT, &
                              GTGAT, QGGAT, ALVSGAT, ALIRGAT, &
                              SFCTGAT, SFCUGAT, SFCVGAT, SFCQGAT, FSNOGAT, &
                              FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, &
                              FLGGGAT, HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, &
                              HEVSGAT, HEVGGAT, HMFCGAT, HMFNGAT, HTCCGAT, &
                              HTCSGAT, PCFCGAT, PCLCGAT, PCPNGAT, PCPGGAT, &
                              QFGGAT, QFNGAT, QFCLGAT, QFCFGAT, ROFGAT, &
                              ROFOGAT, ROFSGAT, ROFBGAT, TROFGAT, TROOGAT, &
                              TROSGAT, TROBGAT, ROFCGAT, ROFNGAT, ROVGGAT, &
                              WTRCGAT, WTRSGAT, WTRGGAT, DRGAT, GFLXGAT, &
                              HMFGGAT, HTCGAT, QFCGAT, MANNGAT, DDGAT, &
                              SANDGAT, CLAYGAT, IGDRGAT, VMODGAT, QLWOGAT, &
                              shd%CoordSys%Proj, shd%CoordSys%Ellips, shd%CoordSys%Zone, &
                              shd%xOrigin, shd%yOrigin, shd%xDelta, shd%yDelta)
!>
! now scatter the variables so that the GATs don't get overwritten incorrectly
        call CLASSS(cp%TBARROW, cp%THLQROW, cp%THICROW, GFLXROW, TSFSROW, &
                    cp%TPNDROW, cp%ZPNDROW, TBASROW, cp%ALBSROW, cp%TSNOROW, &
                    cp%RHOSROW, cp%SNOROW, cp%TCANROW, cp%RCANROW, cp%SCANROW, &
                    cp%GROROW, CMAIROW, TACROW, QACROW, WSNOROW, &
                    shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, &
                    NA, NTYPE, NML, il1, il2, IGND, ICAN, ICAN + 1, &
                    TBARGAT, THLQGAT, THICGAT, GFLXGAT, TSFSGAT, &
                    TPNDGAT, ZPNDGAT, TBASGAT, ALBSGAT, TSNOGAT, &
                    RHOSGAT, SNOGAT, TCANGAT, RCANGAT, SCANGAT, &
                    GROGAT, CMAIGAT, TACGAT, QACGAT, WSNOGAT, &
                    cp%MANNROW, MANNGAT, cp%DDROW, DDGAT, &
                    cp%SANDROW, SANDGAT, cp%CLAYROW, CLAYGAT, cp%XSLPROW, XSLPGAT, &
                    DrySnowRow, SnowAgeROW, DrySnowGAT, SnowAgeGAT, &
                    TSNOdsROW, RHOSdsROW, TSNOdsGAT, RHOSdsGAT, &
                    DriftROW, SublROW, DepositionROW, &
                    DriftGAT, SublGAT, DepositionGAT)
!>
!>   * SCATTER OPERATION ON DIAGNOSTIC VARIABLES SPLIT OUT OF
!>   * CLASSS FOR CONSISTENCY WITH GCM APPLICATIONS.
!>
        do 180 k = il1, il2
            ik = shd%lc%ILMOS(k)
            jk = shd%lc%JLMOS(k)
            CDHROW(ik, jk) = CDHGAT(k)
            CDMROW(ik, jk) = CDMGAT(k)
            HFSROW(ik, jk) = HFSGAT(k)
            TFXROW(ik, jk) = TFXGAT(k)
            QEVPROW(ik, jk) = QEVPGAT(k)
            QFSROW(ik, jk) = QFSGAT(k)
            QFXROW(ik, jk) = QFXGAT(k)
            PETROW(ik, jk) = PETGAT(k)
            GAROW(ik, jk) = GAGAT(k)
            EFROW(ik, jk) = EFGAT(k)
            GTROW(ik, jk) = GTGAT(k)
            QGROW(ik, jk) = QGGAT(k)
            ALVSROW(ik, jk) = ALVSGAT(k)
            ALIRROW(ik, jk) = ALIRGAT(k)
            SFCTROW(ik, jk) = SFCTGAT(k)
            SFCUROW(ik, jk) = SFCUGAT(k)
            SFCVROW(ik, jk) = SFCVGAT(k)
            SFCQROW(ik, jk) = SFCQGAT(k)
            FSNOROW(ik, jk) = FSNOGAT(k)
            FSGVROW(ik, jk) = FSGVGAT(k)
            FSGSROW(ik, jk) = FSGSGAT(k)
            FSGGROW(ik, jk) = FSGGGAT(k)
            FLGVROW(ik, jk) = FLGVGAT(k)
            FLGSROW(ik, jk) = FLGSGAT(k)
            FLGGROW(ik, jk) = FLGGGAT(k)
            HFSCROW(ik, jk) = HFSCGAT(k)
            HFSSROW(ik, jk) = HFSSGAT(k)
            HFSGROW(ik, jk) = HFSGGAT(k)
            HEVCROW(ik, jk) = HEVCGAT(k)
            HEVSROW(ik, jk) = HEVSGAT(k)
            HEVGROW(ik, jk) = HEVGGAT(k)
            HMFCROW(ik, jk) = HMFCGAT(k)
            HMFNROW(ik, jk) = HMFNGAT(k)
            HTCCROW(ik, jk) = HTCCGAT(k)
            HTCSROW(ik, jk) = HTCSGAT(k)
            PCFCROW(ik, jk) = PCFCGAT(k)
            PCLCROW(ik, jk) = PCLCGAT(k)
            PCPNROW(ik, jk) = PCPNGAT(k)
            PCPGROW(ik, jk) = PCPGGAT(k)
            QFGROW(ik, jk) = QFGGAT(k)
            QFNROW(ik, jk) = QFNGAT(k)
            QFCLROW(ik, jk) = QFCLGAT(k)
            QFCFROW(ik, jk) = QFCFGAT(k)
            ROFROW(ik, jk) = ROFGAT(k)
            ROFOROW(ik, jk) = ROFOGAT(k)
            ROFSROW(ik, jk) = ROFSGAT(k)
            ROFBROW(ik, jk) = ROFBGAT(k)
            TROFROW(ik, jk) = TROFGAT(k)
            TROOROW(ik, jk) = TROOGAT(k)
            TROSROW(ik, jk) = TROSGAT(k)
            TROBROW(ik, jk) = TROBGAT(k)
            ROFCROW(ik, jk) = ROFCGAT(k)
            ROFNROW(ik, jk) = ROFNGAT(k)
            ROVGROW(ik, jk) = ROVGGAT(k)
            WTRCROW(ik, jk) = WTRCGAT(k)
            WTRSROW(ik, jk) = WTRSGAT(k)
            WTRGROW(ik, jk) = WTRGGAT(k)
            DRROW(ik, jk) = DRGAT(k)
            WTABROW(ik, jk) = WTABGAT(k)
            ILMOROW(ik, jk) = ILMOGAT(k)
            UEROW(ik, jk) = UEGAT(k)
            HBLROW(ik, jk) = HBLGAT(k)
180     continue
!>
        do 190 l = 1, IGND
            do 190 k = il1, il2
                ik = shd%lc%ILMOS(k)
                jk = shd%lc%JLMOS(k)
                HMFGROW(ik, jk, l) = HMFGGAT(k, l)
                HTCROW(ik, jk, l) = HTCGAT(k, l)
                QFCROW(ik, jk, l) = QFCGAT(k, l)
190     continue
!>
        do 230 m = 1, 50
            do 220 l = 1, 6
                do 210 k = il1, il2
                    ITCTROW(shd%lc%ILMOS(k), shd%lc%JLMOS(k), l, m) = ITCTGAT(k, l, m)
210     continue
220     continue
230     continue
    end if !(RESUMEFLAG == 2) then

!> *********************************************************************
!> Call read_init_prog_variables.f90 for initi prognostic variables by
!> by fields needd by classas as initial conditions
!> *********************************************************************
!> bjd - July 14, 2014: Gonzalo Sapriza
    if (RESUMEFLAG == 3) then
        call read_init_prog_variables_class(CMAIROW, QACROW, TACROW, &
                                            TBASROW, TSFSROW, WSNOROW, &
                                            cp, NA, NTYPE, &
                                            IGND, fls)
    end if !(RESUMEFLAG == 3) then

!> *********************************************************************
!> Call CLASSB to set more CLASS variables
!> *********************************************************************
!> bjd - July 25, 2005: For inputting field measured soil properties.

    call CLASSB(THPROW, THRROW, THMROW, BIROW, PSISROW, &
                GRKSROW, THRAROW, HCPSROW, TCSROW, THFCROW, &
                PSIWROW, DLZWROW, ZBTWROW, ALGWROW, ALGDROW, &
                cp%SANDROW, cp%CLAYROW , cp%ORGMROW, sl%DELZ, sl%ZBOT, &
                cp%SDEPROW, ISNDROW, IGDRROW, NA, NTYPE, &
                1, NA, NMTEST, IGND, ICTEMMOD, &
                SV%WC_THPOR, SV%WC_THLRET, SV%WC_THLMIN, SV%WC_BI, SV%WC_PSISAT, &
                SV%WC_GRKSAT, SV%WC_HCPS, SV%WC_TCS)

!> Allocate variables for WATDRN3
!> ******************************************************************
!> DGP - June 3, 2011: Now that variables are shared, moved from WD3
!> flag to ensure allocation.
    allocate(BTC(NTYPE, IGND), BCAP(NTYPE, IGND), DCOEFF(NTYPE, IGND), &
             BFCAP(NTYPE, IGND), BFCOEFF(NTYPE, IGND), BFMIN(NTYPE, IGND), &
             BQMAX(NTYPE, IGND), stat = PAS)

!> Call WATDRN3B to set WATDRN (Ric) variables
!> ******************************************************************
!> DGP - May 5, 2011: Added.
    if (PAS /= 0) print *, 'Error allocating on WD3 for new WATDRN.'
    call WATDRN3B(PSISROW, THPROW, GRKSROW, BIROW, cp%XSLPROW, cp%DDROW, &
                  NA, NTYPE, IGND, &
                  BTC, BCAP, DCOEFF, BFCAP, BFCOEFF, BFMIN, BQMAX, &
                  cp%SANDROW, cp%CLAYROW)

!> *********************************************************************
!> MAM - Initialize ENDDATE and ENDDATA
!> *********************************************************************
    ENDDATE = .false.
    ENDDATA = .false.

    call climate_module_loaddata(shd, .true., cm, NML, il1, il2, ENDDATA)

    if (ipid == 0) then
        TOTAL_STORE = 0.0
        TOTAL_STORE_2 = 0.0
        TOTAL_RCAN = 0.0
        TOTAL_SCAN = 0.0
        TOTAL_SNO = 0.0
        TOTAL_WSNO = 0.0
        TOTAL_ZPND = 0.0
        TOTAL_THLQ = 0.0
        TOTAL_THIC = 0.0
        TOTAL_STORE_M = 0.0
        TOTAL_STORE_2_M = 0.0
        TOTAL_STORE_ACC_M = 0.0
        TOTAL_RCAN_M = 0.0
        TOTAL_SCAN_M = 0.0
        TOTAL_SNO_M = 0.0
        TOTAL_WSNO_M = 0.0
        TOTAL_ZPND_M = 0.0
        TOTAL_THLQ_M = 0.0
        TOTAL_THIC_M = 0.0

    !> Open CSV output files.
        if (BASINBALANCEOUTFLAG > 0) then

        !> Water balance.
            open(fls%fl(mfk%f900)%iun, &
!todo: This creates a bug if a space doesn't exist in the name of the folder!
                 file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/' // trim(adjustl(fls%fl(mfk%f900)%fn)), &
                 iostat = ios)
!todo: Create this only by flag.
            open(902, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/Basin_average_water_balance_Monthly.csv')

            wrt_900_1 = 'DAY,YEAR,PREACC' // ',EVAPACC,ROFACC,ROFOACC,' // &
                'ROFSACC,ROFBACC,PRE,EVAP,ROF,ROFO,ROFS,ROFB,SCAN,RCAN,SNO,WSNO,ZPND,'

            wrt_900_2 = 'THLQ'
            wrt_900_3 = 'THIC'
            wrt_900_4 = 'THLQIC'

            do i = 1, IGND
                write(strInt, '(i1)') i
                if (i < IGND) then
                    wrt_900_2 = trim(adjustl(wrt_900_2)) // trim(adjustl(strInt)) // ',THLQ'
                    wrt_900_3 = trim(adjustl(wrt_900_3)) // trim(adjustl(strInt)) // ',THIC'
                    wrt_900_4 = trim(adjustl(wrt_900_4)) // trim(adjustl(strInt)) // ',THLQIC'
                else
                    wrt_900_2 = trim(adjustl(wrt_900_2)) // trim(adjustl(strInt)) // ','
                    wrt_900_3 = trim(adjustl(wrt_900_3)) // trim(adjustl(strInt)) // ','
                    wrt_900_4 = trim(adjustl(wrt_900_4)) // trim(adjustl(strInt)) // ','
                end if
            end do !> i = 1, IGND

            wrt_900_f = trim(adjustl(wrt_900_1)) // &
                trim(adjustl(wrt_900_2)) // &
                trim(adjustl(wrt_900_3)) // &
                trim(adjustl(wrt_900_4)) // &
                'THLQ,THLIC,THLQIC,STORAGE,DELTA_STORAGE,DSTOR_ACC'

            write(fls%fl(mfk%f900)%iun, '(a)') trim(adjustl(wrt_900_f))
            write(902, '(a)') trim(adjustl(wrt_900_f))

        !> Energy balance.
            open(901, file = './' // GENDIR_OUT(1:index(GENDIR_OUT, ' ') - 1) // '/Basin_average_energy_balance.csv')

            write(901, '(a)') 'DAY,YEAR,HFSACC,QEVPACC'

        end if !(BASINBALANCEOUTFLAG > 0) then

!>**********************************************************************
!> Set initial SnowAge & DrySnow values for PBSM calculations
!> (MK MacDonald, Sept 2010)
!>**********************************************************************
        if (PBSMFLAG == 1) then
            do i = 1, NA  !i = 2, NA
                do m = 1, NMTEST
                    if (cp%SNOROW(i, m) <= 0.0) then
                        DrySnowROW(i, m) = 0.0 !1 = snowpack is dry (i.e. cold)
                        SnowAgeROW(i, m) = 0.0 !hours since last snowfall
       !todo: this can use the TFREZ parameter instead of a hard-coded value. (dgp: 2015-01-09)
                        if (cm%clin(cfk%TT)%climvGrd(i) >= 273.16) then
                            DrySnowROW(i, m) = 0.0
                            SnowAgeROW(i, m) = 48.0 !assume 48 hours since last snowfall
                        else
                            DrySnowROW(i, m) = 1.0
                            SnowAgeROW(i, m) = 48.0
                        end if
                    end if
                end do
            end do
        end if !PBSMFLAG == 1

    end if !(ipid == 0) then

    call CLASSG(TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                TCANGAT, RCANGAT, SCANGAT, GROGAT, FRZCGAT, CMAIGAT, &
                FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, IGDRGAT, &
                THFCGAT, PSIWGAT, DLZWGAT, ZBTWGAT, VMODGAT, &
                ZSNLGAT, ZPLGGAT, ZPLSGAT, TACGAT, QACGAT, &
                DRNGAT, XSLPGAT, XDGAT, WFSFGAT, KSGAT, &
                ALGWGAT, ALGDGAT, ASVDGAT, ASIDGAT, AGVDGAT, &
                AGIDGAT, ISNDGAT, RADJGAT, ZBLDGAT, Z0ORGAT, &
                ZRFMGAT, ZRFHGAT, ZDMGAT, ZDHGAT, FSVHGAT, &
                FSIHGAT, CSZGAT, FDLGAT, ULGAT, VLGAT, &
                TAGAT, QAGAT, PRESGAT, PREGAT, PADRGAT, &
                VPDGAT, TADPGAT, RHOAGAT, RPCPGAT, TRPCGAT, &
                SPCPGAT, TSPCGAT, RHSIGAT, FCLOGAT, DLONGAT, &
                GGEOGAT, &
                CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT, &
                QFSGAT, QFXGAT, PETGAT, GAGAT, EFGAT, &
                GTGAT, QGGAT, ALVSGAT, ALIRGAT, &
                SFCTGAT, SFCUGAT, SFCVGAT, SFCQGAT, FSNOGAT, &
                FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, &
                FLGGGAT, HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, &
                HEVSGAT, HEVGGAT, HMFCGAT, HMFNGAT, HTCCGAT, &
                HTCSGAT, PCFCGAT, PCLCGAT, PCPNGAT, PCPGGAT, &
                QFGGAT, QFNGAT, QFCLGAT, QFCFGAT, ROFGAT, &
                ROFOGAT, ROFSGAT, ROFBGAT, TROFGAT, TROOGAT, &
                TROSGAT, TROBGAT, ROFCGAT, ROFNGAT, ROVGGAT, &
                WTRCGAT, WTRSGAT, WTRGGAT, DRGAT, GFLXGAT, &
                HMFGGAT, HTCGAT, QFCGAT, ITCTGAT, &
!BEGIN: PDMROF
                CMINPDM, CMAXPDM, BPDM, K1PDM, K2PDM,  &
!END: PDMROF
                shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, NA, NTYPE, &
                NML, il1, il2, IGND, ICAN, ICP1, cp%TBARROW, cp%THLQROW, &
                cp%THICROW, cp%TPNDROW, cp%ZPNDROW, TBASROW, cp%ALBSROW, &
                cp%TSNOROW, cp%RHOSROW, cp%SNOROW, cp%TCANROW, &
                cp%RCANROW, cp%SCANROW, cp%GROROW, CMAIROW, cp%FCANROW, &
                cp%LNZ0ROW, cp%ALVCROW, cp%ALICROW, cp%PAMXROW, &
                cp%PAMNROW, cp%CMASROW, cp%ROOTROW, cp%RSMNROW, &
                cp%QA50ROW, cp%VPDAROW, cp%VPDBROW, cp%PSGAROW, &
                cp%PSGBROW, PAIDROW, HGTDROW, ACVDROW, ACIDROW, TSFSROW, &
                WSNOROW, THPROW, THRROW, THMROW, BIROW, PSISROW, &
                GRKSROW, THRAROW, HCPSROW, TCSROW, IGDRROW, &
                THFCROW, PSIWROW, DLZWROW, ZBTWROW, VMODGRD, &
                hp%ZSNLROW, hp%ZPLGROW, hp%ZPLSROW, hp%FRZCROW, TACROW, QACROW, &
                cp%DRNROW, cp%XSLPROW, cp%XDROW, WFSFROW, cp%KSROW, &
                ALGWROW, ALGDROW, ASVDROW, ASIDROW, AGVDROW, &
                AGIDROW, ISNDROW, RADJGRD, cp%ZBLDGRD, Z0ORGRD, &
                cp%ZRFMGRD, cp%ZRFHGRD, ZDMGRD, ZDHGRD, FSVHGRD, &
                FSIHGRD, CSZGRD, cm%clin(cfk%FI)%climvGrd, cm%clin(cfk%UV)%climvGrd, VLGRD, &
                cm%clin(cfk%TT)%climvGrd, cm%clin(cfk%HU)%climvGrd, cm%clin(cfk%P0)%climvGrd, cm%clin(cfk%PR)%climvGrd, PADRGRD, &
                VPDGRD, TADPGRD, RHOAGRD, RPCPGRD, TRPCGRD, &
                SPCPGRD, TSPCGRD, RHSIGRD, FCLOGRD, DLONGRD, &
                GGEOGRD, cp%MANNROW, MANNGAT, cp%DDROW, DDGAT, &
                cp%SANDROW, SANDGAT, cp%CLAYROW, CLAYGAT, &
!BEGIN: PDMROF
                hp%CMINROW, hp%CMAXROW, hp%BROW, hp%K1ROW, hp%K2ROW, &
!END: PDMROF
                cp%FAREROW, FAREGAT, &
                hp%fetchROW, hp%HtROW, hp%N_SROW, hp%A_SROW, hp%DistribROW, &
                fetchGAT, HtGAT, N_SGAT, A_SGAT, DistribGAT, &
                DrySnowRow, SnowAgeROW, DrySnowGAT, SnowAgeGAT, &
                TSNOdsROW, RHOSdsROW, TSNOdsGAT, RHOSdsGAT, &
                DriftROW, SublROW, DepositionROW, &
                DriftGAT, SublGAT, DepositionGAT)

    !> Initialize and open files for CLASS output.
    if ((ipid /= 0 .or. izero == 0) .and. WF_NUM_POINTS > 0) then

        !> After GATPREP. Determine the GAT-index of the output point.
        op%K_OUT = 0
        do k = il1, il2
            do i = 1, WF_NUM_POINTS
                if (op%N_OUT(i) == shd%lc%ILMOS(k) .and. op%II_OUT(i) == shd%lc%JLMOS(k)) op%K_OUT(i) = k
            end do
        end do

        !> Allocate the CLASS output variables.
        allocate(co%PREACC(WF_NUM_POINTS), co%GTACC(WF_NUM_POINTS), co%QEVPACC(WF_NUM_POINTS), co%EVAPACC(WF_NUM_POINTS), &
                 co%HFSACC(WF_NUM_POINTS), co%HMFNACC(WF_NUM_POINTS), &
                 co%ROFACC(WF_NUM_POINTS), co%ROFOACC(WF_NUM_POINTS), co%ROFSACC(WF_NUM_POINTS), co%ROFBACC(WF_NUM_POINTS), &
                 co%WTBLACC(WF_NUM_POINTS), co%ALVSACC(WF_NUM_POINTS), co%ALIRACC(WF_NUM_POINTS), &
                 co%RHOSACC(WF_NUM_POINTS), co%TSNOACC(WF_NUM_POINTS), co%WSNOACC(WF_NUM_POINTS), co%SNOARE(WF_NUM_POINTS), &
                 co%TCANACC(WF_NUM_POINTS), co%CANARE(WF_NUM_POINTS), co%SNOACC(WF_NUM_POINTS), &
                 co%RCANACC(WF_NUM_POINTS), co%SCANACC(WF_NUM_POINTS), co%GROACC(WF_NUM_POINTS), co%FSINACC(WF_NUM_POINTS), &
                 co%FLINACC(WF_NUM_POINTS), co%FLUTACC(WF_NUM_POINTS), &
                 co%TAACC(WF_NUM_POINTS), co%UVACC(WF_NUM_POINTS), co%PRESACC(WF_NUM_POINTS), co%QAACC(WF_NUM_POINTS))
        allocate(co%TBARACC(WF_NUM_POINTS, IGND), co%THLQACC(WF_NUM_POINTS, IGND), co%THICACC(WF_NUM_POINTS, IGND), &
                 co%THALACC(WF_NUM_POINTS, IGND), co%GFLXACC(WF_NUM_POINTS, IGND))

        !> Initialize the CLASS output variables.
        co%PREACC = 0.0
        co%GTACC = 0.0
        co%QEVPACC = 0.0
        co%EVAPACC = 0.0
        co%HFSACC = 0.0
        co%HMFNACC = 0.0
        co%ROFACC = 0.0
        co%ROFOACC = 0.0
        co%ROFSACC = 0.0
        co%ROFBACC = 0.0
        co%WTBLACC = 0.0
        co%TBARACC = 0.0
        co%THLQACC = 0.0
        co%THICACC = 0.0
        co%THALACC = 0.0
        co%GFLXACC = 0.0
        co%ALVSACC = 0.0
        co%ALIRACC = 0.0
        co%RHOSACC = 0.0
        co%TSNOACC = 0.0
        co%WSNOACC = 0.0
        co%SNOARE = 0.0
        co%TCANACC = 0.0
        co%CANARE = 0.0
        co%SNOACC = 0.0
        co%RCANACC = 0.0
        co%SCANACC = 0.0
        co%GROACC = 0.0
        co%FSINACC = 0.0
        co%FLINACC = 0.0
        co%FLUTACC = 0.0
        co%TAACC = 0.0
        co%UVACC = 0.0
        co%PRESACC = 0.0
        co%QAACC = 0.0

        !> Open the files if the GAT-index of the output point resides on this node.
        do i = 1, WF_NUM_POINTS
            if ((ipid /= 0 .or. izero == 0) .and. op%K_OUT(i) >= il1 .and. op%K_OUT(i) <= il2) then

                !> Open the files in the appropriate directory.
                BNAM = op%DIR_OUT(i)
                j = 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF1.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF2.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF3.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF4.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF5.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF6.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF7.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF8.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/CLASSOF9.csv'); j = j + 1
                open(150 + i*10 + j, file = './' // trim(adjustl(BNAM)) // '/GRU_water_balance.csv')

                !> Write project header information.
                do j = 1, 9
                    write(150 + i*10 + j, "('CLASS TEST RUN:     ', 6a4)") TITLE1, TITLE2, TITLE3, TITLE4, TITLE5, TITLE6
                    write(150 + i*10 + j, "('RESEARCHER:         ', 6a4)") NAME1, NAME2, NAME3, NAME4, NAME5, NAME6
                    write(150 + i*10 + j, "('INSTITUTION:        ', 6a4)") PLACE1, PLACE2, PLACE3, PLACE4, PLACE5, PLACE6
                end do

                !> CLASSOF1.
                write(150 + i*10 + 1, "('IDAY,IYEAR,FSSTAR,FLSTAR,QH,QE,SNOMLT,BEG," // &
                    'GTOUT,SNOACC(I),RHOSACC(I),WSNOACC(I),ALTOT,ROFACC(I),' // &
                    "ROFOACC(I),ROFSACC(I),ROFBACC(I)')")

                !> CLASSOF2.
                write(FMT, *) ''
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // 'TBARACC(I ' // trim(IGND_CHAR) // ')-TFREZ,THLQACC(I ' // &
                        trim(IGND_CHAR) // '),THICACC(I ' // trim(IGND_CHAR) // '),'
                end do
                write(150 + i*10 + 2, "('IDAY,IYEAR," // trim(FMT) // "TCN,RCANACC(I),SCANACC(I),TSN,ZSN')")

                !> CLASSOF3.
                write(150 + i*10 + 3, "('IDAY,IYEAR,FSINACC(I),FLINACC(I)," // &
                    'TAACC(I)-TFREZ,UVACC(I),PRESACC(I),QAACC(I),PREACC(I),' // &
                    "EVAPACC(I)')")

                !> CLASSOF4.
                write(150 + i*10 + 4, "('IHOUR,IMIN,IDAY,IYEAR,FSSTAR,FLSTAR,QH,QE," // &
                    'SNOMLT,BEG,GTOUT,SNOROW(I M),RHOSROW(I M),WSNOROW(I M),ALTOT,' // &
                    "ROFROW(I M),TPN,ZPNDROW(I M),ZPND,FSTR')")

                !> CLASSOF5.
                write(FMT, *) ''
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // 'TBARROW(I ' // trim(IGND_CHAR) // ')-TFREZ,THLQROW(I ' // &
                        trim(IGND_CHAR) // '),THICROW(I ' // trim(IGND_CHAR) // '),'
                end do
                write(150 + i*10 + 5, "('IHOUR,IMIN,IDAY,IYEAR," // trim(FMT) // "TCN,RCANROW(I M),SCANROW(I M),TSN,ZSN')")

                !> CLASSOF6.
                write(150 + i*10 + 6, "('IHOUR,IMIN,IDAY,FSDOWN(I),FDLGRD(I)," // &
                    "PREGRD(I),TAGRD(I)-TFREZ,UVGRD(I),PRESGRD(I),QAGRD(I)')")

                !> CLASSOF7.
                write(150 + i*10 + 7,"('TROFROW(I M),TROOROW(I M),TROSROW(I M)," // &
                    'TROBROW(I M),ROFROW(I M),ROFOROW(I M),ROFSROW(I M),' // &
                    "ROFBROW(I M),FCS(I),FGS(I),FC(I),FG(I)')")

                !> CLASSOF8.
                write(FMT, *) ''
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // ',HMFGROW(I M ' // trim(IGND_CHAR) // ')'
                end do
                FMT = trim(adjustl(FMT)) // ',HTCCROW(I M),HTCSROW(I M)'
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // ',HTCROW(I M ' // trim(IGND_CHAR) // ')'
                end do
                write(150 + i*10 + 8, "('FSGVROW(I M),FSGSROW(I M),FSGGROW(I M)," // &
                    'FLGVROW(I M),FLGSROW(I M),FLGGROW(I M),HFSCROW(I M),' // &
                    'HFSSROW(I M),HFSGROW(I M),HEVCROW(I M),HEVSROW(I M),' // &
                    'HEVGROW(I M),HMFCROW(I M),HMFNROW(I M)' // trim(FMT) // "')")

                !> CLASSOF9.
                write(FMT, *) ''
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // 'QFCROW(I M ' // trim(IGND_CHAR) // '),'
                end do
                write(150 + i*10 + 9, "('PCFCROW(I M),PCLCROW(I M),PCPNROW(I M)," // &
                    'PCPGROW(I M),QFCFROW(I M),QFCLROW(I M),QFNROW(I M),QFGROW(I M),' // trim(FMT) // 'ROFCROW(I M),' // &
                    'ROFNROW(I M),ROFOROW(I M),ROFROW(I M),WTRCROW(I M),' // &
                    "WTRSROW(I M),WTRGROW(I M)')")

                !> GRU water balance file.
                write(FMT, *) ''
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // 'THLQ' // trim(IGND_CHAR) // ','
                end do
                do j = 1, IGND
                    write(IGND_CHAR, *) j
                    IGND_CHAR = adjustl(IGND_CHAR)
                    FMT = trim(adjustl(FMT)) // 'THIC' // trim(IGND_CHAR) // ','
                end do
                write(150 + i*10 + 10, "('IHOUR,IMIN,IDAY,IYEAR," // &
                    'PRE,EVAP,ROF,ROFO,ROFS,ROFB,' // &
                    'SCAN,RCAN,SNO,WSNO,ZPND,' // trim(FMT) // "')")

            end if !(op%K_OUT(i) >= il1 .and. op%K_OUT(i) <= il2) then
        end do !i = 1, wf_num_points
    end if !(WF_NUM_POINTS > 0) then

!> *********************************************************************
!> End of Initialization
!> *********************************************************************

    if (ro%VERBOSEMODE > 0) then
        print *
        print 2836
        print 2835
    end if !(ro%VERBOSEMODE > 0) then

2836    format(/1x, 'DONE INTITIALIZATION')
2835    format(/1x, 'STARTING MESH')

!> *********************************************************************
!> Start of main loop that is run each half hour
!> *********************************************************************
    do while (.not. ENDDATE .and. .not. ENDDATA)

!* N: is only used for debugging purposes.
!> N is incremented at the beginning of each loop. so you can tell which
!> iteration of the loop you are on by what the value of N is.
!> N is printed out with each of the error messages in CLASSZ.
        N = N + 1

    !> MAM - Linearly interpolate forcing data for intermediate time steps
        if (INTERPOLATIONFLAG == 1) then
            call climate_module_interpolatedata(shd, FAREGAT, cm, NML, il1, il2)
        end if
        UVGRD = max(VMIN, cm%clin(cfk%UV)%climvGrd)
        VMODGRD = UVGRD
        VMODGAT = max(VMIN, ULGAT)

!> *********************************************************************
!> Read in current reservoir release value
!> *********************************************************************

!> only read in current value if we are on the correct time step
!> however put in an exception if this is the first time through (ie. jan = 1),
!> otherwise depending on the hour of the first time step
!> there might not be any data in wf_qrel, wf_qhyd
!> make sure we have a controlled reservoir (if not the mod(HOUR_NOW, wf_ktr)
!> may give an error. Frank S Jun 2007
        if (WF_NORESV_CTRL > 0) then
            if (mod(HOUR_NOW, WF_KTR) == 0 .and. MINS_NOW == 0) then
!>        READ in current reservoir value
                read(21, '(100f10.3)', iostat = IOS) (WF_QREL(i), i = 1, WF_NORESV_CTRL)
                if (IOS /= 0) then
                    print *, 'ran out of reservoir data before met data'
                    stop
                end if
            else
                if (JAN == 1 .and. WF_NORESV_CTRL > 0) then
                    read(21, '(100f10.3)', iostat = IOS) (WF_QREL(i), i = 1, WF_NORESV_CTRL)
                    rewind 21
                    read(21, *)
                    do i = 1, WF_NORESV
                        read(21, *)
                    end do
                end if
            end if
        end if

! *********************************************************************
!> Read in current streamflow value
!> *********************************************************************

!> only read in current value if we are on the correct time step
!> also read in the first value if this is the first time through
        if (mod(HOUR_NOW, WF_KT) == 0 .and. MINS_NOW == 0 .and. JAN > 1) then
!>       read in current streamflow value
            read(22, *, iostat = IOS) (WF_QHYD(i), i = 1, WF_NO)
            if (IOS /= 0) then
                print *, 'ran out of streamflow data before met data'
                stop
            end if
        end if

!> *********************************************************************
!> Set some more CLASS parameters
!> *********************************************************************

!> This estimates the fractional cloud cover (FCLOGRD) by the basis
!>  of the solar zenith angle and the occurrence of precipitation.
!>  Assumed to be 1 (100%) when precipitation occurs and somewhere
!>  in the range of [0.1, 1] based on the location of the sun in the
!>  sky when precipitation is not occuring. (0.1 when the sun is at
!>  the zenith, 1 when the sun is at the horizon).
        RDAY = real(JDAY_NOW) + (real(HOUR_NOW) + real(MINS_NOW)/60.0)/24.0
        DECL = sin(2.0*PI*(284.0 + RDAY)/365.0)*23.45*PI/180.0
        HOUR = (real(HOUR_NOW) + real(MINS_NOW)/60.0)*PI/12.0 - PI

        do k = il1, il2
            ik = shd%lc%ILMOS(k)
            COSZ = sin(RADJGAT(k))*sin(DECL) + cos(RADJGAT(k))*cos(DECL)*cos(HOUR)
            CSZGAT(k) = sign(max(abs(COSZ), 1.0e-3), COSZ)
            CSZGRD(ik) = CSZGAT(k)
            if (PREGAT(k) > 0.0) then
    !todo: there isn't a GAT variable for this (although, there might be for the canopy)?
                XDIFFUS(ik) = 1.0
            else
                XDIFFUS(ik) = max(0.0, min(1.0 - 0.9*COSZ, 1.0))
            end if
            FCLOGAT(k) = XDIFFUS(ik)
            FCLOGRD(ik) = FCLOGAT(k)
        end do

!> *********************************************************************
!> Start of calls to CLASS subroutines
!> *********************************************************************

        !> Were initialized in CLASSG and so have been extracted.
        DriftGAT = 0.0 !DriftROW (ILMOS(k), JLMOS(k))
        SublGAT = 0.0 !SublROW (ILMOS(k), JLMOS(k))
        DepositionGAT = 0.0

!>
!>   * INITIALIZATION OF DIAGNOSTIC VARIABLES SPLIT OUT OF CLASSG
!>   * FOR CONSISTENCY WITH GCM APPLICATIONS.
!>

        CDHGAT = 0.0
        CDMGAT = 0.0
        HFSGAT = 0.0
        TFXGAT = 0.0
        QEVPGAT = 0.0
        QFSGAT = 0.0
        QFXGAT = 0.0
        PETGAT = 0.0
        GAGAT = 0.0
        EFGAT = 0.0
        GTGAT = 0.0
        QGGAT = 0.0
        ALVSGAT = 0.0
        ALIRGAT = 0.0
        SFCTGAT = 0.0
        SFCUGAT = 0.0
        SFCVGAT = 0.0
        SFCQGAT = 0.0
        FSNOGAT = 0.0
        FSGVGAT = 0.0
        FSGSGAT = 0.0
        FSGGGAT = 0.0
        FLGVGAT = 0.0
        FLGSGAT = 0.0
        FLGGGAT = 0.0
        HFSCGAT = 0.0
        HFSSGAT = 0.0
        HFSGGAT = 0.0
        HEVCGAT = 0.0
        HEVSGAT = 0.0
        HEVGGAT = 0.0
        HMFCGAT = 0.0
        HMFNGAT = 0.0
        HTCCGAT = 0.0
        HTCSGAT = 0.0
        PCFCGAT = 0.0
        PCLCGAT = 0.0
        PCPNGAT = 0.0
        PCPGGAT = 0.0
        QFGGAT = 0.0
        QFNGAT = 0.0
        QFCFGAT = 0.0
        QFCLGAT = 0.0
        ROFGAT = 0.0
        ROFOGAT = 0.0
        ROFSGAT = 0.0
        ROFBGAT = 0.0
        TROFGAT = 0.0
        TROOGAT = 0.0
        TROSGAT = 0.0
        TROBGAT = 0.0
        ROFCGAT = 0.0
        ROFNGAT = 0.0
        ROVGGAT = 0.0
        WTRCGAT = 0.0
        WTRSGAT = 0.0
        WTRGGAT = 0.0
        DRGAT = 0.0
        HMFGGAT = 0.0
        HTCGAT = 0.0
        QFCGAT = 0.0
        GFLXGAT = 0.0
        ITCTGAT = 0

        call CLASSI(VPDGAT, TADPGAT, PADRGAT, RHOAGAT, RHSIGAT, &
                    RPCPGAT, TRPCGAT, SPCPGAT, TSPCGAT, TAGAT, QAGAT, &
                    PREGAT, RPREGAT, SPREGAT, PRESGAT, &
                    IPCP, NML, il1, il2)

        if (ipid == 0) then

!> Calculate initial storage (after reading in resume.txt file if applicable)
            if (JAN == 1) then
                INIT_STORE = 0.0
                do i = 1, NA
                    if (shd%FRAC(i) >= 0.0) then
                        do m = 1, NMTEST
                            INIT_STORE = INIT_STORE + cp%FAREROW(i, m)* &
                                (cp%RCANROW(i, m) + cp%SCANROW(i, m) + cp%SNOROW(i, m) + WSNOROW(i, m) + cp%ZPNDROW(i, m)*RHOW)
                            wb%stg(i) = cp%FAREROW(i, m)* &
                                (cp%RCANROW(i, m) + cp%SCANROW(i, m) + cp%SNOROW(i, m) + WSNOROW(i, m) + cp%ZPNDROW(i, m)*RHOW)
                            do j = 1, IGND
                                INIT_STORE = INIT_STORE + cp%FAREROW(i, m)* &
                                    (cp%THLQROW(i, m, j)*RHOW + cp%THICROW(i, m, j)*RHOICE)*DLZWROW(i, m, j)
                                wb%stg(i) = cp%FAREROW(i, m)* &
                                    (cp%THLQROW(i, m, j)*RHOW + cp%THICROW(i, m, j)*RHOICE)*DLZWROW(i, m, j)
                            end do
                        end do
                        wb%dstg(i) = wb%stg(i)
                    end if
                end do
                TOTAL_STORE_2 = INIT_STORE

    ! For monthly totals.
                call FIND_MONTH(JDAY_NOW, YEAR_NOW, imonth_old)
                TOTAL_STORE_2_M = INIT_STORE
            end if

!>=========================================================================
!> Initialization of the Storage field
            if (JAN == 1) then
                do m = 1, NMTEST
                    STG_I(:) = STG_I(:) + cp%FAREROW(:, m)*(cp%RCANROW(:, m) + &
                                                            cp%SCANROW(:, m) + &
                                                            cp%SNOROW(:, m)  + &
                                                            cp%ZPNDROW(:, m)*RHOW)
                    do j = 1, IGND
                        STG_I(:) = STG_I(:) + cp%FAREROW(:, m)*(cp%THLQROW(:, m, j)*RHOW + &
                                                                cp%THICROW(:, m, j)*RHOICE)*DLZWROW(:, m, j)
                    end do
                end do
            end if

        end if !(ipid == 0) then

!> *********************************************************************
!> Start of the NML-based LSS loop.
!> *********************************************************************

!> ========================================================================
        if (ipid /= 0 .or. izero == 0) then

            call CLASSZ(0, CTVSTP, CTSSTP, CT1STP, CT2STP, CT3STP, &
                        WTVSTP, WTSSTP, WTGSTP, &
                        FSGVGAT, FLGVGAT, HFSCGAT, HEVCGAT, HMFCGAT, HTCCGAT, &
                        FSGSGAT, FLGSGAT, HFSSGAT, HEVSGAT, HMFNGAT, HTCSGAT, &
                        FSGGGAT, FLGGGAT, HFSGGAT, HEVGGAT, HMFGGAT, HTCGAT, &
                        PCFCGAT, PCLCGAT, QFCFGAT, QFCLGAT, ROFCGAT, WTRCGAT, &
                        PCPNGAT, QFNGAT, ROFNGAT, WTRSGAT, PCPGGAT, QFGGAT, &
                        QFCGAT, ROFGAT, WTRGGAT, CMAIGAT, RCANGAT, SCANGAT, &
                        TCANGAT, SNOGAT, WSNOGAT, TSNOGAT, THLQGAT, THICGAT, &
                        HCPSGAT, THPGAT, DLZWGAT, TBARGAT, ZPNDGAT, TPNDGAT, &
                        sl%DELZ, FCS, FGS, FC, FG, &
                        il1, il2, NML, IGND, N, &
                        DriftGAT, SublGAT)

!> ========================================================================
!> ALBEDO AND TRANSMISSIVITY CALCULATIONS; GENERAL VEGETATION
!> CHARACTERISTICS.
            call CLASSA(FC, FG, FCS, FGS, ALVSCN, ALIRCN, &
                        ALVSG, ALIRG, ALVSCS, ALIRCS, ALVSSN, ALIRSN, &
                        ALVSGC, ALIRGC, ALVSSC, ALIRSC, TRVSCN, TRIRCN, &
                        TRVSCS, TRIRCS, FSVF, FSVFS, &
                        RAICAN, RAICNS, SNOCAN, SNOCNS, FRAINC, FSNOWC, &
                        FRAICS, FSNOCS, &
                        DISP, DISPS, ZOMLNC, ZOMLCS, &
                        ZOELNC, ZOELCS, ZOMLNG, ZOMLNS, ZOELNG, ZOELNS, &
                        CHCAP, CHCAPS, CMASSC, CMASCS, CWLCAP, CWFCAP, &
                        CWLCPS, CWFCPS, RC, RCS, RBCOEF, FROOT, &
                        ZPLIMC, ZPLIMG, ZPLMCS, ZPLMGS, TRSNOW, ZSNOW, &
                        WSNOGAT, ALVSGAT, ALIRGAT, HTCCGAT, HTCSGAT, HTCGAT, &
                        WTRCGAT, WTRSGAT, WTRGGAT, CMAIGAT, FSNOGAT, &
                        FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, PAMNGAT, &
                        CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, VPDAGAT, VPDBGAT, &
                        PSGAGAT, PSGBGAT, PAIDGAT, HGTDGAT, ACVDGAT, ACIDGAT, &
                        ASVDGAT, ASIDGAT, AGVDGAT, AGIDGAT, ALGWGAT, ALGDGAT, &
                        THLQGAT, THICGAT, TBARGAT, RCANGAT, SCANGAT, TCANGAT, &
                        GROGAT, SNOGAT, TSNOGAT, RHOSGAT, ALBSGAT, ZBLDGAT, &
                        Z0ORGAT, ZSNLGAT, ZPLGGAT, ZPLSGAT, &
                        FCLOGAT, TAGAT, VPDGAT, RHOAGAT, CSZGAT, &
                        FSVHGAT, RADJGAT, DLONGAT, RHSIGAT, sl%DELZ, DLZWGAT, &
                        ZBTWGAT, THPGAT, THMGAT, PSISGAT, BIGAT, PSIWGAT, &
                        HCPSGAT, ISNDGAT, &
                        FCANCMX, ICTEM, ICTEMMOD, RMATC, &
                        AILC, PAIC, L2MAX, NOL2PFTS, &
                        AILCG, AILCGS, FCANC, FCANCS, &
                        JDAY_NOW, NML, il1, il2, &
                        JLAT, N, ICAN, ICAN + 1, IGND, IDISP, IZREF, &
                        IWF, IPAI, IHGT, IALC, IALS, IALG)
!
!-----------------------------------------------------------------------
!          * SURFACE TEMPERATURE AND FLUX CALCULATIONS.
!
            call CLASST(TBARC, TBARG, TBARCS, TBARGS, THLIQC, THLIQG, &
                        THICEC, THICEG, HCPC, HCPG, TCTOPC, TCBOTC, TCTOPG, TCBOTG, &
                        GZEROC, GZEROG, GZROCS, GZROGS, G12C, G12G, G12CS, G12GS, &
                        G23C, G23G, G23CS, G23GS, QFREZC, QFREZG, QMELTC, QMELTG, &
                        EVAPC, EVAPCG, EVAPG, EVAPCS, EVPCSG, EVAPGS, TCANO, TCANS, &
                        RAICAN, SNOCAN, RAICNS, SNOCNS, CHCAP, CHCAPS, TPONDC, TPONDG, &
                        TPNDCS, TPNDGS, TSNOCS, TSNOGS, WSNOCS, WSNOGS, RHOSCS, RHOSGS, &
                        ITCTGAT, CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT, QFSGAT, QFXGAT, &
                        PETGAT, GAGAT, EFGAT, GTGAT, QGGAT, SFCTGAT, SFCUGAT, SFCVGAT, &
                        SFCQGAT, SFRHGAT, FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, FLGGGAT, &
                        HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, HEVSGAT, HEVGGAT, HMFCGAT, HMFNGAT, &
                        HTCCGAT, HTCSGAT, HTCGAT, QFCFGAT, QFCLGAT, DRGAT, WTABGAT, ILMOGAT, &
                        UEGAT, HBLGAT, TACGAT, QACGAT, ZRFMGAT, ZRFHGAT, ZDMGAT, ZDHGAT, &
                        VPDGAT, TADPGAT, RHOAGAT, FSVHGAT, FSIHGAT, FDLGAT, ULGAT, VLGAT, &
                        TAGAT, QAGAT, PADRGAT, FC, FG, FCS, FGS, RBCOEF, &
                        FSVF, FSVFS, PRESGAT, VMODGAT, ALVSCN, ALIRCN, ALVSG, ALIRG, &
                        ALVSCS, ALIRCS, ALVSSN, ALIRSN, ALVSGC, ALIRGC, ALVSSC, ALIRSC, &
                        TRVSCN, TRIRCN, TRVSCS, TRIRCS, RC, RCS, WTRGGAT, QLWOGAT, &
                        FRAINC, FSNOWC, FRAICS, FSNOCS, CMASSC, CMASCS, DISP, DISPS, &
                        ZOMLNC, ZOELNC, ZOMLNG, ZOELNG, ZOMLCS, ZOELCS, ZOMLNS, ZOELNS, &
                        TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, TBASGAT, TCANGAT, TSNOGAT, &
                        ZSNOW, TRSNOW, RHOSGAT, WSNOGAT, THPGAT, THRGAT, THMGAT, THFCGAT, &
                        RADJGAT, PREGAT, HCPSGAT, TCSGAT, TSFSGAT, sl%DELZ, DLZWGAT, ZBTWGAT, &
                        FTEMP, FVAP, RIB, ISNDGAT, &
                        AILCG, AILCGS, FCANC, FCANCS, CO2CONC, CO2I1CG, CO2I1CS, CO2I2CG, &
                        CO2I2CS, COSZS, XDIFFUSC, SLAI, ICTEM, ICTEMMOD, RMATCTEM, &
                        FCANCMX, L2MAX, NOL2PFTS, CFLUXCG, CFLUXCS, ANCSVEG, ANCGVEG, &
                        RMLCSVEG, RMLCGVEG, FIELDSM, WILTSM, &
                        ITC, ITCG, ITG, NML, il1, il2, JLAT, N, ICAN, &
                        IGND, IZREF, ISLFD, NLANDCS, NLANDGS, NLANDC, NLANDG, NLANDI)
!
!-----------------------------------------------------------------------
!          * WATER BUDGET CALCULATIONS.
!
            if (JDAY_NOW == 1 .and. NCOUNT == 48) then
       ! bruce davison - only increase NMELT if we don't start the run on January 1st, otherwise t0_ACC allocation is too large
       ! and the model crashes if the compiler is checking for array bounds when t0_ACC is passed into CLASSW with size NMELT
                if (JDAY_START == 1 .and. NSUM_TOTAL < 49) then
                    continue ! NMELT should stay = 1
                else
                    NMELT = NMELT + 1
                end if
                CUMSNOWINFILCS = 0.0
                CUMSNOWINFILGS = 0.0
                INFILTYPE = 2
            end if

            call CLASSW(THLQGAT, THICGAT, TBARGAT, TCANGAT, RCANGAT, SCANGAT, &
                        ROFGAT, TROFGAT, SNOGAT, TSNOGAT, RHOSGAT, ALBSGAT, &
                        WSNOGAT, ZPNDGAT, TPNDGAT, GROGAT, FRZCGAT, TBASGAT, GFLXGAT, &
                        PCFCGAT, PCLCGAT, PCPNGAT, PCPGGAT, QFCFGAT, QFCLGAT, &
                        QFNGAT, QFGGAT, QFCGAT, HMFCGAT, HMFGGAT, HMFNGAT, &
                        HTCCGAT, HTCSGAT, HTCGAT, ROFCGAT, ROFNGAT, ROVGGAT, &
                        WTRSGAT, WTRGGAT, ROFOGAT, ROFSGAT, ROFBGAT, &
                        TROOGAT, TROSGAT, TROBGAT, QFSGAT, &
                        TBARC, TBARG, TBARCS, TBARGS, THLIQC, THLIQG, &
                        THICEC, THICEG, HCPC, HCPG, RPCPGAT, TRPCGAT, &
                        SPCPGAT, TSPCGAT, PREGAT, TAGAT, RHSIGAT, GGEOGAT, &
                        FC, FG, FCS, FGS, TPONDC, TPONDG, &
                        TPNDCS, TPNDGS, EVAPC, EVAPCG, EVAPG, EVAPCS, &
                        EVPCSG, EVAPGS, QFREZC, QFREZG, QMELTC, QMELTG, &
                        RAICAN, SNOCAN, RAICNS, SNOCNS, FROOT, FSVF, &
                        FSVFS, CWLCAP, CWFCAP, CWLCPS, CWFCPS, TCANO, &
                        TCANS, CHCAP, CHCAPS, CMASSC, CMASCS, ZSNOW, &
                        GZEROC, GZEROG, GZROCS, GZROGS, G12C, G12G, &
                        G12CS, G12GS, G23C, G23G, G23CS, G23GS, &
                        TSNOCS, TSNOGS, WSNOCS, WSNOGS, RHOSCS, RHOSGS, &
                        ZPLIMC, ZPLIMG, ZPLMCS, ZPLMGS, TSFSGAT, &
                        TCTOPC, TCBOTC, TCTOPG, TCBOTG, &
                        THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, GRKSGAT, &
                        THRAGAT, THFCGAT, DRNGAT, HCPSGAT, sl%DELZ, &
                        DLZWGAT, ZBTWGAT, XSLPGAT, XDGAT, WFSFGAT, KSGAT, &
                        ISNDGAT, IGDRGAT, IWF, NML, il1, il2, N, &
                        JLAT, ICAN, IGND, IGND + 1, IGND + 2, &
                        NLANDCS, NLANDGS, NLANDC, NLANDG, NLANDI, &
                        MANNGAT, DDGAT, NCOUNT, &
                        t0_ACC(NMELT), SI, TSI, INFILTYPE, SNOWMELTD, SNOWMELTD_LAST, &
                        MELTRUNOFF, SNOWINFIL, CUMSNOWINFILCS, CUMSNOWINFILGS, &
                        SOIL_POR_MAX, SOIL_DEPTH, S0, T_ICE_LENS, &
                        NA, NTYPE, shd%lc%ILMOS, shd%lc%JLMOS, &
                        BTC, BCAP, DCOEFF, BFCAP, BFCOEFF, BFMIN, BQMAX, &
!FOR PDMROF
                        CMINPDM, CMAXPDM, BPDM, K1PDM, K2PDM, &
                        ZPNDPRECS, ZPONDPREC, ZPONDPREG, ZPNDPREGS, &
                        UM1CS, UM1C, UM1G, UM1GS, &
                        QM1CS, QM1C, QM1G, QM1GS, &
                        QM2CS, QM2C, QM2G, QM2GS, UMQ, &
                        FSTRCS, FSTRC, FSTRG, FSTRGS, &
                        ZSNOCS, ZSNOGS, ZSNOWC, ZSNOWG, &
                        HCPSCS, HCPSGS, HCPSC, HCPSG, &
                        TSNOWC, TSNOWG, RHOSC, RHOSG, &
                        XSNOWC, XSNOWG, XSNOCS, XSNOGS)
!
!========================================================================
!          * SINGLE COLUMN BLOWING SNOW CALCULATIONS.
!
            if (PBSMFLAG == 1) then
                call PBSMrun(ZSNOW, WSNOGAT, SNOGAT, RHOSGAT, TSNOGAT, HTCSGAT, &
                             ZSNOCS, ZSNOGS, ZSNOWC, ZSNOWG, &
                             HCPSCS, HCPSGS, HCPSC, HCPSG, &
                             TSNOWC, TSNOWG, TSNOCS, TSNOGS, &
                             RHOSC, RHOSG, RHOSCS, RHOSGS,&
                             XSNOWC, XSNOWG, XSNOCS, XSNOGS, &
                             WSNOCS, WSNOGS, &
                             FC, FG, FCS, FGS, &
                             fetchGAT, N_SGAT, A_SGAT, HtGAT, &
                             SFCTGAT, SFCUGAT, SFCQGAT, PRESGAT, PREGAT, &
                             DrySnowGAT, SnowAgeGAT, DriftGAT, SublGAT, &
                             TSNOdsGAT, &
                             NML, il1, il2, N, ZRFMGAT, ZOMLCS, ZOMLNS)
            end if
!========================================================================
!
            call CLASSZ(1, CTVSTP, CTSSTP, CT1STP, CT2STP, CT3STP, &
                        WTVSTP, WTSSTP, WTGSTP, &
                        FSGVGAT, FLGVGAT, HFSCGAT, HEVCGAT, HMFCGAT, HTCCGAT, &
                        FSGSGAT, FLGSGAT, HFSSGAT, HEVSGAT, HMFNGAT, HTCSGAT, &
                        FSGGGAT, FLGGGAT, HFSGGAT, HEVGGAT, HMFGGAT, HTCGAT, &
                        PCFCGAT, PCLCGAT, QFCFGAT, QFCLGAT, ROFCGAT, WTRCGAT, &
                        PCPNGAT, QFNGAT, ROFNGAT, WTRSGAT, PCPGGAT, QFGGAT, &
                        QFCGAT, ROFGAT, WTRGGAT, CMAIGAT, RCANGAT, SCANGAT, &
                        TCANGAT, SNOGAT, WSNOGAT, TSNOGAT, THLQGAT, THICGAT, &
                        HCPSGAT, THPGAT, DLZWGAT, TBARGAT, ZPNDGAT, TPNDGAT, &
                        sl%DELZ, FCS, FGS, FC, FG, &
                        il1, il2, NML, IGND, N, &
                        DriftGAT, SublGAT)
!
!=======================================================================
!
!          *Redistribute blowing snow mass between GRUs
!
            call REDISTRIB_SNOW(NML, 1, NA, NTYPE, NML, TSNOGAT, ZSNOW, &
                                RHOSGAT, SNOGAT, TSNOCS, ZSNOCS, HCPSCS, RHOSCS, TSNOGS, &
                                ZSNOGS, HCPSGS, RHOSGS, TSNOWC, ZSNOWC, HCPSC, RHOSC, TSNOWG, &
                                ZSNOWG, HCPSG, RHOSG, cp%GCGRD, shd%lc%ILMOS, DriftGAT, FAREGAT, &
                                TSNOdsGAT, DistribGAT, WSNOCS, WSNOGS, FCS, FGS, FC, FG, DepositionGAT, &
                                TROOGAT, ROFOGAT, TROFGAT, ROFGAT, ROFNGAT, PCPGGAT, HTCSGAT, WSNOGAT, N)
!
!=======================================================================
            ROFGAT = ROFGAT - UMQ

        end if !(ipid /= 0 .or. izero == 0) then

!> *********************************************************************
!> End of the NML-based LSS loop.
!> *********************************************************************

! *********************************************************************
! Calculate values for output files and print them out
! *********************************************************************

    !> Send/receive process.
        itag = NSUM_TOTAL*1000
        invars = 14 + 4*IGND

    !> Update the variable count per the active control flags.
        if (SAVERESUMEFLAG == 3) invars = invars + 10 + 4

        if (inp > 1 .and. ipid /= 0) then

        !> Send data back to head-node.

            if (allocated(irqst)) deallocate(irqst)
            if (allocated(imstat)) deallocate(imstat)
            allocate(irqst(invars), imstat(mpi_status_size, invars))
            irqst = mpi_request_null

            i = 1
            call mpi_isend(PREGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(QFSGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(ROFGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(ROFOGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(ROFSGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(ROFBGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(SCANGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(RCANGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(ZPNDGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(SNOGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(FSNOGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(WSNOGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(HFSGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(QEVPGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            do j = 1, IGND
                call mpi_isend(THLQGAT(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(THICGAT(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(GFLXGAT(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(TBARGAT(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            end do

        !> Send optional variables per the active control flags.
            if (SAVERESUMEFLAG == 3) then
                call mpi_isend(ALBSGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(CMAIGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(GROGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(QACGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(RHOSGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(TACGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(TBASGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(TCANGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(TPNDGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(TSNOGAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                do j = 1, 4
                    call mpi_isend(TSFSGAT(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                end do
            end if !(SAVERESUMEFLAG == 3) then

            lstat = .false.
            do while (.not. lstat)
                call mpi_testall(invars, irqst, lstat, imstat, ierr)
            end do

!            print *, ipid, ' done sending'

        else if (inp > 1) then

        !> Receive data from worker nodes.
            if (allocated(irqst)) deallocate(irqst)
            if (allocated(imstat)) deallocate(imstat)
            allocate(irqst(invars), imstat(mpi_status_size, invars))

        !> Receive and assign variables.
            do u = 1, (inp - 1)

!                print *, 'initiating irecv for:', u, ' with ', itag

                irqst = mpi_request_null
                imstat = 0

                call GetIndices(inp, izero, u, shd%lc%NML, shd%lc%ILMOS, ii1, ii2, iilen)

                i = 1
                call mpi_irecv(PREGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(QFSGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(ROFGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(ROFOGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(ROFSGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(ROFBGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(SCANGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(RCANGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(ZPNDGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(SNOGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(FSNOGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(WSNOGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(HFSGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(QEVPGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                do j = 1, IGND
                    call mpi_irecv(THLQGAT(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(THICGAT(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(GFLXGAT(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(TBARGAT(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                end do

            !> Send optional variables per the active control flags.
                if (SAVERESUMEFLAG == 3) then
                    call mpi_irecv(ALBSGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(CMAIGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(GROGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(QACGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(RHOSGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(TACGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(TBASGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(TCANGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(TPNDGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(TSNOGAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    do j = 1, 4
                        call mpi_irecv(TSFSGAT(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    end do
                end if !(SAVERESUMEFLAG == 3) then

                lstat = .false.
                do while (.not. lstat)
                    call mpi_testall(invars, irqst, lstat, imstat, ierr)
                end do

            end do !u = 1, (inp - 1)
!            print *, 'done receiving'

        end if !(inp > 1 .and. ipid /= 0) then

        if (inp > 1 .and. NCOUNT == MPIUSEBARRIER) call MPI_Barrier(MPI_COMM_WORLD, ierr)

!> *********************************************************************
!> Start of book-keeping and grid accumulation.
!> *********************************************************************

!
!=======================================================================
!     * WRITE FIELDS FROM CURRENT TIME STEP TO OUTPUT FILES.

        !> Write to CLASSOF* output files.
        do i = 1, WF_NUM_POINTS
            if ((ipid /= 0 .or. izero == 0) .and. op%K_OUT(i) >= il1 .and. op%K_OUT(i) <= il2) then

            !> Update variables.
                k = op%K_OUT(i)
                if (2.0*FSVHGAT(k) > 0.0) then
                    ALTOT = (ALVSGAT(k) + ALIRGAT(k))/2.0
                else
                    ALTOT = 0.0
                end if
                FSSTAR = 2.0*FSVHGAT(k)*(1.0 - ALTOT)
                FLSTAR = FDLGAT(k) - SBC*GTGAT(k)**4
                QH = HFSGAT(k)
                QE = QEVPGAT(k)
                BEG = FSSTAR + FLSTAR - QH - QE
                SNOMLT = HMFNGAT(k)
                if (RHOSGAT(k) > 0.0) then
                    ZSN = SNOGAT(k)/RHOSGAT(k)
                else
                    ZSN = 0.0
                end if
                if (TCANGAT(k) > 0.01) then
                    TCN = TCANGAT(k) - TFREZ
                else
                    TCN = 0.0
                end if
                if (TSNOGAT(k) > 0.01) then
                    TSN = TSNOGAT(k) - TFREZ
                else
                    TSN = 0.0
                end if
                if (TPNDGAT(k) > 0.01) then
                    TPN = TPNDGAT(k) - TFREZ
                else
                    TPN = 0.0
                end if
                if (shd%wc%ILG == 1) then
                    GTOUT = GTGAT(k) - TFREZ
                else
                    GTOUT = 0.0
                end if
                ZPND = ZPNDPRECS(k)*FCS(k) + ZPONDPREC(k)*FC(k) + ZPONDPREG(k)*FG(k) + ZPNDPREGS(k)*FGS(k)
                FSTR = FSTRCS(k)*FCS(k) + FSTRC(k)*FC(k) + FSTRG(k)*FG(k) + FSTRGS(k)*FGS(k)

            !> Write to the CLASSOF* output files for sub-hourly output.
                write(150 + i*10 + 4, &
                      "(i2,',', i3,',', i5,',', i6,',', 9(f8.2,','), 2(f7.3,','), e11.3,',', f8.2,',', 3(f12.4,','))") &
                    HOUR_NOW, MINS_NOW, JDAY_NOW, YEAR_NOW, FSSTAR, FLSTAR, QH, &
                    QE, SNOMLT, BEG, GTOUT, SNOGAT(k), &
                    RHOSGAT(k), WSNOGAT(k), ALTOT, ROFGAT(k), &
                    TPN, ZPNDGAT(k), ZPND, FSTR
                write(150 + i*10 + 5, "(i2,',', i3,',', i5,',', i6,',', " // trim(adjustl(IGND_CHAR)) // &
                      "(f7.2,',', 2(f6.3,',')), f8.2,',', 2(f8.4,','), f8.2,',', f8.3,',')") &
                    HOUR_NOW, MINS_NOW, JDAY_NOW, YEAR_NOW, &
                    (TBARGAT(k, j) - TFREZ, THLQGAT(k, j), &
                    THICGAT(k, j), j = 1, IGND), TCN, &
                    RCANGAT(k), SCANGAT(k), TSN, ZSN
                write(150 + i*10 + 6, &
                      "(i2,',', i3,',', i5,',', 2(f10.2,','), f12.6,',', f10.2,',', f8.2,',', f10.2,',', f15.9,',')") &
                    HOUR_NOW, MINS_NOW, JDAY_NOW, 2.0*FSVHGAT(k), FDLGAT(k), &
                    PREGAT(k), TAGAT(k) - TFREZ, VMODGAT(k), PRESGAT(k), &
                    QAGAT(k)
                write(150 + i*10 + 7, "(999(e11.4,','))") &
                    TROFGAT(k), TROOGAT(k), TROSGAT(k), &
                    TROBGAT(k), ROFGAT(k), ROFOGAT(k), &
                    ROFSGAT(k), ROFBGAT(k), &
                    FCS(k), FGS(k), FC(k), FG(k)
                write(150 + i*10 + 8, "(999(f12.4,','))") &
                    FSGVGAT(k), FSGSGAT(k), FSGGGAT(k), &
                    FLGVGAT(k), FLGSGAT(k), FLGGGAT(k), &
                    HFSCGAT(k), HFSSGAT(k), HFSGGAT(k), &
                    HEVCGAT(k), HEVSGAT(k), HEVGGAT(k), &
                    HMFCGAT(k), HMFNGAT(k), &
                    (HMFGGAT(k, j), j = 1, IGND), &
                    HTCCGAT(k), HTCSGAT(k), &
                    (HTCGAT(k, j), j = 1, IGND)
                write(150 + i*10 + 9, "(999(e12.4,','))") &
                    PCFCGAT(k), PCLCGAT(k), PCPNGAT(k), &
                    PCPGGAT(k), QFCFGAT(k), QFCLGAT(k), &
                    QFNGAT(k), QFGGAT(k), (QFCGAT(k, j), j = 1, IGND), &
                    ROFCGAT(k), ROFNGAT(k), &
                    ROFOGAT(k), ROFGAT(k), WTRCGAT(k), &
                    WTRSGAT(k), WTRGGAT(k)
                write(150 + i*10 + 10, "(i2,',', i3,',', i5,',', i6,',', 999(f14.6,','))") &
                    HOUR_NOW, MINS_NOW, JDAY_NOW, YEAR_NOW, PREGAT(k)*DELT, QFSGAT(k)*DELT, &
                    ROFGAT(k)*DELT, ROFOGAT(k)*DELT, ROFSGAT(k)*DELT, ROFBGAT(k)*DELT, &
                    SCANGAT(k), RCANGAT(k), SNOGAT(k), WSNOGAT(k), &
                    ZPNDGAT(k)*RHOW, (THLQGAT(k, j)*RHOW*DLZWGAT(k, j), j = 1, IGND), &
                    (THICGAT(k, j)*RHOICE*DLZWGAT(k, j), j = 1, IGND)

            !> Calculate accumulated grid variables.
                do k = il1, il2
                    if (shd%lc%ILMOS(k) == op%N_OUT(i)) then
                        co%PREACC(i) = co%PREACC(i) + PREGAT(k)*FAREGAT(k)*DELT
                        co%GTACC(i) = co%GTACC(i) + GTGAT(k)*FAREGAT(k)
                        co%QEVPACC(i) = co%QEVPACC(i) + QEVPGAT(k)*FAREGAT(k)
                        co%EVAPACC(i) = co%EVAPACC(i) + QFSGAT(k)*FAREGAT(k)*DELT
                        co%HFSACC(i) = co%HFSACC(i) + HFSGAT(k)*FAREGAT(k)
                        co%HMFNACC(i) = co%HMFNACC(i) + HMFNGAT(k)*FAREGAT(k)
                        co%ROFACC(i) = co%ROFACC(i) + ROFGAT(k)*FAREGAT(k)*DELT
                        co%ROFOACC(i) = co%ROFOACC(i) + ROFOGAT(k)*FAREGAT(k)*DELT
                        co%ROFSACC(i) = co%ROFSACC(i) + ROFSGAT(k)*FAREGAT(k)*DELT
                        co%ROFBACC(i) = co%ROFBACC(i) + ROFBGAT(k)*FAREGAT(k)*DELT
                        co%WTBLACC(i) = co%WTBLACC(i) + WTABGAT(k)*FAREGAT(k)
                        do j = 1, IGND
                            co%TBARACC(i, j) = co%TBARACC(i, j) + TBARGAT(k, j)*shd%lc%ACLASS(shd%lc%ILMOS(k), shd%lc%JLMOS(k))
                            co%THLQACC(i, j) = co%THLQACC(i, j) + THLQGAT(k, j)*FAREGAT(k)
                            co%THICACC(i, j) = co%THICACC(i, j) + THICGAT(k, j)*FAREGAT(k)
                            co%THALACC(i, j) = co%THALACC(i, j) + (THLQGAT(k, j) + THICGAT(k, j))*FAREGAT(k)
                            co%GFLXACC(i, j) = co%GFLXACC(i, j) + GFLXGAT(k, j)*FAREGAT(k)
                        end do
                        co%ALVSACC(i) = co%ALVSACC(i) + ALVSGAT(k)*FSVHGAT(k)*FAREGAT(k)
                        co%ALIRACC(i) = co%ALIRACC(i) + ALIRGAT(k)*FSIHGAT(k)*FAREGAT(k)
                        if (SNOGAT(k) > 0.0) then
                            co%RHOSACC(i) = co%RHOSACC(i) + RHOSGAT(k)*FAREGAT(k)
                            co%TSNOACC(i) = co%TSNOACC(i) + TSNOGAT(k)*FAREGAT(k)
                            co%WSNOACC(i) = co%WSNOACC(i) + WSNOGAT(k)*FAREGAT(k)
                            co%SNOARE(i) = co%SNOARE(i) + FAREGAT(k)
                        end if
                        if (TCANGAT(k) > 0.5) then
                            co%TCANACC(i) = co%TCANACC(i) + TCANGAT(k)*FAREGAT(k)
                            co%CANARE(i) = co%CANARE(i) + FAREGAT(k)
                        end if
                        co%SNOACC(i) = co%SNOACC(i) + SNOGAT(k)*FAREGAT(k)
                        co%RCANACC(i) = co%RCANACC(i) + RCANGAT(k)*FAREGAT(k)
                        co%SCANACC(i) = co%SCANACC(i) + SCANGAT(k)*FAREGAT(k)
                        co%GROACC(i) = co%GROACC(i) + GROGAT(k)*FAREGAT(k)
                        co%FSINACC(i) = co%FSINACC(i) + 2.0*FSVHGAT(k)*FAREGAT(k)
                        co%FLINACC(i) = co%FLINACC(i) + FDLGAT(k)*FAREGAT(k)
                        co%FLUTACC(i) = co%FLUTACC(i) + SBC*GTGAT(k)**4*FAREGAT(k)
                        co%TAACC(i) = co%TAACC(i) + TAGAT(k)*FAREGAT(k)
                        co%UVACC(i) = co%UVACC(i) + VMODGAT(k)*FAREGAT(k)
                        co%PRESACC(i) = co%PRESACC(i) + PRESGAT(k)*FAREGAT(k)
                        co%QAACC(i) = co%QAACC(i) + QAGAT(k)*FAREGAT(k)
                    end if
                end do

            !> Write to the CLASSOF* output files for daily output.
                if (NCOUNT == 48) then

                !> Calculate grid averages.
                    co%GTACC(i) = co%GTACC(i)/real(NSUM)
                    co%QEVPACC(i) = co%QEVPACC(i)/real(NSUM)
                    co%HFSACC(i) = co%HFSACC(i)/real(NSUM)
                    co%HMFNACC(i) = co%HMFNACC(i)/real(NSUM)
                    co%WTBLACC(i) = co%WTBLACC(i)/real(NSUM)
                    co%TBARACC(i, :) = co%TBARACC(i, :)/real(NSUM)
                    co%THLQACC(i, :) = co%THLQACC(i, :)/real(NSUM)
                    co%THICACC(i, :) = co%THICACC(i, :)/real(NSUM)
                    co%THALACC(i, :) = co%THALACC(i, :)/real(NSUM)
                    if (co%FSINACC(i) > 0.0) then
                        co%ALVSACC(i) = co%ALVSACC(i)/(co%FSINACC(i)*0.5)
                        co%ALIRACC(i) = co%ALIRACC(i)/(co%FSINACC(i)*0.5)
                    else
                        co%ALVSACC(i) = 0.0
                        co%ALIRACC(i) = 0.0
                    end if
                    if (co%SNOARE(i) > 0.0) then
                        co%RHOSACC(i) = co%RHOSACC(i)/co%SNOARE(i)
                        co%TSNOACC(i) = co%TSNOACC(i)/co%SNOARE(i)
                        co%WSNOACC(i) = co%WSNOACC(i)/co%SNOARE(i)
                    end if
                    if (co%CANARE(i) > 0.0) then
                        co%TCANACC(i) = co%TCANACC(i)/co%CANARE(i)
                    end if
                    co%SNOACC(i) = co%SNOACC(i)/real(NSUM)
                    co%RCANACC(i) = co%RCANACC(i)/real(NSUM)
                    co%SCANACC(i) = co%SCANACC(i)/real(NSUM)
                    co%GROACC(i) = co%GROACC(i)/real(NSUM)
                    co%FSINACC(i) = co%FSINACC(i)/real(NSUM)
                    co%FLINACC(i) = co%FLINACC(i)/real(NSUM)
                    co%FLUTACC(i) = co%FLUTACC(i)/real(NSUM)
                    co%TAACC(i) = co%TAACC(i)/real(NSUM)
                    co%UVACC(i) = co%UVACC(i)/real(NSUM)
                    co%PRESACC(i) = co%PRESACC(i)/real(NSUM)
                    co%QAACC(i) = co%QAACC(i)/real(NSUM)
                    ALTOT = (co%ALVSACC(i) + co%ALIRACC(i))/2.0
                    FSSTAR = co%FSINACC(i)*(1.0 - ALTOT)
                    FLSTAR = co%FLINACC(i) - co%FLUTACC(i)
                    QH = co%HFSACC(i)
                    QE = co%QEVPACC(i)
                    BEG = FSSTAR + FLSTAR - QH - QE
                    SNOMLT = co%HMFNACC(i)
                    if (co%RHOSACC(i) > 0.0) then
                        ZSN = co%SNOACC(i)/co%RHOSACC(i)
                    else
                        ZSN = 0.0
                    end if
                    if (co%TCANACC(i) > 0.01) then
                        TCN = co%TCANACC(i) - TFREZ
                    else
                        TCN = 0.0
                    end if
                    if (co%TSNOACC(i) > 0.01) then
                        TSN = co%TSNOACC(i) - TFREZ
                    else
                        TSN = 0.0
                    end if
                    if (shd%wc%ILG == 1) then
                        GTOUT = co%GTACC(i) - TFREZ
                    else
                        GTOUT = 0.0
                    end if

                !> Write to the CLASSOF* output files for daily accumulated output.
                    write(150 + i*10 + 1, "(i4,',', i5,',', 9(f8.2,','), 2(f8.3,','), 999(f12.4,','))") &
                        JDAY_NOW, YEAR_NOW, FSSTAR, FLSTAR, QH, QE, SNOMLT, &
                        BEG, GTOUT, co%SNOACC(i), co%RHOSACC(i), &
                        co%WSNOACC(i), ALTOT, co%ROFACC(i), co%ROFOACC(i), &
                        co%ROFSACC(i), co%ROFBACC(i)
                    write(150 + i*10 + 2, "(i4,',', i5,',', " // adjustl(IGND_CHAR) // "((f8.2,','), " // &
                          "2(f6.3,',')), f8.2,',', 2(f7.4,','), 2(f8.2,','))") &
                        JDAY_NOW, YEAR_NOW, (co%TBARACC(i, j) - TFREZ, &
                        co%THLQACC(i, j), co%THICACC(i, j), j = 1, IGND), &
                        TCN, co%RCANACC(i), co%SCANACC(i), TSN, ZSN
                    write(150 + i*10 + 3, "(i4,',', i5,',', 3(f9.2,','), f8.2,',', " // &
                          "f10.2,',', e12.3,',', 2(f12.3,','))") &
                        JDAY_NOW, YEAR_NOW, co%FSINACC(i), co%FLINACC(i), &
                        co%TAACC(i) - TFREZ, co%UVACC(i), co%PRESACC(i), &
                        co%QAACC(i), co%PREACC(i), co%EVAPACC(i)

                !> Reset the CLASS output variables.
                    co%PREACC = 0.0
                    co%GTACC = 0.0
                    co%QEVPACC = 0.0
                    co%EVAPACC = 0.0
                    co%HFSACC = 0.0
                    co%HMFNACC = 0.0
                    co%ROFACC = 0.0
                    co%ROFOACC = 0.0
                    co%ROFSACC = 0.0
                    co%ROFBACC = 0.0
                    co%WTBLACC = 0.0
                    co%TBARACC = 0.0
                    co%THLQACC = 0.0
                    co%THICACC = 0.0
                    co%THALACC = 0.0
                    co%GFLXACC = 0.0
                    co%ALVSACC = 0.0
                    co%ALIRACC = 0.0
                    co%RHOSACC = 0.0
                    co%TSNOACC = 0.0
                    co%WSNOACC = 0.0
                    co%SNOARE = 0.0
                    co%TCANACC = 0.0
                    co%CANARE = 0.0
                    co%SNOACC = 0.0
                    co%RCANACC = 0.0
                    co%SCANACC = 0.0
                    co%GROACC = 0.0
                    co%FSINACC = 0.0
                    co%FLINACC = 0.0
                    co%FLUTACC = 0.0
                    co%TAACC = 0.0
                    co%UVACC = 0.0
                    co%PRESACC = 0.0
                    co%QAACC = 0.0
                end if !(NCOUNT == 48) then
            end if !(op%K_OUT(k) >= il1 .and. op%K_OUT(k) <= il2) then
        end do !i = 1, WF_NUM_POINTS

        if (ipid == 0) then

!> Write ENSIM output
!> -----------------------------------------------------c
!>
            if (NR2CFILES > 0 .and. mod(NCOUNT*30, DELTR2C) == 0) then
                call FIND_MONTH (JDAY_NOW, YEAR_NOW, ensim_month)
                call FIND_DAY (JDAY_NOW, YEAR_NOW, ensim_day)
                call WRITE_R2C_DATA(shd%lc%NML, NLTEST, NMTEST, NCOUNT, MINS_NOW, shd%lc%ACLASS, &
                                    NA, shd%xxx, shd%yyy, shd%xCount, shd%yCount, shd%lc%ILMOS, shd%lc%JLMOS, NML, &
                                    NR2C, NR2CFILES, R2CFILEUNITSTART, GRD, GAT, &
                                    GRDGAT, NR2CSTATES, R2C_ATTRIBUTES, FRAME_NO_NEW, YEAR_NOW, &
                                    ensim_MONTH, ensim_DAY, HOUR_NOW, MINS_NOW, ICAN, &
                                    ICAN + 1, IGND, &
                                    TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                                    TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                                    TCANGAT, RCANGAT, SCANGAT, GROGAT, CMAIGAT, &
                                    FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                                    PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                                    VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                                    HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                                    THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                                    GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, &
                                    THFCGAT, PSIWGAT, DLZWGAT, ZBTWGAT, &
                                    ZSNLGAT, ZPLGGAT, ZPLSGAT, TACGAT, QACGAT, &
                                    DRNGAT, XSLPGAT, XDGAT, WFSFGAT, KSGAT, &
                                    ALGWGAT, ALGDGAT, ASVDGAT, ASIDGAT, AGVDGAT, &
                                    AGIDGAT, ISNDGAT, RADJGAT, ZBLDGAT, Z0ORGAT, &
                                    ZRFMGAT, ZRFHGAT, ZDMGAT, ZDHGAT, FSVHGAT, &
                                    FSIHGAT, CSZGAT, FDLGAT, ULGAT, VLGAT, &
                                    TAGAT, QAGAT, PRESGAT, PREGAT, PADRGAT, &
                                    VPDGAT, TADPGAT, RHOAGAT, RPCPGAT, TRPCGAT, &
                                    SPCPGAT, TSPCGAT, RHSIGAT, FCLOGAT, DLONGAT, &
                                    GGEOGAT, &
                                    CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT, &
                                    QFSGAT, QFXGAT, PETGAT, GAGAT, EFGAT, &
                                    GTGAT, QGGAT, ALVSGAT, ALIRGAT, &
                                    SFCTGAT, SFCUGAT, SFCVGAT, SFCQGAT, FSNOGAT, &
                                    FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, &
                                    FLGGGAT, HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, &
                                    HEVSGAT, HEVGGAT, HMFCGAT, HMFNGAT, HTCCGAT, &
                                    HTCSGAT, PCFCGAT, PCLCGAT, PCPNGAT, PCPGGAT, &
                                    QFGGAT, QFNGAT, QFCLGAT, QFCFGAT, ROFGAT, &
                                    ROFOGAT, ROFSGAT, ROFBGAT, TROFGAT, TROOGAT, &
                                    TROSGAT, TROBGAT, ROFCGAT, ROFNGAT, ROVGGAT, &
                                    WTRCGAT, WTRSGAT, WTRGGAT, DRGAT, GFLXGAT, &
                                    HMFGGAT, HTCGAT, QFCGAT, MANNGAT, DDGAT, &
                                    IGDRGAT, VMODGAT, QLWOGAT)
                FRAME_NO_NEW = FRAME_NO_NEW + 1 !UPDATE COUNTERS
            end if

!> =======================================================================
!>     * CALCULATE GRID CELL AVERAGE DIAGNOSTIC FIELDS.

!> many of these varibles are currently not being used for anything,
!> but we want to keep them because they may be useful in the future.
!> these variables hold the grid cell averages. 
!> In the future, someone will need to use them.

            CDHGRD = 0.0
            CDMGRD = 0.0
            HFSGRD = 0.0
            TFXGRD = 0.0
            QEVPGRD = 0.0
            QFSGRD = 0.0
            QFXGRD = 0.0
            PETGRD = 0.0
            GAGRD = 0.0
            EFGRD = 0.0
            GTGRD = 0.0
            QGGRD = 0.0
            TSFGRD = 0.0
            ALVSGRD = 0.0
            ALIRGRD = 0.0
            SFCTGRD = 0.0
            SFCUGRD = 0.0
            SFCVGRD = 0.0
            SFCQGRD = 0.0
            FSNOGRD = 0.0
            FSGVGRD = 0.0
            FSGSGRD = 0.0
            FSGGGRD = 0.0
            SNOGRD = 0.0
            FLGVGRD = 0.0
            FLGSGRD = 0.0
            FLGGGRD = 0.0
            HFSCGRD = 0.0
            HFSSGRD = 0.0
            HFSGGRD = 0.0
            HEVCGRD = 0.0
            HEVSGRD = 0.0
            HEVGGRD = 0.0
            HMFCGRD = 0.0
            HMFNGRD = 0.0
            HTCCGRD = 0.0
            HTCSGRD = 0.0
            PCFCGRD = 0.0
            PCLCGRD = 0.0
            PCPNGRD = 0.0
            PCPGGRD = 0.0
            QFGGRD = 0.0
            QFNGRD = 0.0
            QFCLGRD = 0.0
            QFCFGRD = 0.0
            ROFGRD = 0.0
            ROFOGRD = 0.0
            ROFSGRD = 0.0
            ROFBGRD = 0.0
            ROFCGRD = 0.0
            ROFNGRD = 0.0
            ROVGGRD = 0.0
            WTRCGRD = 0.0
            WTRSGRD = 0.0
            WTRGGRD = 0.0
            DRGRD = 0.0
            WTABGRD = 0.0
            ILMOGRD = 0.0
            UEGRD = 0.0
            HBLGRD = 0.0
            HMFGGRD = 0.0
            HTCGRD = 0.0
            QFCGRD = 0.0
            GFLXGRD = 0.0
!>
!>*******************************************************************
!>

    !> Grid data for output.
            md%fsdown = cm%clin(cfk%FB)%climvGrd
            md%fsvh = fsvhgrd
            md%fsih = fsihgrd
            md%fdl = cm%clin(cfk%FI)%climvGrd
            md%ul = cm%clin(cfk%UV)%climvGrd
            md%ta = cm%clin(cfk%TT)%climvGrd
            md%qa = cm%clin(cfk%HU)%climvGrd
            md%pres = cm%clin(cfk%P0)%climvGrd
            md%pre = cm%clin(cfk%PR)%climvGrd

!> GRU-distributed data for output.
            wb_h%pre = 0.0
            wb_h%evap = 0.0
            wb_h%rof = 0.0
            wb_h%rofo = 0.0
            wb_h%rofs = 0.0
            wb_h%rofb = 0.0
            wb_h%rcan = 0.0
            wb_h%sncan = 0.0
            wb_h%pndw = 0.0
            wb_h%sno = 0.0
            wb_h%wsno = 0.0
            wb_h%lqws = 0.0
            wb_h%frws = 0.0

            !$omp parallel do
            do k = il1, il2
                ik = shd%lc%ILMOS(k)
                CDHGRD(ik) = CDHGRD(ik) + CDHGAT(k)*FAREGAT(k)
                CDMGRD(ik) = CDMGRD(ik) + CDMGAT(k)*FAREGAT(k)
                HFSGRD(ik) = HFSGRD(ik) + HFSGAT(k)*FAREGAT(k)
                TFXGRD(ik) = TFXGRD(ik) + TFXGAT(k)*FAREGAT(k)
                QEVPGRD(ik) = QEVPGRD(ik) + QEVPGAT(k)*FAREGAT(k)
                QFSGRD(ik) = QFSGRD(ik) + QFSGAT(k)*FAREGAT(k)
                QFXGRD(ik) = QFXGRD(ik) + QFXGAT(k)*FAREGAT(k)
                PETGRD(ik) = PETGRD(ik) + PETGAT(k)*FAREGAT(k)
                GAGRD(ik) = GAGRD(ik) + GAGAT(k)*FAREGAT(k)
                EFGRD(ik) = EFGRD(ik) + EFGAT(k)*FAREGAT(k)
                GTGRD(ik) = GTGRD(ik) + GTGAT(k)*FAREGAT(k)
                QGGRD(ik) = QGGRD(ik) + QGGAT(k)*FAREGAT(k)
!                TSFGRD(ik) = TSFGRD(ik) + TSFGAT(k)*FAREGAT(k)
                ALVSGRD(ik) = ALVSGRD(ik) + ALVSGAT(k)*FAREGAT(k)
                ALIRGRD(ik) = ALIRGRD(ik) + ALIRGAT(k)*FAREGAT(k)
                SFCTGRD(ik) = SFCTGRD(ik) + SFCTGAT(k)*FAREGAT(k)
                SFCUGRD(ik) = SFCUGRD(ik) + SFCUGAT(k)*FAREGAT(k)
                SFCVGRD(ik) = SFCVGRD(ik) + SFCVGAT(k)*FAREGAT(k)
                SFCQGRD(ik) = SFCQGRD(ik) + SFCQGAT(k)*FAREGAT(k)
                FSNOGRD(ik) = FSNOGRD(ik) + FSNOGAT(k)*FAREGAT(k)
                FSGVGRD(ik) = FSGVGRD(ik) + FSGVGAT(k)*FAREGAT(k)
                FSGSGRD(ik) = FSGSGRD(ik) + FSGSGAT(k)*FAREGAT(k)
                FSGGGRD(ik) = FSGGGRD(ik) + FSGGGAT(k)*FAREGAT(k)
                SNOGRD(ik) = SNOGRD(ik) + SNOGAT(k)*FAREGAT(k)
                FLGVGRD(ik) = FLGVGRD(ik) + FLGVGAT(k)*FAREGAT(k)
                FLGSGRD(ik) = FLGSGRD(ik) + FLGSGAT(k)*FAREGAT(k)
                FLGGGRD(ik) = FLGGGRD(ik) + FLGGGAT(k)*FAREGAT(k)
                HFSCGRD(ik) = HFSCGRD(ik) + HFSCGAT(k)*FAREGAT(k)
                HFSSGRD(ik) = HFSSGRD(ik) + HFSSGAT(k)*FAREGAT(k)
                HFSGGRD(ik) = HFSGGRD(ik) + HFSGGAT(k)*FAREGAT(k)
                HEVCGRD(ik) = HEVCGRD(ik) + HEVCGAT(k)*FAREGAT(k)
                HEVSGRD(ik) = HEVSGRD(ik) + HEVSGAT(k)*FAREGAT(k)
                HEVGGRD(ik) = HEVGGRD(ik) + HEVGGAT(k)*FAREGAT(k)
                HMFCGRD(ik) = HMFCGRD(ik) + HMFCGAT(k)*FAREGAT(k)
                HMFNGRD(ik) = HMFNGRD(ik) + HMFNGAT(k)*FAREGAT(k)
                HTCCGRD(ik) = HTCCGRD(ik) + HTCCGAT(k)*FAREGAT(k)
                HTCSGRD(ik) = HTCSGRD(ik) + HTCSGAT(k)*FAREGAT(k)
                PCFCGRD(ik) = PCFCGRD(ik) + PCFCGAT(k)*FAREGAT(k)
                PCLCGRD(ik) = PCLCGRD(ik) + PCLCGAT(k)*FAREGAT(k)
                PCPNGRD(ik) = PCPNGRD(ik) + PCPNGAT(k)*FAREGAT(k)
                PCPGGRD(ik) = PCPGGRD(ik) + PCPGGAT(k)*FAREGAT(k)
                QFGGRD(ik) = QFGGRD(ik) + QFGGAT(k)*FAREGAT(k)
                QFNGRD(ik) = QFNGRD(ik) + QFNGAT(k)*FAREGAT(k)
                QFCLGRD(ik) = QFCLGRD(ik) + QFCLGAT(k)*FAREGAT(k)
                QFCFGRD(ik) = QFCFGRD(ik) + QFCFGAT(k)*FAREGAT(k)
                ROFGRD(ik) = ROFGRD(ik) + ROFGAT(k)*FAREGAT(k)
                ROFOGRD(ik) = ROFOGRD(ik) + ROFOGAT(k)*FAREGAT(k)
                ROFSGRD(ik) = ROFSGRD(ik) + ROFSGAT(k)*FAREGAT(k)
                ROFBGRD(ik) = ROFBGRD(ik) + ROFBGAT(k)*FAREGAT(k)
                ROFCGRD(ik) = ROFCGRD(ik) + ROFCGAT(k)*FAREGAT(k)
                ROFNGRD(ik) = ROFNGRD(ik) + ROFNGAT(k)*FAREGAT(k)
                ROVGGRD(ik) = ROVGGRD(ik) + ROVGGAT(k)*FAREGAT(k)
                WTRCGRD(ik) = WTRCGRD(ik) + WTRCGAT(k)*FAREGAT(k)
                WTRSGRD(ik) = WTRSGRD(ik) + WTRSGAT(k)*FAREGAT(k)
                WTRGGRD(ik) = WTRGGRD(ik) + WTRGGAT(k)*FAREGAT(k)
                DRGRD(ik) = DRGRD(ik) + DRGAT(k)*FAREGAT(k)
                WTABGRD(ik) = WTABGRD(ik) + WTABGAT(k)*FAREGAT(k)
                ILMOGRD(ik) = ILMOGRD(ik) + ILMOGAT(k)*FAREGAT(k)
                UEGRD(ik) = UEGRD(ik) + UEGAT(k)*FAREGAT(k)
                HBLGRD(ik) = HBLGRD(ik) + HBLGAT(k)*FAREGAT(k)
                wb_h%pre(ik) = wb_h%pre(ik) + FAREGAT(k)*PREGAT(k)*DELT
                wb_h%evap(ik) = wb_h%evap(ik) + FAREGAT(k)*QFSGAT(k)*DELT
                wb_h%rof(ik) = wb_h%rof(ik) + FAREGAT(k)*ROFGAT(k)*DELT
                wb_h%rofo(ik) = wb_h%rofo(ik) + FAREGAT(k)*ROFOGAT(k)*DELT
                wb_h%rofs(ik) = wb_h%rofs(ik) + FAREGAT(k)*ROFSGAT(k)*DELT
                wb_h%rofb(ik) = wb_h%rofb(ik) + FAREGAT(k)*ROFBGAT(k)*DELT
                wb_h%rcan(ik) = wb_h%rcan(ik) + FAREGAT(k)*RCANGAT(k)
                wb_h%sncan(ik) = wb_h%sncan(ik) + FAREGAT(k)*SCANGAT(k)
                wb_h%pndw(ik) = wb_h%pndw(ik) + FAREGAT(k)*ZPNDGAT(k)*RHOW
                wb_h%sno(ik) = wb_h%sno(ik) + FAREGAT(k)*SNOGAT(k)
                wb_h%wsno(ik) = wb_h%wsno(ik) + FAREGAT(k)*WSNOGAT(k)
                do j = 1, IGND
                    HMFGGRD(ik, j) = HMFGGRD(ik, j) + HMFGGAT(k, j)*FAREGAT(k)
                    HTCGRD(ik, j) = HTCGRD(ik, j) + HTCGAT(k, j)*FAREGAT(k)
                    QFCGRD(ik, j) = QFCGRD(ik, j) + QFCGAT(k, j)*FAREGAT(k)
                    GFLXGRD(ik, j) = GFLXGRD(ik, j) + GFLXGAT(k, j)*FAREGAT(k)
                    wb_h%lqws(ik, j) = wb_h%lqws(ik, j) + FAREGAT(k)*THLQGAT(k, j)*DLZWGAT(k, j)*RHOW
                    wb_h%frws(ik, j) = wb_h%frws(ik, j) + FAREGAT(k)*THICGAT(k, j)*DLZWGAT(k, j)*RHOICE
                end do
                wb_h%stg(ik) = wb%rcan(ik) + wb%sncan(ik) + wb%pndw(ik) + &
                    wb%sno(ik) + wb%wsno(ik) + &
                    sum(wb%lqws(ik, :)) + sum(wb%frws(ik, :))
            end do !k = il1, il2

!> calculate and write the basin avg SCA similar to watclass3.0f5
!> Same code than in wf_ensim.f subrutine of watclass3.0f8
!> Especially for version MESH_Prototype 3.3.1.7b (not to be incorporated in future versions)
!> calculate and write the basin avg SWE using the similar fudge factor!!!

!            if (BASIN_FRACTION(1) == -1) then
!                do i = 1, NA ! NA = number of grid squares
!>         BASIN_FRACTION is the basin snow cover
!>         (portions of the grids outside the basin are not included)
!>         for a given day - JDAY_NOW in the if statement
!                    BASIN_FRACTION(i) = shd%FRAC(i)
    !TODO: FRAC is not actually the fraction of the grid square
    !within the basin, we should be using some other value, but I'm
    !not sure what.
    !todo: calculate frac and write document to send to someone else.
!                end do
!            end if

            if (HOUR_NOW == 12 .and. MINS_NOW == 0) then
                basin_SCA = 0.0
                basin_SWE = 0.0
!                do i = 1, NA
!                    if (BASIN_FRACTION(i) /= 0.0) then
!                        basin_SCA = basin_SCA + FSNOGRD(i)/BASIN_FRACTION(i)
!                        basin_SWE = basin_SWE + SNOGRD(i)/BASIN_FRACTION(i)
!                    end if
!                end do
!                basin_SCA = basin_SCA/NA
!                basin_SWE = basin_SWE/NA

! BRUCE DAVISON - AUG 17, 2009 (see notes in my notebook for this day)
! Fixed calculation of basin averages. Needs documenting and testing.
                do k = il1, il2
                    basin_SCA = basin_SCA + FSNOGAT(k)*FAREGAT(k)
                    basin_SWE = basin_SWE + SNOGAT(k)*FAREGAT(k)
                end do
                basin_SCA = basin_SCA/TOTAL_AREA
                basin_SWE = basin_SWE/TOTAL_AREA
                if (BASINSWEOUTFLAG > 0) then
                    write(85, "(i5,',', f10.3)") JDAY_NOW, basin_SCA
                    write(86, "(i5,',', f10.3)") JDAY_NOW, basin_SWE
                end if
            end if

!> =======================================================================
!> ACCUMULATE OUTPUT DATA FOR DIURNALLY AVERAGED FIELDS.

            !$omp parallel do
            do k = il1, il2
                ik = shd%lc%ILMOS(k)
                if (shd%FRAC(ik) /= 0.0) then
                    PREACC(ik) = PREACC(ik) + PREGAT(k)*FAREGAT(k)*DELT
                    GTACC(ik) = GTACC(ik) + GTGAT(k)*FAREGAT(k)
                    QEVPACC(ik) = QEVPACC(ik) + QEVPGAT(k)*FAREGAT(k)
                    EVAPACC(ik) = EVAPACC(ik) + QFSGAT(k)*FAREGAT(k)*DELT
                    HFSACC(ik)  = HFSACC(ik) + HFSGAT(k)*FAREGAT(k)
                    HMFNACC(ik) = HMFNACC(ik) + HMFNGAT(k)*FAREGAT(k)
                    ROFACC(ik) = ROFACC(ik) + ROFGAT(k)*FAREGAT(k)*DELT
                    ROFOACC(ik) = ROFOACC(ik) + ROFOGAT(k)*FAREGAT(k)*DELT
                    ROFSACC(ik) = ROFSACC(ik) + ROFSGAT(k)*FAREGAT(k)*DELT
                    ROFBACC(ik) = ROFBACC(ik) + ROFBGAT(k)*FAREGAT(k)*DELT
                    WTBLACC(ik) = WTBLACC(ik) + WTABGAT(k)*FAREGAT(k)
                    do j = 1, IGND
                        TBARACC(ik, j) = TBARACC(ik, j) + TBARGAT(k, j)*shd%lc%ACLASS(ik, shd%lc%JLMOS(k))
                        THLQACC(ik, j) = THLQACC(ik, j) + THLQGAT(k, j)*FAREGAT(k)
                        THICACC(ik, j) = THICACC(ik, j) + THICGAT(k, j)*FAREGAT(k)
                        THALACC(ik, j) = THALACC(ik, j) + (THLQGAT(k, j) + THICGAT(k, j))*FAREGAT(k)
            !Added by GSA compute daily heat conduction flux between layers
                        GFLXACC(ik, j) = GFLXACC(ik, j) + GFLXGAT(k, j)*FAREGAT(k)
!                        (k) = THALACC_STG(k) + THALACC(k, j)
                        THLQ_FLD(ik, j) =  THLQ_FLD(ik, j) + THLQGAT(k, j)*RHOW*FAREGAT(k)*DLZWGAT(k, j)
                        THIC_FLD(ik, j) =  THIC_FLD(ik, j) + THICGAT(k, j)*RHOICE*FAREGAT(k)*DLZWGAT(k, j)
                    end do
                    ALVSACC(ik) = ALVSACC(ik) + ALVSGAT(k)*FAREGAT(k)*FSVHGRD(ik)
                    ALIRACC(ik) = ALIRACC(ik) + ALIRGAT(k)*FAREGAT(k)*FSIHGRD(ik)
                    if (SNOGAT(k) > 0.0) then
                        RHOSACC(ik) = RHOSACC(ik) + RHOSGAT(k)*FAREGAT(k)
                        TSNOACC(ik) = TSNOACC(ik) + TSNOGAT(k)*FAREGAT(k)
                        WSNOACC(ik) = WSNOACC(ik) + WSNOGAT(k)*FAREGAT(k)
                        SNOARE(ik) = SNOARE(ik) + FAREGAT(k)
                    end if
                    if (TCANGAT(k) > 0.5) then
                        TCANACC(ik) = TCANACC(ik) + TCANGAT(k)*FAREGAT(k)
                        CANARE(ik) = CANARE(ik) + FAREGAT(k)
                    end if
                    SNOACC(ik) = SNOACC(ik) + SNOGAT(k)*FAREGAT(k)
                    RCANACC(ik) = RCANACC(ik) + RCANGAT(k)*FAREGAT(k)
                    SCANACC(ik) = SCANACC(ik) + SCANGAT(k)*FAREGAT(k)
                    GROACC(ik) = GROACC(ik) + GROGAT(k)*FAREGAT(k)
                    FSINACC(ik) = FSINACC(ik) + cm%clin(cfk%FB)%climvGrd(ik)*FAREGAT(k)
                    FLINACC(ik) = FLINACC(ik) + cm%clin(cfk%FI)%climvGrd(ik)*FAREGAT(k)
                    FLUTACC(ik) = FLUTACC(ik) + SBC*GTGAT(k)**4*FAREGAT(k)
                    TAACC(ik) = TAACC(ik) + cm%clin(cfk%TT)%climvGrd(ik)*FAREGAT(k)
                    UVACC(ik) = UVACC(ik) + UVGRD(ik)*FAREGAT(k)
                    PRESACC(ik) = PRESACC(ik) + cm%clin(cfk%P0)%climvGrd(ik)*FAREGAT(k)
                    QAACC(ik) = QAACC(ik) + cm%clin(cfk%HU)%climvGrd(ik)*FAREGAT(k)
                end if
            end do !k = il1, il2

    !> Update output data.
            call updatefieldsout_temp(shd, ts, ic, ifo, &
                                      md, wb_h, &
                                      vr)

!> CALCULATE AND PRINT DAILY AVERAGES.

!todo: use delta t here
            if (NCOUNT == 48) then !48 is the last half-hour period of the day
                      ! when they're numbered 1-48

    !no omp b/c of file IO
                do i = 1, NA
                    if (shd%FRAC(i) /= 0.0) then
                        PREACC(i) = PREACC(i)
                        GTACC(i) = GTACC(i)/real(NSUM)
                        QEVPACC(i) = QEVPACC(i)/real(NSUM)
                        EVAPACC(i) = EVAPACC(i)
                        HFSACC(i) = HFSACC(i)/real(NSUM)
                        HMFNACC(i) = HMFNACC(i)/real(NSUM)
                        ROFACC(i) = ROFACC(i)
                        ROFOACC(i) = ROFOACC(i)
                        ROFSACC(i) = ROFSACC(i)
                        ROFBACC(i) = ROFBACC(i)
                        WTBLACC(i) = WTBLACC(i)/real(NSUM)
                        do j = 1, IGND
                            TBARACC(i, j) = TBARACC(i, j)/real(NSUM)
                            THLQACC(i, j) = THLQACC(i, j)/real(NSUM)
                            THICACC(i, j) = THICACC(i, j)/real(NSUM)
                            THALACC(i, j) = THALACC(i, j)/real(NSUM)
                        end do
                        if (FSINACC(i) > 0.0) then
                            ALVSACC(i) = ALVSACC(i)/(FSINACC(i)*0.5)
                            ALIRACC(i) = ALIRACC(i)/(FSINACC(i)*0.5)
                        else
                            ALVSACC(i) = 0.0
                            ALIRACC(i) = 0.0
                        end if
                        if (SNOARE(i) > 0.0) then
                            RHOSACC(i) = RHOSACC(i)/SNOARE(i)
                            TSNOACC(i) = TSNOACC(i)/SNOARE(i)
                            WSNOACC(i) = WSNOACC(i)/SNOARE(i)
                        end if
                        if (CANARE(i) > 0.0) then
                            TCANACC(i) = TCANACC(i)/CANARE(i)
                        end if
                        SNOACC(i) = SNOACC(i)/real(NSUM)
                        RCANACC(i) = RCANACC(i)/real(NSUM)
                        SCANACC(i) = SCANACC(i)/real(NSUM)
                        GROACC(i) = GROACC(i)/real(NSUM)
                        FSINACC(i) = FSINACC(i)/real(NSUM)
                        FLINACC(i) = FLINACC(i)/real(NSUM)
                        FLUTACC(i) = FLUTACC(i)/real(NSUM)
                        TAACC(i) = TAACC(i)/real(NSUM)
                        UVACC(i) = UVACC(i)/real(NSUM)
                        PRESACC(i) = PRESACC(i)/real(NSUM)
                        QAACC(i) = QAACC(i)/real(NSUM)
!* ALTOT: the average of the visible spectrum and infrared spectrum
                        ALTOT = (ALVSACC(i) + ALIRACC(i))/2.0
                        FSSTAR = FSINACC(i)*(1.0 - ALTOT)
                        FLSTAR = FLINACC(i) - FLUTACC(i)
                        QH = HFSACC(i)
                        QE = QEVPACC(i)
                        BEG = FSSTAR + FLSTAR - QH - QE
                        SNOMLT = HMFNACC(i)
                        if (RHOSACC(i) > 0.0) then
                            ZSN = SNOACC(i)/RHOSACC(i)
                        else
                            ZSN = 0.0
                        end if
                        if (TCANACC(i) > 0.01) then
                            TCN = TCANACC(i) - TFREZ
                        else
                            TCN = 0.0
                        end if
                        if (TSNOACC(i) > 0.01) then
                            TSN = TSNOACC(i) - TFREZ
                        else
                            TSN = 0.0
                        end if
                        if (shd%wc%ILG == 1) then
                            GTOUT = GTACC(i) - TFREZ
                        else
                            GTOUT = 0.0
                        end if

!> update components for final water balance tally
                        TOTAL_PRE = TOTAL_PRE + PREACC(i)
                        TOTAL_EVAP = TOTAL_EVAP + EVAPACC(i)
                        TOTAL_ROF = TOTAL_ROF + ROFACC(i)
                        TOTAL_ROFO = TOTAL_ROFO + ROFOACC(i)
                        TOTAL_ROFS = TOTAL_ROFS + ROFSACC(i)
                        TOTAL_ROFB = TOTAL_ROFB + ROFBACC(i)
                        TOTAL_PREACC = TOTAL_PREACC + PREACC(i)
                        TOTAL_EVAPACC = TOTAL_EVAPACC + EVAPACC(i)
                        TOTAL_ROFACC = TOTAL_ROFACC + ROFACC(i)
                        TOTAL_ROFOACC = TOTAL_ROFOACC + ROFOACC(i)
                        TOTAL_ROFSACC = TOTAL_ROFSACC + ROFSACC(i)
                        TOTAL_ROFBACC = TOTAL_ROFBACC + ROFBACC(i)
                        wb%pre(i) = wb%pre(i) + PREACC(i)
                        wb%evap(i) = wb%evap(i) + EVAPACC(i)
                        wb%rof(i) = wb%rof(i) + ROFACC(i)
                        wb%rofo(i) = wb%rofo(i) + ROFOACC(i)
                        wb%rofs(i) =  wb%rofs(i) + ROFSACC(i)
                        wb%rofb(i) = wb%rofb(i) + ROFBACC(i)

!> update components for final energy balance tally
                        TOTAL_HFSACC  = TOTAL_HFSACC  + HFSACC(i)
                        TOTAL_QEVPACC = TOTAL_QEVPACC + QEVPACC(i)
                        eng%hfs(i) = eng%hfs(i) + HFSACC(i)
                        eng%qevp(i) = eng%qevp(i) + QEVPACC(i)
                        do j = 1, IGND
                            eng%gflx(i, j) = eng%gflx(i, j) + GFLXACC(i, j)
                        end do
                    end if
                end do

    !> update components for final water balance tally
                wb%rcan = 0.0
                wb%sncan = 0.0
                wb%pndw = 0.0
                wb%sno = 0.0
                wb%wsno = 0.0
                wb%lqws = 0.0
                wb%frws = 0.0
                sov%tbar = 0.0
                sov%thic = 0.0
                sov%thic = 0.0

                do k = il1, il2
                    ik = shd%lc%ILMOS(k)
                    if (shd%FRAC(ik) >= 0.0) then
                        TOTAL_SCAN = TOTAL_SCAN + FAREGAT(k)*SCANGAT(k)
                        TOTAL_RCAN = TOTAL_RCAN + FAREGAT(k)*RCANGAT(k)
                        TOTAL_SNO = TOTAL_SNO + FAREGAT(k)*SNOGAT(k)
                        TOTAL_WSNO = TOTAL_WSNO + FAREGAT(k)*WSNOGAT(k)
                        TOTAL_ZPND = TOTAL_ZPND + FAREGAT(k)*ZPNDGAT(k)*RHOW
                        wb%rcan(ik) = wb%rcan(ik) + FAREGAT(k)*SCANGAT(k)
                        wb%sncan(ik) = wb%sncan(ik) + FAREGAT(k)*RCANGAT(k)
                        wb%pndw(ik) = wb%pndw(ik) + FAREGAT(k)*ZPNDGAT(k)*RHOW
                        wb%sno(ik) = wb%sno(ik) + FAREGAT(k)*SNOGAT(k)
                        wb%wsno(ik) = wb%wsno(ik) + FAREGAT(k)*WSNOGAT(k)
                        do j = 1, IGND
                            TOTAL_THLQ(j) = TOTAL_THLQ(j) + FAREGAT(k)*THLQGAT(k, j)*RHOW*DLZWGAT(k, j)
                            TOTAL_THIC(j) = TOTAL_THIC(j) + FAREGAT(k)*THICGAT(k, j)*RHOICE*DLZWGAT(k, j)
                            wb%lqws(ik, j) = wb%lqws(ik, j) + FAREGAT(k)*THLQGAT(k, j)*RHOW*DLZWGAT(k, j)
                            wb%frws(ik, j) = wb%frws(ik, j) + FAREGAT(k)*THICGAT(k, j)*RHOICE*DLZWGAT(k, j)
                            sov%tbar(ik, j) = sov%tbar(ik, j) + TBARGAT(k, j)*shd%lc%ACLASS(ik, shd%lc%JLMOS(k))
                            sov%thic(ik, j) = sov%thic(ik, j) + FAREGAT(k)*THICGAT(k, j)
                            sov%thlq(ik, j) = sov%thlq(ik, j) + FAREGAT(k)*THLQGAT(k, j)
                        end do
                    end if !(shd%FRAC(ik) >= 0.0) then
                end do !k = il1, il2

    !> Calculate storage
                wb%stg = wb%rcan + wb%sncan + wb%pndw + wb%sno + wb%wsno + sum(wb%lqws, 2) + sum(wb%frws, 2)
                wb%dstg = wb%stg - wb%dstg
                TOTAL_STORE = TOTAL_SCAN + TOTAL_RCAN + TOTAL_SNO + TOTAL_WSNO + TOTAL_ZPND + sum(TOTAL_THLQ) + sum(TOTAL_THIC)

    !> Write output CSV files.
                if (BASINBALANCEOUTFLAG > 0) then

        !> Water balance.
                    write(fls%fl(mfk%f900)%iun, "(i4,',', i5,',', 999(e14.6,','))") &
                          JDAY_NOW, YEAR_NOW, &
                          TOTAL_PREACC/TOTAL_AREA, &
                          TOTAL_EVAPACC/TOTAL_AREA, &
                          TOTAL_ROFACC/TOTAL_AREA, &
                          TOTAL_ROFOACC/TOTAL_AREA, &
                          TOTAL_ROFSACC/TOTAL_AREA, &
                          TOTAL_ROFBACC/TOTAL_AREA, &
                          TOTAL_PRE/TOTAL_AREA, &
                          TOTAL_EVAP/TOTAL_AREA, &
                          TOTAL_ROF/TOTAL_AREA, &
                          TOTAL_ROFO/TOTAL_AREA, &
                          TOTAL_ROFS/TOTAL_AREA, &
                          TOTAL_ROFB/TOTAL_AREA, &
                          TOTAL_SCAN/TOTAL_AREA, &
                          TOTAL_RCAN/TOTAL_AREA, &
                          TOTAL_SNO/TOTAL_AREA, &
                          TOTAL_WSNO/TOTAL_AREA, &
                          TOTAL_ZPND/TOTAL_AREA, &
                          (TOTAL_THLQ(j)/TOTAL_AREA, j = 1, IGND), &
                          (TOTAL_THIC(j)/TOTAL_AREA, j = 1, IGND), &
                          ((TOTAL_THLQ(j) + TOTAL_THIC(j))/TOTAL_AREA, j = 1, IGND), &
                          SUM(TOTAL_THLQ(1:IGND))/TOTAL_AREA, &
                          SUM(TOTAL_THIC(1:IGND))/TOTAL_AREA, &
                          (SUM(TOTAL_THLQ(1:IGND)) + SUM(TOTAL_THIC(1:IGND)))/TOTAL_AREA, &
                          TOTAL_STORE/TOTAL_AREA, &
                          (TOTAL_STORE - TOTAL_STORE_2)/TOTAL_AREA, &
                          (TOTAL_STORE - INIT_STORE)/TOTAL_AREA

        !> Energy balance.
                    write(901, "(i4,',', i5,',', 999(e12.5,','))") &
                          JDAY_NOW, YEAR_NOW, &
                          TOTAL_HFSACC/TOTAL_AREA, &
                          TOTAL_QEVPACC/TOTAL_AREA

        ! Monthly totals.
                    TOTAL_PRE_ACC_M = TOTAL_PRE_ACC_M + TOTAL_PRE
                    TOTAL_EVAP_ACC_M = TOTAL_EVAP_ACC_M + TOTAL_EVAP
                    TOTAL_ROF_ACC_M = TOTAL_ROF_ACC_M + TOTAL_ROF
                    TOTAL_ROFO_ACC_M = TOTAL_ROFO_ACC_M + TOTAL_ROFO
                    TOTAL_ROFS_ACC_M = TOTAL_ROFS_ACC_M + TOTAL_ROFS
                    TOTAL_ROFB_ACC_M = TOTAL_ROFB_ACC_M + TOTAL_ROFB
                    TOTAL_PRE_M = TOTAL_PRE_M + TOTAL_PRE
                    TOTAL_EVAP_M = TOTAL_EVAP_M + TOTAL_EVAP
                    TOTAL_ROF_M = TOTAL_ROF_M + TOTAL_ROF
                    TOTAL_ROFO_M = TOTAL_ROFO_M + TOTAL_ROFO
                    TOTAL_ROFS_M = TOTAL_ROFS_M + TOTAL_ROFS
                    TOTAL_ROFB_M = TOTAL_ROFB_M + TOTAL_ROFB
                    TOTAL_SCAN_M = TOTAL_SCAN_M + TOTAL_SCAN
                    TOTAL_RCAN_M = TOTAL_RCAN_M + TOTAL_RCAN
                    TOTAL_SNO_M = TOTAL_SNO_M + TOTAL_SNO
                    TOTAL_WSNO_M = TOTAL_WSNO_M + TOTAL_WSNO
                    TOTAL_ZPND_M = TOTAL_ZPND_M + TOTAL_ZPND
                    TOTAL_THLQ_M = TOTAL_THLQ_M + TOTAL_THLQ
                    TOTAL_THIC_M = TOTAL_THIC_M + TOTAL_THIC
                    TOTAL_STORE_M = TOTAL_STORE
                    TOTAL_STORE_ACC_M = TOTAL_STORE

        ! Write out monthly totals.
                    call FIND_MONTH(JDAY_NOW, YEAR_NOW, imonth_now)
                    if (imonth_now /= imonth_old) then
                        write(902, "(i4,',', i5,',', 999(e14.6,','))") &
                              JDAY_NOW, YEAR_NOW, &
                              TOTAL_PRE_ACC_M/TOTAL_AREA, &
                              TOTAL_EVAP_ACC_M/TOTAL_AREA, &
                              TOTAL_ROF_ACC_M/TOTAL_AREA, &
                              TOTAL_ROFO_ACC_M/TOTAL_AREA, &
                              TOTAL_ROFS_ACC_M/TOTAL_AREA, &
                              TOTAL_ROFB_ACC_M/TOTAL_AREA, &
                              TOTAL_PRE_M/TOTAL_AREA, &
                              TOTAL_EVAP_M/TOTAL_AREA, &
                              TOTAL_ROF_M/TOTAL_AREA, &
                              TOTAL_ROFO_M/TOTAL_AREA, &
                              TOTAL_ROFS_M/TOTAL_AREA, &
                              TOTAL_ROFB_M/TOTAL_AREA, &
                              TOTAL_SCAN_M/TOTAL_AREA, &
                              TOTAL_RCAN_M/TOTAL_AREA, &
                              TOTAL_SNO_M/TOTAL_AREA, &
                              TOTAL_WSNO_M/TOTAL_AREA, &
                              TOTAL_ZPND_M/TOTAL_AREA, &
                              (TOTAL_THLQ_M(j)/TOTAL_AREA, j = 1, IGND), &
                              (TOTAL_THIC_M(j)/TOTAL_AREA, j = 1, IGND), &
                              ((TOTAL_THLQ_M(j) + TOTAL_THIC_M(j))/TOTAL_AREA, j = 1, IGND), &
                              sum(TOTAL_THLQ_M(1:IGND))/TOTAL_AREA, &
                              sum(TOTAL_THIC_M(1:IGND))/TOTAL_AREA, &
                              (sum(TOTAL_THLQ_M(1:IGND)) + sum(TOTAL_THIC_M(1:IGND)))/TOTAL_AREA, &
                              TOTAL_STORE_M/TOTAL_AREA, &
                              (TOTAL_STORE_M - TOTAL_STORE_2_M)/TOTAL_AREA, &
                              (TOTAL_STORE_ACC_M - INIT_STORE)/TOTAL_AREA
                        TOTAL_PRE_M = 0.0
                        TOTAL_EVAP_M = 0.0
                        TOTAL_ROF_M = 0.0
                        TOTAL_ROFO_M = 0.0
                        TOTAL_ROFS_M = 0.0
                        TOTAL_ROFB_M = 0.0
                        TOTAL_SCAN_M = 0.0
                        TOTAL_RCAN_M = 0.0
                        TOTAL_SNO_M = 0.0
                        TOTAL_WSNO_M = 0.0
                        TOTAL_ZPND_M = 0.0
                        TOTAL_THLQ_M = 0.0
                        TOTAL_THIC_M = 0.0
                        TOTAL_STORE_2_M = TOTAL_STORE_M
                        TOTAL_STORE_M = 0.0
                        imonth_old = imonth_now
                    end if
                end if !(BASINBALANCEOUTFLAG > 0) then

!>  Added by Gonzalo Sapriza
    !DELTA STORAGE
                do i = 1, IGND
                    DSTG = DSTG + THLQ_FLD(:, i) + THIC_FLD(:, i)
                end do
                DSTG = DSTG + RCANACC + SCANACC + SNOACC - STG_I

                if (OUTFIELDSFLAG == 1) then
                    call UpdateFIELDSOUT(vr, ts, ifo, &
                                         wb%pre, wb%evap, wb%rof, wb%dstg, &
                                         sov%tbar, wb%lqws, wb%frws, &
                                         wb%rcan, wb%sncan, &
                                         wb%pndw, wb%sno, wb%wsno, &
                                         eng%gflx, eng%hfs, eng%qevp, &
                                         sov%thlq, sov%thic, &
                                         IGND, &
                                         JDAY_NOW, YEAR_NOW)
                end if
                STG_I = DSTG + STG_I

!RESET ACCUMULATION VARIABLES TO ZERO
!> RESET ACCUMULATOR ARRAYS.
                PREACC = 0.0
                GTACC = 0.0
                QEVPACC = 0.0
                HFSACC = 0.0
                HMFNACC = 0.0
                ROFACC = 0.0
                SNOACC = 0.0
                CANARE = 0.0
                SNOARE = 0.0
                ROFOACC = 0.0
                ROFSACC = 0.0
                ROFBACC = 0.0
                WTBLACC = 0.0
                TBARACC = 0.0
                THLQACC = 0.0
                THICACC = 0.0
                THALACC = 0.0
                GFLXACC = 0.0
                ALVSACC = 0.0
                ALIRACC = 0.0
                RHOSACC = 0.0
                TSNOACC = 0.0
                WSNOACC = 0.0
                TCANACC = 0.0
                RCANACC = 0.0
                SCANACC = 0.0
                GROACC = 0.0
                FSINACC = 0.0
                FLINACC = 0.0
                TAACC = 0.0
                UVACC = 0.0
                PRESACC = 0.0
                QAACC = 0.0
                EVAPACC = 0.0
                FLUTACC = 0.0
                TOTAL_STORE_2 = TOTAL_STORE
                TOTAL_STORE = 0.0
                TOTAL_RCAN = 0.0
                TOTAL_SCAN = 0.0
                TOTAL_SNO = 0.0
                TOTAL_WSNO = 0.0
                TOTAL_ZPND = 0.0
                TOTAL_THLQ = 0.0
                TOTAL_THIC = 0.0
                TOTAL_PRE = 0.0
                TOTAL_EVAP = 0.0
                TOTAL_ROF = 0.0
                TOTAL_ROFO = 0.0
                TOTAL_ROFS = 0.0
                TOTAL_ROFB = 0.0
                TOTAL_HFSACC = 0.0
                TOTAL_QEVPACC = 0.0
                eng%gflx = 0.0
                eng%hfs = 0.0
                eng%qevp = 0.0
                sov%tbar = 0.0
                sov%thic = 0.0
                sov%thlq = 0.0
                THIC_FLD = 0.0
                THLQ_FLD = 0.0
                DSTG = 0.0
            end if !(NCOUNT == 48) then
        end if !(ipid == 0) then

        NCOUNT = NCOUNT + 1 !todo: does this work with hourly forcing data?
        NSUM = NSUM + 1
        NSUM_TOTAL = NSUM_TOTAL + 1
        if (NCOUNT > 48) then !48 is the last half-hour period of the day
                      ! when they're numbered 1-48
            NCOUNT = 1
            NSUM = 1
        end if

        if (ipid == 0) call run_between_grid(shd, ts, ic, cm, wb, eng, sov)

!> *********************************************************************
!> Call routing routine
!> *********************************************************************

        if (ipid == 0) then
            call WF_ROUTE(WF_ROUTETIMESTEP, WF_R1, WF_R2, &
                          NA, shd%NAA, NTYPE, shd%yCount, shd%xCount, shd%iyMin, &
                          shd%iyMax, shd%jxMin, shd%jxMax, shd%yyy, shd%xxx, shd%IAK, shd%IROUGH, &
                          shd%ICHNL, shd%NEXT, shd%IREACH, shd%AL, shd%GRDN, shd%GRDE, &
                          shd%DA, shd%BNKFLL, shd%SLOPE_CHNL, shd%ELEV, shd%FRAC, &
                          WF_NO, WF_NL, WF_MHRD, WF_KT, WF_IY, WF_JX, &
                          WF_QHYD, WF_RES, WF_RESSTORE, WF_NORESV_CTRL, WF_R, &
                          WF_NORESV, WF_NREL, WF_KTR, WF_IRES, WF_JRES, WF_RESNAME, &
                          WF_B1, WF_B2, WF_QREL, WF_QR, &
                          WF_TIMECOUNT, WF_NHYD, WF_QBASE, WF_QI1, WF_QI2, WF_QO1, WF_QO2, &
                          WF_STORE1, WF_STORE2, &
                          DRIVERTIMESTEP, ROFGRD, NA, M_C, M_R, M_S, NA, &
                          WF_S, JAN, JDAY_NOW, HOUR_NOW, MINS_NOW)
            do i = 1, WF_NO
                WF_QSYN(i) = WF_QO2(WF_S(i))
                WF_QSYN_AVG(i) = WF_QSYN_AVG(i) + WF_QO2(WF_S(i))
                WF_QSYN_CUM(i) = WF_QSYN_CUM(i) + WF_QO2(WF_S(i))
                WF_QHYD_AVG(i) = WF_QHYD(i) !(MAM)THIS SEEMS WORKING OKAY (AS IS THE CASE IN THE READING) FOR A DAILY STREAM FLOW DATA.
            end do

            if (JAN == 1) then
!>     this is done so that INIT_STORE is not recalculated for
!>     each iteration when wf_route is not used
                JAN = 2
            end if

!> *********************************************************************
!> Write measured and simulated streamflow to file and screen
!> Also write daily summary (pre, evap, rof)
!> *********************************************************************

    !> Write output for hourly streamflow.
            if (STREAMFLOWFLAG == 1 .and. STREAMFLOWOUTFLAG >= 2) then
                write(71, 5085) JDAY_NOW, HOUR_NOW, MINS_NOW, (WF_QHYD(i), WF_QSYN(i), i = 1, WF_NO)
            end if

            if (NCOUNT == 48) then !48 is the last half-hour period of the day
                      ! when they're numbered 1-48

                do i = 1, WF_NO
                    WF_QHYD_CUM(i) = WF_QHYD_CUM(i) + WF_QHYD_AVG(i)
                end do

    !> Write output for daily and cumulative daily streamflow.
                if (STREAMFLOWOUTFLAG > 0) then
                    write(fls%fl(mfk%f70)%iun, 5084) JDAY_NOW, (WF_QHYD_AVG(i), WF_QSYN_AVG(i)/NCOUNT, i = 1, WF_NO)
                    if (STREAMFLOWOUTFLAG >= 2) then
                        write(72, 5084) JDAY_NOW, (WF_QHYD_CUM(i), WF_QSYN_CUM(i)/NCOUNT, i = 1, WF_NO)
                    end if
                end if

5084    format(i5, ',', f10.3, 999(',', f10.3))
5085    format(3(i5, ','), f10.3, 999(',', f10.3))

                if (ro%VERBOSEMODE > 0) then
                    if (WF_NUM_POINTS > 1) then !FOR MORE THAN ONE OUTPUT
                        print 5176, YEAR_NOW, JDAY_NOW, (WF_QHYD_AVG(i), WF_QSYN_AVG(i)/NCOUNT, i = 1, WF_NO)
                    else !FOR GENERAL CASE OR SINGLE GRID OUTPUT POINT
    !todo: Update or remove this altogether. If to update, take NA-1 or something more akin
    !to an outlet, than the average middle-elevation grid (as it's coded now).
    !Should there be a choice to print point-process (pre, evap, rof) vs flow-process (wf_qo2)?
                        j = ceiling(real(NA)/2); if (WF_NUM_POINTS > 0) j = op%N_OUT(1)
                        print 5176, YEAR_NOW, JDAY_NOW, (WF_QHYD_AVG(i), WF_QSYN_AVG(i)/NCOUNT, i = 1, WF_NO), &
                            wb%pre(j), wb%evap(j), wb%rof(j)
                    end if
                end if !(ro%VERBOSEMODE > 0) then
                if (mtsflg%AUTOCALIBRATIONFLAG > 0) then
                    call stats_update_daily(WF_QHYD_AVG, WF_QSYN_AVG, NCOUNT)
                    if (mtsflg%PREEMPTIONFLAG > 1) then
                        if (FTEST > FBEST) goto 199
                    end if
                end if
                WF_QSYN_AVG = 0.0
                wb%pre = 0.0
                wb%evap = 0.0
                wb%rof = 0.0
                wb%rofo = 0.0
                wb%rofs =  0.0
                wb%rofb = 0.0
            end if !(NCOUNT == 48) then
        end if !(ipid == 0) then

5176    format(2i5, 999(f10.3))

! *********************************************************************
! Update time counters and return to beginning of main loop
! *********************************************************************

        MINS_NOW = MINS_NOW + TIME_STEP_MINS ! increment the current time by 30 minutes
        if (MINS_NOW == 60) then
            MINS_NOW = 0
            HOUR_NOW = HOUR_NOW + 1
            if (HOUR_NOW == 24) then
                HOUR_NOW = 0
                JDAY_NOW = JDAY_NOW + 1
                if (JDAY_NOW >= 366) then
                    if (mod(YEAR_NOW, 400) == 0) then !LEAP YEAR
                        if (JDAY_NOW == 367) then
                            JDAY_NOW = 1
                            YEAR_NOW = YEAR_NOW + 1
                        end if
                    else if (mod(YEAR_NOW, 100) == 0) then !NOT A LEAP YEAR
                        JDAY_NOW = 1
                        YEAR_NOW = YEAR_NOW + 1
                    else if (mod(YEAR_NOW, 4) == 0) then !LEAP YEAR
                        if (JDAY_NOW == 367) then
                            JDAY_NOW = 1
                            YEAR_NOW = YEAR_NOW + 1
                        end if
                    else !NOT A LEAP YEAR
                        JDAY_NOW = 1
                        YEAR_NOW = YEAR_NOW + 1
                    end if
                end if
            end if
        end if

!> check if we should terminate the run yet
        if (YEAR_NOW >= YEAR_STOP .and. YEAR_STOP > 0) then
            if (YEAR_NOW > YEAR_STOP) then
                ENDDATE = .true.
            else if (YEAR_NOW == YEAR_STOP .and. JDAY_NOW >= JDAY_STOP) then
                if (JDAY_NOW > JDAY_STOP) then
                    ENDDATE = .true.
                else if (JDAY_NOW == JDAY_STOP .and. HOUR_NOW >= HOUR_STOP) then
                    if (HOUR_NOW > HOUR_STOP) then
                        ENDDATE = .true.
                    else if (HOUR_NOW == HOUR_STOP .and. MINS_NOW >= MINS_STOP) then
                        ENDDATE = .true.
                    end if
                end if
            end if
        end if
        TIME_STEP_NOW = TIME_STEP_NOW + TIME_STEP_MINS
        if (TIME_STEP_NOW == HOURLYFLAG) TIME_STEP_NOW = 0

        call update_now_iter_counter(ic, YEAR_NOW, JDAY_NOW, HOUR_NOW, MINS_NOW)

    !> *********************************************************************
    !> Read in meteorological forcing data
    !> *********************************************************************
        call climate_module_loaddata(shd, .false., cm, NML, il1, il2, ENDDATA)

    end do !while (.not. ENDDATE .and. .not. ENDDATA)

    !> End program if not the head node.
    if (ipid /= 0) then
!        print 4696, ipid
        goto 999

!4696 format (1x, 'Node ', i4, ' is exiting...')

    end if !(ipid /= 0) then

    call CLASSS(cp%TBARROW, cp%THLQROW, cp%THICROW, GFLXROW, TSFSROW, &
                cp%TPNDROW, cp%ZPNDROW, TBASROW, cp%ALBSROW, cp%TSNOROW, &
                cp%RHOSROW, cp%SNOROW, cp%TCANROW, cp%RCANROW, cp%SCANROW, &
                cp%GROROW, CMAIROW, TACROW, QACROW, WSNOROW, &
                shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, &
                NA, NTYPE, NML, il1, il2, IGND, ICAN, ICAN + 1, &
                TBARGAT, THLQGAT, THICGAT, GFLXGAT, TSFSGAT, &
                TPNDGAT, ZPNDGAT, TBASGAT, ALBSGAT, TSNOGAT, &
                RHOSGAT, SNOGAT, TCANGAT, RCANGAT, SCANGAT, &
                GROGAT, CMAIGAT, TACGAT, QACGAT, WSNOGAT, &
                cp%MANNROW, MANNGAT, cp%DDROW, DDGAT, &
                cp%SANDROW, SANDGAT, cp%CLAYROW, CLAYGAT, cp%XSLPROW, XSLPGAT, &
                DrySnowRow, SnowAgeROW, DrySnowGAT, SnowAgeGAT, &
                TSNOdsROW, RHOSdsROW, TSNOdsGAT, RHOSdsGAT, &
                DriftROW, SublROW, DepositionROW, &
                DriftGAT, SublGAT, DepositionGAT)
!>
!>   * SCATTER OPERATION ON DIAGNOSTIC VARIABLES SPLIT OUT OF
!>   * CLASSS FOR CONSISTENCY WITH GCM APPLICATIONS.
!>
    do 380 k = il1, il2
        ik = shd%lc%ILMOS(k)
        jk = shd%lc%JLMOS(k)
        CDHROW(ik, jk) = CDHGAT(k)
        CDMROW(ik, jk) = CDMGAT(k)
        HFSROW(ik, jk) = HFSGAT(k)
        TFXROW(ik, jk) = TFXGAT(k)
        QEVPROW(ik, jk) = QEVPGAT(k)
        QFSROW(ik, jk) = QFSGAT(k)
        QFXROW(ik, jk) = QFXGAT(k)
        PETROW(ik, jk) = PETGAT(k)
        GAROW(ik, jk) = GAGAT(k)
        EFROW(ik, jk) = EFGAT(k)
        GTROW(ik, jk) = GTGAT(k)
        QGROW(ik, jk) = QGGAT(k)
        ALVSROW(ik, jk) = ALVSGAT(k)
        ALIRROW(ik, jk) = ALIRGAT(k)
        SFCTROW(ik, jk) = SFCTGAT(k)
        SFCUROW(ik, jk) = SFCUGAT(k)
        SFCVROW(ik, jk) = SFCVGAT(k)
        SFCQROW(ik, jk) = SFCQGAT(k)
        FSNOROW(ik, jk) = FSNOGAT(k)
        FSGVROW(ik, jk) = FSGVGAT(k)
        FSGSROW(ik, jk) = FSGSGAT(k)
        FSGGROW(ik, jk) = FSGGGAT(k)
        FLGVROW(ik, jk) = FLGVGAT(k)
        FLGSROW(ik, jk) = FLGSGAT(k)
        FLGGROW(ik, jk) = FLGGGAT(k)
        HFSCROW(ik, jk) = HFSCGAT(k)
        HFSSROW(ik, jk) = HFSSGAT(k)
        HFSGROW(ik, jk) = HFSGGAT(k)
        HEVCROW(ik, jk) = HEVCGAT(k)
        HEVSROW(ik, jk) = HEVSGAT(k)
        HEVGROW(ik, jk) = HEVGGAT(k)
        HMFCROW(ik, jk) = HMFCGAT(k)
        HMFNROW(ik, jk) = HMFNGAT(k)
        HTCCROW(ik, jk) = HTCCGAT(k)
        HTCSROW(ik, jk) = HTCSGAT(k)
        PCFCROW(ik, jk) = PCFCGAT(k)
        PCLCROW(ik, jk) = PCLCGAT(k)
        PCPNROW(ik, jk) = PCPNGAT(k)
        PCPGROW(ik, jk) = PCPGGAT(k)
        QFGROW(ik, jk) = QFGGAT(k)
        QFNROW(ik, jk) = QFNGAT(k)
        QFCLROW(ik, jk) = QFCLGAT(k)
        QFCFROW(ik, jk) = QFCFGAT(k)
        ROFROW(ik, jk) = ROFGAT(k)
        ROFOROW(ik, jk) = ROFOGAT(k)
        ROFSROW(ik, jk) = ROFSGAT(k)
        ROFBROW(ik, jk) = ROFBGAT(k)
        TROFROW(ik, jk) = TROFGAT(k)
        TROOROW(ik, jk) = TROOGAT(k)
        TROSROW(ik, jk) = TROSGAT(k)
        TROBROW(ik, jk) = TROBGAT(k)
        ROFCROW(ik, jk) = ROFCGAT(k)
        ROFNROW(ik, jk) = ROFNGAT(k)
        ROVGROW(ik, jk) = ROVGGAT(k)
        WTRCROW(ik, jk) = WTRCGAT(k)
        WTRSROW(ik, jk) = WTRSGAT(k)
        WTRGROW(ik, jk) = WTRGGAT(k)
        DRROW(ik, jk) = DRGAT(k)
        WTABROW(ik, jk) = WTABGAT(k)
        ILMOROW(ik, jk) = ILMOGAT(k)
        UEROW(ik, jk) = UEGAT(k)
        HBLROW(ik, jk) = HBLGAT(k)
380     continue
!>
    do 390 l = 1, IGND
        do 390 k = il1, il2
            ik = shd%lc%ILMOS(k)
            jk = shd%lc%JLMOS(k)
            HMFGROW(ik, jk, l) = HMFGGAT(k, l)
            HTCROW(ik, jk, l) = HTCGAT(k, l)
            QFCROW(ik, jk, l) = QFCGAT(k, l)
390     continue
!>
    do 430 m = 1, 50
        do 420 l = 1, 6
            do 410 k = il1, il2
                ITCTROW(shd%lc%ILMOS(k), shd%lc%JLMOS(k), l, m) = ITCTGAT(k, l, m)
410     continue
420     continue
430     continue

!> *********************************************************************
!> Run is now over, print final results to the screen and close files
!> *********************************************************************

!> *********************************************************************
!> Save the state of the basin in r2c file format
!> *********************************************************************

!> Write the resume file
    if (SAVERESUMEFLAG == 2) then !todo: done: use a flag
        print *, 'Saving state variables in r2c file format'

! Allocate arrays for save_state_r2c
        open(55, file = 'save_state_r2c.txt', action = 'read')
        read(55, *, iostat = IOS) NR2C_S, DELTR2C_S
        if (IOS == 0) then
            allocate(GRD_S(NR2C_S), GAT_S(NR2C_S), GRDGAT_S(NR2C_S), R2C_ATTRIBUTES_S(NR2C_S, 3), stat = PAS)
            if (PAS /= 0) then
                print *, 'ALLOCATION ERROR: CHECK THE VALUE OF THE FIRST ', &
                    'RECORD AT THE FIRST LINE IN THE save_state_r2c.txt FILE. ', &
                    'IT SHOULD BE AN INTEGER VALUE (GREATER THAN 0).'
                stop
            end if
        end if
        close(55)

        call SAVE_STATE_R2C(shd%lc%NML, NLTEST, NMTEST, NCOUNT, &
                            MINS_NOW, shd%lc%ACLASS, NR2C_S, GRD_S, GAT_S, GRDGAT_S, R2C_ATTRIBUTES_S, &
                            NA, shd%xxx, shd%yyy, shd%xCount, shd%yCount, shd%lc%ILMOS, shd%lc%JLMOS, NML, ICAN, ICP1, IGND, &
                            TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                            TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                            TCANGAT, RCANGAT, SCANGAT, GROGAT, CMAIGAT, &
                            FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                            PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                            VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                            HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                            THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                            GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, &
                            THFCGAT, PSIWGAT, DLZWGAT, ZBTWGAT, &
                            ZSNLGAT, ZPLGGAT, ZPLSGAT, TACGAT, QACGAT, &
                            DRNGAT, XSLPGAT, XDGAT, WFSFGAT, KSGAT, &
                            ALGWGAT, ALGDGAT, ASVDGAT, ASIDGAT, AGVDGAT, &
                            AGIDGAT, ISNDGAT, RADJGAT, ZBLDGAT, Z0ORGAT, &
                            ZRFMGAT, ZRFHGAT, ZDMGAT, ZDHGAT, FSVHGAT, &
                            FSIHGAT, CSZGAT, FDLGAT, ULGAT, VLGAT, &
                            TAGAT, QAGAT, PRESGAT, PREGAT, PADRGAT, &
                            VPDGAT, TADPGAT, RHOAGAT, RPCPGAT, TRPCGAT, &
                            SPCPGAT, TSPCGAT, RHSIGAT, FCLOGAT, DLONGAT, &
                            GGEOGAT, &
                            CDHGAT, CDMGAT, HFSGAT, TFXGAT, QEVPGAT, &
                            QFSGAT, QFXGAT, PETGAT, GAGAT, EFGAT, &
                            GTGAT, QGGAT, ALVSGAT, ALIRGAT, &
                            SFCTGAT, SFCUGAT, SFCVGAT, SFCQGAT, FSNOGAT, &
                            FSGVGAT, FSGSGAT, FSGGGAT, FLGVGAT, FLGSGAT, &
                            FLGGGAT, HFSCGAT, HFSSGAT, HFSGGAT, HEVCGAT, &
                            HEVSGAT, HEVGGAT, HMFCGAT, HMFNGAT, HTCCGAT, &
                            HTCSGAT, PCFCGAT, PCLCGAT, PCPNGAT, PCPGGAT, &
                            QFGGAT, QFNGAT, QFCLGAT, QFCFGAT, ROFGAT, &
                            ROFOGAT, ROFSGAT, ROFBGAT, TROFGAT, TROOGAT, &
                            TROSGAT, TROBGAT, ROFCGAT, ROFNGAT, ROVGGAT, &
                            WTRCGAT, WTRSGAT, WTRGGAT, DRGAT, GFLXGAT, &
                            HMFGGAT, HTCGAT, QFCGAT, MANNGAT, DDGAT, &
                            SANDGAT, CLAYGAT, IGDRGAT, VMODGAT, QLWOGAT, &
                            shd%CoordSys%Proj, shd%CoordSys%Ellips, shd%CoordSys%Zone, &
                            shd%xOrigin, shd%yOrigin, shd%xDelta, shd%yDelta)
    end if !(SAVERESUMEFLAG == 2) then

!> Write the resume file
    if (SAVERESUMEFLAG == 1) then !todo: done: use a flag
        print *, 'Saving state variables'
        call SAVE_STATE(HOURLYFLAG, MINS_NOW, TIME_STEP_NOW, &
                        cm%clin(cfk%FB)%filefmt, cm%clin(cfk%FI)%filefmt, &
                        cm%clin(cfk%PR)%filefmt, cm%clin(cfk%TT)%filefmt, &
                        cm%clin(cfk%UV)%filefmt, cm%clin(cfk%P0)%filefmt, cm%clin(cfk%HU)%filefmt, &
                        cm%clin(cfk%FB)%climvGrd, FSVHGRD, FSIHGRD, cm%clin(cfk%FI)%climvGrd, &
                        i, j, shd%xCount, shd%yCount, jan, &
                        VPDGRD, TADPGRD, PADRGRD, RHOAGRD, RHSIGRD, &
                        RPCPGRD, TRPCGRD, SPCPGRD, TSPCGRD, cm%clin(cfk%TT)%climvGrd, &
                        cm%clin(cfk%HU)%climvGrd, cm%clin(cfk%PR)%climvGrd, RPREGRD, SPREGRD, cm%clin(cfk%P0)%climvGrd, &
!MAM - FOR FORCING DATA INTERPOLATION
                        FSVHGATPRE, FSIHGATPRE, FDLGATPRE, PREGATPRE, &
                        TAGATPRE, ULGATPRE, PRESGATPRE, QAGATPRE, &
                        IPCP, NA, NA, shd%lc%ILMOS, shd%lc%JLMOS, shd%wc%ILMOS, shd%wc%JLMOS, &
                        shd%lc%NML, shd%wc%NML, &
                        cp%GCGRD, cp%FAREROW, cp%MIDROW, NTYPE, NML, NMTEST, &
                        TBARGAT, THLQGAT, THICGAT, TPNDGAT, ZPNDGAT, &
                        TBASGAT, ALBSGAT, TSNOGAT, RHOSGAT, SNOGAT, &
                        TCANGAT, RCANGAT, SCANGAT, GROGAT, FRZCGAT, CMAIGAT, &
                        FCANGAT, LNZ0GAT, ALVCGAT, ALICGAT, PAMXGAT, &
                        PAMNGAT, CMASGAT, ROOTGAT, RSMNGAT, QA50GAT, &
                        VPDAGAT, VPDBGAT, PSGAGAT, PSGBGAT, PAIDGAT, &
                        HGTDGAT, ACVDGAT, ACIDGAT, TSFSGAT, WSNOGAT, &
                        THPGAT, THRGAT, THMGAT, BIGAT, PSISGAT, &
                        GRKSGAT, THRAGAT, HCPSGAT, TCSGAT, THFCGAT, &
                        PSIWGAT, DLZWGAT, ZBTWGAT, ZSNLGAT, ZPLGGAT, &
                        ZPLSGAT, TACGAT, QACGAT, DRNGAT, XSLPGAT, &
                        XDGAT, WFSFGAT, KSGAT, ALGWGAT, ALGDGAT, &
                        ASVDGAT, ASIDGAT, AGVDGAT, AGIDGAT, ISNDGAT, &
                        RADJGAT, ZBLDGAT, Z0ORGAT, ZRFMGAT, ZRFHGAT, &
                        ZDMGAT, ZDHGAT, FSVHGAT, FSIHGAT, CSZGAT, &
                        FDLGAT, ULGAT, VLGAT, TAGAT, QAGAT, PRESGAT, &
                        PREGAT, PADRGAT, VPDGAT, TADPGAT, RHOAGAT, &
                        RPCPGAT, TRPCGAT, SPCPGAT, TSPCGAT, RHSIGAT, &
                        FCLOGAT, DLONGAT, GGEOGAT, CDHGAT, CDMGAT, &
                        HFSGAT, TFXGAT, QEVPGAT, QFSGAT, QFXGAT, &
                        PETGAT, GAGAT, EFGAT, GTGAT, QGGAT, &
                        ALVSGAT, ALIRGAT, SFCTGAT, SFCUGAT, SFCVGAT, &
                        SFCQGAT, FSNOGAT, FSGVGAT, FSGSGAT, FSGGGAT, &
                        FLGVGAT, FLGSGAT, FLGGGAT, HFSCGAT, HFSSGAT, &
                        HFSGGAT, HEVCGAT, HEVSGAT, HEVGGAT, HMFCGAT, &
                        HMFNGAT, HTCCGAT, HTCSGAT, PCFCGAT, PCLCGAT, &
                        PCPNGAT, PCPGGAT, QFGGAT, QFNGAT, QFCLGAT, &
                        QFCFGAT, ROFGAT, ROFOGAT, ROFSGAT, ROFBGAT, &
                        TROFGAT, TROOGAT, TROSGAT, TROBGAT, ROFCGAT, &
                        ROFNGAT, ROVGGAT, WTRCGAT, WTRSGAT, WTRGGAT, &
                        DRGAT, HMFGGAT, HTCGAT, QFCGAT, ITCTGAT, &
                        IGND, ICAN, ICP1, &
                        cp%TBARROW, cp%THLQROW, cp%THICROW, cp%TPNDROW, cp%ZPNDROW, &
                        TBASROW, cp%ALBSROW, cp%TSNOROW, cp%RHOSROW, cp%SNOROW, &
                        cp%TCANROW, cp%RCANROW, cp%SCANROW, cp%GROROW, CMAIROW, &
                        cp%FCANROW, cp%LNZ0ROW, cp%ALVCROW, cp%ALICROW, cp%PAMXROW, &
                        cp%PAMNROW, cp%CMASROW, cp%ROOTROW, cp%RSMNROW, cp%QA50ROW, &
                        cp%VPDAROW, cp%VPDBROW, cp%PSGAROW, cp%PSGBROW, PAIDROW, &
                        HGTDROW, ACVDROW, ACIDROW, TSFSROW, WSNOROW, &
                        THPROW, THRROW, THMROW, BIROW, PSISROW, &
                        GRKSROW, THRAROW, HCPSROW, TCSROW, THFCROW, &
                        PSIWROW, DLZWROW, ZBTWROW, hp%ZSNLROW, hp%ZPLGROW, &
                        hp%ZPLSROW, hp%FRZCROW, TACROW, QACROW, cp%DRNROW, cp%XSLPROW, &
                        cp%XDROW, WFSFROW, cp%KSROW, ALGWROW, ALGDROW, &
                        ASVDROW, ASIDROW, AGVDROW, AGIDROW, &
                        ISNDROW, RADJGRD, cp%ZBLDGRD, Z0ORGRD, &
                        cp%ZRFMGRD, cp%ZRFHGRD, ZDMGRD, ZDHGRD, CSZGRD, &
                        cm%clin(cfk%UV)%climvGrd, VLGRD, FCLOGRD, DLONGRD, GGEOGRD, &
                        cp%MANNROW, MANNGAT, cp%DDROW, DDGAT, &
                        IGDRROW, IGDRGAT, VMODGRD, VMODGAT, QLWOGAT, &
                        CTVSTP, CTSSTP, CT1STP, CT2STP, CT3STP, &
                        WTVSTP, WTSSTP, WTGSTP, &
                        sl%DELZ, FCS, FGS, FC, FG, N, &
                        ALVSCN, ALIRCN, ALVSG, ALIRG, ALVSCS, &
                        ALIRCS, ALVSSN, ALIRSN, ALVSGC, ALIRGC, &
                        ALVSSC, ALIRSC, TRVSCN, TRIRCN, TRVSCS, &
                        TRIRCS, FSVF, FSVFS, &
                        RAICAN, RAICNS, SNOCAN, SNOCNS, &
                        FRAINC, FSNOWC, FRAICS, FSNOCS, &
                        DISP, DISPS, ZOMLNC, ZOMLCS, ZOELNC, ZOELCS, &
                        ZOMLNG, ZOMLNS, ZOELNG, ZOELNS, &
                        CHCAP, CHCAPS, CMASSC, CMASCS, CWLCAP, &
                        CWFCAP, CWLCPS, CWFCPS, RC, RCS, RBCOEF, &
                        FROOT, ZPLIMC, ZPLIMG, ZPLMCS, ZPLMGS, &
                        TRSNOW, ZSNOW, JDAY_NOW, JLAT, IDISP, &
                        IZREF, IWF, IPAI, IHGT, IALC, IALS, IALG, &
                        TBARC, TBARG, TBARCS, TBARGS, THLIQC, THLIQG, &
                        THICEC, THICEG, HCPC, HCPG, TCTOPC, TCBOTC, &
                        TCTOPG, TCBOTG, &
                        GZEROC, GZEROG, GZROCS, GZROGS, G12C, G12G, &
                        G12CS, G12GS, G23C, G23G, G23CS, G23GS, &
                        QFREZC, QFREZG, QMELTC, QMELTG, &
                        EVAPC, EVAPCG,EVAPG, EVAPCS, EVPCSG, EVAPGS, &
                        TCANO, TCANS, TPONDC, TPONDG, TPNDCS, TPNDGS, &
                        TSNOCS, TSNOGS, WSNOCS, WSNOGS, RHOSCS, RHOSGS, &
                        WTABGAT, &
                        ILMOGAT, UEGAT, HBLGAT, &
                        shd%wc%ILG, ITC, ITCG, ITG, ISLFD, &
                        NLANDCS, NLANDGS, NLANDC, NLANDG, NLANDI, &
                        GFLXGAT, CDHROW, CDMROW, HFSROW, TFXROW, &
                        QEVPROW, QFSROW, QFXROW, PETROW, GAROW, &
                        EFROW, GTROW, QGROW, TSFROW, ALVSROW, &
                        ALIRROW, SFCTROW, SFCUROW, SFCVROW, SFCQROW, &
                        FSGVROW, FSGSROW, FSGGROW, FLGVROW, FLGSROW, &
                        FLGGROW, HFSCROW, HFSSROW, HFSGROW, HEVCROW, &
                        HEVSROW, HEVGROW, HMFCROW, HMFNROW, HTCCROW, &
                        HTCSROW, PCFCROW, PCLCROW, PCPNROW, PCPGROW, &
                        QFGROW, QFNROW, QFCLROW, QFCFROW, ROFROW, &
                        ROFOROW, ROFSROW, ROFBROW, TROFROW, TROOROW, &
                        TROSROW, TROBROW, ROFCROW, ROFNROW, ROVGROW, &
                        WTRCROW, WTRSROW, WTRGROW, DRROW, WTABROW, &
                        ILMOROW, UEROW, HBLROW, HMFGROW, HTCROW, &
                        QFCROW, FSNOROW, ITCTROW, NCOUNT, ireport, &
                        wfo_seq, YEAR_NOW, ensim_MONTH, ensim_DAY, &
                        HOUR_NOW, shd%xxx, shd%yyy, NA, &
                        NTYPE, DELT, TFREZ, UVGRD, SBC, RHOW, CURREC, &
                        M_C, M_S, M_R, &
                        WF_ROUTETIMESTEP, WF_R1, WF_R2, shd%NAA, shd%iyMin, &
                        shd%iyMax, shd%jxMin, shd%jxMax, shd%IAK, shd%IROUGH, &
                        shd%ICHNL, shd%NEXT, shd%IREACH, shd%AL, shd%GRDN, shd%GRDE, &
                        shd%DA, shd%BNKFLL, shd%SLOPE_CHNL, shd%ELEV, shd%FRAC, &
                        WF_NO, WF_NL, WF_MHRD, WF_KT, WF_IY, WF_JX, &
                        WF_QHYD, WF_RES, WF_RESSTORE, WF_NORESV_CTRL, WF_R, &
                        WF_NORESV, WF_NREL, WF_KTR, WF_IRES, WF_JRES, WF_RESNAME, &
                        WF_B1, WF_B2, WF_QREL, WF_QR, &
                        WF_TIMECOUNT, WF_NHYD, WF_QBASE, WF_QI1, WF_QI2, WF_QO1, WF_QO2, &
                        WF_STORE1, WF_STORE2, &
                        DRIVERTIMESTEP, ROFGRD, &
                        WF_S, &
                        TOTAL_ROFACC, TOTAL_ROFOACC, TOTAL_ROFSACC, &
                        TOTAL_ROFBACC, TOTAL_EVAPACC, TOTAL_PREACC, INIT_STORE, &
                        FINAL_STORE, TOTAL_AREA, TOTAL_HFSACC, TOTAL_QEVPACC, &
                        SOIL_POR_MAX, SOIL_DEPTH, S0, T_ICE_LENS, NMELT, t0_ACC, &
                        CO2CONC, COSZS, XDIFFUSC, CFLUXCG, CFLUXCS, &
                        AILCG, AILCGS, FCANC, FCANCS, CO2I1CG, CO2I1CS, CO2I2CG, CO2I2CS, &
                        SLAI, FCANCMX, ANCSVEG, ANCGVEG, RMLCSVEG, RMLCGVEG, &
                        AILC, PAIC, FIELDSM, WILTSM, &
                        RMATCTEM, RMATC, NOL2PFTS, ICTEMMOD, L2MAX, ICTEM, &
                        hp%fetchROW, hp%HtROW, hp%N_SROW, hp%A_SROW, hp%DistribROW, &
                        fetchGAT, HtGAT, N_SGAT, A_SGAT, DistribGAT)
    end if !(SAVERESUMEFLAG == 1) then

!> *********************************************************************
!> Call save_init_prog_variables_class.f90 to save initi prognostic variables by
!> by fields needd by classas as initial conditions
!> *********************************************************************

!> bjd - July 14, 2014: Gonzalo Sapriza
    if (SAVERESUMEFLAG == 3) then
!> Save the last time step
        call save_init_prog_variables_class(CMAIROW, QACROW, TACROW, &
                                            TBASROW, TSFSROW, WSNOROW, &
                                            cp%ALBSROW, cp%GROROW, cp%RCANROW, &
                                            cp%RHOSROW, cp%SCANROW, cp%SNOROW, &
                                            cp%TBARROW, cp%TCANROW, cp%THICROW, &
                                            cp%THLQROW, cp%TPNDROW, cp%TSNOROW, &
                                            cp%ZPNDROW, &
                                            NA, NTYPE, IGND, &
                                            fls)
    end if !(SAVERESUMEFLAG == 3) then

    if (OUTFIELDSFLAG == 1) call write_outputs(shd, fls, ts, ic, ifo, vr)

    if (ENDDATA) print *, 'Reached end of forcing data'
    if (ENDDATE) print *, 'Reached end of simulation date'

!> Calculate final storage
    FINAL_STORE = 0.0
    do k = il1, il2
        if (shd%FRAC(shd%lc%ILMOS(k)) >= 0.0) then
            FINAL_STORE = FINAL_STORE + FAREGAT(k)*(RCANGAT(k) + SCANGAT(k) + SNOGAT(k) + WSNOGAT(k) + ZPNDGAT(k)*RHOW)
            do j = 1, IGND
                FINAL_STORE = FINAL_STORE + FAREGAT(k)*(THLQGAT(k, j)*RHOW + THICGAT(k, j)*RHOICE)*DLZWGAT(k, j)
            end do
        end if
    end do

    !> write out final totals to screen
    if (ro%VERBOSEMODE > 0) then

        print *
        print 5641, 'Total Precipitation         (mm) =', TOTAL_PREACC/TOTAL_AREA
        print 5641, 'Total Evaporation           (mm) =', TOTAL_EVAPACC/TOTAL_AREA
        print 5641, 'Total Runoff                (mm) =', TOTAL_ROFACC/TOTAL_AREA
        print 5641, 'Storage (Change/Init/Final) (mm) =', (FINAL_STORE - INIT_STORE)/TOTAL_AREA, INIT_STORE/TOTAL_AREA, &
            FINAL_STORE/TOTAL_AREA
        print *
        print 5641, 'Total Overland flow         (mm) =', TOTAL_ROFOACC/TOTAL_AREA
        print 5641, 'Total Interflow             (mm) =', TOTAL_ROFSACC/TOTAL_AREA
        print 5641, 'Total Baseflow              (mm) =', TOTAL_ROFBACC/TOTAL_AREA
        print *

5641    format(3x, a34, 999(f11.3))
5635    format(1x, 'Program has terminated normally.'/)

    end if !(ro%VERBOSEMODE > 0) then

    print 5635

    !> Write final totals to output file.
    if (MODELINFOOUTFLAG > 0) then

        write(58, *)
        write(58, '(a, f11.3)') '  Total Precipitation         (mm) = ', TOTAL_PREACC/TOTAL_AREA
        write(58, '(a, f11.3)') '  Total Evaporation           (mm) = ', TOTAL_EVAPACC/TOTAL_AREA
        write(58, '(a, f11.3)') '  Total Runoff                (mm) = ', TOTAL_ROFACC/TOTAL_AREA
        write(58, '(a, 3f11.3)') '  Storage(Change/Init/Final)  (mm) = ', &
            (FINAL_STORE - INIT_STORE)/TOTAL_AREA, &
            INIT_STORE/TOTAL_AREA, &
            FINAL_STORE/TOTAL_AREA
        write(58, '(a, f11.3)') '  Total Overland flow         (mm) = ', TOTAL_ROFOACC/TOTAL_AREA
        write(58, '(a, f11.3)') '  Total Interflow             (mm) = ', TOTAL_ROFSACC/TOTAL_AREA
        write(58, '(a, f11.3)') '  Total Baseflow              (mm) = ', TOTAL_ROFBACC/TOTAL_AREA
        write(58, *)
        write(58, *)
        write(58, '(a)') 'Program has terminated normally.'
        write(58, *)

        call cpu_time(endprog)
        write(58, "('Time = ', e14.6, ' seconds.')") (endprog - startprog)

    end if !(MODELINFOOUTFLAG > 0) then

199 continue

    if (mtsflg%AUTOCALIBRATIONFLAG > 0) call stats_write()

999 continue
    close(51)

    !todo++:
    !todo++: CUT OUT CLASS ACCUMULATION AND OUTPUT FILES TO APPROPRIATE NODE
    !todo++:
    !> Close the CLASS output files if the GAT-index of the output point resides on this node.
    do i = 1, WF_NUM_POINTS
        if ((ipid /= 0 .or. izero == 0) .and. op%K_OUT(i) >= il1 .and. op%K_OUT(i) <= il2) then
            close(150 + i*10 + 1)
            close(150 + i*10 + 2)
            close(150 + i*10 + 3)
            close(150 + i*10 + 4)
            close(150 + i*10 + 5)
            close(150 + i*10 + 6)
            close(150 + i*10 + 7)
            close(150 + i*10 + 8)
            close(150 + i*10 + 9)
            close(150 + i*10 + 10)
        end if
    end do

    !> Close model output file.
    close(58)

    !> Close CSV streamflow files.
    close(fls%fl(mfk%f70)%iun)
    close(71)
    close(72)

    !> Close the SWE CSV files.
    close(85)
    close(86)

    !> Close the legacy binary format forcing files.
!    close(90)
!    close(91)
!    close(92)
!    close(93)
!    close(94)
!    close(95)
!    close(96)

    !> Close the CSV energy and water balance output files.
    close(fls%fl(mfk%f900)%iun)
    close(901)
    close(902)

9000    format(/1x, 'INTERPOLATIONFLAG IS NOT SPECIFIED CORRECTLY AND IS SET TO 0 BY THE MODEL.', &
               /1x, '0: NO INTERPOLATION OF FORCING DATA.', &
               /1x, '1: LINEARLY INTERPOLATES FORCING DATA FOR INTERMEDIATE TIME STEPS.', &
               /1x, 'NOTE: INTERPOLATIONFLAG SHOULD BE SET TO 0 FOR 30 MINUTE FORCING DATA.', /)

9002    format(/1x, 'ERROR IN READING r2c_output.txt FILE.', &
               /1x, 'THE FIRST RECORD AT THE FIRST LINE IS FOR THE NUMBER OF ALL THE', &
               /1x, 'VARIABLES LISTED IN THE r2c_output.txt FILE.',&
               /1x, 'THE SECOND RECORD AT THE FIRST LINE IS TIME STEP FOR R2C OUTPUT.', &
               /1x, 'IT SHOULD BE AN INTEGER MULTIPLE OF 30.',&
               /1x, 'THE REMAINING RECORDS SHOULD CONTAIN 3 COLUMNS FOR EACH VARIABLE WITH', &
               /1x, 'INTEGER VALUES OF EITHER 0 OR 1,', &
               /1x, 'AND 3 COLUMNS CONTAINING INFORMATION ABOUT THE VARIABLES.', /)

    call mpi_finalize(ierr)

    stop

end program
