import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';
import pointer from '@ohos.multimodalInput.pointer';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { getEngineStatus, getOhosZipDropTarget, injectKeyEvent, setAppDataPaths,
  setPublicUserDataDir } from '../native/LuantiNative';
import { OhosUiBridge } from '../util/OhosUiBridge';
import { WindowDecorCapsule } from '../components/WindowDecorCapsule';
import { LuantiAssets } from '../util/LuantiAssets';
import { VoxeraPaths } from '../util/VoxeraPaths';
import { WindowDecorHelper } from '../util/WindowDecorHelper';

const DOMAIN = 0x0000;
const TAG = 'VoxeraGame';
const XCOMPONENT_ID = 'luanti_xcomponent';
/** Porting stage HUD (阶段1/2/3、Luanti 移植叠层). Off for release / store builds. */
const SHOW_STARTUP_DEBUG_UI: boolean = false;
/** Matches module.json5 startWindowBackground — seamless after system cold start. */
const STARTUP_COVER_COLOR: string = '#FFFFFF';

@Entry
@Component
struct Game {
  @State statusText: string = '';
  @State assetsReady: boolean = false;
  /** Full-screen cover until main menu / engine ready (replaces debug stage overlay). */
  @State showStartupCover: boolean = true;
  @State startupError: string = '';
  @State showDebugHud: boolean = false;
  @State showDecorCapsule: boolean = false;
  @State capsuleWidth: number = 96;
  @State capsuleHeight: number = 28;
  @State capsuleMarginTop: number = 4;
  @State capsuleMarginRight: number = 0;
  /** Path-select formname while local install dialog accepts zip drops. */
  @State zipDropFormname: string = '';
  private shareDir: string = '';
  /** Engine path_user (sandbox); native fopen/SQLite can write here. */
  private engineUserDir: string = '';
  /** Documents/Voxera/user_data mirror for backup and file manager. */
  private publicUserDir: string = '';
  private uiContext: common.UIAbilityContext | undefined = undefined;
  private statusTimer: number = -1;
  private syncPollTicks: number = 0;
  private keysLogged: number = 0;
  private focusRequestedForGame: boolean = false;
  private mouseCaptureActive: boolean = false;
  private windowDecorHelper: WindowDecorHelper = new WindowDecorHelper();

