! vdart_wind_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: WIND - compute relative velocity and angle of attack at blade sections.
! Author: U.S.Paulsen
! Date: 2026-02-26
! SPDX-License-Identifier: MIT

module vdart_wind_mod
  use vdart_kinds_mod
  use vdart_state_mod
  implicit none

  public :: wind

contains

  subroutine wind(teta)
    real(dp), intent(in) :: teta

    integer :: i, j, l
    real(dp) :: teta1, st1, ct1, fi, rz, cf, sf, cb, sb
    real(dp) :: xi, eta, zeta, fidot, t1, t2
    real(dp), allocatable :: uvek(:,:,:), uloc(:,:,:)

    if (.not. allocated(SWB) .or. .not. allocated(UREL) .or. .not. allocated(ALFA) .or. .not. allocated(BLSNIT)) then
      write(*,*) 'WIND ERROR: Arrays not allocated. Call allocate_state first.'
      return
    end if

    allocate( uvek(NB, NOL, 3), uloc(NB, NOL, 3) )
    uvek = 0.0_dp
    uloc = 0.0_dp

    xi = 0.0_dp
    zeta = 0.0_dp
    fidot = OMEGA - FI0DOT

    ! =========================================================================
    ! First pass: compute UREL at c/4 (quarter-chord)
    ! =========================================================================
    ! The bound vortex is located at c/4 (HSTAR = 0.75 means 75% from TE = 25% from LE)
    ! ETA is the offset from blade axis to c/4 point in the normal direction
    ! For HSTAR = 0.75: eta = C*(0.75-0.75) = 0 (bound vortex ON blade axis)
    ! If blade axis is at different position, eta ≠ 0
    if (USE_ETA_OFFSET) then
      eta = C * (0.75_dp - HSTAR)
    else
      eta = 0.0_dp   ! Legacy mode: both c/4 and 3c/4 at same point
    end if
    ! Note: For pitching blades (FI0DOT ≠ 0), ETA affects the velocity at c/4
    ! due to the rotational motion about the pitch axis

    do i = 1, NB
      teta1 = teta + CRANK(i)
      st1 = sin(teta1)
      ct1 = cos(teta1)
      do j = 1, NOL
        fi = teta1 - FI0(i, j)
        rz = 0.5_dp * (BLSNIT(1, j, 2) + BLSNIT(1, j+1, 2))
        cf = cos(fi)
        sf = sin(fi)
        cb = cos(BETA(j))
        sb = sin(BETA(j))

        uvek(i, j, 1) = VIND(j, 1) + SWB(i, j, 1) + rz * OMEGA * ct1 - fidot * (xi * cf * cb - eta * sf + zeta * cf * sb)
        uvek(i, j, 2) = VIND(j, 2) + SWB(i, j, 2) + rz * OMEGA * st1 - fidot * (xi * sf * cb + eta * cf + zeta * sf * sb)
        uvek(i, j, 3) = VIND(j, 3) + SWB(i, j, 3)

        uloc(i, j, 1) = -uvek(i, j, 1) * sf * cb + uvek(i, j, 2) * cf * cb - uvek(i, j, 3) * sb
        uloc(i, j, 2) = -uvek(i, j, 1) * cf - uvek(i, j, 2) * sf

        UREL(i, j) = sqrt(uloc(i, j, 1)**2 + uloc(i, j, 2)**2)
      end do
    end do

    uvek = 0.0_dp
    uloc = 0.0_dp

    ! =========================================================================
    ! Second pass: compute ALFA at 3c/4 (three-quarter-chord)
    ! =========================================================================
    ! The control point for thin airfoil theory is at 3c/4 (75% from LE)
    ! This is where the boundary condition (no flow through airfoil) is satisfied
    ! For HSTAR = 0.75: eta = C*(0.25-0.75) = -0.5*C 
    ! (3c/4 is 0.5*C behind the c/4 point, hence negative in eta direction)
    if (USE_ETA_OFFSET) then
      eta = C * (0.25_dp - HSTAR)
    else
      eta = 0.0_dp   ! Legacy mode
    end if

    do i = 1, NB
      teta1 = teta + CRANK(i)
      st1 = sin(teta1)
      ct1 = cos(teta1)
      do j = 1, NOL
        fi = teta1 - FI0(i, j)
        rz = 0.5_dp * (BLSNIT(1, j, 2) + BLSNIT(1, j+1, 2))
        cf = cos(fi)
        sf = sin(fi)
        cb = cos(BETA(j))
        sb = sin(BETA(j))

        uvek(i, j, 1) = VIND(j, 1) + SWB(i, j, 1) + rz * OMEGA * ct1 - fidot * (xi * cf * cb - eta * sf + zeta * cf * sb)
        uvek(i, j, 2) = VIND(j, 2) + SWB(i, j, 2) + rz * OMEGA * st1 - fidot * (xi * sf * cb + eta * cf + zeta * sf * sb)
        uvek(i, j, 3) = VIND(j, 3) + SWB(i, j, 3)

        uloc(i, j, 1) = -uvek(i, j, 1) * sf * cb + uvek(i, j, 2) * cf * cb - uvek(i, j, 3) * sb
        uloc(i, j, 2) = -uvek(i, j, 1) * cf - uvek(i, j, 2) * sf

        t1 = -uloc(i, j, 1)
        t2 = -uloc(i, j, 2)
        ALFA(i, j) = atan2(t1, t2)
		
! DEBUG: Print velocities and ALFA for blade 1, section 6
! In WIND after ALFA calculation:
    if (i==1 .and. j==6 .and. (IRUN==18 .or. IRUN==54)) then
        write(*,*) '=== WIND DEBUG at IRUN=', IRUN, ' ==='
        write(*,*) '  TETA1 = ', teta1*180/pi, ' deg'
        write(*,*) '  rz (radius) = ', rz
        write(*,*) '  VIND(1) = ', VIND(j,1), ' (freestream X)'
        write(*,*) '  SWB(1) = ', SWB(i,j,1), ' (induced X)'
        write(*,*) '  SWB(2) = ', SWB(i,j,2), ' (induced Y)'
        write(*,*) '  SWB(3) = ', SWB(i,j,3), ' (induced Z)'
        write(*,*) '  BETA = ', BETA(j)*180/pi, ' deg (blade cant)'
        write(*,*) '  rz*OMEGA*ct1 = ', rz*OMEGA*ct1, ' (blade vel X)'
        write(*,*) '  rz*OMEGA*st1 = ', rz*OMEGA*st1, ' (blade vel Y)'
        write(*,*) '  UVEK(1) = ', uvek(i,j,1), ' (total X)'
        write(*,*) '  UVEK(2) = ', uvek(i,j,2), ' (total Y)'
        write(*,*) '  UVEK(3) = ', uvek(i,j,3), ' (total Z)'
        write(*,*) '  ULOC(1) = ', uloc(i,j,1), ' (chordwise)'
        write(*,*) '  ULOC(2) = ', uloc(i,j,2), ' (normal)'
        write(*,*) '  -UVEK(3)*SB contrib to ULOC(1) = ', -uvek(i,j,3)*sb
        write(*,*) '  UREL = ', UREL(i,j), ' m/s'
        write(*,*) '  ALFA = ', alfa(i,j)*180/pi, ' deg'
    end if
! DEBUG end
      end do
    end do

    deallocate(uvek, uloc)

  end subroutine wind

end module vdart_wind_mod