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

-- Color3:ToHex, zoals Roblox hem heeft: zes tekens, zonder hekje.
function Color3:ToHex()
	return string.format("%02X%02X%02X",
		math.round(self.R * 255), math.round(self.G * 255), math.round(self.B * 255))
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
	TextWrapped = false, RichText = false, Active = true, AutoButtonColor = true,
	TextEditable = true, ScrollBarThickness = 12, Thickness = 1, Transparency = 0,
	LineHeight = 1,
	-- Een CanvasGroup tekent zijn hele inhoud en laat die daarna als geheel doorschijnen.
	GroupTransparency = 0,
	-- Zoals Roblox ze standaard heeft. Vooral TextXAlignment telt: een knop die er zelf
	-- niets over zegt zet zijn tekst in het midden, en de tekenaar zette hem links --
	-- waardoor elke knop in de preview verkeerd stond zonder dat er iets mis was.
	TextXAlignment = "Center", TextYAlignment = "Center",
}

local Instance = {}
local alles = {}

-- De maat van een vak, uitgerekend door de ouderketen af te lopen tot aan het scherm.
-- Genoeg voor vakken die hun maat uit hun ouder halen -- en dat zijn ze hier bijna
-- allemaal. De tekenaar rekent daarna alles nog eens na; dit is er voor code die tijdens
-- het bouwen zelf AbsoluteSize leest, zoals het spelraster op het beginscherm.
local SCHERM_B, SCHERM_H = 1536, 1000

local function maatVan(o)
	if not o then return SCHERM_B, SCHERM_H end
	local ouderB, ouderH = maatVan(o.Parent and o.Parent.__obj)
	-- De opvulling van de ouder gaat van de ruimte af voordat een kind zijn deel krijgt.
	if o.Parent then
		for _, k in o.Parent.__obj.Children do
			if k.__obj.ClassName == "UIPadding" then
				local pp = k.__obj.Props
				local function px(v, basis)
					if typeof(v) ~= "table" then return 0 end
					return (v.Scale or 0) * basis + (v.Offset or 0)
				end
				ouderB -= px(pp.PaddingLeft, ouderB) + px(pp.PaddingRight, ouderB)
				ouderH -= px(pp.PaddingTop, ouderH) + px(pp.PaddingBottom, ouderH)
				break
			end
		end
	end
	local maat = o.Props.Size
	if typeof(maat) ~= "table" then return ouderB, ouderH end
	local b = (maat.X and maat.X.Scale or 0) * ouderB + (maat.X and maat.X.Offset or 0)
	local h = (maat.Y and maat.Y.Scale or 0) * ouderH + (maat.Y and maat.Y.Offset or 0)
	return math.max(0, b), math.max(0, h)
