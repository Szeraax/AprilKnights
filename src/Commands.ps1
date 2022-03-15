param(
    [switch]$GuildSpecific,
    $GuildID = "",
    [ValidateSet("GetBearer", "ListCommands", "AddSlashCommand", "AddUserCommand", "AddMessageCommand", "RemoveCommand")]
    $Command,
    $Bearer = "",
    $Client_secret = "",
    $ApplicationID = "",
    $CommandID

)

function ConvertTo-Base64 ($String) {
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    $EncodedText = [Convert]::ToBase64String($Bytes)
    $EncodedText
}

$url = "https://discord.com/api/v8/applications/$Applicationid/commands"
if ($GuildSpecific) {
    $url = $url -replace "commands", "guilds/$guildID/commands"
}
$headers = @{Authorization = "Bearer $bearer" }

switch ($command) {
    "GetBearer" {
        $auth = ConvertTo-Base64 "${Applicationid}:${client_secret}"
        $headers = @{Authorization = "Basic $auth" }
        Invoke-RestMethod https://discord.com/api/oauth2/token -Headers $headers -Method Post -Body @{
            'grant_type' = 'client_credentials'
            'scope'      = 'identify connections applications.commands applications.commands.update'
        }
    }
    "ListCommands" {
        Invoke-RestMethod -Headers $headers -Uri $url
    }

    "AddSlashCommand" {
        Invoke-RestMethod -Headers $headers -Uri $url -Method Post -ContentType application/json -Body (@{
                type        = 1
                name        = "Expando"
                description = "Attempt to find the next destination of a URI"
                options     = @(
                    @{
                        type        = 3
                        name        = "link"
                        description = "The URI to lookup"
                        required    = $true
                    }
                )
            } | ConvertTo-Json)
    }
    "AddUserCommand" {
        Invoke-RestMethod -Headers $headers -Uri $url -Method Post -ContentType application/json -Body (@{
                type = 2
                name = "Thank"
            } | ConvertTo-Json)
    }
    "AddMessageCommand" {
        # Not implemented. Could be used to have the bot respond to a specific command
        Invoke-RestMethod -Headers $headers -Uri $url -Method Post -ContentType application/json -Body (@{
                type = 3
                name = "Look"
            } | ConvertTo-Json)
    }
    "RemoveCommand" {
        if ($CommandID) { Invoke-RestMethod -Headers $headers -Uri $url/$CommandID -Method Delete }
        else { Write-Warning "No command ID specified. Exiting" }
    }
}
