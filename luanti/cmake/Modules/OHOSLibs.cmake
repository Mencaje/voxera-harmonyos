# Prebuilt deps for HarmonyOS (layout matches android/native/deps).
# Populate: entry/ohos_deps/<abi>/ from luanti_android_deps or OHOS cross-build.

if(CMAKE_OHOS_ARCH_ABI)
	set(OHOS_ABI "${CMAKE_OHOS_ARCH_ABI}")
elseif(OHOS_ARCH)
	set(OHOS_ABI "${OHOS_ARCH}")
else()
	set(OHOS_ABI "arm64-v8a")
endif()

get_filename_component(LUANTI_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(DEPS "${LUANTI_ROOT}/../entry/ohos_deps/${OHOS_ABI}")

if(NOT EXISTS "${DEPS}/SDL2/libSDL2.a")
	message(WARNING "OHOS deps missing at ${DEPS} — engine link will fail until libraries are built for OHOS.")
	return()
endif()

message(STATUS "Using OHOS deps: ${DEPS}")

set(CURL_INCLUDE_DIR ${DEPS}/Curl/include)
set(CURL_LIBRARY
	${DEPS}/Curl/libcurl.a
	${DEPS}/Curl/libmbedtls.a
	${DEPS}/Curl/libmbedx509.a
	${DEPS}/Curl/libmbedcrypto.a
)
set(CURL_FOUND TRUE)
set(FREETYPE_INCLUDE_DIR_ft2build ${DEPS}/Freetype/include/freetype2)
set(FREETYPE_INCLUDE_DIR_freetype2 ${DEPS}/Freetype/include/freetype2/freetype)
set(FREETYPE_LIBRARY ${DEPS}/Freetype/libfreetype.a)
set(JPEG_INCLUDE_DIR ${DEPS}/JPEG/include)
set(JPEG_LIBRARY ${DEPS}/JPEG/libjpeg.a)
set(LUA_INCLUDE_DIR ${DEPS}/LuaJIT/include)
set(LUA_LIBRARY ${DEPS}/LuaJIT/libluajit.a)
set(OGG_INCLUDE_DIR ${DEPS}/Vorbis/include)
set(OGG_LIBRARY ${DEPS}/Vorbis/libogg.a)
set(OPENAL_INCLUDE_DIR ${DEPS}/OpenAL-Soft/include)
set(OPENAL_LIBRARY ${DEPS}/OpenAL-Soft/libopenal.a)
set(PNG_LIBRARY ${DEPS}/PNG/libpng.a)
set(PNG_PNG_INCLUDE_DIR ${DEPS}/PNG/include)
set(SQLITE3_INCLUDE_DIR ${DEPS}/SQLite/include)
set(SQLITE3_LIBRARY ${DEPS}/SQLite/libsqlite3.a)
set(VORBIS_INCLUDE_DIR ${DEPS}/Vorbis/include)
set(VORBIS_LIBRARY ${DEPS}/Vorbis/libvorbis.a)
set(VORBISFILE_LIBRARY ${DEPS}/Vorbis/libvorbisfile.a)
set(ZSTD_INCLUDE_DIR ${DEPS}/Zstd/include)
set(ZSTD_LIBRARY ${DEPS}/Zstd/libzstd.a)
set(SDL2_INCLUDE_DIRS ${DEPS}/SDL2/include/SDL2)
set(SDL2_LIBRARIES ${DEPS}/SDL2/libSDL2.a)
# Prefer a local ohos_sdl2 rebuild (has Voxera XComponent resize/input symbols).
set(_VOXERA_SDL_BUILD "${LUANTI_ROOT}/../third_party/ohos_sdl2_build/libSDL2.a")
if(EXISTS "${_VOXERA_SDL_BUILD}")
	set(SDL2_LIBRARIES "${_VOXERA_SDL_BUILD}")
	message(STATUS "Using rebuilt OHOS SDL2: ${SDL2_LIBRARIES}")
endif()
# Internal OHOS SDL sources (OhosPluginManager, OHOS_SetScreen*, etc.)
set(SDL2_OHOS_SRC_DIR "${LUANTI_ROOT}/../third_party/ohos_sdl2/src")
