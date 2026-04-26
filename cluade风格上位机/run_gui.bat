@echo off
setlocal
set "PROJECT_ROOT=%~dp0"
set "PYTHON_EXE=%PROJECT_ROOT%.venv\Scripts\python.exe"

if not exist "%PYTHON_EXE%" (
    echo Virtual environment not found.
    echo Please run:
    echo   python -m venv .venv
    echo   .\.venv\Scripts\python -m pip install -r requirements.txt
    exit /b 1
)

cd /d "%PROJECT_ROOT%"
"%PYTHON_EXE%" main.py
