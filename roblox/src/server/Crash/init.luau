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
-- Hoe vaak er tijdens de vlucht gekeken wordt of iemands doel gehaald is.
local AUTO_TIK = 0.05
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
		-- Onderweg de automatische uitstappers afrekenen. Kijken in plaats van vooruit
		-- plannen, want een speler mag zijn doel tijdens de vlucht nog omzetten; een plan
		-- dat bij de start is gemaakt zou dat missen.
		--
		-- Hoe fijn er gekeken wordt doet niets met het bedrag: er wordt afgerekend op het
		-- doel, niet op de stand van dat moment. Het scheelt alleen een fractie in wanneer.
		while nu() < r.eindigt do
			task.wait(AUTO_TIK)
			if ronde ~= r or r.fase ~= "flying" then break end
			Crash.autoSettle(math.min(Crash.multAt(nu() - r.opent), r.crashAt))
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

-- Het doel bijstellen terwijl de ronde loopt. In de webversie leest de lus elke frame de
-- schakelaar en het getal, dus daar kun je hem tijdens de vlucht nog omzetten of uitzetten;
-- dat hoort hier ook te kunnen.
--
-- Ligt het nieuwe doel onder de multiplier van dit moment, dan is het al voorbij: dan is
-- het hetzelfde als op de knop drukken, en wordt er meteen op de huidige stand afgerekend.
-- Zo levert laag zetten nooit minder op dan zelf uitstappen.
function Crash.setAuto(speler: Player, autoDoel: any): any
	local r = ronde
	if not r then return { ok = false, err = "geen ronde" } end
	local i = r.inzetten[speler.UserId]
	if not i then return { ok = false, err = "geen inzet in deze ronde" } end
	if i.cashed or i.geboekt then return { ok = false, err = "deze inzet is al beslist" } end

	local doel = schoonDoel(autoDoel)
	i.auto = doel
	if doel and r.fase == "flying" then
		local m = math.min(Crash.multAt(nu() - r.opent), r.crashAt)
		if doel <= m then
			return Crash.cashOut(speler)
		end
	end
	duw()
	return { ok = true, auto = doel }
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
