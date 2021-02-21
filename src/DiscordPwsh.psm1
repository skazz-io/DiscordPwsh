
$ModuleDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    '.\src'
}

Get-ChildItem -Path $ModuleDir -Recurse -Filter *.psm1 -Exclude 'DiscordPwsh.psm1' | ForEach-Object {
    try {
        Import-Module -Force $_.FullName
    } catch {
        $_
    }
}

Get-ChildItem -Path "$ModuleDir\Types" -Recurse -Filter *.ps1 | ForEach-Object {
    try {
        . $_.FullName
    } catch {
        $_
    }
}

Get-ChildItem -Path $ModuleDir -Directory -Exclude 'Types' | Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
    try {
        . $_.FullName
    } catch {
        $_
    }
}
