// HarmonyOS: touch -> SDL mouse (same path as x86 emulator). ArkUI overlay only.
// SPDX-License-Identifier: LGPL-2.1-or-later

#ifndef __OHOS__
#error This file may only be compiled for HarmonyOS
#endif

#include "ohos_touch_dispatch.h"
#include "settings.h"
#include "porting.h"
#include "porting_ohos.h"
#include <ace/xcomponent/native_interface_xcomponent.h>
#include <cmath>
#include <cstring>
#include <vector>
#include <SDL.h>
#include <hilog/log.h>

extern "C" {
#include "video/SDL_sysvideo.h"
#include "video/ohos/SDL_ohosvideo.h"
#include "video/ohos/SDL_ohosmouse.h"
#include "video/ohos/SDL_ohostouch.h"

extern SDL_mutex *g_ohosPageMutex;

#define OHOS_TOUCH_ACTION_DOWN 0
#define OHOS_TOUCH_ACTION_UP 1
#define OHOS_TOUCH_ACTION_MOVE 2
#define OHOS_TOUCH_ACTION_CANCEL 3

#define OHOS_MOUSE_BUTTON_PRIMARY 0x01
#define OHOS_MOUSE_BUTTON_SECONDARY 0x02

static bool s_pointerDown = false;
static float s_lastPx = 0.0f;
static float s_lastPy = 0.0f;

struct PhoneTouchState {
	bool active = false;
	bool dig_down = false;
	bool moved = false;
	float last_x = 0.0f;
	float last_y = 0.0f;
	float down_x = 0.0f;
	float down_y = 0.0f;
	u64 down_ms = 0;
};

static PhoneTouchState s_phone;

struct HotbarRect {
	u16 index;
	float x1;
	float y1;
	float x2;
	float y2;
};

struct PhoneHotbarTouch {
	bool active = false;
	bool moved = false;
	bool long_drop_fired = false;
	u16 slot = 0;
	float down_x = 0.0f;
	float down_y = 0.0f;
	u64 down_ms = 0;
};

static std::vector<HotbarRect> s_hotbar_rects;
static PhoneHotbarTouch s_hotbar;
static int s_pending_hotbar_select = -1;
static int s_pending_hotbar_drop = -1;
static bool s_menu_hotbar_touch = false;
static u16 s_menu_hotbar_slot = 0;

static constexpr int PHONE_LONG_PRESS_MS = 450;
static constexpr float PHONE_TAP_SLOP_PX = 28.0f;

static float phone_touch_dist(float x1, float y1, float x2, float y2)
{
	const float dx = x2 - x1;
	const float dy = y2 - y1;
	return std::sqrt(dx * dx + dy * dy);
}

static void phone_send_rel_motion(SDL_Window *window, float dx, float dy)
{
	if (!window || (dx == 0.0f && dy == 0.0f))
		return;

	float sens = 1.0f;
	if (g_settings)
		sens = g_settings->getFloat("touchscreen_sensitivity", 0.001f, 10.0f);
	float density = 1.0f;
	if (g_settings)
		density = g_settings->getFloat("display_density_factor", 0.5f, 10.0f);
	if (density <= 0.0f)
		density = 1.0f;
	int mx = (int)lround(dx * sens * 6.0f / density);
	int my = (int)lround(dy * sens * 6.0f / density);
	if (mx == 0 && std::fabs(dx) >= 0.5f)
		mx = dx > 0.0f ? 1 : -1;
	if (my == 0 && std::fabs(dy) >= 0.5f)
		my = dy > 0.0f ? 1 : -1;
	if (mx == 0 && my == 0)
		return;

	static int s_phoneMotionLog = 0;
	if (s_phoneMotionLog < 8) {
		OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPhoneTouch",
				"look rel dx=%{public}d dy=%{public}d", mx, my);
		++s_phoneMotionLog;
	}
	OHOS_DeliverRelativeMouseMotion(window, mx, my);
}

