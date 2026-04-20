@echo off
if "%~1"=="" goto :eof
set "_ELINX_DISPATCH=%~1"
if "%_ELINX_DISPATCH:~0,1%"==":" set "_ELINX_DISPATCH=%_ELINX_DISPATCH:~1%"
shift /1
call :%_ELINX_DISPATCH% %1 %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%

:bootstrap_env
if not defined ELINX_HOME set "ELINX_HOME=D:\eLinx3.0"
if "%ELINX_HOME:~-1%"=="\" set "ELINX_HOME=%ELINX_HOME:~0,-1%"

for %%I in ("%~dp0..\..") do set "ELINX_REPO_ROOT=%%~fI"
if "%ELINX_REPO_ROOT:~-1%"=="\" set "ELINX_REPO_ROOT=%ELINX_REPO_ROOT:~0,-1%"
if not defined ELINX_WORKSPACE_ROOT if exist "%ELINX_REPO_ROOT%\..\linksea_h6_env" set "ELINX_WORKSPACE_ROOT=%ELINX_REPO_ROOT%\..\linksea_h6_env"
if defined ELINX_WORKSPACE_ROOT if "%ELINX_WORKSPACE_ROOT:~-1%"=="\" set "ELINX_WORKSPACE_ROOT=%ELINX_WORKSPACE_ROOT:~0,-1%"
if not defined ELINX_PROJECTS_ROOT if defined ELINX_WORKSPACE_ROOT if exist "%ELINX_WORKSPACE_ROOT%\projects" set "ELINX_PROJECTS_ROOT=%ELINX_WORKSPACE_ROOT%\projects"
if defined ELINX_PROJECTS_ROOT if "%ELINX_PROJECTS_ROOT:~-1%"=="\" set "ELINX_PROJECTS_ROOT=%ELINX_PROJECTS_ROOT:~0,-1%"

set "ELINX_GUI=%ELINX_HOME%\eLinx3.0.exe"
set "ELINX_SHELL_BIN=%ELINX_HOME%\bin\shell\bin"
set "ELINX_PASSKEY_BIN=%ELINX_HOME%\bin\Passkey\bin"
set "ELINX_QUARTUS_SH=%ELINX_PASSKEY_BIN%\quartus_sh.exe"
set "ELINX_QUARTUS_MAP=%ELINX_PASSKEY_BIN%\quartus_map.exe"
set "ELINX_QUARTUS_STA=%ELINX_PASSKEY_BIN%\quartus_sta.exe"
set "ELINX_QUARTUS_PGM=%ELINX_PASSKEY_BIN%\quartus_pgm.exe"
set "ELINX_TCLSH=%ELINX_PASSKEY_BIN%\tclsh.exe"
set "ELINX_TCL_CLIENT=%ELINX_PASSKEY_BIN%\tcl_client.tcl"
set "ELINX_TCL_SERVER=%ELINX_PASSKEY_BIN%\tcl_server.tcl"
set "ELINX_NATIVE_IMPL=%ELINX_SHELL_BIN%\Implementation.exe"
set "ELINX_NATIVE_BITGEN=%ELINX_SHELL_BIN%\BitGenerator.exe"
set "ELINX_NATIVE_SYNTH=%ELINX_SHELL_BIN%\eLinx_synthesis.exe"
set "ELINX_DEFAULT_PORT=2589"

