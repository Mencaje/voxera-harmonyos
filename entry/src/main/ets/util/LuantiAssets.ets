import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

interface BootstrapManifest {
  shaders?: string[];
  builtin?: string[];
  textures?: string[];
}

const DOMAIN = 0x0000;
const TAG = 'LuantiAssets';
/** Bump when builtin/locale in HAP change — triggers full reinstall on device. */
const ASSETS_GENERATION = 52;
const MARKER = `luanti_assets_installed_v${ASSETS_GENERATION}`;
const ZIP_RAW = 'luanti_assets.zip';
const MANIFEST_RAW = 'bootstrap_manifest.json';
const FONT_PROBE = 'fonts/Arimo-Regular.ttf';
const SHADER_PROBE = 'client/shaders/cloud_shader/opengl_vertex.glsl';
const BUILTIN_PROBE = 'builtin/init.lua';
const MAINMENU_PROBE = 'builtin/mainmenu/init.lua';
const TEXTURE_PROBE = 'textures/base/pack/blank.png';
const LOCALE_PROBE = 'locale/zh_CN/LC_MESSAGES/luanti.po';
const CRITICAL_SHADERS: string[] = [
  SHADER_PROBE,
  'client/shaders/cloud_shader/opengl_fragment.glsl',
];
const BOOTSTRAP_FONTS: string[] = [
  'Arimo-Regular.ttf',
  'Arimo-Bold.ttf',
  'Arimo-Italic.ttf',
  'Arimo-BoldItalic.ttf',
  'Cousine-Regular.ttf',
  'Cousine-Bold.ttf',
  'Cousine-Italic.ttf',
  'Cousine-BoldItalic.ttf',
  'DroidSansFallbackFull.ttf',
];
/** Copied from rawfile when zip omits UI textures on device. */
/** Always refreshed from HAP rawfile (menu Lua hotfix without full wipe). */
const FORCE_RAW_BUILTIN: string[] = [
  'builtin/mainmenu/after.lua',
  'builtin/mainmenu/init.lua',
  'builtin/mainmenu/tab_local.lua',
  'builtin/mainmenu/dlg_create_world.lua',
  'builtin/mainmenu/content/init.lua',
  'builtin/mainmenu/tab_content.lua',
  'builtin/mainmenu/content/dlg_contentdb.lua',
  'builtin/mainmenu/content/dlg_local_game.lua',
  'builtin/mainmenu/content/phone_native_install.lua',
  'builtin/mainmenu/content/phone_native_local.lua',
  'builtin/mainmenu/content/phone_native_content.lua',
  'builtin/mainmenu/content/phone_native_settings.lua',
  'builtin/pause_menu/after.lua',
  'builtin/pause_menu/init.lua',
  'builtin/common/settings/dlg_settings.lua',
  'builtin/mainmenu/content/local_install.lua',
  'builtin/mainmenu/content/pkgmgr.lua',
  'builtin/mainmenu/game_theme.lua',
  'builtin/mainmenu/tab_about.lua',
  'builtin/mainmenu/tab_online.lua',
  'builtin/mainmenu/dlg_config_world.lua',
];

/** Always overwrite from HAP rawfile (branding / menu header updates). */
const FORCE_RAW_TEXTURES: string[] = [
  'textures/base/pack/voxera_menu_header.png',
  'textures/base/pack/voxera_about_source.png',
  'textures/base/pack/no_screenshot.png',
  'textures/base/pack/menu_overlay.png',
];

const CRITICAL_TEXTURES: string[] = [
  TEXTURE_PROBE,
  'textures/base/pack/checkbox_16.png',
  'textures/base/pack/checkbox_32.png',
  'textures/base/pack/checkbox_64.png',
  'textures/base/pack/voxera_menu_header.png',
  'textures/base/pack/logo.png',
  'textures/base/pack/voxera_about_source.png',
  'textures/base/pack/voxera_brand.png',
];

export class LuantiAssets {
  static shareDir(context: common.UIAbilityContext): string {
    return `${context.filesDir}/luanti_share`;
  }

