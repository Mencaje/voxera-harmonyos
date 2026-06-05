import { window } from '@kit.ArkUI';

/** Set from EntryAbility; used as fallback when TYPE_FLOAT createWindow is unavailable. */
export class AppStageHolder {
  private static stage: window.WindowStage | undefined = undefined;

  static set(stage: window.WindowStage): void {
    AppStageHolder.stage = stage;
  }

  static get(): window.WindowStage | undefined {
    return AppStageHolder.stage;
  }
}
