import {
  BACK_LABEL,
  DOWNLOAD_LABEL,
  DOWNLOAD_TOOLTIP,
  GATE_MESSAGE,
  INSTALL_GAME_BUTTON,
  PICK_TOOLTIP,
} from '../util/PhoneGameInstallTexts';
import { PhoneGameInstallHelper, PhoneInstallScreen } from '../util/PhoneGameInstallHelper';
import { JOIN_DEFAULT_PORT } from '../util/PhoneJoinGameTexts';
import { PhoneContentState } from '../util/PhoneContentHelper';
import { PhoneSettingsState } from '../util/PhoneSettingsHelper';
import { PhoneJoinGameDrawer } from './PhoneJoinGameDrawer';
import { PhoneMoreMenuScreen } from './PhoneMoreMenuScreen';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PhoneGameInstall';
const DOMAIN = 0xA0000;

/** Bottom inset for landscape phone (nav bar / gesture area). */
const PICKER_FOOTER_BOTTOM_VP: number = 24;
const PICKER_FOOTER_SIDE_VP: number = 28;
const PICKER_TOP_VP: number = 28;
/** Frosted-glass orbs on the home (gate) screen top bar. */
const HOME_ORB_VP: number = 40;
const HOME_ORB_ICON_VP: number = 22;
const HOME_ORB_TOP_VP: number = 16;
const HOME_ORB_RIGHT_VP: number = 16;
const HOME_ORB_GAP_VP: number = 10;

@Component
export struct PhoneGameInstallPanel {
  @Prop screen: PhoneInstallScreen = 'gate';
  @Prop statusText: string = '';
  @Prop shareDir: string = '';
  @Prop contentState: PhoneContentState = {};
  @Prop settingsState: PhoneSettingsState = {};
  private uiContext: common.UIAbilityContext | undefined = undefined;
  @State plusTipVisible: boolean = false;
  @State backTipVisible: boolean = false;
  @State downloadTipVisible: boolean = false;
  @State joinDrawerOpen: boolean = false;
  @State moreMenuOpen: boolean = false;
  @State joinAddress: string = '';
  @State joinPort: string = JOIN_DEFAULT_PORT;
  @State joinServerDescription: string = '';
  @State joinPlayerName: string = '';
  @State joinPassword: string = '';

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private onInstallGame(): void {
    PhoneGameInstallHelper.openPickerScreen();
  }

  private onBack(): void {
    if (this.screen === 'picker') {
      if (PhoneGameInstallHelper.shouldPickerBackToGate()) {
        PhoneGameInstallHelper.openGateScreen();
      } else {
        PhoneGameInstallHelper.dismissAdditionalPicker();
      }
    }
  }

  private async onPick(): Promise<void> {
    if (!this.uiContext) {
      return;
    }
    await PhoneGameInstallHelper.pickAndInstall(this.uiContext, this.uiContext.cacheDir);
  }

  private async onDownload(): Promise<void> {
    if (!this.uiContext) {
      return;
    }
    await PhoneGameInstallHelper.openDownloadSite(this.uiContext);
  }

  private openJoinDrawer(): void {
    this.joinDrawerOpen = true;
    hilog.info(DOMAIN, TAG, 'join drawer open');
  }

  private openMoreMenu(): void {
    this.moreMenuOpen = true;
    hilog.info(DOMAIN, TAG, 'more menu open');
  }

