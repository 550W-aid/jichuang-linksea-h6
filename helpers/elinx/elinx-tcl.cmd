@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0common.cmd" bootstrap_env --quiet
if errorlevel 1 exit /b %ERRORLEVEL%

if "%~1"=="" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage

if /I "%~1"=="-t" goto run_script
if /I "%~1"=="--tcl_eval" goto run_eval

goto usage

:run_script
if "%~2"=="" goto usage
call "%~dp0common.cmd" normalize_existing_file "%~2" ELINX_TCL_SCRIPT
if errorlevel 1 exit /b %ERRORLEVEL%
call "%~dp0common.cmd" require_ascii_path "%ELINX_TCL_SCRIPT%" "Tcl script"
if errorlevel 1 exit /b %ERRORLEVEL%
set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\tcl-script.log"
"%ELINX_QUARTUS_SH%" -t "%ELINX_TCL_SCRIPT%" > "%ELINX_LAST_LOG%" 2>&1
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
exit /b %ELINX_EXIT%

:run_eval
shift
if "%~1"=="" goto usage
set "ELINX_TCL_EXPR=%~1"
set "ELINX_LAST_LOG=%ELINX_HELPER_LOG_DIR%\tcl-eval.log"
"%ELINX_QUARTUS_SH%" --tcl_eval "%ELINX_TCL_EXPR%" > "%ELINX_LAST_LOG%" 2>&1
set "ELINX_EXIT=%ERRORLEVEL%"
type "%ELINX_LAST_LOG%"
exit /b %ELINX_EXIT%

:usage
echo Usage:
echo   elinx-tcl.cmd -t ^<script.tcl^>
echo   elinx-tcl.cmd --tcl_eval "^<command^>"
echo.
echo Example:
echo   elinx-tcl.cmd --tcl_eval "puts [pwd]"
exit /b 1
