! test_vortex.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Smoke test for vortex_iterate using minimal seeded state.
! Author: U.S.Paulsen
! Date: 2026-02-24
! SPDX-License-Identifier: MIT

program test_vortex
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_vortex_mod
  implicit none
  integer :: ierr

  call allocate_state(3, 8, 32, ierr)
  if (ierr /= 0) then
    write(*,*) 'allocate_state failed with', ierr
    stop 1
  end if

  C = 1.0_dp
  UREL = 5.0_dp
  ALFA = 5.0_dp * (pi/180.0_dp)  ! 5 degrees in radians

  call vortex_iterate(0.5_dp, max_iter=200, tol=1.0e-7_dp, ierr=ierr)
  if (ierr /= 0) then
    write(*,*) 'vortex_iterate returned error', ierr
  else
    write(*,*) 'vortex_iterate completed successfully.'
  end if

  call deallocate_state()

end program test_vortex