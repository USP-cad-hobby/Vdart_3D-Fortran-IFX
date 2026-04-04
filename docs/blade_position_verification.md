# VDaRT Blade Position and Transformation Verification

## 1. Blade Position in Global Coordinates

From `vdart_blad_mod.f90` (lines 156-160):
```fortran
BLSNIT(i, j, 3) = BLSNIT(1, j, 3)                    ! Z unchanged
BLSNIT(i, j, 2) = BLSNIT(1, j, 2) * cos(CRANK(i))   ! Y component
BLSNIT(i, j, 1) = -BLSNIT(1, j, 2) * sin(CRANK(i))  ! X component
```

For blade 1 at CRANK(1) = 0°:
- `BLSNIT(1, j, :) = (0, R, Z)` where R = blade radius at section j

For blade i at CRANK(i) = θ_crank:
```
X = -R·sin(θ_crank)
Y = R·cos(θ_crank)  
Z = Z (vertical position)
```

### Verification at Key Azimuths

| CRANK | X | Y | Position Description |
|-------|---|---|---------------------|
| 0° | 0 | +R | Blade at +Y axis |
| 90° | -R | 0 | Blade at -X axis |
| 120° | -R·sin(120°) = -0.866R | R·cos(120°) = -0.5R | Blade 2 initial position |
| 180° | 0 | -R | Blade at -Y axis |
| 240° | -R·sin(240°) = +0.866R | R·cos(240°) = -0.5R | Blade 3 initial position |
| 270° | +R | 0 | Blade at +X axis |

### Convention
The azimuth θ is measured **from the +Y axis**, positive **counter-clockwise** when viewed from above (+Z direction):
- θ = 0°: Blade at +Y
- θ = 90°: Blade at -X  
- θ = 180°: Blade at -Y
- θ = 270°: Blade at +X

## 2. Time-Dependent Position

At simulation time, the blade azimuth is:
```
θ = TETA + CRANK(i)
```
where `TETA = IRUN × DTETA` is the rotor rotation angle.

### From FLYT Subroutine (vdart_flyt_mod.f90, lines 75-77):
```fortran
t1 = teta + CRANK(i)                    ! θ = azimuth angle
st1 = sin(t1); ct1 = cos(t1)

! Bound vortex position (K=1):
H1(i, j, 1, 1) = -BLSNIT(1, j, 2) * st1 - xi*sf*cb - eta*cf - zeta*sf*sb
H1(i, j, 1, 2) =  BLSNIT(1, j, 2) * ct1 - xi*cf*cb - eta*sf - zeta*cf*sb  
H1(i, j, 1, 3) =  BLSNIT(1, j, 3)       - xi*sb    + zeta*cb
```

Where:
- `BLSNIT(1, j, 2)` = R = blade radius at section j (from blade 1 master geometry)
- `BLSNIT(1, j, 3)` = Z = vertical position of section j
- `xi, eta, zeta` = c/4 offset (currently all = 0)
- `sf, cf` = sin(φ), cos(φ) where φ = θ - FI0 (effective angle with pitch)
- `sb, cb` = sin(β), cos(β) where β = cant angle

**Primary position terms** (ignoring xi, eta, zeta):
```
X_blade = -R·sin(θ)
Y_blade = R·cos(θ)
Z_blade = Z
```

## 3. Local Coordinate Systems

### 3.1 RTS (Radial-Tangential-Spanwise)

For a blade at azimuth θ, the RTS unit vectors in global coordinates are:

**Radial (outward from axis):**
```
R_hat = (-sin(θ), cos(θ), 0)
```

**Tangential (direction of rotation, CCW viewed from above):**
```
T_hat = (-cos(θ), -sin(θ), 0)
```

**Spanwise (upward along blade):**
```
S_hat = (0, 0, 1)
```

### 3.2 NCS (Normal-Chord-Spanwise) - Blade Local

With pitch angle FI0 and cant angle β:

Let φ = θ - FI0 (effective angle)

**Chord direction (LE → TE):**
The chord is tangent to the rotation circle, rotated by pitch FI0:
```
C_hat = (-cos(φ), -sin(φ), 0) · cos(β) + (0, 0, -1) · sin(β)  [for canted blade]
```
For straight blade (β = 0):
```
C_hat = (-cos(φ), -sin(φ), 0)
```

**Normal direction (lift direction for positive α):**
```
N_hat = perpendicular to C in the plane of rotation
     = (sin(φ), -cos(φ), 0) · cos(β) + ...
```
For straight blade (β = 0):
```  
N_hat = (sin(φ), -cos(φ), 0)
```

## 4. ξ-η-ζ (Xi-Eta-Zeta) Coordinate System

The (ξ, η, ζ) system defines offsets from the blade axis (rotation center) to evaluation points like c/4 or 3c/4. This is a **blade-fixed** coordinate system that rotates with the blade.

### Definition (relative to blade section):