  private static writeBytes(fd: number, data: Uint8Array): void {
    if (data.byteOffset === 0 && data.byteLength === data.buffer.byteLength) {
      fs.writeSync(fd, data.buffer);
    } else {
      fs.writeSync(fd, data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
    }
  }

  private static fileOk(shareDir: string, rel: string, minSize: number): boolean {
    try {
      const st = fs.statSync(`${shareDir}/${rel}`);
      return st.size >= minSize;
    } catch {
      return false;
    }
  }

  static hasCoreAssets(shareDir: string): boolean {
    return LuantiAssets.listMissingCoreAssets(shareDir).length === 0;
  }

  static listMissingCoreAssets(shareDir: string): string[] {
    const missing: string[] = [];
    if (!LuantiAssets.fileOk(shareDir, FONT_PROBE, 10000)) {
      missing.push(FONT_PROBE);
    }
    if (!LuantiAssets.fileOk(shareDir, BUILTIN_PROBE, 32)) {
      missing.push(BUILTIN_PROBE);
    }
    if (!LuantiAssets.fileOk(shareDir, MAINMENU_PROBE, 32)) {
      missing.push(MAINMENU_PROBE);
    }
    if (!LuantiAssets.fileOk(shareDir, SHADER_PROBE, 8)) {
      missing.push(SHADER_PROBE);
    }
    if (!LuantiAssets.fileOk(shareDir, TEXTURE_PROBE, 8)) {
      missing.push(TEXTURE_PROBE);
    }
    if (!LuantiAssets.fileOk(shareDir, LOCALE_PROBE, 4096)) {
      missing.push(LOCALE_PROBE);
    }
    return missing;
  }

  /** Recursive delete (rmdirSync only removes empty dirs on OHOS). */
  private static deleteTree(root: string): void {
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
        LuantiAssets.deleteTree(p);
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

  private static copyTree(src: string, dest: string): void {
    LuantiAssets.mkdirSafe(dest);
    let names: string[] = [];
    try {
      names = fs.listFileSync(src);
    } catch {
      return;
    }
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
        LuantiAssets.copyTree(from, to);
      } else {
        try {
          fs.unlinkSync(to);
        } catch {
          // dest may not exist
        }
        fs.copyFileSync(from, to);
      }
    }
  }

  /** Drop partial installs so zip + bootstrap run again. */
  private static wipeShareIfIncomplete(shareDir: string): void {
    if (LuantiAssets.hasCoreAssets(shareDir) && LuantiAssets.hasValidMarker(shareDir)) {
      return;
    }
    hilog.warn(DOMAIN, TAG, 'Incomplete share at %{public}s — wiping for reinstall', shareDir);
    LuantiAssets.deleteTree(shareDir);
  }

  private static ensureParentDir(filePath: string): void {
    const idx = filePath.lastIndexOf('/');
    if (idx <= 0) {
      return;
    }
    try {
      fs.mkdirSync(filePath.substring(0, idx), true);
    } catch {
      // ignore
    }
  }

  private static decodeRawUtf8(bytes: Uint8Array): string {
    const opts: util.TextDecoderOptions = { fatal: false, ignoreBOM: true };
    const decoder = util.TextDecoder.create('utf-8', opts);
    return decoder.decodeToString(bytes);
  }

  private static rawFileToBytes(raw: Uint8Array | ArrayBuffer): Uint8Array {
    if (raw instanceof Uint8Array) {
      return raw;
    }
    return new Uint8Array(raw);
  }

  private static markerPath(shareDir: string): string {
    return `${shareDir}/${MARKER}`;
  }

  private static hasValidMarker(shareDir: string): boolean {
    try {
      fs.accessSync(LuantiAssets.markerPath(shareDir));
      return true;
    } catch {
      return false;
    }
  }

  private static wipeShareDir(shareDir: string): void {
    LuantiAssets.deleteTree(shareDir);
  }

