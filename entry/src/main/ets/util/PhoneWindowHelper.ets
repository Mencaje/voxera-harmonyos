import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DeviceFormFactor } from './DeviceFormFactor';
import { WindowDecorHelper } from './WindowDecorHelper';

const DOMAIN = 0x0000;
const TAG = 'PhoneWindow';

/** Phone-only window policy — landscape game + immersive fullscreen. */
export class PhoneWindowHelper {
  static async applyGameWindow(context: common.UIAbilityContext): Promise<void> {
    if (!DeviceFormFactor.isPhone()) {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      await win.setPreferredOrientation(window.Orientation.LANDSCAPE);
      await WindowDecorHelper.applyImmersiveFullscreen(win, true);
      hilog.info(DOMAIN, TAG, 'phone: landscape lock + immersive fullscreen');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'applyGameWindow failed: %{public}s', `${e}`);
    }
  }
}
