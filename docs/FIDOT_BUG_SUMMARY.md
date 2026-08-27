# The fidot Bug: Root Cause Analysis

**Date**: 2026-08-27  
**Severity**: CRITICAL  
**Impact**: 10% performance error, convergence failure  
**Status**: ✅ FIXED

---

## The Bug in One Picture

```
HARMONIC PITCH: FI0(t) = FI0_BASE + FI0_AMP · sin(FI0DOT · t)

┌─────────────────────────────────────────────────────────────┐
│  PITCH ANGLE vs TIME                                        │
│                                                              │
│  FI0 [deg]                                                  │
│    +5° ┤     ╱──╲                                           │
│        │    ╱    ╲                                          │
│     0° ┼───────────────────────                            │
│        │            ╲    ╱                                  │
│    -5° ┤             ╲──╱                                   │
│        └─────┬─────┬─────┬─────┬───► time                  │
│            T/4   T/2   3T/4   T                             │
│                                                              │
│  PITCH RATE: dFI0/dt = FI0_AMP · FI0DOT · cos(FI0DOT · t)  │
│                                                              │
│  fidot                                                       │
│    Ω+A ┤     ╲    ╱      ← CORRECT (time-varying)          │
│     Ω  ┼───────────────── ← WRONG (constant)               │
│    Ω-A ┤      ╲──╱                                          │
│        └─────┬─────┬─────┬─────┬───► time                  │
└─────────────────────────────────────────────────────────────┘

A = FI0_AMP · FI0DOT = 0.0873 · 0.817 = 0.0713 rad/s
```

---

## Root Cause

### WRONG Implementation (Before Fix)
```fortran
fidot = OMEGA - FI0DOT  ! Assumed dFI0/dt = FI0DOT (constant)
```

This is only correct if:
```
FI0(t) = FI0_BASE + FI0DOT · t  (linear ramp, NOT sinusoidal!)
```

But our harmonic pitch is:
```
FI0(t) = FI0_BASE + FI0_AMP · sin(FI0DOT · t)
dFI0/dt = FI0_AMP · FI0DOT · cos(FI0DOT · t)  ← TIME-VARYING!
```

### CORRECT Implementation (After Fix)
```fortran
if (PITCH_MODE == 1) then
  time_now = teta / OMEGA
  fidot = OMEGA - FI0_AMP * FI0DOT * cos(FI0DOT * time_now)
else
  fidot = OMEGA  ! Fixed or cyclic pitch (step function)
end if
```

---

## Impact on Aerodynamics

### Where fidot Appears

In `vdart_wind_mod.f90`, the velocity at evaluation points includes pitching motion:

```fortran
! First pass: UREL at c/4 (η = 0 for HSTAR=0.75)
uvek(1) = VIND + SWB + rz·Ω·cos(θ) - fidot·(... - η·sin(fi) + ...)
                                              ^^^^^^^^^^^
                                              This is ZERO at c/4!

! Second pass: ALFA at 3c/4 (η = -0.5·C = -1.35 m)
uvek(1) = VIND + SWB + rz·Ω·cos(θ) - fidot·(... - η·sin(fi) + ...)
                                              ^^^^^^^^^^^
                                              This is NON-ZERO at 3c/4!
```

### Velocity Correction at 3c/4

The term `fidot · η · sin(fi)` represents the velocity at 3c/4 due to pitching:

```
Wrong fidot:  V_corr = (OMEGA - FI0DOT) · (-1.35) · sin(fi)
                     = constant · (-1.35) · sin(fi)
                     
Correct fidot: V_corr = [OMEGA - FI0_AMP·FI0DOT·cos(Ω·t)] · (-1.35) · sin(fi)
                      = time-varying · (-1.35) · sin(fi)
```

**Magnitude of error**:
```
ΔV_corr = |correct - wrong| 
        = |FI0_AMP · FI0DOT · cos(Ω·t)| · 1.35 · |sin(fi)|
        ≈ 0.0713 · 1.35 · 1.0  (maximum)
        ≈ 0.096 m/s
```

For UREL ≈ 25 m/s, this is a **0.4% error in velocity**, but it affects ALFA directly:
```
ΔALFA ≈ arctan(ΔV/UREL) ≈ arctan(0.096/25) ≈ 0.22° (typical)
Up to 3.7° observed in actual results!
```

---

## Consequences

### Performance Underestimation

| Metric | Wrong fidot | Correct fidot | Error |
|--------|-------------|---------------|-------|
| CP | 0.141 | 0.156 | -9.6% |
| Power | 457 kW | 507 kW | -9.9% |
| Torque | 559 kNm | 621 kNm | -10.0% |

**Why?** Incorrect ALFA → incorrect CL → incorrect forces → wrong power

### Convergence Failure

