module model_output

    !>******************************************************************************
    !>  Athor: Gonzalo Sapriza Azuri
    !>******************************************************************************

    use model_dates

    implicit none

    !> Data type to store basin information
    !* na: Number of grid cells [-]
    !* nm: Number of GRUs [-]
    !* ignd: Number of soil layers per grid [-]
    type basin_info
        integer :: na, nm, ignd
    end type basin_info

    !>
    !> *****************************************************************************
    !> Although it may seen redundant, data types for groups are created
    !> to include the time-series dim, if applicable, because of the way
    !> arrays are stored in Fortran. Storing group(t)%vars(i) can have significant
    !> overhead when compared to group_vars(t, i).
    !> *****************************************************************************
    !>

    !>
    !> *****************************************************************************
    !> Meteorological output data
    !> *****************************************************************************
    !>

    !> Data type for storing meteorlogical data in time and space.
    !* (1: time, 2: space)
    type met_data_series

        real, dimension(:, :), allocatable :: &
            fsdown, fsvh, fsih, fdl, ul, &
            ta, qa, pres, pre

        contains

        !> Procedure to initialize the variables and allocate the arrays.
        procedure :: init => init_met_data_series

    end type !met_data_series

    !> Data type for storing meteorological data in time or space.
    !* (1: time or space)
    type met_data

        real, dimension(:), allocatable :: &
            fsdown, fsvh, fsih, fdl, ul, &
            ta, qa, pres, pre

        contains

        !> Procedure to initialize the variables and allocate the arrays.
        procedure :: init => init_met_data

    end type !met_data

    !>
    !> *****************************************************************************
    !> Water balance output data
    !> *****************************************************************************
    !* pre: Precipitation [kg m-2]
    !* evap: Evaporation (water lost by evapotranspiration and sublimation, both rain and snow components) [kg m-2]
    !* rof: Runoff (combination of overland-, subsurface-, and base-flows) [kg m-2]
    !* rofo: Overland flow component of runoff [kg m-2]
    !* rofs: Subsurface flow component of runoff [kg m-2]
    !* rofb: Baseflow component of runoff [kg m-2]
    !* rcan: Rainfall intercepted by the canopy [kg m-2]
    !* sncan: Snowfall intercepted by the canopy [kg m-2]
    !* pndw: Water ponded at the surface of the soil [kg m-2]
    !* sno: Snowpack at the surface of the soil [kg m-2]
    !* wsno: Water stored in the snowpack [kg m-2]
    !* stg: Water stored in the system [kg m-2]
    !* dstg: Difference of water stored in the system compared to the previous time-step of the element [kg m-2]
    !* grid_area: Fractional area of the grid-square [m2 m-2]
    !* lqws: Water stored in the soil matrix [kg m-2]
    !* frws: Frozen water (ice) stored in the soil matrix [kg m-2]
    !* basin_area: Total fractional area of the basin [m2 m-2]
    !> *****************************************************************************
    !>

    !> Data type to store components of the water balance in time and space.
    !* (1: time, 2: space) or (1: time, 2: space, 3: soil layer)
    type water_balance_series

        real, dimension(:, :), allocatable :: &
            pre, evap, rof, &
            rofo, rofs, rofb, &
            rcan, sncan, pndw, sno, wsno, &
            stg, dstg, &
            grid_area
        real, dimension(:, :, :), allocatable :: &
            lqws, frws
        real :: basin_area

        contains

        procedure :: init => init_water_balance_series

    end type !water_balance_series

    !> Data type to store components of the water balance in time or space.
    !* (1: time or space) or (1: time or space, 2: soil layer)
    type water_balance

        real, dimension(:), allocatable :: &
            pre, evap, rof, &
            rofo, rofs, rofb, &
            rcan, sncan, pndw, sno, wsno, &
            stg, dstg, &
            grid_area
        real, dimension(:, :), allocatable :: &
            lqws, frws
        real :: basin_area

        contains

        procedure :: init => init_water_balance
!        procedure :: deallocate => deallocate_water_balance

    end type !water_balance

    !> Data type to store components of the energy balance in time and space.
    type energy_balance_series

        real, dimension(:, :), allocatable :: &
            hfs, qevp

    end type !energy_balance_series

    !> Data type to store components of the energy balance in time or space.
    type energy_balance

        real, dimension(:), allocatable :: &
            hfs, qevp

    end type !energy_balance

    !> Data type to store soil parameters.
    !* tbar: Temperature of the soil layer (1: grid, 2: soil layer).
    !* thic: Fractional (frozen water) ice-content stored in the soil layer (1: grid, 2: soil layer).
    !* thlq: Fractional water-content stored in the soil layer (1: grid, 2: soil layer).
    type soil_parameters

        real, dimension(:, :, :), allocatable :: &
            tbar, thic, thlq

        contains

        procedure :: init => init_soil_parameters

    end type

    type wr_output_series

        real, dimension(:, :), allocatable :: &
            rof, rchg

        contains

        procedure :: init => init_wr_output_series

    end type !wr_output_series

    !> Data type to store the output format and data handling for an output variable.
    !* name: Name of the variable.
    !* nargs: Number of arguments in the argument array.
    !* args: Argument array containing flags for handling the output of the variable (1: Arguments)
    !* out_*: Output is written if .TRUE.; *: time interval (e.g., 'Y', 'M', etc.).
    !* out_fmt: Format of the output (e.g., 'R2C', 'SEQ', etc.).
    !* out_acc: Method of accumulation (e.g., if accumulated, averaged, etc., over the time period).
    type data_var_out

        character*20 :: name
        integer :: nargs
        character*20, dimension(:), allocatable :: args
        logical :: out_y, out_m, out_s, out_d, out_h
        character*20 :: out_fmt, out_acc

        contains

        procedure :: allocate_args => data_var_out_allocate_args

    end type

    !> Total water and energy balances.
    !* wb: Water balance (1: grid).
    !* eb: Energy balance (1: grid).
    type out_bal_intg

        !real, dimension(:)  ,allocatable :: TOTAL_PRE   , TOTAL_EVAP , TOTAL_ROF
        !real, dimension(:)  ,allocatable :: TOTAL_ZPND  , TOTAL_RCAN , TOTAL_SCAN
        !real, dimension(:)  ,allocatable :: TOTAL_SNO   , TOTAL_STORE, DSTG
        !real, dimension(:)  ,allocatable :: TOTAL_ROFO  , TOTAL_ROFS , TOTAL_ROFB
        !real, dimension(:,:),allocatable :: TOTAL_lqws  , TOTAL_frws
        type(water_balance) :: wb

        !real, dimension(:)  ,allocatable :: TOTAL_HFSACC, TOTAL_QEVPACC
        !real :: TOTAL_AREA
        type(energy_balance) :: eb

    end type

    !> Contains the internal output response for a specific rank ID
    !> This type is mainly used to look at the model response in the
    !> Permafrost, Daily time step.
    !* na_id: Rank ID.
    !* rofo: Overland flow component of runoff (1: grid).
    !* rofs: Interflow (sub-surface) flow component of runoff (1: grid).
    !* rofb: Baseflow component of runoff (1: grid).
    !* gflx: Heat conduction (1: grid, 2: soil layer).
    !* thlq: Fractional liquid water content (1: grid, 2: soil layer).
    !* thic: Fractional frozen water (ice) content (1: grid, 2: soil layer).
    type OUT_INTER_RESP

        !Rank ID
        integer :: na_id

        !Runoff
        real, dimension(:)   , allocatable :: rofo, rofs, rofb

        !State variable and flux in soil layers
        real, dimension(:, :), allocatable :: gflx
        real, dimension(:, :), allocatable :: thlq, thic, tbar

    end type

    !>******************************************************************************
    !> This type contains the fields outputs
    !* *_y: Yearly value
    !* *_m: Monthly value
    !* *_s: Seasonal value
    !* *_d: Daily value
    !* wb*: Water balance (1: time-based index)
    !* sp*: Soil parameter (1: time-based index)
    type out_flds

        ! Component of the water balance
        !real, dimension(:,:), allocatable :: prec_y, prec_m, prec_s !Precipitation
        !real, dimension(:,:), allocatable :: evap_y, evap_m, evap_s !Evaporation
        !real, dimension(:,:), allocatable :: roff_y, roff_m, roff_s !Runoff
        !real, dimension(:,:), allocatable :: dstg_y, dstg_m, dstg_s !Delta Storage

        ! State Variables soil
        !real, dimension(:,:,:), allocatable :: tbar_y, tbar_m, tbar_s !Temperature in the soil layers
        !real, dimension(:,:,:), allocatable :: lqws_y, lqws_m, lqws_s !Liquid content in the soil layer
        !real, dimension(:,:,:), allocatable :: frws_y, frws_m, frws_s !Ice content in the soil layer
        !real, dimension(:,:), allocatable :: rcan_y, rcan_m, rcan_s ! Rainfall intercepted by the canopy
        !real, dimension(:,:), allocatable :: scan_y, scan_m, scan_s ! Snowfall intercepted by the canopy
        !real, dimension(:,:), allocatable :: pndw_y, pndw_m, pndw_s ! Water ponded at the surface of the soil
        !real, dimension(:,:), allocatable :: sno_y, sno_m, sno_s ! Snow stored at the surface of the soil (snowpack)
        !real, dimension(:,:), allocatable :: wsno_y, wsno_m, wsno_s ! Water stored in the snowpack
        type(water_balance_series) :: wbt_y, wbt_m, wbt_s, wbt_d, wbt_h
        type(water_balance) :: wd_ts

        type(soil_parameters) :: spt_y, spt_m, spt_s, spt_d, spt_h
        type(soil_parameters) :: sp_ts
        !type(soil_parameters_series) :: spt_y, spt_m, spt_s, spt_d, spt_h
        !type(soil_parameters) :: sp_ts

        !* mdt_h: Meteological data (hourly time-step).
        type(met_data_series) :: mdt_h
        type(met_data) :: md_ts

        type(wr_output_series) :: wroutt_h

        contains

        procedure :: init => init_out_flds

    end type

    !>******************************************************************************
    !* flIn: File that contains the input information of the variables that we want to init and the frequency.
    !* pthOut: path out.
    !* ids_var_out: Array that contains the IDs of the files and frequency (e.g., 'PREPC', 'Y', 'M', 'S', 'CUM', 'SEQ').
    !* nr_out: Number of output variables.
    TYPE info_out

        character*450 :: flIn
        character*450 :: pthOut
