/** Phone native UI — Content tab (installed packages). */

export const PHONE_CONTENT_FORM = 'phone_native_content';

export const CONTENT_INSTALLED_LABEL = '已安装包：';
export const CONTENT_BROWSE_ONLINE = '浏览在线内容';
export const CONTENT_BROWSE_ONLINE_UPDATES = '浏览在线内容';
export const CONTENT_UNINSTALL_BUTTON = '卸载';
export const CONTENT_UPDATE_BUTTON = '更新';
export const CONTENT_USE_TXP_BUTTON = '使用材质包';
export const CONTENT_DISABLE_TXP_BUTTON = '禁用材质包';
export const CONTENT_NO_DESCRIPTION = '暂无包描述';
export const CONTENT_NO_DEPS = '无依赖项。';
export const CONTENT_HARD_DEPS_LABEL = '依赖项：';
export const CONTENT_SOFT_DEPS_LABEL = '可选依赖项：';
export const CONTENT_DELETE_CONFIRM_TITLE = '卸载内容';
export const CONTENT_DELETE_CONFIRM_MESSAGE = '确定要卸载此内容吗？';
export const CONTENT_DELETE_CONFIRM_OK = '卸载';
export const CONTENT_DELETE_CONFIRM_CANCEL = '取消';
export const CONTENT_ERROR_DELETE_FAILED = '卸载失败';
export const CONTENT_ERROR_CANNOT_UNINSTALL = '无法卸载此内容';

export function browseOnlineLabel(updateCount: number): string {
  if (updateCount > 0) {
    return `${CONTENT_BROWSE_ONLINE} [${updateCount}]`;
  }
  return CONTENT_BROWSE_ONLINE;
}
