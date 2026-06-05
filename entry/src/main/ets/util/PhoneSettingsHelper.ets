import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { completeOhosFilePick } from '../native/LuantiNative';
import { PHONE_SETTINGS_FORM } from './PhoneSettingsTexts';

const DOMAIN = 0x0000;
const TAG = 'PhoneSettings';
const STATE_FILE = 'phone_settings_state.json';

export interface PhoneSettingsPage {
  id: string;
  title: string;
  section: string;
}

export interface PhoneSettingsEnumOption {
  value?: string;
  label: string;
  index?: number;
}

export interface PhoneSettingsFlag {
  name: string;
  label: string;
  value: boolean;
}

export interface PhoneSettingsV3f {
  x: number;
  y: number;
  z: number;
}

export interface PhoneSettingsItem {
  kind: string;
  name?: string;
  label?: string;
  comment?: string;
  text?: string;
  value?: string | boolean | number;
  resettable?: boolean;
  defaultText?: string;
  options?: PhoneSettingsEnumOption[];
  selectedIndex?: number;
  flags?: PhoneSettingsFlag[];
  action?: string;
  x?: number;
  y?: number;
  z?: number;
  min?: number;
  max?: number;
}

export interface PhoneSettingsState {
  pages?: PhoneSettingsPage[];
  selectedPageId?: string;
  query?: string;
  showTechnicalNames?: boolean;
  showAdvanced?: boolean;
  items?: PhoneSettingsItem[];
  actionError?: string;
}

export function copyPhoneSettingsPages(value: PhoneSettingsPage[] | null | undefined): PhoneSettingsPage[] {
  if (Array.isArray(value)) {
    return value.slice();
  }
  return [];
}

export function copyPhoneSettingsItems(value: PhoneSettingsItem[] | null | undefined): PhoneSettingsItem[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item: PhoneSettingsItem): PhoneSettingsItem => {
    const copy: PhoneSettingsItem = {
      kind: item.kind,
      name: item.name,
      label: item.label,
      comment: item.comment,
      text: item.text,
      value: item.value,
      resettable: item.resettable,
      defaultText: item.defaultText,
      selectedIndex: item.selectedIndex,
      action: item.action,
      x: item.x,
      y: item.y,
      z: item.z,
      min: item.min,
      max: item.max,
    };
    if (item.options) {
      copy.options = item.options.slice();
    }
    if (item.flags) {
      copy.flags = item.flags.map((f: PhoneSettingsFlag): PhoneSettingsFlag => ({
        name: f.name,
        label: f.label,
        value: f.value,
      }));
    }
    return copy;
  });
}

export interface PhoneSettingsRefreshAction {
  op: 'refresh';
  pageId?: string;
  query?: string;
}

export interface PhoneSettingsSelectPageAction {
  op: 'select_page';
  pageId: string;
}

export interface PhoneSettingsSearchAction {
  op: 'search';
  query: string;
}

export interface PhoneSettingsSetBoolAction {
  op: 'set_bool';
  name: string;
  value: boolean;
}

export interface PhoneSettingsSetEnumAction {
  op: 'set_enum';
  name: string;
  index: number;
}

export interface PhoneSettingsSetValueAction {
  op: 'set_value';
  name: string;
  value: string;
}

export interface PhoneSettingsSetV3fAction {
  op: 'set_v3f';
  name: string;
  value: PhoneSettingsV3f;
}

export interface PhoneSettingsSetFlagAction {
  op: 'set_flag';
  name: string;
  flag: string;
  value: boolean;
}

export interface PhoneSettingsResetAction {
  op: 'reset';
  name: string;
}

export interface PhoneSettingsUiBoolAction {
  op: 'set_ui_bool';
  name: string;
  value: boolean;
}

export interface PhoneSettingsShadowAction {
  op: 'set_shadow';
  index: number;
}

export interface PhoneSettingsRunAction {
  op: 'action';
  action: string;
}

export interface PhoneSettingsPersistAction {
  op: 'persist';
}

export type PhoneSettingsMenuAction =
  PhoneSettingsRefreshAction |
  PhoneSettingsSelectPageAction |
  PhoneSettingsSearchAction |
  PhoneSettingsSetBoolAction |
  PhoneSettingsSetEnumAction |
  PhoneSettingsSetValueAction |
  PhoneSettingsSetV3fAction |
  PhoneSettingsSetFlagAction |
  PhoneSettingsResetAction |
  PhoneSettingsUiBoolAction |
  PhoneSettingsShadowAction |
  PhoneSettingsRunAction |
  PhoneSettingsPersistAction;

export class PhoneSettingsHelper {
  private static cacheDir: string = '';
  private static stateHandler: ((state: PhoneSettingsState) => void) | undefined = undefined;
  private static lastEngineStatus: string = '';
  /** size+mtime fingerprint — in-game status stays phone_settings:state (unlike main_menu:running). */
  private static lastStateFingerprint: string = '';

