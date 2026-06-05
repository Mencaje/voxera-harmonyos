-- HarmonyOS phone: native ArkUI Content tab bridge (installed packages).
-- Mirrors tab_content.lua; SPDX-License-Identifier: LGPL-2.1-or-later

local PHONE_PATH = "phone_native_content"
local STATE_FILE = "phone_content_state.json"

local phone_content_packages = nil
local phone_content_selected = 1

local function package_display_title(pkg, use_technical_names)
	if use_technical_names then
		return pkg.list_name or pkg.name
	end
	return pkg.list_title or pkg.list_name or pkg.title or pkg.name
end

local function find_screenshot(path)
	local candidates = {
		path .. DIR_DELIM .. "screenshot.png",
		path .. DIR_DELIM .. "screenshot.jpg",
		path .. DIR_DELIM .. "screenshot.jpeg",
	}
	for _, filename in ipairs(candidates) do
		local f = io.open(filename, "r")
		if f then
			f:close()
			return filename
		end
	end
	return ""
end

local function get_update_icons()
	local ret = {}
	for _, content in ipairs(update_detector.get_all()) do
		ret[content.virtual_path or content.path] = true
	end
	return ret
end

local function refresh_packages()
	pkgmgr.load_all()
	local packages_raw = {}
	table.insert_all(packages_raw, pkgmgr.games)
	table.insert_all(packages_raw, pkgmgr.texture_packs)
	table.insert_all(packages_raw, pkgmgr.global_mods:get_list())

	local function get_data()
		return packages_raw
	end

	local function is_equal(element, uid)
		return (element.type == "game" and element.id == uid) or element.name == uid
	end

	phone_content_packages = filterlist.create(get_data, pkgmgr.compare_package, is_equal, nil, {})
	if phone_content_selected > phone_content_packages:size() then
		phone_content_selected = math.max(phone_content_packages:size(), 1)
	end
	if phone_content_selected < 1 then
		phone_content_selected = 1
	end
end

local function build_package_detail(pkg, update_icons)
	if not pkg then
		return { kind = "empty", title = "" }
	end

	local info = core.get_content_info(pkg.path)
	local desc = (pkg.description and pkg.description:trim() ~= "") and pkg.description or
		"暂无包描述"
	local screenshot = find_screenshot(pkg.path)
	local subtitle = ""
	if pkg.type ~= "game" then
		subtitle = pkg.name
	end

	local detail = {
		kind = pkg.type,
		title = pkg.title or pkg.name,
		subtitle = subtitle,
		description = desc,
		screenshotPath = screenshot,
		isModpack = pkg.is_modpack == true,
		canUninstall = core.may_modify_path(pkg.path),
		hasUpdate = update_icons[pkg.virtual_path or pkg.path] == true,
		txpEnabled = pkg.type == "txp" and core.settings:get("texture_path") == pkg.path,
	}

	if pkg.type == "mod" and not pkg.is_modpack then
		detail.hardDeps = info.depends or {}
		detail.softDeps = info.optional_depends or {}
	end

	return detail
end

local function build_content_state()
	if not phone_content_packages then
		refresh_packages()
	end

	local update_icons = get_update_icons()
	local update_count = #update_detector.get_all()
	local use_technical_names = core.settings:get_bool("show_technical_names")
	local list = phone_content_packages:get_list()
	if phone_content_selected < 1 then
		phone_content_selected = 1
	end
	if phone_content_selected > #list and #list > 0 then
		phone_content_selected = #list
	end

	local packages = {}
	for i, pkg in ipairs(list) do
		local row_type = "package"
		if pkg.is_modpack then
			row_type = "modpack"
		end
		packages[#packages + 1] = {
			index = i,
			name = pkg.name,
			title = package_display_title(pkg, use_technical_names),
			type = pkg.type,
			rowType = row_type,
			indent = pkg.modpack_depth or 0,
			hasUpdate = update_icons[pkg.virtual_path or pkg.path] == true,
			enabled = pkg.type == "txp" and core.settings:get("texture_path") == pkg.path,
		}
	end

	local selected_pkg = list[phone_content_selected]
	return {
		updateCount = update_count,
		selectedIndex = phone_content_selected,
		packages = packages,
		detail = build_package_detail(selected_pkg, update_icons),
	}
end

local function write_state(payload)
	local state = build_content_state()
	if type(payload) == "table" then
		for k, v in pairs(payload) do
			state[k] = v
		end
	end
	local path = core.get_cache_path() .. DIR_DELIM .. STATE_FILE
	local json = core.write_json(state)
	if json then
		json = json:gsub('"packages":null', '"packages":[]')
		core.safe_file_write(path, json)
	end
	if core.ohos_set_status then
		core.ohos_set_status("phone_content:state")
	end
end

local function handle_refresh()
	local ok, err = pcall(function()
		refresh_packages()
		write_state()
	end)
	if not ok and core.ohos_set_status then
		core.ohos_set_status("phone_content:err:" .. tostring(err))
	end
end

local function handle_select(index)
	index = tonumber(index) or 1
	phone_content_selected = index
	write_state()
end

local function handle_uninstall(index)
	index = tonumber(index) or phone_content_selected
	local list = phone_content_packages and phone_content_packages:get_list() or {}
	local pkg = list[index]
	if not pkg then
		write_state({ actionError = "no_package" })
		return
	end
	if not core.may_modify_path(pkg.path) then
		write_state({ actionError = "cannot_uninstall" })
		return
	end
	if pkg.path and pkg.path ~= "" and pkg.path ~= core.get_modpath() and
			pkg.path ~= core.get_gamepath() and pkg.path ~= core.get_texturepath() then
		if not core.delete_dir(pkg.path) then
			write_state({ actionError = "delete_failed" })
			return
		end
		pkgmgr.reload_by_type(pkg.type)
	else
		write_state({ actionError = "invalid_path" })
		return
	end
	phone_content_packages = nil
	refresh_packages()
	write_state({ actionSuccess = "uninstalled" })
end

local function handle_use_txp(index)
	index = tonumber(index) or phone_content_selected
	local list = phone_content_packages:get_list()
	local pkg = list[index]
	if pkg and pkg.type == "txp" then
		core.settings:set("texture_path", pkg.path)
		phone_content_packages = nil
		pkgmgr.reload_texture_packs()
		mm_game_theme.init()
		mm_game_theme.set_engine()
		handle_refresh()
	end
end

local function handle_disable_txp()
	core.settings:set("texture_path", "")
	phone_content_packages = nil
	pkgmgr.reload_texture_packs()
	mm_game_theme.init()
	mm_game_theme.set_engine()
	handle_refresh()
end

local function handle_browse_online()
	if core.ohos_set_status then
		core.ohos_set_status("phone_content:browse")
	end
end

local function dispatch_action(json_str)
	local ok, action = pcall(core.parse_json, json_str)
	if not ok or type(action) ~= "table" or not action.op then
		if core.ohos_set_status then
			core.ohos_set_status("phone_content:err:bad_action")
		end
		return
	end

	if action.op == "refresh" then
		handle_refresh()
	elseif action.op == "select" then
		handle_select(action.index)
	elseif action.op == "uninstall" then
		handle_uninstall(action.index)
	elseif action.op == "use_txp" then
		handle_use_txp(action.index)
	elseif action.op == "disable_txp" then
		handle_disable_txp()
	elseif action.op == "browse_online" then
		handle_browse_online()
	else
		if core.ohos_set_status then
			core.ohos_set_status("phone_content:err:unknown_op")
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

	core.after(0.2, handle_refresh)
end
