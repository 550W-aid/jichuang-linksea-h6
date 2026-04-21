param(
    [Parameter(Mandatory = $true)]
    [string]$Top,

    [Parameter(Mandatory = $true)]
    [string]$FileList,

    [Parameter(Mandatory = $true)]
    [string]$OutDir,

    [string]$Part = "xc7z020clg400-1",

    [string]$ClockPeriod = "7.220",

    [string]$VivadoBat = "D:\\Xilinx\\Vivado\\2018.3\\bin\\vivado.bat",
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..\\..")).Path
}

if (-not (Test-Path -LiteralPath $VivadoBat)) {
    throw "Vivado batch launcher not found: $VivadoBat"
}

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$resolvedFileList = if ([System.IO.Path]::IsPathRooted($FileList)) {
    (Resolve-Path -LiteralPath $FileList).Path
} else {
    (Resolve-Path -LiteralPath (Join-Path $resolvedRepoRoot $FileList)).Path
}

$resolvedOutDir = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir
} else {
    Join-Path $resolvedRepoRoot $OutDir
}

New-Item -ItemType Directory -Force -Path $resolvedOutDir | Out-Null
$consoleLog = Join-Path $resolvedOutDir "vivado_console.log"
$tclScript = Join-Path $PSScriptRoot "run_ooc_signoff.tcl"

Push-Location $resolvedRepoRoot
try {
    & $VivadoBat -mode batch -notrace -source $tclScript -tclargs `
        $resolvedRepoRoot `
        $Top `
        $resolvedFileList `
        $resolvedOutDir `
        $Part `
        $ClockPeriod *>&1 | Tee-Object -FilePath $consoleLog

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $timingSummary = Join-Path $resolvedOutDir "timing_summary.rpt"
    $metricsPath = Join-Path $resolvedOutDir "timing_metrics.txt"
    if (Test-Path -LiteralPath $timingSummary) {
        $lines = Get-Content -LiteralPath $timingSummary
        $wns = $null
        $tns = $null
        $whs = $null
        $ths = $null

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'WNS\(ns\).*TNS\(ns\).*WHS\(ns\).*THS\(ns\)') {
                for ($j = $i + 1; $j -lt [Math]::Min($i + 6, $lines.Count); $j++) {
                    if ($lines[$j] -match '^\s*([-A-Z0-9\.]+)\s+([-A-Z0-9\.]+)\s+\d+\s+\d+\s+([-A-Z0-9\.]+)\s+([-A-Z0-9\.]+)\s+\d+\s+\d+') {
                        $wns = $Matches[1]
                        $tns = $Matches[2]
                        $whs = $Matches[3]
                        $ths = $Matches[4]
                        break
                    }
                }
                if ($wns) {
                    break
                }
            }
        }

        if ($wns) {
            @(
                "WNS=$wns"
                "TNS=$tns"
                "WHS=$whs"
                "THS=$ths"
            ) | Set-Content -LiteralPath $metricsPath
        }
    }
} finally {
    Pop-Location
}
