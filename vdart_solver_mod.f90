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

  subroutine solver_run(krun_in, kmaks_in, eps_conv, ares, ierr)
    integer, intent(in) :: krun_in, kmaks_in
    real(dp), intent(in) :: eps_conv, ares
    integer, intent(out) :: ierr
	real(dp)			 :: teta, theta_blade

    logical :: converged
    real(dp) :: gpert, gpern, gg
    integer :: i, j

    ierr = 0

    if (.not. allocated(GAMME)) then
      write(*,*) 'ERROR: State not allocated. Call allocate_state first.'
      ierr = 1
      return
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
    converged = .false.

    do while (.not. converged .and. IRUN < KMAKS)

      call nethas()

      IRUN = IRUN + 1

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

      end select

      ! --------------------------------------------------------------------
      ! Compute per-section pitch rate FIDOT(i,j) = dFI0/dt for diagnostics
      ! and to be used by WIND. Use backward difference: (FI0_new - FI0_old)/DT
      ! Update FI0_old after computing FIDOT so history is preserved for next
      ! timestep. DT must be set in main before calling solver_run.
      ! --------------------------------------------------------------------
      if (allocated(FIDOT) .and. allocated(FI0_old)) then
        do i = 1, NB
          do j = 1, NOL
            FIDOT(i, j) = (FI0(i, j) - FI0_old(i, j)) / DT
          end do
        end do
        ! Refresh history for next timestep
        FI0_old = FI0
      end if
      if (mod(IRUN, 10) == 0 .or. IRUN <= 5) then
        write(*,'(A,I5,A,F8.2,A)') '  Step ', IRUN, '  Azimuth: ', IRUN*DTETA*180.0_dp/pi, ' deg'
      end if

      call flyt()

      call vortex_iterate(ares, ierr=ierr)
      if (ierr /= 0) then
        write(*,*) 'WARNING: VORTEX iteration did not fully converge at IRUN=', IRUN
      end if

      call forces()

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

end module vdart_solver_mod