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
	local k = tonumber(kolom)
	if not k or k < 1 or k > d.tiles then return { ok = false, err = "die tegel niet" } end

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
	local m = tonumber(mijnen)
	if not m or m < 1 or m > 24 or m ~= math.floor(m) then return { ok = false, err = "tussen 1 en 24 mijnen" } end
	local bet, err = begin(speler, inzet)
	if not bet then return { ok = false, err = err } end
	open[speler.UserId] = { game = "mines", bet = bet, grid = Odds.minesLayout(m), picked = 0, mines = m }
	return { ok = true, tiles = Odds.MINES_TILES, balance = saldo(speler) }
end

function Multi.minesPick(speler: Player, tegel: any): any
	local o = open[speler.UserId]
	if not o or o.game ~= "mines" then return { ok = false, err = "geen veld" } end
	local i = tonumber(tegel)
	local grid = o.grid :: { boolean }
	if not i or i < 1 or i > #grid then return { ok = false, err = "die tegel niet" } end

	if grid[i] then
		afrekenen(speler, "mines", o.bet, 0, 0)
		return { ok = true, mine = true, grid = grid, payout = 0, balance = saldo(speler) }
	end

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
function Multi.busStart(speler: Player, inzet: any): any
	local bet, err = begin(speler, inzet)
	if not bet then return { ok = false, err = err } end
	open[speler.UserId] = { game = "bus", bet = bet, deck = Odds.bjNewShoe(1), shown = {}, step = 0, prob = 1 }
	return { ok = true, options = Odds.busOptions(1), balance = saldo(speler) }
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
	return { ok = true, card = kaart, hit = true, step = stap, mult = mult, options = Odds.busOptions(stap + 1) }
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

return Multi
