import {
  SETTINGS_BODY_PAD_H,
  SETTINGS_CAPSULE_BG,
  SETTINGS_CAPSULE_BORDER,
  SETTINGS_CAPSULE_FONT_SIZE,
  SETTINGS_CAPSULE_HEIGHT,
  SETTINGS_CAPSULE_SET_BG,
  SETTINGS_CAPSULE_SET_PAD_H,
  SETTINGS_CAPSULE_SET_TEXT,
  SETTINGS_DEFAULT_PREFIX,
  SETTINGS_FIELD_PLACEHOLDER_COLOR,
  SETTINGS_FIELD_TEXT_COLOR,
  SETTINGS_HELP_TIP_MAX_LINES,
  SETTINGS_HINT_TITLE,
  SETTINGS_NO_RESULTS,
  SETTINGS_PANEL_GAP,
  SETTINGS_RESET,
  SETTINGS_SET,
  SETTINGS_SIDEBAR_WIDTH,
  SETTINGS_TOGGLE_KNOB_COLOR,
  SETTINGS_TOGGLE_OFF_TRACK_COLOR,
  SETTINGS_TOGGLE_ON_COLOR,
} from '../util/PhoneSettingsTexts';
import {
  PhoneSettingsFlag,
  PhoneSettingsHelper,
  PhoneSettingsItem,
  PhoneSettingsPage,
  PhoneSettingsState,
  PhoneSettingsV3f,
  copyPhoneSettingsItems,
  copyPhoneSettingsPages,
} from '../util/PhoneSettingsHelper';

const LABEL_COLOR: string = '#E6C200';
const VALUE_COLOR: string = '#666666';
const BTN_BG: string = '#505050';
const BTN_TEXT: string = '#FFFFFF';
const PAGE_ROW_H: number = 34;
const SECTION_COLOR: string = '#C87800';
const INFO_ICON_SIZE: number = 30;
const INFO_GLYPH_SIZE: number = 18;

@Component
export struct PhoneSettingsTab {
  @Prop @Watch('onSettingsStateChanged') settingsState: PhoneSettingsState = {};
  /** Local mirrors — @Prop nested objects do not reliably refresh ForEach rows in-game. */
  @State private pagesLocal: PhoneSettingsPage[] = [];
  @State private itemsLocal: PhoneSettingsItem[] = [];
  @State private selectedPageIdLocal: string = '';
  @State pendingText: Record<string, string> = {};
  @State pendingV3f: Record<string, PhoneSettingsV3f> = {};
  @State helpDialogOpen: boolean = false;
  @State helpDialogText: string = '';
  @State activeHelpTipId: string = '';
  @State helpTipText: string = '';
  private pendingPageId: string = '';

  aboutToAppear(): void {
    this.syncFromProp();
    PhoneSettingsHelper.refresh();
  }

  aboutToUpdate(): void {
    this.syncFromProp();
  }

  onSettingsStateChanged(): void {
    this.syncFromProp();
    this.pendingText = {};
    this.pendingV3f = {};
  }

  private syncFromProp(): void {
    const pageId = this.settingsState.selectedPageId ?? '';
    if (this.pendingPageId.length > 0) {
      if (pageId === this.pendingPageId) {
        this.pendingPageId = '';
        this.selectedPageIdLocal = pageId;
      }
    } else {
      this.selectedPageIdLocal = pageId;
    }
    this.pagesLocal = copyPhoneSettingsPages(this.settingsState.pages);
    this.itemsLocal = copyPhoneSettingsItems(this.settingsState.items);
  }

  aboutToDisappear(): void {
    PhoneSettingsHelper.persist();
  }

  private pages(): PhoneSettingsPage[] {
    return this.pagesLocal;
  }

  private items(): PhoneSettingsItem[] {
    return this.itemsLocal;
  }

  private selectedPageId(): string {
    return this.selectedPageIdLocal;
  }

