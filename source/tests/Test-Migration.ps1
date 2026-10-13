param([Parameter(Mandatory=$true)][string]$BaseMount,[Parameter(Mandatory=$true)][string]$Package6,[Parameter(Mandatory=$true)][string]$Package7)
$ErrorActionPreference='Stop';$project=Split-Path -Parent $PSScriptRoot
. "$project\runtime\RadioManager.ps1"
$mount=Join-Path $PSScriptRoot ('migration-'+[Guid]::NewGuid().ToString('N')+'\Mount');New-Item -ItemType Directory -Path $mount -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $BaseMount 'media') -Destination $mount -Recurse
$original=@{};foreach($file in Get-ChildItem "$mount\media" -File -Recurse){$original[$file.FullName.Substring($mount.Length+1)]=Radio-Hash $file.FullName}
& "$Package6\Install.ps1" -GameFolder $mount
Move-Item -LiteralPath "$mount\fh2-custom-radio-backup" -Destination "$mount\sadboys-worldwide-backup"
$bank6='media\audio\fmodanthem\durango\HZ2_MX_Radio_06_Tracks.bank';$six=Radio-Hash (Safe-Target $mount $bank6)
& "$project\runtime\Install.ps1" -GameFolder $mount -PackageFolder $Package7
$root=Join-Path $mount 'fh2-radio-studio';$state=Read-RadioRegistry $root
if(@($state.stations).Count -ne 2 -or ($state.stations | Where-Object slot -eq 6).source -ne 'Imported'){throw 'Earlier station was not imported'}
if((Radio-Hash (Safe-Target $mount $bank6)) -ne $six){throw 'Migration changed existing station audio'}
if(Test-Path -LiteralPath "$mount\sadboys-worldwide-backup"){throw 'Old backup was not archived after migration'}
$slot7='media\audio\fmodanthem\durango\HZ2_MX_Radio_07_Tracks.bank';$before=[IO.File]::ReadAllBytes((Safe-Target $mount $slot7))
try{[IO.File]::WriteAllText((Safe-Target $mount $slot7),'External edit');$refused=$false;try{& "$project\runtime\Uninstall.ps1" -GameFolder $mount -Slot 6}catch{$refused=$true};if(-not $refused){throw 'An external edit was overwritten'};if((Radio-Hash (Safe-Target $mount $bank6)) -ne $six){throw 'Refused restore changed another file'}}finally{[IO.File]::WriteAllBytes((Safe-Target $mount $slot7),$before)}
& "$project\runtime\Uninstall.ps1" -GameFolder $mount -Slot 6
$state=Read-RadioRegistry $root;if(@($state.stations).Count -ne 1 -or $state.stations[0].slot -ne 7){throw 'Restoring imported station removed another station'}
& "$project\runtime\Uninstall.ps1" -GameFolder $mount -All
foreach($path in $original.Keys){if((Radio-Hash (Safe-Target $mount $path)) -ne $original[$path]){throw "Migration final restore differs: $path"}}
Write-Host 'PASS: earlier-install migration, preservation, external-edit refusal, individual and all-station restore'
$unmanaged=Join-Path $PSScriptRoot ('unmanaged-'+[Guid]::NewGuid().ToString('N')+'\Mount');New-Item -ItemType Directory -Path $unmanaged -Force | Out-Null;Copy-Item -LiteralPath (Join-Path $BaseMount 'media') -Destination $unmanaged -Recurse
& "$Package6\Install.ps1" -GameFolder $unmanaged
Move-Item -LiteralPath "$unmanaged\fh2-custom-radio-backup" -Destination "$unmanaged\unmanaged-original-reference"
$six=Radio-Hash (Safe-Target $unmanaged $bank6)
$json=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$project\runtime\Scan-Stations.ps1" -GameFolder $unmanaged
if($LASTEXITCODE){throw 'Unmanaged scan failed'};$scan=$json -join "`n" | ConvertFrom-Json;$detected=$scan.stations | Where-Object slot -eq 6
if($detected.status -ne 'Detected custom' -or $detected.canRestore){throw 'Unmanaged station detection incorrect'}
& "$project\runtime\Install.ps1" -GameFolder $unmanaged -PackageFolder $Package7
& "$project\runtime\Uninstall.ps1" -GameFolder $unmanaged -Slot 7
if((Radio-Hash (Safe-Target $unmanaged $bank6)) -ne $six){throw 'Unmanaged station audio changed'}
if((Get-StationLabel (Read-ZipEntry "$unmanaged\media\stripped\stringtables\EN.zip" 'MyProfile.str') 2463) -ne (Radio-Json "$Package6\station.json").name){throw 'Unmanaged station label changed'}
Write-Host 'PASS: unmanaged custom detection and preservation across another slot install/restore'
