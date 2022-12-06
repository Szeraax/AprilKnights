# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"
$QueueItem | ConvertTo-Json -Compress | Write-Host
$QueueItem.Created -as [datetime] | Write-Host
[datetime]::UtcNow.AddMinutes(-10) | Write-Host
$AzDataTableEntity_params = @{
    ConnectionString = $ENV:AzureWebJobsStorage
    TableName        = "Squirelike"
    ErrorAction      = "Stop"
}

try {
    $row = Get-AzDataTableEntity @AzDataTableEntity_params -Filter "PartitionKey eq 'Candidate' and Timestamp gt datetime'$([Datetime]::now.AddDays(-2).ToString('yyyy-MM-dd'))'" |
    Where-Object PartitionKey -EQ "Candidate" |
    Where-Object RowKey -EQ $QueueItem.RowKey |
    Sort-Object Timestamp |
    Select-Object -Last 1

    if ($row.Created -and [string]::IsNullOrWhiteSpace($row.Token)) {
        "Clear!" | Write-Host
    }
    elseif ($QueueItem.Created -as [datetime] -lt [datetime]::UtcNow.AddMinutes(-5)) {
        Write-Host "10 minutes old!"
        # Check to see if token still exists. If yes, then update and say that this link is expired.
        $invokeRestMethod_splat = @{
            Uri               = "https://discord.com/api/v8/webhooks/{0}/{1}/messages/@original" -f $QueueItem.ApplicationId, $QueueItem.Token
            Method            = "Patch"
            ContentType       = "application/json"
            Body              = (@{
                    type    = 4
                    content = 'Link expired. Please run the `/interview verify reddit` command again.'
                    embeds  = @()
                } | ConvertTo-Json)
            MaximumRetryCount = 5
            RetryIntervalSec  = 2
        }
        try { Invoke-RestMethod @invokeRestMethod_splat | Out-Null }
        catch {
            "failed" | Write-Host
            $invokeRestMethod_splat | ConvertTo-Json -Depth 3 -Compress
            $_
        }
    }
    elseif ($QueueItem.Created -as [datetime] -lt [datetime]::UtcNow.AddMinutes(-1)) {
        # Check to see if token still exists. If yes, then say this is takin a while
        # Then throw so it re-queues
        $invokeRestMethod_splat = @{
            Uri               = "https://discord.com/api/v8/webhooks/{0}/{1}/messages/@original" -f $QueueItem.ApplicationId, $QueueItem.Token
            Method            = "Patch"
            ContentType       = "application/json"
            Body              = (@{
                    type    = 4
                    content = "<@$($QueueItem.DiscordID)>, the link must be clicked by you in order to work. Please click it within the next few minutes."
                    # embeds  = @()
                } | ConvertTo-Json)
            MaximumRetryCount = 5
            RetryIntervalSec  = 2
        }
        try { Invoke-RestMethod @invokeRestMethod_splat | Out-Null }
        catch {
            "failed" | Write-Host
            $invokeRestMethod_splat | ConvertTo-Json -Depth 3 -Compress
            $_
        }

        throw "Delay for a minute"
    }
    else {
        throw "Delay till its a little older"
    }
}
catch {
    throw $_
}
