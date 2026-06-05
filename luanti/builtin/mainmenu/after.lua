-- Lightweight core.after for the main menu (no register_globalstep in INIT=mainmenu).

local queue = {}

function core.run_mainmenu_after_step(_dtime)
	local now = core.get_us_time()
	local i = 1
	while i <= #queue do
		if now >= queue[i].expiry_us then
			local job = table.remove(queue, i)
			local args = job.args
			job.func(unpack(args, 1, args.n))
		else
			i = i + 1
		end
	end
end

function core.after(after, func, ...)
	assert(tonumber(after) and type(func) == "function",
		"Invalid core.after invocation")
	after = tonumber(after)
	if after < 0 then
		after = 0
	end
	queue[#queue + 1] = {
		expiry_us = core.get_us_time() + math.floor(after * 1000000),
		func = func,
		args = {
			n = select("#", ...),
			...
		},
	}
end

-- Poll deferred jobs before each formspec rebuild (same menu tick as button handlers).
local ui_update = ui.update
function ui.update()
	core.run_mainmenu_after_step(0)
	ui_update()
end
