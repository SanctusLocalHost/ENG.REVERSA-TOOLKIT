@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0eng.ps1" %*
exit /b %ERRORLEVEL%
