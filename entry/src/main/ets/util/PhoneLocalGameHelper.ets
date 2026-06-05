import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { completeOhosFilePick } from '../native/LuantiNative';
import { DeviceFormFactor } from './DeviceFormFactor';
import { PhoneGameInstallHelper } from './PhoneGameInstallHelper';
import { PHONE_LOCAL_FORM } from './PhoneLocalGameTexts';

const DOMAIN = 0x0000;
const TAG = 'PhoneLocalGame';
const STATE_FILE = 'phone_local_state.json';

export interface PhoneLocalGameInfo {
  id: string;
  title: string;
  iconPath: string;
  selected: boolean;
}

export interface PhoneLocalWorldInfo {
  name: string;
  gameid: string;
  selected: boolean;
}

export interface PhoneLocalCheckbox {
  visible: boolean;
  value: boolean;
}

export interface PhoneLocalServerPanel {
  announce: boolean;
  playerName: string;
  port: string;
  bindAddress: string;
}

export interface PhoneLocalLeftPanel {
  creativeMode?: PhoneLocalCheckbox;
  enableDamage?: PhoneLocalCheckbox;
  enableServer?: PhoneLocalCheckbox;
  server?: PhoneLocalServerPanel;
}

export interface PhoneLocalFlagItem {
  id: string;
  value: boolean;
}

export interface PhoneLocalCreateSchema {
  gameId?: string;
  mapgens?: string[];
  selectedMapgen?: string;
  seed?: string;
  worldname?: string;
  seedAllowed?: boolean;
  flags?: Record<string, PhoneLocalFlagItem[] | number | boolean>;
  error?: string;
}

export interface PhoneLocalModDep {
  name: string;
  state: 'ok' | 'missing' | 'warn' | 'error' | 'neutral';
}

export interface PhoneLocalModListItem {
  index: number;
  name: string;
  title: string;
  rowType: 'header' | 'modpack' | 'mod';
  enabled: boolean;
  alwaysOn: boolean;
  indent: number;
  errorType?: 'warning' | 'error';
  canToggle: boolean;
}

export interface PhoneLocalModDetail {
  kind: 'description' | 'mod' | 'game' | 'worldmods' | 'modpack';
  title: string;
  description?: string;
  enabled?: boolean;
  alwaysOn?: boolean;
  canToggle?: boolean;
  modpackEntirelyEnabled?: boolean;
  hardDeps?: PhoneLocalModDep[];
  softDeps?: PhoneLocalModDep[];
}

export interface PhoneLocalModSchema {
  worldName?: string;
  selectedIndex?: number;
  showDisableAll?: boolean;
  mods?: PhoneLocalModListItem[];
  detail?: PhoneLocalModDetail;
  error?: string;
}

export interface PhoneLocalState {
  hasGames?: boolean;
  games?: PhoneLocalGameInfo[];
  worlds?: PhoneLocalWorldInfo[];
  selectedWorldIndex?: number;
  hasWorlds?: boolean;
  leftPanel?: PhoneLocalLeftPanel;
  createSchema?: PhoneLocalCreateSchema;
  createResult?: string | null;
  createSuccess?: boolean;
  modSchema?: PhoneLocalModSchema;
  modSaveSuccess?: boolean;
  modSaveError?: string;
  modClosed?: boolean;
  playError?: string;
}

/** Luanti write_json encodes empty Lua tables as JSON null, not []. */
function copyStateArray<T>(value: T[] | Record<string, T> | null | undefined, fallback: T[] = []): T[] {
  if (Array.isArray(value)) {
    return value.slice();
  }
  if (value !== null && value !== undefined && typeof value === 'object') {
    const obj = value as Record<string, T>;
    const keys = Object.keys(obj).filter((k: string): boolean => /^\d+$/.test(k))
      .map((k: string): number => Number.parseInt(k, 10))
      .sort((a: number, b: number): number => a - b);
    if (keys.length > 0) {
      return keys.map((k: number): T => obj[String(k)]);
    }
  }
  return fallback.slice();
}

function leftPanelImpliesWorld(left?: PhoneLocalLeftPanel): boolean {
  return left?.creativeMode?.visible === true ||
    left?.enableDamage?.visible === true ||
    left?.enableServer?.visible === true;
}

