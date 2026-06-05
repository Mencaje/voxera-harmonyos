-- HarmonyOS phone: native ArkUI Settings tab bridge.
-- Uses dlg_settings.lua page/filter logic; persists via core.settings.
-- SPDX-License-Identifier: LGPL-2.1-or-later

local PHONE_PATH = "phone_native_settings"
local STATE_FILE = "phone_settings_state.json"

local function write_state(extra)
	local page_id = extra and extra.pageId or nil
	local query = extra and extra.query or nil
	local state = phone_settings_build_state(page_id, query)
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			if k ~= "pageId" and k ~= "query" then
				state[k] = v
			end
		end
	end
	local path = core.get_cache_path() .. DIR_DELIM .. STATE_FILE
	local json = core.write_json(state)
	if json then
		json = json:gsub('"pages":null', '"pages":[]')
		json = json:gsub('"items":null', '"items":[]')
		json = json:gsub('"options":null', '"options":[]')
		json = json:gsub('"flags":null', '"flags":[]')
		core.safe_file_write(path, json)
	end
	if core.ohos_set_status then
		core.ohos_set_status("phone_settings:state")
	end
end

local function handle_refresh(action)
	local ok, err = pcall(function()
		write_state({
			pageId = action.pageId,
			query = action.query,
		})
	end)
	if not ok and core.ohos_set_status then
		core.ohos_set_status("phone_settings:err:" .. tostring(err))
	end
end

local function handle_select_page(page_id)
	write_state({ pageId = page_id })
end

local function handle_search(query)
	write_state({ query = query or "" })
end

local function handle_set_bool(name, value)
	phone_settings_set_bool(name, value)
	write_state({})
end

local function handle_set_enum(name, index)
	phone_settings_set_enum(name, index)
	write_state({})
end

local function handle_set_value(name, value)
	phone_settings_set_string(name, value)
	write_state({})
end

local function handle_set_v3f(name, value)
	phone_settings_set_string(name, value)
	write_state({})
end

local function handle_set_flag(name, flag_name, enabled)
	phone_settings_set_flag(name, flag_name, enabled)
	write_state({})
end

local function handle_reset(name)
	phone_settings_reset(name)
	write_state({})
end

local function handle_ui_bool(name, value)
	phone_settings_set_ui_bool(name, value)
	write_state({})
end

local function handle_shadow(index)
	phone_settings_apply_shadow(index)
	write_state({})
end

local function handle_action(action_id)
	if action_id == "touch_layout" then
		phone_settings_touch_layout()
	end
end

local function dispatch_action(json_str)
	local ok, action = pcall(core.parse_json, json_str)
	if not ok or type(action) ~= "table" or not action.op then
		if core.ohos_set_status then
			core.ohos_set_status("phone_settings:err:bad_action")
		end
		return
	end

	if action.op == "refresh" then
		handle_refresh(action)
	elseif action.op == "select_page" then
		handle_select_page(action.pageId)
	elseif action.op == "search" then
		handle_search(action.query)
	elseif action.op == "set_bool" then
		handle_set_bool(action.name, action.value)
	elseif action.op == "set_enum" then
		handle_set_enum(action.name, action.index)
	elseif action.op == "set_value" then
		handle_set_value(action.name, action.value)
	elseif action.op == "set_v3f" then
		handle_set_v3f(action.name, action.value)
	elseif action.op == "set_flag" then
		handle_set_flag(action.name, action.flag, action.value)
	elseif action.op == "reset" then
		handle_reset(action.name)
	elseif action.op == "set_ui_bool" then
		handle_ui_bool(action.name, action.value)
	elseif action.op == "set_shadow" then
		handle_shadow(action.index)
	elseif action.op == "action" then
		handle_action(action.action)
	elseif action.op == "persist" then
		phone_settings_persist()
		write_state({})
	else
		if core.ohos_set_status then
			core.ohos_set_status("phone_settings:err:unknown_op")
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
		if orig_button_handler then
			orig_button_handler(fields)
		end
	end

	core.after(0.3, function()
		handle_refresh({})
	end)
end
