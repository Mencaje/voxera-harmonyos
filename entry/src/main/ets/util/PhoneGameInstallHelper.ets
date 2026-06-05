import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DeviceFormFactor } from './DeviceFormFactor';
import { OhosUiBridge } from './OhosUiBridge';
import { completeOhosFilePick, getEngineStatus } from '../native/LuantiNative';
import { PHONE_INSTALL_FORM } from './PhoneGameInstallTexts';

const DOMAIN = 0x0000;
const TAG = 'PhoneGameInstall';
/** Bundled dev-only game; not a retail subgame for the install gate. */
const DEVTEST_GAME_ID = 'devtest';

export type PhoneInstallScreen = 'gate' | 'picker';

/** Phone: full-screen install gate + picker on Game page (no subwindow). */
export interface PhoneGameInstallPhoneOverlay {
  open(): Promise<void>;
  close(): void;
  getScreen(): PhoneInstallScreen;
  setScreen(screen: PhoneInstallScreen): void;
  getStatusText(): string;
  setStatusText(text: string): void;
}

export class PhoneGameInstallPhoneOverlayImpl implements PhoneGameInstallPhoneOverlay {
  private openHandler: () => Promise<void>;
  private closeHandler: () => void;
  private getScreenHandler: () => PhoneInstallScreen;
  private setScreenHandler: (screen: PhoneInstallScreen) => void;
  private getStatusHandler: () => string;
  private setStatusHandler: (text: string) => void;

  constructor(
    openHandler: () => Promise<void>,
    closeHandler: () => void,
    getScreenHandler: () => PhoneInstallScreen,
    setScreenHandler: (screen: PhoneInstallScreen) => void,
    getStatusHandler: () => string,
    setStatusHandler: (text: string) => void,
  ) {
    this.openHandler = openHandler;
    this.closeHandler = closeHandler;
    this.getScreenHandler = getScreenHandler;
    this.setScreenHandler = setScreenHandler;
    this.getStatusHandler = getStatusHandler;
    this.setStatusHandler = setStatusHandler;
  }

  open(): Promise<void> {
    return this.openHandler();
  }

  close(): void {
    this.closeHandler();
  }

  getScreen(): PhoneInstallScreen {
    return this.getScreenHandler();
  }

  setScreen(screen: PhoneInstallScreen): void {
    this.setScreenHandler(screen);
  }

  getStatusText(): string {
    return this.getStatusHandler();
  }

  setStatusText(text: string): void {
    this.setStatusHandler(text);
  }
}

export class PhoneGameInstallHelper {
  private static phoneOverlay: PhoneGameInstallPhoneOverlay | undefined = undefined;
  private static pendingResolve: (() => void) | undefined = undefined;
  private static picking: boolean = false;
  private static installWatchTimer: number = -1;
  private static watchUserDir: string = '';
  private static gamesBeforePick: string[] = [];
  /** Picker opened from local-game + bar: back closes overlay instead of gate. */
  private static additionalPicker: boolean = false;
  private static overlayVisible: boolean = false;

  static bindPhoneOverlay(host: PhoneGameInstallPhoneOverlay): void {
    PhoneGameInstallHelper.phoneOverlay = host;
  }

  /** Used to detect install completion when engine status poll misses phone_install:ok. */
  static setWatchUserDir(userDir: string): void {
    PhoneGameInstallHelper.watchUserDir = userDir;
  }

  /** List retail subgame ids under userDir/games (excludes devtest). */
  static listUserSubgameIds(userDir: string): string[] {
    const ids: string[] = [];
    if (userDir.length === 0) {
      return ids;
    }
    const gamesDir = `${userDir}/games`;
    try {
      const names = fs.listFileSync(gamesDir);
      for (let i = 0; i < names.length; i++) {
        const gameId = names[i];
        if (gameId === DEVTEST_GAME_ID) {
          continue;
        }
        try {
          fs.accessSync(`${gamesDir}/${gameId}/game.conf`);
          ids.push(gameId);
        } catch {
          // not a game folder
        }
      }
    } catch {
      // no games dir yet
    }
    return ids;
  }

