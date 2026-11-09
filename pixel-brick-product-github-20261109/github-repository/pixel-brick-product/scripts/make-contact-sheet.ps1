#requires -Version 7.0
[CmdletBinding(DefaultParameterSetName='Directory')]
param(
 [Parameter(Mandatory,ParameterSetName='Directory')][string]$SourceDirectory,
 [Parameter(Mandatory,ParameterSetName='Files')][string[]]$ImagePath,
 [Parameter(Mandatory)][string]$OutputPath,
 [ValidateRange(1,9)][int]$Columns=3,
 [ValidateRange(80,1254)][int]$ThumbSize=320,
 [string[]]$Labels,
 [switch]$Overwrite
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$files=if($PSCmdlet.ParameterSetName -eq 'Directory'){@(Get-ChildItem -LiteralPath $SourceDirectory -File|Where-Object {$_.Extension.ToLowerInvariant() -in @('.jpg','.jpeg','.png')}|Sort-Object Name|ForEach-Object FullName)}else{@($ImagePath|ForEach-Object {[IO.Path]::GetFullPath($_)})}
if($files.Count -eq 0){throw 'No images selected.'}
if($Labels -and $Labels.Count -ne $files.Count){throw 'Labels must match the number of selected images.'}
$output=[IO.Path]::GetFullPath($OutputPath)
if($files -contains $output){throw 'The contact sheet cannot replace one of its input images.'}
if((Test-Path -LiteralPath $output) -and -not $Overwrite){throw 'Contact sheet exists; choose another path or explicitly use Overwrite.'}
if([IO.Path]::GetExtension($output).ToLowerInvariant() -notin @('.jpg','.png')){throw 'OutputPath must end in .jpg or .png.'}
$rows=[int][Math]::Ceiling($files.Count/[double]$Columns);$gap=12;$labelHeight=36
$width=$Columns*($ThumbSize+$gap)+$gap;$height=$rows*($ThumbSize+$labelHeight+$gap)+$gap
$canvas=[Drawing.Bitmap]::new($width,$height);$g=[Drawing.Graphics]::FromImage($canvas)
$font=[Drawing.Font]::new('Microsoft YaHei',[single][Math]::Max(10,($ThumbSize/24)))
$format=[Drawing.StringFormat]::new();$format.Alignment=[Drawing.StringAlignment]::Center;$format.Trimming=[Drawing.StringTrimming]::EllipsisCharacter
try{
 $g.Clear([Drawing.Color]::FromArgb(241,246,250));$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 for($i=0;$i -lt $files.Count;$i++){
  $im=[Drawing.Image]::FromFile($files[$i])
  try{
   $x=$gap+($i%$Columns)*($ThumbSize+$gap);$y=$gap+[int][Math]::Floor($i/$Columns)*($ThumbSize+$labelHeight+$gap)
   $scale=[Math]::Min($ThumbSize/[double]$im.Width,$ThumbSize/[double]$im.Height);$w=[int][Math]::Round($im.Width*$scale);$h=[int][Math]::Round($im.Height*$scale)
   $g.DrawImage($im,[Drawing.Rectangle]::new(($x+[int](($ThumbSize-$w)/2)),($y+[int](($ThumbSize-$h)/2)),$w,$h))
   $label=if($Labels){$Labels[$i]}else{[IO.Path]::GetFileName($files[$i])}
   $g.DrawString($label,$font,[Drawing.Brushes]::Navy,[Drawing.RectangleF]::new($x,($y+$ThumbSize+4),$ThumbSize,$labelHeight),$format)
  }finally{$im.Dispose()}
 }
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))|Out-Null
 if([IO.Path]::GetExtension($output).ToLowerInvariant() -eq '.png'){$canvas.Save($output,[Drawing.Imaging.ImageFormat]::Png)}else{
  $codec=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|Where-Object MimeType -eq 'image/jpeg';$ep=[Drawing.Imaging.EncoderParameters]::new(1)
  try{$ep.Param[0]=[Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality,[long]93);$canvas.Save($output,$codec,$ep)}finally{$ep.Dispose()}
 }
}finally{$format.Dispose();$font.Dispose();$g.Dispose();$canvas.Dispose()}
[pscustomobject]@{File=$output;Images=$files.Count;Width=$width;Height=$height;Bytes=(Get-Item -LiteralPath $output).Length}|ConvertTo-Json -Compress
