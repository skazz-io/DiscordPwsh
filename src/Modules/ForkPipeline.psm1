<#

.DESCRIPTION
Forks a single pipeline into alternative pipelines based on conditional scriptblocks.

  /---- a
-|----- b
  \---- c

  
The results of all those pipelines can consolidate back into the normal pipeline.

  /---- a ----\
-|----- b -----| --- d
  \---- c ----/

Or the forks can even fork again.

                /---- d ----\
   /---- a ----|----- e -----|--- h
  /
-|------ b -----------f
  \
   \---- c -----------g

Why instead of a scriptblock with some if statements? Because Pipeline, stupid. =]

So existing pipeline functions dont need to be re-written to not pipeline, or might not be efficent to repeatedly call begin/end blocks.

And then so you do not have to use GetSteppablePipeline yourself.

.PARAMETER Forks


.EXAMPLE 

Get-ChildItem | Invoke-Fork { $_.PSIsContainer },{ & Select Name,LastWriteTime | ConvertTo-Json -Compress },{ -not $_.PSIsContainer },{ & Select Name,Length | ConvertTo-Json -Compress }

.EXAMPLE 

Get-ChildItem | Invoke-Fork `
    { $_.PSIsContainer }, { & Select Name,LastWriteTime },
    { -not $_.PSIsContainer }, { & Select Name,Length }
| ConvertTo-Json

.EXAMPLE 

Get-ChildItem | Invoke-Fork @(
    { $_.PSIsContainer }, { & Select Name,LastWriteTime },
    { -not $_.PSIsContainer }, { & Invoke-Fork { $_.Length -ge 1000 },{& Select Name,Length,LastWriteTime },{ $_.Length -lt 1000 },{& Select Name,Length } }
) | ConvertTo-Json

#>
Function Invoke-Fork {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]$InputObject,
        [Parameter(Position = 0)][ScriptBlock[]]$Forks
    )
    begin {
        if ($Forks.Count % 2 -ne 0) {
            throw 'Must define condition and pipeline pairs.'
        }

        $conditions = @()
        $steppablePipelines = @()

        try {
            for ($i = 0; $i -lt $Forks.Count; $i++) {
                if ($i % 2 -eq 0) {
                    $conditions += $Forks[$i]
                } else {
                    $steppablePipelines += $Forks[$i].GetSteppablePipeline($myInvocation.CommandOrigin)
                }
            }
        
            $steppablePipelines.Begin($PSCmdlet)
        } catch {
            throw
        }
    }
    process
    {
        for ($i = 0; $i -lt $Forks.Count; $i++) {
            try {
                if (& $conditions[$i]) {
                    $steppablePipelines[$i].Process($_)
                }
            } catch {
                
            }
        }
    }
    end
    {
        try {
            $steppablePipelines.End()
        } catch {
            throw
        }
    }
}
