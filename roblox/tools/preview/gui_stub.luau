--!nolint
-- Een nagemaakte Roblox-UI, alleen om de boom te kunnen zien. Hij bouwt geen scherm: hij
-- houdt bij welke objecten er gemaakt worden, met welke eigenschappen en in welke volgorde,
-- en schrijft dat als JSON weg. tools/preview/render.py rekent daar de indeling van uit en
-- tekent er een plaatje van.
--
-- Waarom: zonder Studio is de enige manier om te controleren of een scherm eruitziet zoals
-- de webversie, het zelf natekenen. Blind bouwen op een stylesheet is precies hoe het de
-- vorige keer misging.
local Stub = {}

-- ---------- de waardetypes ----------
local function maakType(naam, velden)
	local mt = { __index = {} }
	mt.__tostring = function() return naam end
	return mt, velden
end

local UDim = {}
UDim.__index = UDim
function UDim.new(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0, __t = "UDim" }, UDim) end

local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo), __t = "UDim2" }, UDim2)
end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end

local Vector2 = {}
Vector2.__index = Vector2
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0, __t = "Vector2" }, Vector2) end

local Color3 = {}
Color3.__index = Color3
local function kleur(r, g, b)
	return setmetatable({ R = r, G = g, B = b, __t = "Color3" }, Color3)
end
function Color3.new(r, g, b) return kleur(r or 0, g or 0, b or 0) end
function Color3.fromRGB(r, g, b) return kleur(r / 255, g / 255, b / 255) end
function Color3.fromHex(h)
	h = string.gsub(h, "#", "")
	local n = tonumber(h, 16)
	return kleur(math.floor(n / 65536) % 256 / 255, math.floor(n / 256) % 256 / 255, n % 256 / 255)
end

local ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
local ColorSequence = {
	new = function(a, b)
		if b then return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b } }, __t = "ColorSequence" } end
		return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = a } }, __t = "ColorSequence" }
	end,
}
local NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local NumberSequence = {
	new = function(a)
		if type(a) == "table" then return { Keypoints = a, __t = "NumberSequence" } end
		return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = a } }, __t = "NumberSequence" }
	end,
}

-- Enum: elke naam die gevraagd wordt bestaat, en onthoudt zichzelf.
local EnumItem = {}
EnumItem.__index = EnumItem
EnumItem.__tostring = function(self) return self.Name end
local Enum = setmetatable({}, {
	__index = function(_, soort)
		return setmetatable({}, {
			__index = function(_, naam)
				return setmetatable({ Name = naam, Soort = soort, __t = "Enum" }, EnumItem)
			end,
		})
	end,
})

-- ---------- Instance ----------
local STANDAARD = {
	Name = "", Visible = true, ZIndex = 1, LayoutOrder = 0,
	BackgroundTransparency = 0, TextTransparency = 0, BorderSizePixel = 1,
	ClipsDescendants = false, Rotation = 0, TextSize = 14, Text = "",
	TextWrapped = false, RichText = true, Active = true, AutoButtonColor = true,
	TextEditable = true, ScrollBarThickness = 12, Thickness = 1, Transparency = 0,
	LineHeight = 1,
}

local Instance = {}
local alles = {}

