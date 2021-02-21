New-Variable -Scope Script -Force -Name DiscordApiUrl -Value 'https://discord.com/api/v8'
New-Variable -Scope Script -Force -Name DiscordApiAgent -Value 'DiscordPwsh (https://github.com/skazz-io/DiscordPwsh, v1.0.0)'
New-Variable -Scope Script -Force -Name DiscordApiCounter -Value 0

<#

.DESCRIPTION

#>
Function Invoke-DiscordApi {
    param (
        [HttpSession]$Session,
        [string]$Uri,
        [string]$Method = 'GET',
        [object]$Body
    )
    
    [HttpSession]$ActiveSession = $Session

    if (-not $ActiveSession) {
        $ActiveSession = Get-DiscordApiSession | Select-Object -First 1
        
        if (-not $ActiveSession) {
            throw 'No existing Discord HttpSession, use New-DiscordApiSession'
        }
    }
    
    [System.Net.Http.HttpResponseMessage]$response = Invoke-HttpSession -Session $ActiveSession.HttpSession `
        -Uri:$Uri -Method:$Method -Body:$Body
    
    if ($response.StatusCode -eq [System.Net.HttpStatusCode]::TooManyRequests) {
        Start-Sleep -Seconds ([double]$response.Headers['X-RateLimit-Reset-After'])

        Invoke-DiscordApi @PSBoundParameters
    } else {
        $response
    }

}
<#

.PARAMETER Authorization
The authorization string for the HTTP header (including BOT or BEARER).

#>
Function New-DiscordApiSession ([Parameter(Mandatory)][string]$Authorization) {
    New-HttpSession `
        -Name "Discord$DiscordApiCounter".Trim('0') `
        -Order ($DiscordApiCounter += 1) `
        -BaseAddress $DiscordApiUrl `
        -DefaultRequestHeaders @{
            Authorization = $Authorization
            UserAgent = $DiscordApiAgent
        }
}
<#

#>
Function Get-DiscordApiSession {
    Get-HttpSession | Where-Object { $_.Name -like 'Discord*' } | Sort-Object -Descending Order
}
<#

#>
Function Remove-DiscordApiSession {
    process {
        $_ | Remove-HttpSession
    }
}