-- Luanti
-- Copyright (C) 2014 sapier
-- Copyright (C) 2018 rubenwardy <rw@rubenwardy.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local function z(en, zh)
	if PLATFORM == "HarmonyOS" then
		return core.formspec_escape(zh)
	end
	return fgettext(en)
end

local function z_ne(en, zh, ...)
	if PLATFORM == "HarmonyOS" then
		local s = zh
		local arg = { n = select("#", ...), ... }
		if arg.n >= 1 then
			local pos = 1
			local result = ""
			while pos <= #s do
				local newpos = s:find("[$]", pos)
				if not newpos then
					result = result .. s:sub(pos)
					break
				end
				local idx = tonumber(s:sub(newpos + 1, newpos + 1))
				result = result .. s:sub(pos, newpos - 1) .. tostring(arg[idx])
				pos = newpos + 2
			end
			s = result
		end
		return core.formspec_escape(s)
	end
	return fgettext_ne(en, ...)
end

local function get_content_icons(packages_with_updates)
	local ret = {}
	for _, content in ipairs(packages_with_updates) do
		ret[content.virtual_path or content.path] = { type = "update" }
	end
	return ret
end


local packages_raw, packages

local function update_packages()
	pkgmgr.load_all()

	packages_raw = {}
	table.insert_all(packages_raw, pkgmgr.games)
	table.insert_all(packages_raw, pkgmgr.texture_packs)
	table.insert_all(packages_raw, pkgmgr.global_mods:get_list())

	local function get_data()
		return packages_raw
	end

	local function is_equal(element, uid) --uid match
		return (element.type == "game" and element.id == uid) or
				element.name == uid
	end

	packages = filterlist.create(get_data, pkgmgr.compare_package,
			is_equal, nil, {})
end

local function on_change(type)
	if type == "ENTER" then
		mm_game_theme.set_engine()
		update_packages()
	end
end

local function get_formspec(tabview, name, tabdata)
	if not packages then
		update_packages()
	end

	if not tabdata.selected_pkg then
		tabdata.selected_pkg = 1
	end

	local use_technical_names = core.settings:get_bool("show_technical_names")

	local packages_with_updates = update_detector.get_all()
	local update_icons = get_content_icons(packages_with_updates)
	local update_count = #packages_with_updates
	local contentdb_label
	if update_count == 0 then
		contentdb_label = z("Browse online content", "浏览在线内容")
	else
		contentdb_label = z_ne("Browse online content [$1]", "浏览在线内容 [$1]", update_count)
	end

	local retval = {
		"label[0.4,0.4;", z("Installed Packages:", "已安装包："), "]",
		"tablecolumns[color;tree;image,align=inline,width=1.5",
			",tooltip=", z("Update available?", "有更新可用？"),
			",0=", core.formspec_escape(defaulttexturedir .. "blank.png"),
			",4=", core.formspec_escape(defaulttexturedir .. "cdb_update_cropped.png"),
			";text]",
		"table[0.4,0.8;6.3,4.8;pkglist;",
		pkgmgr.render_packagelist(packages, use_technical_names, update_icons),
		";", tabdata.selected_pkg, "]",

		"button[0.4,5.8;6.3,0.9;btn_contentdb;", contentdb_label, "]"
	}

	local selected_pkg
	if filterlist.size(packages) >= tabdata.selected_pkg then
		selected_pkg = packages:get_list()[tabdata.selected_pkg]
	end

	if selected_pkg then
		local valid_screenshots = {
			-- See also contentdb/app/tasks/importtasks.py, def import_repo_screenshot
			selected_pkg.path .. DIR_DELIM .. "screenshot.png",
			selected_pkg.path .. DIR_DELIM .. "screenshot.jpg",
			selected_pkg.path .. DIR_DELIM .. "screenshot.jpeg",
		}

		-- Check for screenshot being available
		local modscreenshot
		for _, screenshotfilename in ipairs(valid_screenshots) do
			local screenshotfile, err = io.open(screenshotfilename, "r")
			if not err then
				screenshotfile:close()
				modscreenshot = screenshotfilename
				break
			end
		end

		-- Fallback to no_screenshot if no screenshot is avaliable
		if not modscreenshot then
			modscreenshot = defaulttexturedir .. "no_screenshot.png"
		end

		local desc = z("No package description available", "暂无包描述")
		if selected_pkg.description and selected_pkg.description:trim() ~= "" then
			desc = core.formspec_escape(selected_pkg.description)
		end

		local info = core.get_content_info(selected_pkg.path)

		local title_and_name
		if selected_pkg.type == "game" then
			title_and_name = selected_pkg.title or selected_pkg.name
		else
			title_and_name = (selected_pkg.title or selected_pkg.name) .. "\n" ..
				core.colorize("#BFBFBF", selected_pkg.name)
		end

		local desc_height = 3.2

		if selected_pkg.is_modpack then
			desc_height = 2.1

			table.insert_all(retval, {
				"button[7.1,4.7;8,0.9;btn_mod_mgr_rename_modpack;",
				z("Rename", "重命名"), "]"
			})
		elseif selected_pkg.type == "mod" then
			-- Show dependencies for mods
			desc = desc .. "\n\n"
			local toadd_hard = table.concat(info.depends or {}, "\n")
			local toadd_soft = table.concat(info.optional_depends or {}, "\n")
			if toadd_hard == "" and toadd_soft == "" then
				desc = desc .. z("No dependencies.", "无依赖项。")
			else
				if toadd_hard ~= "" then
					desc = desc .. z("Dependencies:", "依赖项：") ..
						"\n" .. toadd_hard
				end
				if toadd_soft ~= "" then
					if toadd_hard ~= "" then
						desc = desc .. "\n\n"
					end
					desc = desc .. z("Optional dependencies:", "可选依赖项：") ..
						"\n" .. toadd_soft
				end
			end
		elseif selected_pkg.type == "txp" then
			desc_height = 2.1

			if selected_pkg.enabled then
				table.insert_all(retval, {
					"button[7.1,4.7;8,0.9;btn_mod_mgr_disable_txp;",
					z("Disable Texture Pack", "禁用材质包"), "]"
				})
			else
				table.insert_all(retval, {
					"button[7.1,4.7;8,0.9;btn_mod_mgr_use_txp;",
					z("Use Texture Pack", "使用材质包"), "]"
				})
			end
		end

		table.insert_all(retval, {
			"image[7.1,0.2;3,2;", core.formspec_escape(modscreenshot), "]",
			"label[10.5,1;", core.formspec_escape(title_and_name), "]",
			"box[7.1,2.4;8,", tostring(desc_height), ";#000]",
			"textarea[7.1,2.4;8,", tostring(desc_height), ";;;", desc, "]",
		})

		if core.may_modify_path(selected_pkg.path) then
			table.insert_all(retval, {
				"button[7.1,5.8;4,0.9;btn_mod_mgr_delete_mod;",
				z("Uninstall", "卸载"), "]"
			})
		end

		if update_icons[selected_pkg.virtual_path or selected_pkg.path] then
			table.insert_all(retval, {
				"button[11.1,5.8;4,0.9;btn_mod_mgr_update;",
				z("Update", "更新"), "]"
			})
		end
	end

	return table.concat(retval)
