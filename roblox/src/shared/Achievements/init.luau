--!strict
-- De prestaties, één op één uit de webversie. Elke prestatie kijkt naar de stand van een
-- speler; de server beslist wanneer er eentje opengaat, niet de client.
--
-- `extra` is het boekje naast de statistieken: reeksen, records per spel, en de paar
-- gebeurtenissen die je anders niet uit de totalen kunt aflezen (een gewonnen dubbele hand
-- bijvoorbeeld). Alles hier is puur rekenwerk, dus buiten Studio te bewijzen.
local Achievements = {}

export type Extra = {
	streak: number,
	bestStreak: number,
	bigWin: number,
	crashAbove2: number,
	rouletteStraight: boolean,
	towerLevel: number,
	towerMaster: boolean,
	minesMines: number,
	minesPerfect: boolean,
	bjNatural: boolean,
	bjDouble: boolean,
	horseStreak: number,
	comeback: boolean,
	busFull: boolean,
	noodfonds: number,
	wasBroke: boolean,
	max: { [string]: number },
	maxWinPer: { [string]: number },
}

export type Stand = {
	balance: number,
	rounds: number,
	won: number,
	stats: { [string]: { rounds: number, won: number } },
	extra: Extra,
	vipSeason: number?,
	title: string?,
}

export type Prestatie = {
	id: string,
	icon: string,
	tier: string,
	title: string,
	desc: string,
	test: (Stand) -> boolean,
}

-- De negen spellen die iedereen kan spelen; 777 en de bus zitten achter de VIP-zone en
-- tellen daarom niet mee voor "speel elke stand een keer".
Achievements.BASE_GAMES = {"crash", "roulette", "tower", "mines", "plinko", "blackjack", "horse", "scratch", "wheel"}

local function max(s: Stand, spel: string): number
	return s.extra.max[spel] or 0
end

local function winst(s: Stand, spel: string): number
	return s.extra.maxWinPer[spel] or 0
end

local function rondes(s: Stand, spel: string): number
	local g = s.stats[spel]
	return if g then g.rounds else 0
end

local function gewonnen(s: Stand, spel: string): number
	local g = s.stats[spel]
	return if g then g.won else 0
end

