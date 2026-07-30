[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot "android"
$PubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$SourceApkPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-dev-debug.apk"
$DistDevPath = Join-Path $RepoRoot "dist\dev"
$DestinationApkPath = Join-Path $DistDevPath "PresenceKit-mobile-dev.apk"
$InfoPath = Join-Path $DistDevPath "PresenceKit-mobile-dev.build-info.txt"
$PackageName = "com.presencekit.mobile.dev"

function Stop-DevBuild {
    param([string]$Message)
    throw $Message
}

function Get-LocalProperties {
    param([string]$Path)
    $properties = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $properties }
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) { continue }
        $separator = $trimmed.IndexOf("=")
        if ($separator -le 0) { continue }
        $key = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()
        $properties[$key] = $value.Replace("\\", "\")
    }
    return $properties
}

function Resolve-Flutter {
    $localProperties = Get-LocalProperties -Path (Join-Path $AndroidRoot "local.properties")
    $candidates = @()
    if ($localProperties.ContainsKey("flutter.sdk")) {
        $candidates += Join-Path ([string]$localProperties["flutter.sdk"]) "bin\flutter.bat"
    }
    if ($env:FLUTTER_HOME) { $candidates += Join-Path $env:FLUTTER_HOME "bin\flutter.bat" }
    $pathCommand = Get-Command "flutter.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $pathCommand) { $candidates += $pathCommand.Source }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    Stop-DevBuild "flutter.bat was not found. Configure flutter.sdk in android/local.properties, FLUTTER_HOME, or PATH."
}

function Resolve-Aapt {
    $localProperties = Get-LocalProperties -Path (Join-Path $AndroidRoot "local.properties")
    $sdkCandidates = @()
    if ($localProperties.ContainsKey("sdk.dir")) { $sdkCandidates += [string]$localProperties["sdk.dir"] }
    if ($env:ANDROID_HOME) { $sdkCandidates += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $sdkCandidates += $env:ANDROID_SDK_ROOT }
    $sdkRoot = $null
    foreach ($candidate in $sdkCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            $sdkRoot = [IO.Path]::GetFullPath($candidate)
            break
        }
    }
    if ($null -eq $sdkRoot) { Stop-DevBuild "Android SDK was not found." }
    $toolDirectories = @(Get-ChildItem -LiteralPath (Join-Path $sdkRoot "build-tools") -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    foreach ($toolDirectory in $toolDirectories) {
        $aapt = Join-Path $toolDirectory.FullName "aapt.exe"
        if (Test-Path -LiteralPath $aapt -PathType Leaf) { return $aapt }
    }
    Stop-DevBuild "Android SDK aapt was not found in build-tools."
}

function Resolve-Adb {
    $localProperties = Get-LocalProperties -Path (Join-Path $AndroidRoot "local.properties")
    $sdkCandidates = @()
    if ($localProperties.ContainsKey("sdk.dir")) { $sdkCandidates += [string]$localProperties["sdk.dir"] }
    if ($env:ANDROID_HOME) { $sdkCandidates += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $sdkCandidates += $env:ANDROID_SDK_ROOT }
    foreach ($candidate in $sdkCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            $adb = Join-Path ([IO.Path]::GetFullPath($candidate)) "platform-tools\adb.exe"
            if (Test-Path -LiteralPath $adb -PathType Leaf) { return $adb }
        }
    }
    $pathCommand = Get-Command "adb.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $pathCommand -and (Test-Path -LiteralPath $pathCommand.Source -PathType Leaf)) { return $pathCommand.Source }
    Stop-DevBuild "Android SDK adb was not found. Configure sdk.dir in android/local.properties or add adb to PATH."
}

