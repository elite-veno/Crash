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

local Gedeeld = game:GetService("ReplicatedStorage").Shared
local Money = require(Gedeeld.Money)
local Season = require(Gedeeld.Season)
local Achievements = require(Gedeeld.Achievements)

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
	-- Het boekje naast de statistieken: reeksen, records per spel, en de gebeurtenissen
	-- die je niet uit de totalen kunt aflezen.
	extra: Achievements.Extra,
	featured: { string },
	titles: { string },
	title: string?,
	titleSeason: number?,
	resetSeason: number?,
	seasonStart: number,
	-- De lopende sprint, en wat je er tot nu toe aan overgehouden hebt. Daar wordt de
	-- ranglijst op gescoord.
	sprint: number?,
	sprintProfit: number,
	-- Tot en met welke sprint de prijzen al zijn uitgedeeld aan deze speler.
	awardedSprint: number?,
	-- Het seizoen waarvoor zijn VIP-pas geldt, of niets.
	vipSeason: number?,
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

local POGINGEN = 4

-- Hoe vaak het profiel tussentijds wordt weggeschreven. Elke schrijfbeurt zet het slot
-- opnieuw op de klok, dus dit is ook het tempo van het levensteken.
local AUTOSAVE = 60

-- Zoveel seconden zonder levensteken en het slot van een andere server vervalt.
--
-- Dit moet ruim boven AUTOSAVE liggen en niet eronder. Stond het slot eerder af dan het
-- volgende levensteken -- 90 tegen 120, zoals hier eerst -- dan lijkt een speler die
-- gewoon zit te spelen elke ronde dertig seconden lang verlaten, en kan een tweede server
-- zijn profiel oppakken. Twee servers die hetzelfde saldo bijhouden is geld dat verdwijnt
-- of geld dat er twee keer is.
--
-- Drie beurten missen mag dus, en dan pas is het slot van iemand anders. Een schrijfbeurt
-- die stukloopt doet er hooguit een paar seconden over (POGINGEN met verdubbelende wacht),
-- dus een server die leeft haalt die drie ruimschoots. Eentje die crasht houdt de speler
-- drie minuten tegen, en dat is de goede kant om op te missen.
local SLOT_VERVAL = AUTOSAVE * 3

-- Naar buiten toe zichtbaar zodat de test het verband kan nakijken in plaats van de
-- getallen over te schrijven: hij faalt als iemand ze ooit weer langs elkaar heen zet.
Profiles.AUTOSAVE = AUTOSAVE
Profiles.SLOT_VERVAL = SLOT_VERVAL

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
		extra = Achievements.fresh(),
		featured = {},
		titles = {},
		title = nil,
		titleSeason = nil,
		resetSeason = Season.seasonId(),
		seasonStart = Money.START,
		sprint = Season.sprintId(),
		sprintProfit = 0,
		awardedSprint = nil,
		vipSeason = nil,
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
	uit.sprint = tonumber(p.sprint)
	uit.sprintProfit = tonumber(p.sprintProfit) or 0
	uit.awardedSprint = tonumber(p.awardedSprint)
	uit.vipSeason = tonumber(p.vipSeason)
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
	-- Het boekje veld voor veld overzetten: wat er niet in staat blijft op de verse waarde,
	-- zodat een profiel van een oudere versie gewoon doorloopt.
	if typeof(p.extra) == "table" then
		local o = p.extra
		local e = uit.extra
		e.streak = tonumber(o.streak) or 0
		e.bestStreak = tonumber(o.bestStreak) or 0
		e.bigWin = tonumber(o.bigWin) or 0
		e.crashAbove2 = tonumber(o.crashAbove2) or 0
		e.towerLevel = tonumber(o.towerLevel) or 0
		e.minesMines = tonumber(o.minesMines) or 0
		e.horseStreak = tonumber(o.horseStreak) or 0
		e.rouletteStraight = o.rouletteStraight == true
		e.towerMaster = o.towerMaster == true
		e.minesPerfect = o.minesPerfect == true
		e.bjNatural = o.bjNatural == true
		e.bjDouble = o.bjDouble == true
		e.comeback = o.comeback == true
		e.busFull = o.busFull == true
		e.wasBroke = o.wasBroke == true
		e.noodfonds = tonumber(o.noodfonds) or 0
		for _, veld in {"max", "maxWinPer"} do
			if typeof(o[veld]) == "table" then
				for k, v in o[veld] do
					if typeof(k) == "string" and tonumber(v) then
						(e :: any)[veld][k] = tonumber(v)
					end
				end
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
	Profiles.rollOver(speler, p)
	return p
end

-- Waar de prijzen vandaan komen. Ranking hangt zichzelf hier in; Profiles hoeft dan niets
-- van DataStores voor ranglijsten te weten.
local plaatsZoeker: ((number, number) -> number?)? = nil

function Profiles.setPlaceLookup(f: (number, number) -> number?): ()
	plaatsZoeker = f
end

