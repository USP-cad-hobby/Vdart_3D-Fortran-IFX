# VDaRT Development Session Notes

## Latest Session: 2026-09-15

### Baseline Test: 2026-09-15
- **Branch:** test/pitch-baseline
- **Parameters:** FI0_BASE=0.0_dp, FI0_AMP=0.0_dp
- **Built exe:** build/vdart_baseline.exe
- **Commit:** fc1f07f

The baseline test was executed and the resulting executable saved for reproducibility. See tests/ for the comparison scaffold.

---

## Previous Session: 2026-08-27

### 🔥 CRITICAL BUG FIX: Pitch Rate Calculation
**Bug Found**: `fidot = OMEGA - FI0DOT` (constant, WRONG)  
**Bug Fixed**: `fidot = OMEGA - FI0_AMP * FI0DOT * cos(FI0DOT * t)` (instantaneous, CORRECT)

**Impact**:
- ✅ **Performance recovered**: CP from 0.141 → 0.156 (+10.6%)
- ✅ **Convergence improved**: GG from 0.263 → 0.057 (5× better)
- ✅ **Pistolesi corrections working**: c/4 vs 3c/4 separation validated
- ✅ **Harmonic pitch validated**: Matches baseline within 0.6%

### Current Status (After Fix)
- **CP**: 0.1565 (harmonic pitch ±5° at 1P)
- **Power**: 507 kW
- **Torque**: 621 kNm
- **Convergence**: GG = 0.057 ✅ (excellent)
- **Baseline match**: Within 0.6% ✅

### Test Matrix Completed

| Config | PITCH_MODE | USE_ETA_OFFSET | CP | Power [kW] | GG | Status |
|--------|------------|----------------|-----|------------|-----|--------|
| Baseline | 0 (Fixed) | .false. | 0.156 | 504 | 0.0076 | ✅ Reference |
| Step 1 | 1 (Harmonic) | .false. | 0.141 | 457 | 0.263 | ❌ Wrong fidot |
| Step 1B | 1 (Harmonic) | .true. | 0.141 | 457 | 0.263 | ❌ Same (eta=0 at c/4) |
| **Step 2** | **1 (Harmonic)** | **.true.** | **0.156** | **507** | **0.057** | ✅ **CORRECTED** |

### Files Modified This Session
1. **vdart_wind_mod.f90** (lines 22, 36-57)
   - Added `time_now` variable
   - Fixed `fidot` calculation for PITCH_MODE=1
   - Proper instantaneous pitch rate: `dFI0/dt = FI0_AMP * FI0DOT * cos(FI0DOT*t)`

### Current Configuration (main.f90)
```fortran
USE_ETA_OFFSET = .true.   ! Pistolesi corrections enabled
PITCH_MODE = 1            ! Harmonic pitch
FI0_BASE = 0.0           ! No mean offset
FI0_AMP = 5.0° = 0.0873 rad  ! ±5° amplitude
FI0DOT = 0.817 rad/s     ! 1P frequency (= OMEGA)
```

### Documentation Created
- **PITCH_CONTROL_VALIDATION.md** - Complete analysis of bug fix and validation
- Updated **coordinate_transformations.md** (previous session)
- Updated **blade_position_verification.md** (previous session)

### Next Steps
1. 🔲 Test **PITCH_MODE = 2** (Cyclic pitch) for performance optimization
2. 🔲 Test higher pitch amplitudes (10°, 15°)
3. 🔲 Test variable pitch frequencies (0.5P, 2P, 3P)
4. 🔲 Implement added mass terms (Theodorsen/Wagner functions)

---

## Previous Session: 2026-02-28

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

To Resume Next Session
Tell Copilot:
> "I'm continuing VDaRT development. Please read `docs/coordinate_transformations.md` 
> and `docs/SESSION_NOTES.md` for context. Last CP was ~0.14 with good convergence."
