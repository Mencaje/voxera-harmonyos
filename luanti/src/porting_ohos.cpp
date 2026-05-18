// Luanti — HarmonyOS port (Voxera)
// SPDX-License-Identifier: LGPL-2.1-or-later

#ifndef __OHOS__
#error This file may only be compiled for HarmonyOS
#endif

#include "porting_ohos.h"
#include <ace/xcomponent/native_interface_xcomponent.h>
#include <hilog/log.h>
#include "core/ohos/SDL_ohos_voxerabridge.h"
#include "video/ohos/SDL_ohosmouse.h"
#include "porting.h"
#include "config.h"
#include "settings.h"
#include "filesys.h"
#include <cstring>
#include "log.h"
#include "threading/thread.h"
#include "util/numeric.h"
#include "util/string.h"
#include "translation.h"

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <array>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <string>

#define SDL_MAIN_HANDLED 1
#include <SDL.h>

enum class OhosUiRequestKind : int {
	None = 0,
	OpenUrl = 1,
	PickZip = 2,
	RelativeMouse = 3,
	Fullscreen = 4,
	OpenLocalPath = 5,
	CopyDir = 6,
};

namespace {
std::mutex g_ohosUiMutex;
OhosUiRequestKind g_ohosUiPending = OhosUiRequestKind::None;
std::string g_ohosUiPayload;
std::string g_ohosPickFormname;
std::string g_ohosPickPath;
bool g_ohosPickReady = false;
bool g_ohosPickAccepted = false;
std::string g_ohosZipDropFormname;

std::mutex g_ohosCopyMutex;
std::condition_variable g_ohosCopyCv;
bool g_ohosCopyDone = false;
bool g_ohosCopyOk = false;

struct OhosPendingKey {
	int keycode;
	bool down;
};

std::mutex g_ohosKeyMutex;
std::deque<OhosPendingKey> g_pendingKeys;
constexpr size_t OHOS_MAX_PENDING_KEYS = 512;
constexpr size_t OHOS_MAX_KEYS_DRAIN_PER_FRAME = 64;
constexpr size_t OHOS_KEY_DRAIN_BURST_THRESHOLD = 32;

std::mutex g_heldScanMutex;
std::array<bool, SDL_NUM_SCANCODES> g_heldScancodes{};

struct OhosPendingMouseMotion {
	int dx;
	int dy;
};

std::mutex g_ohosMouseMutex;
std::deque<OhosPendingMouseMotion> g_pendingMouse;
constexpr size_t OHOS_MAX_PENDING_MOUSE = 256;
constexpr size_t OHOS_MAX_MOUSE_DRAIN_PER_FRAME = 128;

std::atomic<bool> g_relativeMouseUiDirty{false};
std::atomic<bool> g_relativeMouseUiWant{false};
std::atomic<bool> g_fullscreenUiDirty{false};
std::atomic<bool> g_fullscreenUiWant{false};
std::atomic<bool> g_ohosFullscreenActive{false};

static void ohosOnRelativeMouseModeChanged(int enabled)
{
	g_relativeMouseUiWant = enabled != 0;
	g_relativeMouseUiDirty.store(true);
}

/** Map HarmonyOS KEYCODE_* (same as SDL OHOS driver) to SDL_Scancode. */
static int ohosKeycodeToScancode(int keycode)
{
	if (keycode >= 2017 && keycode <= 2042)
		return SDL_SCANCODE_A + (keycode - 2017);
	if (keycode >= 2000 && keycode <= 2009)
		return SDL_SCANCODE_0 + (keycode - 2000);
	if (keycode >= 2090 && keycode <= 2101)
		return SDL_SCANCODE_F1 + (keycode - 2090);
	switch (keycode) {
	case 2050: return SDL_SCANCODE_SPACE;
	case 2054: return SDL_SCANCODE_RETURN;
	case 2070: return SDL_SCANCODE_ESCAPE;
	case 2047: return SDL_SCANCODE_LSHIFT;
	case 2048: return SDL_SCANCODE_RSHIFT;
	case 2072: return SDL_SCANCODE_LCTRL;
	case 2073: return SDL_SCANCODE_RCTRL;
	case 2045: return SDL_SCANCODE_LALT;
	case 2046: return SDL_SCANCODE_RALT;
	case 2049: return SDL_SCANCODE_TAB;
	case 2012: return SDL_SCANCODE_UP;
	case 2013: return SDL_SCANCODE_DOWN;
	case 2014: return SDL_SCANCODE_LEFT;
	case 2015: return SDL_SCANCODE_RIGHT;
	default: return SDL_SCANCODE_UNKNOWN;
	}
}

static void ohosUpdateHeldScancode(int keycode, bool down)
{
	const int sc = ohosKeycodeToScancode(keycode);
	if (sc <= SDL_SCANCODE_UNKNOWN || sc >= SDL_NUM_SCANCODES)
		return;
	std::lock_guard<std::mutex> lock(g_heldScanMutex);
	g_heldScancodes[sc] = down;
}

} // namespace

