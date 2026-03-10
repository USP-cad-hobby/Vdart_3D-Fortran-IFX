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
          if (gg < EPS1) then
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
    integer :: i, j, iu
    real(dp) :: radius, rx, ry
    
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
    
  end subroutine diagnostic_dump

end module vdart_solver_mod