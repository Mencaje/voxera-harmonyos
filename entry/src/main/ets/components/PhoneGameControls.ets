import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  PHONE_GAME_ACTION_INVENTORY,
  PHONE_GAME_ACTION_MINIMAP,
  injectKeyEvent,
  setNativePauseActive,
  triggerPhoneGameAction,
} from '../native/LuantiNative';
import {
  KEYCODE_A,
  KEYCODE_D,
  KEYCODE_S,
  KEYCODE_SPACE,
  KEYCODE_W,
} from '../util/OhosKeyCodes';

const CTRL_LOG_DOMAIN = 0x0000;
const CTRL_LOG_TAG = 'PhoneGameControls';
/** Large left virtual stick + right jump (phone in-game only). */
const JOY_OUTER_VP: number = 152;
const JOY_KNOB_VP: number = 58;
const JOY_MAX_OFFSET_VP: number = 46;
const JOY_DEAD_VP: number = 14;
const JOY_MARGIN_LEFT_VP: number = 20;
const JOY_MARGIN_BOTTOM_VP: number = 28;

const JUMP_OUTER_VP: number = 96;
const JUMP_ICON_VP: number = 40;
const JUMP_MARGIN_RIGHT_VP: number = 24;
const JUMP_MARGIN_BOTTOM_VP: number = 36;

/** Match PhoneLocalGamePanel homeFrostOrb (top-right four-dot menu). */
const MENU_ORB_VP: number = 40;
const MENU_ORB_ICON_VP: number = 22;
const MENU_ORB_TOP_VP: number = 16;
const MENU_ORB_RIGHT_VP: number = 16;
const MENU_ORB_LEFT_VP: number = 16;
const MENU_ORB_STACK_GAP_VP: number = 10;
const BACKPACK_ICON_VP: number = 26;

/** Maps stick deflection to discrete WASD (keyboard semantics, not Luanti touch logic). */
class WasdKeyState {
  private w: boolean = false;
  private a: boolean = false;
  private s: boolean = false;
  private d: boolean = false;

  private setKey(code: number, want: boolean, held: boolean): boolean {
    if (want === held) {
      return held;
    }
    injectKeyEvent(code, want);
    return want;
  }

  apply(offsetX: number, offsetY: number): void {
    const forward = offsetY <= -JOY_DEAD_VP;
    const back = offsetY >= JOY_DEAD_VP;
    const left = offsetX <= -JOY_DEAD_VP;
    const right = offsetX >= JOY_DEAD_VP;
    this.w = this.setKey(KEYCODE_W, forward, this.w);
    this.s = this.setKey(KEYCODE_S, back, this.s);
    this.a = this.setKey(KEYCODE_A, left, this.a);
    this.d = this.setKey(KEYCODE_D, right, this.d);
  }

  releaseAll(): void {
    if (this.w) {
      injectKeyEvent(KEYCODE_W, false);
      this.w = false;
    }
    if (this.a) {
      injectKeyEvent(KEYCODE_A, false);
      this.a = false;
    }
    if (this.s) {
      injectKeyEvent(KEYCODE_S, false);
      this.s = false;
    }
    if (this.d) {
      injectKeyEvent(KEYCODE_D, false);
      this.d = false;
    }
  }
}

@Component
export struct PhoneGameControls {
  @Link pauseMenuOpen: boolean;
  @Link inventoryOpen: boolean;
  @State private knobOffsetX: number = 0;  @State private knobOffsetY: number = 0;
  @State private jumpPressed: boolean = false;
  private stickActive: boolean = false;
  private wasd: WasdKeyState = new WasdKeyState();

  aboutToDisappear(): void {
    this.resetStick();
    this.releaseJump();
  }

