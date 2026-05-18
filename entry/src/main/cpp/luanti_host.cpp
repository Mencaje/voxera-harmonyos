#include "luanti_host.h"
#include "egl_preview.h"

#include <hilog/log.h>
#include <ace/xcomponent/native_interface_xcomponent.h>

#include <atomic>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>

#ifdef VOXERA_LINK_LUANTI
#include "filesys.h"
#include "porting.h"
#include "porting_ohos.h"
extern "C" int SDL_Main(int argc, char *argv[]);
#endif

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "VoxeraLuanti"

namespace {
std::atomic<bool> g_surfaceReady{false};
std::atomic<bool> g_engineRunning{false};
std::string g_status = "阶段1：等待 Surface";

#ifdef VOXERA_LINK_LUANTI
std::mutex g_engineMutex;
std::thread g_engineThread;

void RunEngineThread()
{
    porting::ohosEngineStatusSet("启动 Luanti 引擎…");
    g_status = "Luanti SDL_Main running";
    OH_LOG_INFO(LOG_APP, "Starting Luanti SDL_Main (worker thread)");
    SDL_Main(0, nullptr);
    g_engineRunning = false;
    g_status = "Luanti exited";
}

void RunEngineOnSurfaceThread(OH_NativeXComponent * /*component*/)
{
    porting::ohosRefreshPaths();
    if (!porting::ohosDataPathsReady()) {
        g_status = "阶段4失败：资源路径未就绪（请先等资源解压完成）";
        OH_LOG_ERROR(LOG_APP, "Luanti paths not ready");
        return;
    }

    const std::string builtin_init = porting::path_share + DIR_DELIM "builtin" + DIR_DELIM
            "init.lua";
    if (!fs::PathExists(builtin_init)) {
        porting::ohosEngineStatusSet(
            "缺少 builtin/init.lua：请清除应用数据后重装（见 LuantiAssets v12）");
        OH_LOG_ERROR(LOG_APP, "builtin/init.lua missing: %{public}s (share=%{public}s)",
            builtin_init.c_str(), porting::path_share.c_str());
        return;
    }

    std::lock_guard<std::mutex> lock(g_engineMutex);
    if (g_engineRunning.load()) {
        return;
    }
    if (g_engineThread.joinable()) {
        g_engineThread.join();
    }

    g_engineRunning = true;
    g_engineThread = std::thread(RunEngineThread);
}
#endif
} // namespace

namespace voxera {

void SetAppDataPaths(const char *shareDir, const char *cacheDir, const char *userDir)
{
#ifdef VOXERA_LINK_LUANTI
    porting::ohosSetDataPaths(shareDir ? shareDir : "", cacheDir ? cacheDir : "",
            userDir ? userDir : "");
    g_status = "paths configured";
#else
    (void)shareDir;
    (void)cacheDir;
    (void)userDir;
    g_status = "阶段3：资源路径已设置（引擎未链接）";
#endif
}

void SetPublicUserDataDir(const char *publicUserDir)
{
#ifdef VOXERA_LINK_LUANTI
    porting::ohosSetPublicUserDir(publicUserDir ? publicUserDir : "");
#else
    (void)publicUserDir;
#endif
}

void OnSurfaceCreated(OH_NativeXComponent *component, void *window)
{
    g_surfaceReady = true;
    OH_LOG_INFO(LOG_APP, "XComponent surface created");

#ifdef VOXERA_LINK_LUANTI
    EglPreviewStop();
    porting::ohosRequestStart(component, window);
    /* Do not block the UI thread — page transition / onLoad still run. */
    RunEngineOnSurfaceThread(component);
#else
    if (EglPreviewStart(component, window)) {
        g_status = "阶段3：GPU 正常 + 资源已就绪";
    } else {
        g_status = "阶段3：资源就绪，但 GPU 初始化失败";
    }
#endif
}

void OnSurfaceChanged(OH_NativeXComponent *component, void *window)
{
#ifdef VOXERA_LINK_LUANTI
    if (component && window) {
        porting::ohosRequestStart(component, window);
    }
#else
    EglPreviewResize(component, window);
#endif
}

void OnSurfaceDestroyed()
{
    g_surfaceReady = false;
#ifdef VOXERA_LINK_LUANTI
    porting::ohosRequestStop();
    {
        std::lock_guard<std::mutex> lock(g_engineMutex);
        if (g_engineThread.joinable()) {
            g_engineThread.join();
        }
        g_engineRunning = false;
    }
#else
    EglPreviewStop();
#endif
    g_status = "Surface 已销毁";
}

const char *GetEngineStatus()
{
#ifdef VOXERA_LINK_LUANTI
    const char *phase = porting::ohosEngineStatus();
    if (phase && phase[0] != '\0' && strcmp(phase, "engine idle") != 0)
        return phase;
#endif
    return g_status.c_str();
}

} // namespace voxera
