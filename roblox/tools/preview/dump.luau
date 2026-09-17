--!nolint
-- Bouwt één scherm in de nagemaakte UI en schrijft de boom als JSON naar stdout.
--   luau tools/preview/dump.luau -a <scherm>
local Stub = require("./gui_stub")
local BRON = require("./sources")

local scherm = ... or "home"

local ReplicatedStorage = { Shared = {} }
local env, Instance = Stub.omgeving({ replicated = ReplicatedStorage })

-- Elke module krijgt een merkteken; require zoekt daarmee de juiste bron op.
local merk = {}
local geladen = {}
local Views = {}

local function stempel(naam)
	local m = { __naam = naam }
	merk[m] = naam
	return m
end

for naam in BRON do
	local m = stempel(naam)
	local kort = string.match(naam, "^%a+:(.+)$")
	if string.sub(naam, 1, 7) == "shared:" then
		ReplicatedStorage.Shared[kort] = m
	elseif string.sub(naam, 1, 5) == "view:" then
		Views[kort] = m
	end
end
ReplicatedStorage.Shared.Net = stempel("Net")

-- Net wordt nagemaakt: dit is alleen om te kijken hoe het eruitziet.
local NetStub = {
	fn = function()
		return { InvokeServer = function()
			return { ok = true, top = {}, friends = {}, here = {}, options = {},
			         mine = 0, label = "SEASON 1 \u{00B7} SPRINT 1", endsAt = 0, seasonEndsAt = 0,
			         sprintsLeft = 4, now = 0, vipActive = false }
		end }
	end,
	ev = function()
		return { OnClientEvent = { Connect = function() end } }
	end,
	build = function() end,
}

local eigenRequire
local function omgevingVoor(naam)
	local e = setmetatable({}, { __index = env })
	e.require = eigenRequire
	-- script.Parent.X voor de views, script.Parent voor de gedeelde modules
	e.script = setmetatable({}, {
		__index = function(_, k)
			if k == "Parent" then
				return setmetatable({}, { __index = function(_, kk)
					return Views[kk] or ReplicatedStorage.Shared[kk]
				end })
			end
			return Views[k]
		end,
	})
	return e
end

local diepte = 0
local stapel = {}
function eigenRequire(doel)
	if type(doel) ~= "table" then return doel end
	local naam = merk[doel]
	if not naam then return doel end
	if naam == "Net" then return NetStub end
	if geladen[naam] then return geladen[naam] end
	local bron = BRON[naam]
	if not bron then error("geen bron voor " .. naam) end
	diepte += 1
	table.insert(stapel, naam)
	if diepte > 25 then
		error("te diep: " .. table.concat(stapel, " > "), 0)
	end
	local f = assert(loadstring(bron, "=" .. naam))
	setfenv(f, omgevingVoor(naam))
	local m = f()
	diepte -= 1
	table.remove(stapel)
	geladen[naam] = m
	return m
end
env.require = eigenRequire

local SCHERMEN = {
	home = "Home", crash = "Crash", roulette = "Roulette", tower = "Tower", mines = "Mines",
	plinko = "Plinko", blackjack = "Blackjack", scratch = "Scratch", wheel = "Wheel",
	slots = "Slots", horse = "Horse", bus = "Bus", profile = "Profile", vip = "Vip",
	friends = "Friends", achievements = "Achievements",
}

local naam = assert(SCHERMEN[scherm], "onbekend scherm: " .. tostring(scherm))

-- De hele schil draaien, zodat de zijbalk erbij staat en het beeld te vergelijken is met een
-- schermafdruk van de webversie. init.client bouwt alles in PlayerGui; daarna zetten we het
-- gevraagde scherm zichtbaar en de rest niet.
local f = assert(loadstring(BRON.__schil, "=Client"))
local e = setmetatable({}, { __index = env })
e.require = eigenRequire
e.script = setmetatable({}, {
	__index = function(_, k)
		if k == "Views" then
			return setmetatable({}, { __index = function(_, kk) return Views[kk] end })
		end
		if k == "Icons" then return Views.Icons end
		return nil
	end,
})
setfenv(f, e)
f()

local Players = env.game:GetService("Players")
local gui = Players.LocalPlayer.PlayerGui
local scherm3 = gui:FindFirstChild("NeonCasino")
assert(scherm3, "geen ScreenGui gebouwd")

-- Alleen het gevraagde scherm laten staan. Let op: de naam moet precies overeenkomen met
-- een van de zestien schermen. `Common.columns` noemt zijn eigen vak ook "GameView", en die
-- eindigt eveneens op "View" -- die mag niet meegepakt worden.
local ECHTE = {}
for id in SCHERMEN do
	ECHTE[id .. "View"] = id
end

local function zetZichtbaar(knoop)
	for _, k in knoop:GetChildren() do
		local id = ECHTE[k.Name]
		if id then
			k.Visible = (id == scherm)
		end
		zetZichtbaar(k)
	end
end
zetZichtbaar(scherm3)

-- De ScreenGui heeft zelf geen maat; er komt een vak omheen zodat de tekenaar weet hoe
-- groot het scherm is.
local wortel = Instance.new("Frame")
wortel.Name = "Root"
wortel.Size = env.UDim2.fromOffset(1536, 1000)
wortel.BackgroundColor3 = env.Color3.fromHex("0e1116")
for _, k in scherm3:GetChildren() do
	k.Parent = wortel
end

print(Stub.json(wortel))
