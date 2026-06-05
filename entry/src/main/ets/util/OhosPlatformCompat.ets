import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'OhosPlatform';

/**
 * Runtime split: Huawei commercial HarmonyOS vs OpenHarmony PC forks (e.g. Kaihong).
 * Kaihong x86 often mislabels or mishandles READ_WRITE_DOCUMENTS_DIRECTORY — use sandbox only.
 */
export class OhosPlatformCompat {
  private static logged: boolean = false;

  static logRuntimeOnce(): void {
    if (OhosPlatformCompat.logged) {
      return;
    }
    OhosPlatformCompat.logged = true;
    try {
      hilog.info(DOMAIN, TAG,
        'runtime deviceType=%{public}s brand=%{public}s manufacture=%{public}s osFullName=%{public}s productModel=%{public}s',
        deviceInfo.deviceType, deviceInfo.brand, deviceInfo.manufacture, deviceInfo.osFullName,
        deviceInfo.productModel);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'logRuntimeOnce failed: %{public}s', `${e}`);
    }
  }

  /** True on Huawei phones/tablets/2in1 where Documents/Voxera path is known-good. */
  static isHuaweiCommercialHarmony(): boolean {
    try {
      const manufacture = (deviceInfo.manufacture ?? '').toUpperCase();
      const brand = (deviceInfo.brand ?? '').toUpperCase();
      return manufacture.includes('HUAWEI') || brand.includes('HUAWEI') || brand.includes('HONOR');
    } catch {
      return false;
    }
  }

  /** OpenHarmony desktop forks (Kaihong ISO x86, etc.) — not Huawei AppGallery stack. */
  static isOpenHarmonyPcFork(): boolean {
    try {
      if (OhosPlatformCompat.isHuaweiCommercialHarmony()) {
        return false;
      }
      const os = (deviceInfo.osFullName ?? '').toLowerCase();
      const brand = (deviceInfo.brand ?? '').toLowerCase();
      const manufacture = (deviceInfo.manufacture ?? '').toLowerCase();
      const openFork = os.includes('openharmony') || os.includes('kaihong') || os.includes('开鸿') ||
        brand.includes('kaihong') || brand.includes('开鸿') || manufacture.includes('kaihong') ||
        manufacture.includes('深开鸿');
      if (openFork) {
        return true;
      }
      /* API 14 OH PC ISO may report tablet/default instead of 2in1. */
      const t = deviceInfo.deviceType;
      return t === '2in1' || t === 'tablet' || t === 'default';
    } catch {
      return false;
    }
  }

  /**
   * Whether to call READ_WRITE_DOCUMENTS_DIRECTORY + Documents/Voxera mirror.
   * OpenHarmony PC: sandbox only (avoids mislabeled permission UI + unstable APIs).
   */
  static supportsPublicDocuments(): boolean {
    OhosPlatformCompat.logRuntimeOnce();
    if (OhosPlatformCompat.isOpenHarmonyPcFork()) {
      hilog.info(DOMAIN, TAG, 'OpenHarmony PC fork — public Documents disabled, sandbox user_data only');
      return false;
    }
    return true;
  }
}