  /** ArkUI focus id (`.id()`), distinct from XComponent native `id` in the constructor. */
  private requestGameSurfaceFocus(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(XCOMPONENT_ID);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'requestFocus failed: %{public}s', `${e}`);
    }
  }

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!this.uiContext) {
      this.startupError = '无法获取应用上下文';
      return;
    }
    LuantiAssets.ensureInstalled(this.uiContext).then(async (shareDir: string) => {
      this.shareDir = shareDir;
      try {
        LuantiAssets.verifyInstalled(shareDir);
      } catch (e) {
        throw new Error(`${e}`);
      }
      const docsOk = await VoxeraPaths.ensureDocumentsPermission(this.uiContext!);
      const engineDir = VoxeraPaths.sandboxUserDir(this.uiContext!);
      const publicDir = docsOk ? VoxeraPaths.publicUserDataDir() : '';
      VoxeraPaths.ensureUserDataTree(engineDir);
      if (docsOk && publicDir.length > 0) {
        VoxeraPaths.ensureUserDataTree(publicDir);
        VoxeraPaths.migratePublicToEngine(this.uiContext!, publicDir);
      }
      this.engineUserDir = engineDir;
      this.publicUserDir = publicDir;
      OhosUiBridge.setUserDataDirs(engineDir, publicDir);
      setAppDataPaths(shareDir, this.uiContext!.cacheDir, engineDir);
      setPublicUserDataDir(publicDir);
      this.assetsReady = true;
      if (docsOk && publicDir.length > 0) {
        if (VoxeraPaths.needsSandboxMigrate(publicDir)) {
          VoxeraPaths.scheduleMigrateSandboxUserData(this.uiContext!, publicDir);
        } else {
          VoxeraPaths.scheduleSyncEngineToPublic(engineDir, publicDir);
        }
      }
      this.statusText = '资源就绪';
      hilog.info(DOMAIN, TAG, 'Engine user: %{public}s public: %{public}s', engineDir, publicDir);
      this.windowDecorHelper.onRectChange = (rect: window.TitleButtonRect) => {
        this.applyCapsuleLayout(rect);
      };
      this.windowDecorHelper.attach(this.uiContext!).catch(() => {
      });
      OhosUiBridge.bindWindowDecor(this.windowDecorHelper);
      hilog.info(DOMAIN, TAG, 'Share dir: %{public}s', shareDir);
    }).catch((err: Error) => {
      this.startupError = err.message;
      hilog.error(DOMAIN, TAG, 'Startup failed: %{public}s', err.message);
    });
  }

  private isErrorStatus(status: string): boolean {
    return status.includes('失败') || status.includes('缺少') ||
      status.includes('missing file') || status.includes('Failed to');
  }

  /** Release: drop startup cover when main menu (or equivalent) is ready. */
  private shouldDismissStartupCover(status: string): boolean {
    if (this.startupError.length > 0) {
      return false;
    }
    if (status.startsWith('main_menu:')) {
      return true;
    }
    if (status.startsWith('init_engine:') && status.includes('done')) {
      return true;
    }
    if (status.startsWith('video driver:')) {
      return true;
    }
    return false;
  }

  private shouldHideDebugHud(status: string): boolean {
    if (!SHOW_STARTUP_DEBUG_UI) {
      return true;
    }
    if (this.isErrorStatus(status)) {
      return false;
    }
    return this.shouldDismissStartupCover(status);
  }

  private applyCapsuleLayout(rect: window.TitleButtonRect): void {
    // 2in1 上 getTitleButtonRect 常比三个键实际占地大很多，不能直接用 width/height 铺满
    const padH: number = 3;
    const padV: number = 2;
    const maxW: number = 100;
    const maxH: number = 28;
    const minW: number = 84;
    const minH: number = 24;
    const w: number = Math.min(maxW, Math.max(minW, rect.width + padH * 2));
    const h: number = Math.min(maxH, Math.max(minH, rect.height + padV * 2));
    const shiftLeft: number = 16;
    const extendLeft: number = 22;
    this.capsuleWidth = w + extendLeft;
    this.capsuleHeight = h;
    // 先整体左移 shiftLeft（右缘位置），再向左加长 extendLeft（宽度）
    this.capsuleMarginRight = Math.max(0, rect.right - padH + shiftLeft);
    this.capsuleMarginTop = rect.top + Math.max(0, (rect.height - h) / 2);
  }

  /** 仅成功进入游戏世界后显示毛玻璃底托，主菜单/加载阶段不显示。 */
  private updateDecorCapsule(status: string): void {
    if (deviceInfo.deviceType !== '2in1') {
      this.showDecorCapsule = false;
      return;
    }
    if (this.windowDecorHelper.immersiveActive) {
      this.showDecorCapsule = false;
      return;
    }
    this.showDecorCapsule = (status === 'in_game: world');
  }

  private setMouseCapture(active: boolean): void {
    if (this.mouseCaptureActive === active) {
      return;
    }
    this.mouseCaptureActive = active;
    try {
      pointer.setPointerVisibleSync(!active);
      hilog.info(DOMAIN, TAG, 'mouse capture %{public}s', active ? 'on' : 'off');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setPointerVisibleSync: %{public}s', `${e}`);
    }
  }

  private refreshStatus(): void {
    const status = getEngineStatus();
    this.statusText = status;
    this.zipDropFormname = getOhosZipDropTarget();
    this.updateDecorCapsule(status);
    const inWorld = (status === 'in_game: world');
    this.setMouseCapture(inWorld && this.assetsReady);
    if (status === 'in_game: world' && this.assetsReady && !this.focusRequestedForGame) {
      this.focusRequestedForGame = true;
      this.requestGameSurfaceFocus();
      hilog.info(DOMAIN, TAG, 'in_game: requesting XComponent focus');
    }
    if (this.shouldDismissStartupCover(status)) {
      this.showStartupCover = false;
    }
    if (SHOW_STARTUP_DEBUG_UI) {
      if (this.shouldHideDebugHud(status)) {
        this.showDebugHud = false;
      } else if (this.isErrorStatus(status)) {
        this.showDebugHud = true;
        this.startupError = status;
      }
    } else if (this.isErrorStatus(status)) {
      this.startupError = status;
      this.showStartupCover = true;
    }
    if (this.uiContext && this.assetsReady) {
      OhosUiBridge.poll(this.uiContext, this.uiContext.cacheDir).catch(() => {
        // picker cancel / ability errors are logged in OhosUiBridge
      });
      if (this.publicUserDir.length > 0 && this.engineUserDir.length > 0) {
        this.syncPollTicks++;
        if (this.syncPollTicks >= 120) {
          this.syncPollTicks = 0;
          VoxeraPaths.scheduleSyncEngineToPublic(this.engineUserDir, this.publicUserDir);
        }
      }
    }
  }

  aboutToDisappear(): void {
    if (this.statusTimer >= 0) {
      clearInterval(this.statusTimer);
      this.statusTimer = -1;
    }
    this.showDecorCapsule = false;
    this.setMouseCapture(false);
    this.windowDecorHelper.detach();
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    if (!this.assetsReady) {
      return false;
    }
    if (event.type === KeyType.Down) {
      if (this.keysLogged < 8) {
        hilog.info(DOMAIN, TAG, 'key down code=%{public}d source=%{public}d', event.keyCode,
          event.keySource);
        this.keysLogged++;
      }
      injectKeyEvent(event.keyCode, true);
    } else if (event.type === KeyType.Up) {
      injectKeyEvent(event.keyCode, false);
    }
    return true;
  }

  build() {
    Stack() {
      if (!this.assetsReady && SHOW_STARTUP_DEBUG_UI) {
        Column() {
          Text('Voxera · 资源安装')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#222222')
          Text(this.statusText)
            .fontSize(14)
            .fontColor('#444444')
            .margin({ top: 12 })
        }
        .padding(24)
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor('#F5F5F5')
        .zIndex(2)
      }

      if (this.assetsReady) {
        XComponent({
          id: XCOMPONENT_ID,
          type: XComponentType.SURFACE,
          libraryname: 'entry',
        })
          .id(XCOMPONENT_ID)
          .width('100%')
          .height('100%')
          .focusable(true)
          .defaultFocus(true)
          .focusOnTouch(true)
          /* Single path: onKeyPreIme only (onKeyEvent + native XComponent key = duplicate chars). */
          .onKeyPreIme((event: KeyEvent) => this.handleKeyEvent(event))
          .zIndex(0)
          .onLoad(() => {
            if (this.shareDir.length > 0) {
              try {
                fs.accessSync(`${this.shareDir}/builtin/init.lua`);
              } catch {
                this.assetsReady = false;
                this.statusText = '正在重新安装资源…';
                LuantiAssets.ensureInstalled(this.uiContext!).then(async (dir: string) => {
                  this.shareDir = dir;
                  LuantiAssets.verifyInstalled(dir);
                  const docsOk = await VoxeraPaths.ensureDocumentsPermission(this.uiContext!);
                  const engineDir = VoxeraPaths.sandboxUserDir(this.uiContext!);
                  const publicDir = docsOk ? VoxeraPaths.publicUserDataDir() : '';
                  VoxeraPaths.ensureUserDataTree(engineDir);
                  if (docsOk && publicDir.length > 0) {
                    VoxeraPaths.ensureUserDataTree(publicDir);
                    VoxeraPaths.migratePublicToEngine(this.uiContext!, publicDir);
                  }
                  this.engineUserDir = engineDir;
                  this.publicUserDir = publicDir;
                  OhosUiBridge.setUserDataDirs(engineDir, publicDir);
                  setAppDataPaths(dir, this.uiContext!.cacheDir, engineDir);
                  setPublicUserDataDir(publicDir);
                  this.assetsReady = true;
                  if (docsOk && publicDir.length > 0) {
                    if (VoxeraPaths.needsSandboxMigrate(publicDir)) {
                      VoxeraPaths.scheduleMigrateSandboxUserData(this.uiContext!, publicDir);
                    } else {
                      VoxeraPaths.scheduleSyncEngineToPublic(engineDir, publicDir);
                    }
                  }
                  this.statusText = '资源就绪';
                }).catch((e: Error) => {
                  this.startupError = e.message;
                });
                return;
              }
            }
            this.refreshStatus();
            if (this.statusTimer < 0) {
              this.statusTimer = setInterval(() => {
                this.refreshStatus();
              }, 500);
            }
            this.requestGameSurfaceFocus();
            hilog.info(DOMAIN, TAG, 'XComponent onLoad');
          })
          .onDestroy(() => {
            hilog.info(DOMAIN, TAG, 'XComponent onDestroy');
          })
      }

      if (this.zipDropFormname.length > 0 && this.assetsReady && this.uiContext) {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .allowDrop([uniformTypeDescriptor.UniformDataType.FILE_URI])
          .onDrop((event: DragEvent) => {
            OhosUiBridge.handleZipDrop(this.uiContext!, this.uiContext!.cacheDir,
              this.zipDropFormname, event);
          })
          .zIndex(0.5)
      }

      WindowDecorCapsule({
        visible: this.showDecorCapsule && this.assetsReady,
        capsuleWidth: this.capsuleWidth,
        capsuleHeight: this.capsuleHeight,
        marginTop: this.capsuleMarginTop,
        marginRight: this.capsuleMarginRight,
      })

      /* Release: white cover until main menu; debug: stage HUD + optional status text. */
      if (this.showStartupCover) {
        Column() {
          if (this.startupError.length > 0) {
            Text('启动失败')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#222222')
            Text(this.startupError)
              .fontSize(14)
              .fontColor('#CC3333')
              .margin({ top: 12 })
          } else if (SHOW_STARTUP_DEBUG_UI && this.statusText.length > 0) {
            Text('Voxera · Luanti 移植')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#222222')
            Text(this.statusText)
              .fontSize(13)
              .fontColor('#444444')
              .margin({ top: 8 })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .padding(24)
        .backgroundColor(STARTUP_COVER_COLOR)
        .hitTestBehavior(this.startupError.length > 0 ? HitTestMode.Default : HitTestMode.None)
        .zIndex(2)
      }

      if (SHOW_STARTUP_DEBUG_UI && this.showDebugHud) {
        Column() {
          Text('Voxera · Luanti 移植')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.statusText)
            .fontSize(13)
            .fontColor('#EEFFFFFF')
            .margin({ top: 8 })
          Text('主菜单就绪后此叠层会自动隐藏')
            .fontSize(11)
            .fontColor('#AAFFFFFF')
            .margin({ top: 4 })
        }
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .hitTestBehavior(HitTestMode.None)
        .zIndex(1)
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    /* Parent must stay focusable so XComponent can receive ArkUI focus (see AceFocus logs). */
    .focusable(true)
    .defaultFocus(!this.assetsReady)
  }
}
