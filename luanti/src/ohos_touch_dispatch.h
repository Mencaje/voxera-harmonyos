// HarmonyOS touch/pointer input for Luanti (ArkUI onTouch + optional XComponent callback).
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#ifdef __OHOS__

struct OH_NativeXComponent;

#ifdef __cplusplus
extern "C" {
#endif

#define OHOS_POINTER_DOWN 0
#define OHOS_POINTER_UP 1
#define OHOS_POINTER_MOVE 2
#define OHOS_POINTER_CANCEL 3

/** action: OHOS_POINTER_* . x/y in surface pixels. */
void ohos_deliver_pointer_input(struct OH_NativeXComponent *component, void *nativeWindow,
		float x, float y, int action, int fingerId);

void ohos_forward_xcomponent_touch(struct OH_NativeXComponent *component, void *window);

/** Release stuck left button after tab/dialog changes (HarmonyOS menu stability). */
void ohos_release_stale_pointer(void);

/** Deliver touch as SDL touch events (TouchControls in-game). x/y in surface pixels. */
void ohos_deliver_sdl_touch_input(struct OH_NativeXComponent *component, void *nativeWindow,
		float x, float y, int action, int fingerId);

/** Phone in-game: swipe=look, long-press=LMB dig, tap=RMB place. x/y in surface pixels. */
void ohos_deliver_phone_game_touch(struct OH_NativeXComponent *component, void *nativeWindow,
		float x, float y, int action, int fingerId);

/** Clear phone touch gesture state (menu/dialog transitions). */
void ohos_phone_touch_reset(void);

/** Call each frame while phone in-game touch is active (long-press without move). */
void ohos_phone_touch_tick(struct OH_NativeXComponent *component);

/** Clear hotbar slot rects (call at start of each hotbar draw). */
void ohos_phone_hotbar_reset(void);

/** Register one hotbar slot screen rect (surface pixels, inclusive bounds). */
void ohos_phone_hotbar_register_rect(unsigned index, int x1, int y1, int x2, int y2);

/** Consume tap-to-select; returns 1 and writes 0-based slot index if pending. */
int ohos_phone_take_hotbar_select(unsigned *out_index);

/** Consume long-press drop; returns 1 and writes 0-based slot index if pending. */
int ohos_phone_take_hotbar_drop(unsigned *out_index);

#ifdef __cplusplus
}
#endif

#endif /* __OHOS__ */