  private onPageTap(pageId: string): void {
    this.selectedPageIdLocal = pageId;
    this.pendingPageId = pageId;
    PhoneSettingsHelper.selectPage(pageId);
  }

  private enumSelectOptions(item: PhoneSettingsItem): SelectOption[] {
    const out: SelectOption[] = [];
    const options = item.options ?? [];
    for (let i = 0; i < options.length; i++) {
      out.push({ value: options[i].label });
    }
    return out;
  }

  private enumSelectedLabel(item: PhoneSettingsItem): string {
    const options = item.options ?? [];
    const idx = (item.selectedIndex ?? 1) - 1;
    if (idx >= 0 && idx < options.length) {
      return options[idx].label;
    }
    return '';
  }

  private textDraft(name: string, fallback: string): string {
    const draft = this.pendingText[name];
    if (draft !== undefined) {
      return draft;
    }
    return fallback;
  }

  private v3fDraft(name: string, item: PhoneSettingsItem): PhoneSettingsV3f {
    const draft = this.pendingV3f[name];
    if (draft !== undefined) {
      return draft;
    }
    return {
      x: item.x ?? 0,
      y: item.y ?? 0,
      z: item.z ?? 0,
    };
  }

  private settingComment(item: PhoneSettingsItem): string {
    return (item.comment ?? '').trim();
  }

  private hasSettingComment(item: PhoneSettingsItem): boolean {
    return this.settingComment(item).length > 0;
  }

  private helpTipId(item: PhoneSettingsItem, suffix: string = ''): string {
    const base = item.name ?? item.label ?? item.action ?? suffix;
    return `${item.kind}_${base}`;
  }

  private truncateHelpTip(text: string): string {
    const lines = text.split('\n');
    if (lines.length > SETTINGS_HELP_TIP_MAX_LINES) {
      return lines.slice(0, SETTINGS_HELP_TIP_MAX_LINES).join('\n') + '...';
    }
    if (text.length > 480) {
      return text.substring(0, 480) + '...';
    }
    return text;
  }

  private openHelpDialog(text: string): void {
    this.helpDialogText = text;
    this.helpDialogOpen = true;
  }

  private closeHelpDialog(): void {
    this.helpDialogOpen = false;
  }

