import {
  browseOnlineLabel,
  CONTENT_DELETE_CONFIRM_CANCEL,
  CONTENT_DELETE_CONFIRM_MESSAGE,
  CONTENT_DELETE_CONFIRM_OK,
  CONTENT_DELETE_CONFIRM_TITLE,
  CONTENT_DISABLE_TXP_BUTTON,
  CONTENT_ERROR_CANNOT_UNINSTALL,
  CONTENT_ERROR_DELETE_FAILED,
  CONTENT_HARD_DEPS_LABEL,
  CONTENT_NO_DEPS,
  CONTENT_NO_DESCRIPTION,
  CONTENT_SOFT_DEPS_LABEL,
  CONTENT_UNINSTALL_BUTTON,
  CONTENT_UPDATE_BUTTON,
  CONTENT_USE_TXP_BUTTON,
} from '../util/PhoneContentTexts';
import {
  PhoneContentDetail,
  PhoneContentHelper,
  PhoneContentPackageItem,
  PhoneContentState,
  copyPhoneContentPackages,
} from '../util/PhoneContentHelper';

const VALUE_COLOR: string = '#666666';
const BTN_BG: string = '#505050';
const BTN_TEXT: string = '#FFFFFF';
const LIST_ROW_H: number = 36;
const LIST_TOP_GAP: number = 6;
const SCREENSHOT_W: number = 120;
const SCREENSHOT_H: number = 80;
@Component
export struct PhoneContentTab {
  @Prop @Watch('onContentStateChanged') contentState: PhoneContentState = {};
  /** Local mirrors — @Prop nested objects do not reliably refresh ForEach rows in-game. */
  @State private packagesLocal: PhoneContentPackageItem[] = [];
  @State private detailLocal: PhoneContentDetail = { kind: 'empty', title: '' };
  @State private selectedIndexLocal: number = 1;
  @State showDeleteConfirm: boolean = false;
  @State statusText: string = '';
  private pendingSelectIndex: number = 0;

  onContentStateChanged(): void {
    this.syncFromProp();
    if (this.contentState.actionError === 'delete_failed') {
      this.statusText = CONTENT_ERROR_DELETE_FAILED;
    } else if (this.contentState.actionError === 'cannot_uninstall') {
      this.statusText = CONTENT_ERROR_CANNOT_UNINSTALL;
    } else if (this.contentState.actionSuccess) {
      this.statusText = '';
      this.showDeleteConfirm = false;
    }
  }

  aboutToAppear(): void {
    this.syncFromProp();
    PhoneContentHelper.refresh();
  }

  aboutToUpdate(): void {
    this.syncFromProp();
  }

  private syncFromProp(): void {
    const idx = this.contentState.selectedIndex ?? 1;
    if (this.pendingSelectIndex > 0) {
      if (idx === this.pendingSelectIndex) {
        this.pendingSelectIndex = 0;
        this.selectedIndexLocal = idx;
      }
    } else {
      this.selectedIndexLocal = idx;
    }
    this.packagesLocal = copyPhoneContentPackages(this.contentState.packages);
    this.detailLocal = this.contentState.detail ?? { kind: 'empty', title: '' };
  }

  private packages(): PhoneContentPackageItem[] {
    return this.packagesLocal;
  }

  private detail(): PhoneContentDetail {
    return this.detailLocal;
  }

  private selectedIndex(): number {
    return this.selectedIndexLocal;
  }

  private onPackageTap(index: number): void {
    this.selectedIndexLocal = index;
    this.pendingSelectIndex = index;
    PhoneContentHelper.selectPackage(index);
  }

  private rowColor(item: PhoneContentPackageItem): string {
    if (item.hasUpdate) {
      return '#C87800';
    }
    if (item.enabled) {
      return '#2E7D32';
    }
    return '#333333';
  }

