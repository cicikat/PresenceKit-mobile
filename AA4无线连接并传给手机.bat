@echo off
setlocal
cd /d "%~dp0"

rem Pair/connect Android 11+ over Wi-Fi, then install an existing APK.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\wireless_phone.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" echo [ERROR] Wireless connection or installation failed with exit code %EXIT_CODE%.
pause
endlocal & exit /b %EXIT_CODE%