  @Builder
  private helpTipPopupBody(): void {
    Column() {
      Text(this.truncateHelpTip(this.helpTipText))
        .fontSize(12)
        .fontColor('#333333')
        .lineHeight(18)
        .maxLines(SETTINGS_HELP_TIP_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding(12)
    .constraintSize({ maxWidth: 300 })
  }

  @Builder
  private settingInfoIcon(tipId: string, comment: string): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(INFO_GLYPH_SIZE)
        .fontColor([VALUE_COLOR])
    }
    .width(INFO_ICON_SIZE)
    .height(INFO_ICON_SIZE)
    .margin({ top: 2 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.openHelpDialog(comment);
    })
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.helpTipText = comment;
        this.activeHelpTipId = tipId;
      } else if (this.activeHelpTipId === tipId) {
        this.activeHelpTipId = '';
      }
    })
    .bindPopup(this.activeHelpTipId === tipId, {
      builder: this.helpTipPopupBody,
      placement: Placement.Bottom,
      showInSubWindow: true,
      popupColor: '#FFFFFF',
      enableArrow: true,
    })
  }

  @Builder
  private helpDialog(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .onClick(() => {
          this.closeHelpDialog();
        })

      Column({ space: 12 }) {
        Row() {
          Text(SETTINGS_HINT_TITLE)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Blank()
            .layoutWeight(1)
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(16)
              .fontColor(['#666666'])
          }
          .width(32)
          .height(32)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.closeHelpDialog();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Text(this.helpDialogText)
            .fontSize(14)
            .fontColor('#333333')
            .lineHeight(20)
            .width('100%')
        }
        .align(Alignment.TopStart)
        .width('100%')
        .constraintSize({ maxHeight: 360 })
      }
      .width('82%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private sectionHeader(text: string): void {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(SECTION_COLOR)
      .width('100%')
      .padding({ left: 8, top: 6, bottom: 2 })
  }

  @Builder
  private pageRow(page: PhoneSettingsPage, showSection: boolean): void {
    if (showSection && page.section.length > 0) {
      this.sectionHeader(page.section)
    }
    Row() {
      Text(page.title)
        .fontSize(13)
        .fontColor(this.selectedPageId() === page.id ? '#0A59F7' : '#333333')
        .fontWeight(this.selectedPageId() === page.id ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(PAGE_ROW_H)
    .padding({ left: 8, right: 6 })
    .backgroundColor(this.selectedPageId() === page.id ? '#EEEEEE' : '#FFFFFF')
    .borderRadius(4)
    .stateStyles({
      pressed: {
        .backgroundColor(this.selectedPageId() === page.id ? '#DDDDDD' : '#F0F0F0')
      },
    })
    .onClick(() => {
      this.onPageTap(page.id);
    })
  }

  @Builder
  private pageList(): void {
    Scroll() {
      Column() {
        ForEach(this.pages(), (page: PhoneSettingsPage, index: number) => {
          this.pageRow(page, index === 0 || this.pages()[index - 1].section !== page.section)
        }, (page: PhoneSettingsPage): string => page.id)
        if (this.pages().length === 0) {
          Text(SETTINGS_NO_RESULTS)
            .fontSize(13)
            .fontColor(VALUE_COLOR)
            .padding(12)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .align(Alignment.TopStart)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor('#F5F5F5')
    .border({ width: 1, color: '#DDDDDD' })
  }

  @Builder
  private resetButton(name: string, defaultText?: string): void {
    if (name.length > 0) {
      Button(SETTINGS_RESET)
        .type(ButtonType.Normal)
        .height(28)
        .fontSize(12)
        .fontColor(BTN_TEXT)
        .backgroundColor(BTN_BG)
        .borderRadius(14)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          PhoneSettingsHelper.reset(name);
        })
      if ((defaultText ?? '').length > 0) {
        Text(`${SETTINGS_DEFAULT_PREFIX}${defaultText ?? ''}`)
          .fontSize(11)
          .fontColor(VALUE_COLOR)
          .margin({ top: 4 })
      }
    }
  }

  @Builder
  private textInputCapsule(item: PhoneSettingsItem): void {
    Row() {
      TextInput({
        text: this.textDraft(item.name ?? '', `${item.value ?? ''}`),
        placeholder: item.name ?? '',
      })
        .layoutWeight(1)
        .height(SETTINGS_CAPSULE_HEIGHT)
        .fontSize(SETTINGS_CAPSULE_FONT_SIZE)
        .fontColor(SETTINGS_FIELD_TEXT_COLOR)
        .placeholderColor(SETTINGS_FIELD_PLACEHOLDER_COLOR)
        .backgroundColor(Color.Transparent)
        .padding({ left: 12, right: 8 })
        .borderRadius(0)
        .onChange((value: string) => {
          if (item.name) {
            const next: Record<string, string> = {};
            next[item.name] = value;
            this.pendingText = next;
          }
        })

      Button(SETTINGS_SET)
        .type(ButtonType.Normal)
        .height(SETTINGS_CAPSULE_HEIGHT)
        .fontSize(SETTINGS_CAPSULE_FONT_SIZE)
        .fontColor(SETTINGS_CAPSULE_SET_TEXT)
        .backgroundColor(SETTINGS_CAPSULE_SET_BG)
        .borderRadius(0)
        .padding({ left: SETTINGS_CAPSULE_SET_PAD_H, right: SETTINGS_CAPSULE_SET_PAD_H })
        .onClick(() => {
          if (item.name) {
            PhoneSettingsHelper.setValue(item.name, this.textDraft(item.name, `${item.value ?? ''}`));
            const cleared: Record<string, string> = {};
            this.pendingText = cleared;
          }
        })
    }
    .width('100%')
    .height(SETTINGS_CAPSULE_HEIGHT)
    .clip(true)
    .borderRadius(SETTINGS_CAPSULE_HEIGHT / 2)
    .backgroundColor(SETTINGS_CAPSULE_BG)
    .border({ width: 1, color: SETTINGS_CAPSULE_BORDER })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private v3fInputCapsule(item: PhoneSettingsItem): void {
    Row() {
      Row({ space: 4 }) {
        TextInput({ text: `${this.v3fDraft(item.name ?? '', item).x}`, placeholder: 'X' })
          .layoutWeight(1)
          .height(SETTINGS_CAPSULE_HEIGHT)
          .fontSize(SETTINGS_CAPSULE_FONT_SIZE)
          .fontColor(SETTINGS_FIELD_TEXT_COLOR)
          .placeholderColor(SETTINGS_FIELD_PLACEHOLDER_COLOR)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .borderRadius(0)
          .onChange((v: string) => {
            if (item.name) {
              const cur = this.v3fDraft(item.name, item);
              const next: Record<string, PhoneSettingsV3f> = {};
              next[item.name] = { x: Number(v), y: cur.y, z: cur.z };
              this.pendingV3f = next;
            }
          })
        TextInput({ text: `${this.v3fDraft(item.name ?? '', item).y}`, placeholder: 'Y' })
          .layoutWeight(1)
          .height(SETTINGS_CAPSULE_HEIGHT)
          .fontSize(SETTINGS_CAPSULE_FONT_SIZE)
          .fontColor(SETTINGS_FIELD_TEXT_COLOR)
          .placeholderColor(SETTINGS_FIELD_PLACEHOLDER_COLOR)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .borderRadius(0)
          .onChange((v: string) => {
            if (item.name) {
              const cur = this.v3fDraft(item.name, item);
              const next: Record<string, PhoneSettingsV3f> = {};
              next[item.name] = { x: cur.x, y: Number(v), z: cur.z };
              this.pendingV3f = next;
            }
          })
        TextInput({ text: `${this.v3fDraft(item.name ?? '', item).z}`, placeholder: 'Z' })
          .layoutWeight(1)
          .height(SETTINGS_CAPSULE_HEIGHT)
          .fontSize(SETTINGS_CAPSULE_FONT_SIZE)
          .fontColor(SETTINGS_FIELD_TEXT_COLOR)
          .placeholderColor(SETTINGS_FIELD_PLACEHOLDER_COLOR)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .borderRadius(0)
          .onChange((v: string) => {
            if (item.name) {
              const cur = this.v3fDraft(item.name, item);
              const next: Record<string, PhoneSettingsV3f> = {};
              next[item.name] = { x: cur.x, y: cur.y, z: Number(v) };
              this.pendingV3f = next;
            }
          })
      }
      .layoutWeight(1)
      .height(SETTINGS_CAPSULE_HEIGHT)
      .padding({ left: 12, right: 4 })
      .alignItems(VerticalAlign.Center)

      Button(SETTINGS_SET)
        .type(ButtonType.Normal)
        .height(SETTINGS_CAPSULE_HEIGHT)
        .fontSize(SETTINGS_CAPSULE_FONT_SIZE)
        .fontColor(SETTINGS_CAPSULE_SET_TEXT)
        .backgroundColor(SETTINGS_CAPSULE_SET_BG)
        .borderRadius(0)
        .padding({ left: SETTINGS_CAPSULE_SET_PAD_H, right: SETTINGS_CAPSULE_SET_PAD_H })
        .onClick(() => {
          if (item.name) {
            PhoneSettingsHelper.setV3f(item.name, this.v3fDraft(item.name, item));
            const cleared: Record<string, PhoneSettingsV3f> = {};
            this.pendingV3f = cleared;
          }
        })
    }
    .width('100%')
    .height(SETTINGS_CAPSULE_HEIGHT)
    .clip(true)
    .borderRadius(SETTINGS_CAPSULE_HEIGHT / 2)
    .backgroundColor(SETTINGS_CAPSULE_BG)
    .border({ width: 1, color: SETTINGS_CAPSULE_BORDER })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private settingHeading(item: PhoneSettingsItem): void {
    Text(item.text ?? '')
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(LABEL_COLOR)
      .width('100%')
      .margin({ top: 8, bottom: 4 })
  }

  @Builder
  private settingNote(item: PhoneSettingsItem): void {
    Text(item.text ?? '')
      .fontSize(12)
      .fontColor(VALUE_COLOR)
      .width('100%')
      .lineHeight(18)
      .margin({ bottom: 6 })
  }

  @Builder
  private settingBool(item: PhoneSettingsItem): void {
    Row({ space: 8 }) {
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.label ?? item.name ?? '')
            .fontSize(13)
            .fontColor('#333333')
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: item.value === true })
            .selectedColor(SETTINGS_TOGGLE_ON_COLOR)
            .switchPointColor(SETTINGS_TOGGLE_KNOB_COLOR)
            .switchStyle({
              pointColor: SETTINGS_TOGGLE_KNOB_COLOR,
              unselectedColor: SETTINGS_TOGGLE_OFF_TRACK_COLOR,
            })
            .onChange((on: boolean) => {
              if (item.name) {
                PhoneSettingsHelper.setBool(item.name, on);
              }
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        if (item.resettable && item.name) {
          this.resetButton(item.name, item.defaultText)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.hasSettingComment(item)) {
        this.settingInfoIcon(this.helpTipId(item), this.settingComment(item))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  private settingEnum(item: PhoneSettingsItem): void {
    Row({ space: 8 }) {
      Column({ space: 6 }) {
        Text(item.label ?? item.name ?? '')
          .fontSize(13)
          .fontColor('#333333')
        if ((item.options ?? []).length > 0) {
          Select(this.enumSelectOptions(item))
            .selected(item.selectedIndex ?? 0)
            .value(this.enumSelectedLabel(item))
            .font({ size: 13 })
            .optionFont({ size: 13 })
            .onSelect((index: number) => {
              if (item.kind === 'shadows') {
                const opt = (item.options ?? [])[index];
                PhoneSettingsHelper.setShadow(opt?.index ?? index + 1);
              } else if (item.name) {
                PhoneSettingsHelper.setEnum(item.name, index + 1);
              }
            })
        }
        if (item.resettable && item.name) {
          this.resetButton(item.name, item.defaultText)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.hasSettingComment(item)) {
        this.settingInfoIcon(this.helpTipId(item), this.settingComment(item))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  private settingTextField(item: PhoneSettingsItem): void {
    Row({ space: 8 }) {
      Column({ space: 6 }) {
        Text(item.label ?? item.name ?? '')
          .fontSize(13)
          .fontColor('#333333')
        this.textInputCapsule(item)
        if (item.resettable && item.name) {
          this.resetButton(item.name, item.defaultText)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.hasSettingComment(item)) {
        this.settingInfoIcon(this.helpTipId(item), this.settingComment(item))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  private settingV3f(item: PhoneSettingsItem): void {
    Row({ space: 8 }) {
      Column({ space: 6 }) {
        Text(item.label ?? item.name ?? '')
          .fontSize(13)
          .fontColor('#333333')
        this.v3fInputCapsule(item)
        if (item.resettable && item.name) {
          this.resetButton(item.name, item.defaultText)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.hasSettingComment(item)) {
        this.settingInfoIcon(this.helpTipId(item), this.settingComment(item))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  private settingFlags(item: PhoneSettingsItem): void {
    Row({ space: 8 }) {
      Column({ space: 6 }) {
        Text(item.label ?? item.name ?? '')
          .fontSize(13)
          .fontColor('#333333')
        ForEach(item.flags ?? [], (flag: PhoneSettingsFlag) => {
          Row() {
            Toggle({ type: ToggleType.Switch, isOn: flag.value })
              .selectedColor(SETTINGS_TOGGLE_ON_COLOR)
              .switchPointColor(SETTINGS_TOGGLE_KNOB_COLOR)
              .switchStyle({
                pointColor: SETTINGS_TOGGLE_KNOB_COLOR,
                unselectedColor: SETTINGS_TOGGLE_OFF_TRACK_COLOR,
              })
              .onChange((on: boolean) => {
                if (item.name) {
                  PhoneSettingsHelper.setFlag(item.name, flag.name, on);
                }
              })
            Text(flag.label)
              .fontSize(12)
              .fontColor('#333333')
              .margin({ left: 8 })
          }
          .width('100%')
        }, (flag: PhoneSettingsFlag): string => flag.name)
        if (item.resettable && item.name) {
          this.resetButton(item.name, item.defaultText)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.hasSettingComment(item)) {
        this.settingInfoIcon(this.helpTipId(item), this.settingComment(item))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  private settingReadonly(item: PhoneSettingsItem): void {
    Row({ space: 8 }) {
      Column({ space: 4 }) {
        if ((item.label ?? '').length > 0) {
          Text(item.label ?? '')
            .fontSize(13)
            .fontColor('#333333')
        }
        Text(`${item.value ?? ''}`)
          .fontSize(12)
          .fontColor(VALUE_COLOR)
          .lineHeight(18)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.hasSettingComment(item)) {
        this.settingInfoIcon(this.helpTipId(item), this.settingComment(item))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  private settingAction(item: PhoneSettingsItem): void {
    Button(item.label ?? '')
      .type(ButtonType.Normal)
      .height(36)
      .fontSize(13)
      .fontColor(BTN_TEXT)
      .backgroundColor(BTN_BG)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 10 })
      .onClick(() => {
        if (item.action) {
          PhoneSettingsHelper.runAction(item.action);
        }
      })
  }

  @Builder
  private settingItem(item: PhoneSettingsItem): void {
    if (item.kind === 'heading') {
      this.settingHeading(item)
    } else if (item.kind === 'note') {
      this.settingNote(item)
    } else if (item.kind === 'bool') {
      this.settingBool(item)
    } else if (item.kind === 'enum' || item.kind === 'shadows') {
      this.settingEnum(item)
    } else if (item.kind === 'string' || item.kind === 'int' || item.kind === 'float') {
      this.settingTextField(item)
    } else if (item.kind === 'v3f') {
      this.settingV3f(item)
    } else if (item.kind === 'flags') {
      this.settingFlags(item)
    } else if (item.kind === 'action') {
      this.settingAction(item)
    } else if (item.kind === 'readonly') {
      this.settingReadonly(item)
    }
  }

  @Builder
  private itemsPanel(): void {
    Scroll() {
      Column() {
        ForEach(this.items(), (item: PhoneSettingsItem, index: number) => {
          this.settingItem(item)
        }, (item: PhoneSettingsItem, index: number): string =>
          `${index}_${item.kind}_${item.name ?? item.text ?? item.action ?? ''}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
    }
    .align(Alignment.TopStart)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor('#FFFFFF')
  }

  build() {
    Stack() {
      Row({ space: SETTINGS_PANEL_GAP }) {
        Column() {
          this.pageList()
        }
        .width(SETTINGS_SIDEBAR_WIDTH)
        .height('100%')

        Column() {
          this.itemsPanel()
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: SETTINGS_BODY_PAD_H, right: SETTINGS_BODY_PAD_H, bottom: 8 })

      if (this.helpDialogOpen) {
        this.helpDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
