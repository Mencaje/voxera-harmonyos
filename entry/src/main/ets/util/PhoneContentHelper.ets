import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { completeOhosFilePick } from '../native/LuantiNative';
import { PHONE_CONTENT_FORM } from './PhoneContentTexts';

const DOMAIN = 0x0000;
const TAG = 'PhoneContent';
const STATE_FILE = 'phone_content_state.json';

export interface PhoneContentPackageItem {
  index: number;
  name: string;
  title: string;
  type: string;
  rowType: string;
  indent: number;
  hasUpdate: boolean;
  enabled: boolean;
}

export interface PhoneContentDetail {
  kind: string;
  title: string;
  subtitle?: string;
  description?: string;
  screenshotPath?: string;
  isModpack?: boolean;
  canUninstall?: boolean;
  hasUpdate?: boolean;
  txpEnabled?: boolean;
  hardDeps?: string[];
  softDeps?: string[];
}

export interface PhoneContentState {
  updateCount?: number;
  selectedIndex?: number;
  packages?: PhoneContentPackageItem[];
  detail?: PhoneContentDetail;
  actionError?: string;
  actionSuccess?: string;
}

export function copyPhoneContentPackages(value: PhoneContentPackageItem[] | null | undefined): PhoneContentPackageItem[] {
  if (Array.isArray(value)) {
    return value.slice();
  }
  return [];
}

export function copyPhoneContentDetail(value: PhoneContentDetail | null | undefined): PhoneContentDetail | undefined {
  if (value === null || value === undefined) {
    return undefined;
  }
  const copy: PhoneContentDetail = {
    kind: value.kind,
    title: value.title,
    subtitle: value.subtitle,
    description: value.description,
    screenshotPath: value.screenshotPath,
    isModpack: value.isModpack,
    canUninstall: value.canUninstall,
    hasUpdate: value.hasUpdate,
    txpEnabled: value.txpEnabled,
  };
  if (value.hardDeps) {
    copy.hardDeps = value.hardDeps.slice();
  }
  if (value.softDeps) {
    copy.softDeps = value.softDeps.slice();
  }
  return copy;
}

export interface PhoneContentRefreshAction {
  op: 'refresh';
}

export interface PhoneContentSelectAction {
  op: 'select';
  index: number;
}

export interface PhoneContentUninstallAction {
  op: 'uninstall';
  index: number;
}

export interface PhoneContentUseTxpAction {
  op: 'use_txp';
  index: number;
}

export interface PhoneContentDisableTxpAction {
  op: 'disable_txp';
}

export interface PhoneContentBrowseAction {
  op: 'browse_online';
}

export type PhoneContentMenuAction =
  PhoneContentRefreshAction |
  PhoneContentSelectAction |
  PhoneContentUninstallAction |
  PhoneContentUseTxpAction |
  PhoneContentDisableTxpAction |
  PhoneContentBrowseAction;

export class PhoneContentHelper {
  private static cacheDir: string = '';
  private static stateHandler: ((state: PhoneContentState) => void) | undefined = undefined;
  private static browseHandler: (() => void) | undefined = undefined;
  /** Sticky engine status — only act on rising edge / explicit UI browse. */
  private static lastEngineStatus: string = '';
  private static browseHandled: boolean = false;
  /** size+mtime fingerprint — in-game status stays phone_content:state. */
  private static lastStateFingerprint: string = '';

  static bindStateHandler(handler: (state: PhoneContentState) => void): void {
    PhoneContentHelper.stateHandler = handler;
  }

  static bindBrowseHandler(handler: () => void): void {
    PhoneContentHelper.browseHandler = handler;
  }

  static setPaths(cacheDir: string): void {
    PhoneContentHelper.cacheDir = cacheDir;
  }

