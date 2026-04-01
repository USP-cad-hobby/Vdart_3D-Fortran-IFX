! vdart_aero_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Aerodynamics helpers: safe linear interpolation and ideal polar.
! Author: U.S.Paulsen
! Date: 2026-02-24
! SPDX-License-Identifier: MIT

module vdart_aero_mod
  use vdart_kinds_mod
  implicit none
  private
  public :: afinta, clcdideal

contains

  subroutine afinta(alfad, nt, tv, clv, cdv, cla, cda, ierr)
    integer, intent(in) :: nt
    real(dp), intent(in) :: alfad
    real(dp), intent(in) :: tv(nt), clv(nt), cdv(nt)
    real(dp), intent(out) :: cla, cda
    integer, intent(out) :: ierr
    integer :: i
    real(dp) :: x, alfadn

    ierr = 0
    alfadn = abs(alfad)

    if (nt < 2) then
      ierr = 1
      cla = 0.0_dp
      cda = 0.0_dp
      return
    end if

    if (alfadn <= tv(1)) then
      cla = clv(1)
      cda = cdv(1)
      return
    end if
    if (alfadn >= tv(nt)) then
      cla = clv(nt)
      cda = cdv(nt)
      return
    end if

    do i = 1, nt-1
      if (alfadn >= tv(i) .and. alfadn <= tv(i+1)) then
        if (abs(tv(i+1)-tv(i)) < 1.0e-15_dp) then
          x = 0.0_dp
        else
          x = (alfadn - tv(i)) / (tv(i+1) - tv(i))
        end if
        cla = clv(i) + x*(clv(i+1)-clv(i))
        cda = cdv(i) + x*(cdv(i+1)-cdv(i))
        return
      end if
    end do

    ierr = 2
    cla = clv(1)
    cda = cdv(1)
  end subroutine afinta

  subroutine clcdideal(alfad, cll, cdd)
    real(dp), intent(in) :: alfad
    real(dp), intent(out) :: cll, cdd
    real(dp) :: alfab, sina, sin2a

    alfab = abs(alfad)
    sina = sin(alfab*pi/180.0_dp)
    sin2a = sin(2.0_dp*alfab*pi/180.0_dp)

    if (alfab < 172.0_dp) then
      if (alfab < 16.0_dp) then
        cll = 2.0_dp*pi*sina
        cdd = 0.0060_dp
      else
        cll = 1.035_dp * sin2a
        cdd = 0.0060_dp + 1.8_dp*sina*sina
      end if
    else
      cll = -2.0_dp*pi*sina
      cdd = 0.0060_dp
    end if
  end subroutine clcdideal

end module vdart_aero_mod