extern int main(int argc, char *argv[]);

#include "video/ohos/SDL_ohoskeyboard.h"

extern "C" {

void OHOS_QueueKeyEvent(int keycode, int down)
{
	ohosUpdateHeldScancode(keycode, down != 0);
	std::lock_guard<std::mutex> lock(g_ohosKeyMutex);
	while (g_pendingKeys.size() >= OHOS_MAX_PENDING_KEYS)
		g_pendingKeys.pop_front();
	g_pendingKeys.push_back({keycode, down != 0});
}

void OHOS_FlushQueuedKeyEvents(void)
{
	std::deque<OhosPendingKey> batch;
	{
		std::lock_guard<std::mutex> lock(g_ohosKeyMutex);
		const size_t backlog = g_pendingKeys.size();
		const size_t limit = backlog > OHOS_KEY_DRAIN_BURST_THRESHOLD
				? backlog
				: OHOS_MAX_KEYS_DRAIN_PER_FRAME;
		const size_t n = std::min(backlog, limit);
		batch.resize(n);
		for (size_t i = 0; i < n; ++i) {
			batch[i] = g_pendingKeys.front();
			g_pendingKeys.pop_front();
		}
	}
	for (const auto &k : batch) {
		static int s_flushLogCount = 0;
		if (s_flushLogCount < 8) {
			OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraInput",
					"flush kc=%{public}d down=%{public}d", k.keycode, k.down ? 1 : 0);
			++s_flushLogCount;
		}
		if (k.down)
			OHOS_OnKeyDown(k.keycode);
		else
			OHOS_OnKeyUp(k.keycode);
	}
}

void OHOS_QueueMouseMotion(int dx, int dy)
{
	if (dx == 0 && dy == 0)
		return;
	std::lock_guard<std::mutex> lock(g_ohosMouseMutex);
	while (g_pendingMouse.size() >= OHOS_MAX_PENDING_MOUSE)
		g_pendingMouse.pop_front();
	g_pendingMouse.push_back({dx, dy});
}

void OHOS_FlushQueuedMouseEvents(void)
{
	std::deque<OhosPendingMouseMotion> batch;
	{
		std::lock_guard<std::mutex> lock(g_ohosMouseMutex);
		const size_t n = std::min(g_pendingMouse.size(), OHOS_MAX_MOUSE_DRAIN_PER_FRAME);
		batch.resize(n);
		for (size_t i = 0; i < n; ++i) {
			batch[i] = g_pendingMouse.front();
			g_pendingMouse.pop_front();
		}
	}
	if (batch.empty())
		return;

	SDL_Window *window = SDL_GetMouseFocus();
	if (!window)
		window = SDL_GetKeyboardFocus();
	if (!window)
		return;

	for (const auto &m : batch) {
		static int s_mouseLogCount = 0;
		if (s_mouseLogCount < 8) {
			OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraInput",
					"mouse rel dx=%{public}d dy=%{public}d", m.dx, m.dy);
			++s_mouseLogCount;
		}
		OHOS_DeliverRelativeMouseMotion(window, m.dx, m.dy);
	}
}

} // extern "C"

