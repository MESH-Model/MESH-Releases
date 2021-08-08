module mesh_io_options

    implicit none

    !> Constants for file formats.
    !* FILE_TYPE_NUL: None (no file format applicable or not set).
    !* FILE_TYPE_R2C: EnSim Hydrologic/GreenKenue R2C file in ASCII format
    !*  (multi-attribute single framed or single attribute multi-frame).
    !* FILE_TYPE_R2C_BIN: EnSim Hydrologic/GreenKenue R2C file in binary format
    !*  (single attribute multi-frame).
    !* FILE_TYPE_TXT: Space-delimited plain text format.
    !* FILE_TYPE_ASC: Space-delimited plain text format (Rank-order).
    !* FILE_TYPE_CSV: Comma-delimited plain text format.
    !* FILE_TYPE_TSI: Space-delimited plain text format (Rank-subset).
    !* FILE_TYPE_TSK: Space-delimited plain text format (Tile-subset).
    !* FILE_TYPE_SEQ: Binary sequential format (no predefined structure).
    !* FILE_TYPE_NC4: NetCDF format.
    !* FILE_TYPE_MET: CLASS 'MET' format forcing file.
    integer, parameter :: FILE_TYPE_NUL = 0
    integer, parameter :: FILE_TYPE_R2C = 1
    integer, parameter :: FILE_TYPE_R2C_BIN = 2
    integer, parameter :: FILE_TYPE_TXT = 3
    integer, parameter :: FILE_TYPE_ASC = 4
    integer, parameter :: FILE_TYPE_CSV = 5
    integer, parameter :: FILE_TYPE_TSI = 6
    integer, parameter :: FILE_TYPE_TSK = 7
    integer, parameter :: FILE_TYPE_SEQ = 8
    integer, parameter :: FILE_TYPE_NC4 = 9
    integer, parameter :: FILE_TYPE_MET = 10

    !> Constants for field lengths.
    !* SHORT_FIELD_LENGTH: Default length for short fields.
    !* LONG_FIELD_LENGTH: Default length for long fields.
    integer, parameter :: SHORT_FIELD_LENGTH = 200
    integer, parameter :: LONG_FIELD_LENGTH = 2000

    !> Constants for field scale.
    !* DATA_TYPE_GRID: Grid-based (e.g., aggregated from 'tile').
    !* DATA_TYPE_TILE: Tile-based.
    integer, parameter :: DATA_TYPE_GRID = 1
    integer, parameter :: DATA_TYPE_TILE = 2

    !> Constants for binary flag states.
    !* FLAG_OFF: Disabled/inactive.
    !* FLAG_ON: Enabled/active.
    !* FLAG_AUTO: Automatic (e.g., if dependent on other flags disabled or enabled).
    integer, parameter :: FLAG_OFF = 0
    integer, parameter :: FLAG_ON = 1
    integer, parameter :: FLAG_AUTO = 2

    !> Constants for time frequencies of inputs and outputs.
    !* FREQ_NUL: None/no frequency applicable or not set.
    !* FREQ_YEARLY: Yearly, before the beginning of the next year.
    !* FREQ_MONTHLY: Monthly, before the beginning of the next month.
    !* FREQ_SEASONAL: Seasonal monthly output (monthly average across years).
    !* FREQ_DAILY: Daily, before the beginning of the next day.
    !* FREQ_HOURLY: Hourly, before the beginning of the next hour.
    !* FREQ_PTS: Per model time-step (model configuration dependent).
    !* FREQ_START: Only at the start of a simulation.
    !* FREQ_END: Only at the end of a simulation.
    !* FREQ_NOW: In the current time-step.
    !* FREQ_SECONDS: At the end of a pre-defined increment in seconds.
    !* FREQ_MINUTES: At the end of a pre-defined increment in minutes.
    !* FREQ_HOURS: At the end of a pre-defined increment in hours.
    !* FREQ_DAYS: At the end of a pre-defined increment in days.
    !* FREQ_IC: A pre-defined 'ic' counter date, where values matched are those greater than zero.
    integer, parameter :: FREQ_NUL = 0
    integer, parameter :: FREQ_YEARLY = 1
    integer, parameter :: FREQ_MONTHLY = 2
    integer, parameter :: FREQ_SEASONAL = 3
    integer, parameter :: FREQ_DAILY = 4
    integer, parameter :: FREQ_HOURLY = 5
    integer, parameter :: FREQ_PTS = 6
    integer, parameter :: FREQ_START = 7
    integer, parameter :: FREQ_END = 8
    integer, parameter :: FREQ_NOW = 9
    integer, parameter :: FREQ_SECONDS = 10
    integer, parameter :: FREQ_MINUTES = 11
    integer, parameter :: FREQ_HOURS = 12
    integer, parameter :: FREQ_DAYS = 13
    integer, parameter :: FREQ_IC = 14

end module
