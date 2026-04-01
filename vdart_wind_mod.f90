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

    ! First pass: compute UREL at c/4
    eta = C * (0.75_dp - HSTAR)
    eta = 0.0_dp

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
        uvek(i, j, 2) = SWB(i, j, 2) + rz * OMEGA * st1 - fidot * (xi * sf * cb + eta * cf + zeta * sf * sb)
        uvek(i, j, 3) = SWB(i, j, 3)

        uloc(i, j, 1) = -uvek(i, j, 1) * sf * cb + uvek(i, j, 2) * cf * cb - uvek(i, j, 3) * sb
        uloc(i, j, 2) = -uvek(i, j, 1) * cf - uvek(i, j, 2) * sf

        UREL(i, j) = sqrt(uloc(i, j, 1)**2 + uloc(i, j, 2)**2)
      end do
    end do

    uvek = 0.0_dp
    uloc = 0.0_dp

    ! Second pass: compute ALFA at 3c/4
    eta = C * (0.25_dp - HSTAR)
    eta = 0.0_dp

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
        uvek(i, j, 2) = SWB(i, j, 2) + rz * OMEGA * st1 - fidot * (xi * sf * cb + eta * cf + zeta * sf * sb)
        uvek(i, j, 3) = SWB(i, j, 3)

        uloc(i, j, 1) = -uvek(i, j, 1) * sf * cb + uvek(i, j, 2) * cf * cb - uvek(i, j, 3) * sb
        uloc(i, j, 2) = -uvek(i, j, 1) * cf - uvek(i, j, 2) * sf

        t1 = -uloc(i, j, 1)
        t2 = -uloc(i, j, 2)
        ALFA(i, j) = atan2(t1, t2)
		
! DEBUG: Print velocities and ALFA for blade 1, section 12
! In WIND after ALFA calculation:
    if (i==1 .and. j==12 .and. IRUN==18) then
        write(*,*) '=== ALFA DEBUG at IRUN=18 (90°) ==='
        write(*,*) '  TETA1 = ', teta1*180/pi, ' deg'
        write(*,*) '  FI = ', fi*180/pi, ' deg'
        write(*,*) '  ULOC(1) = ', uloc(i,j,1)
        write(*,*) '  ULOC(2) = ', uloc(i,j,2)
        write(*,*) '  T1 = -ULOC(1) = ', -uloc(i,j,1)
        write(*,*) '  T2 = -ULOC(2) = ', -uloc(i,j,2)
        write(*,*) '  ALFA = atan2(T1,T2) = ', alfa(i,j)*180/pi, ' deg'
        write(*,*) '  Expected: ±27 deg'
    end if
! DEBUG end
      end do
    end do

    deallocate(uvek, uloc)

  end subroutine wind

end module vdart_wind_mod