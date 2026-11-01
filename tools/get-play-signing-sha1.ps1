# Prints the signing certificate SHA-1/SHA-256 of an app installed on a
# connected Android device.
#
# Use this when the Play Console "Play app signing" page is not reachable.
# Install the app from Google Play on the device first, enable Developer
# options + USB debugging, then run:
#
#   powershell -ExecutionPolicy Bypass -File tools\get-play-signing-sha1.ps1
#
param(
    [string]$Package = 'com.gjandasher.digitalprinting'
)

$ErrorActionPreference = 'Stop'

function Find-Adb {
    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add('adb')
    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'))
    }
    foreach ($sdk in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) {
        if ([string]::IsNullOrWhiteSpace($sdk)) { continue }
        $candidates.Add((Join-Path $sdk 'platform-tools\adb.exe'))
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Convert-HexToSha1([string]$hex) {
    $bytes = [byte[]]::new($hex.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
    }
    $sha1 = [System.Security.Cryptography.SHA1]::Create().ComputeHash($bytes)
    $sha256 = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return [pscustomobject]@{
        Sha1   = (($sha1 | ForEach-Object { $_.ToString('X2') }) -join ':')
        Sha256 = (($sha256 | ForEach-Object { $_.ToString('X2') }) -join ':')
    }
}

$adb = Find-Adb
if (-not $adb) {
    Write-Host 'adb was not found.' -ForegroundColor Red
    Write-Host 'Install Android platform-tools or add adb to PATH, then try again.'
    exit 1
}

$devices = (& $adb devices) | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }
if (-not $devices) {
    Write-Host 'No Android device detected.' -ForegroundColor Red
    Write-Host 'Connect the phone with USB, enable USB debugging and accept the prompt.'
    exit 1
}

Write-Host "Looking up $Package ..."
$dump = (& $adb shell dumpsys package $Package) -join "`n"

if ($dump -match 'Unable to find package') {
    Write-Host "Package $Package is not installed on this device." -ForegroundColor Red
    Write-Host 'Install it from Google Play first, then run this script again.'
    exit 1
}

# Example: signatures=PackageSignatures{1a2b3c [308201... 308201...]}
$match = [regex]::Match($dump, 'signatures=PackageSignatures\{[^[]*\[([^\]]+)\]')
if (-not $match.Success) {
    Write-Host 'Could not read the signature block from dumpsys.' -ForegroundColor Red
    exit 1
}

$signers = $match.Groups[1].Value -split '\s+' | Where-Object { $_ -match '^[0-9a-fA-F]+$' }
if (-not $signers) {
    Write-Host 'No signer certificate found.' -ForegroundColor Red
    exit 1
}

$index = 0
foreach ($signer in $signers) {
    $index++
    $result = Convert-HexToSha1 $signer
    Write-Host ''
    Write-Host "Signer $index" -ForegroundColor Cyan
    Write-Host "  SHA-1   : $($result.Sha1)"
    Write-Host "  SHA-1   : $($result.Sha1.Replace(':', '').ToLower())  (colonless, for Firebase)"
    Write-Host "  SHA-256 : $($result.Sha256)"
}

Write-Host ''
Write-Host 'Add each SHA-1 in Firebase Console -> Project settings -> Your apps'
Write-Host '-> Android app -> Add fingerprint.'
