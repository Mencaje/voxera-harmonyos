-- Luanti
-- Copyright (C) 2023 rubenwardy
-- SPDX-License-Identifier: LGPL-2.1-or-later

local path = core.get_mainmenu_path() .. DIR_DELIM .. "content"

dofile(path .. DIR_DELIM .. "pkgmgr.lua")
pkgmgr.trigger_reload_games()
dofile(path .. DIR_DELIM .. "local_install.lua")
dofile(path .. DIR_DELIM .. "contentdb.lua")
dofile(path .. DIR_DELIM .. "update_detector.lua")
dofile(path .. DIR_DELIM .. "screenshots.lua")
dofile(path .. DIR_DELIM .. "dlg_install.lua")
dofile(path .. DIR_DELIM .. "dlg_overwrite.lua")
dofile(path .. DIR_DELIM .. "dlg_package.lua")
dofile(path .. DIR_DELIM .. "dlg_contentdb.lua")
dofile(path .. DIR_DELIM .. "dlg_local_game.lua")
if PLATFORM == "HarmonyOS" and DEVICE_FORM_FACTOR == "phone" then
	dofile(path .. DIR_DELIM .. "phone_native_install.lua")
	dofile(path .. DIR_DELIM .. "phone_native_local.lua")
	dofile(path .. DIR_DELIM .. "phone_native_content.lua")
	dofile(path .. DIR_DELIM .. "phone_native_settings.lua")
end
