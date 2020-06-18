subroutine READ_PARAMETERS_CLASS(shd, fls, cm, ierr)

    !> Required for file object and CLASS.ini file index.
    use model_files_variables

    !> For the 'ShedGridParams' type and SA_MESH parameters.
    use sa_mesh_common

    !> Required for 'NRSOILAYEREADFLAG'.
    use FLAGS

    use RUNCLASS36_constants
    use RUNCLASS36_variables

    !> Used for starting date of climate forcing data.
    use climate_forcing

    implicit none

    !> Input variables.
    type(ShedGridParams) :: shd
    type(fl_ids) :: fls
    type(clim_info) :: cm

    !> Output variables.
    integer, intent(out) :: ierr

    !> Local variables.
    integer NA, NTYPE, NSL, iun, k, ignd, i, m, j
    character(len = DEFAULT_LINE_LENGTH) line

    !> Local variables (read from file).
    real DEGLAT, DEGLON
    integer JOUT1, JOUT2, JAV1, JAV2, KOUT1, KOUT2, KAV1, KAV2

    !> Initialize the return status.
    ierr = 0

    !> Open the file.
    call reset_tab()
    call print_message('READING: ' // trim(fls%fl(mfk%f50)%fn))
    call increase_tab()
    iun = fls%fl(mfk%f50)%iun
    open(iun, file = fls%fl(mfk%f50)%fn, status = 'old', action = 'read', iostat = ierr)
    if (ierr /= 0) then
        call print_error('Unable to open the file. Check if the file exists.')
        return
    end if

    NA = shd%NA
    NTYPE = shd%lc%NTYPE
    NSL = shd%lc%IGND

    !> Read constants from file.
    read(iun, '(2x, 6a4)', err = 98) TITLE1, TITLE2, TITLE3, TITLE4, TITLE5, TITLE6
    read(iun, '(2x, 6a4)', err = 98) NAME1, NAME2, NAME3, NAME4, NAME5, NAME6
    read(iun, '(2x, 6a4)', err = 98) PLACE1, PLACE2, PLACE3, PLACE4, PLACE5, PLACE6
    read(iun, *, err = 98) &
        DEGLAT, DEGLON, pm%gru%zrfm(1), pm%gru%zrfh(1), pm%gru%zbld(1), pm%gru%gc(1), shd%wc%ILG, i, m

    !> Check that the number of GRUs matches the drainage database value.
    if (NTYPE /= m .and. NTYPE > 0) then
        call print_error('The number of GRUs does not match the drainage database.')
        write(line, FMT_GEN) NTYPE
        call print_message('Drainage database: ' // trim(adjustl(line)))
        write(line, FMT_GEN) m
        call print_message(trim(adjustl(fls%fl(mfk%f50)%fn)) // ': ' // trim(adjustl(line)))
        ierr = 1
        close(iun)
    end if

    !> Check that the number of grid cells matches the drainage database value.
    if (i /= NA) then
        call print_error('The number of grid cells does not match the drainage database.')
        write(line, FMT_GEN) NA
        call print_message('Drainage database: ' // trim(adjustl(line)))
        write(line, FMT_GEN) i
        call print_message(trim(adjustl(fls%fl(mfk%f50)%fn)) // ': ' // trim(adjustl(line)))
        ierr = 1
        close(iun)
    end if

    !> Return if an error has occurred.
    if (ierr /= 0) return

    JLAT = nint(DEGLAT)

    !> Determine the number of layers for soil parameters to read from file.
    if (NRSOILAYEREADFLAG > 3) then
        ignd = min(NRSOILAYEREADFLAG, NSL)
    else if (NRSOILAYEREADFLAG == 1) then
        ignd = NSL
    else
        ignd = 3
    end if

    !> Populate temporary variables from file.
    do m = 1, NTYPE
        read(iun, *, err = 98) (pm%gru%fcan(m, j), j = 1, ICP1), (pm%gru%lamx(m, j), j = 1, ICAN)
        read(iun, *, err = 98) (pm%gru%lnz0(m, j), j = 1, ICP1), (pm%gru%lamn(m, j), j = 1, ICAN)
        read(iun, *, err = 98) (pm%gru%alvc(m, j), j = 1, ICP1), (pm%gru%cmas(m, j), j = 1, ICAN)
        read(iun, *, err = 98) (pm%gru%alic(m, j), j = 1, ICP1), (pm%gru%root(m, j), j = 1, ICAN)
        read(iun, *, err = 98) (pm%gru%rsmn(m, j), j = 1, ICAN), (pm%gru%qa50(m, j), j = 1, ICAN)
        read(iun, *, err = 98) (pm%gru%vpda(m, j), j = 1, ICAN), (pm%gru%vpdb(m, j), j = 1, ICAN)
        read(iun, *, err = 98) (pm%gru%psga(m, j), j = 1, ICAN), (pm%gru%psgb(m, j), j = 1, ICAN)
        read(iun, *, err = 98) pm%gru%drn(m), pm%gru%sdep(m), pm%gru%fare(m), pm%gru%dd(m)
        read(iun, *, err = 98) pm%gru%xslp(m), pm%gru%grkf(m), pm%gru%mann(m), pm%gru%ks(m), pm%gru%mid(m)
        read(iun, *, err = 98) (pm%gru%sand(m, j), j = 1, ignd)
        read(iun, *, err = 98) (pm%gru%clay(m, j), j = 1, ignd)
        read(iun, *, err = 98) (pm%gru%orgm(m, j), j = 1, ignd)
        read(iun, *, err = 98) &
            (vs%gru%tbar(m, j), j = 1, ignd), vs%gru%tcan(m), vs%gru%tsno(m), vs%gru%tpnd(m)
        read(iun, *, err = 98) (vs%gru%thlq(m, j), j = 1, ignd), (vs%gru%thic(m, j), j = 1, ignd), vs%gru%zpnd(m)
        read(iun, *, err = 98) &
            vs%gru%rcan(m), vs%gru%sncan(m), vs%gru%sno(m), vs%gru%albs(m), &
            vs%gru%rhos(m), vs%gru%gro(m)
    end do

!todo: Make sure these variables are documented properly (for CLASS output, not currently used)
    read(iun, *, err = 98) JOUT1, JOUT2, JAV1, JAV2
    read(iun, *, err = 98) KOUT1, KOUT2, KAV1, KAV2

    !> Read in the starting date of the forcing files.
    read(iun, *, err = 98) cm%start_date%hour, cm%start_date%mins, cm%start_date%jday, cm%start_date%year

    !> Close the file.
    close(iun)

    !> Assign DEGLAT and DEGLON if running a point run where no shed file exists.
    if (SHDFILEFMT == 2) then
        shd%ylat = DEGLAT
        shd%xlng = DEGLON
    end if

    return

98  ierr = 1
    call print_error('Unable to read the file.')
    close(iun)
    return

end subroutine