export function normalizePhoneLocalState(raw: PhoneLocalState, prev?: PhoneLocalState): PhoneLocalState {
  const prevGames = prev?.games;
  const prevWorlds = prev?.worlds;
  const games = copyStateArray(raw.games, prevGames);
  const worlds = copyStateArray(raw.worlds, prevWorlds);
  let leftPanel = raw.leftPanel !== undefined ? raw.leftPanel : prev?.leftPanel;
  if (leftPanelImpliesWorld(leftPanel) && worlds.length === 0) {
    leftPanel = {};
  }
  return {
    hasGames: raw.hasGames !== undefined ? raw.hasGames : prev?.hasGames,
    games,
    worlds,
    selectedWorldIndex: raw.selectedWorldIndex !== undefined ?
      raw.selectedWorldIndex : prev?.selectedWorldIndex,
    hasWorlds: worlds.length > 0,
    leftPanel,
    createSchema: raw.createSchema !== undefined ? raw.createSchema : prev?.createSchema,
    createResult: raw.createResult !== undefined ? raw.createResult : prev?.createResult,
    createSuccess: raw.createSuccess !== undefined ? raw.createSuccess : prev?.createSuccess,
    modSchema: raw.modSchema !== undefined ? raw.modSchema : prev?.modSchema,
    modSaveSuccess: raw.modSaveSuccess,
    modSaveError: raw.modSaveError,
    modClosed: raw.modClosed,
    playError: raw.playError !== undefined ? raw.playError : prev?.playError,
  };
}

export interface PhoneLocalRefreshAction {
  op: 'refresh';
}

export interface PhoneLocalSelectGameAction {
  op: 'select_game';
  id: string;
}

export interface PhoneLocalSelectWorldAction {
  op: 'select_world';
  index: number;
}

export interface PhoneLocalSetSettingAction {
  op: 'set_setting';
  key: string;
  value: string | boolean;
  index?: number;
}

export interface PhoneLocalDeleteWorldAction {
  op: 'delete_world';
  name: string;
}

export interface PhoneLocalPlayAction {
  op: 'play';
  password?: string;
  playerName?: string;
  port?: string;
  bindAddress?: string;
  worldIndex?: number;
}

export interface PhoneLocalConfigureWorldAction {
  op: 'configure_world';
}

export interface PhoneLocalCreateSchemaAction {
  op: 'create_schema';
}

export interface PhoneLocalMapgenSchemaAction {
  op: 'mapgen_schema';
  mapgen: string;
  flagsJson: string;
}

export interface PhoneLocalCreateWorldAction {
  op: 'create_world';
  worldname: string;
  seed: string;
  mapgen: string;
  gameId?: string;
  flagsJson: string;
}

export interface PhoneLocalModSchemaAction {
  op: 'mod_schema';
}

export interface PhoneLocalModSelectAction {
  op: 'mod_select';
  index: number;
}

export interface PhoneLocalModToggleAction {
  op: 'mod_toggle';
  index: number;
  enabled?: boolean;
}

export interface PhoneLocalModEnableAllAction {
  op: 'mod_enable_all';
}

export interface PhoneLocalModDisableAllAction {
  op: 'mod_disable_all';
}

export interface PhoneLocalModSaveAction {
  op: 'mod_save';
}

export interface PhoneLocalModCancelAction {
  op: 'mod_cancel';
}

export type PhoneLocalMenuAction =
  PhoneLocalRefreshAction |
  PhoneLocalSelectGameAction |
  PhoneLocalSelectWorldAction |
  PhoneLocalSetSettingAction |
  PhoneLocalDeleteWorldAction |
  PhoneLocalPlayAction |
  PhoneLocalConfigureWorldAction |
  PhoneLocalCreateSchemaAction |
  PhoneLocalMapgenSchemaAction |
  PhoneLocalCreateWorldAction |
  PhoneLocalModSchemaAction |
  PhoneLocalModSelectAction |
  PhoneLocalModToggleAction |
  PhoneLocalModEnableAllAction |
  PhoneLocalModDisableAllAction |
  PhoneLocalModSaveAction |
  PhoneLocalModCancelAction;

export interface PhoneLocalGamePhoneOverlay {
  open(): Promise<void>;
  close(): void;
  onStateChanged(state: PhoneLocalState): void;
  onInstallPickerRequested(): void;
  onCreateWorldOpen(schema: PhoneLocalCreateSchema): void;
  onCreateWorldClose(): void;
  onModSelectOpen(schema: PhoneLocalModSchema): void;
  onModSelectClose(): void;
  onModFindMoreRequested(): void;
}