if not exist "%ELINX_GUI%" (
  echo [elinx-env] ERROR: eLinx GUI not found at "%ELINX_GUI%".
  exit /b 1
)
if not exist "%ELINX_SHELL_BIN%" (
  echo [elinx-env] ERROR: Native shell bin directory not found at "%ELINX_SHELL_BIN%".
  exit /b 1
)
if not exist "%ELINX_QUARTUS_SH%" (
  echo [elinx-env] ERROR: quartus_sh.exe not found at "%ELINX_QUARTUS_SH%".
  exit /b 1
)
if not exist "%ELINX_QUARTUS_MAP%" (
  echo [elinx-env] ERROR: quartus_map.exe not found at "%ELINX_QUARTUS_MAP%".
  exit /b 1
)
if not exist "%ELINX_QUARTUS_STA%" (
  echo [elinx-env] ERROR: quartus_sta.exe not found at "%ELINX_QUARTUS_STA%".
  exit /b 1
)
if not exist "%ELINX_QUARTUS_PGM%" (
  echo [elinx-env] ERROR: quartus_pgm.exe not found at "%ELINX_QUARTUS_PGM%".
  exit /b 1
)
if not exist "%ELINX_TCLSH%" (
  echo [elinx-env] ERROR: tclsh.exe not found at "%ELINX_TCLSH%".
  exit /b 1
)
if not exist "%ELINX_TCL_CLIENT%" (
  echo [elinx-env] ERROR: Tcl client script not found at "%ELINX_TCL_CLIENT%".
  exit /b 1
)
if not exist "%ELINX_NATIVE_IMPL%" (
  echo [elinx-env] ERROR: Native Implementation.exe not found at "%ELINX_NATIVE_IMPL%".
  exit /b 1
)
if not exist "%ELINX_NATIVE_BITGEN%" (
  echo [elinx-env] ERROR: Native BitGenerator.exe not found at "%ELINX_NATIVE_BITGEN%".
  exit /b 1
)
if not exist "%ELINX_NATIVE_SYNTH%" (
  echo [elinx-env] ERROR: Native eLinx_synthesis.exe not found at "%ELINX_NATIVE_SYNTH%".
  exit /b 1
)

if not defined ELINX_HELPER_LOG_DIR set "ELINX_HELPER_LOG_DIR=%USERPROFILE%\elinx-logs"
if not exist "%ELINX_HELPER_LOG_DIR%" mkdir "%ELINX_HELPER_LOG_DIR%" >nul 2>&1

call :ensure_path "%ELINX_SHELL_BIN%"
if errorlevel 1 exit /b 1
call :ensure_path "%ELINX_PASSKEY_BIN%"
if errorlevel 1 exit /b 1

if /I not "%~1"=="--quiet" call :print_env
exit /b 0

:ensure_path
echo ;%PATH%;| "%SystemRoot%\System32\findstr.exe" /I /C:";%~1;" >nul
if errorlevel 1 set "PATH=%~1;%PATH%"
exit /b 0

:print_env
echo [elinx-env] ELINX_HOME=%ELINX_HOME%
echo [elinx-env] SHELL_BIN=%ELINX_SHELL_BIN%
echo [elinx-env] PASSKEY_BIN=%ELINX_PASSKEY_BIN%
echo [elinx-env] LOG_DIR=%ELINX_HELPER_LOG_DIR%
if defined ELINX_WORKSPACE_ROOT echo [elinx-env] WORKSPACE_ROOT=%ELINX_WORKSPACE_ROOT%
if defined ELINX_PROJECTS_ROOT echo [elinx-env] PROJECTS_ROOT=%ELINX_PROJECTS_ROOT%
echo [elinx-env] Default Tcl server port=%ELINX_DEFAULT_PORT%
call :contains_non_ascii "%CD%" _ELINX_CWD_HAS_NON_ASCII
if "%_ELINX_CWD_HAS_NON_ASCII%"=="1" (
  echo [elinx-env] WARN: Current directory contains non-ASCII characters.
  echo [elinx-env] WARN: For compile and STA, prefer an ASCII-only project path or set ELINX_ALLOW_NON_ASCII=1 to override.
)
set "_ELINX_CWD_HAS_NON_ASCII="
exit /b 0

:contains_non_ascii
set "_ELINX_PATH_CHECK=%~1"
set "_ELINX_NON_ASCII=0"
for /f %%I in ('py -c "import os; p=os.environ.get('_ELINX_PATH_CHECK', ''); print(1 if any(ord(ch)//128 for ch in p) else 0)"') do set "_ELINX_NON_ASCII=%%I"
set "%~2=%_ELINX_NON_ASCII%"
set "_ELINX_PATH_CHECK="
set "_ELINX_NON_ASCII="
exit /b 0

