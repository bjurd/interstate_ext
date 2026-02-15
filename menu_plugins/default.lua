--loads default menu plugins
local Files = file.Find("lua/menu_plugins/default/*.lua", "GAME")
for k, fil in next, Files do
	menup.include("default/"..fil)
end
