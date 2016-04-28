module climate_forcing_variabletypes

    use model_dates

    implicit none

    type clim_info_series

        integer nattr
        character(20) attrtype
        character(200), dimension(:), allocatable :: attr

    end type

!-    type clim_info_transform_series

        !* nattr: Number of attributes in the transform.
        !* attrtype: Type of transform.
        !* attr: Attributes (e.g., coefficients) of the transform [-].
        !* tfs: Array for work or for the transformed series.
!-        integer :: nattr = 0
!-        integer attrtype
!-        real, dimension(:), allocatable :: attr
!-        real, dimension(:, :), allocatable :: tfs

!-    end type

    type clim_series

        !* id_var: Climate variable name and ID.
        !* factive: Returns .true. if the variable is active.
        !* ffmt: Input file format.
        !* fname: Input file name.
        !* fpath: Full path to the forcing input file, including extension.
        !* fiun: Input file unit.
        !* fopen: Returns .true. if an input file for the variable has been opened.
        character(20) :: id_var
        logical :: factive = .false.
        integer :: ffmt = 0
        character(200) :: fname = ''
        character(200) :: fpath = ''
        integer fiun
        logical :: fopen = .false.

        !* GRD: Values for forcing data (Bounds: 1: Grid).
        !>      Values are averaged to the grid-level for grid-based
        !>      processing and certain output. These gridded values are
        !>      not used to drive the model, as they are not compatible
        !>      with data at the GRU- or GAT-level.
        !* GRU: Values for forcing data (Bounds: 1: GRU).
        !* GAT: Values for forcing data (Bounds: 1: Land Element).
        real, dimension(:), allocatable :: GRD
        real, dimension(:), allocatable :: GRU
        real, dimension(:), allocatable :: GAT

        !* nblocks: Number of frames of blocks of data to read into memory.
        !* blocktype: Type of data being stored (1 = GRD; 2 = GRU; 3 = GAT).
        !* blocks: Forcing data (Bounds: 1: Element; 2: nblocks).
        !* iblock: Index of the current block in data to memory [-].
        integer :: nblocks = 1
        integer :: blocktype = 1
        real, dimension(:, :), allocatable :: blocks
        integer :: iblock = 1

        !* start_date: Starting date of the data in the file.
        !* hf: Increment of minutes passed in each frame of data [mins].
        !* itimestep: Current time-step [mins].
        type(counter_date_julian) :: start_date
        integer :: hf = 30
        integer :: itimestep = 0

        !* ipflg: INTERPOLATIONFLAG (0: none, 1: active).
        !* ipwgt: Interpolation type (1: arithmetic mean; 2: harmonic mean).
        !* ipdat: Array to store the states of the forcing data [-] (Bounds: 1: Element; 2: interpolation/previous time-step state).
        integer :: ipflg = 0
        integer :: ipwgt = 1
        real, dimension(:, :), allocatable :: ipdat

        !* nseries: Number of series in the definition.
        !* series: Definitions for the series.
        integer :: nseries = 0
        type(clim_info_series), dimension(:), allocatable :: series

    end type

!-    type clim_info_read

!-        character(20) :: id_var
!-        integer :: filefmt = 0
!-        character(200), dimension(:), allocatable :: name
!-        integer unitR
!-        logical openFl

!-        integer :: timeSize = 1
!-        integer, dimension(:), allocatable :: ntimes
!-        integer :: readIndx = 1 !index in the block of time that we are reading
!-        integer :: itime = 1 !time index
!-        integer :: timestep_now = 0

!-        integer :: hf = 30 !hourly flag
!-        character freq !time freq of data

!-        integer :: nseries = 1

        !* climv: Values for forcing data. (1: Land Element (GAT); 2: Series; 3: Time-step).
        !> Values are stored at the GAT level, as it is the finest level of
        !> elemental computation in the model (e.g., with CLASS).
!-        real, dimension(:, :, :), allocatable :: climv

        !* GRD: Values for forcing data. (1: Grid)
        !> Values are averaged to the grid-level for grid-based processing and certain output.
        !> Gridded values aren't used to drive the model, as they are incompatible with
        !> data input at the GRU- (e.g., in one of the CSV formats) or GAT-level.
!-        real, dimension(:), allocatable :: GRD

        !* GAT: Values for forcing data. (1: Land Element)
!-        real, dimension(:), allocatable :: GAT

        !* alpha: Uniform weight to assign when there are multiple series of data. (1: Series).
!        real, dimension(:), allocatable :: alpha
!-        type(clim_info_series), dimension(:), allocatable :: series

!-    end type !clim_info_read

    type clim_info

        integer :: basefileunit = 89

!-        type(counter_date_julian) :: start_date

        !* nclim: Number of climate variables.
        !* dat: Climate variables.
        integer :: nclim = 7
        type(clim_series) :: dat(7)
!-        type(clim_info_read) :: clin(7)

    end type !clim_info

end module
