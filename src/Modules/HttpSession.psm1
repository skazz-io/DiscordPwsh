<#

#>
Class HttpSession {    
    [string]$Name
    [int]$Order
    [System.Net.Http.HttpClient]$HttpClient
}
<#

The module variable that stores the array of sessions.

#>
New-Variable -Scope Script -Force -Name ModuleHttpSession -Value ([HttpSession[]]@())
New-Variable -Scope Script -Force -Name ModuleHttpCounter -Value 0
<#

.DESCRIPTION
Returns all HttpSessions.

#>
Function Get-HttpSession {
    $ModuleHttpSession
}
<#

.DESCRIPTION
Removes and disposes the given session(s).

.PARAMETER Force
Cancel pending requests before dispose of the HttpClient.

TODO: Verify if Dispose waits for pending requests.

#>
Function Remove-HttpSession ([switch]$Force) {
    process {
        [HttpSession]$session = $_

        $ModuleHttpSession.Remove($session)

        if ($Force) {
            $session.HttpClient.CancelPendingRequests()
        }

        $session.HttpClient.Dispose()
    }
}
<#

.DESCRIPTION
Creates a new HttpSession and returns it.

.PARAMETER Name
Friendly name for the session, defaults to HttpSession#.

.PARAMETER Order
Optional Order number for filtering using (Get-HttpSession).

.PARAMETER BaseAddress
The base Uri for every request.

.PARAMETER DefaultRequestHeaders
Default Headers for every request, for Cookie/Authentication.

#>
Function New-HttpSession {
    param (
        [string]$Name,
        [int]$Order,
        [string]$BaseAddress,
        [hashtable]$DefaultRequestHeaders,
        [long]$MaxResponseContentBufferSize,
        [timespan]$Timeout
    )

    $session = [HttpSession]::new()

    $session.HttpClient = [System.Net.Http.HttpClient]::new()

    $session.Name = if ($Name) {
        $Name
    } else {
        "HttpSession$ModuleHttpCounter".Trim('0')
        $ModuleHttpCounter++
    }

    $session | Set-HttpSession `
        -BaseAddress $BaseAddress `
        -DefaultRequestHeaders $DefaultRequestHeaders `
        -MaxResponseContentBufferSize $MaxResponseContentBufferSize
        -Timeout $Timeout

    $ModuleHttpSession += $session

    $session
}
<#

.DESCRIPTION
Changes settings on an existing HttpSession.

#>
Function Set-HttpSession {
    param (
        [string]$Name,
        [int]$Order,
        [string]$BaseAddress,
        [hashtable]$DefaultRequestHeaders,
        [long]$MaxResponseContentBufferSize,
        [timespan]$Timeout,
        [switch]$PassThru
    )
    process {
        [HttpSession]$session = $_

        if ($Name) {
            $session.Name = $Name
        }
        
        if ($Order) {
            $session.Order = $Order
        }

        if ($BaseAddress) {
            $session.HttpClient.BaseAddress = $BaseAddress
        }
        
        if ($DefaultRequestHeaders) {
            $DefaultRequestHeaders.Keys | ForEach-Object {
                if ($session.HttpClient.DefaultRequestHeaders.Contains($_)) {
                    $session.HttpClient.DefaultRequestHeaders[$_] = $DefaultRequestHeaders[$_]
                } else {
                    $session.HttpClient.DefaultRequestHeaders.Add($_, $DefaultRequestHeaders[$_])
                }
            }
        }

        if ($MaxResponseContentBufferSize) { 
            $session.HttpClient.MaxResponseContentBufferSize = $MaxResponseContentBufferSize
        }

        if ($Timeout) {
            $session.HttpClient.Timeout = $Timeout
        }

        if ($PassThru) {
            $session
        }
    }
}
<#

.DESCRIPTION
Invokes a web request using the given session.

#>
Function Invoke-HttpSession {
    param (
        [Parameter(Mandatory)][HttpSession]$Session,
        [string]$Uri,
        [string]$Method = 'GET',
        [object]$Body,
        [string]$BodyType = 'application/json',
        [System.Text.Encoding]$DefaultEncoding = [System.Text.Encoding]::UTF8
    )

    if ($Body -and $Method -eq 'GET') { $Method = 'POST' }
    
    $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method.ToUpper()), $Uri)

    $req.Content = if ($Body) {
        $str = if ($Body -is [string]) {
            [System.Net.Http.StringContent]::new($Body, $DefaultEncoding, $BodyType)
        } elseif ($Body -is [IO.Stream]) {
            [System.Net.Http.StreamContent]::new($Body)
        } elseif ($Body -is [System.Net.Http.HttpContent]) {
            $Body
        } else {
            $str = $Body | ConvertTo-JsonObject | ConvertTo-Json -Compress -Depth 10

            [System.Net.Http.StringContent]::new($str, $DefaultEncoding, $BodyType)
        }
    }

    $responseTask = $Session.HttpClient.SendAsync($req)

    while (-not $responseTask.AsyncWaitHandle.WaitOne(200)) { }
    
    # TODO: Handle exception in a nicer way than throw? (Includes DNS and Socket issues)

    $response = $responseTask.GetAwaiter().GetResult()

    $body = if ($response.Content) {
        $bodyBuffer = [IO.MemoryStream]::new($response.Content.Headers.ContentLength)

        $response.Content.ReadAsStream().CopyTo($bodyBuffer)

        $response | Add-Member -NotePropertyName 'BodyBuffer' -NotePropertyValue $bodyBuffer

        $bodyBuffer.Position = 0

        if ($response.Content.Headers.ContentType.MediaType -like 'application/json' -or    
            $response.Content.Headers.ContentType.MediaType -like 'text/*')
        {
            [System.Text.Encoding]$enc = $DefaultEncoding
            
            if ($response.Content.Headers.ContentType.CharSet) {
                try {
                    $enc = [System.Text.Encoding]::GetEncoding($enc)
                } catch {
                    $_
                }
            }

            $bodyString = [IO.StreamReader]::new($bodyBuffer, $enc, $false).ReadToEnd()

            if ($response.Content.Headers.ContentType.MediaType -like 'application/json') {
                $bodyString | ConvertFrom-Json
            } else {
                $bodyString
            }
        }
    }

    $response | Add-Member -NotePropertyName 'Body' -NotePropertyValue $body -PassThru
}
