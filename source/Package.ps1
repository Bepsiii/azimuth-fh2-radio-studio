$ErrorActionPreference='Stop'
$files=@('FH2RadioStudio.exe','Build-App.ps1','Build-Radio.ps1','README.md','LICENSE','Package.ps1','.gitignore','ui\RadioStudio.cs','ui\Build-Icon.ps1','ui\RadioStudio.ico','ui\radio-icon.png','tools\stations.json','tools\discover.cjs','tools\build-radio.cjs','tools\bank.cjs','tools\RadioTexture.cs','tools\ninja-bc7-map.bin','tools\bin\texconv.exe','runtime\ForzaZip.cs','runtime\StationTools.ps1','runtime\Install.ps1','runtime\Uninstall.ps1','runtime\RadioManager.ps1','runtime\Scan-Stations.ps1','third-party\DirectXTex-LICENSE.txt','third-party\README.md','tests\Test-Studio.ps1','tests\Test-MultipleStations.ps1','tests\Test-Migration.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$destination=Join-Path (Split-Path -Parent $PSScriptRoot) 'FH2-Radio-Studio-0.3.1.zip'
if(Test-Path -LiteralPath $destination){throw 'Archive already exists. Choose a new version or preserve/remove the previous local archive explicitly.'}
$zip=[IO.Compression.ZipFile]::Open($destination,[IO.Compression.ZipArchiveMode]::Create)
try{foreach($relative in $files){$source=Join-Path $PSScriptRoot $relative;if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Missing file: $relative"};[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$source,('FH2-Radio-Studio-0.3.1/'+$relative.Replace('\','/')),[IO.Compression.CompressionLevel]::Optimal) | Out-Null}}finally{$zip.Dispose()}
Write-Host "Packaged $destination"
