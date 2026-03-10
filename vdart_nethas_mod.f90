! vdart_nethas_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: NETHAS - compute induced velocities at all vortex mesh points.
! Author: U.S.Paulsen
! Date: 2026-02-26
! SPDX-License-Identifier: MIT

module vdart_nethas_mod
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_bsa_mod
  implicit none
  public :: nethas

contains

  subroutine nethas()
    ! Computes local velocities for all vortex mesh points in the wake
    ! by calling BSA and overlaying with freestream velocity VIND.
    ! Uses symmetry around the mid-axis (index N) to fill the upper half.

    integer :: i, j, k, l, n, nol1
    real(dp) :: sw(3)

    ! Validate state
    if (.not. allocated(H1)) then
      write(*,*) 'NETHAS ERROR: H1 not allocated. Call allocate_state first.'
      return
    end if
    if (.not. allocated(V2)) then
      write(*,*) 'NETHAS ERROR: V2 not allocated. Call allocate_state first.'
      return
    end if
    if (.not. allocated(VIND)) then
      write(*,*) 'NETHAS ERROR: VIND not allocated. Call allocate_state first.'
      return
    end if

    nol1 = NOL + 1
    n = NOL / 2 + 1

    ! Compute local velocity at vortex nodes in wake (first half by symmetry)
    do i = 1, NB
      do j = 1, n
        do k = 1, KMNET
          ! Call BSA with INDI=1 (use H1 for field point coordinates)
          call bsa(1, i, j, k, sw)
          ! Add freestream velocity
          do l = 1, 3
            V2(i, j, k, l) = sw(l) + VIND(j, l)
          end do
        end do
      end do
    end do

    ! Mirror around mid-axis (symmetry: upper half = reflection of lower half)
    do i = 1, NB
      do j = n, NOL
        do k = 1, KMNET
          ! Mirror x,y components
          do l = 1, 2
            V2(i, j+1, k, l) = V2(i, nol1 - j, k, l)
          end do
          ! Invert z component
          V2(i, j+1, k, 3) = -V2(i, nol1 - j, k, 3)
        end do
      end do
    end do

  end subroutine nethas

end module vdart_nethas_mod