!        character*20, dimension(:,:), allocatable :: ids_var_out
        integer :: nr_out
        type(data_var_out), dimension(:), allocatable :: var_out

    END TYPE
    !>******************************************************************************

    !todo: Move this to somewhere more appropriate, perhaps as model_info.
    type(iter_counter), public :: public_ic

    contains

    subroutine init_met_data_series(mdt, bi, nts)

        !> Derived-type variable.
        class(met_data_series) :: mdt

        !> Input variables.
        !* nts: Number of time-steps in the series.
        type(basin_info), intent(in) :: bi
        integer, intent(in) :: nts

        !> Allocate the arrays.
        allocate( &
            mdt%fsdown(nts, bi%na), mdt%fsvh(nts, bi%na), mdt%fsih(nts, bi%na), mdt%fdl(nts, bi%na), mdt%ul(nts, bi%na), &
            mdt%ta(nts, bi%na), mdt%qa(nts, bi%na), mdt%pres(nts, bi%na), mdt%pre(nts, bi%na))

        !> Explicitly set all variables to 0.0.
        mdt%fsdown = 0.0
        mdt%fsvh = 0.0
        mdt%fsih = 0.0
        mdt%fdl = 0.0
        mdt%ul = 0.0
        mdt%ta = 0.0
        mdt%qa = 0.0
        mdt%pres = 0.0
        mdt%pre = 0.0

    end subroutine !init_met_data_series

    subroutine init_met_data(md, bi)

        !> Derived-type variable.
        class(met_data) :: md

        !> Input variables.
        type(basin_info), intent(in) :: bi

        !> Allocate the arrays.
        allocate( &
            md%fsdown(bi%na), md%fsvh(bi%na), md%fsih(bi%na), md%fdl(bi%na), md%ul(bi%na), &
            md%ta(bi%na), md%qa(bi%na), md%pres(bi%na), md%pre(bi%na))

        !> Explicitly set all variables to 0.0.
        md%fsdown = 0.0
        md%fsvh = 0.0
        md%fsih = 0.0
        md%fdl = 0.0
        md%ul = 0.0
        md%ta = 0.0
        md%qa = 0.0
        md%pres = 0.0
        md%pre = 0.0

    end subroutine !init_met_data

    subroutine data_var_out_allocate_args(vo, args)

        !> Type variable.
        class(data_var_out) :: vo

        !> Input variables.
        character*20, dimension(:), intent(in) :: args

        !> Local variables.
        integer :: i

        !> De-allocate the args if they have already been allocated.
        if (allocated(vo%args)) &
            deallocate(vo%args)

        !> Set nargs to the size of the array.
        vo%nargs = size(args)

        !> Allocate args and copy the input args to the array.
        allocate(vo%args(vo%nargs))
        vo%args = args

        !> Reset variables.
        vo%out_y = .false.
        vo%out_m = .false.
        vo%out_s = .false.
        vo%out_d = .false.
        vo%out_h = .false.
        vo%out_fmt = "unknown"

        !> Assign variables according to the args.
        do i = 1, vo%nargs

            !todo: A better means for comparison would be a string utility to convert all chars to lower-case, say, and then run the comparison.
            select case (trim(adjustl(vo%args(i))))

                !> Yearly output.
                case ("Y", "y")
                    vo%out_y = .true.

                !> Monthly output.
                case ("M", "m")
                    vo%out_m = .true.

                !> Seasonal output.
                case ("S", "s")
                    vo%out_s = .true.

                !> Daily output.
                case ("D", "d")
                    vo%out_d = .true.

                !> Hourly:
                case ("H", "h")
                    vo%out_h = .true.

                !> Output format.
                case ("R2C", "r2c", &
                      "SEQ", "seq", "BINSEQ", "binseq")
                    vo%out_fmt = vo%args(i)

                !> Method of accumulation.
                case ("CUM", "cum", &
                      "AVG", "avg", &
                      "MAX", "max", &
                      "MIN", "min")
                    vo%out_acc = vo%args(i)

                case default
                    print *, trim(vo%args(i)) // " (Line ", i, ") is an unrecognized argument for output."

            end select !case (vo%args(i))

        end do !i = 1, vo%nargs

    end subroutine !data_var_out_allocate_args

