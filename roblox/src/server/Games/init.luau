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