  static bindStateHandler(handler: (state: PhoneSettingsState) => void): void {
    PhoneSettingsHelper.stateHandler = handler;
  }

  static setPaths(cacheDir: string): void {
    PhoneSettingsHelper.cacheDir = cacheDir;
  }

  static onEngineStatus(status: string): void {
    if (status === 'phone_settings:state') {
      PhoneSettingsHelper.readStateFileIfChanged();
    }
    PhoneSettingsHelper.lastEngineStatus = status;
  }

  private static stateFingerprint(stat: fs.Stat): string {
    return `${stat.size}:${stat.mtime}`;
  }

  private static readStateFileIfChanged(): void {
    if (PhoneSettingsHelper.cacheDir.length === 0) {
      return;
    }
    const path = `${PhoneSettingsHelper.cacheDir}/${STATE_FILE}`;
    try {
      const stat = fs.statSync(path);
      const fingerprint = PhoneSettingsHelper.stateFingerprint(stat);
      if (fingerprint === PhoneSettingsHelper.lastStateFingerprint) {
        return;
      }
      PhoneSettingsHelper.readStateFile();
    } catch {
      // ignore
    }
  }

  /** After queued Lua pick, poll state file (in-game engine status does not toggle). */
  private static scheduleStateRead(): void {
    const delays = [50, 150, 400];
    for (let i = 0; i < delays.length; i++) {
      setTimeout((): void => {
        PhoneSettingsHelper.readStateFileIfChanged();
      }, delays[i]);
    }
  }

  private static readStateFile(): void {
    if (PhoneSettingsHelper.cacheDir.length === 0) {
      return;
    }
    const path = `${PhoneSettingsHelper.cacheDir}/${STATE_FILE}`;
    try {
      const stat = fs.statSync(path);
      PhoneSettingsHelper.lastStateFingerprint = PhoneSettingsHelper.stateFingerprint(stat);
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const opts: util.TextDecoderOptions = { fatal: false, ignoreBOM: true };
      const text = util.TextDecoder.create('utf-8', opts).decodeToString(new Uint8Array(buf));
      const parsed = JSON.parse(text) as PhoneSettingsState;
      parsed.pages = copyPhoneSettingsPages(parsed.pages);
      parsed.items = copyPhoneSettingsItems(parsed.items);
      hilog.info(DOMAIN, TAG, 'state read pages=%{public}d items=%{public}d page=%{public}s',
        parsed.pages.length, parsed.items.length, parsed.selectedPageId ?? '');
      PhoneSettingsHelper.stateHandler?.(parsed);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'read state failed: %{public}s', `${e}`);
    }
  }

  static sendAction(action: PhoneSettingsMenuAction): void {
    completeOhosFilePick(PHONE_SETTINGS_FORM, JSON.stringify(action));
  }

  static refresh(pageId?: string, query?: string): void {
    const action: PhoneSettingsRefreshAction = { op: 'refresh' };
    if (pageId !== undefined) {
      action.pageId = pageId;
    }
    if (query !== undefined) {
      action.query = query;
    }
    PhoneSettingsHelper.sendAction(action);
  }

  static selectPage(pageId: string): void {
    PhoneSettingsHelper.lastStateFingerprint = '';
    PhoneSettingsHelper.sendAction({ op: 'select_page', pageId: pageId });
    PhoneSettingsHelper.scheduleStateRead();
  }

  static search(query: string): void {
    PhoneSettingsHelper.sendAction({ op: 'search', query: query });
  }

  static setBool(name: string, value: boolean): void {
    PhoneSettingsHelper.sendAction({ op: 'set_bool', name: name, value: value });
  }

  static setEnum(name: string, index: number): void {
    PhoneSettingsHelper.sendAction({ op: 'set_enum', name: name, index: index });
  }

  static setValue(name: string, value: string): void {
    PhoneSettingsHelper.sendAction({ op: 'set_value', name: name, value: value });
  }

  static setV3f(name: string, value: PhoneSettingsV3f): void {
    PhoneSettingsHelper.sendAction({ op: 'set_v3f', name: name, value: value });
  }

  static setFlag(name: string, flag: string, value: boolean): void {
    PhoneSettingsHelper.sendAction({ op: 'set_flag', name: name, flag: flag, value: value });
  }

  static reset(name: string): void {
    PhoneSettingsHelper.sendAction({ op: 'reset', name: name });
  }

  static setUiBool(name: string, value: boolean): void {
    PhoneSettingsHelper.sendAction({ op: 'set_ui_bool', name: name, value: value });
  }

  static setShadow(index: number): void {
    PhoneSettingsHelper.sendAction({ op: 'set_shadow', index: index });
  }

  static runAction(action: string): void {
    PhoneSettingsHelper.sendAction({ op: 'action', action: action });
  }

  static persist(): void {
    PhoneSettingsHelper.sendAction({ op: 'persist' });
  }
}
