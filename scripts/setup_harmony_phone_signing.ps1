# Sync HarmonyOS (commercial phone) debug signing for Voxera2.
# OpenHarmony certs under .ohos/config/openharmony/ cannot install on HarmonyOS phones (9568257 pkcs7).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$configRoot = Join-Path $env:USERPROFILE '.ohos\config'
$bp = Join-Path $root 'build-profile.json5'

function Find-Harmony555Voxera2Base {
    Get-ChildItem -LiteralPath $configRoot -File -Filter '555_Voxera2_*.p7b' -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -eq $configRoot } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 |
        ForEach-Object { $_.BaseName }
}

$harmonyBase = Find-Harmony555Voxera2Base
if (-not $harmonyBase) {
    Write-Host ''
    Write-Host 'HarmonyOS 555 debug cert for Voxera2 not found yet.'
    Write-Host 'Regenerate in DevEco Studio (phone connected via USB):'
    Write-Host '  1) File -> Project Structure -> Project -> Signing Configs'
    Write-Host '  2) Select signing config "555"'
    Write-Host '  3) Check "Support HarmonyOS" (required for Enjoy 90 / HarmonyOS phones)'
    Write-Host '  4) Click "Automatically generate signature" -> Apply -> OK'
    Write-Host '  5) Re-run: powershell -File scripts\setup_harmony_phone_signing.ps1'
    Write-Host ''
    Write-Host 'Expected cert location (NOT openharmony/):'
    Write-Host "  $configRoot\555_Voxera2_<hash>=.p7b"
    exit 1
}

$prefix = ($harmonyBase -replace '=', [regex]::Escape('='))
$cert = Join-Path $configRoot "$harmonyBase.cer"
$p7b = Join-Path $configRoot "$harmonyBase.p7b"
$p12 = Join-Path $configRoot "$harmonyBase.p12"
foreach ($f in @($cert, $p7b, $p12)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Error "Missing signing file: $f"
    }
}

$text = Get-Content -LiteralPath $bp -Raw -Encoding UTF8
if ($text -notmatch '555_Voxera2') {
    Write-Host '555 signing block uses manual debug material — skip auto path sync.'
    Write-Host 'To use DevEco auto 555_Voxera2 certs: File -> Project Structure -> Signing Configs -> 555 -> Apply'
    exit 0
}
$certEsc = ($cert -replace '\\', '/')
$p7bEsc = ($p7b -replace '\\', '/')
$p12Esc = ($p12 -replace '\\', '/')

$text = [regex]::Replace(
    $text,
    '("name"\s*:\s*"555"[\s\S]*?"certpath"\s*:\s*")[^"]+(")',
    "`${1}$certEsc`${2}"
)
$text = [regex]::Replace(
    $text,
    '("name"\s*:\s*"555"[\s\S]*?"profile"\s*:\s*")[^"]+(")',
    "`${1}$p7bEsc`${2}"
)
$text = [regex]::Replace(
    $text,
    '("name"\s*:\s*"555"[\s\S]*?"storeFile"\s*:\s*")[^"]+(")',
    "`${1}$p12Esc`${2}"
)
# Point both products at 555 debug signing.
$text = $text -replace '"signingConfig"\s*:\s*"default"', '"signingConfig": "555"'
$text = $text -replace '"signingConfig"\s*:\s*"555_oh"', '"signingConfig": "555"'
# Do not rewrite product oh runtimeOS — OpenHarmony builds need runtimeOS OpenHarmony.

Set-Content -LiteralPath $bp -Value $text -Encoding UTF8 -NoNewline
if (-not $text.EndsWith("`n")) { Add-Content -LiteralPath $bp -Value '' -Encoding UTF8 }

Write-Host "HarmonyOS phone signing synced -> config 555"
Write-Host "  cert:    $cert"
Write-Host "  profile: $p7b"
Write-Host "  store:   $p12"
Write-Host ''
Write-Host 'Rebuild and run on phone (product=default, runtimeOS=HarmonyOS).'
Write-Host 'Tablet/PC OpenHarmony builds: -p product=oh'
