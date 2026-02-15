local Lime = Color(127, 255, 0,   255)
local Aquamarine = Color(127, 255, 212, 255)
local LightBlue  = Color(72,  209, 204, 255)
local Red = Color(255, 100, 100, 255)

-- TODO: Improve startup banner, it's not fancy enough
local message =
{
	"+-------------------oOo-------------------+",
	"|~ ~ ~ ~ ~ Print this if you are ~ ~ ~ ~ ~|",
	"|~ ~ ~  a beautiful strong lua script  ~ ~|",
	"|~ ~ who is about to load menu plugins ~ ~|",
	"+-------------------oOo-------------------+",
}

local longest = 0
for k, v in next, message do
	if string.len(v) > longest then
		longest = string.len(v)
	end
end

MsgN()

for k, line in next, message do
	for i=1, line:len() do
		local hue = ((i-1) / longest) * 360
		MsgC(HSVToColor(hue, 0.375, 1), line:sub(i, i))
	end
	MsgN()
end

MsgN()

--- @type MenuPlugins
--- @diagnostic disable-next-line: lowercase-global, missing-fields
menup = {} -- We will store menu plugin functions/vars here

function RunFile(Path)
	local Code = file.Read(Path, "GAME")
	--interstate.RunOnMenu(Code, Path)
	RunString(Code, Path)
end

local function IsWorkshopPlugin(File)
	local MenuPlugins = file.Exists("lua/menu_plugins/" .. File, "WORKSHOP")
	local Modules = file.Exists("lua/menu_plugins/modules/" .. File, "WORKSHOP")

	return MenuPlugins or Modules
end

local Files = file.Find("lua/menu_plugins/modules/*.lua", "GAME")
for k, fil in next, Files do
	if fil == "init.lua" then continue end

	if IsWorkshopPlugin(fil) then
		MsgC(Red, "Not loading workshop module ")
		MsgC(Lime, fil)
		MsgC(Aquamarine, " ...\n")

		continue
	end

	MsgC(Aquamarine, "Loading module ")
	MsgC(Lime, fil)
	MsgC(Aquamarine, " ...\n")

	-- include("menu_plugins/modules/"..fil)
	local Path = "lua/menu_plugins/modules/" .. fil
	RunFile(Path)
end

Files = file.Find("lua/menu_plugins/*.lua", "GAME")
for k, fil in next, Files do
	if fil == "init.lua" then continue end

	if IsWorkshopPlugin(fil) then
		MsgC(Red, "Not loading workshop module ")
		MsgC(Lime, fil)
		MsgC(Aquamarine, " ...\n")

		continue
	end

	MsgC(Aquamarine, "Loading module ")
	MsgC(Lime, fil)
	MsgC(Aquamarine, " ...\n")

	menup.include(fil)
end

MsgC(LightBlue, "\nAll menu plugins loaded!\n\n")

hook.Add("DrawOverlay", "MenuVGUIReady", function()
	hook.Run("MenuVGUIReady")
	hook.Remove("DrawOverlay", "MenuVGUIReady")
end)
