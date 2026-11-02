<#
.SYNOPSIS
    Builds the signed release artifacts with the transactional-email worker
    baked in.

.DESCRIPTION
    The app only sends branded email when it is built with EMAIL_WORKER_URL and
    EMAIL_API_KEY. Forgetting those flags is why password-reset mail silently
    falls back to Firebase's `firebaseapp.com` sender and lands in Spam.

    This script makes the flags mandatory, checks the deployed worker's
    deliverability settings first, then builds the AAB and/or APK.

    Configuration is read from, in order of precedence:
      1. -WorkerUrl / -ApiKey parameters
      2. EMAIL_WORKER_URL / EMAIL_API_KEY environment variables
      3. release.local.json in the repository root (git-ignored)

    Copy release.local.example.json to release.local.json and fill it in.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build-release.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build-release.ps1 -Target aab
#>
[CmdletBinding()]
param(
    [ValidateSet('aab', 'apk', 'both')]
    [string]$Target = 'both',

    [string]$WorkerUrl,
    [string]$ApiKey,

    [switch]$SkipHealthCheck
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    # ------------------------------------------------------------------
    # 1. Resolve configuration
    # ------------------------------------------------------------------
    $configFile = Join-Path $repoRoot 'release.local.json'
    $config = $null
    if (Test-Path $configFile) {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
    }

    if (-not $WorkerUrl) { $WorkerUrl = $env:EMAIL_WORKER_URL }
    if (-not $WorkerUrl -and $config) { $WorkerUrl = $config.emailWorkerUrl }

    if (-not $ApiKey) { $ApiKey = $env:EMAIL_API_KEY }
    if (-not $ApiKey -and $config) { $ApiKey = $config.emailApiKey }

    if (-not $WorkerUrl) {
        throw @"
EMAIL_WORKER_URL is required.

The app cannot send branded email without it, so password-reset mail would fall
back to Firebase's firebaseapp.com sender and land in Spam.

Set it one of these ways:
  - create release.local.json (copy release.local.example.json)
  - set `$env:EMAIL_WORKER_URL = 'https://gjandasher-email.<subdomain>.workers.dev'
  - pass -WorkerUrl https://...
"@
    }

    $WorkerUrl = $WorkerUrl.Trim().TrimEnd('/')
    if ($WorkerUrl -notmatch '^https://') {
        throw "EMAIL_WORKER_URL must start with https:// (got '$WorkerUrl')."
    }
    if (-not $ApiKey) {
        Write-Warning 'EMAIL_API_KEY is empty. The worker will reject requests unless its API_KEY secret is also unset (it is not).'
    }

    # ------------------------------------------------------------------
    # 2. Verify the deployed worker before trusting it
    # ------------------------------------------------------------------
    if (-not $SkipHealthCheck) {
        Write-Host ''
        Write-Host "Checking $WorkerUrl/health ..." -ForegroundColor Cyan
        try {
            $health = Invoke-RestMethod -Uri "$WorkerUrl/health" -TimeoutSec 20
            $d = $health.deliverability
            if (-not $d) {
                Write-Warning 'Worker returned no deliverability info. It may be running an older revision - redeploy it.'
            }
            else {
                Write-Host ("  MAIL_FROM domain      : {0}" -f $d.mailFromDomain) -ForegroundColor DarkGray
                Write-Host ("  MAIL_FROM usable      : {0}" -f $d.mailFromUsable) -ForegroundColor $(if ($d.mailFromUsable) { 'Green' } else { 'Red' })
                Write-Host ("  Reply-To configured   : {0}" -f $d.replyToConfigured) -ForegroundColor DarkGray
                Write-Host ("  Resend key configured : {0}" -f $d.resendKeyConfigured) -ForegroundColor DarkGray
                Write-Host ("  Reset link configured : {0}" -f $d.passwordResetConfigured) -ForegroundColor DarkGray

                if ($d.mailFromProblem) {
                    Write-Host ''
                    Write-Host "  PROBLEM: $($d.mailFromProblem)" -ForegroundColor Red
                    Write-Host '  Fix wrangler.toml, redeploy, then re-run this script.' -ForegroundColor Red
                    throw 'Worker sender is not deliverable.'
                }
                if (-not $d.passwordResetConfigured) {
                    Write-Warning 'Password-reset email is not configured on the worker (missing Firebase service-account secrets). The app will fall back to Firebase mail, which lands in Spam.'
                }
            }
        }
        catch [System.Net.WebException] {
            Write-Warning "Could not reach the worker health endpoint: $($_.Exception.Message)"
            Write-Warning 'Continuing without the pre-flight check.'
        }
    }

    # ------------------------------------------------------------------
    # 3. Sanity-check signing
    # ------------------------------------------------------------------
    $keyProps = Join-Path $repoRoot 'android\key.properties'
    if (-not (Test-Path $keyProps)) {
        throw 'android/key.properties is missing. Release builds would use the debug key and Play would reject the upload.'
    }
    $props = Get-Content $keyProps | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' }
    if ($props -match 'CHANGE_ME') {
        throw 'android/key.properties still contains CHANGE_ME placeholders.'
    }

    $version = (Select-String -Path (Join-Path $repoRoot 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()

    $defines = @(
        "--dart-define=EMAIL_WORKER_URL=$WorkerUrl",
        "--dart-define=EMAIL_API_KEY=$ApiKey"
    )

    Write-Host ''
    Write-Host "Building $version for $Target" -ForegroundColor Cyan
    Write-Host "  worker: $WorkerUrl" -ForegroundColor DarkGray
    Write-Host ''

    # ------------------------------------------------------------------
    # 4. Build
    # ------------------------------------------------------------------
    if ($Target -in @('aab', 'both')) {
        Write-Host '--- app bundle ---' -ForegroundColor Cyan
        & flutter build appbundle --release @defines
        if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle failed.' }
    }

    if ($Target -in @('apk', 'both')) {
        Write-Host '--- release apk ---' -ForegroundColor Cyan
        & flutter build apk --release @defines
        if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed.' }
    }

    # ------------------------------------------------------------------
    # 5. Report
    # ------------------------------------------------------------------
    Write-Host ''
    Write-Host 'Artifacts' -ForegroundColor Green
    $aab = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
    $apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
    if (Test-Path $aab) { Get-Item $aab | Select-Object FullName, Length, LastWriteTime | Format-List }
    if (Test-Path $apk) { Get-Item $apk | Select-Object FullName, Length, LastWriteTime | Format-List }

    $buildTools = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($buildTools -and (Test-Path $apk)) {
        $signer = Join-Path $buildTools.FullName 'apksigner.bat'
        & $signer verify --print-certs $apk 2>$null |
            Select-String -Pattern 'SHA-1 digest' |
            ForEach-Object { Write-Host ("APK signing SHA-1: {0}" -f ($_.Line -replace '.*digest:\s*', '')) }
    }
}
finally {
    Pop-Location
}
