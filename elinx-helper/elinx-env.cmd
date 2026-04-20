@echo off
call "%~dp0common.cmd" bootstrap_env %*
exit /b %ERRORLEVEL%
