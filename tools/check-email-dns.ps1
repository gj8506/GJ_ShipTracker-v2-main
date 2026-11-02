<#
.SYNOPSIS
    Checks the DNS records that decide whether transactional email reaches the
    inbox instead of the spam folder.

.DESCRIPTION
    Resend requires four records before it will send from a domain:
    DKIM, SPF, a feedback MX, and (recommended) DMARC. A missing or malformed
    record is the usual reason Gmail files your mail under Spam.

    Run this after adding the records in your DNS provider and again after
    Resend reports the domain as Verified.

.PARAMETER Domain
    The domain you verified in Resend, e.g. gjandasher.ph

.PARAMETER DkimSelector
    The DKIM selector Resend shows on the Domains page. Resend uses `resend`
    by default.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\check-email-dns.ps1 -Domain gjandasher.ph
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Domain,

    [string]$DkimSelector = 'resend',

    [string]$DnsServer = '8.8.8.8'
)

$ErrorActionPreference = 'Stop'
$Domain = $Domain.Trim().ToLower().TrimEnd('.')

function Get-Records {
    param([string]$Name, [string]$Type)

    $result = [pscustomobject]@{ Name = $Name; Type = $Type; Values = @(); Error = $null }
    try {
        $records = Resolve-DnsName -Name $Name -Type $Type -Server $DnsServer `
            -DnsOnly -ErrorAction Stop |
            Where-Object { $_.Type -eq $Type }

        $result.Values = @($records | ForEach-Object {
                if ($Type -eq 'TXT') { ($_.Strings -join '') }
                elseif ($Type -eq 'MX') { "$($_.NameExchange) (pref $($_.Preference))" }
                else { $_.IPAddress }
            } | Where-Object { $_ })
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

$checks = @()

function Add-Check {
    param(
        [string]$Label,
        [string]$RecordName,
        [string]$RecordType,
        [scriptblock]$Validate,
        [string]$Hint
    )

    $record = Get-Records -Name $RecordName -Type $RecordType
    $values = @($record.Values)
    $ok = $false
    $detail = ''

    if ($values.Count -gt 0) {
        $ok = & $Validate $values
        $detail = ($values -join ' | ')
    }
    elseif ($record.Error) {
        $detail = "lookup failed: $($record.Error)"
    }
    else {
        $detail = 'no record found'
    }

    $script:checks += [pscustomobject]@{
        Check  = $Label
        Record = "$RecordName  $RecordType"
        Status = if ($ok) { 'PASS' } else { 'FAIL' }
        Detail = $detail
        Hint   = if ($ok) { '' } else { $Hint }
    }
}

Write-Host ""
Write-Host "Checking email DNS for $Domain (via $DnsServer)" -ForegroundColor Cyan
Write-Host ""

# 1. DKIM - proves the message really came from the sending domain.
Add-Check -Label 'DKIM' `
    -RecordName "$DkimSelector._domainkey.$Domain" -RecordType 'TXT' `
    -Validate { param($v) $v -match 'p=' } `
    -Hint 'Copy the DKIM TXT record from Resend > Domains > your domain. The name is usually resend._domainkey and the value starts with p=MIGf...'

# 2. SPF on the sending subdomain - Resend sends from send.<domain>.
Add-Check -Label 'SPF (send subdomain)' `
    -RecordName "send.$Domain" -RecordType 'TXT' `
    -Validate { param($v) ($v -match '^"?v=spf1') -and ($v -match 'amazonses\.com|resend') } `
    -Hint 'Add the SPF TXT record from Resend on the send subdomain, e.g. "v=spf1 include:amazonses.com ~all".'

# 3. Feedback MX - how bounces and complaints are reported back.
Add-Check -Label 'Feedback MX' `
    -RecordName "send.$Domain" -RecordType 'MX' `
    -Validate { param($v) ($v -match 'amazonses\.com|resend') } `
    -Hint 'Add the MX record from Resend on the send subdomain, pointing at feedback-smtp.<region>.amazonses.com with priority 10.'

# 4. DMARC - tells Gmail what to do with unauthenticated mail.
Add-Check -Label 'DMARC' `
    -RecordName "_dmarc.$Domain" -RecordType 'TXT' `
    -Validate { param($v) $v -match '^"?v=DMARC1' } `
    -Hint ("Add a TXT record on _dmarc with `"v=DMARC1; p=none; rua=mailto:dmarc@$Domain`". Move to p=quarantine once everything passes.")

$checks | Format-Table -Property Check, Status, Record -AutoSize | Out-String | Write-Host

foreach ($check in $checks) {
    $colour = if ($check.Status -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1}" -f $check.Status, $check.Check) -ForegroundColor $colour
    Write-Host ("       {0}" -f $check.Record) -ForegroundColor DarkGray
    Write-Host ("       {0}" -f $check.Detail) -ForegroundColor DarkGray
    if ($check.Hint) {
        Write-Host ("       -> {0}" -f $check.Hint) -ForegroundColor Yellow
    }
    Write-Host ""
}

$failures = @($checks | Where-Object { $_.Status -eq 'FAIL' })

if ($failures.Count -eq 0) {
    Write-Host "All records look correct. Verify the domain in Resend, then send a test:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  curl.exe -X POST `"https://<your-worker>/password-reset`" ``" -ForegroundColor DarkGray
    Write-Host "    -H `"Content-Type: application/json`" ``" -ForegroundColor DarkGray
    Write-Host "    -H `"x-api-key: <your-api-key>`" ``" -ForegroundColor DarkGray
    Write-Host "    -d `"{\`"email\`":\`"you@example.com\`"}`"" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "DNS can take up to 48 hours to propagate, but usually finishes in minutes." -ForegroundColor DarkGray
}
else {
    Write-Host "$($failures.Count) record(s) still need attention. See the hints above." -ForegroundColor Yellow
}

Write-Host ""
