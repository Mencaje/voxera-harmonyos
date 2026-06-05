import {
  ANNOUNCE_SERVER_LABEL,
  BIND_ADDRESS_LABEL,
  CREATIVE_MODE_LABEL,
  DELETE_CONFIRM_CANCEL,
  DELETE_CONFIRM_MESSAGE,
  DELETE_CONFIRM_OK,
  DELETE_CONFIRM_TITLE,
  DELETE_WORLD_BUTTON,
  ENABLE_DAMAGE_LABEL,
  HOST_GAME_BUTTON,
  HOST_SERVER_LABEL,
  NEW_WORLD_BUTTON,
  PASSWORD_LABEL,
  PLAYER_NAME_LABEL,
  PORT_LABEL,
  SELECT_MODS_BUTTON,
  SELECT_WORLD_LABEL,
  START_GAME_BUTTON,
  VIEW_SERVER_DETAILS_LABEL,
} from '../util/PhoneLocalGameTexts';
import {
  PhoneLocalCreateSchema,
  PhoneLocalGameHelper,
  PhoneLocalGameInfo,
  PhoneLocalLeftPanel,
  PhoneLocalModSchema,
  PhoneLocalState,
  PhoneLocalWorldInfo,
} from '../util/PhoneLocalGameHelper';
import { PhoneContentState } from '../util/PhoneContentHelper';
import { PhoneSettingsState } from '../util/PhoneSettingsHelper';
import { PhoneLocalServerPrefs, PhoneLocalServerStore } from '../util/PhoneLocalServerStore';
import { JOIN_DEFAULT_PORT } from '../util/PhoneJoinGameTexts';
import { PhoneCreateWorldPanel } from './PhoneCreateWorldPanel';
import { PhoneSelectModPanel } from './PhoneSelectModPanel';
import { PhoneJoinGameDrawer } from './PhoneJoinGameDrawer';
import { PhoneMoreMenuScreen } from './PhoneMoreMenuScreen';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PhoneLocalGame';
const DOMAIN = 0xA0000;
/** Match mm_game_theme light sky — opaque cover over Lua main menu. */
const PHONE_LOCAL_BG = '#8CBEFA';
const HOME_ORB_VP: number = 40;
const HOME_ORB_ICON_VP: number = 22;
const HOME_ORB_TOP_VP: number = 16;
const HOME_ORB_RIGHT_VP: number = 16;
const HOME_ORB_GAP_VP: number = 10;

const BAR_BOTTOM_VP: number = 10;
const BAR_SIDE_VP: number = 32;
const BAR_HEIGHT_VP: number = 56;
const BAR_RADIUS_VP: number = 28;
const GAME_ICON_VP: number = 48;
const PLUS_BOX_VP: number = 48;
const WORLD_LIST_H_VP: number = 160;
const BTN_H_VP: number = 36;

@Component
export struct PhoneLocalGamePanel {
  @Prop userDir: string = '';
  @Prop shareDir: string = '';
  @Prop @Watch('onExternalStateChanged') externalState: PhoneLocalState = {};
  /** Dedicated prop so world rows re-render when Lua state file updates (matches tab_local sp_worlds). */
  @Prop @Watch('onWorldsPropChanged') worldsProp: PhoneLocalWorldInfo[] = [];
  @State selectedWorldIndex: number = 0;
  private pendingSelectIndex: number = 0;
  @State selectedGameId: string = '';
  private pendingSelectGameId: string = '';
  @Prop showCreateWorld: boolean = false;
  @Prop createSchema: PhoneLocalCreateSchema = {};
  @Prop createError: string = '';
  onCloseCreateWorld: () => void = () => {
  };
  onOpenCreateWorld: () => void = () => {
  };
  @Prop showSelectMod: boolean = false;
  @Prop modSchema: PhoneLocalModSchema = {};
  onCloseSelectMod: () => void = () => {
  };
  onModFindMore: () => void = () => {
  };
  @Prop contentState: PhoneContentState = {};
  @Prop settingsState: PhoneSettingsState = {};
  @State showDeleteConfirm: boolean = false;
  @State deleteTargetName: string = '';
  @State showServerDialog: boolean = false;
  @State serverPlayerName: string = '';
  @State serverPassword: string = '';
  @State serverPort: string = '30000';
  @State serverBindAddress: string = '';
  @State serverAnnounce: boolean = false;
  @State serverPrefsLoaded: boolean = false;
  @State joinDrawerOpen: boolean = false;
  @State moreMenuOpen: boolean = false;
  @State joinAddress: string = '';
  @State joinPort: string = JOIN_DEFAULT_PORT;
  @State joinServerDescription: string = '';
  @State joinPlayerName: string = '';
  @State joinPassword: string = '';
  @State creativeModeChecked: boolean = false;
  @State enableDamageChecked: boolean = false;
  @State enableServerChecked: boolean = false;

