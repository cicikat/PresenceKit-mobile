@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

rem ---- Resolve Flutter SDK: android/local.properties > FLUTTER_ROOT > PATH > legacy default ----
set "FLUTTER="
set "FLUTTER_SDK="
if exist "%~dp0android\local.properties" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0android\local.properties") do (
    if "%%a"=="flutter.sdk" set "FLUTTER_SDK=%%b"
  )
)
if defined FLUTTER_SDK set "FLUTTER_SDK=!FLUTTER_SDK:\\=\!"
if defined FLUTTER_SDK if exist "!FLUTTER_SDK!\bin\flutter.bat" set "FLUTTER=!FLUTTER_SDK!\bin\flutter.bat"
if not defined FLUTTER if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER=%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER for /f "delims=" %%i in ('where flutter 2^>nul') do if not defined FLUTTER set "FLUTTER=%%i"
if not defined FLUTTER if exist "D:\soft3\flutter\bin\flutter.bat" set "FLUTTER=D:\soft3\flutter\bin\flutter.bat"
if not defined FLUTTER (
  echo [ERROR] Flutter SDK not found.
  echo Set flutter.sdk in android\local.properties, set FLUTTER_ROOT, or add flutter to PATH.
  pause
  exit /b 1
)

set "DART_SUPPRESS_ANALYTICS=true"
set "APPDATA=%~dp0.tool-home"

echo ==========================================
echo   PresenceKit mobile - browser preview
echo ==========================================
echo Flutter: %FLUTTER%
echo.
echo [1/2] Checking dependencies...
call "%FLUTTER%" pub get
if errorlevel 1 (
  echo.
  echo [ERROR] Flutter dependency check failed.
  pause
  exit /b 1
)

echo.
set "WEB_DEVICE="
for /f "tokens=1" %%a in ('call "%FLUTTER%" devices 2^>nul') do (
  if /i "%%a"=="Chrome" set "WEB_DEVICE=chrome"
  if /i "%%a"=="Edge" if not defined WEB_DEVICE set "WEB_DEVICE=edge"
)
if not defined WEB_DEVICE (
  echo [ERROR] No Chrome or Edge Web device was found.
  echo Run flutter devices to check browser support.
  pause
  exit /b 1
)
echo Web device detected: !WEB_DEVICE!
echo [2/2] Starting !WEB_DEVICE! preview...
echo Close this window or press q in the Flutter terminal to stop the preview.
echo.
call "%FLUTTER%" run -d !WEB_DEVICE! --web-port 5353 %*
set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo Browser preview stopped. Exit code: %EXIT_CODE%
pause
exit /b %EXIT_CODE%
