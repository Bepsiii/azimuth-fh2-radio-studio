. "$PSScriptRoot\StationTools.ps1"
function Get-RadioDefinitions {
    return @(
        [pscustomobject]@{slot=1;name='Horizon Pulse';labelKey=5535;icon='Pulse';stockLabel='Horizon Pulse'},
        [pscustomobject]@{slot=2;name='Horizon Bass Arena';labelKey=6559;icon='Bass';stockLabel='Horizon Bass Arena'},
        [pscustomobject]@{slot=3;name='Horizon XS';labelKey=7583;icon='XS';stockLabel='Horizon XS'},
        [pscustomobject]@{slot=4;name='Radio Levante';labelKey=415;icon='Levante';stockLabel='Levante FM'},
        [pscustomobject]@{slot=5;name='Hospital Records';labelKey=1439;icon='Hospital';stockLabel='Hospital Records Radio'},
        [pscustomobject]@{slot=6;name='Ninja Tune';labelKey=2463;icon='Ninja_Tune';stockLabel='Ninja Tune Radio'},
        [pscustomobject]@{slot=7;name='Innovative Leisure';labelKey=3487;icon='Innovative_Leisure';stockLabel='Innovative Leisure Radio'}
    )
}
function Get-RadioDefinition([int]$Slot){$value=Get-RadioDefinitions | Where-Object slot -eq $Slot;if(-not $value){throw 'Unsupported station slot.'};return $value}
function Get-StationLabel([byte[]]$Bytes,[int]$Key){
    if($Bytes.Length -lt 36 -or [Text.Encoding]::ASCII.GetString($Bytes,0,4) -ne 'LSB2'){throw 'Unsupported station label table.'}
    $start=[BitConverter]::ToUInt32($Bytes,20);$end=[BitConverter]::ToUInt32($Bytes,24);$count=[BitConverter]::ToUInt32($Bytes,$start+4);$pool=$start+8+$count*6+6
    if($pool -gt $end -or $end -gt $Bytes.Length){throw 'Invalid station label bounds.'}
    for($i=0;$i -lt $count;$i++){$p=$start+8+$i*6;if([BitConverter]::ToUInt16($Bytes,$p) -ne $Key){continue};$offset=$pool+2*[BitConverter]::ToUInt32($Bytes,$p+2);if($offset -lt $pool -or $offset -ge $end){throw 'Invalid station label offset.'};$finish=$offset;while($finish+1 -lt $end -and ($Bytes[$finish] -or $Bytes[$finish+1])){$finish+=2};if($finish+1 -ge $end){throw 'Unterminated station label.'};return [Text.Encoding]::Unicode.GetString($Bytes,$offset,$finish-$offset)}
    return $null
}
function Radio-Hash([string]$File){return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash}
function Radio-Json([string]$File){return Get-Content -LiteralPath $File -Raw -Encoding UTF8 | ConvertFrom-Json}
function Seal-RadioCapsule([string]$Capsule){
    $checks=@(Get-ChildItem -LiteralPath $Capsule -File -Recurse | Where-Object Name -ne 'hashes.json' | ForEach-Object {[pscustomobject]@{path=$_.FullName.Substring($Capsule.Length+1);sha256=(Radio-Hash $_.FullName)}})
    Write-RadioJson (Join-Path $Capsule 'hashes.json') $checks
    return Radio-Hash (Join-Path $Capsule 'hashes.json')
}
function Write-RadioJson([string]$File,$Value){
    $temporary=$File+'.new-'+[Guid]::NewGuid().ToString('N')
    if($Value -is [Array]){$items=@(foreach($item in $Value){ConvertTo-Json -InputObject $item -Depth 12 -Compress});$text='['+($items -join ',')+']'}else{$text=ConvertTo-Json -InputObject $Value -Depth 12}
    [IO.File]::WriteAllText($temporary,$text,(New-Object Text.UTF8Encoding($false)))
    if(Test-Path -LiteralPath $File){$previous=$File+'.previous-'+[Guid]::NewGuid().ToString('N');[IO.File]::Replace($temporary,$File,$previous)}else{[IO.File]::Move($temporary,$File)}
}
function Station-Pattern([int]$Slot){return '<RadioStation\b[^>]*Number="'+$Slot+'"[^>]*>[\s\S]*?</RadioStation>'}
function Assert-RadioPath([string]$Path){
    if($Path -match '^media\\audio\\RadioInfo_[A-Z]{2}\.xml$' -or $Path -eq 'media\ui\textures\Anthem.zip' -or $Path -match '^media\\stripped\\stringtables\\[^\\]+\.zip$' -or $Path -match '^media\\audio\\fmodanthem\\durango\\HZ2_MX_Radio_0[1-7]_(Tracks|DJ|Stingers)(_[A-Z]{2})?\.bank$'){return}
    throw "Unexpected radio file: $Path"
}
function Read-RadioRegistry([string]$Root){
    $file=Join-Path $Root 'registry.json';if(-not(Test-Path -LiteralPath $file)){return $null};$state=Radio-Json $file
    if($state.schema -ne 1){throw 'Unsupported station registry version.'}
    foreach($record in $state.files){Assert-RadioPath $record.path;Safe-Target $Root $record.original | Out-Null}
    $seen=@{};foreach($station in $state.stations){Get-RadioDefinition $station.slot | Out-Null;if($seen.ContainsKey([int]$station.slot)){throw 'Duplicate registry slot.'};$seen[[int]$station.slot]=$true;Safe-Target $Root $station.capsule | Out-Null}
    return $state
}
function Get-LegacyRadio([string]$Mount){
    $found=@();foreach($folder in 'sadboys-worldwide-backup','fh2-custom-radio-backup'){$file=Join-Path $Mount "$folder\restore.json";if(Test-Path -LiteralPath $file){$records=Radio-Json $file;$slots=@($records | ForEach-Object {if($_.path -match 'HZ2_MX_Radio_0([1-7])_Tracks\.bank$'){[int]$Matches[1]}} | Select-Object -Unique);if($slots.Count -ne 1){throw 'Cannot identify the slot in an earlier radio backup.'};$found+=[pscustomobject]@{folder=$folder;slot=$slots[0];records=@($records)}}}
    return $found
}
function Shared-RadioFiles([string]$Mount){
    $paths=@();foreach($file in Get-ChildItem -LiteralPath (Join-Path $Mount 'media\audio') -Filter 'RadioInfo_*.xml' -File){$paths+='media\audio\'+$file.Name}
    $paths+='media\ui\textures\Anthem.zip'
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $Mount 'media\stripped\stringtables') -Filter '*.zip' -File){$zip=[IO.Compression.ZipFile]::OpenRead($file.FullName);try{if($zip.GetEntry('MyProfile.str')){$paths+='media\stripped\stringtables\'+$file.Name}}finally{$zip.Dispose()}}
    return $paths
}
function Capture-RadioCapsule([string]$Mount,[string]$Root,[int]$Slot){
    $definition=Get-RadioDefinition $Slot;$relative='capsules\'+[Guid]::NewGuid().ToString('N');$capsule=Safe-Target $Root $relative
    New-Item -ItemType Directory -Path (Join-Path $capsule 'patches') -Force | Out-Null
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $Mount 'media\audio') -Filter 'RadioInfo_*.xml' -File){$fragment=[regex]::Matches([IO.File]::ReadAllText($file.FullName),(Station-Pattern $Slot));if($fragment.Count -ne 1){throw 'Expected one existing station fragment.'};[IO.File]::WriteAllText((Join-Path $capsule ('patches\'+$file.Name.Replace('RadioInfo_','RadioStation_'))),$fragment[0].Value,(New-Object Text.UTF8Encoding($false)))}
    $labels=@{};foreach($file in Get-ChildItem -LiteralPath (Join-Path $Mount 'media\stripped\stringtables') -Filter '*.zip' -File){$zip=[IO.Compression.ZipFile]::OpenRead($file.FullName);try{$has=$null -ne $zip.GetEntry('MyProfile.str')}finally{$zip.Dispose()};if(-not $has){continue};$text=Get-StationLabel (Read-ZipEntry $file.FullName 'MyProfile.str') $definition.labelKey;if($null -ne $text){$labels[$file.Name]=$text}}
    Write-RadioJson (Join-Path $capsule 'labels.json') $labels
    [IO.File]::WriteAllBytes((Join-Path $capsule 'patches\icon.swatchbin'),(Read-ZipEntry (Join-Path $Mount 'media\ui\textures\Anthem.zip') "HUD/HUD_RadioIcon_$($definition.icon).swatchbin"))
    $display=if($labels.ContainsKey('EN.zip')){$labels['EN.zip']}else{$definition.name}
    $fragment=[IO.File]::ReadAllText((Join-Path $capsule 'patches\RadioStation_EN.xml'));$music=[regex]::Match($fragment,'<Playlist Type="FreeroamTracks"[^>]*>([\s\S]*?)</Playlist>').Groups[1].Value
    return [pscustomobject]@{slot=$Slot;name=$display;capsule=$relative;capsule_sha256=(Seal-RadioCapsule $capsule);tracks=[regex]::Matches($music,'<Entry\b').Count;source='Imported';installedUtc=[DateTime]::UtcNow.ToString('o')}
}
function Add-RadioOriginal([string]$Mount,[string]$Root,$State,[string]$Relative,[string]$Source=$null,[string]$Expected=$null){
    Assert-RadioPath $Relative;if(@($State.files | Where-Object path -eq $Relative).Count){return}
    $target=Safe-Target $Mount $Relative;if(-not $Source){$Source=$target};$original='originals\'+$Relative;$saved=Safe-Target $Root $original
    New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
    if($Expected -and (Radio-Hash $Source) -ne $Expected){throw "Original backup integrity failed: $Relative"}
    Copy-Item -LiteralPath $Source -Destination $saved -Force
    $State.files+= [pscustomobject]@{path=$Relative;original=$original;original_sha256=(Radio-Hash $saved);installed_sha256=(Radio-Hash $target)}
}
function Initialize-RadioRegistry([string]$Mount,[string]$Root){
    Write-Host '[PROGRESS] Importing existing radio backups'
    $legacy=@(Get-LegacyRadio $Mount);if($legacy.Count -gt 1){throw 'Multiple earlier backup folders need manual review before migration.'}
    if(Test-Path -LiteralPath $Root){throw 'An incomplete manager directory exists. Preserve it and review before retrying.'}
    $state=[pscustomobject]@{schema=1;files=@();stations=@()}
    New-Item -ItemType Directory -Path $Root | Out-Null
    try{
        if($legacy.Count){
            $old=$legacy[0];$sourceRoot=Join-Path $Mount $old.folder
            foreach($record in $old.records){Assert-RadioPath $record.path;if((Radio-Hash (Safe-Target $Mount $record.path)) -ne $record.installed_sha256){throw "Earlier installation changed: $($record.path). Migration stopped."};Add-RadioOriginal $Mount $Root $state $record.path (Safe-Target $sourceRoot $record.path) $record.original_sha256}
            $state.stations+=Capture-RadioCapsule $Mount $Root $old.slot
        }
        foreach($relative in Shared-RadioFiles $Mount){Add-RadioOriginal $Mount $Root $state $relative}
        Write-RadioJson (Join-Path $Root 'registry.json') $state
        if($legacy.Count){$source=Join-Path $Mount $legacy[0].folder;$archive=Join-Path $Mount ($legacy[0].folder+'-imported-'+[Guid]::NewGuid().ToString('N'));Move-Item -LiteralPath $source -Destination $archive}
        return $state
    }catch{if(-not(Test-Path -LiteralPath (Join-Path $Root 'registry.json'))){$failed=Join-Path $Mount ('fh2-radio-studio-initialise-failed-'+[Guid]::NewGuid().ToString('N'));Move-Item -LiteralPath $Root -Destination $failed};throw}
}
function Verify-RadioRegistry([string]$Mount,[string]$Root,$State){
    foreach($record in $State.files){if((Radio-Hash (Safe-Target $Mount $record.path)) -ne $record.installed_sha256){throw "Radio file changed outside the manager: $($record.path). No files overwritten."};if((Radio-Hash (Safe-Target $Root $record.original)) -ne $record.original_sha256){throw "Original backup integrity failed: $($record.path)"}}
    foreach($station in $State.stations){$capsule=Safe-Target $Root $station.capsule;$file=Join-Path $capsule 'hashes.json';if((Radio-Hash $file) -ne $station.capsule_sha256){throw 'Stored station manifest damaged.'};foreach($check in (Radio-Json $file)){if((Radio-Hash (Safe-Target $capsule $check.path)) -ne $check.sha256){throw 'Stored station data changed.'}}}
}
function Recover-RadioTransaction([string]$Mount,[string]$Root,[switch]$OwnFailure){
    $file=Join-Path $Root 'transaction.json';if(-not(Test-Path -LiteralPath $file)){return}
    $journal=Radio-Json $file;$directory=Safe-Target $Root $journal.directory
    foreach($record in $journal.files){Assert-RadioPath $record.path;$current=Radio-Hash (Safe-Target $Mount $record.path);if(-not $OwnFailure -and $current -ne $record.before_sha256 -and $current -ne $record.after_sha256){throw 'An interrupted transaction contains externally changed files. Review its recovery journal.'};if((Radio-Hash (Safe-Target $directory ('before\'+$record.path))) -ne $record.before_sha256){throw 'Transaction recovery backup damaged.'}}
    foreach($record in $journal.files){Copy-Item -LiteralPath (Safe-Target $directory ('before\'+$record.path)) -Destination (Safe-Target $Mount $record.path) -Force}
    $previous=Radio-Json (Join-Path $directory 'registry-before.json');Write-RadioJson (Join-Path $Root 'registry.json') $previous
    Move-Item -LiteralPath $file -Destination (Join-Path $directory 'recovered.json')
    Write-Host 'Recovered an interrupted radio operation; the previous installed state was restored.'
}
function Commit-RadioFiles([string]$Mount,[string]$Root,$State,$Prepared){
    Write-Host '[PROGRESS] Saving rollback files'
    $relative='transactions\'+[Guid]::NewGuid().ToString('N');$directory=Safe-Target $Root $relative
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'registry.json') -Destination (Join-Path $directory 'registry-before.json')
    $records=@();foreach($item in $Prepared){$target=Safe-Target $Mount $item.path;$saved=Safe-Target $directory ('before\'+$item.path);New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null;Copy-Item -LiteralPath $target -Destination $saved;$records+=[pscustomobject]@{path=$item.path;before_sha256=(Radio-Hash $saved);after_sha256=(Radio-Hash $item.source)}}
    $journal=[pscustomobject]@{schema=1;directory=$relative;files=$records};Write-RadioJson (Join-Path $Root 'transaction.json') $journal
    try{
        Write-Host '[PROGRESS] Installing radio files'
        foreach($item in $Prepared){Copy-Item -LiteralPath $item.source -Destination (Safe-Target $Mount $item.path) -Force}
        foreach($record in $records){if((Radio-Hash (Safe-Target $Mount $record.path)) -ne $record.after_sha256){throw 'Installed radio hash verification failed.'};($State.files | Where-Object path -eq $record.path).installed_sha256=$record.after_sha256}
        Write-RadioJson (Join-Path $Root 'registry.json') $State
        Move-Item -LiteralPath (Join-Path $Root 'transaction.json') -Destination (Join-Path $directory 'committed.json')
    }catch{$failure=$_;Recover-RadioTransaction $Mount $Root -OwnFailure;throw $failure}
    # Once committed, originals remain in the registry; large temporary rollback copies are no longer needed.
    foreach($record in $records){$saved=Safe-Target $directory ('before\'+$record.path);Remove-Item -LiteralPath $saved -ErrorAction SilentlyContinue}
}
function Prepare-SharedRadio([string]$Root,$State,[string]$Staging){
    $prepared=@();foreach($record in $State.files){
        if($record.path -match '\.bank$'){continue};$original=Safe-Target $Root $record.original;$source=Safe-Target $Staging $record.path
        New-Item -ItemType Directory -Path (Split-Path -Parent $source) -Force | Out-Null;Copy-Item -LiteralPath $original -Destination $source
        if($record.path -match 'RadioInfo_([A-Z]{2})\.xml$'){
            $locale=$Matches[1];$text=[IO.File]::ReadAllText($source)
            foreach($station in $State.stations){$patch=Join-Path (Safe-Target $Root $station.capsule) "patches\RadioStation_$locale.xml";if(-not(Test-Path -LiteralPath $patch)){throw 'Stored station fragment missing.'};$replacement=[IO.File]::ReadAllText($patch);$pattern=Station-Pattern $station.slot;if([regex]::Matches($text,$pattern).Count -ne 1){throw 'Expected one original station fragment.'};$text=[regex]::Replace($text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match)$replacement})}
            if(@($State.stations).Count){[IO.File]::WriteAllText($source,$text,(New-Object Text.UTF8Encoding($false)))}
        }elseif($record.path -eq 'media\ui\textures\Anthem.zip'){
            foreach($station in $State.stations){$icon=Join-Path (Safe-Target $Root $station.capsule) 'patches\icon.swatchbin';if(Test-Path -LiteralPath $icon){$definition=Get-RadioDefinition $station.slot;Update-ZipEntry $source "HUD/HUD_RadioIcon_$($definition.icon).swatchbin" ([IO.File]::ReadAllBytes($icon))}}
        }elseif($record.path -match 'stringtables'){
            $table=Read-ZipEntry $original 'MyProfile.str';$changed=$false
            foreach($station in $State.stations){$definition=Get-RadioDefinition $station.slot;$labelsFile=Join-Path (Safe-Target $Root $station.capsule) 'labels.json';$label=$station.name;if(Test-Path -LiteralPath $labelsFile){$labels=Radio-Json $labelsFile;$property=$labels.PSObject.Properties[[IO.Path]::GetFileName($source)];if($property){$label=[string]$property.Value}};$patched=Patch-StationLabel $table $label $definition.labelKey;if($null -ne $patched){$table=$patched;$changed=$true}}
            if($changed){Update-ZipEntry $source 'MyProfile.str' $table}
        }
        $prepared+=[pscustomobject]@{path=$record.path;source=$source}
    };return $prepared
}
function Install-ManagedRadio([string]$Mount,[string]$PackageFolder){
    Write-Host '[PROGRESS] Checking station package'
    $package=(Resolve-Path -LiteralPath $PackageFolder).Path;$info=Radio-Json (Join-Path $package 'station.json');$definition=Get-RadioDefinition $info.slot
    if($info.labelKey -ne $definition.labelKey -or $info.icon -ne $definition.icon -or [string]::IsNullOrWhiteSpace($info.name) -or $info.name.Length -gt 80){throw 'Invalid station package definition.'}
    [Xml.XmlConvert]::VerifyXmlChars([string]$info.name) | Out-Null
    $checks=Radio-Json (Join-Path $package 'checksums.json');foreach($check in $checks){if((Radio-Hash (Safe-Target $package $check.path)) -ne $check.sha256){throw "Package integrity failed: $($check.path)"}}
    $id=('{0:D2}' -f [int]$info.slot);$banks=@();foreach($file in Get-ChildItem -LiteralPath (Join-Path $package 'media') -File -Recurse){$relative=$file.FullName.Substring($package.Length+1);if($relative -notmatch ('^media\\audio\\fmodanthem\\durango\\HZ2_MX_Radio_'+$id+'_(Tracks|DJ|Stingers)(_[A-Z]{2})?\.bank$')){throw 'Package contains files outside its station slot.'};if(@($checks | Where-Object path -eq $relative).Count -ne 1){throw 'Audio file not covered by package checksums.'};$banks+=[pscustomobject]@{path=$relative;source=$file.FullName}}
    if(-not @($banks | Where-Object path -Match ('_Radio_'+$id+'_Tracks\.bank$')).Count){throw 'Music bank missing.'}
    $root=Join-Path $Mount 'fh2-radio-studio';Recover-RadioTransaction $Mount $root;$state=Read-RadioRegistry $root;if(-not $state){$state=Initialize-RadioRegistry $Mount $root};Write-Host '[PROGRESS] Verifying installed files and original backups';Verify-RadioRegistry $Mount $root $state
    $capsuleRelative='capsules\'+[Guid]::NewGuid().ToString('N');$capsule=Safe-Target $root $capsuleRelative;New-Item -ItemType Directory -Path (Join-Path $capsule 'patches') -Force | Out-Null
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $package 'patches') -Filter 'RadioStation_*.xml' -File){$relative=$file.FullName.Substring($package.Length+1);if(@($checks | Where-Object path -eq $relative).Count -ne 1){throw 'Station fragment not covered by checksums.'};Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $capsule 'patches')}
    $icon=Join-Path $package "patches\HUD_RadioIcon_$($definition.icon).swatchbin";$previous=@($state.stations | Where-Object slot -eq $info.slot)
    if(Test-Path -LiteralPath $icon){$relative=$icon.Substring($package.Length+1);if(@($checks | Where-Object path -eq $relative).Count -ne 1){throw 'Artwork not covered by checksums.'};Copy-Item -LiteralPath $icon -Destination (Join-Path $capsule 'patches\icon.swatchbin')}
    elseif($previous.Count){$oldIcon=Join-Path (Safe-Target $root $previous[0].capsule) 'patches\icon.swatchbin';if(Test-Path -LiteralPath $oldIcon){Copy-Item -LiteralPath $oldIcon -Destination (Join-Path $capsule 'patches\icon.swatchbin')}}
    $tracks=Radio-Json (Join-Path $package 'tracks.json');$state.stations=@($state.stations | Where-Object slot -ne $info.slot)+@([pscustomobject]@{slot=[int]$info.slot;name=[string]$info.name;capsule=$capsuleRelative;capsule_sha256=(Seal-RadioCapsule $capsule);tracks=@($tracks).Count;source='Managed';installedUtc=[DateTime]::UtcNow.ToString('o')})
    foreach($bank in $banks){Add-RadioOriginal $Mount $root $state $bank.path}
    $staging=Join-Path $root ('staging-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $staging | Out-Null
    try{Write-Host '[PROGRESS] Preparing all active stations';$shared=@(Prepare-SharedRadio $root $state $staging);Commit-RadioFiles $Mount $root $state (@($shared)+@($banks))}finally{if((Split-Path -Parent $staging) -eq $root -and (Split-Path -Leaf $staging) -match '^staging-[a-f0-9]{32}$'){Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue}}
    Write-Host "Installed $($info.name) in slot $($info.slot). Other stations preserved."
}
function Restore-ManagedRadio([string]$Mount,[int]$Slot,[bool]$All=$false){
    Write-Host '[PROGRESS] Verifying station restore backups'
    $root=Join-Path $Mount 'fh2-radio-studio';Recover-RadioTransaction $Mount $root;$state=Read-RadioRegistry $root;if(-not $state){$state=Initialize-RadioRegistry $Mount $root};Verify-RadioRegistry $Mount $root $state
    $removed=@($state.stations | Where-Object {$All -or $_.slot -eq $Slot});if(-not $removed.Count){throw 'This station has no managed original backup.'}
    $ids=@($removed | ForEach-Object slot);$state.stations=@($state.stations | Where-Object {$ids -notcontains $_.slot});$banks=@()
    foreach($record in $state.files){if($record.path -match 'HZ2_MX_Radio_0([1-7])_' -and $ids -contains [int]$Matches[1]){$banks+=[pscustomobject]@{path=$record.path;source=(Safe-Target $root $record.original)}}}
    $staging=Join-Path $root ('staging-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $staging | Out-Null
    try{$shared=@(Prepare-SharedRadio $root $state $staging);Commit-RadioFiles $Mount $root $state (@($shared)+@($banks))}finally{if((Split-Path -Parent $staging) -eq $root -and (Split-Path -Leaf $staging) -match '^staging-[a-f0-9]{32}$'){Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue}}
    Write-Host "Restored $($removed.Count) station(s). Remaining custom stations preserved."
}
