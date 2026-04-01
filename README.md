# VDaRT 3D Fortran Modular (IFX)

**Darrieus Vertical Axis Wind Turbine - 3D Vortex Method Simulation**

- **Author:** U.S. Paulsen
- **License:** MIT (SPDX-License-Identifier: MIT)
- **Repository:** https://github.com/USP-cad-hobby/Vdart_3D-Fortran-IFX

---

## Project Overview

VDaRT (Vortex Darrieus Rotor Tool) is a 3D aerodynamic simulation for vertical-axis wind turbines using the vortex lattice method. This modular Fortran version is compiled with Intel Fortran (IFX) in Visual Studio.

### Test Case: 100m Straight-Blade Rotor
| Parameter | Value |
|-----------|-------|
| Rotor height (H0) | 100.0 m |
| Number of blades | 3 |
| Blade sections (NOL) | 24 |
| Chord length | 2.7 m |
| Wind speed (UINF) | 10.0 m/s |
| Rotation speed | 7.8 RPM |
| Azimuthal step | 5.0° |

---

## Project Structure

```
Vdart3D_Fortran_mod/
├── main.f90                 # Main demo program
├── test_vortex.f90          # Vortex module test (excluded from build)
├── vdart_kinds_mod.f90      # Kind parameters (dp = double precision)
├── vdart_state_mod.f90      # Global state arrays and allocation
├── vdart_blad_mod.f90       # Blade geometry generation
├── vdart_solver_mod.f90     # Time-stepping solver
├── vdart_aero_mod.f90       # Aerodynamic calculations
├── vdart_biot_mod.f90       # Biot-Savart law implementation
├── vdart_vortex_mod.f90     # Vortex element routines
├── vdart_forces_mod.f90     # Force calculations
├── vdart_bsa_mod.f90        # Bound surface area
├── vdart_nethas_mod.f90     # Net hash/mesh routines
├── vdart_flyt_mod.f90       # Flight/flow routines
├── vdart_start_mod.f90      # Startup initialization
├── vdart_wind_mod.f90       # Wind field definitions
├── vdart_io_mod.f90         # Input/output routines
├── Vdart3D_Fortran_mod.vfproj  # Intel Fortran project file
├── Vdart3D_Fortran_mod.slnx    # Visual Studio solution
├── Compile.bat              # Batch compile script
├── .gitignore               # Git ignore rules
└── README.md                # This file
```

---

## Build Instructions

### Prerequisites
- **Visual Studio 2022/2026** with Intel Fortran compiler (IFX)
- **Intel oneAPI HPC Toolkit** (for `ifx` compiler)

### Building in Visual Studio

1. **Open the project:**
   - File → Open → Project/Solution
   - Select `Vdart3D_Fortran_mod.vfproj`

2. **Select configuration:**
   - Configuration: `Debug` or `Release`
   - Platform: `x64` (recommended)

3. **Build:**
   - Press `Ctrl+Shift+B` or Build → Build Solution

4. **Run:**
   - Press `F5` (with debugger) or `Ctrl+F5` (without debugger)

### Build Configurations

| Configuration | Platform | Compiler | Use Case |
|--------------|----------|----------|----------|
| Debug x64 | x64 | ifx | Development (bounds checking, debug symbols) |
| Release x64 | x64 | ifx | Production (optimized) |
| Debug Win32 | x86 | ifort | Legacy 32-bit |
| Release Win32 | x86 | ifort | Legacy 32-bit optimized |

### Note on Multiple Programs
The project contains two files with `program` statements:
- `main.f90` → `program vdart_demo` (main entry point)
- `test_vortex.f90` → `program test_vortex` (unit test)

**Only one can be included in a build.** To switch:
1. Right-click the file in Solution Explorer
2. Properties → Excluded From Build → Yes/No

---

## Git Workflow (Visual Studio GUI)

### Initial Setup (Already Complete)
```
Repository: https://github.com/USP-cad-hobby/Vdart_3D-Fortran-IFX.git
Branch: master
```

### Daily Workflow

#### 1. Open Git Changes Panel
- Menu: **View → Git Changes**
- Shortcut: **Ctrl+Alt+G**

#### 2. Stage Files
The Git Changes panel shows:
```
┌─────────────────────────────────┐
│ [Enter commit message]          │
├─────────────────────────────────┤
│ Changes (n)              [+]    │  ← Click [+] to Stage All
│   📄 modified_file.f90   [+]    │  ← Click [+] to stage one
├─────────────────────────────────┤
│ Staged (n)               [-]    │
│   📄 staged_file.f90     [-]    │  ← Click [-] to unstage
├─────────────────────────────────┤
│ [Commit Staged] [Commit All]    │
└─────────────────────────────────┘
```

#### 3. Commit
1. Type a descriptive message (e.g., "Fix convergence tolerance")
2. Click **Commit All** (or **Commit Staged**)

#### 4. Push to GitHub
- Click the **↑ Push** button (up arrow)
- Or menu: **Git → Push**

#### 5. Pull from GitHub
- Click the **↓ Pull** button (down arrow)
- Or menu: **Git → Pull**

### Git Menu Reference

| Action | Menu | Shortcut | Description |
|--------|------|----------|-------------|
| Commit | Git → Commit or Stash | Ctrl+Alt+F7 | Save changes locally |
| Push | Git → Push | — | Upload to GitHub |
| Pull | Git → Pull | — | Download from GitHub |
| Sync | Git → Sync | — | Pull + Push |
| View History | Git → View Branch History | — | See commit log |

---

## Pitch Control Modes

The solver supports two pitch control modes set in `main.f90`:

### Mode 1: Harmonic Pitching
```fortran
PITCH_MODE = 1
FI0_BASE = 0.0_dp      ! Baseline pitch (radians)
FI0_AMP = 5.0*pi/180   ! Amplitude (radians)
FI0DOT = omega         ! Frequency (rad/s)
```
- All blades pitch identically: `FI0(t) = FI0_BASE + FI0_AMP * sin(FI0DOT*t)`
- Use for: Frequency response, flutter analysis

### Mode 2: Cyclic Pitching
```fortran
PITCH_MODE = 2
FI0_BASE = 0.0_dp      ! Baseline pitch
FI0_AMP = 5.0*pi/180   ! Downwind offset
```
- Blade-specific pitch based on azimuth position
- Downwind (90°<θ<270°): Increased pitch
- Upwind: Baseline pitch
- Use for: Torque ripple reduction, performance enhancement

---

## Files Ignored by Git

The `.gitignore` excludes:
- Build artifacts: `*.obj`, `*.mod`, `*.exe`, `*.pdb`
- Output directories: `x64/`, `Debug/`, `Release/`
- Visual Studio files: `.vs/`, `*.suo`, `*.user`
- Intel Fortran specifics: `*.dyn`, `*.dpi`, `*.lock`

---

## Troubleshooting

### Link Error: MAIN__ already defined
**Cause:** Both `main.f90` and `test_vortex.f90` have `program` statements.  
**Fix:** Exclude one file from build (right-click → Properties → Excluded From Build → Yes)

### Git not recognized
**Cause:** Git not in PATH for PowerShell.  
**Fix:** Use full path: `& "C:\Program Files\Git\bin\git.exe" <command>`

### Build fails with missing modules
**Cause:** Compilation order issue.  
**Fix:** Rebuild All (Build → Rebuild Solution)

---

## Contact

- **GitHub:** https://github.com/USP-cad-hobby
- **Project:** https://github.com/USP-cad-hobby/Vdart_3D-Fortran-IFX
