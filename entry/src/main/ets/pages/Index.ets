import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  build() {
    Column({ space: 16 }) {
      Text('Voxera')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text('路线 A：原生引擎移植（当前为阶段性测试）')
        .fontSize(14)
        .fontColor('#666666')
        .textAlign(TextAlign.Center)
      Text('点下面按钮进入测试画面，截图即可')
        .fontSize(12)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
      Button('Launch Luanti')
        .width('70%')
        .height(48)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Game' }).catch((err: Error) => {
            console.error(`pushUrl failed: ${err.message}`);
          });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }
}