  aboutToAppear(): void {
    this.syncSelectionFromState();
    this.syncGameSelectionFromState();
    this.syncLeftPanelChecks();
    PhoneLocalGameHelper.refresh();
    this.loadServerPrefs();
  }

  aboutToUpdate(): void {
    this.syncSelectionFromState();
    this.syncGameSelectionFromState();
    this.syncLeftPanelChecks();
    if (!this.serverPrefsLoaded) {
      this.mergeServerFromLuaState();
    }
  }

  onExternalStateChanged(): void {
    this.syncSelectionFromState();
    this.syncGameSelectionFromState();
    this.syncLeftPanelChecks();
  }

  private syncLeftPanelChecks(): void {
    const lp = this.leftPanel();
    if (lp.creativeMode?.visible) {
      this.creativeModeChecked = lp.creativeMode.value;
    }
    if (lp.enableDamage?.visible) {
      this.enableDamageChecked = lp.enableDamage.value;
    }
    if (lp.enableServer?.visible) {
      this.enableServerChecked = lp.enableServer.value;
    }
  }

  onWorldsPropChanged(): void {
    this.syncSelectionFromState();
    hilog.info(DOMAIN, TAG, 'worlds prop changed count=%{public}d', this.worlds().length);
  }

  private syncSelectionFromState(): void {
    const list = this.worlds();
    const idx = this.externalState.selectedWorldIndex ?? 0;
    if (this.pendingSelectIndex > 0) {
      if (idx === this.pendingSelectIndex) {
        this.pendingSelectIndex = 0;
      }
      this.selectedWorldIndex = this.pendingSelectIndex;
    } else if (idx > 0) {
      this.selectedWorldIndex = idx;
    } else if (list.length > 0) {
      let pick = list.length;
      for (let i = 0; i < list.length; i++) {
        if (list[i].selected) {
          pick = i + 1;
          break;
        }
      }
      this.selectedWorldIndex = pick;
    } else {
      this.selectedWorldIndex = 0;
    }
  }

  private isWorldSelected(world: PhoneLocalWorldInfo, index: number): boolean {
    if (this.selectedWorldIndex > 0) {
      return (index + 1) === this.selectedWorldIndex;
    }
    return world.selected;
  }

  private syncGameSelectionFromState(): void {
    const list = this.games();
    if (this.pendingSelectGameId.length > 0) {
      let confirmed = false;
      for (let i = 0; i < list.length; i++) {
        if (list[i].id === this.pendingSelectGameId && list[i].selected) {
          confirmed = true;
          break;
        }
      }
      if (confirmed) {
        this.pendingSelectGameId = '';
      }
      this.selectedGameId = this.pendingSelectGameId.length > 0 ?
        this.pendingSelectGameId : (list.find((g: PhoneLocalGameInfo): boolean => g.selected)?.id ?? '');
    } else {
      const sel = list.find((g: PhoneLocalGameInfo): boolean => g.selected);
      if (sel) {
        this.selectedGameId = sel.id;
      } else if (list.length > 0 && this.selectedGameId.length === 0) {
        this.selectedGameId = list[0].id;
      }
    }
  }

