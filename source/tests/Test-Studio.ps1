param([Parameter(Mandatory=$true)][string]$GameFolder,[Parameter(Mandatory=$true)][string]$StockFixture,[Parameter(Mandatory=$true)][string]$AudioFile,[Parameter(Mandatory=$true)][string]$LogoPath,[Parameter(Mandatory=$true)][string]$Texconv)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. "$root\runtime\RadioManager.ps1"
$fixture=Join-Path $PSScriptRoot ('fixture-'+[Guid]::NewGuid().ToString('N'))
$mount=Join-Path $fixture 'Mount';New-Item -ItemType Directory -Path "$mount\media\audio","$mount\media\ui\textures","$mount\media\stripped\stringtables","$mount\media\audio\fmodanthem\durango" -Force | Out-Null
Get-ChildItem -LiteralPath "$StockFixture\media\audio" -Filter 'RadioInfo_*.xml' -File | Copy-Item -Destination "$mount\media\audio"
Copy-Item -LiteralPath "$StockFixture\media\ui\textures\Anthem.zip" -Destination "$mount\media\ui\textures"
Get-ChildItem -LiteralPath "$StockFixture\media\stripped\stringtables" -Filter '*.zip' -File | Copy-Item -Destination "$mount\media\stripped\stringtables"
function Strings([byte[]]$b){$s=[BitConverter]::ToUInt32($b,20);$n=[BitConverter]::ToUInt32($b,$s+4);$pool=$s+8+$n*6+6;$map=@{};for($i=0;$i -lt $n;$i++){$p=$s+8+$i*6;$key=[BitConverter]::ToUInt16($b,$p);$off=$pool+2*[BitConverter]::ToUInt32($b,$p+2);$end=$off;while($b[$end] -or $b[$end+1]){$end+=2};$map[$key]=[Text.Encoding]::Unicode.GetString($b,$off,$end-$off)};return $map}
$definitions=Get-Content -LiteralPath "$root\tools\stations.json" -Raw | ConvertFrom-Json
$title='Track & "quotes" '+[char]0x00a3+' '+[char]0x65e5+[char]0x672c+[char]0x8a9e
foreach($definition in $definitions){
 $slot=$definition.slot;$output=Join-Path $PSScriptRoot ('built-slot'+$slot+'-'+[Guid]::NewGuid().ToString('N'))
 $project=@{schema=1;slot=$slot;gameFolder=$GameFolder;stationName="Fixture & Slot $slot";logoPath=$LogoPath;outputFolder=$output;normalise=($slot -eq 7);tools=@{node='node.exe';ffmpeg='ffmpeg.exe';ffprobe='ffprobe.exe';texconv=$Texconv};tracks=@(@{file=$AudioFile;title=$title;artist='Fixture <Artist>'},@{file=$AudioFile;title='Second';artist='Fixture'})}
 $projectFile=Join-Path $PSScriptRoot "test-project-$slot.json";[IO.File]::WriteAllText($projectFile,($project | ConvertTo-Json -Depth 7),(New-Object Text.UTF8Encoding($false)))
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$root\Build-Radio.ps1" -ProjectFile $projectFile *> (Join-Path $PSScriptRoot "build-$slot.log")
 if($LASTEXITCODE){throw "Build slot $slot failed. See build-$slot.log"}
 $tracks=Get-Content -LiteralPath "$output\tracks.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 if($tracks[0].title -cne $title -or $tracks[0].artist -cne 'Fixture <Artist>'){throw 'Metadata was damaged'}
 foreach($file in Get-ChildItem -LiteralPath "$output\media" -File -Recurse){$relative=$file.FullName.Substring($output.Length+1);$target=Safe-Target $mount $relative;[IO.File]::WriteAllText($target,'Fixture original '+$file.Name)}
 & "$output\Install.ps1" -GameFolder $mount *> (Join-Path $PSScriptRoot "install-$slot.log")
 $manager=Join-Path $mount 'fh2-radio-studio';$backup=Join-Path $manager 'originals';$records=(Radio-Json (Join-Path $manager 'registry.json')).files
 foreach($record in $records){
  $current=Safe-Target $mount $record.path;$original=Safe-Target $backup $record.path
  if((Get-FileHash -LiteralPath $current).Hash -ne $record.installed_sha256){throw 'Installed hash differs'}
  if($record.path -match 'RadioInfo_'){$a=[IO.File]::ReadAllText($original);$b=[IO.File]::ReadAllText($current);$pattern='<RadioStation\b[^>]*Number="'+$slot+'"[^>]*>[\s\S]*?</RadioStation>';if([regex]::Replace($a,$pattern,'') -cne [regex]::Replace($b,$pattern,'')){throw 'Unrelated station changed'};$s=([xml]([regex]::Match($b,$pattern).Value)).DocumentElement;if($s.SelectNodes('Playlist[@Type="FreeroamTracks"]/Entry').Count -ne 2){throw 'Wrong playlist length'}}
  if($record.path -match 'stringtables'){$a=Strings (Read-ZipEntry $original 'MyProfile.str');$b=Strings (Read-ZipEntry $current 'MyProfile.str');foreach($key in $a.Keys){if($key -eq $definition.labelKey){if($b[$key] -cne $project.stationName){throw 'Wrong station label'}}elseif($a[$key] -cne $b[$key]){throw 'Unrelated label changed'}}}
 }
 $archive=Join-Path $backup 'media\ui\textures\Anthem.zip';$zip=[IO.Compression.ZipFile]::OpenRead($archive)
 try{foreach($entry in $zip.Entries){if($entry.FullName -eq "HUD/HUD_RadioIcon_$($definition.icon).swatchbin"){continue};$a=Read-ZipEntry $archive $entry.FullName;$b=Read-ZipEntry "$mount\media\ui\textures\Anthem.zip" $entry.FullName;$hash=[Security.Cryptography.SHA256]::Create();try{if([Convert]::ToBase64String($hash.ComputeHash($a)) -ne [Convert]::ToBase64String($hash.ComputeHash($b))){throw 'Unrelated texture changed'}}finally{$hash.Dispose()}}}finally{$zip.Dispose()}
 & "$root\runtime\Uninstall.ps1" -GameFolder $mount -Slot $slot *> (Join-Path $PSScriptRoot "restore-$slot.log")
 foreach($record in $records){if((Get-FileHash -LiteralPath (Safe-Target $mount $record.path)).Hash -ne $record.original_sha256){throw 'Restore differs'}}
 Write-Host "PASS: slot $slot build, artwork, metadata, unrelated data preservation and exact restore"
}
Write-Host 'PASS: all seven station slots'
