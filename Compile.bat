@echo off
echo ========================================
echo VDaRT Compilation with ifx 2025.3
echo ========================================

REM Set up environment with YOUR specific paths
set "INTEL_ROOT=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3"
set "SDK_ROOT=C:\Program Files (x86)\Windows Kits\10"
set "SDK_VER=10.0.26100.0"
set "VS_ROOT=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717"
set "LIB=%INTEL_ROOT%\lib;%SDK_ROOT%\Lib\%SDK_VER%\um\x64;%SDK_ROOT%\Lib\%SDK_VER%\ucrt\x64;%VS_ROOT%\lib\x64"
set "PATH=%INTEL_ROOT%\bin;%VS_ROOT%\bin\Hostx64\x64;%PATH%"

echo.
echo Cleaning old files...
del /Q *.mod *.obj *.exe 2>nul

echo.
echo Compiling modules...
echo ========================================

ifx /c /O2 vdart_kinds_mod.f90 || goto :error
ifx /c /O2 vdart_state_mod.f90 || goto :error
ifx /c /O2 vdart_aero_mod.f90 || goto :error
ifx /c /O2 vdart_biot_mod.f90 || goto :error
ifx /c /O2 vdart_blad_mod.f90 || goto :error
ifx /c /O2 vdart_wind_mod.f90 || goto :error
ifx /c /O2 vdart_forces_mod.f90 || goto :error
ifx /c /O2 vdart_flyt_mod.f90 || goto :error
ifx /c /O2 vdart_bsa_mod.f90 || goto :error
ifx /c /O2 vdart_nethas_mod.f90 || goto :error
ifx /c /O2 vdart_start_mod.f90 || goto :error
ifx /c /O2 vdart_vortex_mod.f90 || goto :error
ifx /c /O2 vdart_solver_mod.f90 || goto :error
ifx /c /O2 main.f90 || goto :error

echo.
echo Linking...
ifx /exe:vdart_demo.exe *.obj
if errorlevel 1 goto :error

echo.
echo ========================================
echo SUCCESS!
echo ========================================
dir vdart_demo.exe
echo.
echo Run with:
echo   vdart_demo.exe
pause
exit /b 0

:error
echo.
echo FAILED!
pause
exit /b 1