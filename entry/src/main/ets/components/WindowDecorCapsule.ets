/**
 * 2in1 窗口右上角系统按钮下方的白色毛玻璃胶囊（不拦截点击）。
 * 尺寸与边距由 Game 页根据 getTitleButtonRect 计算后传入。
 */
@Component
export struct WindowDecorCapsule {
  @Prop visible: boolean = false;
  @Prop capsuleWidth: number = 148;
  @Prop capsuleHeight: number = 44;
  @Prop marginTop: number = 4;
  @Prop marginRight: number = 0;

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Row()
          .width(this.capsuleWidth)
          .height(this.capsuleHeight)
          .borderRadius(this.capsuleHeight / 2)
          .backgroundColor('rgba(255, 255, 255, 0.42)')
          .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.LIGHT })
          .backdropBlur(16)
          .border({
            width: 0.5,
            color: 'rgba(255, 255, 255, 0.55)',
          })
          .margin({
            top: this.marginTop,
            right: this.marginRight,
          })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .zIndex(3)
    }
  }
}
