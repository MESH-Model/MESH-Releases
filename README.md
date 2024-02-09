# MESH Releases

> [!CAUTION]
> This information is actively being updated. Please contact @dprincz if you require additional information.

## Overview

This page contains the official release of the MESH code.

Most MESH versions are identified by a string of three numbers: "MESH major.minor.release"

* The _major_ number is incremented when a significant change to the code or framework has occurred that breaks lineage with previous versions
* The _minor_ number is incremented when a significant change to the code has occurred, and the results and outputs from the new release may significantly differ from the results and outputs from the previous version (provided the same configuration)
* The _release_ number is incremented when a new version has been created to introduce new features and functionality, and/or when major bugs have been identified and corrected, that don't significantly impact the model results and outputs compared to the previous version

## Latest Versions

Latest versions are the most recent releases of MESH. Using the top-listed most recent version is recommended for most users. If possible, users are recommended to upgrade their code. If starting a new project, users are recommended to use only the most recent version of the code.

### MESH 1.4

MESH 1.4 is the current MESH series.

__[MESH 1.4.1860](https://github.com/MESH-Model/MESH-Dev/releases/tag/SA_MESH_1.4%2FSA_MESH_1.4.1860) (r1860)__

This release contains optimizations regarding how internal variables and fields are managed and stored, and related to the handling or inputs and outputs (I/O), as well as for improvements for more descriptive and consistent messaging and error handling throughout.

Other changes:
* Added support for the `scale_factor`, `add_offset`, `valid_max` and `valid_min` attributes for variables read from netCDF files.
* Reactivated the internal `LQWSSOL` and `FZWSSOL` variables to handle when tiles within a grid have different values for `DZWAT`/`DZSOLHYD`, as before.
* Activated `LQWSICE` to contribute to `STGW`, as well as the `TICE` variable. Added columns for the `LQWSICE` and `TICE` variables to the basin-average water and energy balance output files, respectively.
* Re-issued the use of `DRAINSOL` as only water from the bottom of the soil column and distinguished `RCHG` as the water that enters any active baseflow/aquifer and `LKG` as water that is released from lower zone storage to match documentation. The revised terms now match how 'wf_lzs' is described in the WATFLOOD manual. Total runoff no longer considers `DRAINSOL`; only `OVRFLW`, `SUBFLW` and `LKG`. The labels for these columns have been revised in the basin-average water balance output file.
* Added `pbsm_fraction_threshold` as an internal parameter to disable the redistribution of snow to tiles with a grid-fraction less than the specified value.

Bug-fixes:
* Bug-fixes to remove implicit allocations throughout.
* Bug-fix in 'WFILL' for the case when soil profiles are greater than 10.0 m in depth.
* Fixed an issue where mal-formed gridded domains that do not contain the minimum 2-by-2 dimension originally enforced by the EnSim/Green Kenue software would be interpreted as a vector-/subbasin-based domain, which would result in certain properties, such as the derivation of latitudes and longitudes from the EnSim grid specification, not being calculated.
* Bug-fix in PBSM to use the proper tile-fraction within a grid instead of the `FARE` parameter from 'MESH_parameters_CLASS.ini'.
* Added `Subl` from PBSM to the general `ET` parameter to account for the missing water balance term.
* Bug-fix where if the 'MESH_ggeo.ini' file is used, it might use a file unit already used by another open file.

Known issues or limitations:
* This version of the code will print "1858" to screen.
* This version contains in-progress optimizations for inputs and outputs (I/O) and is known to run slower than previous versions.
* Subl is added to ET using incorrect units .
