# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message and insertion time to the information log.
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"

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
    $body = "called token"
    try {
        $userToken = Invoke-RestMethod @irmSplat @invokeRestMethod_GetTokenSplat
    }
    catch {
        $body = "Failed to authorize, could not get authorization from Discord"
        throw $body
    }

    try {
        $Headers = @{Authorization = "Bearer {0}" -f $userToken.access_token }
        $irmSplat.Uri = "$baseUri/users/@me"
        $user = Invoke-RestMethod @irmSplat -Headers $Headers
        # $irmSplat.Uri = "$baseUri/users/@me/guilds"
        # $userGuilds = Invoke-RestMethod @irmSplat -Headers $Headers
        $irmSplat.Uri = "$baseUri/users/@me/connections"
        $userConnections = Invoke-RestMethod @irmSplat -Headers $Headers

        $data = [ordered]@{
            DiscordId   = $user.id
            DiscordUser = "{0}#{1}" -f $user.username, $user.discriminator
            RedditUser  = "No reddit user connected"
            Locale      = $user.locale
        }

        if ($reddituser = $userConnections | Where-Object type -EQ "reddit") {
            $data.RedditUser = $reddituser.name
            $irmSplat.Uri = "https://www.reddit.com/r/AprilKnights/comments/gdbsi0/it_is_the_age_of_the_imposter_hile_and_welcome.json"
            $pledges = Invoke-RestMethod @irmSplat
            $comments = Get-Comments $pledges[1..99]
            $userComments = $comments | Where-Object author -EQ $data.redditUser | Sort-Object -desc created
            if ($userComments) {
                if ($userComments.count -ge 1) {
                    $addin = " (comment 1 of their {0} comments in thread)" -f $comments.count
                }
                $redditMessage = "{1}. They left this comment in the pledge thread${addin}:`n> {2}`nSrc: {3}" -f @(
                    $data.redditUser
                    $userComments[0].body
                    $userComments[0].permalink
                )
            }
            else {
                $redditMessage = "{0}. They HAVE NOT left any comment in the pledge thread located here:`n{1}`n<@{2}>, you need to go pledge your support in this thread." -f @(
                    $data.redditUser
                    $irmSplat.Uri -replace ".json$"
                    $user.id
                )
            }
        }
        else {
            $redditMessage = "NOT FOUND!`n<@{0}>, you need to connect your Discord account to your Reddit account for verification." -f $user.id
        }

        $table = Get-AzTableTable -resourceGroup AprilKnights -TableName Squirelike -storageAccountName aprilknights80e7
        if (-not $table) { throw "no table found" }
        $row = Get-AzTableRow -Table $table | Where-Object rowkey -Match $user.id | Sort-Object TableTimestamp | Select-Object -Last 1
        if (-not $row) { throw "no row found" }
        $data.Requestor = $row.Requestor
        $data.Name = $row.Name
        $data.Token = $row.Token
        $i = 0
        $pending = $true
        do {
            try {
                $i++
                Add-AzTableRow -Table $table -PartitionKey "Authorized" -RowKey ($user.id + $user.username) -UpdateExisting -Property $data -ea stop
                $pending = $false
            }
            catch {
                Start-Sleep 1
                $_.Exception | Write-Host
            }
        } while ($i -le 3 -or $pending)


        $response = "For user <@{0}>, their reddit account is $redditMessage" -f $data.DiscordId

        $item = @{
            application_id = $row.ApplicationId
            token          = $row.Token
        }
    }
    catch {
        $body = "Failed to authorize2, please click the link again. "
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
