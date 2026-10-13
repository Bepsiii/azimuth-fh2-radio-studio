$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'radio-icon.png'))
$images=@()
try {
    foreach($size in @(16,24,32,48,64,128,256)) {
        $bitmap=New-Object Drawing.Bitmap($size,$size)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {$graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;$graphics.DrawImage($source,0,0,$size,$size)} finally {$graphics.Dispose()}
        $stream=New-Object IO.MemoryStream;$dib=New-Object IO.BinaryWriter($stream)
        $maskStride=[int]([Math]::Ceiling($size/32.0)*4);$pixels=New-Object byte[] ($size*$size*4);$mask=New-Object byte[] ($maskStride*$size)
        $data=$bitmap.LockBits((New-Object Drawing.Rectangle(0,0,$size,$size)),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            for($y=0;$y -lt $size;$y++) {
                [Runtime.InteropServices.Marshal]::Copy([IntPtr]::Add($data.Scan0,$y*$data.Stride),$pixels,($size-1-$y)*$size*4,$size*4)
            }
        } finally {$bitmap.UnlockBits($data);$bitmap.Dispose()}
        for($y=0;$y -lt $size;$y++){for($x=0;$x -lt $size;$x++){if($pixels[($y*$size+$x)*4+3] -eq 0){$index=$y*$maskStride+[int][Math]::Floor($x/8);$mask[$index]=$mask[$index] -bor (128 -shr ($x%8))}}}
        try {
            $dib.Write([uint32]40);$dib.Write([int]$size);$dib.Write([int]($size*2));$dib.Write([uint16]1);$dib.Write([uint16]32);$dib.Write([uint32]0);$dib.Write([uint32]($pixels.Length+$mask.Length));$dib.Write([int]0);$dib.Write([int]0);$dib.Write([uint32]0);$dib.Write([uint32]0);$dib.Write([byte[]]$pixels);$dib.Write([byte[]]$mask);$images+=,@{size=$size;bytes=$stream.ToArray()}
        } finally {$dib.Dispose()}

    }
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'RadioStudio.ico'));$writer=New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$images.Count);$offset=6+16*$images.Count
        foreach($entry in $images){$dimension=if($entry.size -eq 256){0}else{$entry.size};$writer.Write([byte]$dimension);$writer.Write([byte]$dimension);$writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]$entry.bytes.Length);$writer.Write([uint32]$offset);$offset+=$entry.bytes.Length}
        foreach($entry in $images){$writer.Write([byte[]]$entry.bytes)}
    } finally {$writer.Dispose()}
} finally {$source.Dispose()}
