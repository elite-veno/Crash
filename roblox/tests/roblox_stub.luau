--!nolint
-- Een nagemaakte Roblox-omgeving, klein genoeg om te overzien en groot genoeg om de
-- serverbestanden echt te draaien. Zo worden de exploits getest op de code die straks in
-- Studio staat, niet op een kopie ervan.
--
-- Wat hier NIET nagemaakt wordt: threads. task.spawn onthoudt de functie maar draait hem
-- niet, want de autosave-lus van Profiles is oneindig. task.wait doet niets; de tests
-- rekenen zelf met de klok waar dat uitmaakt.
local bronnen = require("./server_sources")

local Stub = {}

local function signaal()
	local luisteraars = {}
	local s = {}
	function s:Connect(f)
		table.insert(luisteraars, f)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, f in luisteraars do f(...) end
	end
	return s
end

-- Een DataStore die onthoudt wat erin geschreven is, en die desgewenst een paar keer
-- kapot gaat: daarmee is de herhaling te testen.
local function nieuweStore()
	local ds: any = { data = {}, schrijfbeurten = 0, leesbeurten = 0, kapot = 0, tijdens = nil }
	function ds:GetAsync(key)
		ds.leesbeurten += 1
		if ds.kapot > 0 then
			ds.kapot -= 1
			error("DataStore is even weg")
		end
		return ds.data[key]
	end
	function ds:SetAsync(key, waarde)
		ds.schrijfbeurten += 1
		ds.data[key] = waarde
	end
	function ds:UpdateAsync(key, f)
		ds.leesbeurten += 1
		-- In Roblox hangt deze aanroep even. Met `tijdens` kan een test daar iets in laten
		-- gebeuren -- een speler die net dan weggaat, bijvoorbeeld.
		if ds.tijdens then
			local h = ds.tijdens
			ds.tijdens = nil
			h(key)
		end
		if ds.kapot > 0 then
			ds.kapot -= 1
			error("DataStore is even weg")
		end
		local nieuw = f(ds.data[key])
		if nieuw == nil then return ds.data[key] end
		ds.schrijfbeurten += 1
		ds.data[key] = nieuw
		return nieuw
	end
	return ds
end