Achievements.LIST = {
	{ id = "first_bet", icon = "\u{1F3B2}", tier = "bronze", title = "First bet", desc = "Play your first round",
	  test = function(s) return s.rounds >= 1 end },
	{ id = "first_win", icon = "\u{1F4B5}", tier = "bronze", title = "First win", desc = "Win a round",
	  test = function(s) return s.won >= 1 end },
	{ id = "rounds_50", icon = "\u{1F550}", tier = "bronze", title = "Regular", desc = "Play 50 rounds",
	  test = function(s) return s.rounds >= 50 end },
	{ id = "rounds_250", icon = "\u{1F3DB}", tier = "silver", title = "Fixture", desc = "Play 250 rounds",
	  test = function(s) return s.rounds >= 250 end },
	{ id = "all_games", icon = "\u{1F3A0}", tier = "silver", title = "Allrounder", desc = "Play every mode at least once",
	  test = function(s)
		for _, g in Achievements.BASE_GAMES do
			if rondes(s, g) < 1 then return false end
		end
		return true
	  end },
	{ id = "streak_5", icon = "\u{1F4C8}", tier = "bronze", title = "On a roll", desc = "Win five rounds in a row",
	  test = function(s) return s.extra.bestStreak >= 5 end },
	{ id = "streak_10", icon = "\u{1F680}", tier = "gold", title = "Untouchable", desc = "Win ten rounds in a row",
	  test = function(s) return s.extra.bestStreak >= 10 end },
	{ id = "balance_2500", icon = "\u{1F4B0}", tier = "bronze", title = "Well off", desc = "Reach a balance of $2,500",
	  test = function(s) return s.balance >= 2500 end },
	{ id = "balance_10k", icon = "\u{1F3E6}", tier = "gold", title = "Fortune", desc = "Reach a balance of $10,000",
	  test = function(s) return s.balance >= 10000 end },
	{ id = "big_win_500", icon = "\u{1F48E}", tier = "silver", title = "Big hit", desc = "Win $500 or more in one round",
	  test = function(s) return s.extra.bigWin >= 500 end },
	{ id = "comeback", icon = "\u{1F504}", tier = "silver", title = "Comeback", desc = "Go from under $50 back above $1,000",
	  test = function(s) return s.extra.comeback end },
	{ id = "crash_5x", icon = "\u{2708}", tier = "bronze", title = "High flyer", desc = "Cash out at 5x or higher in Crash",
	  test = function(s) return max(s, "crash") >= 5 end },
	{ id = "crash_20x", icon = "\u{1F6F0}", tier = "gold", title = "Stratosphere", desc = "Cash out at 20x or higher in Crash",
	  test = function(s) return max(s, "crash") >= 20 end },
	{ id = "crash_cool", icon = "\u{1F9CA}", tier = "silver", title = "Cool head", desc = "Cash out above 2x ten times in Crash",
	  test = function(s) return s.extra.crashAbove2 >= 10 end },
	{ id = "rl_straight", icon = "\u{1F3AF}", tier = "gold", title = "Straight up", desc = "Win on a straight number bet",
	  test = function(s) return s.extra.rouletteStraight end },
	{ id = "rl_500", icon = "\u{1FA99}", tier = "silver", title = "Table master", desc = "Win $500 or more on one spin",
	  test = function(s) return winst(s, "roulette") >= 500 end },
	{ id = "tw_top", icon = "\u{1F5FC}", tier = "silver", title = "Tower keeper", desc = "Reach the ninth floor",
	  test = function(s) return s.extra.towerLevel >= 9 end },
	{ id = "tw_master", icon = "\u{1F409}", tier = "gold", title = "Dragon tamer", desc = "Cash out on master in the Dragon Tower",
	  test = function(s) return s.extra.towerMaster end },
	{ id = "mn_10", icon = "\u{26CF}", tier = "silver", title = "Miner", desc = "Cash out with ten mines on the field",
	  test = function(s) return s.extra.minesMines >= 10 end },
	{ id = "mn_perfect", icon = "\u{1F9E8}", tier = "gold", title = "Bomb squad", desc = "Clear a whole field with five mines on it",
	  test = function(s) return s.extra.minesPerfect end },
	{ id = "pk_50", icon = "\u{1F53B}", tier = "silver", title = "Bouncer", desc = "Hit a 50x or better slot in Plinko",
	  test = function(s) return max(s, "plinko") >= 50 end },
	{ id = "pk_500", icon = "\u{1F3B0}", tier = "gold", title = "Jackpot", desc = "Hit a 500x or better slot in Plinko",
	  test = function(s) return max(s, "plinko") >= 500 end },
	{ id = "bj_natural", icon = "\u{1F0CF}", tier = "bronze", title = "Blackjack!", desc = "Win a hand with a blackjack",
	  test = function(s) return s.extra.bjNatural end },
	{ id = "bj_double", icon = "\u{270C}", tier = "silver", title = "Nerve", desc = "Win a doubled hand",
	  test = function(s) return s.extra.bjDouble end },
	{ id = "hr_outsider", icon = "\u{1F40E}", tier = "gold", title = "Longshot", desc = "Win a race on a horse paying 8x or more",
	  test = function(s) return max(s, "horse") >= 8 end },
	{ id = "hr_triple", icon = "\u{1F3C7}", tier = "silver", title = "Stable master", desc = "Win three races in a row",
	  test = function(s) return s.extra.horseStreak >= 3 end },
	{ id = "nood_precise", icon = "\u{1F39A}", tier = "silver", title = "Precision", desc = "Get $35 or more out of the safety net",
	  test = function(s) return s.extra.noodfonds >= 35 end },
	{ id = "sc_win", icon = "\u{1F39F}", tier = "bronze", title = "Scratched a prize", desc = "Win on a scratch card",
	  test = function(s) return gewonnen(s, "scratch") >= 1 end },
	{ id = "sc_diamond", icon = "\u{1F48E}", tier = "gold", title = "Three diamonds", desc = "Scratch open three diamonds (50x)",
	  test = function(s) return max(s, "scratch") >= 50 end },
	{ id = "vip_zone", icon = "\u{1F511}", tier = "gold", title = "Key to the zone", desc = "Finish a sprint at #1 and enter the VIP zone",
	  test = function(s) return s.vipSeason ~= nil end },
	{ id = "sl_777", icon = "\u{0037}\u{FE0F}\u{20E3}", tier = "gold", title = "Three sevens", desc = "Spin 777 in the VIP zone (40x)",
	  test = function(s) return max(s, "slots") >= 40 end },
	{ id = "wh_top", icon = "\u{1F3A1}", tier = "gold", title = "Wheel topper", desc = "Hit the 10x segment on the wheel",
	  test = function(s) return max(s, "wheel") >= 10 end },
	{ id = "bus_ride", icon = "\u{1F68C}", tier = "silver", title = "All aboard", desc = "Win a ride in Ride the Bus",
	  test = function(s) return gewonnen(s, "bus") >= 1 end },
	{ id = "bus_full", icon = "\u{1F3AB}", tier = "gold", title = "The full ride", desc = "Make all four calls in Ride the Bus",
	  test = function(s) return s.extra.busFull end },
	{ id = "season_pod", icon = "\u{1F3C6}", tier = "gold", title = "On the podium", desc = "Finish a sprint in the top three",
	  test = function(s) return s.title ~= nil and s.title ~= "" end },
} :: { Prestatie }

