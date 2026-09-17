--!strict
-- De prestaties. Elke prestatie hoort precies één ding te meten, en geen enkele mag
-- opengaan zonder dat er iets voor gedaan is.
local Ach = require("../src/shared/Achievements")
local h = require("./harness")

local SPELLEN = {"crash", "roulette", "tower", "mines", "plinko", "blackjack",
	"horse", "scratch", "wheel", "slots", "bus"}

local function verseStand(): Ach.Stand
	local stats = {}
	for _, g in SPELLEN do
		stats[g] = { rounds = 0, won = 0 }
	end
	return {
		balance = 1000, rounds = 0, won = 0, stats = stats,
		extra = Ach.fresh(), vipSeason = nil, title = nil,
	}
end

-- ---------- de lijst zelf ----------
h.check("er zijn vierendertig prestaties", 34, #Ach.LIST)
do
	local ids, iconen = {}, 0
	local dubbel = 0
	for _, a in Ach.LIST do
		if ids[a.id] then dubbel += 1 end
		ids[a.id] = true
		if a.icon ~= "" then iconen += 1 end
		h.check(a.id .. " heeft een titel", true, #a.title > 0)
		h.check(a.id .. " heeft een omschrijving", true, #a.desc > 0)
		h.check(a.id .. " heeft een geldig niveau", true,
			a.tier == "bronze" or a.tier == "silver" or a.tier == "gold")
	end
	h.check("geen enkele id komt twee keer voor", 0, dubbel)
	h.check("ze hebben allemaal een pictogram", #Ach.LIST, iconen)
	h.check("de index wijst naar dezelfde lijst", #Ach.LIST, (function()
		local n = 0
		for _ in Ach.BY_ID do n += 1 end
		return n
	end)())
end

-- ---------- een verse speler heeft er nul ----------
do
	local s = verseStand()
	local nieuw = Ach.check(s, {})
	h.check("een verse speler heeft nog niets verdiend", 0, #nieuw)
end

-- ---------- elke prestatie gaat open van precies het juiste ----------
local function opent(naam: string, id: string, pas: (Ach.Stand) -> ())
	local s = verseStand()
	local voor = Ach.check(s, {})
	h.check(naam .. ": staat nog dicht", false, table.find(voor, id) ~= nil)
	pas(s)
	local na = Ach.check(s, {})
	h.check(naam .. ": gaat open", true, table.find(na, id) ~= nil)
end

opent("eerste inzet", "first_bet", function(s) s.rounds = 1 end)
opent("eerste winst", "first_win", function(s) s.won = 1 end)
opent("vijftig rondes", "rounds_50", function(s) s.rounds = 50 end)
opent("tweehonderdvijftig rondes", "rounds_250", function(s) s.rounds = 250 end)
opent("alle standen", "all_games", function(s)
	for _, g in Ach.BASE_GAMES do s.stats[g].rounds = 1 end
end)
opent("vijf op een rij", "streak_5", function(s) s.extra.bestStreak = 5 end)
opent("tien op een rij", "streak_10", function(s) s.extra.bestStreak = 10 end)
opent("saldo 2500", "balance_2500", function(s) s.balance = 2500 end)
opent("saldo 10000", "balance_10k", function(s) s.balance = 10000 end)
opent("grote klapper", "big_win_500", function(s) s.extra.bigWin = 500 end)
opent("comeback", "comeback", function(s) s.extra.comeback = true end)
opent("crash 5x", "crash_5x", function(s) s.extra.max.crash = 5 end)
opent("crash 20x", "crash_20x", function(s) s.extra.max.crash = 20 end)
opent("tien keer boven 2x", "crash_cool", function(s) s.extra.crashAbove2 = 10 end)
opent("los nummer", "rl_straight", function(s) s.extra.rouletteStraight = true end)
opent("500 op een draai", "rl_500", function(s) s.extra.maxWinPer.roulette = 500 end)
opent("negende verdieping", "tw_top", function(s) s.extra.towerLevel = 9 end)
opent("master gehaald", "tw_master", function(s) s.extra.towerMaster = true end)
opent("tien mijnen", "mn_10", function(s) s.extra.minesMines = 10 end)
opent("veld leeggespeeld", "mn_perfect", function(s) s.extra.minesPerfect = true end)
opent("plinko 50x", "pk_50", function(s) s.extra.max.plinko = 50 end)
opent("plinko 500x", "pk_500", function(s) s.extra.max.plinko = 500 end)
opent("blackjack", "bj_natural", function(s) s.extra.bjNatural = true end)
opent("dubbel gewonnen", "bj_double", function(s) s.extra.bjDouble = true end)
opent("buitenbeentje", "hr_outsider", function(s) s.extra.max.horse = 8 end)
opent("drie races op rij", "hr_triple", function(s) s.extra.horseStreak = 3 end)
opent("kraslot gewonnen", "sc_win", function(s) s.stats.scratch.won = 1 end)
opent("drie diamanten", "sc_diamond", function(s) s.extra.max.scratch = 50 end)
opent("rad op tien", "wh_top", function(s) s.extra.max.wheel = 10 end)
opent("de zone in", "vip_zone", function(s) s.vipSeason = 7 end)
opent("drie zevens", "sl_777", function(s) s.extra.max.slots = 40 end)
opent("bus gewonnen", "bus_ride", function(s) s.stats.bus.won = 1 end)
opent("hele rit", "bus_full", function(s) s.extra.busFull = true end)
opent("op het podium", "season_pod", function(s) s.title = "Kampioen S1" end)

-- ---------- net niet is niet ----------
do
	local s = verseStand()
	s.balance = 2499.99
	h.check("net onder 2500 telt niet", false, table.find(Ach.check(s, {}), "balance_2500") ~= nil)
	s.extra.max.crash = 4.99
	h.check("net onder 5x telt niet", false, table.find(Ach.check(s, {}), "crash_5x") ~= nil)
	s.extra.bestStreak = 4
	h.check("vier op een rij telt niet", false, table.find(Ach.check(s, {}), "streak_5") ~= nil)
	for i, g in Ach.BASE_GAMES do
		if i > 1 then s.stats[g].rounds = 1 end
	end
	h.check("acht van de negen standen telt niet", false, table.find(Ach.check(s, {}), "all_games") ~= nil)
	h.check("een lege titel telt niet", false, (function()
		s.title = ""
		return table.find(Ach.check(s, {}), "season_pod") ~= nil
	end)())
end

-- ---------- wat al open staat gaat niet nog een keer open ----------
do
	local s = verseStand()
	s.rounds = 500
	s.won = 100
	local eerste = Ach.check(s, {})
	h.check("er gaat iets open", true, #eerste > 0)
	local al = {}
	for _, id in eerste do al[id] = 1 end
	h.check("de tweede keer gaat er niets meer open", 0, #Ach.check(s, al))
end

-- ---------- het boekje bijhouden ----------
do
	local e = Ach.fresh()
	-- Drie keer winnen op rij.
	for i = 1, 3 do
		Ach.record(e, { game = "crash", wager = 10, payout = 30, mult = 3 }, 1000)
	end
	h.check("de reeks staat op drie", 3, e.streak)
	h.check("de beste reeks ook", 3, e.bestStreak)
	h.check("het record voor crash is 3x", 3, e.max.crash)
	h.check("drie keer boven 2x", 3, e.crashAbove2)

	-- En dan een keer verliezen.
	Ach.record(e, { game = "crash", wager = 10, payout = 0, mult = 0 }, 990)
	h.check("de reeks is gebroken", 0, e.streak)
	h.check("maar de beste reeks blijft staan", 3, e.bestStreak)
	h.check("het record blijft ook staan", 3, e.max.crash)
end

do
	local e = Ach.fresh()
	Ach.record(e, { game = "horse", wager = 10, payout = 100, mult = 10 }, 1090)
	Ach.record(e, { game = "horse", wager = 10, payout = 100, mult = 10 }, 1180)
	h.check("twee races op rij", 2, e.horseStreak)
	Ach.record(e, { game = "horse", wager = 10, payout = 0, mult = 0 }, 1170)
	h.check("een verloren race breekt de reeks", 0, e.horseStreak)
end

do
	-- De comeback: eerst bijna blut, daarna weer boven de duizend.
	local e = Ach.fresh()
	Ach.record(e, { game = "slots", wager = 10, payout = 0, mult = 0 }, 1200)
	h.check("boven de duizend blijven is geen comeback", false, e.comeback)
	Ach.record(e, { game = "slots", wager = 10, payout = 0, mult = 0 }, 20)
	h.check("onder de vijftig gezeten", true, e.wasBroke)
	h.check("maar nog geen comeback", false, e.comeback)
	Ach.record(e, { game = "slots", wager = 10, payout = 5000, mult = 500 }, 5000)
	h.check("en terug boven de duizend is een comeback", true, e.comeback)
end

do
	-- De toren onthoudt hoe hoog je kwam, ook als je eraf viel.
	local e = Ach.fresh()
	Ach.record(e, { game = "tower", wager = 10, payout = 0, mult = 0, level = 7, diff = "master" }, 990)
	h.check("de hoogte telt ook bij een gevallen ronde", 7, e.towerLevel)
	h.check("maar master telt alleen bij winst", false, e.towerMaster)
	Ach.record(e, { game = "tower", wager = 10, payout = 400, mult = 40, level = 4, diff = "master" }, 1390)
	h.check("gewonnen op master telt wel", true, e.towerMaster)
	h.check("een lagere ronde verlaagt de hoogte niet", 7, e.towerLevel)
end

do
	local e = Ach.fresh()
	Ach.record(e, { game = "mines", wager = 10, payout = 0, mult = 0, mines = 20 }, 990)
	h.check("een verloren mijnenveld telt niet mee", 0, e.minesMines)
	Ach.record(e, { game = "mines", wager = 10, payout = 50, mult = 5, mines = 12 }, 1040)
	h.check("een gewonnen wel", 12, e.minesMines)
	Ach.record(e, { game = "mines", wager = 10, payout = 90, mult = 9, mines = 5, cleared = 20, perfect = true }, 1120)
	h.check("het veld leegspelen telt", true, e.minesPerfect)
end

do
	local e = Ach.fresh()
	Ach.record(e, { game = "blackjack", wager = 10, payout = 25, mult = 2.5, natural = true }, 1015)
	h.check("blackjack onthouden", true, e.bjNatural)
	h.check("maar dubbel nog niet", false, e.bjDouble)
	Ach.record(e, { game = "blackjack", wager = 20, payout = 40, mult = 2, doubled = true }, 1035)
	h.check("een gewonnen dubbele hand telt", true, e.bjDouble)
	-- Een verloren dubbele hand telt niet.
	local f = Ach.fresh()
	Ach.record(f, { game = "blackjack", wager = 20, payout = 0, mult = 0, doubled = true }, 980)
	h.check("een verloren dubbele hand telt niet", false, f.bjDouble)
end

do
	local e = Ach.fresh()
	Ach.record(e, { game = "bus", wager = 10, payout = 300, mult = 30, steps = 3 }, 1290)
	h.check("drie calls is nog niet de hele rit", false, e.busFull)
	Ach.record(e, { game = "bus", wager = 10, payout = 800, mult = 80, steps = 4 }, 2080)
	h.check("vier calls wel", true, e.busFull)
end

do
	local e = Ach.fresh()
	Ach.record(e, { game = "roulette", wager = 10, payout = 360, mult = 36, straight = true }, 1350)
	h.check("een los nummer onthouden", true, e.rouletteStraight)
	h.check("de grootste winst per spel", 350, e.maxWinPer.roulette)
	h.check("en de grootste winst in het algemeen", 350, e.bigWin)
end

h.report("PRESTATIES")
