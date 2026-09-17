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
	picked: { number }?,
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
		local b = tonumber(bedrag)
		if not b or b < Money.MIN_BET then continue end
		b = Money.floor2(b)
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
	local i = tonumber(index)
	local cells = o.cells :: { string }
	local revealed = o.revealed :: { boolean }
	if not i or i < 1 or i > #cells or revealed[i] then return { ok = false, err = "dat vakje niet" } end
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
		local idx = tonumber(i)
		local b = tonumber(bedrag)
		if not idx or not b or idx < 1 or idx > #Odds.HORSES or b < Money.MIN_BET then continue end
		b = Money.floor2(b)
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

return Games
