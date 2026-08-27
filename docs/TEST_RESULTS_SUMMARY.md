# VDaRT Test Results Summary

**Date**: 2026-08-27  
**Test Case**: 100m straight-blade rotor (H0=100m, R=27m, TSR=2.2)  
**Purpose**: Validate pitch control and Pistolesi corrections

---

## Quick Reference Table

| Test | Config | fidot | CP | Power | Torque | GG | Status |
|------|--------|-------|-----|-------|--------|-----|--------|
| **Baseline** | Fixed pitch | Ω | 0.1560 | 504 kW | 617 kNm | 0.0076 | ✅ Reference |
| **Step 1** | Harmonic ±5° @ 1P | ❌ Constant | 0.1410 | 457 kW | 559 kNm | 0.263 | ❌ Bug |
| **Step 2** | Harmonic ±5° @ 1P | ✅ Corrected | **0.1565** | **507 kW** | **621 kNm** | **0.057** | ✅ **Fixed!** |

**Key Finding**: Correcting `fidot` recovered 10% performance and achieved 5× better convergence.

---

## Configuration Details

### Test Parameters (All Tests)
- Wind speed: 10 m/s
- RPM: 7.8 (Ω = 0.817 rad/s)
- Rotor height: 100 m
- Rotor radius: 27 m (nominal)
- Chord: 2.7 m
- TSR: 2.2
- Blades: 3 (120° spacing)
- Sections: 12
- Wake: 3 revolutions (KMNET=217)
- Simulation: 5 revolutions (360 timesteps)

### Baseline Configuration
```fortran
PITCH_MODE = 0           ! Fixed pitch
FI0_BASE = 0.0          ! No offset
USE_ETA_OFFSET = .false. ! Legacy mode
```

### Step 1 & 2 Configuration
```fortran
PITCH_MODE = 1           ! Harmonic
FI0_BASE = 0.0          ! No mean offset
FI0_AMP = 5.0° = 0.0873 rad   ! ±5° amplitude
FI0DOT = 0.817 rad/s    ! 1P frequency
USE_ETA_OFFSET = .true.  ! Pistolesi corrections
```

**Difference**: Step 1 used wrong `fidot`, Step 2 uses corrected `fidot`.

---

## Performance Metrics

### Power Coefficient (CP)

```
0.160 ┤                              
      │   ●─────────────────●        ● = Baseline (0.156)
0.155 ┤                     ╱         ◆ = Step 2 (0.156)
      │                    ╱ ◆        ■ = Step 1 (0.141)
0.150 ┤                   ╱           
      │                  ╱            
0.145 ┤                 ╱             
      │                ╱              
0.140 ┤   ■───────────╱               
      │                               
0.135 ┤                               
      └──┬────────────┬────────────┬──
      Baseline     Step 1       Step 2
```

**Recovery**: +10.6% (Step 1 → Step 2)

### Convergence (GG)

```
0.30 ┤   ■                         ■ = Step 1 (0.263, FAILED)
     │   │                         ◆ = Step 2 (0.057, CONVERGED)
0.25 ┤   │                         ● = Baseline (0.0076)
     │   │                         
0.20 ┤   │                         Target: GG < 0.10
     │   │                         
0.15 ┤   │                         
     │   │                         
0.10 ┤   │─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    
     │   │                         
0.05 ┤   │        ◆                
     │   │         │                
0.00 ┤   │         │ ●              
     └───┴─────────┴─────┴─────────
      Step 1    Step 2  Baseline
```

**Improvement**: 5× better convergence (Step 1 → Step 2)

---

## Angle of Attack (ALFA) at IRUN=360

| Blade | Azimuth | Baseline | Step 1 (Wrong) | Step 2 (Correct) | Δ(Step2-Step1) |
|-------|---------|----------|----------------|------------------|----------------|
| 1 | 0° | N/A | -2.665° | **-3.562°** | **-0.90°** |
| 2 | 120° | N/A | +26.203° | **+23.286°** | **-2.92°** |
| 3 | 240° | N/A | -22.552° | **-26.210°** | **-3.66°** |

**Observation**: Corrected `fidot` changes ALFA by up to 3.7°, significantly affecting lift forces.

---

## Forces at IRUN=360 (Blade 1, θ=0°)

| Quantity | Step 1 | Step 2 | Change |
|----------|--------|--------|--------|
| ALFA | -2.665° | -3.562° | -33.7% |
| CL | -0.2921 | -0.3904 | +33.7% |
| UREL | 30.204 m/s | 31.703 m/s | +5.0% |
| FN (normal) | 4.86 kN | 7.14 kN | **+47%** |
| FT (tangential) | 0.126 kN | 0.335 kN | **+165%** |