  private static async copyRawToShare(
    context: common.UIAbilityContext,
    shareDir: string,
    rel: string,
    force: boolean = false
  ): Promise<boolean> {
    const dest = `${shareDir}/${rel}`;
    if (!force) {
      try {
        const st = fs.statSync(dest);
        if (st.size > 8) {
          return true;
        }
      } catch {
        // copy below
      }
    }
    try {
      LuantiAssets.ensureParentDir(dest);
      const buf = await context.resourceManager.getRawFileContent(rel);
      const data = LuantiAssets.rawFileToBytes(buf);
      const out = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      LuantiAssets.writeBytes(out.fd, data);
      fs.closeSync(out);
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'copyRawToShare %{public}s failed: %{public}s', rel, `${e}`);
      return false;
    }
  }

  private static async readManifest(context: common.UIAbilityContext): Promise<BootstrapManifest> {
    try {
      const raw = await context.resourceManager.getRawFileContent(MANIFEST_RAW);
      const text = LuantiAssets.decodeRawUtf8(LuantiAssets.rawFileToBytes(raw));
      return JSON.parse(text) as BootstrapManifest;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'bootstrap_manifest.json: %{public}s', `${e}`);
      return {};
    }
  }

  private static async bootstrapCritical(
    context: common.UIAbilityContext,
    shareDir: string
  ): Promise<void> {
    await LuantiAssets.copyRawToShare(context, shareDir, BUILTIN_PROBE);
    await LuantiAssets.copyRawToShare(context, shareDir, MAINMENU_PROBE);
    for (const rel of CRITICAL_SHADERS) {
      await LuantiAssets.copyRawToShare(context, shareDir, rel);
    }
    for (const rel of CRITICAL_TEXTURES) {
      await LuantiAssets.copyRawToShare(context, shareDir, rel);
    }
    await LuantiAssets.bootstrapFontsFromRaw(context, shareDir);
    await LuantiAssets.copyRawToShare(context, shareDir, LOCALE_PROBE);
    const localeMo = 'locale/zh_CN/LC_MESSAGES/luanti.mo';
    await LuantiAssets.copyRawToShare(context, shareDir, localeMo);
  }

  private static async bootstrapShadersFromRaw(
    context: common.UIAbilityContext,
    shareDir: string,
    manifest: BootstrapManifest
  ): Promise<void> {
    for (const rel of CRITICAL_SHADERS) {
      await LuantiAssets.copyRawToShare(context, shareDir, rel);
    }
    const list = manifest.shaders ?? [];
    for (let i = 0; i < list.length; i++) {
      await LuantiAssets.copyRawToShare(context, shareDir, list[i]);
    }
    hilog.info(DOMAIN, TAG, 'Bootstrap shaders finished (%{public}d manifest entries)', list.length);
  }

  private static async bootstrapBuiltinFromRaw(
    context: common.UIAbilityContext,
    shareDir: string,
    manifest: BootstrapManifest
  ): Promise<void> {
    const list = manifest.builtin ?? [];
    let ok = 0;
    for (let i = 0; i < list.length; i++) {
      if (await LuantiAssets.copyRawToShare(context, shareDir, list[i])) {
        ok++;
      }
    }
    hilog.info(DOMAIN, TAG, 'Bootstrap builtin copied %{public}d/%{public}d files', ok, list.length);
  }

  private static async bootstrapForcedTextures(
    context: common.UIAbilityContext,
    shareDir: string
  ): Promise<void> {
    for (const rel of FORCE_RAW_TEXTURES) {
      await LuantiAssets.copyRawToShare(context, shareDir, rel, true);
    }
  }

  private static async bootstrapTexturesFromRaw(
    context: common.UIAbilityContext,
    shareDir: string,
    manifest: BootstrapManifest
  ): Promise<void> {
    await LuantiAssets.bootstrapForcedTextures(context, shareDir);
    for (const rel of CRITICAL_TEXTURES) {
      await LuantiAssets.copyRawToShare(context, shareDir, rel);
    }
    const list = manifest.textures ?? [];
    let ok = 0;
    for (let i = 0; i < list.length; i++) {
      if (await LuantiAssets.copyRawToShare(context, shareDir, list[i])) {
        ok++;
      }
    }
    hilog.info(DOMAIN, TAG, 'Bootstrap textures copied %{public}d/%{public}d files', ok, list.length);
  }

  private static async bootstrapForcedBuiltin(
    context: common.UIAbilityContext,
    shareDir: string
  ): Promise<void> {
    for (const rel of FORCE_RAW_BUILTIN) {
      await LuantiAssets.copyRawToShare(context, shareDir, rel, true);
    }
  }

  private static async bootstrapFontsFromRaw(
    context: common.UIAbilityContext,
    shareDir: string
  ): Promise<void> {
    const fontDir = `${shareDir}/fonts`;
    try {
      fs.mkdirSync(fontDir, true);
    } catch {
      // ignore
    }
    for (const name of BOOTSTRAP_FONTS) {
      const dest = `${fontDir}/${name}`;
      try {
        const st = fs.statSync(dest);
        if (st.size > 10000) {
          continue;
        }
      } catch {
        // copy below
      }
      try {
        const buf = await context.resourceManager.getRawFileContent(`fonts/${name}`);
        const data = LuantiAssets.rawFileToBytes(buf);
        const out = fs.openSync(dest, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        LuantiAssets.writeBytes(out.fd, data);
        fs.closeSync(out);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'Bootstrap font %{public}s failed: %{public}s', name, `${e}`);
      }
    }
  }

  private static async extractZipToShare(
    context: common.UIAbilityContext,
    shareDir: string
  ): Promise<boolean> {
    const cacheZip = `${context.cacheDir}/${ZIP_RAW}`;
    const staging = `${context.cacheDir}/luanti_share_staging`;
    try {
      const data = await context.resourceManager.getRawFileContent(ZIP_RAW);
      const raw = LuantiAssets.rawFileToBytes(data);
      try {
        fs.unlinkSync(cacheZip);
      } catch {
        // ignore
      }
      const out = fs.openSync(cacheZip, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      LuantiAssets.writeBytes(out.fd, raw);
      fs.closeSync(out);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Cannot read %{public}s from HAP: %{public}s', ZIP_RAW, `${e}`);
      return false;
    }

    LuantiAssets.deleteTree(staging);
    LuantiAssets.deleteTree(shareDir);
    LuantiAssets.mkdirSafe(staging);

    try {
      await new Promise<void>((resolve, reject) => {
        zlib.decompressFile(cacheZip, staging, (err: BusinessError) => {
          if (err) {
            reject(err);
          } else {
            resolve();
          }
        });
      });
      LuantiAssets.deleteTree(shareDir);
      LuantiAssets.mkdirSafe(shareDir);
      LuantiAssets.copyTree(staging, shareDir);
      LuantiAssets.deleteTree(staging);
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'zip decompress failed: %{public}s', `${e}`);
      LuantiAssets.deleteTree(staging);
      return false;
    }
  }

  static verifyInstalled(shareDir: string): void {
    const missing = LuantiAssets.listMissingCoreAssets(shareDir);
    if (missing.length > 0) {
      throw new Error(`verify: missing ${missing.join(', ')} under ${shareDir}`);
    }
    const builtinPath = `${shareDir}/${BUILTIN_PROBE}`;
    const st = fs.statSync(builtinPath);
    hilog.info(DOMAIN, TAG, 'verify OK %{public}s (%{public}d bytes)', builtinPath, st.size);
  }

  static async ensureInstalled(context: common.UIAbilityContext): Promise<string> {
    const shareDir = LuantiAssets.shareDir(context);
    const marker = LuantiAssets.markerPath(shareDir);
    const manifest = await LuantiAssets.readManifest(context);

    LuantiAssets.wipeShareIfIncomplete(shareDir);

    const assetsReady = LuantiAssets.hasCoreAssets(shareDir) && LuantiAssets.hasValidMarker(shareDir);

    if (assetsReady) {
      await LuantiAssets.bootstrapForcedBuiltin(context, shareDir);
      await LuantiAssets.bootstrapForcedTextures(context, shareDir);
      LuantiAssets.verifyInstalled(shareDir);
      hilog.info(DOMAIN, TAG, 'Assets OK at %{public}s (gen %{public}d)', shareDir, ASSETS_GENERATION);
      return shareDir;
    }

    if (LuantiAssets.hasCoreAssets(shareDir)) {
      hilog.warn(DOMAIN, TAG, 'Stale assets (marker %{public}s) — full reinstall', MARKER);
      LuantiAssets.wipeShareDir(shareDir);
    }

    hilog.warn(DOMAIN, TAG, 'Installing Luanti share data (zip + rawfile fallback)…');

    const zipOk = await LuantiAssets.extractZipToShare(context, shareDir);
    if (!zipOk) {
      hilog.warn(DOMAIN, TAG, 'Zip install failed — using rawfile bootstrap only');
    }

    await LuantiAssets.bootstrapCritical(context, shareDir);
    await LuantiAssets.bootstrapShadersFromRaw(context, shareDir, manifest);
    await LuantiAssets.bootstrapBuiltinFromRaw(context, shareDir, manifest);
    await LuantiAssets.bootstrapTexturesFromRaw(context, shareDir, manifest);
    await LuantiAssets.bootstrapForcedBuiltin(context, shareDir);
    await LuantiAssets.bootstrapForcedTextures(context, shareDir);

    LuantiAssets.verifyInstalled(shareDir);

    const flag = fs.openSync(marker, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    fs.writeSync(flag.fd, 'ok');
    fs.closeSync(flag);

    hilog.info(DOMAIN, TAG, 'Extracted assets to %{public}s (zip=%{public}s, gen=%{public}d)',
      shareDir, zipOk ? 'ok' : 'skip', ASSETS_GENERATION);
    return shareDir;
  }
}
