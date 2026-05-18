#include "egl_preview.h"

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <hilog/log.h>
#include <native_window/external_window.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "VoxeraEGL"

namespace {
EGLDisplay g_display = EGL_NO_DISPLAY;
EGLSurface g_surface = EGL_NO_SURFACE;
EGLContext g_context = EGL_NO_CONTEXT;
bool g_active = false;

bool InitEgl(void *window)
{
    g_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_display == EGL_NO_DISPLAY) {
        OH_LOG_ERROR(LOG_APP, "eglGetDisplay failed");
        return false;
    }

    if (eglInitialize(g_display, nullptr, nullptr) != EGL_TRUE) {
        OH_LOG_ERROR(LOG_APP, "eglInitialize failed");
        return false;
    }

    const EGLint attribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE,
    };

    EGLConfig config = nullptr;
    EGLint numConfigs = 0;
    if (eglChooseConfig(g_display, attribs, &config, 1, &numConfigs) != EGL_TRUE || numConfigs < 1) {
        OH_LOG_ERROR(LOG_APP, "eglChooseConfig failed");
        return false;
    }

    const EGLint contextAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_context = eglCreateContext(g_display, config, EGL_NO_CONTEXT, contextAttribs);
    if (g_context == EGL_NO_CONTEXT) {
        OH_LOG_ERROR(LOG_APP, "eglCreateContext failed");
        return false;
    }

    const EGLNativeWindowType nativeWindow = reinterpret_cast<EGLNativeWindowType>(window);
    g_surface = eglCreateWindowSurface(g_display, config, nativeWindow, nullptr);
    if (g_surface == EGL_NO_SURFACE) {
        OH_LOG_ERROR(LOG_APP, "eglCreateWindowSurface failed");
        return false;
    }

    if (eglMakeCurrent(g_display, g_surface, g_surface, g_context) != EGL_TRUE) {
        OH_LOG_ERROR(LOG_APP, "eglMakeCurrent failed");
        return false;
    }

    return true;
}

void DrawFrame(uint64_t width, uint64_t height)
{
    if (!g_active || g_display == EGL_NO_DISPLAY) {
        return;
    }

    glViewport(0, 0, static_cast<GLsizei>(width), static_cast<GLsizei>(height));
    // Luanti-ish sky + ground tones so screenshots are easy to tell from "empty black"
    glClearColor(0.35f, 0.55f, 0.85f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    eglSwapBuffers(g_display, g_surface);
}

void ShutdownEgl()
{
    if (g_display != EGL_NO_DISPLAY) {
        eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (g_surface != EGL_NO_SURFACE) {
            eglDestroySurface(g_display, g_surface);
            g_surface = EGL_NO_SURFACE;
        }
        if (g_context != EGL_NO_CONTEXT) {
            eglDestroyContext(g_display, g_context);
            g_context = EGL_NO_CONTEXT;
        }
        eglTerminate(g_display);
        g_display = EGL_NO_DISPLAY;
    }
    g_active = false;
}
} // namespace

namespace voxera {

bool EglPreviewStart(OH_NativeXComponent *component, void *window)
{
    if (window == nullptr || component == nullptr) {
        OH_LOG_ERROR(LOG_APP, "EglPreviewStart: null window");
        return false;
    }

    EglPreviewStop();

    if (!InitEgl(window)) {
        return false;
    }

    uint64_t width = 0;
    uint64_t height = 0;
    if (OH_NativeXComponent_GetXComponentSize(component, window, &width, &height) != 0) {
        width = 1;
        height = 1;
    }

    g_active = true;
    DrawFrame(width, height);
    OH_LOG_INFO(LOG_APP, "EglPreviewStart %{public}llu x %{public}llu", width, height);
    return true;
}

void EglPreviewResize(OH_NativeXComponent *component, void *window)
{
    if (!g_active || window == nullptr || component == nullptr) {
        return;
    }

    uint64_t width = 0;
    uint64_t height = 0;
    if (OH_NativeXComponent_GetXComponentSize(component, window, &width, &height) != 0) {
        return;
    }
    DrawFrame(width, height);
}

void EglPreviewStop()
{
    ShutdownEgl();
}

bool EglPreviewIsActive()
{
    return g_active;
}

} // namespace voxera
