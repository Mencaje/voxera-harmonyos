import { Environment, fileIo as fs } from '@kit.CoreFileKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
import { userDataCopyTask } from './VoxeraSyncWorker';

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

  static sandboxUserDir(context: common.UIAbilityContext): string {
    return `${context.filesDir}/luanti_user`;
  }

  static publicUserDataDir(): string {
    const docs = Environment.getUserDocumentDir();
    return `${docs}/${VOXERA_APP_FOLDER}/${VOXERA_USER_DATA_FOLDER}`;
  }

  static async ensureDocumentsPermission(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const tokenId = context.applicationInfo.accessTokenId;
      const status = await atManager.checkAccessToken(tokenId, DOC_PERM);
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'checkAccessToken failed: %{public}s', `${e}`);
    }
    try {
      const result = await atManager.requestPermissionsFromUser(context, [DOC_PERM]);
      return result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'requestPermissionsFromUser failed: %{public}s', `${e}`);
      return false;
    }
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
