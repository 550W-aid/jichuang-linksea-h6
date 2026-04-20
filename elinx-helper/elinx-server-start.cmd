@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0common.cmd" bootstrap_env --quiet
if errorlevel 1 exit /b %ERRORLEVEL%

set "QUARTUS_ENABLE_TCL_SERVER=1"
set "QUARTUS_TCL_PORT=%ELINX_DEFAULT_PORT%"
set "ELINX_SERVER_TARGET=shell"

if /I "%~1"=="--gui" set "ELINX_SERVER_TARGET=gui"
if /I "%~2"=="--gui" set "ELINX_SERVER_TARGET=gui"

if not "%~1"=="" if /I not "%~1"=="--gui" set "QUARTUS_TCL_PORT=%~1"
if not "%~2"=="" if /I not "%~2"=="--gui" set "QUARTUS_TCL_PORT=%~2"

if /I "%ELINX_SERVER_TARGET%"=="gui" (
  start "eLinx Tcl Server %QUARTUS_TCL_PORT%" "%ELINX_GUI%"
) else (
  start "eLinx Tcl Server %QUARTUS_TCL_PORT%" "%ELINX_QUARTUS_SH%" -s
)

echo [elinx-server-start] Started %ELINX_SERVER_TARGET% Tcl server on port %QUARTUS_TCL_PORT%.
echo [elinx-server-start] The server stays alive while the launched window remains open.
exit /b 0
