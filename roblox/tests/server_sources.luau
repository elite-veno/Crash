-- GEGENEREERD door tools/bundle_server.py -- niet met de hand aanpassen.
return {
	["Profiles"] = [[
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
local bezig: { [number]: boolean } = {}       -- lezen mislukt: niets overschrijven
local laden: { [number]: boolean } = {}       -- er wordt nu gelezen (GetAsync hangt)
local verlaten: { [number]: boolean } = {}    -- vertrokken terwijl er nog gelezen werd
local afgerond: { [number]: boolean } = {}    -- al afgesloten; niet twee keer schrijven

-- Zoveel seconden zonder levensteken en het slot van een andere server vervalt. Lager en
-- een server die crasht blokkeert de speler onnodig lang; hoger en twee servers kunnen
-- elkaar overschrijven.
local SLOT_VERVAL = 90
local AUTOSAVE = 120
local POGINGEN = 4

-- De haakjes die vlak voor het opslaan nog iets recht moeten zetten: een openstaande
-- inzet teruggeven bijvoorbeeld. Ze draaien BINNEN dit bestand, zodat de volgorde
-- vastligt en niet afhangt van welke Connect toevallig eerst is gemaakt.
local haken: { (Player) -> () } = {}

function Profiles.onLeave(f: (Player) -> ()): ()
	table.insert(haken, f)
end

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

-- Een DataStore-aanroep mag een keer misgaan: throttling en storingen horen erbij.
-- Zonder herhaling is een hele sessie weg door een hikje van een halve seconde.
local function metHerhaling(wat: string, f: () -> any): (boolean, any)
	local wacht = 0.5
	for poging = 1, POGINGEN do
		local ok, res = pcall(f)
		if ok then return true, res end
		if poging == POGINGEN then
			warn("[Profiles] " .. wat .. " mislukt na " .. POGINGEN .. " pogingen: " .. tostring(res))
			return false, res
		end
		task.wait(wacht)
		wacht *= 2
	end
	return false, nil
end

-- Mag deze server het profiel claimen? Het slot is van niemand, van onszelf, of het is
-- oud genoeg om vervallen te zijn. Los van Roblox opgeschreven, zodat het te testen is.
function Profiles.slotVrij(rec: any, jobId: string, nu: number): boolean
	if typeof(rec) ~= "table" then return true end
	local job = rec.lockJob
	if typeof(job) ~= "string" or job == "" or job == jobId then return true end
	local at = tonumber(rec.lockAt)
	if not at then return true end
	return nu - at > SLOT_VERVAL
end

local function jobId(): string
	-- In Studio is JobId leeg; dan is er toch maar een server.
	return if game.JobId ~= "" then game.JobId else "studio"
end

-- Het profiel plus het slot, zoals het in de DataStore terechtkomt. De slotvelden zitten
-- bewust NIET in Profile: dan kan Profiles.view ze ook niet per ongeluk doorsturen.
local function metSlot(p: Profile, vasthouden: boolean): any
	local rec: any = table.clone(p :: any)
	rec.updatedAt = os.time()
	rec.lockJob = if vasthouden then jobId() else nil
	rec.lockAt = if vasthouden then os.time() else nil
	return rec
end

function Profiles.load(speler: Player): Profile
	local id = speler.UserId
	if levend[id] then return levend[id] end

	-- Wordt er al gelezen, dan wachten we daarop in plaats van een tweede lezing te
	-- starten die de eerste zou overschrijven.
	if laden[id] then
		local tot = os.clock() + 30
		while laden[id] and os.clock() < tot do
			task.wait(0.1)
		end
		if levend[id] then return levend[id] end
	end

	-- Een nieuwe sessie van dezelfde speler op deze server begint met een schone lei.
	verlaten[id] = nil
	afgerond[id] = nil
	bezig[id] = nil

	local p = Profiles.fresh()
	if not store then
		levend[id] = p
		return p
	end

	laden[id] = true

	local mij = jobId()
	local geclaimd = false
	local geblokkeerd = false
	for ronde = 1, 3 do
		geblokkeerd = false
		local ok, res = metHerhaling("profiel lezen voor " .. id, function()
			return store:UpdateAsync(sleutel(id), function(oud: any): any
				if not Profiles.slotVrij(oud, mij, os.time()) then
					geblokkeerd = true
					return nil
				end
				local nieuw = heel(oud)
				return metSlot(nieuw, true)
			end)
		end)
		if ok and not geblokkeerd then
			p = heel(res)
			geclaimd = true
			break
		end
		if not ok then
			-- Lezen lukte niet. Doorspelen op een vers profiel mag, opslaan niet: anders
			-- wist deze sessie iemands echte voortgang.
			bezig[id] = true
			break
		end
		-- Een andere server heeft het profiel nog vast. Even wachten: normaal laat hij
		-- los zodra zijn laatste save klaar is.
		task.wait(3)
	end
	if geblokkeerd and not geclaimd then
		warn("[Profiles] " .. id .. " staat nog open op een andere server; deze sessie slaat niet op")
		bezig[id] = true
	end

	laden[id] = nil
	if verlaten[id] or speler.Parent ~= Players then
		-- Vertrokken terwijl we aan het lezen waren. Niet in `levend` zetten, anders
		-- blijft er een profiel hangen dat nooit meer wordt losgelaten en dat bij een
		-- herstart van dezelfde speler als "al geladen" wordt teruggegeven.
		verlaten[id] = nil
		bezig[id] = nil
		if geclaimd then
			metHerhaling("slot teruggeven voor " .. id, function()
				return store:UpdateAsync(sleutel(id), function(oud: any): any
					if typeof(oud) ~= "table" then return nil end
					oud.lockJob = nil
					oud.lockAt = nil
					return oud
				end)
			end)
		end
		return p
	end

	levend[id] = p
	return p
end

function Profiles.get(speler: Player): Profile?
	return levend[speler.UserId]
end

-- `vrijgeven` betekent: dit was de laatste schrijfbeurt, het slot mag los.
local function schrijf(speler: Player, vrijgeven: boolean): ()
	local id = speler.UserId
	local p = levend[id]
	if not p or not store then return end
	if bezig[id] then return end   -- lezen was mislukt; niets overschrijven
	local mij = jobId()
	metHerhaling("profiel opslaan voor " .. id, function()
		return store:UpdateAsync(sleutel(id), function(oud: any): any
			-- Heeft een andere server het slot intussen overgenomen, dan is zijn versie
			-- de jongste en laten we die met rust.
			if typeof(oud) == "table" then
				local job = oud.lockJob
				if typeof(job) == "string" and job ~= "" and job ~= mij then return nil end
			end
			return metSlot(p, not vrijgeven)
		end)
	end)
end

function Profiles.save(speler: Player): ()
	schrijf(speler, false)
end

-- De hele afsluiting op een plek: eerst de haakjes (die een openstaande inzet
-- teruggeven), dan pas opslaan. Andersom verdwijnt het geld, want dan is het saldo al
-- weggeschreven voordat de teruggave erin staat.
function Profiles.finish(speler: Player): ()
	local id = speler.UserId
	if afgerond[id] then return end
	afgerond[id] = true
	if laden[id] then
		-- Nog aan het lezen: de lezing zelf ruimt straks op.
		verlaten[id] = true
		return
	end
	for _, f in haken do
		local ok, err = pcall(function(): any
			f(speler)
			return nil
		end)
		if not ok then warn("[Profiles] opruimen mislukt voor " .. id .. ": " .. tostring(err)) end
	end
	schrijf(speler, true)
	levend[id] = nil
	bezig[id] = nil
	verlaten[id] = nil
end

function Profiles.release(speler: Player): ()
	Profiles.finish(speler)
end

-- ---------- geld ----------
-- De enige plek waar een saldo verandert. Alles gaat hierlangs, zodat er nergens anders
-- per ongeluk geld bij kan komen.
function Profiles.take(speler: Player, bedrag: number): boolean
	local p = levend[speler.UserId]
	if not p then return false end
	-- NaN en oneindig komen hier nooit langs. Een saldo dat eenmaal NaN is, is dat voor
	-- altijd: elke som ermee wordt weer NaN, en JSON kan het niet eens opslaan.
	if bedrag ~= bedrag or bedrag == math.huge then return false end
	if bedrag <= 0 then return false end
	if p.balance + 1e-9 < bedrag then return false end
	p.balance = Money.round2(p.balance - bedrag)
	return true
end

function Profiles.give(speler: Player, bedrag: number): ()
	local p = levend[speler.UserId]
	if not p or bedrag <= 0 then return end
	if bedrag ~= bedrag or bedrag == math.huge then return end
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
	Profiles.finish(speler)
end)

-- Bij het sluiten van de server staat er vaak nog van alles open. Dezelfde afsluiting als
-- bij weggaan, en naast elkaar: Roblox geeft hier maar een halve minuut voor.
game:BindToClose(function()
	local bezigMet = 0
	for _, speler in Players:GetPlayers() do
		bezigMet += 1
		task.spawn(function()
			Profiles.finish(speler)
			bezigMet -= 1
		end)
	end
	local tot = os.clock() + 25
	while bezigMet > 0 and os.clock() < tot do
		task.wait(0.1)
	end
end)

-- Tussentijds opslaan. Gaat er iets mis met de laatste schrijfbeurt, dan kost dat
-- minuten in plaats van een hele sessie.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for _, speler in Players:GetPlayers() do
			if levend[speler.UserId] then Profiles.save(speler) end
		end
	end
end)

return Profiles
]],
	["Games"] = [[
--!strict
-- De spellen, afgerekend op de server. De client stuurt een inzet en een keuze; wat er
-- uitkomt wordt hier bepaald en teruggegeven. Zo kan niemand zijn eigen uitslag schrijven.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Profiles = require(script.Parent.Profiles)

local Games = {}

-- Een echte trekker op de server; Odds krijgt hem van buiten aangereikt.
local rng = Random.new()
Odds.setRandom(function()
	return rng:NextNumber()
end)

-- Spellen die uit meerdere beurten bestaan houden hun stand hier vast, per speler.
-- Nooit bij de client: die zou hem kunnen aanpassen.
type Open = {
	game: string,
	bet: number,
	-- tower
	diff: string?,
	layout: { { boolean } }?,
	level: number?,
	-- mines
	grid: { boolean }?,
	mines: number?,
	-- bus
	deck: { Odds.Card }?,
	shown: { Odds.Card }?,
	step: number?,
	prob: number?,
	-- blackjack (solo)
	shoe: { Odds.Card }?,
	player: { Odds.Card }?,
	dealer: { Odds.Card }?,
	doubled: boolean?,
	-- scratch
	cells: { string }?,
	prize: number?,
	revealed: { boolean }?,
}

local open: { [number]: Open } = {}

function Games.openOf(speler: Player): Open?
	return open[speler.UserId]
end

-- Wat er nog in het spel zit als een speler weggaat: teruggeven, niet laten verdampen.
-- Profiles roept dit zelf aan, vlak voor het opslaan; zo staat de teruggave gegarandeerd
-- in het saldo dat wordt weggeschreven.
function Games.refund(speler: Player): ()
	local o = open[speler.UserId]
	if not o then return end
	open[speler.UserId] = nil
	Profiles.give(speler, o.bet)
end

local function start(speler: Player, spel: string, inzet: any): (number?, string?)
	local p = Profiles.get(speler)
	if not p then return nil, "geen profiel" end
	if open[speler.UserId] then return nil, "je hebt nog een ronde open" end
	local bet = Money.cleanBet(inzet, p.balance)
	if not bet then return nil, "ongeldige inzet" end
	if not Profiles.take(speler, bet) then return nil, "onvoldoende saldo" end
	return bet, nil
end

local function settle(speler: Player, spel: string, inzet: number, uit: number, mult: number): ()
	if uit > 0 then Profiles.give(speler, uit) end
	Profiles.record(speler, spel, inzet, uit, mult)
end

-- ---------- spellen in één beurt ----------

function Games.roulette(speler: Player, inzetten: any): any
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	if typeof(inzetten) ~= "table" then return { ok = false, err = "geen inzetten" } end

	-- Alles eerst optellen en één keer afschrijven, zodat een gedeeltelijke inzet
	-- niet half kan slagen.
	local totaal = 0
	local schoon: { { key: string, bet: number } } = {}
	for key, bedrag in inzetten do
		if typeof(key) ~= "string" then continue end
		-- Door dezelfde zeef als een enkele inzet: die vangt NaN en oneindig af, wat een
		-- gewone `b < MIN_BET` nooit doet.
		local b = Money.cleanAmount(bedrag)
		if not b then continue end
		totaal += b
		table.insert(schoon, { key = key, bet = b })
	end
	if #schoon == 0 then return { ok = false, err = "geen inzetten" } end
	totaal = Money.round2(totaal)
	if not Profiles.take(speler, totaal) then return { ok = false, err = "onvoldoende saldo" } end

	local n = Odds.ROULETTE_ORDER[rng:NextInteger(1, #Odds.ROULETTE_ORDER)]
	local uit = 0
	for _, s in schoon do
		uit += s.bet * Odds.roulettePayout(s.key, n)
	end
	uit = Money.floor2(uit)
	settle(speler, "roulette", totaal, uit, if uit > 0 then uit / totaal else 0)
	return { ok = true, number = n, color = Odds.rouletteColor(n), payout = uit, balance = p.balance }
end

function Games.plinko(speler: Player, inzet: any, rows: any, risk: any): any
	local rr = tonumber(rows)
	local ri = tostring(risk)
	-- Bevestigend controleren in plaats van ontkennend: dan weet de analyzer ook dat
	-- r vanaf hier zeker een getal is.
	local r: number
	if rr == 8 or rr == 12 or rr == 16 then
		r = rr :: number
	else
		return { ok = false, err = "ongeldig aantal rijen" }
	end
	if ri ~= "low" and ri ~= "medium" and ri ~= "high" then return { ok = false, err = "ongeldig risico" } end
	local bet, err = start(speler, "plinko", inzet)
	if not bet then return { ok = false, err = err } end

	local pad = Odds.plinkoPath(r)
	local vak = 0
	for _, stap in pad do vak += stap end
	local tabel = Odds.plinkoTable(r, ri)
	local mult = tabel[vak + 1]
	local uit = Money.floor2(bet * mult)
	settle(speler, "plinko", bet, uit, mult)
	local p = Profiles.get(speler)
	return { ok = true, path = pad, bucket = vak, mult = mult, payout = uit, balance = if p then p.balance else 0 }
end

function Games.scratchBuy(speler: Player, inzet: any): any
	local bet, err = start(speler, "scratch", inzet)
	if not bet then return { ok = false, err = err } end
	local prize = Odds.scratchDraw()
	local cells = Odds.scratchGrid(prize)
	open[speler.UserId] = {
		game = "scratch", bet = bet, cells = cells, prize = prize,
		revealed = table.create(Odds.SCRATCH_CELLS, false),
	}
	-- De cellen gaan NIET mee naar de client: die krijgt ze pas als hij ze openkrast.
	local p = Profiles.get(speler)
	return { ok = true, cells = Odds.SCRATCH_CELLS, balance = if p then p.balance else 0 }
end

function Games.scratchReveal(speler: Player, index: any): any
	local o = open[speler.UserId]
	if not o or o.game ~= "scratch" then return { ok = false, err = "geen lot" } end
	local cells = o.cells :: { string }
	local revealed = o.revealed :: { boolean }
	-- Een heel getal binnen het rooster, anders niet. revealed[1.5] leest nil en
	-- revealed[NaN] = true laat de RemoteFunction klappen.
	local i = Money.cleanIndex(index, 1, #cells)
	if not i or revealed[i] then return { ok = false, err = "dat vakje niet" } end
	revealed[i] = true

	local allesOpen = true
	for _, v in revealed do
		if not v then
			allesOpen = false
			break
		end
	end
	if not allesOpen then
		return { ok = true, index = i, symbol = cells[i], done = false }
	end

	open[speler.UserId] = nil
	local mult = Odds.scratchPayout(cells)
	local uit = Money.floor2(o.bet * mult)
	settle(speler, "scratch", o.bet, uit, mult)
	local p = Profiles.get(speler)
	return {
		ok = true, index = i, symbol = cells[i], done = true,
		mult = mult, payout = uit, balance = if p then p.balance else 0,
	}
end

function Games.slots(speler: Player, inzet: any): any
	local bet, err = start(speler, "slots", inzet)
	if not bet then return { ok = false, err = err } end
	local idx = Odds.slotDraw()
	local reels = Odds.slotReels(idx)
	local mult = Odds.slotPayout(reels)
	local uit = Money.floor2(bet * mult)
	settle(speler, "slots", bet, uit, mult)
	local p = Profiles.get(speler)
	return { ok = true, reels = reels, mult = mult, payout = uit, balance = if p then p.balance else 0 }
end

function Games.wheel(speler: Player, inzet: any): any
	local bet, err = start(speler, "wheel", inzet)
	if not bet then return { ok = false, err = err } end
	local vak = Odds.wheelSpin()
	local mult = Odds.WHEEL[vak]
	local uit = Money.floor2(bet * mult)
	settle(speler, "wheel", bet, uit, mult)
	local p = Profiles.get(speler)
	return { ok = true, slot = vak, mult = mult, payout = uit, balance = if p then p.balance else 0 }
end

function Games.horse(speler: Player, inzetten: any): any
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	if typeof(inzetten) ~= "table" then return { ok = false, err = "geen inzetten" } end

	local kansen = Odds.horseField()
	local totaal = 0
	local schoon: { { i: number, bet: number } } = {}
	for i, bedrag in inzetten do
		local idx = Money.cleanIndex(i, 1, #Odds.HORSES)
		local b = Money.cleanAmount(bedrag)
		if not idx or not b then continue end
		totaal += b
		table.insert(schoon, { i = idx, bet = b })
	end
	if #schoon == 0 then return { ok = false, err = "geen inzetten" } end
	totaal = Money.round2(totaal)
	if not Profiles.take(speler, totaal) then return { ok = false, err = "onvoldoende saldo" } end

	local volgorde = Odds.horseRanking(kansen)
	local winnaar = volgorde[1]
	local uit = 0
	for _, s in schoon do
		if s.i == winnaar then
			uit += Money.floor2(s.bet * Odds.horseMultiplier(kansen[winnaar]))
		end
	end
	uit = Money.floor2(uit)
	settle(speler, "horse", totaal, uit, if uit > 0 then uit / totaal else 0)
	return {
		ok = true, order = volgorde, probs = kansen, winner = winnaar,
		payout = uit, balance = p.balance,
	}
end

Profiles.onLeave(Games.refund)

return Games
]],
	["Multi"] = [[
--!strict
-- De spellen die uit meerdere beurten bestaan. De stand staat op de server: welke tegels
-- veilig zijn, welke kaarten er nog in de stapel zitten, hoe ver je bent. De client krijgt
-- alleen te zien wat hij op dat moment mag weten.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Profiles = require(script.Parent.Parent.Profiles)

local Multi = {}

export type Open = {
	game: string,
	bet: number,
	diff: string?,
	layout: { { boolean } }?,
	level: number?,
	grid: { boolean }?,
	-- Welke tegels al open liggen, niet alleen hoeveel: anders kun je dezelfde veilige
	-- tegel blijven insturen en zo de multiplier omhoog tikken zonder risico.
	opened: { [number]: boolean }?,
	picked: number?,
	mines: number?,
	deck: { Odds.Card }?,
	shown: { Odds.Card }?,
	step: number?,
	prob: number?,
	shoe: { Odds.Card }?,
	hand: { Odds.Card }?,
	dealer: { Odds.Card }?,
	doubled: boolean?,
}

local open: { [number]: Open } = {}

function Multi.get(speler: Player): Open?
	return open[speler.UserId]
end

-- Loopt een speler weg met een ronde open, dan krijgt hij zijn inzet terug. Stil laten
-- verdampen is het ergste wat je met andermans geld kunt doen.
function Multi.refund(speler: Player): number
	local o = open[speler.UserId]
	if not o then return 0 end
	open[speler.UserId] = nil
	local terug = o.bet * (if o.doubled then 2 else 1)
	Profiles.give(speler, terug)
	return terug
end

local function begin(speler: Player, inzet: any): (number?, string?)
	local p = Profiles.get(speler)
	if not p then return nil, "geen profiel" end
	if open[speler.UserId] then return nil, "je hebt nog een ronde open" end
	local bet = Money.cleanBet(inzet, p.balance)
	if not bet then return nil, "ongeldige inzet" end
	if not Profiles.take(speler, bet) then return nil, "onvoldoende saldo" end
	return bet, nil
end

local function saldo(speler: Player): number
	local p = Profiles.get(speler)
	return if p then p.balance else 0
end

local function afrekenen(speler: Player, spel: string, inzet: number, uit: number, mult: number)
	open[speler.UserId] = nil
	if uit > 0 then Profiles.give(speler, uit) end
	Profiles.record(speler, spel, inzet, uit, mult)
end

-- ---------- Dragon Tower ----------
function Multi.towerStart(speler: Player, inzet: any, diff: any): any
	local d = tostring(diff)
	if not Odds.TOWER_DIFF[d] then return { ok = false, err = "onbekende moeilijkheid" } end
	local bet, err = begin(speler, inzet)
	if not bet then return { ok = false, err = err } end
	open[speler.UserId] = { game = "tower", bet = bet, diff = d, layout = Odds.towerLayout(d), level = 0 }
	return { ok = true, tiles = Odds.TOWER_DIFF[d].tiles, balance = saldo(speler) }
end

function Multi.towerPick(speler: Player, kolom: any): any
	local o = open[speler.UserId]
	if not o or o.game ~= "tower" then return { ok = false, err = "geen toren" } end
	local d = Odds.TOWER_DIFF[o.diff :: string]
	local k = Money.cleanIndex(kolom, 1, d.tiles)
	if not k then return { ok = false, err = "die tegel niet" } end

	local niveau = (o.level :: number) + 1
	local rij = (o.layout :: { { boolean } })[niveau]
	local veilig = rij[k]
	if not veilig then
		afrekenen(speler, "tower", o.bet, 0, 0)
		return { ok = true, safe = false, row = rij, payout = 0, balance = saldo(speler) }
	end

	o.level = niveau
	local mult = Odds.towerMultiplier(o.diff :: string, niveau)
	if niveau >= Odds.TOWER_LEVELS then
		local uit = Money.floor2(o.bet * mult)
		afrekenen(speler, "tower", o.bet, uit, mult)
		return { ok = true, safe = true, row = rij, done = true, mult = mult, payout = uit, balance = saldo(speler) }
	end
	return { ok = true, safe = true, level = niveau, mult = mult }
end

function Multi.towerCashOut(speler: Player): any
	local o = open[speler.UserId]
	if not o or o.game ~= "tower" then return { ok = false, err = "geen toren" } end
	local niveau = o.level :: number
	if niveau < 1 then return { ok = false, err = "nog niets gehaald" } end
	local mult = Odds.towerMultiplier(o.diff :: string, niveau)
	local uit = Money.floor2(o.bet * mult)
	afrekenen(speler, "tower", o.bet, uit, mult)
	return { ok = true, mult = mult, payout = uit, balance = saldo(speler) }
end

-- ---------- Mines ----------
function Multi.minesStart(speler: Player, inzet: any, mijnen: any): any
	local m = Money.cleanIndex(mijnen, 1, 24)
	if not m then return { ok = false, err = "tussen 1 en 24 mijnen" } end
	local bet, err = begin(speler, inzet)
	if not bet then return { ok = false, err = err } end
	open[speler.UserId] = { game = "mines", bet = bet, grid = Odds.minesLayout(m), opened = {}, picked = 0, mines = m }
	return { ok = true, tiles = Odds.MINES_TILES, balance = saldo(speler) }
end

function Multi.minesPick(speler: Player, tegel: any): any
	local o = open[speler.UserId]
	if not o or o.game ~= "mines" then return { ok = false, err = "geen veld" } end
	local grid = o.grid :: { boolean }
	local opened = o.opened :: { [number]: boolean }
	-- Een heel tegelnummer, anders niet: grid[1.5] leest nil, en nil is geen mijn.
	local i = Money.cleanIndex(tegel, 1, #grid)
	if not i then return { ok = false, err = "die tegel niet" } end
	-- Twee keer dezelfde tegel telt niet twee keer mee. Zo staat het ook in de webversie
	-- (MN.revealed.includes(i) in mnPick).
	if opened[i] then return { ok = false, err = "die tegel ligt al open" } end

	if grid[i] then
		afrekenen(speler, "mines", o.bet, 0, 0)
		return { ok = true, mine = true, grid = grid, payout = 0, balance = saldo(speler) }
	end

	opened[i] = true
	local gepakt = (o.picked :: number) + 1
	o.picked = gepakt
	local mult = Odds.minesMultiplier(o.mines :: number, gepakt)
	local over = Odds.MINES_TILES - (o.mines :: number)
	if gepakt >= over then
		local uit = Money.floor2(o.bet * mult)
		afrekenen(speler, "mines", o.bet, uit, mult)
		return { ok = true, mine = false, done = true, mult = mult, payout = uit, balance = saldo(speler) }
	end
	return { ok = true, mine = false, picked = gepakt, mult = mult }
end

function Multi.minesCashOut(speler: Player): any
	local o = open[speler.UserId]
	if not o or o.game ~= "mines" then return { ok = false, err = "geen veld" } end
	local gepakt = o.picked :: number
	if gepakt < 1 then return { ok = false, err = "nog niets gepakt" } end
	local mult = Odds.minesMultiplier(o.mines :: number, gepakt)
	local uit = Money.floor2(o.bet * mult)
	afrekenen(speler, "mines", o.bet, uit, mult)
	return { ok = true, mult = mult, payout = uit, grid = o.grid, balance = saldo(speler) }
end

-- ---------- Ride the Bus ----------
-- Wat de client mag weten om de knoppen te tekenen: per keuze de kans, geteld op de
-- kaarten die nog in de stapel zitten. Een kans van 0 wordt straks geweigerd, dus die
-- knop hoort grijs te staan -- net als in buRender in de webversie.
local function busKansen(deck: { Odds.Card }, stap: number, shown: { Odds.Card }): { { key: string, label: string, chance: number } }
	local uit = {}
	for _, paar in Odds.busOptions(stap) do
		table.insert(uit, {
			key = paar[1],
			label = paar[2],
			chance = Odds.busChance(deck, stap, paar[1], shown),
		})
	end
	return uit
end

function Multi.busStart(speler: Player, inzet: any): any
	local bet, err = begin(speler, inzet)
	if not bet then return { ok = false, err = err } end
	local deck = Odds.bjNewShoe(1)
	open[speler.UserId] = { game = "bus", bet = bet, deck = deck, shown = {}, step = 0, prob = 1 }
	return { ok = true, options = busKansen(deck, 1, {}), balance = saldo(speler) }
end

function Multi.busCall(speler: Player, keuze: any): any
	local o = open[speler.UserId]
	if not o or o.game ~= "bus" then return { ok = false, err = "geen rit" } end
	local stap = (o.step :: number) + 1
	if stap > #Odds.BUS_STEPS then return { ok = false, err = "de rit is voorbij" } end

	local k = tostring(keuze)
	local geldig = false
	for _, paar in Odds.busOptions(stap) do
		if paar[1] == k then
			geldig = true
			break
		end
	end
	if not geldig then return { ok = false, err = "die call niet" } end

	local deck = o.deck :: { Odds.Card }
	local shown = o.shown :: { Odds.Card }
	-- De kans wordt geteld op de kaarten die nog in de stapel zitten, precies zoals in
	-- de webversie: daardoor klopt de multiplier ook als je slecht raadt.
	local kans = Odds.busChance(deck, stap, k, shown)
	-- Een call die niet kan uitkomen is geen call. De webversie weigert hem ook
	-- (`if (p <= 0) return;` in buCall), en er wordt dus geen kaart getrokken.
	if kans <= 0 then return { ok = false, err = "die call kan niet uitkomen" } end
	local kaart = table.remove(deck) :: Odds.Card
	local raak = Odds.busHit(kaart, stap, k, shown)
	table.insert(shown, kaart)
	o.step = stap

	if not raak then
		afrekenen(speler, "bus", o.bet, 0, 0)
		return { ok = true, card = kaart, hit = false, payout = 0, balance = saldo(speler) }
	end

	local prob = (o.prob :: number) * kans
	o.prob = prob
	local mult = Odds.busMultiplier(prob)
	if stap >= #Odds.BUS_STEPS then
		local uit = Money.floor2(o.bet * mult)
		afrekenen(speler, "bus", o.bet, uit, mult)
		return { ok = true, card = kaart, hit = true, done = true, mult = mult, payout = uit, balance = saldo(speler) }
	end
	return {
		ok = true, card = kaart, hit = true, step = stap, mult = mult,
		options = busKansen(deck, stap + 1, shown),
	}
end

function Multi.busCashOut(speler: Player): any
	local o = open[speler.UserId]
	if not o or o.game ~= "bus" then return { ok = false, err = "geen rit" } end
	if (o.step :: number) < 1 then return { ok = false, err = "nog geen call gemaakt" } end
	local mult = Odds.busMultiplier(o.prob :: number)
	local uit = Money.floor2(o.bet * mult)
	afrekenen(speler, "bus", o.bet, uit, mult)
	return { ok = true, mult = mult, payout = uit, balance = saldo(speler) }
end

Profiles.onLeave(function(speler: Player)
	Multi.refund(speler)
end)

return Multi
]],
}
