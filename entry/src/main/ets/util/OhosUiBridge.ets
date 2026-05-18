import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { completeOhosCopyDir, completeOhosFilePick, pollOhosUiRequest } from '../native/LuantiNative';
import { VoxeraPaths } from './VoxeraPaths';
import pointer from '@ohos.multimodalInput.pointer';
import { WindowDecorHelper } from './WindowDecorHelper';

const DOMAIN = 0x0000;
const TAG = 'OhosUiBridge';

export class OhosUiBridge {
  private static picking: boolean = false;
  private static decorHelper: WindowDecorHelper | undefined = undefined;
  private static uiContext: common.UIAbilityContext | undefined = undefined;
  private static engineUserDir: string = '';
  private static publicUserDir: string = '';

  static setUserDataDirs(engineDir: string, publicDir: string): void {
    OhosUiBridge.engineUserDir = engineDir;
    OhosUiBridge.publicUserDir = publicDir;
  }

  static bindWindowDecor(helper: WindowDecorHelper): void {
    OhosUiBridge.decorHelper = helper;
  }

  static async poll(context: common.UIAbilityContext, cacheDir: string): Promise<void> {
    OhosUiBridge.uiContext = context;
    const req = pollOhosUiRequest();
    if (!req || req.kind === 0) {
      return;
    }

    if (req.kind === 6 && req.payload.length > 0) {
      OhosUiBridge.handleCopyDir(req.payload);
      return;
    }

    if (req.kind === 1 && req.payload.length > 0) {
      await OhosUiBridge.openInSystemBrowser(context, req.payload);
      return;
    }

    if (req.kind === 5 && req.payload.length > 0) {
      await OhosUiBridge.openLocalFolder(context, req.payload);
      return;
    }

    if (req.kind === 3) {
      const capture = req.payload === '1';
      try {
        pointer.setPointerVisibleSync(!capture);
        hilog.info(DOMAIN, TAG, 'relative mouse capture=%{public}s', capture ? 'on' : 'off');
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'setPointerVisibleSync failed: %{public}s', `${e}`);
      }
      return;
    }

    if (req.kind === 4) {
      await OhosUiBridge.applyFullscreen(context, req.payload === '1');
      return;
    }

