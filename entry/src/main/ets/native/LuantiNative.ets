import native from 'libentry.so';

/** kind: 0=none, 1=openUrl, 2=pickZip, 3=relativeMouse, 4=fullscreen, 5=openLocalPath, 6=copyDir */
export interface OhosUiPollResult {
  kind: number;
  payload: string;
}

export function setAppDataPaths(shareDir: string, cacheDir: string, userDir: string): void {
  native.setAppDataPaths(shareDir, cacheDir, userDir);
}

/** Documents mirror; engine path_user remains sandbox. */
export function setPublicUserDataDir(publicUserDir: string): void {
  native.setPublicUserDataDir(publicUserDir);
}

export function getEngineStatus(): string {
  return native.getEngineStatus();
}

export function pollOhosUiRequest(): OhosUiPollResult {
  return native.pollOhosUiRequest() as OhosUiPollResult;
}

export function completeOhosFilePick(formname: string, path: string): void {
  native.completeOhosFilePick(formname, path);
}

/** Non-empty while local zip install dialog accepts drag-and-drop. */
export function getOhosZipDropTarget(): string {
  return native.getOhosZipDropTarget() as string;
}

export function completeOhosCopyDir(ok: boolean): void {
  native.completeOhosCopyDir(ok);
}

/** OHOS KEYCODE_* (e.g. KEYCODE_W = 2039); down=true for press, false for release. */
export function injectKeyEvent(keyCode: number, down: boolean): void {
  native.injectKeyEvent(keyCode, down);
}

/** Relative mouse delta from ArkUI onMouse (rawDeltaX/Y), for first-person look. */
export function injectMouseMotion(dx: number, dy: number): void {
  native.injectMouseMotion(dx, dy);
}
