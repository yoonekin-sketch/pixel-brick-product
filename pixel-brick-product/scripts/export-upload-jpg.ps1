#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourcePath,
    [string]$OutputDirectory,
    [int]$Edge = 1254,
    [switch]$Recurse,
    [switch]$AuditOnly,
    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$byteLimit = 2000000
$imageExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.gif', '.webp', '.avif', '.heic')
$exportExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff')
if ($Edge -lt 1) { throw 'Edge must be positive.' }
$sourceItem = Get-Item -LiteralPath $SourcePath
$sourceRoot = if ($sourceItem.PSIsContainer) { $sourceItem.FullName } else { $sourceItem.DirectoryName }
$sourceFiles = if ($sourceItem.PSIsContainer) {
    @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse:$Recurse | Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object FullName)
} else { @($sourceItem) }
if ($sourceFiles.Count -eq 0) { throw 'No supported images found.' }

function Read-ImageInfo([string]$ImagePath) {
    $file = Get-Item -LiteralPath $ImagePath
    $decoded = $null
    try {
        $decoded = [System.Drawing.Image]::FromFile($file.FullName)
        $actualFormat = if ($decoded.RawFormat.Guid -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid) { 'JPEG' }
                        elseif ($decoded.RawFormat.Guid -eq [System.Drawing.Imaging.ImageFormat]::Png.Guid) { 'PNG' }
                        else { $decoded.RawFormat.Guid.ToString() }
        [pscustomobject]@{
            Path = $file.FullName
            Bytes = $file.Length
            Width = $decoded.Width
            Height = $decoded.Height
            Format = $actualFormat
            Valid = ($file.Extension.ToLowerInvariant() -eq '.jpg' -and $actualFormat -eq 'JPEG' -and $file.Length -lt $byteLimit -and $decoded.Width -eq $Edge -and $decoded.Height -eq $Edge)
        }
    } finally { if ($null -ne $decoded) { $decoded.Dispose() } }
}

