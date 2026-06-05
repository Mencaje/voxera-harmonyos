import { PhoneAboutTab } from './PhoneAboutTab';
import { PhoneContentTab } from './PhoneContentTab';
import { PhoneSettingsTab } from './PhoneSettingsTab';
import { PhoneContentState, PhoneContentHelper } from '../util/PhoneContentHelper';
import { PhoneSettingsState, PhoneSettingsHelper } from '../util/PhoneSettingsHelper';
import { CONTENT_INSTALLED_LABEL } from '../util/PhoneContentTexts';
import {
  SETTINGS_BODY_PAD_H,
  SETTINGS_CAPSULE_BG,
  SETTINGS_CAPSULE_BORDER,
  SETTINGS_CAPSULE_HEIGHT,
  SETTINGS_FIELD_PLACEHOLDER_COLOR,
  SETTINGS_FIELD_TEXT_COLOR,
  SETTINGS_PANEL_GAP,
  SETTINGS_SEARCH_HINT,
  SETTINGS_SHOW_ADVANCED,
  SETTINGS_SIDEBAR_WIDTH,
  SETTINGS_TOGGLE_KNOB_COLOR,
  SETTINGS_TOGGLE_OFF_TRACK_COLOR,
  SETTINGS_TOGGLE_ON_COLOR,
} from '../util/PhoneSettingsTexts';

/** Top bar tabs in the phone more-menu screen. */
export type PhoneMenuTab = 'about' | 'settings' | 'content';

const MENU_ORB_VP: number = 40;
const MENU_ORB_ICON_VP: number = 22;
const MENU_ORB_TOP_VP: number = 10;
const MENU_ORB_RIGHT_VP: number = 16;
const MENU_ORB_LEFT_VP: number = 16;
const MENU_ORB_GAP_VP: number = 10;
const CONTENT_LABEL_SIZE: number = 18;
const CONTENT_HEADER_LABEL_COLOR: string = '#E6C200';
const SETTINGS_BAR_FONT_SIZE: number = 14;
const SETTINGS_TOGGLE_GAP_VP: number = 14;
const SEARCH_CAPSULE_CLEAR_VP: number = 28;
const SEARCH_CAPSULE_ICON_VP: number = 18;
const ICON_IDLE: string = '#333333';
const ICON_ACTIVE: string = '#0A59F7';
/** mengchuang_brand.svg viewBox 2278×1080 — slightly taller than top orbs */
const BRAND_LOGO_HEIGHT_VP: number = 50;
const BRAND_LOGO_WIDTH_VP: number = Math.round(BRAND_LOGO_HEIGHT_VP * 2278 / 1080);

@Component
export struct PhoneMoreMenuScreen {
  @Link visible: boolean;
  @Prop shareDir: string = '';
  @Prop contentState: PhoneContentState = {};
  @Prop @Watch('onSettingsStateChanged') settingsState: PhoneSettingsState = {};
  @Prop initialTab: PhoneMenuTab = 'about';
  /** In-game pause: settings body + close only (no about/content/settings orbs). */
  @Prop pauseSettingsMode: boolean = false;
  /** Main-menu more menu: show Content tab orb. Ignored when pauseSettingsMode. */
  @Prop showContentTab: boolean = true;
  @State activeTab: PhoneMenuTab = 'about';
  @State settingsSearchDraft: string = '';

  aboutToAppear(): void {
    if (this.pauseSettingsMode) {
      this.activeTab = 'settings';
      this.settingsSearchDraft = this.settingsState.query ?? '';
      PhoneSettingsHelper.refresh();
      return;
    }
    let tab = this.initialTab;
    if (!this.showContentTab && tab === 'content') {
      tab = 'settings';
    }
    this.activeTab = tab;
    this.settingsSearchDraft = this.settingsState.query ?? '';
    if (this.activeTab === 'content') {
      PhoneContentHelper.refresh();
    } else if (this.activeTab === 'settings') {
      PhoneSettingsHelper.refresh();
    }
  }

  onSettingsStateChanged(): void {
    this.settingsSearchDraft = this.settingsState.query ?? '';
  }

  private close(): void {
    this.visible = false;
  }

  private selectTab(tab: PhoneMenuTab): void {
    if (this.pauseSettingsMode) {
      return;
    }
    if (!this.showContentTab && tab === 'content') {
      return;
    }
    this.activeTab = tab;
    if (tab === 'content') {
      PhoneContentHelper.refresh();
    } else if (tab === 'settings') {
      PhoneSettingsHelper.refresh();
    }
  }

  private tabIconColor(tab: PhoneMenuTab): string {
    return this.activeTab === tab ? ICON_ACTIVE : ICON_IDLE;
  }

