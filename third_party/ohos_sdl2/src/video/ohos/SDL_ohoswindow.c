/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License,Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "../../SDL_internal.h"
#include "../../core/ohos/SDL_ohosplugin_c.h"
#include "SDL_log.h"
#include "SDL_timer.h"

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <locale.h>
#include <unistd.h>

#define OHOS_EGL_ALPHA_SIZE_DEFAULT 8
#define OHOS_GETWINDOW_DELAY_TIME 2
#define TIMECONSTANT 3000
#define OHOS_WAIT_COUNT 700
#define OHOS_WAIT_TIME 10

#ifdef SDL_VIDEO_DRIVER_OHOS

#include "napi/native_api.h"
#include "SDL_syswm.h"
#include "../SDL_sysvideo.h"
#include "../../events/SDL_keyboard_c.h"
#include "../../events/SDL_mouse_c.h"
#include "../../events/SDL_windowevents_c.h"
#include "../../core/ohos/SDL_ohos.h"
#include "../../core/ohos/SDL_ohosplugin_c.h"

#include "SDL_ohosvideo.h"
#include "SDL_ohoswindow.h"
#include "SDL_hints.h"
#include <pthread.h>

/* Currently only one window */

int OHOS_CreateWindow(SDL_VideoDevice *thisDevice, SDL_Window * window)
{
    napi_ref parentWindowNode = NULL;
    napi_ref childWindowNode = NULL;
    WindowPosition *windowPosition = NULL;
    if (window->ohosHandle == NULL) {
        OHOS_GetRootNode(g_windowId, &parentWindowNode);
        if (parentWindowNode == NULL) {
            return -1;
        }
        windowPosition = (WindowPosition*)SDL_malloc(sizeof(WindowPosition));
        windowPosition->height = window->h;
        windowPosition->width = window->w;
        windowPosition->x = window->x;
        windowPosition->y = window->y;
        OHOS_AddChildNode(parentWindowNode, &childWindowNode, windowPosition);
        SDL_free(windowPosition);
        if (childWindowNode == NULL) {
            return -1;
        }
    } else {
        parentWindowNode = window->ohosHandle;
    }
    OHOS_CreateWindowFrom(thisDevice, window, childWindowNode);
    return 0;
}

void OHOS_SetWindowTitle(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    (void)thisDevice;
    if (!window || !window->title)
        return;
    OHOS_NAPI_SetTitle(window->title);
}

void OHOS_SetWindowFullscreen(SDL_VideoDevice *thisDevice, SDL_Window *window, SDL_VideoDisplay *display,
                              SDL_bool fullscreen)
{
#if defined(__OHOS__) || defined(VOXERA_EMBEDDED_SDL)
    (void)thisDevice;
    (void)window;
    (void)display;
    (void)fullscreen;
    return;
#else
    SDL_WindowData *data;
    SDL_LockMutex(g_ohosPageMutex);

    /* If the window is being destroyed don't change visible state */
    if (!window->is_destroying) {
        OHOS_NAPI_SetWindowStyle(fullscreen);
    }

    data = (SDL_WindowData *)window->driverdata;

    if (!data || !data->native_window) {
        if (data && !data->native_window) {
            SDL_SetError("Missing native window");
        }
        goto endfunction;
    }
#endif /* __OHOS__ || VOXERA_EMBEDDED_SDL */

endfunction:

    SDL_UnlockMutex(g_ohosPageMutex);
}

void OHOS_MinimizeWindow(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
}

void OHOS_DestroyWindow(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    SDL_Log("Destroy window is Calling.");
    SDL_LockMutex(g_ohosPageMutex);

    if (((window->flags & SDL_WINDOW_RECREATE) == 0) &&
        ((window->flags & SDL_WINDOW_FOREIGN_OHOS) == 0)) {
        OHOS_RemoveChildNode(window->ohosHandle);
    }

    if (window->driverdata) {
        SDL_WindowData *data = (SDL_WindowData *)window->driverdata;
        if (data->egl_xcomponent != EGL_NO_SURFACE) {
            SDL_EGL_DestroySurface(thisDevice, data->egl_xcomponent);
        }
        data->egl_xcomponent = EGL_NO_SURFACE;
        SDL_free(window->driverdata);
        window->driverdata = NULL;
    }

    SDL_UnlockMutex(g_ohosPageMutex);

    if (((window->flags & SDL_WINDOW_RECREATE) == 0) &&
        ((window->flags & SDL_WINDOW_FOREIGN_OHOS) == 0)) {
        OHOS_ClearPluginData(window->xcompentId);
    }
}

