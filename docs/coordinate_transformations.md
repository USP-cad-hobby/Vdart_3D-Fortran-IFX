# VDaRT Coordinate System Transformations

## Overview

This document defines the coordinate transformations used in VDaRT for a vertical-axis wind turbine (VAWT). The transformations connect three coordinate systems:

1. **Global (G)**: Earth-fixed inertial frame
2. **Rotor (R)**: Rotating with the rotor, blade-specific  
3. **Blade Local (B)**: Fixed to blade section, accounts for pitch and cant

## Coordinate System Definitions

### 1. Global Frame (G): X-Y-Z
```
    Wind →  
            Z (up)
            |
            |     Blade at θ=0°
            |     ↓
        ----+---- Y (cross-wind)  ← Blade at θ=90°
           /|
          / |
         X  |
    (downwind)
            ↑ Blade at θ=180°
```

- **Origin**: Rotor axis at Z=0 (equator or ground level)
- **X**: Downwind direction (freestream wind FROM +X direction)
- **Y**: Cross-wind (horizontal, perpendicular to wind)
- **Z**: Vertical (upward)

**Blade positions** (viewed from above, looking down -Z):
- θ = 0°: Blade at +Y axis, moving in -X direction
- θ = 90°: Blade at -X axis, moving in -Y direction  
- θ = 180°: Blade at -Y axis, moving in +X direction
- θ = 270°: Blade at +X axis, moving in +Y direction

### 2. Rotor Frame (R): Radial-Tangential-Vertical
```
For blade at azimuth θ:

        Z (same as global)
        |
        |    T (tangential, direction of rotation)
        |   /
        |  /
        +-/-----> R (radial, outward from axis)
```

- **Origin**: Same as global
- **R**: Radial (outward from rotor axis toward blade)
- **T**: Tangential (in direction of rotation, perpendicular to R in X-Y plane)
- **Z**: Vertical (same as global Z)

The transformation from Global to Rotor depends on blade azimuth θ:
```
θ = TETA + CRANK(i)   where TETA = rotor angle, CRANK(i) = blade i phase offset
```

### 3. Blade Local Frame (B): Normal-Chord-Spanwise (NCS)
```
        S (spanwise, along blade toward tip)
        |
        |    N (normal, lift direction)
        |   /
        |  /
        +-/-----> C (chordwise, LE → TE)
```

- **Origin**: Blade section (at c/4 or 3c/4)
- **C**: Chordwise (from leading edge to trailing edge)
- **N**: Normal to chord (lift direction for positive α)
- **S**: Spanwise (along blade axis, toward upper tip)

## Key Angles

| Symbol | Name | Definition | Sign Convention |
|--------|------|------------|-----------------|
| θ (TETA1) | Blade azimuth | θ = TETA + CRANK(i) | Positive CCW from +Y (viewed from above) |
| φ (FI) | Effective angle | φ = θ - FI0 | Combined azimuth minus pitch |
| FI0 | Pitch angle | Blade pitch offset | Positive = LE into relative wind (nose-up) |
| β (BETA) | Cant angle | Blade section inclination | Positive = tilted outward at top |

## Physical Interpretation at Key Azimuths

### θ = 0° (Blade at +Y, moving in -X direction)
```
        Wind →
              ║ Blade (chord tangent to circle)
              ║
         ←────╬ Blade motion (-X direction)
              ║
              ↓ Chord direction (C)

UVEK(1) = VIND + R*Ω*cos(0°) = VIND + R*Ω    (wind + blade motion in +X)
UVEK(2) = R*Ω*sin(0°) = 0                     (no Y component)

φ = 0° → SF=0, CF=1
ULOC(1) = 0*UVEK(1) + 1*UVEK(2) = 0           (no chordwise component)
ULOC(2) = -1*UVEK(1) + 0*UVEK(2) = -UVEK(1)   (flow FROM +X in -C direction)

Result: Flow hits blade from the side → high AoA, stalled
```

### θ = 90° (Blade at -X, moving in -Y direction)  
```
        Wind →
              ═══════════ Blade (chord perpendicular to wind)
                    ↓ Blade motion (-Y direction)

UVEK(1) = VIND + R*Ω*cos(90°) = VIND          (wind only)
UVEK(2) = R*Ω*sin(90°) = R*Ω                   (blade motion in +Y, but sees -Y flow)

φ = 90° → SF=1, CF=0
ULOC(1) = -1*UVEK(1) + 0*UVEK(2) = -VIND      (chordwise from wind)
ULOC(2) = 0*UVEK(1) - 1*UVEK(2) = -R*Ω        (normal from rotation)

Result: Flow from ahead, reasonable AoA ~ atan2(VIND, R*Ω) ~ 24° for TSR=2.2
```