local function nieuw(klasse)
	local o = {
		ClassName = klasse,
		Children = {},
		Props = {},
		Parent = nil,
	}
	for k, v in STANDAARD do o.Props[k] = v end
	o.Props.Name = klasse
	local proxy
	proxy = setmetatable({}, {
		__index = function(_, k)
			if k == "Parent" then return o.Parent end
			if k == "ClassName" then return klasse end
			if k == "Children" then return o.Children end
			if k == "__obj" then return o end
			local v = o.Props[k]
			if v ~= nil then return v end
			if k == "AbsoluteSize" then
				-- De tekenaar rekent de maten pas later uit; hier is alleen van belang dat
				-- code die AbsoluteSize leest een breed scherm ziet en niet de smalle stand.
				return Vector2.new(1536, 1000)
			end
			if k == "AbsolutePosition" then return Vector2.new(0, 0) end
			-- een kind opzoeken op naam, zoals Roblox doet
			for _, kind in o.Children do
				if kind.__obj.Props.Name == k then return kind end
			end
			-- methodes
			if k == "FindFirstChild" then
				return function(_, naam)
					for _, kind in o.Children do
						if kind.__obj.Props.Name == naam then return kind end
					end
					return nil
				end
			elseif k == "FindFirstChildOfClass" then
				return function(_, kl)
					for _, kind in o.Children do
						if kind.__obj.ClassName == kl then return kind end
					end
					return nil
				end
			elseif k == "GetChildren" then
				return function() return o.Children end
			elseif k == "GetDescendants" then
				return function()
					local uit = {}
					local function loop(n)
						for _, kind in n.__obj.Children do
							table.insert(uit, kind)
							loop(kind)
						end
					end
					loop(proxy)
					return uit
				end
			elseif k == "IsA" then
				return function(_, kl)
					if kl == klasse then return true end
					if kl == "GuiObject" then
						return klasse == "Frame" or klasse == "TextLabel" or klasse == "TextButton"
							or klasse == "TextBox" or klasse == "ScrollingFrame" or klasse == "ImageLabel"
					end
					if kl == "GuiBase2d" then return true end
					return false
				end
			elseif k == "Destroy" then
				return function()
					local ouder = o.Parent
					if ouder then
						for i, kind in ouder.__obj.Children do
							if kind == proxy then table.remove(ouder.__obj.Children, i) break end
						end
					end
					o.Parent = nil
				end
			elseif k == "GetPropertyChangedSignal" then
				return function() return { Connect = function() return { Disconnect = function() end } end } end
			elseif k == "WaitForChild" then
				return function(_, naam)
					for _, kind in o.Children do
						if kind.__obj.Props.Name == naam then return kind end
					end
					return nieuw("Folder")
				end
			end
			-- gebeurtenissen
			if string.match(k, "^%u") then
				return { Connect = function() return { Disconnect = function() end } end, Wait = function() end }
			end
			return nil
		end,
		__newindex = function(_, k, v)
			if k == "Parent" then
				if o.Parent then
					for i, kind in o.Parent.__obj.Children do
						if kind == proxy then table.remove(o.Parent.__obj.Children, i) break end
					end
				end
				o.Parent = v
				if v and v.__obj then table.insert(v.__obj.Children, proxy) end
				return
			end
			o.Props[k] = v
		end,
		__tostring = function() return klasse end,
	})
	o.Proxy = proxy
	table.insert(alles, o)
	return proxy
end
Instance.new = nieuw

-- ---------- de omgeving ----------
function Stub.omgeving(opties)
	opties = opties or {}
	local env = setmetatable({}, { __index = getfenv(0) })

	env.Instance = Instance
	env.UDim = UDim
	env.UDim2 = UDim2
	env.Vector2 = Vector2
	env.Color3 = Color3
	env.Enum = Enum
	env.ColorSequence = ColorSequence
	env.ColorSequenceKeypoint = ColorSequenceKeypoint
	env.NumberSequence = NumberSequence
	env.NumberSequenceKeypoint = NumberSequenceKeypoint
	env.warn = function() end
	env.task = {
		wait = function() return 0 end,
		spawn = function() end,
		delay = function() end,
		defer = function(f) if opties.defer ~= false then pcall(f) end end,
	}

	local speler = nieuw("Player")
	speler.Name = "Speler"
	speler.DisplayName = "Speler"
	speler.UserId = 1
	local gui = nieuw("Folder")
	gui.Name = "PlayerGui"
	gui.Parent = speler

	local Players = nieuw("Players")
	Players.LocalPlayer = speler
	Players.GetPlayers = function() return { speler } end

	local tween = {
		Create = function(_, obj, info, doelen)
			local t
			t = {
				Play = function() for k, v in doelen do obj[k] = v end end,
				Pause = function() end, Cancel = function() end, Destroy = function() end,
				PlaybackState = "Completed",
				Completed = { Wait = function() end, Connect = function() end },
			}
			return t
		end,
	}
	env.TweenInfo = { new = function(...) return { ... } end }

	local diensten = {
		Players = Players,
		TweenService = tween,
		RunService = nieuw("RunService"),
		SocialService = nieuw("SocialService"),
		ReplicatedStorage = opties.replicated,
		UserInputService = nieuw("UserInputService"),
	}

	local werkruimte = nieuw("Workspace")
	werkruimte.GetServerTimeNow = function() return 1000 end
	env.workspace = werkruimte

	local spel = {}
	env.game = setmetatable(spel, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, naam)
					local d = diensten[naam]
					if not d then d = nieuw(naam) diensten[naam] = d end
					return d
				end
			end
			if k == "PlaceId" then return 1 end
			if k == "JobId" then return "studio" end
			return nil
		end,
	})
	return env, Instance
