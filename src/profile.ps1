# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.
function Expand-Uri([string]$Uri) {
    try { Invoke-RestMethod -MaximumRedirection 0 -Uri $Uri -ErrorAction Stop }
    catch {
        if ($_.exception.response.headers.location) { [string]$_.exception.response.headers.location }
        elseif ($_.exception.response.StatusCode) {
            "{0} ({1})- {2}" -f @(
                [int]$_.exception.response.StatusCode
                [string]$_.exception.response.ReasonPhrase
                [string]$_.targetObject.requestUri
            )
        }
        else {
            "Unknown error for this URL: {0}" -f [string]$_.targetObject.requestUri
        }
    }
}

function Assert-Signature {
    $appid = $Request.Body.application_id
    $publicKey = (Get-Item env:\APPID_PUBLICKEY_$appid -ea silent).value
    if (-not $appid -or -not $publicKey) {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
            })
        throw
    }
    if (-not $Request.Headers."x-signature-timestamp" -or -not $Request.Headers."x-signature-ed25519") {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Unauthorized
            })
        throw
    }
    $ed = [Rebex.Security.Cryptography.Ed25519]::new()
    [byte[]]$public = $publicKey -replace "(..)", '0x$1|' -split "\|" | Where-Object { $_ }
    $ed.FromPublicKey($public)
    [string]$message = $Request.Headers."x-signature-timestamp" + $Request.RawBody
    [byte[]]$signature = $Request.Headers."x-signature-ed25519" -replace "(..)", '0x$1|' -split "\|" | Where-Object { $_ }
    $result = $ed.VerifyMessage([System.Text.Encoding]::ASCII.GetBytes($message), $signature)
    if ($result -eq $false) {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Unauthorized
            })
        throw
    }
    Write-Host "Signature is valid"
}

Add-Type -Path .\Rebex.Ed25519.dll

function Get-Comments ($obj) {
    if ($obj.author) {
        [PSCustomObject][ordered]@{
            author    = $obj.author
            permalink = "https://reddit.com" + $obj.permalink
            body      = $obj.body
            created   = $obj.created_utc
        }
    }
    if ($obj.data) { $obj.data | ForEach-Object { Get-Comments $_ } }
    elseif ($obj.children) { $obj.children | ForEach-Object { Get-Comments $_ } }
    elseif ($obj.replies) { $obj.replies | ForEach-Object { Get-Comments $_ } }
}