  @Builder
  private packageRow(item: PhoneContentPackageItem): void {
    Row({ space: 6 }) {
      if (item.hasUpdate) {
        Text('↑')
          .fontSize(12)
          .fontColor('#C87800')
          .width(16)
      } else {
        Blank().width(16)
      }
      Text(item.title)
        .fontSize(13)
        .fontColor(this.rowColor(item))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(LIST_ROW_H)
    .padding({ left: 8 + item.indent * 12, right: 8 })
    .backgroundColor(item.index === this.selectedIndex() ? '#EEEEEE' : '#FFFFFF')
    .borderRadius(4)
    .stateStyles({
      pressed: {
        .backgroundColor(item.index === this.selectedIndex() ? '#DDDDDD' : '#F0F0F0')
      },
    })
    .onClick(() => {
      this.onPackageTap(item.index);
    })
  }

  @Builder
  private packageList(): void {
    Column({ space: 8 }) {
      Scroll() {
        Column() {
          ForEach(this.packages(), (item: PhoneContentPackageItem) => {
            this.packageRow(item)
          }, (item: PhoneContentPackageItem): string => `${item.index}_${item.name}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .align(Alignment.TopStart)
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
      .backgroundColor('#F5F5F5')
      .border({ width: 1, color: '#DDDDDD' })

      Button(browseOnlineLabel(this.contentState.updateCount ?? 0))
        .type(ButtonType.Normal)
        .height(40)
        .fontSize(14)
        .fontColor(BTN_TEXT)
        .backgroundColor(BTN_BG)
        .borderRadius(20)
        .width('100%')
        .onClick(() => {
          PhoneContentHelper.browseOnline();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private actionButton(label: string, onTap: () => void): void {
    Button(label)
      .type(ButtonType.Normal)
      .height(36)
      .fontSize(13)
      .fontColor(BTN_TEXT)
      .backgroundColor(BTN_BG)
      .borderRadius(18)
      .padding({ left: 16, right: 16 })
      .onClick(onTap)
  }

  @Builder
  private detailPanel(): void {
    Scroll() {
      Column({ space: 10 }) {
        if (this.detail().kind !== 'empty') {
          if ((this.detail().screenshotPath ?? '').length > 0) {
            Image('file://' + (this.detail().screenshotPath ?? ''))
              .width(SCREENSHOT_W)
              .height(SCREENSHOT_H)
              .objectFit(ImageFit.Cover)
              .borderRadius(6)
          }

          Text(this.detail().title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          if ((this.detail().subtitle ?? '').length > 0) {
            Text(this.detail().subtitle ?? '')
              .fontSize(13)
              .fontColor(VALUE_COLOR)
          }

          Text((this.detail().description ?? '').length > 0 ?
            (this.detail().description ?? '') : CONTENT_NO_DESCRIPTION)
            .fontSize(13)
            .fontColor(VALUE_COLOR)
            .lineHeight(20)

          if (this.detail().kind === 'mod') {
            if ((this.detail().hardDeps ?? []).length === 0 && (this.detail().softDeps ?? []).length === 0) {
              Text(CONTENT_NO_DEPS)
                .fontSize(13)
                .fontColor(VALUE_COLOR)
            } else {
              if ((this.detail().hardDeps ?? []).length > 0) {
                Text(CONTENT_HARD_DEPS_LABEL)
                  .fontSize(13)
                  .fontColor('#333333')
                ForEach(this.detail().hardDeps ?? [], (dep: string) => {
                  Text(dep)
                    .fontSize(13)
                    .fontColor(VALUE_COLOR)
                }, (dep: string): string => dep)
              }
              if ((this.detail().softDeps ?? []).length > 0) {
                Text(CONTENT_SOFT_DEPS_LABEL)
                  .fontSize(13)
                  .fontColor('#333333')
                  .margin({ top: (this.detail().hardDeps ?? []).length > 0 ? 8 : 0 })
                ForEach(this.detail().softDeps ?? [], (dep: string) => {
                  Text(dep)
                    .fontSize(13)
                    .fontColor(VALUE_COLOR)
                }, (dep: string): string => `opt_${dep}`)
              }
            }
          }

          Row({ space: 10 }) {
            if (this.detail().kind === 'txp') {
              if (this.detail().txpEnabled) {
                this.actionButton(CONTENT_DISABLE_TXP_BUTTON, () => {
                  PhoneContentHelper.disableTexturePack();
                })
              } else {
                this.actionButton(CONTENT_USE_TXP_BUTTON, () => {
                  PhoneContentHelper.useTexturePack(this.selectedIndex());
                })
              }
            }
            if (this.detail().canUninstall) {
              this.actionButton(CONTENT_UNINSTALL_BUTTON, () => {
                this.showDeleteConfirm = true;
              })
            }
            if (this.detail().hasUpdate) {
              this.actionButton(CONTENT_UPDATE_BUTTON, () => {
                PhoneContentHelper.browseOnline();
              })
            }
          }
          .width('100%')
          .margin({ top: 8 })
        }

        if (this.statusText.length > 0) {
          Text(this.statusText)
            .fontSize(13)
            .fontColor('#CC3333')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .padding({ right: 8, bottom: 16 })
    }
    .align(Alignment.TopStart)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  @Builder
  private deleteConfirmDialog(): void {
    if (this.showDeleteConfirm) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => {
            this.showDeleteConfirm = false;
          })

        Column({ space: 16 }) {
          Text(CONTENT_DELETE_CONFIRM_TITLE)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
          Text(CONTENT_DELETE_CONFIRM_MESSAGE)
            .fontSize(14)
            .fontColor(VALUE_COLOR)
          Row({ space: 12 }) {
            Button(CONTENT_DELETE_CONFIRM_CANCEL)
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .backgroundColor('#888888')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.showDeleteConfirm = false;
              })
            Button(CONTENT_DELETE_CONFIRM_OK)
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .backgroundColor('#AA3333')
              .fontColor('#FFFFFF')
              .onClick(() => {
                PhoneContentHelper.uninstallPackage(this.selectedIndex());
              })
          }
          .width('100%')
        }
        .width('72%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
      }
      .width('100%')
      .height('100%')
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Column() {
          this.packageList()
        }
        .width('40%')
        .height('100%')
        .padding({ left: 16, right: 8, top: LIST_TOP_GAP, bottom: 12 })
        .alignItems(HorizontalAlign.Start)

        Column() {
          this.detailPanel()
        }
        .layoutWeight(1)
        .height('100%')
        .padding({ left: 8, right: 16, top: LIST_TOP_GAP, bottom: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Top)

      this.deleteConfirmDialog()
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }
}
