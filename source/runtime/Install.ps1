param([Parameter(Mandatory=$true)][string]$GameFolder,[string]$PackageFolder=$PSScriptRoot)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\RadioManager.ps1"
if(Get-Process azimuth -ErrorAction SilentlyContinue){throw 'Close Azimuth before changing game files.'}
$mount=Resolve-Mount $GameFolder
$lockFile=Join-Path $mount 'fh2-radio-studio.lock'
try{$lock=[IO.File]::Open($lockFile,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'Another station manager operation is active.'}
try{Install-ManagedRadio $mount $PackageFolder}finally{$lock.Dispose()}