!    subroutine info_out_allocate_var_out(ifo, nvo)
!
!        class(info_out) :: ifo
!        integer :: nvo
!
!        if (allocated(ifo%var_out)) deallocate(ifo%var_out)
!        allocate(ifo%var_out(nvo))
!
!    end subroutine !info_out_allocate_var_out

    subroutine init_out_flds(vr, bi, ts)

        !> Type variable.
        class(out_flds) :: vr

        !> Input variables.
        type(basin_info), intent(in) :: bi
        type(dates_model), intent(in) :: ts

        !> Local variables.
        integer :: i

        !> Allocate arrays using basin info.

        !> Yearly:
        call vr%wbt_y%init(bi, ts%nyears)
        call vr%spt_y%init(bi, ts%nyears)

        !> Monthly:
        call vr%wbt_m%init(bi, ts%nmonths)
        call vr%spt_m%init(bi, ts%nmonths)

        !> Seasonally:
        call vr%wbt_s%init(bi, ts%nseason)
        call vr%spt_s%init(bi, ts%nseason)

        !> Daily:
        call vr%wbt_d%init(bi, ts%nr_days)
        call vr%spt_d%init(bi, ts%nr_days)

        !> Hourly:
        call vr%wbt_h%init(bi, max(1, 3600/public_ic%timestep))
        call vr%mdt_h%init(bi, max(1, 3600/public_ic%timestep))
        call vr%wroutt_h%init(bi, max(1, 3600/public_ic%timestep))

        !> Per time-step:
        call vr%md_ts%init(bi)

    end subroutine !init_out_flds

    subroutine init_water_balance_series(wbt, bi, nts)

        !> Type variable.
        class(water_balance_series) :: wbt

        !> Input variables.
        type(basin_info), intent(in) :: bi
        integer, intent(in) :: nts

        !> Allocate arrays using basin info.
        allocate( &
            wbt%pre(nts, bi%na), wbt%evap(nts, bi%na), wbt%rof(nts, bi%na), &
            wbt%rofo(nts, bi%na), wbt%rofs(nts, bi%na), wbt%rofb(nts, bi%na), &
            wbt%rcan(nts, bi%na), wbt%sncan(nts, bi%na), &
            wbt%pndw(nts, bi%na), wbt%sno(nts, bi%na), wbt%wsno(nts, bi%na), &
            wbt%stg(nts, bi%na), wbt%dstg(nts, bi%na), &
            wbt%grid_area(nts, bi%na), &
            wbt%lqws(nts, bi%na, bi%ignd), wbt%frws(nts, bi%na, bi%ignd))

        !> Explicitly set all variables to 0.0.
        wbt%pre = 0.0
        wbt%evap = 0.0
        wbt%rof = 0.0
        wbt%rofo = 0.0
        wbt%rofs = 0.0
        wbt%rofb = 0.0
        wbt%rcan = 0.0
        wbt%sncan = 0.0
        wbt%pndw = 0.0
        wbt%sno = 0.0
        wbt%wsno = 0.0
        wbt%stg = 0.0
        wbt%dstg = 0.0
        wbt%grid_area = 0.0
        wbt%lqws = 0.0
        wbt%frws = 0.0
        wbt%basin_area = 0.0

    end subroutine !init_water_balance_series

    subroutine init_water_balance(wb, bi)

        !> Type variable.
        class(water_balance) :: wb

        !> Input variables.
        type(basin_info), intent(in) :: bi

        !> Allocate arrays using basin info.
        allocate( &
            wb%pre(bi%na), wb%evap(bi%na), wb%rof(bi%na), &
            wb%rofo(bi%na), wb%rofs(bi%na), wb%rofb(bi%na), &
            wb%rcan(bi%na), wb%sncan(bi%na), &
            wb%pndw(bi%na), wb%sno(bi%na), wb%wsno(bi%na), &
            wb%stg(bi%na), wb%dstg(bi%na), &
            wb%grid_area(bi%na), &
            wb%lqws(bi%na, bi%ignd), wb%frws(bi%na, bi%ignd))

        !> Explicitly set all variables to 0.0.
        wb%pre = 0.0
        wb%evap = 0.0
        wb%rof = 0.0
        wb%rofo = 0.0
        wb%rofs = 0.0
        wb%rofb = 0.0
        wb%rcan = 0.0
        wb%sncan = 0.0
        wb%pndw = 0.0
        wb%sno = 0.0
        wb%wsno = 0.0
        wb%stg = 0.0
        wb%dstg = 0.0
        wb%grid_area = 0.0
        wb%lqws = 0.0
        wb%frws = 0.0
        wb%basin_area = 0.0

    end subroutine !init_water_balance

!    subroutine deallocate_water_balance(wb)

        !> Type variable.
!        class(water_balance) :: wb

        !> De-allocate arrays.
!        if (allocated(wb%pre)) deallocate(wb%pre)
!        if (allocated(wb%evap)) deallocate(wb%evap)
!        if (allocated(wb%rof)) deallocate(wb%rof)
!        if (allocated(wb%rofo)) deallocate(wb%rofo)
!        if (allocated(wb%rofs)) deallocate(wb%rofs)
!        if (allocated(wb%rofb)) deallocate(wb%rofb)
!        if (allocated(wb%rcan)) deallocate(wb%rcan)
!        if (allocated(wb%sncan)) deallocate(wb%sncan)
!        if (allocated(wb%pndw)) deallocate(wb%pndw)
!        if (allocated(wb%sno)) deallocate(wb%sno)
!        if (allocated(wb%wsno)) deallocate(wb%wsno)
!        if (allocated(wb%stg)) deallocate(wb%stg)
!        if (allocated(wb%dstg)) deallocate(wb%dstg)
!        if (allocated(wb%grid_area)) deallocate(wb%grid_area)
!        if (allocated(wb%lqws)) deallocate(wb%lqws)
!        if (allocated(wb%frws)) deallocate(wb%frws)

