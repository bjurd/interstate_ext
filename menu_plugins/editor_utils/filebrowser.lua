
-----------------------------------------------------
local Tag='filebrowser'

module(Tag, package.seeall)

local toExpand
local tframe

function LoadFile(path)
	local contents = file.Read(path, true)
	if not contents then
		print("File",path,"does not exist")
		return
	end
	path = string.find( path, "data/lua_editor/" ) and path:gsub( "data/lua_editor/", "" ):gsub( "(%.txt)$", "" ) or path
	
	chatgui.Lua.code:SetCode( contents, path )
end

function ShowTree()
	tframe = vgui.Create("DFrame")
	tframe:SetPos(50, ScrH()/2)
	tframe:SetSize(310,340)
	tframe:SetTitle("File Browser")
	tframe:SetVisible(true)
	tframe:SetDraggable(true)
	tframe:ShowCloseButton(true)
	tframe:MakePopup()
	
	local root = vgui.Create("DTree", tframe)
	root:Dock(FILL)
	root.DoClick = function()
		local sel = root:GetSelectedItem()
		if not sel:HasChildren() then
			local path = ""
			local parent = sel:GetParentNode()
			local keepgoing = true
			while keepgoing do
				if not parent or not parent.Label then
					path = string.sub(path,2)
					break
				end
				path = parent.Label:GetText() .. (#path > 0 and "/" or "") .. path
				parent = parent:GetParentNode()
			end
			path = path .. "/" .. sel.Label:GetText()
			if path:find("%.") == nil then return end
			LoadFile(path)
			tframe:Close()
		end
	end
	local node = root:AddNode("lua")
	local datanode = root:AddNode("data")
	
	node:MakeFolder("lua","GAME", true)
	datanode:MakeFolder( "data","GAME", true )
end