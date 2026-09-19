! main.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Demo program - 100m straight-blade rotor (proven stable case)
! Author: U.S.Paulsen
! Date: 2026-02-28
! SPDX-License-Identifier: MIT

program vdart_demo
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_blad_mod
  use vdart_solver_mod
  implicit none

  integer :: ierr
  integer :: nb_test, nol_test, kmnet_test, krun_test, kmaks_test
  real(dp) :: h0_test, a_test, b_test, bsaf_test, hstar_test
  real(dp) :: omega_test, uinf_test, c_test, dt_test, dteta_test, rc_test
  real(dp) :: ro_test, any_test, eps_test, ares_test
  real(dp) :: rpm_test, pitchoff, pitchoff_test
  integer :: i, neto, ir_temp
  logical :: RUN_CONTINUATION

  write(*,*) ''
  write(*,*) '========================================='
  write(*,*) '   VDaRT Demo: 100m Straight Blade'
  write(*,*) '   (Legacy D3_DATA.SEQ Test Case)'
  write(*,*) '========================================='
  write(*,*) ''

  ! Parameters from D3_DATA.SEQ
  uinf_test = 10.0_dp
  dteta_test = 5.0_dp * pi / 180.0_dp
  pitchoff_test = 0.0_dp * pi / 180.0_dp
  rpm_test = 7.8_dp
  omega_test = rpm_test * 2.0_dp * pi / 60.0_dp
  c_test = 2.7_dp

  h0_test = 100.0_dp
  a_test = 0.0_dp
  b_test = 0.27_dp
  bsaf_test = 0.05_dp
  hstar_test = 0.75_dp

  ro_test = 1.20_dp
  any_test = 15.0e-6_dp
  eps_test = 0.20_dp                 ! Looser tolerance for quick testing (was 0.10)
  ares_test = 0.50_dp                ! Faster convergence (was 0.33)
  rc_test = 7.50e-2_dp

  ! Legacy configuration - REDUCED FOR FASTER TESTING
  neto = 3                         ! Wake revolutions (was 5)
  nb_test = 3
  nol_test = 12                    ! Blade sections (was 24) - halved for speed

  ! Compute KMNET using legacy formula: NETO * IR + 1
  ! IR = 2π / DTETA 
  ir_temp = int(2.0_dp * pi / dteta_test)
  kmnet_test = neto * ir_temp + 1  ! = 3*72+1 = 217 (was 361)

  krun_test = 72                   ! Start checking after 1 revolution
  !kmaks_test = 2160                ! Run 30 revolutions
  kmaks_test = 360                  ! Run 5 revolutions for wake development
  dt_test = dteta_test / omega_test

  write(*,*) 'Test Case: Legacy D3_DATA.SEQ Configuration'
  write(*,*) '-------------------------------------------'
  write(*,'(A,F6.1,A)') '  Rotor height (H0):      ', h0_test, ' m'
  write(*,'(A,F6.2,A)') '  Blade shape:             Straight (B=', b_test, ')'
  write(*,'(A,I3)')     '  Number of blades:       ', nb_test
  write(*,'(A,I3)')     '  Blade sections (NOL):   ', nol_test
  write(*,'(A,I4)')     '  Wake mesh (KMNET):      ', kmnet_test
  write(*,'(A,I4)')     '  Steps per revolution:   ', ir_temp
  write(*,'(A,F6.2,A)') '  Chord length:           ', c_test, ' m'
  write(*,'(A,F6.2,A)') '  Wind speed (UINF):      ', uinf_test, ' m/s'
  write(*,'(A,F6.2,A)') '  Rotation (RPM):         ', rpm_test, ' RPM'
  write(*,'(A,F6.3,A)') '  Omega:                  ', omega_test, ' rad/s'
  write(*,'(A,F6.2,A)') '  Time step (DT):         ', dt_test, ' s'
  write(*,'(A,F6.2,A)') '  Azimuthal step:         ', dteta_test*180.0_dp/pi, ' deg'
  write(*,'(A,F6.4)')   '  Under-relaxation:       ', ares_test
  write(*,'(A,E10.3)')  '  Convergence tolerance:  ', eps_test
  write(*,'(A,I5)')     '  Max iterations:         ', kmaks_test
  write(*,*) ''

  write(*,*) 'Allocating state arrays...'
  call allocate_state(nb_test, nol_test, kmnet_test, ierr)
  if (ierr /= 0) then
    write(*,*) 'ERROR: Failed to allocate state. ierr=', ierr
    stop
  end if

  ! Set module parameters AFTER allocation
  H0 = h0_test
  A = a_test
  B = b_test
  BSAF = bsaf_test
  OMEGA = omega_test
  UINF = uinf_test
  C = c_test
  RC = rc_test
  DTETA = dteta_test
  DT = dt_test
  HSTAR = hstar_test

  ! ============ PITCH CONTROL MODE SELECTION ============
  ! PITCH_MODE = 0: Fixed pitch (legacy validation)
  !   - All blades: FI0 = FI0_BASE (constant)
  !   - Use for: baseline performance, legacy code validation
  !
  ! PITCH_MODE = 1: Harmonic (simple testing) *** ACTIVE ***
  !   - All blades pitch identically: FI0(t) = FI0_BASE + FI0_AMP * sin(FI0DOT*t)
  !   - Use for: Frequency response, flutter analysis, simple actuation
  !
  ! PITCH_MODE = 2: Cyclic (torque smoothing / performance enhancement)
  !   - Blade-specific pitch based on azimuth RELATIVE TO WIND DIRECTION
  !   - θ_rel = blade_azimuth - WIND_DIR
  !   - Downwind (90°<θ_rel<270°): FI0 = FI0_BASE + FI0_AMP (increase AoA)
  !   - Upwind (otherwise):        FI0 = FI0_BASE (baseline)
  !   - Use for: Compensating velocity deficit, reducing torque ripple
  ! ======================================================
  ! *** STEP 1 TEST: Harmonic Pitch at 1P frequency ***
  !PITCH_MODE = 1                     ! Harmonic mode
  !FI0_BASE = 0.0_dp                  ! No mean pitch offset
  !FI0DOT = omega_test                ! Pitch frequency = rotor frequency (1P)
  !FI0_AMP = 5.0_dp * pi / 180.0_dp   ! ±5° pitch amplitude
  !WIND_DIR = 0.0_dp                  ! Wind direction (radians) - 0 = wind from +X axis

  !write(*,*) ''
  !write(*,*) '*** PITCH CONTROL TEST: HARMONIC MODE ***'
  ! *** STEP 0 TEST: Fixed 
  PITCH_MODE = 0                      !Fixed Pitch mode (legacy validation)
  FI0DOT = 0.0_dp                     ! No pitch frequency (fixed pitch)
  FI0_AMP =0.0_dp                     ! ±0° pitch amplitude
  FI0_BASE = 0.0_dp                   ! No mean pitch offset
  WIND_DIR = 0.0_dp 
  FI0 = FI0_BASE
  write(*,*) ''
  !write(*,*) '*** PITCH CONTROL TEST:Static Fixed Pitch Mode ***'
  
  write(*,'(A,I2)')     '  Pitch mode:             ', PITCH_MODE
  write(*,'(A,F6.2,A)') '  Pitch amplitude:        ', FI0_AMP*180.0_dp/pi, ' deg'
  write(*,'(A,F6.3,A)') '  Pitch frequency:        ', FI0DOT, ' rad/s (1P)'
  write(*,*) ''
  write(*,*) '*** STEP 2: PISTOLESI CORRECTIONS ENABLED ***'
  write(*,*) '  USE_ETA_OFFSET = .TRUE.'
  write(*,*) '  - Forces evaluated at c/4 (bound vortex)'
  write(*,*) '  - AoA evaluated at 3c/4 (control point)'
  write(*,*) '  - Accounts for unsteady phase lag'
  write(*,*) '******************************************'
  write(*,*) ''

  ! ============ AERODYNAMIC MODEL OPTIONS ============
  ! USE_ETA_OFFSET controls c/4 vs 3c/4 evaluation point separation
  !   .FALSE. = Legacy mode (both at same point, simpler)
  !   .TRUE.  = Proper thin airfoil theory (more accurate for pitching)
  ! Set to .FALSE. for comparison with old results
  ! ===================================================
  ! *** STEP 2 TEST: Enable Pistolesi c/4 vs 3c/4 corrections ***
  USE_ETA_OFFSET = .true.  ! Proper thin airfoil theory with pitching

  RO = ro_test
  ANY = any_test
  EPS1 = eps_test
  pitchoff = pitchoff_test

  CRANK(1) = 0.0_dp
  CRANK(2) = 120.0_dp * pi / 180.0_dp
  CRANK(3) = 240.0_dp * pi / 180.0_dp

  do i = 1, nol_test + 1
    VIND(i, 1) = uinf_test
    VIND(i, 2) = 0.0_dp
    VIND(i, 3) = 0.0_dp
  end do

  write(*,*) 'Generating blade geometry...'
  call blad(pitchoff)
  write(*,'(A,F7.2,A)') '  Total blade span:       ', sum(DSPAN), ' m'
  write(*,*) ''

  write(*,*) 'Starting VDaRT time-stepping solver...'
  write(*,*) '--------------------------------------'
  ! Option: run continuation sweep over FI0_AMP (warm-start between steps)
  RUN_CONTINUATION = .true.   ! Set to .true. to run FI0_AMP continuation test

  ! By default keep OMEGA constant; set USE_VAR_OMEGA to .true. to enable variable rotor rate
  USE_VAR_OMEGA = .false.

  if (RUN_CONTINUATION) then
    write(*,*) 'Running continuation sweep: FI0_AMP 0 -> 5 deg in 3 steps (warm-start)'
    call continuation_FI0AMP(0.0_dp, 5.0_dp*pi/180.0_dp, 3, krun_test, kmaks_test, eps_test, ares_test)
  else
    call solver_run(krun_test, kmaks_test, eps_test, ares_test, ierr)
  end if

  if (ierr /= 0) then
    write(*,*) 'WARNING: Solver completed with warnings. ierr=', ierr
  else
    write(*,*) ''
    write(*,*) 'Solver completed successfully!'
  end if

  write(*,*) ''
  write(*,*) 'Deallocating memory...'
  call deallocate_state()

  write(*,*) ''
  write(*,*) '========================================='
  write(*,*) '   VDaRT Demo Complete'
  write(*,*) '========================================='
  write(*,*) ''

end program vdart_demo