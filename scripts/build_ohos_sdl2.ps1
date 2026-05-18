# Build HarmonyOS SDL2 for Luanti deps (x86_64 2in1 PC emulator).
# Source: https://gitcode.com/openharmony-sig/ohos_sdl2
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SdkNative = "D:\deveco studio\sdk\default\openharmony\native"
$Toolchain = Join-Path $SdkNative "build\cmake\ohos.toolchain.cmake"
$Cmake = Join-Path $SdkNative "build-tools\cmake\bin\cmake.exe"
$Ninja = Join-Path $SdkNative "build-tools\cmake\bin\ninja.exe"
$Abi = if ($env:OHOS_ARCH) { $env:OHOS_ARCH } else { "x86_64" }
$Out = Join-Path $Root "third_party\ohos_sdl2_build"
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
