local Tag = "filebrowser"

module(Tag, package.seeall)

local tframe

function ShowTree(callback)
	tframe = vgui.Create("DFrame")
	tframe:SetPos(50, ScrH() / 2)
	tframe:SetSize(310,340)
	tframe:SetTitle("File Browser")
	tframe:SetVisible(true)
	tframe:SetDraggable(true)
	tframe:ShowCloseButton(true)
	tframe:MakePopup()

	local root = vgui.Create("DTree", tframe)
	root:Dock(FILL)
	root.DoClick = function(node)
		local sel = root:GetSelectedItem()
		if not sel:HasChildren() then
			local path = sel:GetFileName()
			if not path or path:find("%.") == nil then return end

			if type(callback) == "function" then
				callback(path)
			end

			tframe:Close()
		end
	end

	local node = root:AddNode("lua")
	local editornode = root:AddNode("editor")
	local stolennode = root:AddNode("stolen")
	local datanode = root:AddNode("data")

	node:MakeFolder("lua", "GAME", true)
	editornode:MakeFolder( "data/lua_editor", "GAME", true )
	stolennode:MakeFolder( "data/interscripts/stolen", "GAME", true )
	datanode:MakeFolder( "data", "GAME", true )
end
