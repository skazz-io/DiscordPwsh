<#

.DESCRIPTION Converts types such as DateTime and Enums into strings/integers for friendlier conversion to Json.

.PARAMETER DateTimeFormat
Supports normal [DateTime] toString formats.

Also supports 'js' for Unix Miliseconds and 'unix' for Unix Seconds, both since 1970 epoch.

.EXAMPLE 

$object | ConvertTo-JsonObject | ConvertTo-Json

#>
Function ConvertTo-JsonObject ($DateTimeFormat = 'js', [switch]$EnumString, [switch]$KeepNull, [switch]$KeepPS) {
    process {
        if ($_ -is [Array]) {
            $_ | ConvertTo-JsonObject @PSBoundParameters
        } elseif ($_ -is [Enum]) {
            if ($EnumString) { $_.ToString() } else { [int]$_ }
        } elseif ($_ -is [DateTime]) {
            if ($DateTimeFormat -eq 'js') {
                [DateTimeOffset]::new($_).ToUnixTimeMilliseconds()
            } elseif ($DateTimeFormat -eq 'unix') {
                [DateTimeOffset]::new($_).ToUnixTimeSeconds()
            } else {
                $_.ToString($DateTimeFormat)
            }
        } elseif ($_ -is [String] -or $_.GetType().IsPrimitive) {
            $_
        } elseif ($_ -is [Object]) {
            $ht = [ordered]@{}

            $_.PSObject.Properties | ? { ($KeepNull -or $null -ne $_.Value) -and ($KeepPS -or $_.Name -cnotlike 'PS*') } | % {
                $ht[$_.Name] = $_.Value | ConvertTo-JsonObject @PSBoundParameters
            }

            [pscustomobject]$ht
        } else {
            $_
        }
    }
}
<#

.DESCRIPTION Attempts to convert types such as DateTime back into objects.

.PARAMETER DateTimeFormat
Supports normal [DateTime] toString formats.

Also supports 'js' for Unix Miliseconds and 'unix' for Unix Seconds, both since 1970 epoch.

.EXAMPLE

$json | ConvertFrom-Json | ConvertFrom-JsonObject

#>
Function ConvertFrom-JsonObject ($DateTimeFormat = 'js') {
    process {
        if ($_ -is [Array]) {
            $_ | ConvertFrom-JsonObject @PSBoundParameters
        } elseif ($_ -is [String]) {

            if ($DateTimeFormat -eq 'js') {
                [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$_)
            } elseif ($DateTimeFormat -eq 'unix') {
                [DateTimeOffset]::FromUnixTimeSeconds([int64]$_)
            } else {
                [DateTime]$dt = [DateTime]::MinValue

                if ([DateTime]::TryParseExact($_, $DateTimeFormat, $null, [ref]$dt)) {
                    $dt
                } else {
                    $_
                }
            }
        } elseif ($_ -is [Object]) {
            $ht = [ordered]@{}

            $_.PSObject.Properties | ? { ($KeepNull -or $null -ne $_.Value) -and ($KeepPS -or $_.Name -cnotlike 'PS*') } | % {
                $ht[$_.Name] = $_.Value | ConvertFrom-JsonObject @PSBoundParameters
            }

            [pscustomobject]$ht
        } else {
            $_
        }
    }
}