SDL_bool OHOS_GetWindowWMInfo(SDL_VideoDevice *thisDevice, SDL_Window *window, SDL_SysWMinfo *info)
{
    SDL_WindowData *data = (SDL_WindowData *) window->driverdata;

    if (info->version.major == SDL_MAJOR_VERSION &&
        info->version.minor == SDL_MINOR_VERSION) {
        info->subsystem = SDL_SYSWM_OHOS;
        info->info.ohos.window = data->native_window;
        info->info.ohos.surface = data->egl_xcomponent;
        return SDL_TRUE;
    } else {
        SDL_SetError("Application not compiled with SDL %d.%d",
                     SDL_MAJOR_VERSION, SDL_MINOR_VERSION);
        return SDL_FALSE;
    }
}

void OHOS_SetWindowResizable(SDL_VideoDevice *thisDevice, SDL_Window *window, SDL_bool resizable)
{
    if (resizable) {
        OHOS_NAPI_SetWindowResize(window->windowed.x, window->windowed.y, window->windowed.w, window->windowed.h);
    }
}

void OHOS_SetWindowSize(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    OHOS_ResizeNode(window->ohosHandle, window->w, window->h);
}

void OHOS_SetWindowPosition(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    OHOS_MoveNode(window->ohosHandle, window->x, window->y);
}

void OHOS_ShowWindow(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    (void)thisDevice;
    /* Voxera libraryname XComponent: ohosHandle is OH_NativeXComponent*, not NAPI ref. */
    if (window && (window->flags & SDL_WINDOW_FOREIGN_OHOS)) {
        return;
    }
    OHOS_SetNodeVisibility(window->ohosHandle, 0);
}

void OHOS_HideWindow(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    (void)thisDevice;
    if (window && (window->flags & SDL_WINDOW_FOREIGN_OHOS)) {
        return;
    }
    OHOS_SetNodeVisibility(window->ohosHandle, 1);
}

static void OHOS_WaitGetNativeXcompent(const char *strID, pthread_t tid, OH_NativeXComponent **nativeXComponent)
{
    int cnt = OHOS_WAIT_COUNT;
    while (!OHOS_FindNativeXcomPoment(strID, nativeXComponent)) {
        if (cnt-- == 0) {
            break;
        }
        SDL_Delay(OHOS_WAIT_TIME);
    }
}

static void OHOS_WaitGetNativeWindow(const char *strID, pthread_t tid, SDL_WindowData **windowData,
    OH_NativeXComponent *nativeXComponent)
{
    int cnt = OHOS_WAIT_COUNT;
    while (!OHOS_FindNativeWindow(nativeXComponent, windowData)) {
        if (cnt-- == 0) {
            break;
        }
        SDL_Delay(OHOS_WAIT_TIME);
    }
}

static void OHOS_SetRealWindowPosition(SDL_Window *window, SDL_WindowData *windowData)
{
    window->x = windowData->x;
    window->y = windowData->y;
    window->w = windowData->width;
    window->h = windowData->height;
}