namespace {
std::mutex g_windowMutex;
OH_NativeXComponent *g_nativeXComponent = nullptr;
void *g_nativeWindow = nullptr;
std::atomic<bool> g_runRequested{false};
std::atomic<bool> g_running{false};
std::string g_filesDir;
std::string g_cacheDir;
std::string g_userDir;
/** Documents mirror for「打开用户数据目录」; engine uses g_userDir (sandbox). */
std::string g_publicUserDir;
std::atomic<bool> g_pathsReady{false};
std::string g_engineStatus = "engine idle";
Translations g_ohosMenuTranslations;
bool g_ohosMenuTranslationsLoaded = false;

static std::string ohosUserDataDir(const std::string &shareDir)
{
	// Installed games/worlds live outside luanti_share so asset reinstalls do not wipe them.
	const std::string marker = std::string(DIR_DELIM) + "luanti_share";
	if (shareDir.size() > marker.size() &&
			shareDir.compare(shareDir.size() - marker.size(), marker.size(), marker) == 0) {
		return shareDir.substr(0, shareDir.size() - marker.size()) + std::string(DIR_DELIM) + "luanti_user";
	}
	const auto pos = shareDir.find_last_of("/\\");
	if (pos != std::string::npos)
		return shareDir.substr(0, pos) + std::string(DIR_DELIM) + "luanti_user";
	return shareDir + std::string(DIR_DELIM) + "luanti_user";
}

bool setupOhosPaths()
{
	if (g_filesDir.empty())
		return false;

	porting::path_share = g_filesDir;
	porting::path_user = !g_userDir.empty() ? g_userDir : ohosUserDataDir(g_filesDir);
	porting::path_cache = g_cacheDir.empty() ? g_filesDir : g_cacheDir;
	porting::path_locale = porting::path_share + DIR_DELIM + "locale";

	infostream << "OHOS path_share=" << porting::path_share
			<< " path_user=" << porting::path_user
			<< " path_cache=" << porting::path_cache << std::endl;
	return true;
}

} // namespace

extern "C" int SDL_Main(int /*argc*/, char ** /*argv*/)
{
	SDL_SetMainReady();
	Thread::setName("LuantiMain");
	porting::ohosRefreshPaths();
	porting::ohosEngineStatusSet("SDL_Main: enter");

	char *argv[] = {strdup(PROJECT_NAME), strdup("--verbose"), nullptr};
	const int retval = main(ARRLEN(argv) - 1, argv);
	free(argv[0]);
	free(argv[1]);

	g_running = false;
	if (retval == 0)
		porting::ohosEngineStatusSet("SDL_Main: exit ok");
	else
		porting::ohosEngineStatusExit(retval);
	infostream << "Luanti SDL_Main exit " << retval << std::endl;
	return retval;
}

namespace porting {

void ohosSetDataPaths(const std::string &shareDir, const std::string &cacheDir,
		const std::string &userDir)
{
	g_filesDir = shareDir;
	g_cacheDir = cacheDir;
	g_userDir = userDir;
	g_pathsReady = !g_filesDir.empty();
	if (!ohosRefreshPaths()) {
		ohosEngineStatusSet("资源目录未设置（luanti_share）");
	}
}

void ohosSetPublicUserDir(const std::string &path)
{
	g_publicUserDir = path;
}

const std::string &ohosGetPublicUserDir()
{
	return g_publicUserDir;
}

bool ohosDataPathsReady()
{
	return g_pathsReady.load();
}

void ohosEngineStatusSet(const char *status)
{
	if (status)
		g_engineStatus = status;
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraLuanti", "%{public}s", status ? status : "");
}

void ohosLogMediaProgress(const char *msg)
{
	if (!msg || !msg[0])
		return;
	static u64 s_last_ms = 0;
	const u64 now = porting::getTimeMs();
	if (s_last_ms && porting::getDeltaMs(s_last_ms, now) < 500)
		return;
	s_last_ms = now;
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraLoad", "%{public}s", msg);
	ohosEngineStatusSet(msg);
}

void ohosApplyClientLoadingDefaults()
{
	if (!g_settings)
		return;
	g_settings->setBool("enable_remote_media_server", false);
	g_settings->setBool("ipv6_server", false);
	g_settings->set("curl_timeout", "30000");
}

void ohosEngineStatusExit(int exitCode)
{
	if (g_engineStatus.find("SDL_Main exit") == std::string::npos) {
		char buf[384];
		snprintf(buf, sizeof(buf), "SDL_Main exit %d: %s", exitCode, g_engineStatus.c_str());
		g_engineStatus = buf;
	}
	OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "VoxeraLuanti", "%{public}s", g_engineStatus.c_str());
}

