! vdart_biot_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Robust Biot–Savart line-element induced-velocity routine.
! Author: U.S.Paulsen
! Date: 2026-02-24
! SPDX-License-Identifier: MIT

module vdart_biot_mod
  use vdart_kinds_mod
  implicit none
  private
  public :: biot

contains

  subroutine biot(X, Y, Z, GAMMA, RC, W)
    real(dp), intent(in)  :: X(3), Y(3), Z(3)
    real(dp), intent(in)  :: GAMMA, RC
    real(dp), intent(out) :: W(3)
    real(dp) :: VA(3), VB(3), V(3)
    real(dp) :: VL2, AF2, VAL2, VBL2
    real(dp) :: AF, VL
    real(dp) :: Aproj, Bproj, AFS, WASH
    real(dp) :: DIR(3)
    integer :: i
    real(dp), parameter :: EPS = 1.0e-12_dp

    ! Initialize output
    W = 0.0_dp

    ! Vectors
    do i=1,3
      VA(i) = Z(i) - X(i)
      VB(i) = Z(i) - Y(i)
      V(i)  = Y(i) - X(i)
    end do

    VL2 = V(1)*V(1) + V(2)*V(2) + V(3)*V(3)
    if (VL2 <= EPS) return
    VL = sqrt(VL2)

    DIR(1) = V(2)*VA(3) - VA(2)*V(3)
    DIR(2) = V(3)*VA(1) - VA(3)*V(1)
    DIR(3) = V(1)*VA(2) - VA(1)*V(2)
    AF2 = DIR(1)*DIR(1) + DIR(2)*DIR(2) + DIR(3)*DIR(3)
    if (AF2 <= EPS) return
    AF = sqrt(AF2)

    VAL2 = VA(1)*VA(1) + VA(2)*VA(2) + VA(3)*VA(3)
    VBL2 = VB(1)*VB(1) + VB(2)*VB(2) + VB(3)*VB(3)

    Aproj = 0.0_dp
    if (VAL2 > EPS) then
      Aproj = (VA(1)*V(1)+VA(2)*V(2)+VA(3)*V(3)) / (sqrt(VAL2) * VL)
    end if
    Bproj = 0.0_dp
    if (VBL2 > EPS) then
      Bproj = (VB(1)*V(1)+VB(2)*V(2)+VB(3)*V(3)) / (sqrt(VBL2) * VL)
    end if

    AFS = AF / VL
    WASH = GAMMA * (Aproj - Bproj) * AFS / ( (RC*RC + AFS*AFS) * 4.0_dp * pi )

    do i=1,3
      W(i) = DIR(i) * (WASH / AF)
    end do

  end subroutine biot

end module vdart_biot_mod