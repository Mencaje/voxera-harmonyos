-- HarmonyOS phone: native ArkUI local-game tab bridge (game bar, worlds, create world).
-- SPDX-License-Identifier: LGPL-2.1-or-later

local PHONE_PATH = "phone_native_local"
local STATE_FILE = "phone_local_state.json"

-- Native UI has no sp_worlds textlist; track selection here for highlight + play.
local phone_selected_world_index = nil

local valid_disabled_settings = {
	["enable_damage"] = true,
	["creative_mode"] = true,
	["enable_server"] = true,
}

local flag_checkboxes = {
	v5 = { "caverns" },
	v7 = { "caverns", "ridges", "mountains", "floatlands" },
	carpathian = { "caverns", "rivers" },
	valleys = { "altitude_chill", "altitude_dry", "humid_rivers", "vary_river_depth" },
	flat = { "caverns", "hills", "lakes" },
	fractal = { "terrain" },
	v6 = { "trees", "flat", "mudflow", "temples" },
}

local mgv6_biomes = {
	{ jungles = true, snowbiomes = true },
	{ jungles = true, snowbiomes = false },
	{ jungles = false, snowbiomes = false },
}

local function table_to_flags(ftable)
	local str = {}
	for flag, is_set in pairs(ftable) do
		str[#str + 1] = is_set and flag or ("no" .. flag)
	end
	return table.concat(str, ",")
end

local function get_disabled_settings(game)
	if not game then
		return {}
	end
	local gameconfig = Settings(game.path .. "/game.conf")
	local disabled_settings = {}
	if gameconfig then
		local disabled_settings_str = (gameconfig:get("disabled_settings") or ""):split()
		for _, value in pairs(disabled_settings_str) do
			local state = false
			value = value:trim()
			if string.sub(value, 1, 1) == "!" then
				state = true
				value = string.sub(value, 2)
			end
			if valid_disabled_settings[value] then
				disabled_settings[value] = state
			end
		end
	end
	return disabled_settings
end

-- tab_local.lua defines current_game/apply_game as locals; mirror them here for phone bridge.
local function phone_current_game()
	local gameid = core.settings:get("menu_last_game")
	local game = gameid and pkgmgr.find_by_gameid(gameid)
	if not game and #pkgmgr.games > 0 then
		local picked_game = 1
		if pkgmgr.games[1].id == "devtest" and #pkgmgr.games > 1 then
			picked_game = 2
		end
		game = pkgmgr.games[picked_game]
		core.settings:set("menu_last_game", game.id)
	end
	return game
end

local function phone_apply_game(game)
	core.settings:set("menu_last_game", game.id)
	menudata.worldlist:set_filtercriteria(game.id)
	menudata.worldlist:refresh()
	mm_game_theme.set_game(game)
	local index = phone_selected_world_index
	if not index or index < 1 then
		index = filterlist.get_current_index(menudata.worldlist,
			tonumber(core.settings:get("mainmenu_last_selected_world")))
	end
	if not index or index < 1 then
		local list = menudata.worldlist:get_list() or {}
		if #list > 0 then
			index = #list
		end
	end
	if index and index >= 1 then
		phone_selected_world_index = index
		menu_worldmt_legacy(index)
	end
end

local function resolve_world_index()
	if phone_selected_world_index and phone_selected_world_index >= 1 then
		local list = menudata.worldlist:get_list() or {}
		if phone_selected_world_index <= #list then
			return phone_selected_world_index
		end
	end
	phone_selected_world_index = nil
	local index = filterlist.get_current_index(menudata.worldlist,
		tonumber(core.settings:get("mainmenu_last_selected_world")))
	if (not index or index < 1) and menudata.worldlist:size() > 0 then
		index = menudata.worldlist:size()
	end
	if index and index >= 1 then
		phone_selected_world_index = index
	end
	return index or 0
end

-- Native ArkUI replaces maintab on phone; hide Lua tabview so it does not show through.
local function ensure_maintab_hidden()
	local maintab = ui.find_by_name("maintab")
	if maintab and not maintab.hidden then
		maintab:hide()
	end
end

local function flag_values_from_settings()
	return {
		main = core.settings:get_flags("mg_flags"),
		v5 = core.settings:get_flags("mgv5_spflags"),
		v6 = core.settings:get_flags("mgv6_spflags"),
		v7 = core.settings:get_flags("mgv7_spflags"),
		fractal = core.settings:get_flags("mgfractal_spflags"),
		carpathian = core.settings:get_flags("mgcarpathian_spflags"),
		valleys = core.settings:get_flags("mgvalleys_spflags"),
		flat = core.settings:get_flags("mgflat_spflags"),
	}
end

local function build_flag_list(mapgen, flags, disallowed)
	local result = {}
	if mapgen == "singlenode" then
		return result
	end
	if not disallowed["mg_flags"] then
		result.main = {
			{ id = "caves", value = flags.main.caves == true },
			{ id = "dungeons", value = flags.main.dungeons == true },
			{ id = "decorations", value = flags.main.decorations == true },
		}
	end
	local sp_key = "mg" .. mapgen .. "_spflags"
	if disallowed[sp_key] then
		return result
	end
	local names = flag_checkboxes[mapgen]
	if names then
		local list = {}
		for _, name in ipairs(names) do
			list[#list + 1] = { id = name, value = flags[mapgen][name] == true }
		end
		result[mapgen] = list
	end
	if mapgen == "v6" then
		local biometype = 1
		if flags.v6.snowbiomes == true then
			biometype = 1
		elseif flags.v6.jungles == true then
			biometype = 2
		else
			biometype = 3
		end
		result.v6_biomes = biometype
		result.v6_biomeblend = flags.v6.biomeblend == true
	end
	return result
end

local function build_create_schema()
	local game = pkgmgr.find_by_gameid(core.settings:get("menu_last_game"))
	if not game and #pkgmgr.games > 0 then
		game = pkgmgr.games[1]
	end
	if not game then
		return { error = "no_game" }
	end

	local mapgens = core.get_mapgen_names()
	local current_mg = core.settings:get("mg_name")
	local disallowed_mapgen_settings = {}
	local gameconfig = Settings(game.path .. "/game.conf")
	if gameconfig then
		current_mg = current_mg or gameconfig:get("default_mapgen") or "v7"
		local allowed_mapgens = (gameconfig:get("allowed_mapgens") or ""):split()
		for key, value in pairs(allowed_mapgens) do
			allowed_mapgens[key] = value:trim()
		end
		local disallowed_mapgens = (gameconfig:get("disallowed_mapgens") or ""):split()
		for key, value in pairs(disallowed_mapgens) do
			disallowed_mapgens[key] = value:trim()
		end
		if #allowed_mapgens > 0 then
			for i = #mapgens, 1, -1 do
				if table.indexof(allowed_mapgens, mapgens[i]) == -1 then
					table.remove(mapgens, i)
				end
			end
			-- Subgames may allow mapgen names not yet in core.get_mapgen_names().
			for _, name in ipairs(allowed_mapgens) do
				if name ~= "" and table.indexof(mapgens, name) == -1 then
					mapgens[#mapgens + 1] = name
				end
			end
		end
		if #disallowed_mapgens > 0 then
			for i = #mapgens, 1, -1 do
				if table.indexof(disallowed_mapgens, mapgens[i]) > 0 then
					table.remove(mapgens, i)
				end
			end
		end
		local ds = (gameconfig:get("disallowed_mapgen_settings") or ""):split()
		for _, value in pairs(ds) do
			disallowed_mapgen_settings[value:trim()] = true
		end
	end

	if #mapgens == 0 then
		local default_mg = gameconfig and gameconfig:get("default_mapgen")
		if default_mg and default_mg ~= "" then
			mapgens = { default_mg }
			current_mg = default_mg
		else
			mapgens = { "v7" }
		end
	end
	if not current_mg or table.indexof(mapgens, current_mg) == -1 then
		current_mg = mapgens[1]
	end

	local flags = flag_values_from_settings()
	return {
		gameId = game.id,
		mapgens = mapgens,
		selectedMapgen = current_mg,
		seed = core.settings:get("fixed_map_seed") or "",
		worldname = "",
		seedAllowed = not disallowed_mapgen_settings["seed"],
		flags = build_flag_list(current_mg, flags, disallowed_mapgen_settings),
	}
end

local function build_state()
	if #pkgmgr.games == 0 then
		return { hasGames = false, games = {}, worlds = {} }
	end

	local game = phone_current_game()
	if game then
		phone_apply_game(game)
	end

	local selected_game_id = core.settings:get("menu_last_game") or ""
	local games = {}
	for _, g in ipairs(pkgmgr.games) do
		games[#games + 1] = {
			id = g.id,
			title = g.title or g.id,
			iconPath = (g.menuicon_path and g.menuicon_path ~= "") and g.menuicon_path or "",
			selected = (g.id == selected_game_id),
		}
	end

	menudata.worldlist:set_filtercriteria(selected_game_id)
	menudata.worldlist:refresh()

	local index = resolve_world_index()

	local worlds = {}
	local list = menudata.worldlist:get_list() or {}
	for i, w in ipairs(list) do
		worlds[#worlds + 1] = {
			name = w.name,
			gameid = w.gameid,
			selected = (i == index),
		}
	end

	local world = list[math.min(math.max(index, 1), #list)]
	local game_for_world = world and pkgmgr.find_by_gameid(world.gameid) or game
	local disabled = get_disabled_settings(game_for_world)

	local left = {}
	if world then
		if disabled["creative_mode"] == nil then
			left.creativeMode = {
				visible = true,
				value = core.settings:get_bool("creative_mode"),
			}
		end
		if disabled["enable_damage"] == nil then
			left.enableDamage = {
				visible = true,
				value = core.settings:get_bool("enable_damage"),
			}
		end
		if disabled["enable_server"] == nil then
			left.enableServer = {
				visible = true,
				value = core.settings:get_bool("enable_server"),
			}
		end
	end

	if core.settings:get_bool("enable_server") and disabled["enable_server"] == nil and world then
		left.server = {
			announce = core.settings:get_bool("server_announce"),
			playerName = core.settings:get("name") or "",
			port = core.settings:get("port") or "30000",
			bindAddress = core.settings:get("bind_address") or "",
		}
	end

	return {
		hasGames = true,
		games = games,
		worlds = worlds,
		selectedWorldIndex = index,
		hasWorlds = #worlds > 0,
		leftPanel = left,
		createSchema = build_create_schema(),
	}
end

local function write_state(payload)
	local state = build_state()
	if type(payload) == "table" then
		for k, v in pairs(payload) do
			state[k] = v
		end
	end
	local path = core.get_cache_path() .. DIR_DELIM .. STATE_FILE
	local json = core.write_json(state)
	if json then
		-- Luanti write_json encodes empty Lua tables as null; ArkUI expects arrays.
		json = json:gsub('"worlds":null', '"worlds":[]')
		json = json:gsub('"games":null', '"games":[]')
		json = json:gsub('"mods":null', '"mods":[]')
		core.safe_file_write(path, json)
	end
	if core.ohos_set_status then
		core.ohos_set_status("phone_local:state")
	end
end

local function handle_refresh()
	local ok, err = pcall(function()
		if pkgmgr.load_all then
			pkgmgr.load_all()
		end
		ensure_maintab_hidden()
		write_state()
	end)
	if not ok and core.ohos_set_status then
		core.ohos_set_status("phone_local:err:" .. tostring(err))
	end
end

local function handle_select_game(game_id)
	phone_selected_world_index = nil
	local game = pkgmgr.find_by_gameid(game_id)
	if game then
		phone_apply_game(game)
	end
	handle_refresh()
end

local function handle_select_world(index)
	index = tonumber(index) or 1
	phone_selected_world_index = index
	menu_worldmt_legacy(index)
	core.settings:set("mainmenu_last_selected_world", menudata.worldlist:get_raw_index(index))
	handle_refresh()
end

local function bool_to_mt_string(bool_val)
	return bool_val and "true" or "false"
end

local function resolve_setting_world_index(world_index)
	local selected = tonumber(world_index) or phone_selected_world_index or resolve_world_index()
	if not selected or selected < 1 then
		selected = 1
	end
	return selected
end

local function handle_set_setting(key, value, world_index)
	if key == "creative_mode" or key == "enable_damage" or key == "enable_server" or
			key == "server_announce" then
		local bool_val = (value == true or value == "true")
		local selected = resolve_setting_world_index(world_index)
		phone_selected_world_index = selected
		menu_worldmt_legacy(selected)
		core.settings:set_bool(key, bool_val)
		local world = menudata.worldlist:get_list()[selected]
		if world and key == "server_announce" then
			menu_worldmt(selected, key, bool_to_mt_string(bool_val))
		elseif world and key ~= "enable_server" then
			menu_worldmt(selected, key, bool_to_mt_string(bool_val))
		end
	end
	if key == "player_name" then
		core.settings:set("name", tostring(value))
	elseif key == "port" then
		core.settings:set("port", tostring(value))
	elseif key == "bind_address" then
		core.settings:set("bind_address", tostring(value))
	end
	handle_refresh()
end

local function handle_create_world(data)
	local worldname = data.worldname or ""
	local game = pkgmgr.find_by_gameid(data.gameId or core.settings:get("menu_last_game"))
	local message
	if not game then
		message = "No game selected"
	else
		if worldname == "" then
			local worldnum_max = 0
			for _, world in ipairs(menudata.worldlist:get_list()) do
				if world.name:match("^world%d+$") then
					local worldnum = tonumber(world.name:sub(6))
					worldnum_max = math.max(worldnum_max, worldnum)
				end
			end
			worldname = "world" .. (worldnum_max + 1)
		end
		if menudata.worldlist:uid_exists_raw(worldname) then
			message = 'exists'
		else
			local flags = data.flags or {}
			local mapgen = data.mapgen or "v7"
			-- Honour subgame mapgen restrictions (same as dlg_create_world.lua).
			local gameconfig = Settings(game.path .. "/game.conf")
			if gameconfig then
				local allowed = (gameconfig:get("allowed_mapgens") or ""):split()
				for key, value in pairs(allowed) do
					allowed[key] = value:trim()
				end
				if #allowed > 0 and table.indexof(allowed, mapgen) == -1 then
					mapgen = allowed[1]
				end
				local default_mg = gameconfig:get("default_mapgen")
				if default_mg and default_mg ~= "" and #allowed == 0 then
					mapgen = default_mg
				end
			end
			if mapgen == "v6" and type(flags.v6) == "table" then
				local biometype = 1
				if flags.v6.snowbiomes == true then
					biometype = 1
				elseif flags.v6.jungles == true then
					biometype = 2
				else
					biometype = 3
				end
				if mgv6_biomes[biometype] then
					flags.v6.jungles = mgv6_biomes[biometype].jungles
					flags.v6.snowbiomes = mgv6_biomes[biometype].snowbiomes
				end
			end
			local settings = {
				fixed_map_seed = data.seed or "",
				mg_name = mapgen,
				mg_flags = table_to_flags(flags.main or core.settings:get_flags("mg_flags")),
				mgv5_spflags = table_to_flags(flags.v5 or core.settings:get_flags("mgv5_spflags")),
				mgv6_spflags = table_to_flags(flags.v6 or core.settings:get_flags("mgv6_spflags")),
				mgv7_spflags = table_to_flags(flags.v7 or core.settings:get_flags("mgv7_spflags")),
				mgfractal_spflags = table_to_flags(flags.fractal or core.settings:get_flags("mgfractal_spflags")),
				mgcarpathian_spflags = table_to_flags(flags.carpathian or core.settings:get_flags("mgcarpathian_spflags")),
				mgvalleys_spflags = table_to_flags(flags.valleys or core.settings:get_flags("mgvalleys_spflags")),
				mgflat_spflags = table_to_flags(flags.flat or core.settings:get_flags("mgflat_spflags")),
			}
			core.log("action", "[phone_native_local] create world name=" .. worldname ..
				" game=" .. game.id .. " mapgen=" .. mapgen)
			message = core.create_world(worldname, game.id, settings)
			if message == nil then
				core.settings:set("menu_last_game", game.id)
				menudata.worldlist:set_filtercriteria(game.id)
				menudata.worldlist:refresh()
				core.settings:set("mainmenu_last_selected_world",
					menudata.worldlist:raw_index_by_uid(worldname))
				phone_selected_world_index = nil
				for i, w in ipairs(menudata.worldlist:get_list() or {}) do
					if w.name == worldname then
						phone_selected_world_index = i
						break
					end
				end
			end
		end
	end
	if message == nil then
		write_state({ createSuccess = true, createResult = nil })
	else
		core.log("warning", "[phone_native_local] create world failed: " .. tostring(message))
		write_state({ createResult = message, createSuccess = nil })
	end
end

local function handle_delete_world(name)
	local list = menudata.worldlist:get_list()
	for i, w in ipairs(list) do
		if w.name == name then
			local raw_index = menudata.worldlist:get_raw_index(i)
			core.delete_world(raw_index)
			menudata.worldlist:refresh()
			break
		end
	end
	handle_refresh()
end

local function handle_play(data)
	local selected = resolve_setting_world_index(data and data.worldIndex)
	phone_selected_world_index = selected
	menu_worldmt_legacy(selected)
	if selected == nil or selected < 1 then
		write_state({ playError = "no_world" })
		return
	end
	gamedata.selected_world = menudata.worldlist:get_raw_index(selected)
	if gamedata.selected_world == 0 then
		write_state({ playError = "no_world" })
		return
	end

	local world = menudata.worldlist:get_raw_element(gamedata.selected_world)
	local game_obj
	if world then
		game_obj = pkgmgr.find_by_gameid(world.gameid)
		if game_obj then
			core.settings:set("menu_last_game", game_obj.id)
		end
	end

	local disabled_settings = get_disabled_settings(game_obj)
	for k, _ in pairs(valid_disabled_settings) do
		local v = disabled_settings[k]
		if v ~= nil then
			core.settings:set_bool(k, disabled_settings[k])
		end
	end

	if core.settings:get_bool("enable_server") then
		gamedata.playername = (data and data.playerName) or core.settings:get("name") or ""
		gamedata.password = (data and data.password) or ""
		gamedata.port = (data and data.port) or core.settings:get("port") or "30000"
		gamedata.address = ""
		core.settings:set("port", gamedata.port)
		if data and data.bindAddress then
			core.settings:set("bind_address", data.bindAddress)
		end
	else
		gamedata.singleplayer = true
	end

	core.log("action", "[phone_native_local] play world index=" .. tostring(selected) ..
		" creative_mode=" .. tostring(core.settings:get_bool("creative_mode")) ..
		" enable_damage=" .. tostring(core.settings:get_bool("enable_damage")))

	if core.ohos_set_status then
		core.ohos_set_status("phone_local:playing")
	end
	core.start()
end

-- In-memory mod configuration session (mirrors dlg_config_world.lua dialog state).
local phone_mod_session = nil

local function modname_valid(name)
	return not name:find("[^a-z0-9_]")
end

local function check_mod_configuration(world_path, all_mods)
	local enabled_mod_paths = {}
	local all_mods_by_vpath = {}
	for _, mod in ipairs(all_mods) do
		if mod.type == "mod" then
			all_mods_by_vpath[mod.virtual_path] = mod
		end
		if mod.enabled then
			enabled_mod_paths[mod.virtual_path] = mod.path
		end
	end

	local config_status = core.check_mod_configuration(world_path, enabled_mod_paths)
	local enabled_mods_by_name = {}
	for _, mod in ipairs(config_status.satisfied_mods) do
		assert(mod.virtual_path ~= "")
		enabled_mods_by_name[mod.name] = all_mods_by_vpath[mod.virtual_path] or mod
	end
	for _, mod in ipairs(config_status.unsatisfied_mods) do
		assert(mod.virtual_path ~= "")
		enabled_mods_by_name[mod.name] = all_mods_by_vpath[mod.virtual_path] or mod
	end

	local with_error = {}
	for _, mod in ipairs(config_status.unsatisfied_mods) do
		local error = { type = "warning" }
		with_error[mod.virtual_path] = error
		for _, depname in ipairs(mod.unsatisfied_depends) do
			if not enabled_mods_by_name[depname] then
				error.type = "error"
				break
			end
		end
	end

	return with_error, enabled_mods_by_name
end

local function mod_display_title(mod, use_technical_names)
	if use_technical_names then
		return mod.list_name or mod.name
	end
	return mod.list_title or mod.list_name or mod.title or mod.name
end

local function build_mod_dep_entry(dep_name, enabled_mods_by_name, with_error, mod_enabled)
	if not mod_enabled then
		return { name = dep_name, state = "neutral" }
	end
	local dep = enabled_mods_by_name[dep_name]
	if not dep then
		return { name = dep_name, state = "missing" }
	end
	if with_error[dep.virtual_path] then
		local t = with_error[dep.virtual_path].type
		return { name = dep_name, state = t == "error" and "error" or "warn" }
	end
	return { name = dep_name, state = "ok" }
end

local function build_mod_detail(mod, all_mods, with_error, enabled_mods_by_name, worldspec)
	if mod.is_modpack or mod.type == "game" then
		local info = core.get_content_info(mod.path).description or ""
		if info == "" then
			if mod.is_modpack then
				info = fgettext("No modpack description provided.")
			else
				info = fgettext("No game description provided.")
			end
		end
		local detail = {
			kind = mod.is_modpack and "modpack" or "game",
			title = mod_display_title(mod, false),
			description = info,
		}
		if mod.is_modpack then
			detail.modpackEntirelyEnabled = pkgmgr.is_modpack_entirely_enabled(
				phone_mod_session.list:get_raw_list(), mod)
		end
		return detail
	end

	if mod.type == "worldmods" then
		return {
			kind = "worldmods",
			title = mod.name,
			description = fgettext("Mods located inside the world folder."),
		}
	end

	local hard_deps, soft_deps = pkgmgr.get_dependencies(mod.path)
	local hard_out = {}
	local soft_out = {}
	if mod.enabled or mod.always_on then
		for _, dep_name in ipairs(hard_deps) do
			hard_out[#hard_out + 1] = build_mod_dep_entry(
				dep_name, enabled_mods_by_name, with_error, true)
		end
		for _, dep_name in ipairs(soft_deps) do
			soft_out[#soft_out + 1] = build_mod_dep_entry(
				dep_name, enabled_mods_by_name, with_error, true)
		end
	else
		for _, dep_name in ipairs(hard_deps) do
			hard_out[#hard_out + 1] = { name = dep_name, state = "neutral" }
		end
		for _, dep_name in ipairs(soft_deps) do
			soft_out[#soft_out + 1] = { name = dep_name, state = "neutral" }
		end
	end

	return {
		kind = "mod",
		title = mod.name,
		enabled = mod.enabled == true,
		alwaysOn = mod.always_on == true,
		canToggle = not mod.always_on,
		hardDeps = hard_out,
		softDeps = soft_out,
	}
end

local function build_mod_schema()
	if not phone_mod_session or not phone_mod_session.list then
		return { error = "no_session" }
	end

	local data = phone_mod_session
	local all_mods = data.list:get_list()
	local with_error, enabled_mods_by_name = check_mod_configuration(data.worldspec.path, all_mods)
	local use_technical_names = core.settings:get_bool("show_technical_names")
	local selected = data.selected_mod
	if selected < 1 then
		selected = 1
	end
	if selected > #all_mods then
		selected = math.max(#all_mods, 1)
		data.selected_mod = selected
	end

	local mods = {}
	for i, mod in ipairs(all_mods) do
		local row_type = "mod"
		if mod.type == "game" or mod.type == "worldmods" then
			row_type = "header"
		elseif mod.is_modpack then
			row_type = "modpack"
		end
		local icon_info = with_error[mod.virtual_path or mod.path]
		mods[#mods + 1] = {
			index = i,
			name = mod.name,
			title = mod_display_title(mod, use_technical_names),
			rowType = row_type,
			enabled = mod.enabled == true or mod.always_on == true,
			alwaysOn = mod.always_on == true,
			indent = (mod.modpack_depth or 0) +
				((mod.loc == "game" or mod.loc == "worldmods") and 1 or 0),
			errorType = icon_info and icon_info.type or nil,
			canToggle = mod.type == "mod" and not mod.always_on,
		}
	end

	local selected_mod = all_mods[selected] or { name = "" }
	return {
		worldName = data.worldspec.name,
		selectedIndex = selected,
		showDisableAll = phone_mod_session.enabled_all,
		mods = mods,
		detail = build_mod_detail(selected_mod, all_mods, with_error, enabled_mods_by_name, data.worldspec),
	}
end

local function init_mod_session(world_raw_index)
	local worldspec = core.get_worlds()[world_raw_index]
	if not worldspec then
		return false
	end
	local worldconfig = pkgmgr.get_worldconfig(worldspec.path)
	if not worldconfig or not worldconfig.id or worldconfig.id == "" then
		return false
	end

	local list = filterlist.create(
		pkgmgr.preparemodlist,
		pkgmgr.comparemod,
		function(element, uid)
			if element.name == uid then
				return true
			end
		end,
		nil,
		{
			worldpath = worldspec.path,
			gameid = worldspec.gameid,
		}
	)

	phone_mod_session = {
		list = list,
		selected_mod = tonumber(core.settings:get("world_config_selected_mod")) or 0,
		worldspec = worldspec,
		enabled_all = false,
	}
	if phone_mod_session.selected_mod > list:size() then
		phone_mod_session.selected_mod = 0
	end
	return true
end

local function mod_dialog_stub()
	return { data = phone_mod_session }
end

local function handle_mod_schema()
	local selected = phone_selected_world_index or resolve_world_index()
	if not selected or selected < 1 then
		write_state({ modSchema = { error = "no_world" } })
		return
	end
	if not init_mod_session(menudata.worldlist:get_raw_index(selected)) then
		write_state({ modSchema = { error = "no_world" } })
		return
	end
	write_state({ modSchema = build_mod_schema() })
end

local function handle_mod_select(index)
	if not phone_mod_session then
		handle_mod_schema()
		return
	end
	index = tonumber(index) or 1
	phone_mod_session.selected_mod = index
	core.settings:set("world_config_selected_mod", index)
	write_state({ modSchema = build_mod_schema() })
end

local function handle_mod_toggle(index, enabled)
	if not phone_mod_session then
		return
	end
	index = tonumber(index) or phone_mod_session.selected_mod
	if index < 1 then
		index = 1
	end
	phone_mod_session.selected_mod = index
	local dlg = mod_dialog_stub()
	if enabled == nil then
		pkgmgr.enable_mod(dlg)
	else
		local bool_val = (enabled == true or enabled == "true")
		pkgmgr.enable_mod(dlg, bool_val)
	end
	write_state({ modSchema = build_mod_schema() })
end

local function handle_mod_enable_all()
	if not phone_mod_session then
		return
	end
	local list = phone_mod_session.list:get_raw_list()
	local was_enabled = {}
	for _, mod in ipairs(list) do
		if not mod.always_on and not mod.is_modpack and mod.enabled then
			was_enabled[mod.name] = true
		end
	end
	for _, mod in ipairs(list) do
		if not mod.always_on and not mod.is_modpack and not was_enabled[mod.name] then
			mod.enabled = true
		end
	end
	phone_mod_session.enabled_all = true
	write_state({ modSchema = build_mod_schema() })
end

local function handle_mod_disable_all()
	if not phone_mod_session then
		return
	end
	local list = phone_mod_session.list:get_raw_list()
	for _, mod in ipairs(list) do
		if not mod.always_on and not mod.is_modpack then
			mod.enabled = false
		end
	end
	phone_mod_session.enabled_all = false
	write_state({ modSchema = build_mod_schema() })
end

local function handle_mod_save()
	if not phone_mod_session then
		write_state({ modSaveSuccess = true })
		return
	end
	local filename = phone_mod_session.worldspec.path .. DIR_DELIM .. "world.mt"
	local worldfile = Settings(filename)
	local mods = worldfile:to_table()
	local rawlist = phone_mod_session.list:get_raw_list()
	local was_set = {}
	local err_msg

	for i = 1, #rawlist do
		local mod = rawlist[i]
		if not mod.is_modpack and not mod.always_on then
			if modname_valid(mod.name) then
				if mod.enabled then
					worldfile:set("load_mod_" .. mod.name, mod.virtual_path)
					was_set[mod.name] = true
				elseif not was_set[mod.name] then
					worldfile:remove("load_mod_" .. mod.name)
				end
			elseif mod.enabled then
				err_msg = fgettext_ne("Failed to enable mod \"$1\" as it contains disallowed characters. " ..
					"Only characters [a-z0-9_] are allowed.", mod.name)
			end
			mods["load_mod_" .. mod.name] = nil
		end
	end

	for key in pairs(mods) do
		if key:sub(1, 9) == "load_mod_" then
			worldfile:remove(key)
		end
	end

	if not err_msg and not worldfile:write() then
		core.log("error", "Failed to write world config file")
		err_msg = fgettext("Failed to write world config file")
	end

	phone_mod_session = nil
	if err_msg then
		write_state({ modSaveError = err_msg })
	else
		handle_refresh()
		write_state({ modSaveSuccess = true })
	end
end

local function handle_mod_cancel()
	phone_mod_session = nil
	write_state({ modClosed = true })
end

local function handle_configure_world()
	handle_mod_schema()
end

local function handle_mapgen_schema(mapgen, flags_in)
	local flags = flag_values_from_settings()
	if type(flags_in) == "table" then
		for group, tbl in pairs(flags_in) do
			if type(tbl) == "table" and flags[group] then
				for k, v in pairs(tbl) do
					flags[group][k] = v
				end
			end
		end
	end
	local game = pkgmgr.find_by_gameid(core.settings:get("menu_last_game"))
	local disallowed = {}
	if game then
		local gameconfig = Settings(game.path .. "/game.conf")
		if gameconfig then
			local ds = (gameconfig:get("disallowed_mapgen_settings") or ""):split()
			for _, value in pairs(ds) do
				disallowed[value:trim()] = true
			end
		end
	end
	local schema = build_create_schema()
	schema.selectedMapgen = mapgen or schema.selectedMapgen
	schema.flags = build_flag_list(schema.selectedMapgen, flags, disallowed)
	write_state({ createSchema = schema, hasGames = true })
end

local function dispatch_action(json_str)
	local ok, action = pcall(core.parse_json, json_str)
	if not ok or type(action) ~= "table" or not action.op then
		if core.ohos_set_status then
			core.ohos_set_status("phone_local:err:bad_action")
		end
		return
	end

	if type(action.flagsJson) == "string" and action.flagsJson ~= "" then
		local flags_ok, flags = pcall(core.parse_json, action.flagsJson)
		if flags_ok and type(flags) == "table" then
			action.flags = flags
		end
	end

	if action.op == "refresh" then
		handle_refresh()
		core.after(0.15, handle_refresh)
	elseif action.op == "select_game" then
		handle_select_game(action.id)
	elseif action.op == "select_world" then
		handle_select_world(action.index)
	elseif action.op == "set_setting" then
		handle_set_setting(action.key, action.value, action.index)
	elseif action.op == "create_world" then
		write_state({ createResult = nil, createSuccess = nil })
		handle_create_world(action)
	elseif action.op == "delete_world" then
		handle_delete_world(action.name)
	elseif action.op == "play" then
		handle_play(action)
	elseif action.op == "configure_world" or action.op == "mod_schema" then
		handle_configure_world()
	elseif action.op == "mod_select" then
		handle_mod_select(action.index)
	elseif action.op == "mod_toggle" then
		handle_mod_toggle(action.index, action.enabled)
	elseif action.op == "mod_enable_all" then
		handle_mod_enable_all()
	elseif action.op == "mod_disable_all" then
		handle_mod_disable_all()
	elseif action.op == "mod_save" then
		handle_mod_save()
	elseif action.op == "mod_cancel" then
		handle_mod_cancel()
	elseif action.op == "mapgen_schema" then
		handle_mapgen_schema(action.mapgen, action.flags)
	elseif action.op == "create_schema" then
		write_state({ createSchema = build_create_schema(), hasGames = #pkgmgr.games > 0 })
	else
		if core.ohos_set_status then
			core.ohos_set_status("phone_local:err:unknown_op")
		end
	end
end

if PLATFORM == "HarmonyOS" and DEVICE_FORM_FACTOR == "phone" then
	local orig_button_handler = core.button_handler

	core.button_handler = function(fields)
		if fields[PHONE_PATH .. "_accepted"] then
			local payload = fields[PHONE_PATH .. "_accepted"]
			if payload and payload ~= "" then
				dispatch_action(payload)
			end
			return
		end
		if fields[PHONE_PATH .. "_canceled"] then
			return
		end
		orig_button_handler(fields)
	end

	-- After subgame install from native picker, refresh local UI state.
	local orig_install = phone_native_install_from_path
	if orig_install then
		phone_native_install_from_path = function(path)
			orig_install(path)
			if #pkgmgr.games > 0 then
				core.after(0.05, function()
					handle_refresh()
				end)
				core.after(0.15, function()
					handle_refresh()
				end)
			end
		end
	end

	local function phone_return_to_native_home()
		ensure_maintab_hidden()
		handle_refresh()
	end

	core.after(0, phone_return_to_native_home)
	core.after(0.05, phone_return_to_native_home)
	-- After disconnect/crash the mainmenu loop re-enters; refresh native state again.
	core.after(0.2, phone_return_to_native_home)
end
