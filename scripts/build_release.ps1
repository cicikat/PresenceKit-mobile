[CmdletBinding()]
param(
    [string]$VersionName,
    [string]$VersionCode
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AndroidRoot = Join-Path $RepoRoot "android"
$PubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$KeyPropertiesPath = Join-Path $AndroidRoot "key.properties"
$SourceApkPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-prod-release.apk"
$DistReleasePath = Join-Path $RepoRoot "dist\release"
$PackageName = "com.presencekit.mobile"
$ExpectedSignerDigest = "1869B348D9E26F13D8213FF60933BCF933FE6E8779D13198F655A4D7C0791FAE"

function Stop-ReleaseBuild {
    param([string]$Message)
    throw $Message
}

function Get-LocalProperties {
    param([string]$Path)

    $properties = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $properties
    }

    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }
        $separator = $trimmed.IndexOf("=")
        if ($separator -le 0) {
            continue
        }
        $key = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()
        $properties[$key] = $value.Replace("\\", "\")
    }
    return $properties
}

function Get-KeyProperties {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-ReleaseBuild "android/key.properties is required for a formal release. Debug signing is forbidden."
    }

    $properties = Get-LocalProperties -Path $Path
    foreach ($required in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (-not $properties.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$properties[$required])) {
            Stop-ReleaseBuild "android/key.properties is missing a required signing field."
        }
    }

    $storeFile = [string]$properties["storeFile"]
    $resolvedStoreFile = if ([IO.Path]::IsPathRooted($storeFile)) {
        [IO.Path]::GetFullPath($storeFile)
    } else {
        [IO.Path]::GetFullPath((Join-Path $AndroidRoot $storeFile))
    }

    $storeItem = Get-Item -LiteralPath $resolvedStoreFile -ErrorAction SilentlyContinue
    if ($null -eq $storeItem -or $storeItem.PSIsContainer) {
        Stop-ReleaseBuild "The keystore referenced by android/key.properties does not exist."
    }

    $repoPrefix = $RepoRoot.TrimEnd("\") + "\"
    $distPrefix = $DistReleasePath.TrimEnd("\") + "\"
    if ($resolvedStoreFile.StartsWith($distPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-ReleaseBuild "The signing keystore must not be stored in dist/release."
    }
    if ($resolvedStoreFile.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $relativeStoreFile = $resolvedStoreFile.Substring($RepoRoot.Length).TrimStart("\")
        & git -c core.excludesFile= -C $RepoRoot check-ignore --quiet -- $relativeStoreFile 2>$null
        if ($LASTEXITCODE -ne 0) {
            Stop-ReleaseBuild "The signing keystore is inside the repository but is not ignored."
        }
    }

    & git -c core.excludesFile= -C $RepoRoot check-ignore --quiet -- "android/key.properties" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Stop-ReleaseBuild "android/key.properties must remain ignored by Git."
    }

    Write-Host "[OK] Release signing configuration is present and the referenced keystore exists."
    return $properties
}

function Resolve-Flutter {
    $localProperties = Get-LocalProperties -Path (Join-Path $AndroidRoot "local.properties")
    $candidates = @()
    if ($localProperties.ContainsKey("flutter.sdk")) {
        $candidates += Join-Path ([string]$localProperties["flutter.sdk"]) "bin\flutter.bat"
    }
    if ($env:FLUTTER_HOME) {
        $candidates += Join-Path $env:FLUTTER_HOME "bin\flutter.bat"
    }
    $pathCommand = Get-Command "flutter.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $pathCommand) {
        $candidates += $pathCommand.Source
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    Stop-ReleaseBuild "flutter.bat was not found. Configure flutter.sdk in android/local.properties, FLUTTER_HOME, or PATH."
}

function Resolve-AndroidTools {
    $localProperties = Get-LocalProperties -Path (Join-Path $AndroidRoot "local.properties")
    $sdkCandidates = @()
    if ($localProperties.ContainsKey("sdk.dir")) {
        $sdkCandidates += [string]$localProperties["sdk.dir"]
    }
    if ($env:ANDROID_HOME) {
        $sdkCandidates += $env:ANDROID_HOME
    }
    if ($env:ANDROID_SDK_ROOT) {
        $sdkCandidates += $env:ANDROID_SDK_ROOT
    }

    $sdkRoot = $null
    foreach ($candidate in $sdkCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            $sdkRoot = [IO.Path]::GetFullPath($candidate)
            break
        }
    }
    if ($null -eq $sdkRoot) {
        Stop-ReleaseBuild "Android SDK was not found. Configure sdk.dir in android/local.properties or ANDROID_HOME."
    }

    $buildToolsRoot = Join-Path $sdkRoot "build-tools"
    $toolDirectories = @(Get-ChildItem -LiteralPath $buildToolsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending)
    foreach ($toolDirectory in $toolDirectories) {
        $apksigner = Join-Path $toolDirectory.FullName "apksigner.bat"
        $aapt = Join-Path $toolDirectory.FullName "aapt.exe"
        if ((Test-Path -LiteralPath $apksigner -PathType Leaf) -and (Test-Path -LiteralPath $aapt -PathType Leaf)) {
            return [PSCustomObject]@{
                Apksigner = $apksigner
                Aapt = $aapt
            }
        }
    }
    Stop-ReleaseBuild "Android SDK apksigner and aapt were not found in build-tools."
}

function Invoke-Flutter {
    param(
        [string]$Flutter,
        [string[]]$Arguments
    )

    Write-Host ("[RUN] flutter " + ($Arguments -join " "))
    & $Flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        Stop-ReleaseBuild ("Flutter command failed with exit code " + $LASTEXITCODE + ".")
    }
}

