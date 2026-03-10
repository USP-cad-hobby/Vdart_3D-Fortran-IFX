# VDaRT-3D: Vertical-Axis Darrieus Rotor Turbine (3D)

**Modern Fortran 90 implementation of the VDaRT aerodynamic simulation code**

## Overview

VDaRT (Darrieus 3D) is a vortex-lattice method code for simulating the aerodynamic performance of vertical-axis wind turbines (VAWTs), specifically Darrieus-type rotors. This modernized version converts legacy FORTRAN 77 code to modern Fortran 90 with modular architecture.

### Features

- **3D vortex-lattice wake model** with time-stepping
- **Multiple blade configurations** (straight, parabolic, troposkien)
- **Dynamic pitch control** (active blade pitch actuation)
- **Iterative bound circulation solver** with Aitken acceleration
- **Modular architecture** for maintainability and extensibility

## Physics Model

### Key Aerodynamic Points

- **Bound vortex location:** c/4 (quarter-chord)
- **Angle of attack evaluation:** 3c/4 (three-quarter chord)
- **Vortex shedding:** Trailing edge with local fluid velocity
- **Pitch axis:** Configurable via `HSTAR` (h/c from trailing edge)

### Coordinate Systems

- **Global O(X,Y,Z):** Fixed inertial frame
- **Local Q(ξ,η,ζ):** Blade element frame (origin at pitch axis)
  - ξ: Normal to chord
  - η: Chordwise (positive toward TE)
  - ζ: Spanwise

## Quick Start

### Prerequisites

- Intel Fortran Compiler (IFX or IFORT)
- Visual Studio 2022 (or compatible)
- Windows 10/11

### Building

**Visual Studio:**
```
1. Open: VS_vdart_f90_modular.slnx
2. Build → Build Solution (Ctrl+Shift+B)
3. Run: Debug → Start Without Debugging (Ctrl+F5)
```

**Command Line (Intel oneAPI):**
```bash
ifort -o vdart.exe main.f90 vdart_*.f90 -O2 -assume byterecl
```

### Running

The demo case simulates a 100m straight-blade rotor:
- Height: 100m
- Blades: 3
- Chord: 2.7m
- Wind speed: 10 m/s
- RPM: 7.8

Input parameters are read from `D3_DATA.SEQ`.

## Module Structure

| Module | Purpose |
|--------|---------|
| `vdart_kinds_mod` | Precision definitions |
| `vdart_state_mod` | Global state arrays and parameters |
| `vdart_solver_mod` | Main time-stepping solver loop |
| `vdart_start_mod` | Initial wake generation (backwards in time) |
| `vdart_vortex_mod` | Iterative bound circulation solver |
| `vdart_bsa_mod` | Biot-Savart induced velocity calculations |
| `vdart_biot_mod` | Biot-Savart law for vortex filaments |
| `vdart_wind_mod` | Relative velocity and angle of attack |
| `vdart_aero_mod` | Lift/drag coefficient lookup |
| `vdart_forces_mod` | Force/moment calculation |
| `vdart_flyt_mod` | Wake convection (Adams-Bashforth) |
| `vdart_nethas_mod` | Wake velocity field calculation |
| `vdart_blad_mod` | Blade geometry generation |
| `vdart_io_mod` | File I/O utilities |

## Key Parameters

| Parameter | Meaning | Typical Value |
|-----------|---------|---------------|
| `H0` | Rotor height | 100 m |
| `C` | Chord length | 2.7 m |
| `UINF` | Wind speed | 10 m/s |
| `OMEGA` | Angular velocity | 0.817 rad/s |
| `DTETA` | Azimuthal step | 5° (0.087 rad) |
| `NOL` | Blade sections | 24 |
| `KMNET` | Wake mesh size | 361 (5 revolutions) |
| `HSTAR` | Pitch axis location | 0.75 (at 3c/4 from LE) |
| `RC` | Vortex core radius | 0.075 m |

## Modifications from Legacy Code

### Major Changes

1. **Modularization:** Split monolithic code into 15 modules
2. **Dynamic allocation:** Arrays sized at runtime
3. **FI0 timing fix:** Pitch angle updates AFTER `IRUN++` (synchronization fix)
4. **Array bounds safety:** Fixed tip node access for `FI0(NOL+1)` and `BETA(NOL+1)`
5. **Modern syntax:** `real(dp)`, allocatable arrays, implicit none

### Key Bug Fixes

- **FI0 synchronization:** Pitch angle `FI0(t)` now updates at correct time
- **Tip node access:** Safe access to `j=NOL+1` (tip) for `FI0` and `BETA`
- **NPSI definition:** Clarified as `IR+1` (index of bound vortex from one revolution ago)

## Legacy Code

The original FORTRAN 77 code is preserved in `legacy/vdart_3d_R5.FOR` for:
- Validation and comparison
- Historical reference
- Scientific reproducibility

See `legacy/README_LEGACY.md` for details.

## References

**Original Author:** U.S. Paulsen (Technical University of Denmark)

**Related Publications:**
- Paulsen et al., "A 3D vortex model for unsteady aerodynamics of VAWTs"
- DeepWind project documentation

## License

MIT License - See LICENSE file for details

## Contributing

This is a research code. For questions or collaboration, contact via GitHub issues.

---

**Last Updated:** 2026-03-10
**Version:** 1.0 (Modernized)