static void phone_send_button(SDL_Window *window, float x, float y, bool down, bool right)
{
	if (!window)
		return;

	OHOSWindowSize ws{};
	memset(&ws, 0, sizeof(ws));
	ws.action = down ? OHOS_MOUSE_ACTION_PRESS : OHOS_MOUSE_ACTION_RELEASE;
	ws.state = right ? OHOS_MOUSE_BUTTON_SECONDARY : OHOS_MOUSE_BUTTON_PRIMARY;
	ws.x = x;
	ws.y = y;
	OHOS_OnMouse(window, &ws, SDL_FALSE);
}

static void phone_try_start_dig(SDL_Window *window, float x, float y)
{
	if (s_phone.dig_down || s_phone.moved)
		return;
	s_phone.dig_down = true;
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPhoneTouch", "dig down (long press)");
	phone_send_button(window, x, y, true, false);
}

static int phone_hit_hotbar_slot(float x, float y)
{
	for (const HotbarRect &r : s_hotbar_rects) {
		if (x >= r.x1 && x <= r.x2 && y >= r.y1 && y <= r.y2)
			return (int)r.index;
	}
	return -1;
}

static void phone_hotbar_try_long_drop(u16 slot)
{
	if (s_hotbar.long_drop_fired)
		return;
	s_hotbar.long_drop_fired = true;
	s_pending_hotbar_drop = (int)slot;
	s_pending_hotbar_select = (int)slot;
	OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPhoneTouch",
			"hotbar drop slot=%{public}u", slot);
}

void ohos_phone_hotbar_reset(void)
{
	s_hotbar_rects.clear();
}

void ohos_phone_hotbar_register_rect(unsigned index, int x1, int y1, int x2, int y2)
{
	s_hotbar_rects.push_back({(u16)index, (float)x1, (float)y1, (float)x2, (float)y2});
}

int ohos_phone_take_hotbar_select(unsigned *out_index)
{
	if (s_pending_hotbar_select < 0)
		return 0;
	if (out_index)
		*out_index = (unsigned)s_pending_hotbar_select;
	s_pending_hotbar_select = -1;
	return 1;
}

int ohos_phone_take_hotbar_drop(unsigned *out_index)
{
	if (s_pending_hotbar_drop < 0)
		return 0;
	if (out_index)
		*out_index = (unsigned)s_pending_hotbar_drop;
	s_pending_hotbar_drop = -1;
	return 1;
}

static SDL_Window *ohos_sdl_window_from_xcomponent(OH_NativeXComponent *component)
{
	char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {};
	uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;

	if (!component ||
			OH_NativeXComponent_GetXComponentId(component, idStr, &idSize) !=
					OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
		SDL_VideoDevice *video = SDL_GetVideoDevice();
		return video ? video->windows : nullptr;
	}

	SDL_VideoDevice *video = SDL_GetVideoDevice();
	if (!video) {
		return nullptr;
	}

	for (SDL_Window *w = video->windows; w; w = w->next) {
		if (!w->xcompentId) {
			continue;
		}
		if (strcmp(idStr, w->xcompentId) == 0) {
			return w;
		}
	}
	return video->windows;
}

static void ohos_surface_pixel_size(OH_NativeXComponent *component, void *nativeWindow,
		SDL_Window *sdlWindow, int *outW, int *outH)
{
	uint64_t w = 0;
	uint64_t h = 0;

	*outW = 0;
	*outH = 0;
	if (component && nativeWindow &&
			OH_NativeXComponent_GetXComponentSize(component, nativeWindow, &w, &h) ==
					OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
		*outW = (int)w;
		*outH = (int)h;
	}
	if ((*outW <= 0 || *outH <= 0) && sdlWindow) {
		*outW = sdlWindow->w;
		*outH = sdlWindow->h;
	}
}

static void ohos_send_mouse(SDL_Window *window, int action, float px, float py, int buttonState)
{
	OHOSWindowSize ws;
	memset(&ws, 0, sizeof(ws));
	ws.x = px;
	ws.y = py;
	ws.state = buttonState;
	ws.action = action;
	OHOS_OnMouse(window, &ws, SDL_FALSE);
}

