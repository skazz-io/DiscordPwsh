# Import-Module BitSequence

# $SystemBootTime = [DateTime]::UtcNow.AddMilliseconds(-([Environment]::TickCount))

New-Variable -Scope Script -Force -Name DiscordSnowflakeEpoch -Value 1420070400000
New-Variable -Scope Script -Force -Name DiscordSnowflakeWorkerId -Value ($PID -band 31)
New-Variable -Scope Script -Force -Name DiscordSnowflakeProcessId -Value (($PID -shr 5) -band 31)
New-Variable -Scope Script -Force -Name DiscordSnowflakePropertyMap -Value ([ordered]@{ 
    Timestamp = 42
    WorkerId = 5
    ProcessId = 5
    Increment = 12
})
New-Variable -Scope Global -Force -Name DiscordSnowflakeIncrement -Value 0

<#

#>
Class DiscordSnowflake {
    [DateTime]$Timestamp
    [byte]$WorkerId
    [byte]$ProcessId
    [ushort]$Increment
}
<#

#>
Function New-DiscordSnowflake {
    param (
        [DateTime]$Timestamp = [DateTime]::UtcNow,
        [byte]$WorkerId = $DiscordSnowflakeWorkerId,
        [byte]$ProcessId = $DiscordSnowflakeProcessId,
        [ushort]$Increment = ($Global:DiscordSnowflakeIncrement += 1),
        [switch]$Expand
    )

    $snowflake = [DiscordSnowflake]@{
        Timestamp = $Timestamp
        WorkerId = $WorkerId
        ProcessId = $ProcessId
        Increment = $Increment
    }

    if ($Expand) {
        $snowflake
    } else {
        $snowflake | Compress-DiscordSnowflake
    }
}
<#

#>
Function Expand-DiscordSnowflake {
    process {
        $result = $_ | Expand-Bits -PropertyMap $DiscordSnowflakePropertyMap -AsHashTable

        $result.Timestamp = ([DateTimeOffset]::FromUnixTimeMilliseconds($result.Timestamp + $DiscordSnowflakeEpoch)).DateTime

        [DiscordSnowflake]$result
    }
}
<#

#>
Function Compress-DiscordSnowflake {
    param (
        [DiscordSnowflake]$InputObject
    )
    process {
        $snowflake = [DiscordSnowflake]$_

        @{
            Timestamp = [DateTimeOffset]::new($snowflake.Timestamp).ToUnixTimeMilliseconds() - $DiscordSnowflakeEpoch
            WorkerId = $snowflake.WorkerId
            ProcessId = $snowflake.ProcessId
            Increment = $snowflake.Increment
        } | Compress-Bits -PropertyMap $DiscordSnowflakePropertyMap -Truncate
    }
}