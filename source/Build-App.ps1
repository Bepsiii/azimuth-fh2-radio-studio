$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /win32icon:"$PSScriptRoot\ui\RadioStudio.ico" /resource:"$PSScriptRoot\ui\RadioStudio.ico",RadioStudio.ico /out:"$PSScriptRoot\FH2RadioStudio.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Core.dll "$PSScriptRoot\ui\RadioStudio.cs"
if($LASTEXITCODE){throw 'UI compilation failed.'}
Write-Host 'Built FH2RadioStudio.exe'