if ($AuditOnly) {
    $audit = @($sourceFiles | ForEach-Object {
        try { Read-ImageInfo $_.FullName }
        catch { [pscustomobject]@{ Path = $_.FullName; Valid = $false; Error = $_.Exception.Message } }
    })
    $invalid = @($audit | Where-Object { -not $_.Valid })
    [pscustomobject]@{ Total = $audit.Count; InvalidCount = $invalid.Count; MaxBytes = ($audit | Measure-Object Bytes -Maximum).Maximum; Images = $audit } | ConvertTo-Json -Depth 5
    if ($invalid.Count -gt 0) { throw "Upload audit failed: $($invalid.Count) invalid image(s)." }
    return
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { throw 'OutputDirectory is required for export.' }
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd([char[]]'\/')
$sourceRoot = $sourceRoot.TrimEnd([char[]]'\/')
$directorySeparator = [System.IO.Path]::DirectorySeparatorChar
if ($sourceItem.PSIsContainer -and (
    $outputRoot.Equals($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $outputRoot.StartsWith($sourceRoot + $directorySeparator, [System.StringComparison]::OrdinalIgnoreCase) -or
    $sourceRoot.StartsWith($outputRoot + $directorySeparator, [System.StringComparison]::OrdinalIgnoreCase)
)) { throw 'Source and output folders must be separate, non-nested directories.' }

$jobs = @($sourceFiles | ForEach-Object {
    if ($exportExtensions -notcontains $_.Extension.ToLowerInvariant()) { throw "Convert this input with an appropriate decoder first: $($_.Name)" }
    $relative = [System.IO.Path]::GetRelativePath($sourceRoot, $_.FullName)
    $destination = Join-Path $outputRoot ([System.IO.Path]::ChangeExtension($relative, '.jpg'))
    [pscustomobject]@{ Source = $_.FullName; Destination = $destination; Relative = [System.IO.Path]::ChangeExtension($relative, '.jpg') }
})
if (@($jobs | Group-Object Destination | Where-Object Count -gt 1).Count -gt 0) { throw 'Two input images would produce the same JPG filename; choose distinct source names.' }

# Preflight all inputs and overwrite permissions before writing an output image.
foreach ($job in $jobs) {
    $info = Read-ImageInfo $job.Source
    if ($info.Width -ne $info.Height) { throw "Non-square input needs an explicit crop or padding decision: $($job.Source)" }
    if ((Test-Path -LiteralPath $job.Destination) -and -not $Overwrite) { throw "Destination exists; preserve it or explicitly use -Overwrite: $($job.Destination)" }
}

$backupRoot = $null
if ($Overwrite -and @($jobs | Where-Object { Test-Path -LiteralPath $_.Destination }).Count -gt 0) {
    $backupName = (Split-Path $outputRoot -Leaf) + '-originals-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $backupRoot = Join-Path (Split-Path $outputRoot -Parent) $backupName
}
$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$results = @()
foreach ($job in $jobs) {
    $inputImage = $null
    $canvas = $null
    $outputBytes = $null
    $qualityUsed = $null
    $originalHash = (Get-FileHash -LiteralPath $job.Source -Algorithm SHA256).Hash
    $inputInfo = Read-ImageInfo $job.Source
    if ($inputInfo.Valid) {
        $outputBytes = [System.IO.File]::ReadAllBytes($job.Source)
        $qualityUsed = 'unchanged'
    } else {
        try {
            $inputImage = [System.Drawing.Image]::FromFile($job.Source)
            $canvas = [System.Drawing.Bitmap]::new($Edge, $Edge, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $graphics = [System.Drawing.Graphics]::FromImage($canvas)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                if ($inputImage.Width -eq $Edge -and $inputImage.Height -eq $Edge) {
                    $graphics.DrawImageUnscaled($inputImage, 0, 0)
                } else { $graphics.DrawImage($inputImage, 0, 0, $Edge, $Edge) }
            } finally { $graphics.Dispose() }
            foreach ($quality in @(95, 92, 90, 85, 80)) {
                $buffer = [System.IO.MemoryStream]::new()
                $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
                try {
                    $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
                    $canvas.Save($buffer, $encoder, $parameters)
                    if ($buffer.Length -lt $byteLimit) { $outputBytes = $buffer.ToArray(); $qualityUsed = $quality; break }
                } finally { $parameters.Dispose(); $buffer.Dispose() }
            }
        } finally {
            if ($null -ne $canvas) { $canvas.Dispose() }
            if ($null -ne $inputImage) { $inputImage.Dispose() }
        }
        if ($null -eq $outputBytes) { throw "Cannot meet the byte limit without dropping below quality 80: $($job.Source)" }
    }
    if ((Get-FileHash -LiteralPath $job.Source -Algorithm SHA256).Hash -ne $originalHash) { throw "Source changed during export: $($job.Source)" }
    $destinationExisted = Test-Path -LiteralPath $job.Destination
    if ($destinationExisted -and -not $Overwrite) { throw "Destination appeared during export: $($job.Destination)" }
    $backup = $null
    if ($destinationExisted) {
        if ($null -eq $backupRoot) { throw 'Destination appeared after preflight; stop before overwriting.' }
        $backup = Join-Path $backupRoot $job.Relative
        New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $job.Destination -Destination $backup
        if ((Get-FileHash -LiteralPath $job.Destination -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash) { throw 'Original backup verification failed.' }
    }
    New-Item -ItemType Directory -Path (Split-Path $job.Destination -Parent) -Force | Out-Null
    try {
        [System.IO.File]::WriteAllBytes($job.Destination, $outputBytes)
        $verified = Read-ImageInfo $job.Destination
        if (-not $verified.Valid) { throw "Export verification failed: $($job.Destination)" }
    } catch {
        if ($null -ne $backup) { Copy-Item -LiteralPath $backup -Destination $job.Destination -Force }
        elseif (Test-Path -LiteralPath $job.Destination) { Remove-Item -LiteralPath $job.Destination -Force }
        throw
    }
    $results += [pscustomobject]@{ Path = $job.Destination; Bytes = $verified.Bytes; Width = $verified.Width; Height = $verified.Height; Format = $verified.Format; Quality = $qualityUsed; Backup = $backup }
}
[pscustomobject]@{ Count = $results.Count; MaxBytes = ($results | Measure-Object Bytes -Maximum).Maximum; BackupFolder = $backupRoot; Images = $results } | ConvertTo-Json -Depth 5
