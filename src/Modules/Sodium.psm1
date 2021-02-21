$pssodium = Get-Module -Name PSSodium -ListAvailable

if (-not $pssodium) {
    Write-Warning 'PSSodium not installed, installing for current user.'

    Install-Module -Name PSSodium -Scope CurrentUser
    
    $pssodium = Get-Module -Name PSSodium -ListAvailable
}

$platform = 'win-x64'

if ($IsLinux) { $platform = 'linux-x64' }
elseif ($IsOSX) { $platform = 'osx-x64' }
elseif ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { $platform = 'win-x86' }

$sodium = [IO.Path]::Combine($pssodium.ModuleBase, $platform, 'Sodium.Core.dll')

Add-Type -Path $sodium
