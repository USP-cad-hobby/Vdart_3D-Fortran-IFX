! vdart_start_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: START - initialize vortex mesh backward in time from t=0.
! Author: U.S.Paulsen
! Date: 2026-02-26
! SPDX-License-Identifier: MIT

module vdart_start_mod
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_aero_mod
  use vdart_wind_mod
  implicit none

  public :: start

contains

  subroutine start(use_clcd_table, ierr)
    logical, intent(in), optional :: use_clcd_table
    integer, intent(out) :: ierr

    integer :: i, j, k, l, nol1, io
    real(dp) :: teta, t1, ct, st, fir, sf, cf, cb, sb
    real(dp) :: xi, eta, zeta, rey
    logical :: use_table

    ierr = 0
    use_table = .false.
    if (present(use_clcd_table)) use_table = use_clcd_table

    if (.not. allocated(H1) .or. .not. allocated(V1) .or. .not. allocated(GAMME)) then
      write(*,*) 'START ERROR: Arrays not allocated. Call allocate_state first.'
      ierr = 1
      return
    end if

    ! Control point offsets on chord
    xi = 0.0_dp * C
    eta = (0.75_dp - HSTAR) * C
    eta = 0.0_dp  ! simplified (matches legacy)
    zeta = 0.0_dp * C

    ! Optional file output for debugging
    open(11, file='HPOS.DAT', status='replace', iostat=io)
    if (io /= 0) then
      write(*,*) 'START WARNING: Cannot open HPOS.DAT for writing (IOSTAT=', io, ')'
    end if

    nol1 = NOL + 1

    ! Build vortex mesh backward in time from t=0
    do k = 1, KMNET
      teta = real(1 - k, dp) * DTETA  ! negative time step

      do i = 1, NB
        t1 = teta + CRANK(i)
        ct = cos(t1)
        st = sin(t1)

        do j = 1, nol1
          fir = t1 + FI0(j)  ! note: + instead of - (backward time)
          sf = sin(fir)
          cf = cos(fir)
          cb = cos(BETA(j))
          sb = sin(BETA(j))

          ! Set vortex positions backward in time (convected by freestream)
          H1(i, j, k, 1) = VIND(j, 1) * real(k - 1, dp) * DT &
                           - BLSNIT(1, j, 2) * st &
                           - xi * sf * cb - eta * cf - zeta * sf * sb
          H1(i, j, k, 2) = BLSNIT(1, j, 2) * ct &
                           + xi * cf * cb - eta * sf + zeta * cf * sb
          H1(i, j, k, 3) = BLSNIT(1, j, 3) - xi * sb + zeta * cb

          ! Debug output (middle section, blade 2)
          if (io == 0 .and. j == NOL/2 .and. i == 2) then
            write(11, '(3(I3,1X),4(F8.3,1X))') i, j, k, teta, H1(i, j, k, 1), H1(i, j, k, 2), H1(i, j, k, 3)
          end if

          ! Initialize velocities to freestream
          do l = 1, 3
            V1(i, j, k, l) = VIND(j, l)
          end do
        end do
      end do

      ! Initialize SWB (induced velocity) to zero for this time step
      do i = 1, NB
        do j = 1, NOL
          do l = 1, 3
            SWB(i, j, l) = 0.0_dp
          end do
        end do
      end do

      ! Compute relative velocity and angle of attack at this backward time step
      call wind(teta)

      ! Compute circulation at each blade section for this time step
      do i = 1, NB
        do j = 1, NOL
          rey = UREL(i, j) * C / ANY

          if (use_table) then
            ! Use full CLCD table (not implemented yet — placeholder)
            write(*,*) 'START WARNING: CLCD table not yet implemented, using ideal polar.'
            call clcdideal(ALFA(i, j) * 180.0_dp / pi, CL(i, j), CD(i, j))
          else
            ! Use ideal polar
            call clcdideal(ALFA(i, j) * 180.0_dp / pi, CL(i, j), CD(i, j))
          end if

          GAMME(i, j, k) = 0.5_dp * C * CL(i, j) * UREL(i, j)
          ALFAF(i, j) = ALFA(i, j)
        end do
      end do

    end do

    if (io == 0) close(11)

  end subroutine start

end module vdart_start_mod