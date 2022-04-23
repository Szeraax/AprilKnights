using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

Push-OutputBinding -Name QueueToV2 -value @{
    Code = $Request.Query.code
}

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = "Authorization complete. Please give us a minute to verify your connected account. You can now close this window."
    })
