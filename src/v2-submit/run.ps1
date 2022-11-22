using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$request | ConvertTo-Json -Compress | Write-Host
# Interact with query parameters or the body of the request.
try { Assert-Signature }
catch { return }

if ($Request.Body.type -eq 1) {
    $response = @{
        type = 1
    }
    Write-Host "ACKing ping"
}
elseif (
    $Request.Body.data.name -eq "Interview" -and
    $Request.Body.data.options[0].name -eq "get" -and
    $Request.Body.data.options[0].options[0].name -eq "battalions"
) {
    $response = @{
        type = 4
        data = @{
            content = "https://www.reddit.com/r/AprilKnights/comments/taccao/battalion_overview_thread"
        }
    }
    Write-Host "list battalions."
}
elseif ($Request.body.data.name -eq "Verify Reddit") {
    $requestor = $Request.body.member.user
    $target = $Request.body.data.resolved.users | Select-Object -ExpandProperty *
    $tableRow = @{
        PartitionKey  = 'Candidate'
        RowKey        = $Request.body.data.target_id + "-$(Get-Date -f s)"
        Name          = "{0}#{1}" -f $target.username, $target.discriminator
        Requestor     = "{0}#{1}" -f $requestor.username, $requestor.discriminator
        ApplicationId = $Request.body.application_id
        Token         = $Request.body.Token
    }
    $tableRow | ConvertTo-Json -Compress | Write-Host
    Push-OutputBinding -Name TableBinding -Value $tableRow
    $response = @{
        type = 4
        data = @{
            content = "Please authorize the verification bot at the following link and then wait a few minutes for verification to complete:`nhttps://discord.com/api/oauth2/authorize?client_id=951952755277328404&redirect_uri=https%3A%2F%2Faprilknights.azurewebsites.net%2Fapi%2FAuthorized&response_type=code&scope=connections%20identify"
        }
    }
}
elseif ($Request.Body) {
    Push-OutputBinding -name QueueToV2 -value $Request.Body
    $response = @{
        type    = 5
        content = "Pending"
    }
    Write-Host "Writing item to queue"
}
else {
    $response = "No body sent"
    Write-Host $response
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
    })