### θ = 180° (Blade at -Y, moving in +X direction - DOWNWIND)
```
                    ║
              ────→ ╬ Blade motion (+X direction)
                    ║
                    ↑ Chord direction
        Wind →      ║ Blade

UVEK(1) = VIND + R*Ω*cos(180°) = VIND - R*Ω   (wind minus blade motion)
UVEK(2) = R*Ω*sin(180°) = 0

φ = 180° → SF=0, CF=-1
ULOC(1) = 0*UVEK(1) - 1*UVEK(2) = 0
ULOC(2) = 1*UVEK(1) + 0*UVEK(2) = VIND - R*Ω  (reduced relative velocity)

Result: Lower relative velocity (velocity deficit in wake)
```

### θ = 270° (Blade at +X, moving in +Y direction)
```
        Wind →
              ═══════════ Blade
                    ↑ Blade motion (+Y direction)

UVEK(1) = VIND + R*Ω*cos(270°) = VIND
UVEK(2) = R*Ω*sin(270°) = -R*Ω

φ = 270° → SF=-1, CF=0  
ULOC(1) = 1*UVEK(1) + 0*UVEK(2) = VIND
ULOC(2) = 0*UVEK(1) + 1*UVEK(2) = -R*Ω

Result: Similar to θ=90° but blade moving opposite direction
        ALFA has opposite sign → CL has opposite sign
```

## Transformation Matrices

### Global to Blade Local (Velocity Transformation)

The transformation is a sequence of three rotations:

1. **Rotation by azimuth θ** about Z-axis (Global → intermediate)
2. **Rotation by pitch FI0** about the blade axis (accounts for pitch)
3. **Rotation by cant β** about the tangential axis (accounts for blade shape)

The combined transformation uses φ = θ - FI0:

```
[U_local]   [T_GB] [U_global]
[  C    ] = [    ] [   X    ]
[  N    ]   [    ] [   Y    ]
[  S    ]   [    ] [   Z    ]
```

Where the transformation matrix T_GB is:

```
        | -sin(φ)·cos(β)    cos(φ)·cos(β)   -sin(β) |
T_GB =  | -cos(φ)          -sin(φ)           0      |
        |  sin(φ)·sin(β)   -cos(φ)·sin(β)  -cos(β) |
```

**In code (WIND subroutine):**
```fortran
FI = TETA1 - FI0(i, j)     ! φ = θ - pitch
CF = cos(FI)               ! cos(φ)
SF = sin(FI)               ! sin(φ)  
CB = cos(BETA(j))          ! cos(β)
SB = sin(BETA(j))          ! sin(β)

! ULOC(1) = chordwise velocity (C-direction)
! ULOC(2) = normal velocity (N-direction)
ULOC(1) = -UVEK(1)*SF*CB + UVEK(2)*CF*CB - UVEK(3)*SB
ULOC(2) = -UVEK(1)*CF    - UVEK(2)*SF
```

### Blade Local to Rotor (Force Transformation)

Forces computed in blade local frame (FN, FC) must be transformed to rotor frame (FR, FT, FB).

**Key insight**: This transformation uses **only FI0 and β**, not the full azimuth θ!

This is because FR and FT are defined in the rotor frame which rotates with the blade. The blade local frame differs from the rotor frame only by:
- Pitch angle FI0 (rotation about spanwise axis)
- Cant angle β (for curved blades)

```
        | cos(FI0)·cos(β)    sin(FI0) |   | FN |   | FR |
        |-sin(FI0)·cos(β)    cos(FI0) | × | FC | = | FT |
        |    -sin(β)            0     |           | FB |
```

**In code (FORCES subroutine):**
```fortran
SINFI0 = sin(FI0(i, j))
COSFI0 = cos(FI0(i, j))
COSB = cos(BETA(j))
SINB = sin(BETA(j))

FR =  COSFI0 * COSB * FN + FC * SINFI0
FT = -SINFI0 * FN * COSB + COSFI0 * FC
FB = -SINB * FN
```

## Critical Distinction: FI vs FI0

This is a key architectural decision that affects the entire transformation chain:

