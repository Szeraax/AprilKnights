# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"

$item = $QueueItem

if ($uri = $item.data.options.where{ $_.name -eq "link" }.value) {
    if ($uri -notmatch "^http") { $uri = "https://tinyurl.com/$uri" }
    $response = Expand-Uri $uri
    if ($response -match "The URL you followed redirects back to a TinyURL") {
        $response = $response -replace ".*The URL you followed redirects back to a TinyURL and " -replace "<.*?>"
    }
    $response | Write-Host

}
elseif ($item.data.name -eq "Thank") {
    $response = "Expando is grateful to be noticed by <@$($item.member.user.id)> (Brought to you by <@291431034250067968>)"
}
elseif ($item) {
    $response = $item
}
else {
    $response = "No body sent"
}


$invokeRestMethod_splat = @{
    Uri               = "https://discord.com/api/v8/webhooks/{0}/{1}/messages/@original" -f $item.application_id, $item.token
    Method            = "Patch"
    ContentType       = "application/json"
    Body              = (@{
            type    = 4
            content = $response
        } | ConvertTo-Json)
    MaximumRetryCount = 5
    RetryIntervalSec  = 2
}
try { Invoke-RestMethod @invokeRestMethod_splat }
catch {
    "failed" | Write-Host
    $invokeRestMethod_splat | ConvertTo-Json -Depth 3 -Compress
    $_
}