Achievements.BY_ID = {} :: { [string]: Prestatie }
for _, a in Achievements.LIST do
	Achievements.BY_ID[a.id] = a
end

function Achievements.fresh(): Extra
	return {
		streak = 0, bestStreak = 0, bigWin = 0, crashAbove2 = 0, rouletteStraight = false,
		towerLevel = 0, towerMaster = false, minesMines = 0, minesPerfect = false,
		bjNatural = false, bjDouble = false, horseStreak = 0, comeback = false,
		busFull = false, wasBroke = false, noodfonds = 0, max = {}, maxWinPer = {},
	}
end

-- Wat er van een ronde onthouden moet worden. De server vult dit; de client komt er niet aan.
export type Ronde = {
	game: string,
	wager: number,
	payout: number,
	mult: number?,
	straight: boolean?,   -- roulette: gewonnen op een los nummer
	level: number?,       -- tower: hoe hoog
	diff: string?,        -- tower: op welke stand
	mines: number?,       -- mines: hoeveel mijnen er lagen
	cleared: number?,     -- mines: hoeveel tegels open
	perfect: boolean?,    -- mines: het hele veld leeg
	natural: boolean?,    -- blackjack
	doubled: boolean?,    -- blackjack
	steps: number?,       -- bus: hoeveel calls gehaald
}

local function hoogste(t: { [string]: number }, sleutel: string, waarde: number)
	if waarde > (t[sleutel] or 0) then t[sleutel] = waarde end
end

-- Een afgelopen ronde in het boekje verwerken. Dit past `extra` aan en geeft hem terug.
function Achievements.record(e: Extra, r: Ronde, saldoNa: number): Extra
	local netto = math.floor((r.payout - r.wager) * 100 + 0.5) / 100

	if r.payout > r.wager then
		e.streak += 1
		if e.streak > e.bestStreak then e.bestStreak = e.streak end
		if netto > e.bigWin then e.bigWin = netto end
		hoogste(e.max, r.game, r.mult or 0)
		hoogste(e.maxWinPer, r.game, netto)
		if r.game == "horse" then e.horseStreak += 1 end
		if r.game == "crash" and (r.mult or 0) >= 2 then e.crashAbove2 += 1 end
		if r.game == "roulette" and r.straight then e.rouletteStraight = true end
		if r.game == "blackjack" then
			if r.natural then e.bjNatural = true end
			if r.doubled then e.bjDouble = true end
		end
		if r.game == "bus" and (r.steps or 0) >= 4 then e.busFull = true end
	else
		e.streak = 0
		if r.game == "horse" then e.horseStreak = 0 end
	end

	-- Deze twee tellen ook als de ronde verloren is: hoe hoog je kwam in de toren, en
	-- hoeveel mijnen er op het veld lagen, zegt iets over het risico dat je nam.
	if r.game == "tower" then
		if (r.level or 0) > e.towerLevel then e.towerLevel = r.level :: number end
		if r.diff == "master" and r.payout > r.wager then e.towerMaster = true end
	end
	if r.game == "mines" and r.payout > r.wager then
		if (r.mines or 0) > e.minesMines then e.minesMines = r.mines :: number end
		if r.perfect and (r.mines or 0) >= 5 and (r.cleared or 0) >= 5 then e.minesPerfect = true end
	end

	-- De comeback: onder de vijftig gezeten hebben en daarna weer boven de duizend komen.
	if saldoNa < 50 then e.wasBroke = true end
	-- De webversie gebruikt hier >=, niet >: precies op duizend uitkomen telt ook.
	if e.wasBroke and saldoNa >= 1000 then e.comeback = true end
	return e
end

-- Welke prestaties nu open zouden moeten staan en dat nog niet doen.
function Achievements.check(s: Stand, open: { [string]: number }): { string }
	local nieuw: { string } = {}
	for _, a in Achievements.LIST do
		if not open[a.id] then
			local ok, uit = pcall(a.test, s)
			if ok and uit then table.insert(nieuw, a.id) end
		end
	end
	return nieuw
end

return Achievements
