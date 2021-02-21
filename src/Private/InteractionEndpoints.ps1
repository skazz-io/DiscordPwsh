<#

https://discord.com/developers/docs/interactions/slash-commands#endpoints

#>
<#

.DESCRIPTION
Fetch all of the global commands for your application. Returns an array of ApplicationCommand objects.

.PARAMETER ApplicationId

.PARAMETER GuildId
Perform operation on the specified Guild.

.OUTPUTS

#>
Function Get-GlobalApplicationCommand {
    [OutputType([ApplicationCommand])]
    param (
        [parameter(Mandatory)][string]$ApplicationId,
        [string]$GuildId
    )

    $uri = "applications/$ApplicationId"

    if ($GuildId) {
        $uri += "guilds/$GuildId"
    }

    $uri += '/commands'

    [System.Net.Http.HttpResponseMessage]$response = Invoke-DiscordApi -Uri $uri -Method 'GET'

    if (-not $response.IsSuccessStatusCode) {
        Write-Error -Message 'Api Request Failure' -TargetObject $response
    } else {
        try {
            $response.Body | ForEach-Object {
                [ApplicationCommand]$_
            }
        } catch {
            Write-Error -Message 'Api Response Not Parsable' -TargetObject $response
        }
    }
}
<#

.DESCRIPTION
Create a new global command. New global commands will be available in all guilds after 1 hour. Returns 201 and an ApplicationCommand object.

.PARAMETER GuildId
Perform operation on the specified Guild.

.NOTES
Creating a command with the same name as an existing command for your application will overwrite the old command. (Why PATCH then...)

#>
Function Publish-GlobalApplicationCommand {
    [OutputType([ApplicationCommand])]
    param (
        [ApplicationCommand[]]$InputObject,
        [string]$GuildId
    )
    process {
        $command = [ApplicationCommand]$_

        $uri = "applications/$($command.application_id)"

        if ($GuildId) {
            $uri += "guilds/$GuildId"
        }
    
        $uri += '/commands'

        [System.Net.Http.HttpResponseMessage]$response = Invoke-DiscordApi -Uri $uri -Method 'POST' -Body $command

        if (-not $response.IsSuccessStatusCode) {
            Write-Error -Message 'Api Request Failure' -TargetObject $response
        } else {
            try {
                [ApplicationCommand]$response.Body
            } catch {
                Write-Error -Message 'Api Response Not Parsable' -TargetObject $response
            }
        }
    }
}
<#

.DESCRIPTION
Edit a global command. Updates will be available in all guilds after 1 hour. Returns 200 and an ApplicationCommand object.

.PARAMETER GuildId
Perform operation on the specified Guild.

#>
Function Edit-GlobalApplicationCommand {
    param (
        [ApplicationCommand[]]$InputObject,
        [string]$GuildId
    )
    process {
        $command = [ApplicationCommand]$_

        $uri = "applications/$($command.application_id)"

        if ($GuildId) {
            $uri += "guilds/$GuildId"
        }
    
        $uri += "/commands/$($command.id)"

        [System.Net.Http.HttpResponseMessage]$response = Invoke-DiscordApi -Uri $uri -Method 'PATCH' -Body $command

        if (-not $response.IsSuccessStatusCode) {
            Write-Error -Message 'Api Request Failure' -TargetObject $response
        } else {
            try {
                [ApplicationCommand]$response.Body
            } catch {
                Write-Error -Message 'Api Response Not Parsable' -TargetObject $response
            }
        }
    }
}
<#

.DESCRIPTION
Delete a guild command. Returns 204 on success.

.PARAMETER GuildId
Perform operation on the specified Guild.

#>
Function Unpublish-GlobalApplicationCommand {
    param (
        [ApplicationCommand[]]$InputObject,
        [string]$GuildId
    )
    process {
        $command = [ApplicationCommand]$_

        $uri = "applications/$($command.application_id)"

        if ($GuildId) {
            $uri += "guilds/$GuildId"
        }
    
        $uri += "/commands/$($command.id)"

        [System.Net.Http.HttpResponseMessage]$response = Invoke-DiscordApi -Uri $uri -Method 'DELETE'

        if (-not $response.IsSuccessStatusCode) {
            Write-Error -Message 'Api Request Failure' -TargetObject $response
        } elseif ($response.StatusCode -ne 204) {
            Write-Error -Message 'Api Response Not Expected' -TargetObject $response
        }
    }
}
<#

.DESCRIPTION
Create a response to an Interaction from the gateway. Takes an Interaction response.

#>
Function Publish-InteractionResponse {
    param (
        [InteractionResponseCommand[]]$InputObject
    )
    process {
        $command = [InteractionResponseCommand]$_

        $uri = "interactions/$($command.Interaction.id)/$($command.Interaction.token)/callback"

        [System.Net.Http.HttpResponseMessage]$response = Invoke-DiscordApi -Uri $uri -Method 'POST' -Body $command.InteractionResponse

        if (-not $response.IsSuccessStatusCode) {
            Write-Error -Message 'Api Request Failure' -TargetObject $response
        } else {
            try {
                [ApplicationCommand]$response.Body
            } catch {
                Write-Error -Message 'Api Response Not Parsable' -TargetObject $response
            }
        }
    }
}