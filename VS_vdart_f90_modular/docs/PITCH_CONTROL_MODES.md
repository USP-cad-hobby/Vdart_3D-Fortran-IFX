# Dual-Mode Pitch Control System

## Overview

The VDaRT code now supports **two pitch control strategies** for investigating different actuation concepts:

---

## Mode 1: Harmonic Pitch (Simple Testing)

### Description:
All blades pitch identically with sinusoidal motion:
```
FI0(i,j,t) = FI0_BASE + FI0_AMP * sin(FI0DOT * t)
```

### Use Cases:
- **Frequency response analysis**
- **Flutter/instability testing**
- **Simple harmonic actuation**
- **Validation against quasi-steady theory**

### Parameters:
```fortran
PITCH_MODE = 1
FI0_BASE   = 0.0      ! Baseline offset (rad)
FI0_AMP    = 0.0873   ! Amplitude (rad) = 5°
FI0DOT     = 0.817    ! Frequency (rad/s) = OMEGA for 1P excitation
```

### Characteristics:
- ✅ Simple implementation
- ✅ FI0DOT ≪ OMEGA → Quasi-steady OK
- ✅ All blades synchronized
- ⚠️ Not physically optimal for performance

---

## Mode 2: Cyclic Pitch (Torque Smoothing)

### Description:
Blade-specific pitch based on azimuth position to compensate for velocity deficit:
```
FI0(i,θ) = FI0_BASE + FI0_AMP   if sin(θ) < 0  (downwind: 90°<θ<270°)
         = FI0_BASE              otherwise       (upwind: −90°<θ<90°)
```

### Use Cases:
- **Torque ripple reduction**
- **Power coefficient enhancement**
- **Downwind velocity compensation**
- **Realistic VAWT control strategy**

### Parameters:
```fortran
PITCH_MODE = 2
FI0_BASE   = 0.0      ! Baseline pitch (rad)
FI0_AMP    = 0.0873   ! Downwind increment (rad) = 5°
FI0DOT     = N/A      ! (not used in mode 2)
```

### Characteristics:
- ✅ Physically motivated
- ✅ Each blade independent
- ✅ Once-per-revolution (FI0DOT ~ OMEGA)
- ✅ Can improve CP by 5-15% (literature)
- ⚠️ Requires blade-resolved logic
- ⚠️ Potential dynamic stall downwind

---

## Physical Basis (Mode 2)

### Problem:
```
Upwind (θ=0°):   V_rel ≈ √(V_∞² + (ΩR)²)     → High lift
Downwind (θ=180°): V_rel ≈ √((V_∞-2a*V_∞)² + (ΩR)²)  → Low lift
                                ↑
                         wake deficit (a≈0.3)
```

### Solution:
**Increase α downwind** to compensate:
```
α_upwind   = baseline
α_downwind = baseline + Δα_compensation
```

Achieved by: `FI0(θ) = FI0_BASE + FI0_AMP` for 90°<θ<270°

---

## Implementation Details

### Array Structure:
```fortran
! Before: FI0(NOL)          - All blades shared same pitch
! After:  FI0(NB, NOL)      - Blade-specific pitch control
```

### Code Structure:

**In `vdart_solver_mod.f90`:**
```fortran
select case (PITCH_MODE)
  case (1)  ! Harmonic
    FI0(:,:) = FI0_BASE + FI0_AMP * sin(FI0DOT * t)
    
  case (2)  ! Cyclic
    do i = 1, NB
      theta_i = teta + CRANK(i)
      if (sin(theta_i) < 0) then  ! Downwind
        FI0(i,:) = FI0_BASE + FI0_AMP
      else  ! Upwind
        FI0(i,:) = FI0_BASE
      end if
    end do
end select
```

---

## Example Configurations

### Example 1: No Pitch Control (Baseline)
```fortran
PITCH_MODE = 1
FI0_AMP = 0.0_dp
```

### Example 2: Harmonic Test (3 Hz, ±5°)
```fortran
PITCH_MODE = 1
FI0_BASE = 0.0_dp
FI0_AMP = 5.0_dp * pi / 180.0_dp
FI0DOT = 3.0_dp * 2.0_dp * pi  ! 3 Hz
```

### Example 3: Cyclic Torque Smoothing (+5° downwind)
```fortran
PITCH_MODE = 2
FI0_BASE = 0.0_dp
FI0_AMP = 5.0_dp * pi / 180.0_dp
! FI0DOT not used in mode 2
```

### Example 4: Cyclic with Baseline Offset (+2° baseline, +5° additional downwind)
```fortran
PITCH_MODE = 2
FI0_BASE = 2.0_dp * pi / 180.0_dp    ! All blades start at +2°
FI0_AMP = 5.0_dp * pi / 180.0_dp     ! Downwind adds +5° → total 7° downwind
```

---

## Expected Results

### Mode 1 (Harmonic):
- Torque oscillates at frequency `FI0DOT`
- Power coefficient unchanged (averaged)
- Useful for stability analysis

### Mode 2 (Cyclic):
- Flatter torque curve (reduced ripple)
- Increased CP (2-10% typical)
- Risk: Dynamic stall if FI0_AMP too large
- Optimal FI0_AMP depends on TSR

---

## Future Enhancements

### Option 3: Smooth Cyclic (Sinusoidal)
```
FI0(θ) = FI0_BASE + FI0_AMP * sin(θ - 180°)
```
Smoother than square wave, gentler actuation.

### Option 4: TSR-Adaptive
```
FI0_AMP = f(TSR, V_∞, position)
```
Optimal pitch schedule based on operating conditions.

---

**Author:** U.S. Paulsen  
**Date:** 2026-03-10  
**Status:** Implemented and ready for testing
