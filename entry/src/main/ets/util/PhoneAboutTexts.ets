/** HarmonyOS phone About tab — mirrors luanti/builtin/mainmenu/tab_about.lua (HarmonyOS). */

export const ABOUT_VERSION_LABEL = 'Voxera-HarmonyOS 1.0.0';
export const ABOUT_HOMEPAGE_LABEL = '萌创匠盒';
export const ABOUT_OPEN_USER_DATA = '打开用户数据目录';
export const ABOUT_RENDERER_TITLE = '主动渲染器：';

export const MENCAJE_HOMEPAGE_URL = 'https://mencaje.com/';
export const VOXERA_GITHUB_URL = 'https://github.com/Mencaje/voxera-harmonyos';
export const VOXERA_LEGAL_URL = 'https://voxera.mencaje.com/';

export const ABOUT_DEV_LABEL = '开发者：';
export const ABOUT_DEV_VALUE = '萌创匠盒';
export const ABOUT_SITE_LABEL = '官网：';
export const ABOUT_SITE_DISPLAY = 'mencaje.com';
export const ABOUT_PROJECT_LABEL = '本项目开源地址：';

export const ABOUT_ENGINE_HEADING = '本应用所基于的主要开源项目（引擎）：';
export const ABOUT_ENGINE_NAME_LABEL = '开源名称：';
export const ABOUT_ENGINE_NAME = 'Luanti';
export const ABOUT_ENGINE_DESC =
  '开源体素游戏引擎（本应用在其源码基础上移植至 HarmonyOS）';
export const ABOUT_ENGINE_SITE_LABEL = '开源官网：';
export const ABOUT_ENGINE_SITE_URL = 'https://www.luanti.org/';
export const ABOUT_ENGINE_SOURCE_LABEL = '开源源码：';
export const ABOUT_ENGINE_SOURCE_URL = 'https://github.com/luanti-org/luanti/';
export const ABOUT_ENGINE_LICENSE_LABEL = '开源协议：';
export const ABOUT_ENGINE_LICENSE =
  'GNU 宽通用公共许可证 第 2.1 版或更新版本（SPDX：LGPL-2.1-or-later）';
export const ABOUT_ENGINE_LICENSE_URL = 'https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html';
export const ABOUT_MEDIA_LICENSE_LABEL = '随附素材协议：';
export const ABOUT_MEDIA_LICENSE =
  '默认贴图与音效：知识共享 署名-相同方式共享 3.0（SPDX：CC-BY-SA-3.0）';
export const ABOUT_MEDIA_LICENSE_URL = 'https://creativecommons.org/licenses/by-sa/3.0/';

export const ABOUT_RUNTIME_HEADING = '引擎运行时还使用以下组件：';

export interface AboutRuntimeLib {
  name: string;
  siteLabel: string;
  siteUrl: string;
  licenseLabel: string;
  licenseText: string;
  licenseUrl: string;
}

export const ABOUT_RUNTIME_LIBS: AboutRuntimeLib[] = [
  {
    name: 'SDL2',
    siteLabel: '开源官网：',
    siteUrl: 'https://www.libsdl.org/',
    licenseLabel: '开源协议：',
    licenseText: 'zlib 许可证（SPDX：Zlib）',
    licenseUrl: 'https://www.zlib.net/zlib_license.html',
  },
  {
    name: 'Lua',
    siteLabel: '开源官网：',
    siteUrl: 'https://www.lua.org/',
    licenseLabel: '开源协议：',
    licenseText: 'MIT 许可证（SPDX：MIT）',
    licenseUrl: 'https://www.lua.org/license.html',
  },
];

export const ABOUT_PRIVACY_LABEL = '隐私政策：';
export const ABOUT_TERMS_LABEL = '用户协议：';

/** Relative to luanti_share after assets install. */
export const ABOUT_LOGO_REL = 'textures/base/pack/voxera_about_source.png';