### FI = θ - FI0 (Effective Angle)
Used when transforming between **GLOBAL** (fixed) and **BLADE-LOCAL** (rotating + pitched):

| Module | Usage | Purpose |
|--------|-------|---------|
| **WIND** | `fi = teta1 - FI0(i,j)` | Velocity: Global → Local |
| **FLYT** | `fir = t1 - FI0(...)` | Position offset: (ξ,η,ζ) → Global |

### FI0 Alone (Pitch Angle Only)
Used when transforming between **ROTOR** (rotating) and **BLADE-LOCAL** (rotating + pitched):

| Module | Usage | Purpose |
|--------|-------|---------|
| **FORCES** | `sin(FI0), cos(FI0)` | Force: Local → Rotor |

### Physical Explanation

```
    GLOBAL FRAME              ROTOR FRAME              BLADE-LOCAL FRAME
    (Earth-fixed)             (Rotates with blade)     (Rotates + Pitched)
         X,Y,Z          θ          R,T,Z          FI0         N,C,S
           ←─────────────────────────→←─────────────────────────→
                                      │
                   FI = θ - FI0       │        FI0 only
           ←──────────────────────────┼─────────────────────────→
                                      │
                 Full transformation  │  Partial transformation
                 (velocity, position) │  (forces only)
```

**Key insight**: The rotor frame ALREADY includes the θ rotation, so transforming 
from blade-local to rotor only needs FI0 (the additional pitch offset).

### Verification Example

At θ = 0° (blade at +Y axis), FI0 = 10° pitch:

| Direction | Rotor Frame | Blade-Local Frame | Angle Between |
|-----------|-------------|-------------------|---------------|
| **Tangent/Chord** | T = -X | C = -X rotated 10° | **10° = FI0** ✓ |
| **Radial/Normal** | R = +Y | N = +Y rotated 10° | **10° = FI0** ✓ |

The transformation matrices correctly use `cos(FI0)`, `sin(FI0)` for the angle between these frames.

## Evaluation Points: c/4 and 3c/4

The blade section has two evaluation points:

| Point | Purpose | Position along chord |
|-------|---------|---------------------|
| c/4 (quarter-chord) | Force evaluation, bound vortex location | 25% from LE |
| 3c/4 (three-quarter-chord) | Angle of attack evaluation | 75% from LE |

### Configuration: USE_ETA_OFFSET Flag

The separation between c/4 and 3c/4 evaluation points is **configurable** via a runtime flag:

```fortran
! In main.f90:
USE_ETA_OFFSET = .false.   ! Legacy mode (default)
USE_ETA_OFFSET = .true.    ! Proper thin airfoil theory
```

| Setting | c/4 ETA | 3c/4 ETA | Best For |
|---------|---------|----------|----------|
| `.false.` (Legacy) | 0 | 0 | Validation, fixed pitch |
| `.true.` (Proper) | C×(0.75-HSTAR) | C×(0.25-HSTAR) | Pitching blades |

**Important**: For fixed pitch (FI0DOT = 0), the ETA offset has **NO EFFECT** because 
the `fidot * eta` term in the velocity equation is zero. The offset only matters when 
the blade is actively pitching.

### c/4 Point (HSTAR = 0.75 typically)
- **UREL** is computed here (relative velocity magnitude)
- **Forces** (FN, FC) are applied here
- Bound vortex is located here

Position offset from blade axis:
```fortran
if (USE_ETA_OFFSET) then
  η = C * (0.75 - HSTAR)   ! = 0 for HSTAR = 0.75
else
  η = 0                     ! Legacy mode
end if
ξ = 0                       ! chordwise offset
ζ = 0                       ! spanwise offset
```

### 3c/4 Point
- **ALFA** (angle of attack) is computed here
- This accounts for bound vortex downwash effect

Position offset:
```fortran
if (USE_ETA_OFFSET) then
  η = C * (0.25 - HSTAR)   ! = -0.5*C for HSTAR = 0.75
else
  η = 0                     ! Legacy mode
end if
```

### When Does ETA Offset Matter?

| Condition | ETA Effect |
|-----------|------------|
| **Fixed pitch** (FI0DOT = 0) | **None** - fidot×eta = 0 |
| **Harmonic pitch** (Mode 1) | **Yes** - 3c/4 sees different velocity |
| **Cyclic pitch** (Mode 2) | **Yes** - affects AoA calculation |
| **High pitch rates** | **Significant** - unsteady effects |

### Diagram: c/4 vs 3c/4 Separation

