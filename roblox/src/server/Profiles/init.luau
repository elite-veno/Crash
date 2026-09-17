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
