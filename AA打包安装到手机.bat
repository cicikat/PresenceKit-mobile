@echo off
setlocal enabledelayedexpansion

set "FLUTTER=D:\soft3\flutter\bin\flutter.bat"
set "ADB=D:\soft3\AndroidSDK\platform-tools\adb.exe"
set "PACKAGE=com.example.yexuan_memery"
set "APK=build\app\outputs\flutter-apk\app-debug.apk"

cd /d %~dp0

if not exist "%FLUTTER%" (
  echo [ERROR] flutter not found: %FLUTTER%
  pause & exit /b 1
)
if not exist "%ADB%" (
  echo [ERROR] adb not found: %ADB%
  pause & exit /b 1
)

echo [1/5] Waiting for device...
"%ADB%" start-server >nul 2>&1
"%ADB%" wait-for-device
if errorlevel 1 (
  echo [ERROR] No device found.
  pause & exit /b 1
)
"%ADB%" devices

echo.
echo [2/5] Building debug APK...
call "%FLUTTER%" build apk --debug
if errorlevel 1 (
  echo [ERROR] Build failed.
  pause & exit /b 1
)
if not exist "%APK%" (
  echo [ERROR] APK not found: %APK%
  pause & exit /b 1
)

echo.
echo [3/5] Installing APK...
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo [WARN] Install failed, trying uninstall + reinstall...
  choice /c YN /n /m "Uninstall old version and reinstall? (Y/N): "
  if errorlevel 2 (
    echo Cancelled.
    pause & exit /b 1
  )
  "%ADB%" uninstall %PACKAGE%
  "%ADB%" install "%APK%"
  if errorlevel 1 (
    echo [ERROR] Reinstall failed.
    pause & exit /b 1
  )
)

echo.
echo [4/5] Setting up adb reverse...
"%ADB%" reverse tcp:8080 tcp:8080
if errorlevel 1 (
  echo [WARN] adb reverse failed.
)

echo.
echo [5/5] Launching App...
"%ADB%" shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 >nul 2>&1

echo.
echo [DONE] Build and install complete.
pause
endlocal
