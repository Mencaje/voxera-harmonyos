import { Environment, fileIo as fs } from '@kit.CoreFileKit';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { window } from '@kit.ArkUI';
import { userDataCopyTask } from './VoxeraSyncWorker';
import { OhosPlatformCompat } from './OhosPlatformCompat';
import { DeviceFormFactor } from './DeviceFormFactor';
import { WindowDecorHelper } from './WindowDecorHelper';

const DOMAIN = 0x0000;
const TAG = 'VoxeraPaths';

/** Top-level folder in Documents (matches app display name). */
export const VOXERA_APP_FOLDER = 'Voxera';
/** English user-data folder (Luanti path_user equivalent). */
export const VOXERA_USER_DATA_FOLDER = 'user_data';

const DOC_PERM: Permissions = 'ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY';

const USER_SUBDIRS: string[] = [
  'worlds',
  'games',
  'mods',
  'clientmods',
  'textures',
  'client/serverlist',
];

/**
 * Public user data: Documents/Voxera/user_data (requires READ_WRITE_DOCUMENTS_DIRECTORY).
 * Falls back to app-private luanti_user if Documents is unavailable.
 */
export class VoxeraPaths {
  private static syncInFlight: boolean = false;
  /** Only one system permission sheet at a time (concurrent calls dismiss each other). */
  private static documentsPermissionRequest: Promise<boolean> | null = null;

  static sandboxUserDir(context: common.UIAbilityContext): string {
    return `${context.filesDir}/luanti_user`;
  }

  static publicUserDataDir(): string {
    if (!OhosPlatformCompat.supportsPublicDocuments()) {
      return '';
    }
    try {
      const docs = Environment.getUserDocumentDir();
      return `${docs}/${VOXERA_APP_FOLDER}/${VOXERA_USER_DATA_FOLDER}`;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getUserDocumentDir failed: %{public}s', `${e}`);
      return '';
    }
  }

