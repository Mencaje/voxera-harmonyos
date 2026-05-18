# Pack Luanti share data (same set as Android prepareAssets) into rawfile zip.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$Root\luanti\builtin")) {
    $Root = "d:\xiangmu\Voxera\Voxera2"
}
$Luanti = Join-Path $Root "luanti"
$Staging = Join-Path $Root "entry\build\luanti_assets_staging"
$OutDir = Join-Path $Root "entry\src\main\resources\rawfile"
$ZipPath = Join-Path $OutDir "luanti_assets.zip"

if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
New-Item -ItemType Directory -Force -Path $Staging, $OutDir | Out-Null

Copy-Item "$Luanti\minetest.conf.example", "$Luanti\README.md" -Destination $Staging
Copy-Item "$Luanti\doc\lgpl-2.1.txt" -Destination $Staging
Copy-Item "$Luanti\builtin" -Destination "$Staging\builtin" -Recurse
Copy-Item "$Luanti\client\shaders" -Destination "$Staging\client\shaders" -Recurse
$irrShaders = "$Luanti\irr\media\Shaders"
if (Test-Path $irrShaders) {
    Copy-Item $irrShaders -Destination "$Staging\client\shaders\Irrlicht" -Recurse
}
$FontsDir = Join-Path $Luanti "fonts"
$StagingFonts = Join-Path $Staging "fonts"
New-Item -ItemType Directory -Force -Path $StagingFonts | Out-Null

$FontNames = @(
    "Arimo-Regular.ttf", "Arimo-Bold.ttf", "Arimo-Italic.ttf", "Arimo-BoldItalic.ttf",
    "Cousine-Regular.ttf", "Cousine-Bold.ttf", "Cousine-Italic.ttf", "Cousine-BoldItalic.ttf",
    "DroidSansFallbackFull.ttf"
)
$FontBaseUrl = "https://github.com/luanti-org/luanti/raw/master/fonts"

foreach ($name in $FontNames) {
    $dest = Join-Path $FontsDir $name
    if (-not (Test-Path $dest)) {
        Write-Host "Downloading font $name ..."
        Invoke-WebRequest -Uri "$FontBaseUrl/$name" -OutFile $dest -UseBasicParsing
    }
    Copy-Item $dest -Destination $StagingFonts
}
$fontCount = (Get-ChildItem "$StagingFonts\*.ttf").Count
if ($fontCount -lt 1) {
    throw "No .ttf fonts in package (need $FontNames)"
}
Write-Host "Packed $fontCount font files"

$RawFonts = Join-Path $Root "entry\src\main\resources\rawfile\fonts"
New-Item -ItemType Directory -Force -Path $RawFonts | Out-Null
foreach ($name in $FontNames) {
    Copy-Item (Join-Path $StagingFonts $name) -Destination (Join-Path $RawFonts $name) -Force
}
Write-Host "Copied fonts to rawfile/fonts for HAP bootstrap"

$RawClient = Join-Path $Root "entry\src\main\resources\rawfile\client"
$RawShaders = Join-Path $RawClient "shaders"
if (Test-Path $RawShaders) { Remove-Item -Recurse -Force $RawShaders }
New-Item -ItemType Directory -Force -Path $RawShaders | Out-Null
Copy-Item "$Luanti\client\shaders\*" -Destination $RawShaders -Recurse -Force
if (Test-Path $irrShaders) {
    Copy-Item $irrShaders -Destination (Join-Path $RawShaders "Irrlicht") -Recurse -Force
}
$shaderManifest = @()
Get-ChildItem $RawShaders -Recurse -File | ForEach-Object {
    $rel = "client/shaders/" + ($_.FullName.Substring($RawShaders.Length + 1) -replace '\\', '/')
    $shaderManifest += $rel
}

# Also pack builtin/*.lua into rawfile (zip extract fallback on device)
$RawBuiltinRoot = Join-Path $OutDir "builtin"
if (Test-Path $RawBuiltinRoot) { Remove-Item -Recurse -Force $RawBuiltinRoot }
$builtinManifest = @()
Get-ChildItem "$Staging\builtin" -Recurse -File | ForEach-Object {
    $rel = "builtin/" + ($_.FullName.Substring((Join-Path $Staging "builtin").Length + 1) -replace '\\', '/')
    $dest = Join-Path $OutDir ($rel -replace '/', '\')
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    Copy-Item $_.FullName -Destination $dest -Force
    $builtinManifest += $rel
}
Write-Host "Copied $($builtinManifest.Count) builtin files to rawfile/builtin"

# UI textures into rawfile (OHOS zip may skip some paths; bootstrap copies these)
$textureManifest = @()
$PackSrc = Join-Path $Luanti "textures\base\pack"
if (Test-Path $PackSrc) {
    Get-ChildItem $PackSrc -Recurse -File | ForEach-Object {
        $rel = "textures/base/pack/" + ($_.FullName.Substring($PackSrc.Length + 1) -replace '\\', '/')
        $dest = Join-Path $OutDir ($rel -replace '/', '\')
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
        Copy-Item $_.FullName -Destination $dest -Force
        $textureManifest += $rel
    }
    Write-Host "Copied $($textureManifest.Count) textures to rawfile/textures/base/pack"
} else {
    Write-Warning "Missing $PackSrc — run from full luanti tree"
}

$manifestPath = Join-Path $OutDir "bootstrap_manifest.json"
$manifestJson = (@{
    shaders = $shaderManifest
    builtin = $builtinManifest
    textures = $textureManifest
} | ConvertTo-Json -Compress)
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Bootstrap manifest: $($shaderManifest.Count) shaders, $($builtinManifest.Count) builtin, $($textureManifest.Count) textures"

Copy-Item "$Luanti\textures\base\pack" -Destination "$Staging\textures\base\pack" -Recurse
Copy-Item "$Luanti\games\devtest" -Destination "$Staging\games\devtest" -Recurse

# GNU gettext catalog for main menu (OHOS build has USE_GETTEXT=0; engine loads .mo/.po directly)
$PoSrc = Join-Path $Luanti "po\zh_CN\luanti.po"
if (Test-Path $PoSrc) {
    $LocaleDest = Join-Path $Staging "locale\zh_CN\LC_MESSAGES"
    New-Item -ItemType Directory -Force -Path $LocaleDest | Out-Null
    Copy-Item $PoSrc -Destination (Join-Path $LocaleDest "luanti.po") -Force
    $msgfmt = Get-Command msgfmt -ErrorAction SilentlyContinue
    if ($msgfmt) {
        & msgfmt -o (Join-Path $LocaleDest "luanti.mo") $PoSrc
        Write-Host "Compiled zh_CN luanti.mo"
    } else {
        Write-Warning "msgfmt not found — packaged luanti.po only (OHOS loads .po)"
    }
    $RawLocale = Join-Path $OutDir "locale\zh_CN\LC_MESSAGES"
    New-Item -ItemType Directory -Force -Path $RawLocale | Out-Null
    Copy-Item (Join-Path $LocaleDest "luanti.po") -Destination $RawLocale -Force
    if (Test-Path (Join-Path $LocaleDest "luanti.mo")) {
        Copy-Item (Join-Path $LocaleDest "luanti.mo") -Destination $RawLocale -Force
    }
} else {
    Write-Warning "Missing $PoSrc — main menu will stay English on OHOS"
}

"" | Out-File "$Staging\.nomedia" -Encoding ascii

if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path "$Staging\*" -DestinationPath $ZipPath -CompressionLevel Fastest
$mb = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
Write-Host "Created $ZipPath ($mb MB)"
