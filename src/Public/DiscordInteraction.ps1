<#

.DESCRIPTION
A fully functioning web server for receiving Discord Interactions.

Ctrl+C to stop running.

.NOTES
Service: If you want to run it as a service you can run it as a scheduled task in Windows or create a init.d script with watchdog for Linux.
Multi-Threaded: Can be, just variable scope and passing through the Handler Script block to a Job with its dependencies.

.PARAMETER Binding
Runs a web server on the given binding.

If not running as admin, as admin permit the binding:

netsh http add urlacl url=http://+:8080/ user=username

.PARAMETER Handler
A script block accepting a [Interaction] object as its parameter and returning a [InteractionResponse] object.

It can't strictly have any dependencies, however you can pipeline after the Acknowledge is sent to continue logic.

.OUTPUTS
The outputs are the different objects as they are being processed, along with a PSTimeStamp for the time it happens.

[System.Net.HttpListenerRequest] = Before
[Interaction] = After
[InteractionResponse] = Before
[Exception] = After
[System.Net.HttpListenerResponse] = After
[System.Net.HttpListenerContext] = Final

[System.Net.HttpListenerContext] is extended with Interaction, InteractionResponse and Exception.

.EXAMPLE

$appPublicKey = '<YOUR HEX KEY HERE>'

Receive-DiscordInteraction -ApplicationPublicKey $appPublicKey -Handler {
    param([Interaction]$interaction)

    if ($interaction.data) {
        if ($interaction.data.name -eq 'test') {
            [InteractionResponse]@{
                type = [InteractionResponseType]::ChannelMessage
                data = @(
                    [InteractionApplicationCommandCallbackData]@{
                        content = 'Hello World!'
                    }
                )
            }
        }
    }
} | Format-HttpListener -IncludeProperty @(
    @{N='InteractionType'; E={if ($_.Interaction) { $_.Interaction.type }}},
    @{N='InteractionCommand'; E={if ($_.Interaction -and $_.Interaction.data) { $_.Interaction.data.name }}},
    @{N='InteractionOptions'; E={if ($_.Interaction -and $_.Interaction.data -and $_.Interaction.data.options) { $_.Interaction.data.options | ConvertTo-Json -Compress }}},
    @{N='InteractionResponseType'; E={if ($_.InteractionResponse) { $_.InteractionResponse.type }}}
) | Export-Csv -NoTypeInformation -Delimter "`t" -UseQuotes AsNeeded -Append -Path "DiscordInteractionLog_$((Get-Date).ToString('yyyy_MM')).tsv"

#>
Function Receive-DiscordInteraction {
    [OutputType(
        [System.Net.HttpListenerRequest],
        [Interaction],
        [InteractionResponse],
        [Exception], 
        [System.Net.HttpListenerResponse], 
        [System.Net.HttpListenerContext]
    )]
    param (
        [Parameter(Mandatory)][string]$ApplicationPublicKey,
        [Parameter(Mandatory)][ScriptBlock]$Handler,
        [string]$Binding = 'http://+:8080/',
        [int]$ThrottleLimit = [Math]::Min([System.Environment]::ProcessorCount - 1, 4)
    )
    begin {
        $invalidSignatureResponse = [Text.Encoding]::UTF8.GetBytes('invalid request signature')
        $appPublicKey = [Sodium.Utilities]::HexToBinary($ApplicationPublicKey)
    }
    process {
        Receive-HttpListener -Binding:$Binding | ForEach-Object {
            [System.Net.HttpListenerContext]$context = $_

            $invalidSignatureResponse = $invalidSignatureResponse
            $appPublicKey = $appPublicKey
            
            $result = $null
            
            try {
                if ($context.Request.HttpMethod -ne 'POST') {
                    throw [int][System.Net.HttpStatusCode]::MethodNotAllowed
                }

                if ($context.Request.Headers.Keys -notcontains 'Content-Length') {
                    throw [int][System.Net.HttpStatusCode]::LengthRequired
                }

                if ($context.Request.Headers.Keys -notcontains 'X-Signature-Timestamp' -or 
                    $context.Request.Headers.Keys -notcontains 'X-Signature-Ed25519') {
                    throw [int][System.Net.HttpStatusCode]::PreconditionFailed
                }

                $contentLength = 0

                if (-not [Int32]::TryParse($context.Request.Headers['Content-Length'], [ref]$contentLength)) { 
                    throw 412
                }

                if ($contentLength -gt 1MB) {
                    throw 413
                }
                
                $timestampUnix = 0
                
                if (-not [Int32]::TryParse($context.Request.Headers['X-Signature-Timestamp'], [ref]$timestampUnix)) { 
                    throw 412
                }

                $timestamp = [DateTimeOffset]::FromUnixTimeSeconds($timestampUnix)

                $offset = [DateTimeOffset]::UtcNow.Subtract($timestamp)

                if ([Math]::Abs($offset.TotalMinutes) -gt 15) {
                    throw 425
                }

                [byte[]]$signature = [Sodium.Utilities]::HexToBinary($context.Request.Headers['X-Signature-Ed25519'])
                                
                if ($signature.Length -gt 1KB) { 
                    throw 431
                }
                
                $timestampBytes = [Text.Encoding]::UTF8.GetBytes($context.Request.Headers['X-Signature-Timestamp'])

                $message = [System.IO.MemoryStream]::new($contentLength + $timestampBytes.Length)

                $message.Write($timestampBytes, 0, $timestampBytes.Length)

                $context.Request.InputStream.CopyTo($message)
                
                if (-not [Sodium.PublicKeyAuth]::VerifyDetached($signature, $message.GetBuffer(), $appPublicKey)) {
                    throw [int][System.Net.HttpStatusCode]::Unauthorized
                }

                $finalMessage = [System.Text.Encoding]::UTF8.GetString($message.GetBuffer(), $timestampBytes.Length, $contentLength)

                $json = $finalMessage | ConvertFrom-Json

                $interaction = [Interaction]$json

                $context | Add-Member -NotePropertyName 'Interaction' -NotePropertyValue ([Interaction]$json)
                $context.Interaction | Add-Member -NotePropertyName 'PSTimeStamp' -NotePropertyValue (Get-Date)
                
                $result = $null

                $result = if ($interaction.type -eq [InteractionType]::Ping) {
                    [InteractionResponse]@{
                        type = [InteractionResponseType]::Pong
                    }
                } else {
                    Invoke-Command -ScriptBlock $Handler -ArgumentList $interaction
                }

                if (-not $result) { 
                    $result = [InteractionResponse]@{
                        type = [InteractionResponseType]::Acknowledge
                    }
                }

                $resultJson = $result | ConvertTo-JsonObject | ConvertTo-Json -Compress -Depth 10

                $context | Add-Member -NotePropertyName 'InteractionResponse' -NotePropertyValue $result
                $context.InteractionResponse | Add-Member -NotePropertyName 'PSTimeStamp' -NotePropertyValue (Get-Date)

                $context.Response.ContentType = 'application/json'

                $result = $resultJson
            } catch {
                $result = $_
            }
            
            $context | Add-Member -NotePropertyName Result -NotePropertyValue $result -PassThru
        } | Send-HttpListener
    }
}
<#