!    end subroutine !deallocate_water_balance

    subroutine init_soil_parameters(sp, bi, nts)

        !> Type variable.
        class(soil_parameters) :: sp

        !> Input variables.
        type(basin_info), intent(in) :: bi
        integer, intent(in) :: nts

        !> Allocate arrays using basin info.
        allocate( &
            sp%tbar(nts, bi%na, bi%ignd), &
            sp%thic(nts, bi%na, bi%ignd), sp%thlq(nts, bi%na, bi%ignd))

        !> Explicitly set all variables to 0.0.
        sp%tbar = 0.0
        sp%thic = 0.0
        sp%thlq = 0.0

    end subroutine !init_soil_parameters

    subroutine init_wr_output_series(wroutt, bi, nts)

        !> Type variable.
        class(wr_output_series) :: wroutt

        !> Input variables.
        type(basin_info), intent(in) :: bi
        integer, intent(in) :: nts

        !> Allocate arrays using basin info.
        allocate( &
            wroutt%rof(nts, bi%na), wroutt%rchg(nts, bi%na))

        !> Explicitly set all variables to zero.
        wroutt%rof = 0.0
        wroutt%rchg = 0.0

    end subroutine !init_wr_output_series

    !>******************************************************************************
    subroutine Init_Internal_resp(pmf_r, ts, ignd, naid)

        !>----------------------------------------------------------------------
        !>  Description: Init output of internal response
        !>  Allocatation
        !>----------------------------------------------------------------------

        !Inputs
        real, intent(in) :: naid
        integer, intent(in) :: ignd
        type(dates_model), intent(in) :: ts

        !Output
        type(OUT_INTER_RESP), intent(inout) :: pmf_r

        !>--------------Main Subtrouine start-----------------------------------

        allocate(pmf_r%rofo(ts%nr_days), &
                 pmf_r%rofs(ts%nr_days), &
                 pmf_r%rofb(ts%nr_days))

        allocate(pmf_r%gflx(ts%nr_days, ignd), &
                 pmf_r%thlq(ts%nr_days, ignd), &
                 pmf_r%thic(ts%nr_days, ignd), &
                 pmf_r%tbar(ts%nr_days, ignd))

        pmf_r%na_id = naid

    end subroutine Init_Internal_resp

    !>**********************************************************************
    subroutine Init_OutBal_Intg(bal, ts, ignd, area)

        !>------------------------------------------------------------------------------
        !>  Description: Init output water and energy balances
        !>
        !>------------------------------------------------------------------------------

        !Inputs
        real, intent(in) :: area
        integer, intent(in) :: ignd
        type(dates_model), intent(in) :: ts

        !Output
        type(out_bal_intg), intent(inout) :: bal

        !>--------------Main Subtrouine start-----------------------------------------------

        !> Allocate variables for basin totals.
        allocate(bal%wb%pre(ts%nr_days), bal%wb%evap(ts%nr_days), &
                 bal%wb%rof(ts%nr_days), &
                 bal%wb%rofo(ts%nr_days), bal%wb%rofs(ts%nr_days), bal%wb%rofb(ts%nr_days), &
                 bal%wb%rcan(ts%nr_days), bal%wb%sncan(ts%nr_days), &
                 bal%wb%pndw(ts%nr_days), bal%wb%sno(ts%nr_days), bal%wb%wsno(ts%nr_days), &
                 bal%wb%stg(ts%nr_days), bal%wb%dstg(ts%nr_days))

        allocate(bal%wb%lqws(ts%nr_days, ignd), bal%wb%frws(ts%nr_days, ignd))

        allocate(bal%eb%hfs(ts%nr_days), bal%eb%qevp(ts%nr_days))

        bal%wb%basin_area = area

    end subroutine Init_OutBal_Intg

    !>******************************************************************************
    subroutine Update_OutBal_Intg(bal, ts, ignd, &
                                  pre, evap, rof, &
                                  pndw, rcan, sncan, &
                                  sno, rofo, rofs, &
                                  rofb, stg, dstg, &
                                  frws, lqws, &
                                  hfs, qevp, &
                                  idate, isavg, nhours)

        !>------------------------------------------------------------------------------
        !>  Description: Update values and compute daily averages for water and
        !>  energy balance
        !>------------------------------------------------------------------------------

        !Input
        logical, intent(in) :: isavg
        integer, intent(in) :: idate, ignd
        integer, optional :: nhours

        type(dates_model), intent(in) :: ts

        real, intent(in) :: pre, evap, rof, pndw, rcan, sncan
        real, intent(in) :: sno, rofo, rofs, rofb, stg, dstg
        real, dimension(:), intent(in) :: frws, lqws
        real, intent(in) :: hfs, qevp

        !Output
        type(out_bal_intg), intent(inout) :: bal

        !Internal
        integer :: i

        !>--------------Main Subtrouine start-----------------------------------------------

        !> Rainfall
        bal%wb%pre(idate) = bal%wb%pre(idate) + pre
        if (isavg) &
            bal%wb%pre(idate) = bal%wb%pre(idate)/real(nhours)

        !> Evapotranspiration
        bal%wb%evap(idate) = bal%wb%evap(idate) + evap
        if (isavg) &
            bal%wb%evap(idate) = bal%wb%evap(idate)/real(nhours)

        !> Total runoff
        bal%wb%rof(idate) = bal%wb%rof(idate) + rof
        if (isavg) &
            bal%wb%rof(idate) = bal%wb%rof(idate)/real(nhours)

        !> Ponded water
        bal%wb%pndw(idate) = bal%wb%pndw(idate) + pndw
        if (isavg) &
            bal%wb%pndw(idate) = bal%wb%pndw(idate)/real(nhours)

        !> Rain intercepted in the canopy
        bal%wb%rcan(idate) = bal%wb%rcan(idate) + rcan
        if (isavg) &
            bal%wb%rcan(idate) = bal%wb%rcan(idate)/real(nhours)

        !> Snow intercepted in the canopy
        bal%wb%sncan(idate) = bal%wb%sncan(idate) + sncan
        if (isavg) &
            bal%wb%sncan(idate) = bal%wb%sncan(idate)/real(nhours)

        !> Snow on the surface
        bal%wb%sno(idate) = bal%wb%sno(idate) + sno
        if (isavg) &
            bal%wb%sno(idate) = bal%wb%sno(idate)/real(nhours)

        !> Overland component of total runoff
        bal%wb%rofo(idate) = bal%wb%rofo(idate) + rofo
        if (isavg) &
            bal%wb%rofo(idate) = bal%wb%rofo(idate)/real(nhours)

        !> Interflow/subsurface component of total runoff
        bal%wb%rofs(idate) = bal%wb%rofs(idate) + rofs
        if (isavg) &
            bal%wb%rofs(idate) = bal%wb%rofs(idate)/real(nhours)

        !> Baseflow component of total runoff
        bal%wb%rofb(idate) = bal%wb%rofb(idate) + rofb
        if (isavg) &
            bal%wb%rofb(idate) = bal%wb%rofb(idate)/real(nhours)

        !> Total Storage
        bal%wb%stg(idate) = bal%wb%stg(idate) + stg
        if (isavg) &
            bal%wb%stg(idate) = bal%wb%stg(idate)/real(nhours)

        !> Delta Storage
        bal%wb%dstg(idate) = bal%wb%dstg(idate) + dstg
        if (isavg) &
            bal%wb%dstg(idate) = bal%wb%dstg(idate)/real(nhours)

        !> Frozen and liquid water stored in the soil
        do i = 1, ignd
            bal%wb%frws(idate, i) = bal%wb%frws(idate, i) + frws(i)
            bal%wb%lqws(idate, i) = bal%wb%lqws(idate, i) + lqws(i)
            if (isavg) then
                bal%wb%frws(idate, i) = bal%wb%frws(idate, i)/real(nhours)
                bal%wb%lqws(idate, i) = bal%wb%lqws(idate, i)/real(nhours)
            end if
        end do

        !> Energy balance
        bal%eb%hfs(idate) = bal%eb%hfs(idate) + hfs
        bal%eb%qevp(idate) = bal%eb%qevp(idate) + qevp
        if (isavg) then
            bal%eb%hfs(idate) = bal%eb%hfs(idate)/real(nhours)
            bal%eb%qevp(idate) = bal%eb%qevp(idate)/real(nhours)
        end if

    end subroutine Update_OutBal_Intg

    !>******************************************************************************

    subroutine init_out(vr, ts, ifo, bi)

        !>------------------------------------------------------------------------------
        !>  Description: Init Fields
        !>
        !>------------------------------------------------------------------------------

        !Inputs
        type(basin_info) :: bi

        !Inputs-Output
        type(out_flds) :: vr
        type(dates_model) :: ts
        type(info_out) :: ifo

        !Internals
        integer :: ios, i, j, k, istat, nargs
        character*50 :: vId
        character*20, dimension(:), allocatable :: args

        call public_ic%init(ts%start_date(1), ts%start_date(2), ts%start_date(3), ts%start_date(4))

        !>--------------Main Subtrouine start-----------------------------------------------

        open(unit = 909, &
             file = 'outputs_balance.txt', &
             status = 'old', &
             action = 'read', &
             iostat = ios)

        ifo%flIn = 'outputs_balance.txt'

        read(909, *) ifo%pthOut
        read(909, *) ifo%nr_out

!        allocate(ifo%ids_var_out(ifo%nr_out, 6))
!        call ifo%allocate_var_out(ifo%nr_out)
        allocate(ifo%var_out(ifo%nr_out), stat = istat)
        if (istat /= 0) &
            print *, "Error allocating output variable array from file."

        !> Initialize variable.
        call vr%init(bi, ts)

        do i = 1, ifo%nr_out

            !> Read configuration information from file.
            !read(909, *) (ifo%ids_var_out(i, j), j = 1, 6)
            read(909, *) ifo%var_out(i)%name, nargs
            if (allocated(args)) deallocate(args)
            allocate(args(nargs))
            backspace(909)
            read(909, *) ifo%var_out(i)%name, nargs, (args(j), j = 1, nargs)
            call ifo%var_out(i)%allocate_args(args)

            !temp: Copy to old array
!            ifo%ids_var_out(i, 1) = ifo%var_out(i)%name
!            do j = 2, nargs + 1
!                ifo%ids_var_out(i, j) = ifo%var_out(i)%args(j - 1)
!            end do

!            !> Yearly:
!            if (trim(adjustl(ifo%ids_var_out(i, 2))) == 'zY') &
!                allocate(vr%sp_y(ts%nyears), vr%wb_y(ts%nyears))

!            !> Monthly:
!            if (trim(adjustl(ifo%ids_var_out(i, 3))) == 'zM') &
!                allocate(vr%sp_m(ts%nmonths), vr%wb_m(ts%nmonths))

!            !> Seasonally:
!            if (trim(adjustl(ifo%ids_var_out(i, 4))) == 'zS') &
!                allocate(vr%sp_s(ts%nseason), vr%wb_s(ts%nseason))

            !> Extract variable ID.
!            vId = trim(adjustl(ifo%ids_var_out(i, 1)))
            vId = trim(adjustl(ifo%var_out(i)%name))
            select case (vId)

                case ('ZPND')
                    print *, "Output of variable '" // trim(adjustl(vId)) // "' is not Implemented yet."
                    print *, "Use PNDW for ponded water at the surface [mm]."

                case ('ROFF')
                    print *, "Output of variable 'ROF' using keyword '" // trim(adjustl(vId)) // "' is not supported."
                    print *, "Use ROF for total runoff."

                case ('THIC', 'ICEContent_soil_layers')
                    print *, "Output of variable '" // trim(adjustl(vId)) // "' is not Implemented yet."
                    print *, "Use LQWS for liquid water stored in the soil [mm]."

                case ('THLQ', 'LiquidContent_soil_layers')
                    print *, "Output of variable '" // trim(adjustl(vId)) // "' is not Implemented yet."
                    print *, "Use FRWS for frozen water stored in the soil [mm]."