static void ohosSetFontPath(const char *setting, const char *rel)
{
	const std::string path = porting::getDataPath(rel);
	g_settings->set(setting, path);
}

void ohosApplyClientDefaults()
{
	if (!g_settings)
		return;
	g_settings->set("video_driver", "ogles2");
	g_settings->setBool("fullscreen", false);
	g_settings->setBool("enable_post_processing", false);
	g_settings->set("antialiasing", "none");
	/* Emulator GPU is often slow; vsync + high view range causes slideshow FPS. */
	g_settings->setBool("vsync", false);
	g_settings->set("viewing_range", "72");
	g_settings->setBool("enable_3d_clouds", false);
	g_settings->setBool("enable_fog", true);
	g_settings->setBool("enable_dynamic_shadows", false);
	g_settings->setBool("enable_bloom", false);
	g_settings->setBool("enable_volumetric_lighting", false);
	g_settings->setBool("enable_water_reflections", false);

	g_settings->set("language", "zh_CN");
	g_settings->setFloat("gui_scaling", 1.12f);
	/* Hotbar + hearts/hunger cluster; independent of menu formspec scale. */
	g_settings->setFloat("hud_scaling", 1.12f);
	g_settings->setFloat("display_density_factor", 1.0f);
	/* Font shadow smears on GLES2 menu (white flickering bars in formspec). */
	g_settings->set("font_shadow", "0");
	g_settings->setBool("gui_scaling_filter", false);
	/* 2in1 / PC emulator: keyboard + mouse, not phone touch overlay. */
	g_settings->setBool("touch_gui", false);
	g_settings->setBool("show_debug", false);
	/* XComponent focus is unreliable; avoid opening pause menu every frame. */
	g_settings->setBool("pause_on_lost_focus", false);

	/*
	 * OHOS uses Android NDK static libcurl+mbedTLS without a packaged CA store.
	 * HTTPS to ContentDB / public server list fails verification otherwise.
	 */
	g_settings->setBool("curl_verify_cert", false);
	/*
	 * HarmonyOS often has no usable IPv6 for games; defaults still set ipv6_server=true
	 * which binds "::" and fails hosting with "IPv6 is disabled".
	 */
	g_settings->setBool("enable_ipv6", false);
	g_settings->setBool("ipv6_server", false);
	g_settings->set("bind_address", "0.0.0.0");
	g_settings->set("curl_timeout", "30000");
	/*
	 * Remote media (index.mth + CDN) can stall "Media..." on 2in1 emulators:
	 * HTTP hangs until timeout while m_httpfetch_active > 0, so the client
	 * never falls back to server push. Local/singleplayer works via protocol.
	 */
	g_settings->setBool("enable_remote_media_server", false);

	/* CJK-capable primary font — Arimo-only triggers slow per-glyph fallback. */
	ohosSetFontPath("font_path", "fonts" DIR_DELIM "DroidSansFallbackFull.ttf");
	ohosSetFontPath("font_path_italic", "fonts" DIR_DELIM "DroidSansFallbackFull.ttf");
	ohosSetFontPath("font_path_bold", "fonts" DIR_DELIM "DroidSansFallbackFull.ttf");
	ohosSetFontPath("font_path_bold_italic", "fonts" DIR_DELIM "DroidSansFallbackFull.ttf");
	/* Use Regular for all mono variants — Bold/Italic files may be absent on device. */
	ohosSetFontPath("mono_font_path", "fonts" DIR_DELIM "Cousine-Regular.ttf");
	ohosSetFontPath("mono_font_path_italic", "fonts" DIR_DELIM "Cousine-Regular.ttf");
	ohosSetFontPath("mono_font_path_bold", "fonts" DIR_DELIM "Cousine-Regular.ttf");
	ohosSetFontPath("mono_font_path_bold_italic", "fonts" DIR_DELIM "Cousine-Regular.ttf");
	ohosSetFontPath("fallback_font_path", "fonts" DIR_DELIM "Arimo-Regular.ttf");

	const std::string main_font = porting::getDataPath("fonts" DIR_DELIM "Arimo-Regular.ttf");
	if (!fs::PathExists(main_font)) {
		char buf[512];
		snprintf(buf, sizeof(buf), "缺少字体: %s", main_font.c_str());
		ohosEngineStatusSet(buf);
	}

	const std::string cloud_vs = porting::getDataPath("client" DIR_DELIM "shaders" DIR_DELIM
			"cloud_shader" DIR_DELIM "opengl_vertex.glsl");
	if (!fs::PathExists(cloud_vs)) {
		char buf[512];
		snprintf(buf, sizeof(buf), "缺少着色器: %s", cloud_vs.c_str());
		ohosEngineStatusSet(buf);
	}

	const std::string shaders = porting::getDataPath("client" DIR_DELIM "shaders" DIR_DELIM
			"Irrlicht");
	if (!fs::PathExists(shaders))
		ohosEngineStatusSet("缺少资源: client/shaders/Irrlicht");

	const std::string builtin_init = porting::path_share + DIR_DELIM "builtin" + DIR_DELIM
			"init.lua";
	if (!fs::PathExists(builtin_init)) {
		ohosEngineStatusSet("缺少 builtin/init.lua（请清除应用数据后重装 HAP）");
		return;
	}
	const std::string mainmenu_init = porting::path_share + DIR_DELIM "builtin" + DIR_DELIM
			"mainmenu" + DIR_DELIM "init.lua";
	if (!fs::PathExists(mainmenu_init))
		ohosEngineStatusSet("缺少 builtin/mainmenu/init.lua（请运行 pack_luanti_assets.ps1）");

	ohosInitMenuTranslations();
}