  private isGameSelected(game: PhoneLocalGameInfo): boolean {
    if (this.selectedGameId.length > 0) {
      return game.id === this.selectedGameId;
    }
    return game.selected;
  }

  private onGameTap(gameId: string): void {
    this.selectedGameId = gameId;
    this.pendingSelectGameId = gameId;
    PhoneLocalGameHelper.selectGame(gameId);
  }

  private onWorldTap(index: number): void {
    this.selectedWorldIndex = index + 1;
    this.pendingSelectIndex = index + 1;
    hilog.info(DOMAIN, TAG, 'select world index=%{public}d name=%{public}s',
      index + 1, this.worlds()[index]?.name ?? '');
    PhoneLocalGameHelper.selectWorld(index + 1);
  }

  private uiAbilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async loadServerPrefs(): Promise<void> {
    const ctx = this.uiAbilityContext();
    if (!ctx) {
      return;
    }
    const saved = await PhoneLocalServerStore.load(ctx);
    this.serverPlayerName = saved.playerName;
    this.serverPassword = saved.password;
    this.serverPort = saved.port.length > 0 ? saved.port : '30000';
    this.serverBindAddress = saved.bindAddress;
    this.serverAnnounce = saved.announce;
    this.serverPrefsLoaded = true;
    this.pushServerToEngine();
  }

  private mergeServerFromLuaState(): void {
    const srv = this.leftPanel().server;
    if (!srv) {
      return;
    }
    if (this.serverPlayerName.length === 0 && (srv.playerName ?? '').length > 0) {
      this.serverPlayerName = srv.playerName ?? '';
    }
    if (this.serverPort === '30000' && (srv.port ?? '').length > 0) {
      this.serverPort = srv.port ?? '30000';
    }
    if (this.serverBindAddress.length === 0 && (srv.bindAddress ?? '').length > 0) {
      this.serverBindAddress = srv.bindAddress ?? '';
    }
    if (!this.serverAnnounce && srv.announce) {
      this.serverAnnounce = srv.announce;
    }
  }

  private serverPrefsSnapshot(): PhoneLocalServerPrefs {
    return {
      playerName: this.serverPlayerName,
      password: this.serverPassword,
      port: this.serverPort,
      bindAddress: this.serverBindAddress,
      announce: this.serverAnnounce,
    };
  }

  private pushServerToEngine(): void {
    PhoneLocalGameHelper.setSetting('player_name', this.serverPlayerName);
    PhoneLocalGameHelper.setSetting('port', this.serverPort);
    PhoneLocalGameHelper.setSetting('bind_address', this.serverBindAddress);
    PhoneLocalGameHelper.setSetting('server_announce', this.serverAnnounce);
  }

  private persistServerFields(): void {
    const ctx = this.uiAbilityContext();
    if (ctx) {
      PhoneLocalServerStore.save(ctx, this.serverPrefsSnapshot()).catch(() => {
      });
    }
    this.pushServerToEngine();
  }

  private openServerDialog(): void {
    this.mergeServerFromLuaState();
    this.showServerDialog = true;
  }

  private closeServerDialog(): void {
    this.persistServerFields();
    this.showServerDialog = false;
  }

  private onHostServerToggle(enabled: boolean): void {
    this.enableServerChecked = enabled;
    PhoneLocalGameHelper.setSetting('enable_server', enabled, this.currentWorldIndex());
    if (enabled) {
      this.openServerDialog();
    } else {
      this.showServerDialog = false;
    }
  }

  private games(): PhoneLocalGameInfo[] {
    return Array.isArray(this.externalState.games) ? this.externalState.games : [];
  }

