shellquote = function(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- gets the info hash or torrent filename for use as the mount directory name
local parse_url = function(url)
	return url:match("^magnet:.*[?&]xt=urn:bt[im]h:([a-zA-Z0-9]*)&?") == 1
		or url:gsub("[?#].*", "", 1):match("/([^/]+%.torrent)$") == 1
end

mp.add_hook("on_load", 11, function()
	local url = mp.get_property("stream-open-filename")
	if not url then
		return
	end

	local dirname = parse_url(url)
	if not dirname then
		return
	end

	mp.set_property("file-local-options/force-media-title", files[1]:match("[^/]+$"))
	mp.set_property("stream-open-filename", "file://" .. files[1])
end)

mp.register_event("shutdown", function() end)
