import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'LegalConsentStore';
const PREF_NAME = 'voxera_legal_consent';
const KEY_ACCEPTED = 'accepted_v1';

export class LegalConsentStore {
  static async isAccepted(context: common.Context): Promise<boolean> {
    try {
      const pref = await preferences.getPreferences(context, PREF_NAME);
      return await pref.get(KEY_ACCEPTED, false) as boolean;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'isAccepted failed: %{public}s', `${e}`);
      return false;
    }
  }

  static async markAccepted(context: common.Context): Promise<void> {
    const pref = await preferences.getPreferences(context, PREF_NAME);
    await pref.put(KEY_ACCEPTED, true);
    await pref.flush();
    hilog.info(DOMAIN, TAG, 'legal consent marked accepted');
  }
}
