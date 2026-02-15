if not CLIENT then return end

require("luacheck")
include("menu_plugins/interstate/filebrowser.lua")
--local luadev = include("luadev_compat.lua")

local blue_color = Color(0, 122, 204)
local green_color = Color(141, 210, 138)
local red_color = Color(255, 0, 0)
local orange_color = Color(255, 165, 0)
local gray_color = Color(75, 75, 75)

local ExecutionCallbacks = {
	{
		name = "client",
		icon = "icon16/cog_go.png",
		callback = function(self, code)
			interstate.RunOnClient(code, "[C]", true)
		end,
		check = interstate.IsClientValid,
	},
	{
		name = "shared",
		icon = "icon16/world.png",
		callback = function(self, code)
			if interstate.IsClientValid() then interstate.RunOnClient(code, "[C]", true) end
			if interstate.IsServerValid() then interstate.RunOnServer(code, "[C]", true) end
		end
	},
	{
		name = "server",
		icon = "icon16/server.png",
		callback = function(self, code)
			interstate.RunOnServer(code, "[C]", true)
		end,
		check = interstate.IsServerValid
	},
	{
		name = "menu",
		icon = "icon16/book.png",
		callback = function(self, code)
			RunString(code, "[C]")
		end
	},
	{
		name = "javascript",
		icon = "icon16/script_code.png",
		callback = function(self, code)
			--
		end
	},
}

local EasyChat = {
	TabColor = Color(67,69,71),
	TabOutlineColor = Color(0,0,255),

	CanUseCEFFeatures = function()
		return system.IsWindows() or jit.arch == "x64"
	end
}

local PANEL = {}

local EDITOR_URL = "metastruct.github.io/gmod-monaco"

PANEL.SaveDir = "lua_editor/"
PANEL.Loaded = false

PANEL.ClosedTabHistory = {}
PANEL.LastAction = {
	Script = "",
	Action = "",
	Realm = "",
	Time = ""
}

PANEL.Env = "client"

