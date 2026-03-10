! vdart_kinds_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Define real kinds and common constants (double precision, pi).
! Author: U.S.Paulsen
! Date: 2026-02-24
! SPDX-License-Identifier: MIT

module vdart_kinds_mod
  implicit none
  integer, parameter :: dp = selected_real_kind(15, 307)
  real(dp), parameter :: pi = 3.1415926535897932384626433832795_dp
end module vdart_kinds_mod