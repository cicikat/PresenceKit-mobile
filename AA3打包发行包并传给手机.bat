@echo off
setlocal

cd /d "%~dp0"

rem Formal release packaging plus installation on one authorized Android device.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_release.ps1" -InstallOnDevice %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" echo [ERROR] Formal release packaging or installation failed with exit code %EXIT_CODE%.
pause
endlocal & exit /b %EXIT_CODE%