!                case default
!                    print *, "Output of variable '" // trim(adjustl(vId)) // "' is not Implemented yet."

            end select
        end do ! i = 1, ifo%nr_out

        close(unit = 909)

    end subroutine Init_out

    subroutine updatefieldsout_temp(vr, ts, ifo, bi, &
                                    md, wb, &
                                    now_year, now_day_julian, now_hour, now_timestep)

        !> Input variables.
        type(dates_model), intent(in) :: ts
        type(info_out), intent(in) :: ifo
        type(basin_info), intent(in) :: bi
        type(met_data) :: md
        type(water_balance) :: wb
        integer, intent(in) :: now_year, now_day_julian, now_hour, now_timestep

        !> Input-output variables.
        type(out_flds) :: vr

        !> Local variables.
        integer :: i, j
        character*3 :: freq

        !> Update output fields.
        do i = 1, ifo%nr_out
            select case (trim(adjustl(ifo%var_out(i)%name)))

                case ("FSDOWN")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fsdown, freq, public_ic%now_hour, now_hour, 882101, .true.)
                        vr%mdt_h%fsdown((now_timestep/public_ic%timestep + 1), :) = md%fsdown
                    end if

                case ("FSVH")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fsvh, freq, public_ic%now_hour, now_hour, 882102, .true.)
                        vr%mdt_h%fsvh((now_timestep/public_ic%timestep + 1), :) = md%fsvh
                    end if

                case ("FSIH")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fsih, freq, public_ic%now_hour, now_hour, 882103, .true.)
                        vr%mdt_h%fsih((now_timestep/public_ic%timestep + 1), :) = md%fsih
                    end if

                case ("FDL")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fdl, freq, public_ic%now_hour, now_hour, 882104, .true.)
                        vr%mdt_h%fdl((now_timestep/public_ic%timestep + 1), :) = md%fdl
                    end if

                case ("UL")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%ul, freq, public_ic%now_hour, now_hour, 882105, .true.)
                        vr%mdt_h%ul((now_timestep/public_ic%timestep + 1), :) = md%ul
                    end if

                case ("TA")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%ta, freq, public_ic%now_hour, now_hour, 882106, .true.)
                        vr%mdt_h%ta((now_timestep/public_ic%timestep + 1), :) = md%ta
                    end if

                case ("QA")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%qa, freq, public_ic%now_hour, now_hour, 882107, .true.)
                        vr%mdt_h%qa((now_timestep/public_ic%timestep + 1), :) = md%qa
                    end if

                case ("PRES")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%pres, freq, public_ic%now_hour, now_hour, 882108, .true.)
                        vr%mdt_h%pres((now_timestep/public_ic%timestep + 1), :) = md%pres
                    end if

                case ("PRE")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%pre, freq, public_ic%now_hour, now_hour, 882109, .true.)
                        vr%mdt_h%pre((now_timestep/public_ic%timestep + 1), :) = md%pre
                    end if

                case ("EVAP")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%evap, freq, public_ic%now_hour, now_hour, 882110, .true.)
                        vr%wbt_h%evap((now_timestep/public_ic%timestep + 1), :) = wb%evap
                    end if

                case ("ROF")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%rof, freq, public_ic%now_hour, now_hour, 882111, .true.)
                        vr%wbt_h%rof((now_timestep/public_ic%timestep + 1), :) = wb%rof
                    end if

                case ("LQWS")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        do j = 1, bi%ignd
                            call check_write_var_out(ifo, i, vr%wbt_h%lqws(:, :, j), freq, public_ic%now_hour, now_hour, &
                                (882112 + (100000000*j)), .true., j)
                            vr%wbt_h%lqws((now_timestep/public_ic%timestep + 1), :, j) = wb%lqws(:, j)
                        end do
                    end if

                case ("FRWS")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        do j = 1, bi%ignd
                            call check_write_var_out(ifo, i, vr%wbt_h%frws(:, :, j), freq, public_ic%now_hour, now_hour, &
                                (882113 + (100000000*j)), .true., j)
                            vr%wbt_h%frws((now_timestep/public_ic%timestep + 1), :, j) = wb%frws(:, j)
                        end do
                    end if

                case ("RCAN")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%rcan, freq, public_ic%now_hour, now_hour, 882114, .true.)
                        vr%wbt_h%rcan((now_timestep/public_ic%timestep + 1), :) = wb%rcan
                    end if

                case ("SNCAN")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%sncan, freq, public_ic%now_hour, now_hour, 882115, .true.)
                        vr%wbt_h%sncan((now_timestep/public_ic%timestep + 1), :) = wb%sncan
                    end if

                case ("PNDW")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%pndw, freq, public_ic%now_hour, now_hour, 882116, .true.)
                        vr%wbt_h%pndw((now_timestep/public_ic%timestep + 1), :) = wb%pndw
                    end if

                case ("SNO")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%sno, freq, public_ic%now_hour, now_hour, 882117, .true.)
                        vr%wbt_h%sno((now_timestep/public_ic%timestep + 1), :) = wb%sno
                    end if

                case ("WSNO")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%wsno, freq, public_ic%now_hour, now_hour, 882118, .true.)
                        vr%wbt_h%wsno((now_timestep/public_ic%timestep + 1), :) = wb%wsno
                    end if

                case ("STG")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%stg, freq, public_ic%now_hour, now_hour, 882119, .true.)
                        vr%wbt_h%stg((now_timestep/public_ic%timestep + 1), :) = wb%stg
                    end if

                case ("WR_RUNOFF")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wroutt_h%rof, freq, public_ic%now_hour, now_hour, 882120, .true.)
                        vr%wroutt_h%rof((now_timestep/public_ic%timestep + 1), :) = wb%rofo + wb%rofs
                    end if

                case ("WR_RECHARGE")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wroutt_h%rchg, freq, public_ic%now_hour, now_hour, 882121, .true.)
                        vr%wroutt_h%rchg((now_timestep/public_ic%timestep + 1), :) = wb%rofb
                    end if

            end select !case (trim(adjustl(ifo%var_out(i)%name)))
        end do !i = 1, ifo%nr_out

        !> Update index-array counter.
        call public_ic%update_now(now_year, now_day_julian, now_hour, now_timestep)

    end subroutine !updatefieldsout_temp

    subroutine check_write_var_out(ifo, var_id, fld_in, freq, old_time, now_time, file_unit, keep_file_open, igndx)

        !> Input variables.
        type(info_out), intent(in) :: ifo
        integer, intent(in) :: var_id
        real, dimension(:, :) :: fld_in
        character*3, intent(in) :: freq
        integer, intent(in) :: old_time, now_time, file_unit
        logical :: keep_file_open
        integer, intent(in), optional :: igndx

        !> Local variables.
        integer, dimension(:, :), allocatable :: dates
        real, dimension(:, :), allocatable :: fld_out
        character*3 :: freq2
        character*1 :: st

        !> Write output if at end of time-step.
        if (now_time /= old_time) then

            !> Write output.
            select case (trim(adjustl(freq)))

                case ("H")
                    allocate(fld_out(size(fld_in, 2), 1))
                    select case (trim(adjustl(ifo%var_out(var_id)%out_acc)))

                        case ("AVG")
                            fld_out(:, 1) = sum(fld_in, 1) / size(fld_in, 1)

                        case ("MAX")
                            fld_out(:, 1) = maxval(fld_in, 1)

                        case ("MIN")
                            fld_out(:, 1) = minval(fld_in, 1)

                        case default
                            fld_out(:, 1) = sum(fld_in, 1)

                    end select !case (trim(adjustl(ifo%var_out(i)%out_acc)))

            end select !case (trim(adjustl(freq)))

            !> Reset array.
            fld_in = 0.0

            !> fld will have been allocated if a supported frequency was selected.
            if (allocated(fld_out)) then

                !> Set dates to contain the current time-step.
                allocate(dates(1, 5))
                dates(1, 1) = public_ic%now_year
                dates(1, 2) = public_ic%now_month
                dates(1, 3) = public_ic%now_day
                dates(1, 4) = public_ic%now_day_julian
                dates(1, 5) = public_ic%now_hour

                !> Update freq to include soil layer (if applicable).
                if (present(igndx)) then
                    write(unit = st, fmt = "(I1)") igndx
                    freq2 = trim(freq) // "_" // st
                else
                    freq2 = freq
                end if

                !> Print the output.
                select case (trim(adjustl(ifo%var_out(var_id)%out_fmt)))

                    case ("r2c")
                        call WriteR2C(fld_out, var_id, ifo, freq2, dates, file_unit, keep_file_open, public_ic%count_hour)

                end select !case (trim(adjustl(ifo%var_out(var_id)%out_fmt)))

                !> De-allocate the temporary fld and dates variables.
                deallocate(fld_out, dates)

            end if !(allocated(fld)) then

        end if !(now_time /= old_time) then

    end subroutine !check_write_var_out

    subroutine UpdateFIELDSOUT(vr, ts, ifo, &
                               pre, evap, rof, dstg, &
                               tbar, lqws, frws, &
                               rcan, sncan, &
                               pndw, sno, wsno, &
                               na,  ignd, &
                               iday, iyear)

        !>------------------------------------------------------------------------------
        !>  Description: Update values in each time step
        !>------------------------------------------------------------------------------

        !Inputs
        integer :: na, ignd
        integer :: iday, iyear
        type(dates_model) :: ts
        type(info_out) :: ifo

        real, dimension(:), intent(in) :: pre, evap, rof, dstg, &
                                          rcan, sncan, &
                                          pndw, sno, wsno
        real, dimension(:, :), intent(in) :: tbar, lqws, frws

        !Inputs-Output
        type(out_flds) :: vr

        !Internals
        integer :: i, iy, im, iss, id
        character*50 :: vId

        call GetIndicesDATES(iday, iyear, iy, im, iss, id, ts)

        do i = 1, ifo%nr_out

