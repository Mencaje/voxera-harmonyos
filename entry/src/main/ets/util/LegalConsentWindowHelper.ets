import { display, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStageHolder } from './AppStageHolder';
import { DeviceFormFactor } from './DeviceFormFactor';
import { LegalConsentStore } from './LegalConsentStore';

const DOMAIN = 0x0000;
const TAG = 'LegalConsentWin';
const FLOAT_NAME = 'voxeraLegalConsent';

class CenterRect {
  x: number = 0;
  y: number = 0;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

/** Phone: full-screen overlay on Game page (no subwindow). */
export interface LegalConsentPhoneOverlay {
  open(): Promise<void>;
  close(): void;
}

export class LegalConsentPhoneOverlayImpl implements LegalConsentPhoneOverlay {
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

/**
 * First-launch user agreement + privacy policy.
 * Tablet/PC: WindowStage subwindow. Phone: full-screen overlay on Game page.
 */
export class LegalConsentWindowHelper {
  private static floatWin: window.Window | undefined = undefined;
  private static uiContext: common.UIAbilityContext | undefined = undefined;
  private static pendingResolve: ((accepted: boolean) => void) | undefined = undefined;
  private static phoneOverlay: LegalConsentPhoneOverlay | undefined = undefined;

  static bindPhoneOverlay(host: LegalConsentPhoneOverlay): void {
    LegalConsentWindowHelper.phoneOverlay = host;
  }

  static async ensureAccepted(context: common.UIAbilityContext): Promise<boolean> {
    if (await LegalConsentStore.isAccepted(context)) {
      return true;
    }
    return LegalConsentWindowHelper.show(context);
  }

  static async show(context: common.UIAbilityContext): Promise<boolean> {
    if (LegalConsentWindowHelper.pendingResolve) {
      return new Promise<boolean>((resolve) => {
        const prev = LegalConsentWindowHelper.pendingResolve!;
        LegalConsentWindowHelper.pendingResolve = (accepted: boolean) => {
          prev(accepted);
          resolve(accepted);
        };
      });
    }
    LegalConsentWindowHelper.uiContext = context;
    if (DeviceFormFactor.isPhone() && LegalConsentWindowHelper.phoneOverlay) {
      return new Promise<boolean>((resolve) => {
        LegalConsentWindowHelper.pendingResolve = resolve;
        LegalConsentWindowHelper.phoneOverlay!.open();
      });
    }
    return new Promise<boolean>(async (resolve) => {
      LegalConsentWindowHelper.pendingResolve = resolve;
      try {
        await LegalConsentWindowHelper.openSubWindow(context);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'open subwindow failed: %{public}s', `${e}`);
        LegalConsentWindowHelper.finish(false);
      }
    });
  }

  static async accept(): Promise<void> {
    const ctx = LegalConsentWindowHelper.uiContext;
    if (ctx) {
      await LegalConsentStore.markAccepted(ctx);
    }
    if (DeviceFormFactor.isPhone() && LegalConsentWindowHelper.phoneOverlay) {
      LegalConsentWindowHelper.phoneOverlay.close();
      LegalConsentWindowHelper.finish(true);
      return;
    }
    await LegalConsentWindowHelper.destroy();
    LegalConsentWindowHelper.finish(true);
  }

  static decline(): void {
    const ctx = LegalConsentWindowHelper.uiContext;
    if (DeviceFormFactor.isPhone() && LegalConsentWindowHelper.phoneOverlay) {
      LegalConsentWindowHelper.phoneOverlay.close();
      LegalConsentWindowHelper.finish(false);
      if (ctx) {
        try {
          ctx.terminateSelf();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'terminateSelf: %{public}s', `${e}`);
        }
      }
      return;
    }
    LegalConsentWindowHelper.destroy().then(() => {
      LegalConsentWindowHelper.finish(false);
      if (ctx) {
        try {
          ctx.terminateSelf();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'terminateSelf: %{public}s', `${e}`);
        }
      }
    }).catch(() => {
      LegalConsentWindowHelper.finish(false);
    });
  }

  private static finish(accepted: boolean): void {
    const resolve = LegalConsentWindowHelper.pendingResolve;
    LegalConsentWindowHelper.pendingResolve = undefined;
    LegalConsentWindowHelper.uiContext = undefined;
    if (resolve) {
      resolve(accepted);
    }
  }

  private static async destroy(): Promise<void> {
    const win = LegalConsentWindowHelper.floatWin;
    LegalConsentWindowHelper.floatWin = undefined;
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
    const size = DeviceFormFactor.legalConsentDialogSize();
    const pos = LegalConsentWindowHelper.centerRect(size.width, size.height);
    await win.resize(size.width, size.height);
    await win.moveWindowTo(pos.x, pos.y);
    try {
      await win.setWindowDecorVisible(false);
    } catch {
      // optional on some devices
    }
    try {
      win.setWindowBackgroundColor('#FFFFFF');
    } catch {
      // after loadContent on some API levels
    }
    await win.loadContent(DeviceFormFactor.legalConsentPage());
    try {
      win.setWindowBackgroundColor('#FFFFFF');
    } catch {
      // ignore
    }
    await win.showWindow();
    LegalConsentWindowHelper.floatWin = win;
    hilog.info(DOMAIN, TAG, 'legal consent window shown %{public}dx%{public}d at %{public}d,%{public}d page=%{public}s',
      size.width, size.height, pos.x, pos.y, DeviceFormFactor.legalConsentPage());
  }

  private static async openSubWindow(context: common.UIAbilityContext): Promise<void> {
    const stage = AppStageHolder.get();
    if (!stage) {
      throw new Error('WindowStage not ready');
    }
    const win = await stage.createSubWindow(FLOAT_NAME);
    await LegalConsentWindowHelper.configureWindow(win);
  }
}