void ohosInitMenuTranslations()
{
	if (g_ohosMenuTranslationsLoaded)
		return;

	const char *candidates[] = {
		"locale" DIR_DELIM "zh_CN" DIR_DELIM "LC_MESSAGES" DIR_DELIM "luanti.mo",
		"locale" DIR_DELIM "zh_CN" DIR_DELIM "LC_MESSAGES" DIR_DELIM "luanti.po",
		nullptr,
	};

	for (const char **p = candidates; *p; ++p) {
		const std::string path = porting::getDataPath(*p);
		std::string data;
		if (!fs::ReadFile(path, data) || data.empty())
			continue;

		const char *base = fs::GetFilenameFromPath(path.c_str());
		g_ohosMenuTranslations.loadTranslation(base ? base : "luanti.mo", data);
#if CHECK_CLIENT_BUILD()
		if (g_client_translations)
			g_client_translations->loadTranslation(base ? base : "luanti.mo", data);
#endif
		g_ohosMenuTranslationsLoaded = true;
		infostream << "OHOS menu translations loaded from " << path
				<< " (" << g_ohosMenuTranslations.size() << " entries)" << std::endl;
		return;
	}

	warningstream << "OHOS: no zh_CN menu translations under " << porting::path_share
			<< " (UI stays English until locale is packaged)" << std::endl;
}

const char *ohosMenuGettext(const char *srctext)
{
	thread_local std::string storage;
	if (!srctext || !*srctext)
		return "";
	if (!g_ohosMenuTranslationsLoaded)
		return srctext;

	const std::wstring src = utf8_to_wide(srctext);
	const std::wstring &translated =
			g_ohosMenuTranslations.getTranslation(L"luanti", src);
	if (translated == src)
		return srctext;
	storage = wide_to_utf8(translated);
	return storage.c_str();
}

bool ohosRefreshPaths()
{
	return setupOhosPaths();
}

const char *ohosEngineStatus()
{
	return g_engineStatus.c_str();
}

bool ohosGetSurfaceSize(unsigned *width, unsigned *height)
{
	if (!width || !height)
		return false;

	std::lock_guard<std::mutex> lock(g_windowMutex);
	if (!g_nativeXComponent || !g_nativeWindow)
		return false;

	uint64_t w = 0;
	uint64_t h = 0;
	if (OH_NativeXComponent_GetXComponentSize(g_nativeXComponent, g_nativeWindow, &w, &h) !=
			OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
		w = 1280;
		h = 720;
	}
	*width = static_cast<unsigned>(w);
	*height = static_cast<unsigned>(h);
	return true;
}

void ohosRegisterXComponentInput(OH_NativeXComponent *component)
{
	if (!component)
		return;
	OHOS_VoxeraSetRelativeMouseNotifier(ohosOnRelativeMouseModeChanged);
	if (!OHOS_VoxeraRegisterInputCallbacks(component)) {
		warningstream << "OHOS_VoxeraRegisterInputCallbacks failed" << std::endl;
	}
}

