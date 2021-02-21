<#

.DESCRIPTION
A multi-threaded HTTP Server using [System.Net.HttpListener].

.NOTES


.PARAMETER Binding
Runs a web server on the given binding, plus (+) is a wildcard.

If not running as admin, as admin permit the binding:

netsh http add urlacl url=http://+:8080/ user=username

.PARAMETER LoopTimeoutMs
Defaults to 200ms, the timeout between loops to allow Ctrl+C to work.

.EXAMPLE

$responseBody = [Text.Encoding]::UTF8.GetBytes('Hello World!')

Receive-HttpListener | ForEach-Object -ThrottleLimit 8 -Parallel {
    [System.Net.HttpListenerContext]$context = $_

    try {
        # $context.Request

        $context.Response.StatusCode = 200
        $context.Response.StatusDescription = 'OK'
        
        $context.Response.ContentLength64 = $using:responseBody.Length
        $context.Response.OutputStream.Write($using:responseBody, 0, $using:responseBody.Length)

        $context.Response.OutputStream.Flush()
        $context.Response.OutputStream.Close()

        # $context.Response

        $responses = $using:responses

        $responses.Array += $context
    } catch {
        $context | Add-Member -NotePropertyName Exception -NotePropertyValue $_
    } finally {
        $context
    }
}

$job | receive-job



#>
Function Receive-HttpListener {
    [OutputType([System.Net.HttpListenerContext])]
    param (
        [string[]]$Binding = @('http://+:8080/'),
        [int]$LoopTimeoutMs = 200,
        [TimeSpan]$TimeoutResponseBody = [TimeSpan]::FromSeconds(15),
        [TimeSpan]$TimeoutEntityBody = [TimeSpan]::FromSeconds(15),
        [TimeSpan]$TimeoutDrainEntityBody = [TimeSpan]::FromSeconds(15),
        [TimeSpan]$TimeoutRequestQueue = [TimeSpan]::FromSeconds(120),
        [TimeSpan]$TimeoutIdleConnection = [TimeSpan]::FromSeconds(120),
        [TimeSpan]$TimeoutHeaderWait = [TimeSpan]::FromSeconds(15),
        [uint]$MinSendBytesPerSecond = 128
    )

    if (-not [System.Net.HttpListener]::IsSupported) {
        throw '[System.Net.HttpListener] is not supported on this platform.'
    }

    $http = [System.Net.HttpListener]::new()

    $Binding | ForEach-Object {
        $http.Prefixes.Add($_)
    }

    $http.TimeoutManager.EntityBody = $TimeoutEntityBody
    $http.TimeoutManager.DrainEntityBody = $TimeoutDrainEntityBody
    $http.TimeoutManager.RequestQueue = $TimeoutRequestQueue
    $http.TimeoutManager.IdleConnection = $TimeoutIdleConnection
    $http.TimeoutManager.HeaderWait = $TimeoutHeaderWait
    $http.TimeoutManager.MinSendBytesPerSecond = $MinSendBytesPerSecond

    $http.Start()

    try {
        while ($http.IsListening) {
            $contextTask = $http.GetContextAsync()

            while (-not $contextTask.AsyncWaitHandle.WaitOne($LoopTimeoutMs)) {
                
            }
            
            [System.Net.HttpListenerContext]$context = $contextTask.GetAwaiter().GetResult()

            if (-not $context) {
                break
            }
            
            $context.Request | Add-Member -NotePropertyName 'PSTimeStamp' -NotePropertyValue (Get-Date)

            $context.Response.StatusCode = 999

            $context
        }
    } finally {
        $http.Close()
        $http.Dispose()
    }
}
<#

.DESCRIPTION
Will convert pipeline output after your pipeline for Receive-HttpListener.

You must return the [System.Net.HttpListenerContext] with the added Result NoteProperty.

The Result property can be a [IO.Stream], [byte[]]/[bigint], [primitives]

.PARAMETER RealtimeLog
For better logging/debugging, outputs the Response object at the start and Exception (if occured) with PSTimeStamp.

.EXAMPLE

Receive-HttpListener | ForEach-Object {
    [System.Net.HttpListenerContext]$context = $_

    $result = try {
        if ($context.Request.Url.LocalPath -eq '/') {
            'Hello World!'
        } else {
            throw 404
        }
    } catch {
        $_
    }

    $context | Add-Member -NotePropertyName Result -NotePropertyValue $result -PassThru
} | Send-HttpListener