  @Builder
  private homeFrostOrb(symbol: Resource, onTap: () => void): void {
    /* Button (not blurred Stack) — backdropBlur breaks hit-testing on HarmonyOS phones. */
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(HOME_ORB_ICON_VP)
        .fontColor(['#333333'])
    }
    .width(HOME_ORB_VP)
    .height(HOME_ORB_VP)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 0.5,
      color: 'rgba(255, 255, 255, 0.55)',
    })
    .onClick(onTap)
  }

  @Builder
  private homeTopOrbs(): void {
    Row({ space: HOME_ORB_GAP_VP }) {
      this.homeFrostOrb($r('sys.symbol.gamecontroller_fill'), () => {
        this.openJoinDrawer();
      })
      this.homeFrostOrb($r('sys.symbol.dot_grid_2x2'), () => {
        this.openMoreMenu();
      })
    }
  }

  @Builder
  private gateScreen(): void {
    Column({ space: 24 }) {
      Text(GATE_MESSAGE)
        .fontSize(17)
        .fontColor('#333333')
        .lineHeight(28)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 32, right: 32 })

      Button(INSTALL_GAME_BUTTON)
        .type(ButtonType.Capsule)
        .height(44)
        .fontSize(15)
        .fontColor('#666666')
        .backgroundColor('#E8E8E8')
        .padding({ left: 28, right: 28 })
        .onClick(() => this.onInstallGame())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private plusPickBox(): void {
    Stack() {
      Column()
        .width(88)
        .height(88)
        .border({ width: 2, color: '#AAAAAA', radius: 10 })
        .backgroundColor('#00000000')

      Text('+')
        .fontSize(40)
        .fontWeight(FontWeight.Lighter)
        .fontColor('#888888')
    }
    .width(88)
    .height(88)
    .onClick(() => {
      this.onPick();
    })
    .onHover((isHover: boolean) => {
      this.plusTipVisible = isHover;
    })
    .bindPopup(this.plusTipVisible, {
      message: PICK_TOOLTIP,
      placement: Placement.Bottom,
      showInSubWindow: true,
    })
  }

  @Builder
  private pickerFooter(): void {
    Row() {
      Button(BACK_LABEL)
        .type(ButtonType.Capsule)
        .height(40)
        .fontSize(14)
        .fontColor('#333333')
        .backgroundColor('#F0F0F0')
        .padding({ left: 22, right: 22 })
        .onClick(() => this.onBack())
        .onHover((isHover: boolean) => {
          this.backTipVisible = isHover;
        })
        .bindPopup(this.backTipVisible, {
          message: BACK_LABEL,
          placement: Placement.Top,
          showInSubWindow: true,
        })

      Blank()

      Button(DOWNLOAD_LABEL)
        .type(ButtonType.Capsule)
        .height(40)
        .fontSize(14)
        .fontColor('#333333')
        .backgroundColor('#F0F0F0')
        .padding({ left: 22, right: 22 })
        .onClick(() => {
          this.onDownload();
        })
        .onHover((isHover: boolean) => {
          this.downloadTipVisible = isHover;
        })
        .bindPopup(this.downloadTipVisible, {
          message: DOWNLOAD_TOOLTIP,
          placement: Placement.Top,
          showInSubWindow: true,
        })
    }
    .width('100%')
    .padding({
      left: PICKER_FOOTER_SIDE_VP,
      right: PICKER_FOOTER_SIDE_VP,
      bottom: PICKER_FOOTER_BOTTOM_VP,
    })
  }

  @Builder
  private installedGameCheckBox(_gameId: string): void {
    Stack() {
      Column()
        .width(88)
        .height(88)
        .border({ width: 2, color: '#66BB6A', radius: 10 })
        .backgroundColor('#E8F5E9')
      Text('✓')
        .fontSize(36)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2E7D32')
    }
    .width(88)
    .height(88)
  }

  @Builder
  private pickerTopRow(): void {
    Row({ space: 12 }) {
      this.plusPickBox()
      if (PhoneGameInstallHelper.isAdditionalPicker()) {
        ForEach(PhoneGameInstallHelper.listInstalledGameIds(), (gameId: string) => {
          this.installedGameCheckBox(gameId)
        }, (gameId: string) => gameId)
      }
    }
    .width('100%')
    .padding({ left: PICKER_TOP_VP, top: PICKER_TOP_VP })
  }

  @Builder
  private pickerScreen(): void {
    Column() {
      this.pickerTopRow()

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 48, right: 48, top: 16 })
      }

      Blank()

      this.pickerFooter()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (this.screen === 'gate' && !this.moreMenuOpen) {
          this.gateScreen()
        } else if (this.screen === 'gate' && this.moreMenuOpen) {
          PhoneMoreMenuScreen({ visible: $moreMenuOpen, shareDir: this.shareDir,
            contentState: this.contentState, settingsState: this.settingsState })
            .width('100%')
            .height('100%')
        } else {
          this.pickerScreen()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      if (this.screen === 'gate' && !this.moreMenuOpen) {
        Row() {
          this.homeTopOrbs()
        }
        .width('100%')
        .height(HOME_ORB_VP + HOME_ORB_TOP_VP)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Bottom)
        .padding({
          top: HOME_ORB_TOP_VP,
          right: HOME_ORB_RIGHT_VP,
        })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(100)
      }

      if (this.screen === 'gate' && !this.moreMenuOpen && this.joinDrawerOpen) {
        PhoneJoinGameDrawer({
          visible: $joinDrawerOpen,
          address: $joinAddress,
          port: $joinPort,
          serverDescription: $joinServerDescription,
          playerName: $joinPlayerName,
          password: $joinPassword,
        })
          .width('100%')
          .height('100%')
          .zIndex(200)
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
