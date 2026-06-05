import { HealthyGamingPanel } from '../components/HealthyGamingPanel';
import { HEALTHY_LAYOUT_PC } from '../util/DeviceFormFactor';

/** PC / 2in1 only — tablet and phone use their own pages. */
@Entry
@Component
struct HealthyGamingDeclaration {
  build() {
    Column() {
      HealthyGamingPanel({ layout: HEALTHY_LAYOUT_PC })
    }
    .width('100%')
    .height('100%')
  }
}