-- Twee dingen die bij binnenkomst moeten kloppen: het seizoen, en de prijzen van de
-- sprints die voorbij zijn gegaan terwijl deze speler weg was.
function Profiles.rollOver(speler: Player, p: Profile): ()
	local nuSeizoen = Season.seasonId()
	local nuSprint = Season.sprintId()

	-- Een nieuw seizoen: iedereen begint weer op $1000 plus een tiende van wat hij
	-- daarboven had. Precies zoals in de webversie.
	if p.resetSeason == nil then
		p.resetSeason = nuSeizoen
	elseif p.resetSeason < nuSeizoen then
		p.balance = Season.balanceAfter(p.balance)
		p.seasonStart = p.balance
		p.resetSeason = nuSeizoen
		p.sprint = nuSprint
		p.sprintProfit = 0
	end

	-- Een verlopen pas hoort niet meer te gelden.
	if p.vipSeason ~= nil and p.vipSeason < nuSeizoen then
		p.vipSeason = nil
	end

	-- Een nieuwe sprint: de stand begint op nul.
	if p.sprint ~= nuSprint then
		p.sprint = nuSprint
		p.sprintProfit = 0
	end

	-- De sprint die net voorbij is: stond deze speler in de top drie?
	local vorige = nuSprint - 1
	local zoek = plaatsZoeker
	if zoek and (p.awardedSprint == nil or p.awardedSprint < vorige) then
		p.awardedSprint = vorige
		local plaats = zoek(vorige, speler.UserId)
		if plaats and plaats <= 3 then
			local titel = Season.titleFor(plaats, vorige)
			if titel then
				-- Dezelfde titel kan er maar één keer in. De teller hierboven hoort dat
				-- al te voorkomen, maar een kast met twee keer "Kampioen S12" erin is
				-- zo'n gekke uitkomst dat hij ook hier wordt tegengehouden.
				if not table.find(p.titles, titel) then
					table.insert(p.titles, titel)
				end
				p.title = titel
				p.titleSeason = nuSeizoen
			end
			if plaats == 1 then
				p.vipSeason = Season.vipSeasonFor(vorige)
			end
		end
	end
end

function Profiles.get(speler: Player): Profile?
	return levend[speler.UserId]
end

-- Mag deze speler de VIP-zone in? Een pas geldt voor precies één seizoen van twaalf dagen.
function Profiles.vipActive(speler: Player): boolean
	local p = levend[speler.UserId]
	return p ~= nil and Season.vipActive(p.vipSeason)
end

-- Wie de sprintstand naar de ranglijst brengt. Ranking hangt zichzelf hier in.
local publiceer: ((Player, number, number) -> ())? = nil

function Profiles.setPublisher(f: (Player, number, number) -> ()): ()
	publiceer = f
end

-- `vrijgeven` betekent: dit was de laatste schrijfbeurt, het slot mag los.
local function schrijf(speler: Player, vrijgeven: boolean): ()
	local id = speler.UserId
	local p = levend[id]
	if not p or not store then return end
	-- De ranglijst gaat mee met elke save, dus ongeveer elke twee minuten en bij het
	-- weggaan. Dat is vaak genoeg voor een stand die drie dagen loopt.
	local pub = publiceer
	if pub and p.sprint then
		pcall(function(): any
			pub(speler, p.sprint :: number, p.sprintProfit)
			return nil
		end)
	end
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

-- Wie er meekijkt als er een prestatie opengaat. De server hangt hier een melding aan;
-- Profiles zelf weet niets van het netwerk.
local ontgrendelHaken: { (Player, { string }) -> () } = {}

function Profiles.onUnlock(f: (Player, { string }) -> ()): ()
	table.insert(ontgrendelHaken, f)
end

-- De stand zoals de prestaties hem willen zien.
local function stand(p: Profile): Achievements.Stand
	return {
		balance = p.balance,
		rounds = p.rounds,
		won = p.won,
		stats = p.stats :: any,
		extra = p.extra,
		vipSeason = p.vipSeason,
		title = p.title,
	}
end

-- Een afgelopen ronde boeken. `inzet` is wat er is ingezet, `uit` wat eruit kwam. `over`
-- draagt wat alleen het spel zelf weet: op welke verdieping je stond, of de hand gedubbeld
-- was, of je op een los nummer won.
function Profiles.record(speler: Player, spel: string, inzet: number, uit: number, mult: number, over: any): ()
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

	-- De sprintstand: wat je binnen deze drie dagen hebt overgehouden. Bij een nieuwe
	-- sprint begint iedereen weer op nul.
	local nuSprint = Season.sprintId()
	if p.sprint ~= nuSprint then
		p.sprint = nuSprint
		p.sprintProfit = 0
	end
	p.sprintProfit = Money.round2(p.sprintProfit + uit - inzet)

	-- Het boekje bijwerken en kijken of er iets opengaat.
	local ronde: Achievements.Ronde = {
		game = spel, wager = inzet, payout = uit, mult = mult,
	}
	if typeof(over) == "table" then
		ronde.straight = over.straight
		ronde.level = over.level
		ronde.diff = over.diff
		ronde.mines = over.mines
		ronde.cleared = over.cleared
		ronde.perfect = over.perfect
		ronde.natural = over.natural
		ronde.doubled = over.doubled
		ronde.steps = over.steps
	end
	Achievements.record(p.extra, ronde, p.balance)

	local nieuwe = Achievements.check(stand(p), p.achievements)
	if #nieuwe == 0 then return end
	for _, id in nieuwe do
		p.achievements[id] = os.time()
	end
	for _, f in ontgrendelHaken do
		pcall(function(): any
			f(speler, nieuwe)
			return nil
		end)
	end
end

-- Wat het noodfonds heeft opgeleverd. Staat los van record(), want er is geen inzet en dus
-- geen ronde: het telt alleen mee voor de prestatie.
function Profiles.noteSafetyNet(speler: Player, bedrag: number): ()
	local p = levend[speler.UserId]
	if not p then return end
	if bedrag > p.extra.noodfonds then p.extra.noodfonds = bedrag end
	local nieuwe = Achievements.check(stand(p), p.achievements)
	if #nieuwe == 0 then return end
	for _, id in nieuwe do
		p.achievements[id] = os.time()
	end
	for _, f in ontgrendelHaken do
		pcall(function(): any
			f(speler, nieuwe)
			return nil
		end)
	end
