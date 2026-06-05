# Huawei HarmonyOS (commercial) + OpenHarmony PC (Kaihong), API 20 for OH forks.
$ErrorActionPreference = 'Stop'

$OhApiLevel = 20
$OhSdkVersion = '6.0.0(20)'
$ohSdk = 'D:\HarmonyOS\Huawei\OpenHarmony SDK'
$ohApi = Join-Path $ohSdk "$OhApiLevel"
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

if (-not (Test-Path -LiteralPath "$ohApi\native\llvm\bin\clang++.exe")) {
    Write-Error "API $OhApiLevel SDK not found: $ohApi`nInstall OpenHarmony API $OhApiLevel in DevEco -> Settings -> OpenHarmony SDK."
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
            try {
                Rename-Item -LiteralPath $Link -NewName $bakName -ErrorAction Stop
                Write-Host "Renamed folder -> $bakName"
            } catch {
                Write-Warning "Cannot replace $Link (DevEco may be using it). Close IDE and re-run."
                return
            }
        }
    }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    Write-Host "Junction: $Link -> $Target"
}

function Set-BuildProfileOpenHarmony {
    param([int]$ApiLevel, [string]$SdkVersion)
    $bp = Join-Path $root 'build-profile.json5'
    $text = Get-Content -LiteralPath $bp -Raw -Encoding UTF8
    # Only patch product "oh" (OpenHarmony); leave HarmonyOS product "default" on API 22.
    $ohBlock = [regex]::Match(
        $text,
        '"name"\s*:\s*"oh"[\s\S]*?"runtimeOS"\s*:\s*"OpenHarmony"'
    )
    if (-not $ohBlock.Success) {
        Write-Warning "product oh not found in $bp — add OpenHarmony product with runtimeOS OpenHarmony"
        return
    }
    $patchedBlock = $ohBlock.Value `
        -replace '"compatibleSdkVersion"\s*:\s*"[^"]*"', "`"compatibleSdkVersion`": `"$SdkVersion`"" `
        -replace '"compileSdkVersion"\s*:\s*"[^"]*"', "`"compileSdkVersion`": `"$SdkVersion`"" `
        -replace '"targetSdkVersion"\s*:\s*"[^"]*"', "`"targetSdkVersion`": `"$SdkVersion`""
    $patched = $text.Substring(0, $ohBlock.Index) + $patchedBlock + $text.Substring($ohBlock.Index + $ohBlock.Length)
    if ($patched -ne $text) {
        Set-Content -LiteralPath $bp -Value $patched -Encoding UTF8 -NoNewline
        if (-not $patched.EndsWith("`n")) { Add-Content -LiteralPath $bp -Value '' -Encoding UTF8 }
        Write-Host "Updated product oh -> OpenHarmony API ${ApiLevel} ($SdkVersion): $bp"
    } else {
        Write-Host "OK: product oh already OpenHarmony API ${ApiLevel} ($SdkVersion)"
    }
}

Ensure-Junction -Link $linkNoSpace -Target $ohSdk

@(
    "# OpenHarmony SDK (API $OhApiLevel), 2in1 PC target."
    "sdk.dir=$($linkNoSpace -replace '\\','/')"
    ''
) | Set-Content -LiteralPath (Join-Path $root 'local.properties') -Encoding UTF8

Set-BuildProfileOpenHarmony -ApiLevel $OhApiLevel -SdkVersion $OhSdkVersion

function Set-ModuleDeviceTypesMulti {
    param([int]$ApiLevel)
    $moduleJson = Join-Path $root 'entry\src\main\module.json5'
    if (-not (Test-Path -LiteralPath $moduleJson)) { return }
    $types = if ($ApiLevel -le 14) { @('default', 'tablet') } else { @('default', 'tablet', '2in1') }
    $typeLines = ($types | ForEach-Object { "      `"$_`"" }) -join ",`n"
    $want = @"
    `"deviceTypes`": [
$typeLines
    ],
"@
    $text = Get-Content -LiteralPath $moduleJson -Raw -Encoding UTF8
    $fixed = $text -replace '"deviceTypes"\s*:\s*\[[^\]]*\]', $want.TrimEnd(',')
    if ($fixed -ne $text) {
        Set-Content -LiteralPath $moduleJson -Value $fixed -Encoding UTF8 -NoNewline
        if (-not $fixed.EndsWith("`n")) { Add-Content -LiteralPath $moduleJson -Value '' -Encoding UTF8 }
        Write-Host "Updated deviceTypes -> $($types -join '/'): $moduleJson"
    } else {
        Write-Host "OK: $moduleJson (deviceTypes $($types -join '/'))"
    }
}

Set-ModuleDeviceTypesMulti -ApiLevel $OhApiLevel

$syscap = Join-Path $root 'entry\src\main\syscap.json'
if (Test-Path -LiteralPath $syscap) {
    $types = if ($OhApiLevel -le 14) { @('default', 'tablet') } else { @('default', 'tablet', '2in1') }
    $typeLines = ($types | ForEach-Object { "      `"$_`"" }) -join ",`n"
    $wantSc = @"
    `"general`": [
$typeLines
    ]
"@
    $sc = Get-Content -LiteralPath $syscap -Raw -Encoding UTF8
    $sc2 = $sc -replace '"general"\s*:\s*\[[^\]]*\]', $wantSc.TrimEnd(',')
    if ($sc2 -ne $sc) {
        Set-Content -LiteralPath $syscap -Value $sc2 -Encoding UTF8 -NoNewline
        Write-Host "Updated syscap.json -> $($types -join '/')"
    }
}

function Ensure-SyscapSchema2in1 {
    if ($OhApiLevel -le 14) { return }
    $schema = Join-Path $ohApi 'toolchains\syscapcheck\sysCapSchema.json'
    if (-not (Test-Path -LiteralPath $schema)) { return }
    $text = Get-Content -LiteralPath $schema -Raw -Encoding UTF8
    if ($text -match '"2in1"') { return }
    $patched = $text -replace '("router"\s*\])', ('"router",' + [Environment]::NewLine + '              "2in1"' + [Environment]::NewLine + '            ]')
    if ($patched -ne $text) {
        Set-Content -LiteralPath $schema -Value $patched -Encoding UTF8 -NoNewline
        Write-Host "Patched syscap schema (added 2in1): $schema"
    }
}

Ensure-SyscapSchema2in1

New-Item -ItemType Directory -Force -Path $devecoSdk | Out-Null
Ensure-Junction -Link $devecoOh -Target $ohApi
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
Write-Host "Done. HarmonyOS product=default (API 22) + OpenHarmony product=oh (API ${OhApiLevel}, $OhSdkVersion):"
Write-Host "  1) DevEco run target: phone (ARM) / tablet / 2in1 emulator (phone = default in module.json5)"
Write-Host "  2) Kaihong / 深开鸿 PC: build with product=oh (OpenHarmony API ${OhApiLevel})"
Write-Host "  3) Native: arm64-v8a (真机) + x86_64 (模拟器)"
Write-Host "  4) Build: powershell -File scripts\assemble_hap.ps1"
Write-Host ""
