import { promptAction } from '@kit.ArkUI';
import {
  BIOME_BLEND_LABEL,
  BIOMES_LABEL,
  CANCEL_BUTTON,
  CREATE_BUTTON,
  CREATE_ERROR_EMPTY_NAME,
  CREATE_ERROR_EXISTS,
  CREATE_ERROR_NO_GAME,
  getFlagLabel,
  MAPGEN_FLAGS_LABEL,
  MAPGEN_LABEL,
  MAPGEN_SPECIFIC_LABEL,
  SEED_LABEL,
  V6_BIOME_OPTIONS,
  WORLD_NAME_LABEL,
} from '../util/PhoneLocalGameTexts';
import {
  PhoneLocalCreateSchema,
  PhoneLocalFlagItem,
  PhoneLocalGameHelper,
} from '../util/PhoneLocalGameHelper';

const PANEL_PAD_VP: number = 20;
const FIELD_H_VP: number = 40;
const BTN_H_VP: number = 40;
const FOOTER_PAD_VP: number = 12;
/** Dark frosted scrim — semi-transparent so backgroundBlurStyle shows through. */
const SCRIM_BLUR_TINT: string = 'rgba(0, 0, 0, 0.62)';

interface PhoneV6Flags {
  jungles: boolean;
  snowbiomes: boolean;
  biomeblend: boolean;
}

interface PhoneFlagsPayload {
  main?: Record<string, boolean>;
  v5?: Record<string, boolean>;
  v7?: Record<string, boolean>;
  v6?: PhoneV6Flags;
  flat?: Record<string, boolean>;
  fractal?: Record<string, boolean>;
  carpathian?: Record<string, boolean>;
  valleys?: Record<string, boolean>;
}

@Component
export struct PhoneCreateWorldPanel {
  @Prop visible: boolean = false;
  @Prop schema: PhoneLocalCreateSchema = {};
  @Prop createError: string = '';
  onClose: () => void = () => {
  };
  @State worldName: string = '';
  @State seed: string = '';
  @State mapgenIndex: number = 0;
  @State flagValues: Record<string, Record<string, boolean>> = {};
  @State v6BiomeIndex: number = 0;
  @State v6BiomeBlend: boolean = true;
  @State errorText: string = '';

  aboutToAppear(): void {
    this.applySchema(this.schema);
  }

  aboutToUpdate(): void {
    this.applySchema(this.schema, true);
    if (this.createError.length > 0) {
      this.errorText = mapCreateError(this.createError);
    }
  }

  private applySchema(schema: PhoneLocalCreateSchema, preserveInputs: boolean = false): void {
    if (!preserveInputs) {
      this.worldName = schema.worldname ?? '';
      this.seed = schema.seed ?? '';
    }
    const mapgens = schema.mapgens ?? ['v7'];
    const sel = schema.selectedMapgen ?? mapgens[0];
    let idx = mapgens.indexOf(sel);
    if (idx < 0) {
      idx = 0;
    }
    this.mapgenIndex = idx;
    this.loadFlagsFromSchema(schema);
    this.errorText = '';
  }

  private loadFlagsFromSchema(schema: PhoneLocalCreateSchema): void {
    const flags = schema.flags ?? {};
    const out: Record<string, Record<string, boolean>> = {};
    const groups = ['main', 'v5', 'v7', 'v6', 'flat', 'fractal', 'carpathian', 'valleys'];
    for (let gi = 0; gi < groups.length; gi++) {
      const g = groups[gi];
      const list = flags[g];
      if (Array.isArray(list)) {
        const map: Record<string, boolean> = {};
        const items = list as PhoneLocalFlagItem[];
        for (let ii = 0; ii < items.length; ii++) {
          map[items[ii].id] = items[ii].value;
        }
        out[g] = map;
      }
    }
    this.flagValues = out;
    if (typeof flags.v6_biomes === 'number') {
      this.v6BiomeIndex = flags.v6_biomes - 1;
    }
    if (typeof flags.v6_biomeblend === 'boolean') {
      this.v6BiomeBlend = flags.v6_biomeblend;
    }
  }

  private currentMapgen(): string {
    const mapgens = this.schema.mapgens ?? ['v7'];
    return mapgens[this.mapgenIndex] ?? mapgens[0];
  }

  private schemaMainFlags(): PhoneLocalFlagItem[] {
    const flags = this.schema.flags ?? {};
    const main = flags.main;
    if (Array.isArray(main)) {
      return main as PhoneLocalFlagItem[];
    }
    return [];
  }

