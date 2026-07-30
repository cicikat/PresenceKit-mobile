@echo off
setlocal enabledelayedexpansion

cd /d %~dp0

set "PACKAGE=com.presencekit.mobile.dev"
set "FLAVOR=dev"
set "BUILD_MODE=debug"
set "APK=build\app\outputs\flutter-apk\app-dev-debug.apk"

rem ---- Resolve flutter / adb: local.properties > env vars > PATH > legacy default ----
set "FLUTTER="
set "ADB="
set "FLUTTER_SDK="
set "ANDROID_SDK="
if exist "%~dp0android\local.properties" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0android\local.properties") do (
    if "%%a"=="flutter.sdk" set "FLUTTER_SDK=%%b"
    if "%%a"=="sdk.dir" set "ANDROID_SDK=%%b"
  )
)
if defined FLUTTER_SDK set "FLUTTER_SDK=!FLUTTER_SDK:\\=\!"
if defined ANDROID_SDK set "ANDROID_SDK=!ANDROID_SDK:\\=\!"

if defined FLUTTER_SDK if exist "!FLUTTER_SDK!\bin\flutter.bat" set "FLUTTER=!FLUTTER_SDK!\bin\flutter.bat"
if not defined FLUTTER if defined FLUTTER_HOME if exist "%FLUTTER_HOME%\bin\flutter.bat" set "FLUTTER=%FLUTTER_HOME%\bin\flutter.bat"
if not defined FLUTTER for /f "delims=" %%i in ('where flutter.bat 2^>nul') do if not defined FLUTTER set "FLUTTER=%%i"
if not defined FLUTTER if exist "D:\soft3\flutter\bin\flutter.bat" set "FLUTTER=D:\soft3\flutter\bin\flutter.bat"

if defined ANDROID_SDK if exist "!ANDROID_SDK!\platform-tools\adb.exe" set "ADB=!ANDROID_SDK!\platform-tools\adb.exe"
if not defined ADB if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined ADB if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
if not defined ADB for /f "delims=" %%i in ('where adb 2^>nul') do if not defined ADB set "ADB=%%i"
if not defined ADB if exist "D:\soft3\AndroidSDK\platform-tools\adb.exe" set "ADB=D:\soft3\AndroidSDK\platform-tools\adb.exe"

if not defined FLUTTER (
  echo [ERROR] flutter not found. Set flutter.sdk in android\local.properties, or FLUTTER_HOME, or add flutter to PATH.
  pause & exit /b 1
)
if not defined ADB (
  echo [ERROR] adb not found. Set sdk.dir in android\local.properties, or ANDROID_HOME, or add adb to PATH.
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
echo [2/5] Building %FLAVOR% %BUILD_MODE% APK...
call "%FLUTTER%" build apk --%BUILD_MODE% --flavor %FLAVOR%
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
