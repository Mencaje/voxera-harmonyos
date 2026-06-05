import {
  JOIN_BTN_LOGIN,
  JOIN_BTN_REGISTER,
  JOIN_DRAWER_WIDTH_RATIO,
  JOIN_LABEL_ADDRESS,
  JOIN_LABEL_NAME,
  JOIN_LABEL_PASSWORD,
  JOIN_LABEL_PORT,
  JOIN_LABEL_SERVER_DESC,
  JOIN_TITLE,
} from '../util/PhoneJoinGameTexts';

const DRAWER_ANIM_MS: number = 300;
const DRAWER_PAD_H: number = 16;
const DRAWER_PAD_BOTTOM: number = 20;
const HEADER_HEIGHT: number = 44;
const HEADER_TOP_PAD: number = 10;
const FORM_TOP_GAP: number = 12;
const FIELD_HEIGHT: number = 34;
const FIELD_RADIUS: number = 4;
const DESC_HEIGHT: number = 80;
const BTN_HEIGHT: number = 36;
const LABEL_SIZE: number = 14;
const INPUT_SIZE: number = 14;
const FIELD_GAP: number = 8;
const CLOSE_ICON_VP: number = 22;

/** Grey frosted tint — must stay semi-transparent so backgroundBlurStyle shows through. */
const DRAWER_GLASS_TINT: string = 'rgba(72, 74, 78, 0.42)';
const DRAWER_GLASS_BORDER: string = 'rgba(255, 255, 255, 0.14)';
const SCRIM_COLOR: string = 'rgba(0, 0, 0, 0.48)';
const LABEL_COLOR: string = '#FFFFFF';
const TITLE_COLOR: string = '#FFFFFF';
const FIELD_BG: string = '#ABABAB';
const FIELD_TEXT: string = '#1E1E1E';
const BTN_BG: string = '#505050';
const BTN_TEXT: string = '#FFFFFF';

@Component
export struct PhoneJoinGameDrawer {
  @Link visible: boolean;
  @Link address: string;
  @Link port: string;
  @Link serverDescription: string;
  @Link playerName: string;
  @Link password: string;

  private drawerWidth(): string {
    return `${JOIN_DRAWER_WIDTH_RATIO * 100}%`;
  }

  private close(): void {
    this.visible = false;
  }

  @Builder
  private fieldLabel(text: string): void {
    Text(text)
      .fontSize(LABEL_SIZE)
      .fontColor(LABEL_COLOR)
      .fontWeight(FontWeight.Medium)
  }

  @Builder
  private grayInput(value: string, onChange: (v: string) => void, password: boolean = false): void {
    TextInput({ text: value, placeholder: '' })
      .type(password ? InputType.Password : InputType.Normal)
      .fontSize(INPUT_SIZE)
      .fontColor(FIELD_TEXT)
      .placeholderColor('#666666')
      .backgroundColor(FIELD_BG)
      .borderRadius(FIELD_RADIUS)
      .height(FIELD_HEIGHT)
      .padding({ left: 10, right: 10 })
      .onChange(onChange)
  }

  @Builder
  private actionButton(label: string): void {
    Button(label)
      .type(ButtonType.Normal)
      .height(BTN_HEIGHT)
      .fontSize(14)
      .fontColor(BTN_TEXT)
      .backgroundColor(BTN_BG)
      .borderRadius(FIELD_RADIUS)
      .layoutWeight(1)
  }

  @Builder
  private drawerHeader(): void {
    Row() {
      Text(JOIN_TITLE)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(TITLE_COLOR)
        .layoutWeight(1)

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(CLOSE_ICON_VP)
          .fontColor(['#FFFFFF'])
      }
      .width(36)
      .height(36)
      .backgroundColor('rgba(255, 255, 255, 0.12)')
      .onClick(() => {
        this.close();
      })
    }
    .width('100%')
    .height(HEADER_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private drawerForm(): void {
    Column({ space: FIELD_GAP }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          this.fieldLabel(JOIN_LABEL_ADDRESS)
          this.grayInput(this.address, (v: string) => {
            this.address = v;
          })
        }
        .layoutWeight(1)

        Column({ space: 4 }) {
          this.fieldLabel(JOIN_LABEL_PORT)
          this.grayInput(this.port, (v: string) => {
            this.port = v;
          })
        }
        .width(80)
      }
      .width('100%')

      Column({ space: 4 }) {
        this.fieldLabel(JOIN_LABEL_SERVER_DESC)
        TextArea({ text: this.serverDescription, placeholder: '' })
          .fontSize(INPUT_SIZE)
          .fontColor(FIELD_TEXT)
          .backgroundColor(FIELD_BG)
          .borderRadius(FIELD_RADIUS)
          .height(DESC_HEIGHT)
          .padding(10)
          .onChange((v: string) => {
            this.serverDescription = v;
          })
      }
      .width('100%')

      Row({ space: 10 }) {
        Column({ space: 4 }) {
          this.fieldLabel(JOIN_LABEL_NAME)
          this.grayInput(this.playerName, (v: string) => {
            this.playerName = v;
          })
        }
        .layoutWeight(1)

        Column({ space: 4 }) {
          this.fieldLabel(JOIN_LABEL_PASSWORD)
          this.grayInput(this.password, (v: string) => {
            this.password = v;
          }, true)
        }
        .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 10 }) {
        this.actionButton(JOIN_BTN_REGISTER)
        this.actionButton(JOIN_BTN_LOGIN)
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
  }

  /** Dedicated blur underlay — blurs gate content visible through the left (no-scrim) region. */
  @Builder
  private glassUnderlay(): void {
    Column()
      .width('100%')
      .height('100%')
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        colorMode: ThemeColorMode.DARK,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0,
      })
      .backgroundColor(DRAWER_GLASS_TINT)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      /* Full-screen scrim: entire surface dims together (no right-only gap). */
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(SCRIM_COLOR)
        .onClick(() => {
          this.close();
        })
        .transition(
          TransitionEffect.asymmetric(
            TransitionEffect.opacity(0)
              .animation({ duration: DRAWER_ANIM_MS, curve: Curve.EaseOut }),
            TransitionEffect.opacity(0)
              .animation({ duration: DRAWER_ANIM_MS - 50, curve: Curve.EaseIn }),
          ),
        )

      Stack({ alignContent: Alignment.TopStart }) {
        this.glassUnderlay()

        Column() {
          this.drawerHeader()

          Scroll() {
            this.drawerForm()
          }
          .scrollBar(BarState.Off)
          .width('100%')
          .layoutWeight(1)
          .margin({ top: FORM_TOP_GAP })
        }
        .width('100%')
        .height('100%')
        .padding({
          left: DRAWER_PAD_H,
          right: DRAWER_PAD_H,
          top: HEADER_TOP_PAD,
          bottom: DRAWER_PAD_BOTTOM,
        })
      }
      .width(this.drawerWidth())
      .height('100%')
      .clip(true)
      .border({
        width: { right: 0.5 },
        color: DRAWER_GLASS_BORDER,
      })
      .transition(
        TransitionEffect.asymmetric(
          TransitionEffect.translate({ x: '-100%' })
            .animation({ duration: DRAWER_ANIM_MS, curve: Curve.FastOutSlowIn }),
          TransitionEffect.translate({ x: '-100%' })
            .animation({ duration: DRAWER_ANIM_MS - 40, curve: Curve.FastOutSlowIn }),
        ),
      )
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