  static async checkDocumentsPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (!OhosPlatformCompat.supportsPublicDocuments()) {
      return false;
    }
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const tokenId = context.applicationInfo.accessTokenId;
      const status = await atManager.checkAccessToken(tokenId, DOC_PERM);
      return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'checkAccessToken failed: %{public}s', `${e}`);
      return false;
    }
  }

  static async ensureDocumentsPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (!OhosPlatformCompat.supportsPublicDocuments()) {
      return false;
    }
    if (await VoxeraPaths.checkDocumentsPermission(context)) {
      return true;
    }
    if (VoxeraPaths.documentsPermissionRequest !== null) {
      hilog.info(DOMAIN, TAG, 'Documents permission request already in flight — awaiting');
      return VoxeraPaths.documentsPermissionRequest;
    }
    VoxeraPaths.documentsPermissionRequest = VoxeraPaths.requestDocumentsPermissionOnce(context);
    try {
      return await VoxeraPaths.documentsPermissionRequest;
    } finally {
      VoxeraPaths.documentsPermissionRequest = null;
    }
  }

  private static delayMs(ms: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Exit immersive fullscreen, then request — system PermissionGrantAbility needs visible UI
   * and a user gesture; auto-request during startup is dismissed immediately (authResult=2).
   */
  static async requestDocumentsPermissionInteractive(context: common.UIAbilityContext): Promise<boolean> {
    if (!OhosPlatformCompat.supportsPublicDocuments()) {
      return false;
    }
    if (await VoxeraPaths.checkDocumentsPermission(context)) {
      return true;
    }
    let win: window.Window | undefined;
    try {
      win = await window.getLastWindow(context);
      await WindowDecorHelper.applyImmersiveFullscreen(win, false);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'exit immersive before permission: %{public}s', `${e}`);
    }
    await VoxeraPaths.delayMs(400);
    const granted = await VoxeraPaths.ensureDocumentsPermission(context);
    if (win && DeviceFormFactor.isPhone()) {
      try {
        await WindowDecorHelper.applyImmersiveFullscreen(win, true);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'restore immersive after permission: %{public}s', `${e}`);
      }
    }
    return granted;
  }

  /** Log bundle + token info before request; helps diagnose authResult=2 (invalid / missing ACL). */
  static async logDocumentsPermissionDiagnostics(context: common.UIAbilityContext): Promise<void> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      hilog.info(DOMAIN, TAG,
        'Documents perm diagnostics: bundle=%{public}s version=%{public}s tokenId=%{public}d apl=%{public}s',
        info.name, info.versionName, context.applicationInfo.accessTokenId,
        context.applicationInfo.appDistributionType ?? 'unknown');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Documents perm diagnostics failed: %{public}s', `${e}`);
    }
    hilog.warn(DOMAIN, TAG,
      'READ_WRITE_DOCUMENTS_DIRECTORY is system_basic — requires ACL in p7b signing profile ' +
      '(AGC: restricted ACL permission). authResult=2 means invalid request, not user denial.');
  }

  /** HarmonyOS: abilityAccessCtrl.requestPermissionsFromUser(UIAbilityContext, …). */
  private static async requestDocumentsPermissionOnce(
    context: common.UIAbilityContext,
  ): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      hilog.info(DOMAIN, TAG, 'Requesting Documents permission via requestPermissionsFromUser');
      const result = await atManager.requestPermissionsFromUser(context, [DOC_PERM]);
      const code = result.authResults.length > 0 ? result.authResults[0] : -99;
      const granted = code === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      const dialogShown = result.dialogShownResults !== undefined && result.dialogShownResults.length > 0
        ? result.dialogShownResults[0] : -1;
      hilog.info(DOMAIN, TAG,
        'Documents permission result: authResult=%{public}d dialogShown=%{public}d granted=%{public}s perms=%{public}s',
        code, dialogShown, granted ? 'yes' : 'no', JSON.stringify(result.permissions));
      if (code === 2) {
        await VoxeraPaths.logDocumentsPermissionDiagnostics(context);
        hilog.error(DOMAIN, TAG,
          'System permission sheet dismissed immediately (authResult=2). ' +
          'Re-sign with p7b profile that includes ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY ACL.');
      }
      return granted;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'requestPermissionsFromUser failed: %{public}s', `${e}`);
      return false;
    }
  }

  /**
   * After Documents permission: create Documents/Voxera/user_data tree (worlds, games, mods, …)
   * and mirror sandbox engine data — same folders Luanti creates via core.create_dir.
   */
  static async activatePublicUserDataMirror(
    context: common.UIAbilityContext,
    engineDir: string,
    requestPermission: boolean = true,
  ): Promise<string> {
    if (!OhosPlatformCompat.supportsPublicDocuments() || engineDir.length === 0) {
      return '';
    }
    VoxeraPaths.ensureUserDataTree(engineDir);
    const docsOk = requestPermission
      ? await VoxeraPaths.ensureDocumentsPermission(context)
      : await VoxeraPaths.checkDocumentsPermission(context);
    if (!docsOk) {
      return '';
    }
    const publicDir = VoxeraPaths.publicUserDataDir();
    if (publicDir.length === 0) {
      return '';
    }
    VoxeraPaths.ensureUserDataTree(publicDir);
    VoxeraPaths.migratePublicToEngine(context, publicDir);
    if (VoxeraPaths.needsSandboxMigrate(publicDir)) {
      VoxeraPaths.scheduleMigrateSandboxUserData(context, publicDir);
    } else {
      VoxeraPaths.scheduleSyncEngineToPublic(engineDir, publicDir);
    }
    hilog.info(DOMAIN, TAG, 'Public user_data ready: %{public}s', publicDir);
    return publicDir;
  }

  static resolveUserDataDir(context: common.UIAbilityContext, documentsGranted: boolean): string {
    if (documentsGranted) {
      try {
        const dir = VoxeraPaths.publicUserDataDir();
        if (dir.length > 0) {
          return dir;
        }
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'getUserDocumentDir failed: %{public}s', `${e}`);
      }
    }
    return VoxeraPaths.sandboxUserDir(context);
  }

  private static mkdirSafe(path: string): void {
    try {
      fs.mkdirSync(path, true);
    } catch (e) {
      const msg = `${e}`;
      if (!msg.includes('File exists') && !msg.includes('13900011')) {
        hilog.warn(DOMAIN, TAG, 'mkdir %{public}s: %{public}s', path, msg);
      }
    }
  }

  static ensureUserDataTree(root: string): void {
    VoxeraPaths.mkdirSafe(root);
    for (let i = 0; i < USER_SUBDIRS.length; i++) {
      const rel = USER_SUBDIRS[i];
      const idx = rel.indexOf('/');
      if (idx >= 0) {
        VoxeraPaths.mkdirSafe(`${root}/${rel.substring(0, idx)}`);
      }
      VoxeraPaths.mkdirSafe(`${root}/${rel}`);
    }
    const readme = `${root}/README.txt`;
    try {
      if (fs.statSync(readme).size > 0) {
        return;
      }
    } catch {
      // create below
    }
    const text = 'Voxera user data (worlds, games, mods). Back up this folder to keep your saves.\n';
    const out = fs.openSync(readme, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.writeSync(out.fd, text);
    fs.closeSync(out);
  }

  static deleteTree(root: string): void {
    let names: string[] = [];
    try {
      names = fs.listFileSync(root);
    } catch {
      return;
    }
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      if (name === '.' || name === '..') {
        continue;
      }
      const p = `${root}/${name}`;
      let isDir = false;
      try {
        isDir = fs.statSync(p).isDirectory();
      } catch {
        continue;
      }
      if (isDir) {
        VoxeraPaths.deleteTree(p);
      } else {
        try {
          fs.unlinkSync(p);
        } catch {
          // ignore
        }
      }
    }
    try {
      fs.rmdirSync(root);
    } catch {
      // ignore
    }
  }

  /** Recursive copy (ArkTS fileIo); required for Documents paths on OHOS. */
  static copyDirectory(src: string, dest: string): boolean {
    try {
      fs.accessSync(src);
    } catch {
      return false;
    }
    try {
      fs.accessSync(dest);
      VoxeraPaths.deleteTree(dest);
    } catch {
      // dest does not exist yet
    }
    VoxeraPaths.copyTree(src, dest);
    return true;
  }

  /** Pull Documents user_data into sandbox when engine has no worlds yet. */
  static migratePublicToEngine(context: common.UIAbilityContext, publicRoot: string): void {
    const engine = VoxeraPaths.sandboxUserDir(context);
    if (engine === publicRoot) {
      return;
    }
    const marker = `${engine}/.imported_from_public`;
    try {
      fs.accessSync(marker);
      return;
    } catch {
      // continue
    }
    try {
      fs.accessSync(publicRoot);
    } catch {
      return;
    }
    let publicWorlds = false;
    try {
      const w = fs.listFileSync(`${publicRoot}/worlds`);
      publicWorlds = w.length > 0;
    } catch {
      // no worlds in public
    }
    let engineWorlds = false;
    try {
      const w = fs.listFileSync(`${engine}/worlds`);
      engineWorlds = w.length > 0;
    } catch {
      // no worlds dir yet
    }
    if (!publicWorlds || engineWorlds) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'Import public -> engine: %{public}s', publicRoot);
    VoxeraPaths.copyTree(publicRoot, engine);
    const flag = fs.openSync(marker, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.writeSync(flag.fd, new Date().toISOString());
    fs.closeSync(flag);
  }

  /** Mirror sandbox → Documents on a worker thread (never block UI). */
  static scheduleSyncEngineToPublic(engineDir: string, publicRoot: string): void {
    if (!publicRoot || engineDir === publicRoot || VoxeraPaths.syncInFlight) {
      return;
    }
    VoxeraPaths.syncInFlight = true;
    hilog.info(DOMAIN, TAG, 'Schedule background sync -> %{public}s', publicRoot);
    const task = new taskpool.Task(userDataCopyTask, engineDir, publicRoot, 0);
    taskpool.execute(task).then(() => {
      VoxeraPaths.syncInFlight = false;
      hilog.info(DOMAIN, TAG, 'Background sync finished');
    }).catch((e: object) => {
      VoxeraPaths.syncInFlight = false;
      hilog.warn(DOMAIN, TAG, 'Background sync failed: %{public}s', `${e}`);
    });
  }

  static needsSandboxMigrate(publicRoot: string): boolean {
    try {
      fs.accessSync(`${publicRoot}/.migrated_from_sandbox`);
      return false;
    } catch {
      return true;
    }
  }

  static scheduleMigrateSandboxUserData(context: common.UIAbilityContext, publicRoot: string): void {
    const engine = VoxeraPaths.sandboxUserDir(context);
    if (!publicRoot || engine === publicRoot) {
      return;
    }
    const marker = `${publicRoot}/.migrated_from_sandbox`;
    try {
      fs.accessSync(marker);
      return;
    } catch {
      // not migrated yet
    }
    hilog.info(DOMAIN, TAG, 'Schedule background sandbox migrate -> %{public}s', publicRoot);
    const task = new taskpool.Task(userDataCopyTask, engine, publicRoot, 1);
    taskpool.execute(task).catch((e: object) => {
      hilog.warn(DOMAIN, TAG, 'Background migrate failed: %{public}s', `${e}`);
    });
  }

  /** Copy sandbox luanti_user into public user_data when upgrading (once). */
  static migrateSandboxUserData(context: common.UIAbilityContext, publicRoot: string): void {
    const legacy = VoxeraPaths.sandboxUserDir(context);
    if (legacy === publicRoot) {
      return;
    }
    try {
      fs.accessSync(legacy);
    } catch {
      return;
    }
    const marker = `${publicRoot}/.migrated_from_sandbox`;
    try {
      fs.accessSync(marker);
      return;
    } catch {
      // continue
    }
    hilog.info(DOMAIN, TAG, 'Migrating %{public}s -> %{public}s', legacy, publicRoot);
    VoxeraPaths.copyTree(legacy, publicRoot);
    const flag = fs.openSync(marker, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.writeSync(flag.fd, new Date().toISOString());
    fs.closeSync(flag);
  }

  private static copyTree(src: string, dest: string): void {
    let names: string[] = [];
    try {
      names = fs.listFileSync(src);
    } catch {
      return;
    }
    VoxeraPaths.mkdirSafe(dest);
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      if (name === '.' || name === '..') {
        continue;
      }
      const from = `${src}/${name}`;
      const to = `${dest}/${name}`;
      let isDir = false;
      try {
        isDir = fs.statSync(from).isDirectory();
      } catch {
        continue;
      }
      if (isDir) {
        VoxeraPaths.copyTree(from, to);
      } else {
        try {
          try {
            fs.unlinkSync(to);
          } catch {
            // ignore
          }
          fs.copyFileSync(from, to);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'copy %{public}s failed: %{public}s', from, `${e}`);
        }
      }
    }
  }
}
