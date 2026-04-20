@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0common.cmd" bootstrap_env --quiet
if errorlevel 1 exit /b %ERRORLEVEL%

if "%~1"=="" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage

call "%~dp0common.cmd" resolve_project "%~1" "%~2"
if errorlevel 1 exit /b %ERRORLEVEL%

if not defined ELINX_PROJECT_EPR (
  echo [elinx-bitgen] ERROR: Native bitgen currently requires a real .epr project.
  echo [elinx-bitgen] ERROR: Resolve the project to a path that has a sibling .epr file.
  exit /b 1
)

set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\bitgen-%ELINX_PROJECT_NAME%.log"
echo [elinx-bitgen] Project=%ELINX_PROJECT_NAME%
echo [elinx-bitgen] Revision=%ELINX_PROJECT_REVISION%
echo [elinx-bitgen] Project file=%ELINX_PROJECT_FILE%
echo [elinx-bitgen] EPR=%ELINX_PROJECT_EPR%

py "%~dp0native_flow.py" bitgen --epr "%ELINX_PROJECT_EPR%" --log-dir "%ELINX_HELPER_LOG_DIR%" > "%ELINX_LAST_LOG%" 2>&1
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
echo [elinx-bitgen] Log=%ELINX_LAST_LOG%
exit /b %ELINX_EXIT%

:usage
echo Usage: elinx-bitgen.cmd ^<project^> [revision]
echo.
echo Project must resolve to a real .epr file. This wrapper runs native eLinx bitgen
echo and produces .psk/.min/.fst under .runs\^<imple_run^>.
exit /b 1
