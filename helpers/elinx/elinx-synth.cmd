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
  echo [elinx-synth] ERROR: Native synthesis currently requires a real .epr project.
  echo [elinx-synth] ERROR: Resolve the project to a path that has a sibling .epr file.
  exit /b 1
)

set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\synth-%ELINX_PROJECT_NAME%.log"
echo [elinx-synth] Project=%ELINX_PROJECT_NAME%
echo [elinx-synth] Revision=%ELINX_PROJECT_REVISION%
echo [elinx-synth] Project file=%ELINX_PROJECT_FILE%
echo [elinx-synth] EPR=%ELINX_PROJECT_EPR%

py "%~dp0native_flow.py" synth --epr "%ELINX_PROJECT_EPR%" --revision "%ELINX_PROJECT_REVISION%" --log-dir "%ELINX_HELPER_LOG_DIR%" > "%ELINX_LAST_LOG%" 2>&1
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
echo [elinx-synth] Log=%ELINX_LAST_LOG%
exit /b %ELINX_EXIT%

:usage
echo Usage: elinx-synth.cmd ^<project^> [revision]
echo.
echo Project must resolve to a real .epr file. This wrapper runs native eLinx synthesis first,
echo then falls back to sibling .qpf ^+ quartus_map when native synth is not available for the design.
echo It produces .vqm/.ecp/.ver.pb under .runs\^<synth_run^>.
exit /b 1
