import { HealthyGamingPanel } from '../components/HealthyGamingPanel';
import { HEALTHY_LAYOUT_TABLET } from '../util/DeviceFormFactor';

/** Tablet-only healthy gaming declaration. */
@Entry
@Component
struct HealthyGamingDeclarationTablet {
  build() {
    Column() {
      HealthyGamingPanel({ layout: HEALTHY_LAYOUT_TABLET })
    }
    .width('100%')
    .height('100%')
  }
}
