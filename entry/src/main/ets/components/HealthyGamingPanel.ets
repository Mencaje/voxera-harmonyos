import { HEALTHY_GAMING_ADVISORY_LINES } from '../util/HealthyGamingTexts';
import { HealthyGamingLayout } from '../util/DeviceFormFactor';
import { HealthyGamingWindowHelper } from '../util/HealthyGamingWindowHelper';

@Component
export struct HealthyGamingPanel {
  @Prop layout: HealthyGamingLayout = {
    pagePaddingH: 32,
    pagePaddingV: 32,
    titleFontSize: 22,
    bodyFontSize: 17,
    lineHeight: 30,
    buttonHeight: 46,
  };

  private onConfirm(): void {
    HealthyGamingWindowHelper.confirm();
  }

  @Builder
  private badge18Plus(): void {
    Text('18+')
      .fontSize(this.layout.titleFontSize - 4)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .backgroundColor('#333333')
      .borderRadius(6)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
  }

  @Builder
  private confirmButton(fullWidth: boolean): void {
    Button('确定')
      .type(ButtonType.Capsule)
      .width(fullWidth ? '100%' : undefined)
      .height(this.layout.buttonHeight)
      .fontSize(this.layout.bodyFontSize - 1)
      .padding({ left: fullWidth ? 0 : 28, right: fullWidth ? 0 : 28 })
      .onClick(() => this.onConfirm())
  }

  @Builder
  private advisoryBody(centerTitle: boolean): void {
    Column({ space: 20 }) {
      if (centerTitle) {
        Text('健康游戏声明')
          .fontSize(this.layout.titleFontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .textAlign(TextAlign.Center)
      }
      ForEach(HEALTHY_GAMING_ADVISORY_LINES, (line: string) => {
        Text(line)
          .fontSize(this.layout.bodyFontSize)
          .fontColor('#222222')
          .lineHeight(this.layout.lineHeight)
          .width('100%')
          .textAlign(TextAlign.Center)
      }, (line: string) => line)
    }
    .width('100%')
  }

  build() {
    if (this.layout.fullScreen) {
      Stack() {
        Column() {
          this.advisoryBody(true)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({
          left: this.layout.pagePaddingH + 16,
          right: this.layout.pagePaddingH + 16,
          top: this.layout.pagePaddingV + 36,
          bottom: this.layout.pagePaddingV + 56,
        })

        Column() {
          this.badge18Plus()
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: this.layout.pagePaddingH,
          top: this.layout.pagePaddingV,
        })
        .hitTestBehavior(HitTestMode.None)

        Column() {
          this.confirmButton(false)
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.End)
        .justifyContent(FlexAlign.End)
        .padding({
          right: this.layout.pagePaddingH,
          bottom: this.layout.pagePaddingV,
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
    } else if (this.layout.cornerButtons) {
      Column({ space: 0 }) {
        Column() {
          this.badge18Plus()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Text('健康游戏声明')
          .fontSize(this.layout.titleFontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 12 })

        Column({ space: 20 }) {
          ForEach(HEALTHY_GAMING_ADVISORY_LINES, (line: string) => {
            Text(line)
              .fontSize(this.layout.bodyFontSize)
              .fontColor('#222222')
              .lineHeight(this.layout.lineHeight)
              .width('100%')
              .textAlign(TextAlign.Center)
          }, (line: string) => line)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })

        Row() {
          Blank()
            .layoutWeight(1)
          this.confirmButton(false)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .padding({
        left: this.layout.pagePaddingH,
        right: this.layout.pagePaddingH,
        top: this.layout.pagePaddingV,
        bottom: this.layout.pagePaddingV,
      })
      .backgroundColor('#FFFFFF')
    } else {
      Column({ space: 0 }) {
        Row() {
          Text('健康游戏声明')
            .fontSize(this.layout.titleFontSize)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
            .textAlign(TextAlign.Start)

          this.badge18Plus()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 20 }) {
          ForEach(HEALTHY_GAMING_ADVISORY_LINES, (line: string) => {
            Text(line)
              .fontSize(this.layout.bodyFontSize)
              .fontColor('#222222')
              .lineHeight(this.layout.lineHeight)
              .width('100%')
              .textAlign(TextAlign.Center)
          }, (line: string) => line)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })

        Column() {
          this.confirmButton(true)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .padding({
        left: this.layout.pagePaddingH,
        right: this.layout.pagePaddingH,
        top: this.layout.pagePaddingV,
        bottom: this.layout.pagePaddingV,
      })
      .backgroundColor('#FFFFFF')
    }
  }
}
