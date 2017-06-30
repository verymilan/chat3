-- chat3/init.lua

chat3 = {}

-- [function] Get setting
local function get(key)
	if minetest.settings then
		return minetest.settings:get(key)
	else
		return minetest.setting_get(key)
	end
end

-- [function] Get float setting
local function get_int(key)
	local res = get(key)
	if res then
		return tonumber(res)
	end
end

-- [function] Get boolean setting
local function get_bool(key)
	if minetest.settings then
		return minetest.settings:get_bool(key)
	else
		return minetest.setting_getbool(key)
	end
end

local bell   = get_bool("chat3.bell")
local shout  = get_bool("chat3.shout")
local prefix = get("chat3.shout_prefix") or "!"
local near   = get_int("chat3.near")     or 12

if prefix:len() > 1 then
	prefix = "!"
end

-- [function] Colorize
local function colorize(prot, colour, msg)
	if prot and prot >= 27 then
		return minetest.colorize(colour, msg)
	else
		return msg
	end
end

local prot = {}
-- [event] On join player
minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local info = minetest.get_player_information(name)
	prot[name] = info.protocol_version
end)

-- [function] Process
function chat3.send(name, msg, prefix, source)
	if minetest.get_modpath("ranks") and source ~= "ranks" then
		return
	end

	local sender = minetest.get_player_by_name(name)

	for _, player in pairs(minetest.get_connected_players()) do
		local rname  = player:get_player_name()
		local colour = "#ffffff"

		local vers = prot[rname]
		if not vers or (vers and (vers >= 29 or (vers < 29 and name ~= rname))) then
			-- Check for near
			if near ~= 0 then -- and name ~= rname then
				if vector.distance(sender:getpos(), player:getpos()) <= near then
					colour = "#88ffff"
				end
			end

			-- Check for mentionsfloat
			if msg:lower():find(rname:lower(), 1, true) then
				colour = "#00ff00"

				-- Chat bell
				if bell and name ~= rname then
					local pbell = player:get_attribute("chat3:bell")
					if pbell ~= "false" then
						minetest.sound_play("chat3_bell", {
							gain = 4,
							to_player = rname,
						})
					end
				end
			end

			-- Check for shout
			if shout and msg:sub(1, 1) == prefix then
				colour = "#ff0000"

				-- Chat bell
				if bell and name ~= rname then
					local pbell = player:get_attribute("chat3:bell")
					if pbell ~= "false" then
						minetest.sound_play("chat3_bell", {
							gain = 4,
							to_player = rname,
						})
					end
				end
			end

			-- if same player, set to white
			if name == rname then
				colour = "#ffffff"
			end

			-- Send message
			local send = colorize(vers, colour, "<"..name.."> "..msg)
			if prefix then
				send = prefix..send
			end

			minetest.chat_send_player(rname, send)
		end
	end

	-- Log message
	minetest.log("action", "CHAT: ".."<"..name.."> "..msg)

	-- Prevent from sending normally
	return true
end

-- [event] On chat message
minetest.register_on_chat_message(function(name, msg)
	return chat3.send(name, msg)
end)

-- [redefine] /msg
if minetest.chatcommands["msg"] then
	local old_command = minetest.chatcommands["msg"].func
	minetest.override_chatcommand("msg", {
		func = function(name, param)
			local sendto, message = param:match("^(%S+)%s(.+)$")
			if not sendto then
				return false, "Invalid usage, see /help msg."
			end
			if not core.get_player_by_name(sendto) then
				return false, "The player " .. sendto
						.. " is not online."
			end
			minetest.log("action", "PM from " .. name .. " to " .. sendto
					.. ": " .. message)
			minetest.chat_send_player(sendto, minetest.colorize('#00ff00', "PM from " .. name .. ": "
					.. message))

			if bell then
				local player = minetest.get_player_by_name(sendto)
				local pbell = player:get_attribute("chat3:bell")
				if pbell ~= "false" then
					minetest.sound_play("chat3_bell", {
						gain = 4,
						to_player = sendto,
					})
				end
			end

			return true, "Message sent."
		end,
	})
end

-- [chatcommand] Chatbell
if bell then
	minetest.register_chatcommand("chatbell", {
		description = "Enable/disable chatbell when you are mentioned in the chat",
		func = function(name)
			local player = minetest.get_player_by_name(name)
			if player then
				local bell = player:get_attribute("chat3:bell")
				if not bell or bell == "" or bell == "true" then
					player:set_attribute("chat3:bell", "false")
					return true, "Disabled Chatbell"
				else
					player:set_attribute("chat3:bell", "true")
					return true, "Enabled Chatbell"
				end
			end
		end,
	})
end
