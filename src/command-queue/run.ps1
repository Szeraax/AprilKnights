# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"
$QueueItem | ConvertTo-Json -Compress
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
if ($QueueItem.Command -eq "RESPONSE_GATEWATCH_ASSIGN_BATTALION") {
    $embeds = @()
    $inError = $false
    $channel_name, $role_name = $QueueItem.Values -split ",", 2

    try {
        $embed = @{
            title       = "Announce user in battalion"
            color       = 0x00ff00
            description = [System.Collections.Generic.List[string]]@()
        }
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/channels"
        $channels = Invoke-RestMethod @irm_splat
        $channel = $channels | Where-Object { $_.id -eq $channel_name -or $_.name -eq $channel_name }

        # $member = Invoke-RestMethod @irm_splat -Uri "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)"
        $irm_splat.Uri = "https://discord.com/api/channels/$($channel.id)/messages"
        $channels = Invoke-RestMethod @irm_splat -Method Post -Body (@{
                content = "Please welcome the newest member of the battalion,  <@$($QueueItem.DiscordUserID)>"
            } | ConvertTo-Json)
        $embed.description.Add("Did announce Knight in battalion channel <#$($channel.id)>")
    }
    catch {
        $inError = $true
        $embed.description.Add("Error message: $_")
        $embed.description.Add("Did not announce Knight in battalion ($channel_name/$($channel.id)). Please try this command again or complete manually.")
        $embed.description = $embed.description.Reverse() -join "`n"
        $embed.color = 0xff0000
        $_
    }
    finally {
        $embeds += $embed
    }

    try {
        $embed = @{
            title       = "Add user to role"
            color       = 0x00ff00
            description = [System.Collections.Generic.List[string]]@()
        }
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/roles"
        $roles = Invoke-RestMethod @irm_splat
        $role = $roles | Where-Object { $_.id -eq $role_name -or $_.name -eq $role_name }
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)/roles/$($role.id)"
        try {
            Invoke-RestMethod @irm_splat -Method Put
        }
        catch {
            if (($_ | ConvertFrom-Json).message -match "Missing Permissions") {
                $embed.description.Add("'Missing Permissions' error while adding user to role. Is the Bot role above ``$($role.name)`` in the server roles?")
            }
            throw $_
        }
        $embed.description.Add("Did add knight to role ``$($role.name)``")
    }
    catch {
        $inError = $true
        $embed.description.Add("Error message: $_")
        $embed.description.Add("Did not add knight to battalion ($role_name/$($role.name)). Please try again or do so manually.")
        $embed.description = $embed.description.Reverse() -join "`n"
        $embed.color = 0xff0000
        $_
    }
    finally {
        $embeds += $embed
    }

    try {
        $embed = @{
            title       = "Add user to role"
            color       = 0x00ff00
            description = [System.Collections.Generic.List[string]]@()
        }
        $this_role = 'Recruit'
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/roles"
        $roles = Invoke-RestMethod @irm_splat
        $role = $roles | Where-Object { $_.name -eq $this_role }
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)/roles/$($role.id)"
        try {
            Invoke-RestMethod @irm_splat -Method Put
        }
        catch {
            if (($_ | ConvertFrom-Json).message -match "Missing Permissions") {
                $embed.description.Add("'Missing Permissions' error while adding user to role. Is the Bot role above ``$this_role`` in the server roles?")
            }
            throw $_

        }
        $embed.description.Add("Did add knight to role ``$this_role``")
    }
    catch {
        $inError = $true
        $embed.description.Add("Error message: $_")
        $embed.description.Add("Did not add knight to role ($this_role/$($role.name)). Please try again or do so manually.")
        $embed.description = $embed.description.Reverse() -join "`n"
        $embed.color = 0xff0000
        $_
    }
    finally {
        $embeds += $embed
    }

    try {
        $embed = @{
            title       = "Add user to role"
            color       = 0x00ff00
            description = [System.Collections.Generic.List[string]]@()
        }
        $this_role = 'Knight'
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/roles"
        $roles = Invoke-RestMethod @irm_splat
        $role = $roles | Where-Object { $_.name -eq $this_role }
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)/roles/$($role.id)"
        try {
            Invoke-RestMethod @irm_splat -Method Put
        }
        catch {
            if (($_ | ConvertFrom-Json).message -match "Missing Permissions") {
                $embed.description.Add("'Missing Permissions' error while adding user to role. Is the Bot role above ``$this_role`` in the server roles?")
            }
            throw $_

        }
        $embed.description.Add("Did add knight to role ``$this_role``")
    }
    catch {
        $inError = $true
        $embed.description.Add("Error message: $_")
        $embed.description.Add("Did not add knight to role ($this_role/$($role.name)). Please try again or do so manually.")
        $embed.description = $embed.description.Reverse() -join "`n"
        $embed.color = 0xff0000
        $_
    }
    finally {
        $embeds += $embed
    }

    try {
        $embed = @{
            title       = "Remove user from role"
            color       = 0x00ff00
            description = [System.Collections.Generic.List[string]]@()
        }
        $this_role = 'Guest'
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/roles"
        $roles = Invoke-RestMethod @irm_splat
        $role = $roles | Where-Object { $_.name -eq $this_role }
        $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/members/$($QueueItem.DiscordUserID)/roles/$($role.id)"
        try {
            Invoke-RestMethod @irm_splat -Method Delete
        }
        catch {
            if (($_ | ConvertFrom-Json).message -match "Missing Permissions") {
                $embed.description.Add("'Missing Permissions' error while edit user role. Is the Bot role above ``$this_role`` in the server roles?")
            }
            throw $_

        }
        $embed.description.Add("Did remove knight from role ``$this_role``")
    }
    catch {
        $inError = $true
        $embed.description.Add("Error message: $_")
        $embed.description.Add("Did not remove knight from role ($this_role/$($role.name)). Please try again or do so manually.")
        $embed.description = $embed.description.Reverse() -join "`n"
        $embed.color = 0xff0000
        $_
    }
    finally {
        $embeds += $embed
    }

    if ($inError) {
        $response.Add("Did not successfully complete all tasks. Please see below for details.")
    }
    else {
        $response = @()
        $embeds = @()
        $response.Add("Completed adding <@$($QueueItem.DiscordUserID)> to role '$($role.name)' and announcing them in channel '$($channel.name)'")
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
                embeds  = $embeds
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
}
elseif ($QueueItem.Command -eq "RESPONSE_GATEWATCH_DISCUSS_CANDIDATE") {
    "RESPONSE_GATEWATCH_DISCUSS_CANDIDATE"
    $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/channels"
    $channels = Invoke-RestMethod @irm_splat

    $channel = $channels | Where-Object { $_.id -eq $QueueItem.DiscordChannelID -or $_.name -eq $QueueItem.DiscordChannelID } | Select-Object -First 1
    $last4 = $channel.name[-4..-1] -join ''

    # Need to check whether the thread already exists
    $irm_splat.Uri = "https://discord.com/api/guilds/$($QueueItem.GuildID)/threads/active"
    $threads = Invoke-RestMethod @irm_splat | Select-Object -expand threads
    if ($thread = $threads | Where-Object { $_.name[0..3] -join '' -eq $last4 }) {
        $response = "Already created! <#$($thread.id)>"
    }
    else {
        try {
            $irm_splat.Uri = "https://discord.com/api/channels/$($QueueItem.ParentChannelID)/threads"
            $res = Invoke-RestMethod @irm_splat -Method post -ea stop -Body ( @{
                    name    = "${last4}: $($QueueItem.Username)"
                    message = @{
                        content = "From: <#$($channel.id)>"
                    }
                    type    = 11
                } | ConvertTo-Json)
            $response = "Created! <#$($res.id)>"
        }
        catch {
            $response = "Failed to create thread '${last4}: $($QueueItem.Username)', response: $_"
            $_
        }
    }
    $response

    $invokeRestMethod_splat = @{
        Uri               = "https://discord.com/api/v8/webhooks/{0}/{1}/messages/@original" -f $QueueItem.ApplicationID, $QueueItem.Token
        Method            = "Patch"
        ContentType       = "application/json"
        Body              = (@{
                type    = 4
                content = $response -join "`n"
                flags   = 64 # Ephemeral
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
}