export class PhoneLocalGamePhoneOverlayImpl implements PhoneLocalGamePhoneOverlay {
  private openHandler: () => Promise<void>;
  private closeHandler: () => void;
  private stateHandler: (state: PhoneLocalState) => void;
  private installPickerHandler: () => void;
  private createOpenHandler: (schema: PhoneLocalCreateSchema) => void;
  private createCloseHandler: () => void;
  private modOpenHandler: (schema: PhoneLocalModSchema) => void;
  private modCloseHandler: () => void;
  private modFindMoreHandler: () => void;

  constructor(
    openHandler: () => Promise<void>,
    closeHandler: () => void,
    stateHandler: (state: PhoneLocalState) => void,
    installPickerHandler: () => void,
    createOpenHandler: (schema: PhoneLocalCreateSchema) => void,
    createCloseHandler: () => void,
    modOpenHandler: (schema: PhoneLocalModSchema) => void,
    modCloseHandler: () => void,
    modFindMoreHandler: () => void,
  ) {
    this.openHandler = openHandler;
    this.closeHandler = closeHandler;
    this.stateHandler = stateHandler;
    this.installPickerHandler = installPickerHandler;
    this.createOpenHandler = createOpenHandler;
    this.createCloseHandler = createCloseHandler;
    this.modOpenHandler = modOpenHandler;
    this.modCloseHandler = modCloseHandler;
    this.modFindMoreHandler = modFindMoreHandler;
  }

  open(): Promise<void> {
    return this.openHandler();
  }

  close(): void {
    this.closeHandler();
  }

  onStateChanged(state: PhoneLocalState): void {
    this.stateHandler(state);
  }

  onInstallPickerRequested(): void {
    this.installPickerHandler();
  }

  onCreateWorldOpen(schema: PhoneLocalCreateSchema): void {
    this.createOpenHandler(schema);
  }

  onCreateWorldClose(): void {
    this.createCloseHandler();
  }

  onModSelectOpen(schema: PhoneLocalModSchema): void {
    this.modOpenHandler(schema);
  }

  onModSelectClose(): void {
    this.modCloseHandler();
  }

  onModFindMoreRequested(): void {
    this.modFindMoreHandler();
  }
}

export class PhoneLocalGameHelper {
  private static overlay: PhoneLocalGamePhoneOverlay | undefined = undefined;
  private static cacheDir: string = '';
  private static userDir: string = '';
  private static visible: boolean = false;
  private static playPending: boolean = false;

  static bindPhoneOverlay(host: PhoneLocalGamePhoneOverlay): void {
    PhoneLocalGameHelper.overlay = host;
  }

  static setPaths(cacheDir: string, userDir: string): void {
    PhoneLocalGameHelper.cacheDir = cacheDir;
    PhoneLocalGameHelper.userDir = userDir;
  }

  static isVisible(): boolean {
    return PhoneLocalGameHelper.visible;
  }

  static isPlayPending(): boolean {
    return PhoneLocalGameHelper.playPending;
  }

  static hasRetailSubgames(userDir: string): boolean {
    return PhoneGameInstallHelper.listUserSubgameIds(userDir).length > 0;
  }

  /** Resolve menu icon path for a subgame (same file as PC/tablet game bar). */
  static resolveGameIconPath(userDir: string, gameId: string, engineIconPath: string): string {
    if (engineIconPath.length > 0) {
      try {
        fs.accessSync(engineIconPath);
        return engineIconPath;
      } catch {
        // fall through
      }
    }
    const fallback = `${userDir}/games/${gameId}/menu/icon.png`;
    try {
      fs.accessSync(fallback);
      return fallback;
    } catch {
      return '';
    }
  }

  static async showIfNeeded(context: common.UIAbilityContext, userDir: string): Promise<void> {
    if (!DeviceFormFactor.isPhone()) {
      return;
    }
    if (PhoneLocalGameHelper.playPending) {
      return;
    }
    if (!PhoneLocalGameHelper.hasRetailSubgames(userDir)) {
      return;
    }
    if (!PhoneLocalGameHelper.overlay) {
      hilog.warn(DOMAIN, TAG, 'overlay not bound');
      return;
    }
    PhoneLocalGameHelper.setPaths(context.cacheDir, userDir);
    if (PhoneLocalGameHelper.visible) {
      PhoneLocalGameHelper.refresh();
      return;
    }
    await PhoneLocalGameHelper.openNativeHomeOverlay();
  }

  /** Sync Helper.visible when Game.ets hides overlay without calling hide(). */
  static markUiClosed(): void {
    PhoneLocalGameHelper.visible = false;
  }

