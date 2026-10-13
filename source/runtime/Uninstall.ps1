param([Parameter(Mandatory=$true)][string]$GameFolder,[int]$Slot=0,[switch]$All)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\RadioManager.ps1"
if(Get-Process azimuth -ErrorAction SilentlyContinue){throw 'Close Azimuth before changing game files.'}
if(-not $All -and $Slot -eq 0){$info=Join-Path $PSScriptRoot 'station.json';if(Test-Path -LiteralPath $info){$Slot=(Radio-Json $info).slot}else{throw 'Select a station slot to restore.'}}
$mount=Resolve-Mount $GameFolder;$lockFile=Join-Path $mount 'fh2-radio-studio.lock'
try{$lock=[IO.File]::Open($lockFile,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'Another station manager operation is active.'}
try{Restore-ManagedRadio $mount $Slot ([bool]$All)}finally{$lock.Dispose()}
