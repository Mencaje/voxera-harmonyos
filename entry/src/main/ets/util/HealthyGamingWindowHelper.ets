import { display, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStageHolder } from './AppStageHolder';
import { DeviceFormFactor } from './DeviceFormFactor';

const DOMAIN = 0x0000;
const TAG = 'HealthyGamingWin';
const FLOAT_NAME = 'voxeraHealthyGaming';

class CenterRect {
  x: number = 0;
  y: number = 0;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

/** Phone: full-screen overlay on Game page (no subwindow). */
export interface HealthyGamingPhoneOverlay {
  open(): Promise<void>;
  close(): void;
}

export class HealthyGamingPhoneOverlayImpl implements HealthyGamingPhoneOverlay {
  private openHandler: () => Promise<void>;
  private closeHandler: () => void;

  constructor(openHandler: () => Promise<void>, closeHandler: () => void) {
    this.openHandler = openHandler;
    this.closeHandler = closeHandler;
  }

  open(): Promise<void> {
    return this.openHandler();
  }

  close(): void {
    this.closeHandler();
  }
}

/** Shown every app launch after first-time legal consent is complete. */
export class HealthyGamingWindowHelper {
  private static floatWin: window.Window | undefined = undefined;
  private static pendingResolve: (() => void) | undefined = undefined;
  private static phoneOverlay: HealthyGamingPhoneOverlay | undefined = undefined;

  static bindPhoneOverlay(host: HealthyGamingPhoneOverlay): void {
    HealthyGamingWindowHelper.phoneOverlay = host;
  }

  static async show(context: common.UIAbilityContext): Promise<void> {
    if (DeviceFormFactor.isPhone() && HealthyGamingWindowHelper.phoneOverlay) {
      return HealthyGamingWindowHelper.phoneOverlay.open();
    }
    if (HealthyGamingWindowHelper.pendingResolve) {
      return new Promise<void>((resolve) => {
        const prev = HealthyGamingWindowHelper.pendingResolve!;
        HealthyGamingWindowHelper.pendingResolve = () => {
          prev();
          resolve();
        };
      });
    }
    return new Promise<void>(async (resolve) => {
      HealthyGamingWindowHelper.pendingResolve = resolve;
      try {
        await HealthyGamingWindowHelper.openSubWindow(context);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'open subwindow failed: %{public}s', `${e}`);
        HealthyGamingWindowHelper.finish();
      }
    });
  }

  static async confirm(): Promise<void> {
    if (DeviceFormFactor.isPhone() && HealthyGamingWindowHelper.phoneOverlay) {
      HealthyGamingWindowHelper.phoneOverlay.close();
      return;
    }
    await HealthyGamingWindowHelper.destroy();
    HealthyGamingWindowHelper.finish();
  }

  private static finish(): void {
    const resolve = HealthyGamingWindowHelper.pendingResolve;
    HealthyGamingWindowHelper.pendingResolve = undefined;
    if (resolve) {
      resolve();
    }
  }

  private static async destroy(): Promise<void> {
    const win = HealthyGamingWindowHelper.floatWin;
    HealthyGamingWindowHelper.floatWin = undefined;
    if (!win) {
      return;
    }
    try {
      await win.destroyWindow();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'destroyWindow: %{public}s', `${e}`);
    }
  }

  private static centerRect(width: number, height: number): CenterRect {
    try {
      const d = display.getDefaultDisplaySync();
      const x = Math.max(0, Math.floor((d.width - width) / 2));
      const y = Math.max(0, Math.floor((d.height - height) / 2));
      return new CenterRect(x, y);
    } catch {
      return new CenterRect(80, 60);
    }
  }

  private static async configureWindow(win: window.Window): Promise<void> {
    const size = DeviceFormFactor.healthyGamingDialogSize();
    const pos = HealthyGamingWindowHelper.centerRect(size.width, size.height);
    await win.resize(size.width, size.height);
    await win.moveWindowTo(pos.x, pos.y);
    try {
      await win.setWindowDecorVisible(false);
    } catch {
      // optional
    }
    try {
      win.setWindowBackgroundColor('#FFFFFF');
    } catch {
      // ignore
    }
    await win.loadContent(DeviceFormFactor.healthyGamingPage());
    try {
      win.setWindowBackgroundColor('#FFFFFF');
    } catch {
      // ignore
    }
    await win.showWindow();
    HealthyGamingWindowHelper.floatWin = win;
    hilog.info(DOMAIN, TAG, 'healthy gaming window shown %{public}dx%{public}d page=%{public}s',
      size.width, size.height, DeviceFormFactor.healthyGamingPage());
  }

  private static async openSubWindow(context: common.UIAbilityContext): Promise<void> {
    const stage = AppStageHolder.get();
    if (!stage) {
      throw new Error('WindowStage not ready');
    }
    const win = await stage.createSubWindow(FLOAT_NAME);
    await HealthyGamingWindowHelper.configureWindow(win);
  }
}
