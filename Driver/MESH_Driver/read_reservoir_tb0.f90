!>
!> Description:
!>  Subroutine to read reservoir outlet information from
!>  MESH_input_reservoir.tb0.
!>
!> Input:
!*  shd: Basin shed object, containing information about the grid
!*      definition read from MESH_drainage_database.r2c.
!*  iun: Unit of the input file (default: 100).
!*  fname: Full path to the file (default: 'MESH_input_reservoir.tb0').
!>
subroutine read_reservoir_tb0(shd, iun, fname)

    use strings
    use mpi_module
    use model_dates
    use sa_mesh_variables
    use sa_mesh_utilities
    use ensim_io

    implicit none

    !> Input variables.
    type(ShedGridParams) :: shd
    integer, intent(in) :: iun
    character(len = *), intent(in) :: fname

    !> Local variables.
    type(ensim_keyword), dimension(:), allocatable :: vkeyword
    integer nkeyword, ierr

    !> Open the file and read the header.
    call print_screen('READING: ' // trim(adjustl(fname)))
    call print_echo_txt(fname)
    call open_ensim_file(iun, fname, ierr)
    if (ierr /= 0) then
        call print_error('Unable to open file. Check if the file exists.')
        call stop_program()
    end if
    call parse_header_ensim(iun, fname, vkeyword, nkeyword, ierr)

    !> Get the number of outlet locations (i.e., columns) from the file.
    call count_columns_tb0(iun, fname, vkeyword, nkeyword, fms%rsvr%n, ierr)

    !> Return if no outlets are defined.
    if (fms%rsvr%n == 0) return

    !> Allocate attributes for the driver.
    call allocate_reservoir_outlet_location(fms%rsvr, fms%rsvr%n, ierr)
    if (ierr /= 0) goto 998

    !> Get the time-step of the records.
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':DeltaT', fms%rsvr%rlsmeas%dts, ierr, VERBOSEMODE)

    !> Populate other attributes.
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':ColumnName', fms%rsvr%meta%name, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':ColumnLocationY', fms%rsvr%meta%y, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':ColumnLocationX', fms%rsvr%meta%x, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff1', fms%rsvr%rls%b1, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff2', fms%rsvr%rls%b2, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff3', fms%rsvr%rls%b3, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff4', fms%rsvr%rls%b4, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff5', fms%rsvr%rls%b5, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':ReachArea', fms%rsvr%rls%area, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff6', fms%rsvr%rls%b6, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':Coeff7', fms%rsvr%rls%b7, fms%rsvr%n, ierr, VERBOSEMODE)
    call get_keyword_value(iun, fname, vkeyword, nkeyword, ':InitLvl', fms%rsvr%rls%zlvl0, fms%rsvr%n, ierr, VERBOSEMODE)

    !> Replace 'area' with 'b6' if available.
    if (any(fms%rsvr%rls%b6 > 0.0)) fms%rsvr%rls%area = fms%rsvr%rls%b6

    !> Get the start time of the first record in the file.
    call parse_starttime( &
        iun, fname, vkeyword, nkeyword, &
        fms%rsvr%rlsmeas%iyear, fms%rsvr%rlsmeas%imonth, fms%rsvr%rlsmeas%iday, fms%rsvr%rlsmeas%ihour, fms%rsvr%rlsmeas%imins, &
        ierr, VERBOSEMODE)
    if (fms%rsvr%rlsmeas%iyear > 0 .and. fms%rsvr%rlsmeas%imonth > 0 .and. fms%rsvr%rlsmeas%iday > 0) then
        fms%rsvr%rlsmeas%ijday = get_jday(fms%rsvr%rlsmeas%imonth, fms%rsvr%rlsmeas%iday, fms%rsvr%rlsmeas%iyear)
    end if

    !> Position the file to the first record.
    call advance_past_header(iun, fname, VERBOSEMODE, ierr)

    return

    !> Stop: Error allocating variables.
998 call print_error('Unable to allocate variables.')
    call stop_program()

end subroutine
