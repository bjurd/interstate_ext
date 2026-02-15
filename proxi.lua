pcall(require, "proxi")

if not proxi then
	local col = {
		r = 0,
		g = 255,
		b = 255
	}
	MsgC(col, "u dont have proxi idiot\n")

	return
end

local jitutil = jit.util
local bitrshift = bit.rshift
local bitband = bit.band
local stringgsub = string.gsub
local stringformat = string.format
local stringchar = string.char
local utilCRC = util.CRC
local tableconcat = table.concat
--local randomseed = math.randomseed
--local random = math.random
local tonumber = tonumber
--local pcall = pcall

local proxi = proxi
local bak = {}
proxi.bak = bak

bak.setfenv = setfenv
bak.getfenv = getfenv
bak.getmetatable = getmetatable
bak.setmetatable = setmetatable
bak.CompileString = CompileString
bak.CompileFile = CompileFile
bak.RunString = RunString

-- extended functionality here
do
	proxi._getupvalue = proxi.getupvalue
	function proxi.getupvalue(f, i)
		if tonumber(f) then
			f = proxi.getinfo(tonumber(f), "f").func
		end

		return proxi._getupvalue(f, i)
	end

	function proxi.getupvalues(f)
		if not isfunction(f) then return {} end
		local uvs = {}

		for i = 1, math.huge do
			local k,v = proxi.getupvalue(f, i)
			if not k and not v then break end
			uvs[k] = v
		end

		return uvs
	end

	function proxi.getupvaluex(f, u)
		if isnumber(u) then
			return proxi.getupvalue(f, u)
		elseif isstring(u) then
			if not isfunction(f) then return {} end

			for i = 1, math.huge do
				local k,v = proxi.getupvalue(f, i)
				if not k and not v then break end
				if k == u then
					return v
				end
			end
		end
	end

	function proxi.setupvaluex(f, u, o)
		if isnumber(u) then
			return proxi.setupvalue(f, u, o)
		elseif isstring(u) then
			for i = 1, math.huge do
				local k,v = proxi.getupvalue(f, i)
				if not k and not v then break end

				if k == u then
					return proxi.setupvalue(f, i, o)
				end
			end
		end
	end

	function proxi.getfuncconsts(f)
		if not isfunction(f) then return {} end
		local ks = {}

		for i = -1, -math.huge, -1 do
			local k = jit.util.funck(f,i)
			if not k then break end
			ks[i] = k
		end

		return ks
	end

	local FuncJitInformation = {}

	local bytecodereplace = {
		[0x46] = 0x51,
		[0x47] = 0x51,
		[0x48] = 0x51,
		[0x49] = 0x49,
		[0x4A] = 0x49,
		[0x4B] = 0x4B,
		[0x4C] = 0x4B,
		[0x4D] = 0x4B,
		[0x4E] = 0x4E,
		[0x4F] = 0x4E,
		[0x50] = 0x4E,
		[0x51] = 0x51,
		[0x52] = 0x51,
		[0x53] = 0x51,
	}

	local bytecodereplace2 = {
		[0x44] = 0x54,
		[0x42] = 0x41,
	}

	function proxi.funcinfo(func)
		if not FuncJitInformation[func] then
			local funcjitinformation = jitutil.funcinfo(func)
			local jitinfo = {}

			jitinfo.func = func
			jitinfo.isnative = funcjitinformation.addr ~= nil
			jitinfo.address = tonumber(stringformat("%p", func))

			if not jitinfo.isnative then
				local src = stringgsub (funcjitinformation ["source"], "^@", "")
				src = stringgsub (src, "[/]+", "/")

				jitinfo.source = src
				jitinfo.linedefined = funcjitinformation.linedefined
				jitinfo.lastlinedefined = funcjitinformation.lastlinedefined

				local funcbcs = {}
				local bytecodes = funcjitinformation.bytecodes - 1

				for i = 1, bytecodes do
					local bytecode = jitutil.funcbc (func, i)
					local byt      = bitband (bytecode, 0xFF)

					if bytecodereplace [byt] then
						bytecode = bytecodereplace [byt]
					end

					if bytecodereplace2 [byt] then
						bytecode = bytecode - byt
						bytecode = bytecode + bytecodereplace2 [byt]
					end

					funcbcs [#funcbcs + 1] = stringchar (
						bitband (            bytecode,      0xFF),
						bitband (bitrshift (bytecode,  8), 0xFF),
						bitband (bitrshift (bytecode, 16), 0xFF),
						bitband (bitrshift (bytecode, 24), 0xFF)
					)
				end

				jitinfo.address = tonumber(utilCRC(tableconcat(funcbcs)))
			end

			FuncJitInformation[func] = jitinfo
		end

		return FuncJitInformation[func]
	end

	local ENTITY = proxi._R.Entity
	if ENTITY then
		ENTITY.GetDTNetVar = proxi.__Ent_GetNetVar

		DPT_Int			= 0
		DPT_Float		= 1
		DPT_Vector		= 2
		DPT_Vector2D	= 3
		DPT_String		= 4

		function ENTITY:GetSimTime()
			return self:GetDTNetVar("DT_BaseEntity->m_flSimulationTime", 1) -- force to cast to DPT_Float
		end
		function ENTITY:GetTickBase()
			return self:GetDTNetVar("DT_LocalPlayerExclusive->m_nTickBase", 0) -- force to cast to DPT_Int
		end
	end
