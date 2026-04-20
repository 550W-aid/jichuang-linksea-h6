@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0common.cmd" bootstrap_env --quiet
if errorlevel 1 exit /b %ERRORLEVEL%

if "%~1"=="" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage

if /I "%~1"=="--list-cables" (
  set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\program-list-cables.log"
  "%ELINX_QUARTUS_PGM%" -l > "!ELINX_LAST_LOG!" 2>&1
  type "!ELINX_LAST_LOG!"
  exit /b !ERRORLEVEL!
)

if /I "%~1"=="--list-devices" (
  if "%~2"=="" (
    echo [elinx-program] ERROR: Missing cable name for --list-devices.
    exit /b 1
  )
  set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\program-list-devices.log"
  "%ELINX_QUARTUS_PGM%" -c "%~2" -a > "!ELINX_LAST_LOG!" 2>&1
  type "!ELINX_LAST_LOG!"
  exit /b !ERRORLEVEL!
)

if "%~2"=="" goto usage
if "%~3"=="" goto usage

call "%~dp0common.cmd" normalize_existing_file "%~3" ELINX_PROGRAM_ARTIFACT
if errorlevel 1 exit /b %ERRORLEVEL%
call "%~dp0common.cmd" require_ascii_path "%ELINX_PROGRAM_ARTIFACT%" "Programming artifact"
if errorlevel 1 exit /b %ERRORLEVEL%

set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\program-last.log"
echo [elinx-program] Cable=%~1
echo [elinx-program] Mode=%~2
echo [elinx-program] Artifact=%ELINX_PROGRAM_ARTIFACT%
if /I "%~x3"==".cdf" (
  "%ELINX_QUARTUS_PGM%" -c "%~1" "%ELINX_PROGRAM_ARTIFACT%" > "%ELINX_LAST_LOG%" 2>&1
) else (
  "%ELINX_QUARTUS_PGM%" -c "%~1" -m "%~2" -o "P;%ELINX_PROGRAM_ARTIFACT%" > "%ELINX_LAST_LOG%" 2>&1
)
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
exit /b %ELINX_EXIT%

:usage
echo Usage:
echo   elinx-program.cmd --list-cables
echo   elinx-program.cmd --list-devices ^<cable^>
echo   elinx-program.cmd ^<cable^> ^<mode^> ^<artifact^>
echo.
echo Examples:
echo   elinx-program.cmd --list-cables
echo   elinx-program.cmd --list-devices "USB-Blaster"
echo   elinx-program.cmd "USB-Blaster" JTAG output.sof
exit /b 1