    if (req.kind === 2 && req.payload.length > 0 && !OhosUiBridge.picking) {
      OhosUiBridge.picking = true;
      const formname = req.payload;
      try {
        const path = await OhosUiBridge.pickZipToCache(context, cacheDir);
        hilog.info(DOMAIN, TAG, 'pick ok: %{public}s', path);
        completeOhosFilePick(formname, path);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'pick canceled or failed: %{public}s', `${e}`);
        completeOhosFilePick(formname, '');
      } finally {
        OhosUiBridge.picking = false;
      }
    }
  }

  private static async applyFullscreen(context: common.UIAbilityContext, immersive: boolean): Promise<void> {
    if (OhosUiBridge.decorHelper) {
      await OhosUiBridge.decorHelper.setImmersive(context, immersive);
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      await WindowDecorHelper.applyImmersiveFullscreen(win, immersive);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'applyFullscreen failed: %{public}s', `${e}`);
    }
  }

  private static handleCopyDir(payload: string): void {
    const nl = payload.indexOf('\n');
    if (nl <= 0) {
      completeOhosCopyDir(false);
      return;
    }
    const src = payload.substring(0, nl);
    const dest = payload.substring(nl + 1);
    try {
      const ok = VoxeraPaths.copyDirectory(src, dest);
      hilog.info(DOMAIN, TAG, 'copyDir %{public}s -> %{public}s ok=%{public}s', src, dest, ok ? 'yes' : 'no');
      completeOhosCopyDir(ok);
      if (ok && OhosUiBridge.engineUserDir.length > 0 && OhosUiBridge.publicUserDir.length > 0) {
        VoxeraPaths.scheduleSyncEngineToPublic(OhosUiBridge.engineUserDir, OhosUiBridge.publicUserDir);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'copyDir failed: %{public}s', `${e}`);
      completeOhosCopyDir(false);
    }
  }

  private static async openLocalFolder(context: common.UIAbilityContext, dirPath: string): Promise<void> {
    try {
      fs.accessSync(dirPath);
    } catch {
      fs.mkdirSync(dirPath, true);
    }
    let uri = '';
    try {
      uri = fileUri.getUriFromPath(dirPath);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getUriFromPath failed: %{public}s', `${e}`);
      return;
    }
    const want: Want = {
      bundleName: 'com.huawei.hmos.filemanager',
      abilityName: 'MainAbility',
      parameters: {
        fileUri: uri,
      },
    };
    try {
      await context.startAbility(want);
      hilog.info(DOMAIN, TAG, 'opened folder %{public}s', dirPath);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'filemanager startAbility failed, picker fallback: %{public}s', `${e}`);
      try {
        const documentPicker = new picker.DocumentViewPicker(context);
        const options = new picker.DocumentSelectOptions();
        options.maxSelectNumber = 1;
        options.defaultFilePathUri = uri;
        await documentPicker.select(options);
      } catch (e2) {
        hilog.error(DOMAIN, TAG, 'open folder failed: %{public}s', `${e2}`);
      }
    }
  }

  private static async openInSystemBrowser(context: common.UIAbilityContext, url: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url,
    };
    try {
      await context.startAbility(want);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'startAbility browser failed: %{public}s', `${e}`);
    }
  }

  /** Copy a picked/dropped .zip URI into cache, extract, return extract dir (same as + button). */
  static async uriZipToExtractDir(uri: string, cacheDir: string): Promise<string> {
    const zipPath = `${cacheDir}/picked_game_${Date.now()}.zip`;
    const src = await fs.open(uri, fs.OpenMode.READ_ONLY);
    const dst = await fs.open(zipPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    await fs.copyFile(src.fd, dst.fd);
    fs.closeSync(src);
    fs.closeSync(dst);

    const st = fs.statSync(zipPath);
    if (st.size < 1) {
      throw new Error('copied zip is empty');
    }
    hilog.info(DOMAIN, TAG, 'zip cached %{public}d bytes -> %{public}s', st.size, zipPath);

    const extractDir = `${cacheDir}/pkg_install_${Date.now()}`;
    await OhosUiBridge.extractZipToDir(zipPath, extractDir);
    hilog.info(DOMAIN, TAG, 'zip extracted -> %{public}s', extractDir);
    return extractDir;
  }

  static extractFileUriFromDrop(event: DragEvent): string {
    const data = event.getData();
    if (!data) {
      return '';
    }
    const records = data.getRecords();
    for (let i = 0; i < records.length; i++) {
      const rec = records[i];
      if (rec.getType() !== uniformTypeDescriptor.UniformDataType.FILE_URI) {
        continue;
      }
      const entry = rec.getEntry(uniformTypeDescriptor.UniformDataType.FILE_URI) as Record<string, Object>;
      const oriUri = entry['oriUri'] as string | undefined;
      if (oriUri && oriUri.length > 0) {
        return oriUri;
      }
      const fileUri = entry['fileUri'] as string | undefined;
      if (fileUri && fileUri.length > 0) {
        return fileUri;
      }
    }
    return '';
  }

  static handleZipDrop(context: common.UIAbilityContext, cacheDir: string,
    formname: string, event: DragEvent): void {
    const uri = OhosUiBridge.extractFileUriFromDrop(event);
    if (uri.length === 0) {
      hilog.warn(DOMAIN, TAG, 'drop: no FILE_URI in drag data');
      return;
    }
    if (OhosUiBridge.picking) {
      return;
    }
    OhosUiBridge.picking = true;
    OhosUiBridge.uriZipToExtractDir(uri, cacheDir).then((path: string) => {
      hilog.info(DOMAIN, TAG, 'drop install ok: %{public}s', path);
      completeOhosFilePick(formname, path);
      // DragResult.DRAG_SUCCESSFUL = 0; enum not exported from @kit.ArkUI in this SDK.
      try {
        event.setResult(0);
      } catch {
        // optional on some API levels
      }
    }).catch((e: Error) => {
      hilog.warn(DOMAIN, TAG, 'drop install failed: %{public}s', `${e}`);
      completeOhosFilePick(formname, '');
    }).finally(() => {
      OhosUiBridge.picking = false;
    });
  }

  private static async extractZipToDir(zipPath: string, destDir: string): Promise<void> {
    try {
      fs.rmdirSync(destDir);
    } catch {
      // ignore
    }
    fs.mkdirSync(destDir, true);
    await new Promise<void>((resolve, reject) => {
      zlib.decompressFile(zipPath, destDir, (err: BusinessError) => {
        if (err) {
          reject(err);
        } else {
          resolve();
        }
      });
    });
  }

  private static async pickZipToCache(context: common.UIAbilityContext, cacheDir: string): Promise<string> {
    const documentPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['.zip'];

    const uris = await documentPicker.select(options);
    if (!uris || uris.length === 0) {
      throw new Error('no file selected');
    }

    return OhosUiBridge.uriZipToExtractDir(uris[0], cacheDir);
  }
}
