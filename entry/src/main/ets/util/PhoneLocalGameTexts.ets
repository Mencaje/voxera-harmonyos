/** Phone native UI — local game tab (game bar, worlds, create world). */

export const PHONE_LOCAL_FORM = 'phone_native_local';

export const SELECT_WORLD_LABEL = '选择世界：';
export const NEW_WORLD_BUTTON = '新建';
export const DELETE_WORLD_BUTTON = '删除';
export const SELECT_MODS_BUTTON = '选择Mod';
export const SELECT_MODS_TITLE = '选择Mod';
export const MOD_WORLD_LABEL = '世界：';
export const MOD_ENABLED_LABEL = '已启用';
export const MOD_SAVE_BUTTON = '保存';
export const MOD_FIND_MORE_BUTTON = '查找更多Mod';
export const MOD_ENABLE_ALL_BUTTON = '全部启用';
export const MOD_DISABLE_ALL_BUTTON = '全部禁用';
export const MOD_ENABLE_MODPACK_BUTTON = '启用Mod包';
export const MOD_DISABLE_MODPACK_BUTTON = '禁用Mod包';
export const MOD_HARD_DEPS_LABEL = '依赖：';
export const MOD_SOFT_DEPS_LABEL = '可选依赖：';
export const MOD_NO_DEPS_LABEL = '无（可选）依赖';
export const MOD_NO_HARD_DEPS_LABEL = '无硬性依赖';
export const MOD_NO_SOFT_DEPS_LABEL = '无可选依赖';
export const MOD_ERROR_NO_WORLD = '请先选择世界';
export const START_GAME_BUTTON = '开始游戏';
export const HOST_GAME_BUTTON = '建立服务器';

export const CREATIVE_MODE_LABEL = '创造模式';
export const ENABLE_DAMAGE_LABEL = '开启伤害';
export const HOST_SERVER_LABEL = '建立服务器';
export const VIEW_SERVER_DETAILS_LABEL = '查看服务器详情';
export const ANNOUNCE_SERVER_LABEL = '公布服务器';

export const WORLD_NAME_LABEL = '世界名称';
export const SEED_LABEL = '种子';
export const MAPGEN_LABEL = '地图生成器';
export const CREATE_BUTTON = '创建';
export const CANCEL_BUTTON = '取消';
export const MAPGEN_FLAGS_LABEL = '地图生成标志';
export const MAPGEN_SPECIFIC_LABEL = '地图专用标志';
export const BIOMES_LABEL = '生物群系';
export const BIOME_BLEND_LABEL = '生物群系混合';

export const CAVES_LABEL = '洞穴';
export const DUNGEONS_LABEL = '地牢';
export const DECORATIONS_LABEL = '装饰';
export const CAVERNS_LABEL = '大洞穴';
export const RIVERS_LABEL = '河流';
export const MOUNTAINS_LABEL = '山脉';
export const FLOATLANDS_LABEL = '浮空岛（实验性）';
export const HILLS_LABEL = '丘陵';
export const LAKES_LABEL = '湖泊';
export const TERRAIN_LABEL = '附加地形';
export const TREES_LABEL = '树木与丛林草';
export const FLAT_LABEL = '平坦地形';
export const MUDFLOW_LABEL = '泥流';
export const TEMPLES_LABEL = '沙漠神庙';

export const DELETE_CONFIRM_TITLE = '删除世界';
export const DELETE_CONFIRM_MESSAGE = '确定要删除此世界吗？';
export const DELETE_CONFIRM_OK = '删除';
export const DELETE_CONFIRM_CANCEL = '取消';

export const CREATE_ERROR_EXISTS = '此名称与其他世界名称重复';
export const CREATE_ERROR_NO_GAME = '未选择子游戏';
export const CREATE_ERROR_EMPTY_NAME = '请输入世界名称';
export const CREATE_EMPTY_NAME_DIALOG_TITLE = '提示';
export const CREATE_EMPTY_NAME_DIALOG_OK = '确定';

export const PLAYER_NAME_LABEL = '名称';
export const PORT_LABEL = '端口';
export const BIND_ADDRESS_LABEL = '绑定地址';
export const PASSWORD_LABEL = '密码';

/** Mapgen flag id → display label (mirrors dlg_create_world.lua). */
export function getFlagLabel(id: string): string {
  switch (id) {
    case 'caves':
      return CAVES_LABEL;
    case 'dungeons':
      return DUNGEONS_LABEL;
    case 'decorations':
      return DECORATIONS_LABEL;
    case 'caverns':
      return CAVERNS_LABEL;
    case 'ridges':
    case 'rivers':
      return RIVERS_LABEL;
    case 'mountains':
      return MOUNTAINS_LABEL;
    case 'floatlands':
      return FLOATLANDS_LABEL;
    case 'hills':
      return HILLS_LABEL;
    case 'lakes':
      return LAKES_LABEL;
    case 'terrain':
      return TERRAIN_LABEL;
    case 'trees':
      return TREES_LABEL;
    case 'flat':
      return FLAT_LABEL;
    case 'mudflow':
      return MUDFLOW_LABEL;
    case 'temples':
      return TEMPLES_LABEL;
    case 'altitude_chill':
      return '海拔降温';
    case 'altitude_dry':
      return '海拔干燥';
    case 'humid_rivers':
      return '河流增湿';
    case 'vary_river_depth':
      return '河流深浅变化';
    default:
      return id;
  }
}

export const V6_BIOME_OPTIONS: string[] = [
  '温带、沙漠、丛林、苔原、针叶林',
  '温带、沙漠、丛林',
  '温带、沙漠',
];
