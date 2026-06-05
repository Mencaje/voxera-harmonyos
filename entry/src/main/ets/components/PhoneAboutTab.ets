import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import {
  ABOUT_DEV_LABEL,
  ABOUT_DEV_VALUE,
  ABOUT_ENGINE_DESC,
  ABOUT_ENGINE_HEADING,
  ABOUT_ENGINE_LICENSE,
  ABOUT_ENGINE_LICENSE_LABEL,
  ABOUT_ENGINE_LICENSE_URL,
  ABOUT_ENGINE_NAME,
  ABOUT_ENGINE_NAME_LABEL,
  ABOUT_ENGINE_SITE_LABEL,
  ABOUT_ENGINE_SITE_URL,
  ABOUT_ENGINE_SOURCE_LABEL,
  ABOUT_ENGINE_SOURCE_URL,
  ABOUT_HOMEPAGE_LABEL,
  ABOUT_LOGO_REL,
  ABOUT_MEDIA_LICENSE,
  ABOUT_MEDIA_LICENSE_LABEL,
  ABOUT_MEDIA_LICENSE_URL,
  ABOUT_OPEN_USER_DATA,
  ABOUT_PRIVACY_LABEL,
  ABOUT_PROJECT_LABEL,
  ABOUT_RENDERER_TITLE,
  ABOUT_RUNTIME_HEADING,
  ABOUT_RUNTIME_LIBS,
  ABOUT_SITE_DISPLAY,
  ABOUT_SITE_LABEL,
  ABOUT_TERMS_LABEL,
  ABOUT_VERSION_LABEL,
  MENCAJE_HOMEPAGE_URL,
  VOXERA_GITHUB_URL,
  VOXERA_LEGAL_URL,
} from '../util/PhoneAboutTexts';
import { OhosUiBridge } from '../util/OhosUiBridge';

const LABEL_COLOR: string = '#E6C200';
const VALUE_COLOR: string = '#888888';
const LINK_COLOR: string = '#AAAAAA';
const BTN_BG: string = '#505050';
const BTN_TEXT: string = '#FFFFFF';
const LOGO_VP: number = 88;

@Component
export struct PhoneAboutTab {
  @Prop shareDir: string = '';
  @Prop rendererInfo: string = 'ES 3.2 / ogles2 / SDL 2.0';
  private uiContext: common.UIAbilityContext | undefined = undefined;

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async openUrl(url: string): Promise<void> {
    if (!this.uiContext) {
      return;
    }
    await OhosUiBridge.openBrowserUrl(this.uiContext, url);
  }

  private async openUserDataDir(): Promise<void> {
    if (!this.uiContext) {
      return;
    }
    await OhosUiBridge.openUserDataDirectory(this.uiContext);
  }

  private logoSource(): Resource | string {
    if (this.shareDir.length > 0) {
      const path = `${this.shareDir}/${ABOUT_LOGO_REL}`;
      try {
        fs.accessSync(path);
        return fileUri.getUriFromPath(path);
      } catch (_e) {
        // fall through
      }
    }
    return $r('app.media.splash_logo');
  }

  @Builder
  private labelText(text: string): void {
    Text(text)
      .fontSize(14)
      .fontColor(LABEL_COLOR)
      .fontWeight(FontWeight.Medium)
  }

  @Builder
  private valueText(text: string): void {
    Text(text)
      .fontSize(14)
      .fontColor(VALUE_COLOR)
      .lineHeight(22)
  }

