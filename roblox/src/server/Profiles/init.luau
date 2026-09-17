--!strict
-- Het profiel van een speler: saldo, statistieken, prestaties, titels.
--
-- Dit is het grootste verschil met de webversie. Daar rekent alleen crash op de server af
-- en doen de tien andere spellen dat in de browser, wat in principe te bewerken is. Hier
-- staat alles in ServerScriptService en kan de client er per definitie niet bij: hij mag
-- een inzet en een keuze sturen, nooit een bedrag.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Money = require(game:GetService("ReplicatedStorage").Shared.Money)

local Profiles = {}

export type Stats = {
	rounds: number,
	won: number,
	lost: number,
	highest: number,
	profit: number,
}

export type Profile = {
	balance: number,
	rounds: number,
	won: number,
	lost: number,
	profit: number,
	stats: { [string]: Stats },
	achievements: { [string]: number },
	featured: { string },
	titles: { string },
	title: string?,
	titleSeason: number?,
	resetSeason: number?,
	seasonStart: number,
	updatedAt: number,
}

Profiles.GAMES = {
	"crash", "roulette", "tower", "mines", "plinko", "blackjack",
	"horse", "scratch", "wheel", "slots", "bus",
}

local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore("NeonCasino_v1")
local levend: { [number]: Profile } = {}
local bezig: { [number]: boolean } = {}

local function versStats(): Stats
	return { rounds = 0, won = 0, lost = 0, highest = 0, profit = 0 }
end

function Profiles.fresh(): Profile
	local stats: { [string]: Stats } = {}
	for _, g in Profiles.GAMES do
		stats[g] = versStats()
	end
	return {
		balance = Money.START,
		rounds = 0, won = 0, lost = 0, profit = 0,
		stats = stats,
		achievements = {},
		featured = {},
		titles = {},
		title = nil,
		titleSeason = nil,
		resetSeason = nil,
		seasonStart = Money.START,
		updatedAt = os.time(),
	}
end

-- Vult ontbrekende velden aan, zodat een profiel van een oudere versie blijft werken.
local function heel(p: any): Profile
	local uit = Profiles.fresh()
	if typeof(p) ~= "table" then return uit end
	uit.balance = tonumber(p.balance) or uit.balance
	uit.rounds = tonumber(p.rounds) or 0
	uit.won = tonumber(p.won) or 0
	uit.lost = tonumber(p.lost) or 0
	uit.profit = tonumber(p.profit) or 0
	uit.seasonStart = tonumber(p.seasonStart) or Money.START
	uit.resetSeason = tonumber(p.resetSeason)
	uit.title = if typeof(p.title) == "string" then p.title else nil
	uit.titleSeason = tonumber(p.titleSeason)
	if typeof(p.stats) == "table" then
		for _, g in Profiles.GAMES do
			local s = p.stats[g]
			if typeof(s) == "table" then
				uit.stats[g] = {
					rounds = tonumber(s.rounds) or 0,
					won = tonumber(s.won) or 0,
					lost = tonumber(s.lost) or 0,
					highest = tonumber(s.highest) or 0,
					profit = tonumber(s.profit) or 0,
				}
			end
		end
	end
	if typeof(p.achievements) == "table" then
		for k, v in p.achievements do
			if typeof(k) == "string" and tonumber(v) then
				uit.achievements[k] = tonumber(v) :: number
			end
		end
	end
	if typeof(p.featured) == "table" then
		for _, v in p.featured do
			if typeof(v) == "string" and #uit.featured < 3 then
				table.insert(uit.featured, v)
			end
		end
	end
	if typeof(p.titles) == "table" then
		for _, v in p.titles do
			if typeof(v) == "string" then table.insert(uit.titles, v) end
		end
	end
	return uit
end

local function sleutel(id: number): string
	return "speler_" .. id
end

function Profiles.load(speler: Player): Profile
	local id = speler.UserId
	if levend[id] then return levend[id] end
	local p = Profiles.fresh()
	if store then
		local ok, res = pcall(function()
			return store:GetAsync(sleutel(id))
		end)
		if ok and res then
			p = heel(res)
		elseif not ok then
			-- Kon niet lezen: speel verder op een vers profiel, maar sla NIET op, anders
			-- overschrijven we straks iemands echte voortgang met een lege.
			warn("profiel lezen mislukt voor " .. id .. ": " .. tostring(res))
			bezig[id] = true
		end
	end
	levend[id] = p
	return p
end

function Profiles.get(speler: Player): Profile?
	return levend[speler.UserId]
end

function Profiles.save(speler: Player): ()
	local id = speler.UserId
	local p = levend[id]
	if not p or not store then return end
	if bezig[id] then return end   -- lezen was mislukt; niets overschrijven
	p.updatedAt = os.time()
	local ok, err = pcall(function()
		store:SetAsync(sleutel(id), p)
	end)
	if not ok then
		warn("profiel opslaan mislukt voor " .. id .. ": " .. tostring(err))
	end
end

function Profiles.release(speler: Player): ()
	Profiles.save(speler)
	levend[speler.UserId] = nil
	bezig[speler.UserId] = nil
end

-- ---------- geld ----------
-- De enige plek waar een saldo verandert. Alles gaat hierlangs, zodat er nergens anders
-- per ongeluk geld bij kan komen.
function Profiles.take(speler: Player, bedrag: number): boolean
	local p = levend[speler.UserId]
	if not p then return false end
	if bedrag <= 0 then return false end
	if p.balance + 1e-9 < bedrag then return false end
	p.balance = Money.round2(p.balance - bedrag)
	return true
end

function Profiles.give(speler: Player, bedrag: number): ()
	local p = levend[speler.UserId]
	if not p or bedrag <= 0 then return end
	p.balance = Money.round2(p.balance + bedrag)
end

-- Een afgelopen ronde boeken. `inzet` is wat er is ingezet, `uit` wat eruit kwam.
function Profiles.record(speler: Player, spel: string, inzet: number, uit: number, mult: number): ()
	local p = levend[speler.UserId]
	if not p then return end
	local s = p.stats[spel]
	if not s then return end
	s.rounds += 1
	p.rounds += 1
	if uit > inzet + 1e-9 then
		s.won += 1
		p.won += 1
	elseif uit < inzet - 1e-9 then
		s.lost += 1
		p.lost += 1
	end
	s.profit = Money.round2(s.profit + uit - inzet)
	p.profit = Money.round2(p.profit + uit - inzet)
	if mult > s.highest then s.highest = mult end
end

-- Wat de client mag zien. Precies genoeg om het scherm te vullen, niets meer.
function Profiles.view(speler: Player): Profile?
	local p = levend[speler.UserId]
	if not p then return nil end
	return p
end

Players.PlayerRemoving:Connect(function(speler)
	Profiles.release(speler)
end)

game:BindToClose(function()
	for _, speler in Players:GetPlayers() do
		Profiles.save(speler)
	end
end)

return Profiles
