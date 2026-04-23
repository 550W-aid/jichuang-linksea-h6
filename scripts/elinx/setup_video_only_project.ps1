param(
    [string]$SourceProjectRoot = "D:\\Work\\FPGA\\eLinx\\VideoProc",
    [string]$OutputProjectRoot = "D:\\Work\\FPGA\\eLinx\\VideoProc\\VideoOnlySTA",
    [string]$ProjectName = "VideoOnlySTA",
    [string]$TopEntity = "VP_Top"
)

$ErrorActionPreference = "Stop"

function Convert-ToUnixPath {
    param([string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    return ($fullPath -replace "\\", "/")
}

$sourceQpf = Join-Path $SourceProjectRoot "VideoProcess.qpf"
$sourceQsf = Join-Path $SourceProjectRoot "VideoProcess.qsf"
$sourceEpr = Join-Path $SourceProjectRoot "VideoProcess.epr"
$sourceSynthPsf = Join-Path $SourceProjectRoot "VideoProcess.runs\\synth_1\\VideoProcess.run.psf"
$sourceImplPsf = Join-Path $SourceProjectRoot "VideoProcess.runs\\imple_1\\VideoProcess.run.psf"
$sourceCleanSdc = Join-Path $SourceProjectRoot "VideoProcess.srcs\\constrs_1\\new\\VideoProcess_sta_clean.sdc"
$wrapperTop = Join-Path $SourceProjectRoot "VideoProcess.srcs\\sources_1\\new\\VP_Top_board_video_only.v"
$minimalVgaTop = Join-Path $SourceProjectRoot "VideoProcess.srcs\\sources_1\\new\\DISP\\vga_top_gaussian_only.v"

$projectRunsRoot = Join-Path $OutputProjectRoot "$ProjectName.runs"
$synthRoot = Join-Path $projectRunsRoot "synth_1"
$impleRoot = Join-Path $projectRunsRoot "imple_1"
$constraintRoot = Join-Path $OutputProjectRoot "constraints"

New-Item -ItemType Directory -Force -Path $OutputProjectRoot, $projectRunsRoot, $synthRoot, $impleRoot, $constraintRoot | Out-Null

$qpfText = Get-Content -Path $sourceQpf -Raw
$qpfText = [regex]::Replace($qpfText, 'PROJECT_REVISION = ".*"', "PROJECT_REVISION = `"$ProjectName`"")
Set-Content -Path (Join-Path $OutputProjectRoot "$ProjectName.qpf") -Value $qpfText -Encoding ASCII

$qsfText = Get-Content -Path $sourceQsf -Raw
$qsfText = [regex]::Replace(
    $qsfText,
    'set_global_assignment -name TOP_LEVEL_ENTITY .*',
    "set_global_assignment -name TOP_LEVEL_ENTITY $TopEntity"
)
$qsfText = [regex]::Replace(
    $qsfText,
    'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY \".*\"',
    ('set_global_assignment -name PROJECT_OUTPUT_DIRECTORY "{0}"' -f (Convert-ToUnixPath $synthRoot))
)
$qsfText = [regex]::Replace(
    $qsfText,
    'set_global_assignment -name VERILOG_FILE \".*/VP_Top\.v\"',
    ('set_global_assignment -name VERILOG_FILE "{0}"' -f (Convert-ToUnixPath $wrapperTop))
)
if ($qsfText -notmatch [regex]::Escape((Convert-ToUnixPath $minimalVgaTop))) {
    $qsfText += "`r`n" + ('set_global_assignment -name VERILOG_FILE "{0}"' -f (Convert-ToUnixPath $minimalVgaTop)) + "`r`n"
}
Set-Content -Path (Join-Path $OutputProjectRoot "$ProjectName.qsf") -Value $qsfText -Encoding ASCII

[xml]$eprXml = Get-Content -Path $sourceEpr
$eprXml.Project.Path = "/$ProjectName.epr"

foreach ($fileSet in $eprXml.Project.FileSets.FileSet) {
    foreach ($file in $fileSet.File) {
        $pathText = [string]$file.Path
        if ($pathText -eq "/VideoProcess.srcs/sources_1/new/VP_Top.v") {
            $file.Path = Convert-ToUnixPath $wrapperTop
        }
        elseif ($pathText.StartsWith("/")) {
            $resolvedPath = Join-Path $SourceProjectRoot ($pathText.TrimStart('/') -replace '/', '\')
            $file.Path = Convert-ToUnixPath $resolvedPath
        }
    }

    if ($fileSet.Config -and $fileSet.Config.Option) {
        foreach ($option in $fileSet.Config.Option) {
            $optVal = [string]$option.Val
            if ($optVal.StartsWith("/")) {
                $resolvedOpt = Join-Path $SourceProjectRoot ($optVal.TrimStart('/') -replace '/', '\')
                $option.Val = Convert-ToUnixPath $resolvedOpt
            }
        }
    }
}

if ($eprXml.Project.Configuration -and $eprXml.Project.Configuration.Option) {
    foreach ($option in $eprXml.Project.Configuration.Option) {
        if ($option.Name -eq "SimulationTopModule") {
            $option.Val = "VP_video_tb"
        }
    }
}

foreach ($run in $eprXml.Project.Runs.Run) {
    if ($run.Option) {
        foreach ($option in $run.Option) {
            if ($option.Id -eq "TopModule") {
                $option.InnerText = $TopEntity
            }
        }
    }
}

$eprXml.Save((Join-Path $OutputProjectRoot "$ProjectName.epr"))

Get-Content -Path $sourceSynthPsf |
    Where-Object { $_ -notmatch 'u_eth_udp_loop\|sys_clk' } |
    Set-Content -Path (Join-Path $synthRoot "$ProjectName.run.psf") -Encoding ASCII
Get-Content -Path $sourceImplPsf |
    Where-Object { $_ -notmatch 'u_eth_udp_loop\|sys_clk' } |
    Set-Content -Path (Join-Path $impleRoot "$ProjectName.run.psf") -Encoding ASCII

$cleanSdcTarget = Join-Path $constraintRoot "$ProjectName`_sta_clean.sdc"
Copy-Item -Path $sourceCleanSdc -Destination $cleanSdcTarget -Force

$packTcl = @"
cd   "D:/eLinx/eLinx3.0/bin/shell/bin"
set tclFile  "D:/eLinx/eLinx3.0/bin/shell/bin/run_pack.tcl"
set dir "$(Convert-ToUnixPath $OutputProjectRoot)"
set prj $ProjectName
set topEntity $TopEntity
set seriesName "eHiChip6"
set deviceName "EQ6HL130"
set packageName "CSG484_H"
set synthName synth_1
source `$tclFile
run_pack `$dir `$prj `$topEntity `$seriesName `$deviceName `$packageName `$synthName
exit 0
"@
Set-Content -Path (Join-Path $synthRoot "$ProjectName`_pack.tcl") -Value $packTcl -Encoding ASCII

$routeTcl = @"
cd   "D:/eLinx/eLinx3.0/bin/shell/bin"
set tclFile  "D:/eLinx/eLinx3.0/bin/shell/bin/run_route.tcl"
set dir "$(Convert-ToUnixPath $OutputProjectRoot)"
set prj $ProjectName
set topEntity $TopEntity
set seriesName "eHiChip6"
set deviceName "EQ6HL130"
set packageName "CSG484_H"
set synthName synth_1
set ImpleName imple_1
source `$tclFile
run_route `$dir `$prj `$topEntity `$seriesName `$deviceName `$packageName `$synthName `$ImpleName
exit 0
"@
Set-Content -Path (Join-Path $impleRoot "$ProjectName`_route.tcl") -Value $routeTcl -Encoding ASCII

Write-Host "Video-only project prepared:"
Write-Host "  Root : $OutputProjectRoot"
Write-Host "  QPF  : $(Join-Path $OutputProjectRoot "$ProjectName.qpf")"
Write-Host "  QSF  : $(Join-Path $OutputProjectRoot "$ProjectName.qsf")"
Write-Host "  PSF  : $(Join-Path $synthRoot "$ProjectName.run.psf")"
Write-Host "  SDC  : $cleanSdcTarget"
