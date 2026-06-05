// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2025 grorp

#include "scripting_pause_menu.h"
#include "client/client.h"
#include "cpp_api/s_internal.h"
#include "filesys.h"
#include "lua_api/l_client_common.h"
#include "lua_api/l_mainmenu.h"
#include "lua_api/l_menu_common.h"
#include "lua_api/l_pause_menu.h"
#include "lua_api/l_settings.h"
#include "lua_api/l_util.h"
#include "porting.h"

PauseMenuScripting::PauseMenuScripting(Client *client):
		ScriptApiBase(ScriptingType::PauseMenu)
{
	setGameDef(client);

	SCRIPTAPI_PRECHECKHEADER

	initializeSecurity();

	lua_getglobal(L, "core");
	int top = lua_gettop(L);

	// Initialize our lua_api modules
	initializeModApi(L, top);
	lua_pop(L, 1);

	// Push builtin initialization type
	lua_pushstring(L, "pause_menu");
	lua_setglobal(L, "INIT");

	infostream << "SCRIPTAPI: Initialized pause menu modules" << std::endl;
}

void PauseMenuScripting::initializeModApi(lua_State *L, int top)
{
	// Register reference classes (userdata)
	LuaSettings::Register(L);

	// Initialize mod API modules
	ModApiPauseMenu::Initialize(L, top);
	ModApiMenuCommon::Initialize(L, top);
	ModApiClientCommon::Initialize(L, top);
	ModApiUtil::Initialize(L, top);
#if defined(__OHOS__)
	// Phone pause menu Content tab uses pkgmgr / phone_native_content bridges.
	ModApiMainMenu::InitializeContentPackages(L, top);
#endif
}

void PauseMenuScripting::loadBuiltin()
{
	loadScript(Client::getBuiltinLuaPath() + DIR_DELIM "init.lua");
	checkSetByBuiltin();
}

void PauseMenuScripting::step()
{
	SCRIPTAPI_PRECHECKHEADER

	int error_handler = PUSH_ERROR_HANDLER(L);

	lua_getglobal(L, "core");
	lua_getfield(L, -1, "run_mainmenu_after_step");
	lua_remove(L, -2);
	if (lua_isfunction(L, -1)) {
		lua_pushnumber(L, 0);
		PCALL_RES(lua_pcall(L, 1, 0, error_handler));
	} else {
		lua_pop(L, 1);
	}

	lua_pop(L, 1); // Pop error handler
}

static bool pause_menu_may_modify_path(const std::string &path)
{
	std::string path_temp = fs::AbsolutePathPartial(fs::TempPath());
	if (fs::PathStartsWith(path, path_temp))
		return true;

	std::string path_user = fs::AbsolutePathPartial(porting::path_user);
	if (fs::PathStartsWith(path, path_user))
		return true;

	if (fs::PathStartsWith(path, fs::AbsolutePathPartial(porting::path_cache)))
		return true;

	return false;
}

bool PauseMenuScripting::checkPathInternal(const std::string &abs_path, bool write_required,
		bool *write_allowed)
{
	// Same cache/user/temp write policy as main menu — phone native settings/content
	// bridges persist JSON state under path_cache via core.safe_file_write.
	if (pause_menu_may_modify_path(abs_path)) {
		if (write_allowed)
			*write_allowed = true;
		return true;
	}

	if (write_required)
		return false;

	// Read-only: same as main menu — allow listing share/user content paths.
	return true;
}
