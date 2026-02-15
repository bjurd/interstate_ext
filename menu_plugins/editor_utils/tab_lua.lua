-----------------------------------------------------
local Tag="chatbox"
module(Tag,package.seeall)

local L = function(s) return s end
local RealTime=CurTime

local OpenLoadMenu do
	local function del(place)
		return place..(#place>0 and '/' or "")
	end
	local icons = {
		lua = 'page_code',
		png = 'image',
		jpg = 'image',
		txt = 'page',
		vpk = 'database',
		db  = 'database_edit',
	}
	local Menu
	Menu = function(place,cb,x,y)
			
		local m = DermaMenu()
		
			local back = place:match("^(.+)[\\/].-$") or ""
			if back and place~=back then
				m:AddOption(L"BACK",function()
					timer.Simple(0,function()
						Menu(back,cb,x,y)
					end)
				end):SetImage'icon16/arrow_left.png'
			end

		
			local files,folders = file.Find(del(place)..'*','GAME')
			for k,v in next,folders do
				m:AddOption(v,function()
					timer.Simple(0,function()
						Menu(del(place)..v,cb,x,y)
					end)
				end):SetImage'icon16/folder.png'
			end
			for k,v in next,files do
				local o = m:AddOption(v:gsub("%.txt$",""),function()
					local fp = 	del(place)..v
					cb(fp)
				end)
				local ext = v:match(".+%.(.-)$")
				local t = icons[ext or ""] or 'page_white'
				o:SetImage('icon16/'..t..'.png')
			end
		m:Open()
		if x and y then
		--	m:SetPos(x,y)
		else
			x,y = m:GetPos()
		end
	end
	OpenLoadMenu = Menu
end

------------------------------------------------------
-- Lua Chat Tab
------------------------------------------------------
local PANEL={}

local id = 0 -- Running ID.
local function saveBackup(path, code)
	file.Write(path, code)
	local p = util.RelativePathToFull_Menu('data/'..path)
	print("Backed up to: "..p)
	SetClipboardText(p)
end

local function codename(editor)
	return editor.TabControl:GetActiveTab().Name
end

local buttons= {
	"up",
	"",
	"",
	{L"Client",'icon16/cog_go.png',
		function(code,editor,extra)
			interstate.RunOnClient(code, "[C]"--[[codename(editor)]], true)
		end,
		rightbutton_mode = true,
	},
	{L"Server",'icon16/server.png',
		function(code,editor,extra)
			interstate.RunOnServer(code, codename(editor), true)
		end,
		rightbutton_mode = true,
	},
	{L"Shared",'icon16/world.png',
		function(code,editor,extra)
			interstate.RunOnClient(code, "[C]"--[[codename(editor)]], true)
			interstate.RunOnServer(code, codename(editor), true)
		end,
		rightbutton_mode = true,
	},
	{L"Menu",'icon16/book.png',
		function(code,editor,extra)
			pcall(RunString, code, codename(editor), true)
		end,
		rightbutton_mode = true,
	},
	"",
	{L"Javascript",'icon16/script_gear.png',
		function(code,editor)
			editor.code.HTML:Call(code)
		end
	},
	
	"left",
	"",
	{L"Save",'icon16/script_save.png',
		function(code,editor)
			local path = "lua_editor"
			file.CreateDir(path,'DATA')
			path=path..'/'..os.date'%Y_%m'
			file.CreateDir(path,'DATA')
			
			local filepath
			local menu = DermaMenu()
			menu:AddOption("Name", function()
				Derma_StringRequest("Backup", "Name your backup", "",
				function(str)
					filepath = path.."/"..str..".txt"
					saveBackup(filepath, code)
				end,
				function() end,
				"Confirm", "Cancel")
			end)
			menu:AddOption("No name", function()
				local ver = 0

				while not filepath or file.Exists(filepath,'DATA') and ver<9000 do
					ver= ver + 1
					filepath = path.."/backup"..(ver <= 9 and "0" or "")..""..ver..'.txt'
				end

				saveBackup(filepath, code)
			end)
			menu:Open()
		end
	},
	{L"Load",'icon16/script_edit.png',
		function(code,editor)
			OpenLoadMenu ("data/lua_editor",function(p)
				editor.code:SetCode(file.Read(p,'GAME') or "FAILED LOADING "..tostring(p), p:gsub( "data/lua_editor/", "" ):gsub( "(%.txt)$" ,"" ) )
			end)
		end
	},
	{L"Open",'icon16/folder_explore.png',
		function(code)
			filebrowser.ShowTree()
		end
	},
	"",
	{L"Load URL",'icon16/page_link.png',
		function(code,editor)
			Derma_StringRequest("Load URL",
			"Paste in URL, pastebin and hastebin links are automatically in raw form.","",
			function(url)
				local new_url = url
				new_url = string.gsub(new_url,"pastebin.com/","pastebin.com/raw/")
				new_url = string.gsub(new_url,"hastebin.com/","hastebin.com/raw/")
				--new_url = string.gsub(new_url)
				http.Fetch(new_url,
				function(txt)
					local newtxt = txt
					if newtxt:find("%</html%>") then newtxt = "--[[\nThis URL isn't supported or isn't in raw form\nIf you want another paste site added to whitelist, ask Flex\nIf you just tried to insert HTML code, sorry\n]]--" end
					local url_title = new_url
					url_title = string.gsub(url_title,"(.+)://","")
					url_title = string.gsub(url_title,"%.(.+)/raw/","/")
					url_title = string.gsub(url_title,"","")
					editor.code:SetCode(newtxt,url_title)
					--print("[DEBUG] Loaded URL: "..new_url)
				end,
				function(err)
					MsgN("Error loading URL: "..err)
				end)
			end)
		end
	},
	"",
	{L"pastebin",'icon16/page_link.png',
		function(code,editor)
			local t={
				api_dev_key='df9eb1e9d83f595d31a64e8d03a083ae',
				api_paste_code=code,
				api_option='paste',
				api_paste_format="lua",
				api_paste_private=0,
				api_paste_expire_date='1D',
			}
			local function doit()
				http.Post("http://pastebin.com/api/api_post.php",t,
				function(url,_,head,code)
					MsgN("Paste URL: "..url)
					SetClipboardText(url)
				end,
				function(err)
					MsgN("Pastebin err: "..err)
				end)
			end
			local m = DermaMenu()
			local lengths={
				{"Month","1M"},
				{"Week","1W"},
				{"Day","1D"},
				{"Hour","1H"},
				{"10 Minutes","10M"},
			}
			for k,v in next,lengths do
				m:AddOption(v[1],function()
					t.api_paste_expire_date=v[2]
					doit()
				end)
			end
			
			m:Open()
		end
	},
	--[["",
	{L"Beautify",'icon16/style.png',
		function(code,editor)
			if not util.BeautifyLua then return end
			
			local ok,code2 = pcall(util.BeautifyLua,code)
			editor.code:SetCode(tostring(code2))
		end
	},]]

}
function PANEL:Think()
	if not self._initb then self._initb=true self:InitButtons() end

	if self.nextresize and self.nextresize<RealTime() then
		self.nextresize = false
		local x,y=self.code_imitator:GetPos()
		local w,h=self.code_imitator:GetSize()
		self.code:SetPos(x,y)
		self.code:SetSize(w,h)
	end
end

function PANEL:PerformLayout()
	if not self.nextresize then
		self.nextresize = RealTime()+0.2
	end
end

function PANEL:OnActivatedPanel(prev)
	if IsValid(self.code.HTML) then
		self.code.HTML:RequestFocus()
	end
end

function PANEL:Init()
	self.filename = "chatbox_lua_save.txt"
	
	local code_imitator = vgui.Create("EditablePanel", self)
	code_imitator:Dock(FILL)
	self.code_imitator=code_imitator
	
	self.TabControl = vgui.Create( "lua_editor_TabControl", self )
	self.TabControl:Dock( FILL )
	self.TabControl:SetSkin( "Default" )
	
	local code = self.TabControl:GetEditor()
	self.code = code
	self.Helpers = Helpers
	
	function code.OnCodeChanged(code, msg)
		if not code:GetHasLoaded() then return end
		hook.Run("ChatTextChanged", msg, true)
	end
	
	function code.OnFocus(code,gained)
		if not gained then return end
		self.code.OnCodeChanged(self.code, self.code:GetCode())
	end
		
end

function PANEL:InitButtons()
	-- buttons

	self.container_top_wrapper=vgui.Create('DPanel',self)
		self.container_top_wrapper:SetTall(24)
		self.container_top_wrapper:Dock(TOP)
	
	self.container_top=vgui.Create('DHorizontalScroller',self.container_top_wrapper)
		local container_top=self.container_top
		container_top:Dock(FILL)
	
	local buttons_container=vgui.Create('DScrollPanel',self)
		self.buttons_container = buttons_container
		buttons_container:SetWide(75)
		
		buttons_container.m_bBackground = true
		buttons_container.Paint=function(self,w,h)
			DPanel.Paint(self,w,h)
		end
		
		buttons_container.VBar:SetEnabled(true)
		buttons_container.VBar:Dock(NODOCK)
		buttons_container.VBar:SetSize(1,1)
		buttons_container.VBar:SetPos(0,0)
		buttons_container.VBar.SetEnabled=function()end
		buttons_container.VBar:SetVisible(true)
		
		buttons_container:Dock(LEFT)
		function buttons_container.AddPanel(self,pnl)
			pnl:SetParent(self)
			pnl:Dock(TOP)
			self:AddItem(pnl)
		end
		
	local b = vgui.Create("DButton", container_top)
		b:SetText( L"Menu" )
		b:SetIcon("icon16/application_edit.png")
		b:SetDrawBorder(false)
		b:SetDrawBackground( false )
		
		b.DoClick = function()
			self:OpenMenu1()
		end

		container_top:AddPanel( b )
		


	--local b = vgui.Create("DLabel", buttons_container)
	--	b:SetText( "      "..(L"Run on") )
	--	b:SizeToContents()
	--	buttons_container:AddPanel( b )
	local container = buttons_container
	for _,data in next,buttons do
		if isstring(data) then
		
			if data=="" then
				local b = vgui.Create("EditablePanel", container)
				b:SetSize(16,8)
				b.ApplySchemeSettings=function()end
				container:AddPanel( b )
			elseif data=="-" then
				DMenu.AddSpacer(buttons_container)
			elseif data=="up" then
				container = container_top
			elseif data=="left" then
				container = buttons_container
			else
				error"uh"
			end
			
			continue
		elseif isfunction(data[1]) then
			local f  = data[1]
			if f(data,container,self) then continue end
		end
		
		local b = vgui.Create("DButton", container)

		b:SetText( data[1] )
		b:SetDrawBorder(false)
		b:SetDrawBackground( false )
		
		if data[2] then
			
			b:SetImage( data[2] )
			b.m_Image2=b.m_Image
			b.m_Image=nil
			b.m_Image2:SetPos( 1, (b:GetTall() - b.m_Image2:GetTall()) * 0.5 )
			b:SetTextInset( b.m_Image2:GetWide() + 4, 0 )
			b:SetContentAlignment(4)
		end
		
		local h=b:GetTall()
		b:SizeToContents()
		b:SetTall(h)
		b:SetWide( b:GetWide() + 8 )
		b.DoClick = function()
			data[3](self.code:GetCode(),self)
		end
		b.Paint=function(b,w,h)
			if b.Hovered then
				surface.SetDrawColor(30,30,30,30)
				surface.DrawRect(0,0,w,h)
			end
			derma.SkinHook( "Paint", "Button", b, w, h )
			return false
		end
		
		
		if data[2]=="icon16/cog_go.png" then
			b.Paint=function(b,w,h)
				derma.SkinHook( "Paint", "Button", b, w, h )

				if b.Hovered then
					surface.SetDrawColor(30,30,30,30)
				else
					surface.SetDrawColor(interstate.IsClientValid() and 50 or 255,interstate.IsClientValid() and 255 or 50,20,100)
				end
				surface.DrawRect(0,0,w,h)

				return false
			end
		elseif data[2]=="icon16/server.png" then
			b.Paint=function(b,w,h)
				derma.SkinHook( "Paint", "Button", b, w, h )

				if b.Hovered then
					surface.SetDrawColor(30,30,30,30)
				else
					surface.SetDrawColor(interstate.IsServerValid() and 50 or 255,interstate.IsServerValid() and 255 or 50,20,100)
				end
				surface.DrawRect(0,0,w,h)

				return false
			end
		elseif data[2]=="icon16/world.png" then
			b.Paint=function(b,w,h)
				derma.SkinHook( "Paint", "Button", b, w, h )

				if b.Hovered then
					surface.SetDrawColor(30,30,30,30)
					surface.DrawRect(0,0,w,h)
				else
					if interstate.IsClientValid() and interstate.IsServerValid() then
						surface.SetDrawColor(50, 255, 20, 100)
					elseif interstate.IsClientValid() and not interstate.IsServerValid() then
						surface.SetDrawColor(255, 255, 20, 100)
					else
						surface.SetDrawColor(255, 50, 20, 100)
					end
				end
				surface.DrawRect(0,0,w,h)

				return false
			end
		end

		container:AddPanel( b )
	end
end

function PANEL:OpenMenu1()
	local m =DermaMenu()
	
	m:AddOption(L"Configure",function()
		self.code:ShowMenu()
	end)
	
	m:AddOption((L'Toggle left panel'),function()
		self.buttons_container:GetParent():InvalidateLayout()
		self.buttons_container:SetVisible(not self.buttons_container:IsVisible())
	end)
	
	m:AddOption(L"Show Help",function()
		self.code:ShowBinds()
	end)
	
	do
		local m=m:AddSubMenu("Fix")
			m:AddOption(L"Reopen URL",function()
				self.code:LoadURL()
			end)
			m:AddOption(L"Reload",function()
				self.code:ReloadPage()
			end)
			m:AddOption(L"Reload (empty cache)",function()
				self.code:ReloadPage(true)
			end)
			
	end
	
	do
		local m=m:AddSubMenu("Mode")
		
		for _,name in pairs(self.code.Modes) do
			local txt= name:sub(1,1):upper()..name:sub(2):gsub("_"," ")
			m:AddOption(txt,function()
				self.code:SetMode(name)
			end)
		end
		
	end
	
	do
		local m=m:AddSubMenu("Theme")
		
		for _,name in pairs(self.code.Themes) do
			local txt= name:sub(1,1):upper()..name:sub(2):gsub("_"," ")
			local cb = function()
				self.code:SetTheme(name)
			end
			
			local a = m:AddOption(txt,cb)
			local a_OnMousePressed = a.OnMousePressed
			function a.OnMousePressed( a, mousecode )
				cb()
				return a_OnMousePressed(a,mousecode)
			end
				
		end
		
	end
	
	do
		local m=m:AddSubMenu("Font Size")
		
		for i=9,24 do
			local txt= i..' px'
			m:AddOption(txt,function()
				self.code:SetFontSize(i)
			end)
		end
		
	end

	m:Open()
end

vgui.Register( Tag..'_lua', PANEL, "EditablePanel" )