  /** Always reopen native shell (fixes visible=true but ArkUI panel closed after in-game). */
  static async forceShowNativeHome(context: common.UIAbilityContext, userDir: string): Promise<void> {
    if (!DeviceFormFactor.isPhone()) {
      return;
    }
    if (!PhoneLocalGameHelper.hasRetailSubgames(userDir)) {
      return;
    }
    if (!PhoneLocalGameHelper.overlay) {
      hilog.warn(DOMAIN, TAG, 'force native home: overlay not bound');
      return;
    }
    PhoneLocalGameHelper.playPending = false;
    PhoneLocalGameHelper.setPaths(context.cacheDir, userDir);
    await PhoneLocalGameHelper.openNativeHomeOverlay(true);
  }

  private static async openNativeHomeOverlay(force: boolean = false): Promise<void> {
    if (!PhoneLocalGameHelper.overlay) {
      return;
    }
    if (force) {
      PhoneLocalGameHelper.visible = false;
      PhoneLocalGameHelper.overlay.close();
    } else if (PhoneLocalGameHelper.visible) {
      PhoneLocalGameHelper.refresh();
      return;
    }
    PhoneLocalGameHelper.visible = true;
    await PhoneLocalGameHelper.overlay.open();
    hilog.info(DOMAIN, TAG, 'native home overlay open (force=%{public}s)', `${force}`);
    const action: PhoneLocalRefreshAction = { op: 'refresh' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static onInstallSuccess(context: common.UIAbilityContext, userDir: string): void {
    if (!DeviceFormFactor.isPhone()) {
      return;
    }
    PhoneLocalGameHelper.setPaths(context.cacheDir, userDir);
    PhoneLocalGameHelper.showIfNeeded(context, userDir).catch((e: Error) => {
      hilog.error(DOMAIN, TAG, 'show after install failed: %{public}s', e.message);
    });
  }

  static hide(): void {
    PhoneLocalGameHelper.visible = false;
    PhoneLocalGameHelper.overlay?.close();
  }

  static onLeftGame(): void {
    PhoneLocalGameHelper.playPending = false;
  }

  static onEngineStatus(status: string): void {
    if (status.startsWith('in_game:')) {
      PhoneLocalGameHelper.playPending = false;
    } else if (status.startsWith('phone_local:err:')) {
      PhoneLocalGameHelper.playPending = false;
    } else if (status === 'phone_local:state') {
      PhoneLocalGameHelper.readStateFile();
      if (!PhoneLocalGameHelper.playPending && PhoneLocalGameHelper.overlay &&
        !PhoneLocalGameHelper.visible && PhoneLocalGameHelper.userDir.length > 0 &&
        PhoneLocalGameHelper.cacheDir.length > 0) {
        PhoneLocalGameHelper.openNativeHomeOverlay(false).catch((e: Error) => {
          hilog.warn(DOMAIN, TAG, 'reopen native home: %{public}s', e.message);
        });
      }
    } else if (status.startsWith('main_menu:')) {
      PhoneLocalGameHelper.playPending = false;
      if (PhoneLocalGameHelper.overlay && PhoneLocalGameHelper.userDir.length > 0 &&
        PhoneLocalGameHelper.hasRetailSubgames(PhoneLocalGameHelper.userDir)) {
        PhoneLocalGameHelper.openNativeHomeOverlay(true).catch((e: Error) => {
          hilog.warn(DOMAIN, TAG, 'reopen after menu: %{public}s', e.message);
        });
      } else {
        PhoneLocalGameHelper.sendAction({ op: 'refresh' });
      }
    } else if (status === 'phone_local:playing' || status === 'phone_local:lua_dialog') {
      if (status === 'phone_local:lua_dialog') {
        PhoneLocalGameHelper.playPending = false;
      }
      /* Hide native panel so XComponent shows engine draw_load_screen (original Lua loading). */
      PhoneLocalGameHelper.hide();
    }
  }

  private static readStateFile(): void {
    if (PhoneLocalGameHelper.cacheDir.length === 0) {
      return;
    }
    const path = `${PhoneLocalGameHelper.cacheDir}/${STATE_FILE}`;
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const opts: util.TextDecoderOptions = { fatal: false, ignoreBOM: true };
      const text = util.TextDecoder.create('utf-8', opts).decodeToString(new Uint8Array(buf));
      const parsed = JSON.parse(text) as PhoneLocalState;
      if (parsed.playError) {
        PhoneLocalGameHelper.playPending = false;
      }
      const worlds = copyStateArray(parsed.worlds);
      const names = worlds.map((w: PhoneLocalWorldInfo): string => w.name ?? '').join(',');
      hilog.info(DOMAIN, TAG, 'state read worlds=%{public}d names=%{public}s sel=%{public}d',
        worlds.length, names, parsed.selectedWorldIndex ?? 0);
      PhoneLocalGameHelper.overlay?.onStateChanged(parsed);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'read state failed: %{public}s', `${e}`);
    }
  }

