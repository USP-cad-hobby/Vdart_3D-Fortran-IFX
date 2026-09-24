<#
PowerShell helper to run two simulation commands (baseline and offset), collect outputs, and invoke the Python comparator.
Usage:
  .\run_and_compare.ps1 -BaselineCmd "C:\path\to\vdart.exe --config baseline.cfg" -OffsetCmd "C:\path\to\vdart.exe --config offset.cfg" -ResultsDir .\results -KeepDatFiles

Notes:
- This script does not change Fortran source. Provide commands that execute the simulator configured for each case.
- The script captures stdout/stderr into results/<case>/output.log and also copies any .dat files produced in the repository root into results/<case>/ (use KeepDatFiles switch to preserve .dat filenames).
- After both runs it calls compare_results.py to compute numeric verdicts. Python 3.x is required.
#>
param(
  [Parameter(Mandatory=$true)]
  [string] $BaselineCmd,

  [Parameter(Mandatory=$true)]
  [string] $OffsetCmd,

  [string] $ResultsDir = "tests\results",

  [switch] $KeepDatFiles
)

function Run-Case {
  param(
	[string] $Name,
	[string] $Cmd
  )

  $caseDir = Join-Path $ResultsDir $Name
  if (-Not (Test-Path $caseDir)) { New-Item -ItemType Directory -Path $caseDir | Out-Null }

  $logPath = Join-Path $caseDir "output.log"
  Write-Host "Running case '$Name' -> cmd: $Cmd"

	# Run the command and capture output. Use Invoke-Expression so callers may provide
  # a full PowerShell expression (including the call operator &). Capture both
  # stdout and stderr together and preserve them in the log.
	try {
	# Normalize the provided command string. Users may pass a quoted literal like '\'.\\build\\vdart.exe\''
	$cmdNormalized = $Cmd.Trim()
	if ($cmdNormalized.StartsWith("'") -and $cmdNormalized.EndsWith("'")) {
	  $cmdNormalized = $cmdNormalized.Trim("'")
	}
	# If the command does not start with the call operator, prefix it so a plain path will be executed
	if (-not $cmdNormalized.StartsWith("&")) {
	  $cmdNormalized = "& " + $cmdNormalized
	}
	$execOutput = Invoke-Expression $cmdNormalized 2>&1 | Out-String
	$stdout = $execOutput
	$stderr = ""
  } catch {
	$stdout = ""
	$stderr = $_.Exception.Message
  }

  "=== STDOUT ===`n$stdout`n=== STDERR ===`n$stderr" | Out-File -FilePath $logPath -Encoding UTF8

  # Collect any .dat files in repo root (or current directory) if present
  $repoRoot = Resolve-Path "..\.."  # script located at tests/
  $datFiles = Get-ChildItem -Path $repoRoot -Filter "*.dat" -File -ErrorAction SilentlyContinue
  foreach ($f in $datFiles) {
	Copy-Item -Path $f.FullName -Destination $caseDir -Force
	if (-Not $KeepDatFiles) { Remove-Item -Path $f.FullName -ErrorAction SilentlyContinue }
  }

  Write-Host "Case '$Name' finished. Log saved to $logPath"
}

# Clean previous results
if (Test-Path $ResultsDir) { Remove-Item -Recurse -Force -Path $ResultsDir }
New-Item -ItemType Directory -Path $ResultsDir | Out-Null

# Run baseline and offset
Run-Case -Name baseline -Cmd $BaselineCmd
Run-Case -Name offset -Cmd $OffsetCmd

# Call Python comparator
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) { Write-Error "Python not found on PATH. Please install Python 3 and try again."; exit 2 }

$cmp = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "compare_results.py"
& $py.Path $cmp (Join-Path $ResultsDir "baseline") (Join-Path $ResultsDir "offset")
exit $LASTEXITCODE