static void ohos_post_mouse(SDL_Window *window, OH_NativeXComponent *component,
		void *nativeWindow, float x, float y, int action)
{
	int surfW = 0;
	int surfH = 0;
	float px = x;
	float py = y;

	if (action == OHOS_TOUCH_ACTION_MOVE) {
		return;
	}

	ohos_surface_pixel_size(component, nativeWindow, window, &surfW, &surfH);
	if (surfW > 0 && surfH > 0) {
		if (x <= 1.0f && y <= 1.0f && x >= 0.0f && y >= 0.0f) {
			px = x * (float)surfW;
			py = y * (float)surfH;
		}
	}

	if (action == OHOS_TOUCH_ACTION_DOWN) {
		if (porting::ohosGetDeviceFormFactor() == "phone" && porting::ohosIsGameMenuActive()) {
			const int hotbar_slot = phone_hit_hotbar_slot(px, py);
			if (hotbar_slot >= 0) {
				if (s_pointerDown) {
					ohos_send_mouse(window, OHOS_MOUSE_ACTION_RELEASE, s_lastPx, s_lastPy,
							OHOS_MOUSE_BUTTON_PRIMARY);
					s_pointerDown = false;
				}
				s_menu_hotbar_touch = true;
				s_menu_hotbar_slot = (u16)hotbar_slot;
				s_lastPx = px;
				s_lastPy = py;
				return;
			}
		}

		if (s_pointerDown) {
			ohos_send_mouse(window, OHOS_MOUSE_ACTION_RELEASE, s_lastPx, s_lastPy,
					OHOS_MOUSE_BUTTON_PRIMARY);
			s_pointerDown = false;
		}
		ohos_send_mouse(window, OHOS_MOUSE_ACTION_PRESS, px, py, OHOS_MOUSE_BUTTON_PRIMARY);
		s_pointerDown = true;
		s_lastPx = px;
		s_lastPy = py;
		return;
	}

	if (action == OHOS_TOUCH_ACTION_UP || action == OHOS_TOUCH_ACTION_CANCEL) {
		if (s_menu_hotbar_touch) {
			s_pending_hotbar_select = (int)s_menu_hotbar_slot;
			s_menu_hotbar_touch = false;
			s_pointerDown = false;
			s_lastPx = px;
			s_lastPy = py;
			return;
		}

		if (!s_pointerDown) {
			return;
		}
		ohos_send_mouse(window, OHOS_MOUSE_ACTION_RELEASE, px, py, OHOS_MOUSE_BUTTON_PRIMARY);
		s_pointerDown = false;
		s_lastPx = px;
		s_lastPy = py;
	}
}

void ohos_release_stale_pointer(void)
{
	if (s_phone.dig_down) {
		SDL_VideoDevice *video = SDL_GetVideoDevice();
		SDL_Window *window = video ? video->windows : nullptr;
		if (window)
			phone_send_button(window, s_phone.last_x, s_phone.last_y, false, false);
	}
	s_phone = PhoneTouchState{};
	s_hotbar = PhoneHotbarTouch{};
	s_menu_hotbar_touch = false;
	if (!s_pointerDown) {
		return;
	}

	SDL_VideoDevice *video = SDL_GetVideoDevice();
	SDL_Window *window = video ? video->windows : nullptr;
	if (!window) {
		s_pointerDown = false;
		return;
	}

	if (g_ohosPageMutex) {
		SDL_LockMutex(g_ohosPageMutex);
	}
	ohos_send_mouse(window, OHOS_MOUSE_ACTION_RELEASE, s_lastPx, s_lastPy,
			OHOS_MOUSE_BUTTON_PRIMARY);
	if (g_ohosPageMutex) {
		SDL_UnlockMutex(g_ohosPageMutex);
	}
	s_pointerDown = false;
}

