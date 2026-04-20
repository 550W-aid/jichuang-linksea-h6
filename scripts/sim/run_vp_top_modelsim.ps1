param()

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BuildDir = Join-Path $PSScriptRoot 'out\modelsim'
$Vlib = 'C:\modeltech64_10.4\win64\vlib.exe'
$Vlog = 'C:\modeltech64_10.4\win64\vlog.exe'
$Vsim = 'C:\modeltech64_10.4\win64\vsim.exe'
$QuartusSimLib = 'C:\altera\13.0sp1\quartus\eda\sim_lib'

$VendorFiles = @(
    (Join-Path $QuartusSimLib '220model.v'),
    (Join-Path $QuartusSimLib 'sgate.v'),
    (Join-Path $QuartusSimLib 'altera_primitives.v'),
    (Join-Path $QuartusSimLib 'altera_mf.v'),
    (Join-Path $QuartusSimLib 'stratix_atoms.v')
)

$DesignFiles = @(
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sim_1\new\VP_video_tb.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\VP_Top.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\ip\pll_1\pll_1.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\DISP\vga_top.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\DISP\gaussian3x3_stream_demo.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\CCIC_H6A_TRIED_ALGO_ARCHIVE_2026-04-19\01_raw_algorithm_library\stream_std_library\rtl\grayscale_stream_std.v'),
    (Join-Path $ProjectRoot 'VideoProcess.srcs\sources_1\new\CCIC_H6A_TRIED_ALGO_ARCHIVE_2026-04-19\01_raw_algorithm_library\stream_std_library\rtl\window3x3_stream_std.v')
)

New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Push-Location $BuildDir
try {
    Remove-Item -LiteralPath 'work' -Recurse -Force -ErrorAction SilentlyContinue

    & $Vlib 'work'
    if ($LASTEXITCODE -ne 0) {
        throw "vlib failed with exit code $LASTEXITCODE"
    }

    & $Vlog -work work @VendorFiles
    if ($LASTEXITCODE -ne 0) {
        throw "vlog vendor library compile failed with exit code $LASTEXITCODE"
    }

    & $Vlog -work work @DesignFiles
    if ($LASTEXITCODE -ne 0) {
        throw "vlog design compile failed with exit code $LASTEXITCODE"
    }

    & $Vsim -c work.VP_video_tb -do 'run -all; quit -f'
    if ($LASTEXITCODE -ne 0) {
        throw "vsim run failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
