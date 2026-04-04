# VDaRT Development Session Notes

## Last Session: 2026-02-28

### Current Status
- **CP**: ~0.14 (5 revolutions, converged)
- **All torques positive** ✅ (power extraction working)
- **Convergence**: GG < 0.003 ✅

### Key Fixes Applied This Session
1. ✅ **CL sign correction** in `vdart_aero_mod.f90` (`clcdideal`)
   - Added `sign_a` multiplier so CL has same sign as ALFA
2. ✅ **WB self-induction** re-implemented in `vdart_vortex_mod.f90`
   - Bound vortex (K=1) and first shed (K=2) contribution restored
3. ✅ **VIND(2), VIND(3)** added in `vdart_wind_mod.f90`
   - All three freestream components now included in UVEK
4. ✅ **USE_ETA_OFFSET** flag added for c/4 vs 3c/4 evaluation
   - Configurable in `main.f90`, default `.false.` (legacy)

### Current Configuration (main.f90)
```fortran
USE_ETA_OFFSET = .false.  ! Legacy mode
PITCH_MODE = 0            ! Fixed pitch
FI0_BASE = 0.0           ! No pitch offset
FI0_AMP = 0.0            ! No pitch amplitude
```

### Test Case Parameters
- Wind speed: 10 m/s
- RPM: 7.8
- Blade height: 100 m
- Blade radius: 27 m
- Chord: 2.7 m
- TSR: ~2.2
- 3 blades, 12 sections

### Documentation Created
- `docs/coordinate_transformations.md` - Complete transformation theory
- `docs/blade_position_verification.md` - Position formulas and (ξ,η,ζ) system

### Key Concepts Clarified
1. **FI vs FI0**: 
   - FI = θ - FI0 for velocity/position transforms (Global → Local)
   - FI0 alone for force transforms (Local → Rotor)
2. **BETA (cant angle)**: Handles cone-shaped rotors (β ≠ 0)
3. **c/4 vs 3c/4**: Force evaluation at c/4, AoA at 3c/4

### TODO Items
1. Test with pitch control (PITCH_MODE = 1 or 2)
2. Implement helical blade SWEEP angle
3. Verify against legacy Fortran results

### Output Files
- `output_T.txt` - Latest run (check for results)
- `debug_forces.dat` - Force breakdown per blade
- `torque_vs_azimuth.dat` - Torque pattern data

### To Resume Next Session
Tell Copilot:
> "I'm continuing VDaRT development. Please read `docs/coordinate_transformations.md` 
> and `docs/SESSION_NOTES.md` for context. Last CP was ~0.14 with good convergence."
