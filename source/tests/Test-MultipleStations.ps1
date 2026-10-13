param([Parameter(Mandatory=$true)][string]$StockFixture,[Parameter(Mandatory=$true)][string]$GameFolder,[Parameter(Mandatory=$true)][string]$Package6,[Parameter(Mandatory=$true)][string]$Package7)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
. "$project\runtime\RadioManager.ps1"
$mount=Join-Path $PSScriptRoot ('multiple-'+[Guid]::NewGuid().ToString('N')+'\Mount')
New-Item -ItemType Directory -Path "$mount\media\audio","$mount\media\ui\textures","$mount\media\stripped\stringtables","$mount\media\audio\fmodanthem\durango" -Force | Out-Null
Get-ChildItem "$StockFixture\media\audio" -Filter 'RadioInfo_*.xml' -File | Copy-Item -Destination "$mount\media\audio"
Copy-Item -LiteralPath "$StockFixture\media\ui\textures\Anthem.zip" -Destination "$mount\media\ui\textures"
Get-ChildItem "$StockFixture\media\stripped\stringtables" -Filter '*.zip' -File | Copy-Item -Destination "$mount\media\stripped\stringtables"
$game=Resolve-Mount $GameFolder
foreach($slot in 1..7){$name="HZ2_MX_Radio_0$($slot)_Tracks.bank";$source=Join-Path $game "media\audio\fmodanthem\durango\$name";if($slot -eq 6){$old=Join-Path $game "sadboys-worldwide-backup\media\audio\fmodanthem\durango\$name";if(Test-Path -LiteralPath $old){$source=$old}};$stream=[IO.File]::OpenRead($source);try{$b=New-Object byte[] ([Math]::Min(100000,$stream.Length));$stream.Read($b,0,$b.Length) | Out-Null;[IO.File]::WriteAllBytes((Join-Path $mount "media\audio\fmodanthem\durango\$name"),$b)}finally{$stream.Dispose()}}
foreach($package in $Package6,$Package7){foreach($file in Get-ChildItem "$package\media" -File -Recurse){$relative=$file.FullName.Substring($package.Length+1);$target=Safe-Target $mount $relative;if(-not(Test-Path -LiteralPath $target)){[IO.File]::WriteAllText($target,'Fixture original '+$file.Name)}}}
$original=@{};foreach($file in Get-ChildItem "$mount\media" -Recurse -File){$original[$file.FullName.Substring($mount.Length+1)]=Radio-Hash $file.FullName}
function Assert-Slots([int[]]$Ids){$state=Read-RadioRegistry (Join-Path $mount 'fh2-radio-studio');$actual=@($state.stations | ForEach-Object slot | Sort-Object);$wanted=@($Ids | Sort-Object);if(($actual -join ',') -ne ($wanted -join ',')){throw "Wrong managed slots: $($actual -join ',')"};Verify-RadioRegistry $mount (Join-Path $mount 'fh2-radio-studio') $state}
& "$project\runtime\Install.ps1" -GameFolder $mount -PackageFolder $Package6
Assert-Slots @(6)
$updated=Join-Path $PSScriptRoot ('updated-seven-'+[Guid]::NewGuid().ToString('N'));Copy-Item -LiteralPath $Package7 -Destination $updated -Recurse
$info=Radio-Json (Join-Path $updated 'station.json');$info.name='Updated Seven';Write-RadioJson (Join-Path $updated 'station.json') $info
$checks=Radio-Json (Join-Path $updated 'checksums.json');($checks | Where-Object path -eq 'station.json').sha256=Radio-Hash (Join-Path $updated 'station.json');Write-RadioJson (Join-Path $updated 'checksums.json') $checks
& "$project\runtime\Install.ps1" -GameFolder $mount -PackageFolder $updated
Assert-Slots @(6,7)
$state=Read-RadioRegistry (Join-Path $mount 'fh2-radio-studio');$bank6=$state.files | Where-Object path -Match '_Radio_06_Tracks';$sixHash=Radio-Hash (Safe-Target $mount $bank6.path)
$label6=Get-StationLabel (Read-ZipEntry "$mount\media\stripped\stringtables\EN.zip" 'MyProfile.str') 2463;$label7=Get-StationLabel (Read-ZipEntry "$mount\media\stripped\stringtables\EN.zip" 'MyProfile.str') 3487
if($label6 -ne (Radio-Json "$Package6\station.json").name -or $label7 -ne 'Updated Seven'){throw 'Both station names were not preserved'}
& "$project\runtime\Install.ps1" -GameFolder $mount -PackageFolder $Package7
Assert-Slots @(6,7)
if((Radio-Hash (Safe-Target $mount $bank6.path)) -ne $sixHash){throw 'Updating slot 7 changed slot 6 audio'}
& "$project\runtime\Uninstall.ps1" -GameFolder $mount -Slot 7
Assert-Slots @(6)
if((Radio-Hash (Safe-Target $mount $bank6.path)) -ne $sixHash){throw 'Restoring slot 7 changed slot 6 audio'}
if((Get-StationLabel (Read-ZipEntry "$mount\media\stripped\stringtables\EN.zip" 'MyProfile.str') 2463) -ne $label6){throw 'Restoring slot 7 changed slot 6 name'}
& "$project\runtime\Uninstall.ps1" -GameFolder $mount -Slot 6
Assert-Slots @()
foreach($path in $original.Keys){if((Radio-Hash (Safe-Target $mount $path)) -ne $original[$path]){throw "Final original restore differs: $path"}}
Write-Host 'PASS: two installs, same-slot update, independent restore, shared labels and exact final restore'
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'multiple-test-mount.txt'),$mount)
