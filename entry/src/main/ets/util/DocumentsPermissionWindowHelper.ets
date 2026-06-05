import { common } from '@kit.AbilityKit';

import { hilog } from '@kit.PerformanceAnalysisKit';

import { OhosPlatformCompat } from './OhosPlatformCompat';

import { VoxeraPaths } from './VoxeraPaths';



const DOMAIN = 0x0000;

const TAG = 'DocumentsPermWin';



/**

 * Opens HarmonyOS system permission sheet (PermissionGrantAbility / privacycenter).

 * No custom overlay — same API path as PC/tablet.

 */

export class DocumentsPermissionWindowHelper {

  static async ensureGranted(context: common.UIAbilityContext): Promise<boolean> {

    if (!OhosPlatformCompat.supportsPublicDocuments()) {

      return false;

    }

    if (await VoxeraPaths.checkDocumentsPermission(context)) {

      return true;

    }

    await VoxeraPaths.logDocumentsPermissionDiagnostics(context);

    hilog.info(DOMAIN, TAG, 'Opening system Documents permission sheet (requestPermissionsFromUser)');

    return VoxeraPaths.requestDocumentsPermissionInteractive(context);

  }

}

