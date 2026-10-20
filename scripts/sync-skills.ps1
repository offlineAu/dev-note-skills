<#
Copies every skill in this repo's skills/ folder into every Codex home on this
machine, so the skills are present whichever account Codex is using.

Homes covered:
  - ~/.codex (or $env:CODEX_HOME)
  - each Orca account: %APPDATA%\orca\codex-accounts\<id>\home
  - the Orca shared runtime: %APPDATA%\orca\codex-runtime-home\home

Run again after switching or adding an account. Existing copies of these skills
are replaced; other skills in each home are left alone.

Usage:  powershell -File scripts\sync-skills.ps1 [-Skill dev-note,mirror-3-term] [-WhatIf]
#>
[CmdletBinding(SupportsShouldProcess)]
param([string[]]$Skill)

$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo 'skills'

$homes = @()
$homes += if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$orca = Join-Path $env:APPDATA 'orca'
$accounts = Join-Path $orca 'codex-accounts'
if (Test-Path $accounts) {
    $homes += Get-ChildItem $accounts -Directory | ForEach-Object { Join-Path $_.FullName 'home' }
}
$homes += Join-Path $orca 'codex-runtime-home\home'
$homes = $homes | Where-Object { Test-Path $_ } | Select-Object -Unique

$skills = Get-ChildItem $source -Directory | Where-Object { -not $Skill -or $Skill -contains $_.Name }

foreach ($h in $homes) {
    $dest = Join-Path $h 'skills'
    New-Item -ItemType Directory -Force $dest | Out-Null
    foreach ($s in $skills) {
        $target = Join-Path $dest $s.Name
        if ($PSCmdlet.ShouldProcess($target, "install $($s.Name)")) {
            if (Test-Path $target) { Remove-Item $target -Recurse -Force }
            Copy-Item $s.FullName $target -Recurse
            Write-Host "installed $($s.Name) -> $target"
        }
    }
}