#>
Function Send-HttpListener {
    param (
        $RealtimeLog
    )
    begin {
        $ExtendedStatusCodes = @{
            '413' = 'Payload too large'
            '425' = 'Too Early'
            '431' = 'Request Header Fields Too Large'
        }
    }
    process {
        [System.Net.HttpListenerContext]$context = $_

        $context.Response | Add-Member -NotePropertyName 'PSTimeStamp' -NotePropertyValue (Get-Date) -ErrorAction SilentlyContinue -PassThru:$RealtimeLog

        try {
            if ($result -is [Exception]) {
                throw $result
            }

            if (-not $context.Result) {
                throw 204
            }

            $result = $context.Result

            $contentType = 'application/octet-stream'

            $resultStream = if ($result -is [IO.Stream]) {
                $result
            } else {
                $resultBuffer = if ($result -is [byte[]]) {
                    $result
                } elseif ($result -is [bigint]) {
                    ([bigint]$result).ToByteArray()
                } else {
                    $contentType = 'text/plain'

                    $resultString = if ($result -is [string]) {
                        $result
                    } elseif ($result.GetType().IsPrimitive) {
                        $result.ToString()
                    } else {
                        $contentType = 'application/json'

                        $resultObject = if ($result -is [HashTable]) {
                            [pscustomobject]$result
                        } else {
                            $result
                        }

                        $resultObject | ConvertTo-Json -Compress
                    }

                    [Text.Encoding]::UTF8.GetBytes($resultString)
                }

                [System.IO.MemoryStream]::new($resultBuffer)
            }

            if (-not $context.Response.ContentType) {
                $context.Response.ContentType = $contentType
            }
            
            if ($context.Response.StatusCode -eq 999) {
                $context.Response.StatusCode = 200
                $context.Response.StatusDescription = 'OK'
            }
            
            if ($context.Response.ContentLength64 -eq 0) {
                if ($resultStream.Length -gt 0) {
                    $context.Response.ContentLength64 = $resultStream.Length
                } else {
                    $context.Response.SendChunked = $true
                }
            }

            $resultStream.CopyTo($context.Response.OutputStream)
        } catch {
            $statuscode = [System.Net.HttpStatusCode]::InternalServerError
            
            if ([System.Net.HttpStatusCode]::TryParse($_.Exception.Message, [ref]$statuscode)) {
                $context.Response.StatusCode = [int]$statuscode
                $context.Response.StatusDescription = $statuscode
            } elseif ($ExtendedStatusCodes.ContainsKey($_.Exception.Message)) {
                $context.Response.StatusCode = $_.Exception.Message
                $context.Response.StatusDescription = $ExtendedStatusCodes[$_.Exception.Message]
            } else {
                $context | Add-Member -NotePropertyName 'Exception' -NotePropertyValue $_ -PassThru:$RealtimeLog
            }
        } finally {
            try { 
                if ($context.Response.StatusCode -eq 999) {
                    $statuscode = [System.Net.HttpStatusCode]::InternalServerError
                    $context.Response.StatusCode = [int]$statuscode
                    $context.Response.StatusDescription = $statuscode
                }

                $context.Response.OutputStream.Flush()
                $context.Response.OutputStream.Close()
            } catch { }
            
            $context | Add-Member -NotePropertyName 'PSTimeStamp' -NotePropertyValue (Get-Date)
            $context
        }
    }
}
<#

.DESCRIPTION
Result formatter for the Receive-HttpListener and optionally the Send-HttpListener.

To best utilise you should use Add-Member to the [HttpListenerContext] with custom types and add PSTimeStamp.

.PARAMETER IncludeProperty
Adds additional Select-Object properties to the default or selected format.

.PARAMETER ExcludeProperty
Removes from the default properties sent.

.EXAMPLE

... | Format-HttpListener