  @Builder
  private linkRow(label: string, url: string, display?: string): void {
    Row() {
      this.labelText(label)
      Text(display ?? url)
        .fontSize(14)
        .fontColor(LINK_COLOR)
        .decoration({ type: TextDecorationType.Underline, color: LINK_COLOR })
        .maxLines(3)
        .layoutWeight(1)
        .onClick(() => {
          this.openUrl(url);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private labelValueRow(label: string, value: string): void {
    Row({ space: 0 }) {
      this.labelText(label)
      Text(value)
        .fontSize(14)
        .fontColor(VALUE_COLOR)
        .lineHeight(22)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private darkButton(label: string, onTap: () => void): void {
    Button(label)
      .type(ButtonType.Normal)
      .height(36)
      .fontSize(14)
      .fontColor(BTN_TEXT)
      .backgroundColor(BTN_BG)
      .borderRadius(18)
      .width('100%')
      .onClick(onTap)
  }

  @Builder
  private runtimeBlock(index: number): void {
    Column({ space: 6 }) {
      this.labelValueRow('开源名称：', ABOUT_RUNTIME_LIBS[index].name)
      this.linkRow(ABOUT_RUNTIME_LIBS[index].siteLabel, ABOUT_RUNTIME_LIBS[index].siteUrl)
      this.labelValueRow(ABOUT_RUNTIME_LIBS[index].licenseLabel, ABOUT_RUNTIME_LIBS[index].licenseText)
      Text('协议全文')
        .fontSize(14)
        .fontColor(LINK_COLOR)
        .decoration({ type: TextDecorationType.Underline, color: LINK_COLOR })
        .onClick(() => {
          this.openUrl(ABOUT_RUNTIME_LIBS[index].licenseUrl);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private scrollBody(): void {
    Column({ space: 10 }) {
      this.labelValueRow(ABOUT_DEV_LABEL, ABOUT_DEV_VALUE)
      this.linkRow(ABOUT_SITE_LABEL, MENCAJE_HOMEPAGE_URL, ABOUT_SITE_DISPLAY)
      this.linkRow(ABOUT_PROJECT_LABEL, VOXERA_GITHUB_URL)

      Text(ABOUT_ENGINE_HEADING)
        .fontSize(14)
        .fontColor(LABEL_COLOR)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ top: 4 })

      this.labelValueRow(ABOUT_ENGINE_NAME_LABEL, ABOUT_ENGINE_NAME)
      this.valueText(ABOUT_ENGINE_DESC)
      this.linkRow(ABOUT_ENGINE_SITE_LABEL, ABOUT_ENGINE_SITE_URL)
      this.linkRow(ABOUT_ENGINE_SOURCE_LABEL, ABOUT_ENGINE_SOURCE_URL)
      this.labelValueRow(ABOUT_ENGINE_LICENSE_LABEL, ABOUT_ENGINE_LICENSE)
      this.linkRow('协议全文：', ABOUT_ENGINE_LICENSE_URL)
      this.labelValueRow(ABOUT_MEDIA_LICENSE_LABEL, ABOUT_MEDIA_LICENSE)
      this.linkRow('素材协议全文：', ABOUT_MEDIA_LICENSE_URL)

      Text(ABOUT_RUNTIME_HEADING)
        .fontSize(14)
        .fontColor(LABEL_COLOR)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ top: 4 })

      this.runtimeBlock(0)
      this.runtimeBlock(1)

      this.linkRow(ABOUT_PRIVACY_LABEL, VOXERA_LEGAL_URL)
      this.linkRow(ABOUT_TERMS_LABEL, VOXERA_LEGAL_URL)
    }
    .width('100%')
    .padding({ right: 8, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private leftColumn(): void {
    Column({ space: 12 }) {
      Image(this.logoSource())
        .width(LOGO_VP)
        .height(LOGO_VP)
        .objectFit(ImageFit.Contain)

      Text(ABOUT_VERSION_LABEL)
        .fontSize(14)
        .fontColor(VALUE_COLOR)
        .textAlign(TextAlign.Center)
        .width('100%')

      this.darkButton(ABOUT_HOMEPAGE_LABEL, () => {
        this.openUrl(MENCAJE_HOMEPAGE_URL);
      })

      this.darkButton(ABOUT_OPEN_USER_DATA, () => {
        this.openUserDataDir();
      })

      Blank()

      Column({ space: 4 }) {
        Text(ABOUT_RENDERER_TITLE)
          .fontSize(13)
          .fontColor(VALUE_COLOR)
        Text(this.rendererInfo)
          .fontSize(13)
          .fontColor(VALUE_COLOR)
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 12, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Row() {
      Column() {
        this.leftColumn()
      }
      .width('38%')
      .height('100%')

      Scroll() {
        this.scrollBody()
      }
      .scrollBar(BarState.Auto)
      .width('62%')
      .height('100%')
      .padding({ left: 8, top: 4, right: 16 })
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
  }
}
