@echo off
setlocal enabledelayedexpansion

cd /d %~dp0

rem ---- Produces a distributable release APK: dist\PresenceKit-mobile-vX.Y.Z.apk + .sha256 ----
rem ---- For installing to a connected device during dev, use AA1打包安装到手机.bat instead ----

rem ---- Resolve flutter: local.properties > env vars > PATH > legacy default ----
set "FLUTTER="
set "FLUTTER_SDK="
if exist "%~dp0android\local.properties" (
  for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0android\local.properties") do (
    if "%%a"=="flutter.sdk" set "FLUTTER_SDK=%%b"
  )
)
if defined FLUTTER_SDK set "FLUTTER_SDK=!FLUTTER_SDK:\\=\!"

if defined FLUTTER_SDK if exist "!FLUTTER_SDK!\bin\flutter.bat" set "FLUTTER=!FLUTTER_SDK!\bin\flutter.bat"
if not defined FLUTTER if defined FLUTTER_HOME if exist "%FLUTTER_HOME%\bin\flutter.bat" set "FLUTTER=%FLUTTER_HOME%\bin\flutter.bat"
if not defined FLUTTER for /f "delims=" %%i in ('where flutter.bat 2^>nul') do if not defined FLUTTER set "FLUTTER=%%i"
if not defined FLUTTER if exist "D:\soft3\flutter\bin\flutter.bat" set "FLUTTER=D:\soft3\flutter\bin\flutter.bat"

if not defined FLUTTER (
  echo [ERROR] flutter not found. Set flutter.sdk in android\local.properties, or FLUTTER_HOME, or add flutter to PATH.
  pause & exit /b 1
)

rem ---- Read version from pubspec.yaml (version: X.Y.Z+N -> vX.Y.Z) ----
set "PKG_VERSION="
for /f "usebackq tokens=2 delims= " %%v in (`findstr /b "version:" pubspec.yaml`) do set "PKG_VERSION=%%v"
if not defined PKG_VERSION (
  echo [ERROR] Could not read version from pubspec.yaml.
  pause & exit /b 1
)
for /f "tokens=1 delims=+" %%v in ("%PKG_VERSION%") do set "SEMVER=%%v"
set "TAG=v%SEMVER%"

if exist "android\key.properties" (
  echo [INFO] android\key.properties found - validating release signing.
) else (
  echo [ERROR] android\key.properties is required for a distributable release APK.
  echo [ERROR] See android\key.properties.example. No debug-signed release artifact will be produced.
  pause & exit /b 1
)

echo.
echo [1/3] Building release APK (%TAG%)...
call "%FLUTTER%" build apk --release
if errorlevel 1 (
  echo [ERROR] Build failed.
  pause & exit /b 1
)

set "SRC_APK=build\app\outputs\flutter-apk\app-release.apk"
if not exist "%SRC_APK%" (
  echo [ERROR] APK not found: %SRC_APK%
  pause & exit /b 1
)

echo.
echo [2/3] Copying to dist\PresenceKit-mobile-%TAG%.apk...
if not exist "dist" mkdir "dist"
set "DEST_APK=dist\PresenceKit-mobile-%TAG%.apk"
copy /y "%SRC_APK%" "%DEST_APK%" >nul

echo.
echo [3/3] Computing SHA256...
certutil -hashfile "%DEST_APK%" SHA256 | findstr /v "hash" > "%DEST_APK%.sha256"
type "%DEST_APK%.sha256"

echo.
echo [DONE] Release APK ready: %DEST_APK%
pause
endlocal