  private worlds(): PhoneLocalWorldInfo[] {
    if (Array.isArray(this.worldsProp) && this.worldsProp.length > 0) {
      return this.worldsProp;
    }
    return Array.isArray(this.externalState.worlds) ? this.externalState.worlds : [];
  }

  /** Same as tab_local: world list drives play/delete; left options need a selected world. */
  private hasWorlds(): boolean {
    return this.worlds().length > 0;
  }

  private showLeftPanel(): boolean {
    const lp = this.leftPanel();
    return this.hasWorlds() ||
      lp.creativeMode?.visible === true ||
      lp.enableDamage?.visible === true ||
      lp.enableServer?.visible === true;
  }

  private leftPanel(): PhoneLocalLeftPanel {
    return this.externalState.leftPanel ?? {};
  }

  /** Lua world list index (1-based) for the row highlighted in native UI. */
  private currentWorldIndex(): number {
    if (this.selectedWorldIndex > 0) {
      return this.selectedWorldIndex;
    }
    const fromState = this.externalState.selectedWorldIndex ?? 0;
    if (fromState > 0) {
      return fromState;
    }
    return this.worlds().length > 0 ? this.worlds().length : 1;
  }

  private selectedWorldName(): string {
    for (const w of this.worlds()) {
      if (w.selected) {
        return w.name;
      }
    }
    const list = this.worlds();
    return list.length > 0 ? list[list.length - 1].name : '';
  }

  private openCreateWorld(): void {
    this.onOpenCreateWorld();
  }

  private openSelectMods(): void {
    PhoneLocalGameHelper.requestModSchema();
    PhoneLocalGameHelper.openSelectModDialog(this.modSchema);
  }

  private openJoinDrawer(): void {
    this.joinDrawerOpen = true;
    hilog.info(DOMAIN, TAG, 'join drawer open');
  }

  private openMoreMenu(): void {
    this.moreMenuOpen = true;
    hilog.info(DOMAIN, TAG, 'more menu open');
  }