end

-- ---------- de boom als JSON ----------
local function jsonTekst(s)
	s = string.gsub(tostring(s), "\\", "\\\\")
	s = string.gsub(s, '"', '\\"')
	s = string.gsub(s, "\n", "\\n")
	s = string.gsub(s, "\t", "\\t")
	s = string.gsub(s, "\r", "\\r")
	-- besturingstekens weg
	s = string.gsub(s, "[\1-\31]", " ")
	return '"' .. s .. '"'
end

-- Oneindig en NaN bestaan niet in JSON; ze worden hier een heel groot getal.
local function getal(n)
	if n ~= n then return 0 end
	if n == math.huge then return 1e9 end
	if n == -math.huge then return -1e9 end
	return n
end

local function waarde(v)
	local t = type(v)
	if t == "number" then
		return string.format("%.4f", getal(v))
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return jsonTekst(v)
	elseif t == "table" then
		local soort = rawget(v, "__t")
		if soort == "UDim2" then
			return string.format('{"t":"UDim2","xs":%f,"xo":%f,"ys":%f,"yo":%f}',
				getal(v.X.Scale), getal(v.X.Offset), getal(v.Y.Scale), getal(v.Y.Offset))
		elseif soort == "UDim" then
			return string.format('{"t":"UDim","s":%f,"o":%f}', getal(v.Scale), getal(v.Offset))
		elseif soort == "Vector2" then
			return string.format('{"t":"Vector2","x":%f,"y":%f}', getal(v.X), getal(v.Y))
		elseif soort == "Color3" then
			return string.format('{"t":"Color3","r":%f,"g":%f,"b":%f}', v.R, v.G, v.B)
		elseif soort == "Enum" then
			return jsonTekst(v.Name)
		elseif soort == "ColorSequence" or soort == "NumberSequence" then
			local stukken = {}
			for _, kp in v.Keypoints do
				table.insert(stukken, string.format('{"t":%f,"v":%s}', kp.Time, waarde(kp.Value)))
			end
			return '{"t":"' .. soort .. '","k":[' .. table.concat(stukken, ",") .. "]}"
		end
		return "null"
	end
	return "null"
end

function Stub.json(wortel)
	local uit = {}
	local function loop(knoop)
		local o = knoop.__obj
		local stukken = { '"class":' .. jsonTekst(o.ClassName) }
		local sleutels = {}
		for k in o.Props do table.insert(sleutels, k) end
		table.sort(sleutels)
		local props = {}
		for _, k in sleutels do
			local w = waarde(o.Props[k])
			if w ~= "null" then table.insert(props, jsonTekst(k) .. ":" .. w) end
		end
		table.insert(stukken, '"props":{' .. table.concat(props, ",") .. "}")
		local kinderen = {}
		for _, kind in o.Children do table.insert(kinderen, loop(kind)) end
		table.insert(stukken, '"children":[' .. table.concat(kinderen, ",") .. "]")
		return "{" .. table.concat(stukken, ",") .. "}"
	end
	return loop(wortel)
end

return Stub
