PR: Add phased per-blade +2° pitch mode (PITCH_MODE=3)

Overview

This branch implements a new pitch control mode in the solver: PITCH_MODE=3 assigns a phased per-blade fixed pitch offset such that adjacent blades have opposite sign (+FI0_BASE / -FI0_BASE). The default example sets FI0_BASE = +2° (in radians) and PITCH_MODE = 3 in main.f90 for easy testing.

Changes

- vdart_solver_mod.f90: added CASE 3 to the pitch selection logic to set per-blade phased offsets.
- main.f90: default test configuration updated to PITCH_MODE = 3 with FI0_BASE = 2°.
- tests/compare_three.py and results: included three-way comparison artifacts.
- tests/plot_torque_runs.py: script to visualize torque vs azimuth for baseline/offset/phased runs (added in this commit).

How to validate

1) Build Release|x64 in Visual Studio.
2) Copy the built exe to build\vdart_phased_offset.exe and run it in tests/phased_run as described in tests/README.md.
3) Run python tests/compare_three.py to regenerate combined CSV and summary.
4) Run python tests/plot_torque_runs.py to produce PNG plots under tests/results.

Reviewer notes

- The phased pattern is simple alternating sign per blade; other phasing patterns can be implemented similarly.
- The implementation is conservative and does not alter other modes.

Requested reviewers: @USP-cad-hobby
