// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2025 grorp

#include "l_pause_menu.h"
#include "client/keycode.h"
#include "gui/mainmenumanager.h"
#include "lua_api/l_internal.h"
#include "client/client.h"
#if defined(__OHOS__)
#include "porting_ohos.h"
#include "porting.h"
#include "filesys.h"
#endif


int ModApiPauseMenu::l_show_touchscreen_layout(lua_State *L)
{
	g_gamecallback->touchscreenLayout();
	return 0;
}


int ModApiPauseMenu::l_is_internal_server(lua_State *L)
{
	lua_pushboolean(L, getClient(L)->m_internal_server);
	return 1;
}

#if defined(__OHOS__)
int ModApiPauseMenu::l_ohos_set_status(lua_State *L)
{
	const char *msg = luaL_checkstring(L, 1);
	porting::ohosEngineStatusSet(msg);
	return 0;
}

int ModApiPauseMenu::l_get_cache_path(lua_State *L)
{
	lua_pushstring(L, fs::RemoveRelativePathComponents(porting::path_cache).c_str());
	return 1;
}
#endif


void ModApiPauseMenu::Initialize(lua_State *L, int top)
{
	API_FCT(show_touchscreen_layout);
	API_FCT(is_internal_server);
#if defined(__OHOS__)
	API_FCT(ohos_set_status);
	API_FCT(get_cache_path);
#endif
}