```
    LE ─────────────────────────────────── TE
        │←── c/4 ──→│←───── c/2 ─────→│

        ↑           ↑                 ↑
        │           │                 │
     c/4 point   Blade axis      3c/4 point
    (Forces)    (Pitch axis)      (AoA)
    η = 0       HSTAR=0.75      η = -0.5*C

    When pitching, 3c/4 moves relative to c/4, changing the
    effective velocity and hence the angle of attack.
```

### Pitch Rate Contribution

When pitch varies (FI0DOT ≠ 0), there's an additional velocity at the evaluation point:

```fortran
! Velocity due to pitching motion at point (ξ, η, ζ) from blade axis:
FIDOT = OMEGA - FI0DOT    ! Angular rate

! Additional velocity in global frame:
dU_X = -FIDOT * (ξ*CF*CB - η*SF + ζ*CF*SB)
dU_Y = -FIDOT * (ξ*SF*CB + η*CF + ζ*SF*SB)
```

## Verification Checklist

### Velocity Transformation (WIND)
- [x] FI = TETA1 - FI0 correctly combines azimuth and pitch
- [x] ULOC(1) uses SF, CF, CB, SB correctly
- [x] ULOC(2) uses SF, CF correctly (no β dependence - correct for 2D airfoil)
- [x] UVEK(3) includes induced velocity SWB(3)
- [x] ETA offset for c/4 vs 3c/4 evaluation (configurable via USE_ETA_OFFSET)

### Force Transformation (FORCES)
- [x] Uses only FI0, not full azimuth θ (correct)
- [x] FR, FT, FB formulas match legacy
- [x] FT = FC when FI0 = 0 and β = 0 (straight blade, no pitch)

### Sign Conventions
- [x] Positive FT = force in direction of rotation = positive torque
- [x] Positive FR = force outward from axis
- [x] Positive ALFA = nose-up angle of attack
- [x] Positive CL has same sign as ALFA (fixed in clcdideal)

## FI0 Modes for Pitch Control

The code supports three pitch modes (in solver_run):

| Mode | Name | FI0 Behavior |
|------|------|--------------|
| 0 | Fixed | FI0 = FI0_BASE (constant) |
| 1 | Harmonic | FI0 = FI0_BASE + FI0_AMP × sin(FI0DOT × t) |
| 2 | Cyclic | FI0 varies with blade azimuth relative to wind |

### Mode 2 (Cyclic) Details:
```
θ_rel = blade_azimuth - WIND_DIR
if (90° < θ_rel < 270°):    ! Downwind pass
    FI0 = FI0_BASE + FI0_AMP
else:                        ! Upwind pass
    FI0 = FI0_BASE
```

## TODO: Full Pitch Implementation

For complete variable pitch support, these items need attention:

1. ~~**ETA offset**: Enable proper c/4 vs 3c/4 offset~~ ✅ **DONE** - Configurable via USE_ETA_OFFSET
2. **FI0DOT tracking**: Track pitch rate for unsteady aerodynamics
3. **Force transformation**: Verify works correctly for large FI0 values
4. **Wake geometry**: H1 array should use updated blade positions with pitch

## TODO: Helical Blade Support

For helical/twisted blade configurations (e.g., Gorlov turbine), add:

1. **Blade sweep angle (SWEEP or LAMBDA)**
   - Forward sweep: SWEEP > 0 (blade LE ahead of TE in rotation direction)
   - Backward sweep: SWEEP < 0 (blade TE ahead of LE)
   - Affects blade section azimuth offset along span

2. **Helical geometry formula**:
   ```
   θ_section(z) = θ_blade + SWEEP × (z - z_mid) / H0
   ```
   Where:
   - `θ_blade` = blade root azimuth
   - `SWEEP` = total twist angle over blade span [radians]
   - `z` = vertical position of section
   - `z_mid` = blade midspan height
   - `H0` = total blade height

3. **Extended Transformation Chain**:
   ```
   GLOBAL FRAME         ROTOR FRAME          SWEPT FRAME          BLADE-LOCAL FRAME
   (Earth-fixed)        (Rotates with blade) (Helical offset)     (Pitched)
        X,Y,Z      θ        R,T,Z       Δθ(z)     R',T',Z      FI0      N,C,S
          ←───────────────────→←─────────────────→←─────────────────────→
                               │                  │
              FI = θ - FI0     │    θ + Δθ(z)     │        FI0 only
          ←────────────────────┼──────────────────┼─────────────────────→
                               │                  │
           (velocity, position)│  (sweep offset)  │  (forces only)
   ```

   **New angle**: `Δθ(z) = SWEEP × (z - z_mid) / H0`

   The effective azimuth becomes: `θ_eff(z) = θ + Δθ(z)`

