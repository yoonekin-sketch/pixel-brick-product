$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
$repo=Join-Path $PSScriptRoot 'github-repository';$skill=Join-Path $repo 'pixel-brick-product'
$assets=@(Get-ChildItem -LiteralPath (Join-Path $skill 'assets') -File -Recurse|Where-Object Extension -in '.jpg','.png')
if($assets.Count -ne 16 -or (Test-Path -LiteralPath (Join-Path $skill 'assets/product-12k75'))){throw 'Unexpected public-image scope.'}
$index=@($assets|ForEach-Object {
 $im=[Drawing.Image]::FromFile($_.FullName)
 try{[pscustomobject]@{path=[IO.Path]::GetRelativePath($skill,$_.FullName).Replace('\','/');width=$im.Width;height=$im.Height;bytes=$_.Length;format=if($im.RawFormat.Guid -eq [Drawing.Imaging.ImageFormat]::Jpeg.Guid){'JPEG'}else{'PNG'};sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}}finally{$im.Dispose()}
})
$index|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $skill 'assets/asset-index.json') -Encoding utf8
$upload=(& (Join-Path $skill 'scripts/export-upload-jpg.ps1') -SourcePath (Join-Path $skill 'assets/examples') -AuditOnly -Recurse|Out-String)|ConvertFrom-Json
if($upload.Total -ne 13 -or $upload.InvalidCount -ne 0){throw 'Public full-size sample audit failed.'}
$broken=@()
foreach($md in Get-ChildItem -LiteralPath $repo -File -Recurse -Filter '*.md'){
 $text=Get-Content -LiteralPath $md.FullName -Raw
 foreach($m in [regex]::Matches($text,'\[[^\]]*\]\(([^)]+)\)')){$link=$m.Groups[1].Value;if($link -notmatch '^(https?:|#)' -and -not (Test-Path -LiteralPath (Join-Path $md.DirectoryName $link))){$broken+=$md.Name+':'+$link}}
}
if($broken.Count){throw ('Broken publishing links: '+($broken -join '; '))}
$forbidden='C:\\Users\\|H:\\|E:\\|71423|BEGIN .*PRIVATE KEY|github_pat_|ghp_|\[TODO:'
foreach($file in Get-ChildItem -LiteralPath $repo -File -Recurse|Where-Object Extension -in '.md','.json','.yaml','.ps1'){
 if((Get-Content -LiteralPath $file.FullName -Raw) -match $forbidden){throw ('Private path, secret marker or unfinished scaffold in publishing content: '+$file.Name)}
}
if((Get-FileHash -LiteralPath (Join-Path $repo 'LICENSE')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $skill 'LICENSE')).Hash){throw 'Bundled MIT notices differ.'}
$files=@(Get-ChildItem -LiteralPath $repo -File -Recurse|Sort-Object FullName)
if(@($files|Where-Object Name -Match '^\.env|credential|secret|token|local-build|install-plan|installation-result|config\.toml').Count){throw 'A local-only file entered the publishing directory.'}
$records=@($files|ForEach-Object {[pscustomobject]@{path=[IO.Path]::GetRelativePath($repo,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash;bytes=$_.Length}})
$zipFile=Join-Path $PSScriptRoot 'pixel-brick-product-public-lite.zip'
$stream=[IO.File]::Open($zipFile,[IO.FileMode]::CreateNew);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
try{foreach($r in $records){$entry=$zip.CreateEntry($r.path,[IO.Compression.CompressionLevel]::Optimal);$to=$entry.Open();$from=[IO.File]::OpenRead((Join-Path $repo $r.path));try{$from.CopyTo($to)}finally{$from.Dispose();$to.Dispose()}}}finally{$zip.Dispose();$stream.Dispose()}
$stream=[IO.File]::OpenRead($zipFile);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$false)
try{
 if($zip.Entries.Count -ne $records.Count){throw 'Publishing ZIP count mismatch.'}
 foreach($r in $records){$entry=$zip.GetEntry($r.path);if(-not $entry){throw 'Missing publishing ZIP entry.'};$s=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create();try{$hash=[BitConverter]::ToString($sha.ComputeHash($s)).Replace('-','')}finally{$sha.Dispose();$s.Dispose()};if($hash -ne $r.sha256){throw 'Publishing ZIP content mismatch.'}}
}finally{$zip.Dispose();$stream.Dispose()}
$report=[pscustomobject]@{status='ready_for_manual_upload';files=$records.Count;sample_art=13;contact_sheets=3;raw_product_photos=0;private_text_markers=0;local_links_valid=$true;mit_for_code=$true;images_reference_only=$true;zip=$zipFile;zip_bytes=(Get-Item -LiteralPath $zipFile).Length;github_uploaded=$false;github_block='Connected GitHub API returned 403 account suspended';records=$records}
$report|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'public-package-validation.json') -Encoding utf8
$report|Select-Object status,files,sample_art,contact_sheets,raw_product_photos,zip_bytes,github_uploaded|ConvertTo-Json -Compress