end

-- De drie badges die een speler aan anderen laat zien. Alleen prestaties die hij echt
-- heeft, en hoogstens drie.
function Profiles.setFeatured(speler: Player, lijst: any): boolean
	local p = levend[speler.UserId]
	if not p or typeof(lijst) ~= "table" then return false end
	local uit: { string } = {}
	local gezien: { [string]: boolean } = {}
	for _, id in lijst do
		if typeof(id) == "string" and p.achievements[id] and not gezien[id] and #uit < 3 then
			gezien[id] = true
			table.insert(uit, id)
		end
	end
	p.featured = uit
	return true
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

-- Wat er nog in het spel zit als een speler weggaat. Profiles roept dit zelf aan, vlak voor
-- het opslaan; zo staat de afhandeling gegarandeerd in het saldo dat wordt weggeschreven.
--
-- Een kraslot is de uitzondering, en dat is belangrijk: de prijs en het hele rooster worden
-- getrokken op het moment dat je het lot koopt. Wie acht vakjes openkrast en dan ziet dat er
-- niets in zit, zou met een teruggave gratis spelen -- weglopen als het tegenzit, doorkrassen
-- als het meezit. Zo'n lot wordt daarom uitbetaald op wat er al in zat, niet terugbetaald.
-- De webversie doet het net zo: een gekocht lot staat daar in pendingRounds(), niet in
-- pendingStakes(), met precies deze reden erbij.
function Games.refund(speler: Player): ()
	local o = open[speler.UserId]
	if not o then return end
	open[speler.UserId] = nil

	if o.game == "scratch" then
		local mult = Odds.scratchPayout(o.cells :: { string })
		local uit = Money.floor2(o.bet * mult)
		if uit > 0 then Profiles.give(speler, uit) end
		Profiles.record(speler, "scratch", o.bet, uit, mult)
		return
	end

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

-- `over` draagt wat alleen dit spel weet en wat de prestaties nodig hebben.
local function settle(speler: Player, spel: string, inzet: number, uit: number, mult: number, over: any): ()
	if uit > 0 then Profiles.give(speler, uit) end
	Profiles.record(speler, spel, inzet, uit, mult, over)
end

-- ---------- het noodfonds ----------
-- Wie helemaal blut is kan niets meer. In de webversie is daar een klein spel voor: een
-- streepje loopt heen en weer en je drukt op stop; hoe dichter bij het midden, hoe meer je
-- krijgt. Tien dollar is gegarandeerd, veertig bij een perfecte stop.
--
-- De klok staat op de server, net als bij crash. De client stuurt alleen "nu", en waar het
-- streepje op dat moment stond bepaalt de server zelf -- anders zou iedereen elke keer
-- precies veertig pakken.
local NOOD = { min = 10, max = 40, periode = 1.1 }
local noodStart: { [number]: number } = {}

local function nu(): number
	return workspace:GetServerTimeNow()
end

-- Een driehoeksgolf: 0 naar 1 en terug, net als bkPos() in de webversie.
local function noodPositie(verstreken: number): number
	local fase = (verstreken % NOOD.periode) / NOOD.periode
	return if fase < 0.5 then fase * 2 else 2 - fase * 2
end

-- Wie er nog geld in het spel heeft staan is niet blut, ook al leest zijn saldo nul: de
-- inzet is afgeschreven maar nog niet beslist. Zonder deze controle is het noodfonds een
-- geldpers -- zet alles in op mines, pak veertig dollar uit het fonds, stap uit, herhaal.
-- De webversie kijkt er ook naar (roundInProgress() in bkAvailable).
--
-- De spellen melden zichzelf aan in plaats van dat Games ze opzoekt, anders vereisen
-- Games en Crash elkaar over en weer.
local inSpelChecks: { (Player) -> boolean } = {}
function Games.addInPlayCheck(f: (Player) -> boolean): ()
	table.insert(inSpelChecks, f)
end

function Games.inPlay(speler: Player): boolean
	if open[speler.UserId] then return true end
	for _, f in inSpelChecks do
		if f(speler) then return true end
	end
	return false
end

function Games.safetyAvailable(speler: Player): boolean
	local p = Profiles.get(speler)
	if not p then return false end
	return p.balance < Money.MIN_BET and not Games.inPlay(speler)
end

function Games.safetyOpen(speler: Player): any
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	if p.balance >= Money.MIN_BET then return { ok = false, err = "je hebt nog geld" } end
	if Games.inPlay(speler) then return { ok = false, err = "je hebt nog een ronde open" } end
	-- Twee keer openen is één ronde: anders zet je met de tweede klok de eerste stil en
	-- kies je achteraf welke van de twee het dichtst bij het midden stond.
	if noodStart[speler.UserId] then return { ok = false, err = "je hebt al een ronde open" } end
	noodStart[speler.UserId] = nu()
	return { ok = true, startsAt = noodStart[speler.UserId], period = NOOD.periode, now = nu() }
end