  @Builder
  private homeFrostOrb(symbol: Resource, onTap: () => void): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(HOME_ORB_ICON_VP)
        .fontColor(['#333333'])
    }
    .width(HOME_ORB_VP)
    .height(HOME_ORB_VP)
    .backgroundColor('rgba(255, 255, 255, 0.72)')
    .border({
      width: 0.5,
      color: 'rgba(255, 255, 255, 0.55)',
    })
    .onClick(onTap)
  }

  @Builder
  private homeTopOrbs(): void {
    Row({ space: HOME_ORB_GAP_VP }) {
      this.homeFrostOrb($r('sys.symbol.gamecontroller_fill'), () => {
        this.openJoinDrawer();
      })
      this.homeFrostOrb($r('sys.symbol.dot_grid_2x2'), () => {
        this.openMoreMenu();
      })
    }
  }

  @Builder
  private gameIconCircle(game: PhoneLocalGameInfo): void {
    Stack() {
      Column()
        .width(GAME_ICON_VP)
        .height(GAME_ICON_VP)
        .borderRadius(GAME_ICON_VP / 2)
        .backgroundColor(this.isGameSelected(game) ? '#3A3A3A' : '#2A2A2A')
        .border({
          width: this.isGameSelected(game) ? 2 : 1,
          color: this.isGameSelected(game) ? '#C8A040' : '#666666',
        })

      if (PhoneLocalGameHelper.resolveGameIconPath(this.userDir, game.id, game.iconPath).length > 0) {
        Image('file://' + PhoneLocalGameHelper.resolveGameIconPath(this.userDir, game.id, game.iconPath))
          .width(GAME_ICON_VP - 8)
          .height(GAME_ICON_VP - 8)
          .borderRadius((GAME_ICON_VP - 8) / 2)
          .objectFit(ImageFit.Cover)
      } else {
        Text(game.id.substring(0, 2).toUpperCase())
          .fontSize(14)
          .fontColor('#FFFFFF')
      }
    }
    .width(GAME_ICON_VP)
    .height(GAME_ICON_VP)
    .onClick(() => this.onGameTap(game.id))
  }

  @Builder
  private plusInstallBox(): void {
    Stack() {
      Column()
        .width(PLUS_BOX_VP)
        .height(PLUS_BOX_VP)
        .borderRadius(10)
        .border({ width: 1.5, color: '#888888' })
      Text('+')
        .fontSize(28)
        .fontWeight(FontWeight.Lighter)
        .fontColor('#CCCCCC')
    }
    .width(PLUS_BOX_VP)
    .height(PLUS_BOX_VP)
    .onClick(() => PhoneLocalGameHelper.openInstallPicker())
  }

  @Builder
  private bottomGameBar(): void {
    Column() {
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.games(), (game: PhoneLocalGameInfo) => {
            this.gameIconCircle(game)
          }, (game: PhoneLocalGameInfo) => game.id)
          this.plusInstallBox()
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .height(BAR_HEIGHT_VP)
    .backgroundColor('rgba(20, 20, 20, 0.88)')
    .borderRadius(BAR_RADIUS_VP)
    .border({ width: 0.5, color: 'rgba(200, 160, 64, 0.45)' })
    .margin({ left: BAR_SIDE_VP, right: BAR_SIDE_VP, bottom: BAR_BOTTOM_VP })
  }

  @Builder
  private leftOptionsPanel(): void {
    Column({ space: 10 }) {
      if (this.leftPanel().creativeMode?.visible) {
        Row({ space: 8 }) {
          Checkbox({ name: 'creative', group: 'localopts' })
            .select(this.creativeModeChecked)
            .onChange((v: boolean) => {
              this.creativeModeChecked = v;
              PhoneLocalGameHelper.setSetting('creative_mode', v, this.currentWorldIndex());
            })
          Text(CREATIVE_MODE_LABEL).fontSize(14).fontColor('#FFFFFF')
        }
      }
      if (this.leftPanel().enableDamage?.visible) {
        Row({ space: 8 }) {
          Checkbox({ name: 'damage', group: 'localopts' })
            .select(this.enableDamageChecked)
            .onChange((v: boolean) => {
              this.enableDamageChecked = v;
              PhoneLocalGameHelper.setSetting('enable_damage', v, this.currentWorldIndex());
            })
          Text(ENABLE_DAMAGE_LABEL).fontSize(14).fontColor('#FFFFFF')
        }
      }
      if (this.leftPanel().enableServer?.visible) {
        Row({ space: 8 }) {
          Checkbox({ name: 'server', group: 'localopts' })
            .select(this.enableServerChecked)
            .onChange((v: boolean) => this.onHostServerToggle(v))
          Text(HOST_SERVER_LABEL).fontSize(14).fontColor('#FFFFFF')
        }
        if (this.enableServerChecked) {
          Text(VIEW_SERVER_DETAILS_LABEL)
            .fontSize(13)
            .fontColor('#E8EEF8')
            .decoration({ type: TextDecorationType.Underline, color: '#E8EEF8' })
            .margin({ left: 28, top: 2 })
            .onClick(() => this.openServerDialog())
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, top: 16 })
    .width('36%')
  }

  @Builder
  private worldListPanel(): void {
    Column({ space: 8 }) {
      Text(SELECT_WORLD_LABEL)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .width('100%')

      Scroll() {
        Column({ space: 2 }) {
          if (this.worlds().length === 0) {
            Row() {
              Text('—')
                .fontSize(14)
                .fontColor('#666666')
            }
            .width('100%')
            .height(36)
            .padding({ left: 10, right: 10 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
          } else {
            ForEach(this.worlds(), (world: PhoneLocalWorldInfo, index: number) => {
              Row() {
                Text(world.name.length > 0 ? world.name : `#${index + 1}`)
                  .fontSize(15)
                  .fontColor('#FFFFFF')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .height(36)
              .padding({ left: 10, right: 10 })
              .backgroundColor(this.isWorldSelected(world, index) ? '#2E7D32' : '#1A1A1A')
              .borderRadius(2)
              .onClick(() => this.onWorldTap(index))
            }, (world: PhoneLocalWorldInfo, index: number) => `${index}:${world.name}:${world.gameid}`)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(WORLD_LIST_H_VP)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)
      .align(Alignment.TopStart)
      .backgroundColor('#111111')
      .border({ width: 1, color: '#333333' })

      if (this.hasWorlds()) {
        Row({ space: 8 }) {
          Button(DELETE_WORLD_BUTTON)
            .layoutWeight(1)
            .height(BTN_H_VP)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#444444')
            .onClick(() => {
              const name = this.selectedWorldName();
              if (name.length > 0) {
                this.deleteTargetName = name;
                this.showDeleteConfirm = true;
              }
            })
          Button(SELECT_MODS_BUTTON)
            .layoutWeight(1)
            .height(BTN_H_VP)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#444444')
            .onClick(() => this.openSelectMods())
          Button(NEW_WORLD_BUTTON)
            .layoutWeight(1)
            .height(BTN_H_VP)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#444444')
            .onClick(() => this.openCreateWorld())
        }
        .width('100%')

        Row() {
          Blank()
          Button(this.enableServerChecked ? HOST_GAME_BUTTON : START_GAME_BUTTON)
            .height(BTN_H_VP + 4)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#444444')
            .padding({ left: 24, right: 24 })
            .onClick(() => {
              PhoneLocalGameHelper.play(
                this.serverPassword,
                this.serverPlayerName,
                this.serverPort,
                this.serverBindAddress,
                this.currentWorldIndex(),
              );
            })
        }
        .width('100%')
      } else {
        Row() {
          Blank()
          Button(NEW_WORLD_BUTTON)
            .height(BTN_H_VP)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#444444')
            .padding({ left: 20, right: 20 })
            .onClick(() => this.openCreateWorld())
        }
        .width('100%')
      }
    }
    .width('54%')
    .padding({ left: 4, right: 36, top: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private hostServerDialog(): void {
    if (this.showServerDialog) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.55)')
          .onClick(() => {
            this.closeServerDialog();
          })

        Column({ space: 14 }) {
          Row() {
            Text(HOST_SERVER_LABEL)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Blank()
            Button({ type: ButtonType.Circle }) {
              Text('×')
                .fontSize(20)
                .fontColor('#CCCCCC')
            }
            .width(32)
            .height(32)
            .backgroundColor('#444444')
            .onClick(() => this.closeServerDialog())
          }
          .width('100%')

          TextInput({ text: this.serverPlayerName, placeholder: PLAYER_NAME_LABEL })
            .height(40)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#333333')
            .onChange((v: string) => {
              this.serverPlayerName = v;
              this.persistServerFields();
            })

          TextInput({ text: this.serverPassword, placeholder: PASSWORD_LABEL })
            .height(40)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#333333')
            .type(InputType.Password)
            .onChange((v: string) => {
              this.serverPassword = v;
              this.persistServerFields();
            })

          TextInput({ text: this.serverBindAddress, placeholder: BIND_ADDRESS_LABEL })
            .height(40)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#333333')
            .onChange((v: string) => {
              this.serverBindAddress = v;
              this.persistServerFields();
            })

          TextInput({ text: this.serverPort, placeholder: PORT_LABEL })
            .height(40)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#333333')
            .onChange((v: string) => {
              this.serverPort = v;
              this.persistServerFields();
            })

          Row() {
            Blank()
            Row({ space: 8 }) {
              Checkbox({ name: 'announce', group: 'serverdlg' })
                .select(this.serverAnnounce)
                .onChange((v: boolean) => {
                  this.serverAnnounce = v;
                  this.persistServerFields();
                })
              Text(ANNOUNCE_SERVER_LABEL)
                .fontSize(14)
                .fontColor('#FFFFFF')
            }
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .width('82%')
        .padding(20)
        .backgroundColor('#222222')
        .borderRadius(16)
      }
      .width('100%')
      .height('100%')
      .zIndex(250)
    }
  }

  @Builder
  private deleteConfirmDialog(): void {
    if (this.showDeleteConfirm) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.6)')
          .onClick(() => {
            this.showDeleteConfirm = false;
          })
        Column({ space: 16 }) {
          Text(DELETE_CONFIRM_TITLE)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(DELETE_CONFIRM_MESSAGE + ` "${this.deleteTargetName}"?`)
            .fontSize(14)
            .fontColor('#CCCCCC')
          Row({ space: 12 }) {
            Button(DELETE_CONFIRM_CANCEL)
              .layoutWeight(1)
              .height(BTN_H_VP)
              .fontColor('#FFFFFF')
              .backgroundColor('#555555')
              .onClick(() => {
                this.showDeleteConfirm = false;
              })
            Button(DELETE_CONFIRM_OK)
              .layoutWeight(1)
              .height(BTN_H_VP)
              .fontColor('#FFFFFF')
              .backgroundColor('#AA3333')
              .onClick(() => {
                PhoneLocalGameHelper.deleteWorld(this.deleteTargetName);
                this.showDeleteConfirm = false;
              })
          }
          .width('100%')
        }
        .width('80%')
        .padding(20)
        .backgroundColor('#222222')
        .borderRadius(12)
      }
      .width('100%')
      .height('100%')
      .zIndex(300)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          if (this.showLeftPanel()) {
            this.leftOptionsPanel()
          } else {
            Blank().width('36%')
          }
          this.worldListPanel()
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)

        this.bottomGameBar()
      }
      .width('100%')
      .height('100%')

      if (!this.moreMenuOpen) {
        Row() {
          this.homeTopOrbs()
        }
        .width('100%')
        .height(HOME_ORB_VP + HOME_ORB_TOP_VP)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Bottom)
        .padding({
          top: HOME_ORB_TOP_VP,
          right: HOME_ORB_RIGHT_VP,
        })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(100)
      }

      if (this.moreMenuOpen) {
        PhoneMoreMenuScreen({ visible: $moreMenuOpen, shareDir: this.shareDir,
          contentState: this.contentState, settingsState: this.settingsState })
          .width('100%')
          .height('100%')
          .zIndex(150)
      }

      if (!this.moreMenuOpen && this.joinDrawerOpen) {
        PhoneJoinGameDrawer({
          visible: $joinDrawerOpen,
          address: $joinAddress,
          port: $joinPort,
          serverDescription: $joinServerDescription,
          playerName: $joinPlayerName,
          password: $joinPassword,
        })
          .width('100%')
          .height('100%')
          .zIndex(200)
      }

      if (this.showCreateWorld) {
        PhoneCreateWorldPanel({
          visible: this.showCreateWorld,
          schema: this.createSchema,
          createError: this.createError,
          onClose: (): void => {
            this.onCloseCreateWorld();
          },
        })
          .width('100%')
          .height('100%')
          .zIndex(200)
      }

      if (this.showSelectMod) {
        PhoneSelectModPanel({
          visible: this.showSelectMod,
          schema: this.modSchema,
          onClose: (): void => {
            this.onCloseSelectMod();
          },
          onFindMore: (): void => {
            this.onModFindMore();
          },
        })
          .width('100%')
          .height('100%')
          .zIndex(200)
      }

      this.deleteConfirmDialog()
      this.hostServerDialog()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PHONE_LOCAL_BG)
    .hitTestBehavior(HitTestMode.Default)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