#>
Function Format-HttpListener {
    param (
        [object[]]$IncludeProperty,
        [string[]]$ExcludeProperty
    )
    begin {
        $properties = if ($TextLogFormat) {
            @(
                @{N='TimeStamp'; E={$_.Request.PSTimeStamp.ToString('s')}},
                @{N='RemoteEndPoint'; E={$_.Request.RemoteEndPoint}},
                @{N='UserName'; E={$_.User.Identity.Name}},
                @{N='LocalEndPoint'; E={$_.Request.LocalEndPoint}},
                @{N='HttpMethod'; E={$_.Request.HttpMethod}},
                @{N='RawUrl'; E={$_.Request.RawUrl}},
                @{N='RequestLength'; E={$_.Request.InputStream.Length}},
                @{N='ResponseLength'; E={$_.Request.OutputStream.Length}},
                @{N='DurationMiliseconds'; E={($_.Response.PSTimeStamp - $_.Request.PSTimeStamp).TotalMiliseconds}},
                @{N='ProtocolVersion'; E={$_.Response.ProtocolVersion}},
                @{N='Host'; E={$_.Request.UserHostName}},
                @{N='UserAgent'; E={$_.Request.UserAgent}},
                @{N='Referrer'; E={$_.Request.UrlReferrer.ToString()}},
                @{N='StatusCode'; E={$_.Response.StatusCode}}
            )
        }

        if ($ExcludeProperty) {
            $properties = $properties | Where-Object -Not { $p = $_; $ExcludeProperty | Where-Object { $p.N -like $_ } | Select-Object -First 1 }
        }

        if ($IncludeProperty) {
            $properties += $IncludeProperty
        }
    }
    process {
        $result = $_

        if ($result -is [System.Net.HttpListenerContext]) {
            [System.Net.HttpListenerContext]$context = $result

            Select-Object -InputObject $context -Property $properties
        }
    }
}
<#

.DESCRIPTION
WIP

.PARAMETER FileDirectory
Specify a directory and use the generated filename.

.PARAMETER FilePath
Specify your own full file path.

.PARAMETER CsvFormat
Output to a CSV file for easy Import-Csv to parse the logs

.PARAMETER JsonFormat
Output to a JSON file that stacks logs in a json array.

.PARAMETER LogRotate
Needed if FilePath is provided as the name wont be the date.

.PARAMETER NoLogRotate
Turn off automatic log rotate.

.EXAMPLE

... | Format-HttpListener | Out-HttpListener -CsvFormat

.NOTES

# CSV for easy import
... | Format-HttpListener | Export-Csv -NoTypeInformation -UseQuotes AsNeeded -Append -Path "HttpLog_$((Get-Date).ToString('yyyy-MM-dd')).csv"