4. **Transformation Matrix Extension**:

   For helical blades, the transformation uses `φ = θ + Δθ(z) - FI0`:
   ```fortran
   ! Section-dependent azimuth offset for helical blade
   delta_theta = SWEEP * (z - z_mid) / H0

   ! Effective angle including sweep
   FI = TETA1 + delta_theta - FI0(i, j)

   CF = cos(FI)
   SF = sin(FI)
   ```

5. **Implementation locations**:
   | Module | Change Required |
   |--------|-----------------|
   | `vdart_state_mod.f90` | Add `SWEEP`, `SWEEP_SECTION(NOL)` variables |
   | `vdart_blad_mod.f90` | Compute section sweep: `SWEEP_SECTION(j) = SWEEP*(z(j)-z_mid)/H0` |
   | `vdart_wind_mod.f90` | Use `fi = teta1 + SWEEP_SECTION(j) - FI0(i,j)` |
   | `vdart_flyt_mod.f90` | Update H1 positions with `t1 + SWEEP_SECTION(j)` |
   | `vdart_forces_mod.f90` | Forces still use only FI0 (sweep is in rotor frame) |

6. **Key Insight: Forces Transformation**:

   The force transformation from blade-local to rotor **still uses only FI0**!

   Why? Because:
   - The sweep angle Δθ(z) rotates the entire section in the X-Y plane
   - This is PART OF the rotor frame (just offset azimuthally)
   - The blade-local frame differs from the swept-rotor frame only by FI0

   ```
   Swept-Rotor Frame    →    Blade-Local Frame
        R',T',Z         FI0         N,C,S
          ←─────────────────────────────→
                    FI0 only
   ```

7. **Helical blade diagram**:
   ```
   Top view (looking down -Z):

        Straight blade          Helical blade (SWEEP > 0)
              │                       ╱  ← Top (z = H0)
              │                      ╱
              │                     ╱  Forward sweep
              │                    ╱
              ●────────────       ●────────────  ← Mid (z = H0/2)
              │                    ╲
              │                     ╲
              │                      ╲
              │                       ╲  ← Bottom (z = 0)

   Section azimuth varies with height:
   - Top:    θ + SWEEP/2
   - Mid:    θ
   - Bottom: θ - SWEEP/2
   ```

8. **Physics considerations**:
   - Each section sees slightly different azimuth → smoother torque
   - Wake geometry becomes helical
   - Blade-blade interaction changes (wake from one section hits different azimuth)
   - Self-starting improved (always some section at favorable azimuth)

## Aerodynamic Model Configuration Summary

| Parameter | Location | Default | Purpose |
|-----------|----------|---------|---------|
| `USE_ETA_OFFSET` | main.f90 | `.false.` | Enable c/4 vs 3c/4 separation |
| `PITCH_MODE` | main.f90 | `0` | Pitch control strategy |
| `FI0_BASE` | main.f90 | `0.0` | Baseline pitch angle |
| `FI0_AMP` | main.f90 | `0.0` | Pitch amplitude (modes 1,2) |
| `FI0DOT` | main.f90 | `0.0` | Pitch frequency (mode 1) |
| `HSTAR` | main.f90 | `0.75` | Bound vortex position (c/4) |
| `SWEEP` | main.f90 | `0.0` | Helical blade twist (TODO) |

## Complete Angle Summary

| Angle | Symbol | Formula | Used In | Purpose |
|-------|--------|---------|---------|---------|
| Blade azimuth | θ | `TETA + CRANK(i)` | All | Blade position |
| Sweep offset | Δθ(z) | `SWEEP × (z-z_mid)/H0` | WIND, FLYT | Helical geometry (TODO) |
| Effective angle | φ | `θ + Δθ(z) - FI0` | WIND, FLYT | Velocity transform |
| Pitch angle | FI0 | User input | FORCES | Force transform |
| Cant angle | β | `atan(dR/dZ)` | WIND, FORCES | 3D blade shape |

## References

- Legacy code: `Vdart_3d_R5.for`, lines 1960-2079 (WIND), lines 1408-1448 (FORCES)
- Modern code: `vdart_wind_mod.f90`, `vdart_forces_mod.f90`
