<#

#>
Function Get-DiscordChannelMessages (
    [Parameter(Mandatory)][string]$Authorization,
    [Parameter(Mandatory)][string]$ChannelId,
    [Parameter(Mandatory,ParameterSetName='around')][DateTime]$Around,
    [Parameter(Mandatory,ParameterSetName='before')][DateTime]$Before,
    [Parameter(Mandatory,ParameterSetName='after')][DateTime]$After,
    [byte]$Limit = 50
) {
    $opt = "/channels/$ChannelId/messages"

    $ts = switch ($PSCmdlet.ParameterSetName) {
        'around' { $opt += "?around="; $Around }
        'before' { $opt += "?before="; $Before }
        'after' { $opt += "?after="; $After }
    }

    $offset = [DateTimeOffset]::new($ts)

    $opt += (($offset.ToUnixTimeMilliseconds() - 1420070400000) -shl 22)

    if ($Limit -ne 50) {
        $opt += "&limit=$Limit"
    }

    Invoke-DiscordApi -Option $opt
}
