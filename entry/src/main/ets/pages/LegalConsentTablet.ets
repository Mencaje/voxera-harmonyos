import { LegalConsentPanel } from '../components/LegalConsentPanel';
import { LEGAL_LAYOUT_TABLET } from '../util/DeviceFormFactor';

/** Tablet-only legal consent page. */
@Entry
@Component
struct LegalConsentTablet {
  build() {
    Column() {
      LegalConsentPanel({ layout: LEGAL_LAYOUT_TABLET })
    }
    .width('100%')
    .height('100%')
  }
}
