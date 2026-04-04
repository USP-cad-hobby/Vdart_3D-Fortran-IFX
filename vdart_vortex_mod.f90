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
  use vdart_biot_mod    ! Added for direct Biot-Savart calls in inner loop
  use vdart_wind_mod
  implicit none

  public :: vortex_iterate

contains

  subroutine vortex_iterate(ares, max_iter, tol, ierr)
    real(dp), intent(in) :: ares
    integer, intent(in), optional :: max_iter
    real(dp), intent(in), optional :: tol
    integer, intent(out) :: ierr

    integer :: it, imax, inb, ins, i, j, k, l, n, n1, nol1
    real(dp) :: tolv, gmax, gmix, gg, teta, gamma
    real(dp), allocatable :: gammet(:,:), swslip(:,:,:)
    real(dp), allocatable :: gamma_old(:,:), gamma_old2(:,:)
    real(dp), allocatable :: wb(:,:,:)    ! Bound vortex induced velocity
    real(dp) :: wslip(3), x(3), y(3), zpt(3), w(3)
    real(dp) :: ares_aitken, denom, delta1, delta2
    logical , parameter :: use_aitken=.false.	! Disable for testing

    ierr = 0
    if (.not. allocated(GAMME)) then
      write(*,*) 'VORTEX ERROR: GAMME not allocated.'
      ierr = 1
      return
    end if

    imax = 200   ! Increased from 50 for better convergence
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
	allocate( wb(NB, NOL, 3) )    ! Bound vortex induced velocity workspace
	gammet = 0.0_dp
	swslip = 0.0_dp
	gamma_old = 0.0_dp
	gamma_old2 = 0.0_dp
	wb = 0.0_dp
	it = 0

	! Compute induced velocities from wake (K >= 3 only)
	! The contribution from K=1,2 is recomputed each iteration below
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

    ! ==========================================================================
    ! ITERATION STRUCTURE - MATCHES LEGACY EXACTLY:
    !   Legacy flow: GOTO 100 → WIND → CLCD → GAMME → relax → GOTO 200 → WB → GOTO 100
    !   First pass: GOTO 100 skips WB computation
    ! ==========================================================================

    ! First iteration: jump to label 100 (skip WB computation)
    goto 100

    ! =========================================================================
    ! Label 200: WB COMPUTATION - Bound vortex self-induction from K=1,2
    ! SWB = SWSLIP (wake K>=3) + WB (bound K=1,2)
    ! Legacy lines 1789-1845
    ! =========================================================================
200 continue
    ! Compute WB for lower half (INS=1 to N), then mirror
    do inb = 1, NB
      do ins = 1, n
        ! Initialize WB for this control point
        do l = 1, 3
          wb(inb, ins, l) = 0.0_dp
          ! Control point Z = midpoint of bound vortex segment
          zpt(l) = 0.5_dp * (H1(inb, ins, 1, l) + H1(inb, ins+1, 1, l))
        end do

        ! Sum contributions from ALL blades (including self)
        do i = 1, NB
          ! Loop over all spanwise sections (J=1 to NOL+1)
          do j = 1, nol1
            if (j == nol1) then
              ! Top tip trailing vortex (J=NOL+1)
              gamma = GAMME(i, NOL, 1)
              do l = 1, 3
                x(l) = H1(i, nol1, 1, l)
                y(l) = H1(i, nol1, 2, l)
              end do
              call biot(x, y, zpt, gamma, RC, w)
              do l = 1, 3
                wb(inb, ins, l) = wb(inb, ins, l) + w(l)
              end do
            else
              ! Bound vortex segments K=1,2
              do k = 1, 2
                do l = 1, 3
                  x(l) = H1(i, j, k, l)
                  y(l) = H1(i, j+1, k, l)
                end do
                if (k == 1) then
                  gamma = GAMME(i, j, 1)
                else
                  gamma = GAMME(i, j, k) - GAMME(i, j, k-1)
                end if
                call biot(x, y, zpt, gamma, RC, w)
                do l = 1, 3
                  wb(inb, ins, l) = wb(inb, ins, l) + w(l)
                end do
              end do

              ! Trailing vortex from K=1 to K=2 (shed from this section)
              do l = 1, 3
                x(l) = H1(i, j, 1, l)
                y(l) = H1(i, j, 2, l)
              end do
              if (j == 1) then
                ! Bottom tip
                gamma = -GAMME(i, 1, 1)
              else
                gamma = GAMME(i, j-1, 1) - GAMME(i, j, 1)
              end if
              call biot(x, y, zpt, gamma, RC, w)
              do l = 1, 3
                wb(inb, ins, l) = wb(inb, ins, l) + w(l)
              end do
            end if
          end do
        end do

        ! Total SWB = SWSLIP (wake K>=3) + WB (bound K=1,2)
        do l = 1, 3
          SWB(inb, ins, l) = swslip(inb, ins, l) + wb(inb, ins, l)
        end do
      end do
    end do

    ! Mirror SWB for upper half (symmetry)
    do inb = 1, NB
      do ins = n1, NOL
        do l = 1, 2
          SWB(inb, ins, l) = SWB(inb, nol1 - ins, l)
        end do
        SWB(inb, ins, 3) = -SWB(inb, nol1 - ins, 3)
      end do
    end do
    ! Fall through to label 100

    ! =========================================================================
    ! Label 100: WIND → CLCD → GAMME update → convergence check → relax
    ! Legacy label 100 (lines 1839-1894)
    ! =========================================================================
