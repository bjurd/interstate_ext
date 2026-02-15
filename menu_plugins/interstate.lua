--if true then return end
require"hninterstate"

include"menu_plugins/editor_utils/filebrowser.lua"
include"menu_plugins/editor_utils/lua_editor.lua"
include"menu_plugins/editor_utils/lua_editor_panels.lua"
include"menu_plugins/editor_utils/tab_lua.lua"
require"json"

menup.options.addOption("interstate","autorun","proxi.lua")
menup.options.addOption("interstate","overrides","false")
menup.options.addOption("interstate","run before autorun","true")
menup.options.addOption("interstate","steal","false")
menup.options.addOption("interstate","block remote lua","false")

local javascript_escape_replacements = {
	["\\"] = "\\\\",
	["\0"] = "\\0" ,
	["\b"] = "\\b" ,
	["\t"] = "\\t" ,
	["\n"] = "\\n" ,
	["\v"] = "\\v" ,
	["\f"] = "\\f" ,
	["\r"] = "\\r" ,
	["\""] = "\\\"",
	["\'"] = "\\\'"
}

function string.JavascriptSafe( str )
	str = str:gsub( ".", javascript_escape_replacements )

	-- U+2028 and U+2029 are treated as line separators in JavaScript, handle separately as they aren't single-byte
	str = str:gsub( "\226\128\168", "\\\226\128\168" )
	str = str:gsub( "\226\128\169", "\\\226\128\169" )

	return str
end

concommand.Add("interstate_editor", function()
	if chatgui and chatgui.Lua and IsValid(chatgui.Lua) then
		chatgui.Lua:GetParent():MakePopup()
		return
	end

	chatgui = chatgui or {}

	local f = vgui.Create("DFrame")
	f:SetSize(ScrW() * .75, ScrH() * .75)
	f:Center()
	f:SetSizable(true)
	f:MakePopup()

	f.btnMaxim:SetDisabled(false)
	function f.btnMaxim:DoClick()
		if not f.max then
			f.max = true
			f.lastx, f.lasty = f:GetPos()

			f:SetPos(0,0)
			f:SetSize(ScrW(),ScrH())
			f:SetDraggable(false)
		else
			f.max = false
			f:SetPos(f.lastx, f.lasty)
			f:SetSize(ScrW() * .75, ScrH() * .75)
			f:SetDraggable(true)
		end
	end

	chatgui.Lua = vgui.Create("chatbox_lua", f)
	chatgui.Lua:Dock(FILL)
end)

