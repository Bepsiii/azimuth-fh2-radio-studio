$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not ('FH2Radio.ForzaZip' -as [type])) { Add-Type -Path "$PSScriptRoot\ForzaZip.cs" }
function Resolve-Mount([string]$GameFolder) {
    $resolved = (Resolve-Path -LiteralPath $GameFolder).Path
    if (Test-Path -LiteralPath (Join-Path $resolved 'Mount\media\audio')) { $resolved = Join-Path $resolved 'Mount' }
    if (-not (Test-Path -LiteralPath (Join-Path $resolved 'media\audio\RadioInfo_EN.xml'))) { throw 'Choose the FH2 game folder containing Mount, or Mount itself.' }
    return $resolved
}
function Safe-Target([string]$Mount, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) { throw 'Invalid relative path' }
    $target = [IO.Path]::GetFullPath((Join-Path $Mount $Relative))
    if (-not $target.StartsWith($Mount.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Path outside game folder' }
    return $target
}
function Patch-StationLabel([byte[]]$Bytes, [string]$StationName, [int]$LabelKey) {
    if ([Text.Encoding]::ASCII.GetString($Bytes,0,4) -ne 'LSB2') { throw 'Unsupported string table format' }
    $chunks = [BitConverter]::ToUInt32($Bytes,16)
    if ($chunks -ne 4) { throw 'Unsupported string table layout' }
    $start = [BitConverter]::ToUInt32($Bytes,20)
    $end = [BitConverter]::ToUInt32($Bytes,24)
    $count = [BitConverter]::ToUInt32($Bytes,$start+4)
    $pool = $start + 8 + $count*6 + 6
    if ($start -ne 36 -or $pool -ge $end -or $end -gt $Bytes.Length) { throw 'Invalid string table bounds' }
    $record = -1
    for ($i=0; $i -lt $count; $i++) {
        $p = $start+8+$i*6
        if ([BitConverter]::ToUInt16($Bytes,$p) -eq $LabelKey) { if ($record -ge 0) {throw 'Duplicate station label'}; $record=$p }
    }
    # Some shipped fallback/localisation tables have no radio labels.
    if ($record -lt 0) { return $null }
    $old = $pool + 2*[BitConverter]::ToUInt32($Bytes,$record+2)
    if ($old -lt $pool -or $old -ge $end) { throw 'Invalid station label offset' }
    $oldEnd=$old
    while($oldEnd+1 -lt $end -and ($Bytes[$oldEnd] -ne 0 -or $Bytes[$oldEnd+1] -ne 0)) {$oldEnd+=2}
    if($oldEnd+1 -ge $end){throw 'Unterminated station label'}
    $oldEnd+=2
    $label = [Text.Encoding]::Unicode.GetBytes("$StationName`0")
    $delta=$label.Length-($oldEnd-$old)
    $result = New-Object byte[] ($Bytes.Length+$delta)
    [Array]::Copy($Bytes,0,$result,0,$old)
    [Array]::Copy($label,0,$result,$old,$label.Length)
    [Array]::Copy($Bytes,$oldEnd,$result,$old+$label.Length,$Bytes.Length-$oldEnd)
    # Preserve ordered string offsets, including the terminal 0xFFFF record.
    for($i=0;$i -le $count;$i++) {
        $p=$start+8+$i*6+2;$offset=[BitConverter]::ToUInt32($Bytes,$p)
        if($pool+2*$offset -gt $old){[BitConverter]::GetBytes([uint32]($offset+$delta/2)).CopyTo($result,$p)}
    }
    [BitConverter]::GetBytes([uint32]([BitConverter]::ToUInt32($Bytes,$start)+$delta)).CopyTo($result,$start)
    for ($i=1;$i -lt $chunks;$i++) { $p=20+4*$i; [BitConverter]::GetBytes([uint32]([BitConverter]::ToUInt32($Bytes,$p)+$delta)).CopyTo($result,$p) }
    return ,$result
}
function Update-ZipEntry([string]$Archive, [string]$EntryName, [byte[]]$Bytes) {
    [FH2Radio.ForzaZip]::Replace($Archive,$EntryName,$Bytes)
}
function Read-ZipEntry([string]$Archive, [string]$EntryName) {
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $entry=$zip.GetEntry($EntryName); if(-not $entry){throw "Archive entry missing: $EntryName"}
        $stream=$entry.Open();$memory=New-Object IO.MemoryStream
        try {$stream.CopyTo($memory);return ,$memory.ToArray()} finally {$stream.Dispose();$memory.Dispose()}
    } finally {$zip.Dispose()}
}
