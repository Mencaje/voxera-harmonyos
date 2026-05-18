export interface OhosUiPollResult {
  kind: number;
  payload: string;
}

export const getEngineStatus: () => string;
export const setAppDataPaths: (shareDir: string, cacheDir: string, userDir: string) => void;
export const setPublicUserDataDir: (publicUserDir: string) => void;
export const pollOhosUiRequest: () => OhosUiPollResult;
export const completeOhosFilePick: (formname: string, path: string) => void;
export const getOhosZipDropTarget: () => string;
export const completeOhosCopyDir: (ok: boolean) => void;