function Read-VersionInputs {
    $inputVersionName = $VersionName
    if ([string]::IsNullOrWhiteSpace($inputVersionName)) {
        $inputVersionName = Read-Host "versionName (for example 1.0.0 or 1.0.0-rc.1)"
    }
    $inputVersionName = $inputVersionName.Trim()
    if ($inputVersionName -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
        Stop-ReleaseBuild "versionName must be a semantic version such as 1.0.0 or 1.0.0-rc.1."
    }

    $inputVersionCode = $VersionCode
    if ([string]::IsNullOrWhiteSpace($inputVersionCode)) {
        $inputVersionCode = Read-Host "versionCode (positive integer; must increase for every Android release)"
    }
    $inputVersionCode = $inputVersionCode.Trim()
    if ($inputVersionCode -notmatch '^[1-9][0-9]*$') {
        Stop-ReleaseBuild "versionCode must be a positive integer."
    }
    $parsedVersionCode = 0L
    if (-not [Int64]::TryParse($inputVersionCode, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsedVersionCode) -or $parsedVersionCode -gt 2147483647) {
        Stop-ReleaseBuild "versionCode must be a positive Android integer no greater than 2147483647."
    }
    $inputVersionCode = $parsedVersionCode.ToString([Globalization.CultureInfo]::InvariantCulture)

    $pubspec = Get-Content -Raw -Encoding UTF8 $PubspecPath
    $pubspecVersionMatch = [regex]::Match($pubspec, '(?m)^\s*version:\s*[^\s+]+\+([0-9]+)\s*$')
    if ($pubspecVersionMatch.Success) {
        $currentVersionCode = [Int64]$pubspecVersionMatch.Groups[1].Value
        if ($parsedVersionCode -le $currentVersionCode) {
            Stop-ReleaseBuild ("versionCode must be greater than the current pubspec.yaml build number (" + $currentVersionCode + ").")
        }
    }
    return [PSCustomObject]@{
        VersionName = $inputVersionName
        VersionCode = $inputVersionCode
    }
}

