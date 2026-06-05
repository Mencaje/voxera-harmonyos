import { HealthyGamingPanel } from '../components/HealthyGamingPanel';
import { HEALTHY_LAYOUT_PHONE } from '../util/DeviceFormFactor';

/** Phone-only healthy gaming declaration. */
@Entry
@Component
struct HealthyGamingDeclarationPhone {
  build() {
    Column() {
      HealthyGamingPanel({ layout: HEALTHY_LAYOUT_PHONE })
    }
    .width('100%')
    .height('100%')
  }
}
