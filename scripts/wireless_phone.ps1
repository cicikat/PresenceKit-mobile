[CmdletBinding()]
param(
    [string]$ConnectAddress,
    [string]$PairAddress,
    [string]$ApkPath,
    [switch]$ConnectOnly,
    [switch]$ReverseBackend
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-WirelessAdb {
    $sdkRoots = @()
    $propertiesPath = Join-Path $RepoRoot 'android\local.properties'
    if (Test-Path -LiteralPath $propertiesPath -PathType Leaf) {
        foreach ($line in (Get-Content -LiteralPath $propertiesPath -Encoding UTF8)) {
            if ($line -match '^\s*sdk\.dir\s*=(.*)$') {
                $sdkRoots += $Matches[1].Trim().Replace('\\', '\')
            }
        }
    }
    if ($env:ANDROID_HOME) { $sdkRoots += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $sdkRoots += $env:ANDROID_SDK_ROOT }
    foreach ($sdkRoot in $sdkRoots) {
        $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    $command = Get-Command adb.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) { return $command.Source }
    throw '找不到 adb：请配置 android/local.properties 的 sdk.dir、ANDROID_HOME 或 PATH。'
}

function Assert-WirelessAddress {
    param([string]$Address)
    $parsedIp = $null
    if ($Address -notmatch '^(\d{1,3}(?:\.\d{1,3}){3}):(\d{1,5})$') {
        throw '地址格式应为 IPv4:端口，例如 192.168.1.10:37123；请照手机页面填写。'
    }
    $hostPart = $Matches[1]
    $portNumber = [int]$Matches[2]
    if (-not [Net.IPAddress]::TryParse($hostPart, [ref]$parsedIp) -or $portNumber -lt 1 -or $portNumber -gt 65535) {
        throw 'IP 地址或端口无效，请重新查看手机页面。'
    }
}

function Invoke-WirelessAdb {
    param(
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 30,
        [string]$StandardInput
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $script:Adb
    $startInfo.Arguments = (($Arguments | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw '无法启动 adb。' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if ($StandardInput) { $process.StandardInput.WriteLine($StandardInput) }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "ADB 操作超时（$TimeoutSeconds 秒）。请检查同一 Wi-Fi、无线调试开关、当前端口和网络隔离。"
        }
        $output = $stdoutTask.GetAwaiter().GetResult() + "`n" + $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "ADB 操作失败：$($output.Trim())" }
        return $output.Trim()
    } finally {
        $process.Dispose()
    }
}

function Find-WirelessApk {
    param([ValidateSet('release', 'dev')][string]$Kind)
    $candidates = @()
    $distPath = Join-Path $RepoRoot "dist\$Kind"
    $filter = if ($Kind -eq 'release') { 'PresenceKit-mobile-v*.apk' } else { 'PresenceKit-mobile-dev.apk' }
    if (Test-Path -LiteralPath $distPath -PathType Container) {
        $candidates += @(Get-ChildItem -LiteralPath $distPath -Filter $filter -File)
    }
    $buildName = if ($Kind -eq 'release') { 'app-prod-release.apk' } else { 'app-dev-debug.apk' }
    $buildPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\$buildName"
    if (Test-Path -LiteralPath $buildPath -PathType Leaf) { $candidates += Get-Item -LiteralPath $buildPath }
    $newest = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $newest) { throw '没有找到已打好的 APK。请先用 AA1 打发行包，或选择手动填写 APK 路径。' }
    return $newest.FullName
}

try {
    if ($ConnectOnly -and $ApkPath) { throw '-ConnectOnly 与 -ApkPath 不能同时使用。' }
    $script:Adb = Resolve-WirelessAdb
    Write-Host '=== 手机无线连接 / APK 安装（Android 11 及以上）===' -ForegroundColor Cyan
    Write-Host '电脑和手机须在同一 Wi-Fi；手机打开：开发者选项 -> 无线调试。'
    Write-Host '找不到开发者选项时：在关于本机中连续点击版本号，按系统提示开启。'
    Write-Host '配对码只输入本机脚本；无需发给他人。输入 0 可退出。'

    if (-not $PairAddress -and -not $ConnectAddress) {
        $mode = (Read-Host '首次配对输入 1；已经配对直接连接输入 2 [默认 2]').Trim()
        if ($mode -eq '0') { exit 0 }
        if ($mode -eq '1') {
            Write-Host '手机点击“使用配对码配对设备”，保持窗口打开。'
            $PairAddress = (Read-Host '输入配对窗口的 IP 地址和端口').Trim()
        } elseif ($mode -notin @('', '2')) { throw '请选择 1 或 2。' }
    }

    if ($PairAddress) {
        Assert-WirelessAddress $PairAddress
        Write-Host '配对码来自手机“使用配对码配对设备”窗口，通常为 6 位数字。'
        $secureCode = Read-Host '输入配对码（隐藏输入）' -AsSecureString
        $codePointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureCode)
        try {
            $pairCode = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($codePointer)
            if ($pairCode -notmatch '^\d{6}$') { throw '配对码应为 6 位数字。请重新打开配对窗口后重试。' }
            $pairResult = Invoke-WirelessAdb -Arguments @('pair', $PairAddress) -StandardInput $pairCode
            if ($pairResult -notmatch 'Successfully paired') { throw "配对未成功：$pairResult" }
            Write-Host '配对成功。'
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($codePointer)
            $pairCode = $null
            $secureCode.Dispose()
        }
    }

    if (-not $ConnectAddress) {
        Write-Host '返回“无线调试”主页，查看主页的“IP 地址和端口”。连接端口通常与配对端口不同！'
        $ConnectAddress = (Read-Host '输入连接用 IP:端口（0 退出）').Trim()
        if ($ConnectAddress -eq '0') { exit 0 }
    }
    Assert-WirelessAddress $ConnectAddress
    Write-Host (Invoke-WirelessAdb -Arguments @('connect', $ConnectAddress))
    $state = Invoke-WirelessAdb -Arguments @('-s', $ConnectAddress, 'get-state')
    if ($state -ne 'device') { throw "无线设备未就绪（$state）。请确认连接端口，必要时重新配对。" }
    Write-Host "已连接：$ConnectAddress" -ForegroundColor Green

    if ($ReverseBackend) {
        Write-Host (Invoke-WirelessAdb -Arguments @('-s', $ConnectAddress, 'reverse', 'tcp:8080', 'tcp:8080'))
        Write-Host '已建立后端 8080 隧道；保持电脑后端和无线调试连接运行。'
    }

    if (-not $ConnectOnly -and -not $ApkPath) {
        Write-Host '1 = 选择最新修改的已有发行 APK；2 = 已有测试 APK；3 = 自选 APK；0 = 仅连接。'
        $action = (Read-Host '选择操作 [默认 0，仅连接]').Trim()
        switch ($action) {
            '1' { $ApkPath = Find-WirelessApk -Kind release }
            '2' { $ApkPath = Find-WirelessApk -Kind dev }
            '3' { $ApkPath = (Read-Host '输入 APK 路径（支持拖入文件）').Trim().Trim('"') }
            { $_ -in @('', '0') } { $ConnectOnly = $true }
            default { throw '请选择 0、1、2 或 3。' }
        }
    }

    if ($ApkPath) {
        if (-not [IO.Path]::IsPathRooted($ApkPath)) { $ApkPath = Join-Path $RepoRoot $ApkPath }
        if ([IO.Path]::GetExtension($ApkPath) -ne '.apk' -or -not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
            throw 'APK 文件不存在或扩展名不是 .apk。'
        }
        $apk = Get-Item -LiteralPath $ApkPath
        Write-Host "设备：$ConnectAddress"
        Write-Host "安装：$($apk.FullName)"
        Write-Host "文件时间：$($apk.LastWriteTime)；大小：$([math]::Round($apk.Length / 1MB, 1)) MB"
        if (-not $PSBoundParameters.ContainsKey('ApkPath')) {
            if ((Read-Host '开始无线覆盖安装？输入 Y 继续，其他键取消') -notmatch '^[Yy]$') { exit 0 }
        }
        $result = Invoke-WirelessAdb -Arguments @('-s', $ConnectAddress, 'install', '-r', $apk.FullName) -TimeoutSeconds 180
        if ($result -notmatch '(?m)^Success\s*$') { throw "安装未成功：$result" }
        Write-Host '无线安装完成。' -ForegroundColor Green
    }
    Write-Host '连接后也可使用 AA2 / AA3 打包安装；它们要求仅有一个 ADB 设备，请拔掉重复连接的 USB 线。'
    Write-Host '本入口安装已有 APK，不会重新编译。Wi-Fi 切换或重启后端口可能变化，重新运行连接即可。'
    Write-Host '如需手机通过 127.0.0.1:8080 访问电脑后端，可加参数 -ReverseBackend 重跑。'
    exit 0
} catch {
    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '检查：同一 Wi-Fi、无线调试已开启、配对码未过期、使用主页连接端口；旧版 adb 请更新 SDK Platform-Tools。'
    Write-Host '安装签名或版本不匹配时请使用正确 APK；本脚本不会自动卸载应用或强制降级。'
    exit 1
}
