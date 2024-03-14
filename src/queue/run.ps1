# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"

if ($TriggerMetadata.DequeueCount -gt 3) {
    return "Too many failures. Skipping."
}

$item = $QueueItem

if ($uri = $item.data.options.where{ $_.name -eq "link" }.value) {
    if ($uri -notmatch "^http") { $uri = "https://tinyurl.com/$uri" }
    $response = Expand-Uri $uri
    if ($response -match " redirects ") {
        $response = "The URL you supplied redirects and cannot be resolved automatically. Please manually test this URI in your browser: $uri"
    }
}
elseif ($item.data.name -eq "Thank") {
    $response = "Expando is grateful to be noticed by <@$($item.member.user.id)> (Brought to you by <@291431034250067968>)"
}
elseif ($item.data.name -eq "Battalion Announce") {
    $response = "Announcing user <@951952755277328404>"
}
elseif ($item.Code) {
    $response = "unhandled error caught. Please contact szeraax."

    $baseUri = "https://discord.com/api"
    $irmSplat = @{
        MaximumRetryCount = 4
        RetryIntervalSec  = 1
        ErrorAction       = 'Stop'
    }

    $invokeRestMethod_body = @{
        client_id     = $ENV:APP_CLIENT_ID
        client_secret = $ENV:APP_CLIENT_SECRET
        grant_type    = "authorization_code"
        code          = $item.Code
        redirect_uri  = "https://aprilknights.azurewebsites.net/api/Authorized"
    }
    $invokeRestMethod_GetTokenSplat = @{
        Method = 'Post'
        Uri    = "$baseUri/oauth2/token"
        Body   = $invokeRestMethod_body
    }
    $invokeRestMethod_GetTokenSplat | ConvertTo-Json -Compress -Depth 10 | Write-Host
    $body = "called token"
    try {
        $userToken = Invoke-RestMethod @irmSplat @invokeRestMethod_GetTokenSplat
    }
    catch {
        $body = "Failed to authorize, could not get authorization from Discord"
        $_
        throw $body
    }

    try {
        $Headers = @{Authorization = "Bearer {0}" -f $userToken.access_token }
        $irmSplat.Uri = "$baseUri/users/@me"
        $user = Invoke-RestMethod @irmSplat -Headers $Headers
        $user | ConvertTo-Json -Depth 10 | Write-Verbose
        # $irmSplat.Uri = "$baseUri/users/@me/guilds"
        # $userGuilds = Invoke-RestMethod @irmSplat -Headers $Headers
        $irmSplat.Uri = "$baseUri/users/@me/connections"
        $userConnections = Invoke-RestMethod @irmSplat -Headers $Headers
        $userConnections | ConvertTo-Json -Depth 10 | Write-Verbose

        $data = [ordered]@{
            DiscordId   = $user.id
            DiscordUser = "{0}#{1}" -f $user.username, $user.discriminator
            RedditUser  = "No reddit user connected"
            Locale      = $user.locale
        }

        if (-not ($userConnections | Where-Object type -EQ "reddit")) {
            Write-Debug "No connections found. Skipping"
            $redditMessage = "NOT FOUND!`n<@{0}>, you need to connect your Discord account to your Reddit account for verification. Once complete, please run the command again." -f $user.id
        }
        foreach ($reddituser in $userConnections | Where-Object type -EQ "reddit") {
            "Processing connection for account $($reddituser.name)" | Write-Verbose
            $data.RedditUser = $reddituser.name
            $threads = Get-ChildItem ENV:APP_OATH_* | Sort-Object Name -Desc | Select-Object -expand Value
            $attempt = 0
            $current = 0

            $redditMessage = ""
            if ($userComments) {
                if ($userComments.count -gt 1) {
                    $addin = " (comment 1 of their {0} comments in thread)" -f $userComments.count
                }

                $redditMessage += "{0} (https://reddit.com/u/{0}). They left this comment in the pledge thread${addin}:`n{1}`nSrc: {2}`n<@{3}>, you can now remove the discord/reddit connection in your Discord settings." -f @(
                    $data.redditUser
                    $userComments[0].body -replace "`n`n`n", "`n" -replace "(?m)^", "> "
                    $userComments[0].permalink
                    $data.DiscordId
                )

                if ($current -gt 0) {
                    $redditMessage += "`nError: No comments in current oath thread. Please have applicant pledge in the current oath thread"
                }

                # When you have multiple reddit accounts counnected to discord, it is assume that only one of them will be to the April Knights.
                # Find the first account that has userComments in a AK thread and don't search the rest of the accounts thereafter.
                break
            }
            elseif ($attempt -gt 3) {
                $response = "Error occurred. Please try again."
            }
            else {
                $redditMessage = "{0} (https://reddit.com/u/{0}).`n`nBuilder, please go to the [latest oath thread]({1}) and manually verify if there is a pledge present for this user. Then report back here and announce if the pledge was present. `n`n<@{2}>, you can now remove this discord/reddit connection in your Discord settings if you wish." -f @(
                    $data.redditUser
                    $threads[0]
                    $user.id
                )
            }
        }


        $AzDataTableEntity_params = @{
            ConnectionString = $ENV:AzureWebJobsStorage
            TableName        = "Squirelike"
        }
        $row = Get-AzDataTableEntity @AzDataTableEntity_params -Filter "PartitionKey eq 'Candidate' and Timestamp gt datetime'$([Datetime]::now.AddDays(-2).ToString('yyyy-MM-dd'))'" |
        Where-Object PartitionKey -EQ "Candidate" |
        Where-Object RowKey -Match $user.id |
        Sort-Object Timestamp |
        Select-Object -Last 1
        if (-not $row) { throw "no row found" }
        "Row'd" | Write-Host
        $data.Requestor = $row.Requestor
        $data.Name = $row.Name
        $data.Token = $row.Token
        $data.PartitionKey = "Authorized"
        $data.RowKey = $user.id + $user.username
        $i = 0
        $pending = $true
        do {
            try {
                $i++
                Add-AzDataTableEntity @AzDataTableEntity_params -Force -Entity $data -ea stop
                $pending = $false
            }
            catch {
                "Trying again!"
                Start-Sleep 1
                $_.Exception | Write-Host
            }
        } while ($i -le 3 -or $pending)

        if ($redditMessage) {
            $response = "For user <@{0}>, their reddit account is $redditMessage" -f $data.DiscordId
        }

        $item = @{
            application_id = $row.ApplicationId
            token          = $row.Token
        }
        $row.Remove("Token")
        Add-AzDataTableEntity @AzDataTableEntity_params -Force -Entity $row -ea stop
    }
    catch {
        $_
        $body = "Failed to authorize! please click the link again. "
        $body += $irmSplat | ConvertTo-Json -Compress -Depth 7
    }
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
