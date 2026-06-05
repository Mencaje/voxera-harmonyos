// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2025 grorp

#include "s_pause_menu.h"
#include "cpp_api/s_internal.h"
#include "common/c_converter.h"

void ScriptApiPauseMenu::open_settings()
{
	SCRIPTAPI_PRECHECKHEADER

	int error_handler = PUSH_ERROR_HANDLER(L);

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "open_settings");

	PCALL_RES(lua_pcall(L, 0, 0, error_handler));

	lua_pop(L, 2); // Pop core, error handler
}

void ScriptApiPauseMenu::handlePauseMenuButtons(const StringMap &fields)
{
	SCRIPTAPI_PRECHECKHEADER

	int error_handler = PUSH_ERROR_HANDLER(L);

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "button_handler");
	lua_remove(L, -2);
	if (lua_isnil(L, -1)) {
		warningstream << "Pause menu button_handler is nil (pick ignored)" << std::endl;
		lua_pop(L, 2);
		return;
	}
	luaL_checktype(L, -1, LUA_TFUNCTION);

	lua_newtable(L);
	for (const auto &it : fields) {
		lua_pushstring(L, it.first.c_str());
		lua_pushlstring(L, it.second.c_str(), it.second.size());
		lua_settable(L, -3);
	}

	PCALL_RES(lua_pcall(L, 1, 0, error_handler));
	lua_pop(L, 1);
}