  /** Phone: native install gate when user has no retail subgame yet. */
  static async show(context: common.UIAbilityContext, shareDir: string, userDir: string): Promise<void> {
    if (!DeviceFormFactor.isPhone()) {
      hilog.info(DOMAIN, TAG, 'skip: not phone');
      return;
    }
    if (!PhoneGameInstallHelper.phoneOverlay) {
      hilog.warn(DOMAIN, TAG, 'phone overlay not bound');
      return;
    }
    const existing = PhoneGameInstallHelper.listUserSubgameIds(userDir);
    if (existing.length > 0) {
      hilog.info(DOMAIN, TAG, 'skip: user subgames already installed [%{public}s]',
        existing.join(','));
      return;
    }
    if (PhoneGameInstallHelper.pendingResolve) {
      return new Promise<void>((resolve) => {
        const prev = PhoneGameInstallHelper.pendingResolve!;
        PhoneGameInstallHelper.pendingResolve = () => {
          prev();
          resolve();
        };
      });
    }
    hilog.info(DOMAIN, TAG, 'opening native install gate (user=%{public}s)', userDir);
    return new Promise<void>((resolve) => {
      PhoneGameInstallHelper.pendingResolve = resolve;
      PhoneGameInstallHelper.additionalPicker = false;
      PhoneGameInstallHelper.phoneOverlay!.setScreen('gate');
      PhoneGameInstallHelper.phoneOverlay!.setStatusText('');
      PhoneGameInstallHelper.phoneOverlay!.open().catch((e: Error) => {
        hilog.error(DOMAIN, TAG, 'open overlay failed: %{public}s', e.message);
        PhoneGameInstallHelper.finish();
      });
    });
  }

  static onInstallSuccess(): void {
    PhoneGameInstallHelper.finish();
  }

  static isAdditionalPicker(): boolean {
    return PhoneGameInstallHelper.additionalPicker;
  }

  static shouldPickerBackToGate(): boolean {
    return !PhoneGameInstallHelper.additionalPicker;
  }

  static markOverlayVisible(visible: boolean): void {
    PhoneGameInstallHelper.overlayVisible = visible;
  }

  /** Close picker opened from local-game + without touching the first-run gate flow. */
  static dismissAdditionalPicker(): void {
    PhoneGameInstallHelper.additionalPicker = false;
    PhoneGameInstallHelper.endInstallWatch();
    PhoneGameInstallHelper.phoneOverlay?.setStatusText('');
    PhoneGameInstallHelper.phoneOverlay?.close();
  }

  static listInstalledGameIds(): string[] {
    return PhoneGameInstallHelper.listUserSubgameIds(PhoneGameInstallHelper.watchUserDir);
  }

  /** Phone local game bar: open picker to add another subgame. */
  static openAdditionalInstallPicker(_context: common.UIAbilityContext, _cacheDir: string): void {
    if (!PhoneGameInstallHelper.phoneOverlay) {
      return;
    }
    if (PhoneGameInstallHelper.additionalPicker && PhoneGameInstallHelper.overlayVisible) {
      return;
    }
    PhoneGameInstallHelper.additionalPicker = true;
    PhoneGameInstallHelper.phoneOverlay.setScreen('picker');
    PhoneGameInstallHelper.phoneOverlay.setStatusText('');
    PhoneGameInstallHelper.phoneOverlay.open().catch(() => {
    });
  }

  static onEngineStatus(status: string): void {
    if (status === 'phone_install:ok') {
      PhoneGameInstallHelper.onInstallSuccess();
      return;
    }
    if (status.startsWith('phone_install:err:')) {
      const msg = status.substring('phone_install:err:'.length);
      PhoneGameInstallHelper.phoneOverlay?.setStatusText(msg);
    }
  }