  private clampKnob(dx: number, dy: number): number[] {
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist <= JOY_MAX_OFFSET_VP || dist < 0.001) {
      return [dx, dy];
    }
    const scale = JOY_MAX_OFFSET_VP / dist;
    return [dx * scale, dy * scale];
  }

  private applyStickOffset(dx: number, dy: number): void {
    const c = this.clampKnob(dx, dy);
    this.knobOffsetX = c[0];
    this.knobOffsetY = c[1];
    this.wasd.apply(c[0], c[1]);
  }

  private resetStick(): void {
    this.stickActive = false;
    this.knobOffsetX = 0;
    this.knobOffsetY = 0;
    this.wasd.releaseAll();
  }

  private releaseJump(): void {
    if (this.jumpPressed) {
      injectKeyEvent(KEYCODE_SPACE, false);
      this.jumpPressed = false;
    }
  }

  private stickDeflectionFromTouch(localX: number, localY: number): number[] {
    const cx = JOY_OUTER_VP / 2;
    const cy = JOY_OUTER_VP / 2;
    return [localX - cx, localY - cy];
  }

  private handleStickTouch(event: TouchEvent): void {
    if (event.type !== TouchType.Down && event.type !== TouchType.Move &&
      event.type !== TouchType.Up && event.type !== TouchType.Cancel) {
      return;
    }
    for (let i = 0; i < event.changedTouches.length; i++) {
      const t = event.changedTouches[i];
      if (event.type === TouchType.Down) {
        this.stickActive = true;
        const d = this.stickDeflectionFromTouch(t.x, t.y);
        this.applyStickOffset(d[0], d[1]);
      } else if (event.type === TouchType.Move && this.stickActive) {
        const d = this.stickDeflectionFromTouch(t.x, t.y);
        this.applyStickOffset(d[0], d[1]);
      } else if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.stickActive) {
        this.resetStick();
      }
    }
  }

  private openNativePause(): void {
    hilog.info(CTRL_LOG_DOMAIN, CTRL_LOG_TAG, 'open native pause');
    setNativePauseActive(true);
    this.pauseMenuOpen = true;
  }

  private toggleInventory(): void {
    hilog.info(CTRL_LOG_DOMAIN, CTRL_LOG_TAG, 'toggle inventory (open=%{public}s)',
      this.inventoryOpen ? 'true' : 'false');
    triggerPhoneGameAction(PHONE_GAME_ACTION_INVENTORY);
    this.inventoryOpen = !this.inventoryOpen;
  }

  private toggleMinimap(): void {
    hilog.info(CTRL_LOG_DOMAIN, CTRL_LOG_TAG, 'toggle minimap (fixed action)');
    triggerPhoneGameAction(PHONE_GAME_ACTION_MINIMAP);
  }

  @Builder
  private topOrbButton(icon: Resource, onTap: () => void): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(MENU_ORB_ICON_VP)
        .fontColor(['#333333'])
    }
    .width(MENU_ORB_VP)
    .height(MENU_ORB_VP)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 0.5,
      color: 'rgba(255, 255, 255, 0.55)',
    })
    .hitTestBehavior(HitTestMode.Block)
    .onClick(onTap)
  }

  @Builder
  private inventoryButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (this.inventoryOpen) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(MENU_ORB_ICON_VP)
          .fontColor(['#333333'])
      } else {
        Image($r('app.media.backpack'))
          .width(BACKPACK_ICON_VP)
          .height(BACKPACK_ICON_VP)
          .objectFit(ImageFit.Contain)
      }
    }
    .width(MENU_ORB_VP)
    .height(MENU_ORB_VP)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 0.5,
      color: 'rgba(255, 255, 255, 0.55)',
    })
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => this.toggleInventory())
  }

  @Builder
  private pauseMenuButton(): void {
    this.topOrbButton($r('sys.symbol.dot_grid_2x2'), () => this.openNativePause())
  }

  @Builder
  private minimapButton(): void {
    this.topOrbButton($r('sys.symbol.map'), () => this.toggleMinimap())
  }

  private handleJumpTouch(event: TouchEvent): void {
    if (event.type !== TouchType.Down && event.type !== TouchType.Up &&
      event.type !== TouchType.Cancel) {
      return;
    }
    if (event.type === TouchType.Down && !this.jumpPressed) {
      injectKeyEvent(KEYCODE_SPACE, true);
      this.jumpPressed = true;
    } else if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.jumpPressed) {
      this.releaseJump();
    }
  }

  @Builder
  private virtualJoystick(): void {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(JOY_OUTER_VP)
        .height(JOY_OUTER_VP)
        .fill('rgba(255, 255, 255, 0.14)')
        .stroke('rgba(255, 255, 255, 0.38)')
        .strokeWidth(2)
      Circle()
        .width(JOY_KNOB_VP)
        .height(JOY_KNOB_VP)
        .fill('rgba(255, 255, 255, 0.52)')
        .stroke('rgba(255, 255, 255, 0.65)')
        .strokeWidth(1.5)
        .translate({ x: this.knobOffsetX, y: this.knobOffsetY })
    }
    .width(JOY_OUTER_VP)
    .height(JOY_OUTER_VP)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent) => this.handleStickTouch(event))
  }

  @Builder
  private jumpButton(): void {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(JUMP_OUTER_VP)
        .height(JUMP_OUTER_VP)
        .fill(this.jumpPressed ? 'rgba(255, 255, 255, 0.55)' : 'rgba(255, 255, 255, 0.22)')
        .stroke('rgba(255, 255, 255, 0.45)')
        .strokeWidth(2)
      SymbolGlyph($r('sys.symbol.chevron_up'))
        .fontSize(JUMP_ICON_VP)
        .fontColor(['#FFFFFF'])
    }
    .width(JUMP_OUTER_VP)
    .height(JUMP_OUTER_VP)
    .hitTestBehavior(HitTestMode.Block)
    .onTouch((event: TouchEvent) => this.handleJumpTouch(event))
  }

  build() {
    /* Only Block children participate in hit test; other touches fall through to game layer. */
    Stack() {
      Stack({ alignContent: Alignment.Bottom }) {
        Row() {
          Column() {
            this.virtualJoystick()
          }
          .margin({ left: JOY_MARGIN_LEFT_VP, bottom: JOY_MARGIN_BOTTOM_VP })
          .hitTestBehavior(HitTestMode.None)

          Blank()
            .layoutWeight(1)
            .hitTestBehavior(HitTestMode.None)

          Column() {
            this.jumpButton()
          }
          .margin({ right: JUMP_MARGIN_RIGHT_VP, bottom: JUMP_MARGIN_BOTTOM_VP })
          .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)

      if (!this.pauseMenuOpen) {
        Row() {
          Column() {
            this.inventoryButton()
          }
          .hitTestBehavior(HitTestMode.None)

          Blank()
            .layoutWeight(1)
            .hitTestBehavior(HitTestMode.None)

          Column({ space: MENU_ORB_STACK_GAP_VP }) {
            this.pauseMenuButton()
            this.minimapButton()
          }
          .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({
          top: MENU_ORB_TOP_VP,
          left: MENU_ORB_LEFT_VP,
          right: MENU_ORB_RIGHT_VP,
        })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
    .hitTestBehavior(HitTestMode.None)
  }
}
