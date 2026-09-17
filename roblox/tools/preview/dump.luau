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
	if naam == "Theme" or naam == "UI" or naam == "Money" or naam == "Odds"
		or naam == "Season" or naam == "Achievements" or naam == "Sha256" or naam == "Net" then
		ReplicatedStorage.Shared[naam] = m
	end
	Views[naam] = m
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

function eigenRequire(doel)
	if type(doel) ~= "table" then return doel end
	local naam = merk[doel]
	if not naam then return doel end
	if naam == "Net" then return NetStub end
	if geladen[naam] then return geladen[naam] end
	local bron = BRON[naam]
	if not bron then error("geen bron voor " .. naam) end
	local f = assert(loadstring(bron, "=" .. naam))
	setfenv(f, omgevingVoor(naam))
	local m = f()
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

local wortel = Instance.new("Frame")
wortel.Name = "Root"
wortel.Size = env.UDim2.fromOffset(1536, 1000)
wortel.BackgroundColor3 = env.Color3.fromHex("0e1116")

local naam = assert(SCHERMEN[scherm], "onbekend scherm: " .. tostring(scherm))
local view = eigenRequire(Views[naam])
if naam == "Home" or naam == "Vip" then
	view.build(wortel, function() end)
else
	view.build(wortel)
end

print(Stub.json(wortel))