  static openPickerScreen(): void {
    PhoneGameInstallHelper.phoneOverlay?.setScreen('picker');
    PhoneGameInstallHelper.phoneOverlay?.setStatusText('');
  }

  static openGateScreen(): void {
    PhoneGameInstallHelper.phoneOverlay?.setScreen('gate');
    PhoneGameInstallHelper.phoneOverlay?.setStatusText('');
  }

  static async openDownloadSite(context: common.UIAbilityContext): Promise<void> {
    await OhosUiBridge.openContentDbDownload(context);
  }

  static async pickAndInstall(context: common.UIAbilityContext, cacheDir: string): Promise<void> {
    if (PhoneGameInstallHelper.picking) {
      return;
    }
    PhoneGameInstallHelper.picking = true;
    PhoneGameInstallHelper.phoneOverlay?.setStatusText('');
    PhoneGameInstallHelper.gamesBeforePick =
      PhoneGameInstallHelper.listUserSubgameIds(PhoneGameInstallHelper.watchUserDir);
    try {
      const extractDir = await OhosUiBridge.pickGamePackage(context, cacheDir);
      hilog.info(DOMAIN, TAG, 'pick ok -> %{public}s', extractDir);
      PhoneGameInstallHelper.phoneOverlay?.setStatusText('正在安装…');
      PhoneGameInstallHelper.beginInstallWatch();
      completeOhosFilePick(PHONE_INSTALL_FORM, extractDir);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'pick canceled or failed: %{public}s', `${e}`);
      completeOhosFilePick(PHONE_INSTALL_FORM, '');
      PhoneGameInstallHelper.phoneOverlay?.setStatusText('已取消选择');
      PhoneGameInstallHelper.endInstallWatch();
    } finally {
      PhoneGameInstallHelper.picking = false;
    }
  }

  private static beginInstallWatch(): void {
    PhoneGameInstallHelper.endInstallWatch();
    let ticks = 0;
    PhoneGameInstallHelper.installWatchTimer = setInterval(() => {
      ticks++;
      const status = getEngineStatus();
      if (status === 'phone_install:ok' || status.startsWith('phone_install:err:')) {
        PhoneGameInstallHelper.onEngineStatus(status);
        PhoneGameInstallHelper.endInstallWatch();
        return;
      }
      const userDir = PhoneGameInstallHelper.watchUserDir;
      if (userDir.length > 0) {
        const after = PhoneGameInstallHelper.listUserSubgameIds(userDir);
        if (after.length > PhoneGameInstallHelper.gamesBeforePick.length) {
          hilog.info(DOMAIN, TAG, 'install watch: new subgame detected');
          PhoneGameInstallHelper.onInstallSuccess();
          PhoneGameInstallHelper.endInstallWatch();
          return;
        }
      }
      if (ticks >= 300) {
        hilog.warn(DOMAIN, TAG, 'install watch timeout');
        PhoneGameInstallHelper.phoneOverlay?.setStatusText('安装超时，请重试');
        PhoneGameInstallHelper.endInstallWatch();
      }
    }, 100) as number;
  }

  private static endInstallWatch(): void {
    if (PhoneGameInstallHelper.installWatchTimer >= 0) {
      clearInterval(PhoneGameInstallHelper.installWatchTimer);
      PhoneGameInstallHelper.installWatchTimer = -1;
    }
  }

  private static finish(): void {
    PhoneGameInstallHelper.endInstallWatch();
    PhoneGameInstallHelper.additionalPicker = false;
    PhoneGameInstallHelper.phoneOverlay?.setStatusText('');
    PhoneGameInstallHelper.phoneOverlay?.close();
    const resolve = PhoneGameInstallHelper.pendingResolve;
    PhoneGameInstallHelper.pendingResolve = undefined;
    if (resolve) {
      resolve();
    }
  }
}
