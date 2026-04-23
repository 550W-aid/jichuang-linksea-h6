param(
    [string]$ProjectDir,
    [string]$ProjectName,
    [string]$Revision = "",
    [string]$SdcPath = "",
    [string]$OutputSubdir = "sta_clean"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    throw "ProjectDir is required."
}
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    throw "ProjectName is required."
}
if ([string]::IsNullOrWhiteSpace($Revision)) {
    $Revision = $ProjectName
}
if ([string]::IsNullOrWhiteSpace($SdcPath)) {
    $SdcPath = Join-Path $ProjectDir "constraints\\$ProjectName`_sta_clean.sdc"
}

$quartusSta = "D:\\eLinx\\eLinx3.0\\bin\\Passkey\\bin\\quartus_sta.exe"
if (-not (Test-Path $quartusSta)) {
    throw "quartus_sta.exe not found at $quartusSta"
}

$projectRoot = (Resolve-Path $ProjectDir).Path
$reportRoot = Join-Path $projectRoot "$ProjectName.runs\\$OutputSubdir"
$sdcResolved = (Resolve-Path $SdcPath).Path
$tclFile = Join-Path $reportRoot "$ProjectName`_postmap_sta_clean.tcl"
$reportFile = Join-Path $reportRoot "$ProjectName`_postmap_sta_clean.rpt"

New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null

$sdcUnix = $sdcResolved -replace "\\", "/"
$tcl = @"
project_open $ProjectName -revision $Revision
create_timing_netlist -post_map
read_sdc "$sdcUnix"
update_timing_netlist
puts "=== CLOCKS ==="
report_clocks
puts "=== OVERALL_SETUP_TOP20 ==="
report_timing -setup -npaths 20 -detail summary
puts "=== OVERALL_HOLD_TOP20 ==="
report_timing -hold -npaths 20 -detail summary
puts "=== VIDEO_25M_SETUP_TOP20 ==="
report_timing -from_clock {u_pll_1|altpll_component|pll|clk[1]} -to_clock {u_pll_1|altpll_component|pll|clk[1]} -setup -npaths 20 -detail summary
puts "=== VIDEO_25M_HOLD_TOP20 ==="
report_timing -from_clock {u_pll_1|altpll_component|pll|clk[1]} -to_clock {u_pll_1|altpll_component|pll|clk[1]} -hold -npaths 20 -detail summary
puts "=== PLL_125M_SETUP_TOP20 ==="
report_timing -from_clock {u_pll_1|altpll_component|pll|clk[0]} -to_clock {u_pll_1|altpll_component|pll|clk[0]} -setup -npaths 20 -detail summary
puts "=== PLL_125M_HOLD_TOP20 ==="
report_timing -from_clock {u_pll_1|altpll_component|pll|clk[0]} -to_clock {u_pll_1|altpll_component|pll|clk[0]} -hold -npaths 20 -detail summary
project_close
"@

Set-Content -Path $tclFile -Value $tcl -Encoding ASCII
Push-Location $projectRoot
try {
    & $quartusSta -t $tclFile 2>&1 | Tee-Object -FilePath $reportFile
    Write-Host "Timing report written to $reportFile"
}
finally {
    Pop-Location
}