int OHOS_CreateWindowFrom(SDL_VideoDevice *thisDevice, SDL_Window *window, const void *data)
{
    char *strID = NULL;
    pthread_t tid;
    OH_NativeXComponent *nativeXComponent = NULL;
    SDL_WindowData *windowData = NULL;
    SDL_WindowData *sdlWindowData = NULL;
    const void *handle = NULL;
    int retval = 0;

    if (data == NULL && window->ohosHandle == NULL) {
        return SDL_SetError("OHOS_CreateWindowFrom: no handle");
    }
    if (data != NULL && window->ohosHandle == NULL) {
        window->ohosHandle = data;
    }
    handle = data ? data : window->ohosHandle;

    /* Voxera: SDL_CreateWindowFrom passes OH_NativeXComponent*, not NAPI ref. */
    if (handle) {
        OH_NativeXComponent *xc = (OH_NativeXComponent *)handle;
        char idbuf[OH_XCOMPONENT_ID_LEN_MAX + 1];
        uint64_t idSize = sizeof(idbuf);

        if (OH_NativeXComponent_GetXComponentId(xc, idbuf, &idSize) ==
            OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
            strID = SDL_strdup(idbuf);
            nativeXComponent = xc;
            (void)OHOS_FindNativeWindow(nativeXComponent, &windowData);
        }
    }

    if (!windowData) {
        if (!strID) {
            strID = OHOS_GetXComponentId(window->ohosHandle);
        }
        if (!strID && window->ohosHandle) {
            char idbuf[OH_XCOMPONENT_ID_LEN_MAX + 1];
            OH_NativeXComponent *xc = (OH_NativeXComponent *)window->ohosHandle;
            uint64_t idSize = sizeof(idbuf);
            if (OH_NativeXComponent_GetXComponentId(xc, idbuf, &idSize) ==
                OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
                strID = SDL_strdup(idbuf);
            }
        }

        tid = pthread_self();
        if ((window->flags & SDL_WINDOW_RECREATE) == 0) {
            OHOS_AddXcomPomentIdForThread(strID, tid);
            if (!nativeXComponent) {
                OHOS_WaitGetNativeXcompent(strID, tid, &nativeXComponent);
            }
            OHOS_WaitGetNativeWindow(strID, tid, &windowData, nativeXComponent);
        } else {
            OHOS_FindNativeXcomPoment(strID, &nativeXComponent);
            OHOS_FindNativeWindow(nativeXComponent, &windowData);
        }
    }

    window->xcompentId = strID;

    if (windowData == NULL) {
        if (strID) {
            SDL_free(strID);
        }
        return SDL_SetError("OHOS_CreateWindowFrom: native window not ready");
    }

    sdlWindowData = (SDL_WindowData *)SDL_malloc(sizeof(SDL_WindowData));
    if (!sdlWindowData) {
        return -1;
    }
    SDL_zerop(sdlWindowData);

    SDL_LockMutex(g_ohosPageMutex);
    OHOS_SetRealWindowPosition(window, windowData);
    sdlWindowData->native_window = windowData->native_window;
    if (!sdlWindowData->native_window) {
        SDL_free(sdlWindowData);
        retval = -1;
        goto endfunction;
    }

    /* Voxera: SDL_WINDOW_FOREIGN_OHOS from SDL_CreateWindowFrom has no OPENGL until above. */
    if ((window->flags & (SDL_WINDOW_OPENGL | SDL_WINDOW_FOREIGN_OHOS)) != 0) {
        if (thisDevice->gl_config.alpha_size == 0) {
            thisDevice->gl_config.alpha_size = OHOS_EGL_ALPHA_SIZE_DEFAULT;
        }
        if (windowData->egl_xcomponent != EGL_NO_SURFACE) {
            SDL_EGL_DestroySurface(thisDevice, windowData->egl_xcomponent);
            windowData->egl_xcomponent = EGL_NO_SURFACE;
        }
        sdlWindowData->egl_xcomponent =
            (EGLSurface)SDL_EGL_CreateSurface(thisDevice, (NativeWindowType)windowData->native_window);
        windowData->egl_xcomponent = sdlWindowData->egl_xcomponent;
        if (sdlWindowData->egl_xcomponent == EGL_NO_SURFACE) {
            SDL_SetError("OHOS_CreateWindowFrom: EGL surface failed");
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to create eglsurface");
            SDL_free(sdlWindowData);
            retval = -1;
            goto endfunction;
        }
        window->flags |= SDL_WINDOW_OPENGL;
    }
    window->driverdata = sdlWindowData;

    /* Match Android: foreign XComponent windows must be shown and focused or
     * Irrlicht's isWindowActive() stays false and Luanti clears all key state. */
    window->flags &= ~SDL_WINDOW_HIDDEN;
    window->flags |= SDL_WINDOW_SHOWN | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS;
    SDL_SetMouseFocus(window);
    SDL_SetKeyboardFocus(window);
endfunction:
    SDL_UnlockMutex(g_ohosPageMutex);
    return retval;
}

char *OHOS_GetWindowTitle(SDL_VideoDevice *thisDevice, SDL_Window *window)
{
    char *title = NULL;
    title = window->title;
    SDL_Log("sdlthread OHOS_GetWindowTitle");
    if (title) {
        return title;
    } else {
        return "Title is NULL";
    }
}
#endif /* SDL_VIDEO_DRIVER_OHOS */

/* vi: set ts=4 sw=4 expandtab: */