end

-- detours/cheeto stuff
do
	--local function getpath(path)
	--	return path:match( "^(.*[/\\])[^/\\]-$" ) or ""
	--end

	local detours = {
		detours = {},
		r_detours = {},
	}
	proxi.detours = detours
	function detours.Add(og, detour)
		if not (isfunction(og) and isfunction(detour)) then return og end

		detours.detours[detour] = og
		detours.r_detours[og] = detour
		setfenv(detour, setmetatable({_G = _G, fnOriginal = og, fnDetour = detour}, {__index = _G, __newindex = _G}))

		return detour
	end

	-- used to tell when stuff is ran
	_G.include = detours.Add(include, function(filename, ...)
		--MsgC({r = 0,g = 255,b = 255}, "[INCLUDE] ", {r = 255,b = 255,g = 255}, getpath(proxi.getinfo(2).short_src) .. filename, "\n")
		return fnOriginal(filename, ...)
	end)
	_G.require = detours.Add(require, function(filename, ...)
		--MsgC({r = 255,g = 0,b = 0}, "[REQUIRE] ", {r = 255,b = 255,g = 255}, filename, "\n")
		return fnOriginal(filename, ...)
	end)
	_G.AddCSLuaFile = detours.Add(AddCSLuaFile, function(filename)
		if not filename then
			filename = proxi.getinfo(2).short_src
		end

		--MsgC({r = 255,g = 255,b = 0}, "[ADDCSLUA] ", {r = 255,b = 255,g = 255}, filename, "\n")
		return fnOriginal(filename)
	end)

	--[=[_G.debug.getinfo = detours.Add(debug.getinfo, function(func_or_level, fields)
		if not pcall(fnOriginal, func_or_level, fields) then return fnOriginal(func_or_level, fields) end

		if detours.detours[func_or_level] then
			func_or_level = detours.detours[func_or_level]
		end

		local info = fnOriginal(func_or_level, fields)
		if detours[info.func] then
			info.func = detours[info.func]
		end

		return info
	end)]=]

	-- misc stuff to prevent info leaking
	_G.tostring = detours.Add(tostring, function(obj)
		return fnOriginal(detours.detours[obj] or obj)
	end)
	_G.string.format = detours.Add(string.format, function(format, ...)
		local args = {...}

		for i = 1, #args do
			if detours.detours[args[i]] then
				args[i] = detours.detours[args[i]]
			end
		end

		return fnOriginal(format, unpack(args))
	end)

	--local fileTime = file.Time
	--local vpk_time = fileTime("sourceengine/hl2_sound_vo_english_000.vpk","BASE_PATH")
	--local cv_name  = GetConVar_Internal("name"):GetString()
	--[[file.Time = function(a,b)
		local ret = fileTime(a,b)

		if ret == vpk_time then
			randomseed(tonumber(utilCRC(cv_name)))
			local r = random()
			local r2 = random(1, 10000000)

			return ret + (r <= .5 and -r2 or r2)
		end

		return ret
	end]]

	sql.Query("BEGIN; DELETE FROM cookies WHERE key = snoop_dogg_weps; COMMIT;")
	file.Delete("wiremod_icon.jpg")

	--local jitattach = jit.attach
	--[[jit.attach = function(callback, event)
		local f = jitattach
		print("jit.attach()", f, callback, event)
	end]]

	--local debugsethook = debug.sethook
	--[[debug.sethook = function(...)
		local f = debugsethook
		print("debug.sethook()", ...)
	end]]
end