100 continue
    call wind(teta)

    ! Save old GAMME for convergence check (legacy: GAMMET=GAMME before CLCD)
    gammet = GAMME(:,:,1)

    ! Update circulation from aerodynamics
    do inb = 1, NB
      do ins = 1, n
        call clcdideal(ALFA(inb, ins) * 180.0_dp / pi, CL(inb, ins), CD(inb, ins))
        GAMME(inb, ins, 1) = 0.5_dp * C * CL(inb, ins) * max(UREL(inb, ins), 0.0_dp)
      end do
    end do

    ! Mirror GAMME, CL, CD for upper half (legacy lines 1858-1866)
    do inb = 1, NB
      do ins = n1, NOL
        gammet(inb, ins) = gammet(inb, nol1 - ins)
        GAMME(inb, ins, 1) = GAMME(inb, nol1 - ins, 1)
        CL(inb, ins) = CL(inb, nol1 - ins)
        CD(inb, ins) = CD(inb, nol1 - ins)
      end do
    end do

    ! Increment iteration counter BEFORE convergence check (legacy line 1868)
    it = it + 1

    ! Diagnostic output (moved here to show current iteration)
    if (mod(it, 50) == 0 .or. it <= 3) then
      ! Note: GG computed below, so we show previous values or skip for it=1
    end if

    ! Check convergence (legacy lines 1869-1887)
    gmax = 0.0_dp
    gmix = 0.0_dp
    do inb = 1, NB
      do ins = 1, n
        gmax = max(abs(GAMME(inb, ins, 1)), gmax)
        gmix = max(abs(GAMME(inb, ins, 1) - gammet(inb, ins)), gmix)
      end do
    end do

    ! Legacy: IF(GMAX) 18,18,19 → return if GMAX <= 0
    if (gmax <= 0.0_dp) then
      ierr = 0
      deallocate(gammet, swslip, gamma_old, gamma_old2, wb)
      return
    end if

    gg = abs(gmix / gmax)

    ! Diagnostic output (now we have GG)
    if (mod(it, 50) == 0 .or. it <= 3) then
      write(*,'(A,I4,A,E12.4,A,E12.4)') '    Vortex iter ', it, '  GG=', gg, '  GMAX=', gmax
    end if

    ! Legacy: IF(GG.LT.EPS1) GOTO 18 → converged, return
    if (gg < tolv) then
      ierr = 0
      deallocate(gammet, swslip, gamma_old, gamma_old2, wb)
      return
    end if

    ! Legacy: IF(IT.GT.9999) GOTO 300 → max iterations exceeded
    if (it >= imax) then
      write(*,*) 'VORTEX WARNING: max iterations ', it, ' GG=', gg
      ierr = 2
      deallocate(gammet, swslip, gamma_old, gamma_old2, wb)
      return
    end if

    ! Under-relaxation (legacy lines 1889-1893)
    do i = 1, NB
      do j = 1, NOL
        GAMME(i, j, 1) = ares * GAMME(i, j, 1) + (1.0_dp - ares) * gammet(i, j)
      end do
    end do

    ! GOTO 200 - compute WB with relaxed GAMME, then back to 100
    goto 200

  end subroutine vortex_iterate

end module vdart_vortex_mod