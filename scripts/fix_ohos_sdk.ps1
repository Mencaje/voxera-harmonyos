# Align Voxera with OpenHarmony API 20 only (avoids hvigor 00303168 on HarmonyOS / API 22).
$ErrorActionPreference = 'Stop'

$ohSdk = 'D:\HarmonyOS\Huawei\OpenHarmony SDK'
$ohApi20 = Join-Path $ohSdk '20'
$devecoSdk = 'D:\deveco studio\sdk\default'
$devecoOh = Join-Path $devecoSdk 'openharmony'
$devecoHmsLink = Join-Path $devecoSdk 'HarmonyOS-6.0.2'
$linkNoSpace = 'D:\OHOS_SDK'
$root = Split-Path $PSScriptRoot -Parent
$node = 'D:\deveco studio\tools\node\node.exe'
$hvigor = 'D:\deveco studio\tools\hvigor\bin\hvigorw.js'
if ((Test-Path -LiteralPath $node) -and (Test-Path -LiteralPath $hvigor)) {
    & $node $hvigor --stop-daemon 2>$null | Out-Null
    Start-Sleep -Seconds 1
}

if (-not (Test-Path -LiteralPath "$ohApi20\native\llvm\bin\clang++.exe")) {
    Write-Error "API 20 SDK not found: $ohApi20`nInstall API 20 in DevEco -> Settings -> OpenHarmony SDK."
}

function Ensure-Junction([string]$Link, [string]$Target) {
    if (Test-Path -LiteralPath $Link) {
        $item = Get-Item -LiteralPath $Link -Force
        if ($item.LinkType -eq 'Junction') {
            $current = $item.Target
            if ($current -and ($current[0] -ieq $Target)) {
                Write-Host "OK junction: $Link"
                return
            }
            Remove-Item -LiteralPath $Link -Force
        } else {
            $bakName = "openharmony.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            $bak = Join-Path (Split-Path $Link -Parent) $bakName
            try {
                Rename-Item -LiteralPath $Link -NewName $bakName -ErrorAction Stop
                Write-Host "Renamed folder -> $bak"
            } catch {
                Write-Warning "Cannot replace $Link (DevEco may be using it). Close IDE and re-run, or ignore if native build already works."
                return
            }
        }
    }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Host "Junction: $Link -> $Target"
}

function Set-BuildProfileOpenHarmony20 {
    $bp = Join-Path $root 'build-profile.json5'
    $text = Get-Content -LiteralPath $bp -Raw -Encoding UTF8
    $bad = $text -match 'runtimeOS"\s*:\s*"HarmonyOS"' -or
        $text -match 'compileSdkVersion"\s*:\s*"' -or
        $text -match 'compatibleSdkVersion"\s*:\s*"' -or
        $text -match '6\.0\.[02]\(2[02]\)' -or
        $text -match '6\.0\.2\(22\)'
    if ($bad) {
        Write-Warning "build-profile.json5 had HarmonyOS / API 22 — rewriting to OpenHarmony API 20."
    }
    $fixed = @'
{
  "app": {
    "signingConfigs": [],
    "products": [{
      "name": "default",
      "signingConfig": "default",
      "compatibleSdkVersion": 20,
      "compileSdkVersion": 20,
      "targetSdkVersion": 20,
      "runtimeOS": "OpenHarmony"
    }],
    "buildModeSet": [{"name": "debug"}, {"name": "release"}]
  },
  "modules": [{"name": "entry", "srcPath": "./entry", "targets": [{"name": "default", "applyToProducts": ["default"]}]}]
}
'@
    if ($bad -or -not ($text -match 'runtimeOS"\s*:\s*"OpenHarmony"')) {
        Set-Content -LiteralPath $bp -Value $fixed.TrimEnd() -Encoding UTF8 -NoNewline
        Add-Content -LiteralPath $bp -Value '' -Encoding UTF8
        Write-Host "Updated: $bp"
    } else {
        Write-Host "OK: $bp (OpenHarmony API 20)"
    }
}

