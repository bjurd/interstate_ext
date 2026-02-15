menup.options = {}
local options = {}

local prfx = "menup_"
function menup.options.addOption(plugin, option, default)
	options[plugin] = options[plugin] or {}
	options[plugin][option] = {}

	if menup.options.getOption(plugin, option) == "unset" then
		menup.options.setOption(plugin, option, default)
	end
end
function menup.options.setOption(plugin, option, value)
	cookie.Set(prfx..plugin.."_"..option, value)

	if _G.interstate.IsClientValid() and tobool(menup.options.getOption("interstate","client value callbacks")) then
		local Codens = string.format([[
			local GAMEMODE = GM or GAMEMODE
			if not GAMEMODE then
				if not not istable(gmod) or not isfunction(gmod.GetGamemode) then
					return
				end

				GAMEMODE = gmod.GetGamemode()
			end
			if not GAMEMODE then
				return
			end

			if istable(hook) and isfunction(hook.Call) then
				hook.Call("InterstateOptionChanged", GAMEMODE, "%s", "%s", "%s")
			end
		]], plugin, option, value)

		_G.interstate.RunOnClient(Codens, "[C]")
	end

	if tobool(menup.options.getOption("interstate","menu value callbacks")) then
		hook.Call("InterstateOptionChanged", nil, plugin, option, value)
	end
end
function menup.options.getOption(plugin, option)
	return cookie.GetString(prfx..plugin.."_"..option, "unset")
end

local function setOption(ply, cmd, args)
	menup.options.setOption(args[1], args[2], args[3])
end
concommand.Add("menup_setOption", setOption, nil, "Set a menu state option; Format: <plugin> <option> <value>")

local function spewOptions()
	for plugin, tab in next, options do
		print(plugin..": ")
		for option, _ in next, tab do
			print("\t"..option..":\t"..menup.options.getOption(plugin, option))
		end
	end
end
concommand.Add("menup_spewOptions", spewOptions, nil, "Spew all menu state options")

function menup.options.getTable()
	return options
end