function Games.safetyStop(speler: Player): any
	local t0 = noodStart[speler.UserId]
	if not t0 then return { ok = false, err = "geen ronde" } end
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	noodStart[speler.UserId] = nil

	local pos = noodPositie(nu() - t0)
	local raak = math.max(0, 1 - math.abs(pos - 0.5) * 2)
	local uit = Money.round2(NOOD.min + (NOOD.max - NOOD.min) * raak)
	Profiles.give(speler, uit)
	Profiles.noteSafetyNet(speler, uit)
	return { ok = true, position = pos, accuracy = raak, payout = uit, balance = p.balance }
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
	local losNummer = false
	for _, s in schoon do
		local factor = Odds.roulettePayout(s.key, n)
		uit += s.bet * factor
		-- Winnen op een los nummer telt voor een prestatie; dat is de enige inzet met
		-- een sleutel die met "n:" begint.
		if factor > 0 and string.sub(s.key, 1, 2) == "n:" then losNummer = true end
	end
	uit = Money.floor2(uit)
	settle(speler, "roulette", totaal, uit, if uit > 0 then uit / totaal else 0, { straight = losNummer })
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
	-- 777 zit achter de VIP-zone. Die controle staat hier, bij het spel zelf, en niet bij
	-- de ingang: dan kan geen enkele latere route eromheen.
	if not Profiles.vipActive(speler) then return { ok = false, err = "vip pass required" } end
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

-- ---------- de paardenrace ----------
-- Het veld wordt geloot voordat er wordt ingezet, niet erna. In de webversie is dat
-- hrNewField(): de kansen staan op het scherm en dat zijn ook de quotes die je krijgt.
-- Trok de server ze pas bij het startschot, dan zou je blind inzetten en had de server
-- ruimte om een veld te kiezen dat slecht uitkomt voor wat er ligt. Nu ligt het veld vast
-- voordat hij weet waar het geld op staat.
--
-- Opnieuw laten loten mag zo vaak als je wilt, want het levert niets op: een quote is
-- 0,97 gedeeld door de kans, dus elk paard in elk veld betaalt 97% terug. Er valt geen
-- gunstiger veld uit te zoeken.
local paardenVeld: { [number]: { number } } = {}

local function veldVan(speler: Player): { number }
	local v = paardenVeld[speler.UserId]
	if not v then
		v = Odds.horseField()
		paardenVeld[speler.UserId] = v
	end
	return v
end

function Games.horseField(speler: Player): any
	return { ok = true, probs = veldVan(speler) }
end

function Games.horseNewOdds(speler: Player): any
	paardenVeld[speler.UserId] = Odds.horseField()
	return { ok = true, probs = paardenVeld[speler.UserId] }
end

function Games.horse(speler: Player, inzetten: any): any
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	if typeof(inzetten) ~= "table" then return { ok = false, err = "geen inzetten" } end

	-- Het veld dat de speler op zijn scherm zag, niet een vers geloot veld.
	local kansen = veldVan(speler)
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
	-- De race is gelopen; de volgende krijgt een nieuw veld.
	paardenVeld[speler.UserId] = nil
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

-- Staat er geld van deze speler nog in een onbesliste ronde? Het noodfonds vraagt het.
function Multi.inPlay(speler: Player): boolean
	return open[speler.UserId] ~= nil
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

-- `over` draagt wat alleen dit spel weet en wat de prestaties nodig hebben: hoe hoog je in
-- de toren kwam, hoeveel mijnen er lagen, hoeveel calls je bij de bus haalde.
local function afrekenen(speler: Player, spel: string, inzet: number, uit: number, mult: number, over: any)
	open[speler.UserId] = nil
	if uit > 0 then Profiles.give(speler, uit) end
	Profiles.record(speler, spel, inzet, uit, mult, over)
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
		afrekenen(speler, "tower", o.bet, 0, 0, { level = o.level, diff = o.diff })
		return { ok = true, safe = false, row = rij, payout = 0, balance = saldo(speler) }
	end

	o.level = niveau
	local mult = Odds.towerMultiplier(o.diff :: string, niveau)
	if niveau >= Odds.TOWER_LEVELS then
		local uit = Money.floor2(o.bet * mult)
		afrekenen(speler, "tower", o.bet, uit, mult, { level = niveau, diff = o.diff })
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
	afrekenen(speler, "tower", o.bet, uit, mult, { level = niveau, diff = o.diff })
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
		afrekenen(speler, "mines", o.bet, 0, 0, { mines = o.mines, cleared = o.picked })
		return { ok = true, mine = true, grid = grid, payout = 0, balance = saldo(speler) }
	end

	opened[i] = true
	local gepakt = (o.picked :: number) + 1
	o.picked = gepakt
	local mult = Odds.minesMultiplier(o.mines :: number, gepakt)
	local over = Odds.MINES_TILES - (o.mines :: number)
	if gepakt >= over then
		local uit = Money.floor2(o.bet * mult)
		afrekenen(speler, "mines", o.bet, uit, mult, { mines = o.mines, cleared = gepakt, perfect = true })
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
	afrekenen(speler, "mines", o.bet, uit, mult, { mines = o.mines, cleared = gepakt })
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
	-- Ride the Bus zit achter de VIP-zone, net als 777.
	if not Profiles.vipActive(speler) then return { ok = false, err = "vip pass required" } end
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
		afrekenen(speler, "bus", o.bet, 0, 0, { steps = stap - 1 })
		return { ok = true, card = kaart, hit = false, payout = 0, balance = saldo(speler) }
	end

	local prob = (o.prob :: number) * kans
	o.prob = prob
	local mult = Odds.busMultiplier(prob)
	if stap >= #Odds.BUS_STEPS then
		local uit = Money.floor2(o.bet * mult)
		afrekenen(speler, "bus", o.bet, uit, mult, { steps = stap })
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
	afrekenen(speler, "bus", o.bet, uit, mult, { steps = o.step })
	return { ok = true, mult = mult, payout = uit, balance = saldo(speler) }