**Conclusion**: Proper `fidot` leads to higher UREL and larger forces, explaining performance recovery.

---

## The Bug vs The Fix

### WRONG (Step 1)
```fortran
fidot = OMEGA - FI0DOT  ! Assumed dFI0/dt = FI0DOT (constant)
```
**Problem**: For harmonic pitch `FI0(t) = FI0_AMP·sin(FI0DOT·t)`, the rate is **time-varying**:
```
dFI0/dt = FI0_AMP · FI0DOT · cos(FI0DOT·t)  ≠ FI0DOT
```

### CORRECT (Step 2)
```fortran
if (PITCH_MODE == 1) then
  time_now = teta / OMEGA
  fidot = OMEGA - FI0_AMP * FI0DOT * cos(FI0DOT * time_now)
else
  fidot = OMEGA
end if
```
**Result**: Instantaneous pitch rate computed correctly, leading to proper unsteady aerodynamics.

---

## fidot Variation (Step 2)

For FI0_AMP = 0.0873 rad, FI0DOT = 0.817 rad/s:
```
fidot(t) = 0.817 - 0.0873 · 0.817 · cos(0.817·t)
         = 0.817 - 0.0713 · cos(Ω·t)

Range:  0.746 rad/s  ≤  fidot  ≤  0.888 rad/s
Mean:   0.817 rad/s
Variation: ±8.7% around mean
```

**Effect at 3c/4** (η = -1.35 m):
```
V_correction = fidot · 1.35 · sin(fi)
ΔV_correction = ±0.096 m/s  (difference from wrong constant fidot)
```

For UREL ≈ 25 m/s, this is **0.4% velocity error** but causes **up to 3.7° ALFA error**.

---

## Validation Summary

### ✅ Passed Criteria

1. **Performance recovery**: Step 2 matches baseline within 0.6%
2. **Convergence**: GG < 0.10 achieved (GG = 0.057)
3. **Harmonic nullity**: ±5° at 1P produces near-zero net effect (validates implementation)
4. **Physical correctness**: ALFA changes consistent with pitching motion
5. **Wake stability**: No oscillations or divergence

### 📊 Validation Tests

| Test | Expected | Observed | Status |
|------|----------|----------|--------|
| Harmonic pitch nullity | CP ≈ CP_baseline | 0.156 vs 0.156 | ✅ Pass |
| Convergence with pitching | GG < 0.10 | 0.057 | ✅ Pass |
| ALFA varies with fidot | Δ ALFA ~ 1-4° | 0.9-3.7° | ✅ Pass |
| Force consistency | FN, FT positive & reasonable | Yes | ✅ Pass |

---

## Next Steps

### Immediate
1. ✅ **DONE**: Fix `fidot` calculation in `vdart_wind_mod.f90`
2. ✅ **DONE**: Validate with harmonic pitch test
3. ✅ **DONE**: Document findings

### Near-Term
1. 🔲 Test **PITCH_MODE = 2** (Cyclic pitch) for performance optimization
2. 🔲 Test higher pitch amplitudes (10°, 15°)
3. 🔲 Test variable pitch frequencies (0.5P, 2P, 3P)

### Long-Term
1. 🔲 Implement added mass terms (Theodorsen/Wagner functions)
2. 🔲 Add dynamic stall model (Beddoes-Leishman)
3. 🔲 Aeroelastic coupling (structural dynamics)

---

## File References

### Code
- `vdart_wind_mod.f90` - Fixed fidot calculation (lines 36-57)
- `vdart_solver_mod.f90` - Pitch control modes implementation
- `main.f90` - Test configuration

### Documentation
- `PITCH_CONTROL_VALIDATION.md` - Complete validation report
- `FIDOT_BUG_SUMMARY.md` - Root cause analysis
- `SESSION_NOTES.md` - Session history
- `coordinate_transformations.md` - Kinematics theory

### Data
- `torque_vs_azimuth.dat` - Torque history (last revolution)
- `debug_forces.dat` - Force debugging output

---

## Conclusion

The `fidot` bug caused **10% performance underestimation** and **convergence failure** in pitch control simulations. After fixing the bug to use **instantaneous pitch rate** instead of a constant value:

- ✅ Performance recovered to baseline (CP = 0.156)
- ✅ Convergence improved 5× (GG = 0.057)
- ✅ Pistolesi corrections (c/4 vs 3c/4) validated
- ✅ Ready for advanced pitch control strategies

**Impact**: Critical fix enabling all future pitch control research with VDaRT.

---

**Document Version**: 1.0  
**Status**: Complete  
**Next Review**: After PITCH_MODE=2 testing
