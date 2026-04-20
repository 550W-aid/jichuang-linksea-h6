param(
    [switch]$DumpVcd
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BuildDir = Join-Path $PSScriptRoot 'out\iverilog'
$Iverilog = 'C:\iverilog\bin\iverilog.exe'
$Vvp = 'C:\iverilog\bin\vvp.exe'
$Output = Join-Path $BuildDir 'VP_video_tb.vvp'

$Files = @(
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sim_1\new\VP_video_tb.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\VP_Top.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\ip\pll_1\pll_1.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\DISP\vga_top.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\DISP\gaussian3x3_stream_demo.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\CCIC_H6A_TRIED_ALGO_ARCHIVE_2026-04-19\01_raw_algorithm_library\stream_std_library\rtl\grayscale_stream_std.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\CCIC_H6A_TRIED_ALGO_ARCHIVE_2026-04-19\01_raw_algorithm_library\stream_std_library\rtl\window3x3_stream_std.v')
)

New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Remove-Item -LiteralPath $Output -Force -ErrorAction SilentlyContinue

& $Iverilog -g2001 -DSIM_PLL_STUB -o $Output @Files
if ($LASTEXITCODE -ne 0) {
    throw "iverilog compile failed with exit code $LASTEXITCODE"
}

Push-Location $BuildDir
try {
    $RunArgs = @($Output)
    if ($DumpVcd) {
        $RunArgs += '+dump_vcd'
    }

    & $Vvp @RunArgs
    if ($LASTEXITCODE -ne 0) {
        throw "vvp run failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
