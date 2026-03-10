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
  public :: allocate_mesh, deallocate_mesh
  public :: NB, NOL, KMNET, NPSI, IR, IRUN, KMAKS
  public :: RO, ANY
  public :: C, DTETA, DT, OMEGA, EPS1, RC, HSTAR, FI0DOT, UINF, BOOLPRINT
  public :: H0, A, B, BSAF
  public :: GAMME, SWB, UREL, ALFA, ALFAF, CL, CD
  public :: H1, H2, V1, V2, VIND, BLSNIT
  public :: DSPAN, BETA, FI0, CRANK, RS
  public :: FR, FT, FB
  public :: POINT, HAS, ITALX, ITALY, ITALZ

  integer :: NB, NOL, KMNET, NPSI, IR, IRUN, KMAKS
  integer :: ITALX, ITALY, ITALZ
  
  real(dp) :: RO, ANY
  real(dp) :: C, DTETA, DT, OMEGA, EPS1, RC, HSTAR, FI0DOT, UINF
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
  real(dp), allocatable :: FI0(:)
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
    UINF = 0.0_dp
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

    allocate( FI0(NOL), stat=ios )
    if (ios /= 0) then
      ierr = 17
      return
    end if
    FI0 = 0.0_dp

    allocate( CRANK(NB), stat=ios )
    if (ios /= 0) then
      ierr = 18
      return
    end if
    CRANK = 0.0_dp

    allocate( RS(300, 2), stat=ios )
    if (ios /= 0) then
      ierr = 19
      return
    end if
    RS = 0.0_dp

    ! Force arrays: fixed size matching legacy (8000 timesteps)
    allocate( FR(NB, NOL, KMAKS_FORCE), stat=ios )
    if (ios /= 0) then
      ierr = 20
      return
    end if
    FR = 0.0_dp

    allocate( FT(NB, NOL, KMAKS_FORCE), stat=ios )
    if (ios /= 0) then
      ierr = 21
      return
    end if
    FT = 0.0_dp

    allocate( FB(NB, NOL, KMAKS_FORCE), stat=ios )
    if (ios /= 0) then
      ierr = 22
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

end module vdart_state_mod