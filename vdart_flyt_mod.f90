! vdart_flyt_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: FLYT - move vortex positions forward in time using quadratic formula.
! Author: U.S.Paulsen
! Date: 2026-02-26
! SPDX-License-Identifier: MIT

module vdart_flyt_mod
  use vdart_kinds_mod
  use vdart_state_mod
  implicit none

  public :: flyt, renumk

contains

  subroutine flyt()
    integer :: i, j, k, l, nol1
    real(dp) :: teta, eta, xi, zeta, t1, fir, st1, ct1, sf, cf, sb, cb

    if (.not. allocated(H1) .or. .not. allocated(H2) .or. .not. allocated(V1) .or. .not. allocated(V2)) then
      write(*,*) 'FLYT ERROR: Arrays not allocated. Call allocate_state first.'
      return
    end if

    teta = IRUN * DTETA
    nol1 = NOL + 1

    ! Move vortex wake positions (K=3 to KMNET) using quadratic formula
    do k = 3, KMNET
      do i = 1, NB
        do j = 1, nol1
          do l = 1, 3
            H2(i, j, k, l) = H1(i, j, k, l) + (1.5_dp * V2(i, j, k, l) - 0.5_dp * V1(i, j, k, l)) * DT
          end do
        end do
      end do
    end do

    ! Move first shed vortex (K=2, old bound vortex) using first-order
    do i = 1, NB
      do j = 1, nol1
        do l = 1, 3
          H2(i, j, 2, l) = V2(i, j, 2, l) * DT + H1(i, j, 2, l)
        end do
      end do
    end do

    ! Renumber arrays (shift wake downstream)
    call renumk()

    ! Update bound vortex positions on blade (K=1) and velocities
    eta = (1.0_dp - HSTAR - 0.25_dp) * C
    xi = 0.0_dp * C
    zeta = 0.0_dp * C
    eta = 0.0_dp

    do i = 1, NB
      t1 = teta + CRANK(i)
      do j = 1, nol1
        fir = t1 - FI0(j)
        st1 = sin(t1)
        ct1 = cos(t1)
        sf = sin(fir)
        cf = cos(fir)
        sb = sin(BETA(j))
        cb = cos(BETA(j))

        do l = 1, 3
          H1(i, j, 2, l) = V2(i, j, 1, l) * DT + H1(i, j, 1, l)
          V1(i, j, 2, l) = 0.0_dp
          V1(i, j, 1, l) = V2(i, j, 1, l)
        end do

        H1(i, j, 1, 1) = -BLSNIT(1, j, 2) * st1 - xi * sf * cb - eta * cf - zeta * sf * sb
        H1(i, j, 1, 2) =  BLSNIT(1, j, 2) * ct1 - xi * cf * cb - eta * sf - zeta * cf * sb
        H1(i, j, 1, 3) =  BLSNIT(1, j, 3) - xi * sb + zeta * cb
        ! Debug bound vortex position
        if (i == 1 .and. j == 12 .and. IRUN == 18) then
            write(*,'(A)') '=== DEBUG FLYT: Bound vortex at IRUN=18 (90°) ==='
            write(*,'(A,F8.2,A)') '  TETA = ', teta*180.0_dp/pi, ' deg'
            write(*,'(A,3F10.3)') '  H1(1,12,1,:) = ', H1(1,12,1,1), H1(1,12,1,2), H1(1,12,1,3)
            write(*,'(A,F10.3)')  '  Radius BLSNIT = ', BLSNIT(1,12,2)
            write(*,'(A,2F10.6)') '  sin(teta), cos(teta) = ', st1, ct1
            write(*,'(A)') '  Expected: X≈-27, Y≈0'
        end if
      end do
    end do

  end subroutine flyt

  subroutine renumk()
    integer :: i, j, k, k1, l, n, km, nol1

    nol1 = NOL + 1
    km = KMNET - 2

    do i = 1, NB
      do j = 1, nol1
        do n = 1, km
          k = KMNET - n
          k1 = k + 1
          do l = 1, 3
            H1(i, j, k1, l) = H2(i, j, k, l)
            V1(i, j, k1, l) = V2(i, j, k, l)
          end do
          GAMME(i, j, k1) = GAMME(i, j, k)
        end do
        GAMME(i, j, 2) = GAMME(i, j, 1)
      end do
    end do

  end subroutine renumk

end module vdart_flyt_mod