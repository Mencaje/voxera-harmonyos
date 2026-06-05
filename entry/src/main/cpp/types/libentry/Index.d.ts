export interface OhosUiPollResult {
  kind: number;
  payload: string;
}

export const getEngineStatus: () => string;
export const isInGameWorld: () => boolean;
export const isPlayerInventoryOpen: () => boolean;
export const setAppDataPaths: (shareDir: string, cacheDir: string, userDir: string) => void;
export const setPublicUserDataDir: (publicUserDir: string) => void;
export const setDeviceFormFactor: (deviceType: string) => void;
export const pollOhosUiRequest: () => OhosUiPollResult;
export const completeOhosFilePick: (formname: string, path: string) => void;
export const getOhosZipDropTarget: () => string;
export const completeOhosCopyDir: (ok: boolean) => void;
export const completeOhosTextInput: (canceled: boolean, text: string) => void;
export const injectKeyEvent: (keyCode: number, down: boolean) => void;
/** 1=inventory, 2=minimap — fixed phone HUD actions, ignores key remapping. */
export const triggerPhoneGameAction: (action: number) => void;
export const injectMouseMotion: (dx: number, dy: number) => void;
export const injectTouch: (x: number, y: number, action: number, fingerId: number) => void;
export const injectClick: (x: number, y: number) => void;
export const getNativePauseActive: () => boolean;
export const setNativePauseActive: (active: boolean) => void;
export const nativePauseExitMenu: () => void;
export const nativePauseExitOS: () => void;