  static sendAction(action: PhoneLocalMenuAction): void {
    completeOhosFilePick(PHONE_LOCAL_FORM, JSON.stringify(action));
  }

  static refresh(): void {
    const action: PhoneLocalRefreshAction = { op: 'refresh' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static selectGame(gameId: string): void {
    const action: PhoneLocalSelectGameAction = { op: 'select_game', id: gameId };
    PhoneLocalGameHelper.sendAction(action);
  }

  static selectWorld(index: number): void {
    const action: PhoneLocalSelectWorldAction = { op: 'select_world', index: index };
    PhoneLocalGameHelper.sendAction(action);
  }

  static setSetting(key: string, value: string | boolean, worldIndex?: number): void {
    const action: PhoneLocalSetSettingAction = {
      op: 'set_setting',
      key: key,
      value: value,
    };
    if (worldIndex !== undefined && worldIndex > 0) {
      action.index = worldIndex;
    }
    PhoneLocalGameHelper.sendAction(action);
  }

  static deleteWorld(name: string): void {
    const action: PhoneLocalDeleteWorldAction = { op: 'delete_world', name: name };
    PhoneLocalGameHelper.sendAction(action);
  }

  static play(password: string, playerName: string, port: string, bindAddress: string,
    worldIndex: number = 0): void {
    PhoneLocalGameHelper.playPending = true;
    const action: PhoneLocalPlayAction = {
      op: 'play',
      password: password,
      playerName: playerName,
      port: port,
      bindAddress: bindAddress,
    };
    if (worldIndex > 0) {
      action.worldIndex = worldIndex;
    }
    PhoneLocalGameHelper.sendAction(action);
  }

  static configureWorld(): void {
    PhoneLocalGameHelper.requestModSchema();
  }

  static requestModSchema(): void {
    const action: PhoneLocalModSchemaAction = { op: 'mod_schema' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static selectMod(index: number): void {
    const action: PhoneLocalModSelectAction = { op: 'mod_select', index: index };
    PhoneLocalGameHelper.sendAction(action);
  }

  static toggleMod(index: number, enabled?: boolean): void {
    const action: PhoneLocalModToggleAction = { op: 'mod_toggle', index: index, enabled: enabled };
    PhoneLocalGameHelper.sendAction(action);
  }

  static enableAllMods(): void {
    const action: PhoneLocalModEnableAllAction = { op: 'mod_enable_all' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static disableAllMods(): void {
    const action: PhoneLocalModDisableAllAction = { op: 'mod_disable_all' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static saveMods(): void {
    const action: PhoneLocalModSaveAction = { op: 'mod_save' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static cancelMods(): void {
    const action: PhoneLocalModCancelAction = { op: 'mod_cancel' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static requestCreateSchema(): void {
    const action: PhoneLocalCreateSchemaAction = { op: 'create_schema' };
    PhoneLocalGameHelper.sendAction(action);
  }

  static requestMapgenSchema(mapgen: string, flagsJson: string): void {
    const action: PhoneLocalMapgenSchemaAction = {
      op: 'mapgen_schema',
      mapgen: mapgen,
      flagsJson: flagsJson,
    };
    PhoneLocalGameHelper.sendAction(action);
  }

  static createWorld(worldname: string, seed: string, mapgen: string, gameId: string, flagsJson: string): void {
    const action: PhoneLocalCreateWorldAction = {
      op: 'create_world',
      worldname: worldname,
      seed: seed,
      mapgen: mapgen,
      gameId: gameId.length > 0 ? gameId : undefined,
      flagsJson: flagsJson,
    };
    PhoneLocalGameHelper.sendAction(action);
  }

  static openInstallPicker(): void {
    PhoneLocalGameHelper.overlay?.onInstallPickerRequested();
  }

  static openCreateWorldDialog(schema: PhoneLocalCreateSchema): void {
    PhoneLocalGameHelper.overlay?.onCreateWorldOpen(schema);
  }

  static openSelectModDialog(schema: PhoneLocalModSchema): void {
    PhoneLocalGameHelper.overlay?.onModSelectOpen(schema);
  }
}