function Invoke-AdbWithTimeout {
    param(
        [string]$Adb,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 30
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Adb
    $startInfo.Arguments = (($Arguments | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { Stop-DevBuild "Could not start adb." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        Stop-DevBuild ("adb " + ($Arguments -join " ") + " timed out after $TimeoutSeconds seconds.")
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { Stop-DevBuild ("adb " + ($Arguments -join " ") + " failed with exit code " + $process.ExitCode + ".") }
    return ($stdout + [Environment]::NewLine + $stderr)
}

function Install-DevApk {
    param([string]$Adb, [string]$ApkPath)
    Write-Host "[INFO] Checking for one connected Android device..."
    $deviceOutput = Invoke-AdbWithTimeout -Adb $Adb -Arguments @("devices") -TimeoutSeconds 30
    $deviceLines = @($deviceOutput -split "`r?`n" | ForEach-Object { [string]$_ })
    $devices = @($deviceLines | Where-Object { $_ -match "^\S+\s+(device|unauthorized|offline)$" } | ForEach-Object {
        $parts = $_ -split "\s+"
        [PSCustomObject]@{ Serial = $parts[0]; State = $parts[1] }
    })
    if ($devices.Count -eq 0) { Stop-DevBuild "No connected Android device found. Connect and authorize the phone, then retry." }
    if ($devices.Count -ne 1) { Stop-DevBuild ("Expected exactly one connected Android device, found " + $devices.Count + ". Disconnect other devices and retry.") }
    if ($devices[0].State -ne "device") { Stop-DevBuild ("Connected Android device is not authorized and ready (state: " + $devices[0].State + "). Unlock the phone and authorize USB debugging.") }

    Write-Host "[RUN] adb install -r -d <Dev APK>"
    Invoke-AdbWithTimeout -Adb $Adb -Arguments @("-s", $devices[0].Serial, "install", "-r", "-d", $ApkPath) -TimeoutSeconds 60 | Out-Null
    Write-Host ("[DONE] Installed Dev APK on device " + $devices[0].Serial + ".")
}

function Invoke-Flutter {
    param([string]$Flutter, [string[]]$Arguments)
    Write-Host ("[RUN] flutter " + ($Arguments -join " "))
    & $Flutter @Arguments
    if ($LASTEXITCODE -ne 0) { Stop-DevBuild ("Flutter command failed with exit code " + $LASTEXITCODE + ".") }
}

function Get-ApkMetadata {
    param([string]$Aapt, [string]$ApkPath)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $badging = @(& $Aapt dump badging $ApkPath 2>&1 | ForEach-Object { [string]$_ })
        $toolExitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousErrorActionPreference }
    if ($toolExitCode -ne 0) { Stop-DevBuild "aapt could not read the Dev APK metadata." }
    $packageLine = $badging | Where-Object { $_ -match '^package:' } | Select-Object -First 1
    $packageMatch = if ($packageLine) { [regex]::Match($packageLine, "name='([^']+)'") } else { $null }
    $versionCodeMatch = if ($packageLine) { [regex]::Match($packageLine, "versionCode='([^']+)'") } else { $null }
    $versionNameMatch = if ($packageLine) { [regex]::Match($packageLine, "versionName='([^']+)'") } else { $null }
    if ($null -eq $packageLine -or -not $packageMatch.Success -or -not $versionCodeMatch.Success -or -not $versionNameMatch.Success) {
        Stop-DevBuild "aapt output did not contain package name, versionName, and versionCode."
    }
    return [PSCustomObject]@{
        PackageName = $packageMatch.Groups[1].Value
        VersionCode = $versionCodeMatch.Groups[1].Value
        VersionName = $versionNameMatch.Groups[1].Value
    }
}

function Assert-PubspecUnchanged {
    param([string]$ExpectedHash)
    if ((Get-FileHash -LiteralPath $PubspecPath -Algorithm SHA256).Hash -ne $ExpectedHash) {
        Stop-DevBuild "pubspec.yaml changed during Dev packaging; it will not be overwritten or committed."
    }
}

$sourceOutputOwned = $false
$destinationCreated = $false
try {
    if (-not (Test-Path -LiteralPath $PubspecPath -PathType Leaf)) { Stop-DevBuild "pubspec.yaml was not found." }
    $gitCommit = (& git -c core.excludesFile= -C $RepoRoot rev-parse HEAD 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($gitCommit)) { Stop-DevBuild "Could not determine the current Git commit." }
    $pubspecHash = (Get-FileHash -LiteralPath $PubspecPath -Algorithm SHA256).Hash
    $flutter = Resolve-Flutter
    $aapt = Resolve-Aapt
    $adb = Resolve-Adb

    if (Test-Path -LiteralPath $SourceApkPath -PathType Leaf) {
        Write-Host "[INFO] Removing stale Dev APK before building so a failed build cannot be copied."
        Remove-Item -LiteralPath $SourceApkPath -Force
    }
    $sourceOutputOwned = $true
    Invoke-Flutter -Flutter $flutter -Arguments @("pub", "get")
    Assert-PubspecUnchanged -ExpectedHash $pubspecHash
    Invoke-Flutter -Flutter $flutter -Arguments @("build", "apk", "--debug", "--flavor", "dev")
    Assert-PubspecUnchanged -ExpectedHash $pubspecHash
    if (-not (Test-Path -LiteralPath $SourceApkPath -PathType Leaf)) { Stop-DevBuild "Flutter reported success but app-dev-debug.apk was not produced." }

    $metadata = Get-ApkMetadata -Aapt $aapt -ApkPath $SourceApkPath
    if ($metadata.PackageName -ne $PackageName) {
        Remove-Item -LiteralPath $SourceApkPath -Force -ErrorAction SilentlyContinue
        Stop-DevBuild ("Dev APK package id mismatch: expected $PackageName, got " + $metadata.PackageName + ".")
    }

    New-Item -ItemType Directory -Path $DistDevPath -Force | Out-Null
    [IO.File]::Copy($SourceApkPath, $DestinationApkPath, $true)
    $destinationCreated = $true
    $buildTime = (Get-Date).ToString("o", [Globalization.CultureInfo]::InvariantCulture)
    $apkHash = (Get-FileHash -LiteralPath $DestinationApkPath -Algorithm SHA256).Hash.ToUpperInvariant()
    $info = @(
        "PresenceKit-mobile Dev APK"
        "buildType: debug"
        "apk: dist/dev/PresenceKit-mobile-dev.apk"
        "packageName: $($metadata.PackageName)"
        "versionName: $($metadata.VersionName)"
        "versionCode: $($metadata.VersionCode)"
        "apkSha256: $apkHash"
        "gitCommit: $gitCommit"
        "buildTime: $buildTime"
    )
    Set-Content -LiteralPath $InfoPath -Value ($info -join [Environment]::NewLine) -Encoding UTF8
    Install-DevApk -Adb $adb -ApkPath $DestinationApkPath

    Write-Host ""
    Write-Host "[DONE] Dev debug APK created successfully."
    Write-Host "APK path    : $([IO.Path]::GetFullPath($DestinationApkPath))"
    Write-Host "applicationId: $($metadata.PackageName)"
    Write-Host "versionName : $($metadata.VersionName)"
    Write-Host "versionCode : $($metadata.VersionCode)"
    Write-Host "Git commit  : $gitCommit"
    Write-Host "Build time  : $buildTime"
    Write-Host "Build info  : $([IO.Path]::GetFullPath($InfoPath))"
    exit 0
}
catch {
    if ($sourceOutputOwned -and (Test-Path -LiteralPath $SourceApkPath -PathType Leaf)) { Remove-Item -LiteralPath $SourceApkPath -Force -ErrorAction SilentlyContinue }
    if ($destinationCreated -and (Test-Path -LiteralPath $DestinationApkPath -PathType Leaf)) { Remove-Item -LiteralPath $DestinationApkPath -Force -ErrorAction SilentlyContinue }
    if ($destinationCreated -and (Test-Path -LiteralPath $InfoPath -PathType Leaf)) { Remove-Item -LiteralPath $InfoPath -Force -ErrorAction SilentlyContinue }
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