  static onEngineStatus(status: string): void {
    if (status === 'phone_content:state') {
      if (PhoneContentHelper.lastEngineStatus === 'phone_content:browse') {
        PhoneContentHelper.browseHandled = false;
      }
      PhoneContentHelper.readStateFileIfChanged();
    } else if (status === 'phone_content:browse') {
      if (!PhoneContentHelper.browseHandled &&
        status !== PhoneContentHelper.lastEngineStatus) {
        PhoneContentHelper.browseHandled = true;
        PhoneContentHelper.browseHandler?.();
      }
    } else if (PhoneContentHelper.lastEngineStatus === 'phone_content:browse') {
      PhoneContentHelper.browseHandled = false;
    }
    PhoneContentHelper.lastEngineStatus = status;
  }

  private static stateFingerprint(stat: fs.Stat): string {
    return `${stat.size}:${stat.mtime}`;
  }

  private static readStateFileIfChanged(): void {
    if (PhoneContentHelper.cacheDir.length === 0) {
      return;
    }
    const path = `${PhoneContentHelper.cacheDir}/${STATE_FILE}`;
    try {
      const stat = fs.statSync(path);
      const fingerprint = PhoneContentHelper.stateFingerprint(stat);
      if (fingerprint === PhoneContentHelper.lastStateFingerprint) {
        return;
      }
      PhoneContentHelper.readStateFile();
    } catch {
      // file missing — ignore until next explicit state signal
    }
  }

  /** After queued Lua pick, poll state file (in-game engine status does not toggle). */
  private static scheduleStateRead(): void {
    const delays = [50, 150, 400];
    for (let i = 0; i < delays.length; i++) {
      setTimeout((): void => {
        PhoneContentHelper.readStateFileIfChanged();
      }, delays[i]);
    }
  }

  private static readStateFile(): void {
    if (PhoneContentHelper.cacheDir.length === 0) {
      return;
    }
    const path = `${PhoneContentHelper.cacheDir}/${STATE_FILE}`;
    try {
      const stat = fs.statSync(path);
      PhoneContentHelper.lastStateFingerprint = PhoneContentHelper.stateFingerprint(stat);
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const opts: util.TextDecoderOptions = { fatal: false, ignoreBOM: true };
      const text = util.TextDecoder.create('utf-8', opts).decodeToString(new Uint8Array(buf));
      const parsed = JSON.parse(text) as PhoneContentState;
      parsed.packages = copyPhoneContentPackages(parsed.packages);
      hilog.info(DOMAIN, TAG, 'state read packages=%{public}d sel=%{public}d',
        parsed.packages.length, parsed.selectedIndex ?? 0);
      PhoneContentHelper.stateHandler?.(parsed);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'read state failed: %{public}s', `${e}`);
    }
  }

  static sendAction(action: PhoneContentMenuAction): void {
    completeOhosFilePick(PHONE_CONTENT_FORM, JSON.stringify(action));
  }

  static refresh(): void {
    const action: PhoneContentRefreshAction = { op: 'refresh' };
    PhoneContentHelper.sendAction(action);
  }

  static selectPackage(index: number): void {
    PhoneContentHelper.lastStateFingerprint = '';
    const action: PhoneContentSelectAction = { op: 'select', index: index };
    PhoneContentHelper.sendAction(action);
    PhoneContentHelper.scheduleStateRead();
  }

  static uninstallPackage(index: number): void {
    const action: PhoneContentUninstallAction = { op: 'uninstall', index: index };
    PhoneContentHelper.sendAction(action);
  }

  static useTexturePack(index: number): void {
    const action: PhoneContentUseTxpAction = { op: 'use_txp', index: index };
    PhoneContentHelper.sendAction(action);
  }

  static disableTexturePack(): void {
    const action: PhoneContentDisableTxpAction = { op: 'disable_txp' };
    PhoneContentHelper.sendAction(action);
  }

  static browseOnline(): void {
    PhoneContentHelper.browseHandled = true;
    PhoneContentHelper.browseHandler?.();
    const action: PhoneContentBrowseAction = { op: 'browse_online' };
    PhoneContentHelper.sendAction(action);
  }
}
