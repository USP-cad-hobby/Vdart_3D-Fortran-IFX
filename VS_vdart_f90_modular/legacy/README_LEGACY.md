# Legacy FORTRAN 77 Code

## File: `vdart_3d_R5.FOR`

This is the original FORTRAN 77 implementation of VDaRT (Darrieus 3D), preserved for:

- **Validation:** Compare results with modernized version
- **Historical reference:** Original implementation by U.S. Paulsen
- **Scientific reproducibility:** Verify published results

## Key Characteristics

### Language: FORTRAN 77
- Fixed-form source (columns 1-72)
- COMMON blocks for data sharing
- Computed GOTOs and arithmetic IFs
- IMPLICIT typing
- Static array dimensions

### Compilation (Historic)

**Original (CDC/Cray):**
```fortran
! FILE 5(KIND=DISK,TITLE='D3/DATA',DEPENDENTSPECS=.TRUE.)
! FILE 6(KIND=PRINTER)
```

**Modern (Intel Fortran):**
```bash
ifort vdart_3d_R5.FOR -o vdart_legacy.exe -fixed -assume byterecl
```

## Known Issues (Fixed in Modern Version)

1. **FI0 timing bug:** Pitch angle updated BEFORE `IRUN++`, causing 1-step phase error
2. **Array bounds:** Unsafe access to `FI0(NOL+1)` in WIND subroutine
3. **NPSI typo:** Comment says `IR1+1` but should be `IR+1`
4. **Hardcoded limits:** Arrays fixed at 8000 time steps, 300 sections

## Differences from Modern Code

| Aspect | Legacy (FOR) | Modern (f90) |
|--------|--------------|--------------|
| **Modules** | None (monolithic) | 15 modules |
| **Arrays** | Static (DIMENSION) | Allocatable |
| **Precision** | REAL (single) | real(dp) (double) |
| **FI0 timing** | Before IRUN++ | After IRUN++ ✓ |
| **GOTOs** | Extensive | None |
| **Comments** | Danish + English | English |

## Historical Context

**Original Development:** Technical University of Denmark (DTU)  
**Project:** DeepWind (floating offshore VAWTs)  
**Last Modified:** 2022-04-12 (version R5)

## Validation

To compare legacy vs modern results:

1. Run both versions with identical `D3_DATA.SEQ`
2. Compare output files:
   - `RESULT.DAT` (blade loads, performance)
   - `RES.DAT` (mid-span time series)
3. Expect numerical differences < 0.1% (due to fixed/free format I/O)

## Notes

- The code contains valuable Danish-language comments explaining the physics
- Some subroutines have duplicate versions (e.g., `BIOTg` vs `BIOT`)
- The CLCD routine includes Reynolds number interpolation (currently bypassed)

---

**For the modernized version, see parent directory.**