end

local function handle_doubleclick(pkg)
	if pkg.type == "txp" then
		if core.settings:get("texture_path") == pkg.path then
			core.settings:set("texture_path", "")
		else
			core.settings:set("texture_path", pkg.path)
		end
		packages = nil
		pkgmgr.reload_texture_packs()

		mm_game_theme.init()
		mm_game_theme.set_engine()
	end
end

local function handle_buttons(tabview, fields, tabname, tabdata)

	if fields.pkglist then
		local event = core.explode_table_event(fields.pkglist)
		tabdata.selected_pkg = event.row
		if event.type == "DCL" then
			handle_doubleclick(packages:get_list()[tabdata.selected_pkg])
		end
		return true
	end

	if fields.btn_contentdb then
		local dlg = create_contentdb_dlg()
		dlg:set_parent(tabview)
		tabview:hide()
		dlg:show()
		packages = nil
		return true
	end

	if fields.btn_mod_mgr_rename_modpack then
		local mod = packages:get_list()[tabdata.selected_pkg]
		local dlg_renamemp = create_rename_modpack_dlg(mod)
		dlg_renamemp:set_parent(tabview)
		tabview:hide()
		dlg_renamemp:show()
		packages = nil
		return true
	end

	if fields.btn_mod_mgr_delete_mod then
		local mod = packages:get_list()[tabdata.selected_pkg]
		local dlg_delmod = create_delete_content_dlg(mod)
		dlg_delmod:set_parent(tabview)
		tabview:hide()
		dlg_delmod:show()
		packages = nil
		return true
	end

	if fields.btn_mod_mgr_update then
		local pkg = packages:get_list()[tabdata.selected_pkg]
		local dlg = create_contentdb_dlg(nil, pkgmgr.get_contentdb_id(pkg))
		dlg:set_parent(tabview)
		tabview:hide()
		dlg:show()
		packages = nil
		return true
	end

	if fields.btn_mod_mgr_use_txp or fields.btn_mod_mgr_disable_txp then
		local txp_path = ""
		if fields.btn_mod_mgr_use_txp then
			txp_path = packages:get_list()[tabdata.selected_pkg].path
		end

		core.settings:set("texture_path", txp_path)
		packages = nil
		pkgmgr.reload_texture_packs()

		mm_game_theme.init()
		mm_game_theme.set_engine()
		return true
	end

	return false
end

return {
	name = "content",
	caption = function()
		local update_count = core.settings:get_bool("contentdb_enable_updates_indicator") and update_detector.get_count() or 0
		if update_count == 0 then
			return z("Content", "内容")
		else
			return z_ne("Content [$1]", "内容 [$1]", update_count)
		end
	end,
	cbf_formspec = get_formspec,
	cbf_button_handler = handle_buttons,
	on_change = on_change
}
