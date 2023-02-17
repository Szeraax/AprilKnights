# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"
$QueueItem | ConvertTo-Json -Compress
$channel_name, $role_name = $QueueItem.Values -split ",", 2
$token = [Environment]::GetEnvironmentVariable("APP_DISCORD_BOT_TOKEN_$($QueueItem.ApplicationID)")
[System.Collections.Generic.List[string]]$response = @()

$headers = @{
    Authorization = "Bot $token"
}
$irm_splat = @{
    MaximumRetryCount = 5
    RetryIntervalSec  = 1
    ContentType       = 'application/json'
    UserAgent         = 'DiscordBot (https://dcrich.net,0.0.1)'
    Headers           = $headers
    ErrorAction       = 'Stop'
}
try {
    $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/channels"
    $channels = Invoke-RestMethod @irm_splat
    $channel = $channels | Where-Object { $_.id -eq $channel_name -or $_.name -eq $channel_name }
    $channel_name = $channel.name

    # $member = Invoke-RestMethod @irm_splat -Uri "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)"
    $irm_splat.Uri = "https://discord.com/api/channels/$($channel.id)/messages"
    $channels = Invoke-RestMethod @irm_splat -Method Post -Body (@{
            content = "Please welcome the newest member of the battalion,  <@$($QueueItem.DiscordUserID)>"
        } | ConvertTo-Json)
    $channelDone = $true
}
catch {
    $response.Add("Error message: $_")
    $_
}
try {
    $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/roles"
    $roles = Invoke-RestMethod @irm_splat
    $role = $roles | Where-Object { $_.id -eq $role_name -or $_.name -eq $role_name }
    $role_name = $role.name
    $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)/roles/$($role.id)"
    try {
        Invoke-RestMethod @irm_splat -Method Put
    }
    catch {
        if (($_ | ConvertFrom-Json).message -match "Missing Permissions") {
            $response.Add("'Missing Permissions' error while adding user to role. Is the Bot role above ``$role_name` in the server roles?")
        }
        throw $_
    }
    $roleDone = $true
}
catch {
    $response.Add("Error message: $_")
    $_
}
if ($channelDone -and $roleDone) {
    $response.Add("Completed adding user to role '$role_name' and announcing them in channel '$channel_name'")
}
elseif ($channelDone) {
    $response.Add("Announced user in channel '$channel_name', but did not successfully add them to the role '$role_name'")
}
elseif ($roleDone) {
    $response.Add("Completed adding user to role '$role_name', but did not successfully announce them in the channel '$channel_name'")
}
else {
    $response.Add("Did not successfully add user to role '$role_name' or announce them in the channel '$channel_name'")
}

# The most authoritative answers are determined at the end of processing, but we want them to be seen first during reading:
$response.Reverse()
$invokeRestMethod_splat = @{
    Uri               = "https://discord.com/api/v8/webhooks/{0}/{1}/messages/@original" -f $QueueItem.ApplicationID, $QueueItem.Token
    Method            = "Patch"
    ContentType       = "application/json"
    Body              = (@{
            type    = 4
            content = $response -join "`n"
            embeds  = @()
        } | ConvertTo-Json)
    MaximumRetryCount = 5
    RetryIntervalSec  = 1
}
try { Invoke-RestMethod @invokeRestMethod_splat | Out-Null }
catch {
    "failed" | Write-Host
    $invokeRestMethod_splat | ConvertTo-Json -Depth 3 -Compress
    $_
}