!            vId = trim(adjustl(ifo%ids_var_out(i, 1)))
            vId = trim(adjustl(ifo%var_out(i)%name))

            select case (vId)

                case ('PREC', 'Rainfall', 'Rain', 'Precipitation')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%pre(iy, :) = vr%wbt_y%pre(iy, :) + pre

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%pre(im, :) = vr%wbt_m%pre(im, :) + pre

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%pre(iss, :) = vr%wbt_s%pre(iss, :) + pre

                    if (ifo%var_out(i)%out_d) &
                        vr%wbt_d%pre(id, :) = vr%wbt_d%pre(id, :) + pre

                case ('EVAP', 'Evapotranspiration')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%evap(iy, :) = vr%wbt_y%evap(iy, :) + evap

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%evap(im, :) = vr%wbt_m%evap(im, :) + evap

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%evap(iss, :) = vr%wbt_s%evap(iss, :) + evap

                    if (ifo%var_out(i)%out_d) &
                        vr%wbt_d%evap(id, :) = vr%wbt_d%evap(id, :) + evap

                case ('Runoff', 'ROF')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%rof(iy, :) = vr%wbt_y%rof(iy, :)  + rof

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%rof(im, :) = vr%wbt_m%rof(im, :) + rof

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%rof(iss, :) = vr%wbt_s%rof(iss, :) + rof

                    if (ifo%var_out(i)%out_d) &
                        vr%wbt_d%rof(id, :) = vr%wbt_d%rof(id, :) + rof

                case ('DeltaStorage', 'DSTG')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%dstg(iy, :) = vr%wbt_y%dstg(iy, :) + dstg

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%dstg(im, :) =  vr%wbt_m%dstg(im, :) + dstg

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%dstg(iss, :) = vr%wbt_s%dstg(iss, :) + dstg

                    if (ifo%var_out(i)%out_d) &
                        vr%wbt_d%dstg(id, :) = vr%wbt_d%dstg(id, :) + dstg

                case ('TempSoil', 'Temperature_soil_layers', 'TBAR')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%spt_y%tbar(iy, :, :) = vr%spt_y%tbar(iy, :, :) + tbar

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%spt_m%tbar(im, :, :) = vr%spt_m%tbar(im, :, :) + tbar

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%spt_s%tbar(iss, :, :) = vr%spt_s%tbar(iss, :, :) + tbar

                case ('LQWS')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%lqws(iy, :, :) = vr%wbt_y%lqws(iy, :, :) + lqws

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%lqws(im, :, :) = vr%wbt_m%lqws(im, :, :) + lqws

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%lqws(iss, :, :) = vr%wbt_s%lqws(iss, :, :) + lqws

                case ('FRWS')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%frws(iy, :, :) = vr%wbt_y%frws(iy, :, :) + frws

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%frws(im, :, :) = vr%wbt_m%frws(im, :, :) + frws

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%frws(iss, :, :) = vr%wbt_s%frws(iss, :, :) + frws

                case ('RCAN')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%rcan(iy, :) = vr%wbt_y%rcan(iy, :) + rcan

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%rcan(im, :) = vr%wbt_m%rcan(im, :) + rcan

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%rcan(iss, :) = vr%wbt_s%rcan(iss, :) + rcan

                case ('SCAN', 'SNCAN')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%sncan(iy, :) = vr%wbt_y%sncan(iy, :) + sncan

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%sncan(im, :) = vr%wbt_m%sncan(im, :) + sncan

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%sncan(iss, :) = vr%wbt_s%sncan(iss, :) + sncan

                case ('PNDW')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%pndw(iy, :) = vr%wbt_y%pndw(iy, :) + pndw

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%pndw(im, :) = vr%wbt_m%pndw(im, :) + pndw

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%pndw(iss, :) = vr%wbt_s%pndw(iss, :) + pndw

                case ('SNO')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%sno(iy, :) = vr%wbt_y%sno(iy, :) + sno

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%sno(im, :) = vr%wbt_m%sno(im, :) + sno

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%sno(iss, :) = vr%wbt_s%sno(iss, :) + sno

                case ('WSNO')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        vr%wbt_y%wsno(iy, :) = vr%wbt_y%wsno(iy, :) + wsno

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        vr%wbt_m%wsno(im, :) = vr%wbt_m%wsno(im, :) + wsno

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        vr%wbt_s%wsno(iss, :) = vr%wbt_s%wsno(iss, :) + wsno

!                case default
!                    print *, "Output of variable '" // trim(adjustl(vId)) // "' is not Implemented yet."

            end select
        end do ! i = 1, ifo%nr_out

    end subroutine UpdateFIELDSOUT

    subroutine Write_Outputs(vr, ts, ifo, bi)

        !>------------------------------------------------------------------------------
        !>  Description: Loop over the variablaes to write
        !>  output balance's fields in selected format
        !>------------------------------------------------------------------------------

        !Inputs
        type(out_flds) :: vr
        type(info_out) :: ifo
        type(dates_model) :: ts
        type(basin_info) :: bi

        !Outputs
        !Files

        !Internals
        integer :: i, j
        character*50 :: vId
        character*3 :: freq

        do i = 1, ifo%nr_out

