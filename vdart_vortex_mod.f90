! vdart_vortex_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: VORTEX - iterative bound circulation solver with Aitken acceleration.
! Author: U.S.Paulsen
! Date: 2026-02-28
! SPDX-License-Identifier: MIT

module vdart_vortex_mod
  use vdart_kinds_mod
  use vdart_state_mod
  use vdart_aero_mod
  use vdart_bsa_mod
  use vdart_wind_mod
  implicit none

  public :: vortex_iterate

contains

  subroutine vortex_iterate(ares, max_iter, tol, ierr)
    real(dp), intent(in) :: ares
    integer, intent(in), optional :: max_iter
    real(dp), intent(in), optional :: tol
    integer, intent(out) :: ierr

    integer :: it, imax, inb, ins, i, j, l, n, n1, nol1
    real(dp) :: tolv, gmax, gmix, gg, teta, rey
    real(dp), allocatable :: gammet(:,:), swslip(:,:,:)
    real(dp), allocatable :: gamma_old(:,:), gamma_old2(:,:)
    real(dp) :: wslip(3)
    real(dp) :: ares_aitken, denom, delta1, delta2
    logical , parameter :: use_aitken=.false.	! Disable for testing

    ierr = 0
    if (.not. allocated(GAMME)) then
      write(*,*) 'VORTEX ERROR: GAMME not allocated.'
      ierr = 1
      return
    end if

    imax = 9999
    if (present(max_iter)) imax = max_iter
    tolv = EPS1
    if (present(tol)) tolv = tol

    nol1 = NOL + 1
    n = NOL / 2
    n1 = n + 1
    ! Compute azimuthal angle
	teta = real(IRUN, dp) * DTETA   ! DTETA already in radians!

    allocate( gammet(NB, NOL), swslip(NB, NOL+1, 3) )
    allocate( gamma_old(NB, NOL), gamma_old2(NB, NOL) )
    gammet = 0.0_dp
    swslip = 0.0_dp
    gamma_old = 0.0_dp
    gamma_old2 = 0.0_dp
    it = 0

    ! Compute induced velocities from wake
    do inb = 1, NB
      do ins = 1, n1
        call bsa(3, inb, ins, 1, wslip)
        do l = 1, 3
          swslip(inb, ins, l) = wslip(l)
        end do
      end do
    end do

    ! Mirror (symmetry)
    do inb = 1, NB
      do ins = n1, NOL
        do l = 1, 2
          swslip(inb, ins+1, l) = swslip(inb, nol1 - ins, l)
        end do
        swslip(inb, ins+1, 3) = -swslip(inb, nol1 - ins, 3)
      end do
    end do

    ! Average to element centers
    do inb = 1, NB
      do ins = 1, NOL
        do l = 1, 3
          swslip(inb, ins, l) = 0.5_dp * (swslip(inb, ins+1, l) + swslip(inb, ins, l))
          SWB(inb, ins, l) = swslip(inb, ins, l)
        end do
        GAMME(inb, ins, 1) = GAMME(inb, ins, NPSI)
      end do
    end do

    call wind(teta)

    ! Iterative loop
100 continue
    it = it + 1

    ! Save history for Aitken
    gamma_old2 = gamma_old
    gamma_old = gammet
    gammet = GAMME(:,:,1)

    ! Update circulation
    do inb = 1, NB
      do ins = 1, n
        rey = UREL(inb, ins) * C / ANY
        call clcdideal(ALFA(inb, ins) * 180.0_dp / pi, CL(inb, ins), CD(inb, ins))
        GAMME(inb, ins, 1) = 0.5_dp * C * CL(inb, ins) * max(UREL(inb, ins), 0.0_dp)
      end do
    end do

    ! Mirror
    do inb = 1, NB
      do ins = n1, NOL
        gammet(inb, ins) = gammet(inb, nol1 - ins)
        GAMME(inb, ins, 1) = GAMME(inb, nol1 - ins, 1)
        CL(inb, ins) = CL(inb, nol1 - ins)
        CD(inb, ins) = CD(inb, nol1 - ins)
      end do
    end do

    ! Check convergence
    gmax = 0.0_dp
    gmix = 0.0_dp
    do inb = 1, NB
      do ins = 1, n
        gmax = max(abs(GAMME(inb, ins, 1)), gmax)
        gmix = max(abs(GAMME(inb, ins, 1) - gammet(inb, ins)), gmix)
      end do
    end do

    if (gmax <= 0.0_dp) then
      ierr = 0
      deallocate(gammet, swslip, gamma_old, gamma_old2)
      return
    end if

    gg = abs(gmix / gmax)
    if (gg < tolv) then
      ierr = 0
      deallocate(gammet, swslip, gamma_old, gamma_old2)
      return
    end if

    if (it >= imax) then
      write(*,*) 'VORTEX WARNING: max iterations ', it, ' GG=', gg
      ierr = 2
      deallocate(gammet, swslip, gamma_old, gamma_old2)
      return
    end if

    ! Aitken acceleration (after 3rd iteration when we have history)
    !use_aitken = (it >= 3)		! Testing purpose on convergence issue Delete the assignment line - not needed with parameter
    ! ==================== ADD THIS DIAGNOSTIC ====================
    if (mod(it, 50) == 0 .or. it <= 3) then
      write(*,'(A,I4,A,E12.4,A,E12.4)') '    Vortex iter ', it, '  GG=', gg, '  GMAX=', gmax
    end if
    ! =============================================================
  
    if (use_aitken) then
      ! Aitken delta-squared method
      ! Compute typical magnitude for safe division
      do i = 1, NB
        do j = 1, NOL
          delta1 = gammet(i,j) - gamma_old(i,j)
          delta2 = gamma_old(i,j) - gamma_old2(i,j)
          denom = delta1**2 - delta2 * (gammet(i,j) - gamma_old2(i,j))
          
          if (abs(denom) > 1.0e-12_dp * gmax) then
            ! Aitken's formula for optimal relaxation
            ares_aitken = abs(delta1**2 / denom)
            ! Clamp to safe range [0.1, 0.95]
            ares_aitken = max(0.1_dp, min(0.95_dp, ares_aitken))
          else
            ! Fallback to fixed under-relaxation
            ares_aitken = ares
          end if
          
          ! Apply Aitken-accelerated relaxation
          GAMME(i, j, 1) = ares_aitken * GAMME(i, j, 1) + (1.0_dp - ares_aitken) * gammet(i, j)
        end do
      end do
    else
      ! First few iterations: use fixed under-relaxation
      do i = 1, NB
        do j = 1, NOL
          GAMME(i, j, 1) = ares * GAMME(i, j, 1) + (1.0_dp - ares) * gammet(i, j)
        end do
      end do
    end if

    goto 100

  end subroutine vortex_iterate

end module vdart_vortex_mod