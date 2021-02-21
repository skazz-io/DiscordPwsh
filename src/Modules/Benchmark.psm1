<#

#>
Function Measure-CommandBenchmark ([Parameter(Mandatory)][ScriptBlock]$ScriptBlock, $RunSeconds = 10) {
    $totalSeconds = 0

    $runs = while ($totalSeconds -lt $RunSeconds) {
        $duration = Measure-Command $ScriptBlock

        $totalSeconds += $duration.TotalSeconds

        $duration
    }

    $stats = $runs | Measure-Object -Sum -Average -Min -Max -Property TotalMilliseconds

    $stats | Add-Member -NotePropertyName 'RateSecond' -NotePropertyValue ($stats.Count / $totalSeconds)

    $stats
}
