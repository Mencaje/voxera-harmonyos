import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DeviceFormFactor } from './DeviceFormFactor';
import { WindowDecorHelper } from './WindowDecorHelper';

const DOMAIN = 0x0000;
const TAG = 'TabletWindow';

/** Tablet-only window policy — PC (2in1) and phone use their own helpers. */
export class TabletWindowHelper {
  static async applyGameWindow(context: common.UIAbilityContext): Promise<void> {
    if (!DeviceFormFactor.isTablet()) {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
      await WindowDecorHelper.applyImmersiveFullscreen(win, true);
      hilog.info(DOMAIN, TAG, 'tablet: landscape lock + immersive fullscreen');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'applyGameWindow failed: %{public}s', `${e}`);
    }
  }
}
