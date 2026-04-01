! vdart_forces_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: FORCES - compute blade loads from aerodynamics.
! Author: U.S.Paulsen
! Date: 2026-02-27
! SPDX-License-Identifier: MIT

module vdart_forces_mod
  use vdart_kinds_mod
  use vdart_state_mod
  implicit none

  public :: forces

contains

  subroutine forces()
    integer :: i, j
    real(dp) :: cd1, cl1, sina, cosa, fn, fc, cosb, sinb, sinfi0, cosfi0

    if (.not. allocated(FR) .or. .not. allocated(FT) .or. .not. allocated(FB)) then
      write(*,*) 'FORCES ERROR: Force arrays not allocated.'
      return
    end if

    do i = 1, NB
      do j = 1, NOL
        cd1 = CD(i, j)
        cl1 = CL(i, j)

        sina = sin(ALFA(i, j))
        cosa = cos(ALFA(i, j))
        
        fn = -0.5_dp * RO * DSPAN(j) * (UREL(i, j)**2) * C * (cl1 * cosa + cd1 * sina)
        fc =  0.5_dp * RO * DSPAN(j) * (UREL(i, j)**2) * C * (cl1 * sina - cd1 * cosa)
! In FORCES after FC calculation:
        if (i==1 .and. j==12 .and. (IRUN==18 .or. IRUN==54)) then
            write(*,*) '=== FORCES DEBUG at IRUN=', IRUN
            write(*,*) '  ALFA = ', alfa(i,j)*180/pi, ' deg'
            write(*,*) '  CL = ', cl1
            write(*,*) '  CD = ', cd1
            write(*,*) '  sin(ALFA) = ', sina
            write(*,*) '  cos(ALFA) = ', cosa
            write(*,*) '  FN = ', fn, ' N'
            write(*,*) '  FC = ', fc, ' N'
            write(*,*) '  FT = FC = ', fc, ' N'
        end if
        cosb = cos(BETA(j))
        sinb = sin(BETA(j))
        sinfi0 = sin(FI0(i, j))
        cosfi0 = cos(FI0(i, j))

        FR(i, j, IRUN) =  cosfi0 * cosb * fn + fc * sinfi0
        FT(i, j, IRUN) = -sinfi0 * fn * cosb + cosfi0 * fc
        FB(i, j, IRUN) = -sinb * fn

        ALFAF(i, j) = ALFA(i, j)
      end do
    end do

  end subroutine forces

end module vdart_forces_mod