$ErrorActionPreference='Stop'
$source='C:\Users\71423\.codex\skills\pixel-brick-product'
$repo=Join-Path $PSScriptRoot 'github-repository';$skill=Join-Path $repo 'pixel-brick-product'
if(Test-Path -LiteralPath $repo){throw 'Publishing draft already exists; inspect it rather than replacing it.'}
[IO.Directory]::CreateDirectory($skill)|Out-Null
function Copy-PackageFile([string]$from,[string]$relative){$to=Join-Path $skill $relative;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))|Out-Null;[IO.File]::Copy($from,$to,$false);if((Get-FileHash -LiteralPath $from).Hash -ne (Get-FileHash -LiteralPath $to).Hash){throw 'Publishing copy mismatch.'}}
foreach($relative in @('SKILL.md','agents/openai.yaml','references/style-guide.md','references/prompt-recipes.md','scripts/export-upload-jpg.ps1','scripts/make-contact-sheet.ps1')){Copy-PackageFile (Join-Path $source $relative) $relative}
foreach($n in 1..9){$name=$n.ToString('00')+'.jpg';Copy-PackageFile (Join-Path $source ('assets/approved/navy/'+$name)) ('assets/examples/listing/'+$name)}
foreach($theme in @('black','ivory','wine')){Copy-PackageFile (Join-Path $source ('assets/approved/'+$theme+'/01.jpg')) ('assets/examples/heroes/'+$theme+'.jpg')}
Copy-PackageFile (Join-Path $source 'assets/approved/sku/01-wine.jpg') 'assets/examples/sku/wine.jpg'
foreach($name in @('navy-nine.jpg','four-color-heroes.jpg','four-color-sku.jpg')){Copy-PackageFile (Join-Path $source ('assets/contact-sheets/'+$name)) ('assets/contact-sheets/'+$name)}
$entry=Get-Content -LiteralPath (Join-Path $skill 'SKILL.md') -Raw
$entry=$entry.Replace('包含已确认雨伞样图和独立的12K75案例；不把真实商品改成积木，不套用手绘涂鸦风。','包含精选雨伞风格样图与通用九图叙述框架；不把真实商品改成积木，不套用手绘涂鸦风。')
$entry=$entry.Replace('- 只有明确为同款7-12K75黑胶手动款时，才读[雨伞案例](references/umbrella-12k75.md)及其实拍和参数。其他产品重新核对。','- 系列规划参考[九图叙述框架](references/storyboard.md)，按当前商品调整图位。公开包没有实物资料；所有产品结构、材质与参数都必须由使用者提供并重新核对。')
[IO.File]::WriteAllText((Join-Path $skill 'SKILL.md'),$entry,[Text.UTF8Encoding]::new($false))
$prompts=Get-Content -LiteralPath (Join-Path $skill 'references/prompt-recipes.md') -Raw
$prompts=$prompts.Replace('用$pixel-brick-product给同款12K75酒红伞做九张泰文商品图，忠于实物，每套一张九宫格，暂不覆盖。','用$pixel-brick-product按我提供的商品实拍做九张泰文商品图，忠于实物，每套一张九宫格，暂不覆盖。')
[IO.File]::WriteAllText((Join-Path $skill 'references/prompt-recipes.md'),$prompts,[Text.UTF8Encoding]::new($false))
[pscustomobject]@{PublicRepoDraft=$repo;SampleArt=13;ContactSheets=3;RawProductPhotos=0;PersonalSkillUnchanged=$true}|ConvertTo-Json -Compress
