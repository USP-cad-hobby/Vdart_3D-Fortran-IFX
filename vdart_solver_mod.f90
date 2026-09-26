! vdart_solver_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Main solver orchestration - time-stepping loop.
! Author: U.S.Paulsen
! Date: 2026-02-28
! SPDX-License-Identifier: MIT

module vdart_solver_mod
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_start_mod
  use vdart_nethas_mod
  use vdart_flyt_mod
  use vdart_vortex_mod
  use vdart_forces_mod
  implicit none

  public :: solver_run

contains

  subroutine solver_run(krun_in, kmaks_in, eps_conv, ares, ierr, warm_start, state_file, mean_torque, rel_rms_out, rel_harm_out)
    integer, intent(in) :: krun_in, kmaks_in
    real(dp), intent(in) :: eps_conv, ares
    integer, intent(out) :: ierr
    logical, intent(in), optional :: warm_start
    character(len=*), intent(in), optional :: state_file
    real(dp), intent(out), optional :: mean_torque
    real(dp), intent(out), optional :: rel_rms_out
    real(dp), intent(out), optional :: rel_harm_out
    real(dp)                :: teta, theta_blade

    logical :: converged
    real(dp) :: gpert, gpern, gg
    integer :: i, j, l
    real(dp), allocatable :: torque_history(:)
    real(dp), allocatable :: prev_torque_history(:)
    real(dp) :: dFI0_dt_global, time_now
    integer :: rev_counter
    real(dp) :: mean_torque_local, rel_change, tol_period, denom
    real(dp) :: tol_rms, tol_harm, cur_harm_mag, prev_harm_mag, rel_harm
    integer :: iu2, ierr2

    ierr = 0
    write(*,*) 'DEBUG: Entered solver_run, IRUN=', IRUN
    if (present(warm_start)) then
      write(*,*) 'DEBUG: warm_start arg present, value=', warm_start
    else
      write(*,*) 'DEBUG: warm_start arg not present'
    end if
    ! If warm_start requested, optionally load saved state
    if (present(warm_start)) then
      if (warm_start) then
        if (present(state_file)) then
          call load_state(state_file, ierr)
          if (ierr /= 0) then
            write(*,*) 'ERROR: Failed to load warm-start state from ', state_file
            return
          end if
        end if
        write(*,*) 'Warm-start: using existing state. IRUN=', IRUN
      else
        ! warm_start present but false -> continue with normal init
        if (.not. allocated(GAMME)) then
          write(*,*) 'ERROR: State not allocated. Call allocate_state first.'
          ierr = 1
          return
        else
          write(*,*) 'DEBUG: GAMME allocated OK. NB,NOL,KMNET=', NB, NOL, KMNET
        end if

        EPS1 = eps_conv
        KMAKS = kmaks_in
        IRUN = 0
        IR = int(2.0_dp * pi / DTETA)
        NPSI = IR + 1

        write(*,*) 'Initializing vortex mesh (START)...'
        call start(.false., ierr)
        if (ierr /= 0) then
          write(*,*) 'ERROR: START failed. ierr=', ierr
          return
        end if

        write(*,*) 'Starting time-stepping loop...'
        write(*,'(A,I4,A)') '  Steps per revolution (IR): ', IR
      end if
    else
      write(*,*) 'DEBUG: allocated(GAMME)=', allocated(GAMME)
      if (.not. allocated(GAMME)) then
        write(*,*) 'ERROR: State not allocated. Call allocate_state first.'
        ierr = 1
        return
      else
        write(*,*) 'DEBUG: GAMME allocated OK. NB,NOL,KMNET=', NB, NOL, KMNET
      end if

      EPS1 = eps_conv
      KMAKS = kmaks_in
      IRUN = 0
      IR = int(2.0_dp * pi / DTETA)
      NPSI = IR + 1

      write(*,*) 'Initializing vortex mesh (START)...'
      call start(.false., ierr)
      if (ierr /= 0) then
        write(*,*) 'ERROR: START failed. ierr=', ierr
        return
      end if

      write(*,*) 'Starting time-stepping loop...'
      write(*,'(A,I4,A)') '  Steps per revolution (IR): ', IR
    end if
    converged = .false.

    ! Initialize buffer for torque history per revolution (for periodicity monitoring)
    allocate(torque_history(IR), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate torque_history'
      ierr = 2
      return
    end if
    torque_history = 0.0_dp

    ! Allocate storage for previous-revolution torque to detect periodicity
    rev_counter = 0
    tol_period = 1.0E-3_dp
    tol_rms = 1.0E-3_dp
    tol_harm = 1.0E-3_dp
    prev_harm_mag = 0.0_dp
    ierr2 = 0
    allocate(prev_torque_history(IR), stat=ierr2)
    if (ierr2 /= 0) then
      write(*,*) 'WARNING: Failed to allocate prev_torque_history; periodicity monitor disabled.'
      if (allocated(prev_torque_history)) deallocate(prev_torque_history)
    else
      prev_torque_history = 0.0_dp
    end if

    ! Initialize simulation time (account for warm-start IRUN)
    if (IRUN > 0) then
      time_now = real(IRUN, dp) * DT
    else
      time_now = 0.0_dp
    end if

    do while (.not. converged .and. IRUN < KMAKS)

      call nethas()

      IRUN = IRUN + 1

      ! Optionally update instantaneous rotor rate and time step (variable OMEGA)
      ! Use module-level USE_VAR_OMEGA flag (PRESENT() is invalid for module variables)
      if (USE_VAR_OMEGA) then
        if (OMEGA <= 1.0E-12_dp) then
          OMEGA = max(OMEGA, 1.0E-8_dp)
        end if
        DT = DTETA / OMEGA
      end if
      ! Advance simulation time by this DT (may be unchanged if variable OMEGA disabled)
      time_now = time_now + DT

      ! ========================================================================
      ! PITCH CONTROL ACTUATION
      ! ========================================================================
      ! This block updates FI0(i,j) for each blade i and section j based on
      ! the selected PITCH_MODE. FI0 is the blade pitch angle offset used by
      ! the aerodynamics (vdart_wind_mod) to compute angle of attack.
      !
      ! Timing: Pitch is updated AFTER IRUN increment so that the new pitch
      ! value is synchronized with the current timestep (legacy behavior).
      !
      ! Modes:
      !   0 = Fixed pitch:    FI0 = FI0_BASE (constant, no active control)
      !   1 = Harmonic pitch: FI0 = FI0_BASE + FI0_AMP * sin(FI0DOT * t)
      !   2 = Cyclic pitch:   FI0 varies with blade azimuth position
      ! ========================================================================
      select case (PITCH_MODE)

      case (0)
        ! --------------------------------------------------------------------
        ! MODE 0: FIXED PITCH (No Active Control)
        ! --------------------------------------------------------------------
        ! All blades maintain a constant pitch offset equal to FI0_BASE.
        ! This is the baseline configuration for validation against legacy
        ! codes and for rotors without pitch actuation.
        ! --------------------------------------------------------------------
        do i = 1, NB
          do j = 1, NOL
            FI0(i, j) = FI0_BASE
          end do
        end do

      case (1)
        ! --------------------------------------------------------------------
        ! MODE 1: HARMONIC PITCH (Time-Varying, All Blades Identical)
        ! --------------------------------------------------------------------
        ! All blades pitch identically following a sinusoidal function:
        !   FI0(t) = FI0_BASE + FI0_AMP * sin(FI0DOT * t)
        ! where t = DT * IRUN is the current simulation time.
        !
        ! Use cases:
        !   - Frequency response analysis
        !   - Flutter / aeroelastic stability testing
        !   - Simple collective pitch actuation
        !
        ! Parameters:
        !   FI0_BASE = baseline pitch offset [rad]
        !   FI0_AMP  = pitch oscillation amplitude [rad]
        !   FI0DOT   = pitch oscillation frequency [rad/s]
        ! --------------------------------------------------------------------
        do i = 1, NB
          do j = 1, NOL
            FI0(i, j) = FI0_BASE + FI0_AMP * sin(FI0DOT * DT * real(IRUN, dp))
          end do
        end do

      case (2)
        ! --------------------------------------------------------------------
        ! MODE 2: CYCLIC PITCH (Azimuth-Dependent, Blade-Specific)
        ! --------------------------------------------------------------------
        ! Each blade's pitch depends on its azimuth position RELATIVE TO WIND:
        !   - θ_rel = blade azimuth - WIND_DIR (blade position vs wind direction)
        !   - Downwind (90° < θ_rel < 270°): FI0 = FI0_BASE + FI0_AMP
        !   - Upwind   (otherwise):          FI0 = FI0_BASE
        !
        ! Downwind detection uses sin(θ_rel) < 0, which is true when
        ! the blade is in the rear half relative to the wind (wake region).
        !
        ! Use cases:
        !   - Torque ripple reduction
        !   - Compensating for velocity deficit in the downwind pass
        !   - Performance optimization for VAWTs
        !
        ! Parameters:
        !   FI0_BASE = baseline pitch (used upwind) [rad]
        !   FI0_AMP  = additional pitch increment (added downwind) [rad]
        !   WIND_DIR = wind direction angle [rad] (0 = +X axis)
        ! --------------------------------------------------------------------
        teta = real(IRUN, dp) * DTETA
        do i = 1, NB
          theta_blade = teta + CRANK(i) - WIND_DIR  ! Relative to wind direction

          ! Downwind detection: sin(θ_rel) < 0 means 90° < θ_rel < 270°
          if (sin(theta_blade) < 0.0_dp) then
            ! Downwind pass: increase pitch to compensate for velocity deficit
            do j = 1, NOL
              FI0(i, j) = FI0_BASE + FI0_AMP
            end do
          else
            ! Upwind pass: use baseline pitch
            do j = 1, NOL
              FI0(i, j) = FI0_BASE
            end do
          end if
        end do

      case default
        ! Invalid mode - should not happen if main.f90 is configured correctly
        write(*,*) 'ERROR: Invalid PITCH_MODE =', PITCH_MODE
        write(*,*) '       Valid values are 0 (fixed), 1 (harmonic), 2 (cyclic).'
        ierr = 99
        return
      case (3)
        ! --------------------------------------------------------------------
        ! MODE 3: PHASED PER-BLADE FIXED OFFSET
        ! --------------------------------------------------------------------
        ! Use a phased pattern across blades: alternate +FI0_BASE and -FI0_BASE
        ! (effectively a 180-degree phase shift between adjacent blades).
        do i = 1, NB
          do j = 1, NOL
            if (mod(i,2) == 0) then
              FI0(i, j) = -FI0_BASE
            else
              FI0(i, j) = FI0_BASE
            end if
          end do
        end do

      case default
        ! Invalid mode - should not happen if main.f90 is configured correctly
        write(*,*) 'ERROR: Invalid PITCH_MODE =', PITCH_MODE
        write(*,*) '       Valid values are 0 (fixed), 1 (harmonic), 2 (cyclic), 3 (phased) .'
        ierr = 99
        return
      end select

      ! --------------------------------------------------------------------
      ! Compute per-section pitch rate FIDOT(i,j) = dFI0/dt for diagnostics
      ! and to be used by WIND. Use a GLOBAL analytical/zero derivative
      ! depending on PITCH_MODE to avoid noisy per-section finite-differences
      ! for cyclic/step changes. For harmonic mode use analytic derivative:
      !   d/dt FI0 = FI0_AMP * FI0DOT * cos(FI0DOT * t)
      ! For fixed or cyclic modes we set derivative to zero (instantaneous
      ! step changes handled as zero-rate except at discontinuities).
      ! --------------------------------------------------------------------
      if (allocated(FIDOT)) then
        if (PITCH_MODE == 1) then
          time_now = DT * real(IRUN, dp)
          dFI0_dt_global = FI0_AMP * FI0DOT * cos(FI0DOT * time_now)
        else
          dFI0_dt_global = 0.0_dp
        end if

        do i = 1, NB
          do j = 1, NOL
            FIDOT(i, j) = dFI0_dt_global
          end do
        end do
      end if

      ! Refresh FI0_old for any diagnostics that rely on it
      if (allocated(FI0_old)) FI0_old = FI0
      if (mod(IRUN, 10) == 0 .or. IRUN <= 5) then
        write(*,'(A,I5,A,F8.2,A)') '  Step ', IRUN, '  Azimuth: ', IRUN*DTETA*180.0_dp/pi, ' deg'
      end if

      call flyt()

      call vortex_iterate(ares, ierr=ierr)
      if (ierr /= 0) then
        write(*,*) 'WARNING: VORTEX iteration did not fully converge at IRUN=', IRUN
      end if

      call forces()

      ! Collect per-azimuth torque over the last full revolution for periodicity checks
      if (mod(IRUN, IR) == 0) then
        torque_history = 0.0_dp
        do l = max(1, IRUN - IR + 1), IRUN
          do i = 1, NB
            do j = 1, NOL
              torque_history(l - max(1, IRUN - IR + 1) + 1) = &
                torque_history(l - max(1, IRUN - IR + 1) + 1) + &
                FT(i, j, l) * (BLSNIT(1, j, 2) + BLSNIT(1, j+1, 2)) * 0.5_dp
            end do
          end do
        end do
        ! torque_history now holds torque vs azimuth for the latest revolution
        rev_counter = rev_counter + 1
        if (allocated(prev_torque_history)) then
          ! Compute mean torque for this revolution
          mean_torque_local = 0.0_dp
          do l = 1, IR
            mean_torque_local = mean_torque_local + torque_history(l)
          end do
          mean_torque_local = mean_torque_local / real(IR, dp)

          if (rev_counter > 1) then
            ! Normalized RMS difference between revolutions
            denom = 0.0_dp
            rel_change = 0.0_dp
            do l = 1, IR
              rel_change = rel_change + (torque_history(l) - prev_torque_history(l))**2
              denom = denom + prev_torque_history(l)**2
            end do
            if (denom <= 0.0_dp) then
              denom = 1.0_dp
            end if
            rel_change = sqrt(rel_change / denom)

            ! 1P harmonic detection (DFT at k=1)
            cur_harm_mag = 0.0_dp
            do l = 1, IR
              cur_harm_mag = cur_harm_mag + torque_history(l) * cos(2.0_dp*pi*(real(l-1,dp))/real(IR,dp))
            end do
            cur_harm_mag = abs(cur_harm_mag) / real(IR, dp)

            if (prev_harm_mag <= 0.0_dp) then
              rel_harm = 1.0_dp
            else
              rel_harm = abs(cur_harm_mag - prev_harm_mag) / prev_harm_mag
            end if

            ! Report computed metrics
            if (present(rel_rms_out)) then
              rel_rms_out = rel_change
            end if
            if (present(rel_harm_out)) then
              rel_harm_out = rel_harm
            end if

            write(*,'(A,F8.6,A,F8.6)') '  rev_metrics: rel_rms=', rel_change, '  rel_harm=', rel_harm

            ! If both RMS and harmonic changes are below tolerance and past krun, consider periodic
            if (rel_change < tol_rms .and. rel_harm < tol_harm .and. IRUN > krun_in) then
              write(*,'(A,F8.6,A,F8.6)') 'Periodicity detected (rms,1P)=', rel_change, rel_harm
              converged = .true.
            end if
          end if

          prev_torque_history = torque_history
          prev_harm_mag = cur_harm_mag
        end if
      end if

      if (IRUN > krun_in) then
        gpert = 0.0_dp
        gpern = 0.0_dp
        do i = 1, NB
          do j = 1, NOL
            gpert = max(abs(GAMME(i, j, 1) - GAMME(i, j, NPSI)), gpert)
            gpern = max(abs(GAMME(i, j, 1)), gpern)
          end do
        end do

        if (gpern > 0.0_dp) then
          gg = gpert / gpern
          ! Report convergence status but DON'T stop early - run full revolutions
          if (mod(IRUN, IR) == 0) then
            write(*,'(A,I5,A,E12.4)') '  Rev ', IRUN/IR, ' periodic GG=', gg
          end if
          if (gg < EPS1 .and. IRUN >= kmaks_in) then
            write(*,'(A,I5,A,E12.4)') '  Converged at IRUN=', IRUN, '  GG=', gg
            converged = .true.
          end if
        end if
      end if

    end do

    if (.not. converged) then
      write(*,*) 'WARNING: Maximum iterations reached without convergence.'
    end if

    write(*,*) 'Time-stepping complete. IRUN=', IRUN
    write(*,*) 'Computing final statistics...'
    ! Compute mean torque over last revolution if available
    mean_torque = 0.0_dp
    if (allocated(torque_history)) then
      mean_torque = 0.0_dp
      do l = 1, size(torque_history)
        mean_torque = mean_torque + torque_history(l)
      end do
      mean_torque = mean_torque / real(size(torque_history), dp)
    end if
    if (present(mean_torque)) then
      mean_torque = mean_torque
    end if
    call output_summary()
    call diagnostic_dump()

  end subroutine solver_run

  subroutine output_summary()
    integer :: i, j, l, nrev
    real(dp) :: tsum, tmean, cp, aref, radius
    real(dp) :: ft_sum, ft_avg, ravg, ry_ref

    write(*,*) ''
    write(*,*) '========================================='
    write(*,*) '  VDaRT Simulation Summary'
    write(*,*) '========================================='
    write(*,*) '  Total time steps:      ', IRUN
    write(*,*) '  Number of blades:      ', NB
    write(*,*) '  Number of sections:    ', NOL
    write(*,*) '  Mesh size (KMNET):     ', KMNET
    write(*,'(A,I6)')     '  Steps per revolution:  ', IR
    
    nrev = IRUN / IR
    write(*,'(A,I6)')     '  Complete revolutions:  ', nrev
    write(*,*) '========================================='

    if (IRUN > 0 .and. IR > 0) then
      tsum = 0.0_dp
      ft_sum = 0.0_dp
      aref = 0.0_dp
      
      ! Compute swept area (legacy formula: trapezoidal integration)
      do j = 1, NOL
        aref = aref + (BLSNIT(1, j, 2) + BLSNIT(1, j+1, 2)) * &
                     (BLSNIT(1, j+1, 3) - BLSNIT(1, j, 3))
      end do
      
      ! Average torque over last complete revolution
      ! LEGACY FORMULA: Torque = Σ FT(i,j) * Y_blade1(j)
      do l = max(1, IRUN - IR + 1), IRUN
        do i = 1, NB
          do j = 1, NOL
            ! Reference Y from blade 1 (master) - ALWAYS use blade 1!
            ry_ref = (BLSNIT(1, j, 2) + BLSNIT(1, j+1, 2)) * 0.5_dp
            
            ! Torque = FT × reference Y-radius
            tsum = tsum + FT(i, j, l) * ry_ref
            ft_sum = ft_sum + FT(i, j, l)
          end do
        end do
      end do
      
      ! Mean values per timestep
      tmean = tsum / real(min(IRUN, IR), dp)
      ft_avg = ft_sum / real(NB * NOL * min(IRUN, IR), dp)
      
      ! Nominal radius (blade 1 reference)
      ravg = (BLSNIT(1, NOL/2, 2) + BLSNIT(1, NOL/2+1, 2)) * 0.5_dp
      
      write(*,'(A,F8.2,A)') '  Blade radius (nominal): ', ravg, ' m'
      write(*,'(A,F10.2,A)') '  Swept area (integ):     ', aref, ' m²'
      write(*,'(A,E12.4,A)') '  Avg tangential force:   ', ft_avg, ' N'
      
      ! Power coefficient
      if (UINF > 0.0_dp .and. aref > 0.0_dp) then
        cp = tmean * OMEGA / (0.5_dp * RO * (UINF**3) * aref)
        write(*,'(A,F10.5)') '  Power coefficient (CP): ', cp
      end if
      
      write(*,'(A,E14.6,A)') '  Mean torque:            ', tmean, ' Nm'
      write(*,'(A,F14.1,A)') '  Mean power:             ', tmean * OMEGA / 1000.0_dp, ' kW'
      
      if (tmean < 0.0_dp) then
        write(*,*) ''
        write(*,*) '  WARNING: Negative torque detected!'
        write(*,*) '  Likely cause: startup transient (run more revolutions)'
      end if
    end if

    write(*,*) '========================================='

  end subroutine output_summary
  
  subroutine diagnostic_dump()
    integer :: i, j, l, iu
    real(dp) :: radius, rx, ry, torque_step, azimuth_deg, ry_ref
    real(dp) :: torque_blade(3)  ! Per-blade torque

    ! =========================================================================
    ! Output 1: Forces by blade section at final timestep
    ! =========================================================================
    open(newunit=iu, file='debug_forces.dat', status='replace')
    write(iu,'(A)') '# Blade Section Radius(2D) FT(last_step) Torque_contrib'

    do i = 1, NB
      do j = 1, NOL
        ! Corrected 2D radius: sqrt(X² + Y²) at element midpoint
        rx = (BLSNIT(i, j, 1) + BLSNIT(i, j+1, 1)) * 0.5_dp
        ry = (BLSNIT(i, j, 2) + BLSNIT(i, j+1, 2)) * 0.5_dp
        radius = sqrt(rx**2 + ry**2)

        write(iu,'(2I5,4E16.6)') i, j, rx, ry, radius, FT(i, j, IRUN), FT(i,j,IRUN)*radius
      end do
    end do

    close(iu)
    write(*,*) 'Debug output written to: debug_forces.dat'

    ! =========================================================================
    ! Output 2: Torque vs Azimuth over last revolution
    ! This is the KEY diagnostic for answering "does FT contribute to power?"
    ! =========================================================================
    open(newunit=iu, file='torque_vs_azimuth.dat', status='replace')
    write(iu,'(A)') '# Azimuth[deg]  Total_Torque[Nm]  Blade1_Torque  Blade2_Torque  Blade3_Torque'

    write(*,*) ''
    write(*,*) '========================================='
    write(*,*) '  Torque vs Azimuth (Last Revolution)'
    write(*,*) '========================================='
    write(*,'(A)') '   Azimuth    Total_Torque    Power_Sign'

    do l = max(1, IRUN - IR + 1), IRUN
      azimuth_deg = real(l, dp) * DTETA * 180.0_dp / pi

      ! Compute total torque and per-blade torque at this timestep
      torque_step = 0.0_dp
      torque_blade = 0.0_dp
      do i = 1, NB
        do j = 1, NOL
          ! Use blade 1 reference radius (legacy convention)
          ry_ref = (BLSNIT(1, j, 2) + BLSNIT(1, j+1, 2)) * 0.5_dp
          torque_step = torque_step + FT(i, j, l) * ry_ref
          torque_blade(i) = torque_blade(i) + FT(i, j, l) * ry_ref
        end do
      end do

      ! Per-blade torque for detailed analysis
      write(iu,'(F8.1,4E16.6)') azimuth_deg, torque_step, &
        torque_blade(1), torque_blade(2), torque_blade(3)

      ! Console output every 30 degrees
      if (mod(l - max(1, IRUN-IR+1), IR/12) == 0 .or. l == IRUN) then
        if (torque_step > 0.0_dp) then
          write(*,'(F8.1,A,E14.4,A)') azimuth_deg, ' deg  ', torque_step, '  (+) EXTRACTING'
        else
          write(*,'(F8.1,A,E14.4,A)') azimuth_deg, ' deg  ', torque_step, '  (-) motoring'
        end if
      end if
    end do

    close(iu)
    write(*,*) '========================================='
    write(*,*) 'Torque data written to: torque_vs_azimuth.dat'

  end subroutine diagnostic_dump

  subroutine continuation_FI0AMP(fi0_start, fi0_stop, fi0_steps, krun_in, kmaks_in, eps_conv, ares)
    real(dp), intent(in) :: fi0_start, fi0_stop
    integer, intent(in) :: fi0_steps, krun_in, kmaks_in
    real(dp), intent(in) :: eps_conv, ares
    integer :: ierr
    integer :: step
    real(dp) :: fi0_val
    character(len=128) :: state_file
    real(dp) :: FI0_AMP_prev
    character(len=32) :: tmpstr
    real(dp) :: mean_tq
    real(dp) :: out_ierr
    character(len=128) :: csv_file
    integer :: csv_unit, openstat

    if (fi0_steps < 1) then
      write(*,*) 'ERROR: fi0_steps must be >= 1'
      return
    end if

    do step = 1, fi0_steps
      fi0_val = fi0_start + (real(step-1, dp) / real(max(1, fi0_steps-1), dp)) * (fi0_stop - fi0_start)
      FI0_AMP = fi0_val
      write(*,'(A,F8.5)') 'Continuation step: FI0_AMP = ', FI0_AMP

      if (step == 1) then
        ! First step: cold start
        call solver_run(krun_in, kmaks_in, eps_conv, ares, ierr, mean_torque=mean_tq, rel_rms_out=out_ierr)
      else
        ! Warm start from previous saved state
        write(tmpstr, '(F6.4)') FI0_AMP_prev
        state_file = 'state_fi0_' // trim(adjustl(tmpstr)) // '.bin'
        call solver_run(krun_in, kmaks_in, eps_conv, ares, ierr, .true., trim(state_file), mean_torque=mean_tq, rel_rms_out=out_ierr)
      end if

      if (ierr /= 0) then
        write(*,'(A,I3)') 'Solver returned error. ierr=', ierr
        return
      end if

      ! Save state for next warm start
      write(tmpstr, '(F6.4)') FI0_AMP
      state_file = 'state_fi0_' // trim(adjustl(tmpstr)) // '.bin'
      call save_state(trim(state_file), ierr)
      if (ierr /= 0) then
        write(*,*) 'WARNING: Failed to save state to ', trim(state_file)
      end if

      ! Log summary line for continuation step
      write(*,'(A,F8.4,A,F12.4)') 'Continuation step FI0_AMP=', FI0_AMP, '  mean_torque=', mean_tq

      ! Append CSV for post-processing
      csv_file = 'continuation_results.csv'
      open(newunit=csv_unit, file=csv_file, status='unknown', action='write', iostat=openstat)
      if (openstat == 0) then
        ! If file newly created, write header
        inquire(unit=csv_unit, size=openstat)
        if (openstat == 0) then
          write(csv_unit,'(A)') 'FI0_AMP_deg,mean_torque_Nm'
        end if
        write(csv_unit,'(F8.4,1X,F12.4)') FI0_AMP*180.0_dp/pi, mean_tq
        close(csv_unit)
      else
        write(*,*) 'WARNING: Could not open CSV file for continuation results.'
      end if

      FI0_AMP_prev = FI0_AMP
    end do

  end subroutine continuation_FI0AMP

end module vdart_solver_mod