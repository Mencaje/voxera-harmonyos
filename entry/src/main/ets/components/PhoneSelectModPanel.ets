import {
  CANCEL_BUTTON,
  MOD_DISABLE_ALL_BUTTON,
  MOD_DISABLE_MODPACK_BUTTON,
  MOD_ENABLED_LABEL,
  MOD_ENABLE_ALL_BUTTON,
  MOD_ENABLE_MODPACK_BUTTON,
  MOD_ERROR_NO_WORLD,
  MOD_FIND_MORE_BUTTON,
  MOD_HARD_DEPS_LABEL,
  MOD_NO_DEPS_LABEL,
  MOD_NO_HARD_DEPS_LABEL,
  MOD_NO_SOFT_DEPS_LABEL,
  MOD_SAVE_BUTTON,
  MOD_SOFT_DEPS_LABEL,
  MOD_WORLD_LABEL,
  SELECT_MODS_TITLE,
} from '../util/PhoneLocalGameTexts';
import {
  PhoneLocalGameHelper,
  PhoneLocalModDep,
  PhoneLocalModDetail,
  PhoneLocalModListItem,
  PhoneLocalModSchema,
} from '../util/PhoneLocalGameHelper';

const PANEL_PAD_VP: number = 16;
const BTN_H_VP: number = 40;
const FOOTER_PAD_VP: number = 12;
const LIST_ROW_H_VP: number = 36;
const SCRIM_BLUR_TINT: string = 'rgba(0, 0, 0, 0.62)';

@Component
export struct PhoneSelectModPanel {
  @Prop visible: boolean = false;
  @Prop schema: PhoneLocalModSchema = {};
  onClose: () => void = () => {
  };
  onFindMore: () => void = () => {
  };
  @State errorText: string = '';

  private modList(): PhoneLocalModListItem[] {
    return this.schema.mods ?? [];
  }

  private detail(): PhoneLocalModDetail {
    return this.schema.detail ?? { kind: 'mod', title: '' };
  }

  private selectedIndex(): number {
    return this.schema.selectedIndex ?? 1;
  }

  private depColor(state: string): string {
    switch (state) {
      case 'ok':
        return '#88CC88';
      case 'missing':
        return '#FF8888';
      case 'warn':
        return '#FFAA55';
      case 'error':
        return '#FF6666';
      default:
        return '#CCCCCC';
    }
  }

  private rowTitleColor(item: PhoneLocalModListItem): string {
    if (item.errorType === 'error') {
      return '#FF6666';
    }
    if (item.errorType === 'warning') {
      return '#FFAA55';
    }
    if (item.alwaysOn) {
      return '#88AAFF';
    }
    if (item.enabled) {
      return '#88CC88';
    }
    if (item.rowType === 'header' || item.rowType === 'modpack') {
      return '#AAAAAA';
    }
    return '#DDDDDD';
  }