Ensure-Junction -Link $linkNoSpace -Target $ohSdk

@(
    '# OpenHarmony SDK (API 20). Must match DevEco Settings -> OpenHarmony SDK.'
    "sdk.dir=$($linkNoSpace -replace '\\','/')"
    ''
) | Set-Content -LiteralPath (Join-Path $root 'local.properties') -Encoding UTF8

Set-BuildProfileOpenHarmony20

function Set-ModuleDeviceTypes2in1 {
    $moduleJson = Join-Path $root 'entry\src\main\module.json5'
    if (-not (Test-Path -LiteralPath $moduleJson)) { return }
    $text = Get-Content -LiteralPath $moduleJson -Raw -Encoding UTF8
    if ($text -match '"deviceTypes"\s*:\s*\[\s*"2in1"\s*\]') {
        Write-Host "OK: $moduleJson (deviceTypes 2in1)"
        return
    }
    $fixed = $text -replace '"deviceTypes"\s*:\s*\[\s*"default"\s*\]', '"deviceTypes": [`n      "2in1"`n    ]'
    if ($fixed -eq $text) {
        $fixed = $text -replace '"deviceTypes"\s*:\s*\[[^\]]*\]', '"deviceTypes": [`n      "2in1"`n    ]'
    }
    if ($fixed -ne $text) {
        Set-Content -LiteralPath $moduleJson -Value $fixed -Encoding UTF8 -NoNewline
        if (-not $fixed.EndsWith("`n")) { Add-Content -LiteralPath $moduleJson -Value '' -Encoding UTF8 }
        Write-Host "Updated deviceTypes -> 2in1: $moduleJson"
    }
}

Set-ModuleDeviceTypes2in1

function Ensure-SyscapSchema2in1 {
    $schema = Join-Path $ohApi20 'toolchains\syscapcheck\sysCapSchema.json'
    if (-not (Test-Path -LiteralPath $schema)) { return }
    $text = Get-Content -LiteralPath $schema -Raw -Encoding UTF8
    if ($text -match '"2in1"') { return }
    $patched = $text -replace '("router"\s*\])', '"router",`n              "2in1"`n            ]'
    if ($patched -ne $text) {
        Set-Content -LiteralPath $schema -Value $patched -Encoding UTF8 -NoNewline
        Write-Host "Patched syscap schema (added 2in1): $schema"
    }
}

Ensure-SyscapSchema2in1

New-Item -ItemType Directory -Force -Path $devecoSdk | Out-Null
Ensure-Junction -Link $devecoOh -Target $ohApi20
if (Test-Path -LiteralPath $devecoHmsLink) {
    $h = Get-Item -LiteralPath $devecoHmsLink -Force
    if ($h.LinkType -ne 'Junction' -or ($h.Target -and $h.Target[0] -ne $devecoOh)) {
        Remove-Item -LiteralPath $devecoHmsLink -Force -ErrorAction SilentlyContinue
        Ensure-Junction -Link $devecoHmsLink -Target $devecoOh
    }
} else {
    Ensure-Junction -Link $devecoHmsLink -Target $devecoOh
}

Write-Host ""
Write-Host "Done. Next in DevEco:"
Write-Host "  1) Settings -> OpenHarmony SDK path = $ohSdk"
Write-Host "  2) File -> Sync Project (if sync changes build-profile, run this script again)"
Write-Host "  3) Product: runtimeOS OpenHarmony, API 20 — NOT HarmonyOS 6.0.2(22)"
Write-Host "  4) Run target: OpenHarmony 2in1 模拟器 (API 20)，不要用 phone 模拟器"
Write-Host "  5) 若运行报 00401004 SysCap：已用 entry/src/main/syscap.json 裁剪，需 Clean + 重装 HAP"
Write-Host "  6) Build via: powershell -File scripts\assemble_hap.ps1"
Write-Host ""
