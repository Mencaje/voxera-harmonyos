# Build entry HAP with correct SDK + Java (DevEco CLI often lacks JAVA_HOME).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $root

try {
    & (Join-Path $PSScriptRoot 'fix_ohos_sdk.ps1')
} catch {
    Write-Warning "fix_ohos_sdk.ps1: $_"
}

$sdkRoot = 'D:\OHOS_SDK'
if (-not (Test-Path -LiteralPath "$sdkRoot\20\native")) {
    $sdkRoot = 'D:/HarmonyOS/Huawei/OpenHarmony SDK' -replace '/','\'
}
$env:OHOS_BASE_SDK_HOME = $sdkRoot

$javaHome = 'D:\deveco studio\jbr'
if (Test-Path -LiteralPath "$javaHome\bin\java.exe") {
    $env:JAVA_HOME = $javaHome
    $env:Path = "$javaHome\bin;$env:Path"
} else {
    Write-Warning "Java not found at $javaHome — PackageHap may fail with spawn java ENOENT."
}

$node = 'D:\deveco studio\tools\node\node.exe'
$hvigor = 'D:\deveco studio\tools\hvigor\bin\hvigorw.js'
if (-not (Test-Path -LiteralPath $node)) { Write-Error "Node not found: $node" }
if (-not (Test-Path -LiteralPath $hvigor)) { Write-Error "hvigorw not found: $hvigor" }

& $node $hvigor --stop-daemon 2>$null | Out-Null

$args = @(
    $hvigor,
    '--mode', 'module',
    '-p', 'module=entry@default',
    '-p', 'product=oh',
    '-p', 'buildMode=debug',
    'assembleHap',
    '--analyze=normal',
    '--parallel',
    '--incremental'
)
Write-Host "OHOS_BASE_SDK_HOME=$env:OHOS_BASE_SDK_HOME"
Write-Host "JAVA_HOME=$env:JAVA_HOME"
& $node @args
exit $LASTEXITCODE