function PANEL:Init()
	self.MenuBar = self:Add("DMenuBar")
	self.MenuBar:Dock(NODOCK)
	self.MenuBar:DockPadding(5, 0, 0, 0)
	self.MenuBar.Paint = function(self, w, h)
		surface.SetDrawColor(EasyChat.TabColor)
		surface.DrawRect(0, 0, w, h)
	end

	local options = {}

	self.MenuFile = self.MenuBar:AddMenu("File")
	table.insert(options, self.MenuFile:AddOption("New (Ctrl + N)", function() self:UserInput_NewTab() end))
	table.insert(options, self.MenuFile:AddOption("Close Current (Ctrl + W)", function() self:CloseCurrentTab() end))

	table.insert(options, self.MenuFile:AddOption("Load File (Ctrl + O)", function() self:OpenFileBrowser() end))
	table.insert(options, self.MenuFile:AddOption("Save (Ctrl + S)", function() self:SaveCurrentEditor() end))
	table.insert(options, self.MenuFile:AddOption("Save As... (Ctrl + Shift + S)", function()
		Derma_StringRequest("Save As...", "Enter the file name to save as", "", function(name)
			self:SaveCurrentEditor(name)
		end)
	end))
	self.MenuFile:AddSpacer()
	table.insert(options, self.MenuFile:AddOption("Settings"))

	self.MenuEdit = self.MenuBar:AddMenu("Edit")
	table.insert(options, self.MenuEdit:AddOption("Rename Current (F2)", function() self:RenameCurrentTab() end))

	self.MenuTools = self.MenuBar:AddMenu("Tools")
	table.insert(options, self.MenuTools:AddOption("Upload to Pastebin", function() self:UploadCodeToPastebin() end))
	table.insert(options, self.MenuTools:AddOption("Load Code from URL", function() self:LoadCodeFromURL() end))
	--table.insert(options, self.MenuTools:AddOption("Send Code", function()
	--	timer.Simple(0, function() self:SendCode() end)
	--end))

	self.EnvSelector = self.MenuBar:Add("DComboBox")
	self.EnvSelector:SetSize(100, 20)
	self.EnvSelector:SetPos(200, 5)
	self.EnvSelector:SetSortItems(false)
	self.EnvSelector:SetTextColor(color_white)

	for i, data in pairs(ExecutionCallbacks) do
		self.EnvSelector:AddChoice(data.name, nil, i == 1, data.icon)
	end

	self.EnvSelector.OnSelect = function(_, id, value)
		local data = self.EnvSelector:GetOptionData(id)
		self.Env = data or value
	end

	self.RunButton = self.MenuBar:Add("DButton")
	self.RunButton:SetText("")
	self.RunButton:SetTextColor(color_white)
	self.RunButton:SetSize(40, 10)
	self.RunButton:SetPos(300, 5)
	self.RunButton.DoClick = function() self:RunCode() end

	local function menu_paint(self, w, h)
		surface.SetDrawColor(gray_color)
		surface.DrawRect(0, 0, w, h)
	end

	local function option_paint(self, w, h)
		if self:IsHovered() then
			surface.SetDrawColor(color_white)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
	end

	local function menu_button_paint(self, w, h)
		if self:IsHovered() then
			surface.SetDrawColor(gray_color)
			surface.DrawRect(0, 0, w, h)
		end
	end

	local function combo_box_paint(_, w, h)
		surface.SetDrawColor(color_white)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local drop_triangle = {
		{ x = 10, y = 3 },
		{ x = 5, y = 12 },
		{ x = 0, y = 3 },
	}
	local function drop_button_paint()
		surface.SetDrawColor(color_white)
		draw.NoTexture()
		surface.DrawPoly(drop_triangle)
	end

	self.MenuFile.Paint = menu_paint
	self.MenuEdit.Paint = menu_paint
	self.MenuTools.Paint = menu_paint
	self.EnvSelector.Paint = menu_paint

	for _, option in ipairs(options) do
		option:SetTextColor(color_white)
		option.Paint = option_paint
	end

	-- menu bar buttons changes
	for _, panel in pairs(self.MenuBar:GetChildren()) do
		if panel.ClassName == "DButton" then
			panel:SetTextColor(color_white)
			panel:SetSize(50, 25)
			panel.Paint = menu_button_paint
		end
	end

	local run_triangle = {
		{ x = 10, y = 15 },
		{ x = 10, y = 5 },
		{ x = 20, y = 10 }
	}
	self.RunButton.Paint = function(but, w_, h)
		surface.SetDrawColor(gray_color)
		if but:IsHovered() then
			surface.DrawRect(0, 0, 30, h - 5)
		else
			surface.DrawOutlinedRect(0, 0, 30, h - 5)
		end

		local check
		for k, v in next, ExecutionCallbacks do
			if v.name == self.Env then
				check = v.check
				break
			end
		end

		draw.NoTexture()
		surface.SetDrawColor((not check or check()) and green_color or red_color)
		surface.DrawPoly(run_triangle)
	end

	self:SetCookieName("TabControl")

	self.HTML = self:Add("DHTML")
	self.HTML:AddFunction("gmodinterface", "OnCode", function(new_code)
		if not self.Loaded then return end
		if self.SettingTab then self.SettingTab = false return end

		local tab = self.CodeTabs:GetActiveTab()
		tab.Code = new_code

		timer.Create(Format("interstate_autosave_%s", tab.Name), 0.5, 1, function()
			if not self then return end

			self:SaveFileAs(tab.Name, new_code)
			self:AnalyzeTab(tab, tab.m_pPanel)
		end)
	end)

	self.HTML:AddFunction("gmodinterface", "OnThemesLoaded", function(themes)
		self.ThemeSelector:Clear()

		for _, theme_name in pairs(themes) do
			if cookie.GetString("ECLuaTabTheme") == theme_name then
				self.ThemeSelector:AddChoice(theme_name, nil, true)
				self.HTML:QueueJavascript(Format([[gmodinterface.SetTheme("%s");]], theme_name))
			else
				self.ThemeSelector:AddChoice(theme_name)
			end
		end
	end)

	self.HTML:AddFunction("gmodinterface", "OnLanguages", function(languages)
		self.LangSelector:Clear()

		for _, lang in pairs(languages) do
			self.LangSelector:AddChoice(lang)
		end

		self.LangSelector:ChooseOption("glua")
	end)

	self.HTML:AddFunction("gmodinterface", "OnReady", function()
		if not self:LoadLastSession() then
			local tab = self:NewTab()
			self.CodeTabs:SetActiveTab(tab)
		end

		self.LblRunStatus:SetText(("%sReady"):format((" "):rep(3)))

		local tab = self.CodeTabs:GetActiveTab()

		if IsValid(tab) then
			tab.m_pPanel:QueueJavascript(Format([[gmodinterface.SetCode(`%s`);]], tab.Code:JavascriptSafe()))
			tab.m_pPanel:QueueJavascript([[gmodinterface.LoadAutocompleteState("Shared");]])

			tab.m_pPanel:RequestFocus()
			self:AnalyzeTab(tab, tab.m_pPanel)
		end
	end)

	self.HTML._Paint = self.HTML.Paint
	self.HTML.Paint = function(editor, w, h)
		surface.DisableClipping(true)
		surface.SetDrawColor(blue_color)
		surface.DrawRect(0, -2, w, 2)
		surface.DisableClipping(false)

		editor:_Paint(w, h)
	end

	self.HTML:OpenURL(EDITOR_URL)

	self.CodeTabs = self:Add("DPropertySheet")
	self.CodeTabs:SetPos(0, 35)
	self.CodeTabs:SetPadding(0)
	self.CodeTabs:SetFadeTime(0)
	self.CodeTabs.Paint = function(_, w, h)
		surface.DisableClipping(true)
		surface.SetDrawColor(EasyChat.TabColor)
		surface.DrawRect(0, -10, w, h + 20)
		surface.DisableClipping(false)
	end
	self.CodeTabs.OnActiveTabChanged = function(_, _, new_tab)
		local code = new_tab.Code or ""
		new_tab.m_pPanel:RequestFocus()
		self.SettingTab = true
		new_tab.m_pPanel:QueueJavascript(Format([[gmodinterface.SetCode("%s");]], code:JavascriptSafe()))
		self:AnalyzeTab(new_tab, new_tab.m_pPanel)
		self:SaveActiveTab()
	end
	self.CodeTabs.SetActiveTab = function(self, active)
		if not IsValid(active) or self.m_pActiveTab == active then return end

		if IsValid(self.m_pActiveTab) then
			if self:GetFadeTime() > 0 then
				self.animFade:Start(self:GetFadeTime(), {OldTab = self.m_pActiveTab, NewTab = active})
			else
				self.m_pActiveTab:GetPanel():SetVisible(false)
			end
		end

		local old = self.m_pActiveTab
		self.m_pActiveTab = active

		-- Only run this callback when we actually switch a tab, not when a tab is initially set active
		self:OnActiveTabChanged(old, active)
		self:InvalidateLayout()
	end

	self.CodeTabs.tabScroller:SetUseLiveDrag(true)
	self.CodeTabs.tabScroller:MakeDroppable("LuaTabs")
	self.CodeTabs.tabScroller.OnDragModified = function(self) self:InvalidateLayout(true) end
	self.CodeTabs.tabScroller.Paint = function() end

	self.CodeTabs.CloseTab = function(propsheet, tab, bRemovePanelToo )
		local iTabIndex = 0
		for k, v in pairs( propsheet.Items ) do
			if v.Tab == tab then
				table.remove( propsheet.Items, k )
				iTabIndex = k
				break
			end
		end

		-- closed tab history
		if #tab.Code > 0 then
			table.insert(self.ClosedTabHistory, {
				tab.Name,
				tab.Code,
				iTabIndex
			})
		end

		if #self.ClosedTabHistory > 100 then
			table.remove(self.ClosedTabHistory, 101)
		end

		for k, v in pairs(propsheet.tabScroller.Panels) do
			if v == tab then
				table.remove( propsheet.tabScroller.Panels, k )
				break
			end
		end
		propsheet.tabScroller:InvalidateLayout( true )

		local ActiveTab = propsheet:GetActiveTab()
		if tab == ActiveTab then
			if iTabIndex >= #propsheet.Items then
				iTabIndex = iTabIndex - 1
			end

			local newTab = propsheet.Items[iTabIndex].Tab
			propsheet.tabScroller:ScrollToChild(newTab)
			propsheet:SetActiveTab(newTab)
		end

		local pnl = tab:GetPanel()

		if ( bRemovePanelToo ) then
			pnl:Remove()
		end

		tab:Remove()

		propsheet:InvalidateLayout( true )

		self:SaveTabsOrder()

		return pnl
	end

	if not EasyChat.CanUseCEFFeatures() then
		self.Warn = self:Add("DLabel")
		self.Warn:SetWrap(true)
		self.Warn:Dock(TOP)
		self.Warn:DockMargin(5, 5, 5, 5)
		self.Warn:SetTall(75)
		self.Warn:SetTextColor(color_white)
		self.Warn:SetText([[You cannot use the editor on a non-chromium branch, please switch to x86-64.
		You can change your Garry's Mod branch in your steam library.]])
	end

	self.LblRunStatus = self:Add("DLabel")
	self.LblRunStatus:SetTextColor(color_white)
	self.LblRunStatus:Dock(BOTTOM)
	self.LblRunStatus:SetSize(self:GetWide(), 25)
	self.LblRunStatus:SetText(("%sReady"):format((" "):rep(3)))
	self.LblRunStatus.Paint = function(_, w, h)
		surface.SetDrawColor(blue_color)
		surface.DrawRect(0, 0, w, h)
	end

	self.ThemeSelector = self:Add("DComboBox")
	self.ThemeSelector:AddChoice("vs-dark", nil, true)
	self.ThemeSelector:SetTextColor(color_white)
	self.ThemeSelector:SetWide(100)
	self.ThemeSelector.DropButton.Paint = drop_button_paint
	self.ThemeSelector.Paint = combo_box_paint

	self.ThemeSelector.OnSelect = function(_, _, theme_name)
		self.HTML:QueueJavascript( Format([[gmodinterface.SetTheme("%s");]], theme_name) )
		cookie.Set("ECLuaTabTheme", theme_name)
	end

	self.LangSelector = self:Add("DComboBox")
	self.LangSelector:SetTextColor(color_white)
	self.LangSelector:SetWide(100)
	self.LangSelector.DropButton.Paint = drop_button_paint
	self.LangSelector.Paint = combo_box_paint

	-- TODO: Per-tab language
	self.LangSelector.OnSelect = function(_, _, lang)
		local active_tab = self.CodeTabs:GetActiveTab()
		if not IsValid(active_tab) then return end

		local editor = active_tab.m_pPanel
		if lang == "glua" or lang == "lua" then
			self:AnalyzeTab(active_tab, editor)
		else
			editor:QueueJavascript([[gmodinterface.SubmitLuaReport({ events: []});]])
			self.ErrorList.List:Clear()
			self.ErrorList:SetLabel("Error List")
		end

		editor:QueueJavascript(Format([[gmodinterface.SetLanguage("%s");]], lang))
		active_tab.Lang = lang
	end

	self.ErrorList = self:Add("DCollapsibleCategory")
	self.ErrorList:Dock(BOTTOM)
	self.ErrorList:SetSize(self:GetWide(), 150)
	self.ErrorList:SetLabel("Error List")
	self.ErrorList.Paint = function(self, w, h)
		surface.SetDrawColor(blue_color)
		surface.DrawRect(0, 0, w, 25)
	end

	self.ErrorList.PerformLayout = function(self)
		if ( IsValid( self.Contents ) ) then
			if ( self:GetExpanded() ) then
				self.Contents:InvalidateLayout( true )
				self.Contents:SetVisible( true )
			else
				self.Contents:SetVisible( false )
			end

		end

		if not self:GetExpanded() then
			if IsValid( self.Contents ) and not self.OldHeight then self.OldHeight = self.Contents:GetTall() end
			self:SetTall( self:GetHeaderHeight() )
		end

		-- Make sure the color of header text is set
		self.Header:ApplySchemeSettings()

		self.animSlide:Run()
		self:UpdateAltLines()
	end

	local error_list = vgui.Create("DListView")
	error_list:SetMultiSelect(false)
	error_list.Paint = function(self, w, h)
		surface.SetDrawColor(EasyChat.TabColor)
		surface.DrawRect(0, 0, w, h)
	end

	-- hack to paint the scrollbar
	error_list._OnScrollbarAppear = error_list.OnScrollbarAppear
	error_list.OnScrollbarAppear = function(self)
		self:_OnScrollbarAppear()

		self.VBar:SetHideButtons(true)
		self.VBar.Paint = function(self, w, h)
			surface.SetDrawColor(gray_color)
			surface.DrawLine(0, 0, 0, h)
		end

		local grip_color = table.Copy(gray_color)
		grip_color.a = 150
		self.VBar.btnGrip.Paint = function(self, w, h)
			surface.SetDrawColor(grip_color)
			surface.DrawRect(0, 0, w, h)
		end
	end

	local line_column = error_list:AddColumn("Line")
	line_column:SetFixedWidth(50)
	line_column.Header:SetTextColor(color_white)
	line_column.Header.Paint = function(self, w, h)
		surface.SetDrawColor(EasyChat.TabColor)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(gray_color)
		surface.DrawLine(0, h - 1, w, h - 1)
		surface.DrawLine(w - 1, 0, w - 1, h)
	end

	local code_column = error_list:AddColumn("Code")
	code_column:SetFixedWidth(50)
	code_column.Header:SetTextColor(color_white)
	code_column.Header.Paint = function(self, w, h)
		surface.SetDrawColor(EasyChat.TabColor)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(gray_color)
		surface.DrawLine(0, h - 1, w, h - 1)
		surface.DrawLine(w - 1, 0, w - 1, h)
	end

	local desc_column = error_list:AddColumn("Description")
	desc_column.Header:SetTextColor(color_white)
	desc_column.Header.Paint = function(self, w, h)
		surface.SetDrawColor(EasyChat.TabColor)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(gray_color)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	self.ErrorList:SetContents(error_list)
	self.ErrorList:SetExpanded(EasyChat.CanUseCEFFeatures())
	self.ErrorList.List = error_list
	self.ErrorList.Header:SetFont("DermaDefault")

	if not cookie.GetString("ECLuaTabTheme") then
		cookie.Set("ECLuaTabTheme", "vs-dark")
	end

	if EasyChat.CanUseCEFFeatures() then
		hook.Add( "ShutDown", self, function()
			if not IsValid(self) then return end

			self:SaveTabsOrder()
			self:SaveActiveTab()
		end)
	end
end

function PANEL:OpenFileBrowser(callback)
	if type(callback) ~= "function" then
		callback = function(path)
			self:LoadFile(path)
		end
	end

	filebrowser.ShowTree(callback)
end
function PANEL:PerformLayout(w, h)
	self.MenuBar:SetSize(w, 25)
	self.CodeTabs:SetSize(w, h - (60 + self.ErrorList:GetTall()))

	local x, y, w, _ = self.LblRunStatus:GetBounds()
	self.ThemeSelector:SetPos(x + w - self.ThemeSelector:GetWide() - 5, y + 1)
	self.LangSelector:SetPos(x + w - self.ThemeSelector:GetWide() - 10 - self.LangSelector:GetWide(), y + 1)
end

function PANEL:RunCode()
	local code = self:GetCode():Trim()
	if #code == 0 then return end

	if self.Env == "javascript" then
		local active_tab = self.CodeTabs:GetActiveTab()
		if IsValid(active_tab) then
			active_tab.m_pPanel:QueueJavascript(code:JavascriptSafe())
			self:RegisterAction(self.Env)
		end

		return
	end

	for k, v in next, ExecutionCallbacks do
		if v.name == self.Env and (not isfunction(v.check) or v.check()) then
			v.callback(self, code)
			self:RegisterAction(self.Env)
			break
		end
	end
end

-- keyboard input handling for shortcuts
do
	PANEL.ShortcutsTree = {}
	PANEL.Shortcuts = {
		{
			Trigger = { KEY_LCONTROL, KEY_N },
			Callback = function(self) self:UserInput_NewTab() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_W },
			Callback = function(self) self:CloseCurrentTab() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_R },
			Callback = function(self) self:RunCode() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_O },
			Callback = function(self) self:OpenFileBrowser() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_S },
			Callback = function(self) self:SaveCurrentEditor() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_S, KEY_LSHIFT },
			Callback = function(self)
				Derma_StringRequest("Save As...", "Enter the file name to save as", "", function(name)
					self:SaveCurrentEditor(name)
				end)
			end,
		},
		{
			Trigger = { KEY_F2 },
			Callback = function(self) self:RenameCurrentTab() end,
			Cooldown = 0.5,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_TAB },
			Callback = function(self) self:SwitchToNextTab() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_TAB, KEY_LSHIFT },
			Callback = function(self) self:SwitchToPreviousTab() end,
		},
		{
			Trigger = { KEY_LCONTROL, KEY_T, KEY_LSHIFT },
			Callback = function(self)
				if #self.ClosedTabHistory > 0 then
					local t = table.remove(self.ClosedTabHistory)
					self:NewTab(t[1], t[2])
				end
			end,
		}
	}

	function PANEL:Think()
		-- dont think if not open!
		if not self:HasHierarchicalFocus() then return end

		-- initialize shortcut tree
		if table.IsEmpty(self.ShortcutsTree) then
			for iShortcut, shortcut in ipairs(self.Shortcuts) do
				local tree = self.ShortcutsTree

				for i, key in ipairs(shortcut.Trigger) do
					tree[key] = tree[key] or {tree = {}}

					if i == #shortcut.Trigger then
						table.insert(tree[key], iShortcut)
					end

					tree = tree[key].tree
				end
			end
		end

		self:CheckShortcuts()
	end
	function PANEL:CheckCadence(t, key)
		if not input.IsKeyDown(key) then return end

		-- check for longer cadences before this one
		if not table.IsEmpty(t.tree) then
			-- continue cadence
			for key2, t2 in next, t.tree do
				if self:CheckCadence(t2, key2) == false then
					return false
				end
			end
		end

		-- callback for completed cadence
		for _, i in next, t do
			if _ == "tree" then continue end

			local shortcut = self.Shortcuts[i]
			if (shortcut.Next or 0) <= CurTime() then
				shortcut.Callback(self)
				shortcut.Next = CurTime() + (shortcut.Cooldown or 0.2)
			end

			return false -- do not attempt to handle any other shortcuts for this cadence
		end
	end
	function PANEL:CheckShortcuts()
		for key, t in next, self.ShortcutsTree do
			self:CheckCadence(t, key)
		end
	end