  @Builder
  private tabOrb(symbol: Resource, tab: PhoneMenuTab): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(MENU_ORB_ICON_VP)
        .fontColor([this.tabIconColor(tab)])
    }
    .width(MENU_ORB_VP)
    .height(MENU_ORB_VP)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 0.5,
      color: 'rgba(255, 255, 255, 0.55)',
    })
    .onClick(() => {
      this.selectTab(tab);
    })
  }

  @Builder
  private closeOrb(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(MENU_ORB_ICON_VP)
        .fontColor([ICON_IDLE])
    }
    .width(MENU_ORB_VP)
    .height(MENU_ORB_VP)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 0.5,
      color: 'rgba(255, 255, 255, 0.55)',
    })
    .onClick(() => {
      this.close();
    })
  }

  @Builder
  private menuOrbs(): void {
    Row({ space: MENU_ORB_GAP_VP }) {
      if (!this.pauseSettingsMode) {
        this.tabOrb($r('sys.symbol.info_circle_fill'), 'about')
        this.tabOrb($r('sys.symbol.gearshape_fill'), 'settings')
        if (this.showContentTab) {
          this.tabOrb($r('sys.symbol.doc_text_fill'), 'content')
        }
      }
      this.closeOrb()
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private aboutHeaderBar(): void {
    Row() {
      Image($r('app.media.mengchuang_brand'))
        .width(BRAND_LOGO_WIDTH_VP)
        .height(BRAND_LOGO_HEIGHT_VP)
        .objectFit(ImageFit.Contain)

      Blank()
        .layoutWeight(1)

      this.menuOrbs()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private contentHeaderBar(): void {
    Row() {
      Text(CONTENT_INSTALLED_LABEL)
        .fontSize(CONTENT_LABEL_SIZE)
        .fontColor(CONTENT_HEADER_LABEL_COLOR)
        .fontWeight(FontWeight.Medium)
        .height(MENU_ORB_VP)
        .textAlign(TextAlign.Start)
      Blank()
        .layoutWeight(1)
      this.menuOrbs()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private clearSettingsSearch(): void {
    this.settingsSearchDraft = '';
    PhoneSettingsHelper.search('');
  }

  @Builder
  private settingsToggleRow(label: string, settingName: string, enabled: boolean): void {
    Row({ space: 6 }) {
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(SETTINGS_TOGGLE_ON_COLOR)
        .switchPointColor(SETTINGS_TOGGLE_KNOB_COLOR)
        .switchStyle({
          pointColor: SETTINGS_TOGGLE_KNOB_COLOR,
          unselectedColor: SETTINGS_TOGGLE_OFF_TRACK_COLOR,
        })
        .onChange((on: boolean) => {
          PhoneSettingsHelper.setUiBool(settingName, on);
        })
      Text(label)
        .fontSize(SETTINGS_BAR_FONT_SIZE)
        .fontColor(ICON_IDLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(MENU_ORB_VP)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private settingsSearchCapsule(): void {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(SEARCH_CAPSULE_ICON_VP)
        .fontColor([ICON_IDLE])

      TextInput({ text: this.settingsSearchDraft, placeholder: SETTINGS_SEARCH_HINT })
        .layoutWeight(1)
        .height(SETTINGS_CAPSULE_HEIGHT)
        .fontSize(SETTINGS_BAR_FONT_SIZE)
        .fontColor(SETTINGS_FIELD_TEXT_COLOR)
        .placeholderFont({ size: SETTINGS_BAR_FONT_SIZE })
        .placeholderColor(SETTINGS_FIELD_PLACEHOLDER_COLOR)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .borderRadius(0)
        .onChange((value: string) => {
          this.settingsSearchDraft = value;
        })
        .onSubmit(() => {
          PhoneSettingsHelper.search(this.settingsSearchDraft);
        })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(SEARCH_CAPSULE_ICON_VP)
          .fontColor([ICON_IDLE])
      }
      .width(SEARCH_CAPSULE_CLEAR_VP)
      .height(SEARCH_CAPSULE_CLEAR_VP)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.clearSettingsSearch();
      })
    }
    .width(SETTINGS_SIDEBAR_WIDTH)
    .height(SETTINGS_CAPSULE_HEIGHT)
    .padding({ left: 12, right: 6 })
    .borderRadius(SETTINGS_CAPSULE_HEIGHT / 2)
    .backgroundColor(SETTINGS_CAPSULE_BG)
    .border({
      width: 1,
      color: SETTINGS_CAPSULE_BORDER,
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private settingsHeaderBar(): void {
    Row() {
      Row({ space: SETTINGS_TOGGLE_GAP_VP }) {
        this.settingsSearchCapsule()
        this.settingsToggleRow(
          SETTINGS_SHOW_ADVANCED,
          'show_advanced',
          this.settingsState.showAdvanced === true,
        )
      }
      .alignItems(VerticalAlign.Center)

      Blank()
        .layoutWeight(1)

      this.menuOrbs()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private tabBody(): void {
    if (this.pauseSettingsMode || this.activeTab === 'settings') {
      PhoneSettingsTab({ settingsState: this.settingsState })
    } else if (this.activeTab === 'about') {
      PhoneAboutTab({ shareDir: this.shareDir })
    } else if (this.activeTab === 'content') {
      PhoneContentTab({ contentState: this.contentState })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#FFFFFF')

      Column() {
        if (this.pauseSettingsMode || this.activeTab === 'settings') {
          Row() {
            this.settingsHeaderBar()
          }
          .width('100%')
          .padding({
            top: MENU_ORB_TOP_VP,
            left: MENU_ORB_LEFT_VP,
            right: MENU_ORB_RIGHT_VP,
          })
        } else if (this.activeTab === 'content') {
          Row() {
            this.contentHeaderBar()
          }
          .width('100%')
          .padding({
            top: MENU_ORB_TOP_VP,
            left: MENU_ORB_LEFT_VP,
            right: MENU_ORB_RIGHT_VP,
          })
        } else {
          Row() {
            this.aboutHeaderBar()
          }
          .width('100%')
          .padding({
            top: MENU_ORB_TOP_VP,
            left: MENU_ORB_LEFT_VP,
            right: MENU_ORB_RIGHT_VP,
          })
        }

        Column() {
          this.tabBody()
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 0 })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