| Metric | Wrong fidot | Correct fidot | Improvement |
|--------|-------------|---------------|-------------|
| GG | 0.263 | 0.057 | 5× better |
| Status | Non-convergent | Converged | ✅ |

**Why?** Wrong velocities → inconsistent wake evolution → oscillations → no convergence

### ALFA Errors (IRUN=360)

| Blade | Azimuth | Wrong ALFA | Correct ALFA | Error |
|-------|---------|------------|--------------|-------|
| 1 | 0° | -2.665° | -3.562° | -0.90° |
| 2 | 120° | +26.203° | +23.286° | -2.92° |
| 3 | 240° | -22.552° | -26.210° | -3.66° |

**Why?** Wrong pitch velocity at 3c/4 → wrong flow angle → wrong ALFA

---

## Mathematical Derivation

### Blade Pitch Kinematics

Starting from blade orientation angle relative to rotor:
```
fi(t) = θ(t) - FI0(t)
      = Ω·t - [FI0_BASE + FI0_AMP·sin(FI0DOT·t)]
```

Taking time derivative:
```
dfi/dt = Ω - dFI0/dt
       = Ω - FI0_AMP·FI0DOT·cos(FI0DOT·t)
```

This is **fidot**, the angular velocity of the blade pitch angle.

### Velocity Due to Pitching

A point at distance **η** from the pitch axis (perpendicular to blade) experiences velocity:
```
V_pitch = fidot × η  (cross product)

In component form:
  V_x = -fidot · η · sin(fi)
  V_y = +fidot · η · cos(fi)
```

These appear in the velocity equations (lines 92, 104-105 of vdart_wind_mod.f90).

### For Our Test Case

```
FI0(t) = 0 + 0.0873 · sin(0.817·t)  [radians]
       = 0 + 5° · sin(Ω·t)          [degrees]

dFI0/dt = 0.0873 · 0.817 · cos(0.817·t)
        = 0.0713 · cos(Ω·t)  [rad/s]

fidot = 0.817 - 0.0713 · cos(Ω·t)
      = Ω · [1 - 0.0873·cos(Ω·t)]
      
Variation: ±8.7% around mean
```

At 3c/4 with η = -1.35 m:
```
V_pitch_correction = -fidot · (-1.35) · sin(fi)
                   = +fidot · 1.35 · sin(fi)
                   
Maximum: (Ω + 0.0713) · 1.35 · 1.0 = 1.20 m/s
Minimum: (Ω - 0.0713) · 1.35 · 1.0 = 1.01 m/s

Error if using constant fidot = Ω:
  Actual - Constant = ±0.096 m/s (±8% of pitch contribution)
```

---

## Validation

### Harmonic Pitch Nullity Test

With ±5° harmonic pitch at 1P frequency:
- **Expected**: Near-zero net effect when averaged over complete cycles
- **Observed**: CP matches baseline within 0.6% ✅

This validates:
1. ✅ Pitch control mechanism working
2. ✅ fidot calculation correct
3. ✅ Pistolesi corrections (c/4 vs 3c/4) working
4. ✅ Integration over full cycles accurate

---

## Lessons Learned

### 1. Always Derive Time Derivatives Explicitly

❌ **WRONG**: Assume `dFI0/dt = FI0DOT` because it's called "FI0DOT"  
✅ **CORRECT**: Compute `dFI0/dt` from the actual time function `FI0(t)`

### 2. Test Pitch Control Early

The bug was latent since the pitch control system was implemented but never tested with USE_ETA_OFFSET=.true. until now.

### 3. Convergence is a Sanity Check

GG = 0.263 (non-convergent) should have been a red flag that something was physically wrong, not just a convergence parameter issue.

### 4. Validate Against Known Results

The harmonic pitch test (±5° at 1P) should produce near-zero net effect. This "nullity test" immediately revealed the bug when Step 2 matched baseline but Step 1 did not.

---

## Conclusion

The `fidot` bug was a **conceptual error** in understanding pitch kinematics:
- Variable name "FI0DOT" implied it was the time derivative of FI0
- But for harmonic pitch, `dFI0/dt ≠ FI0DOT` (FI0DOT is the frequency, not the rate!)
- The actual rate is `dFI0/dt = FI0_AMP · FI0DOT · cos(FI0DOT·t)` (time-varying)

**Impact**: 10% performance error, convergence failure  
**Fix complexity**: ~20 lines of code  
**Validation**: Harmonic pitch now matches baseline within 0.6%  
**Status**: ✅ Resolved, documented, validated

---

**References**:
- `docs/PITCH_CONTROL_VALIDATION.md` - Full validation report
- `docs/coordinate_transformations.md` - Kinematics derivations
- `vdart_wind_mod.f90` lines 36-57 - Fixed implementation