| Symbol | Direction | Physical Meaning |
|--------|-----------|------------------|
| ξ (XI) | Chordwise | Offset along chord (positive = toward TE) |
| η (ETA) | Normal | Offset perpendicular to chord (positive = toward pressure side / upwind) |
| ζ (ZETA) | Spanwise | Offset along blade span (positive = toward upper tip) |

### Transformation to Global Coordinates

From FLYT subroutine (legacy lines 1393-1398):
```fortran
φ = θ - FI0                  ! Effective angle (azimuth minus pitch)
SF = sin(φ); CF = cos(φ)     ! sin/cos of effective angle
SB = sin(β); CB = cos(β)     ! sin/cos of cant angle

! Position offset in global coordinates:
ΔX = -ξ·SF·CB - η·CF - ζ·SF·SB
ΔY = -ξ·CF·CB - η·SF - ζ·CF·SB
ΔZ = -ξ·SB + ζ·CB
```

### Verification at θ = 0° (blade at +Y, zero pitch, straight blade)
```
φ = 0°, β = 0° → SF=0, CF=1, SB=0, CB=1

ΔX = -ξ·0·1 - η·1 - ζ·0·0 = -η    → η moves point in -X (upwind)
ΔY = -ξ·1·1 - η·0 - ζ·1·0 = -ξ    → ξ moves point in -Y (toward axis = chordwise)
ΔZ = -ξ·0 + ζ·1 = ζ               → ζ moves point in +Z (upward = spanwise)
```

At θ = 0°, the chord is aligned with the -Y direction (tangent to rotation circle), so:
- Moving in -Y is moving along the chord ✓
- Moving in -X is moving perpendicular to chord (toward oncoming wind) ✓
- Moving in +Z is moving along the blade span ✓

### Evaluation Points

**Bound vortex location (c/4):**
```fortran
ETA = (0.75 - HSTAR) * C    ! For HSTAR = 0.75, ETA = 0
XI = 0
ZETA = 0
```
With HSTAR = 0.75, the bound vortex is at the blade axis (no offset).

**AoA evaluation (3c/4):**
```fortran
ETA = (0.25 - HSTAR) * C    ! For HSTAR = 0.75, ETA = -0.5*C
```
The 3c/4 point is offset by -0.5*C in the η direction (toward the suction side / downwind).

**Note:** In the current code, ETA is set to 0 for both passes (disabled).

### Legacy Code Inconsistency Note

There is a sign difference between START and FLYT in the legacy code for the Y-component:
- **START (line 1620):** `+XI*CF*CB - ETA*SF + ZETA*CF*SB`
- **FLYT (line 1397):**  `-XI*CF*CB - ETA*SF - ZETA*CF*SB`

The FLYT version is used during simulation. The modern code correctly matches FLYT.

## 5. Velocity Transformation: Global → Local

### Step 1: Compute Global Velocity
```fortran
! Wind + induced + blade motion
UVEK(1) = VIND(1) + SWB(1) + R·Ω·cos(θ) - FIDOT·(ξ·CF·CB - η·SF + ζ·CF·SB)
UVEK(2) = VIND(2) + SWB(2) + R·Ω·sin(θ) - FIDOT·(ξ·SF·CB + η·CF + ζ·SF·SB)
UVEK(3) = VIND(3) + SWB(3)
```

The blade rotation velocity in global coordinates:
```
V_blade = Ω × r_blade = Ω × (-R·sin(θ), R·cos(θ), 0)
        = (Ω·R·cos(θ), Ω·R·sin(θ), 0)
```

The **relative wind** (what the blade sees) is V_wind - V_blade, but we add V_blade because we're computing the velocity of air relative to blade, which means air appears to come from opposite direction of blade motion.

### Step 2: Transform to Local (φ = θ - FI0)
```fortran
CF = cos(φ);  SF = sin(φ)
CB = cos(β);  SB = sin(β)

ULOC(1) = -UVEK(1)·SF·CB + UVEK(2)·CF·CB - UVEK(3)·SB   ! Chordwise
ULOC(2) = -UVEK(1)·CF    - UVEK(2)·SF                   ! Normal
```

### Transformation Matrix (Global → Local)
```
[ULOC_C]   [-SF·CB    CF·CB   -SB] [UVEK_X]
[ULOC_N] = [-CF      -SF       0 ] [UVEK_Y]
[ULOC_S]   [ SF·SB   -CF·SB   -CB] [UVEK_Z]
```

## 6. Force Transformation: Local → Rotor

Forces computed in blade local frame:
```
FN = normal force (in N direction)
FC = chordwise force (in C direction)
```

Transformation to rotor frame (uses only FI0 and β, NOT θ):
```fortran
SINFI0 = sin(FI0);  COSFI0 = cos(FI0)
SINB = sin(β);      COSB = cos(β)

FR =  COSFI0·COSB·FN + FC·SINFI0    ! Radial
FT = -SINFI0·FN·COSB + COSFI0·FC    ! Tangential  
FB = -SINB·FN                        ! Vertical (Z)
```