# Traditional Text Log space seperated with UrlEncode cells
... | Format-HttpListener | % { $_.PSObject } | % { "# $(($_.Name | % { [System.Web.HttpUtility]::UrlEncode($_) }) -join ' ')"" } { ($_.Value | % { [System.Web.HttpUtility]::UrlEncode($_) }) -join ' ' } | Tee-Object -Append -FilePath "HttpLog_$((Get-Date).ToString('yyyy-MM-dd')).txt"

# Or bypass entirely and save JSON objects
... | Format-HttpListener | % { '['; $d='' } { "$d$($_ | ConvertTo-Json -Compress)"; $d=',' } { ']' } | Tee-Object -Append -FilePath "HttpLog_$((Get-Date).ToString('yyyy-MM-dd HH-mm-ss')).json"

#>
Function Out-HttpListener {
    param (
        [Parameter(ParameterSetName='ByDirectory')]
        [string]$FileDirectory,
        [Parameter(ParameterSetName='ByPath')]
        [string]$FilePath,

        [Parameter(ParameterSetName='ByDefault')]
        [Parameter(ParameterSetName='ByDirectory')]
        [Parameter(ParameterSetName='ByPath')]
        [switch]$CsvFormat,
        [Parameter(ParameterSetName='ByDefault')]
        [Parameter(ParameterSetName='ByDirectory')]
        [Parameter(ParameterSetName='ByPath')]
        [switch]$JsonFormat,
        [Parameter(ParameterSetName='ByDefault')]
        [Parameter(ParameterSetName='ByDirectory')]
        [Parameter(ParameterSetName='ByPath')]
        [switch]$TextFormat
    )
    begin
    {
        if (-not ($CsvFormat -or $JsonFormat -or $TextFormat)) {
            throw 'Must specify Out-HttpListener Format.'
        }

        $finalPath = "HttpListener_$((Get-Date).ToString('yyyy-MM-dd'))"

        if ($FileDirectory) {
            [IO.Path]::Combine($FileDirectory, $finalPath)
        }

        if ($FilePath) {
            $finalPath = $FilePath
        } elseif ($CsvFormat) {
            $finalPath += '.csv'
        } elseif ($JsonFormat) {
            $finalPath += '.json'
        } elseif ($TextFormat) {
            $finalPath += '.txt'
        }
        
        $exists = Test-Path $finalPath

        try {
            $scriptCmd = if ($CsvFormat) {
                { & Export-Csv -NoTypeInformation -UseQuotes AsNeeded -Append -Path }
            } elseif ($JsonFormat) {
                
            } elseif ($TextFormat) {
                
            }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)

            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }
    process
    {
        try {
            if ($JsonFormat) {

            }

            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }
    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
}

Class WebSocketMessage {
    [System.ArraySegment[byte]]$Buffer

}

Function Connect-HttpListenerWebSocket {
    param (
        [string]$SubProtocol,
        [switch]$SocketOnly
    )
    process {
        [System.Net.HttpListenerContext]$context = $_

        $task = $context.AcceptWebSocketAsync($SubProtocol)

        while (-not $task.AsyncWaitHandle.WaitOne(200)) { }
        
        [System.Net.WebSockets.HttpListenerWebSocketContext]$websocketContext = $task.GetAwaiter().GetResult()

        if ($SocketOnly) {
            $websocketContext.WebSocket
        } else {
            $websocketContext
        }
        
    }
}

Function Receive-WebSocket {
    param (
        [switch]$NoBinary,
        [switch]$NoText,
        [int]$MaxMessage,
        [Text.Encoding]$Encoding = [Text.Encoding]::UTF8,
        [int]$InitialBufferSize = 1KB,
        [int]$MaxBufferSize = 64KB
    )
    process {
        [System.Net.WebSockets.WebSocket]$websocket = $_
        
        $buffer = [byte[]]::new($InitialBufferSize)
        $count = 0

        $ct = [System.Threading.CancellationToken]::None

        while ($websocket -eq [System.Net.WebSockets.WebSocketState]::Open) {

            $seg = [System.ArraySegment[byte]]::new($buffer, $recieved)

            $task = $websocket.ReceiveAsync($seg, $ct)

            while (-not $task.AsyncWaitHandle.WaitOne(200)) { }

            [System.Net.WebSockets.WebSocketReceiveResult]$receiveResult = $task.GetAwaiter().GetResult()

            $closeStatus = if ($NoBinary -and $receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Binary) {
                [System.Net.WebSockets.WebSocketCloseStatus]::InvalidMessageType
            } elseif ($NoText -and $receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                [System.Net.WebSockets.WebSocketCloseStatus]::InvalidMessageType
            } elseif ($receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure
            } elseif (-not $receiveResult.EndOfMessage -and $buffer.Length -ge $MaxBufferSize) {
                [System.Net.WebSockets.WebSocketCloseStatus]::MessageTooBig
            }

            if ($closeStatus) {
                $closeMessage = if ($close -eq [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure) {
                    'Client Request Closure'
                } else {
                    "$($receiveResult.MessageType) not supported"
                }

                $closeTask = $websocket.CloseAsync($closeStatus, $closeMessage, $ct)

                while (-not $closeTask.AsyncWaitHandle.WaitOne(200)) { }

                $closeTask.GetAwaiter().GetResult()
            } else {
                $count += $receiveResult.Count

                if ($receiveResult.EndOfMessage) {
                    if ($receiveResult.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Text) {
                        $Encoding.getstring($buffer, 0, $receiveResult.Count)
                    } else {
                        $buffer

                        $buffer = [byte[]]::new($buffer.Length)
                    }

                    $count = 0
                } elseif ($buffer.Length -ge $MaxBufferSize) {
                    $newBuffer = [byte[]]::new($buffer.Length -shl 1)

                    $buffer.CopyTo($newBuffer, 0)

                    $buffer = $newBuffer
                }
            }
        }
    }
}
<#

#>
Function Send-WebSocket {
    process {
        
    }
}
<#

#>
Function Disconnect-WebSocket {
    param(
        [System.Net.WebSockets.WebSocketCloseStatus]$Status,
        [string]$Message
    )
    process {
        [System.Net.WebSockets.WebSocket]$websocket = $_

        $closeTask = $websocket.CloseAsync($Status, $Message, [System.Threading.CancellationToken]::None)

        while (-not $closeTask.AsyncWaitHandle.WaitOne(200)) { }

        $closeTask.GetAwaiter().GetResult()
    }
}