end

Profiles.onLeave(function(speler: Player)
	Multi.refund(speler)
end)

return Multi
]],
	["Blackjack"] = [[
--!strict
-- Blackjack, afgerekend op de server. Zes stapels, dealer pakt bij tot 17 en blijft staan
-- op zacht 17 -- dezelfde regels als de webversie, en dus dezelfde 99%.
--
-- Het belangrijkste verschil met de browser: de dichte kaart van de dealer gaat hier NIET
-- mee naar de client. Die krijgt hij pas als de dealer speelt. In de webversie stond die
-- kaart in het geheugen van de pagina en was hij in principe te lezen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Profiles = require(script.Parent.Parent.Profiles)

local Blackjack = {}

-- Elke hand begint met een verse schoen van zes stapels. Dat is wat de webversie doet
-- ("6 decks, continuously shuffled -- a fresh shoe every hand") en het is ook het enige dat
-- kaarten tellen zinloos maakt: een schoen die tussen handen door blijft liggen geeft een
-- speler die meetelt een echt voordeel over het huis.

type Ronde = {
	bet: number,
	speler: { Odds.Card },
	dealer: { Odds.Card },
	doubled: boolean,
}

local open: { [number]: Ronde } = {}
-- Elke hand krijgt een verse schoen. De webversie deelt uit een schoen die blijft staan,
-- maar daar ziet niemand anders je kaarten; hier zou een speler kunnen tellen wat er al
-- uit is en daarna zijn inzet aanpassen. Vers delen haalt dat voordeel weg.
local schoenen: { [number]: { Odds.Card } } = {}

function Blackjack.get(speler: Player): Ronde?
	return open[speler.UserId]
end

-- Een hand die nog loopt is geld dat nog in het spel staat; het noodfonds vraagt het.
function Blackjack.inPlay(speler: Player): boolean
	return open[speler.UserId] ~= nil
end

-- De hand afrekenen: de dealer speelt uit, en dan pas komt alles op tafel.
local function schud(speler: Player): ()
	schoenen[speler.UserId] = Odds.bjNewShoe(6)
end

local function trek(speler: Player): Odds.Card
	local schoen = schoenen[speler.UserId]
	-- Binnen één hand kan de schoen niet leeg raken (zes stapels, hoogstens een stuk of
	-- twintig kaarten), maar een lege stapel zou een nil-kaart geven en dat is het soort
	-- fout dat de hele tafel meesleept.
	if not schoen or #schoen < 20 then
		schud(speler)
		schoen = schoenen[speler.UserId]
	end
	return table.remove(schoen :: { Odds.Card }) :: Odds.Card
end

local function saldo(speler: Player): number
	local p = Profiles.get(speler)
	return if p then p.balance else 0
end

-- Wat de speler mag zien zolang hij aan zet is: zijn eigen hand, en één kaart van de
-- dealer. De tweede is bewust afwezig -- niet verborgen in een veld, maar er niet.
local function beeld(r: Ronde): any
	local waarde, zacht = Odds.bjValue(r.speler)
	return {
		player = r.speler,
		playerValue = waarde,
		playerSoft = zacht,
		dealerUp = r.dealer[1],
		dealerValue = (Odds.bjValue({ r.dealer[1] })),
		doubled = r.doubled,
		bet = r.bet * (if r.doubled then 2 else 1),
	}
end

local function afrekenen(speler: Player, r: Ronde, dealerSpeelt: boolean): any
	if dealerSpeelt then
		Odds.bjDealerPlay(r.dealer, function()
			return trek(speler)
		end)
	end
	local inzet = r.bet * (if r.doubled then 2 else 1)
	local factor = Odds.bjSettle(r.speler, r.dealer)
	local uit = Money.floor2(inzet * factor)
	open[speler.UserId] = nil
	if uit > 0 then Profiles.give(speler, uit) end
	Profiles.record(speler, "blackjack", inzet, uit, factor, {
		natural = Odds.bjIsBlackjack(r.speler),
		doubled = r.doubled,
	})

	local spelerWaarde = (Odds.bjValue(r.speler))
	local dealerWaarde = (Odds.bjValue(r.dealer))
	local uitslag = if factor > 1 then "win" elseif factor == 1 then "push" else "loss"
	return {
		ok = true, done = true,
		player = r.speler, playerValue = spelerWaarde,
		dealer = r.dealer, dealerValue = dealerWaarde,
		natural = Odds.bjIsBlackjack(r.speler),
		doubled = r.doubled,
		bet = inzet,
		result = uitslag,
		mult = factor,
		payout = uit,
		balance = saldo(speler),
	}
end

-- Weggaan terwijl er nog een hand loopt. Niet terugbetalen: je hebt je eigen kaarten en de
-- open kaart van de dealer al gezien, dus een teruggave zou betekenen dat je elke slechte
-- hand gratis kunt weggooien -- zestien tegen een tien, weglopen, niets verloren. De hand
-- wordt daarom uitgespeeld alsof je past: de dealer speelt uit en er wordt afgerekend.
--
-- Wat er WEL wordt teruggegeven is een hand die nog niet is uitgedeeld, en dat kan hier niet
-- voorkomen: `open` wordt pas gevuld nadat beide handen op tafel liggen.
function Blackjack.refund(speler: Player): number
	local r = open[speler.UserId]
	if not r then return 0 end
	local uitslag = afrekenen(speler, r, true)
	return uitslag.payout or 0
end

function Blackjack.deal(speler: Player, inzet: any): any
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	if open[speler.UserId] then return { ok = false, err = "je hebt nog een hand open" } end
	local bet = Money.cleanBet(inzet, p.balance)
	if not bet then return { ok = false, err = "ongeldige inzet" } end
	if not Profiles.take(speler, bet) then return { ok = false, err = "onvoldoende saldo" } end

	-- Verse schoen: elke hand begint schoon.
	schud(speler)

	local r: Ronde = {
		bet = bet,
		speler = {},
		dealer = {},
		doubled = false,
	}
	-- Om de beurt, zoals aan een echte tafel.
	table.insert(r.speler, trek(speler))
	table.insert(r.dealer, trek(speler))
	table.insert(r.speler, trek(speler))
	table.insert(r.dealer, trek(speler))
	open[speler.UserId] = r

	-- Blackjack ligt meteen op tafel; dan hoeft er niets meer gekozen te worden.
	if Odds.bjIsBlackjack(r.speler) or Odds.bjIsBlackjack(r.dealer) then
		return afrekenen(speler, r, false)
	end

	local b = beeld(r)
	b.ok = true
	b.done = false
	b.balance = saldo(speler)
	return b
end

function Blackjack.act(speler: Player, zet: any): any
	local r = open[speler.UserId]
	if not r then return { ok = false, err = "geen hand" } end
	local k = tostring(zet)

	if k == "hit" then
		table.insert(r.speler, trek(speler))
		if (Odds.bjValue(r.speler)) > 21 then
			return afrekenen(speler, r, false)
		end
		local b = beeld(r)
		b.ok = true
		b.done = false
		b.balance = saldo(speler)
		return b
	end

	if k == "stand" then
		return afrekenen(speler, r, true)
	end

	if k == "double" then
		if #r.speler ~= 2 then return { ok = false, err = "dubbelen kan alleen op de eerste twee kaarten" } end
		if r.doubled then return { ok = false, err = "je hebt al gedubbeld" } end
		-- De tweede helft van de inzet wordt nu pas afgeschreven; lukt dat niet, dan
		-- verandert er niets aan de hand.
		if not Profiles.take(speler, r.bet) then return { ok = false, err = "onvoldoende saldo om te dubbelen" } end
		r.doubled = true
		table.insert(r.speler, trek(speler))
		if (Odds.bjValue(r.speler)) > 21 then
			return afrekenen(speler, r, false)
		end
		return afrekenen(speler, r, true)
	end

	return { ok = false, err = "die zet niet" }
end

Profiles.onLeave(function(sp: Player)
	Blackjack.refund(sp)
	schoenen[sp.UserId] = nil
end)

return Blackjack
]],
	["Crash"] = [[
--!strict
-- De crashronde: één ronde voor iedereen op de server tegelijk, precies zoals in de
-- webversie. De server houdt de klok bij, bepaalt waar de ronde crasht, en rekent elke
-- cashout af op zijn eigen tijd -- nooit op wat de client beweert.
--
-- Eerlijk spel is hier na te rekenen. Voordat de ronde begint publiceert de server
-- sha256("commit:" .. zaad). Als hij voorbij is geeft hij het zaad vrij. Wie wil kan de
-- hash narekenen en zien dat het crashpunt uit dat zaad volgt: de server kan het dus niet
-- achteraf hebben bijgesteld toen hij zag waar de inzetten lagen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Net = require(ReplicatedStorage.Shared.Net)
local Sha256 = require(ReplicatedStorage.Shared.Sha256)
local Profiles = require(script.Parent.Profiles)

local Crash = {}

-- Dezelfde getallen als de webversie: acht seconden inzetten, drie seconden nagenieten,
-- en een multiplier die met e^(0,103995 t) oploopt.
local INZETVENSTER = 8
local NAPAUZE = 3
local GROEI = 0.103995

export type Inzet = {
	naam: string,
	bet: number,
	cashed: number?,
	payout: number?,
	-- De ronde is voor deze speler al in zijn statistieken geboekt. Staat aan zodra iemand
	-- halverwege de vlucht vertrekt: dan ligt de uitslag vast en wordt er meteen geboekt,
	-- dus aan het eind van de ronde hoeft dat niet nog eens.
	geboekt: boolean?,
	-- Automatisch uitstappen op deze multiplier, als de speler er een heeft opgegeven.
	auto: number?,
}

type Ronde = {
	id: number,
	zaad: string,
	commit: string,
	crashAt: number,
	fase: string,        -- "waiting" | "flying" | "crashed"
	opent: number,       -- servertijd waarop het inzetvenster sluit / de vlucht begint
	eindigt: number,     -- servertijd waarop hij crasht
	inzetten: { [number]: Inzet },
}

local ronde: Ronde? = nil
local nummer = 0

-- Waar het zaad vandaan komt. Van buiten aan te reiken, net als Odds.setRandom: een
-- server kan er een betere bron in zetten, en een test iets voorspelbaars. Dit is een
-- servermodule, dus de client kan er niet bij.
local zaadBron: () -> string = Sha256.seed
function Crash.setSeeder(f: () -> string): ()
	zaadBron = f
end

local function nu(): number
	return workspace:GetServerTimeNow()
end

-- De multiplier op tijdstip t na de start. Naar beneden op de cent, net als de webversie.
function Crash.multAt(t: number): number
	if t <= 0 then return 1 end
	return math.max(1, math.floor(math.exp(GROEI * t) * 100) / 100)
end

-- Hoe lang een vlucht duurt die op c crasht.
function Crash.durationFor(c: number): number
	return math.log(c) / GROEI
end

-- Wat iedereen mag zien. Het zaad en het crashpunt zitten er pas in als de ronde voorbij
-- is; daarvoor zou het verklappen waar hij eindigt.
local function beeld(): any
	local r = ronde
	if not r then return { phase = "idle" } end
	-- Het nummer van de speler gaat mee, niet alleen zijn naam. Twee spelers kunnen in
	-- Roblox dezelfde weergavenaam hebben, en het scherm moet kunnen zien welke rij van
	-- hemzelf is -- anders leest hij de stand van een naamgenoot en denkt hij dat hij is
	-- uitgestapt terwijl zijn eigen inzet nog in de lucht hangt. Een UserId is openbaar,
	-- dus dit verklapt niets.
	local lijst = {}
	for id, i in r.inzetten do
		table.insert(lijst, {
			id = id, naam = i.naam, bet = i.bet, cashed = i.cashed, payout = i.payout,
			auto = i.auto,
		})
	end
	return {
		game = "crash",
		id = r.id,
		phase = r.fase,
		commit = r.commit,
		startsAt = r.opent,
		endsAt = if r.fase == "crashed" then r.eindigt else nil,
		crashAt = if r.fase == "crashed" then r.crashAt else nil,
		seed = if r.fase == "crashed" then r.zaad else nil,
		now = nu(),
		bets = lijst,
	}
end

function Crash.state(): any
	return beeld()
end

-- Alleen voor de tests: het crashpunt van de lopende ronde. De client krijgt dit pas als
-- de ronde voorbij is -- dat staat in beeld() -- want anders weet hij waar hij moet
-- uitstappen voordat hij inzet.
function Crash.huidigCrashPunt(): number
	local r = ronde
	return if r then r.crashAt else 0
end

local function duw()
	Net.ev("Round"):FireAllClients(beeld())
end

-- Alles wat nog open staat als de ronde crasht is verloren; dat hoeft niet apart geboekt
-- te worden, want de inzet was al afgeschreven. Wel de statistiek bijwerken.
local function sluit(r: Ronde)
	for id, i in r.inzetten do
		if not i.cashed and not i.geboekt then
			local sp = Players:GetPlayerByUserId(id)
			if sp then
				i.geboekt = true
				Profiles.record(sp, "crash", i.bet, 0, 0)
			end
		end
	end
end

local function nieuweRonde(): Ronde
	nummer += 1
	local zaad = zaadBron()
	local commit = Sha256.commit(zaad)
	-- Het crashpunt komt uit het zaad, niet uit een losse trekking: daardoor ligt het vast
	-- op het moment dat de belofte gepubliceerd wordt.
	local c = Odds.crashPoint(Sha256.unit(Sha256.hash(zaad)))
	local opent = nu() + INZETVENSTER
	return {
		id = nummer,
		zaad = zaad,
		commit = commit,
		crashAt = c,
		fase = "waiting",
		opent = opent,
		eindigt = opent + Crash.durationFor(c),
		inzetten = {},
	}
end

-- De drie stappen van een ronde, elk apart aan te roepen. De lus hieronder rijgt ze aan
-- elkaar met de klok ertussen; de test roept ze zelf aan en zet de klok vooruit.
function Crash.begin(): ()
	ronde = nieuweRonde()
	duw()
end

function Crash.takeOff(): ()
	local r = ronde
	if not r or r.fase ~= "waiting" then return end
	r.fase = "flying"
	duw()
end

-- Automatisch uitstappen wordt door de server zelf gedaan, op zijn eigen klok en precies
-- op de opgegeven multiplier.
--
-- Het scherm kan dit niet: dat ziet de multiplier pas als het beeld er is, moet de vraag
-- dan nog over de lijn sturen, en de server rekent af op het moment dat hij binnenkomt.
-- Zit daar vertraging in, dan komt het verzoek na de klap aan en is de inzet weg -- terwijl
-- het spel belooft dat je op je eigen getal uitstapt. Hier ligt het crashpunt al vast, dus
-- de server weet van tevoren wie er onderweg uitstapt en wanneer, en betaalt op de cent.
-- Iedereen afrekenen wiens doel op of onder `m` ligt en die het crashpunt haalt. De lus
-- roept dit aan op het moment dat de vlucht m bereikt; een test kan het rechtstreeks
-- aanroepen zonder op een klok te wachten.
function Crash.autoSettle(m: number): ()
	local r = ronde
	if not r or r.fase ~= "flying" then return end
	local iets = false
	for id, i in r.inzetten do
		local doel = i.auto
		if doel and not i.cashed and not i.geboekt and doel <= m and doel <= r.crashAt then
			local sp = Players:GetPlayerByUserId(id)
			if sp then
				local uit = Money.floor2(i.bet * doel)
				i.cashed = doel
				i.payout = uit
				i.geboekt = true
				Profiles.give(sp, uit)
				Profiles.record(sp, "crash", i.bet, uit, doel)
				iets = true
			end
		end
	end
	if iets then duw() end
end

-- De doelen die deze ronde gehaald worden, van laag naar hoog, met het tijdstip erbij.
-- Een doel boven het crashpunt haalt het niet en staat er dus niet bij.
local function autoPlan(r: Ronde): { { id: number, doel: number, op: number } }
	local plan = {}
	for id, i in r.inzetten do
		local doel = i.auto
		if doel and not i.cashed and doel <= r.crashAt then
			table.insert(plan, { id = id, doel = doel, op = r.opent + Crash.durationFor(doel) })
		end
	end
	table.sort(plan, function(a, b)
		return a.op < b.op
	end)
	return plan
end

function Crash.blowUp(): ()
	local r = ronde
	if not r or r.fase ~= "flying" then return end
	r.fase = "crashed"
	sluit(r)
	duw()
end

-- De lus die de rondes aan elkaar rijgt. Eén per server.
local function lus()
	while true do
		Crash.begin()
		local r = ronde :: Ronde
		task.wait(math.max(0, r.opent - nu()))
		Crash.takeOff()
		-- Onderweg de automatische uitstappers afrekenen, elk op zijn eigen moment.
		for _, d in autoPlan(r) do
			task.wait(math.max(0, d.op - nu()))
			Crash.autoSettle(d.doel)
		end
		task.wait(math.max(0, r.eindigt - nu()))
		Crash.blowUp()
		task.wait(NAPAUZE)
	end
end

function Crash.start(): ()
	task.spawn(lus)
end

-- ---------- wat een speler mag doen ----------
-- Het doel voor automatisch uitstappen, zoals het van de client komt: nooit op zijn woord.
-- Onder 1,01 heeft het geen zin (de vlucht begint op 1,00) en boven het hoogste crashpunt
-- ook niet. NaN en oneindig glippen door een gewone vergelijking heen, dus die apart.
local AUTO_MIN = 1.01
local AUTO_MAX = 1000000

local function schoonDoel(raw: any): number?
	if raw == nil then return nil end
	local n = tonumber(raw)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	n = math.floor(n * 100 + 0.5) / 100
	if n < AUTO_MIN or n > AUTO_MAX then return nil end
	return n
end

function Crash.bet(speler: Player, inzet: any, autoDoel: any): any
	local r = ronde
	if not r then return { ok = false, err = "geen ronde" } end
	if r.fase ~= "waiting" then return { ok = false, err = "het inzetvenster is gesloten" } end
	if nu() >= r.opent then return { ok = false, err = "het inzetvenster is gesloten" } end
	if r.inzetten[speler.UserId] then return { ok = false, err = "je hebt al ingezet" } end

	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	local bet = Money.cleanBet(inzet, p.balance)
	if not bet then return { ok = false, err = "ongeldige inzet" } end
	if not Profiles.take(speler, bet) then return { ok = false, err = "onvoldoende saldo" } end

	local doel = schoonDoel(autoDoel)
	r.inzetten[speler.UserId] = { naam = speler.DisplayName, bet = bet, auto = doel }
	duw()
	return { ok = true, round = r.id, amount = bet, balance = p.balance, auto = doel }
end

-- Een inzet die nog niet beslist is: de vlucht loopt en er is nog niet uitgestapt. Het
-- noodfonds vraagt het, want zo iemand staat wel op nul maar is niet blut.
function Crash.inPlay(speler: Player): boolean
	local r = ronde
	if not r or r.fase == "crashed" then return false end
	local i = r.inzetten[speler.UserId]
	return i ~= nil and i.cashed == nil
end

function Crash.cashOut(speler: Player): any
	local r = ronde
	if not r then return { ok = false, err = "geen ronde" } end
	local i = r.inzetten[speler.UserId]
	if not i then return { ok = false, err = "geen inzet in deze ronde" } end
	if i.cashed then return { ok = false, err = "al uitgestapt" } end
	if r.fase ~= "flying" then
		return { ok = false, err = if r.fase == "waiting" then "de vlucht is nog niet begonnen" else "te laat" }
	end

	-- De server leest zijn eigen klok. Wat de client denkt dat de multiplier is, doet er
	-- niet toe: hij stuurt hem ook niet mee.
	local t = nu()
	if t >= r.eindigt then return { ok = false, err = "te laat" } end
	local m = math.min(Crash.multAt(t - r.opent), r.crashAt)
	local uit = Money.floor2(i.bet * m)

	i.cashed = m
	i.payout = uit
	Profiles.give(speler, uit)
	Profiles.record(speler, "crash", i.bet, uit, m)
	duw()
	return { ok = true, mult = m, payout = uit, balance = (Profiles.get(speler) :: any).balance }
end

-- Weggaan terwijl het inzetvenster nog open staat: de inzet terug. Is de vlucht al
-- begonnen, dan is hij ingezet en blijft hij staan -- net als in de webversie.
Profiles.onLeave(function(speler: Player)
	local r = ronde
	if not r then return end
	local i = r.inzetten[speler.UserId]
	if not i or i.cashed or i.geboekt then return end
	if r.fase == "waiting" then
		r.inzetten[speler.UserId] = nil
		Profiles.give(speler, i.bet)
		return
	end
	-- De vlucht loopt en hij is weg. Uitstappen kan niet meer -- dat vraagt een speler die
	-- er is -- dus deze inzet is verloren, wat de ronde verder ook doet. Nu boeken, want
	-- straks is dit profiel opgeslagen en weg, en dan telt de ronde nergens meer mee: niet
	-- in zijn statistieken, niet in zijn sprintstand, niet in zijn prestaties. Het geld was
	-- al afgeschreven bij de inzet; alleen het boeken ontbrak.
	i.geboekt = true
	Profiles.record(speler, "crash", i.bet, 0, 0)
end)

return Crash
]],
}
