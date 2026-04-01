! vdart_blad_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: BLAD - generate blade geometry (section coordinates, span lengths, angles).
! Author: U.S.Paulsen
! Date: 2026-02-27
! SPDX-License-Identifier: MIT

module vdart_blad_mod
  use vdart_kinds_mod
  use vdart_state_mod
  implicit none

  public :: blad

contains

  subroutine blad(pitchoff)
    real(dp), intent(in) :: pitchoff

    integer :: i, j, l, nol1, nol2, shape
    real(dp) :: del, vl2, tanb, offsetpitch, z_val, y_val
    real(dp) :: v(3)

    if (.not. allocated(BLSNIT) .or. .not. allocated(DSPAN) .or. .not. allocated(BETA)) then
      write(*,*) 'BLAD ERROR: Arrays not allocated.'
      return
    end if

    offsetpitch = pitchoff
    nol1 = NOL + 1
    nol2 = NOL - 1

    ! Determine rotor shape
    if (B > -1000.0_dp) then
      shape = 1  ! Straight blade
      write(*,*) '  Shape: STRAIGHT blade (B > -1000)'
    else if (B > -2000.0_dp) then
      shape = 2  ! Parabolic
      write(*,*) '  Shape: PARABOLIC blade'
    else if (B < -3000.0_dp) then
      shape = 3  ! Troposkien
      write(*,*) '  Shape: TROPOSKIEN blade'
    else
      shape = 1
      write(*,*) '  Shape: DEFAULT to straight'
    end if

    ! Bottom section (J=1, Z=0)
    z_val = 0.0_dp
    BLSNIT(1, 1, 1) = 0.0_dp
    BLSNIT(1, 1, 3) = z_val
    if (shape == 1) then
      y_val = A * z_val + B * H0
      BLSNIT(1, 1, 2) = y_val
    else if (shape == 2) then
      BLSNIT(1, 1, 2) = 4.0_dp * A * z_val * (1.0_dp - z_val / H0)
    else
      BLSNIT(1, 1, 3) = RS(1, 1)
      BLSNIT(1, 1, 2) = RS(1, 2)
    end if

    ! Second section (J=2)
    z_val = BSAF * H0 / 3.0_dp
    BLSNIT(1, 2, 3) = z_val
    if (shape == 1) then
      BLSNIT(1, 2, 2) = A * z_val + B * H0
    else if (shape == 2) then
      BLSNIT(1, 2, 2) = 4.0_dp * A * z_val * (1.0_dp - z_val / H0)
    else
      BLSNIT(1, 2, 3) = RS(2, 1)
      BLSNIT(1, 2, 2) = RS(2, 2)
    end if
    BLSNIT(1, 2, 1) = 0.0_dp

    ! Middle sections
    del = H0 * (1.0_dp - 2.0_dp * BSAF) / real(NOL - 4, dp)
    write(*,'(A,F8.3)') '  Section spacing (del): ', del

    do j = 3, nol2
      z_val = BSAF * H0 + del * real(j - 3, dp)
      BLSNIT(1, j, 3) = z_val
      if (shape == 1) then
        BLSNIT(1, j, 2) = A * z_val + B * H0
      else if (shape == 2) then
        BLSNIT(1, j, 2) = 4.0_dp * A * z_val * (1.0_dp - z_val / H0)
      else
        BLSNIT(1, j, 3) = RS(j, 1)
        BLSNIT(1, j, 2) = RS(j, 2)
      end if
      BLSNIT(1, j, 1) = 0.0_dp
    end do

    ! Second-to-last section
    z_val = (1.0_dp - BSAF / 3.0_dp) * H0
    BLSNIT(1, NOL, 3) = z_val
    if (shape == 1) then
      BLSNIT(1, NOL, 2) = A * z_val + B * H0
    else if (shape == 2) then
      BLSNIT(1, NOL, 2) = 4.0_dp * A * z_val * (1.0_dp - z_val / H0)
    else
      BLSNIT(1, NOL, 3) = RS(NOL, 1)
      BLSNIT(1, NOL, 2) = RS(NOL, 2)
    end if
    BLSNIT(1, NOL, 1) = 0.0_dp

    ! Top section
    z_val = H0
    BLSNIT(1, nol1, 3) = z_val
    if (shape == 1) then
      BLSNIT(1, nol1, 2) = A * z_val + B * H0
    else if (shape == 2) then
      BLSNIT(1, nol1, 2) = 0.0_dp
    else
      BLSNIT(1, nol1, 3) = RS(nol1, 1)
      BLSNIT(1, nol1, 2) = RS(nol1, 2)
    end if
    BLSNIT(1, nol1, 1) = 0.0_dp

    write(*,'(A,F8.3,A)') '  Blade root Y: ', BLSNIT(1,1,2), ' m'
    write(*,'(A,F8.3,A)') '  Blade tip Y:  ', BLSNIT(1,nol1,2), ' m'

    ! Compute span lengths and angles
    do j = 1, NOL
      vl2 = 0.0_dp
      do l = 1, 3
        v(l) = BLSNIT(1, j+1, l) - BLSNIT(1, j, l)
        vl2 = vl2 + v(l)**2
      end do
      DSPAN(j) = sqrt(vl2)

      ! Blade angle
      if (abs(BLSNIT(1, j+1, 3) - BLSNIT(1, j, 3)) < 1.0e-10_dp) then
        BETA(j) = 0.0_dp
      else
        tanb = (BLSNIT(1, j+1, 2) - BLSNIT(1, j, 2)) / (BLSNIT(1, j+1, 3) - BLSNIT(1, j, 3))
        BETA(j) = atan(tanb)
      end if

      FI0(1, j) = 0.0_dp + offsetpitch
    end do

    write(*,'(A,F8.3,A)') '  Total span calculated: ', sum(DSPAN), ' m'

    ! Copy to other blades (initial pitch same for all)
    if (NB > 1) then
      do i = 2, NB
        do j = 1, NOL
          FI0(i, j) = FI0(1, j)
        end do
      end do
    end if

    ! Copy blade geometry to other blades
    if (NB > 1) then
      do i = 2, NB
        do j = 1, nol1
          BLSNIT(i, j, 3) = BLSNIT(1, j, 3)
          BLSNIT(i, j, 2) = BLSNIT(1, j, 2) * cos(CRANK(i))
          BLSNIT(i, j, 1) = -BLSNIT(1, j, 2) * sin(CRANK(i))
        end do
      end do
    end if

  end subroutine blad

end module vdart_blad_mod