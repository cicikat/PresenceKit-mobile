@echo off
setlocal

set ADB=D:\soft3\AndroidSDK\platform-tools\adb.exe
set PACKAGE=com.example.yexuan_memery

:menu
cls
echo ==========================================
echo   Yexuan mobile dev control
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