void ohos_deliver_pointer_input(OH_NativeXComponent *component, void *nativeWindow,
		float x, float y, int action, int fingerId)
{
	(void)fingerId;
	if (!component) {
		return;
	}

	if (g_ohosPageMutex) {
		SDL_LockMutex(g_ohosPageMutex);
	}
	SDL_Window *curWindow = ohos_sdl_window_from_xcomponent(component);
	if (!curWindow) {
		if (g_ohosPageMutex) {
			SDL_UnlockMutex(g_ohosPageMutex);
		}
		return;
	}

	ohos_post_mouse(curWindow, component, nativeWindow, x, y, action);
	if (g_ohosPageMutex) {
		SDL_UnlockMutex(g_ohosPageMutex);
	}
}

void ohos_forward_xcomponent_touch(OH_NativeXComponent *component, void *window)
{
	OH_NativeXComponent_TouchEvent touchEvent;

	if (!component || !window) {
		return;
	}
	if (OH_NativeXComponent_GetTouchEvent(component, window, &touchEvent) != 0) {
		return;
	}

	ohos_deliver_pointer_input(component, window, touchEvent.x, touchEvent.y,
			touchEvent.type, touchEvent.id);
}

void ohos_deliver_sdl_touch_input(OH_NativeXComponent *component, void *nativeWindow,
		float x, float y, int action, int fingerId)
{
	(void)nativeWindow;
	if (!component) {
		return;
	}

	if (g_ohosPageMutex) {
		SDL_LockMutex(g_ohosPageMutex);
	}
	SDL_Window *window = ohos_sdl_window_from_xcomponent(component);
	if (!window) {
		if (g_ohosPageMutex) {
			SDL_UnlockMutex(g_ohosPageMutex);
		}
		return;
	}

	OhosTouchId touch{};
	touch.touchDeviceIdIn = 1;
	touch.pointerFingerIdIn = fingerId;
	touch.action = action;
	touch.x = x;
	touch.y = y;
	touch.p = 1.0f;
	OHOS_OnTouch(window, &touch);

	if (g_ohosPageMutex) {
		SDL_UnlockMutex(g_ohosPageMutex);
	}
}

void ohos_phone_touch_reset(void)
{
	if (s_phone.dig_down) {
		SDL_VideoDevice *video = SDL_GetVideoDevice();
		SDL_Window *window = video ? video->windows : nullptr;
		if (window)
			phone_send_button(window, s_phone.last_x, s_phone.last_y, false, false);
	}
	s_phone = PhoneTouchState{};
	s_hotbar = PhoneHotbarTouch{};
	s_menu_hotbar_touch = false;
}

