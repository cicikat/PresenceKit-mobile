@echo off
setlocal

cd /d "%~dp0"

rem Dev/Test entry point. This never reads android\key.properties.
rem A connected, authorized Android device is required; the script installs the APK automatically.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build_dev.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" echo [ERROR] Dev/Test packaging failed with exit code %EXIT_CODE%.
pause
endlocal & exit /b %EXIT_CODE%