void ohosRequestStart(OH_NativeXComponent *component, void *nativeWindow)
{
	if (component && nativeWindow) {
		if (!OHOS_VoxeraRegisterSurface(component, nativeWindow)) {
			errorstream << "OHOS_VoxeraRegisterSurface failed" << std::endl;
		}
		OHOS_VoxeraNotifySurfaceChanged(component, nativeWindow);
		std::lock_guard<std::mutex> lock(g_windowMutex);
		g_nativeXComponent = component;
		g_nativeWindow = nativeWindow;
	}
	g_runRequested = true;
}

void ohosRequestStop()
{
	g_runRequested = false;
	if (volatile auto *kill = signal_handler_killstatus())
		*kill = 1;
}

void ohosInitSdlGlEnv()
{
	/* SDL_egl.c defaults to Linux libGLESv2.so.2 without these — fails on OHOS. */
	setenv("SDL_VIDEODRIVER", "OHOS", 1);
	setenv("SDL_VIDEO_GL_DRIVER", "libGLESv3.so", 1);
	setenv("SDL_VIDEO_EGL_DRIVER", "libEGL.so", 1);
	/* Luanti owns the XComponent EGL surface; skip SDL OHOS pause EGL teardown. */
	SDL_SetHint(SDL_HINT_VIDEO_EXTERNAL_CONTEXT, "1");
}

void ohosPrepareSdlWindow(OH_NativeXComponent *component)
{
	if (!component)
		return;

	std::lock_guard<std::mutex> lock(g_windowMutex);
	void *nativeWindow = g_nativeWindow;
	if (nativeWindow) {
		OHOS_VoxeraRegisterSurface(component, nativeWindow);
	}
	OHOS_VoxeraClearPluginEgl(component);
}

void osSpecificInit()
{
	unsetenv("LANGUAGE");
	setenv("LANG", "C.UTF-8", 1);
	ohosInitSdlGlEnv();
}

bool setSystemPaths()
{
	return setupOhosPaths();
}

OH_NativeXComponent *ohosGetNativeXComponent()
{
	std::lock_guard<std::mutex> lock(g_windowMutex);
	return g_nativeXComponent;
}

void ohosRequestOpenUrl(const std::string &url)
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	g_ohosUiPending = OhosUiRequestKind::OpenUrl;
	g_ohosUiPayload = url;
}

void ohosRequestOpenLocalPath(const std::string &path)
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	g_ohosUiPending = OhosUiRequestKind::OpenLocalPath;
	g_ohosUiPayload = path;
}

static bool ohosPathNeedsUiFileOps(const std::string &path)
{
	if (path.empty())
		return false;
	// App sandbox is writable from native POSIX; public Documents is not.
	if (path.rfind("/data/storage/", 0) == 0)
		return false;
	return path.find("/Documents/") != std::string::npos ||
			path.rfind("/storage/Users/", 0) == 0;
}

bool ohosPathNeedsUiCopy(const std::string &path)
{
	return ohosPathNeedsUiFileOps(path);
}

bool ohosCopyDirBlocking(const std::string &src, const std::string &dest)
{
	{
		std::lock_guard<std::mutex> lock(g_ohosCopyMutex);
		g_ohosCopyDone = false;
		g_ohosCopyOk = false;
	}
	{
		std::lock_guard<std::mutex> lock(g_ohosUiMutex);
		g_ohosUiPending = OhosUiRequestKind::CopyDir;
		g_ohosUiPayload = src + '\n' + dest;
	}
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPorting",
			"ohosCopyDirBlocking wait %{public}s -> %{public}s",
			src.c_str(), dest.c_str());

	std::unique_lock<std::mutex> lock(g_ohosCopyMutex);
	const bool finished = g_ohosCopyCv.wait_for(lock, std::chrono::minutes(15),
			[] { return g_ohosCopyDone; });
	if (!finished) {
		OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "VoxeraPorting",
				"ohosCopyDirBlocking timeout");
		return false;
	}
	return g_ohosCopyOk;
}

