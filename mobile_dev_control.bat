@echo off
setlocal enabledelayedexpansion
cd /d %~dp0

set PACKAGE=com.presencekit.mobile

rem ---- Resolve adb: local.properties > env vars > PATH > legacy default ----
set "ADB="
set "ANDROID_SDK="
if exist "%~dp0android\local.properties" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0android\local.properties") do (
    if "%%a"=="sdk.dir" set "ANDROID_SDK=%%b"
  )
)
if defined ANDROID_SDK set "ANDROID_SDK=!ANDROID_SDK:\\=\!"
if defined ANDROID_SDK if exist "!ANDROID_SDK!\platform-tools\adb.exe" set "ADB=!ANDROID_SDK!\platform-tools\adb.exe"
if not defined ADB if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined ADB if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
if not defined ADB for /f "delims=" %%i in ('where adb 2^>nul') do if not defined ADB set "ADB=%%i"
if not defined ADB if exist "D:\soft3\AndroidSDK\platform-tools\adb.exe" set "ADB=D:\soft3\AndroidSDK\platform-tools\adb.exe"
if not defined ADB (
  echo [ERROR] adb not found. Set sdk.dir in android\local.properties, or ANDROID_HOME, or add adb to PATH.
  pause & exit /b 1
)

:menu
cls
echo ==========================================
echo   Companion mobile dev control
echo ==========================================
echo.
echo   1. Start phone connection
echo   2. Stop phone connection
echo   3. Show status
echo   4. Quit
echo.
choice /c 1234 /n /m "Choose: "
if errorlevel 4 goto end
if errorlevel 3 goto status
if errorlevel 2 goto stop
if errorlevel 1 goto start

:start
cls
echo [1/3] Checking phone...
"%ADB%" devices
echo.
echo [2/3] Opening adb reverse tcp:8080 -^> tcp:8080...
"%ADB%" reverse tcp:8080 tcp:8080
if errorlevel 1 (
  echo.
  echo Failed to open adb reverse. Check USB debugging and cable.
  pause
  goto menu
)
echo.
echo [3/3] Launching app...
"%ADB%" shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1
echo.
echo Done. Keep the backend running on this PC.
pause
goto menu

:stop
cls
echo [1/2] Stopping app/background service...
"%ADB%" shell am force-stop %PACKAGE%
echo.
echo [2/2] Removing adb reverse tcp:8080...
"%ADB%" reverse --remove tcp:8080
echo.
echo Done. Phone app is stopped and the dev tunnel is closed.
pause
goto menu

:status
cls
echo Connected devices:
"%ADB%" devices
echo.
echo Active adb reverse rules:
"%ADB%" reverse --list
echo.
pause
goto menu

:end
endlocal
