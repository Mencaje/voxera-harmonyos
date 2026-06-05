-- Luanti
-- Copyright (C) 2013 sapier
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- About tab only: use the transparent source PNG as-is (see scripts/gen_voxera_icons.py --about-only).
local ABOUT_LOGO_FILE = "voxera_about_source.png"
local ABOUT_LOGO_W = 2.5
local ABOUT_LOGO_H = 2.5
local VOXERA_LEGAL_URL = "https://voxera.mencaje.com/"
local MENCAJE_HOMEPAGE_URL = "https://mencaje.com/"

local function resolve_about_logo_path()
	local path = defaulttexturedir .. ABOUT_LOGO_FILE
	local f = io.open(path, "rb")
	if f then
		f:close()
		return path
	end
	return defaulttexturedir .. "logo.png"
end

local function prepare_credits(dest, source)
	local string = table.concat(source, "\n") .. "\n"

	string = core.hypertext_escape(string)
	string = string:gsub("%[.-%]", "<gray>%1</gray>")

	table.insert(dest, string)
end

local function get_credits()
	local f = assert(io.open(core.get_mainmenu_path() .. "/credits.json"))
	local json = core.parse_json(f:read("*all"))
	f:close()
	return json
end

local function get_renderer_info()
	local ret = {}

	-- OpenGL version, stripped to just the important part
	local s1 = core.get_active_renderer()
	if s1:sub(1, 7) == "OpenGL " then
		s1 = s1:sub(8)
	end
	local m = s1:match("^[%d.]+")
	if not m then
		m = s1:match("^ES [%d.]+")
	end
	ret[#ret+1] = m or s1
	-- video driver
	ret[#ret+1] = core.get_active_driver():lower()
	-- irrlicht device
	ret[#ret+1] = core.get_active_irrlicht_device():upper()

	return table.concat(ret, " / ")
end

local function get_about_version_label()
	if PLATFORM == "HarmonyOS" then
		return "Voxera-HarmonyOS 2.0.0"
	end
	local version = core.get_version()
	return version.project .. " " .. version.string
end

local function get_about_homepage_button()
	if PLATFORM == "HarmonyOS" then
		return "button_url[1.5,4.1;2.5,0.8;homepage;" ..
			core.formspec_escape("萌创匠盒") .. ";" .. MENCAJE_HOMEPAGE_URL .. "]"
	end
	return "button_url[1.5,4.1;2.5,0.8;homepage;luanti.org;https://www.luanti.org/]"
end

-- Yellow label + light value (same style as upstream credits headings).
local function hypertext_label_value(label, value)
	return "<heading>" .. core.hypertext_escape(label) .. "</heading>" ..
		"<gray>" .. core.hypertext_escape(value) .. "</gray>\n"
end

-- Map hypertext action names -> URLs (HarmonyOS: Lua fallback if C++ url handler misses).
local about_url_actions = {}
local about_url_action_seq = 0

-- Yellow label + clickable URL. Luanti hypertext requires <action name="..."> (name is mandatory).
local function hypertext_label_link(label, url, display_text)
	local shown = display_text or url
	about_url_action_seq = about_url_action_seq + 1
	local action_name = "voxera_url_" .. about_url_action_seq
	about_url_actions[action_name] = url
	return "<heading>" .. core.hypertext_escape(label) .. "</heading>" ..
		"<action name=\"" .. action_name .. "\" url=\"" .. url .. "\">" ..
		"<style color=\"#aaaaaa\" hovercolor=\"#66ccff\">" ..
		core.hypertext_escape(shown) .. "</style></action>\n"
end

local function handle_about_hypertext_click(fields)
	if not fields.credits or fields.credits:sub(1, 7) ~= "action:" then
		return false
	end
	local action_name = fields.credits:sub(8)
	local url = about_url_actions[action_name]
	if url then
		core.open_url(url)
		return true
	end
	return false
end

-- Luanti LICENSE.txt §「License of Luanti source code」:
-- GNU Lesser General Public License, either version 2.1 or (at your option) any later version.
-- Every engine source file declares: SPDX-License-Identifier: LGPL-2.1-or-later
local VOXERA_BASE_ENGINE = {
	name = "Luanti",
	desc = "开源体素游戏引擎（本应用在其源码基础上移植至 HarmonyOS）",
	site = "https://www.luanti.org/",
	source = "https://github.com/luanti-org/luanti/",
	license_spdx = "LGPL-2.1-or-later",
	license_name = "GNU Lesser General Public License",
	license_name_cn = "GNU 宽通用公共许可证",
	license_version = "v2.1 or later",
	license_version_cn = "第 2.1 版或更新版本",
	license_url = "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html",
	-- Luanti LICENSE.txt §「License of Luanti textures and sounds」 (bundled default assets)
	media_license_spdx = "CC-BY-SA-3.0",
	media_license_cn = "默认贴图与音效：知识共享 署名-相同方式共享 3.0",
	media_license_url = "https://creativecommons.org/licenses/by-sa/3.0/",
}

-- Bundled with the engine binary; not separate “games” or game content.
local VOXERA_RUNTIME_LIBS = {
	{
		name = "SDL2",
		site = "https://www.libsdl.org/",
		license_spdx = "Zlib",
		license_name_cn = "zlib 许可证",
		license_url = "https://www.zlib.net/zlib_license.html",
	},
	{
		name = "Lua",
		site = "https://www.lua.org/",
		license_spdx = "MIT",
		license_name_cn = "MIT 许可证",
		license_url = "https://www.lua.org/license.html",
	},
}

local function format_license_line(dep)
	if not dep.license_spdx then
		return dep.license_cn or dep.license or dep.license_tag or ""
	end
	local name = dep.license_name_cn or dep.license_name or dep.license_spdx
	local ver = dep.license_version_cn or dep.license_version
	local line = ver and ver ~= "" and (name .. " " .. ver) or name
	return line .. "（SPDX：" .. dep.license_spdx .. "）"
end

local function append_oss_block(parts, dep, with_source)
	table.insert(parts, hypertext_label_value("开源名称：", dep.name))
	if dep.desc then
		table.insert(parts, "<gray>" .. core.hypertext_escape(dep.desc) .. "</gray>\n")
	end
	table.insert(parts, hypertext_label_link("开源官网：", dep.site))
	if with_source and dep.source then
		table.insert(parts, hypertext_label_link("开源源码：", dep.source))
	end
	table.insert(parts, hypertext_label_value("开源协议：", format_license_line(dep)))
	if dep.license_url then
		table.insert(parts, hypertext_label_link("协议全文：", dep.license_url))
	end
	if dep.media_license_cn then
		table.insert(parts, hypertext_label_value("随附素材协议：",
			dep.media_license_cn .. "（SPDX：" .. dep.media_license_spdx .. "）"))
		if dep.media_license_url then
			table.insert(parts, hypertext_label_link("素材协议全文：", dep.media_license_url))
		end
	end
end

local function build_voxera_about_hypertext()
	about_url_actions = {}
	about_url_action_seq = 0
	local parts = {
		"<tag name=heading color=#ff0>",
		"<tag name=gray color=#aaa>",
		hypertext_label_value("开发者：", "萌创匠盒"),
		hypertext_label_link("官网：", MENCAJE_HOMEPAGE_URL, "mencaje.com"),
		hypertext_label_link("本项目开源地址：",
			"https://github.com/Mencaje/voxera-harmonyos"),
		"\n",
		"<heading>", core.hypertext_escape("本应用所基于的主要开源项目（引擎）："), "</heading>\n",
	}
	append_oss_block(parts, VOXERA_BASE_ENGINE, true)
	table.insert(parts, "\n")
	table.insert(parts,
		"<heading>" .. core.hypertext_escape("引擎运行时还使用以下组件：") .. "</heading>\n")
	for i = 1, #VOXERA_RUNTIME_LIBS do
		append_oss_block(parts, VOXERA_RUNTIME_LIBS[i], false)
		if i < #VOXERA_RUNTIME_LIBS then
			table.insert(parts, "\n")
		end
	end
	table.insert(parts, "\n")
	table.insert(parts, hypertext_label_link("隐私政策：", VOXERA_LEGAL_URL))
	table.insert(parts, hypertext_label_link("用户协议：", VOXERA_LEGAL_URL))
	return table.concat(parts)
end

local function build_upstream_credits_hypertext()
	local hypertext = {
		"<tag name=heading color=#ff0>",
		"<tag name=gray color=#aaa>",
	}

	local credits = get_credits()

	table.insert_all(hypertext, {
		"<heading>", fgettext_ne("Core Developers"), "</heading>\n",
	})
	prepare_credits(hypertext, credits.core_developers)
	table.insert_all(hypertext, {
		"\n",
		"<heading>", fgettext_ne("Core Team"), "</heading>\n",
	})
	prepare_credits(hypertext, credits.core_team)
	table.insert_all(hypertext, {
		"\n",
		"<heading>", fgettext_ne("Active Contributors"), "</heading>\n",
	})
	prepare_credits(hypertext, credits.contributors)
	table.insert_all(hypertext, {
		"\n",
		"<heading>", fgettext_ne("Previous Core Developers"), "</heading>\n",
	})
	prepare_credits(hypertext, credits.previous_core_developers)
	table.insert_all(hypertext, {
		"\n",
		"<heading>", fgettext_ne("Previous Contributors"), "</heading>\n",
	})
	prepare_credits(hypertext, credits.previous_contributors)

	return table.concat(hypertext):sub(1, -2)
end

return {
	name = "about",
	caption = fgettext("About"),

	cbf_formspec = function(tabview, name, tabdata)
		local logofile = resolve_about_logo_path()

		local hypertext
		if PLATFORM == "HarmonyOS" then
			hypertext = build_voxera_about_hypertext()
		else
			hypertext = build_upstream_credits_hypertext()
		end

		local fs = "image[1.5,0.6;" .. ABOUT_LOGO_W .. "," .. ABOUT_LOGO_H .. ";" ..
			core.formspec_escape(logofile) .. "]" ..
			"style[label_button;border=false]" ..
			"button[0.1,3.4;5.3,0.5;label_button;" ..
			core.formspec_escape(get_about_version_label()) .. "]" ..
			get_about_homepage_button()

		if PLATFORM == "Android" then
			fs = fs .. "button[0.5,5.1;4.5,0.8;share_debug;" .. fgettext("Share debug log") .. "]"
		else
			fs = fs .. "tooltip[userdata;" ..
					fgettext("Opens the directory that contains user-provided worlds, games, mods,\n" ..
							"and texture packs in a file manager / explorer.") .. "]"
			fs = fs .. "button[0.5,5.1;4.5,0.8;userdata;" .. fgettext("Open User Data Directory") .. "]"
		end

		local active_renderer_info = fgettext("Active renderer:") .. "\n" ..
			core.formspec_escape(get_renderer_info())
		fs = fs .. "style[label_button2;border=false]" ..
			"button[0.1,6;5.3,1;label_button2;" .. active_renderer_info .. "]"..
			"tooltip[label_button2;" .. active_renderer_info .. "]" ..
			"hypertext[5.5,0.25;9.75,6.6;credits;" .. core.formspec_escape(hypertext) .. "]"

		return fs
	end,

	cbf_button_handler = function(this, fields, name, tabdata)
		if handle_about_hypertext_click(fields) then
			return true
		end

		if fields.share_debug then
			local path = core.get_user_path() .. DIR_DELIM .. "debug.txt"
			core.share_file(path)
		end

		if fields.userdata then
			core.open_dir(core.get_user_path())
		end
	end,

	on_change = function(type)
		if type == "ENTER" then
			mm_game_theme.set_engine()
		end
	end,
}
