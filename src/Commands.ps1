param(
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
if ($GuildID) {
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
                name        = "interview"
                description = "Tools for interviewing"
                options     = @(
                    @{
                        type        = 2
                        name        = "get"
                        description = "Retrieve data"
                        options     = @(
                            @{
                                type        = 1
                                name        = "battalions"
                                description = "Link to the current battalions list"
                            }
                        )
                    }
                    @{
                        type        = 2
                        name        = "verify"
                        description = "check data"
                        options     = @(
                            @{
                                type        = 1
                                name        = "reddit"
                                description = "Generate a link that a user can use to verify their reddit account"
                            }
                        )
                    }
                )
            } | ConvertTo-Json -Depth 7)
    }
    "AddUserCommand" {
        $url
        Invoke-RestMethod -Headers $headers -Uri $url -Method Post -ContentType application/json -Body (@{
                type = 2
                name = "Battalion Announce"
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
