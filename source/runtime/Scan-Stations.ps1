param([Parameter(Mandatory=$true)][string]$GameFolder,[string]$NodePath='node.exe')
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
. "$PSScriptRoot\RadioManager.ps1"
$mount=Resolve-Mount $GameFolder
$root=Join-Path $mount 'fh2-radio-studio';$registry=Read-RadioRegistry $root
$legacy=@();if(-not $registry){$legacy=@(Get-LegacyRadio $mount)}
$english=$null;foreach($locale in 'EN','GB'){$file=Join-Path $mount "media\stripped\stringtables\$locale.zip";if(Test-Path -LiteralPath $file){$english=Read-ZipEntry $file 'MyProfile.str';break}}
$rows=@();$text=[IO.File]::ReadAllText((Join-Path $mount 'media\audio\RadioInfo_EN.xml'))
foreach($definition in Get-RadioDefinitions){
    $name=$definition.stockLabel;if($english){$value=Get-StationLabel $english $definition.labelKey;if($value){$name=$value}}
    $path=Join-Path $mount ('media\audio\fmodanthem\durango\HZ2_MX_Radio_0'+$definition.slot+'_Tracks.bank');$max=0;$mode=0
    if(Test-Path -LiteralPath $path){$stream=[IO.File]::OpenRead($path);try{$length=[Math]::Min(10*1024*1024,$stream.Length);$b=New-Object byte[] $length;$read=0;while($read -lt $length){$got=$stream.Read($b,$read,$length-$read);if(-not $got){break};$read+=$got};$ascii=[Text.Encoding]::ASCII.GetString($b);$offset=$ascii.IndexOf('FSB5',[StringComparison]::Ordinal);if($offset -ge 0 -and $offset+60 -le $read){$max=[BitConverter]::ToUInt32($b,$offset+8);$mode=[BitConverter]::ToUInt32($b,$offset+24)}}finally{$stream.Dispose()}}
    $fragment=[regex]::Match($text,(Station-Pattern $definition.slot)).Value;$music=[regex]::Match($fragment,'<Playlist Type="FreeroamTracks"[^>]*>([\s\S]*?)</Playlist>').Groups[1].Value;$tracks=[regex]::Matches($music,'<Entry\b').Count
    $managed=@();if($registry){$managed=@($registry.stations | Where-Object slot -eq $definition.slot)}
    $earlier=@($legacy | Where-Object slot -eq $definition.slot);$status='Original';$restorable=$false
    if($managed.Count){$name=$managed[0].name;$status=$managed[0].source;$restorable=$true}
    elseif($earlier.Count){$status='Earlier install';$restorable=$true}
    elseif($name -cne $definition.stockLabel -or $mode -eq 2 -or ($max -gt 0 -and $tracks -ne $max)){$status='Detected custom'}
    $rows+=[pscustomobject]@{slot=$definition.slot;name=$definition.name;currentName=$name;labelKey=$definition.labelKey;icon=$definition.icon;maxTracks=$max;available=($max -gt 0 -and $max -le 100);status=$status;canRestore=$restorable;trackCount=$tracks}
}
[Console]::WriteLine((ConvertTo-Json -InputObject @{mount=$mount;stations=$rows;pendingRecovery=(Test-Path -LiteralPath (Join-Path $root 'transaction.json'))} -Depth 6))
