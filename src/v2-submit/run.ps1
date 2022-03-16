using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
try { Assert-Signature }
catch { return }

if ($Request.Body.type -eq 1) {
    $response = @{
        type = 1
    }
    Write-Host "ACKing ping"
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