function Get-SafeVersionPart {
    param([string]$Value)

    $invalid = [IO.Path]::GetInvalidFileNameChars()
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $Value.ToCharArray()) {
        if ([char]::IsControl($character) -or $invalid -contains $character) {
            [void]$builder.Append("_")
        } else {
            [void]$builder.Append($character)
        }
    }
    $safe = $builder.ToString().Trim()
    $safe = $safe.TrimEnd(".")
    if ([string]::IsNullOrWhiteSpace($safe)) {
        Stop-ReleaseBuild "versionName does not produce a usable APK filename."
    }
    return $safe
}

function Get-ApkMetadataSafe {
    param(
        [string]$Aapt,
        [string]$ApkPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $badging = @(& $Aapt dump badging $ApkPath 2>&1 | ForEach-Object { [string]$_ })
        $toolExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($toolExitCode -ne 0) {
        Stop-ReleaseBuild "aapt could not read the final APK metadata."
    }
    $packageLine = $badging | Where-Object { $_ -match '^package:' } | Select-Object -First 1
    $packageMatch = if ($packageLine) { [regex]::Match($packageLine, "name='([^']+)'") } else { $null }
    $versionCodeMatch = if ($packageLine) { [regex]::Match($packageLine, "versionCode='([^']+)'") } else { $null }
    $versionNameMatch = if ($packageLine) { [regex]::Match($packageLine, "versionName='([^']+)'") } else { $null }
    if ($null -eq $packageLine -or -not $packageMatch.Success -or -not $versionCodeMatch.Success -or -not $versionNameMatch.Success) {
        Stop-ReleaseBuild "aapt output did not contain package name, versionName, and versionCode."
    }
    return [PSCustomObject]@{
        PackageName = $packageMatch.Groups[1].Value
        VersionCode = $versionCodeMatch.Groups[1].Value
        VersionName = $versionNameMatch.Groups[1].Value
    }
}

function Normalize-Digest {
    param([string]$Digest)
    return (($Digest -replace '[^0-9A-Fa-f]', '').ToUpperInvariant())
}

function Format-Digest {
    param([string]$Digest)
    $normalized = Normalize-Digest $Digest
    if ($normalized.Length -ne 64) {
        return $normalized
    }
    return (($normalized -split '(.{2})' | Where-Object { $_ }) -join ':')
}

function Get-SignerDigest {
    param(
        [string]$Apksigner,
        [string]$ApkPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $verification = @(& $Apksigner verify --print-certs $ApkPath 2>&1 | ForEach-Object { [string]$_ })
        $toolExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($toolExitCode -ne 0) {
        Stop-ReleaseBuild "apksigner verification failed."
    }
    $digests = @()
    foreach ($line in $verification) {
        $match = [regex]::Match($line, 'certificate SHA-256 digest:\s*([0-9A-Fa-f: ]{64,95})')
        if ($match.Success) {
            $normalized = Normalize-Digest $match.Groups[1].Value
            if ($normalized.Length -eq 64) {
                $digests += $normalized
            }
        }
    }
    if ($digests.Count -eq 0) {
        Stop-ReleaseBuild "apksigner did not report a SHA-256 signer certificate digest."
    }
    if ($digests -notcontains $ExpectedSignerDigest) {
        Stop-ReleaseBuild ("The APK signer does not match the required historical PresenceKit-mobile signing identity (found " + (Format-Digest $digests[0]) + ").")
    }
    return $digests[0]
}

function Assert-PubspecUnchanged {
    param([string]$ExpectedHash)
    $currentHash = (Get-FileHash -LiteralPath $PubspecPath -Algorithm SHA256).Hash
    if ($currentHash -ne $ExpectedHash) {
        Stop-ReleaseBuild "pubspec.yaml changed during packaging; the script will not overwrite or commit it."
    }
}

$publishedApkPath = $null
$publishedInfoPath = $null
$publishedHashPath = $null
$publishedArtifactCreated = $false
$sourceOutputOwned = $false

try {
    if (-not (Test-Path -LiteralPath $PubspecPath -PathType Leaf)) {
        Stop-ReleaseBuild "pubspec.yaml was not found."
    }

    $gitCommit = (& git -c core.excludesFile= -C $RepoRoot rev-parse HEAD 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($gitCommit)) {
        Stop-ReleaseBuild "Could not determine the current Git commit."
    }
    $gitStatus = @(& git -c core.excludesFile= -C $RepoRoot status --porcelain 2>$null)
    $pubspecHash = (Get-FileHash -LiteralPath $PubspecPath -Algorithm SHA256).Hash

    $versionInputs = Read-VersionInputs
    $VersionName = $versionInputs.VersionName
    $VersionCode = $versionInputs.VersionCode
    $safeVersionName = Get-SafeVersionPart $VersionName
    $artifactStem = "PresenceKit-mobile-v$safeVersionName-build$VersionCode"
    $publishedApkPath = Join-Path $DistReleasePath "$artifactStem.apk"
    $publishedInfoPath = Join-Path $DistReleasePath "$artifactStem.build-info.txt"
    $publishedHashPath = Join-Path $DistReleasePath "$artifactStem.apk.sha256"

    Write-Host ""
    Write-Host "versionName : $VersionName"
    Write-Host "versionCode : $VersionCode"
    Write-Host "Git commit  : $gitCommit"
    Write-Host "Build type  : release"
    if ($gitStatus.Count -gt 0) {
        Write-Host "[WARN] The worktree has uncommitted changes; they will not be modified or committed by this script."
    }
    $confirmation = Read-Host "Build this formal release? [y/N]"
    if ($confirmation -notmatch '^(?i:y|yes)$') {
        Write-Host "[CANCELLED] No build was started."
        exit 0
    }

    if ((Test-Path -LiteralPath $publishedApkPath -PathType Leaf) -or
        (Test-Path -LiteralPath $publishedInfoPath -PathType Leaf) -or
        (Test-Path -LiteralPath $publishedHashPath -PathType Leaf)) {
        Stop-ReleaseBuild "A release artifact with this versionName/versionCode already exists; it will not be overwritten."
    }

    [void](Get-KeyProperties -Path $KeyPropertiesPath)
    $flutter = Resolve-Flutter
    $androidTools = Resolve-AndroidTools
    Write-Host "[INFO] flutter and Android SDK release verification tools are ready."
    Write-Host "[INFO] flutter clean skipped; the existing formal entry point did not require it."

    if (Test-Path -LiteralPath $SourceApkPath -PathType Leaf) {
        Write-Host "[INFO] Removing stale release APK before building so a failed build cannot be published."
        Remove-Item -LiteralPath $SourceApkPath -Force
    }
    $sourceOutputOwned = $true

    Invoke-Flutter -Flutter $flutter -Arguments @("pub", "get")
    Assert-PubspecUnchanged -ExpectedHash $pubspecHash

    Invoke-Flutter -Flutter $flutter -Arguments @(
        "build", "apk", "--release", "--flavor", "prod", "--build-name", $VersionName, "--build-number", $VersionCode
    )
    Assert-PubspecUnchanged -ExpectedHash $pubspecHash

    if (-not (Test-Path -LiteralPath $SourceApkPath -PathType Leaf)) {
        Stop-ReleaseBuild "Flutter reported success but app-prod-release.apk was not produced."
    }

    $sourceSignerDigest = Get-SignerDigest -Apksigner $androidTools.Apksigner -ApkPath $SourceApkPath
    $sourceMetadata = Get-ApkMetadataSafe -Aapt $androidTools.Aapt -ApkPath $SourceApkPath
    if (($sourceMetadata.PackageName -ne $PackageName) -or
        ($sourceMetadata.VersionName -ne $VersionName) -or
        ($sourceMetadata.VersionCode -ne $VersionCode)) {
        Remove-Item -LiteralPath $SourceApkPath -Force -ErrorAction SilentlyContinue
        Stop-ReleaseBuild "The built APK metadata does not match the requested package/version inputs."
    }
    Write-Host "[OK] APK signer matches the required historical identity: $(Format-Digest $sourceSignerDigest)"
    Write-Host "[OK] APK metadata verified: $($sourceMetadata.PackageName), $($sourceMetadata.VersionName), build $($sourceMetadata.VersionCode)"

    New-Item -ItemType Directory -Path $DistReleasePath -Force | Out-Null
    [IO.File]::Copy($SourceApkPath, $publishedApkPath, $false)
    $publishedApkPath = [IO.Path]::GetFullPath($publishedApkPath)
    $publishedArtifactCreated = $true

    $finalSignerDigest = Get-SignerDigest -Apksigner $androidTools.Apksigner -ApkPath $publishedApkPath
    $finalMetadata = Get-ApkMetadataSafe -Aapt $androidTools.Aapt -ApkPath $publishedApkPath
    if (($finalMetadata.PackageName -ne $PackageName) -or
        ($finalMetadata.VersionName -ne $VersionName) -or
        ($finalMetadata.VersionCode -ne $VersionCode)) {
        Stop-ReleaseBuild "The final copied APK metadata does not match the requested inputs."
    }

    $apkHash = (Get-FileHash -LiteralPath $publishedApkPath -Algorithm SHA256).Hash.ToUpperInvariant()
    $buildTime = (Get-Date).ToString("o", [Globalization.CultureInfo]::InvariantCulture)
    $relativeApkPath = $publishedApkPath.Substring($RepoRoot.Length).TrimStart("\").Replace("\", "/")
    $hashLine = "$apkHash  $([IO.Path]::GetFileName($publishedApkPath))"
    $info = @(
        "PresenceKit-mobile formal APK release"
        "buildType: release"
        "apk: $relativeApkPath"
        "packageName: $($finalMetadata.PackageName)"
        "versionName: $($finalMetadata.VersionName)"
        "versionCode: $($finalMetadata.VersionCode)"
        "apkSha256: $apkHash"
        "signerSha256: $(Format-Digest $finalSignerDigest)"
        "gitCommit: $gitCommit"
        "buildTime: $buildTime"
    )
    Set-Content -LiteralPath $publishedHashPath -Value $hashLine -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath $publishedInfoPath -Value ($info -join [Environment]::NewLine) -Encoding UTF8

    Write-Host ""
    Write-Host "[DONE] Formal release APK created successfully."
    Write-Host "APK path    : $publishedApkPath"
    Write-Host "versionName : $($finalMetadata.VersionName)"
    Write-Host "versionCode : $($finalMetadata.VersionCode)"
    Write-Host "APK SHA-256  : $apkHash"
    Write-Host "Signer SHA-256: $(Format-Digest $finalSignerDigest)"
    Write-Host "Git commit   : $gitCommit"
    Write-Host "Build time   : $buildTime"
    Write-Host "Build info   : $publishedInfoPath"
    exit 0
}
catch {
    if ($sourceOutputOwned -and (Test-Path -LiteralPath $SourceApkPath -PathType Leaf)) {
        Remove-Item -LiteralPath $SourceApkPath -Force -ErrorAction SilentlyContinue
    }
    if ($publishedArtifactCreated -and $null -ne $publishedApkPath -and (Test-Path -LiteralPath $publishedApkPath -PathType Leaf)) {
        Remove-Item -LiteralPath $publishedApkPath -Force -ErrorAction SilentlyContinue
    }
    if ($publishedArtifactCreated -and $null -ne $publishedInfoPath -and (Test-Path -LiteralPath $publishedInfoPath -PathType Leaf)) {
        Remove-Item -LiteralPath $publishedInfoPath -Force -ErrorAction SilentlyContinue
    }
    if ($publishedArtifactCreated -and $null -ne $publishedHashPath -and (Test-Path -LiteralPath $publishedHashPath -PathType Leaf)) {
        Remove-Item -LiteralPath $publishedHashPath -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
