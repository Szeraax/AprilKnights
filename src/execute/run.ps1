using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.

Assert-Signature

if ($Request.Body.type -eq 1) {
    $response = @{
        type = 1
    }
}
elseif ($uri = $Request.Body.data.options.where{ $_.name -eq "link" }.value) {
    $response = Expand-Uri $uri
    $response | Write-Host
    $response = @{
        type = 4
        data = @{
            content = $response
        }
    }
}
elseif ($Request.Body.data.name -eq "Thank") {
    $response = @{
        type = 4
        data = @{
            content = "Expando is grateful to be noticed by <@$($Request.Body.member.user.id)> (Brought to you by <@291431034250067968>)"
        }
    }
}
elseif ($Request.Body) {
    $response = $Request.Body
}
else {
    $response = "No body sent"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
    })
