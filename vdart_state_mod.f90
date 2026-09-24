! vdart_state_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Runtime state container replacing COMMON blocks (allocatable arrays).
! Author: U.S.Paulsen
! Date: 2026-02-28
! SPDX-License-Identifier: MIT

module vdart_state_mod
  use vdart_kinds_mod
  implicit none

  public :: allocate_state, deallocate_state
  public :: save_state, load_state
  public :: allocate_mesh, deallocate_mesh
  public :: NB, NOL, KMNET, NPSI, IR, IRUN, KMAKS
  public :: RO, ANY
  public :: C, DTETA, DT, OMEGA, EPS1, RC, HSTAR, FI0DOT, FI0_AMP, FI0_BASE, UINF, BOOLPRINT
  public :: H0, A, B, BSAF
  public :: PITCH_MODE, WIND_DIR, USE_ETA_OFFSET
  public :: USE_VAR_OMEGA
  public :: AUTO_SAVE_STATE
  public :: GAMME, SWB, UREL, ALFA, ALFAF, CL, CD
  public :: FI0_old, FIDOT
  public :: H1, H2, V1, V2, VIND, BLSNIT
  public :: DSPAN, BETA, FI0, CRANK, RS
  public :: FR, FT, FB
  public :: POINT, HAS, ITALX, ITALY, ITALZ

  integer :: NB, NOL, KMNET, NPSI, IR, IRUN, KMAKS
  integer :: ITALX, ITALY, ITALZ

  ! ============================================================================
  ! PITCH CONTROL SYSTEM
  ! ============================================================================
  ! PITCH_MODE: Selects the blade pitch actuation strategy.
  !   0 = Fixed pitch (no active control)
  !       - FI0(i,j) = FI0_BASE for all blades and sections
  !       - Use for: baseline performance, legacy validation
  !   1 = Harmonic pitch (time-varying, all blades identical)
  !       - FI0(i,j) = FI0_BASE + FI0_AMP * sin(FI0DOT * t)
  !       - Use for: frequency response, flutter analysis, simple actuation
  !   2 = Cyclic pitch (azimuth-dependent, blade-specific)
  !       - Downwind (90° < θ_rel < 270°): FI0 = FI0_BASE + FI0_AMP
  !       - Upwind (otherwise):            FI0 = FI0_BASE
  !       - θ_rel = blade azimuth relative to WIND_DIR
  !       - Use for: torque smoothing, velocity deficit compensation
  !
  ! Related parameters:
  !   FI0_BASE  - Baseline pitch offset [radians]
  !   FI0_AMP   - Pitch amplitude for modes 1 and 2 [radians]
  !   FI0DOT    - Pitch oscillation frequency for mode 1 [rad/s]
  !   WIND_DIR  - Wind direction angle [radians] (0 = +X axis, default)
  !   FI0(i,j)  - Actual pitch per blade i, section j [radians] (set by solver)
  ! ============================================================================
  integer :: PITCH_MODE
  real(dp) :: WIND_DIR

  ! ============================================================================
  ! AERODYNAMIC MODEL OPTIONS
  ! ============================================================================
  ! USE_ETA_OFFSET: Controls whether c/4 and 3c/4 evaluation points differ
  !   .TRUE.  = Use proper thin airfoil theory (c/4 for forces, 3c/4 for AoA)
  !   .FALSE. = Legacy mode (both evaluated at same point, ETA=0)
  !
  ! When .FALSE. (legacy): Simpler, matches original VDaRT behavior
  ! When .TRUE. (proper):  More accurate for pitching blades (FI0DOT ≠ 0)
  ! ============================================================================
  logical :: USE_ETA_OFFSET = .false.   ! Default: legacy behavior for safety
  logical :: USE_VAR_OMEGA = .false.    ! Default: keep OMEGA constant unless enabled
  logical :: AUTO_SAVE_STATE = .true.   ! Automatically save state after successful runs

  real(dp) :: RO, ANY
  real(dp) :: C, DTETA, DT, OMEGA, EPS1, RC, HSTAR, FI0DOT, FI0_AMP, FI0_BASE, UINF
  real(dp) :: H0, A, B, BSAF
  logical :: BOOLPRINT

  real(dp), allocatable :: GAMME(:,:,:)
  real(dp), allocatable :: SWB(:,:,:)
  real(dp), allocatable :: UREL(:,:)
  real(dp), allocatable :: ALFA(:,:)
  real(dp), allocatable :: ALFAF(:,:)
  real(dp), allocatable :: CL(:,:)
  real(dp), allocatable :: CD(:,:)
  real(dp), allocatable :: H1(:,:,:,:)
  real(dp), allocatable :: H2(:,:,:,:)
  real(dp), allocatable :: V1(:,:,:,:)
  real(dp), allocatable :: V2(:,:,:,:)
  real(dp), allocatable :: VIND(:,:)
  real(dp), allocatable :: BLSNIT(:,:,:)
  real(dp), allocatable :: DSPAN(:)
  real(dp), allocatable :: BETA(:)
  real(dp), allocatable :: FI0(:,:)
  real(dp), allocatable :: FI0_old(:,:)
  real(dp), allocatable :: FIDOT(:,:)
  real(dp), allocatable :: CRANK(:)
  real(dp), allocatable :: RS(:,:)
  real(dp), allocatable :: FR(:,:,:)
  real(dp), allocatable :: FT(:,:,:)
  real(dp), allocatable :: FB(:,:,:)
  real(dp), allocatable :: POINT(:,:,:,:)
  real(dp), allocatable :: HAS(:,:,:,:)

  ! Fixed size for force arrays (legacy: 8000)
  integer, parameter :: KMAKS_FORCE = 8000

