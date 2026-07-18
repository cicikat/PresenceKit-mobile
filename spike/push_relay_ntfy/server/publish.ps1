# publish.ps1 — PowerShell equivalent of publish.sh
# Usage:
#   .\publish.ps1 [-Host localhost:8080] [-Topic mychar-spike] [-Msg "hello"]

param(
    [string]$NtfyHost = "localhost:8080",
    [string]$Topic    = "mychar-spike",
    [string]$Msg      = "ping $(Get-Date -Format 'HH:mm:ss')"
)

$ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$url = "http://$NtfyHost/$Topic"

Write-Host "[$ts] Publishing to $url  ->  `"$Msg`""

$headers = @{
    "Title"    = "mychar-spike"
    "Priority" = "default"
    "Tags"     = "bell"
}

try {
    $resp = Invoke-WebRequest -Method POST -Uri $url -Headers $headers -Body $Msg -UseBasicParsing
    Write-Host "[$ts] HTTP $($resp.StatusCode)"
} catch {
    Write-Host "[$ts] ERROR: $_"
}