void ohos_deliver_phone_game_touch(OH_NativeXComponent *component, void *nativeWindow,
		float x, float y, int action, int fingerId)
{
	(void)fingerId;
	(void)nativeWindow;
	if (!component)
		return;

	if (g_ohosPageMutex)
		SDL_LockMutex(g_ohosPageMutex);
	SDL_Window *window = ohos_sdl_window_from_xcomponent(component);
	if (!window) {
		if (g_ohosPageMutex)
			SDL_UnlockMutex(g_ohosPageMutex);
		return;
	}

	if (action == OHOS_TOUCH_ACTION_DOWN) {
		const int hotbar_slot = phone_hit_hotbar_slot(x, y);
		if (hotbar_slot >= 0) {
			if (s_phone.active && s_phone.dig_down)
				phone_send_button(window, s_phone.last_x, s_phone.last_y, false, false);
			s_phone = PhoneTouchState{};
			s_hotbar = PhoneHotbarTouch{};
			s_hotbar.active = true;
			s_hotbar.slot = (u16)hotbar_slot;
			s_hotbar.down_x = x;
			s_hotbar.down_y = y;
			s_hotbar.down_ms = porting::getTimeMs();
			goto phone_touch_done;
		}

		if (s_hotbar.active)
			s_hotbar = PhoneHotbarTouch{};
		if (s_phone.active && s_phone.dig_down)
			phone_send_button(window, s_phone.last_x, s_phone.last_y, false, false);
		s_phone = PhoneTouchState{};
		s_phone.active = true;
		s_phone.down_x = x;
		s_phone.down_y = y;
		s_phone.last_x = x;
		s_phone.last_y = y;
		s_phone.down_ms = porting::getTimeMs();
	} else if (action == OHOS_TOUCH_ACTION_MOVE) {
		if (s_hotbar.active) {
			if (phone_touch_dist(s_hotbar.down_x, s_hotbar.down_y, x, y) > PHONE_TAP_SLOP_PX)
				s_hotbar.moved = true;
			if (!s_hotbar.moved && !s_hotbar.long_drop_fired &&
					porting::getTimeMs() - s_hotbar.down_ms >= (u64)PHONE_LONG_PRESS_MS) {
				phone_hotbar_try_long_drop(s_hotbar.slot);
			}
			goto phone_touch_done;
		}

		if (!s_phone.active)
			goto phone_touch_done;

		const float dx = x - s_phone.last_x;
		const float dy = y - s_phone.last_y;
		s_phone.last_x = x;
		s_phone.last_y = y;

		if (!s_phone.dig_down &&
				phone_touch_dist(s_phone.down_x, s_phone.down_y, x, y) > PHONE_TAP_SLOP_PX) {
			s_phone.moved = true;
		}

		phone_send_rel_motion(window, dx, dy);

		if (!s_phone.dig_down && !s_phone.moved &&
				porting::getTimeMs() - s_phone.down_ms >= (u64)PHONE_LONG_PRESS_MS) {
			phone_try_start_dig(window, x, y);
		}
	} else if (action == OHOS_TOUCH_ACTION_UP || action == OHOS_TOUCH_ACTION_CANCEL) {
		if (s_hotbar.active) {
			const u64 held = porting::getTimeMs() - s_hotbar.down_ms;
			const float travel = phone_touch_dist(s_hotbar.down_x, s_hotbar.down_y, x, y);
			if (!s_hotbar.long_drop_fired && !s_hotbar.moved &&
					travel <= PHONE_TAP_SLOP_PX && held < (u64)PHONE_LONG_PRESS_MS) {
				s_pending_hotbar_select = (int)s_hotbar.slot;
				OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPhoneTouch",
						"hotbar select slot=%{public}u", s_hotbar.slot);
			}
			s_hotbar = PhoneHotbarTouch{};
			goto phone_touch_done;
		}

		if (!s_phone.active)
			goto phone_touch_done;

		const u64 held = porting::getTimeMs() - s_phone.down_ms;
		const float travel = phone_touch_dist(s_phone.down_x, s_phone.down_y, x, y);

		if (s_phone.dig_down) {
			phone_send_button(window, x, y, false, false);
			OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPhoneTouch", "dig up");
		} else if (!s_phone.moved && travel <= PHONE_TAP_SLOP_PX && held < (u64)PHONE_LONG_PRESS_MS) {
			OH_LOG_Print(LOG_APP, LOG_INFO, 0, "VoxeraPhoneTouch", "place tap (RMB)");
			phone_send_button(window, x, y, true, true);
			phone_send_button(window, x, y, false, true);
		}

		s_phone = PhoneTouchState{};
	}

phone_touch_done:
	if (g_ohosPageMutex)
		SDL_UnlockMutex(g_ohosPageMutex);
}

void ohos_phone_touch_tick(OH_NativeXComponent *component)
{
	const u64 now = porting::getTimeMs();

	if (s_hotbar.active && !s_hotbar.moved && !s_hotbar.long_drop_fired &&
			now - s_hotbar.down_ms >= (u64)PHONE_LONG_PRESS_MS) {
		phone_hotbar_try_long_drop(s_hotbar.slot);
	}

	if (!s_phone.active || s_phone.dig_down || s_phone.moved)
		return;
	if (now - s_phone.down_ms < (u64)PHONE_LONG_PRESS_MS)
		return;

	if (g_ohosPageMutex)
		SDL_LockMutex(g_ohosPageMutex);
	SDL_Window *window = ohos_sdl_window_from_xcomponent(component);
	if (window)
		phone_try_start_dig(window, s_phone.last_x, s_phone.last_y);
	if (g_ohosPageMutex)
		SDL_UnlockMutex(g_ohosPageMutex);
}

} // extern "C"
