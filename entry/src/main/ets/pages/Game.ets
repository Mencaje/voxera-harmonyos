import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { promptAction, window } from '@kit.ArkUI';
import pointer from '@ohos.multimodalInput.pointer';
import { getEngineStatus, getNativePauseActive, getOhosZipDropTarget, injectKeyEvent, injectTouch,
  isInGameWorld, isPlayerInventoryOpen,
  nativePauseExitMenu, nativePauseExitOS, setAppDataPaths, setDeviceFormFactor,
  setNativePauseActive, setPublicUserDataDir } from '../native/LuantiNative';
import { OhosUiBridge } from '../util/OhosUiBridge';
import { WindowDecorCapsule } from '../components/WindowDecorCapsule';
import { LuantiAssets } from '../util/LuantiAssets';
import { VoxeraPaths } from '../util/VoxeraPaths';
import { OhosPlatformCompat } from '../util/OhosPlatformCompat';
import { WindowDecorHelper } from '../util/WindowDecorHelper';
import { LegalConsentWindowHelper, LegalConsentPhoneOverlayImpl } from '../util/LegalConsentWindowHelper';
import { HealthyGamingWindowHelper, HealthyGamingPhoneOverlayImpl } from '../util/HealthyGamingWindowHelper';
import { DocumentsPermissionWindowHelper } from '../util/DocumentsPermissionWindowHelper';
import { LegalConsentPanel } from '../components/LegalConsentPanel';
import { HealthyGamingPanel } from '../components/HealthyGamingPanel';
import { HEALTHY_LAYOUT_PHONE, LEGAL_LAYOUT_PHONE } from '../util/DeviceFormFactor';
import { TabletWindowHelper } from '../util/TabletWindowHelper';
import { PhoneWindowHelper } from '../util/PhoneWindowHelper';
import { PhoneGameInstallPanel } from '../components/PhoneGameInstallPanel';
import { PhoneLocalGamePanel } from '../components/PhoneLocalGamePanel';
import {
  PhoneGameInstallHelper,
  PhoneGameInstallPhoneOverlayImpl,
  PhoneInstallScreen,
} from '../util/PhoneGameInstallHelper';
import {
  PhoneLocalGameHelper,
  PhoneLocalGamePhoneOverlayImpl,
  normalizePhoneLocalState,
  PhoneLocalCreateSchema,
  PhoneLocalModSchema,
  PhoneLocalState,
  PhoneLocalWorldInfo,
} from '../util/PhoneLocalGameHelper';
import {
  PhoneContentHelper,
  PhoneContentState,
  copyPhoneContentDetail,
  copyPhoneContentPackages,
} from '../util/PhoneContentHelper';
import {
  PhoneSettingsHelper,
  PhoneSettingsState,
  copyPhoneSettingsItems,
  copyPhoneSettingsPages,
} from '../util/PhoneSettingsHelper';
import { DeviceFormFactor } from '../util/DeviceFormFactor';
import { CREATE_ERROR_EXISTS } from '../util/PhoneLocalGameTexts';
import { PhoneGameControls } from '../components/PhoneGameControls';
import { PhoneInGamePauseOverlay } from '../components/PhoneInGamePauseOverlay';
import { PhoneMoreMenuScreen } from '../components/PhoneMoreMenuScreen';
import { FormspecTextInputRequest, PhoneFormspecTextInput } from '../components/PhoneFormspecTextInput';

const DOMAIN = 0x0000;
const TAG = 'VoxeraGame';
const XCOMPONENT_ID = 'luanti_xcomponent';
/** Porting stage HUD (阶段1/2/3、Luanti 移植叠层). Off for release / store builds. */
const SHOW_STARTUP_DEBUG_UI: boolean = false;
/** Layer-2 splash matches layer-1 start window (black + transparent logo). */
const STARTUP_COVER_COLOR: string = '#FF000000';
/** splash_logo.png canvas — layer-1 startWindowIcon displays at resource pixel size (not scaled). */
const SPLASH_LOGO_CANVAS_PX: number = 1024;

