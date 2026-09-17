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

	local Players = { PlayerAdded = signaal(), PlayerRemoving = signaal() }
	local spelers = {}
	function Players:GetPlayers()
		local uit = {}
		for _, s in spelers do table.insert(uit, s) end
		return uit
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
		RunService = { IsStudio = function() return w.studio end },
		DataStoreService = { GetDataStore = function(_, _naam) return w.store end },
	}

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
	ReplicatedStorage.Shared.Odds = {}
	ReplicatedStorage.Shared.Money = {}
	geladen[ReplicatedStorage.Shared.Odds] = Odds
	geladen[ReplicatedStorage.Shared.Money] = Money
	w.Odds = Odds
	w.Money = Money

	Server.Profiles = {}
	Server.Games = GamesScript
	GamesScript.Multi = MultiScript
	merk[Server.Profiles] = "Profiles"
	merk[GamesScript] = "Games"
	merk[MultiScript] = "Multi"

	local eigenRequire
	local function omgevingVoor(scriptRef)
		local env = setmetatable({}, { __index = getfenv(0) })
		env.game = game
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
		env.task = {
			wait = function(_) return 0 end,
			spawn = function(f, ...) table.insert(w.gespawnd, f) end,
			delay = function(_, f) table.insert(w.gespawnd, f) end,
			defer = function(f) table.insert(w.gespawnd, f) end,
		}
		return env
	end

	local scripts = { Profiles = Server.Profiles, Games = GamesScript, Multi = MultiScript }
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
	return w
end

Stub.nieuweStore = nieuweStore
return Stub
