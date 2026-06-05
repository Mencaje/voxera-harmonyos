# Build HarmonyOS SDL2 + cJSON for one ABI (x86_64 emulator or arm64-v8a device).
# Usage: $env:OHOS_ARCH='arm64-v8a'; .\scripts\build_ohos_sdl2.ps1
# Source: https://gitcode.com/openharmony-sig/ohos_sdl2
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SdkNative = $env:OHOS_NATIVE_HOME
if (-not $SdkNative -or -not (Test-Path $SdkNative)) {
    foreach ($cand in @(
        'D:\HarmonyOS\Huawei\OpenHarmony SDK\20\native',
        'D:\deveco studio\sdk\default\openharmony\native'
    )) {
        if (Test-Path $cand) { $SdkNative = $cand; break }
    }
}
if (-not $SdkNative) { throw 'OpenHarmony native SDK not found. Set OHOS_NATIVE_HOME.' }
$Toolchain = Join-Path $SdkNative "build\cmake\ohos.toolchain.cmake"
$Cmake = Join-Path $SdkNative "build-tools\cmake\bin\cmake.exe"
$Ninja = Join-Path $SdkNative "build-tools\cmake\bin\ninja.exe"
$Abi = if ($env:OHOS_ARCH) { $env:OHOS_ARCH } else { "x86_64" }
$Out = Join-Path $Root "third_party\ohos_sdl2_build\$Abi"
$Src = Join-Path $Root "third_party\ohos_sdl2"
$Cjson = Join-Path $Root "third_party\cjson"

if (-not (Test-Path $Src)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Src) | Out-Null
    git clone --depth 1 https://gitcode.com/openharmony-sig/ohos_sdl2.git $Src
}

if (-not (Test-Path (Join-Path $Src "CMakeLists.txt"))) {
    throw "ohos_sdl2 sources not found at $Src"
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
if (-not (Test-Path $Cjson)) {
    git clone --depth 1 --branch v1.7.15 https://github.com/DaveGamble/cJSON.git $Cjson
}

& $Cmake -S $Src -B $Out -G Ninja `
    "-DCMAKE_TOOLCHAIN_FILE=$Toolchain" `
    "-DCMAKE_MAKE_PROGRAM=$Ninja" `
    "-DOHOS_ARCH=$Abi" `
    "-DCJSON_SOURCE_DIR=$Cjson" `
    -DCMAKE_BUILD_TYPE=Release `
    -DSDL_SHARED=OFF `
    -DSDL_STATIC=ON `
    -DSDL_STATIC_PIC=ON `
    -DSDL_TEST=OFF `
    -DVOXERA_EMBEDDED_SDL=ON
& $Ninja -C $Out
if ($LASTEXITCODE -ne 0) {
    throw "ninja failed with exit code $LASTEXITCODE"
}

$Dest = Join-Path $Root "entry\ohos_deps\$Abi\SDL2"
New-Item -ItemType Directory -Force -Path (Join-Path $Dest "include\SDL2") | Out-Null
$Lib = Get-ChildItem $Out -Recurse -Filter "libSDL2*.a" | Select-Object -First 1
if (-not $Lib) { throw "libSDL2.a not found under $Out" }
Copy-Item $Lib.FullName (Join-Path $Dest "libSDL2.a") -Force
Copy-Item (Join-Path $Src "include\*.h") (Join-Path $Dest "include\SDL2\") -Force
Write-Host "Installed SDL2 to $Dest"

$CjsonLib = Get-ChildItem $Out -Recurse -Filter "libcjson.a" | Select-Object -First 1
if ($CjsonLib) {
    $CjsonDest = Join-Path $Root "entry\ohos_deps\$Abi\cjson"
    New-Item -ItemType Directory -Force -Path $CjsonDest | Out-Null
    Copy-Item $CjsonLib.FullName (Join-Path $CjsonDest "libcjson.a") -Force
    Write-Host "Installed cJSON to $CjsonDest"
} else {
    Write-Warning "libcjson.a not found under $Out"
}