@Entry
@Component
struct Game {
  @State statusText: string = '';
  @State assetsReady: boolean = false;
  /** Full-screen cover until main menu / engine ready (replaces debug stage overlay). */
  @State showStartupCover: boolean = true;
  /** Phone: full-screen healthy gaming declaration (no subwindow). */
  @State showHealthyGamingOverlay: boolean = false;
  /** Phone: full-screen legal consent (no subwindow). */
  @State showLegalConsentOverlay: boolean = false;
  /** Phone: install subgame gate + picker (replaces Lua no-games UI). */
  @State showPhoneGameInstallOverlay: boolean = false;
  /** Phone: local game UI after at least one subgame is installed. */
  @State showPhoneLocalGameOverlay: boolean = false;
  @State phoneLocalState: PhoneLocalState = {};
  @State phoneLocalWorlds: PhoneLocalWorldInfo[] = [];
  @State phoneLocalShowCreateWorld: boolean = false;
  @State phoneLocalCreateSchema: PhoneLocalCreateSchema = {};
  @State phoneLocalCreateError: string = '';
  private phoneLocalPendingCreateOpen: boolean = false;
  @State phoneLocalShowSelectMod: boolean = false;
  @State phoneLocalModSchema: PhoneLocalModSchema = {};
  @State phoneContentState: PhoneContentState = {};
  @State phoneSettingsState: PhoneSettingsState = {};
  @State phoneInstallScreen: PhoneInstallScreen = 'gate';
  @State phoneInstallStatus: string = '';
  @State startupError: string = '';
  @State showDebugHud: boolean = false;
  @State showDecorCapsule: boolean = false;
  /** Phone: in-world HUD controls (joystick + jump). */
  @State inGameWorld: boolean = false;
  /** Phone: native in-game pause overlay (replaces Lua formspec pause). */
  @State phoneNativePauseOpen: boolean = false;
  /** Phone: player inventory formspec open (backpack button shows xmark). */
  @State phoneInventoryOpen: boolean = false;
  @State phonePauseSettingsOpen: boolean = false;
  @State phonePauseProgress: string = '';
  /** Phone: hide HUD (four-dot, joystick, jump) while exiting to home or OS. */
  @State phoneExiting: boolean = false;
  /** Phone: native keyboard overlay for in-game formspec edit boxes. */
  @State phoneFormspecTextInputOpen: boolean = false;
  @State phoneFormspecTextEditType: number = 2;
  @State phoneFormspecTextHint: string = '';
  @State phoneFormspecTextCurrent: string = '';
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
  private touchInjectLogCount: number = 0;
  private windowDecorHelper: WindowDecorHelper = new WindowDecorHelper();
  private healthyGamingResolve: (() => void) | undefined = undefined;
  private legalConsentOpenResolve: (() => void) | undefined = undefined;
  private phoneGameInstallResolve: (() => void) | undefined = undefined;
  private phoneLocalGameResolve: (() => void) | undefined = undefined;
  /** Compliance dialogs run once after engine reaches main menu (not before load). */
  private postLoadGatesStarted: boolean = false;
  private postLoadGatesDone: boolean = false;

  /** Match system startWindowIcon: PNG shown at resource pixel size → vp. */
  private startupIconVp(): number {
    try {
      return Math.round(this.getUIContext().px2vp(SPLASH_LOGO_CANVAS_PX));
    } catch (_e) {
      return 341;
    }
  }