  private schemaMapgenFlags(): PhoneLocalFlagItem[] {
    const mg = this.currentMapgen();
    const flags = this.schema.flags ?? {};
    const list = flags[mg];
    if (Array.isArray(list)) {
      return list as PhoneLocalFlagItem[];
    }
    return [];
  }

  private mapgenSelectOptions(): SelectOption[] {
    const names = this.schema.mapgens ?? ['v7'];
    const out: SelectOption[] = [];
    for (let i = 0; i < names.length; i++) {
      out.push({ value: names[i] });
    }
    return out;
  }

  private v6BiomeSelectOptions(): SelectOption[] {
    const out: SelectOption[] = [];
    for (let i = 0; i < V6_BIOME_OPTIONS.length; i++) {
      out.push({ value: V6_BIOME_OPTIONS[i] });
    }
    return out;
  }

  private onMapgenChange(index: number): void {
    this.mapgenIndex = index;
    PhoneLocalGameHelper.requestMapgenSchema(this.currentMapgen(), this.buildFlagsPayloadJson());
  }

  private buildFlagsPayloadJson(): string {
    const payload: PhoneFlagsPayload = {};
    const keys = Object.keys(this.flagValues);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k === 'main') {
        payload.main = this.flagValues[k];
      } else if (k === 'v5') {
        payload.v5 = this.flagValues[k];
      } else if (k === 'v7') {
        payload.v7 = this.flagValues[k];
      } else if (k === 'v6') {
        // merged below when mapgen is v6
      } else if (k === 'flat') {
        payload.flat = this.flagValues[k];
      } else if (k === 'fractal') {
        payload.fractal = this.flagValues[k];
      } else if (k === 'carpathian') {
        payload.carpathian = this.flagValues[k];
      } else if (k === 'valleys') {
        payload.valleys = this.flagValues[k];
      }
    }
    if (this.currentMapgen() === 'v6') {
      let jungles = false;
      let snowbiomes = false;
      if (this.v6BiomeIndex === 0) {
        jungles = true;
        snowbiomes = true;
      } else if (this.v6BiomeIndex === 1) {
        jungles = true;
        snowbiomes = false;
      }
      const v6map: PhoneV6Flags = {
        jungles: jungles,
        snowbiomes: snowbiomes,
        biomeblend: this.v6BiomeBlend,
      };
      if (this.flagValues.v6) {
        const merged: PhoneV6Flags = {
          jungles: jungles,
          snowbiomes: snowbiomes,
          biomeblend: this.v6BiomeBlend,
        };
        payload.v6 = merged;
      } else {
        payload.v6 = v6map;
      }
    }
    return JSON.stringify(payload);
  }

  private onCreate(): void {
    const name = this.worldName.trim();
    if (name.length === 0) {
      promptAction.showToast({
        message: CREATE_ERROR_EMPTY_NAME,
        duration: 2000,
      });
      return;
    }
    this.errorText = '';
    PhoneLocalGameHelper.createWorld(
      name,
      this.seed,
      this.currentMapgen(),
      this.schema.gameId ?? '',
      this.buildFlagsPayloadJson(),
    );
  }

  @Builder
  private flagGroup(title: string, groupKey: string, items: PhoneLocalFlagItem[]): void {
    if (items.length > 0) {
      Column({ space: 6 }) {
        Text(title)
          .fontSize(13)
          .fontColor('#CCCCCC')
        ForEach(items, (item: PhoneLocalFlagItem) => {
          Row({ space: 8 }) {
            Checkbox({ name: item.id, group: groupKey })
              .select(this.flagValues[groupKey]?.[item.id] ?? item.value)
              .onChange((checked: boolean) => {
                const group = this.flagValues[groupKey] ?? {};
                group[item.id] = checked;
                this.flagValues[groupKey] = group;
              })
            Text(getFlagLabel(item.id))
              .fontSize(14)
              .fontColor('#FFFFFF')
          }
          .width('100%')
        }, (item: PhoneLocalFlagItem) => `${groupKey}_${item.id}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  private v6BiomePanel(): void {
    Column({ space: 6 }) {
      Text(BIOMES_LABEL)
        .fontSize(13)
        .fontColor('#CCCCCC')
      Select(this.v6BiomeSelectOptions())
        .selected(this.v6BiomeIndex)
        .value(V6_BIOME_OPTIONS[this.v6BiomeIndex])
        .font({ size: 14 })
        .fontColor('#FFFFFF')
        .backgroundColor('#333333')
        .width('100%')
        .onSelect((index: number) => {
          this.v6BiomeIndex = index;
        })
      Row({ space: 8 }) {
        Checkbox({ name: 'biomeblend', group: 'v6extra' })
          .select(this.v6BiomeBlend)
          .onChange((checked: boolean) => {
            this.v6BiomeBlend = checked;
          })
        Text(BIOME_BLEND_LABEL)
          .fontSize(14)
          .fontColor('#FFFFFF')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private blurBackdrop(): void {
    Column()
      .width('100%')
      .height('100%')
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
        colorMode: ThemeColorMode.DARK,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0,
      })
      .backgroundColor(SCRIM_BLUR_TINT)
  }

  @Builder
  private flagsTwoColumnPanel(): void {
    Scroll() {
      Row({ space: 20 }) {
        Column({ space: 8 }) {
          this.flagGroup(MAPGEN_FLAGS_LABEL, 'main', this.schemaMainFlags())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, top: 4 })

        Column({ space: 8 }) {
          this.flagGroup(MAPGEN_SPECIFIC_LABEL, this.currentMapgen(), this.schemaMapgenFlags())
          if (this.currentMapgen() === 'v6') {
            this.v6BiomePanel()
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 4, right: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 4, right: 4, top: 4, bottom: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    if (!this.visible) {
      Blank()
    } else {
      Stack() {
        this.blurBackdrop()

        Column() {
          Row() {
            Column({ space: 10 }) {
              Text(WORLD_NAME_LABEL)
                .fontSize(14)
                .fontColor('#FFFFFF')
              TextInput({ text: this.worldName, placeholder: '' })
                .height(FIELD_H_VP)
                .fontSize(15)
                .fontColor('#FFFFFF')
                .backgroundColor('#2E7D32')
                .onChange((v: string) => {
                  this.worldName = v;
                })

              if (this.schema.seedAllowed !== false) {
                Text(SEED_LABEL)
                  .fontSize(14)
                  .fontColor('#FFFFFF')
                TextInput({ text: this.seed, placeholder: '' })
                  .height(FIELD_H_VP)
                  .fontSize(15)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#555555')
                  .onChange((v: string) => {
                    this.seed = v;
                  })
              }

              Text(MAPGEN_LABEL)
                .fontSize(14)
                .fontColor('#FFFFFF')
              Select(this.mapgenSelectOptions())
                .selected(this.mapgenIndex)
                .value(this.currentMapgen())
                .font({ size: 15 })
                .fontColor('#FFFFFF')
                .backgroundColor('#333333')
                .width('100%')
                .onSelect((index: number) => {
                  this.onMapgenChange(index);
                })

              if (this.errorText.length > 0) {
                Text(this.errorText)
                  .fontSize(13)
                  .fontColor('#FF8888')
              }
            }
            .width('38%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: PANEL_PAD_VP, top: PANEL_PAD_VP, bottom: PANEL_PAD_VP })

            Column() {
              this.flagsTwoColumnPanel()
            }
            .layoutWeight(1)
            .height('100%')
            .padding({ top: PANEL_PAD_VP, right: PANEL_PAD_VP, bottom: PANEL_PAD_VP })
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)

          Row({ space: 16 }) {
            Button(CREATE_BUTTON)
              .height(BTN_H_VP)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#444444')
              .padding({ left: 28, right: 28 })
              .onClick(() => this.onCreate())
            Button(CANCEL_BUTTON)
              .height(BTN_H_VP)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#444444')
              .padding({ left: 28, right: 28 })
              .onClick(() => this.onClose())
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: FOOTER_PAD_VP, bottom: FOOTER_PAD_VP + 4 })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
  }
}

export function mapCreateError(result: string | null | undefined): string {
  if (result === null || result === undefined || result.length === 0) {
    return '';
  }
  if (result === 'exists') {
    return CREATE_ERROR_EXISTS;
  }
  if (result === 'No game selected') {
    return CREATE_ERROR_NO_GAME;
  }
  if (result === 'Game ID not found') {
    return '子游戏未找到，请重新安装';
  }
  if (result.startsWith('Failed to initialize world:')) {
    return '创建世界失败：' + result.substring('Failed to initialize world:'.length).trim();
  }
  return result;
}
