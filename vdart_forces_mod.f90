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
    real(dp) :: teta_blade, st, ct, fr_global, ft_global

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

        ! Forces in LOCAL blade coordinates (N-C system)
        fn = -0.5_dp * RO * DSPAN(j) * (UREL(i, j)**2) * C * (cl1 * cosa + cd1 * sina)
        fc =  0.5_dp * RO * DSPAN(j) * (UREL(i, j)**2) * C * (cl1 * sina - cd1 * cosa)

        cosb = cos(BETA(j))
        sinb = sin(BETA(j))
        sinfi0 = sin(FI0(i, j))
        cosfi0 = cos(FI0(i, j))

        ! Legacy transformation (uses only FI0, not blade azimuth)
        FR(i, j, IRUN) =  cosfi0 * cosb * fn + fc * sinfi0
        FT(i, j, IRUN) = -sinfi0 * fn * cosb + cosfi0 * fc
        FB(i, j, IRUN) = -sinb * fn

        ! DEBUG: Detailed output for mid-section at end of each revolution
        if (j == NOL/2 .and. (IRUN == 72 .or. IRUN == 144 .or. IRUN == 216 .or. IRUN == 288 .or. IRUN == 360)) then
          teta_blade = real(IRUN, dp) * DTETA + CRANK(i)
          st = sin(teta_blade)
          ct = cos(teta_blade)

          write(*,'(A)') '================================================'
          write(*,'(A,I1,A,I4,A,F8.1,A)') 'FORCES DEBUG: Blade ', i, &
            ' at IRUN=', IRUN, ', theta=', mod(teta_blade*180.0_dp/pi, 360.0_dp), ' deg'
          write(*,'(A,F10.3,A)') '  ALFA = ', ALFA(i,j)*180.0_dp/pi, ' deg'
          write(*,'(A,F10.4,A,F10.4)') '  CL = ', cl1, '  CD = ', cd1
          write(*,'(A,F10.3,A)') '  UREL = ', UREL(i,j), ' m/s'
          write(*,'(A,E14.4,A,E14.4)') '  FN (normal) = ', fn, ' N, FC (chord) = ', fc, ' N'
          write(*,'(A,F10.6,A,F10.6)') '  sin(FI0) = ', sinfi0, ', cos(FI0) = ', cosfi0
          write(*,'(A,E14.4,A,E14.4)') '  FT (legacy) = ', FT(i,j,IRUN), ' N, FR = ', FR(i,j,IRUN), ' N'

          ! What FT SHOULD be if we transform FC properly using blade azimuth
          ! FT_correct = FC projected onto tangential direction
          ! For blade at azimuth θ, tangential direction is (-sin(θ), cos(θ))
          ! Local chord direction is (-sin(θ-FI0), cos(θ-FI0)) approximately
          ! But for zero pitch, FT should equal FC at all azimuths IF FC is computed correctly
          write(*,'(A,F10.4,A,F10.4)') '  sin(theta) = ', st, ', cos(theta) = ', ct
          write(*,'(A)') '================================================'
        end if

        ALFAF(i, j) = ALFA(i, j)
      end do
    end do

  end subroutine forces

end module vdart_forces_mod