!            vId = trim(adjustl(ifo%ids_var_out(i, 1)))
            vId = trim(adjustl(ifo%var_out(i)%name))

            select case (vId)

                case ("FSDOWN")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fsdown, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882101, .false.)
                    end if

                case ("FSVH")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fsvh, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882102, .false.)
                    end if

                case ("FSIH")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fsih, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882103, .false.)
                    end if

                case ("FDL")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%fdl, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882104, .false.)
                    end if

                case ("UL")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%ul, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882105, .false.)
                    end if

                case ("TA")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%ta, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882106, .false.)
                    end if

                case ("QA")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%qa, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882107, .false.)
                    end if

                case ("PRES")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%pres, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882108, .false.)
                    end if

                case ("PRE")
                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%mdt_h%pre, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882109, .false.)
                    end if

                case ('PREC', 'Rainfall', 'Rain', 'Precipitation')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_d) &
                        call WriteFields_i(vr, ts, ifo, i, 'D', bi%na, ts%nr_days)

                case ('EVAP', 'Evapotranspiration')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_d) &
                        call WriteFields_i(vr, ts, ifo, i, 'D', bi%na, ts%nr_days)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%evap, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882110, .false.)
                    end if

                case ('Runoff', 'ROF')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_d) &
                        call WriteFields_i(vr, ts, ifo, i, 'D', bi%na, ts%nr_days)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%rof, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882111, .false.)
                    end if

                case ('DeltaStorage', 'DSTG')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_d) &
                        call WriteFields_i(vr, ts, ifo, i, 'D', bi%na, ts%nr_days)

                case ('TempSoil', 'Temperature_soil_layers', 'TBAR')

                    if (ifo%var_out(i)%out_y) then!trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_m) then!trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_s) then!trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason, j)
                        end do
                    end if

                case ('LQWS')

                    if (ifo%var_out(i)%out_y) then!trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_m) then!trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_s) then!trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        do j = 1, bi%ignd
                            call check_write_var_out(ifo, i, vr%wbt_h%lqws(:, :, j), freq, public_ic%now_hour - 1, &
                                public_ic%now_hour, (882112 + (100000000*j)), .false., j)
                        end do
                    end if

                case ('FRWS')

                    if (ifo%var_out(i)%out_y) then!trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'Y',bi%na, ts%nyears, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_m) then!trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_s) then!trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') then
                        do j = 1, bi%ignd
                            call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason, j)
                        end do
                    end if

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        do j = 1, bi%ignd
                            call check_write_var_out(ifo, i, vr%wbt_h%frws(:, :, j), freq, public_ic%now_hour - 1, &
                                public_ic%now_hour, (882113 + (100000000*j)), .false., j)
                        end do
                    end if

                case ('RCAN')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%rcan, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882114, .false.)
                    end if

                case ('SCAN', 'SNCAN')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%sncan, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882115, .false.)
                    end if

                case ('PNDW')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%pndw, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882116, .false.)
                    end if

                case ('SNO')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%sno, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882117, .false.)
                    end if

                case ('WSNO')

                    if (ifo%var_out(i)%out_y) & !trim(adjustl(ifo%ids_var_out(i, 2))) == 'Y') &
                        call WriteFields_i(vr, ts, ifo, i, 'Y', bi%na, ts%nyears)

                    if (ifo%var_out(i)%out_m) & !trim(adjustl(ifo%ids_var_out(i, 3))) == 'M') &
                        call WriteFields_i(vr, ts, ifo, i, 'M', bi%na, ts%nmonths)

                    if (ifo%var_out(i)%out_s) & !trim(adjustl(ifo%ids_var_out(i, 4))) == 'S') &
                        call WriteFields_i(vr, ts, ifo, i, 'S', bi%na, ts%nseason)

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%wsno, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882118, .false.)
                    end if

                case ('STG')

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wbt_h%stg, freq, public_ic%now_hour - 1, public_ic%now_hour, &
                            882119, .false.)
                    end if

                case ('WR_RUNOFF')

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wroutt_h%rof, freq, public_ic%now_hour - 1, &
                            public_ic%now_hour, 882120, .false.)
                    end if

                case ('WR_RECHARGE')

                    if (ifo%var_out(i)%out_h) then
                        freq = "H"
                        call check_write_var_out(ifo, i, vr%wroutt_h%rchg, freq, public_ic%now_hour - 1, &
                            public_ic%now_hour, 882121, .false.)
                    end if

!                case default
!                    print *, "Output of variable '" // trim(adjustl(vId)) // "' is not Implemented yet."

                end select
            end do ! i = 1, ifo%nr_out

    end subroutine Write_Outputs

    !>******************************************************************************

    subroutine WriteFields_i(vr, ts, ifo, indx, freq, na, nt, igndx)

        !>------------------------------------------------------------------------------
        !>  Description: Loop over the variables to write
        !>  output balance's fields in selected format
        !>------------------------------------------------------------------------------

        !Inputs
        type(out_flds), intent(in) :: vr
        type(dates_model), intent(in) :: ts
        type(info_out), intent(in) :: ifo
        integer, intent(in) :: indx
        character*1, intent(in) :: freq
        integer, intent(in) :: na, nt
        integer, intent(in), optional :: igndx

        !Internals
        integer :: i, nr
        character*50 :: vId, tfunc
        integer, dimension(:), allocatable :: days
        character*3 :: freq2
        character*1 :: st
        real :: fld(na, nt)

        integer, dimension(:, :), allocatable :: dates

!        vId = trim(adjustl(ifo%ids_var_out(indx, 6)))
        vId = trim(adjustl(ifo%var_out(indx)%out_fmt))
