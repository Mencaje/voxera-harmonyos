import { completeOhosTextInput } from '../native/LuantiNative';

const PANEL_BG: string = 'rgba(28, 28, 30, 0.96)';
const FIELD_BG: string = '#ABABAB';
const FIELD_TEXT: string = '#1E1E1E';
const LABEL_COLOR: string = '#FFFFFF';
const BTN_BG: string = '#505050';
const BTN_TEXT: string = '#FFFFFF';
const SCRIM_COLOR: string = 'rgba(0, 0, 0, 0.45)';

export interface FormspecTextInputRequest {
  editType: number;
  hint: string;
  current: string;
}

@Component
export struct PhoneFormspecTextInput {
  @Link visible: boolean;
  @Prop editType: number = 2;
  @Prop hint: string = '';
  @Prop current: string = '';
  @State private draft: string = '';

  private isPassword(): boolean {
    return this.editType === 3;
  }

  private isMultiline(): boolean {
    return this.editType === 1;
  }

  private submit(): void {
    completeOhosTextInput(false, this.draft);
    this.visible = false;
  }

  private cancel(): void {
    completeOhosTextInput(true, '');
    this.visible = false;
  }

  @Builder
  private inputField(): void {
    if (this.isMultiline()) {
      TextArea({ text: this.draft, placeholder: this.hint })
        .fontSize(16)
        .fontColor(FIELD_TEXT)
        .placeholderColor('#666666')
        .backgroundColor(FIELD_BG)
        .borderRadius(8)
        .height(120)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .onChange((v: string) => {
          this.draft = v;
        })
    } else {
      TextInput({ text: this.draft, placeholder: this.hint })
        .type(this.isPassword() ? InputType.Password : InputType.Normal)
        .fontSize(16)
        .fontColor(FIELD_TEXT)
        .placeholderColor('#666666')
        .backgroundColor(FIELD_BG)
        .borderRadius(8)
        .height(44)
        .padding({ left: 12, right: 12 })
        .defaultFocus(true)
        .onChange((v: string) => {
          this.draft = v;
        })
        .onSubmit(() => {
          if (!this.isMultiline()) {
            this.submit();
          }
        })
    }
  }

  build() {
    if (!this.visible) {
      Blank()
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(SCRIM_COLOR)
          .onClick(() => this.cancel())

        Column({ space: 12 }) {
          Text(this.hint.length > 0 ? this.hint : '输入')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(LABEL_COLOR)
            .width('100%')

          this.inputField()

          Row({ space: 12 }) {
            Button('取消')
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(40)
              .fontSize(15)
              .fontColor(BTN_TEXT)
              .backgroundColor('#3A3A3C')
              .borderRadius(8)
              .onClick(() => this.cancel())

            Button(this.isMultiline() ? '完成' : '确定')
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(40)
              .fontSize(15)
              .fontColor(BTN_TEXT)
              .backgroundColor(BTN_BG)
              .borderRadius(8)
              .onClick(() => this.submit())
          }
          .width('100%')
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 16,
          bottom: 24,
        })
        .backgroundColor(PANEL_BG)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onAppear(() => {
          this.draft = this.current;
        })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Block)
      .zIndex(20)
    }
  }
}

export function parseFormspecTextInputPayload(payload: string): FormspecTextInputRequest | undefined {
  const nl1 = payload.indexOf('\n');
  if (nl1 < 0) {
    return undefined;
  }
  const nl2 = payload.indexOf('\n', nl1 + 1);
  if (nl2 < 0) {
    return undefined;
  }
  const editType = parseInt(payload.substring(0, nl1), 10);
  const hint = payload.substring(nl1 + 1, nl2);
  const current = payload.substring(nl2 + 1);
  return { editType, hint, current };
}