  @Builder
  private blurBackdrop(): void {
    Column()
      .width('100%')
      .height('100%')
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        colorMode: ThemeColorMode.DARK,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0,
      })
      .backgroundColor(SCRIM_BLUR_TINT)
  }

  @Builder
  private depList(label: string, deps: PhoneLocalModDep[], emptyLabel: string): void {
    if (deps.length === 0) {
      Text(emptyLabel)
        .fontSize(13)
        .fontColor('#999999')
    } else {
      Text(label)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .margin({ top: 8, bottom: 4 })
      ForEach(deps, (dep: PhoneLocalModDep) => {
        Text(dep.name)
          .fontSize(13)
          .fontColor(this.depColor(dep.state))
          .margin({ bottom: 2 })
      }, (dep: PhoneLocalModDep): string => dep.name)
    }
  }

  @Builder
  private detailPanel(): void {
    Scroll() {
      Column({ space: 6 }) {
        if (this.schema.error !== undefined && this.schema.error.length > 0) {
          Text(this.schema.error === 'no_world' ? MOD_ERROR_NO_WORLD : this.schema.error)
            .fontSize(14)
            .fontColor('#FF8888')
        } else {
          Text(this.detail().title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          if ((this.detail().description ?? '').length > 0) {
            Text(this.detail().description ?? '')
              .fontSize(13)
              .fontColor('#CCCCCC')
              .margin({ top: 8 })
          }

          if (this.detail().kind === 'modpack') {
            Button(this.detail().modpackEntirelyEnabled ? MOD_DISABLE_MODPACK_BUTTON : MOD_ENABLE_MODPACK_BUTTON)
              .height(BTN_H_VP - 4)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor('#444444')
              .margin({ top: 12 })
              .onClick(() => {
                PhoneLocalGameHelper.toggleMod(this.selectedIndex(),
                  !(this.detail().modpackEntirelyEnabled === true));
              })
          }

          if (this.detail().kind === 'mod' && this.detail().canToggle === true && !this.detail().alwaysOn) {
            Row({ space: 8 }) {
              Checkbox({ name: 'mod_enable', group: 'mod_detail' })
                .select(this.detail().enabled === true)
                .onChange((checked: boolean) => {
                  PhoneLocalGameHelper.toggleMod(this.selectedIndex(), checked);
                })
              Text(MOD_ENABLED_LABEL)
                .fontSize(14)
                .fontColor('#FFFFFF')
            }
            .margin({ top: 10 })
          }

          if (this.detail().kind === 'mod') {
            if ((this.detail().hardDeps ?? []).length === 0 && (this.detail().softDeps ?? []).length === 0) {
              Text(MOD_NO_DEPS_LABEL)
                .fontSize(13)
                .fontColor('#999999')
                .margin({ top: 12 })
            } else {
              this.depList(MOD_HARD_DEPS_LABEL, this.detail().hardDeps ?? [], MOD_NO_HARD_DEPS_LABEL)
              this.depList(MOD_SOFT_DEPS_LABEL, this.detail().softDeps ?? [], MOD_NO_SOFT_DEPS_LABEL)
            }
          }
        }

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(13)
            .fontColor('#FF8888')
            .margin({ top: 12 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 4, right: 8, top: 4, bottom: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  private modRow(item: PhoneLocalModListItem): void {
    Row({ space: 6 }) {
      if (item.canToggle) {
        Checkbox({ name: `mod_${item.index}`, group: 'mod_list' })
          .select(item.enabled)
          .onChange((checked: boolean) => {
            PhoneLocalGameHelper.toggleMod(item.index, checked);
          })
      } else {
        Blank().width(24)
      }
      Text(item.title)
        .fontSize(13)
        .fontColor(this.rowTitleColor(item))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(LIST_ROW_H_VP)
    .padding({ left: 8 + item.indent * 14, right: 8 })
    .backgroundColor(item.index === this.selectedIndex() ? '#3A3A3A' : '#00000000')
    .borderRadius(4)
    .onClick(() => {
      PhoneLocalGameHelper.selectMod(item.index);
    })
  }

  @Builder
  private modListPanel(): void {
    Column({ space: 8 }) {
      Row() {
        Blank()
        Button(this.schema.showDisableAll ? MOD_DISABLE_ALL_BUTTON : MOD_ENABLE_ALL_BUTTON)
          .height(BTN_H_VP - 6)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#444444')
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            if (this.schema.showDisableAll) {
              PhoneLocalGameHelper.disableAllMods();
            } else {
              PhoneLocalGameHelper.enableAllMods();
            }
          })
      }
      .width('100%')

      Scroll() {
        Column() {
          ForEach(this.modList(), (item: PhoneLocalModListItem) => {
            this.modRow(item)
          }, (item: PhoneLocalModListItem): string => `${item.index}_${item.name}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .backgroundColor('#111111')
      .border({ width: 1, color: '#333333' })
    }
    .layoutWeight(1)
    .height('100%')
  }

  build() {
    if (!this.visible) {
      Blank()
    } else {
      Stack() {
        this.blurBackdrop()

        Column() {
          Row() {
            Text(SELECT_MODS_TITLE)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Blank()
            Text(MOD_WORLD_LABEL + (this.schema.worldName ?? ''))
              .fontSize(14)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .padding({ left: PANEL_PAD_VP, right: PANEL_PAD_VP, top: PANEL_PAD_VP })

          Row({ space: 12 }) {
            Column() {
              this.detailPanel()
            }
            .width('42%')
            .height('100%')
            .padding({ left: PANEL_PAD_VP, bottom: PANEL_PAD_VP })

            Column() {
              this.modListPanel()
            }
            .layoutWeight(1)
            .height('100%')
            .padding({ right: PANEL_PAD_VP, bottom: PANEL_PAD_VP })
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)

          Row({ space: 16 }) {
            Button(MOD_SAVE_BUTTON)
              .height(BTN_H_VP)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#444444')
              .padding({ left: 28, right: 28 })
              .onClick(() => {
                this.errorText = '';
                PhoneLocalGameHelper.saveMods();
              })
            Button(CANCEL_BUTTON)
              .height(BTN_H_VP)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#444444')
              .padding({ left: 28, right: 28 })
              .onClick(() => {
                PhoneLocalGameHelper.cancelMods();
                this.onClose();
              })
            Button(MOD_FIND_MORE_BUTTON)
              .height(BTN_H_VP)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#444444')
              .padding({ left: 20, right: 20 })
              .onClick(() => {
                PhoneLocalGameHelper.cancelMods();
                this.onFindMore();
                this.onClose();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: FOOTER_PAD_VP, bottom: FOOTER_PAD_VP + 4 })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
  }
}