end

-- tab handling
do
	function PANEL:GetNewFilename()
		local best = 0

		for _,v in next, self.CodeTabs.Items do
			local name = v.Name:lower()

			if name:find("new") then
				local index1, index2 = name:find("%d+")
				local num = index1 and tonumber(name:sub(index1, index2)) or 0

				if num == best then
					best = best + 1
				end
			end
		end

		if best == 0 then
			return "new"
		else
			return Format("new %d", best)
		end
	end

	function PANEL:UserInput_NewTab()
		local newestFileName = self:GetNewFilename()
		local filepath  = newestFileName

		if not file.Exists(filepath, "GAME") then
			filepath = Format("data/%s%s.txt", self.SaveDir, newestFileName)
		end

		if file.Exists(filepath, "GAME") then
			self:LoadFile(filepath)
		else
			self:NewTab(newestFileName)
		end
	end

	function PANEL:NewTab(tab_name, code)
		if not EasyChat.CanUseCEFFeatures() then return end

		tab_name = tab_name or self:GetNewFilename() --"Untitled" --("Untitled%s"):format((" "):rep(20))
		code = code or ""

		local editor = self.HTML
		local sheet = self.CodeTabs:AddSheet(tab_name, editor)
		local tab = sheet.Tab
		tab:SetMinimumSize(0, 20)
		tab.Code = code
		tab.Name = tab_name:Trim()
		tab.Lang = "glua"
		self.LblRunStatus:SetText(("%sLoading..."):format((" "):rep(3)))

		if self.Loaded then
			self.CodeTabs:SetActiveTab(tab)
		end

		self.CodeTabs.tabScroller:ScrollToChild(tab)
		tab:SetTextColor(color_white)

		surface.SetFont(tab:GetFont())
		local textw = surface.GetTextSize(tab_name)
		tab:SetMinimumSize(textw + 40)

		local close_btn = tab:Add("DButton")
		close_btn:SetSize(20, 20)
		close_btn:SetText("x")
		close_btn:SetTextColor(color_white)
		close_btn.Paint = function() end
		close_btn.DoClick = function()
			if self.CodeTabs:GetActiveTab() == tab then
				self:CloseCurrentTab()
			elseif #self.CodeTabs:GetItems() > 1 then
				self.CodeTabs:CloseTab(tab, false)
			end
		end
		close_btn.DoMiddleClick = close_btn.DoClick
		tab.DoMiddleClick = close_btn.DoClick
		tab.Close = close_btn.DoClick

		function tab:GetContentSize()
			surface.SetFont(self:GetFont())

			local w, h = surface.GetTextSize(self:GetText())
			local insetw, inseth = self:GetTextInset()

			w = w + insetw + close_btn:GetWide()
			h = math.max(h + inseth, close_btn:GetTall())

			return w,h
		end

		tab._PerformLayout = tab.PerformLayout
		tab.PerformLayout = function(self, w, h)
			close_btn:AlignRight(2)

			self:_PerformLayout(w, h)
		end

		local function FormatName( str )
			return str:gsub( "[^%/%w%_%. ]", "" )
		end

		tab.DoDoubleClick = function(tb) -- Edit name!
			local TextEdit = vgui.Create( "DTextEntry", tb )
			TextEdit:Dock( FILL )
			TextEdit:DockMargin( 4, 3, 4, 8 )
			TextEdit:SetText( tb:GetText() )
			TextEdit:SetFont( tb:GetFont() )
			TextEdit:SetDrawLanguageID( false )

			TextEdit.OnTextChanged = function()
				tb:SetText( TextEdit:GetText() )
				tb:GetPropertySheet().tabScroller:InvalidateLayout(true)
			end

			TextEdit.OnLoseFocus = function()
				hook.Run( "OnTextEntryLoseFocus", TextEdit )

				local name = FormatName( TextEdit:GetText() )
				if name:len() < 1 then tb:Close() return end

				tb:SetName( name )
				tb.Name = name
				sheet.Name = name
				editor:RequestFocus()
				TextEdit:Remove()

				self:OnTabRenamed(tb)
			end

			TextEdit.OnEnter = TextEdit.OnLoseFocus

			TextEdit:RequestFocus()
			TextEdit:OnGetFocus()
			TextEdit:SelectAllText( true )
		end
		tab.Paint = function(tab, w, h)
			if tab:IsDragging() or tab == self.CodeTabs:GetActiveTab() then
				surface.SetDrawColor(blue_color)
				surface.DrawRect(0, 0, w, 20)
			end
		end
		tab._OnStartDragging = tab.OnStartDragging
		tab.OnStartDragging = function(tab)
			tab:_OnStartDragging()
			self.CodeTabs:SetActiveTab(tab)
		end

		self:SaveTabsOrder()

		return tab
	end
	function PANEL:CloseCurrentTab()
		local Items = self.CodeTabs:GetItems()
		if #Items > 1 then
			local tab = self.CodeTabs:GetActiveTab()

			self.CodeTabs:CloseTab(tab, false)

			tab = self.CodeTabs:GetActiveTab()
			tab.m_pPanel:RequestFocus()

			self:SaveActiveTab()
		end
	end
	function PANEL:RenameCurrentTab()
		local tab = self.CodeTabs:GetActiveTab()
		if IsValid(tab) then tab:DoDoubleClick() end
	end
	function PANEL:SwitchToPreviousTab()
		local tabs = self.CodeTabs.tabScroller.Panels
		if #tabs == 1 then return end

		local active_tab = self.CodeTabs:GetActiveTab()
		local prev_index

		for i, item in ipairs(tabs) do
			if item == active_tab then
				prev_index = ((i - 2) % #tabs) + 1
				break
			end
		end

		local prev_tab = tabs[prev_index]
		self.CodeTabs:SetActiveTab(prev_tab)
		self.CodeTabs.tabScroller:ScrollToChild(prev_tab)
	end
	function PANEL:SwitchToNextTab()
		local tabs = self.CodeTabs.tabScroller.Panels
		if #tabs == 1 then return end

		local active_tab = self.CodeTabs:GetActiveTab()
		local next_index

		for i, item in ipairs(tabs) do
			if item == active_tab then
				next_index = (i % #tabs) + 1
				break
			end
		end

		local next_tab = tabs[next_index]
		self.CodeTabs:SetActiveTab(next_tab)
		self.CodeTabs.tabScroller:ScrollToChild(next_tab)
	end
	function PANEL:SwitchToName(name)
		for _, item in ipairs(self.CodeTabs:GetItems()) do
			if item.Tab.Name == name then
				self.CodeTabs:SetActiveTab(item.Tab)
				self.CodeTabs.tabScroller:ScrollToChild(item.Tab)
				break
			end
		end
	end


	function PANEL:OnTabRenamed(tab)
		self:SaveTabsOrder()
	end
end

-- save/loading editor
do
	-- removes bad characters
	local function FormatFilepath(str)
		return str:gsub("[^%/%w%_%. ]", "")
	end

	function PANEL:LoadLastSession()
		local tbl = util.JSONToTable(self:GetCookie("TabsOrder", "")) or {}

		self.CodeTabs.m_pActiveTab = true -- hack
		for k, name in ipairs(tbl) do
			if not file.Exists(name, "GAME") then
				name = Format("data/%s%s.txt", self.SaveDir, name)
			end

			self:LoadFile(name)
		end
		self.CodeTabs.m_pActiveTab = nil

		if #self.CodeTabs.Items > 0 then
			self:SwitchToName( self:GetCookie("ActiveTab", "") )
		end

		self.Loaded = true

		return #tbl > 0
	end
	function PANEL:SaveActiveTab()
		if not self.Loaded then return end

		local tab = self.CodeTabs:GetActiveTab()
		if not IsValid(tab) then return end

		self:SetCookie("ActiveTab", tab.Name)
	end
	function PANEL:SaveTabsOrder()
		if not self.Loaded then return end

		local tabs = {}

		for k, v in ipairs( self.CodeTabs.tabScroller.Panels ) do
			tabs[k] = v.Name
		end

		self:SetCookie( "TabsOrder", util.TableToJSON( tabs ) )
	end
	function PANEL:LoadFile(filepath)
		local filename = filepath

		if string.GetExtensionFromFilename(filename) == "txt" then
			filename = string.StripExtension(filepath:match(".+/(.*)$"))
		end

		self:NewTab( filename, file.Read( filepath, "GAME" ) )
	end
	function PANEL:SaveFileAs(path, code)
		if not path or #path == 0 or not code then return end
		if file.Exists(path, "GAME") then return end

		if #code == 0 then
			self:DeleteFile( path )
			return
		end

		path = FormatFilepath( path )

		if path:find("(.+)/") then
			file.CreateDir( Format("%s%s", self.SaveDir, path:match("(.+)/" )) )
		end

		file.Write( Format("%s%s.txt", self.SaveDir, path), code )
	end
	function PANEL:DeleteFile(filepath)
		local path = Format( "%s%s.txt", self.SaveDir, FormatFilepath(filepath) )
		if file.Exists(path, "GAME") then return end

		if file.Exists(path, "DATA") then
			file.Delete(path, "DATA")

			local subpath = filepath:match("(.+)/.*$")
			while filepath:match( "(.+)/.*$" ) do
				file.Delete( Format("%s%s", self.SaveDir, filepath), "DATA" )

				subpath = subpath:match( "(.+)/.*$" )
			end
		end
	end
	function PANEL:OnRemove()
		self:SaveTabsOrder()
	end

	function PANEL:SaveCurrentEditor(name)
		local tab = self.CodeTabs:GetActiveTab()
		if not IsValid(tab) then return end

		name = name or tab.Name
		self:SaveFileAs(name, tab.Code)
		--self:RegisterAction("Save")
	end
end

-- scans lua file for errors
function PANEL:AnalyzeTab(tab, editor)
	timer.Create("EasyChatLuaCheck", 1, 1, function()
		if not IsValid(tab) or not IsValid(editor) then return end -- this can happen upon reload / disabling
		if not tab.Code or tab.Code:Trim() == "" then return end
		if tab ~= self.CodeTabs:GetActiveTab() then return end
		if not (tab.Lang == "glua" or tab.Lang == "lua") then return end

		-- luacheck can sometime error out
		local succ, ret = pcall(function()
			local report = luacheck.get_report(tab.Code)
			return luacheck.filter.filter({ report })
		end)

		local events = succ and ret[1] or {}
		local js_objects = {}
		local error_list = self.ErrorList.List
		error_list:Clear()
		for _, event in ipairs(events) do
			local code = tostring(event.code)
			--local ignore = (code == "113" or code == "143") and self:IsOKServerIndex(event.indexing)
			--if not ignore then
				local is_error = code[1] == "0"
				local msg = luacheck.get_message(event)
				local line, start_column, end_column = event.line, event.column, event.end_column + 1

				local js_object = ([[{ message: `%s`, isError: %s, line: %d, startColumn: %d, endColumn: %d, luacheckCode: `%s` }]]):format(msg, tostring(is_error), line, start_column, end_column, code)
				table.insert(js_objects, js_object)

				local line_panel = error_list:AddLine(line + 1, code, msg)
				line_panel.Paint = function(self, w, h)
					if not self:IsHovered() then return end
					surface.SetDrawColor(is_error and red_color or orange_color)
					surface.DrawOutlinedRect(0, 0, w, h)
				end
				line_panel.OnSelect = function()
					editor:QueueJavascript(Format([[gmodinterface.GotoLine(%d);]], line))
				end

				--PrintTable(line_panel:GetTable())
				for _, column in pairs(line_panel.Columns) do
					column:SetTextColor(is_error and red_color or orange_color)
				end
			--end
		end

		local error_count = #events
		error_list:GetParent():SetLabel(error_count > 0 and ("Error List (%d)"):format(error_count) or "Error List")
		error_list:InvalidateParent(true)
		editor:QueueJavascript(Format([[gmodinterface.SubmitLuaReport({ events: [ %s ]});]], table.concat(js_objects, ",")))
	end)
end

function PANEL:RegisterAction(realm, action)
	local tab = self.CodeTabs:GetActiveTab()
	if not IsValid(tab) then return end

	self.LastAction = {
		Script = ("%s..."):format(tab.Name),
		Action = action or "Ran",
		Realm = realm,
		Time = os.date("%H:%M:%S")
	}

	local spacing = (" "):rep(3)
	local text = ("%s[%s] Ran %s on %s"):format(spacing, self.LastAction.Time, tab.Name, self.LastAction.Realm)
	if #text == 0 then text = ("%sReady"):format(spacing) end
	self.LblRunStatus:SetText(text)
end
function PANEL:GetCode()
	local tab = self.CodeTabs:GetActiveTab()
	if IsValid(tab) and tab.Code then
		return tab.Code
	end

	return ""
end

-- pastebin/url handling
do
	function PANEL:Pastebin(succ_callback, err_callback)
		local code = self:GetCode()
		if #code == 0 then err_callback("no code") return end

		http.Post("https://pastebin.com/api/api_post.php", {
			api_dev_key = "58cf95ab426b33880fad5d9374afefea",
			api_paste_code = code,
			api_option = "paste",
			api_paste_format = "lua",
			api_paste_private = 1,
			api_paste_expire_date = "1D",
		}, succ_callback, err_callback)
	end
	function PANEL:UploadCodeToPastebin()
		self:Pastebin(function(url)
			local msg = ("Uploaded code on pastebin: %s"):format(url)
			print(msg)
			--chat.AddText(color_white, msg)
			SetClipboardText(url)
		end, function(err)
			local err_msg = ("Pastebin error: %s"):format(err)
			print(err_msg)
			--notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
			surface.PlaySound("buttons/button11.wav")
		end)
	end
	function PANEL:LoadCodeFromURL()
		Derma_StringRequest("Code URL", "", "", function(url)
			url = url
				:gsub("pastebin.com/", "pastebin.com/raw/")
				:gsub("hastebin.com/", "hastebin.com/raw/")

			http.Fetch(url, function(txt)
				if txt:match("%</html%>") then return end
				self:NewTab(nil, txt)
				print(("Loaded code from: %s"):format(url))
			end, function(err)
				local err_msg = ("Could not load code from: %s"):format(url)
				print(err_msg)
				--notification.AddLegacy(err_msg, NOTIFY_ERROR, 5)
				surface.PlaySound("buttons/button11.wav")
			end)
		end)
	end
end

vgui.Register("ECLuaTab", PANEL, "DPanel")