:require_ascii_path
call :contains_non_ascii "%~1" _ELINX_PATH_NON_ASCII
if "%_ELINX_PATH_NON_ASCII%"=="1" (
  if /I not "%ELINX_ALLOW_NON_ASCII%"=="1" (
    echo [elinx] ERROR: %~2 path contains non-ASCII characters.
    echo [elinx] ERROR: Move the project to an ASCII-only path or set ELINX_ALLOW_NON_ASCII=1 to override.
    set "_ELINX_PATH_NON_ASCII="
    exit /b 1
  )
  echo [elinx] WARN: %~2 path contains non-ASCII characters. Continuing because ELINX_ALLOW_NON_ASCII=1.
)
set "_ELINX_PATH_NON_ASCII="
exit /b 0

:normalize_existing_file
if "%~1"=="" (
  echo [elinx] ERROR: Missing file path.
  exit /b 1
)
if not exist "%~1" (
  echo [elinx] ERROR: File not found: "%~1".
  exit /b 1
)
for %%I in ("%~1") do set "%~2=%%~fI"
exit /b 0

:require_cli_backend_qpf
if defined ELINX_PROJECT_QPF exit /b 0
echo [elinx] ERROR: No .qpf companion file was found for "%ELINX_PROJECT_FILE%".
echo [elinx] ERROR: This wrapper accepts .epr as the public project name, but the current CLI backend still requires a matching .qpf file.
exit /b 1

:resolve_project
set "ELINX_PROJECT_FILE="
set "ELINX_PROJECT_EPR="
set "ELINX_PROJECT_QPF="
set "ELINX_PROJECT_DIR="
set "ELINX_PROJECT_NAME="
set "ELINX_PROJECT_REVISION="
set "ELINX_PROJECT_REQUEST=%~1"
set "_ELINX_PROJECT_FILE="
set "_ELINX_PROJECT_INPUT=%~1"

if not defined _ELINX_PROJECT_INPUT set "_ELINX_PROJECT_INPUT=."

call :resolve_project_file "%_ELINX_PROJECT_INPUT%" _ELINX_PROJECT_FILE
if errorlevel 1 exit /b 1

for %%I in ("%_ELINX_PROJECT_FILE%") do (
  set "ELINX_PROJECT_FILE=%%~fI"
  set "ELINX_PROJECT_DIR=%%~dpI"
  set "ELINX_PROJECT_NAME=%%~nI"
  if /I "%%~xI"==".epr" set "ELINX_PROJECT_EPR=%%~fI"
  if /I "%%~xI"==".qpf" set "ELINX_PROJECT_QPF=%%~fI"
)
if "%ELINX_PROJECT_DIR:~-1%"=="\" set "ELINX_PROJECT_DIR=%ELINX_PROJECT_DIR:~0,-1%"

if not defined ELINX_PROJECT_EPR if exist "%ELINX_PROJECT_DIR%\%ELINX_PROJECT_NAME%.epr" (
  set "ELINX_PROJECT_EPR=%ELINX_PROJECT_DIR%\%ELINX_PROJECT_NAME%.epr"
)
if not defined ELINX_PROJECT_QPF if exist "%ELINX_PROJECT_DIR%\%ELINX_PROJECT_NAME%.qpf" (
  set "ELINX_PROJECT_QPF=%ELINX_PROJECT_DIR%\%ELINX_PROJECT_NAME%.qpf"
)

if not "%~2"=="" (
  set "ELINX_PROJECT_REVISION=%~2"
) else (
  set "ELINX_PROJECT_REVISION=%ELINX_PROJECT_NAME%"
)

call :require_ascii_path "%ELINX_PROJECT_FILE%" "Project"
if errorlevel 1 exit /b 1
exit /b 0

:resolve_project_file
set "_ELINX_RESOLVE_INPUT=%~1"
set "_ELINX_RESOLVE_RESULT="

if exist "%_ELINX_RESOLVE_INPUT%" (
  if /I "%~x1"==".epr" (
    for %%I in ("%_ELINX_RESOLVE_INPUT%") do set "_ELINX_RESOLVE_RESULT=%%~fI"
    goto resolve_project_file_done
  )
  if /I "%~x1"==".qpf" (
    for %%I in ("%_ELINX_RESOLVE_INPUT%") do set "_ELINX_RESOLVE_RESULT=%%~fI"
    goto resolve_project_file_done
  )
  if exist "%_ELINX_RESOLVE_INPUT%\NUL" (
    call :find_project_file_in_dir "%_ELINX_RESOLVE_INPUT%" _ELINX_RESOLVE_RESULT
    if errorlevel 1 exit /b 1
    goto resolve_project_file_done
  )
)