-- Een verse wereld per test: eigen spelers, eigen opslag, eigen modules.
function Stub.wereld(opties)
	opties = opties or {}
	local w = {}
	w.store = opties.store or nieuweStore()
	w.jobId = opties.jobId or "server-A"
	w.studio = opties.studio == true
	w.gespawnd = {}
	w.sluiters = {}
	w.waarschuwingen = {}
	-- Getallen die de volgende trekkingen moeten opleveren. Leeg = gewoon math.random.
	-- Hiermee is een uitslag af te dwingen zonder de spellen zelf aan te passen.
	w.volgende = {}

	local function trek(): number
		if #w.volgende > 0 then return table.remove(w.volgende, 1) :: number end
		return math.random()
	end
	w.trek = trek

	-- De klok staat stil tot een test hem vooruit zet. Zo is een cashout op de seconde
	-- na te rekenen zonder echt te wachten.
	w.klok = 1000
	function w.wacht(seconden: number)
		w.klok += seconden
	end

	local Players = { PlayerAdded = signaal(), PlayerRemoving = signaal() }
	local spelers = {}
	function Players:GetPlayers()
		local uit = {}
		for _, s in spelers do table.insert(uit, s) end
		return uit
	end
	function Players:GetPlayerByUserId(id)
		return spelers[id]
	end
	w.Players = Players

	function w.speler(id, naam)
		local s = { UserId = id, Name = naam or ("speler" .. id), Parent = Players }
		spelers[id] = s
		return s
	end
	function w.vertrek(s)
		spelers[s.UserId] = nil
		s.Parent = nil
		Players.PlayerRemoving:Fire(s)
	end

	local diensten = {
		Players = Players,
		RunService = { IsStudio = function() return w.studio end, IsServer = function() return true end },
		DataStoreService = { GetDataStore = function(_, _naam) return w.store end },
	}

	local werkruimte = {}
	function werkruimte:GetServerTimeNow()
		return w.klok
	end
	w.workspace = werkruimte

	local game = {}
	game.JobId = w.jobId
	function game:GetService(naam)
		local d = diensten[naam]
		if not d then error("onbekende dienst: " .. naam) end
		return d
	end
	function game:BindToClose(f)
		table.insert(w.sluiters, f)
	end
	w.game = game

	-- De boom waarin de modules elkaar opzoeken, precies zoals Rojo hem neerzet.
	local Server = {}
	local GamesScript = { Parent = Server }
	local MultiScript = { Parent = GamesScript }
	local ReplicatedStorage = { Shared = {} }
	diensten.ReplicatedStorage = ReplicatedStorage

	local geladen = {}
	local merk = {}   -- verwijzing -> modulenaam

	local Odds = require("../src/shared/Odds")
	local Money = require("../src/shared/Money")
	local Sha256 = require("../src/shared/Sha256")
	local SeasonMod = require("../src/shared/Season")
	local AchMod = require("../src/shared/Achievements")
	ReplicatedStorage.Shared.Odds = {}
	ReplicatedStorage.Shared.Money = {}
	ReplicatedStorage.Shared.Sha256 = {}
	ReplicatedStorage.Shared.Net = {}
	ReplicatedStorage.Shared.Season = {}
	ReplicatedStorage.Shared.Achievements = {}
	geladen[ReplicatedStorage.Shared.Odds] = Odds
	geladen[ReplicatedStorage.Shared.Money] = Money
	geladen[ReplicatedStorage.Shared.Sha256] = Sha256
	geladen[ReplicatedStorage.Shared.Season] = SeasonMod
	geladen[ReplicatedStorage.Shared.Achievements] = AchMod
	w.Odds = Odds
	w.Money = Money
	w.Sha256 = Sha256
	w.Season = SeasonMod
	w.Achievements = AchMod

	-- Een nagemaakte netwerklaag: geen echte RemoteEvents, wel een lijst van alles wat de
	-- server naar de clients heeft geduwd. Daar is op na te rekenen wat er wel en niet in
	-- stond op welk moment.
	w.geduwd = {}
	local NetStub = {}
	function NetStub.build() end
	function NetStub.ev(naam)
		return {
			FireAllClients = function(_self, lading)
				table.insert(w.geduwd, { kanaal = naam, lading = lading })
			end,
			FireClient = function(_self, speler, lading)
				table.insert(w.geduwd, { kanaal = naam, speler = speler, lading = lading })
			end,
		}
	end
	function NetStub.fn(naam)
		return { OnServerInvoke = nil }
	end
	geladen[ReplicatedStorage.Shared.Net] = NetStub
	w.Net = NetStub

	local BlackjackScript = { Parent = GamesScript }
	local CrashScript = { Parent = Server }
	Server.Profiles = {}
	Server.Games = GamesScript
	Server.Crash = CrashScript
	GamesScript.Multi = MultiScript
	GamesScript.Blackjack = BlackjackScript
	merk[Server.Profiles] = "Profiles"
	merk[GamesScript] = "Games"
	merk[MultiScript] = "Multi"
	merk[BlackjackScript] = "Blackjack"
	merk[CrashScript] = "Crash"

	local eigenRequire
	local function omgevingVoor(scriptRef)
		local env = setmetatable({}, { __index = getfenv(0) })
		env.game = game
		env.workspace = werkruimte
		env.script = scriptRef
		env.require = eigenRequire
		env.warn = function(...)
			local stukken = {}
			for i = 1, select("#", ...) do table.insert(stukken, tostring((select(i, ...)))) end
			table.insert(w.waarschuwingen, table.concat(stukken, " "))
		end
		env.Random = {
			new = function(_)
				local r = {}
				function r:NextNumber(min, max)
					local u = trek()
					if min and max then return min + u * (max - min) end
					return u
				end
				function r:NextInteger(min, max)
					return min + math.floor(trek() * (max - min + 1))
				end
				return r
			end,
		}
		-- task.spawn draait de functie meteen, want anders doet BindToClose niets en lijkt
		-- een test te slagen terwijl er in het geheel niets is opgeslagen. Dat het echt
		-- doorloopt is nodig; dat het niet blijft hangen ook, want Profiles heeft een
		-- oneindige autosave-lus. Daarom stopt task.wait binnen een spawn na een paar
		-- beurten met een foutmelding, die de pcall opvangt.
		local wachtTeller = 0
		local binnenSpawn = false
		local function spawn(f, ...)
			local was = binnenSpawn
			local tellerWas = wachtTeller
			binnenSpawn = true
			wachtTeller = 0
			local args = table.pack(...)
			pcall(function()
				f(table.unpack(args, 1, args.n))
			end)
			binnenSpawn = was
			wachtTeller = tellerWas
		end
		env.task = {
			wait = function(_)
				if binnenSpawn then
					wachtTeller += 1
					if wachtTeller > 3 then error("stub: lus afgebroken", 0) end
				end
				return 0
			end,
			spawn = spawn,
			delay = function(_, f, ...) spawn(f, ...) end,
			defer = function(f, ...) spawn(f, ...) end,
		}
		return env
	end

	local scripts = {
		Profiles = Server.Profiles, Games = GamesScript, Multi = MultiScript,
		Blackjack = BlackjackScript, Crash = CrashScript,
	}
	function eigenRequire(doel)
		if geladen[doel] then return geladen[doel] end
		local naam = merk[doel]
		if not naam then error("onbekende module in require") end
		local bron = bronnen[naam]
		if not bron then error("geen bron voor " .. naam) end
		local f, err = loadstring(bron, "=" .. naam)
		if not f then error("kon " .. naam .. " niet laden: " .. tostring(err)) end
		setfenv(f, omgevingVoor(scripts[naam]))
		local m = f()
		geladen[doel] = m
		return m
	end

	w.require = eigenRequire
	w.Profiles = eigenRequire(Server.Profiles)
	w.Games = eigenRequire(GamesScript)
	w.Multi = eigenRequire(MultiScript)
	w.Blackjack = eigenRequire(BlackjackScript)
	w.Crash = eigenRequire(CrashScript)
	return w
end

Stub.nieuweStore = nieuweStore
return Stub
