import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  PAUSE_BRAND,
  PAUSE_CAPSULE_BG,
  PAUSE_CAPSULE_BORDER,
  PAUSE_CAPSULE_HEIGHT,
  PAUSE_CARD_BG,
  PAUSE_CARD_RADIUS,
  PAUSE_CONTINUE,
  PAUSE_EXIT_MENU,
  PAUSE_EXIT_OS,
  PAUSE_INFO_HEADER,
  PAUSE_MODE_SINGLE,
  PAUSE_SCRIM_TINT,
  PAUSE_SETTINGS,
  PAUSE_TITLE,
  PAUSE_VERSION,
} from '../util/PhoneInGamePauseTexts';

const PAUSE_LOG_DOMAIN = 0x0000;
const PAUSE_LOG_TAG = 'PhonePause';

/** In-game pause dialog (phone): scrim + centered card (no blur — blur breaks touch hit-test on OHOS). */
@Component
export struct PhoneInGamePauseOverlay {
  @Prop progressLabel: string = '';
  onContinue: () => void = () => {
  };
  onSettings: () => void = () => {
  };
  onExitMenu: () => void = () => {
  };
  onExitOs: () => void = () => {
  };

  @Builder
  private capsuleButton(label: string, onTap: () => void): void {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(label)
        .fontSize(15)
        .fontColor('#222222')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(PAUSE_CAPSULE_HEIGHT)
    .backgroundColor(PAUSE_CAPSULE_BG)
    .border({
      width: 0.5,
      color: PAUSE_CAPSULE_BORDER,
    })
    .onClick((): void => {
      hilog.info(PAUSE_LOG_DOMAIN, PAUSE_LOG_TAG, 'button: %{public}s', label);
      onTap();
    })
    .focusable(true)
    .hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private pauseCard(): void {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(PAUSE_BRAND)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')
        Text(PAUSE_VERSION)
          .fontSize(12)
          .fontColor('#666666')
        Text(PAUSE_INFO_HEADER)
          .fontSize(13)
          .fontColor('#444444')
          .margin({ top: 10 })
        Text(PAUSE_MODE_SINGLE)
          .fontSize(13)
          .fontColor('#555555')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        Text(PAUSE_TITLE)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#222222')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 4 })
        this.capsuleButton(PAUSE_CONTINUE, (): void => {
          this.onContinue();
        })
        this.capsuleButton(PAUSE_SETTINGS, (): void => {
          this.onSettings();
        })
        this.capsuleButton(PAUSE_EXIT_MENU, (): void => {
          this.onExitMenu();
        })
        this.capsuleButton(PAUSE_EXIT_OS, (): void => {
          this.onExitOs();
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor(PAUSE_CARD_BG)
    .borderRadius(PAUSE_CARD_RADIUS)
    .shadow({
      radius: 24,
      color: 'rgba(0, 0, 0, 0.18)',
      offsetX: 0,
      offsetY: 8,
    })
  }

  @Builder
  private progressOverlay(): void {
    Column({ space: 14 }) {
      /* HarmonyOS system spinner — hidden; Luanti draws its own exit progress in-game. */
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#FFFFFF')
        .visibility(Visibility.Hidden)
      Text(this.progressLabel)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(0, 0, 0, 0.45)')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(PAUSE_SCRIM_TINT)

      if (this.progressLabel.length > 0) {
        this.progressOverlay()
      } else {
        Column() {
          this.pauseCard()
        }
        .width('100%')
        .padding({ left: 28, right: 28 })
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Default)
  }
}
