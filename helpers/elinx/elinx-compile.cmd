@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0common.cmd" bootstrap_env --quiet
if errorlevel 1 exit /b %ERRORLEVEL%

if "%~1"=="" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage

call "%~dp0common.cmd" resolve_project "%~1" "%~2"
if errorlevel 1 exit /b %ERRORLEVEL%

set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\compile-%ELINX_PROJECT_NAME%.log"
echo [elinx-compile] Project=%ELINX_PROJECT_NAME%
echo [elinx-compile] Revision=%ELINX_PROJECT_REVISION%
echo [elinx-compile] Project file=%ELINX_PROJECT_FILE%
if defined ELINX_PROJECT_EPR echo [elinx-compile] EPR=%ELINX_PROJECT_EPR%
if defined ELINX_PROJECT_QPF echo [elinx-compile] Backend QPF=%ELINX_PROJECT_QPF%

if defined ELINX_PROJECT_EPR (
  py "%~dp0native_flow.py" compile --epr "%ELINX_PROJECT_EPR%" --revision "%ELINX_PROJECT_REVISION%" --log-dir "%ELINX_HELPER_LOG_DIR%" > "%ELINX_LAST_LOG%" 2>&1
  set "ELINX_EXIT=%ERRORLEVEL%"
  type "%ELINX_LAST_LOG%"
  echo [elinx-compile] Log=%ELINX_LAST_LOG%
  exit /b %ELINX_EXIT%
)

call "%~dp0common.cmd" require_cli_backend_qpf
if errorlevel 1 exit /b %ERRORLEVEL%

pushd "%ELINX_PROJECT_DIR%" >nul
if errorlevel 1 (
  echo [elinx-compile] ERROR: Failed to enter project directory "%ELINX_PROJECT_DIR%".
  exit /b 1
)

"%ELINX_QUARTUS_SH%" --flow compile "%ELINX_PROJECT_NAME%" -c "%ELINX_PROJECT_REVISION%" > "%ELINX_LAST_LOG%" 2>&1
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
if not "%ELINX_EXIT%"=="0" call "%~dp0common.cmd" report_quartus_compat_hint "%ELINX_LAST_LOG%"
popd >nul

echo [elinx-compile] Log=%ELINX_LAST_LOG%
exit /b %ELINX_EXIT%

:usage
echo Usage: elinx-compile.cmd ^<project^> [revision]
echo.
echo Project may be:
echo   - an .epr path, which now runs native-first synth ^(+ quartus_map fallback^) + route
echo   - an existing .qpf path
echo   - a project directory containing an .epr or .qpf
echo   - a known repo project name such as bringup_uart_vga
echo.
echo For .epr compile, the helper will generate synthesis outputs, fall back to sibling .qpf synthesis
echo when native synth fails, and then continue into route.
exit /b 1
