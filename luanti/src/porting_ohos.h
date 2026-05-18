// Luanti — HarmonyOS port (Voxera)
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#ifdef __OHOS__

#include <string>

struct OH_NativeXComponent;

namespace porting {

void ohosSetDataPaths(const std::string &shareDir, const std::string &cacheDir,
		const std::string &userDir);
/** User-visible Documents/Voxera/user_data (engine path_user stays in sandbox). */
void ohosSetPublicUserDir(const std::string &path);
const std::string &ohosGetPublicUserDir();
bool ohosDataPathsReady();
/** HiLog status for Game page overlay (updated from the engine thread). */
const char *ohosEngineStatus();
void ohosEngineStatusSet(const char *status);
/** Throttled HiLog for media/load phases (tag VoxeraLoad). Safe on engine thread. */
void ohosLogMediaProgress(const char *msg);
/** Re-apply settings that must win over minetest.conf before connecting. */
void ohosApplyClientLoadingDefaults();
/** Append numeric exit code without erasing the last phase message. */
void ohosEngineStatusExit(int exitCode);
/** Safe GLES / window defaults before RenderingEngine starts. */
void ohosApplyClientDefaults();
/** Menu gettext when USE_GETTEXT is off (loads locale/zh_CN/LC_MESSAGES/luanti.mo|.po). */
void ohosInitMenuTranslations();
const char *ohosMenuGettext(const char *srctext);
bool ohosGetSurfaceSize(unsigned *width, unsigned *height);
void ohosRequestStart(OH_NativeXComponent *component, void *nativeWindow);
/** Register SDL mouse/keyboard on the Game XComponent (call once from ArkUI onLoad). */
void ohosRegisterXComponentInput(OH_NativeXComponent *component);
void ohosRequestStop();
void ohosInitSdlGlEnv();
/** Apply g_filesDir to path_share/path_user (call before SDL_Main if needed). */
bool ohosRefreshPaths();
/** Re-register surface + clear stale EGL before SDL_CreateWindowFrom. */
void ohosPrepareSdlWindow(OH_NativeXComponent *component);

/** Used by Irrlicht/SDL when creating the render window from the Game XComponent. */
OH_NativeXComponent *ohosGetNativeXComponent();

/** Queue opening a URL in the system browser (ArkTS polls and calls startAbility). */
void ohosRequestOpenUrl(const std::string &url);
/** Queue opening a local folder in the system file manager (ArkTS kind=5). */
void ohosRequestOpenLocalPath(const std::string &path);
/** Queue a zip file pick; result is delivered via ohosDeliverPendingPickResult. */
void ohosRequestPickZipFile(const std::string &formname);
/** When non-empty, ArkTS accepts zip drag-and-drop for this path-select formname. */
void ohosSetZipDropTarget(const std::string &formname);
std::string ohosGetZipDropTarget();
/** Main-menu frame: if a pick finished, fills form/path and returns true. */
bool ohosTakePickResult(std::string &formname, std::string &path, bool &accepted);
/** Queue immersive fullscreen (hide OHOS status/navigation bars). */
void ohosNotifyFullscreen(bool enabled);
/** True when native immersive fullscreen is active (OHOS embedded SDL path). */
bool ohosIsFullscreen();
/** True when POSIX I/O to this path should go through ArkTS fileIo (e.g. Documents). */
bool ohosPathNeedsUiCopy(const std::string &path);
/** Copy directory via ArkTS; blocks until UI thread completes (main-menu install). */
bool ohosCopyDirBlocking(const std::string &src, const std::string &dest);
void ohosCompleteCopyDir(bool ok);
/** NAPI: returns 0=none, 1=openUrl, 2=pickZip, 3=relativeMouse, 4=fullscreen, 5=openLocalPath, 6=copyDir. */
int ohosPollUiRequest(std::string &out);
/** NAPI: path empty means canceled. */
void ohosCompleteFilePick(const std::string &formname, const std::string &path);
/** Forward PC keyboard events from ArkUI into SDL (keycode = OHOS KEYCODE_*). */
void ohosInjectKeyEvent(int keycode, bool down);
/** Drain keys queued by ohosInjectKeyEvent; call once per frame from the SDL thread. */
void ohosPollPendingKeys();
/** Drain relative mouse motion queued from ArkUI; call once per frame from the SDL thread. */
void ohosPollPendingMouse();
/** Forward relative mouse delta from ArkUI onMouse (rawDeltaX/Y). */
void ohosInjectMouseMotion(int dx, int dy);
/** True if ArkUI/NAPI reported this SDL scancode as down (independent of SDL focus). */
bool ohosIsScancodePressed(unsigned scancode);

} // namespace porting

#ifdef __cplusplus
extern "C" {
#endif
OH_NativeXComponent *porting_ohosGetNativeXComponent(void);
bool porting_ohosGetSurfaceSize(unsigned *width, unsigned *height);
void porting_ohosEngineStatusSet(const char *status);
void porting_ohosEngineStatusExit(int exitCode);
const char *porting_ohosEngineStatus(void);
void porting_ohosPrepareSdlWindow(OH_NativeXComponent *component);
#ifdef __cplusplus
}
#endif

#endif
