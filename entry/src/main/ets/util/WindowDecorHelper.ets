import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0000;
const TAG = 'WindowDecorHelper';

/** 仅查询系统标题按钮区域，不改窗口/按钮样式。 */
export class WindowDecorHelper {
  private mainWindow: window.Window | undefined = undefined;
  private rectHandler: ((rect: window.TitleButtonRect) => void) | undefined = undefined;
  private statusHandler: ((status: window.WindowStatusType) => void) | undefined = undefined;
  /** Luanti F11 / settings fullscreen — hide status bar + dock (immersive). */
  immersiveActive: boolean = false;
  private currentWindowStatus: window.WindowStatusType = window.WindowStatusType.FLOATING;
  private windowStatusBeforeImmersive: window.WindowStatusType = window.WindowStatusType.FLOATING;
  onRectChange: (rect: window.TitleButtonRect) => void = () => {
  };

  async attach(context: common.UIAbilityContext): Promise<void> {
    if (deviceInfo.deviceType !== '2in1') {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      this.mainWindow = win;
      const rect = win.getTitleButtonRect();
      this.onRectChange(rect);
      this.rectHandler = (r: window.TitleButtonRect) => {
        this.onRectChange(r);
      };
      win.on('windowTitleButtonRectChange', this.rectHandler);
      this.statusHandler = (status: window.WindowStatusType) => {
        this.currentWindowStatus = status;
      };
      win.on('windowStatusChange', this.statusHandler);
      hilog.info(DOMAIN, TAG, 'title buttons rect %{public}d,%{public}d %{public}dx%{public}d',
        rect.right, rect.top, rect.width, rect.height);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'attach failed: %{public}s', JSON.stringify(err));
    }
  }

  detach(): void {
    if (this.mainWindow) {
      try {
        if (this.rectHandler) {
          this.mainWindow.off('windowTitleButtonRectChange', this.rectHandler);
        }
        if (this.statusHandler) {
          this.mainWindow.off('windowStatusChange', this.statusHandler);
        }
      } catch (_e) {
        // ignore
      }
    }
    this.mainWindow = undefined;
    this.rectHandler = undefined;
    this.statusHandler = undefined;
    this.immersiveActive = false;
  }

  /**
   * HarmonyOS 2in1 (PC): setWindowLayoutFullScreen is unsupported in free multi-window mode
   * (WMS logs "OnSetWindowLayoutFullScreen device not support"). Use maximize presentation instead.
   * @see window.Window.maximize / MaximizePresentation / setTitleAndDockHoverShown (API 12–20)
   */
  static async applyImmersiveFullscreen(win: window.Window, immersive: boolean,
    statusBefore?: window.WindowStatusType): Promise<void> {
    if (deviceInfo.deviceType === '2in1') {
      if (immersive) {
        await win.maximize(window.MaximizePresentation.ENTER_IMMERSIVE_DISABLE_TITLE_AND_DOCK_HOVER);
        await win.setTitleAndDockHoverShown(false, false);
        hilog.info(DOMAIN, TAG, '2in1 immersive ON (maximize presentation, dock hover off)');
      } else {
        await win.maximize(window.MaximizePresentation.EXIT_IMMERSIVE);
        await win.setTitleAndDockHoverShown(true, true);
        const prior = statusBefore ?? window.WindowStatusType.FLOATING;
        if (prior === window.WindowStatusType.FLOATING) {
          await win.recover();
        }
        hilog.info(DOMAIN, TAG, '2in1 immersive OFF (recover=%{public}s)',
          prior === window.WindowStatusType.FLOATING ? 'yes' : 'no');
      }
      return;
    }
    await win.setWindowLayoutFullScreen(immersive);
    await win.setWindowSystemBarEnable(immersive ? [] : ['status', 'navigation']);
    hilog.info(DOMAIN, TAG, 'layout fullscreen=%{public}s', immersive ? 'on' : 'off');
  }

  async setImmersive(context: common.UIAbilityContext, immersive: boolean): Promise<void> {
    this.immersiveActive = immersive;
    try {
      const win = this.mainWindow ?? await window.getLastWindow(context);
      this.mainWindow = win;
      if (immersive) {
        this.windowStatusBeforeImmersive = this.currentWindowStatus;
      }
      await WindowDecorHelper.applyImmersiveFullscreen(win, immersive,
        immersive ? undefined : this.windowStatusBeforeImmersive);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setImmersive failed: %{public}s', JSON.stringify(err));
    }
  }
}