.DESCRIPTION
Creates a sample DiscordInteraction for testing with Send-DiscordInteraction.

For more flexibility create your own [Interaction] instance and use (New-DiscordSnowflake) for identifiers.

#>
Function New-DiscordInteraction ([String]$Command, [HashTable]$Options, [ApplicationCommandInteractionDataOption[]]$DataOptions) {
    $data = $null

    $type = if ($Command) {
        [InteractionType]::ApplicationCommand

        $data = [ApplicationCommandInteractionData]@{
            id = (New-DiscordSnowflake)
            name = $Command
        }

        if ($DataOptions) {
            $data.options = $DataOptions
        } elseif ($Options) {
            $data.options = $Options.Keys | ForEach-Object {
                [ApplicationCommandInteractionDataOption]@{
                    name = $_
                    value = $Options[$_]
                }
            }
        }
    } else {
        [InteractionType]::Ping
    }

    [Interaction]@{
        id = (New-DiscordSnowflake)
        type = $type
        data = $data
        guild_id = (New-DiscordSnowflake)
        channel_id = (New-DiscordSnowflake)
        member = [GuildMember]@{
            nick = 'NO API SUPPORT'
            roles = @((New-DiscordSnowflake))
            joined_at = (Get-Date).AddYears(-1).Date
            deaf = $false
            mute = $false
        }
        token = [Guid]::NewGuid().ToString()
        version = 1        
    }
}
<#

.DESCRIPTION
Lets you test your DiscordInteraction API.

.EXAMPLE
$keypair = [Sodium.PublicKeyAuth]::GenerateKeyPair()

$appPublicKey = [Sodium.Utilities]::BinaryToHex($keypair.PublicKey)
$appPrivateKey = [Sodium.Utilities]::BinaryToHex($keypair.PrivateKey)

Write-Host "`$appPublicKey = '$appPublicKey'"
Write-Host "`$appPrivateKey = '$appPrivateKey'"

# Start your server with the $appPublicKey in another instance

Send-DiscordInteraction -ApplicationPrivateKey $appPrivateKey -Interaction (New-DiscordInteraction)
Send-DiscordInteraction -ApplicationPrivateKey $appPrivateKey -Interaction (New-DiscordInteraction -Command 'test')

#>
Function Send-DiscordInteraction (
    [string]$EndPoint = 'http://localhost:8080/',
    [Parameter(Mandatory)][string]$ApplicationPrivateKey,
    [Parameter(Mandatory)][Interaction]$interaction,
    [switch]$WhatIf
) {
    $appPrivateKey = [Sodium.Utilities]::HexToBinary($ApplicationPrivateKey)

    $json = $interaction | ConvertTo-JsonObject | ConvertTo-Json -Compress

    $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    
    $signature = [Sodium.PublicKeyAuth]::SignDetached($ts.ToString() + $json, $appPrivateKey)

    $headers = @{
        'X-Signature-Timestamp' = $ts
        'X-Signature-Ed25519' = [Sodium.Utilities]::BinaryToHex($signature)
    }
    
    if ($WhatIf) {
        $headers.Body = $json
        $headers
    } else {
        Invoke-RestMethod -Method POST -Uri $EndPoint -UseBasicParsing -Body $json -Headers $headers
    }
}