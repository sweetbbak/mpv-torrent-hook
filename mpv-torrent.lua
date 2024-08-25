local options = {
	remove_files = false,
	download_dir = "",
	disable_ipv6 = false,
	port = "",
}

-- require("mp.options").read_options(settings, "mpv-torrent")

local utils = require("mp.utils")
local script_dir = mp.get_script_directory()
require("mp.options").read_options(options, "mpv-torrent")
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
	mp.command({
		"loadfile",
		url,
		"append",
		opt,
	})
end

-- get the mpv socket name for communication
function GetSocket()
	local socketname = mp.get_property("input-ipc-server")

	if socketname == nil or socketname == "" then
		mp.set_property("input-ipc-server", "/tmp/mpv-torrent-socket-" .. utils.getpid())
		socketname = mp.get_property("input-ipc-server")
	end

	return socketname
end

function check_torrent()
	local url = mp.get_property("stream-open-filename")

	if not is_handled_url(url) then
		return nil
	end

	mp.msg.info("running mpv-torrent hook")

	local command = mp.command_native_async({
		name = "subprocess",
		playback_only = false,
		capture_stdout = true,
		detach = true,
		args = {
			"mpv-torrent",
			"--port=6969",
			"--torrent",
			url,
		},
	}, function(suc, res, err)
		print("exiting")
		if err ~= nil or not suc then
			mp.msg.error("err: " .. err)
		end
	end)

	local sock = mp.get_property("input-ipc-server")
	if sock == nil or sock == "" then
		mp.msg.error("couldnt get mpv socket path")
	else
		mp.msg.info("mpv socket path: " .. sock)
	end

	local cmd = mp.command_native({
		name = "subprocess",
		playback_only = false,
		capture_stdout = true,
		args = {
			"mpv-torrent",
			"--port=6969",
			"--info",
		},
	})

	local info = utils.parse_json(cmd.stdout)

	local link = info["Link"]
	local name = info["Name"]
	local pid = info["Pid"]

	mp.msg.info("playing: " .. name .. link)

	if link ~= nil then
		table.insert(playing, { url = link, name = name, pid = pid })
		-- local opt = {}
		-- opt["force-media-title"] = name
		mp.commandv("force-media-title", name)
		mp.commandv("loadfile", link, "append")
	else
		return
	end
end

function cleanup()
	mp.msg.info("cleanup... ")
	-- mp.abort_async_command()
	mp.unregister_event(check_torrent)

	for _, inst in pairs(playing) do
		mp.msg.info("killing server PID " .. inst.pid)
		mp.commandv("run", "kill", inst.pid)
	end
end

mp.add_hook("on_load", 50, check_torrent)
-- mp.add_hook("on_load_fail", 50, check_torrent)

-- mp.register_event("on_load", check_torrent)
mp.register_event("shutdown", cleanup)
-- mp.add_hook("shutdown", cleanup)