contains

  subroutine allocate_state(nb_in, nol_in, kmnet_in, ierr)
    integer, intent(in) :: nb_in, nol_in, kmnet_in
    integer, intent(out) :: ierr
    integer :: ios, nol1

    ierr = 0
    if (nb_in <= 0 .or. nol_in <= 0 .or. kmnet_in <= 0) then
      ierr = 1
      return
    end if

    NB = nb_in
    NOL = nol_in
    KMNET = kmnet_in
    NPSI = 0
    IR = 0
    IRUN = 0
    KMAKS = 0
    ITALX = 0
    ITALY = 0
    ITALZ = 0
    RO = 1.225_dp
    ANY = 1.5e-5_dp
    C = 0.0_dp
    DTETA = 0.0_dp
    DT = 0.0_dp
    OMEGA = 0.0_dp
    EPS1 = 1.0e-6_dp
    RC = 0.0_dp
    HSTAR = 0.0_dp
    FI0DOT = 0.0_dp
    FI0_AMP = 0.0_dp
    FI0_BASE = 0.0_dp
    UINF = 0.0_dp
    USE_VAR_OMEGA = .false.
    PITCH_MODE = 0      ! Default: fixed pitch (no control)
    WIND_DIR = 0.0_dp   ! Default: wind from +X direction
    H0 = 0.0_dp
    A = 0.0_dp
    B = 0.0_dp
    BSAF = 0.0_dp
    BOOLPRINT = .false.

    nol1 = NOL + 1

    allocate( GAMME(NB, NOL, KMNET), stat=ios )
    if (ios /= 0) then
      ierr = 2
      return
    end if
    GAMME = 0.0_dp

    allocate( SWB(NB, NOL, 3), stat=ios )
    if (ios /= 0) then
      ierr = 3
      return
    end if
    SWB = 0.0_dp

    allocate( UREL(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 4
      return
    end if
    UREL = 0.0_dp

    allocate( ALFA(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 5
      return
    end if
    ALFA = 0.0_dp

    allocate( ALFAF(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 6
      return
    end if
    ALFAF = 0.0_dp

    allocate( CL(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 7
      return
    end if
    CL = 0.0_dp

    allocate( CD(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 8
      return
    end if
    CD = 0.0_dp

    allocate( H1(NB, nol1, KMNET, 3), stat=ios )
    if (ios /= 0) then
      ierr = 9
      return
    end if
    H1 = 0.0_dp

    allocate( H2(NB, nol1, KMNET, 3), stat=ios )
    if (ios /= 0) then
      ierr = 10
      return
    end if
    H2 = 0.0_dp

    allocate( V1(NB, nol1, KMNET, 3), stat=ios )
    if (ios /= 0) then
      ierr = 11
      return
    end if
    V1 = 0.0_dp

    allocate( V2(NB, nol1, KMNET, 3), stat=ios )
    if (ios /= 0) then
      ierr = 12
      return
    end if
    V2 = 0.0_dp

    allocate( VIND(nol1, 3), stat=ios )
    if (ios /= 0) then
      ierr = 13
      return
    end if
    VIND = 0.0_dp

    allocate( BLSNIT(NB, nol1, 3), stat=ios )
    if (ios /= 0) then
      ierr = 14
      return
    end if
    BLSNIT = 0.0_dp

    allocate( DSPAN(NOL), stat=ios )
    if (ios /= 0) then
      ierr = 15
      return
    end if
    DSPAN = 0.0_dp

    allocate( BETA(NOL), stat=ios )
    if (ios /= 0) then
      ierr = 16
      return
    end if
    BETA = 0.0_dp

    allocate( FI0(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 17
      return
    end if
    FI0 = 0.0_dp

    ! Allocate pitch-history arrays for controller diagnostics (FI0_old, FIDOT)
    allocate( FI0_old(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 18
      return
    end if
    FI0_old = 0.0_dp

    allocate( FIDOT(NB, NOL), stat=ios )
    if (ios /= 0) then
      ierr = 19
      return
    end if
    FIDOT = 0.0_dp

    allocate( CRANK(NB), stat=ios )
    if (ios /= 0) then
      ierr = 20
      return
    end if
    CRANK = 0.0_dp

    allocate( RS(300, 2), stat=ios )
    if (ios /= 0) then
      ierr = 21
      return
    end if
    RS = 0.0_dp

    ! Force arrays: fixed size matching legacy (8000 timesteps)
    allocate( FR(NB, NOL, KMAKS_FORCE), stat=ios )
    if (ios /= 0) then
      ierr = 22
      return
    end if
    FR = 0.0_dp
    allocate( FT(NB, NOL, KMAKS_FORCE), stat=ios )
    if (ios /= 0) then
      ierr = 23
      return
    end if
    FT = 0.0_dp
    allocate( FB(NB, NOL, KMAKS_FORCE), stat=ios )
    if (ios /= 0) then
      ierr = 24
      return
    end if
    FB = 0.0_dp

  end subroutine allocate_state

  subroutine deallocate_state()
    if (allocated(GAMME))  deallocate(GAMME)
    if (allocated(SWB))    deallocate(SWB)
    if (allocated(UREL))   deallocate(UREL)
    if (allocated(ALFA))   deallocate(ALFA)
    if (allocated(ALFAF))  deallocate(ALFAF)
    if (allocated(CL))     deallocate(CL)
    if (allocated(CD))     deallocate(CD)
    if (allocated(H1))     deallocate(H1)
    if (allocated(H2))     deallocate(H2)
    if (allocated(V1))     deallocate(V1)
    if (allocated(V2))     deallocate(V2)
    if (allocated(VIND))   deallocate(VIND)
    if (allocated(BLSNIT)) deallocate(BLSNIT)
    if (allocated(DSPAN))  deallocate(DSPAN)
    if (allocated(BETA))   deallocate(BETA)
    if (allocated(FI0))    deallocate(FI0)
    if (allocated(FI0_old))deallocate(FI0_old)
    if (allocated(FIDOT))  deallocate(FIDOT)
    if (allocated(CRANK))  deallocate(CRANK)
    if (allocated(RS))     deallocate(RS)
    if (allocated(FR))     deallocate(FR)
    if (allocated(FT))     deallocate(FT)
    if (allocated(FB))     deallocate(FB)
    if (allocated(POINT))  deallocate(POINT)
    if (allocated(HAS))    deallocate(HAS)
    NB = 0
    NOL = 0
    KMNET = 0
    ITALX = 0
    ITALY = 0
    ITALZ = 0
  end subroutine deallocate_state

  subroutine allocate_mesh(ix, iy, iz, ierr)
    integer, intent(in) :: ix, iy, iz
    integer, intent(out) :: ierr
    integer :: ios

    ierr = 0
    if (ix <= 0 .or. iy <= 0 .or. iz <= 0) then
      ierr = 1
      return
    end if

    ITALX = ix
    ITALY = iy
    ITALZ = iz

    allocate( POINT(ITALX, ITALY, ITALZ, 3), stat=ios )
    if (ios /= 0) then
      ierr = 2
      return
    end if
    POINT = 0.0_dp

    allocate( HAS(ITALX, ITALY, ITALZ, 3), stat=ios )
    if (ios /= 0) then
      ierr = 3
      return
    end if
    HAS = 0.0_dp

  end subroutine allocate_mesh

  subroutine deallocate_mesh()
    if (allocated(POINT)) deallocate(POINT)
    if (allocated(HAS))   deallocate(HAS)
    ITALX = 0
    ITALY = 0
    ITALZ = 0
  end subroutine deallocate_mesh

  ! ================================================================
  ! State persistence: save / load runtime state for warm-starts
  ! ================================================================
  subroutine save_state(filename, ierr)
    character(len=*), intent(in) :: filename
    integer, intent(out) :: ierr
    integer :: ios, unit

    ierr = 0
    unit = 99
    open(unit, file=filename, status='replace', form='unformatted', access='stream', iostat=ios)
    if (ios /= 0) then
      ierr = 1
      return
    end if

    ! Write basic scalars
    write(unit) NB, NOL, KMNET, IR, IRUN, KMAKS
    write(unit) RO, ANY, C, DTETA, DT, OMEGA, EPS1, RC, HSTAR
    write(unit) FI0DOT, FI0_AMP, FI0_BASE, UINF
    write(unit) PITCH_MODE, WIND_DIR, USE_ETA_OFFSET
    write(unit) H0, A, B, BSAF

    ! Write arrays (in consistent order)
    write(unit) GAMME
    write(unit) SWB
    write(unit) UREL
    write(unit) ALFA
    write(unit) ALFAF
    write(unit) CL
    write(unit) CD
    write(unit) H1
    write(unit) H2
    write(unit) V1
    write(unit) V2
    write(unit) VIND
    write(unit) BLSNIT
    write(unit) DSPAN
    write(unit) BETA
    write(unit) FI0
    write(unit) FI0_old
    write(unit) FIDOT
    write(unit) CRANK
    write(unit) RS
    write(unit) FR
    write(unit) FT
    write(unit) FB

    close(unit)

  end subroutine save_state

  subroutine load_state(filename, ierr)
    character(len=*), intent(in) :: filename
    integer, intent(out) :: ierr
    integer :: ios, unit

    ierr = 0
    unit = 99
    open(unit, file=filename, status='old', form='unformatted', access='stream', iostat=ios)
    if (ios /= 0) then
      ierr = 1
      return
    end if

    ! Read scalars
    read(unit) NB, NOL, KMNET, IR, IRUN, KMAKS
    read(unit) RO, ANY, C, DTETA, DT, OMEGA, EPS1, RC, HSTAR
    read(unit) FI0DOT, FI0_AMP, FI0_BASE, UINF
    read(unit) PITCH_MODE, WIND_DIR, USE_ETA_OFFSET
    read(unit) H0, A, B, BSAF

    ! Reallocate arrays using allocate_state to ensure sizes
    call allocate_state(NB, NOL, KMNET, ios)
    if (ios /= 0) then
      ierr = 2
      close(unit)
      return
    end if

    ! Read arrays in same order
    read(unit) GAMME
    read(unit) SWB
    read(unit) UREL
    read(unit) ALFA
    read(unit) ALFAF
    read(unit) CL
    read(unit) CD
    read(unit) H1
    read(unit) H2
    read(unit) V1
    read(unit) V2
    read(unit) VIND
    read(unit) BLSNIT
    read(unit) DSPAN
    read(unit) BETA
    read(unit) FI0
    read(unit) FI0_old
    read(unit) FIDOT
    read(unit) CRANK
    read(unit) RS
    read(unit) FR
    read(unit) FT
    read(unit) FB

    close(unit)

  end subroutine load_state

end module vdart_state_mod