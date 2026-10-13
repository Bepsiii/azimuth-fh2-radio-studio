param([Parameter(Mandatory=$true)][string]$ProjectFile,[string]$WorkFolder)
$ErrorActionPreference='Stop'
$project=Get-Content -LiteralPath $ProjectFile -Raw -Encoding UTF8 | ConvertFrom-Json
if($project.schema -ne 1){throw 'Unsupported project version.'}
$StationName=[string]$project.stationName
if([string]::IsNullOrWhiteSpace($StationName) -or $StationName.Length -gt 80 -or $StationName -match '[\x00-\x1f]'){throw 'Station name must contain 1-80 printable characters.'}
[Xml.XmlConvert]::VerifyXmlChars($StationName) | Out-Null
. "$PSScriptRoot\runtime\StationTools.ps1"
$mount=Resolve-Mount ([string]$project.gameFolder)
$definition=@(Get-Content -LiteralPath "$PSScriptRoot\tools\stations.json" -Raw | ConvertFrom-Json | ForEach-Object {$_} | Where-Object slot -eq $project.slot)
if($definition.Count -ne 1){throw 'Select a supported station slot (1-7).'}
$station=$definition[0]
function Tool([string]$value,[string]$fallback){if([string]::IsNullOrWhiteSpace($value)){$value=$fallback};return (Get-Command $value -ErrorAction Stop).Source}
$node=Tool $project.tools.node 'node.exe';$ffmpeg=Tool $project.tools.ffmpeg 'ffmpeg.exe';$ffprobe=Tool $project.tools.ffprobe 'ffprobe.exe'
$discovery=& $node "$PSScriptRoot\tools\discover.cjs" $mount
if($LASTEXITCODE){throw 'Unable to inspect game stations.'}
$available=($discovery | ConvertFrom-Json).stations | Where-Object slot -eq $station.slot
$inputs=@($project.tracks)
if(-not $available.available -or $inputs.Count -lt 1 -or $inputs.Count -gt $available.maxTracks){throw "This station supports 1-$($available.maxTracks) tracks."}
$output=[IO.Path]::GetFullPath([string]$project.outputFolder)
if(Test-Path -LiteralPath $output){throw 'Choose a new output folder; existing files will not be overwritten.'}
if($output.StartsWith($mount.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or $output -eq $mount){throw 'Build outside the game folder.'}
$logo=$null;$texconv=$null
if($project.logoPath){$logo=(Resolve-Path -LiteralPath ([string]$project.logoPath)).Path;$texconv=Tool $project.tools.texconv 'texconv.exe'}
foreach($track in $inputs){
    if(-not (Test-Path -LiteralPath $track.file -PathType Leaf)){throw "Audio file missing: $($track.file)"}
    foreach($value in @($track.title,$track.artist)){if([string]$value -match '[\x00-\x1f]' -or ([string]$value).Length -gt 240){throw 'Title/artist must be at most 240 printable characters.'};[Xml.XmlConvert]::VerifyXmlChars([string]$value) | Out-Null}
}
$work=Join-Path ([IO.Path]::GetTempPath()) ('fh2-radio-build-'+[Guid]::NewGuid().ToString('N'))
if($WorkFolder){
    $work=[IO.Path]::GetFullPath($WorkFolder)
    if((Split-Path -Parent $work) -ne ([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path -Leaf $work) -notmatch '^fh2-radio-build-[a-f0-9]{32}$' -or (Test-Path -LiteralPath $work)){throw 'Invalid temporary build directory.'}
}
New-Item -ItemType Directory -Path $work,$output,(Join-Path $output 'patches') -Force | Out-Null
try {
    $tracks=@();$index=0
    foreach($inputTrack in $inputs){
        $index++;Write-Output "[PROGRESS] $index/$($inputs.Count) Converting audio"
        $file=(Resolve-Path -LiteralPath ([string]$inputTrack.file)).Path
        $probe=& $ffprobe -v error -show_entries 'format=duration:format_tags=title,artist,album_artist' -of json $file
        if($LASTEXITCODE){throw "Cannot read audio: $file"}
        $meta=($probe -join "`n") | ConvertFrom-Json
        $duration=[double]$meta.format.duration
        if([double]::IsNaN($duration) -or [double]::IsInfinity($duration) -or $duration -lt 5 -or $duration -gt 3600){throw 'Tracks must be between five seconds and one hour long.'}
        $title=[string]$inputTrack.title;if([string]::IsNullOrWhiteSpace($title)){$title=$meta.format.tags.title};if(-not $title){$title=[IO.Path]::GetFileNameWithoutExtension($file)}
        $artist=[string]$inputTrack.artist;if([string]::IsNullOrWhiteSpace($artist)){$artist=$meta.format.tags.artist};if(-not $artist){$artist=$meta.format.tags.album_artist};if(-not $artist){$artist='Unknown artist'}
        [Xml.XmlConvert]::VerifyXmlChars([string]$title) | Out-Null;[Xml.XmlConvert]::VerifyXmlChars([string]$artist) | Out-Null
        $wav=('{0:D2}.wav' -f $index)
        $convert=@('-hide_banner','-loglevel','error','-nostdin','-i',$file,'-map','0:a:0','-vn','-ar','48000','-ac','2','-c:a','pcm_s16le','-map_metadata','-1')
        if($project.normalise){$convert+=@('-af','loudnorm=I=-16:TP=-1.5:LRA=11')}
        # Game metadata is written from JSON, avoiding native command-line quoting of arbitrary tags.
        & $ffmpeg @convert (Join-Path $work $wav)
        if($LASTEXITCODE){throw "Audio conversion failed: $file"}
        $tracks+=[pscustomobject]@{number=$index;title=[string]$title;artist=[string]$artist;wav=$wav}
    }
    [IO.File]::WriteAllText((Join-Path $work 'tracks.json'),(ConvertTo-Json -InputObject @($tracks) -Depth 5),(New-Object Text.UTF8Encoding($false)))
    Write-Output '[PROGRESS] Building game audio banks'
    & $node "$PSScriptRoot\tools\build-radio.cjs" (Join-Path $mount 'media') $work $output ([string]$station.slot)
    if($LASTEXITCODE){throw 'Bank construction failed.'}
    Copy-Item -LiteralPath "$PSScriptRoot\runtime\Install.ps1","$PSScriptRoot\runtime\Uninstall.ps1","$PSScriptRoot\runtime\StationTools.ps1","$PSScriptRoot\runtime\ForzaZip.cs","$PSScriptRoot\runtime\RadioManager.ps1" -Destination $output
    [IO.File]::WriteAllText((Join-Path $output 'station.json'),(@{name=$StationName;slot=$station.slot;originalName=$station.name;labelKey=$station.labelKey;icon=$station.icon;schema=1} | ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
    if($logo){
        Write-Output '[PROGRESS] Converting station artwork'
        $entry="HUD/HUD_RadioIcon_$($station.icon).swatchbin"
        $template=Read-ZipEntry (Join-Path $mount 'media\ui\textures\Anthem.zip') $entry
        [IO.File]::WriteAllBytes((Join-Path $work 'template.swatchbin'),$template)
        $height=[BitConverter]::ToUInt16($template,66)
        if($height -notin @(96,104)){throw 'Unsupported artwork height.'}
        & $ffmpeg -hide_banner -loglevel error -nostdin -i $logo -vf "scale=$($height):$($height):force_original_aspect_ratio=decrease:flags=lanczos,pad=196:$($height):(ow-iw)/2:(oh-ih)/2:color=black@0,format=rgba" -frames:v 1 (Join-Path $work 'logo.png')
        if($LASTEXITCODE){throw 'Logo conversion failed.'}
        & $texconv -pmalpha -f BC7_UNORM -m 1 -nologo -y -o $work (Join-Path $work 'logo.png')
        if($LASTEXITCODE){throw 'BC7 encoding failed.'}
        if(-not ('RadioTexture' -as [type])){Add-Type -Path "$PSScriptRoot\tools\RadioTexture.cs"}
        [RadioTexture]::Build((Join-Path $work 'template.swatchbin'),(Join-Path $work 'logo.dds'),"$PSScriptRoot\tools\ninja-bc7-map.bin",(Join-Path $output "patches\HUD_RadioIcon_$($station.icon).swatchbin"))
    }
    $checks=@(Get-ChildItem -LiteralPath (Join-Path $output 'media'),(Join-Path $output 'patches'),(Join-Path $output 'station.json') -File -Recurse | ForEach-Object {[pscustomobject]@{path=$_.FullName.Substring($output.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    [IO.File]::WriteAllText((Join-Path $output 'checksums.json'),(ConvertTo-Json -InputObject $checks -Depth 4),(New-Object Text.UTF8Encoding($false)))
    Write-Output "BUILD COMPLETE: $output"
} finally {
    if((Split-Path -Parent $work) -eq ([IO.Path]::GetTempPath()).TrimEnd('\') -and (Split-Path -Leaf $work) -match '^fh2-radio-build-[a-f0-9]{32}$'){Remove-Item -LiteralPath $work -Recurse -Force}
}
