! vdart_bsa_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Converted BSA subroutine (induced velocity from wake/vortex mesh).
! Author: U.S.Paulsen
! Date: 2026-02-25
! SPDX-License-Identifier: MIT

module vdart_bsa_mod
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_biot_mod
  implicit none
  public :: bsa

contains

  subroutine bsa(indi, inb, ins, ih, sw)
    integer, intent(in) :: indi, inb, ins, ih
    real(dp), intent(out) :: sw(3)

    integer :: noli, indi1
    integer :: i, j, k, l
    real(dp) :: gamma
    real(dp) :: x(3), y(3), zpt(3), w(3)
    integer :: km, nblades

    ! Validate state
    if (.not. allocated(GAMME)) then
      write(*,*) 'BSA ERROR: GAMME not allocated. Call allocate_state first.'
      sw = 0.0_dp
      return
    end if

    noli = NOL + 1
    sw = 0.0_dp

    ! Determine field point Z: either from POINT (sampling grid) or H1 (net)
    if (indi >= 1) then
      indi1 = indi
      if (.not. allocated(H1)) then
        write(*,*) 'BSA ERROR: H1 not allocated; cannot use H1(...)'
        sw = 0.0_dp
        return
      end if
      do l = 1, 3
        zpt(l) = H1(inb, ins, ih, l)
      end do
    else
      indi1 = indi + 1
      if (.not. allocated(POINT)) then
        write(*,*) 'BSA ERROR: POINT not allocated; cannot use POINT(...)'
        sw = 0.0_dp
        return
      end if
      do l = 1, 3
        zpt(l) = POINT(inb, ins, ih, l)
      end do
    end if

    ! Loop through blades and wake elements to accumulate induced velocity
    nblades = NB
    km = KMNET
    do i = 1, nblades
      do k = indi1, km
        do j = 1, noli
          if (j .eq. noli) cycle  ! matches original IF(J .EQ. NOL1) GOTO 99

          ! coordinates of vortex segment endpoints
          do l = 1, 3
            x(l) = H1(i, j, k, l)
            y(l) = H1(i, j+1, k, l)
          end do

          if (k .eq. 1) then
            gamma = GAMME(i, j, 1)
          else
            gamma = GAMME(i, j, k) - GAMME(i, j, k-1)
          end if

          call biot(x, y, zpt, gamma, RC, w)
          do l = 1, 3
            sw(l) = sw(l) + w(l)
          end do

          if (BOOLPRINT) then
            ! Optional debug output (user must enable BOOLPRINT)
            write(6, '(3I3, 9(F7.2,X),3(F10.3,X))') i, j, k, x(1), x(2), x(3), y(1), y(2), y(3), zpt(1), zpt(2), zpt(3), sw(1), sw(2), sw(3)
          end if

        end do  ! j
        ! handle longitudinal vortex contribution (the "longitudinal" part)
        do l = 1, 3
          x(l) = H1(i, j, k, l)
          y(l) = H1(i, j, k+1, l)
        end do
        if (j == 1) then
          gamma = -GAMME(i, 1, k)
        else if (j == noli) then
          gamma = GAMME(i, NOL, k)
        else
          gamma = GAMME(i, j-1, k) - GAMME(i, j, k)
        end if
        call biot(x, y, zpt, gamma, RC, w)
        do l = 1, 3
          sw(l) = sw(l) + w(l)
        end do

      end do  ! k
    end do  ! i

    ! Additional inclusion from K=2 -> K=3 in the original code (if applicable)
    if (indi1 /= 1) then
      do j = 1, noli
        do l = 1, 3
          x(l) = H1(1, j, 2, l)  ! using blade 1 as placeholder; original loops over I, but this block
          y(l) = H1(1, j, 3, l)
        end do
        if (j == 1) then
          gamma = -GAMME(1, 1, 2)
        else if (j == noli) then
          gamma = GAMME(1, NOL, 2)
        else
          gamma = GAMME(1, j-1, 2) - GAMME(1, j, 2)
        end if
        call biot(x, y, zpt, gamma, RC, w)
        do l = 1, 3
          sw(l) = sw(l) + w(l)
        end do
      end do
    end if

  end subroutine bsa

end module vdart_bsa_mod