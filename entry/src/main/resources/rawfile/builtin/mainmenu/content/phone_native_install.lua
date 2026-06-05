-- HarmonyOS phone: native ArkUI install gate feeds zip paths via completeOhosFilePick.
-- SPDX-License-Identifier: LGPL-2.1-or-later

local PHONE_PATH = "phone_native_install"

if PLATFORM == "HarmonyOS" and DEVICE_FORM_FACTOR == "phone" then
	local orig_button_handler = core.button_handler

	core.button_handler = function(fields)
		if fields[PHONE_PATH .. "_accepted"] then
			local path = fields[PHONE_PATH .. "_accepted"]
			if path and path ~= "" and phone_native_install_from_path then
				phone_native_install_from_path(path)
			end
			return
		end
		if fields[PHONE_PATH .. "_canceled"] then
			return
		end
		orig_button_handler(fields)
	end
end