call :resolve_missing_public_alias "%_ELINX_RESOLVE_INPUT%" _ELINX_RESOLVE_RESULT
if defined _ELINX_RESOLVE_RESULT goto resolve_project_file_done

if exist "%_ELINX_RESOLVE_INPUT%.epr" (
  for %%I in ("%_ELINX_RESOLVE_INPUT%.epr") do set "_ELINX_RESOLVE_RESULT=%%~fI"
  goto resolve_project_file_done
)
if exist "%_ELINX_RESOLVE_INPUT%.qpf" (
  for %%I in ("%_ELINX_RESOLVE_INPUT%.qpf") do set "_ELINX_RESOLVE_RESULT=%%~fI"
  goto resolve_project_file_done
)

if exist "%ELINX_REPO_ROOT%\%_ELINX_RESOLVE_INPUT%.epr" (
  for %%I in ("%ELINX_REPO_ROOT%\%_ELINX_RESOLVE_INPUT%.epr") do set "_ELINX_RESOLVE_RESULT=%%~fI"
  goto resolve_project_file_done
)

if exist "%ELINX_REPO_ROOT%\%_ELINX_RESOLVE_INPUT%.qpf" (
  for %%I in ("%ELINX_REPO_ROOT%\%_ELINX_RESOLVE_INPUT%.qpf") do set "_ELINX_RESOLVE_RESULT=%%~fI"
  goto resolve_project_file_done
)

if defined ELINX_PROJECTS_ROOT if exist "%ELINX_PROJECTS_ROOT%\%_ELINX_RESOLVE_INPUT%\%_ELINX_RESOLVE_INPUT%.epr" (
  for %%I in ("%ELINX_PROJECTS_ROOT%\%_ELINX_RESOLVE_INPUT%\%_ELINX_RESOLVE_INPUT%.epr") do set "_ELINX_RESOLVE_RESULT=%%~fI"
  goto resolve_project_file_done
)
if defined ELINX_PROJECTS_ROOT if exist "%ELINX_PROJECTS_ROOT%\%_ELINX_RESOLVE_INPUT%\%_ELINX_RESOLVE_INPUT%.qpf" (
  for %%I in ("%ELINX_PROJECTS_ROOT%\%_ELINX_RESOLVE_INPUT%\%_ELINX_RESOLVE_INPUT%.qpf") do set "_ELINX_RESOLVE_RESULT=%%~fI"
  goto resolve_project_file_done
)

if defined ELINX_PROJECTS_ROOT if exist "%ELINX_PROJECTS_ROOT%\%_ELINX_RESOLVE_INPUT%" (
  call :find_project_file_in_dir "%ELINX_PROJECTS_ROOT%\%_ELINX_RESOLVE_INPUT%" _ELINX_RESOLVE_RESULT
  if errorlevel 1 exit /b 1
  goto resolve_project_file_done
)

echo [elinx] ERROR: Could not resolve project "%~1" to an .epr or .qpf file.
echo [elinx] ERROR: Pass an .epr file, an .epr-style project name, a .qpf file, a project directory, or a known ASCII workspace project name such as bringup_uart_vga.
exit /b 1

:resolve_project_file_done
set "%~2=%_ELINX_RESOLVE_RESULT%"
set "_ELINX_RESOLVE_INPUT="
set "_ELINX_RESOLVE_RESULT="
exit /b 0

:resolve_missing_public_alias
set "_ELINX_ALIAS_INPUT=%~1"
set "_ELINX_ALIAS_RESULT="

if /I "%~x1"==".epr" (
  for %%I in ("%_ELINX_ALIAS_INPUT%") do (
    if exist "%%~dpnI.qpf" (
      for %%J in ("%%~dpnI.qpf") do set "_ELINX_ALIAS_RESULT=%%~fJ"
    )
  )
)
if defined _ELINX_ALIAS_RESULT echo [elinx] INFO: "%~1" was requested as an .epr project name; using the sibling .qpf backend "%_ELINX_ALIAS_RESULT%".

