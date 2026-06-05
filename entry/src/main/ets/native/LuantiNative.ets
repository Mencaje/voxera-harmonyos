import native from 'libentry.so';

function requireNative(): ESObject {
  if (native === undefined || native === null) {
    throw new Error(
      '原生库 libentry.so 未加载。真机需 arm64-v8a 架构：请在 DevEco 中勾选 arm64 并完整编译 native（entry/ohos_deps/arm64-v8a）。'
    );
  }
  return native;
}

/** kind: 0=none, 1=openUrl, 2=pickZip, 3=relativeMouse, 4=fullscreen, 5=openLocalPath, 6=copyDir, 7=vibrate, 8=textInput */
export interface OhosUiPollResult {
  kind: number;
  payload: string;
}

export function setAppDataPaths(shareDir: string, cacheDir: string, userDir: string): void {
  requireNative().setAppDataPaths(shareDir, cacheDir, userDir);
}

/** Documents mirror; engine path_user remains sandbox. */
export function setPublicUserDataDir(publicUserDir: string): void {
  requireNative().setPublicUserDataDir(publicUserDir);
}

/** phone / tablet / 2in1 — must run before engine thread (see deviceInfo.deviceType). */
export function setDeviceFormFactor(deviceType: string): void {
  requireNative().setDeviceFormFactor(deviceType);
}

export function getEngineStatus(): string {
  return requireNative().getEngineStatus() as string;
}

export function isInGameWorld(): boolean {
  return requireNative().isInGameWorld() as boolean;
}

export function isPlayerInventoryOpen(): boolean {
  return requireNative().isPlayerInventoryOpen() as boolean;
}

export function pollOhosUiRequest(): OhosUiPollResult {
  return requireNative().pollOhosUiRequest() as OhosUiPollResult;
}

export function completeOhosFilePick(formname: string, path: string): void {
  requireNative().completeOhosFilePick(formname, path);
}

/** Non-empty while local zip install dialog accepts drag-and-drop. */
export function getOhosZipDropTarget(): string {
  return requireNative().getOhosZipDropTarget() as string;
}

export function completeOhosCopyDir(ok: boolean): void {
  requireNative().completeOhosCopyDir(ok);
}

export function completeOhosTextInput(canceled: boolean, text: string): void {
  requireNative().completeOhosTextInput(canceled, text);
}

/** OHOS KEYCODE_* (e.g. KEYCODE_W = 2039); down=true for press, false for release. */
export function injectKeyEvent(keyCode: number, down: boolean): void {
  requireNative().injectKeyEvent(keyCode, down);
}

/** Fixed phone in-game HUD actions (ignore user key remapping). */
export const PHONE_GAME_ACTION_INVENTORY: number = 1;
export const PHONE_GAME_ACTION_MINIMAP: number = 2;

export function triggerPhoneGameAction(action: number): void {
  requireNative().triggerPhoneGameAction(action);
}

/** Relative mouse delta from ArkUI onMouse (rawDeltaX/Y), for first-person look. */
export function injectMouseMotion(dx: number, dy: number): void {
  requireNative().injectMouseMotion(dx, dy);
}

/** Surface pixels; action 0=down 1=up 2=move (matches OH_NATIVEXCOMPONENT touch type). */
export function injectTouch(x: number, y: number, action: number, fingerId: number): void {
  requireNative().injectTouch(x, y, action, fingerId);
}

/** Surface pixels; one menu tap (press+release on engine thread). */
export function injectClick(x: number, y: number): void {
  requireNative().injectClick(x, y);
}

export function getNativePauseActive(): boolean {
  return requireNative().getNativePauseActive() as boolean;
}

export function setNativePauseActive(active: boolean): void {
  requireNative().setNativePauseActive(active);
}

export function nativePauseExitMenu(): void {
  requireNative().nativePauseExitMenu();
}

export function nativePauseExitOS(): void {
  requireNative().nativePauseExitOS();
}
