@echo off
setlocal

cd /d "%~dp0"

rem Formal release entry point. The PowerShell script owns validation and exit codes.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_release.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" echo [ERROR] Formal release packaging failed with exit code %EXIT_CODE%.
pause
endlocal & exit /b %EXIT_CODE%
