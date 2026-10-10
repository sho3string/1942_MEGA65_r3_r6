param(
    [Parameter(Position=0)][string]$Zip = '1942.zip',
    [Alias('o')][string]$Out = 'arcade/1942',
    [switch]$NoSortObjects
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$baseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($baseDir)) { $baseDir = (Get-Location).Path }
if (-not [System.IO.Path]::IsPathRooted($Zip)) { $Zip = Join-Path $baseDir $Zip }
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $baseDir $Out }
$Out = [System.IO.Path]::GetFullPath($Out)
Write-Host "Output directory: $Out"
$zipPath = (Resolve-Path -LiteralPath $Zip).Path
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    function Chip([string]$name) {
        $entry = $archive.GetEntry($name)
        if ($null -eq $entry) { throw "Missing ROM in ZIP: $name" }
        $stream = $entry.Open()
        try {
            $mem = [System.IO.MemoryStream]::new()
            try { $stream.CopyTo($mem); return ,$mem.ToArray() }
            finally { $mem.Dispose() }
        } finally { $stream.Dispose() }
    }
    function Join-Chips([object[]]$chunks) {
        $mem = [System.IO.MemoryStream]::new()
        try {
            foreach ($chunk in $chunks) { $mem.Write($chunk,0,$chunk.Length) }
            return ,$mem.ToArray()
        } finally { $mem.Dispose() }
    }
    function Interleave([object[]]$chunks,[int]$lanes) {
        if ($chunks.Count % $lanes) { throw 'Invalid lane count' }
        $mem = [System.IO.MemoryStream]::new()
        try {
            for ($g=0; $g -lt $chunks.Count; $g += $lanes) {
                $len = $chunks[$g].Length
                for ($k=1; $k -lt $lanes; $k++) { if ($chunks[$g+$k].Length -ne $len) { throw 'Lane length mismatch' } }
                for ($i=0; $i -lt $len; $i++) { for ($k=0; $k -lt $lanes; $k++) { $mem.WriteByte($chunks[$g+$k][$i]) } }
            }
            return ,$mem.ToArray()
        } finally { $mem.Dispose() }
    }
    function CRC32([byte[]]$bytes) {
        # Use Int64 for intermediate arithmetic: Windows PowerShell can
        # interpret high-bit CRC32 values as negative signed Int32 values.
        [long]$crc = [long]4294967295
        foreach ($b in $bytes) {
            $crc = $crc -bxor [long]$b
            for ($i=0; $i -lt 8; $i++) {
                if (($crc -band [long]1) -ne 0) {
                    $crc = (($crc -shr 1) -bxor [long]3988292384) -band [long]4294967295
                } else {
                    $crc = ($crc -shr 1) -band [long]4294967295
                }
            }
        }
        return (($crc -bxor [long]4294967295) -band [long]4294967295)
    }
    $main = Join-Chips @((Chip 'srb-03.m3'),(Chip 'srb-04.m4'),(Chip 'srb-05.m5'),(Chip 'srb-06.m6'),(Chip 'srb-06.m6'),(Chip 'srb-07.m7'))
    $sound = Chip 'sr-01.c11'
    $char = Chip 'sr-02.f2'
    if ($char.Length % 2) { throw 'Odd character ROM size' }
    for ($i=0;$i -lt $char.Length;$i+=2) { $t=$char[$i];$char[$i]=$char[$i+1];$char[$i+1]=$t }
    $obj = Interleave @((Chip 'sr-16.n1'),(Chip 'sr-14.l1'),(Chip 'sr-17.n2'),(Chip 'sr-15.l2')) 2
    if (-not $NoSortObjects) {
        $sorted = [byte[]]::new($obj.Length)
        for ($i=0;$i -lt $obj.Length;$i++) {
            $dst = ($i -band (-bnot 0x7c)) -bor (($i -band 0x40) -shr 4) -bor (($i -band 0x3c) -shl 1)
            $sorted[$dst]=$obj[$i]
        }
        $obj=$sorted
    }
    $scr = Interleave @((Chip 'sr-08.a1'),(Chip 'sr-10.a3'),(Chip 'sr-12.a5'),(Chip 'sr-12.a5'),(Chip 'sr-09.a2'),(Chip 'sr-11.a4'),(Chip 'sr-13.a6'),(Chip 'sr-13.a6')) 4
    $prom = Join-Chips @((Chip 'sb-5.e8'),(Chip 'sb-6.e9'),(Chip 'sb-7.e10'),(Chip 'sb-0.f1'),(Chip 'sb-4.d6'),(Chip 'sb-8.k3'),(Chip 'sb-2.d1'),(Chip 'sb-3.d2'),([byte[]]::new(256)),(Chip 'sb-1.k6'))
    $roms = [ordered]@{ '1942_main.rom'=$main; '1942_sound.rom'=$sound; '1942_char.rom'=$char; '1942_obj.rom'=$obj; '1942_scr.rom'=$scr; '1942_prom.rom'=$prom }
    $sizes = @(0x14000,0x4000,0x2000,0x10000,0x10000,0xA00)
    $i=0
    foreach ($name in $roms.Keys) {
        if ($roms[$name].Length -ne $sizes[$i]) { throw "Unexpected size for ${name}: $($roms[$name].Length) expected $($sizes[$i])" }
        $i++
    }
    try {
        [System.IO.Directory]::CreateDirectory($Out) | Out-Null
    } catch {
        throw "Cannot create output directory '$Out'. Check folder permissions or specify -Out with a writable path. $($_.Exception.Message)"
    }
    foreach ($name in $roms.Keys) {
        $bytes = [byte[]]$roms[$name]
        [System.IO.File]::WriteAllBytes((Join-Path $Out $name),$bytes)
        '{0,-20} {1,7} bytes  CRC32 {2:X8}' -f $name,$bytes.Length,(CRC32 $bytes)
    }
    if (-not $NoSortObjects) { 'Object sorting: hvvvvxx' } else { 'Object sorting: none' }
} finally { $archive.Dispose() }
