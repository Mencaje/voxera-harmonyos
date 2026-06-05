import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'PhoneLocalServerStore';
const PREF_NAME = 'voxera_phone_local_server';

export interface PhoneLocalServerPrefs {
  playerName: string;
  password: string;
  port: string;
  bindAddress: string;
  announce: boolean;
}

const DEFAULT_PREFS: PhoneLocalServerPrefs = {
  playerName: '',
  password: '',
  port: '30000',
  bindAddress: '',
  announce: false,
};

function defaultPrefs(): PhoneLocalServerPrefs {
  return {
    playerName: DEFAULT_PREFS.playerName,
    password: DEFAULT_PREFS.password,
    port: DEFAULT_PREFS.port,
    bindAddress: DEFAULT_PREFS.bindAddress,
    announce: DEFAULT_PREFS.announce,
  };
}

export class PhoneLocalServerStore {
  static async load(context: common.Context): Promise<PhoneLocalServerPrefs> {
    try {
      const pref = await preferences.getPreferences(context, PREF_NAME);
      return {
        playerName: await pref.get('playerName', DEFAULT_PREFS.playerName) as string,
        password: await pref.get('password', DEFAULT_PREFS.password) as string,
        port: await pref.get('port', DEFAULT_PREFS.port) as string,
        bindAddress: await pref.get('bindAddress', DEFAULT_PREFS.bindAddress) as string,
        announce: await pref.get('announce', DEFAULT_PREFS.announce) as boolean,
      };
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'load failed: %{public}s', `${e}`);
      return defaultPrefs();
    }
  }

  static async save(context: common.Context, prefs: PhoneLocalServerPrefs): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREF_NAME);
      await pref.put('playerName', prefs.playerName);
      await pref.put('password', prefs.password);
      await pref.put('port', prefs.port);
      await pref.put('bindAddress', prefs.bindAddress);
      await pref.put('announce', prefs.announce);
      await pref.flush();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'save failed: %{public}s', `${e}`);
    }
  }
}