void ohosCompleteCopyDir(bool ok)
{
	{
		std::lock_guard<std::mutex> lock(g_ohosCopyMutex);
		g_ohosCopyOk = ok;
		g_ohosCopyDone = true;
	}
	g_ohosCopyCv.notify_one();
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPorting",
			"ohosCompleteCopyDir ok=%{public}d", ok ? 1 : 0);
}

void ohosRequestPickZipFile(const std::string &formname)
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	g_ohosUiPending = OhosUiRequestKind::PickZip;
	g_ohosUiPayload = formname;
}

void ohosSetZipDropTarget(const std::string &formname)
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	g_ohosZipDropFormname = formname;
}

std::string ohosGetZipDropTarget()
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	return g_ohosZipDropFormname;
}

void ohosNotifyFullscreen(bool enabled)
{
	g_fullscreenUiWant = enabled;
	g_ohosFullscreenActive.store(enabled);
	g_fullscreenUiDirty.store(true);
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPorting",
			"ohosNotifyFullscreen enabled=%{public}d", enabled ? 1 : 0);
}

bool ohosIsFullscreen()
{
	return g_ohosFullscreenActive.load();
}

int ohosPollUiRequest(std::string &out)
{
	if (g_relativeMouseUiDirty.exchange(false)) {
		out = g_relativeMouseUiWant.load() ? "1" : "0";
		return static_cast<int>(OhosUiRequestKind::RelativeMouse);
	}
	if (g_fullscreenUiDirty.exchange(false)) {
		out = g_fullscreenUiWant.load() ? "1" : "0";
		return static_cast<int>(OhosUiRequestKind::Fullscreen);
	}

	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	const auto kind = g_ohosUiPending;
	if (kind == OhosUiRequestKind::None)
		return 0;
	out = g_ohosUiPayload;
	g_ohosUiPending = OhosUiRequestKind::None;
	return static_cast<int>(kind);
}

void ohosCompleteFilePick(const std::string &formname, const std::string &path)
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	g_ohosPickFormname = formname;
	g_ohosPickPath = path;
	g_ohosPickAccepted = !path.empty();
	g_ohosPickReady = true;
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraLuanti",
			"file pick %{public}s -> %{public}s",
			formname.c_str(), path.empty() ? "(canceled)" : path.c_str());
}

void ohosInjectKeyEvent(int keycode, bool down)
{
	OHOS_QueueKeyEvent(keycode, down ? 1 : 0);
}

void ohosPollPendingKeys()
{
	OHOS_FlushQueuedKeyEvents();
}

void ohosPollPendingMouse()
{
	OHOS_FlushQueuedMouseEvents();
}

void ohosInjectMouseMotion(int dx, int dy)
{
	OHOS_QueueMouseMotion(dx, dy);
}

bool ohosIsScancodePressed(unsigned scancode)
{
	if (scancode <= SDL_SCANCODE_UNKNOWN || scancode >= SDL_NUM_SCANCODES)
		return false;
	std::lock_guard<std::mutex> lock(g_heldScanMutex);
	return g_heldScancodes[scancode];
}

bool ohosTakePickResult(std::string &formname, std::string &path, bool &accepted)
{
	std::lock_guard<std::mutex> lock(g_ohosUiMutex);
	if (!g_ohosPickReady)
		return false;
	formname = g_ohosPickFormname;
	path = g_ohosPickPath;
	accepted = g_ohosPickAccepted;
	g_ohosPickReady = false;
	return true;
}

} // namespace porting

extern "C" OH_NativeXComponent *porting_ohosGetNativeXComponent(void)
{
	return porting::ohosGetNativeXComponent();
}

extern "C" bool porting_ohosGetSurfaceSize(unsigned *width, unsigned *height)
{
	return porting::ohosGetSurfaceSize(width, height);
}

extern "C" void porting_ohosEngineStatusSet(const char *status)
{
	porting::ohosEngineStatusSet(status);
}

extern "C" void porting_ohosEngineStatusExit(int exitCode)
{
	porting::ohosEngineStatusExit(exitCode);
}

extern "C" const char *porting_ohosEngineStatus(void)
{
	return porting::ohosEngineStatus();
}

extern "C" void porting_ohosPrepareSdlWindow(OH_NativeXComponent *component)
{
	porting::ohosPrepareSdlWindow(component);
}