!        tfunc = trim(adjustl(ifo%ids_var_out(indx, 5)))
        tfunc = trim(adjustl(ifo%var_out(indx)%out_acc))

        select case (trim(adjustl(ifo%var_out(indx)%name)))

            case ('PREC', 'Rainfall', 'Rain', 'Precipitation')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%pre(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%pre(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%pre(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'D') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_d%pre(i, :)
                    end do
                end if

            case ('EVAP', 'Evapotranspiration')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%evap(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%evap(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%evap(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'D') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_d%evap(i, :)
                    end do
                end if

            case ('Runoff', 'ROF')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%rof(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%rof(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%rof(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'D') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_d%rof(i, :)
                    end do
                end if

            case ('DeltaStorage', 'DSTG')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%dstg(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%dstg(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%dstg(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'D') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_d%dstg(i, :)
                    end do
                end if

            case ('TempSoil', 'Temperature_soil_layers', 'TBAR')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%spt_y%tbar(i, :, igndx)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%spt_m%tbar(i, :, igndx)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%spt_s%tbar(i, :, igndx)
                    end do
                end if

            case ('LQWS')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%lqws(i, :, igndx)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%lqws(i, :, igndx)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%lqws(i, :, igndx)
                    end do
                end if

            case ('FRWS')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%frws(i, :, igndx)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%frws(i, :, igndx)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%frws(i, :, igndx)
                    end do
                end if

            case ('RCAN')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%rcan(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%rcan(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%rcan(i, :)
                    end do
                end if

            case ('SCAN', 'SNCAN')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%sncan(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%sncan(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%sncan(i, :)
                    end do
                end if

            case ('PNDW')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%pndw(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%pndw(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%pndw(i, :)
                    end do
                end if

            case ('SNO')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%sno(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%sno(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%sno(i, :)
                    end do
                end if

            case ('WSNO')

                if (trim(adjustl(freq)) == 'Y') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_y%wsno(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'M') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_m%wsno(i, :)
                    end do
                end if

                if (trim(adjustl(freq)) == 'S') then
                    do i = 1, nt
                        fld(:, i) = vr%wbt_s%wsno(i, :)
                    end do
                end if

            case ('ZPND')
                print *, "Output of variable '" // trim(adjustl(ifo%var_out(indx)%name)) // &
                    "' is not Implemented yet."
                print *, "Use PNDW for ponded water at the surface [mm]."

            case ('ROFF')
                print *, "Output of variable 'ROF' using keyword '" // &
                    trim(adjustl(ifo%var_out(indx)%name)) // "' is not supported."
                print *, "Use ROF for total runoff."

            case ('THIC', 'ICEContent_soil_layers')
                print *, "Output of variable '" // trim(adjustl(ifo%var_out(indx)%name)) // &
                    "' is not Implemented yet."
                print *, "Use LQWS for liquid water stored in the soil [mm]."

            case ('THLQ', 'LiquidContent_soil_layers')
                print *, "Output of variable '" // trim(adjustl(ifo%var_out(indx)%name)) // &
                    "' is not Implemented yet."
                print *, "Use FRWS for frozen water stored in the soil [mm]."

            case default
                print *, "Output of variable '" // trim(adjustl(ifo%var_out(indx)%name)) // &
                    "' is not Implemented yet."

        end select !case (trim(adjustl(vars)))

        if (tfunc == 'AVG') then

            allocate(days(nt))

            select case (freq)

                case ('Y')
                    days = ts%daysINyears

                case ('M')
                    days = ts%daysINmonths

                case ('S')
                    days = ts%daysINseasons

                case default
                    days = 1

            end select !freq

            do i = 1, nt
                fld(:, i) = fld(:, i)/days(i)
            end do

            deallocate(days)

        end if

        select case (freq)

            case ('Y')
                allocate(dates(ts%nyears, 2))
                dates(:, 1) = ts%years
                dates(:, 2) = 1

            case ('M')
                allocate(dates(ts%nmonths, 2))
                dates = ts%mnthyears

            case ('S')
                allocate(dates(ts%nseason, 2))
                do i = 1, 12
                    dates(i, 1) = ts%years(1)
                    dates(i, 2) = i
                end do

            case ("D")
!                allocate(dates(ts%nr_days, 3))
!                do i = 1, ts%nr_days*24, 24
!                    dates(i/24, 1) = ts%dates(i, 1)
!                    dates(i/24, 2) = ts%dates(i, 2)
!                    dates(i/24, 3) = ts%dates(i, 3)
!                end do

            case ("H")
!                allocate(dates(1, 5))
!                dates(1, 1) = public_ic%now_year
!                dates(1, 2) = public_ic%now_month
!                dates(1, 3) = public_ic%now_day
!                dates(1, 4) = public_ic%now_day_julian
!                dates(1, 5) = public_ic%now_hour

        end select !freq

        if (present(igndx)) then
            write(unit = st, fmt = '(I1)') igndx
            freq2 = freq // '_' // st
        else
            freq2 = freq
        end if

        select case (vId)

            case('seq', 'binseq')
                call WriteSeq(fld, indx, ifo, freq2, dates)

            case('r2c')
                call WriteR2C(fld, indx, ifo, freq2, dates)

            case default
                print *, "Output as file format '" // trim(adjustl(vId)) // "' is not implemented yet."

        end select

if (allocated(dates)) &
        deallocate(dates)

    end subroutine WriteFields_i

    !>******************************************************************************

    !>******************************************************************************

    subroutine WriteSeq(fld, indx, info, freq, dates)

        !>------------------------------------------------------------------------------
        !>  Description: Write bin sequential file
        !>
        !>------------------------------------------------------------------------------

        !Inputs
        real :: fld(:, :)
        integer :: indx
        character*3 :: freq
        integer :: dates(:, :)
        type(info_out) :: info

        !Internal
        character*450 :: flOut
        integer :: ios, i
        integer :: na, nt

        flOut = trim(adjustl(info%pthOut)) // &
!                trim(adjustl(info%ids_var_out(indx, 1))) // &
                trim(adjustl(info%var_out(indx)%name)) // &
                '_' // trim(adjustl(freq)) // '.seq'

        open(unit = 882, &
             file = trim(adjustl(flOut)), &
             status = 'replace', &
             form = 'unformatted', &
             action = 'write', &
             access = 'sequential', &
             iostat = ios)

        nt = size(dates(:, 1))

        do i = 1, nt
            write(882) i
            write(882) fld(:, i)
        end do

        close(882)

    end subroutine WriteSeq

    !>******************************************************************************

    subroutine WriteR2C(fld, indx, info, freq, dates, file_unit, keep_file_open, frame_no)

        !>------------------------------------------------------------------------------
        !>  Description: Write r2c file
        !>
        !>------------------------------------------------------------------------------

        use area_watflood

        !Inputs
        real :: fld(:, :)
        integer :: indx
        type(info_out) :: info
        character*3 :: freq
        integer, allocatable :: dates(:, :)
        integer, optional :: file_unit
        logical, optional :: keep_file_open
        integer, optional :: frame_no

        !Internal
        character*450 :: flOut
        integer :: ios, i, un, nfr
        integer :: na1, nt, j, t, k
        real, dimension(:, :), allocatable :: data_aux
        character(10) :: ctime
        character(8) :: cday
        logical :: opened_status, close_file

        flOut = trim(adjustl(info%pthOut)) // &
!                trim(adjustl(info%ids_var_out(indx, 1))) // &
                trim(adjustl(info%var_out(indx)%name)) // &
                '_' // trim(adjustl(freq)) // '.r2c'

        if (present(file_unit)) then
            un = file_unit
        else
            un = 882
        end if

        inquire(unit = un, opened = opened_status)
        if (.not. opened_status) then

        open(unit = un, &
             file = trim(adjustl(flOut)), &
             status = 'replace', &
             form = 'formatted', &
             action = 'write', &
             iostat = ios)

        write(un, 3005) '########################################'
        write(un, 3005) ':FileType r2c  ASCII  EnSim 1.0         '
        write(un, 3005) '#                                       '
        write(un, 3005) '# DataType               2D Rect Cell   '
        write(un, 3005) '#                                       '
        write(un, 3005) ':Application               MeshOutput   '
        write(un, 3005) ':Version                 1.0.00         '
        write(un, 3020) ':WrittenBy          ', 'MESH_DRIVER                             '

        call date_and_time(cday, ctime)

        write(un, 3010) ':CreationDate       ', &
            cday(1:4), cday(5:6), cday(7:8), ctime(1:2), ctime(3:4)

        write(un, 3005) '#                                       '
        write(un, 3005) '#---------------------------------------'
        write(un, 3005) '#                                       '
        write(un, 3020) ':Name               ', info%var_out(indx)%name !info%ids_var_out(indx, 1)
        write(un, 3005) '#                                       '
        write(un, 3004) ':Projection         ', coordsys1

        if (coordsys1 == 'LATLONG   ') &
            write(un, 3004) ':Ellipsoid          ', datum1

        if (coordsys1 == 'UTM       ') then
            write(un, 3004) ':Ellipsoid          ', datum1
            write(un, 3004) ':Zone               ', zone1
        end if

        write(un, 3005) '#                                       '
        write(un, 3003) ':xOrigin            ', xorigin
        write(un, 3003) ':yOrigin            ', yorigin
        write(un, 3005) '#                                       '
        write(un, 3005) ':SourceFile            MESH_DRIVER      '
        write(un, 3005) '#                                       '

        write(un, 3020) ':AttributeName      ', info%var_out(indx)%name !info%ids_var_out(indx, 1)

        write(un, 3020) ':AttributeUnits     ', '' !info%ids_var_out(indx, 2)
        write(un, 3005) '#                                       '
        write(un, 3001) ':xCount             ', xCount
        write(un, 3001) ':yCount             ', ycount
        write(un, 3003) ':xDelta             ', xdelta
        write(un, 3003) ':yDelta             ', yDelta
        write(un, 3005) '#                                       '
        write(un, 3005) '#                                       '
        write(un, 3005) ':endHeader                              '

        end if !(.not. opened_status) then

        if (allocated(dates)) then

        nt = size(dates(:, 1))

        do t = 1, nt

            if (present(frame_no)) then
                nfr = frame_no
            else
                nfr = t
            end if

            if (size(dates, 2) == 5) then
                write(un, 9000) ':Frame', nfr, nfr, dates(t, 1), dates(t, 2), dates(t, 3), dates(t, 5), 0
            elseif (size(dates, 2) == 3) then
                write(un, 9000) ':Frame', nfr, nfr, dates(t, 1), dates(t, 2), dates(t, 3), 0, 0
            else
                write(un, 9000) ':Frame', nfr, nfr, dates(t, 1), dates(t, 2), 1, 0, 0
            end if

            allocate(data_aux(ycount, xcount))
            data_aux = 0.0

            do k = 1, na
                data_aux(yyy(k), xxx(k)) = fld(k, t)
            end do

            do j = 1, ycount
                write(un, '(*(e12.6,2x))') (data_aux(j, i), i = 1, xcount)
            end do

            write(un, '(a)') ':EndFrame'

            deallocate(data_aux)

        end do

        end if !(allocated(dates)) then

        if (present(keep_file_open)) then
            close_file = .not. keep_file_open
        else
            close_file = .true.
        end if

        if (close_file) &
            close(unit = un)

        3000 format(a10, i5)
        3001 format(a20, i16)
        3002 format(2a20)
        3003 format(a20, f16.7)
        3004 format(a20, a10, 2x, a10)
        3005 format(a40)
        3006 format(a3, a10)
        3007 format(a14, i5, a6, i5)
        3010 format(a20, a4, '-', a2, '-', a2, 2x, a2, ':', a2)
        3012 format(a9)
        3020 format(a20, a40)
        9000 format(a6, 2i10, 3x, '"', i4, '/', i2.2, '/', i2.2, 1x, i2.2, ':', i2.2, ':00.000"')

    end subroutine WriteR2C

end module model_output