set "%~2=%_ELINX_ALIAS_RESULT%"
set "_ELINX_ALIAS_INPUT="
set "_ELINX_ALIAS_RESULT="
exit /b 0

:find_project_file_in_dir
set "_ELINX_QPF_DIR=%~f1"
set "_ELINX_QPF_RESULT="
set "_ELINX_QPF_COUNT=0"

for %%I in ("%_ELINX_QPF_DIR%") do set "_ELINX_QPF_DIR_NAME=%%~nxI"
if exist "%_ELINX_QPF_DIR%\%_ELINX_QPF_DIR_NAME%.epr" (
  set "_ELINX_QPF_RESULT=%_ELINX_QPF_DIR%\%_ELINX_QPF_DIR_NAME%.epr"
  goto find_qpf_done
)
if exist "%_ELINX_QPF_DIR%\%_ELINX_QPF_DIR_NAME%.qpf" (
  set "_ELINX_QPF_RESULT=%_ELINX_QPF_DIR%\%_ELINX_QPF_DIR_NAME%.qpf"
  goto find_qpf_done
)

for /f "delims=" %%I in ('dir /b /a-d "%_ELINX_QPF_DIR%\*.epr" 2^>nul') do (
  set /a _ELINX_QPF_COUNT+=1
  if !_ELINX_QPF_COUNT! EQU 1 set "_ELINX_QPF_RESULT=%_ELINX_QPF_DIR%\%%I"
)
if "%_ELINX_QPF_COUNT%"=="1" goto find_qpf_done
if not "%_ELINX_QPF_COUNT%"=="0" (
  echo [elinx] ERROR: Multiple .epr files found in "%_ELINX_QPF_DIR%".
  echo [elinx] ERROR: Pass the exact project file path.
  exit /b 1
)

for /f "delims=" %%I in ('dir /b /a-d "%_ELINX_QPF_DIR%\*.qpf" 2^>nul') do (
  set /a _ELINX_QPF_COUNT+=1
  if !_ELINX_QPF_COUNT! EQU 1 set "_ELINX_QPF_RESULT=%_ELINX_QPF_DIR%\%%I"
)

if "%_ELINX_QPF_COUNT%"=="0" (
  echo [elinx] ERROR: No .epr or .qpf file found in "%_ELINX_QPF_DIR%".
  exit /b 1
)
if not "%_ELINX_QPF_COUNT%"=="1" (
  echo [elinx] ERROR: Multiple .qpf files found in "%_ELINX_QPF_DIR%".
  echo [elinx] ERROR: Pass the exact project file path.
  exit /b 1
)

:find_qpf_done
set "%~2=%_ELINX_QPF_RESULT%"
set "_ELINX_QPF_DIR="
set "_ELINX_QPF_DIR_NAME="
set "_ELINX_QPF_RESULT="
set "_ELINX_QPF_COUNT="
exit /b 0

:run_with_log
set "_ELINX_LOG_FILE=%~1"
set "_ELINX_COMMAND=%~2"

if "%_ELINX_LOG_FILE%"=="" (
  echo [elinx] ERROR: Missing log file path.
  exit /b 1
)
if "%_ELINX_COMMAND%"=="" (
  echo [elinx] ERROR: Missing command to execute.
  exit /b 1
)

"%SystemRoot%\System32\cmd.exe" /d /c %_ELINX_COMMAND% > "%_ELINX_LOG_FILE%" 2>&1
set "_ELINX_RUN_EXIT=%ERRORLEVEL%"
type "%_ELINX_LOG_FILE%"
exit /b %_ELINX_RUN_EXIT%

:report_quartus_compat_hint
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0

"%SystemRoot%\System32\findstr.exe" /C:eHiChip /C:"Part name EQ" "%~1" >nul 2>&1
if errorlevel 1 exit /b 0

echo [elinx] WARN: The Quartus-compatible backend launched correctly, but it does not understand the current eLinx family/device settings.
echo [elinx] WARN: This confirms the wrapper path is wired up, but a real device compile will need the native eLinx shell flow under "%ELINX_HOME%\bin\shell\bin".
exit /b 0
