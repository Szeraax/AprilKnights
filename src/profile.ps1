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
    try { Invoke-WebRequest -MaximumRedirection 0 -Uri $Uri -ErrorAction Stop }
    catch {
        if ($_.exception.response.headers.location) { [string]$_.exception.response.headers.location }
        else {
            "{0} ({1})- {2}" -f @(
                [int]$_.exception.response.StatusCode
                [string]$_.exception.response.ReasonPhrase
                [string]$_.targetObject.requestUri
            )
        }
    }
}

function Assert-Signature {
    if (-not $Request.Headers."x-signature-timestamp" -or -not $Request.Headers."x-signature-ed25519") {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Unauthorized
            })
        return
    }
    else {
        $ed = [Rebex.Security.Cryptography.Ed25519]::new()
        [byte[]]$public = $ENV:APP_PUBLIC_KEY -replace "(..)", '0x$1|' -split "\|" | Where-Object { $_ }
        $ed.FromPublicKey($public)
        [string]$message = $Request.Headers."x-signature-timestamp" + $Request.RawBody
        [byte[]]$signature = $Request.Headers."x-signature-ed25519" -replace "(..)", '0x$1|' -split "\|" | Where-Object { $_ }
        $result = $ed.VerifyMessage([System.Text.Encoding]::ASCII.GetBytes($message), $signature)
        if ($result -eq $false) {
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::Unauthorized
                })
            return
        }
    }
}

Add-Type -Path .\Rebex.Ed25519.dll
