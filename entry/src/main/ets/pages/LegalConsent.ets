import { LegalConsentPanel } from '../components/LegalConsentPanel';
import { LEGAL_LAYOUT_PC } from '../util/DeviceFormFactor';

/** PC / 2in1 only — tablet and phone use their own pages. */
@Entry
@Component
struct LegalConsent {
  build() {
    Column() {
      LegalConsentPanel({ layout: LEGAL_LAYOUT_PC })
    }
    .width('100%')
    .height('100%')
  }
}
