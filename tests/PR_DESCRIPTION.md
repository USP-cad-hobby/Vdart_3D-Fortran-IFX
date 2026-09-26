PR: Add baseline vs offset combined comparison and helpers

Overview

This branch contains tooling and saved artifacts to compare a baseline run vs an offset (+2°) run for the VDaRT solver. The intent is to make it easy to reproduce the comparison locally and to provide a concise per-azimuth delta table for inspection.

Summary of changes

- tests/compare_side_by_side.py  : script that aggregates per-run compare_summary.txt into a combined summary and produces a per-azimuth CSV delta.
- tests/results/combined_comparison.txt : human-readable combined summary (baseline vs offset).
- tests/results/combined_torque_delta.csv : per-azimuth torque delta CSV (azimuth_deg, baseline, offset, delta, delta_pct).
- tests/README.md : instructions to reproduce the runs and generate the artifacts.

How to validate locally

1) Build the project (Release|x64) in Visual Studio so the Intel Fortran toolchain creates the executable under x64\Release.
2) Prepare run folders and copy executables to build\vdart_baseline.exe and build\vdart_offset.exe as described in tests/README.md.
3) Run each executable inside its own folder and capture console output and torque_vs_azimuth.dat:
   - tests/baseline_run/output_run.txt and torque_vs_azimuth.dat
   - tests/offset_run/output_run.txt and torque_vs_azimuth.dat
4) Run the comparator(s):
   - python tools/compare_baseline.py   # run inside each run folder to create compare_summary.txt
   - python tests/compare_side_by_side.py  # creates tests/results/combined_comparison.txt and combined_torque_delta.csv
5) Inspect tests/results/* for the combined report and per-azimuth deltas.

Checklist for PR review

- [ ] Code: tests/compare_side_by_side.py reviewed for parsing correctness and encoding handling.
- [ ] Documentation: tests/README.md provides reproducible commands and notes.
- [ ] Artifacts: tests/results/* are small CSV/TXT files and acceptable to include for review.
- [ ] No large binaries committed (verify .gitignore excludes build artifacts and .exe/.mod files).
- [ ] Confirm the baseline and offset runs were produced with the same build configuration (Release|x64) and same solver settings except FI0_BASE.

Notes

- This PR stores small text artifacts and the helper script only. It does not include any large binaries.
- If you prefer, I can open a draft PR on GitHub and copy this description into the PR body.

Requested reviewers: @USP-cad-hobby

