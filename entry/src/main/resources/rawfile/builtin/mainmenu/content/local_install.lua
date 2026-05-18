-- Luanti / Voxera — install ContentDB-style .zip packages from local files
-- SPDX-License-Identifier: LGPL-2.1-or-later

local_install = {}

local CONTENTDB_DOWNLOAD_URL = "https://content.luanti.org/"

function local_install.ohos_status(msg)
	core.log("info", msg)
	if core.ohos_set_status then
		core.ohos_set_status(msg)
	end
end

function local_install.get_download_url()
	return CONTENTDB_DOWNLOAD_URL
end

local function validate_zip_path(zip_path)
	if not zip_path or zip_path == "" then
		return false
	end
	return zip_path:lower():match("%.zip$") ~= nil
end

-- Use cache dir (writable on OHOS); system temp from get_temp_path() is often empty.
local function make_install_work_dir()
	local cache = core.get_cache_path()
	if not cache or cache == "" then
		return ""
	end
	local stamp = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
	local dir = cache .. DIR_DELIM .. "pkg_install_" .. stamp
	if not core.create_dir(dir) then
		return ""
	end
	return dir
end

-- Extract on the main menu thread (Irrlicht zip + OHOS EGL are unreliable in async workers).
function local_install.extract_to_temp(zip_path)
	if not zip_path or zip_path == "" then
		return { bad_file = true }
	end

	-- OHOS DocumentPicker path: ArkTS already extracted the zip to a cache folder.
	if core.is_dir(zip_path) then
		local_install.ohos_status("local_install: using pre-extracted " .. zip_path)
		return { path = zip_path }
	end

	if not validate_zip_path(zip_path) then
		return { bad_file = true }
	end

	local tempfolder = make_install_work_dir()
	if tempfolder == "" then
		core.log("warning", "local_install: could not create work dir under cache")
		ohos_status("local_install: cache work dir failed")
		return { error = true }
	end

	local_install.ohos_status("local_install: extract zip")
	core.log("info", "local_install: extract " .. zip_path .. " -> " .. tempfolder)
	if not core.extract_zip(zip_path, tempfolder) then
		core.delete_dir(tempfolder)
		local_install.ohos_status("local_install: extract_zip failed")
		return { bad_file = true }
	end

	return { path = tempfolder }
end

-- Async worker: core API only (pkgmgr is not available in the async environment).
local function extract_zip_to_temp(param)
	local zip_path = param.zip_path

	if not validate_zip_path(zip_path) then
		return { bad_file = true }
	end

	local tempfolder = make_install_work_dir()
	if tempfolder == "" then
		return { error = true }
	end

	if not core.extract_zip(zip_path, tempfolder) then
		core.delete_dir(tempfolder)
		return { bad_file = true }
	end

	return { path = tempfolder }
end

function local_install.extract_zip_async(zip_path, callback)
	if not core.handle_async then
		callback({ error = true })
		return false
	end

	return core.handle_async(extract_zip_to_temp, {
		zip_path = zip_path,
	}, callback)
end

function local_install.install_zip_async(zip_path, expected_type, callback)
	expected_type = expected_type or "game"

	local function on_extracted(result)
		if not result then
			callback({ error = true })
			return
		end
		if result.bad_file or result.error then
			callback(result)
			return
		end
		if not result.path then
			callback({ error = true })
			return
		end

		local basefolder = pkgmgr.get_base_folder(result.path)
		if not basefolder then
			callback({ bad_file = true })
			return
		end

		if basefolder.type ~= expected_type and
				not (expected_type == "mod" and basefolder.type == "modpack") then
			callback({ bad_file = true })
			return
		end

		local path, msg = pkgmgr.install_dir(expected_type, result.path, nil, nil)
		if not path then
			core.log("warning", "local_install: " .. tostring(msg))
			callback({ error = true })
			return
		end

		callback({ ok = true, path = path, content_type = expected_type })
	end

	return local_install.extract_zip_async(zip_path, on_extracted)
end
