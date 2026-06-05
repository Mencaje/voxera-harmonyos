import { PRIVACY_POLICY_TEXT, USER_AGREEMENT_TEXT } from '../util/LegalConsentTexts';
import { LegalConsentLayout } from '../util/DeviceFormFactor';
import { LegalConsentWindowHelper } from '../util/LegalConsentWindowHelper';

@Component
export struct LegalConsentPanel {
  @Prop layout: LegalConsentLayout = {
    pagePadding: 24,
    titleFontSize: 22,
    bodyFontSize: 14,
    lineHeight: 22,
    buttonHeight: 44,
  };
  @State step: number = 1;
  @State agreed: boolean = false;

  private titleText(): string {
    return this.step === 1 ? '用户协议' : '隐私政策';
  }

  private bodyText(): string {
    return this.step === 1 ? USER_AGREEMENT_TEXT : PRIVACY_POLICY_TEXT;
  }

  private checkboxLabel(): string {
    return this.step === 1 ? '我已阅读并同意用户协议' : '我已阅读并同意隐私政策';
  }

  private leftButtonLabel(): string {
    return this.step === 1 ? '退出' : '上一步';
  }

  private rightButtonLabel(): string {
    return this.step === 1 ? '下一步' : '确认';
  }

  private onLeftClick(): void {
    if (this.step === 1) {
      LegalConsentWindowHelper.decline();
      return;
    }
    this.step = 1;
    this.agreed = false;
  }

  private onNextClick(): void {
    if (!this.agreed) {
      return;
    }
    if (this.step === 1) {
      this.step = 2;
      this.agreed = false;
      return;
    }
    LegalConsentWindowHelper.accept();
  }

  private footerTextSize(): number {
    return this.layout.footerFontSize ?? this.layout.bodyFontSize;
  }

  @Builder
  private agreeCheckbox(compact: boolean): void {
    Row({ space: compact ? 6 : 10 }) {
      Checkbox({ name: 'legalAgree', group: 'legalGroup' })
        .select(this.agreed)
        .width(compact ? 16 : undefined)
        .height(compact ? 16 : undefined)
        .onChange((checked: boolean) => {
          this.agreed = checked;
        })
      Text(this.checkboxLabel())
        .fontSize(compact ? this.footerTextSize() : this.layout.bodyFontSize)
        .fontColor('#222222')
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private leftActionLink(): void {
    Text(this.leftButtonLabel())
      .fontSize(this.footerTextSize())
      .fontColor('#333333')
      .padding({ top: 6, bottom: 6, left: 4, right: 10 })
      .onClick(() => this.onLeftClick())
  }

  @Builder
  private actionButtons(phoneStyle: boolean): void {
    if (phoneStyle) {
      Row({ space: 10 }) {
        this.leftActionLink()

        Button(this.rightButtonLabel())
          .type(ButtonType.Capsule)
          .height(this.layout.buttonHeight)
          .fontSize(this.footerTextSize())
          .padding({ left: 18, right: 18 })
          .enabled(this.agreed)
          .opacity(this.agreed ? 1 : 0.45)
          .onClick(() => this.onNextClick())
      }
      .alignItems(VerticalAlign.Center)
    } else {
      Row({ space: 12 }) {
        Button(this.leftButtonLabel())
          .type(ButtonType.Normal)
          .backgroundColor('#EEEEEE')
          .fontColor('#333333')
          .height(this.layout.buttonHeight)
          .padding({ left: 20, right: 20 })
          .onClick(() => this.onLeftClick())

        Button(this.rightButtonLabel())
          .type(ButtonType.Capsule)
          .height(this.layout.buttonHeight)
          .padding({ left: 24, right: 24 })
          .enabled(this.agreed)
          .opacity(this.agreed ? 1 : 0.45)
          .onClick(() => this.onNextClick())
      }
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private bottomBar(phoneStyle: boolean): void {
    Row() {
      this.agreeCheckbox(phoneStyle)

      Blank()
        .layoutWeight(1)

      this.actionButtons(phoneStyle)
    }
    .width('100%')
    .flexShrink(0)
    .alignItems(VerticalAlign.Center)
    .padding({
      top: phoneStyle ? (this.layout.footerBarGapTop ?? 0) : 0,
      bottom: phoneStyle ? (this.layout.footerPaddingBottom ?? 0) : 0,
    })
  }

  build() {
    if (this.layout.fullScreen) {
      Column({ space: 0 }) {
        Text(this.titleText())
          .fontSize(this.layout.titleFontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .width('100%')
          .flexShrink(0)
          .textAlign(TextAlign.Start)

        Scroll() {
          Text(this.bodyText())
            .fontSize(this.layout.bodyFontSize)
            .fontColor('#333333')
            .lineHeight(this.layout.lineHeight)
            .width('100%')
            .textAlign(TextAlign.Start)
            .padding({ bottom: this.layout.scrollBottomPadding ?? 0 })
        }
        .layoutWeight(1)
        .flexShrink(1)
        .width('100%')
        .margin({ top: 12 })
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)

        this.bottomBar(true)
      }
      .width('100%')
      .height('100%')
      .padding({
        left: this.layout.pagePadding,
        right: this.layout.pagePadding,
        top: this.layout.pagePaddingTop ?? this.layout.pagePadding,
        bottom: this.layout.pagePaddingBottom ?? this.layout.pagePadding,
      })
      .backgroundColor('#FFFFFF')
    } else {
      Column({ space: 16 }) {
        Text(this.titleText())
          .fontSize(this.layout.titleFontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .width('100%')
          .textAlign(TextAlign.Start)

        Scroll() {
          Text(this.bodyText())
            .fontSize(this.layout.bodyFontSize)
            .fontColor('#333333')
            .lineHeight(this.layout.lineHeight)
            .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Auto)

        Row({ space: 10 }) {
          Checkbox({ name: 'legalAgree', group: 'legalGroup' })
            .select(this.agreed)
            .onChange((checked: boolean) => {
              this.agreed = checked;
            })
          Text(this.checkboxLabel())
            .fontSize(this.layout.bodyFontSize)
            .fontColor('#222222')
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.layout.cornerButtons) {
          Row() {
            Button(this.leftButtonLabel())
              .type(ButtonType.Normal)
              .backgroundColor('#EEEEEE')
              .fontColor('#333333')
              .height(this.layout.buttonHeight)
              .padding({ left: 20, right: 20 })
              .onClick(() => this.onLeftClick())

            Blank()
              .layoutWeight(1)

            Button(this.rightButtonLabel())
              .type(ButtonType.Capsule)
              .height(this.layout.buttonHeight)
              .padding({ left: 24, right: 24 })
              .enabled(this.agreed)
              .opacity(this.agreed ? 1 : 0.45)
              .onClick(() => this.onNextClick())
          }
          .width('100%')
        } else {
          Row({ space: 16 }) {
            Button(this.leftButtonLabel())
              .type(ButtonType.Normal)
              .backgroundColor('#EEEEEE')
              .fontColor('#333333')
              .layoutWeight(1)
              .height(this.layout.buttonHeight)
              .onClick(() => this.onLeftClick())

            Button(this.rightButtonLabel())
              .type(ButtonType.Capsule)
              .layoutWeight(1)
              .height(this.layout.buttonHeight)
              .enabled(this.agreed)
              .opacity(this.agreed ? 1 : 0.45)
              .onClick(() => this.onNextClick())
          }
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding(this.layout.pagePadding)
      .backgroundColor('#FFFFFF')
    }
  }
}
