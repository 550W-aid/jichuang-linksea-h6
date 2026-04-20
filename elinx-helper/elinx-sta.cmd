@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0common.cmd" bootstrap_env --quiet
if errorlevel 1 exit /b %ERRORLEVEL%

if "%~1"=="" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage

call "%~dp0common.cmd" resolve_project "%~1" "%~2"
if errorlevel 1 exit /b %ERRORLEVEL%

if not "%~3"=="" (
  call "%~dp0common.cmd" normalize_existing_file "%~3" ELINX_REPORT_SCRIPT
  if errorlevel 1 exit /b %ERRORLEVEL%
  call "%~dp0common.cmd" require_ascii_path "%ELINX_REPORT_SCRIPT%" "Report script"
  if errorlevel 1 exit /b %ERRORLEVEL%
)

set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\sta-%ELINX_PROJECT_NAME%.log"
echo [elinx-sta] Project=%ELINX_PROJECT_NAME%
echo [elinx-sta] Revision=%ELINX_PROJECT_REVISION%
echo [elinx-sta] Project file=%ELINX_PROJECT_FILE%
if defined ELINX_PROJECT_EPR echo [elinx-sta] EPR=%ELINX_PROJECT_EPR%
if defined ELINX_PROJECT_QPF echo [elinx-sta] Backend QPF=%ELINX_PROJECT_QPF%
if defined ELINX_REPORT_SCRIPT echo [elinx-sta] Report script=%ELINX_REPORT_SCRIPT%

if defined ELINX_PROJECT_EPR if not defined ELINX_REPORT_SCRIPT (
  py "%~dp0native_flow.py" sta --epr "%ELINX_PROJECT_EPR%" --log-dir "%ELINX_HELPER_LOG_DIR%" > "%ELINX_LAST_LOG%" 2>&1
  set "ELINX_EXIT=%ERRORLEVEL%"
  type "%ELINX_LAST_LOG%"
  echo [elinx-sta] Log=%ELINX_LAST_LOG%
  exit /b %ELINX_EXIT%
)

call "%~dp0common.cmd" require_cli_backend_qpf
if errorlevel 1 exit /b %ERRORLEVEL%

pushd "%ELINX_PROJECT_DIR%" >nul
if errorlevel 1 (
  echo [elinx-sta] ERROR: Failed to enter project directory "%ELINX_PROJECT_DIR%".
  exit /b 1
)

if defined ELINX_REPORT_SCRIPT (
  "%ELINX_QUARTUS_STA%" "%ELINX_PROJECT_NAME%" -c "%ELINX_PROJECT_REVISION%" --report_script="%ELINX_REPORT_SCRIPT%" > "%ELINX_LAST_LOG%" 2>&1
) else (
  "%ELINX_QUARTUS_STA%" "%ELINX_PROJECT_NAME%" -c "%ELINX_PROJECT_REVISION%" --do_report_timing > "%ELINX_LAST_LOG%" 2>&1
)
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
if not "%ELINX_EXIT%"=="0" call "%~dp0common.cmd" report_quartus_compat_hint "%ELINX_LAST_LOG%"
popd >nul

echo [elinx-sta] Log=%ELINX_LAST_LOG%
exit /b %ELINX_EXIT%

:usage
echo Usage: elinx-sta.cmd ^<project^> [revision] [report_script.tcl]
echo.
echo Project may be passed with an .epr name; native .epr timing is preferred when no custom report script is provided.
echo If a custom report script is provided, the wrapper falls back to the Quartus-compatible .qpf backend.
exit /b 1