concommand.Add("interstate_openscript_cl", function(_,_,args,argstring)
	if not interstate.IsClientValid() then Msg"Not in Game\n" return end
	if not args or #args == 0 then return end
	if not file.Exists("lua/" .. args[1], "GAME") then
		Msg("File not found " .. args[1] .. "...\n")
		return
	end
	if file.IsDir("lua/" .. args[1], "GAME") then
		Msg("File is directory " .. args[1] .. "...\n")
		return
	end

	MsgC(color_white,"Running script " .. args[1] .. "...\n")

	interstate.RunOnClient(file.Read(string.format("lua/%s", args[1]), "GAME"), args[2] or "[C]", true)
end, function(cmd,args)
	-- remove space char at args[0]
	args = args:sub(2)

	-- get shit after the last forward slash
	local a = args:find("/[%w%s%._]*$")
	local path = args:sub(0, a)
	local filename = args:sub(#path + 1)

	-- get all files and dirs, put them into one table
	local files, dirs = file.Find(string.format("lua/%s*", path), "GAME")
	local all_files = {}
	table.Add(all_files, files) table.Add(all_files, dirs)

	-- no first slash yet, use path as filename
	if filename == "" and not path:find"/" then
		filename = path
		path = ""
	end

	local auto = {}

	-- populate auto table
	if not table.IsEmpty(dirs) then
		for k, v in next, dirs do
			if v:find(filename) then
				table.insert(auto, string.format("%s %s%s", cmd, path, v))
			end
		end
	end
	if not table.IsEmpty(files) then
		for k, v in next, files do
			if v:find(filename) then
				table.insert(auto, string.format("%s %s%s", cmd, path, v))
			end
		end
	end

	-- i have to do this, or the last result is stripped off.
	table.insert(auto, "shouldn't see this")

	return auto
end)

concommand.Add("interstate_run_cl", function(_,_,args,argstring)
	if not interstate.IsClientValid() then Msg"Not in Game\n" return end

	interstate.RunOnClient(argstring,"[C]",true)
end)

concommand.Add("interstate_require_cl", function(_,_,args,argstring)
	if not interstate.IsClientValid() then Msg"Not in Game\n" return end

	local first, last = argstring:find("_(.+)_")
	local name = argstring:sub(first + 1, last - 1)

	interstate.RequireOnClient(name)
end, function(cmd, args)
	-- remove space char at args[0]
	args = args:sub(2)

	-- get shit after the last forward slash
	local a = args:find("/[%w%s%._]*$")
	local path = args:sub(0, a)
	local filename = args:sub(#path + 1)

	-- get all files and dirs, put them into one table
	local files = file.Find(string.format("lua/bin/%s*", path), "GAME")

	-- no first slash yet, use path as filename
	if filename == "" and not path:find"/" then
		filename = path
		path = ""
	end

	local auto = {}

	if not table.IsEmpty(files) then
		for k, v in next, files do
			if v:find(filename) then
				table.insert(auto, string.format("%s %s%s", cmd, path, v))
			end
		end
	end

	-- i have to do this, or the last result is stripped off.
	table.insert(auto, "shouldn't see this")

	return auto
end)

local append = {
	Startup = true,
	RunString = true,
	LuaCmd = true,
	["[C]"] = true,
}
local ignore_src = {
	["lua/%.dragondildos/rc1/%.%./nul/(.+)%.lua"] = function(src, code)
		--print(src, code)
		if code == "local badDragon = \"DRAGON DILDOS\"\nbadDragon()" then return end
		local id = src:StripExtension():GetFileFromFilename()
		print(id, code)
	end,
	["_yee.lua"] = print,
	--[[["yugh/extensions/client/derma%.lua"] = function(src, code)
		print("HELLO!!!!!!!!!!!!!!!!!")
		print(src, code)
	end]]
}

local function dump(name, src)
	if name:lower():find"gamemodes/base/" then return end
	if name == "interstate_client" then return end
	for k,v in next, ignore_src do
		if name:find(k) then
			if isfunction(v) then
				v(name, src)
			end

			return
		end
	end

	local path = "interscripts/stolen/" .. interstate.ip

	if not file.Exists(path, "DATA") then
		file.CreateDir(path)
	end

	if append[name] then -- append code to file
		file.Append(path .. "/" .. name .. ".txt", "\r\n" .. ("="):rep(20) .. "\r\n" ..  src)
	else -- overwrite file entirely
		local garbage = {}

		for i = 1, #name do
			if name[i] == "/" then
				garbage[#garbage + 1] = i
			end
		end

		if #garbage > 1 then
			local str = name

			for i = 1, #garbage do
				file.CreateDir("interscripts/stolen/" .. interstate.ip .. "/" .. string.sub(str, 1, garbage[i] - 1))
			end
		end
		file.Write(path .. "/" .. name .. ".txt", src)
	end
end

local ran = {}
local first = true
local was_cookie = false
hook.Add("RunOnClient", "interstate", function(name, src)
	if tobool(menup.options.getOption("interstate","block remote lua")) and name == "LuaCmd" then print("BLOCKED LUACMD", src) return "" end

	if src:find("while true do end") then print("shitty crash attempt") return src:gsub("while true do end","--[[ crash attempt ]]") end
	if ran[name] then return end

	if was_cookie then
		interstate.RunOnClient([[cookie.Delete("snoop_dogg_weps")]])
		was_cookie = false
	end
	if name:find"cookie.lua" then
		was_cookie = true
	end

	ran[name] = true
	if first then
		interstate.ip = interstate.GetIP():gsub(":", "-")

		first = false

		if tobool(menup.options.getOption("interstate","run before autorun")) then
			local autorun = menup.options.getOption("interstate","autorun")
			if not autorun or autorun == "unset" or autorun == "" then return end

			if file.Exists("lua/" .. autorun, "GAME") then
				interstate.RunOnClient(file.Read("lua/" .. autorun, "GAME"), autorun, true)
			end
		end

		return
	end
	if tobool(menup.options.getOption("interstate","steal")) and interstate.ip ~= "loopback" then
		dump(name, src)
	end
	if tobool(menup.options.getOption("interstate","overrides")) then
		return file.Read("interscripts/overrides/" .. name, "DATA") or src
	end
end)

hook.Add("LuaStateCreated", "interstate", function(type)
	if type == 0 then
		file.Delete("wiremod_icon.jpg")
	end
end)

hook.Add("LuaStateClosed", "interstate", function(type)
	if type == 0 then
		table.Empty(ran)
		first = true
		was_cookie = false
	end
end)
