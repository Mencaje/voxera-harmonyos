import { LegalConsentPanel } from '../components/LegalConsentPanel';
import { LEGAL_LAYOUT_PHONE } from '../util/DeviceFormFactor';

/** Phone-only legal consent page. */
@Entry
@Component
struct LegalConsentPhone {
  build() {
    Column() {
      LegalConsentPanel({ layout: LEGAL_LAYOUT_PHONE })
    }
    .width('100%')
    .height('100%')
  }
}