end

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
				local b, h = maatVan(o)
				return Vector2.new(b, h)
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

	-- Een spawn wordt meteen uitgevoerd in plaats van weggelegd: een scherm dat bij het
	-- openen iets bij de server opvraagt doet dat in een spawn, en die vraag hoort in de
	-- tekening terug te komen.
	--
	-- Alleen zit er ook animatielus in een spawn, en die draait op task.wait. Die wacht
	-- hier niet, dus zo'n lus zou nooit ophouden. Daarom telt hij: binnen een spawn mag er
	-- een paar keer gewacht worden, en daarna stopt de lus met een fout die de pcall
	-- eromheen opvangt. Wat er tot dat moment getekend is blijft staan.
	local inSpawn = false
	local gewacht = 0
	env.task = {
		wait = function()
			if inSpawn then
				gewacht += 1
				if gewacht > 3 then error("preview: lus afgekapt", 0) end
			end
			return 0
		end,
		spawn = function(f, ...)
			local vorigeStand, vorigeTeller = inSpawn, gewacht
			inSpawn, gewacht = true, 0
			pcall(f, ...)
			inSpawn, gewacht = vorigeStand, vorigeTeller
		end,
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

	-- TextService:GetTextSize, met dezelfde letterbreedtes als de tekenaar gebruikt. De
	-- schermcode meet er tekst mee die niet past -- de kop van een speelscherm wikkelt als
	-- de naam naast de terugknop niet meer op een regel kan.
local GLYPH = {
	ui = {[32] = 0.2812, [33] = 0.2876, [34] = 0.4658, [35] = 0.6333, [36] = 0.6416, [37] = 0.9819, [38] = 0.644, [39] = 0.2998, [40] = 0.3647, [41] = 0.3647, [42] = 0.501, [43] = 0.6616, [44] = 0.2881, [45] = 0.46, [46] = 0.2881, [47] = 0.3604, [48] = 0.6309, [49] = 0.4067, [50] = 0.6099, [51] = 0.6177, [52] = 0.646, [53] = 0.6079, [54] = 0.6201, [55] = 0.5659, [56] = 0.6187, [57] = 0.6201, [58] = 0.2881, [59] = 0.3018, [60] = 0.6616, [61] = 0.6616, [62] = 0.6616, [63] = 0.5112, [64] = 0.9658, [65] = 0.6899, [66] = 0.6543, [67] = 0.7305, [68] = 0.7217, [69] = 0.6011, [70] = 0.5903, [71] = 0.7461, [72] = 0.7432, [73] = 0.2686, [74] = 0.5708, [75] = 0.6719, [76] = 0.5654, [77] = 0.9033, [78] = 0.7534, [79] = 0.7646, [80] = 0.6387, [81] = 0.7646, [82] = 0.6436, [83] = 0.6416, [84] = 0.6455, [85] = 0.7441, [86] = 0.6899, [87] = 0.9854, [88] = 0.6821, [89] = 0.6787, [90] = 0.6289, [91] = 0.3647, [92] = 0.3604, [93] = 0.3647, [94] = 0.4712, [95] = 0.4561, [96] = 0.3228, [97] = 0.5615, [98] = 0.6123, [99] = 0.5713, [100] = 0.6123, [101] = 0.583, [102] = 0.3701, [103] = 0.6133, [104] = 0.5913, [105] = 0.2422, [106] = 0.2422, [107] = 0.5488, [108] = 0.2422, [109] = 0.876, [110] = 0.5908, [111] = 0.5996, [112] = 0.6123, [113] = 0.6123, [114] = 0.3765, [115] = 0.5278, [116] = 0.3271, [117] = 0.5913, [118] = 0.562, [119] = 0.8184, [120] = 0.5459, [121] = 0.562, [122] = 0.5522, [123] = 0.4263, [124] = 0.3325, [125] = 0.4263, [126] = 0.6616},
	uiMed = {[32] = 0.252, [33] = 0.3213, [34] = 0.5229, [35] = 0.6436, [36] = 0.6504, [37] = 1.0044, [38] = 0.6626, [39] = 0.3257, [40] = 0.373, [41] = 0.373, [42] = 0.5396, [43] = 0.6729, [44] = 0.3188, [45] = 0.4653, [46] = 0.3188, [47] = 0.3789, [48] = 0.6597, [49] = 0.4229, [50] = 0.623, [51] = 0.6362, [52] = 0.666, [53] = 0.6289, [54] = 0.6396, [55] = 0.5762, [56] = 0.6401, [57] = 0.6396, [58] = 0.3188, [59] = 0.3291, [60] = 0.6729, [61] = 0.6729, [62] = 0.6729, [63] = 0.5435, [64] = 0.999, [65] = 0.7275, [66] = 0.6592, [67] = 0.7368, [68] = 0.7222, [69] = 0.6055, [70] = 0.5879, [71] = 0.749, [72] = 0.7456, [73] = 0.2769, [74] = 0.5796, [75] = 0.7031, [76] = 0.5654, [77] = 0.9224, [78] = 0.7593, [79] = 0.7686, [80] = 0.645, [81] = 0.7729, [82] = 0.6523, [83] = 0.6504, [84] = 0.6602, [85] = 0.7358, [86] = 0.7275, [87] = 1.02, [88] = 0.7197, [89] = 0.7134, [90] = 0.6523, [91] = 0.373, [92] = 0.3789, [93] = 0.373, [94] = 0.4814, [95] = 0.4692, [96] = 0.3511, [97] = 0.5742, [98] = 0.624, [99] = 0.5825, [100] = 0.624, [101] = 0.5913, [102] = 0.3887, [103] = 0.6255, [104] = 0.6123, [105] = 0.2617, [106] = 0.2617, [107] = 0.5693, [108] = 0.2617, [109] = 0.9004, [110] = 0.6118, [111] = 0.6089, [112] = 0.624, [113] = 0.624, [114] = 0.397, [115] = 0.5493, [116] = 0.353, [117] = 0.6123, [118] = 0.5869, [119] = 0.8394, [120] = 0.5688, [121] = 0.5884, [122] = 0.5659, [123] = 0.4546, [124] = 0.3589, [125] = 0.4546, [126] = 0.6729},
	num = {[32] = 0.6, [33] = 0.6, [34] = 0.6, [35] = 0.6, [36] = 0.6, [37] = 0.6, [38] = 0.6, [39] = 0.6, [40] = 0.6, [41] = 0.6, [42] = 0.6, [43] = 0.6, [44] = 0.6, [45] = 0.6, [46] = 0.6, [47] = 0.6, [48] = 0.6, [49] = 0.6, [50] = 0.6, [51] = 0.6, [52] = 0.6, [53] = 0.6, [54] = 0.6, [55] = 0.6, [56] = 0.6, [57] = 0.6, [58] = 0.6, [59] = 0.6, [60] = 0.6, [61] = 0.6, [62] = 0.6, [63] = 0.6, [64] = 0.6, [65] = 0.6, [66] = 0.6, [67] = 0.6, [68] = 0.6, [69] = 0.6, [70] = 0.6, [71] = 0.6, [72] = 0.6, [73] = 0.6, [74] = 0.6, [75] = 0.6, [76] = 0.6, [77] = 0.6, [78] = 0.6, [79] = 0.6, [80] = 0.6, [81] = 0.6, [82] = 0.6, [83] = 0.6, [84] = 0.6, [85] = 0.6, [86] = 0.6, [87] = 0.6, [88] = 0.6, [89] = 0.6, [90] = 0.6, [91] = 0.6, [92] = 0.6, [93] = 0.6, [94] = 0.6, [95] = 0.6, [96] = 0.6, [97] = 0.6, [98] = 0.6, [99] = 0.6, [100] = 0.6, [101] = 0.6, [102] = 0.6, [103] = 0.6, [104] = 0.6, [105] = 0.6, [106] = 0.6, [107] = 0.6, [108] = 0.6, [109] = 0.6, [110] = 0.6, [111] = 0.6, [112] = 0.6, [113] = 0.6, [114] = 0.6, [115] = 0.6, [116] = 0.6, [117] = 0.6, [118] = 0.6, [119] = 0.6, [120] = 0.6, [121] = 0.6, [122] = 0.6, [123] = 0.6, [124] = 0.6, [125] = 0.6, [126] = 0.6},
}
	local tekstDienst = nieuw("TextService")
	tekstDienst.GetTextSize = function(_, tekst, maat, font, _vak)
		local naam = tostring(font)
		local tabel = if string.find(naam, "Code") then GLYPH.num
			elseif string.find(naam, "Bold") or string.find(naam, "Med") then GLYPH.uiMed
			else GLYPH.ui
		local som = 0
		for _, punt in utf8.codes(tekst) do
			som += tabel[punt] or 0.55
		end
		return { X = som * maat, Y = maat }
	end

	local diensten = {
		Players = Players,
		TextService = tekstDienst,
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
