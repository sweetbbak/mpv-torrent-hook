local settings = {
	remove_files = false,
	download_dir = "",
	disable_ipv6 = false,
	port = "8888",
}

-- require("mp.options").read_options(settings, "mpv-torrent")

local utils = require("mp.utils")
local script_dir = mp.get_script_directory()
local playing = {}

-- * Helpers
-- http://lua-users.org/wiki/StringRecipes
function ends_with(str, ending)
	return ending == "" or str:sub(-#ending) == ending
end

function read_file(file)
	local fh = assert(io.open(file, "rb"))
	local contents = fh:read("*all")
	fh:close()
	return contents
end

function write_file(file, text)
	local fh = io.open(file, "w")
	fh:write(text)
	fh:close()
end

function startswith(str, start)
	return str:sub(1, #start) == start
end

function is_handled_url(url)
	if startswith(url, "magnet:") then
		return true
	elseif ends_with(url, ".torrent") then
		return true
	else
		return false
	end
end

function start_playing(url, name, pid)
	table.insert(playing, { url = url, name = name, pid = pid })
	mp.msg.info("Playing:")
	mp.msg.info(name)
	mp.msg.info(url)
	mp.msg.info(pid)

	local opt = {}
	opt["force-media-title"] = name

	mp.command_native({
		"loadfile",
		url,
		"append",
		opt,
	})
end

function check_torrent()
	local url = mp.get_property("stream-open-filename")
	if is_handled_url(url) then
		-- local scriptdir = mp.get_script_directory()
		-- tempfile = utils.join_path(scriptdir, "mpv-torrent.json")

		local command = mp.command_native_async({
			name = "subprocess",
			playback_only = false,
			capture_stdout = true,
			detach = true,
			args = {
				"mpv-torrent",
				"--torrent",
				url,
			},
		}, function(suc, res, err)
			print("exiting")
		end)

		local cmd = mp.command_native({
			name = "subprocess",
			playback_only = false,
			capture_stdout = true,
			args = {
				"mpv-torrent",
				"--info",
			},
		})

		local info = utils.parse_json(cmd.stdout)
		mp.msg.info(info)

		local link = info["Link"]
		local name = info["Name"]
		local pid = info["Pid"]

		mp.msg.info(name)
		mp.msg.info(url)
		mp.msg.info(pid)

		if link ~= nil then
			start_playing(link, name, pid)
		else
			return
		end
	end
end

function cleanup()
	for _, inst in pairs(playing) do
		mp.msg.verbose("killing server PID " .. inst.pid)
		mp.commandv("run", "kill", inst.pid)
		mp.abort_async_command()
	end
end

mp.add_hook("on_load", 50, check_torrent)
mp.add_hook("on_load_fail", 50, check_torrent)

mp.register_event("shutdown", cleanup)
