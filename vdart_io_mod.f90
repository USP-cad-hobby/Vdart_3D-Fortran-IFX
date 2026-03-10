! vdart_io_mod.f90
! Project: VDaRT (Darrieus 3D)
! Purpose: Safe I/O helpers and minimal input reader.
! Author: U.S.Paulsen
! Date: 2026-02-24
! SPDX-License-Identifier: MIT

module vdart_io_mod
  use vdart_kinds_mod
  implicit none
  private
  public :: safe_open, safe_close, safe_read_real, read_initial_scalars

contains

  subroutine safe_open(unit, filename, status, ierr)
    integer, intent(in) :: unit
    character(len=*), intent(in) :: filename
    character(len=*), intent(in), optional :: status
    integer, intent(out) :: ierr
    integer :: ios
    ierr = 0
    if (present(status)) then
      open(unit, file=filename, status=status, iostat=ios, action='readwrite')
    else
      open(unit, file=filename, status='old', iostat=ios, action='read')
    end if
    ierr = ios
    if (ierr /= 0) then
      write(*,*) 'ERROR: failed to open ', trim(filename), ' (IOSTAT=', ierr, ')'
    end if
  end subroutine safe_open

  subroutine safe_close(unit, ierr)
    integer, intent(in) :: unit
    integer, intent(out) :: ierr
    integer :: ios
    ios = 0
    close(unit, iostat=ios)
    ierr = ios
    if (ierr /= 0) then
      write(*,*) 'WARNING: failed to close unit', unit, '(IOSTAT=', ierr, ')'
    end if
  end subroutine safe_close

  subroutine safe_read_real(unit, dest, ierr)
    integer, intent(in) :: unit
    real(dp), intent(out) :: dest
    integer, intent(out) :: ierr
    integer :: ios
    ios = 0
    read(unit, *, iostat=ios) dest
    ierr = ios
    if (ierr /= 0) then
      write(*,*) 'ERROR: read failed on unit', unit, '(IOSTAT=', ierr, ')'
    end if
  end subroutine safe_read_real

  subroutine read_initial_scalars(filename, uinf, dtetad, rpm, c, fi0dot, ierr)
    character(len=*), intent(in) :: filename
    real(dp), intent(out) :: uinf, dtetad, rpm, c, fi0dot
    integer, intent(out) :: ierr

    integer :: unit, ios
    character(len=256) :: skip

    unit = 20
    call safe_open(unit, filename, status='old', ierr=ios)
    if (ios /= 0) then
      ierr = ios
      return
    end if

    ierr = 0
    do
      read(unit, *, iostat=ios) uinf, dtetad, rpm, c, fi0dot
      if (ios == 0) exit
      read(unit, '(A)', iostat=ios) skip
      if (ios /= 0) then
        ierr = ios
        exit
      end if
    end do

    call safe_close(unit, ios)
    if (ios /= 0) ierr = ios
  end subroutine read_initial_scalars

end module vdart_io_mod