local interstate = _G.interstate

if not interstate then
	if util.IsBinaryModuleInstalled("hninterstate") then
		require"hninterstate"
	else
		MsgC(Color(196,0,0), "hninterstate not installed\n")
		return
	end
end

--if not gameevent then
--	if util.IsBinaryModuleInstalled("gameevent") then
--		require("gameevent")
--	else
--		MsgC(Color(196,0,0), "gameevent not installed, interstate will crash on quit\n")
--	end
--end

-- FindMetaTable"Panel".PostMessage = FindMetaTable"Panel".PostMessage or function(...)
-- 	if not PANELPostMessage then return end

-- 	return PANELPostMessage(...)
-- end

-- FindMetaTable"Panel".ActionSignal = FindMetaTable"Panel".ActionSignal or function(...)
-- 	if not PANELActionSignal then return end

-- 	return PANELActionSignal(...)
-- end
-- FindMetaTable"Panel".SetPaintFunction = FindMetaTable"Panel".SetPaintFunction or function(...)
-- 	if not PANELSetPaintFunction then return end

-- 	return PANELSetPaintFunction(...)
-- end


menup.include("interstate/bframe.lua")
menup.include("interstate/code_editor.lua")
--include"menu_plugins/interstate/filebrowser.lua"
--include"menu_plugins/interstate/lua_editor.lua"
--include"menu_plugins/interstate/lua_editor_panels.lua"
--include"menu_plugins/interstate/tab_lua.lua"
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
	if IsValid(interstate.frame) then
		interstate.frame:MakePopup()
		return
	end

	local f = vgui.Create("BFrame")
	interstate.frame = f
	f:SetTitle("interstate editor")
	f:SetSize(ScrW() * .75, ScrH() * .75)
	f:Center()
	f:SetSizable(true)
	f:MakePopup()

	function f:ToggleMinimize()
		if self.BFrame.IsMaximized then
			self:_ToggleMaximize()
		end

		if not f.m_bMinimized then
			f.m_bMinimized = true

			f.lasth = f:GetTall()
			f:SetTall(24)
			--f:SetLockVerticalSizing(true)
			f:SetMinHeight(24)
		else
			f.m_bMinimized = false

			f:SetTall(f.lasth)
			--f:SetLockVerticalSizing(false)
			f:SetMinHeight(50)
		end
	end

	function f:_ToggleMaximize()
		if self.BFrame.IsMinimized then
			self:ToggleMinimize()
		end

		self:_ToggleMaximize()
	end

	function f:Minimize()
		if self.BFrame.IsMinimized then
			self:Restore()
		else
			self:ToggleMinimize()
		end
	end

	-- f._Restore = f.Restore
	-- function f:Restore()
	-- 	--


	-- 	self:_Restore()
	-- end

	-- minimize button
	f.btnMinim:SetEnabled(true)
	f.btnMinim.DoClick = function()
		f:ToggleMinimize()
	end

	local editor = vgui.Create("ECLuaTab", f)
	interstate.editor = editor
	editor:Dock(FILL)
end, nil, nil, { FCVAR_DONTRECORD })

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

	-- no first slash yet, use path as filename
	if filename == "" and not path:find"/" then
		filename = path
		path = ""
	end

	local auto = {}

	-- populate auto table
	if istable(dirs) and not table.IsEmpty(dirs) then
		for k, v in next, dirs do
			if v:find(filename) then
				table.insert(auto, string.format("%s %s%s", cmd, path, v))
			end
		end
	end
	if istable(files) and not table.IsEmpty(files) then
		for k, v in next, files do
			if v:find(filename) then
				table.insert(auto, string.format("%s %s%s", cmd, path, v))
			end
		end
	end

	-- i have to do this, or the last result is stripped off.
	table.insert(auto, "shouldn't see this")

	return auto
end, nil, { FCVAR_DONTRECORD })

concommand.Add("interstate_run_cl", function(_,_,args,argstring)
	if not interstate.IsClientValid() then Msg"Not in Game\n" return end

	interstate.RunOnClient(argstring,"[C]",true)
end, nil, nil, { FCVAR_DONTRECORD })

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
end, nil, { FCVAR_DONTRECORD })

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