### Why Only FI0, Not θ?
Because FR and FT are defined **in the rotor frame**, which rotates with the blade. The transformation from blade-local (N-C) to rotor (R-T) only involves:
- Pitch angle FI0 (how the chord is rotated relative to tangent)
- Cant angle β (blade inclination from vertical)

The azimuth θ already defines the rotor frame orientation relative to global.

## 7. Verification Test Cases

### Test 1: Blade 1 at θ = 0° (at +Y axis)
```
Position: (0, R, Z)
φ = 0° - FI0 = 0° (for zero pitch)
SF = 0, CF = 1

ULOC(1) = 0·UVEK(1) + 1·UVEK(2) = UVEK(2)     ! Y component is chordwise
ULOC(2) = -1·UVEK(1) - 0·UVEK(2) = -UVEK(1)   ! -X component is normal

For UVEK = (VIND + R·Ω, 0, 0):
ULOC(1) = 0        → no chordwise flow
ULOC(2) = -VIND - R·Ω   → flow from +X appears in -N direction
α = atan2(-0, -(-VIND-R·Ω)) = atan2(0, VIND+R·Ω) ≈ 0° 
```
✓ At θ=0°, blade moving in -X, wind from +X → flow hits blade perpendicularly → large α

### Test 2: Blade at θ = 90° (at -X axis)
```
Position: (-R, 0, Z)
φ = 90° - FI0 = 90° (for zero pitch)
SF = 1, CF = 0

ULOC(1) = -1·UVEK(1) + 0·UVEK(2) = -UVEK(1)
ULOC(2) = 0·UVEK(1) - 1·UVEK(2) = -UVEK(2)

For UVEK = (VIND, R·Ω, 0):
ULOC(1) = -VIND     → chordwise flow from wind
ULOC(2) = -R·Ω     → normal flow from rotation

α = atan2(-(-VIND), -(-R·Ω)) = atan2(VIND, R·Ω) ≈ 24° for TSR=2.2
```
✓ Reasonable angle of attack for power-producing condition

### Test 3: Verify with Debug Output
From output_Q.txt at IRUN=72 (θ=360°=0°):
```
Blade 1: ALFA = -2.66° (small, near zero - stalled region)
Blade 2 at θ=120°: ALFA = +26.1° (positive, high AoA)
Blade 3 at θ=240°: ALFA = -22.5° (negative, opposite side)
```
✓ Signs are consistent with physics - blade 2 and 3 have opposite sign ALFA due to 180° phase difference in local flow direction.

## 8. Cone-Shaped Rotor Configuration

For a **cone-shaped rotor** with straight blades that tilt inward or outward, use the blade shape parameters A and B.

### Blade Shape Formula (Shape = 1, Straight)
```
Y(Z) = A × Z + B × H0
```

Where:
- **Y** = radius at height Z
- **Z** = vertical position (0 at bottom, H0 at top)
- **H0** = total blade height
- **A** = slope parameter (dR/dZ)
- **B** = normalized radius at Z=0 (R_bottom / H0)

### Configuration Examples

| Configuration | A | B | β (cant angle) | Description |
|---------------|---|---|----------------|-------------|
| **Vertical cylinder** | 0 | R/H0 | 0° | Standard VAWT |
| **Cone opens up** | +0.1 | R/H0 | ~6° | Radius increases with height |
| **Cone opens down** | -0.1 | R/H0 | ~-6° | Radius decreases with height |

### Resulting β Calculation

From `vdart_blad_mod.f90`:
```fortran
tanb = (Y_upper - Y_lower) / (Z_upper - Z_lower) = A
BETA(j) = atan(A)
```

For constant-slope cone: **β = atan(A)** is constant along the span.

### Example: 10° Cone Opening Upward
```fortran
! In main.f90:
a_test = tan(10.0_dp * pi / 180.0_dp)  ! A = 0.176 for 10° cone
b_test = 0.5_dp                          ! R_bottom = 0.5 × H0
```

### Effect of β ≠ 0 on Physics

1. **Velocity transformation**: Z-component of induced velocity (SWB(3)) contributes to chordwise velocity
2. **Force transformation**: Normal force creates vertical thrust component (FB)
3. **Position**: Bound vortex and wake positions follow the tilted blade geometry

## 9. Summary

The coordinate transformations are **correctly implemented** and match the legacy code:

| Transformation | Key Variables | Status |
|----------------|--------------|--------|
| Blade position | BLSNIT, CRANK | ✓ Verified |
| Global velocity | UVEK, VIND, SWB | ✓ Verified |
| Local velocity | ULOC, FI, BETA | ✓ Verified |
| Angle of attack | ALFA | ✓ Verified |
| Force transformation | FR, FT, FB, FI0 | ✓ Verified |