  /** ArkUI focus id (`.id()`), distinct from XComponent native `id` in the constructor. */
  private requestGameSurfaceFocus(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(XCOMPONENT_ID);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'requestFocus failed: %{public}s', `${e}`);
    }
  }

  private bindLegalConsentPhoneOverlay(): void {
    const overlay = new LegalConsentPhoneOverlayImpl(
      (): Promise<void> => {
        return new Promise<void>((resolve) => {
          this.legalConsentOpenResolve = resolve;
          this.showLegalConsentOverlay = true;
        });
      },
      (): void => {
        this.showLegalConsentOverlay = false;
        const done = this.legalConsentOpenResolve;
        this.legalConsentOpenResolve = undefined;
        if (done) {
          done();
        }
      },
    );
    LegalConsentWindowHelper.bindPhoneOverlay(overlay);
  }

  private bindHealthyGamingPhoneOverlay(): void {
    const overlay = new HealthyGamingPhoneOverlayImpl(
      (): Promise<void> => {
        return new Promise<void>((resolve) => {
          this.healthyGamingResolve = resolve;
          this.showHealthyGamingOverlay = true;
        });
      },
      (): void => {
        this.showHealthyGamingOverlay = false;
        const done = this.healthyGamingResolve;
        this.healthyGamingResolve = undefined;
        if (done) {
          done();
        }
      },
    );
    HealthyGamingWindowHelper.bindPhoneOverlay(overlay);
  }

  private bindPhoneGameInstallOverlay(): void {
    const overlay = new PhoneGameInstallPhoneOverlayImpl(
      (): Promise<void> => {
        return new Promise<void>((resolve) => {
          this.phoneGameInstallResolve = resolve;
          /* Screen ('gate' | 'picker') is set by caller before open(). */
          this.phoneInstallStatus = '';
          this.showPhoneGameInstallOverlay = true;
          PhoneGameInstallHelper.markOverlayVisible(true);
          hilog.info(DOMAIN, TAG, 'phone install overlay visible screen=%{public}s',
            this.phoneInstallScreen);
        });
      },
      (): void => {
        this.showPhoneGameInstallOverlay = false;
        PhoneGameInstallHelper.markOverlayVisible(false);
        const done = this.phoneGameInstallResolve;
        this.phoneGameInstallResolve = undefined;
        if (done) {
          done();
        }
      },
      (): PhoneInstallScreen => this.phoneInstallScreen,
      (screen: PhoneInstallScreen): void => {
        this.phoneInstallScreen = screen;
      },
      (): string => this.phoneInstallStatus,
      (text: string): void => {
        this.phoneInstallStatus = text;
      },
    );
    PhoneGameInstallHelper.bindPhoneOverlay(overlay);
  }

  private bindPhoneLocalGameOverlay(): void {
    const overlay = new PhoneLocalGamePhoneOverlayImpl(
      (): Promise<void> => {
        return new Promise<void>((resolve) => {
          this.phoneLocalGameResolve = resolve;
          this.showPhoneLocalGameOverlay = true;
          hilog.info(DOMAIN, TAG, 'phone local game overlay visible');
        });
      },
      (): void => {
        this.showPhoneLocalGameOverlay = false;
        this.phoneLocalShowCreateWorld = false;
        this.phoneLocalShowSelectMod = false;
        const done = this.phoneLocalGameResolve;
        this.phoneLocalGameResolve = undefined;
        if (done) {
          done();
        }
      },
      (state: PhoneLocalState): void => {
        this.phoneLocalState = normalizePhoneLocalState(state, this.phoneLocalState);
        this.phoneLocalWorlds = this.phoneLocalState.worlds ? this.phoneLocalState.worlds.slice() : [];
        if (state.createSchema) {
          this.phoneLocalCreateSchema = state.createSchema;
          if (this.phoneLocalPendingCreateOpen) {
            this.phoneLocalPendingCreateOpen = false;
            this.phoneLocalCreateError = '';
            this.phoneLocalShowCreateWorld = true;
          }
        }
        if (state.modSchema) {
          this.phoneLocalModSchema = state.modSchema;
        }
        if (state.createResult !== undefined) {
          if (state.createResult) {
            this.phoneLocalCreateError = state.createResult;
            hilog.warn(DOMAIN, TAG, 'create world failed: %{public}s', state.createResult);
            if (state.createResult === 'exists') {
              promptAction.showToast({
                message: CREATE_ERROR_EXISTS,
                duration: 2000,
              });
            }
          } else {
            this.phoneLocalCreateError = '';
          }
        }
        if (state.createSuccess) {
          this.phoneLocalShowCreateWorld = false;
          this.phoneLocalCreateError = '';
        }
        if (state.modSaveSuccess || state.modClosed) {
          this.phoneLocalShowSelectMod = false;
        }
        if (state.modSaveError) {
          const prev = this.phoneLocalModSchema;
          this.phoneLocalModSchema = {
            worldName: prev.worldName,
            selectedIndex: prev.selectedIndex,
            showDisableAll: prev.showDisableAll,
            mods: prev.mods ? prev.mods.slice() : undefined,
            detail: prev.detail,
            error: state.modSaveError,
          };
        }
      },
      (): void => {
        if (this.uiContext) {
          PhoneGameInstallHelper.openAdditionalInstallPicker(this.uiContext, this.uiContext.cacheDir);
        }
      },
      (schema: PhoneLocalCreateSchema): void => {
        this.phoneLocalCreateSchema = schema;
        this.phoneLocalShowCreateWorld = true;
      },
      (): void => {
        this.phoneLocalShowCreateWorld = false;
      },
      (schema: PhoneLocalModSchema): void => {
        this.phoneLocalModSchema = schema;
        this.phoneLocalShowSelectMod = true;
      },
      (): void => {
        this.phoneLocalShowSelectMod = false;
      },
      (): void => {
        if (this.uiContext) {
          PhoneGameInstallHelper.openAdditionalInstallPicker(this.uiContext, this.uiContext.cacheDir);
        }
      },
    );
    PhoneLocalGameHelper.bindPhoneOverlay(overlay);
  }

  private bindPhoneContentHelper(): void {
    PhoneContentHelper.bindStateHandler((state: PhoneContentState): void => {
      this.phoneContentState = {
        updateCount: state.updateCount,
        selectedIndex: state.selectedIndex,
        packages: copyPhoneContentPackages(state.packages),
        detail: copyPhoneContentDetail(state.detail),
        actionError: state.actionError,
        actionSuccess: state.actionSuccess,
      };
    });
    PhoneContentHelper.bindBrowseHandler((): void => {
      if (this.uiContext) {
        PhoneGameInstallHelper.openAdditionalInstallPicker(this.uiContext, this.uiContext.cacheDir);
      }
    });
  }

  private bindPhoneSettingsHelper(): void {
    PhoneSettingsHelper.bindStateHandler((state: PhoneSettingsState): void => {
      this.phoneSettingsState = {
        pages: copyPhoneSettingsPages(state.pages),
        selectedPageId: state.selectedPageId,
        query: state.query,
        showTechnicalNames: state.showTechnicalNames,
        showAdvanced: state.showAdvanced,
        items: copyPhoneSettingsItems(state.items),
        actionError: state.actionError,
      };
    });
  }

  private bindFormspecTextInput(): void {
    OhosUiBridge.bindFormspecTextInput((req: FormspecTextInputRequest): void => {
      this.phoneFormspecTextEditType = req.editType;
      this.phoneFormspecTextHint = req.hint;
      this.phoneFormspecTextCurrent = req.current;
      this.phoneFormspecTextInputOpen = true;
    });
  }

  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!this.uiContext) {
      this.startupError = '无法获取应用上下文';
      return;
    }
    try {
      setDeviceFormFactor(deviceInfo.deviceType);
      OhosPlatformCompat.logRuntimeOnce();
      hilog.info(DOMAIN, TAG, 'deviceType=%{public}s publicDocs=%{public}s',
        deviceInfo.deviceType, OhosPlatformCompat.supportsPublicDocuments() ? 'yes' : 'sandbox');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setDeviceFormFactor: %{public}s', `${e}`);
    }
    this.bindLegalConsentPhoneOverlay();
    this.bindHealthyGamingPhoneOverlay();
    this.bindPhoneGameInstallOverlay();
    this.bindPhoneLocalGameOverlay();
    this.bindPhoneContentHelper();
    this.bindPhoneSettingsHelper();
    this.bindFormspecTextInput();
    if (this.uiContext) {
      PhoneContentHelper.setPaths(this.uiContext.cacheDir);
      PhoneSettingsHelper.setPaths(this.uiContext.cacheDir);
    }
    /* Load assets + engine first; legal / healthy gaming after main menu is ready. */
    this.beginStartup();
  }

  /** After engine ready: legal consent → Documents permission → healthy gaming → install gate. */
  private runPostLoadGates(): void {
    if (!this.uiContext || this.postLoadGatesDone) {
      return;
    }
    const runGates = async (): Promise<void> => {
      const accepted = await LegalConsentWindowHelper.ensureAccepted(this.uiContext!);
      if (!accepted || !this.uiContext) {
        return;
      }
      if (DeviceFormFactor.isPhone() && OhosPlatformCompat.supportsPublicDocuments() &&
        this.publicUserDir.length === 0) {
        /* System PermissionGrantAbility — no custom overlay; same API as PC/tablet. */
        const docsGranted = await DocumentsPermissionWindowHelper.ensureGranted(this.uiContext);
        if (docsGranted) {
          await this.ensurePublicUserDataMirror(false);
        }
      }
      await HealthyGamingWindowHelper.show(this.uiContext);
      if (DeviceFormFactor.isPhone()) {
        if (PhoneLocalGameHelper.hasRetailSubgames(this.engineUserDir)) {
          await PhoneLocalGameHelper.showIfNeeded(this.uiContext, this.engineUserDir);
        } else {
          await PhoneGameInstallHelper.show(this.uiContext, this.shareDir, this.engineUserDir);
        }
      }
      this.postLoadGatesDone = true;
      this.showStartupCover = false;
      this.requestGameSurfaceFocus();
      hilog.info(DOMAIN, TAG, 'Post-load gates complete — entering game');
    };
    runGates().catch((err: Error) => {
      this.startupError = err.message;
      hilog.error(DOMAIN, TAG, 'Post-load gates failed: %{public}s', err.message);
    });
  }

  private applyPublicUserDataMirror(publicDir: string): void {
    if (publicDir.length === 0 || this.engineUserDir.length === 0) {
      return;
    }
    this.publicUserDir = publicDir;
    OhosUiBridge.setUserDataDirs(this.engineUserDir, publicDir);
    setPublicUserDataDir(publicDir);
    hilog.info(DOMAIN, TAG, 'Public user_data mirror active: %{public}s', publicDir);
  }

  private async ensurePublicUserDataMirror(requestPermission: boolean = false): Promise<void> {
    if (!this.uiContext || this.engineUserDir.length === 0) {
      return;
    }
    if (this.publicUserDir.length > 0) {
      return;
    }
    const publicDir = await VoxeraPaths.activatePublicUserDataMirror(
      this.uiContext, this.engineUserDir, requestPermission);
    if (publicDir.length > 0) {
      this.applyPublicUserDataMirror(publicDir);
    }
  }

  private finishUserDataSetup(engineDir: string, publicDir: string): void {
    this.engineUserDir = engineDir;
    PhoneGameInstallHelper.setWatchUserDir(engineDir);
    this.publicUserDir = publicDir;
    OhosUiBridge.setUserDataDirs(engineDir, publicDir);
    setPublicUserDataDir(publicDir);
  }

  private shouldHideEngineSurface(): boolean {
    /* Never hide SURFACE XComponent — breaks GLES compositing on HarmonyOS phones. */
    return false;
  }

  private phoneOverlayBlocksInput(): boolean {
    return this.showLegalConsentOverlay || this.showHealthyGamingOverlay ||
      this.showPhoneGameInstallOverlay || this.showPhoneLocalGameOverlay ||
      this.shouldShowPhonePauseCover() || this.phoneExiting ||
      this.phoneFormspecTextInputOpen;
  }

  private shouldShowPhonePauseCover(): boolean {
    return this.assetsReady && DeviceFormFactor.isPhone() && this.inGameWorld &&
      (this.phoneNativePauseOpen || this.phonePauseSettingsOpen ||
        this.phonePauseProgress.length > 0);
  }

  @Builder
  private buildPhonePauseCover(): void {
    if (this.phonePauseSettingsOpen) {
      PhoneMoreMenuScreen({
        visible: $phonePauseSettingsOpen,
        shareDir: this.shareDir,
        contentState: this.phoneContentState,
        settingsState: this.phoneSettingsState,
        initialTab: 'settings',
        pauseSettingsMode: true,
      })
        .width('100%')
        .height('100%')
    } else {
      PhoneInGamePauseOverlay({
        progressLabel: this.phonePauseProgress,
        onContinue: (): void => {
          this.handlePhonePauseContinue();
        },
        onSettings: (): void => {
          this.handlePhonePauseOpenSettings();
        },
        onExitMenu: (): void => {
          this.handlePhonePauseExitMenu().catch((e: Error) => {
            hilog.warn(DOMAIN, TAG, 'exit menu: %{public}s', e.message);
          });
        },
        onExitOs: (): void => {
          this.handlePhonePauseExitOS().catch((e: Error) => {
            hilog.warn(DOMAIN, TAG, 'exit os: %{public}s', e.message);
          });
        },
      })
        .width('100%')
        .height('100%')
    }
  }

  private handlePhonePauseContinue(): void {
    if (this.phonePauseProgress.length > 0) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'phone pause: continue');
    this.phoneExiting = false;
    this.phonePauseSettingsOpen = false;
    setNativePauseActive(false);
    this.phoneNativePauseOpen = false;
  }

  private handlePhonePauseOpenSettings(): void {
    if (this.phonePauseProgress.length > 0) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'phone pause: open settings');
    this.phonePauseSettingsOpen = true;
    PhoneSettingsHelper.refresh();
  }

  /** Phone: native ArkUI home — not the Lua mainmenu tabview (OHOS draws in XComponent). */
  private requestPhoneNativeHome(reason: string): void {
    if (!DeviceFormFactor.isPhone() || !this.postLoadGatesDone || !this.assetsReady ||
      !this.uiContext) {
      return;
    }
    if (!PhoneLocalGameHelper.hasRetailSubgames(this.engineUserDir)) {
      return;
    }
    if (this.showPhoneGameInstallOverlay) {
      return;
    }
    this.phoneExiting = false;
    this.phoneNativePauseOpen = false;
    this.phonePauseSettingsOpen = false;
    this.phonePauseProgress = '';
    setNativePauseActive(false);
    this.focusRequestedForGame = false;
    hilog.info(DOMAIN, TAG, 'phone native home (%{public}s)', reason);
    PhoneLocalGameHelper.forceShowNativeHome(this.uiContext, this.engineUserDir).catch((e: Error) => {
      hilog.warn(DOMAIN, TAG, 'phone native home failed: %{public}s', e.message);
    });
  }

  private async handlePhonePauseExitMenu(): Promise<void> {
    if (this.phonePauseProgress.length > 0) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'phone pause: exit menu');
    this.phoneExiting = true;
    this.phonePauseSettingsOpen = false;
    this.phoneNativePauseOpen = false;
    setNativePauseActive(false);
    nativePauseExitMenu();
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      await new Promise<void>((resolve: (value: void) => void) => {
        setTimeout(resolve, 200);
      });
      const status = getEngineStatus();
      if (status.startsWith('main_menu:') || status === 'phone_local:state') {
        this.requestPhoneNativeHome('pause_exit_menu');
        return;
      }
    }
  }

  private async handlePhonePauseExitOS(): Promise<void> {
    if (this.phonePauseProgress.length > 0) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'phone pause: exit os');
    this.phoneExiting = true;
    this.phonePauseSettingsOpen = false;
    this.phoneNativePauseOpen = false;
    setNativePauseActive(false);
    nativePauseExitOS();
    await new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(resolve, 1800);
    });
    if (this.uiContext) {
      try {
        this.uiContext.terminateSelf();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'terminateSelf: %{public}s', `${e}`);
      }
    }
  }

  private shouldShowPhoneGateCover(): boolean {
    return DeviceFormFactor.isPhone() && !this.postLoadGatesDone && this.assetsReady &&
      !this.showLegalConsentOverlay &&
      !this.showHealthyGamingOverlay && !this.showPhoneGameInstallOverlay &&
      !this.showPhoneLocalGameOverlay;
  }

  private shouldShowStartupCover(): boolean {
    if (!this.showStartupCover || this.postLoadGatesDone) {
      return false;
    }
    if (this.showLegalConsentOverlay ||
      this.showHealthyGamingOverlay || this.showPhoneGameInstallOverlay ||
      this.showPhoneLocalGameOverlay) {
      return false;
    }
    return true;
  }

  /** After first-launch legal consent: assets, permissions, engine paths. */
  private beginStartup(): void {
    if (!this.uiContext) {
      return;
    }
    LuantiAssets.ensureInstalled(this.uiContext).then(async (shareDir: string) => {
      this.shareDir = shareDir;
      try {
        LuantiAssets.verifyInstalled(shareDir);
      } catch (e) {
        throw new Error(`${e}`);
      }
      const engineDir = VoxeraPaths.sandboxUserDir(this.uiContext!);
      VoxeraPaths.ensureUserDataTree(engineDir);
      let publicDir = '';
      const phoneDocsDeferred = DeviceFormFactor.isPhone() && OhosPlatformCompat.supportsPublicDocuments();
      if (!phoneDocsDeferred && OhosPlatformCompat.supportsPublicDocuments()) {
        publicDir = await VoxeraPaths.activatePublicUserDataMirror(this.uiContext!, engineDir);
      }
      this.finishUserDataSetup(engineDir, publicDir);
      setAppDataPaths(shareDir, this.uiContext!.cacheDir, engineDir);
      this.assetsReady = true;
      if (deviceInfo.deviceType === 'tablet') {
        TabletWindowHelper.applyGameWindow(this.uiContext!).catch(() => {
        });
      } else if (deviceInfo.deviceType === 'phone' || deviceInfo.deviceType === 'default') {
        PhoneWindowHelper.applyGameWindow(this.uiContext!).catch(() => {
        });
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

  /** Set once engine reaches main menu (status string may later change to phone_local:*). */
  private engineMenuReadySeen: boolean = false;

  /** Release: drop startup cover when main menu (or equivalent) is ready. */
  private shouldDismissStartupCover(status: string): boolean {
    if (this.startupError.length > 0) {
      return false;
    }
    if (status.startsWith('main_menu:') || status === 'phone_local:state') {
      this.engineMenuReadySeen = true;
      return true;
    }
    if (status.startsWith('init_engine:') && status.includes('done')) {
      this.engineMenuReadySeen = true;
      return true;
    }
    if (status.startsWith('video driver:')) {
      this.engineMenuReadySeen = true;
      return true;
    }
    return this.engineMenuReadySeen;
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
    if (deviceInfo.deviceType !== '2in1') {
      return;
    }
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
    PhoneGameInstallHelper.onEngineStatus(status);
    PhoneLocalGameHelper.onEngineStatus(status);
    PhoneContentHelper.onEngineStatus(status);
    PhoneSettingsHelper.onEngineStatus(status);
    if (status === 'phone_install:ok' && this.uiContext) {
      PhoneLocalGameHelper.onInstallSuccess(this.uiContext, this.engineUserDir);
      PhoneContentHelper.refresh();
    }
    const wasInGameWorld = this.inGameWorld;
    this.inGameWorld = isInGameWorld();
    if (this.inGameWorld && this.showPhoneLocalGameOverlay) {
      this.showPhoneLocalGameOverlay = false;
      PhoneLocalGameHelper.markUiClosed();
    }
    if (this.inGameWorld !== wasInGameWorld) {
      hilog.info(DOMAIN, TAG, 'inGameWorld %{public}s -> %{public}s (status=%{public}s)',
        wasInGameWorld ? 'true' : 'false', this.inGameWorld ? 'true' : 'false', status);
    }
    if (DeviceFormFactor.isPhone() && this.postLoadGatesDone && this.assetsReady &&
      !this.inGameWorld && wasInGameWorld && !this.phoneExiting &&
      this.isLeavingInGameStatus(status)) {
      PhoneLocalGameHelper.onLeftGame();
      this.requestPhoneNativeHome(`left_game:${status}`);
    }
    if (DeviceFormFactor.isPhone() && this.inGameWorld) {
      this.phoneNativePauseOpen = getNativePauseActive();
      this.phoneInventoryOpen = isPlayerInventoryOpen();
    } else if (!this.inGameWorld) {
      this.phoneExiting = false;
      this.phoneNativePauseOpen = false;
      this.phoneInventoryOpen = false;
      this.phonePauseSettingsOpen = false;
      this.focusRequestedForGame = false;
      if (this.phonePauseProgress.length > 0 && !status.startsWith('main_menu:')) {
        this.phonePauseProgress = '';
      }
    }
    const inWorld = this.inGameWorld;
    this.setMouseCapture(inWorld && this.assetsReady);
    if (this.inGameWorld && this.assetsReady && !this.focusRequestedForGame) {
      this.focusRequestedForGame = true;
      this.requestGameSurfaceFocus();
      hilog.info(DOMAIN, TAG, 'in_game: requesting XComponent focus');
    }
    if (this.shouldDismissStartupCover(status) && this.assetsReady) {
      if (!this.postLoadGatesStarted) {
        this.postLoadGatesStarted = true;
        if (this.statusTimer >= 0) {
          clearInterval(this.statusTimer);
          this.statusTimer = setInterval(() => {
            this.refreshStatus();
          }, 500);
        }
        if (!DeviceFormFactor.isPhone()) {
          this.showStartupCover = false;
        }
        this.runPostLoadGates();
      }
    } else if (this.postLoadGatesDone) {
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

  /** Engine status that means we left the world (not pause-menu pick noise). */
  private isLeavingInGameStatus(status: string): boolean {
    if (status.startsWith('in_game:')) {
      return false;
    }
    if (status.startsWith('phone_settings:') || status.startsWith('phone_content:') ||
      status.startsWith('pick ok:') || status.startsWith('pause_menu:') ||
      status.startsWith('menu:')) {
      return false;
    }
    return true;
  }

  private usesTouchOverlay(): boolean {
    const t = deviceInfo.deviceType;
    return t === 'tablet' || t === 'phone' || t === 'default';
  }

  private touchToSurfacePx(t: TouchObject): number[] {
    const ui = this.getUIContext();
    /* windowX/windowY are vp; engine/SDL surface uses physical pixels (see vpr ~2.25 on tablet). */
    return [ui.vp2px(t.windowX), ui.vp2px(t.windowY)];
  }

  private handleTouchEvent(event: TouchEvent): void {
    if (!this.assetsReady || !this.usesTouchOverlay()) {
      return;
    }
    if (event.type !== TouchType.Down && event.type !== TouchType.Up &&
      event.type !== TouchType.Cancel && event.type !== TouchType.Move) {
      return;
    }
    for (let i = 0; i < event.changedTouches.length; i++) {
      const t = event.changedTouches[i];
      const px = this.touchToSurfacePx(t);
      const x = px[0];
      const y = px[1];
      let action = 1;
      if (event.type === TouchType.Down) {
        action = 0;
      } else if (event.type === TouchType.Move) {
        action = 2;
      } else if (event.type === TouchType.Cancel) {
        action = 3;
      }
      if (this.touchInjectLogCount < 10) {
        hilog.info(DOMAIN, TAG,
          'touch inject vp(%{public}s,%{public}s) -> px(%{public}s,%{public}s) action=%{public}d',
          `${t.windowX}`, `${t.windowY}`, `${x}`, `${y}`, action);
        this.touchInjectLogCount++;
      }
      injectTouch(x, y, action, t.id);
    }
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
          .focusable(!this.phoneNativePauseOpen && !this.phonePauseSettingsOpen)
          .defaultFocus(!this.phoneNativePauseOpen && !this.phonePauseSettingsOpen)
          .focusOnTouch(!this.phoneNativePauseOpen && !this.phonePauseSettingsOpen)
          .hitTestBehavior(this.usesTouchOverlay() ? HitTestMode.None : HitTestMode.Default)
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
                  const engineDir = VoxeraPaths.sandboxUserDir(this.uiContext!);
                  VoxeraPaths.ensureUserDataTree(engineDir);
                  let publicDir = '';
                  const phoneDocsDeferred = DeviceFormFactor.isPhone() &&
                    OhosPlatformCompat.supportsPublicDocuments();
                  if (!phoneDocsDeferred && OhosPlatformCompat.supportsPublicDocuments()) {
                    publicDir = await VoxeraPaths.activatePublicUserDataMirror(this.uiContext!, engineDir);
                  }
                  this.finishUserDataSetup(engineDir, publicDir);
                  setAppDataPaths(dir, this.uiContext!.cacheDir, engineDir);
                  this.assetsReady = true;
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
              }, this.postLoadGatesStarted ? 500 : 100);
            }
            if (this.postLoadGatesDone) {
              this.requestGameSurfaceFocus();
            }
            hilog.info(DOMAIN, TAG, 'XComponent onLoad');
          })
          .onDestroy(() => {
            hilog.info(DOMAIN, TAG, 'XComponent onDestroy');
          })
      }

      /* SURFACE XComponent often ignores ArkUI onTouch on ARM; transparent layer catches taps. */
      if (this.assetsReady && this.usesTouchOverlay()
        && !this.phoneOverlayBlocksInput()
        && (!DeviceFormFactor.isPhone() || this.inGameWorld)) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.Block)
          .onTouch((event: TouchEvent) => this.handleTouchEvent(event))
          .zIndex(3)
      }

      if (this.assetsReady && DeviceFormFactor.isPhone() && this.inGameWorld &&
        !this.phoneOverlayBlocksInput()) {
        PhoneGameControls({ pauseMenuOpen: $phoneNativePauseOpen, inventoryOpen: $phoneInventoryOpen })
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)
          .zIndex(4)
      }

      if (this.assetsReady && DeviceFormFactor.isPhone() && this.phoneFormspecTextInputOpen) {
        PhoneFormspecTextInput({
          visible: $phoneFormspecTextInputOpen,
          editType: this.phoneFormspecTextEditType,
          hint: this.phoneFormspecTextHint,
          current: this.phoneFormspecTextCurrent,
        })
          .width('100%')
          .height('100%')
      }

      /* Zip drag-drop needs UniformDataType.FILE_URI + UnifiedRecord.getEntry (API 15+).
       * OpenHarmony API 13–14: use install dialog + button / DocumentPicker only. */

      WindowDecorCapsule({
        visible: this.showDecorCapsule && this.assetsReady,
        capsuleWidth: this.capsuleWidth,
        capsuleHeight: this.capsuleHeight,
        marginTop: this.capsuleMarginTop,
        marginRight: this.capsuleMarginRight,
      })

      if (this.showLegalConsentOverlay) {
        LegalConsentPanel({ layout: LEGAL_LAYOUT_PHONE })
          .width('100%')
          .height('100%')
          .zIndex(52)
      }

      if (this.showHealthyGamingOverlay) {
        HealthyGamingPanel({ layout: HEALTHY_LAYOUT_PHONE })
          .width('100%')
          .height('100%')
          .zIndex(50)
      }

      if (this.showPhoneGameInstallOverlay) {
        PhoneGameInstallPanel({
          screen: this.phoneInstallScreen,
          statusText: this.phoneInstallStatus,
          shareDir: this.shareDir,
          contentState: this.phoneContentState,
          settingsState: this.phoneSettingsState,
        })
          .width('100%')
          .height('100%')
          .zIndex(55)
      }

      /* In-game pause + settings-from-pause: in-stack overlay (bindContentCover breaks touch on OHOS). */
      if (this.shouldShowPhonePauseCover()) {
        Stack({ alignContent: Alignment.Center }) {
          this.buildPhonePauseCover()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Default)
        .zIndex(70)
        .onAppear(() => {
          hilog.info(DOMAIN, TAG,
            'phone pause overlay shown native=%{public}s settings=%{public}s progress=%{public}s',
            `${this.phoneNativePauseOpen}`, `${this.phonePauseSettingsOpen}`, this.phonePauseProgress);
        })
      }

      if (this.showPhoneLocalGameOverlay) {
        PhoneLocalGamePanel({
          userDir: this.engineUserDir,
          shareDir: this.shareDir,
          externalState: this.phoneLocalState,
          worldsProp: this.phoneLocalWorlds,
          showCreateWorld: this.phoneLocalShowCreateWorld,
          createSchema: this.phoneLocalCreateSchema,
          createError: this.phoneLocalCreateError,
          onCloseCreateWorld: (): void => {
            this.phoneLocalShowCreateWorld = false;
            this.phoneLocalCreateError = '';
          },
          onOpenCreateWorld: (): void => {
            this.phoneLocalPendingCreateOpen = true;
            this.phoneLocalCreateError = '';
            PhoneLocalGameHelper.requestCreateSchema();
          },
          showSelectMod: this.phoneLocalShowSelectMod,
          modSchema: this.phoneLocalModSchema,
          onCloseSelectMod: (): void => {
            this.phoneLocalShowSelectMod = false;
          },
          onModFindMore: (): void => {
            if (this.uiContext) {
              PhoneGameInstallHelper.openAdditionalInstallPicker(this.uiContext, this.uiContext.cacheDir);
            }
          },
          contentState: this.phoneContentState,
          settingsState: this.phoneSettingsState,
        })
          .width('100%')
          .height('100%')
          .zIndex(51)
      }

      /* Phone: opaque cover over engine until compliance gates finish (do not hide XComponent). */
      if (this.shouldShowPhoneGateCover()) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(STARTUP_COVER_COLOR)
          .zIndex(45)
      }

      /* Layer-2 splash: only while loading, never after compliance dialogs. */
      if (this.shouldShowStartupCover()) {
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
          } else {
            Image($r('app.media.splash_logo'))
              .width(this.startupIconVp())
              .height(this.startupIconVp())
              .objectFit(ImageFit.Contain)
              .interpolation(ImageInterpolation.High)
              .renderMode(ImageRenderMode.Original)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(this.startupError.length > 0 ? HorizontalAlign.Start : HorizontalAlign.Center)
        .padding(this.startupError.length > 0 ? 24 : 0)
        .backgroundColor(STARTUP_COVER_COLOR)
        .hitTestBehavior(HitTestMode.None)
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