local charwhitelist = {}

for i = ("a"):byte(), ("z"):byte() do
	charwhitelist[string.char(i)] = i
end

for i = ("A"):byte(), ("Z"):byte() do
	charwhitelist[string.char(i)] = i
end

for i = ("0"):byte(), ("9"):byte() do
	charwhitelist[string.char(i)] = i
end

charwhitelist["."] = string.byte(".")
charwhitelist["%"] = string.byte("%")
charwhitelist["/"] = string.byte("/")
charwhitelist["_"] = string.byte("_")
charwhitelist["-"] = string.byte("-")
charwhitelist["+"] = string.byte("+")
charwhitelist["="] = string.byte("=")

local ValidDirPaths = {
	["lua"] = true,
	["addons"] = true,
	["gamemodes"] = true
}

local reserved = {"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"}

local function FilePathValid(k)
	local _k = ""

	for i = 1, #k do
		local char = string.sub(k, i, i)

		if not charwhitelist[char] then
			char = "%" .. string.byte(char)
		end

		_k = _k .. char
	end

	k = _k
	local folders = string.Explode("/", k)

	if folders[1] and ValidDirPaths[folders[1]] then
		local extension = string.match(k, "^.+(%..+)$")

		if extension ~= nil then
			k = string.sub(k, 1, #k - #extension)
		end
	end

	--k = string.Replace(k, ".", "_")
	if not k:EndsWith(".lua") then
		k = k .. ".lua"
	end
	k = string.Replace(k, "..", "_")
	k = string.Replace(k, "\\", "_")
	k = string.Replace(k, "//", "_")

	if not gaceio then
		k = k .. ".txt"
	end

	for i = 1, #reserved do
		k = k:lower():gsub(reserved[i]:lower(), "_" .. reserved[i])
	end

	return k
end

local function dump(name, src)
	--if name:lower():find"gamemodes/base/" then return end
	--if name == "interstate_client" then return end
	for k,v in next, ignore_src do
		if name:find(k) then
			if isfunction(v) then
				v(name, src)
			end

			return
		end
	end

	local strFilePath = Format("interscripts/stolen/%s/%s", interstate.ip, FilePathValid(name))

	-- create dir if it doesnt exist
	if not file.Exists(strFilePath, "DATA") then
		local folders = string.Explode("/", strFilePath:GetPathFromFilename())

		if #folders > 0 then
			--table.remove(folders, #folders)
			local lastfolder = ""

			for i = 1, #folders do
				local folder = folders[i]
				lastfolder = lastfolder .. (i ~= 1 and "/" or "") .. folder

				if not file.Exists(lastfolder, "DATA") then
					file.CreateDir(lastfolder)
				end
			end
		end
	end

	if append[name] then -- append code to file
		file.Append(strFilePath, "\r\n" .. ("="):rep(20) .. "\r\n" ..  src)
	else -- overwrite file entirely
		file.Write(strFilePath, src)
	end
end

local first = true
hook.Add("RunOnClient", "interstate", function(name, src)
	if tobool(menup.options.getOption("interstate","block remote lua")) and name == "LuaCmd" then print("BLOCKED LUACMD", src) return "" end

	if tobool(menup.options.getOption("interstate","steal")) and interstate.ip ~= "loopback" then
		dump(name, src)
	end
	if tobool(menup.options.getOption("interstate","overrides")) and file.Exists("interscripts/overrides/" .. name, "DATA") then
		return file.Read("interscripts/overrides/" .. name, "DATA") or src
	end

	if first then
		first = false

		if tobool(menup.options.getOption("interstate","run before autorun")) then
			local autorun = menup.options.getOption("interstate","autorun")
			if not autorun or autorun == "" then return end

			if file.Exists("lua/" .. autorun, "GAME") then
				interstate.RunOnClient(file.Read("lua/" .. autorun, "GAME"), autorun, true)
			end
		end

		return
	end
end)

hook.Add("LuaStateCreated", "interstate", function(type)
	if type == 0 then
		interstate.ip = interstate.GetIP():gsub(":", "-")
	end
end)

hook.Add("LuaStateClosed", "interstate", function(type)
	if type == 0 then
		first = true
		interstate.ip = nil
	end
end)
