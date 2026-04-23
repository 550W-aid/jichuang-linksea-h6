param(
    [string]$SourceProjectRoot = "D:\\Work\\FPGA\\eLinx\\VideoProc",
    [string]$CustomProjectRoot = "D:\\Work\\FPGA\\eLinx\\VideoProc\\VideoOnlySTA",
    [string]$ProjectName = "VideoOnlySTA"
)

$ErrorActionPreference = "Stop"

$setupScript = Join-Path $PSScriptRoot "setup_video_only_project.ps1"
$staScript = Join-Path $PSScriptRoot "run_quartus_sta_clean_generic.ps1"
$quartusMap = "D:\\eLinx\\eLinx3.0\\bin\\Passkey\\bin\\quartus_map.exe"
$quartusCdb = "D:\\eLinx\\eLinx3.0\\bin\\Passkey\\bin\\quartus_cdb.exe"
$implExe = "D:\\eLinx\\eLinx3.0\\bin\\shell\\bin\\Implementation.exe"

function Require-Path {
    param([string]$PathToCheck)
    if (-not (Test-Path $PathToCheck)) {
        throw "Required path not found: $PathToCheck"
    }
}

function Invoke-ImplementationChecked {
    param(
        [string]$StageName,
        [string]$TclPath,
        [string]$LogPath,
        [string]$RequiredPattern,
        [string]$RequiredArtifact
    )

    Require-Path $TclPath
    & $implExe -f $TclPath -silence 2>&1 | Tee-Object -FilePath $LogPath

    $logText = Get-Content -Path $LogPath -Raw
    if ($logText -match '\[ERROR\]' -or $logText -match 'process is failed') {
        throw "$StageName emitted errors. See $LogPath"
    }
    if ($RequiredPattern -and $logText -notmatch $RequiredPattern) {
        throw "$StageName did not report the expected completion marker. See $LogPath"
    }
    if ($RequiredArtifact) {
        Require-Path $RequiredArtifact
    }
}

Require-Path $setupScript
Require-Path $staScript
Require-Path $quartusMap
Require-Path $quartusCdb
Require-Path $implExe

& powershell -ExecutionPolicy Bypass -File $setupScript `
    -SourceProjectRoot $SourceProjectRoot `
    -OutputProjectRoot $CustomProjectRoot `
    -ProjectName $ProjectName

$projectQpf = Join-Path $CustomProjectRoot "$ProjectName.qpf"
$projectQsf = Join-Path $CustomProjectRoot "$ProjectName.qsf"
$projectRuns = Join-Path $CustomProjectRoot "$ProjectName.runs"
$synthRoot = Join-Path $projectRuns "synth_1"
$impleRoot = Join-Path $projectRuns "imple_1"
$vqmPath = Join-Path $synthRoot "$ProjectName.vqm"
$packTcl = Join-Path $synthRoot "$ProjectName`_pack.tcl"
$routeTcl = Join-Path $impleRoot "$ProjectName`_route.tcl"
$sdcPath = Join-Path $CustomProjectRoot "constraints\\$ProjectName`_sta_clean.sdc"
$staRawLog = Join-Path $projectRuns "sta_clean\\$ProjectName`_postmap_sta_raw.log"

Require-Path $projectQpf
Require-Path $projectQsf

Push-Location $CustomProjectRoot
try {
    & $quartusMap $ProjectName -c $ProjectName
    if ($LASTEXITCODE -ne 0) {
        throw "quartus_map failed with exit code $LASTEXITCODE"
    }

    $vqmArg = "--vqm=$($vqmPath -replace "\\", "/")"
    & $quartusCdb $ProjectName -c $ProjectName --netlist_type=map $vqmArg
    if ($LASTEXITCODE -ne 0) {
        throw "quartus_cdb failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Require-Path $vqmPath

$ethHits = Select-String -Path $vqmPath -Pattern 'g_eth_udp_loop|u_eth_udp_loop|checksum_acc|eth_udp_loop' -SimpleMatch:$false
if ($ethHits) {
    throw "Standalone VQM still contains Ethernet hierarchy: $($ethHits[0].Line)"
}

$mdioHits = Select-String -Path $vqmPath -Pattern 'g_mdio_rw_test|u_mdio_rw_test|mdio_dri' -SimpleMatch:$false
if ($mdioHits) {
    throw "Standalone VQM still contains Ethernet MDIO management hierarchy: $($mdioHits[0].Line)"
}

$ddioHits = Select-String -Path $vqmPath -Pattern 'altddio_out:u_gtx_clk_fwd|ddiodatain|dff_ddio_data_out' -SimpleMatch:$false
if ($ddioHits) {
    throw "Standalone VQM still contains Ethernet DDIO clock-forwarding atom: $($ddioHits[0].Line)"
}

$packLog = Join-Path $synthRoot "$ProjectName`_pack_stdout.log"
$routeLog = Join-Path $impleRoot "$ProjectName`_route_stdout.log"
$slackReport = Join-Path $impleRoot "$ProjectName.slack.rpt"

Invoke-ImplementationChecked `
    -StageName "eLinx pack" `
    -TclPath $packTcl `
    -LogPath $packLog `
    -RequiredPattern 'Packer process is complete' `
    -RequiredArtifact (Join-Path $synthRoot "$ProjectName`_eHiChip6.ecp")

Invoke-ImplementationChecked `
    -StageName "eLinx route" `
    -TclPath $routeTcl `
    -LogPath $routeLog `
    -RequiredPattern 'All was well!' `
    -RequiredArtifact $slackReport

$staExit = 0
try {
    & powershell -ExecutionPolicy Bypass -File $staScript `
        -ProjectDir $CustomProjectRoot `
        -ProjectName $ProjectName `
        -Revision $ProjectName `
        -SdcPath $sdcPath
}
catch {
    $staExit = 1
    Write-Warning "Standalone quartus_sta did not complete cleanly. See $staRawLog"
}

Write-Host "Video-only custom flow complete."
Write-Host "  Project root : $CustomProjectRoot"
Write-Host "  Synth VQM    : $vqmPath"
Write-Host "  Pack TCL     : $packTcl"
Write-Host "  Route TCL    : $routeTcl"
Write-Host "  Route slack  : $slackReport"
Write-Host "  STA exit     : $staExit"
