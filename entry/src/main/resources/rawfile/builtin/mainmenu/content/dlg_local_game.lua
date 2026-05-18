-- Luanti / Voxera — install games/mods from a local ContentDB .zip (no online fetch)
-- SPDX-License-Identifier: LGPL-2.1-or-later

local PATH_DIALOG = "dlg_local_game_zip"
local PICK_BUTTON = "local_game_pick"
local DOWNLOAD_BTN = "local_game_download_site"
local HISTORY_KEY = "voxera_local_install_history"

local STATUS = {
	installing = "installing",
	ok = "ok",
	bad_file = "bad_file",
	error = "error",
}

local function zh_menu(en, zh)
	local t = fgettext(en)
	if t == nil or t == en or t == "" then
		return zh
	end
	return t
end

local function fs(...)
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do
		local v = select(i, ...)
		if v == nil then
			v = ""
		end
		parts[i] = tostring(v)
	end
	return table.concat(parts)
end

local function layout_metrics()
	local size = { x = 15, y = 10 }
	local padding = { x = 0.5, y = 0.5 }
	if contentdb and contentdb.get_formspec_size and contentdb.get_formspec_padding then
		size = contentdb.get_formspec_size() or size
		padding = contentdb.get_formspec_padding() or padding
	end
	size.x = tonumber(size.x) or 15
	size.y = tonumber(size.y) or 10
	padding.x = tonumber(padding.x) or 0.5
	padding.y = tonumber(padding.y) or 0.5
	local btn_h = 0.8
	local bottom_y = size.y - btn_h - padding.y
	return size, padding, btn_h, bottom_y
end

local function pick_box_formspec(x, y, w, h, border)
	return fs(
		"box[", x, ",", y, ";", w, ",0.06;", border, "]",
		"box[", x, ",", y + h - 0.06, ";", w, ",0.06;", border, "]",
		"box[", x, ",", y, ";0.06,", h, ";", border, "]",
		"box[", x + w - 0.06, ",", y, ";0.06,", h, ";", border, "]"
	)
end

local function load_slots()
	local raw = core.settings:get(HISTORY_KEY)
	if not raw or raw == "" then
		return {}
	end
	local t = core.deserialize(raw)
	if type(t) ~= "table" then
		return {}
	end
	return t
end

local function save_slots(slots)
	core.settings:set(HISTORY_KEY, core.serialize(slots))
end

local function upsert_slot(slots, entry)
	for i, s in ipairs(slots) do
		if s.id == entry.id then
			slots[i] = entry
			return
		end
	end
	table.insert(slots, entry)
end

local function set_zip_drop_target(formname)
	if PLATFORM == "HarmonyOS" and core.ohos_set_zip_drop_target then
		core.ohos_set_zip_drop_target(formname or "")
	end
end

local function row0_slot_capacity(avail_w, pick_w, gap)
	return math.max(0, math.floor((avail_w - pick_w - gap + gap) / (pick_w + gap)))
end

local function full_row_columns(avail_w, pick_w, gap)
	return math.max(1, math.floor((avail_w + gap) / (pick_w + gap)))
end

local function slot_layout_index(index, pick_w, pick_h, gap, avail_w)
	local row0_cap = row0_slot_capacity(avail_w, pick_w, gap)
	if index < row0_cap then
		return pick_w + gap + index * (pick_w + gap), 0
	end
	local j = index - row0_cap
	local cols = full_row_columns(avail_w, pick_w, gap)
	local col = j % cols
	local row = math.floor(j / cols) + 1
	return col * (pick_w + gap), row * (pick_h + gap)
end

