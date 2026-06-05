import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { AppStageHolder } from '../util/AppStageHolder';
import { TabletWindowHelper } from '../util/TabletWindowHelper';
import { PhoneWindowHelper } from '../util/PhoneWindowHelper';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    AppStageHolder.set(windowStage);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    /* Load Game immediately so system start window (layer 1) hands off to layer 2 on first frame. */
    windowStage.loadContent('pages/Game', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    /* Landscape + immersive in parallel — must not block loadContent (was eating layer 1). */
    windowStage.getMainWindow().then(async (win: window.Window) => {
      try {
        if (deviceInfo.deviceType === 'tablet') {
          await TabletWindowHelper.applyGameWindow(this.context);
        } else if (deviceInfo.deviceType === 'phone' || deviceInfo.deviceType === 'default') {
          await PhoneWindowHelper.applyGameWindow(this.context);
        } else if (deviceInfo.deviceType === '2in1') {
          win.setWindowDecorVisible(false);
          win.setWindowDecorHeight(64);
          hilog.info(DOMAIN, 'testTag', '2in1 window decor hidden, title button area height=64vp');
        }
      } catch (err) {
        hilog.warn(DOMAIN, 'testTag', 'window setup failed: %{public}s', JSON.stringify(err));
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'getMainWindow failed: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