local function append_slot_visual(parts, x, y, pick_w, pick_h, border, tex_dir, slot)
	parts[#parts + 1] = pick_box_formspec(x, y, pick_w, pick_h, border)
	local icon = 0.55
	local icon_x = x + (pick_w - icon) / 2
	local icon_y = y + (pick_h - icon) / 2
	local loading_tex = core.formspec_escape(tex_dir .. "cdb_downloading.png") or ""
	local ok_tex = core.formspec_escape(tex_dir .. "checkbox_64.png") or ""
	local err_tex = core.formspec_escape(tex_dir .. "error_icon_red.png") or ""

	local st = slot.status
	if st == STATUS.installing then
		parts[#parts + 1] = fs(
			"animated_image[", icon_x, ",", icon_y, ";", icon, ",", icon,
			";slot_loading_", x, "_", y, ";", loading_tex, ";3;400;;]"
		)
	elseif st == STATUS.ok then
		parts[#parts + 1] = fs(
			"image[", icon_x, ",", icon_y, ";", icon, ",", icon, ";", ok_tex, "]"
		)
	else
		parts[#parts + 1] = fs(
			"image[", icon_x, ",", icon_y, ";", icon, ",", icon, ";", err_tex, "]"
		)
	end

	local caption = slot.status_text or slot.title or slot.id or ""
	if caption ~= "" and st ~= STATUS.ok then
		parts[#parts + 1] = fs(
			"label[", x, ",", y + pick_h + 0.05, ";", pick_w, ",0.4;",
			core.formspec_escape(caption), "]"
		)
	elseif slot.title and slot.title ~= "" and st == STATUS.ok then
		parts[#parts + 1] = fs(
			"tooltip[", x, ",", y, ";", pick_w, ",", pick_h, ";",
			core.formspec_escape(slot.title), "]"
		)
	end
end

local function get_formspec(dlgdata)
	dlgdata = dlgdata or {}
	local size, padding, btn_h, bottom_y = layout_metrics()
	local pick_w = 2.5
	local pick_h = 2.5
	local gap = 0.35
	local dl_btn_w = 3.6
	local border = "#aaaaaa"
	local inner = pick_w - 0.12
	local avail_w = size.x - padding.x * 2
	local grid_h = bottom_y - padding.y

	local tex_dir = defaulttexturedir or ""
	local plus_img = core.formspec_escape(tex_dir .. "plus.png") or ""

	local slots = dlgdata.slots or {}
	local pending = dlgdata.pending
	local display = {}
	for i = 1, #slots do
		display[#display + 1] = slots[i]
	end
	if pending then
		display[#display + 1] = pending
	end

	local top_parts = {
		"container[", padding.x, ",", padding.y, "]",
		pick_box_formspec(0, 0, pick_w, pick_h, border),
		"style[", PICK_BUTTON, ";border=false;bgcolor=#00000000]",
		"style[", PICK_BUTTON, ":hovered;bgcolor=#ffffff12]",
		"style[", PICK_BUTTON, ":pressed;bgcolor=#ffffff22]",
		"button[0.12,0.12;", inner, ",", inner, ";", PICK_BUTTON, ";]",
		"image[", pick_w / 2 - 0.75, ",", pick_h / 2 - 0.75, ";1.5,1.5;", plus_img, "]",
		"tooltip[", PICK_BUTTON, ";",
			zh_menu("Open downloaded package locally", "本地打开下载的包"), "]",
	}

	for i = 1, #display do
		local sx, sy = slot_layout_index(i - 1, pick_w, pick_h, gap, avail_w)
		if sy + pick_h <= grid_h then
			append_slot_visual(top_parts, sx, sy, pick_w, pick_h, border, tex_dir, display[i])
		end
	end

	top_parts[#top_parts + 1] = "container_end[]"

	local out = {
		"formspec_version[6]",
		"size[", size.x, ",", size.y, "]",
		"padding[0,0]",
		"bgcolor[;true]",
	}
	for i = 1, #top_parts do
		out[#out + 1] = top_parts[i]
	end
	out[#out + 1] = "container["
	out[#out + 1] = padding.x
	out[#out + 1] = ","
	out[#out + 1] = bottom_y
	out[#out + 1] = "]"
	out[#out + 1] = "button[0,0;2,"
	out[#out + 1] = btn_h
	out[#out + 1] = ";back;"
	out[#out + 1] = zh_menu("Back", "返回")
	out[#out + 1] = "]"
	out[#out + 1] = "container_end[]"
	out[#out + 1] = "container["
	out[#out + 1] = size.x - padding.x - dl_btn_w
	out[#out + 1] = ","
	out[#out + 1] = bottom_y
	out[#out + 1] = "]"
	out[#out + 1] = "button[0,0;"
	out[#out + 1] = dl_btn_w
	out[#out + 1] = ","
	out[#out + 1] = btn_h
	out[#out + 1] = ";"
	out[#out + 1] = DOWNLOAD_BTN
	out[#out + 1] = ";"
	out[#out + 1] = zh_menu("Go to download packages", "前往下载包")
	out[#out + 1] = "]"
	out[#out + 1] = "container_end[]"
	return fs(unpack(out))
end

local function install_type_for(basefolder)
	if basefolder.type == "game" then
		return "game"
	end
	if basefolder.type == "mod" or basefolder.type == "modpack" then
		return "mod"
	end
	return nil
end

local function apply_install_result(dlg, result)
	dlg.data.pending = nil
	if result and result.ok then
		upsert_slot(dlg.data.slots, {
			id = result.id,
			title = result.title,
			status = STATUS.ok,
		})
		save_slots(dlg.data.slots)
		pkgmgr.reload_by_type(result.content_type or "game")
		if singleplayer_refresh_gamebar and (result.content_type or "game") == "game" then
			singleplayer_refresh_gamebar()
		end
		if result.content_type == "game" and result.id then
			core.settings:set("menu_last_game", result.id)
		end
		ui.update()
		return
	end

	if result and result.bad_file then
		dlg.data.pending = {
			status = STATUS.bad_file,
			status_text = zh_menu("Incorrect file", "文件不正确"),
		}
	elseif result and result.error then
		dlg.data.pending = {
			status = STATUS.error,
			status_text = result.error_msg
				or zh_menu("Other error", "其他错误"),
		}
	else
		dlg.data.pending = {
			status = STATUS.error,
			status_text = result and result.error_msg
				or zh_menu("Other error", "其他错误"),
		}
	end
	ui.update()
end

local function run_install(dlg, zip_path)
	dlg.data.pending = {
		id = "",
		title = "",
		status = STATUS.installing,
	}
	ui.update()

	local function short_err(msg)
		if not msg or msg == "" then
			return zh_menu("Other error", "其他错误")
		end
		msg = tostring(msg)
		if #msg > 72 then
			return msg:sub(1, 69) .. "..."
		end
		return msg
	end

	local function finish_install(extracted_path, basename, content_type, title, id)
		if local_install and local_install.ohos_status then
			local_install.ohos_status("local_install: install " .. content_type)
		end
		if content_type == "game" then
			core.create_dir(core.get_gamepath())
		else
			core.create_dir(core.get_modpath())
		end
		local path, msg = pkgmgr.install_dir(content_type, extracted_path, basename, nil)
		if extracted_path and extracted_path ~= "" then
			core.delete_dir(extracted_path)
		end
		if not path then
			core.log("warning", "local_install dlg: " .. tostring(msg))
			if local_install and local_install.ohos_status then
				local_install.ohos_status("local_install: " .. tostring(msg))
			end
			apply_install_result(dlg, { error = true, error_msg = short_err(msg) })
			return
		end
		apply_install_result(dlg, {
			ok = true,
			path = path,
			content_type = content_type,
			id = id or basename,
			title = title or basename,
		})
	end

	local function do_install(extracted_path, basename, content_type, title, id)
		dlg:show()
		dlg.data.pending = { status = STATUS.installing }
		ui.update()
		finish_install(extracted_path, basename, content_type, title, id)
	end

	local function process_extracted(info)
		if not info then
			apply_install_result(dlg, { error = true })
			return
		end
		if info.bad_file or info.error then
			apply_install_result(dlg, info)
			return
		end
		if not info.path then
			apply_install_result(dlg, { error = true })
			return
		end

		local basefolder = pkgmgr.get_base_folder(info.path)
		local content_type = basefolder and install_type_for(basefolder) or nil
		if not content_type then
			core.delete_dir(info.path)
			apply_install_result(dlg, { bad_file = true })
			return
		end

		local conf_path = basefolder.path .. DIR_DELIM ..
			(content_type == "game" and "game.conf" or "mod.conf")
		local conf = Settings(conf_path)
		local raw_name = conf and conf:get("name")
			or basefolder.path:match("[^/\\]+[/\\]?$")
		local name
		if content_type == "game" then
			name = pkgmgr.normalize_game_id(raw_name)
		else
			name = raw_name and raw_name:match("[^/\\]+[/\\]?$") or nil
		end
		local title = (conf and conf:get("title")) or raw_name or name
		local target_root = content_type == "game" and core.get_gamepath() or core.get_modpath()
		if name and core.is_dir(target_root .. DIR_DELIM .. name) then
			local package = {
				name = name,
				title = title or name,
				type = content_type,
			}
			local confirm = create_confirm_overwrite(package, function()
				do_install(info.path, name, content_type, title, name)
			end)
			confirm:set_parent(dlg)
			dlg:hide()
			confirm:show()
			ui.update()
			return
		end

		finish_install(info.path, name, content_type, title, name)
	end

	if not local_install or not local_install.extract_to_temp then
		apply_install_result(dlg, { error = true })
		return
	end
	if local_install.ohos_status then
		local_install.ohos_status("local_install: begin")
	end
	process_extracted(local_install.extract_to_temp(zip_path))
end

local function handle_submit(dlg, fields)
	if fields.back then
		set_zip_drop_target("")
		dlg:delete()
		return true
	end

	if fields[PICK_BUTTON] then
		core.show_path_select_dialog(PATH_DIALOG,
				zh_menu("Select package", "选择安装包"), true)
		return true
	end

	if fields[PATH_DIALOG .. "_accepted"] then
		local path = fields[PATH_DIALOG .. "_accepted"]
		if path and path ~= "" then
			run_install(dlg, path)
		end
		return true
	end

	if fields[DOWNLOAD_BTN] then
		local url = "https://content.luanti.org/"
		if local_install and local_install.get_download_url then
			url = local_install.get_download_url() or url
		end
		core.open_url(url)
		return true
	end

	return false
end

function create_local_game_install_dlg()
	local dlg
	local function handle_events(event)
		if event == "DialogShow" then
			mm_game_theme.set_engine(true)
			set_zip_drop_target(PATH_DIALOG)
			return true
		end
		if event == "DialogHide" then
			set_zip_drop_target("")
			return true
		end
		return false
	end

	dlg = dialog_create("local_game_install", get_formspec, handle_submit, handle_events)
	dlg.data.slots = load_slots()
	dlg.data.pending = nil

	local orig_delete = dlg.delete
	dlg.delete = function(self)
		set_zip_drop_target("")
		orig_delete(self)
	end

	return dlg
end
