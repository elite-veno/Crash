-- GEGENEREERD door tools/preview/bundle.py
return {
	["Achievements"] = [[
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
	{ id = "sc_win", icon = "\u{1F39F}", tier = "bronze", title = "Scratched a prize", desc = "Win on a scratch card",
	  test = function(s) return gewonnen(s, "scratch") >= 1 end },
	{ id = "sc_diamond", icon = "\u{1F48E}", tier = "gold", title = "Three diamonds", desc = "Scratch open three diamonds (50x)",
	  test = function(s) return max(s, "scratch") >= 50 end },
	{ id = "wh_top", icon = "\u{1F3A1}", tier = "gold", title = "Wheel topper", desc = "Hit the 10x segment on the wheel",
	  test = function(s) return max(s, "wheel") >= 10 end },
	{ id = "vip_zone", icon = "\u{1F511}", tier = "gold", title = "Key to the zone", desc = "Finish a sprint at #1 and enter the VIP zone",
	  test = function(s) return s.vipSeason ~= nil end },
	{ id = "sl_777", icon = "\u{0037}\u{FE0F}\u{20E3}", tier = "gold", title = "Three sevens", desc = "Spin 777 in the VIP zone (40x)",
	  test = function(s) return max(s, "slots") >= 40 end },
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
		busFull = false, wasBroke = false, max = {}, maxWinPer = {},
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
	if e.wasBroke and saldoNa > 1000 then e.comeback = true end
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
]],
	["Money"] = [[
--!strict
-- Bedragen. In de webversie is dit round2/floor2 door de hele code heen; hier staat het
-- op één plek, zodat client en server het op de cent eens zijn.
local Money = {}

Money.START = 1000
Money.MIN_BET = 1

-- Naar beneden op twee decimalen: zo rekent de webversie een uitbetaling af. De epsilon
-- staat er omdat 1.2 * 1.5 in drijvende komma 1.7999999... is: zonder hem is elke
-- uitbetaling een cent te laag. De webversie doet hetzelfde (floor2 in crash.html).
function Money.floor2(x: number): number
	return math.floor(x * 100 + 1e-9) / 100
end

-- Naar de dichtstbijzijnde cent: zo wordt een saldo bewaard.
function Money.round2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function Money.fmt(x: number): string
	return string.format("%.2f", x)
end

-- Is dit uberhaupt een bedrag? NaN glipt door elke gewone vergelijking heen (NaN < 1 is
-- false, en NaN is truthy), dus dat moet apart. Spellen met meerdere inzetten tegelijk
-- gebruiken deze, en tellen daarna pas op.
function Money.cleanAmount(raw: any): number?
	local n = tonumber(raw)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	-- Een inzet gaat naar de dichtstbijzijnde cent, net als takeBet() in de webversie;
	-- naar beneden afkappen is alleen voor wat er uitbetaald wordt.
	n = Money.round2(n)
	if n < Money.MIN_BET then return nil end
	return n
end

-- Een inzet die een speler opstuurt: nooit vertrouwen, altijd door deze zeef.
function Money.cleanBet(raw: any, saldo: number): number?
	local n = Money.cleanAmount(raw)
	if not n then return nil end
	if n > saldo + 1e-9 then return nil end
	return n
end

-- Een geheel getal binnen een bereik: tegelnummers, rijen, aantallen mijnen. Zonder deze
-- controle leest grid[1.5] als nil, en nil is niet "een mijn".
function Money.cleanIndex(raw: any, min: number, max: number): number?
	local n = tonumber(raw)
	if not n or n ~= n or n ~= math.floor(n) then return nil end
	if n < min or n > max then return nil end
	return n
end

return Money
]],
	["Net"] = [[
--!strict
-- Alles wat client en server tegen elkaar zeggen, op één plek. De client roept nooit iets
-- aan dat hier niet staat, en de server rekent alles zelf af: de client stuurt hooguit een
-- inzet en een keuze, nooit een bedrag dat hij zelf heeft uitgerekend.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- De namen van de kanalen. Eén tabel, zodat een typefout niet stilletjes een nieuw
-- RemoteEvent aanmaakt dat nooit geluisterd wordt.
Net.FUNCTIONS = {
	"Bet",          -- (spel, inzet, opties) -> uitslag
	"Act",          -- (spel, zet) -> uitslag, voor spellen met meerdere beurten
	"CashOut",      -- (spel) -> uitbetaling
	"GetProfile",   -- () -> het hele profiel
	"SetFeatured",  -- (lijst) -> de drie uitgelichte badges
	"Leaderboard",  -- () -> de ranglijst
	"Friends",      -- (actie, naam) -> de vriendenlijst
	"Lobby",        -- (actie, gegevens) -> de lobby
	"RoundState",   -- (spel) -> de stand van een gedeelde ronde, voor wie net binnenkomt
}

Net.EVENTS = {
	"Profile",      -- server -> client: saldo, stats, prestaties
	"Round",        -- server -> client: de stand van een gedeelde ronde
	"Toast",        -- server -> client: een melding
	"Lobbies",      -- server -> client: wie er aan tafel zit
}

local folder: Folder? = nil

local function ensure(): Folder
	local gevonden = folder
	if gevonden then return gevonden end

	local bestaand = ReplicatedStorage:FindFirstChild("NeonNet")
	if bestaand then
		folder = bestaand :: Folder
		return bestaand :: Folder
	end

	if RunService:IsServer() then
		local nieuw = Instance.new("Folder")
		nieuw.Name = "NeonNet"
		nieuw.Parent = ReplicatedStorage
		folder = nieuw
		return nieuw
	end

	-- De client wacht: de server maakt de map bij het opstarten.
	local gewacht = ReplicatedStorage:WaitForChild("NeonNet", 30) :: Folder
	folder = gewacht
	return gewacht
end

-- Maakt de kanalen aan. Alleen de server roept dit aan, bij het opstarten.
-- Twee kanalen met dezelfde naam kunnen niet: dan pakt de een de ander af en blijft er
-- eentje stilletjes ongebruikt. Deze controle draait ook in de test.
function Net.conflicts(): { string }
	local gezien: { [string]: string } = {}
	local dubbel: { string } = {}
	for _, naam in Net.FUNCTIONS do
		if gezien[naam] then table.insert(dubbel, naam) end
		gezien[naam] = "function"
	end
	for _, naam in Net.EVENTS do
		if gezien[naam] then table.insert(dubbel, naam) end
		gezien[naam] = "event"
	end
	return dubbel
end

function Net.build(): ()
	assert(RunService:IsServer(), "alleen de server maakt de kanalen")
	local dubbel = Net.conflicts()
	assert(#dubbel == 0, "kanaalnaam dubbel gebruikt: " .. table.concat(dubbel, ", "))

	local f = ensure()
	for _, naam in Net.FUNCTIONS do
		if not f:FindFirstChild(naam) then
			local r = Instance.new("RemoteFunction")
			r.Name = naam
			r.Parent = f
		end
	end
	for _, naam in Net.EVENTS do
		if not f:FindFirstChild(naam) then
			local r = Instance.new("RemoteEvent")
			r.Name = naam
			r.Parent = f
		end
	end
end

function Net.fn(naam: string): RemoteFunction
	return ensure():WaitForChild(naam, 30) :: RemoteFunction
end

function Net.ev(naam: string): RemoteEvent
	return ensure():WaitForChild(naam, 30) :: RemoteEvent
end

return Net
]],
	["Odds"] = [[
--!strict
-- De kansen en uitbetalingen van elk spel. Dit is pure wiskunde: geen Roblox-objecten,
-- geen scherm, geen netwerk. Daardoor is hij buiten Studio te draaien en te bewijzen,
-- precies zoals de webversie dat met odds_test.js doet.
--
-- LET OP bij het vergelijken met de webversie: JavaScript telt tabellen vanaf 0 en Luau
-- vanaf 1. Overal waar een index deel is van het antwoord is dat hier 1-gebaseerd, en
-- betekent 0 "geen prijs" waar de webversie -1 gebruikt.

local Odds = {}

Odds.HOUSE_EDGE = 0.03
local KEEP = 1 - Odds.HOUSE_EDGE   -- 0.97

-- Deze module gebruikt met opzet geen enkel Roblox-type. Daardoor draait en bewijst hij
-- zich buiten Studio, net als odds_test.js in de webversie. De trekker komt van buiten,
-- zodat de server er Random.new() in kan zetten en een test iets voorspelbaars.
local rand: () -> number = function() return math.random() end
function Odds.setRandom(f: () -> number)
	rand = f
end
-- 1..n, zoals Luau telt
local function randInt(n: number): number
	return math.floor(rand() * n) + 1
end

-- Afronden zoals de webversie: naar beneden op twee decimalen.
local function floor2(x: number): number
	return math.floor(x * 100) / 100
end

-- ---------- Crash ----------
-- P(crash >= M) = 0.97 / M, dus ongeveer drie procent van de rondes crasht op 1.00.
function Odds.crashPoint(u: number?): number
	local v = u or rand()
	local raw = KEEP / (1 - v)
	-- Naar boven afronden op de cent, zodat P(crash > M) = 0.97 / M exact klopt voor elke M.
	return math.min(1000, math.max(1, math.ceil(raw * 100 - 1e-9) / 100))
end

-- ---------- Roulette ----------
Odds.ROULETTE_ORDER = {0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26}
local RED = {}
for _, n in {1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36} do
	RED[n] = true
end
Odds.ROULETTE_RED = RED

function Odds.rouletteColor(n: number): string
	if n == 0 then return "green" end
	return if RED[n] then "red" else "black"
end

-- Geeft de totale uitkering als factor van de inzet, inzet inbegrepen. 0 = verloren.
function Odds.roulettePayout(key: string, n: number): number
	if string.sub(key, 1, 2) == "n:" then
		return if n == tonumber(string.sub(key, 3)) then 36 else 0
	end
	if n == 0 then return 0 end
	if key == "red"   then return if RED[n] then 2 else 0 end
	if key == "black" then return if RED[n] then 0 else 2 end
	if key == "even"  then return if n % 2 == 0 then 2 else 0 end
	if key == "odd"   then return if n % 2 == 1 then 2 else 0 end
	if key == "low"   then return if n <= 18 then 2 else 0 end
	if key == "high"  then return if n >= 19 then 2 else 0 end
	if key == "d1"    then return if n <= 12 then 3 else 0 end
	if key == "d2"    then return if n >= 13 and n <= 24 then 3 else 0 end
	if key == "d3"    then return if n >= 25 then 3 else 0 end
	if key == "c1"    then return if n % 3 == 1 then 3 else 0 end
	if key == "c2"    then return if n % 3 == 2 then 3 else 0 end
	if key == "c3"    then return if n % 3 == 0 then 3 else 0 end
	return 0
end

-- ---------- Dragon Tower ----------
export type TowerDiff = { tiles: number, safe: number, label: string }
Odds.TOWER_LEVELS = 9
Odds.TOWER_DIFF = {
	easy   = { tiles = 4, safe = 3, label = "3 of 4 safe" },
	medium = { tiles = 3, safe = 2, label = "2 of 3 safe" },
	hard   = { tiles = 2, safe = 1, label = "1 of 2 safe" },
	expert = { tiles = 3, safe = 1, label = "1 of 3 safe" },
	master = { tiles = 4, safe = 1, label = "1 of 4 safe" },
} :: { [string]: TowerDiff }

function Odds.towerMultiplier(diff: string, level: number): number
	local d = Odds.TOWER_DIFF[diff]
	return floor2(KEEP * (d.tiles / d.safe) ^ level)
end

-- Negen rijen; per rij een lijst booleans waarvan er `safe` waar zijn.
function Odds.towerLayout(diff: string): { { boolean } }
	local d = Odds.TOWER_DIFF[diff]
	local rows = {}
	for _ = 1, Odds.TOWER_LEVELS do
		local row = table.create(d.tiles, false)
		local idx = {}
		for i = 1, d.tiles do idx[i] = i end
		for _ = 1, d.safe do
			row[table.remove(idx, randInt(#idx)) :: number] = true
		end
		table.insert(rows, row)
	end
	return rows
end

-- ---------- Mines ----------
Odds.MINES_TILES = 25
function Odds.minesMultiplier(mines: number, k: number): number
	local p = 1
	for i = 0, k - 1 do
		p *= (Odds.MINES_TILES - i) / (Odds.MINES_TILES - mines - i)
	end
	return floor2(KEEP * p)
end

function Odds.minesLayout(mines: number): { boolean }
	local grid = table.create(Odds.MINES_TILES, false)
	local idx = {}
	for i = 1, Odds.MINES_TILES do idx[i] = i end
	for _ = 1, mines do
		grid[table.remove(idx, randInt(#idx)) :: number] = true
	end
	return grid
end

-- ---------- Plinko ----------
-- De vormen worden bij het laden zo geschaald dat Σ C(n,k)/2^n · mult_k precies 0,97 is.
Odds.PLINKO_BASE = {
	[8] = {
		low    = {5.6,2.1,1.1,1,0.5,1,1.1,2.1,5.6},
		medium = {13,3,1.3,0.7,0.4,0.7,1.3,3,13},
		high   = {29,4,1.5,0.3,0.2,0.3,1.5,4,29},
	},
	[12] = {
		low    = {10,3,1.6,1.4,1.1,1,0.5,1,1.1,1.4,1.6,3,10},
		medium = {33,11,4,2,1.1,0.6,0.3,0.6,1.1,2,4,11,33},
		high   = {170,24,8.1,2,0.7,0.2,0.2,0.2,0.7,2,8.1,24,170},
	},
	[16] = {
		low    = {16,9,2,1.4,1.4,1.2,1.1,1,0.5,1,1.1,1.2,1.4,1.4,2,9,16},
		medium = {110,41,10,5,3,1.5,1,0.5,0.3,0.5,1,1.5,3,5,10,41,110},
		high   = {1000,130,26,9,4,2,0.2,0.2,0.2,0.2,0.2,2,4,9,26,130,1000},
	},
} :: { [number]: { [string]: { number } } }

function Odds.binom(n: number, k: number): number
	local r = 1
	for i = 1, k do
		r = r * (n - k + i) / i
	end
	return r
end

function Odds.plinkoRtp(rows: number, tbl: { number }): number
	local s = 0
	for i, m in tbl do
		s += Odds.binom(rows, i - 1) / 2 ^ rows * m
	end
	return s
end

local plinkoCache: { [string]: { number } } = {}
function Odds.plinkoTable(rows: number, risk: string): { number }
	local key = rows .. risk
	if plinkoCache[key] then return plinkoCache[key] end
	local base = Odds.PLINKO_BASE[rows][risk]
	local f = KEEP / Odds.plinkoRtp(rows, base)
	local t = {}
	for i, m in base do
		t[i] = math.round(m * f * 100) / 100
	end
	-- Spiegelen, zodat links en rechts exact gelijk blijven.
	for i = 1, math.floor(#t / 2) do
		t[#t + 1 - i] = t[i]
	end
	plinkoCache[key] = t
	return t
end

-- Een pad als lijst van 0 (links) en 1 (rechts); het aantal enen is het vakje.
function Odds.plinkoPath(rows: number): { number }
	local p = {}
	for i = 1, rows do
		p[i] = if rand() < 0.5 then 0 else 1
	end
	return p
end

-- ---------- Paardenrace ----------
-- Kleuren als hex, niet als Color3: het scherm zet ze om, de wiskunde blijft Roblox-vrij.
Odds.HORSES = {
	{ name = "LIGHTNING", color = "e0616e" },
	{ name = "THUNDER",   color = "e0b555" },
	{ name = "COMET",     color = "3ecf8e" },
	{ name = "STORM",     color = "5fb8ff" },
	{ name = "SPARK",     color = "ff8c3a" },
	{ name = "MIST",      color = "c084fc" },
}

function Odds.horseField(): { number }
	local w = {}
	local sum = 0
	for i = 1, #Odds.HORSES do
		w[i] = 0.5 + rand() * 2.5
		sum += w[i]
	end
	for i = 1, #w do
		w[i] /= sum
	end
	return w
end

function Odds.horseMultiplier(p: number): number
	return floor2(KEEP / p)
end

-- De hele volgorde, op gewicht getrokken (Plackett-Luce). Plaats 1 is de winnaar.
function Odds.horseRanking(probs: { number }): { number }
	local left: { { p: number, i: number } } = {}
	for i, p in probs do
		table.insert(left, { p = p, i = i })
	end
	local order = {}
	while #left > 0 do
		local total = 0
		for _, h in left do total += h.p end
		local r = rand() * total
		local k = 1
		while k < #left do
			r -= left[k].p
			if r < 0 then break end
			k += 1
		end
		local weg = table.remove(left, k)
		table.insert(order, (weg :: { p: number, i: number }).i)
	end
	return order
end

-- ---------- Krasloten ----------
Odds.SCRATCH_CELLS = 9
Odds.SCRATCH_TOTAL = 10000
Odds.SCRATCH_PRIZES = {
	{ sym = "💎", mult = 50,   weight = 40 },
	{ sym = "🔔", mult = 15,   weight = 120 },
	{ sym = "🍀", mult = 8,    weight = 200 },
	{ sym = "⭐", mult = 4,    weight = 500 },
	{ sym = "🍒", mult = 2,    weight = 900 },
	{ sym = "🪙", mult = 1.25, weight = 400 },
}

function Odds.scratchRtp(): number
	local a = 0
	for _, p in Odds.SCRATCH_PRIZES do a += p.weight * p.mult end
	return a / Odds.SCRATCH_TOTAL
end

-- 0 = geen drie gelijke, anders de plaats in SCRATCH_PRIZES (1-gebaseerd).
function Odds.scratchDraw(u: number?): number
	local r = (u or rand()) * Odds.SCRATCH_TOTAL
	for i, p in Odds.SCRATCH_PRIZES do
		r -= p.weight
		if r < 0 then return i end
	end
	return 0
end

-- Elk verliezend symbool zit twee keer in de pot, dus een vulling kan nooit per ongeluk
-- een derde gelijke opleveren; bij winst gaat het winnende symbool er drie keer in.
function Odds.scratchGrid(prize: number): { string }
	local cells, pool = {}, {}
	local win = if prize > 0 then Odds.SCRATCH_PRIZES[prize].sym else nil
	if win then
		for _ = 1, 3 do table.insert(cells, win) end
	end
	for _, p in Odds.SCRATCH_PRIZES do
		if p.sym ~= win then
			table.insert(pool, p.sym)
			table.insert(pool, p.sym)
		end
	end
	for i = #pool, 2, -1 do
		local j = randInt(i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	while #cells < Odds.SCRATCH_CELLS do
		table.insert(cells, table.remove(pool) :: string)
	end
	for i = #cells, 2, -1 do
		local j = randInt(i)
		cells[i], cells[j] = cells[j], cells[i]
	end
	return cells
end

-- Wat een afgekrast lot waard is, gelezen uit het rooster zelf.
function Odds.scratchPayout(cells: { string }): number
	for _, p in Odds.SCRATCH_PRIZES do
		local n = 0
		for _, c in cells do
			if c == p.sym then n += 1 end
		end
		if n >= 3 then return p.mult end
	end
	return 0
end

-- ---------- 777 ----------
Odds.SLOT_SYMBOLS = {"7️⃣", "💎", "🔔", "🍇", "🍋", "🍒"}
Odds.SLOT_TOTAL = 10000
Odds.SLOT_PRIZES = {
	{ kind = "triple", sym = "7️⃣", mult = 40,  weight = 40 },
	{ kind = "triple", sym = "💎", mult = 20,  weight = 80 },
	{ kind = "triple", sym = "🔔", mult = 12,  weight = 150 },
	{ kind = "triple", sym = "🍇", mult = 8,   weight = 200 },
	{ kind = "triple", sym = "🍋", mult = 5,   weight = 230 },
	{ kind = "triple", sym = "🍒", mult = 3,   weight = 300 },
	{ kind = "pair",   sym = "🍒", mult = 1.5, weight = 700 },
}

function Odds.slotRtp(): number
	local a = 0
	for _, p in Odds.SLOT_PRIZES do a += p.weight * p.mult end
	return a / Odds.SLOT_TOTAL
end

function Odds.slotDraw(u: number?): number
	local r = (u or rand()) * Odds.SLOT_TOTAL
	for i, p in Odds.SLOT_PRIZES do
		r -= p.weight
		if r < 0 then return i end
	end
	return 0
end

function Odds.slotReels(idx: number): { string }
	local cherry = "🍒"
	if idx > 0 then
		local p = Odds.SLOT_PRIZES[idx]
		if p.kind == "triple" then return { p.sym, p.sym, p.sym } end
		local others = {}
		for _, sy in Odds.SLOT_SYMBOLS do
			if sy ~= cherry then table.insert(others, sy) end
		end
		local r = { cherry, cherry, others[randInt(#others)] }
		for i = #r, 2, -1 do
			local j = randInt(i)
			r[i], r[j] = r[j], r[i]
		end
		return r
	end
	-- Verlies: geen drie gelijke en geen twee kersen, anders belooft het beeld meer dan
	-- de uitslag waard is.
	for _ = 1, 100 do
		local r = {
			Odds.SLOT_SYMBOLS[randInt(#Odds.SLOT_SYMBOLS)],
			Odds.SLOT_SYMBOLS[randInt(#Odds.SLOT_SYMBOLS)],
			Odds.SLOT_SYMBOLS[randInt(#Odds.SLOT_SYMBOLS)],
		}
		if r[1] == r[2] and r[2] == r[3] then continue end
		local kersen = 0
		for _, sy in r do
			if sy == cherry then kersen += 1 end
		end
		if kersen == 2 then continue end
		return r
	end
	return { "🍒", "🍋", "🔔" }
end

function Odds.slotPayout(reels: { string }): number
	if reels[1] == reels[2] and reels[2] == reels[3] then
		for _, p in Odds.SLOT_PRIZES do
			if p.kind == "triple" and p.sym == reels[1] then return p.mult end
		end
		return 0
	end
	local kersen = 0
	for _, sy in reels do
		if sy == "🍒" then kersen += 1 end
	end
	if kersen == 2 then
		for _, p in Odds.SLOT_PRIZES do
			if p.kind == "pair" then return p.mult end
		end
	end
	return 0
end

-- ---------- Rad van fortuin ----------
-- Twintig vakken van gelijke grootte. De som is 19,4 = 0,97 × 20.
Odds.WHEEL = {0, 1.2, 0, 2, 0, 1.5, 0, 0, 10, 0, 0, 1.2, 0, 2, 0, 1.5, 0, 0, 0, 0}

function Odds.wheelRtp(): number
	local a = 0
	for _, v in Odds.WHEEL do a += v end
	return a / #Odds.WHEEL
end

function Odds.wheelSpin(): number
	return randInt(#Odds.WHEEL)
end

-- ---------- Ride the Bus ----------
-- Vier keer raden door één geschudde stapel: kleur, hoger of lager, binnen of buiten, en
-- de soort. Elke multiplier is 0,97 gedeeld door de kans om zover te komen, en die kans
-- wordt geteld op de kaarten die nog in de stapel zitten. Daardoor levert uitstappen na
-- elke call precies 97% op, hoe goed of slecht er ook geraden wordt.
export type Card = { r: string, s: string }
Odds.BUS_STEPS = {"colour", "highlow", "inout", "suit"}
Odds.BUS_SUITS = {"♠", "♥", "♦", "♣"}
Odds.BUS_RANKS = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}

function Odds.busRank(card: Card): number
	return (table.find(Odds.BUS_RANKS, card.r) :: number)
end

-- Voldoet deze kaart aan de call? `shown` zijn de kaarten die al op tafel liggen.
function Odds.busHit(card: Card, step: number, choice: string, shown: { Card }): boolean
	if step == 1 then
		local rood = card.s == "♥" or card.s == "♦"
		return (choice == "red") == rood
	end
	if step == 2 then
		local r, a = Odds.busRank(card), Odds.busRank(shown[1])
		return if choice == "higher" then r > a else r < a   -- gelijk verliest altijd
	end
	if step == 3 then
		local r = Odds.busRank(card)
		local lo = math.min(Odds.busRank(shown[1]), Odds.busRank(shown[2]))
		local hi = math.max(Odds.busRank(shown[1]), Odds.busRank(shown[2]))
		return if choice == "inside" then (r > lo and r < hi) else (r < lo or r > hi)
	end
	return card.s == choice
end

function Odds.busChance(deck: { Card }, step: number, choice: string, shown: { Card }): number
	if #deck == 0 then return 0 end
	local hits = 0
	for _, c in deck do
		if Odds.busHit(c, step, choice, shown) then hits += 1 end
	end
	return hits / #deck
end

function Odds.busOptions(step: number): { { string } }
	if step == 1 then return { {"red", "RED"}, {"black", "BLACK"} } end
	if step == 2 then return { {"higher", "HIGHER"}, {"lower", "LOWER"} } end
	if step == 3 then return { {"inside", "INSIDE"}, {"outside", "OUTSIDE"} } end
	local out = {}
	for _, s in Odds.BUS_SUITS do table.insert(out, { s, s }) end
	return out
end

-- prob = de kans om hier te zijn gekomen, de zojuist gemaakte call inbegrepen.
function Odds.busMultiplier(prob: number): number
	return if prob > 0 then floor2(KEEP / prob) else 0
end

-- ---------- Blackjack ----------
function Odds.bjNewShoe(decks: number?): { Card }
	local shoe = {}
	for _ = 1, decks or 6 do
		for _, s in {"♠", "♥", "♦", "♣"} do
			for _, r in Odds.BUS_RANKS do
				table.insert(shoe, { r = r, s = s })
			end
		end
	end
	for i = #shoe, 2, -1 do
		local j = randInt(i)
		shoe[i], shoe[j] = shoe[j], shoe[i]
	end
	return shoe
end

function Odds.bjValue(hand: { Card }): (number, boolean)
	local total, aces = 0, 0
	for _, c in hand do
		if c.r == "A" then
			total += 11
			aces += 1
		elseif c.r == "J" or c.r == "Q" or c.r == "K" then
			total += 10
		else
			total += tonumber(c.r) :: number
		end
	end
	while total > 21 and aces > 0 do
		total -= 10
		aces -= 1
	end
	return total, aces > 0
end

function Odds.bjIsBlackjack(hand: { Card }): boolean
	return #hand == 2 and (Odds.bjValue(hand)) == 21
end

-- De dealer pakt bij tot 17 en blijft staan op zacht 17. Past de hand aan en geeft hem terug.
function Odds.bjDealerPlay(hand: { Card }, draw: () -> Card): { Card }
	while (Odds.bjValue(hand)) < 17 do
		table.insert(hand, draw())
	end
	return hand
end

-- Uitkering als factor van de oorspronkelijke inzet, inzet inbegrepen. 0 = verloren.
function Odds.bjSettle(player: { Card }, dealer: { Card }): number
	local p = (Odds.bjValue(player))
	local d = (Odds.bjValue(dealer))
	local pBJ, dBJ = Odds.bjIsBlackjack(player), Odds.bjIsBlackjack(dealer)
	if pBJ and dBJ then return 1 end
	if pBJ then return 2.5 end
	if dBJ then return 0 end
	if p > 21 then return 0 end
	if d > 21 then return 2 end
	if p > d then return 2 end
	if p < d then return 0 end
	return 1
end

return Odds
]],
	["Season"] = [[
--!strict
-- Twee klokken naast elkaar, precies als in de webversie. Een SPRINT duurt drie dagen: daar
-- wordt de ranglijst op gescoord, en wie hem wint krijgt een titel. Een SEIZOEN duurt twaalf
-- dagen -- vier sprints -- en is hoe lang een VIP-pas geldig blijft.
--
-- Alles hier is rekenwerk op een tijdstempel, zonder Roblox-type erin. Daardoor is het te
-- bewijzen zonder Studio, net als de kansen in Odds.
local Season = {}

Season.SPRINT_SECONDS = 3 * 24 * 3600
Season.SEASON_SECONDS = 12 * 24 * 3600
Season.SPRINTS_PER_SEASON = 4

-- Wat elke plek in een sprint oplevert. Geen geld: een titel, en voor de winnaar een pas
-- voor de VIP-zone tot het einde van het seizoen.
Season.PRIZES = {"VIP PASS + TITLE", "TITLE", "TITLE"}

-- De dag dat het casino openging (16 september 2026, UTC). De blokken worden vanaf het
-- epoch geteld en zijn daardoor enorm; spelers zien het aantal sinds de opening.
Season.OPENING = 1789516800   -- os.time van 2026-09-16 00:00 UTC

function Season.sprintId(nu: number?): number
	return math.floor((nu or os.time()) / Season.SPRINT_SECONDS)
end

function Season.seasonId(nu: number?): number
	return math.floor((nu or os.time()) / Season.SEASON_SECONDS)
end

function Season.sprintEndsAt(id: number): number
	return (id + 1) * Season.SPRINT_SECONDS
end

function Season.seasonEndsAt(id: number): number
	return (id + 1) * Season.SEASON_SECONDS
end

local EERSTE = math.floor(Season.OPENING / Season.SEASON_SECONDS)

function Season.seasonNoOf(sprint: number): number
	return math.floor(sprint / Season.SPRINTS_PER_SEASON) - EERSTE + 1
end

function Season.sprintNoOf(sprint: number): number
	return sprint - math.floor(sprint / Season.SPRINTS_PER_SEASON) * Season.SPRINTS_PER_SEASON + 1
end

function Season.seasonNo(nu: number?): number
	return Season.seasonId(nu) - EERSTE + 1
end

function Season.sprintNo(nu: number?): number
	return Season.sprintNoOf(Season.sprintId(nu))
end

-- Uitslagen van voor de opening zouden anders als seizoen 0 of lager gelezen worden.
function Season.sprintLabel(sprint: number): string
	local se = Season.seasonNoOf(sprint)
	local kop = if se >= 1 then "SEASON " .. se else "PRESEASON"
	return kop .. " \u{00B7} SPRINT " .. Season.sprintNoOf(sprint)
end

-- Hoeveel sprints er nog in dit seizoen zitten, deze meegerekend.
function Season.sprintsLeft(nu: number?): number
	return Season.SPRINTS_PER_SEASON
		- (Season.sprintId(nu) - Season.seasonId(nu) * Season.SPRINTS_PER_SEASON)
end

-- Een sprint winnen opent de zone op het moment dat die sprint afloopt, en hij blijft open
-- tot het seizoen waar dat moment in valt voorbij is. Win je de laatste sprint van een
-- seizoen, dan dekt de pas het seizoen dat begint -- nooit een dat al voorbij is.
function Season.vipSeasonFor(sprint: number): number
	return Season.seasonId((sprint + 1) * Season.SPRINT_SECONDS)
end

function Season.vipActive(vipSeason: number?, nu: number?): boolean
	return vipSeason ~= nil and vipSeason == Season.seasonId(nu)
end

-- Wat er van een saldo overblijft als het seizoen omslaat: $1000 plus een tiende van wat
-- je daarboven had. Naar beneden op de cent, nooit in het voordeel van de speler.
function Season.balanceAfter(saldo: number): number
	local b = math.floor(saldo * 100 + 0.5) / 100
	local boven = math.max(0, b - 1000)
	return math.floor((1000 + math.floor(boven * 0.10 * 100) / 100) * 100 + 0.5) / 100
end

-- "2d 5h 12m", of korter als er minder over is.
function Season.countdown(tot: number, nu: number?): string
	local over = math.max(0, tot - (nu or os.time()))
	local d = math.floor(over / 86400)
	local u = math.floor(over / 3600) % 24
	local m = math.floor(over / 60) % 60
	if d > 0 then return string.format("%dd %dh %dm", d, u, m) end
	if u > 0 then return string.format("%dh %dm", u, m) end
	return string.format("%dm", m)
end

-- De titels worden opgeslagen als "Kampioen S<sprint>"; dit maakt er leesbare tekst van
-- zonder aan het opgeslagen veld te komen.
local RANG = { Kampioen = "Champion", Tweede = "Runner-up", Derde = "Third" }

function Season.titleLabel(titel: string?): string
	local t = titel or ""
	local rang, sprint = string.match(t, "^(%a+) S(%-?%d+)$")
	if rang and sprint and RANG[rang] then
		return RANG[rang] .. " \u{00B7} " .. Season.sprintLabel(tonumber(sprint) :: number)
	end
	return t
end

function Season.titleFor(plaats: number, sprint: number): string?
	local rang = if plaats == 1 then "Kampioen" elseif plaats == 2 then "Tweede" elseif plaats == 3 then "Derde" else nil
	return if rang then rang .. " S" .. sprint else nil
end

return Season
]],
	["Sha256"] = [[
--!strict
-- SHA-256, met de hand in Luau. Roblox heeft geen ingebouwde hashfunctie en de webversie
-- rekent hem in Postgres uit (`encode(sha256(...), 'hex')`), dus hier moet hij zelf.
--
-- Waar hij voor is: eerlijk spel bewijzen. Voordat een crashronde begint publiceert de
-- server sha256("commit:" .. zaad). Na afloop geeft hij het zaad vrij. Iedereen kan dan
-- narekenen dat het zaad bij de belofte hoort en dat het crashpunt eruit volgt -- de
-- server kon het dus niet achteraf aanpassen.
local Sha256 = {}

local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local START = {
	0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
	0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

local band, bxor, bnot = bit32.band, bit32.bxor, bit32.bnot
local rrot, rshift, lshift = bit32.rrotate, bit32.rshift, bit32.lshift

-- De boodschap aanvullen: een 1-bit, dan nullen, dan de lengte in bits als 64-bits getal.
local function vullen(bericht: string): string
	local lengte = #bericht
	local bits = lengte * 8
	local staart = "\128"
	local nullen = (56 - (lengte + 1) % 64) % 64
	staart ..= string.rep("\0", nullen)
	-- De bovenste 32 bits zijn nul zolang het bericht kleiner is dan 512 MB; dat is het
	-- hier altijd (een zaad is een paar tientallen tekens).
	staart ..= string.pack(">I4>I4", math.floor(bits / 4294967296), bits % 4294967296)
	return bericht .. staart
end

function Sha256.hash(bericht: string): string
	local data = vullen(bericht)
	local h = table.clone(START)
	local w = table.create(64, 0)

	for blok = 1, #data, 64 do
		for i = 1, 16 do
			w[i] = (string.unpack(">I4", data, blok + (i - 1) * 4))
		end
		for i = 17, 64 do
			local a, b = w[i - 15], w[i - 2]
			local s0 = bxor(rrot(a, 7), rrot(a, 18), rshift(a, 3))
			local s1 = bxor(rrot(b, 17), rrot(b, 19), rshift(b, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
		end

		local a, b, c, d = h[1], h[2], h[3], h[4]
		local e, f, g, hh = h[5], h[6], h[7], h[8]

		for i = 1, 64 do
			local S1 = bxor(rrot(e, 6), rrot(e, 11), rrot(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (hh + S1 + ch + K[i] + w[i]) % 4294967296
			local S0 = bxor(rrot(a, 2), rrot(a, 13), rrot(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local t2 = (S0 + maj) % 4294967296

			hh = g
			g = f
			f = e
			e = (d + t1) % 4294967296
			d = c
			c = b
			b = a
			a = (t1 + t2) % 4294967296
		end

		local deel = {a, b, c, d, e, f, g, hh}
		for i = 1, 8 do
			h[i] = (h[i] + deel[i]) % 4294967296
		end
	end

	local stukken = table.create(8, "")
	for i = 1, 8 do
		stukken[i] = string.format("%08x", h[i])
	end
	return table.concat(stukken)
end

-- Wat de webversie publiceert voordat een ronde begint.
function Sha256.commit(zaad: string): string
	return Sha256.hash("commit:" .. zaad)
end

-- De eerste dertien hexcijfers als getal tussen 0 en 1 -- dezelfde greep als de webversie
-- gebruikt om een zaad in een crashpunt om te zetten.
function Sha256.unit(hex: string): number
	local stuk = string.sub(hex, 1, 13)
	return (tonumber(stuk, 16) :: number) / 2 ^ 52
end

-- Geen geheim, maar wel onvoorspelbaar genoeg voor een zaad: tijd, een teller en de
-- toevalsgenerator door elkaar.
local teller = 0
function Sha256.seed(): string
	teller += 1
	return string.format("%d-%d-%d-%d", os.time(), teller,
		math.random(0, 2 ^ 31 - 1), math.random(0, 2 ^ 31 - 1))
end

local _ = lshift   -- bit32.lshift blijft hier staan voor toekomstige varianten
return Sha256
]],
	["Theme"] = [[
--!strict
-- De kleuren, letters en maten uit de CSS van de webversie, één op één overgenomen. Waar
-- de webversie een getal noemt staat dat getal hier ook; waar hij rgba() gebruikt staat de
-- kleur plus de doorzichtigheid die daarbij hoort, want zo werkt Roblox.
--
-- Eén plek zet de toon: als hier iets verandert, verandert het overal.

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local Theme = {}

-- ---------- :root ----------
Theme.color = {
	bg         = hex("0e1116"),
	panel      = hex("151a21"),
	panelLight = hex("1a212a"),
	border     = hex("2a323d"),
	neon       = hex("3ecf8e"),
	neonDim    = hex("2d9e6d"),
	gold       = hex("e0b555"),
	green      = hex("3ecf8e"),
	red        = hex("e0616e"),
	text       = hex("e7ebf1"),
	muted      = hex("8d97a6"),
	-- achtergronden van de speelvelden, zoals in de CSS
	felt       = hex("2f5a1a"),
	feltLight  = hex("579a2f"),
	feltDark   = hex("4f8f2a"),
	sky        = hex("5fb8ff"),
	card       = hex("f7f9fc"),
	black      = hex("000000"),
	white      = hex("ffffff"),
}

-- --neon-glow is rgba(62,207,142,0.28): in Roblox is dat de kleur plus doorzichtigheid.
Theme.glow = { color = hex("3ecf8e"), transparency = 0.72 }

-- De doorzichtigheden die in de CSS als rgba() staan.
Theme.alpha = {
	inputBg    = 0.4,    -- rgba(0,0,0,0.6)
	buttonBg   = 0.5,    -- rgba(0,0,0,0.5)
	hoverBg    = 0.96,   -- rgba(255,255,255,0.04)
	activeNav  = 0.90,   -- rgba(62,207,142,0.10)
	tagNeon    = 0.88,   -- rgba(62,207,142,0.12)
	tagGold    = 0.90,   -- rgba(224,181,85,0.10)
	locked     = 0.65,   -- opacity 0.35
	disabled   = 0.40,   -- opacity 0.6
}

Theme.font = {
	ui     = Enum.Font.Gotham,        -- Inter, gewoon
	uiMed  = Enum.Font.GothamMedium,  -- Inter 600
	uiBold = Enum.Font.GothamBold,    -- Inter 700
	num    = Enum.Font.Code,          -- JetBrains Mono
}

-- ---------- maten ----------
-- De border-radius waarden uit de CSS, per onderdeel.
Theme.radius = {
	chip   = 2,
	button = 3,
	input  = 3,
	panel  = 4,
	card   = 6,
	pill   = 8,
}

Theme.size = {
	railWidth   = 64,    -- nav.sidebar
	railOpen    = 240,   -- nav.sidebar.open
	asideWidth  = 320,   -- .game-view grid-template-columns: 320px 1fr
	viewPad     = 16,    -- .game-view padding
	viewGap     = 16,    -- .game-view gap
	asideGap    = 14,    -- aside.game-aside gap
	panelPad    = 18,    -- .panel padding
	homePadY    = 40,    -- #homeView padding
	homePadX    = 50,
	gap         = 8,
	cardMin     = 280,   -- .games-grid minmax(280px, 1fr)
	cardGap     = 20,
	cardPreview = 160,   -- .game-card-preview height
	navIcon     = 24,    -- .nav-icon
	navPadY     = 14,    -- .nav-item padding
	navPadX     = 20,
	navGap      = 16,
	pad         = 12,
}

-- De lettergroottes uit de CSS, met de naam van waar ze vandaan komen.
Theme.text = {
	badge    = 8,    -- .nav-badge
	tiny     = 11,   -- .game-card-desc, .odds-note, .chip, .btn-secondary
	small    = 11,   -- .panel-title, .balance-label, .nav-section-label
	body     = 12,   -- .nav-label, .home-subtitle
	label    = 13,
	button   = 15,   -- .btn-primary
	input    = 16,   -- input[type=number]
	card     = 18,   -- .game-card-title
	title    = 22,   -- .crash-header-title, .section-heading h2
	big      = 22,
	balance  = 30,   -- .balance-amount
	balanceL = 36,   -- .home-balance-card .balance-value
	huge     = 36,
	hero     = 64,   -- .home-title
	giant    = 64,
}

return Theme
]],
	["UI"] = [[
--!strict
-- De bouwstenen uit de CSS, als Roblox-objecten. Elke maat hier komt uit `crash.html`; waar
-- de webversie padding van 18 zegt, staat er 18. Eén plek waar een paneel, een knop en een
-- fiche vandaan komen, zodat elk scherm er hetzelfde uitziet.
--
-- Wat Roblox niet heeft en de CSS wel: letter-spacing, box-shadow en transitions. De eerste
-- twee zijn weggelaten, de derde wordt door TweenService gedaan waar hij opvalt.
local Theme = require(script.Parent.Theme)

local UI = {}

-- ---------- kleine hulpjes ----------
function UI.corner(parent: GuiObject, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.radius.button)
	c.Parent = parent
	return c
end

function UI.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.color.border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UI.padding(parent: GuiObject, all: number?): UIPadding
	local p = Instance.new("UIPadding")
	local n = all or Theme.size.pad
	p.PaddingTop = UDim.new(0, n)
	p.PaddingBottom = UDim.new(0, n)
	p.PaddingLeft = UDim.new(0, n)
	p.PaddingRight = UDim.new(0, n)
	p.Parent = parent
	return p
end

function UI.padding4(parent: GuiObject, boven: number, rechts: number, onder: number, links: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, boven)
	p.PaddingRight = UDim.new(0, rechts)
	p.PaddingBottom = UDim.new(0, onder)
	p.PaddingLeft = UDim.new(0, links)
	p.Parent = parent
	return p
end

function UI.list(parent: GuiObject, gap: number?, dir: Enum.FillDirection?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or Theme.size.gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

-- Het verloop van 180 graden dat door de hele CSS loopt: panel naar panel-light.
function UI.gradient(parent: GuiObject, van: Color3, tot: Color3, rotatie: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(van, tot)
	g.Rotation = rotatie or 90
	g.Parent = parent
	return g
end

-- ---------- paneel ----------
-- .panel: verloop van --panel naar --panel-light, 1px rand, radius 4, padding 18, en
-- bovenlangs een haarlijn in de neongloed (.panel::before).
function UI.panel(parent: Instance, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Panel"
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	UI.gradient(f, Theme.color.panel, Theme.color.panelLight)
	UI.corner(f, Theme.radius.panel)
	UI.stroke(f)
	UI.padding(f, Theme.size.panelPad)
	f.Parent = parent

	-- De haarlijn bovenaan: doorzichtig aan de randen, neon in het midden.
	local lijn = Instance.new("Frame")
	lijn.Name = "TopLine"
	lijn.AnchorPoint = Vector2.new(0.5, 0)
	lijn.Position = UDim2.new(0.5, 0, 0, -Theme.size.panelPad)
	lijn.Size = UDim2.new(1, Theme.size.panelPad * 2, 0, 1)
	lijn.BackgroundColor3 = Theme.glow.color
	lijn.BorderSizePixel = 0
	lijn.ZIndex = 2
	lijn.Parent = f
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = lijn

	return f
end

-- ---------- tekst ----------
export type LabelOpts = {
	size: number?,
	color: Color3?,
	font: Enum.Font?,
	align: Enum.TextXAlignment?,
	name: string?,
}

local LEEG: LabelOpts = {}

function UI.label(parent: Instance, text: string, opts: LabelOpts?): TextLabel
	local o: LabelOpts = opts or LEEG
	local t = Instance.new("TextLabel")
	t.Name = o.name or "Label"
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = o.size or Theme.text.body
	t.TextColor3 = o.color or Theme.color.text
	t.Font = o.font or Theme.font.ui
	t.TextXAlignment = o.align or Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, (o.size or Theme.text.body) + 6)
	t.RichText = false        -- spelersnamen komen hier langs; nooit als opmaak uitvoeren
	t.Parent = parent
	return t
end

-- .panel-title: neon, 11px, en 8 pixels lucht eronder.
function UI.panelTitle(parent: Instance, text: string): TextLabel
	local t = UI.label(parent, string.upper(text), {
		size = Theme.text.small,
		color = Theme.color.neon,
		font = Theme.font.uiMed,
		name = "PanelTitle",
	})
	t.Size = UDim2.new(1, 0, 0, Theme.text.small + 8)
	return t
end

-- .section-heading: een kop van 22, een telling, en een lijn die naar rechts uitdooft.
function UI.sectionHeading(parent: Instance, kop: string, telling: string?): (TextLabel, TextLabel)
	local rij = Instance.new("Frame")
	rij.Name = "SectionHeading"
	rij.Size = UDim2.new(1, 0, 0, 30)
	rij.BackgroundTransparency = 1
	rij.Parent = parent

	local h = UI.label(rij, kop, {
		size = Theme.text.title, color = Theme.color.text, font = Theme.font.uiMed,
	})
	h.Size = UDim2.new(0, 0, 1, 0)
	h.AutomaticSize = Enum.AutomaticSize.X

	local c = UI.label(rij, telling or "", { size = Theme.text.small, color = Theme.color.muted })
	c.Position = UDim2.new(0, 0, 0, 0)
	c.Size = UDim2.new(0, 0, 1, 0)
	c.AutomaticSize = Enum.AutomaticSize.X

	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 20)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = rij
	h.LayoutOrder = 1
	c.LayoutOrder = 2

	local streep = Instance.new("Frame")
	streep.Name = "Divider"
	streep.LayoutOrder = 3
	streep.Size = UDim2.new(1, -260, 0, 1)
	streep.BackgroundColor3 = Theme.color.border
	streep.BorderSizePixel = 0
	streep.Parent = rij
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = streep

	return h, c
end

-- ---------- knoppen ----------
export type Button = TextButton

-- Een knop die op zijn plek blijft als je erover gaat, maar wel reageert.
local function hover(b: TextButton, aan: () -> (), uit: () -> ())
	b.MouseEnter:Connect(function()
		if b.Active then aan() end
	end)
	b.MouseLeave:Connect(uit)
end

-- .btn-primary: volle breedte, padding 16, 15px, radius 3.
function UI.primary(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Primary"
	b.Text = text
	b.Font = Theme.font.uiMed
	b.TextSize = Theme.text.button
	b.TextColor3 = Theme.color.bg
	b.BackgroundColor3 = Theme.color.neon
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 48)
	UI.corner(b, Theme.radius.button)
	hover(b, function()
		b.BackgroundColor3 = Theme.color.neonDim
	end, function()
		b.BackgroundColor3 = Theme.color.neon
	end)
	b.Parent = parent
	return b
end

-- .btn-primary.btn-danger: het verloop naar donkerrood, voor uitstappen.
function UI.danger(parent: Instance, text: string): Button
	local b = UI.primary(parent, text)
	b.Name = "Danger"
	b.BackgroundColor3 = Theme.color.red
	b.TextColor3 = Theme.color.white
	b.Font = Theme.font.uiBold
	UI.gradient(b, Theme.color.red, Color3.fromHex("8a0e1e"), 135)
	return b
end

-- .btn-secondary: zwart met een rand, 11px, padding 12 boven en onder.
function UI.secondary(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Secondary"
	b.Text = text
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = Theme.color.text
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 36)
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b)
	hover(b, function()
		rand.Color = Theme.color.neon
		b.TextColor3 = Theme.color.neon
	end, function()
		rand.Color = Theme.color.border
		b.TextColor3 = Theme.color.text
	end)
	b.Parent = parent
	return b
end

-- .chip: hetzelfde, maar kleiner en met radius 2.
function UI.chip(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Chip"
	b.Text = text
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = Theme.color.text
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(0, 0, 0, 24)
	UI.corner(b, Theme.radius.chip)
	local rand = UI.stroke(b)
	hover(b, function()
		rand.Color = Theme.color.neon
		b.TextColor3 = Theme.color.neon
	end, function()
		rand.Color = Theme.color.border
		b.TextColor3 = Theme.color.text
	end)
	b.Parent = parent
	return b
end

-- .back-btn: "← LOBBY", neon tekst, en bij hover keert hij om.
function UI.backButton(parent: Instance, text: string?): Button
	local b = Instance.new("TextButton")
	b.Name = "Back"
	b.Text = text or "\u{2190} LOBBY"
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = Theme.color.neon
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(86, 30)
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b)
	hover(b, function()
		b.BackgroundColor3 = Theme.color.neon
		b.BackgroundTransparency = 0
		b.TextColor3 = Theme.color.bg
		rand.Color = Theme.color.neon
	end, function()
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.TextColor3 = Theme.color.neon
		rand.Color = Theme.color.border
	end)
	b.Parent = parent
	return b
end

-- Een pilletje: .game-card-tag en .nav-badge.
function UI.tag(parent: Instance, text: string, kleur: Color3?): TextLabel
	local k = kleur or Theme.color.neon
	local f = Instance.new("TextLabel")
	f.Name = "Tag"
	f.Text = text
	f.Font = Theme.font.ui
	f.TextSize = Theme.text.tiny
	f.TextColor3 = k
	f.BackgroundColor3 = k
	f.BackgroundTransparency = Theme.alpha.tagNeon
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 20)
	f.RichText = false
	UI.corner(f, Theme.radius.pill)
	local s = UI.stroke(f, k)
	s.Transparency = 0.6
	UI.padding4(f, 0, 8, 0, 8)
	f.Parent = parent
	return f
end

-- ---------- invoerveld ----------
-- input[type=number]: zwart, rand, cijferlettertype 16, radius 3. Bij focus wordt de rand
-- neon en komt er een gloedring omheen -- dat is de box-shadow uit de CSS.
function UI.numberBox(parent: Instance, start: string): TextBox
	local t = Instance.new("TextBox")
	t.Name = "NumberBox"
	t.Text = start
	t.PlaceholderText = "0"
	t.Font = Theme.font.num
	t.TextSize = Theme.text.input
	t.TextColor3 = Theme.color.text
	t.BackgroundColor3 = Theme.color.black
	t.BackgroundTransparency = Theme.alpha.inputBg
	t.BorderSizePixel = 0
	t.ClearTextOnFocus = false
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, 40)
	UI.corner(t, Theme.radius.input)
	local s = UI.stroke(t)
	UI.padding4(t, 10, 12, 10, 12)

	local ring = Instance.new("UIStroke")
	ring.Color = Theme.glow.color
	ring.Thickness = 2
	ring.Transparency = 1
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = t

	t.Focused:Connect(function()
		s.Color = Theme.color.neon
		ring.Transparency = Theme.glow.transparency
	end)
	t.FocusLost:Connect(function()
		s.Color = Theme.color.border
		ring.Transparency = 1
	end)
	t.Parent = parent
	return t
end

-- ---------- melding ----------
-- .toast: verschijnt rechtsboven het speelveld en verdwijnt vanzelf.
export type ToastKind = "green" | "red" | "gold"

function UI.toast(host: Instance, text: string, kind: ToastKind?): ()
	local k = kind or "green"
	local color = if k == "red" then Theme.color.red
		elseif k == "gold" then Theme.color.gold
		else Theme.color.neon

	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.Size = UDim2.new(0, 0, 0, 34)
	f.AutomaticSize = Enum.AutomaticSize.X
	UI.corner(f, Theme.radius.button)
	UI.stroke(f, color)

	local t = UI.label(f, text, { size = Theme.text.tiny, color = color, font = Theme.font.uiMed })
	t.Size = UDim2.new(0, 0, 1, 0)
	t.AutomaticSize = Enum.AutomaticSize.X
	UI.padding4(f, 0, 12, 0, 12)
	f.Parent = host

	task.delay(2.6, function()
		if f.Parent then f:Destroy() end
	end)
end

-- ---------- bedragen ----------
-- Dezelfde weergave als fmt() in de webversie: altijd twee decimalen.
function UI.money(n: number): string
	return string.format("%.2f", n)
end

-- .balance-amount: het dollarteken staat er gedimd voor, apart van het getal. Geeft het
-- label met het getal terug, en het vak eromheen.
function UI.moneyLabel(parent: Instance, bedrag: string, groot: number?, midden: boolean?): (TextLabel, Frame)
	local maat = groot or Theme.text.balance
	local rij = Instance.new("Frame")
	rij.Name = "Money"
	rij.Size = UDim2.new(1, 0, 0, maat + 10)
	rij.BackgroundTransparency = 1
	rij.Parent = parent

	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = if midden then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 1)
	l.Parent = rij

	local teken = UI.label(rij, "$", { size = maat, color = Theme.color.neon, font = Theme.font.num })
	teken.LayoutOrder = 1
	teken.AutomaticSize = Enum.AutomaticSize.X
	teken.Size = UDim2.new(0, 0, 1, 0)
	teken.TextTransparency = 0.4

	local getal = UI.label(rij, bedrag, {
		size = maat, color = Theme.color.neon, font = Theme.font.num, name = "Amount",
	})
	getal.LayoutOrder = 2
	getal.AutomaticSize = Enum.AutomaticSize.X
	getal.Size = UDim2.new(0, 0, 1, 0)
	return getal, rij
end

-- Een knop uitzetten zoals :disabled in de CSS: nog zichtbaar, maar niet aan te klikken.
function UI.setEnabled(b: TextButton, aan: boolean): ()
	b.Active = aan
	b.AutoButtonColor = false
	b.TextTransparency = if aan then 0 else Theme.alpha.disabled
	if b.BackgroundTransparency < 0.9 then
		b.BackgroundTransparency = if aan then (if b.Name == "Primary" or b.Name == "Danger" then 0 else Theme.alpha.buttonBg) else 0.7
	end
end

return UI
]],
	["Achievements"] = [[
--!strict
-- Prestaties: de drie badges die je aan anderen laat zien, de stand van de sprint, en het
-- hele rek met wat er te halen valt.
--
-- Klikken op een badge in een gevuld vakje legt hem weer af. Dat was in de webversie een
-- aparte wens: zonder dat kon je een badge wel oppakken maar nooit meer neerleggen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Ach = require(ReplicatedStorage.Shared.Achievements)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Achievements = {}

local NIVEAU = {
	bronze = Color3.fromHex("c98a4b"),
	silver = Color3.fromHex("b9c2cf"),
	gold = Color3.fromHex("e0b555"),
}

function Achievements.build(ouder: Instance): (any) -> ()
	local blad = Common.sheet(ouder)

	-- ---------- de drie vakjes ----------
	local etalage = UI.panel(blad, "Featured")
	UI.list(etalage, 6)
	UI.panelTitle(etalage, "featured \u{00B7} click a filled slot to take it off")

	local vakjesRij = Instance.new("Frame")
	vakjesRij.Size = UDim2.new(1, 0, 0, 72)
	vakjesRij.BackgroundTransparency = 1
	vakjesRij.Parent = etalage
	UI.list(vakjesRij, 8, Enum.FillDirection.Horizontal)

	local uitgelicht: { string } = {}
	local open: { [string]: number } = {}
	local vakjes: { TextButton } = {}
	local zetUitgelicht: () -> ()

	for i = 1, 3 do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. i
		b.Size = UDim2.fromOffset(72, 72)
		b.Text = "+"
		b.Font = Theme.font.ui
		b.TextSize = 30
		b.TextColor3 = Theme.color.muted
		b.BackgroundColor3 = Theme.color.bg
		b.BackgroundTransparency = 0.45
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.card)
		UI.stroke(b, Theme.color.border)
		b.Parent = vakjesRij
		vakjes[i] = b

		-- Een gevuld vakje legt de badge weer af.
		b.Activated:Connect(function()
			local id = uitgelicht[i]
			if not id then return end
			table.remove(uitgelicht, i)
			Common.call("SetFeatured", uitgelicht)
			zetUitgelicht()
			Common.toast("BADGE TAKEN OFF", nil)
		end)
	end

	-- ---------- de sprint ----------
	local sprintVak = UI.panel(blad, "Sprint")
	UI.list(sprintVak, 4)
	UI.panelTitle(sprintVak, "sprint profit \u{00B7} title and a vip pass")
	local sprintNaam = Common.statRow(sprintVak, "SPRINT", "\u{2014}")
	local sprintKlok = Common.statRow(sprintVak, "ENDS IN", "\u{2014}")
	local seizoenKlok = Common.statRow(sprintVak, "SEASON ENDS IN", "\u{2014}")
	local mijnWinst = Common.statRow(sprintVak, "YOUR SPRINT PROFIT", "$0.00")
	local prijsUitleg = UI.label(sprintVak, "\u{25BA} FINISH A SPRINT AT #1 AND THE VIP ZONE IS YOURS FOR THE SEASON", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	prijsUitleg.TextWrapped = true
	prijsUitleg.Size = UDim2.new(1, 0, 0, 26)

	local standVak = UI.panel(blad, "Standings")
	UI.list(standVak, 3)
	UI.panelTitle(standVak, "standings")
	local standLijst = Instance.new("Frame")
	standLijst.Size = UDim2.new(1, 0, 0, 0)
	standLijst.AutomaticSize = Enum.AutomaticSize.Y
	standLijst.BackgroundTransparency = 1
	standLijst.Parent = standVak
	UI.list(standLijst, 2)
	local leegLabel = UI.label(standLijst, "Nog niemand op de lijst deze sprint.", {
		size = Theme.text.small, color = Theme.color.muted,
	})

	-- ---------- het rek ----------
	local rek = UI.panel(blad, "All")
	UI.list(rek, 6)
	local rekTitel = UI.label(rek, "\u{25BA} ACHIEVEMENTS \u{00B7} 0 / " .. #Ach.LIST, {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
	})

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = rek
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 168, 0, 74)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = raster

	type Kaartje = { knop: TextButton, rand: UIStroke, icoon: TextLabel, titel: TextLabel, tekst: TextLabel }
	local kaartjes: { [string]: Kaartje } = {}

	for i, a in Ach.LIST do
		local knop = Instance.new("TextButton")
		knop.Name = a.id
		knop.Text = ""
		knop.BackgroundColor3 = Theme.color.bg
		knop.BackgroundTransparency = 0.5
		knop.BorderSizePixel = 0
		knop.AutoButtonColor = false
		knop.LayoutOrder = i
		UI.corner(knop, Theme.radius.button)
		local rand = UI.stroke(knop, Theme.color.border)
		knop.Parent = raster

		local icoon = UI.label(knop, a.icon, {
			size = 26, align = Enum.TextXAlignment.Center,
		})
		icoon.Position = UDim2.new(0, 6, 0, 8)
		icoon.Size = UDim2.fromOffset(34, 34)

		local titel = UI.label(knop, a.title, {
			size = Theme.text.small, color = Theme.color.text, font = Theme.font.uiMed,
		})
		titel.Position = UDim2.new(0, 46, 0, 8)
		titel.Size = UDim2.new(1, -52, 0, 16)

		local tekst = UI.label(knop, a.desc, { size = Theme.text.tiny, color = Theme.color.muted })
		tekst.Position = UDim2.new(0, 46, 0, 26)
		tekst.Size = UDim2.new(1, -52, 0, 40)
		tekst.TextWrapped = true
		tekst.TextYAlignment = Enum.TextYAlignment.Top

		kaartjes[a.id] = { knop = knop, rand = rand, icoon = icoon, titel = titel, tekst = tekst }

		-- Een prestatie die je hebt kun je in een vrij vakje leggen.
		knop.Activated:Connect(function()
			if not open[a.id] then
				Common.toast("NOT UNLOCKED YET", "red")
				return
			end
			if table.find(uitgelicht, a.id) then
				Common.toast("ALREADY FEATURED", nil)
				return
			end
			if #uitgelicht >= 3 then
				Common.toast("ALL THREE SLOTS ARE FULL", "red")
				return
			end
			table.insert(uitgelicht, a.id)
			Common.call("SetFeatured", uitgelicht)
			zetUitgelicht()
		end)
	end

	function zetUitgelicht()
		for i, b in vakjes do
			local id = uitgelicht[i]
			local a = if id then Ach.BY_ID[id] else nil
			b.Text = if a then a.icon else "+"
			b.TextSize = if a then 34 else 30
			b.TextColor3 = if a then Theme.color.text else Theme.color.muted
			b.BackgroundTransparency = if a then 0.2 else 0.45
		end
	end

	-- ---------- de ranglijst ophalen ----------
	local function ververs()
		local res = Common.call("Leaderboard")
		if not res then return end
		sprintNaam.Text = res.label
		sprintKlok.Text = Season.countdown(res.endsAt, res.now)
		seizoenKlok.Text = Season.countdown(res.seasonEndsAt, res.now)
		mijnWinst.Text = "$" .. Money.fmt(res.mine or 0)

		for _, k in standLijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		leegLabel.Visible = #res.top == 0
		for _, plek in res.top do
			local naam = plek.rank .. ". " .. plek.name
			local rij = Common.statRow(standLijst, naam, "$" .. Money.fmt(plek.profit))
			rij.TextColor3 = if plek.rank <= 3 then Theme.color.gold else Theme.color.text
		end
	end

	task.spawn(function()
		while true do
			ververs()
			task.wait(30)
		end
	end)

	-- Het profiel binnenkrijgen.
	return function(p: any)
		if typeof(p) ~= "table" then return end
		open = if typeof(p.achievements) == "table" then p.achievements else {}
		uitgelicht = {}
		if typeof(p.featured) == "table" then
			for _, id in p.featured do
				if typeof(id) == "string" and Ach.BY_ID[id] then table.insert(uitgelicht, id) end
			end
		end
		zetUitgelicht()

		local aantal = 0
		for _, a in Ach.LIST do
			local k = kaartjes[a.id]
			local heeft = open[a.id] ~= nil
			if heeft then aantal += 1 end
			k.knop.BackgroundTransparency = if heeft then 0.15 else 0.55
			k.rand.Color = if heeft then NIVEAU[a.tier] else Theme.color.border
			k.icoon.TextTransparency = if heeft then 0 else 0.6
			k.titel.TextColor3 = if heeft then NIVEAU[a.tier] else Theme.color.muted
			k.tekst.TextTransparency = if heeft then 0 else 0.35
		end
		rekTitel.Text = "\u{25BA} ACHIEVEMENTS \u{00B7} " .. aantal .. " / " .. #Ach.LIST
	end
end

return Achievements
]],
	["Art"] = [[
--!strict
-- De tekeningen op de speltegels. In de webversie is elke preview een SVG van 280 bij 160:
-- een vliegtuigje boven gras, een roulettewiel, tegels met een draken-ei. Egale verlopen
-- zagen er naast het origineel uit als een lege doos, dus die scènes worden hier nagetekend
-- met Frames.
--
-- Alles rekent in dezelfde 280x160 die de SVG gebruikt, zodat de coördinaten uit crash.html
-- rechtstreeks over te nemen zijn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)

local Art = {}

local B = 280   -- viewBox breedte
local H = 160   -- viewBox hoogte

export type Doek = {
	vak: Frame,
	rect: (number, number, number, number, Color3, number?, number?) -> Frame,
	rond: (number, number, number, Color3, number?) -> Frame,
	ovaal: (number, number, number, number, Color3, number?) -> Frame,
	lijn: (number, number, number, number, number, Color3, number?) -> Frame,
	tekst: (number, number, string, number, Color3, Enum.Font?) -> TextLabel,
}

function Art.canvas(ouder: Instance, achtergrondVan: Color3, achtergrondTot: Color3, rotatie: number?): Doek
	local vak = Instance.new("Frame")
	vak.Name = "Art"
	vak.Size = UDim2.new(1, 0, 0, Theme.size.cardPreview)
	vak.BackgroundColor3 = achtergrondVan
	vak.BorderSizePixel = 0
	vak.ClipsDescendants = true
	vak.Parent = ouder
	UI.gradient(vak, achtergrondVan, achtergrondTot, rotatie or 90)

	local doek = {} :: any
	doek.vak = vak

	-- Een rechthoek. x en y zijn de linkerbovenhoek, net als in de SVG.
	function doek.rect(x: number, y: number, w: number, h: number, kleur: Color3, radius: number?, doorzicht: number?): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(x / B, y / H)
		f.Size = UDim2.fromScale(w / B, h / H)
		if radius and radius > 0 then UI.corner(f, radius) end
		f.Parent = vak
		return f
	end

	-- Een cirkel met het middelpunt op cx, cy. De maat gaat in pixels, want een cirkel die
	-- met het vak meerekt wordt een ovaal.
	function doek.rond(cx: number, cy: number, r: number, kleur: Color3, doorzicht: number?): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(cx / B, cy / H)
		f.Size = UDim2.fromOffset(r * 2, r * 2)
		UI.corner(f, r)
		f.Parent = vak
		return f
	end

	function doek.ovaal(cx: number, cy: number, rx: number, ry: number, kleur: Color3, doorzicht: number?): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(cx / B, cy / H)
		f.Size = UDim2.fromOffset(rx * 2, ry * 2)
		UI.corner(f, math.min(rx, ry))
		f.Parent = vak
		return f
	end

	-- Een lijn tussen twee punten: een gedraaid balkje op het midden.
	function doek.lijn(x1: number, y1: number, x2: number, y2: number, dikte: number, kleur: Color3, doorzicht: number?): Frame
		local dx, dy = x2 - x1, y2 - y1
		local lengte = math.sqrt(dx * dx + dy * dy)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale((x1 + x2) / 2 / B, (y1 + y2) / 2 / H)
		f.Size = UDim2.fromOffset(lengte, dikte)
		f.Rotation = math.deg(math.atan2(dy, dx))
		f.Parent = vak
		return f
	end

	function doek.tekst(cx: number, cy: number, tekst: string, maat: number, kleur: Color3, font: Enum.Font?): TextLabel
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(cx / B, cy / H)
		t.Size = UDim2.fromOffset(120, maat + 8)
		t.Text = tekst
		t.TextSize = maat
		t.TextColor3 = kleur
		t.Font = font or Theme.font.uiMed
		t.RichText = false
		t.Parent = vak
		return t
	end

	return doek
end

-- ---------- de negen scènes ----------
-- De coördinaten komen één op één uit de SVG's in crash.html.

local WIT = Color3.fromHex("ffffff")

function Art.crash(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("5fb8ff"), Color3.fromHex("b8e4ff"))
	-- gras
	d.rect(0, 128, 280, 32, Color3.fromHex("5aa030"))
	d.rect(0, 128, 280, 6, Color3.fromHex("7ac050"))
	-- wolken
	d.ovaal(50, 40, 20, 8, WIT, 0.2)
	d.ovaal(200, 30, 25, 10, WIT, 0.15)
	-- de vliegbaan: de kromme uit de SVG in korte stukjes
	local punten = {
		{20, 130}, {50, 124}, {80, 116}, {105, 105}, {128, 92},
		{148, 78}, {168, 64}, {190, 52}, {214, 41}, {240, 30},
	}
	for i = 1, #punten - 1 do
		d.lijn(punten[i][1], punten[i][2], punten[i + 1][1], punten[i + 1][2], 3, WIT, 0.1)
	end
	-- het vliegtuigje
	local romp = d.ovaal(240, 30, 22, 6, Color3.fromHex("e63946"))
	romp.Rotation = -25
	local staart = d.rect(222, 18, 10, 8, Color3.fromHex("c91e2e"), 1)
	staart.Rotation = -25
	d.rond(248, 26, 3, Color3.fromHex("87ceeb"))
end

function Art.roulette(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("2a1010"), Color3.fromHex("0a0505"))
	local goud = Color3.fromHex("cc9900")
	d.rond(140, 80, 60, Color3.fromHex("1a0a0a"))
	local ring = d.rond(140, 80, 60, Color3.fromHex("8a2020"))
	ring.BackgroundTransparency = 1
	UI.stroke(ring, Color3.fromHex("8a2020"), 2)
	local binnen = d.rond(140, 80, 55, goud)
	binnen.BackgroundTransparency = 1
	UI.stroke(binnen, goud, 1)
	d.lijn(140, 25, 140, 135, 1, goud, 0.5)
	d.lijn(85, 80, 195, 80, 1, goud, 0.5)
	d.lijn(101, 41, 179, 119, 1, goud, 0.5)
	d.lijn(179, 41, 101, 119, 1, goud, 0.5)
	local naaf = d.rond(140, 80, 20, Color3.fromHex("3a1010"))
	UI.stroke(naaf, goud, 1.5)
	d.rond(140, 80, 6, goud)
	d.rond(180, 60, 4, WIT)
end

function Art.tower(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("2a0a3a"), Color3.fromHex("0a0510"))
	local paars = Color3.fromHex("8a4ac9")
	local vulling = Color3.fromHex("2a0a4a")
	for i = 0, 3 do
		local rij = d.rect(90, 30 + i * 25, 100, 20, vulling, 2)
		UI.stroke(rij, paars, 1)
	end
	-- de bovenste rij ligt open: twee groene en een rode
	d.rond(110, 40, 6, Theme.color.neon, 0.3)
	d.rond(140, 40, 6, Theme.color.neon, 0.3)
	d.rond(170, 40, 6, Theme.color.red, 0.2)
	for r = 1, 3 do
		for _, x in {110, 140, 170} do
			local c = d.rond(x, 40 + r * 25, 6, vulling)
			UI.stroke(c, paars, 1)
		end
	end
	-- het ei bovenop
	local ei = d.ovaal(140, 14, 10, 7, Color3.fromHex("e0616e"))
	UI.stroke(ei, Color3.fromHex("8a0e1e"), 1)
	d.rond(137, 11, 1.5, Theme.color.gold)
	d.rond(143, 11, 1.5, Theme.color.gold)
end

function Art.mines(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("1a1a2a"), Color3.fromHex("0a0a14"), 135)
	local vulling = Color3.fromHex("2a2a4a")
	local rand = Color3.fromHex("4a4a7a")
	for r = 0, 3 do
		for k = 0, 4 do
			local x, y = 80 + k * 30, 20 + r * 30
			local kleur, doorzicht = vulling, 0
			if r == 1 and k == 1 then kleur, doorzicht = Theme.color.neon, 0.3
			elseif r == 2 and k == 2 then kleur, doorzicht = Theme.color.red, 0.2
			elseif r == 2 and k == 3 then kleur, doorzicht = Theme.color.neon, 0.3
			end
			local t = d.rect(x, y, 24, 24, kleur, 3, doorzicht)
			UI.stroke(t, rand, 1)
		end
	end
	d.tekst(152, 92, "\u{2726}", 14, WIT)
end

function Art.plinko(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("1a0a2a"), Color3.fromHex("0a0518"))
	local pin = Color3.fromHex("8a5ac9")
	for rij = 0, 4 do
		for k = 0, rij do
			local x = 140 - rij * 15 + k * 30
			d.rond(x, 30 + rij * 20, 2, pin)
		end
	end
	local bakken = {
		Color3.fromHex("e0616e"), Theme.color.gold, Theme.color.neon,
		Theme.color.neon, Theme.color.gold, Color3.fromHex("e0616e"),
	}
	for i, kleur in bakken do
		d.rect(70 + (i - 1) * 24, 130, 22, 20, kleur, 0, 0.4)
	end
	d.rond(155, 80, 4, Theme.color.neon)
end

function Art.blackjack(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("0a3a1a"), Color3.fromHex("051a0a"))
	local function kaart(x: number, rang: string, teken: string, kleur: Color3, draai: number)
		local k = d.rect(x, 50, 50, 70, Theme.color.card, 4)
		k.Rotation = draai
		local r = Instance.new("TextLabel")
		r.BackgroundTransparency = 1
		r.Size = UDim2.fromScale(1, 0.55)
		r.Text = rang
		r.TextSize = 20
		r.Font = Theme.font.uiBold
		r.TextColor3 = Color3.fromHex("1a1a1a")
		r.RichText = false
		r.Parent = k
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.5)
		s.Size = UDim2.fromScale(1, 0.45)
		s.Text = teken
		s.TextSize = 14
		s.Font = Theme.font.uiMed
		s.TextColor3 = kleur
		s.RichText = false
		s.Parent = k
		UI.stroke(k, Color3.fromHex("aaaaaa"), 1)
	end
	kaart(80, "A", "\u{2665}", Color3.fromHex("e0616e"), -8)
	kaart(150, "K", "\u{2660}", Color3.fromHex("1a1a1a"), 8)
	d.tekst(140, 140, "BLACKJACK", 12, Theme.color.gold, Theme.font.num)
end

function Art.horse(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("7ec8ff"), Color3.fromHex("b8e4ff"))
	d.rect(0, 88, 280, 72, Color3.fromHex("4a8a2a"))
	for _, y in {105, 125, 145} do
		d.lijn(0, y, 280, y, 1, WIT, 0.5)
	end
	d.rect(238, 88, 4, 70, WIT)
	d.rect(242, 88, 14, 10, Color3.fromHex("e0616e"))
	d.tekst(60, 112, "\u{1F3C7}", 20, WIT)
	d.tekst(120, 132, "\u{1F3C7}", 20, WIT)
	d.tekst(90, 152, "\u{1F3C7}", 20, WIT)
end

function Art.scratch(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("1d2a24"), Color3.fromHex("16181f"))
	local lot = d.rect(52, 26, 176, 110, Theme.color.panel, 8)
	UI.stroke(lot, Theme.color.neon, 2)
	for r = 0, 1 do
		for k = 0, 2 do
			local vakje = d.rect(70 + k * 48, 44 + r * 38, 44, 34, Theme.color.bg, 4)
			UI.stroke(vakje, Theme.color.border, 1)
		end
	end
	for k = 0, 2 do
		d.tekst(92 + k * 48, 61, "\u{1F48E}", 20, WIT)
	end
	for k = 0, 2 do
		d.tekst(92 + k * 48, 99, "?", 17, Theme.color.muted)
	end
end

function Art.wheel(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("12222a"), Color3.fromHex("16181f"))
	local rand = Theme.color.border
	local schijf = d.rond(140, 88, 58, Theme.color.panel)
	schijf.ClipsDescendants = true
	UI.stroke(schijf, rand, 2)

	-- Twee gekleurde parten. Een taartpunt kan Roblox niet tekenen, dus het is een gedraaid
	-- kwart dat door de ronde rand wordt afgesneden -- dat leest hetzelfde.
	local function part(kleur: Color3, randKleur: Color3, draai: number)
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0, 1)
		p.Position = UDim2.fromScale(0.5, 0.5)
		p.Size = UDim2.fromScale(0.5, 0.5)
		p.BackgroundColor3 = kleur
		p.BorderSizePixel = 0
		p.Rotation = draai
		p.Parent = schijf
		UI.stroke(p, randKleur, 1)
	end
	part(Color3.fromHex("3a2f12"), Theme.color.gold, 45)
	part(Color3.fromHex("14301f"), Theme.color.neon, 180)

	for _, hoek in {0, 45, 90, 135} do
		local l = d.lijn(140 - 58, 88, 140 + 58, 88, 1, rand)
		l.Rotation = hoek
	end
	local naaf = d.rond(140, 88, 11, Theme.color.bg)
	UI.stroke(naaf, rand, 1)
	-- het pijltje bovenaan
	local punt = d.rect(133, 24, 14, 14, Theme.color.gold, 2)
	punt.Rotation = 45
	d.tekst(168, 52, "10\u{00D7}", 12, Theme.color.gold, Theme.font.num)
end

Art.BY_ID = {
	crash = Art.crash, roulette = Art.roulette, tower = Art.tower, mines = Art.mines,
	plinko = Art.plinko, blackjack = Art.blackjack, horse = Art.horse,
	scratch = Art.scratch, wheel = Art.wheel,
} :: { [string]: (Instance) -> () }

return Art
]],
	["Blackjack"] = [[
--!strict
-- Blackjack: zes stapels, dealer pakt bij tot 17. De dichte kaart van de dealer staat hier
-- niet in het geheugen van de client -- die komt pas over als de dealer speelt.
--
-- De dubbele inzet wordt er overal bij gezet ("DOUBLED"), want zonder dat leek het alsof
-- je bij een gedubbelde hand te weinig kreeg. Het bedrag klopte altijd; wat ontbrak was
-- dat het scherm liet zien waar het over ging.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Blackjack = {}

type Kaart = { r: string, s: string }

local function kaartVlak(ouder: Instance, kaart: Kaart?, volgorde: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(70, 98)
	f.LayoutOrder = volgorde
	f.BackgroundColor3 = if kaart then Theme.color.card else Color3.fromHex("1b222c")
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.card)
	UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	local tekst = if kaart then kaart.r .. "\n" .. kaart.s else "\u{2756}"
	local rood = kaart ~= nil and (kaart.s == "\u{2665}" or kaart.s == "\u{2666}")
	local kleur = if not kaart then Theme.color.muted
		elseif rood then Color3.fromHex("c0392b")
		else Color3.fromHex("14181f")
	local t = UI.label(f, tekst, {
		size = 22, color = kleur, font = Theme.font.uiMed, align = Enum.TextXAlignment.Center,
	})
	t.Size = UDim2.fromScale(1, 1)
	t.TextYAlignment = Enum.TextYAlignment.Center
	return f
end

function Blackjack.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "BLACKJACK")

	local tafel = UI.panel(bord, "Table")
	UI.list(tafel, 8)
	UI.panelTitle(tafel, "blackjack \u{00B7} dealer stands on all 17s")

	local dealerKop = UI.label(tafel, "DEALER", {
		size = Theme.text.small, color = Theme.color.muted, font = Theme.font.uiMed,
	})
	local dealerRij = Instance.new("Frame")
	dealerRij.Size = UDim2.new(1, 0, 0, 104)
	dealerRij.BackgroundTransparency = 1
	dealerRij.Parent = tafel
	local dl = UI.list(dealerRij, 8, Enum.FillDirection.Horizontal)
	dl.VerticalAlignment = Enum.VerticalAlignment.Center

	local spelerKop = UI.label(tafel, "YOU", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
	})
	local spelerRij = Instance.new("Frame")
	spelerRij.Size = UDim2.new(1, 0, 0, 104)
	spelerRij.BackgroundTransparency = 1
	spelerRij.Parent = tafel
	local sl = UI.list(spelerRij, 8, Enum.FillDirection.Horizontal)
	sl.VerticalAlignment = Enum.VerticalAlignment.Center

	local balk = Common.banner(tafel)
	balk.set("PLACE YOUR BET", nil)

	local actief = false
	local gedubbeld = false
	local betBox: Common.BetBox
	local dealKnop: TextButton
	local hitKnop: TextButton
	local standKnop: TextButton
	local doubleKnop: TextButton

	local function wis(rij: Frame)
		for _, k in rij:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
	end

	local function toonHand(rij: Frame, kaarten: { Kaart }, dicht: boolean)
		wis(rij)
		for i, k in kaarten do
			kaartVlak(rij, k, i)
		end
		if dicht then
			kaartVlak(rij, nil, #kaarten + 1)
		end
	end

	-- De inzetregel: hier komt (DOUBLED) bij te staan zodra er gedubbeld is.
	local function zetKoppen(spelerWaarde: number?, dealerWaarde: number?, inzet: number?)
		local dub = if gedubbeld then "  \u{00B7}  DOUBLED" else ""
		spelerKop.Text = "YOU" .. (if spelerWaarde then "  \u{00B7}  " .. spelerWaarde else "")
			.. (if inzet then "  \u{00B7}  STAKE $" .. Money.fmt(inzet) else "") .. dub
		dealerKop.Text = "DEALER" .. (if dealerWaarde then "  \u{00B7}  " .. dealerWaarde else "")
	end

	local function zetKnoppen()
		dealKnop.Visible = not actief
		hitKnop.Visible = actief
		standKnop.Visible = actief
		doubleKnop.Visible = actief
		betBox.lock(actief)
	end

	local function toonEinde(res: any)
		actief = false
		gedubbeld = res.doubled == true
		toonHand(spelerRij, res.player, false)
		toonHand(dealerRij, res.dealer, false)
		zetKoppen(res.playerValue, res.dealerValue, res.bet)
		zetKnoppen()

		local dub = if res.doubled then "  (DOUBLED)" else ""
		if res.result == "win" then
			local wat = if res.natural then "BLACKJACK" else "YOU WIN"
			balk.set(wat .. "  \u{00B7}  +$" .. Money.fmt(res.payout) .. dub, if res.natural then "gold" else "green")
			Common.toast("+$" .. Money.fmt(res.payout) .. dub, if res.natural then "gold" else "green")
		elseif res.result == "push" then
			balk.set("PUSH  \u{00B7}  $" .. Money.fmt(res.payout) .. " BACK" .. dub, nil)
		else
			balk.set("DEALER WINS  \u{00B7}  -$" .. Money.fmt(res.bet) .. dub, "red")
		end
	end

	local function toonSpel(res: any)
		actief = true
		gedubbeld = res.doubled == true
		toonHand(spelerRij, res.player, false)
		toonHand(dealerRij, { res.dealerUp }, true)
		zetKoppen(res.playerValue, res.dealerValue, res.bet)
		-- Dubbelen mag alleen op de eerste twee kaarten, net als aan een echte tafel.
		doubleKnop.Active = #res.player == 2 and not gedubbeld
		doubleKnop.BackgroundTransparency = if doubleKnop.Active then 0.1 else 0.6
		zetKnoppen()
		balk.set("HIT, STAND OR DOUBLE", nil)
	end

	local function verwerk(res: any)
		if not res then return end
		if res.done then
			toonEinde(res)
		else
			toonSpel(res)
		end
	end

	-- ---------- de bediening ----------
	local regels = UI.panel(bediening, "Rules")
	UI.list(regels, 4)
	UI.panelTitle(regels, "rules")
	Common.statRow(regels, "DECKS", "6")
	Common.statRow(regels, "BLACKJACK PAYS", "3:2")
	Common.statRow(regels, "DEALER", "STANDS ON 17")
	Common.statRow(regels, "DOUBLE", "FIRST TWO CARDS")
	Common.statRow(regels, "RTP", "99%")

	betBox = Common.betBox(bediening, 10)
	dealKnop = UI.primary(bediening, "DEAL")
	hitKnop = UI.primary(bediening, "HIT")
	standKnop = UI.secondary(bediening, "STAND")
	standKnop.Size = UDim2.new(1, 0, 0, 40)
	doubleKnop = UI.secondary(bediening, "DOUBLE")
	doubleKnop.Size = UDim2.new(1, 0, 0, 40)

	dealKnop.Activated:Connect(function()
		if actief then return end
		gedubbeld = false
		verwerk(Common.call("Bet", "blackjack", betBox.get()))
	end)
	hitKnop.Activated:Connect(function()
		if not actief then return end
		verwerk(Common.call("Act", "blackjack", "hit"))
	end)
	standKnop.Activated:Connect(function()
		if not actief then return end
		verwerk(Common.call("Act", "blackjack", "stand"))
	end)
	doubleKnop.Activated:Connect(function()
		if not actief or not doubleKnop.Active then return end
		verwerk(Common.call("Act", "blackjack", "double"))
	end)

	zetKnoppen()
	zetKoppen(nil, nil, nil)
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "blackjack")
	Common.oddsPanel(bediening, "odds", "6 decks, continuously shuffled. Dealer stands on all 17s. Blackjack pays 3:2 and a dealer blackjack is checked straight away. Double on any first two cards. No split, no insurance. House edge around 1%.")

end

return Blackjack
]],
	["Bus"] = [[
--!strict
-- Ride the Bus: vier keer raden door één stapel -- kleur, hoger of lager, binnen of buiten,
-- en de soort. De kans wordt geteld op wat er nog in de stapel ligt, dus uitstappen levert
-- na elke call precies hetzelfde percentage op, hoe goed of slecht je ook geraden hebt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Bus = {}

local STAPNAMEN = {"COLOUR", "HIGHER OR LOWER", "INSIDE OR OUTSIDE", "SUIT"}

-- Een speelkaart: wit vlak, rode of zwarte tekst, zoals in de webversie.
local function kaartVlak(ouder: Instance, kaart: { r: string, s: string }?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(74, 104)
	f.BackgroundColor3 = if kaart then Theme.color.card else Theme.color.panelLight
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.card)
	UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	if kaart then
		local rood = kaart.s == "\u{2665}" or kaart.s == "\u{2666}"
		local kleur = if rood then Color3.fromHex("c0392b") else Color3.fromHex("14181f")
		local t = UI.label(f, kaart.r .. "\n" .. kaart.s, {
			size = 22, color = kleur, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center,
		})
		t.Size = UDim2.fromScale(1, 1)
		t.TextYAlignment = Enum.TextYAlignment.Center
	else
		local t = UI.label(f, "?", {
			size = 30, color = Theme.color.muted, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center,
		})
		t.Size = UDim2.fromScale(1, 1)
		t.TextYAlignment = Enum.TextYAlignment.Center
	end
	return f
end

function Bus.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "RIDE THE BUS")

	local tafel = UI.panel(bord, "Table")
	UI.list(tafel, 10)
	UI.panelTitle(tafel, "ride the bus")

	local stapLabel = UI.label(tafel, "STEP 1 \u{00B7} " .. STAPNAMEN[1], {
		size = Theme.text.label, color = Theme.color.neon, font = Theme.font.uiMed,
	})

	local kaarten = Instance.new("Frame")
	kaarten.Size = UDim2.new(1, 0, 0, 110)
	kaarten.BackgroundTransparency = 1
	kaarten.Parent = tafel
	local kaartLayout = UI.list(kaarten, 10, Enum.FillDirection.Horizontal)
	kaartLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local keuzes = Instance.new("Frame")
	keuzes.Size = UDim2.new(1, 0, 0, 40)
	keuzes.BackgroundTransparency = 1
	keuzes.Parent = tafel
	UI.list(keuzes, 8, Enum.FillDirection.Horizontal)

	local balk = Common.banner(tafel)
	balk.set("FOUR CALLS, ONE DECK", nil)

	local actief = false
	local stap = 0
	local betBox: Common.BetBox
	local startKnop: TextButton
	local uitKnop: TextButton

	local function wisKaarten()
		for _, k in kaarten:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
	end

	local function wisKeuzes()
		for _, k in keuzes:GetChildren() do
			if k:IsA("TextButton") then k:Destroy() end
		end
	end

	local roep: (string) -> ()

	-- De knoppen voor deze stap, met de kans erbij. Een kans van nul is geen knop maar een
	-- grijs vlak: de server weigert die call toch, en dat hoor je te zien voordat je klikt.
	local function toonOpties(opties: { { key: string, label: string, chance: number } })
		wisKeuzes()
		for i, o in opties do
			local b = Instance.new("TextButton")
			b.Name = o.key
			b.Text = o.label .. "   " .. string.format("%d%%", math.floor(o.chance * 100 + 0.5))
			b.Font = Theme.font.uiMed
			b.TextSize = Theme.text.small
			b.LayoutOrder = i
			b.Size = UDim2.new(1 / #opties, -8, 1, 0)
			b.BorderSizePixel = 0
			b.AutoButtonColor = false
			b.RichText = false
			local kan = o.chance > 0
			b.Active = kan
			b.BackgroundColor3 = if kan then Theme.color.neon else Theme.color.bg
			b.BackgroundTransparency = if kan then 0.1 else 0.6
			b.TextColor3 = if kan then Theme.color.bg else Theme.color.muted
			UI.corner(b, Theme.radius.button)
			b.Parent = keuzes
			b.Activated:Connect(function()
				if kan then roep(o.key) end
			end)
		end
	end

	local function zetActief()
		startKnop.Visible = not actief
		uitKnop.Visible = actief
		uitKnop.Active = stap > 0
		keuzes.Visible = actief
		betBox.lock(actief)
	end

	function roep(keuze: string)
		if not actief then return end
		local res = Common.call("Act", "bus", keuze)
		if not res then return end

		kaartVlak(kaarten, res.card).LayoutOrder = stap + 1
		if not res.hit then
			actief = false
			stap = 0
			wisKeuzes()
			zetActief()
			balk.set("WRONG CALL", "red")
			return
		end

		if res.done then
			actief = false
			stap = 0
			wisKeuzes()
			zetActief()
			balk.set("ALL FOUR  \u{00B7}  +$" .. Money.fmt(res.payout), "gold")
			Common.toast("+$" .. Money.fmt(res.payout), "gold")
			return
		end

		stap = res.step
		stapLabel.Text = "STEP " .. (stap + 1) .. " \u{00B7} " .. STAPNAMEN[stap + 1]
		balk.set(Money.fmt(res.mult) .. "\u{00D7} SO FAR", "green")
		uitKnop.Text = "CASH OUT  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}"
		toonOpties(res.options)
		zetActief()
	end

	-- ---------- de bediening ----------
	local uitleg = UI.panel(bediening, "Steps")
	UI.list(uitleg, 4)
	UI.panelTitle(uitleg, "the four calls")
	for i, naam in STAPNAMEN do
		Common.statRow(uitleg, i .. ". " .. naam, "")
	end

	betBox = Common.betBox(bediening, 10)
	startKnop = UI.primary(bediening, "START THE RIDE")
	uitKnop = UI.primary(bediening, "CASH OUT")
	uitKnop.Visible = false

	startKnop.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "bus", betBox.get())
		if not res then return end
		actief = true
		stap = 0
		wisKaarten()
		stapLabel.Text = "STEP 1 \u{00B7} " .. STAPNAMEN[1]
		uitKnop.Text = "CASH OUT"
		toonOpties(res.options)
		zetActief()
		balk.set("RED OR BLACK?", nil)
	end)

	uitKnop.Activated:Connect(function()
		if not actief or stap < 1 then return end
		local res = Common.call("CashOut", "bus")
		if not res then return end
		actief = false
		stap = 0
		wisKeuzes()
		zetActief()
		balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		Common.toast("+$" .. Money.fmt(res.payout), "green")
	end)

	wisKaarten()
	zetActief()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "bus")
	Common.oddsPanel(bediening, "odds", "One shuffled 52-card deck. Every button shows your chance: the multiplier is 0.97 / the chance of getting that far, counted off the cards still in the deck. So stopping after any call returns 97%. A tie always loses.")

end

return Bus
]],
	["Common"] = [[
--!strict
-- Wat elk speelscherm nodig heeft: een blad om op te bouwen, een inzetvak met de ficheknoppen
-- eronder, en een lijntje naar de server. Eén plek, zodat de tien schermen er hetzelfde
-- uitzien en zich hetzelfde gedragen -- precies zoals bindBet() en takeBet() dat in de
-- webversie doen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Money = require(ReplicatedStorage.Shared.Money)

local Common = {}

-- ---------- saldo en meldingen ----------
-- De schil weet het saldo en heeft het meldingenvak; de schermen vragen het hier op.
local saldo = Money.START
local melder: ((string, UI.ToastKind?) -> ())? = nil
local ga: ((string) -> ())? = nil
-- Elk speelscherm heeft links een saldopaneel, net als in de webversie. Ze staan hier
-- allemaal in, zodat één bericht van de server ze in één keer bijwerkt.
local saldoLabels: { TextLabel } = {}

function Common.setBalance(n: number): ()
	saldo = n
	local tekst = Money.fmt(n)
	for _, l in saldoLabels do
		if l.Parent then l.Text = tekst end
	end
end

function Common.setNavigate(f: (string) -> ()): ()
	ga = f
end

function Common.navigate(route: string): ()
	local f = ga
	if f then f(route) end
end

function Common.balance(): number
	return saldo
end

function Common.setToaster(f: (string, UI.ToastKind?) -> ()): ()
	melder = f
end

function Common.toast(tekst: string, soort: UI.ToastKind?): ()
	local f = melder
	if f then f(tekst, soort) end
end

-- Een uitslag van de server. Klapt de aanroep, dan zegt het scherm dat, in plaats van
-- stil te blijven staan.
function Common.call(kanaal: string, ...): any
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Net.fn(kanaal):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		Common.toast("DE SERVER ANTWOORDT NIET", "red")
		return nil
	end
	if typeof(res) == "table" and res.ok == false then
		Common.toast(string.upper(tostring(res.err or "dat ging niet")), "red")
		return nil
	end
	return res
end

-- ---------- indeling ----------
-- Het blad waar een scherm op gebouwd wordt: scrollt, en groeit met zijn inhoud mee.
function Common.sheet(ouder: Instance): ScrollingFrame
	local blad = Instance.new("ScrollingFrame")
	blad.Name = "Sheet"
	blad.Size = UDim2.fromScale(1, 1)
	blad.BackgroundTransparency = 1
	blad.BorderSizePixel = 0
	blad.ScrollBarThickness = 4
	blad.ScrollBarImageColor3 = Theme.color.border
	blad.CanvasSize = UDim2.new()
	blad.AutomaticCanvasSize = Enum.AutomaticSize.Y
	blad.Parent = ouder
	UI.padding(blad, 4)
	UI.list(blad, Theme.size.gap + 4)
	return blad
end

-- Een speelscherm zoals `.game-view` in de CSS: `grid-template-columns: 320px 1fr` en
-- `height: 100vh`. Dus links een aside van 320 breed die zelf scrolt, en rechts een vlak dat
-- de rest van het scherm vult -- in de hoogte ook. Daar staat het speelveld in, gecentreerd.
--
-- Dat laatste was het grootste verschil met de webversie: alles onder elkaar in een
-- scrollende lijst maakt van een bord van 600 pixels een streepje van 200.
--
-- Boven in de aside staat de kop van het spel (`← LOBBY` plus de naam) en daaronder het
-- saldopaneel, precies de volgorde uit de markup.
function Common.columns(ouder: Instance, titel: string?): (Frame, ScrollingFrame)
	local breedte = Theme.size.asideWidth
	local vak = Instance.new("Frame")
	vak.Name = "GameView"
	vak.Size = UDim2.fromScale(1, 1)
	vak.BackgroundTransparency = 1
	vak.Parent = ouder

	-- links: de aside, met een eigen schuifbalk zoals `aside.game-aside { overflow-y: auto }`
	local aside = Instance.new("ScrollingFrame")
	aside.Name = "Aside"
	aside.Size = UDim2.new(0, breedte, 1, 0)
	aside.BackgroundTransparency = 1
	aside.BorderSizePixel = 0
	aside.ScrollBarThickness = 0
	aside.CanvasSize = UDim2.new()
	aside.AutomaticCanvasSize = Enum.AutomaticSize.Y
	aside.Parent = vak
	UI.list(aside, Theme.size.asideGap)

	-- rechts: het speelveld, een paneel dat de rest vult
	local bordVak = Instance.new("Frame")
	bordVak.Name = "Main"
	bordVak.Position = UDim2.new(0, breedte + Theme.size.viewGap, 0, 0)
	bordVak.Size = UDim2.new(1, -(breedte + Theme.size.viewGap), 1, 0)
	bordVak.BackgroundColor3 = Theme.color.panel
	bordVak.BorderSizePixel = 0
	bordVak.ClipsDescendants = true
	UI.gradient(bordVak, Theme.color.panel, Theme.color.panelLight)
	UI.corner(bordVak, Theme.radius.panel)
	UI.stroke(bordVak)
	bordVak.Parent = vak

	-- Waar het spel zelf in komt: gecentreerd, zoals het bord in de webversie.
	local bord = Instance.new("Frame")
	bord.Name = "Board"
	bord.Size = UDim2.new(1, -Theme.size.panelPad * 2, 1, -Theme.size.panelPad * 2)
	bord.Position = UDim2.fromOffset(Theme.size.panelPad, Theme.size.panelPad)
	bord.BackgroundTransparency = 1
	bord.Parent = bordVak
	local bordLijst = UI.list(bord, Theme.size.asideGap)
	bordLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bordLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	-- .crash-header: de terugknop en de naam van het spel, naast elkaar.
	if titel then
		-- Geen LayoutOrder: die staat overal op nul, en bij gelijke waarde houdt Roblox de
		-- volgorde waarin de kinderen zijn toegevoegd. De kop wordt als eerste toegevoegd,
		-- dus hij staat bovenaan. Zette ik hier 1 neer, dan kwam hij juist onder alles wat
		-- een scherm daarna toevoegt -- want dat staat op nul.
		local kop = Instance.new("Frame")
		kop.Name = "Header"
		kop.Size = UDim2.new(1, 0, 0, 34)
		kop.BackgroundTransparency = 1
		kop.Parent = aside
		local kopIndeling = UI.list(kop, 12, Enum.FillDirection.Horizontal)
		kopIndeling.VerticalAlignment = Enum.VerticalAlignment.Center

		local terug = UI.backButton(kop)
		terug.LayoutOrder = 1
		terug.Activated:Connect(function()
			Common.navigate("home")
		end)

		local naam = UI.label(kop, string.upper(titel), {
			size = Theme.text.title, color = Theme.color.neon, font = Theme.font.uiMed,
		})
		naam.LayoutOrder = 2
		naam.Size = UDim2.new(0, 0, 1, 0)
		naam.AutomaticSize = Enum.AutomaticSize.X
	end

	-- Het saldopaneel, zoals `.panel.balance` in de markup: alles gecentreerd.
	local saldoVak = UI.panel(aside, "Balance")
	UI.list(saldoVak, 2)
	local kopje = UI.label(saldoVak, "BALANCE", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
	})
	kopje.Size = UDim2.new(1, 0, 0, 16)
	local bedrag = UI.moneyLabel(saldoVak, Money.fmt(saldo), Theme.text.balance, true)
	table.insert(saldoLabels, bedrag)

	-- Onder de 900 pixels gaat de aside erboven staan; dan is het bord nog steeds groot.
	local smalNu: boolean? = nil
	local function meet()
		local breed = vak.AbsoluteSize.X
		if breed <= 0 then return end
		local smal = breed < 900
		if smal == smalNu then return end
		smalNu = smal
		if smal then
			aside.Size = UDim2.new(1, 0, 0, 300)
			aside.Position = UDim2.new()
			bordVak.Position = UDim2.new(0, 0, 0, 300 + Theme.size.viewGap)
			bordVak.Size = UDim2.new(1, 0, 1, -(300 + Theme.size.viewGap))
		else
			aside.Size = UDim2.new(0, breedte, 1, 0)
			aside.Position = UDim2.new()
			bordVak.Position = UDim2.new(0, breedte + Theme.size.viewGap, 0, 0)
			bordVak.Size = UDim2.new(1, -(breedte + Theme.size.viewGap), 1, 0)
		end
	end
	vak:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	return bord, aside
end

-- Een rij knoppen naast elkaar, gelijk verdeeld.
function Common.row(ouder: Instance, hoogte: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.Size = UDim2.new(1, 0, 0, hoogte or 30)
	f.BackgroundTransparency = 1
	f.Parent = ouder
	local l = UI.list(f, 4, Enum.FillDirection.Horizontal)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

-- ---------- het inzetvak ----------
export type BetBox = {
	panel: Frame,
	get: () -> number,
	set: (number) -> (),
	lock: (boolean) -> (),
}

-- Het inzetveld met ½, 2×, MIN en MAX eronder. Dezelfde vier knoppen en dezelfde rekenregels
-- als bindBet() in de webversie; het afronden gebeurt hier alleen om het netjes te tonen,
-- de server rekent zelf na.
function Common.betBox(ouder: Instance, start: number?): BetBox
	local paneel = UI.panel(ouder, "BetPanel")
	UI.list(paneel, 6)
	-- .field-label: "STAKE" links, het dollarteken als hint rechts.
	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	kop.BackgroundTransparency = 1
	kop.Parent = paneel
	UI.label(kop, "STAKE", { size = Theme.text.small, color = Theme.color.muted })
	UI.label(kop, "$", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
	})

	local vak = UI.numberBox(paneel, Money.fmt(start or 10))
	local ficherij = Common.row(paneel, 24)

	local function huidig(): number
		return tonumber(vak.Text) or 0
	end
	local function zet(n: number)
		vak.Text = Money.fmt(math.max(0, Money.round2(n)))
	end

	type Fiche = { naam: string, maak: () -> number }
	local knoppen: { Fiche } = {
		{ naam = "\u{00BD}", maak = function() return math.max(Money.MIN_BET, Money.round2(huidig() / 2)) end },
		{ naam = "2\u{00D7}", maak = function() return math.min(saldo, Money.round2(huidig() * 2)) end },
		{ naam = "MIN", maak = function() return Money.MIN_BET end },
		{ naam = "MAX", maak = function() return saldo end },
	}
	for _, fiche in knoppen do
		-- .chips is een raster van vier gelijke kolommen met 4 pixels ertussen.
		local b = UI.chip(ficherij, fiche.naam)
		b.Size = UDim2.new(0.25, -3, 0, 24)
		b.Activated:Connect(function()
			zet(fiche.maak())
		end)
	end

	-- Enter sluit het toetsenbord; dat was op de telefoon in de webversie een aparte
	-- knop, hier doet Roblox het zelf. Wel meteen netjes tonen wat er staat.
	vak.FocusLost:Connect(function()
		zet(huidig())
	end)

	return {
		panel = paneel,
		get = huidig,
		set = zet,
		lock = function(op: boolean)
			vak.TextEditable = not op
			vak.TextTransparency = if op then 0.5 else 0
			for _, k in ficherij:GetChildren() do
				if k:IsA("TextButton") then
					k.Active = not op
					k.TextTransparency = if op then 0.5 else 0
				end
			end
		end,
	}
end

-- ---------- de twee panelen die elk speelscherm heeft ----------
-- In de webversie sluit elke aside af met een STATISTICS- en een ODDS-paneel. Die horen
-- erbij: ze vertellen wat het spel met je gedaan heeft en waarom de kansen zijn wat ze zijn.

-- Per spel de regels uit renderStats(): rondes, gewonnen, verloren, de beste multiplier en
-- de winst. Ze worden bijgewerkt zodra de server een profiel stuurt.
local statsVakken: { { spel: string, rondes: TextLabel, won: TextLabel, lost: TextLabel, best: TextLabel, winst: TextLabel } } = {}

function Common.statsPanel(ouder: Instance, spel: string): Frame
	local vak = UI.panel(ouder, "Stats")
	UI.list(vak, 6)
	UI.panelTitle(vak, "\u{25BA} statistics")

	local rondes = Common.statRow(vak, "ROUNDS", "0")
	local won = Common.statRow(vak, "WON", "0")
	won.TextColor3 = Theme.color.neon
	local lost = Common.statRow(vak, "LOST", "0")
	lost.TextColor3 = Theme.color.red
	-- Bij crash heet het BEST, bij de rest BEST MULT -- net als in renderStats.
	local best = Common.statRow(vak, if spel == "crash" then "BEST" else "BEST MULT", "\u{2014}")
	best.TextColor3 = Theme.color.gold
	local winst = Common.statRow(vak, "PROFIT", "+$0.00")
	winst.TextColor3 = Theme.color.neon

	table.insert(statsVakken, {
		spel = spel, rondes = rondes, won = won, lost = lost, best = best, winst = winst,
	})
	return vak
end

-- Het profiel binnenkrijgen: alle statistiekpanelen in één keer bijwerken.
function Common.setProfile(p: any): ()
	if typeof(p) ~= "table" or typeof(p.stats) ~= "table" then return end
	for _, v in statsVakken do
		local st = p.stats[v.spel]
		if typeof(st) == "table" then
			v.rondes.Text = string.format("%d", tonumber(st.rounds) or 0)
			v.won.Text = string.format("%d", tonumber(st.won) or 0)
			v.lost.Text = string.format("%d", tonumber(st.lost) or 0)
			local beste = tonumber(st.highest) or 0
			v.best.Text = if beste > 0 then Money.fmt(beste) .. "\u{00D7}" else "\u{2014}"
			local w = tonumber(st.profit) or 0
			v.winst.Text = (if w >= 0 then "+$" else "-$") .. Money.fmt(math.abs(w))
			v.winst.TextColor3 = if w >= 0 then Theme.color.neon else Theme.color.red
		end
	end
end

-- .odds-note: het uitlegblokje onder ODDS of PAYOUTS. De vetgedrukte stukken zijn in de
-- CSS goud; die staan hier tussen sterretjes en worden goud gekleurd.
function Common.oddsPanel(ouder: Instance, kop: string, tekst: string): Frame
	local vak = UI.panel(ouder, "Odds")
	UI.list(vak, 6)
	UI.panelTitle(vak, "\u{25BA} " .. kop)
	local t = UI.label(vak, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
	t.TextWrapped = true
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Size = UDim2.new(1, 0, 0, 0)
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.LineHeight = 1.7
	return vak
end

-- ---------- terugkerende stukjes ----------
-- Een groot vak met een getal erin: de multiplier bij crash, de stand bij blackjack.
function Common.bigNumber(ouder: Instance, tekst: string, kleur: Color3?): TextLabel
	local t = UI.label(ouder, tekst, {
		size = Theme.text.huge, color = kleur or Theme.color.neon, font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
	})
	t.Size = UDim2.new(1, 0, 0, 52)
	return t
end

-- Een regel met een naam links en een waarde rechts, zoals `.stat-row` in de CSS. Geeft
-- het waardelabel terug, zodat het scherm het kan bijwerken.
function Common.statRow(ouder: Instance, naam: string, waarde: string): TextLabel
	local rij = Instance.new("Frame")
	rij.Size = UDim2.new(1, 0, 0, 20)
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	rij.Size = UDim2.new(1, 0, 0, Theme.text.small + 8)
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted, name = "Key" })
	return UI.label(rij, waarde, {
		size = Theme.text.small, color = Theme.color.text, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Value",
	})
end

-- De uitslagbalk onder een speelveld: groen bij winst, rood bij verlies, grijs als er
-- niets gebeurd is.
export type Banner = { set: (string, string?) -> () }

function Common.banner(ouder: Instance): Banner
	local f = Instance.new("Frame")
	f.Name = "Banner"
	f.Size = UDim2.new(1, 0, 0, 36)
	f.BackgroundColor3 = Theme.color.panel
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.button)
	local rand = UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	local t = UI.label(f, "", {
		size = Theme.text.label, color = Theme.color.muted, font = Theme.font.uiMed,
		align = Enum.TextXAlignment.Center,
	})
	t.Size = UDim2.fromScale(1, 1)

	return {
		set = function(tekst: string, soort: string?)
			t.Text = tekst
			local kleur = if soort == "green" then Theme.color.neon
				elseif soort == "red" then Theme.color.red
				elseif soort == "gold" then Theme.color.gold
				else Theme.color.muted
			t.TextColor3 = kleur
			rand.Color = kleur
		end,
	}
end

return Common
]],
	["Crash"] = [[
--!strict
-- Crash: één ronde voor iedereen tegelijk. De client tekent de vlucht en telt de multiplier
-- mee op de servertijd, maar wat een cashout oplevert bepaalt de server -- de knop stuurt
-- alleen "ik stap uit", nooit een bedrag of een multiplier.
--
-- Het scherm volgt de webversie op de voet: rechts de RECENT-balk, daaronder de lucht waar
-- het vliegtuigje in klimt, en onderaan twee lijsten naast elkaar. Links de aside met het
-- saldo, het inzetpaneel met de schakelaar voor automatisch uitstappen, en de twee
-- panelen STATISTICS en ODDS.
--
-- Wat de webversie op een <canvas> tekent staat hier in Frames: wolken, gras, een spoor en
-- een vliegtuigje. Art.canvas is daar bewust niet voor gebruikt: die rekent alles om naar
-- een vast vak van 280 bij 160 en zet zijn lijnen in pixels van dát vak, terwijl deze lucht
-- met het venster meegroeit en elk beeldje verschuift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Crash = {}

-- Dezelfde getallen als crash.html.
local GROEI = 0.103995
local GRAS = 40          -- GRASS_HEIGHT
local STAPPEN = 50       -- updatePathPoints() tekent de baan in vijftig stukjes
local WOLKEN = 8         -- initClouds()
local SPRIETEN = 48      -- het gras zelf staat per 6 pixels; zoveel Frames is te veel
local HISTORIE = 15      -- state.history.length > 15 -> pop()
local WINSTEN = 20       -- zoveel regels passen er in de feed voordat hij begint te schuiven
local TAFEL = 50         -- de gedeelde tafel haalt er vijftig op (limit=50)

-- main.crash-main: grid-template-rows: auto 1fr auto met gap 14.
local RIJGAT = 14
local BALK_H = 42        -- .history-bar: padding 10 boven en onder om een fiche van 22
local SPELERS_H = 180    -- .players-section max-height
local KOP_H = 30         -- .players-list h3 plus zijn margin-bottom van 10

-- De kleuren die alleen op dit scherm voorkomen; de rest komt uit Theme.
local KLEUR = {
	luchtMidden = Color3.fromHex("8dd0ff"),
	luchtOnder  = Color3.fromHex("b8e4ff"),
	wolkSchaduw = Color3.fromRGB(180, 200, 220),
	grasDiep    = Color3.fromHex("3d7a1f"),
	grasLicht   = Color3.fromHex("7ec045"),
	grasDonker  = Color3.fromHex("5aa030"),
	grasSpriet  = Color3.fromHex("4a8a25"),
	romp        = Color3.fromHex("e63946"),
	rompRand    = Color3.fromHex("8a0e1e"),
	vleugel     = Color3.fromHex("c91e2e"),
	ruit        = Color3.fromHex("87ceeb"),
	ruitRand    = Color3.fromHex("2a5570"),
	tekstRand   = Color3.fromHex("1a4a8a"),   -- -webkit-text-stroke van .multiplier-display
	crashRand   = Color3.fromHex("6a0011"),   -- .multiplier-display.crashed
	crashTekst  = Color3.fromHex("ffdddd"),
	pil         = Color3.fromRGB(10, 30, 60), -- .status-label achtergrond
	vuur        = Color3.fromRGB(255, 140, 50),
	vonk        = Color3.fromRGB(255, 220, 80),
	rook        = Color3.fromRGB(100, 100, 100),
	spoorCrash  = Color3.fromRGB(255, 80, 80),
	rijRand     = Color3.fromRGB(26, 58, 26), -- border-bottom van .player-row
	goudDonker  = Color3.fromHex("cc9900"),   -- .btn-cashout loopt naar dit goud
}

local function multBij(t: number): number
	if t <= 0 then return 1 end
	return math.max(1, math.floor(math.exp(GROEI * t) * 100) / 100)
end

-- ---------- tekenhulpjes ----------
-- Alles in de lucht staat in pixels van de lucht zelf, want de wolken schuiven per pixel
-- en het gras is veertig pixels hoog, hoe breed het venster ook is.
local function rond(ouder: Instance, cx: number, cy: number, r: number, kleur: Color3, doorzicht: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(r * 2, r * 2)
	f.BackgroundColor3 = kleur
	f.BackgroundTransparency = doorzicht or 0
	f.BorderSizePixel = 0
	UI.corner(f, r)
	f.Parent = ouder
	return f
end

-- Een ovaal is in Roblox een rechthoek met de kleinste straal als hoekradius.
local function ovaal(ouder: Instance, cx: number, cy: number, rx: number, ry: number, kleur: Color3, doorzicht: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(rx * 2, ry * 2)
	f.BackgroundColor3 = kleur
	f.BackgroundTransparency = doorzicht or 0
	f.BorderSizePixel = 0
	UI.corner(f, math.min(rx, ry))
	f.Parent = ouder
	return f
end

local function blokje(ouder: Instance, cx: number, cy: number, b: number, h: number, kleur: Color3, hoek: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(b, h)
	f.BackgroundColor3 = kleur
	f.BorderSizePixel = 0
	f.Rotation = hoek or 0
	f.Parent = ouder
	return f
end

-- Een balkje dat als lijnstuk tussen twee punten gelegd wordt: het spoor van het vliegtuig
-- bestaat uit vijftig van deze, elk beeldje opnieuw gelegd.
local function zetLijn(f: Frame, x1: number, y1: number, x2: number, y2: number, dikte: number)
	local dx, dy = x2 - x1, y2 - y1
	local lengte = math.sqrt(dx * dx + dy * dy)
	f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromOffset(math.max(lengte, dikte), dikte)
	f.Rotation = math.deg(math.atan2(dy, dx))
end

-- .panel heeft padding 18. Waar de markup er iets anders bij zet -- de RECENT-balk staat op
-- `padding: 10px 14px` -- verzetten we de UIPadding die UI.panel al maakte, want twee
-- UIPaddings op één vak vechten met elkaar. De haarlijn van .panel::before hangt op diezelfde
-- marge, dus die schuift mee.
local function paneelMarge(paneel: Frame, boven: number, rechts: number, onder: number, links: number)
	local p = paneel:FindFirstChildOfClass("UIPadding")
	if p then
		p.PaddingTop = UDim.new(0, boven)
		p.PaddingRight = UDim.new(0, rechts)
		p.PaddingBottom = UDim.new(0, onder)
		p.PaddingLeft = UDim.new(0, links)
	end
	local lijn = paneel:FindFirstChild("TopLine")
	if lijn and lijn:IsA("Frame") then
		lijn.Position = UDim2.new(0.5, 0, 0, -boven)
		lijn.Size = UDim2.new(1, links + rechts, 0, 1)
	end
end

-- In de CSS is .panel zelf een flexbox. Hier kan dat niet: een UIListLayout op het paneel
-- zet ook de haarlijn in de rij. Vandaar één binnenvak per paneel dat de indeling doet.
local function paneelInhoud(paneel: Frame, gap: number, richting: Enum.FillDirection?): Frame
	local vak = Instance.new("Frame")
	vak.Name = "Body"
	vak.Size = UDim2.fromScale(1, 1)
	vak.BackgroundTransparency = 1
	vak.Parent = paneel
	UI.list(vak, gap, richting)
	return vak
end

-- .history-chip: vier klassen, van rood via wit en goud naar neon.
local function ficheKleur(m: number): (Color3, Color3, number)
	if m < 1.5 then
		return Theme.color.red, Theme.color.red, 0.55       -- rgba(224,97,110,0.45)
	elseif m < 3 then
		return Theme.color.text, Theme.color.border, 0
	elseif m < 10 then
		return Theme.color.gold, Theme.color.gold, 0.5      -- rgba(224,181,85,0.5)
	end
	return Theme.color.neon, Theme.color.neon, 0
end

function Crash.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "CRASH")

	-- Het scherm blijft bestaan als je naar een ander spel gaat; dan hoeft er ook niets
	-- getekend te worden. Het vak van de schil is wat er aan- en uitgezet wordt.
	local scherm: GuiObject? = nil
	local schil = ouder.Parent
	if schil and schil:IsA("GuiObject") then
		scherm = schil
	end

	-- main.crash-main. Het bord van Common centreert zijn kinderen, dus alles gaat in één
	-- vak dat de hele hoogte vult; de drie rijen staan daarbinnen op hun plek.
	local hoofd = Instance.new("Frame")
	hoofd.Name = "CrashMain"
	hoofd.Size = UDim2.fromScale(1, 1)
	hoofd.BackgroundTransparency = 1
	hoofd.Parent = bord

	-- ---------- de RECENT-balk ----------
	local balk = UI.panel(hoofd, "History")
	balk.AutomaticSize = Enum.AutomaticSize.None
	balk.Size = UDim2.new(1, 0, 0, BALK_H)
	paneelMarge(balk, 10, 14, 10, 14)
	local balkVak = paneelInhoud(balk, 6, Enum.FillDirection.Horizontal)
	local balkLijst = balkVak:FindFirstChildOfClass("UIListLayout")
	if balkLijst then
		balkLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	balkVak.ClipsDescendants = true

	local historieKop = UI.label(balkVak, "RECENT", {
		size = Theme.text.small, color = Theme.color.muted,
	})
	historieKop.LayoutOrder = 0
	historieKop.Size = UDim2.fromOffset(52, 20)   -- plus de margin-right van 8 uit de CSS
	historieKop.TextYAlignment = Enum.TextYAlignment.Center

	-- ---------- de lucht ----------
	-- .game-area: verloop van 180 graden van #5fb8ff via #8dd0ff naar #b8e4ff, een neonrand
	-- en radius 4. De box-shadow eronder kent Roblox niet; die is weggelaten.
	local lucht = Instance.new("Frame")
	lucht.Name = "GameArea"
	lucht.Position = UDim2.fromOffset(0, BALK_H + RIJGAT)
	lucht.Size = UDim2.new(1, 0, 1, -(BALK_H + RIJGAT + SPELERS_H + RIJGAT))
	lucht.BackgroundColor3 = Theme.color.sky
	lucht.BorderSizePixel = 0
	lucht.ClipsDescendants = true
	UI.corner(lucht, Theme.radius.panel)
	UI.stroke(lucht, Theme.color.neon)
	lucht.Parent = hoofd

	local luchtVerloop = Instance.new("UIGradient")
	luchtVerloop.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.color.sky),
		ColorSequenceKeypoint.new(0.5, KLEUR.luchtMidden),
		ColorSequenceKeypoint.new(1, KLEUR.luchtOnder),
	})
	luchtVerloop.Rotation = 90
	luchtVerloop.Parent = lucht

	-- de wolken: vier bollen en een schaduw, net als drawCloud()
	type Wolk = { vak: Frame, maat: number, snelheid: number, x: number, y: number }
	local wolken: { Wolk } = {}
	for i = 1, WOLKEN do
		local maat = 30 + math.random() * 50
		local vak = Instance.new("Frame")
		vak.Name = "Cloud"
		vak.Size = UDim2.fromOffset(0, 0)
		vak.BackgroundTransparency = 1
		vak.ZIndex = 1
		vak.Parent = lucht
		rond(vak, 0, 0, maat * 0.5, Theme.color.white, 0.1)
		rond(vak, maat * 0.4, -maat * 0.2, maat * 0.4, Theme.color.white, 0.1)
		rond(vak, maat * 0.8, 0, maat * 0.45, Theme.color.white, 0.1)
		rond(vak, maat * 0.4, maat * 0.1, maat * 0.5, Theme.color.white, 0.1)
		ovaal(vak, maat * 0.4, maat * 0.35, maat * 0.6, maat * 0.15, KLEUR.wolkSchaduw, 0.65)
		wolken[i] = { vak = vak, maat = maat, snelheid = 0.2 + math.random() * 0.4, x = 0, y = 0 }
	end

	-- het gras: een strook van veertig met een lichtere bovenrand van twintig
	local grasvak = Instance.new("Frame")
	grasvak.Name = "Grass"
	grasvak.AnchorPoint = Vector2.new(0, 1)
	grasvak.Position = UDim2.fromScale(0, 1)
	grasvak.Size = UDim2.new(1, 0, 0, GRAS)
	grasvak.BackgroundColor3 = KLEUR.grasDiep
	grasvak.BorderSizePixel = 0
	grasvak.ZIndex = 2
	grasvak.Parent = lucht

	local grasRand = Instance.new("Frame")
	grasRand.Size = UDim2.new(1, 0, 0, 20)
	grasRand.BackgroundColor3 = KLEUR.grasLicht
	grasRand.BorderSizePixel = 0
	grasRand.ZIndex = 2
	grasRand.Parent = grasvak
	UI.gradient(grasRand, KLEUR.grasLicht, KLEUR.grasDonker)

	-- De sprietjes staan in de webversie per zes pixels. Eén Frame per spriet zou er bij een
	-- breed venster honderden zijn, dus ze staan hier op vaste plekken die meerekken.
	for i = 0, SPRIETEN - 1 do
		local deel = i / SPRIETEN
		local h = 4 + (i * 7) % 7
		local spriet = Instance.new("Frame")
		spriet.AnchorPoint = Vector2.new(0.5, 1)
		spriet.Position = UDim2.new(deel, 0, 0, 1)
		spriet.Size = UDim2.fromOffset(2, h)
		spriet.BackgroundColor3 = if i % 3 == 0 then KLEUR.grasSpriet else KLEUR.grasLicht
		spriet.BorderSizePixel = 0
		spriet.Rotation = if i % 2 == 0 then -6 else 5
		spriet.ZIndex = 3
		spriet.Parent = grasvak
	end
	-- de bloemetjes uit drawGrass(): om en om goud en wit
	for i = 0, 7 do
		local bloem = Instance.new("Frame")
		bloem.AnchorPoint = Vector2.new(0.5, 0.5)
		bloem.Position = UDim2.new(i / 8 + 0.06, 0, 0, 8 + (i * 7) % 6)
		bloem.Size = UDim2.fromOffset(4, 4)
		bloem.BackgroundColor3 = if i % 2 == 0 then Theme.color.gold else Theme.color.white
		bloem.BorderSizePixel = 0
		bloem.ZIndex = 3
		UI.corner(bloem, 2)
		bloem.Parent = grasvak
	end

	-- het spoor: drawTrail() trekt één lijn van 6 en daaroverheen een van 2. Twee lagen zou
	-- honderd Frames per beeldje kosten, dus het is er één van vijf dik.
	local spoor: { Frame } = {}
	for i = 1, STAPPEN do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(1, 5)
		f.BackgroundColor3 = Theme.color.white
		f.BackgroundTransparency = 0.15
		f.BorderSizePixel = 0
		f.Visible = false
		f.ZIndex = 4
		UI.corner(f, 2)   -- lineCap: round
		f.Parent = lucht
		spoor[i] = f
	end

	-- het vliegtuigje. De onderdelen staan in de coördinaten van drawPlane(): de neus op
	-- x = 32, de staart op x = -32. Het vak zelf is nul groot, dus draaien draait om de neus
	-- van de curve mee, precies zoals ctx.translate + ctx.rotate.
	local vliegtuig = Instance.new("Frame")
	vliegtuig.Name = "Plane"
	vliegtuig.AnchorPoint = Vector2.new(0.5, 0.5)
	vliegtuig.Size = UDim2.fromOffset(0, 0)
	vliegtuig.BackgroundTransparency = 1
	vliegtuig.ZIndex = 5
	vliegtuig.Visible = false
	vliegtuig.Parent = lucht

	ovaal(vliegtuig, 0, 10, 28, 4, Theme.color.black, 0.88)
	local staartVlak = blokje(vliegtuig, -29, -2, 10, 4, KLEUR.vleugel)
	UI.stroke(staartVlak, KLEUR.rompRand, 2)
	local staart = blokje(vliegtuig, -24, -13, 9, 14, KLEUR.vleugel, -8)
	UI.stroke(staart, KLEUR.rompRand, 2)
	UI.corner(staart, 2)
	local vleugel = blokje(vliegtuig, 4, 12, 16, 12, KLEUR.vleugel, -6)
	UI.stroke(vleugel, KLEUR.rompRand, 2)
	UI.corner(vleugel, 2)
	local romp = blokje(vliegtuig, 0, 0, 64, 16, KLEUR.romp)
	UI.corner(romp, 8)
	UI.stroke(romp, KLEUR.rompRand, 2)
	local ruit = ovaal(vliegtuig, 16, -4, 8, 3.5, KLEUR.ruit)
	ruit.Rotation = -9   -- de -0.15 radialen uit drawPlane()
	UI.stroke(ruit, KLEUR.ruitRand, 1.5)
	for i = 0, 3 do
		rond(vliegtuig, 2 - i * 6, -2, 1.5, KLEUR.ruit)
	end
	local blad1 = blokje(vliegtuig, 33, 0, 2, 12, Theme.color.black)
	blad1.BackgroundTransparency = 0.5
	local blad2 = blokje(vliegtuig, 34, 0, 2, 8, Theme.color.black)
	blad2.BackgroundTransparency = 0.5
	rond(vliegtuig, 33, 0, 2, Color3.fromHex("333333"))

	-- de knal na de crash: drawCrashEffect() in acht Frames
	local knalVak = Instance.new("Frame")
	knalVak.Name = "Boom"
	knalVak.AnchorPoint = Vector2.new(0.5, 0.5)
	knalVak.Size = UDim2.fromOffset(0, 0)
	knalVak.BackgroundTransparency = 1
	knalVak.ZIndex = 6
	knalVak.Visible = false
	knalVak.Parent = lucht
	local vuur = rond(knalVak, 0, 0, 1, KLEUR.vuur, 0.3)
	local vonk = rond(knalVak, 0, 0, 1, KLEUR.vonk, 0.1)
	local rookbollen: { Frame } = {}
	for i = 1, 6 do
		rookbollen[i] = rond(knalVak, 0, 0, 1, KLEUR.rook, 0.5)
	end

	-- ---------- wat er over de lucht heen staat ----------
	-- Een groot wit cijfer met een donkere rand en een schaduw eronder: dat is wat
	-- `-webkit-text-stroke: 2px` en `text-shadow: 0 4px 0 rgba(0,0,0,0.3)` doen. De schaduw
	-- is een tweede label erachter, want text-shadow bestaat hier niet.
	local function witCijfer(ouderVak: Instance, maat: number, randKleur: Color3, volgorde: number): (TextLabel, TextLabel, UIStroke)
		local vak = Instance.new("Frame")
		vak.LayoutOrder = volgorde
		vak.Size = UDim2.new(1, 0, 0, maat + 16)
		vak.BackgroundTransparency = 1
		vak.Parent = ouderVak

		local schaduw = UI.label(vak, "", {
			size = maat, color = Theme.color.black, font = Theme.font.num,
			align = Enum.TextXAlignment.Center,
		})
		schaduw.Position = UDim2.fromOffset(0, 4)
		schaduw.Size = UDim2.fromScale(1, 1)
		schaduw.TextTransparency = 0.7
		schaduw.TextYAlignment = Enum.TextYAlignment.Center

		local tekst = UI.label(vak, "", {
			size = maat, color = Theme.color.white, font = Theme.font.num,
			align = Enum.TextXAlignment.Center,
		})
		tekst.Size = UDim2.fromScale(1, 1)
		tekst.TextYAlignment = Enum.TextYAlignment.Center
		local rand = UI.stroke(tekst, randKleur, 2)
		return tekst, schaduw, rand
	end

	-- .multiplier-display: 96 pixels, midden in de lucht.
	local multVak = Instance.new("Frame")
	multVak.Name = "Multiplier"
	multVak.AnchorPoint = Vector2.new(0.5, 0.5)
	multVak.Position = UDim2.fromScale(0.5, 0.5)
	multVak.Size = UDim2.new(1, 0, 0, 112)
	multVak.BackgroundTransparency = 1
	multVak.ZIndex = 7
	multVak.Visible = false
	multVak.Parent = lucht
	local multTekst, multSchaduw, multRand = witCijfer(multVak, 96, KLEUR.tekstRand, 1)

	-- .status-label: het pilletje 70 pixels onder het midden.
	local statusPil = Instance.new("Frame")
	statusPil.Name = "Status"
	statusPil.AnchorPoint = Vector2.new(0.5, 0.5)
	statusPil.Position = UDim2.new(0.5, 0, 0.5, 70)
	statusPil.Size = UDim2.fromOffset(0, 25)
	statusPil.AutomaticSize = Enum.AutomaticSize.X
	statusPil.BackgroundColor3 = KLEUR.pil
	statusPil.BackgroundTransparency = 0.28   -- rgba(10,30,60,0.72)
	statusPil.BorderSizePixel = 0
	statusPil.ZIndex = 7
	statusPil.Visible = false
	UI.corner(statusPil, 12)
	UI.padding4(statusPil, 0, 12, 0, 12)
	statusPil.Parent = lucht
	local statusTekst = UI.label(statusPil, "", {
		size = Theme.text.label, color = Theme.color.white, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center,
	})
	statusTekst.Size = UDim2.new(0, 0, 1, 0)
	statusTekst.AutomaticSize = Enum.AutomaticSize.X
	statusTekst.ZIndex = 7

	-- .countdown: "NEXT ROUND" met het aantal seconden eronder.
	local aftelVak = Instance.new("Frame")
	aftelVak.Name = "Countdown"
	aftelVak.AnchorPoint = Vector2.new(0.5, 0.5)
	aftelVak.Position = UDim2.fromScale(0.5, 0.5)
	aftelVak.Size = UDim2.new(1, 0, 0, 130)
	aftelVak.BackgroundTransparency = 1
	aftelVak.ZIndex = 7
	aftelVak.Visible = false
	aftelVak.Parent = lucht
	local aftelLijst = UI.list(aftelVak, 12)   -- .countdown-label margin-bottom: 12
	aftelLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	aftelLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	local aftelKop = UI.label(aftelVak, "NEXT ROUND", {
		size = Theme.text.body, color = Theme.color.white, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center,
	})
	aftelKop.ZIndex = 7
	aftelKop.LayoutOrder = 1
	local aftelTekst, aftelSchaduw = witCijfer(aftelVak, 80, KLEUR.tekstRand, 2)

	for _, l in { multTekst, multSchaduw, aftelTekst, aftelSchaduw } do
		l.ZIndex = 7
	end

	-- ---------- de twee lijsten eronder ----------
	local spelersRij = Instance.new("Frame")
	spelersRij.Name = "PlayersSection"
	spelersRij.AnchorPoint = Vector2.new(0, 1)
	spelersRij.Position = UDim2.fromScale(0, 1)
	spelersRij.Size = UDim2.new(1, 0, 0, SPELERS_H)
	spelersRij.BackgroundTransparency = 1
	spelersRij.Parent = hoofd

	-- .players-list h3 .count: neon op een neongroen vlak, met een rand in --border.
	local function telPil(ouderVak: Instance, tekst: string): TextLabel
		local p = UI.tag(ouderVak, tekst)
		p.BackgroundTransparency = Theme.alpha.activeNav   -- rgba(62,207,142,0.10)
		p.AnchorPoint = Vector2.new(1, 0.5)
		p.Position = UDim2.new(1, 0, 0.5, 0)
		local s = p:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = Theme.color.border
			s.Transparency = 0
		end
		return p
	end

	-- .players-list: een paneel met padding 14, een kop, en daaronder een lijst die scrolt.
	local function lijstPaneel(links: boolean, titel: string): (ScrollingFrame, TextLabel)
		local paneel = UI.panel(spelersRij, "PlayersList")
		paneel.AutomaticSize = Enum.AutomaticSize.None
		paneel.Position = if links then UDim2.new() else UDim2.new(0.5, RIJGAT / 2, 0, 0)
		paneel.Size = UDim2.new(0.5, -RIJGAT / 2, 1, 0)
		paneel.ClipsDescendants = true
		paneelMarge(paneel, 14, 14, 14, 14)

		local kop = Instance.new("Frame")
		kop.Name = "Head"
		kop.Size = UDim2.new(1, 0, 0, KOP_H - 10)
		kop.BackgroundTransparency = 1
		kop.Parent = paneel
		local k = UI.label(kop, titel, { size = Theme.text.small, color = Theme.color.muted })
		k.Size = UDim2.new(1, -70, 1, 0)
		k.TextYAlignment = Enum.TextYAlignment.Center
		k.TextTruncate = Enum.TextTruncate.AtEnd
		local telling = telPil(kop, "0")

		local lijst = Instance.new("ScrollingFrame")
		lijst.Name = "Rows"
		lijst.Position = UDim2.fromOffset(0, KOP_H)
		lijst.Size = UDim2.new(1, 0, 1, -KOP_H)
		lijst.BackgroundTransparency = 1
		lijst.BorderSizePixel = 0
		lijst.ScrollBarThickness = 4
		lijst.ScrollBarImageColor3 = Theme.color.border
		lijst.CanvasSize = UDim2.new()
		lijst.AutomaticCanvasSize = Enum.AutomaticSize.Y
		lijst.Parent = paneel
		UI.list(lijst, 0)
		return lijst, telling
	end

	local tafelLijst, tafelTelling = lijstPaneel(true, "YOUR ROUND")
	local winstLijst, winstTelling = lijstPaneel(false, "LIVE WINS \u{00B7} ALL PLAYERS")

	-- De .live-dot zit in de webversie ín het pilletje en knippert. Een stipje kan hier
	-- gewoon links in de pil staan, zolang er links ruimte voor gemaakt wordt.
	winstTelling.Text = "LIVE"
	local winstMarge = winstTelling:FindFirstChildOfClass("UIPadding")
	if winstMarge then
		winstMarge.PaddingLeft = UDim.new(0, 18)
	end
	local levendStip = Instance.new("Frame")
	levendStip.Name = "LiveDot"
	levendStip.AnchorPoint = Vector2.new(0, 0.5)
	levendStip.Position = UDim2.new(0, -13, 0.5, 0)
	levendStip.Size = UDim2.fromOffset(7, 7)
	levendStip.BackgroundColor3 = Theme.color.neon
	levendStip.BorderSizePixel = 0
	UI.corner(levendStip, 4)
	levendStip.Parent = winstTelling

	-- .player-row: naam links, inzet en multiplier rechts, met een streepje eronder.
	type RijOpts = { zelf: boolean?, gecashed: boolean?, verloren: boolean?, meta: string? }
	local function spelerRij(ouderVak: Instance, volgorde: number, naam: string, bedrag: string, mult: string, o: RijOpts)
		local rij = Instance.new("Frame")
		rij.Name = "PlayerRow"
		rij.LayoutOrder = volgorde
		rij.Size = UDim2.new(1, 0, 0, 24)
		rij.BackgroundTransparency = 1
		rij.Parent = ouderVak
		UI.padding4(rij, 0, 4, 0, 4)

		-- .player-row.lost { opacity: 0.4 }: alles in de regel vervaagt mee.
		local vaag = if o.verloren then 0.6 else 0

		local n = UI.label(rij, string.sub(naam, 1, 16), {
			size = Theme.text.tiny,
			color = if o.zelf then Theme.color.neon else Theme.color.text,
			font = if o.zelf then Theme.font.uiBold else Theme.font.ui,
		})
		n.Size = UDim2.new(1, if o.meta then -226 else -150, 1, 0)
		n.TextYAlignment = Enum.TextYAlignment.Center
		n.TextTruncate = Enum.TextTruncate.AtEnd
		-- .player-row .name is 0.85 doorzichtig, tenzij het je eigen regel is
		n.TextTransparency = math.max(vaag, if o.zelf then 0 else 0.15)

		if o.meta then
			local m = UI.label(rij, o.meta, {
				size = Theme.text.tiny, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
			})
			m.AnchorPoint = Vector2.new(1, 0)
			m.Position = UDim2.new(1, -152, 0, 0)
			m.Size = UDim2.fromOffset(70, 24)
			m.TextYAlignment = Enum.TextYAlignment.Center
			m.TextTransparency = vaag
		end

		local b = UI.label(rij, bedrag, {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
			align = Enum.TextXAlignment.Right,
		})
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -72, 0, 0)
		b.Size = UDim2.fromOffset(70, 24)
		b.TextYAlignment = Enum.TextYAlignment.Center
		b.TextTransparency = vaag

		local m = UI.label(rij, mult, {
			size = Theme.text.tiny,
			color = if o.gecashed then Theme.color.neon elseif o.verloren then Theme.color.red else Theme.color.muted,
			font = Theme.font.num,
			align = Enum.TextXAlignment.Right,
		})
		m.AnchorPoint = Vector2.new(1, 0)
		m.Position = UDim2.new(1, 0, 0, 0)
		m.Size = UDim2.fromOffset(60, 24)
		m.TextYAlignment = Enum.TextYAlignment.Center
		m.TextTransparency = vaag

		local streep = Instance.new("Frame")
		streep.AnchorPoint = Vector2.new(0, 1)
		streep.Position = UDim2.fromScale(0, 1)
		streep.Size = UDim2.new(1, 8, 0, 1)
		streep.BackgroundColor3 = KLEUR.rijRand
		streep.BackgroundTransparency = 0.5
		streep.BorderSizePixel = 0
		streep.Parent = rij
	end

	-- De lege lijst krijgt dezelfde regel als in de webversie, in de stijl van .odds-note.
	local function legeRegel(ouderVak: Instance, tekst: string)
		local t = UI.label(ouderVak, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Size = UDim2.new(1, -6, 0, 0)
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.LineHeight = 1.7
	end

	-- ---------- de aside ----------
	-- Eén paneel, precies zoals de markup: het inzetveld met de fiches, de schakelaar voor
	-- automatisch uitstappen, het doelveld dat daarbij hoort, en de knop.
	local betBox = Common.betBox(bediening, 10)
	local zetPaneel = betBox.panel
	-- Common.columns zet de kop op 1 en het saldopaneel op 2. Wat er daarna bij komt heeft
	-- LayoutOrder 0 en zou dus bóven de kop eindigen; vandaar de nummers hier.
	zetPaneel.LayoutOrder = 3
	-- De haarlijn van .panel::before is een gewoon kind, en de UIListLayout van het inzetvak
	-- zet elk kind in de rij. Bovenaan dus, waar de CSS hem ook tekent.
	local haarlijn = zetPaneel:FindFirstChild("TopLine")
	if haarlijn and haarlijn:IsA("Frame") then
		haarlijn.LayoutOrder = -1
	end

	-- .toggle-row: de schakelaar plus zijn etiket, samen aan te klikken.
	local schakelRij = Instance.new("TextButton")
	schakelRij.Name = "ToggleRow"
	schakelRij.LayoutOrder = 1
	schakelRij.Text = ""
	schakelRij.AutoButtonColor = false
	schakelRij.BackgroundTransparency = 1
	schakelRij.Size = UDim2.new(1, 0, 0, 40)   -- 20 hoog met padding 10 boven en onder
	schakelRij.Parent = zetPaneel

	local schakelaar = Instance.new("Frame")
	schakelaar.Name = "Switch"
	schakelaar.AnchorPoint = Vector2.new(0, 0.5)
	schakelaar.Position = UDim2.new(0, 0, 0.5, 0)
	schakelaar.Size = UDim2.fromOffset(38, 20)
	schakelaar.BackgroundColor3 = Theme.color.black
	schakelaar.BackgroundTransparency = Theme.alpha.inputBg
	schakelaar.BorderSizePixel = 0
	UI.corner(schakelaar, 12)
	local schakelRand = UI.stroke(schakelaar)
	schakelaar.Parent = schakelRij

	local knopje = Instance.new("Frame")
	knopje.Name = "Knob"
	knopje.Position = UDim2.fromOffset(2, 2)
	knopje.Size = UDim2.fromOffset(14, 14)
	knopje.BackgroundColor3 = Theme.color.muted
	knopje.BorderSizePixel = 0
	UI.corner(knopje, 7)
	knopje.Parent = schakelaar

	local schakelEtiket = UI.label(schakelRij, "AUTO CASHOUT", {
		size = Theme.text.small, color = Theme.color.muted,
	})
	schakelEtiket.Position = UDim2.fromOffset(48, 0)   -- 38 breed plus de gap van 10
	schakelEtiket.Size = UDim2.new(1, -48, 1, 0)
	schakelEtiket.TextYAlignment = Enum.TextYAlignment.Center

	-- #autoField staat op `opacity: 0.4` tot de schakelaar om gaat. Een CanvasGroup doet
	-- precies dat: alles wat erin staat wordt in één keer doorzichtig.
	local autoVak = Instance.new("CanvasGroup")
	autoVak.Name = "AutoField"
	autoVak.LayoutOrder = 2
	autoVak.Size = UDim2.new(1, 0, 0, 63)
	autoVak.BackgroundTransparency = 1
	autoVak.GroupTransparency = 0.6
	autoVak.Parent = zetPaneel
	UI.list(autoVak, 6)

	local autoKop = Instance.new("Frame")
	autoKop.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	autoKop.BackgroundTransparency = 1
	autoKop.Parent = autoVak
	UI.label(autoKop, "CASH OUT AT", { size = Theme.text.small, color = Theme.color.muted })
	local autoHint = UI.label(autoKop, "\u{00D7}", {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
	})
	autoHint.TextTransparency = 0.3   -- .field-label .hint { opacity: 0.7 }

	local autoVeld = UI.numberBox(autoVak, "2.00")
	autoVeld.TextEditable = false     -- pointer-events: none zolang de schakelaar uit staat

	local knop = UI.primary(zetPaneel, "PLACE BET")
	knop.LayoutOrder = 3
	-- .btn-bet: verloop van 135 graden, neon naar neon-dim. De knop wisselt van kleur met
	-- de fase, net als de klassen btn-bet, btn-cashout en btn-waiting.
	local knopVerloop = UI.gradient(knop, Theme.color.neon, Theme.color.neonDim, 135)
	local knopRand = UI.stroke(knop)
	knopRand.Transparency = 1

	-- ---------- statistieken, kansen en het bewijs ----------
	local statsVak = Common.statsPanel(bediening, "crash")
	statsVak.LayoutOrder = 4
	local oddsVak = Common.oddsPanel(bediening, "odds",
		"RTP 97%. The chance a flight reaches Mx is 0.97 / M. Around 3% of rounds crash straight away at 1.00x. Auto cash-out pays exactly at your target.")
	oddsVak.LayoutOrder = 5

	-- #mpFair: de tweede .odds-note in hetzelfde paneel. In de CSS is "Shared round #n" goud
	-- en de rest grijs; twee kleuren in één regel zou RichText vragen, en dat staat in dit
	-- project uit omdat er spelersnamen langs komen. Dus één kleur.
	local rondeRegel = UI.label(oddsVak, "", { size = Theme.text.tiny, color = Theme.color.muted })
	rondeRegel.TextWrapped = true
	rondeRegel.AutomaticSize = Enum.AutomaticSize.Y
	rondeRegel.Size = UDim2.new(1, 0, 0, 0)
	rondeRegel.TextYAlignment = Enum.TextYAlignment.Top
	rondeRegel.LineHeight = 1.7

	local function fairRegel(): TextLabel
		local t = UI.label(oddsVak, "", { size = 10, color = Theme.color.muted, font = Theme.font.num })
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Size = UDim2.new(1, 0, 0, 0)
		t.TextYAlignment = Enum.TextYAlignment.Top
		return t
	end
	local commitRegel = fairRegel()
	local zaadRegel = fairRegel()
	local puntRegel = fairRegel()

	-- ---------- de stand ----------
	-- Wie er in deze ronde zit leest het scherm uit wat de server stuurt, niet uit een
	-- eigen vlaggetje: dan klopt het ook als je net binnenkwam of even weg was.
	local stand: any = nil
	local mijnNaam = Players.LocalPlayer.DisplayName
	local historie: { number } = {}
	type Winst = { naam: string, bet: number, mult: number, zelf: boolean }
	local winsten: { Winst } = {}
	local gezien: { [string]: boolean } = {}
	local vorigeRonde: number = -1
	local knalMoment = 0
	local autoAan = false
	local autoGeprobeerd = false

	local function autoDoel(): number
		return math.max(1.01, Money.round2(tonumber(autoVeld.Text) or 1.01))
	end

	local function mijnInzet(): any
		if not stand or not stand.bets then return nil end
		for _, b in stand.bets do
			if b.naam == mijnNaam then return b end
		end
		return nil
	end

	-- ---------- de lijsten vullen ----------
	local function wis(vak: Instance)
		for _, k in vak:GetChildren() do
			if k:IsA("GuiObject") then k:Destroy() end
		end
	end

	local function toonSpelers()
		wis(tafelLijst)
		local lijst = if stand and stand.bets then stand.bets else {}
		tafelTelling.Text = string.format("%d", #lijst)
		if #lijst == 0 then
			legeRegel(tafelLijst, "Nobody has bet on this round yet. Be the first.")
			return
		end
		-- De gedeelde tafel in de webversie komt binnen op amount.desc; hier sorteren we
		-- hem zelf, zodat de grootste inzet bovenaan staat.
		table.sort(lijst, function(a, b)
			return a.bet > b.bet
		end)
		local gecrasht = stand.phase == "crashed"
		for i, b in lijst do
			if i > TAFEL then break end
			local verloren = gecrasht and not b.cashed
			local mult = if b.cashed
				then Money.fmt(b.cashed) .. "\u{00D7}"
				elseif verloren then "\u{2715}"
				else "\u{2014}"
			spelerRij(tafelLijst, i, b.naam, "$" .. Money.fmt(b.bet), mult, {
				zelf = b.naam == mijnNaam,
				gecashed = b.cashed ~= nil,
				verloren = verloren,
			})
		end
	end

	-- De feed van de webversie haalt de winst van iedereen op bij de server. Die lijst is er
	-- hier niet; wat wel binnenkomt is elke cashout van deze tafel, en dat is precies wat
	-- eronder hoort te staan. Elke cashout telt één keer mee, per ronde bijgehouden.
	local function toonWinsten()
		wis(winstLijst)
		if #winsten == 0 then
			legeRegel(winstLijst, "No wins yet. Yours will show up here for everyone.")
			return
		end
		for i, w in winsten do
			spelerRij(winstLijst, i, if w.zelf then "YOU" else w.naam,
				"$" .. Money.fmt(w.bet), Money.fmt(w.mult) .. "\u{00D7}", {
					zelf = w.zelf, gecashed = true, meta = "CRASH",
				})
		end
	end

	local function toonHistorie()
		for _, k in balkVak:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		for i, m in historie do
			local tekstKleur, randKleur, randDoorzicht = ficheKleur(m)
			local fiche = Instance.new("Frame")
			fiche.Name = "Chip"
			fiche.LayoutOrder = i
			fiche.Size = UDim2.fromOffset(0, 22)
			fiche.AutomaticSize = Enum.AutomaticSize.X
			fiche.BackgroundColor3 = Theme.color.black
			fiche.BackgroundTransparency = 0.6   -- rgba(0,0,0,0.4)
			fiche.BorderSizePixel = 0
			UI.corner(fiche, 12)
			local s = UI.stroke(fiche, randKleur)
			s.Transparency = randDoorzicht
			UI.padding4(fiche, 0, 10, 0, 10)
			fiche.Parent = balkVak

			local t = UI.label(fiche, Money.fmt(m) .. "\u{00D7}", {
				size = Theme.text.small, color = tekstKleur, font = Theme.font.num,
			})
			t.Size = UDim2.new(0, 0, 1, 0)
			t.AutomaticSize = Enum.AutomaticSize.X
			t.TextYAlignment = Enum.TextYAlignment.Center
		end
	end

	local function toonFairness()
		if not stand or stand.phase == "idle" then
			rondeRegel.Text = ""
			commitRegel.Text = ""
			zaadRegel.Text = ""
			puntRegel.Text = ""
			return
		end
		local kort = function(s: any): string
			local t = tostring(s)
			return if #t > 32 then string.sub(t, 1, 32) .. "\u{2026}" else t
		end
		rondeRegel.Text = string.format(
			"Shared round #%d \u{00B7} the server drew the crash point before betting opened.",
			tonumber(stand.id) or 0)
		commitRegel.Text = "commit " .. (if stand.commit then kort(stand.commit) else "\u{2014}")
		zaadRegel.Text = "seed " .. (if stand.seed then kort(stand.seed) else "revealed when the flight is over")
		puntRegel.Text = if stand.crashAt then "crashed at " .. Money.fmt(stand.crashAt) .. "x" else ""
	end

	-- ---------- de knop ----------
	-- updateButton() uit de webversie, met dezelfde teksten en dezelfde drie jasjes.
	local function zetKnop()
		local fase = if stand then stand.phase else "idle"
		local mijn = mijnInzet()
		local actief = false
		local tekst = "PLACE BET"

		if fase == "waiting" then
			if mijn then
				tekst = "WAITING\u{2026}"
			else
				tekst, actief = "PLACE BET", true
			end
		elseif fase == "flying" then
			if mijn and not mijn.cashed then
				tekst = "CASH OUT $" .. Money.fmt(Money.floor2(mijn.bet * (tonumber(stand.mult) or 1)))
				actief = true
			else
				tekst = if mijn then "CASHED OUT \u{2713}" else "IN FLIGHT"
			end
		elseif fase == "crashed" then
			tekst = "CRASHED"
		else
			tekst = "IN FLIGHT"
		end

		knop.Text = tekst
		knop.Active = actief
		betBox.lock(fase ~= "waiting" or mijn ~= nil)

		if not actief then
			-- .btn-waiting: vlak --panel-light met een rand, plus de opacity 0.6 van :disabled
			knop.BackgroundColor3 = Theme.color.panelLight
			knopVerloop.Color = ColorSequence.new(Theme.color.panelLight)
			knop.BackgroundTransparency = Theme.alpha.disabled
			knop.TextColor3 = Theme.color.muted
			knop.Font = Theme.font.ui
			knopRand.Transparency = 0
		elseif fase == "flying" then
			-- .btn-cashout: goud, en in de webversie pulseert de gloed eromheen
			knop.BackgroundColor3 = Theme.color.gold
			knopVerloop.Color = ColorSequence.new(Theme.color.gold, KLEUR.goudDonker)
			knop.BackgroundTransparency = 0
			knop.TextColor3 = Theme.color.bg
			knop.Font = Theme.font.uiBold
			knopRand.Transparency = 1
		else
			knop.BackgroundColor3 = Theme.color.neon
			knopVerloop.Color = ColorSequence.new(Theme.color.neon, Theme.color.neonDim)
			knop.BackgroundTransparency = 0
			knop.TextColor3 = Theme.color.bg
			knop.Font = Theme.font.uiBold
			knopRand.Transparency = 1
		end
	end

	-- ---------- de schakelaar ----------
	local function zetSchakelaar()
		if autoAan then
			schakelaar.BackgroundColor3 = Theme.color.neon
			schakelaar.BackgroundTransparency = 0.85   -- rgba(62,207,142,0.15)
			schakelRand.Color = Theme.color.neon
			knopje.Position = UDim2.fromOffset(20, 2)
			knopje.BackgroundColor3 = Theme.color.neon
			autoVak.GroupTransparency = 0
			autoVeld.TextEditable = true
		else
			schakelaar.BackgroundColor3 = Theme.color.black
			schakelaar.BackgroundTransparency = Theme.alpha.inputBg
			schakelRand.Color = Theme.color.border
			knopje.Position = UDim2.fromOffset(2, 2)
			knopje.BackgroundColor3 = Theme.color.muted
			autoVak.GroupTransparency = 0.6            -- opacity: 0.4
			autoVeld.TextEditable = false
		end
	end

	schakelRij.Activated:Connect(function()
		autoAan = not autoAan
		zetSchakelaar()
	end)

	autoVeld.FocusLost:Connect(function()
		autoVeld.Text = Money.fmt(autoDoel())
	end)

	-- ---------- de vlucht tekenen ----------
	local baanX: { number } = {}
	local baanY: { number } = {}

	-- updatePathPoints(): dezelfde vensters en schalen als de webversie.
	local function rekenBaan(verstreken: number, mult: number, W: number, H: number)
		local xMax, xMin = W * 0.85, W * 0.08
		local yMax, yMin = H - GRAS - 10, H * 0.12
		local venster = math.max(8, verstreken * 1.1)
		local xSchaal = (xMax - xMin) / venster
		local getoond = math.max(2, mult * 1.3)
		local ySchaal = (yMax - yMin) / math.log(getoond)
		for i = 0, STAPPEN do
			local t = verstreken * i / STAPPEN
			local m = multBij(t)
			baanX[i + 1] = xMin + t * xSchaal
			baanY[i + 1] = yMax - math.log(math.max(1, m)) * ySchaal
		end
	end

	local function tekenSpoor(gecrasht: boolean)
		for i = 1, STAPPEN do
			local f = spoor[i]
			f.Visible = true
			f.BackgroundColor3 = if gecrasht then KLEUR.spoorCrash else Theme.color.white
			zetLijn(f, baanX[i], baanY[i], baanX[i + 1], baanY[i + 1], 5)
		end
	end

	local function wisSpoor()
		for _, f in spoor do
			f.Visible = false
		end
	end

	local function zetVliegtuig(x: number, y: number, hoek: number)
		vliegtuig.Visible = true
		vliegtuig.Position = UDim2.fromOffset(x, y)
		vliegtuig.Rotation = math.deg(hoek)
		-- de propeller: twee bladen die om en om lang en kort zijn
		local fase = os.clock() * 33
		blad1.Size = UDim2.fromOffset(2, (math.abs(math.sin(fase)) * 10 + 2) * 2)
		blad2.Size = UDim2.fromOffset(2, (math.abs(math.cos(fase)) * 10 + 2) * 1.2)
	end

	-- drawCrashEffect(): een oranje bol die uitdijt, een gele kern en zes rookpluimen.
	local function zetKnal(x: number, y: number, t: number)
		knalVak.Visible = true
		knalVak.Position = UDim2.fromOffset(x, y)
		local r = 10 + t * 60
		vuur.Size = UDim2.fromOffset(r * 2, r * 2)
		vuur.BackgroundTransparency = math.clamp(1 - (0.7 - t * 0.5), 0, 1)
		local vc = vuur:FindFirstChildOfClass("UICorner")
		if vc then vc.CornerRadius = UDim.new(0, r) end
		vonk.Size = UDim2.fromOffset(r * 1.2, r * 1.2)
		vonk.BackgroundTransparency = math.clamp(1 - (0.9 - t * 0.7), 0, 1)
		local nc = vonk:FindFirstChildOfClass("UICorner")
		if nc then nc.CornerRadius = UDim.new(0, r * 0.6) end
		for i, bol in rookbollen do
			local a = (i - 1) / 6 * math.pi * 2
			local straal = 8 + t * 8
			bol.Position = UDim2.fromOffset(math.cos(a) * r * 0.9, math.sin(a) * r * 0.9)
			bol.Size = UDim2.fromOffset(straal * 2, straal * 2)
			bol.BackgroundTransparency = math.clamp(1 - (0.5 - t * 0.4), 0, 1)
			local c = bol:FindFirstChildOfClass("UICorner")
			if c then c.CornerRadius = UDim.new(0, straal) end
		end
	end

	-- ---------- de wolken ----------
	local luchtW, luchtH = 0, 0
	local function zaaiWolken()
		for _, w in wolken do
			w.x = math.random() * luchtW * 1.2
			w.y = 30 + math.random() * (luchtH * 0.55)
			w.vak.Position = UDim2.fromOffset(w.x, w.y)
		end
	end

	-- De webversie schuift ze per beeldje op; hier gaat dat maal de tijd sinds het vorige
	-- beeldje, zodat ze op elke beeldsnelheid even hard drijven.
	local function drijf(dt: number)
		for _, w in wolken do
			w.x -= w.snelheid * dt * 60
			if w.x < -w.maat * 3 then
				w.x = luchtW + w.maat * 2
				w.y = 30 + math.random() * (luchtH * 0.55)
			end
			w.vak.Position = UDim2.fromOffset(w.x, w.y)
		end
	end

	-- resizeCanvas() + initClouds(): bij een andere maat opnieuw zaaien.
	local function meetLucht()
		local maat = lucht.AbsoluteSize
		if maat.X <= 0 or maat.Y <= 0 then return end
		if math.abs(maat.X - luchtW) < 1 and math.abs(maat.Y - luchtH) < 1 then return end
		luchtW, luchtH = maat.X, maat.Y
		zaaiWolken()
		-- @media (max-width: 720px) { .multiplier-display { font-size: 64px } }
		local groot = if luchtW < 720 then 64 else 96
		multTekst.TextSize = groot
		multSchaduw.TextSize = groot
	end
	lucht:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetLucht)
	task.defer(meetLucht)

	-- .players-section heeft een max-height van 180, geen vaste hoogte: op een laag venster
	-- krimpt hij mee, zodat er lucht overblijft om in te vliegen.
	local function meetHoofd()
		local h = hoofd.AbsoluteSize.Y
		if h <= 0 then return end
		local spelers = math.clamp(math.floor(h * 0.3), 110, SPELERS_H)
		spelersRij.Size = UDim2.new(1, 0, 0, spelers)
		lucht.Size = UDim2.new(1, 0, 1, -(BALK_H + RIJGAT + spelers + RIJGAT))
	end
	hoofd:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetHoofd)
	task.defer(meetHoofd)

	-- ---------- de overlay ----------
	local function toonMult(m: number, gecrasht: boolean)
		aftelVak.Visible = false
		multVak.Visible = true
		statusPil.Visible = true
		local tekst = Money.fmt(m) .. "\u{00D7}"
		multTekst.Text = tekst
		multSchaduw.Text = tekst
		multRand.Color = if gecrasht then KLEUR.crashRand else KLEUR.tekstRand
		statusTekst.Text = if gecrasht then "\u{25BA} CRASHED" else "\u{25BA} IN THE AIR"
		statusTekst.TextColor3 = if gecrasht then KLEUR.crashTekst else Theme.color.white
	end

	local function toonAftellen(seconden: number)
		multVak.Visible = false
		statusPil.Visible = false
		aftelVak.Visible = true
		local tekst = string.format("%d", math.max(0, math.ceil(seconden)))
		aftelTekst.Text = tekst
		aftelSchaduw.Text = tekst
	end

	-- ---------- een nieuwe stand van de server ----------
	local function nieuweStand(s: any)
		if typeof(s) ~= "table" then return end
		local id = tonumber(s.id) or -1
		if id ~= vorigeRonde then
			vorigeRonde = id
			gezien = {}
			autoGeprobeerd = false
			wisSpoor()
			knalVak.Visible = false
		end

		-- Elke cashout die we nog niet gezien hebben gaat in de feed; per ronde telt een
		-- naam één keer, want de server duwt de hele tafel bij elke verandering opnieuw.
		if typeof(s.bets) == "table" then
			for _, b in s.bets do
				if b.cashed and not gezien[b.naam] then
					gezien[b.naam] = true
					table.insert(winsten, 1, {
						naam = b.naam, bet = b.bet, mult = b.cashed, zelf = b.naam == mijnNaam,
					})
					if #winsten > WINSTEN then table.remove(winsten) end
				end
			end
		end

		-- De RECENT-balk: het crashpunt van elke ronde die voorbij is, nieuwste eerst.
		if s.phase == "crashed" and s.crashAt and not gezien["#crash"] then
			gezien["#crash"] = true
			knalMoment = os.clock()
			table.insert(historie, 1, s.crashAt)
			if #historie > HISTORIE then table.remove(historie) end
			toonHistorie()
		end

		stand = s
		toonSpelers()
		toonWinsten()
		toonFairness()
		zetKnop()
	end

	-- ---------- elke frame ----------
	-- De servertijd is op beide kanten hetzelfde, dus dit loopt gelijk met wat de server
	-- rekent. Staat het scherm niet aan, dan hoeft er ook niets getekend te worden.
	RunService.RenderStepped:Connect(function(dt: number)
		local zichtbaar = scherm == nil or scherm.Visible
		if not zichtbaar or luchtW <= 0 then return end
		drijf(dt)
		-- @keyframes livePulse: van vol naar een kwart en terug, in 1,6 seconden
		levendStip.BackgroundTransparency = 0.375 + 0.375 * math.cos(os.clock() * math.pi * 2 / 1.6)

		if not stand then return end
		local nu = workspace:GetServerTimeNow()
		local fase = stand.phase

		if fase == "waiting" then
			toonAftellen((stand.startsAt or nu) - nu)
			wisSpoor()
			knalVak.Visible = false
			-- drawPlane(W * 0.08, H - GRASS_HEIGHT - 10, -0.15): klaar voor vertrek
			zetVliegtuig(luchtW * 0.08, luchtH - GRAS - 10, -0.15)
			stand.mult = 1
		elseif fase == "flying" then
			local t = nu - (stand.startsAt or nu)
			local m = multBij(t)
			stand.mult = m
			toonMult(m, false)
			rekenBaan(t, m, luchtW, luchtH)
			tekenSpoor(false)
			knalVak.Visible = false
			local hoek = math.atan2(baanY[STAPPEN + 1] - baanY[STAPPEN], baanX[STAPPEN + 1] - baanX[STAPPEN])
			zetVliegtuig(baanX[STAPPEN + 1], baanY[STAPPEN + 1], hoek)

			-- Automatisch uitstappen vraagt de server om af te rekenen zodra het doel gehaald
			-- is -- dezelfde aanroep als de knop. Eén poging per ronde: mislukt hij, dan is de
			-- kans voorbij en moet het scherm niet zestig keer per seconde blijven proberen.
			local mijn = mijnInzet()
			if autoAan and mijn and not mijn.cashed and not autoGeprobeerd and m >= autoDoel() then
				autoGeprobeerd = true
				task.spawn(function()
					local res = Common.call("CashOut", "crash")
					if res then
						Common.toast("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
					end
				end)
			end
			-- de knop telt mee met de multiplier: CASH OUT $12.34
			if mijn and not mijn.cashed then
				knop.Text = "CASH OUT $" .. Money.fmt(Money.floor2(mijn.bet * m))
			end
		elseif fase == "crashed" then
			local c = stand.crashAt or 1
			stand.mult = c
			toonMult(c, true)
			rekenBaan((stand.endsAt or nu) - (stand.startsAt or nu), c, luchtW, luchtH)
			tekenSpoor(true)
			-- Na de knal valt het toestel omlaag en draait het op zijn kop, net als in render().
			local sinds = os.clock() - knalMoment
			local x, y = baanX[STAPPEN + 1], baanY[STAPPEN + 1]
			zetKnal(x, y, math.min(1, sinds / 0.6))
			zetVliegtuig(x, y + math.min(80, sinds * 125), math.pi / 2 + math.min(0.5, sinds))
		else
			-- "idle": er loopt geen ronde. Dan staat er ook niets in de lucht.
			multVak.Visible = false
			statusPil.Visible = false
			aftelVak.Visible = false
			knalVak.Visible = false
			vliegtuig.Visible = false
			wisSpoor()
		end
	end)

	knop.Activated:Connect(function()
		if not stand or not knop.Active then return end
		if stand.phase == "waiting" then
			if Common.call("Bet", "crash", betBox.get()) then
				Common.toast("BET PLACED", "green")
			end
		elseif stand.phase == "flying" then
			local res = Common.call("CashOut", "crash")
			if res then
				Common.toast("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			end
		end
		zetKnop()
	end)

	-- De server duwt elke faseverandering; bij binnenkomst één keer zelf vragen.
	Net.ev("Round").OnClientEvent:Connect(function(s: any)
		if typeof(s) == "table" and s.game == "crash" then
			nieuweStand(s)
		end
	end)

	task.spawn(function()
		local ok, res = pcall(function()
			return Net.fn("RoundState"):InvokeServer("crash")
		end)
		if ok then nieuweStand(res) end
	end)

	toonSpelers()
	toonWinsten()
	toonFairness()
	zetSchakelaar()
	zetKnop()
end

return Crash
]],
	["Friends"] = [[
--!strict
-- Vrienden en tafels. Je vrienden komen van Roblox zelf, want die kent ze al; wie er nu
-- meespeelt staat bovenaan. Een privétafel is een eigen server waar je mensen bij haalt,
-- en quick play zet je terug aan de publieke tafel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Common = require(script.Parent.Common)

local Friends = {}

function Friends.build(ouder: Instance): ()
	local links, rechts = Common.columns(ouder, "FRIENDS")

	-- ---------- de lijst ----------
	local lijstVak = UI.panel(links, "Friends")
	UI.list(lijstVak, 4)
	local lijstTitel = UI.label(lijstVak, "\u{25BA} FRIENDS", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
	})

	local lijst = Instance.new("Frame")
	lijst.Size = UDim2.new(1, 0, 0, 0)
	lijst.AutomaticSize = Enum.AutomaticSize.Y
	lijst.BackgroundTransparency = 1
	lijst.Parent = lijstVak
	UI.list(lijst, 3)

	local leeg = UI.label(lijst, "Nog niemand opgehaald.", {
		size = Theme.text.small, color = Theme.color.muted,
	})

	-- ---------- wie er nu aan tafel zit ----------
	local tafelVak = UI.panel(links, "AtTable")
	UI.list(tafelVak, 4)
	UI.panelTitle(tafelVak, "at this table")
	local tafelLijst = Instance.new("Frame")
	tafelLijst.Size = UDim2.new(1, 0, 0, 0)
	tafelLijst.AutomaticSize = Enum.AutomaticSize.Y
	tafelLijst.BackgroundTransparency = 1
	tafelLijst.Parent = tafelVak
	UI.list(tafelLijst, 2)

	-- ---------- de knoppen ----------
	local uitleg = UI.panel(rechts, "Explain")
	UI.list(uitleg, 4)
	UI.panelTitle(uitleg, "tables")
	local tekst = UI.label(uitleg, "Een privétafel is een eigen server: alleen wie jij erbij haalt speelt mee, aan dezelfde crashronde en dezelfde blackjacktafel. Quick play zet je terug aan de publieke tafel.", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	tekst.TextWrapped = true
	tekst.Size = UDim2.new(1, 0, 0, 64)

	local prive = UI.primary(rechts, "PRIVATE TABLE")
	local nodig = UI.secondary(rechts, "INVITE FRIENDS")
	nodig.Size = UDim2.new(1, 0, 0, 40)
	local snel = UI.secondary(rechts, "QUICK PLAY")
	snel.Size = UDim2.new(1, 0, 0, 40)
	local ververs = UI.secondary(rechts, "REFRESH")
	ververs.Size = UDim2.new(1, 0, 0, 32)

	local codeVak = UI.panel(rechts, "Code")
	UI.list(codeVak, 4)
	UI.panelTitle(codeVak, "your table")
	local codeLabel = UI.label(codeVak, "geen privétafel open", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	codeLabel.TextWrapped = true
	codeLabel.Size = UDim2.new(1, 0, 0, 30)

	-- ---------- vullen ----------
	local function rijVoor(ouderVak: Instance, naam: string, erbij: boolean): TextLabel
		local rij = Common.statRow(ouderVak, naam, if erbij then "AT THE TABLE" else "ELSEWHERE")
		rij.TextColor3 = if erbij then Theme.color.neon else Theme.color.muted
		return rij
	end

	local function vul()
		local res = Common.call("Friends", "list")
		if not res then return end

		for _, k in lijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		local n = 0
		local hier = 0
		for _, v in res.friends do
			n += 1
			if v.here then hier += 1 end
			rijVoor(lijst, v.displayName, v.here)
		end
		leeg.Visible = n == 0
		leeg.Text = if n == 0
			then "Geen vrienden gevonden. Roblox geeft die lijst alleen vrij als je hem gedeeld hebt."
			else ""
		lijstTitel.Text = "\u{25BA} FRIENDS \u{00B7} " .. hier .. " / " .. n .. " HERE"

		for _, k in tafelLijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		for _, p in res.here do
			local rij = Common.statRow(tafelLijst, p.displayName,
				if p.userId == Players.LocalPlayer.UserId then "YOU" else "")
			rij.TextColor3 = Theme.color.muted
		end
	end

	ververs.Activated:Connect(vul)

	prive.Activated:Connect(function()
		local res = Common.call("Friends", "reserve")
		if not res then return end
		codeLabel.Text = "Tafel klaar. Je wordt er nu naartoe gebracht; nodig daarna je vrienden uit."
		codeLabel.TextColor3 = Theme.color.neon
		Common.toast("OPENING YOUR TABLE", "green")
		task.wait(1)
		Common.call("Friends", "join")
	end)

	-- De uitnodiging is die van Roblox zelf: wie je aantikt komt in jouw server terecht.
	nodig.Activated:Connect(function()
		local ok, kan = pcall(function()
			return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
		end)
		if not ok or not kan then
			Common.toast("INVITES ARE NOT AVAILABLE HERE", "red")
			return
		end
		pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
	end)

	snel.Activated:Connect(function()
		Common.toast("BACK TO THE PUBLIC TABLE", nil)
		Common.call("Friends", "quick")
	end)

	task.spawn(function()
		while true do
			vul()
			task.wait(20)
		end
	end)
end

return Friends
]],
	["Home"] = [[
--!strict
-- De lobby, zoals #homeView in de webversie: rechtsboven de twee chips naar profiel en VIP,
-- daaronder de hero van 64 pixels, de saldokaart met neonrand, en dan het raster met
-- speltegels.
--
-- De previews zijn geen plaatjes maar verlopen, precies de `.preview-*` klassen uit de CSS.
-- Daardoor hoeft er niets geüpload te worden voordat het er goed uitziet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Art = require(script.Parent.Art)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Home = {}

export type Kaart = {
	id: string,
	label: string,
	desc: string,
	rtp: string,
	van: Color3,
	tot: Color3,
	rotatie: number?,
}

-- De kleuren komen uit de `preview-*` klassen van de CSS.
local KAARTEN: { Kaart } = {
	{ id = "crash", label = "CRASH", rtp = "97% RTP",
	  desc = "Ride along and cash out before it crashes. Multipliers up to 1000x.",
	  van = Color3.fromHex("5fb8ff"), tot = Color3.fromHex("4a8a2a") },
	{ id = "roulette", label = "ROULETTE", rtp = "97.3% RTP",
	  desc = "European roulette with a single green zero.",
	  van = Color3.fromHex("2a1010"), tot = Color3.fromHex("0a0505") },
	{ id = "tower", label = "DRAGON TOWER", rtp = "97% RTP",
	  desc = "Climb nine floors, dodge the dragon eggs.",
	  van = Color3.fromHex("2a0a3a"), tot = Color3.fromHex("0a0510") },
	{ id = "mines", label = "MINES", rtp = "97% RTP",
	  desc = "Collect diamonds, dodge the mines.",
	  van = Color3.fromHex("1a1a2a"), tot = Color3.fromHex("0a0a14"), rotatie = 135 },
	{ id = "plinko", label = "PLINKO", rtp = "97% RTP",
	  desc = "Drop a ball and watch where it lands.",
	  van = Color3.fromHex("1a0a2a"), tot = Color3.fromHex("0a0518") },
	{ id = "blackjack", label = "BLACKJACK", rtp = "99% RTP",
	  desc = "Six decks, dealer stands on all 17s.",
	  van = Color3.fromHex("0a3a1a"), tot = Color3.fromHex("051a0a") },
	{ id = "scratch", label = "SCRATCH CARDS", rtp = "97% RTP",
	  desc = "Nine squares, three of a kind pays.",
	  van = Color3.fromHex("1f4a4a"), tot = Color3.fromHex("0c1f1f") },
	{ id = "wheel", label = "WHEEL", rtp = "97% RTP",
	  desc = "Twenty segments, one pays ten times.",
	  van = Color3.fromHex("4a3a12"), tot = Color3.fromHex("1e1707") },
	{ id = "horse", label = "HORSE RACE", rtp = "97% RTP",
	  desc = "Six horses, back the one you fancy.",
	  van = Color3.fromHex("2f5a1a"), tot = Color3.fromHex("13260b") },
}

-- .game-card: radius 6, preview van 160 met een rand eronder, body met padding 18, en
-- onderin een pilletje plus een pijl die bij hover naar rechts schuift.
local function tegel(ouder: Instance, k: Kaart, ga: (string) -> ()): Frame
	local f = Instance.new("Frame")
	f.Name = k.id
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	UI.gradient(f, Theme.color.panel, Theme.color.panelLight)
	UI.corner(f, Theme.radius.card)
	local rand = UI.stroke(f)
	f.Parent = ouder

	-- De preview is een getekende scène, zoals de SVG in de webversie. Een egaal verloop
	-- zag er naast het origineel uit als een lege doos.
	local teken = Art.BY_ID[k.id]
	local beeld: Frame
	if teken then
		teken(f)
		beeld = f:FindFirstChild("Art") :: Frame
	else
		beeld = Instance.new("Frame")
		beeld.Name = "Preview"
		beeld.Size = UDim2.new(1, 0, 0, Theme.size.cardPreview)
		beeld.BackgroundColor3 = k.van
		beeld.BorderSizePixel = 0
		beeld.Parent = f
		UI.gradient(beeld, k.van, k.tot, k.rotatie or 90)
	end

	local onderRand = Instance.new("Frame")
	onderRand.AnchorPoint = Vector2.new(0, 1)
	onderRand.Position = UDim2.fromScale(0, 1)
	onderRand.Size = UDim2.new(1, 0, 0, 1)
	onderRand.BackgroundColor3 = Theme.color.border
	onderRand.BorderSizePixel = 0
	onderRand.ZIndex = 2
	onderRand.Parent = beeld

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, Theme.size.cardPreview)
	body.Size = UDim2.new(1, 0, 1, -Theme.size.cardPreview)
	body.BackgroundTransparency = 1
	body.Parent = f
	UI.padding(body, Theme.size.panelPad)
	UI.list(body, 6)

	local titel = UI.label(body, k.label, {
		size = Theme.text.card, color = Theme.color.neon, font = Theme.font.uiMed,
	})
	titel.Size = UDim2.new(1, 0, 0, Theme.text.card + 6)

	local d = UI.label(body, k.desc, { size = Theme.text.tiny, color = Theme.color.muted })
	d.TextWrapped = true
	d.Size = UDim2.new(1, 0, 0, 34)
	d.TextYAlignment = Enum.TextYAlignment.Top

	-- .game-card-footer
	local voet = Instance.new("Frame")
	voet.Size = UDim2.new(1, 0, 0, 22)
	voet.BackgroundTransparency = 1
	voet.Parent = body

	UI.tag(voet, k.rtp, Theme.color.neon)

	local pijl = UI.label(voet, "\u{2192}", {
		size = Theme.text.card, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
	})
	pijl.AnchorPoint = Vector2.new(1, 0.5)
	pijl.Position = UDim2.new(1, 0, 0.5, 0)
	pijl.Size = UDim2.fromOffset(24, 22)

	local knop = Instance.new("TextButton")
	knop.Text = ""
	knop.BackgroundTransparency = 1
	knop.Size = UDim2.fromScale(1, 1)
	knop.ZIndex = 3
	knop.Parent = f
	knop.Activated:Connect(function()
		ga(k.id)
	end)
	-- .game-card.available:hover: de rand wordt neon en de pijl schuift op.
	knop.MouseEnter:Connect(function()
		rand.Color = Theme.color.neon
		pijl.TextColor3 = Theme.color.neon
		pijl.Position = UDim2.new(1, 4, 0.5, 0)
	end)
	knop.MouseLeave:Connect(function()
		rand.Color = Theme.color.border
		pijl.TextColor3 = Theme.color.muted
		pijl.Position = UDim2.new(1, 0, 0.5, 0)
	end)
	return f
end

-- Een chip in de topbar: .home-chip.
local function topChip(ouder: Instance, tekst: string, ga: () -> (), goud: boolean?): (TextButton, TextLabel)
	local b = Instance.new("TextButton")
	b.Name = "HomeChip"
	b.Text = tekst
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = if goud then Theme.color.gold else Theme.color.text
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 32)
	b.RichText = false
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b, if goud then Theme.color.gold else Theme.color.border)
	UI.padding4(b, 0, 14, 0, 14)
	b.Parent = ouder

	local slotje = UI.label(b, "\u{1F512}", { size = Theme.text.tiny, align = Enum.TextXAlignment.Right })
	slotje.AnchorPoint = Vector2.new(0, 0.5)
	slotje.Position = UDim2.new(1, 2, 0.5, 0)
	slotje.Size = UDim2.fromOffset(16, 16)
	slotje.Visible = false

	b.Activated:Connect(ga)
	b.MouseEnter:Connect(function()
		rand.Color = Theme.color.neon
	end)
	b.MouseLeave:Connect(function()
		rand.Color = if goud then Theme.color.gold else Theme.color.border
	end)
	return b, slotje
end

-- Bouwt het scherm en geeft terug hoe je het saldo bijwerkt.
function Home.build(ouder: Instance, ga: (string) -> ()): (number) -> ()
	local blad = Instance.new("ScrollingFrame")
	blad.Size = UDim2.fromScale(1, 1)
	blad.BackgroundTransparency = 1
	blad.BorderSizePixel = 0
	blad.ScrollBarThickness = 4
	blad.ScrollBarImageColor3 = Theme.color.border
	blad.CanvasSize = UDim2.new()
	blad.AutomaticCanvasSize = Enum.AutomaticSize.Y
	blad.Parent = ouder
	-- #homeView heeft padding 40/50; de marge van 40 zit al in de schil, dus hier alleen
	-- de extra breedte naar links en rechts.
	UI.padding4(blad, 0, Theme.size.homePadX - Theme.size.homePadY, 24, Theme.size.homePadX - Theme.size.homePadY)
	UI.list(blad, 18)

	-- ---------- .home-topbar ----------
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 32)
	topbar.BackgroundTransparency = 1
	topbar.LayoutOrder = 1
	topbar.Parent = blad
	local topLijst = UI.list(topbar, 10, Enum.FillDirection.Horizontal)
	topLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right
	topLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	topChip(topbar, "PROFILE", function()
		ga("profile")
	end).LayoutOrder = 1
	local vipChip, vipSlot = topChip(topbar, "VIP ZONE", function()
		ga("vip")
	end, true)
	vipChip.LayoutOrder = 2
	vipSlot.Visible = true

	-- ---------- .home-hero ----------
	local hero = Instance.new("Frame")
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.BackgroundTransparency = 1
	hero.LayoutOrder = 2
	hero.Parent = blad
	UI.list(hero, 12)

	local kop = UI.label(hero, "NEON CASINO", {
		size = Theme.text.hero, color = Theme.color.neon, font = Theme.font.uiMed,
	})
	kop.Size = UDim2.new(1, 0, 0, Theme.text.hero + 6)

	UI.label(hero, "\u{25BA} FAIR ODDS \u{00B7} PLAY MONEY ONLY", {
		size = Theme.text.body, color = Theme.color.muted,
	})

	-- ---------- .home-balance-card ----------
	local saldoKaart = Instance.new("Frame")
	saldoKaart.Name = "BalanceCard"
	saldoKaart.Size = UDim2.fromOffset(320, 0)
	saldoKaart.AutomaticSize = Enum.AutomaticSize.Y
	saldoKaart.BackgroundColor3 = Theme.color.panel
	saldoKaart.BorderSizePixel = 0
	saldoKaart.LayoutOrder = 3
	UI.gradient(saldoKaart, Theme.color.panel, Theme.color.panelLight, 135)
	UI.corner(saldoKaart, Theme.radius.panel)
	UI.stroke(saldoKaart, Theme.color.neon)
	UI.padding4(saldoKaart, 24, 32, 24, 32)
	UI.list(saldoKaart, 6)
	saldoKaart.Parent = blad

	UI.label(saldoKaart, "YOUR BALANCE", { size = Theme.text.small, color = Theme.color.muted })
	local bedrag = UI.moneyLabel(saldoKaart, Money.fmt(Money.START), Theme.text.balanceL)

	-- ---------- .section-heading + .games-grid ----------
	local kopRij = Instance.new("Frame")
	kopRij.Size = UDim2.new(1, 0, 0, 34)
	kopRij.BackgroundTransparency = 1
	kopRij.LayoutOrder = 4
	kopRij.Parent = blad
	UI.sectionHeading(kopRij, "AVAILABLE GAMES", #KAARTEN .. " LIVE")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.LayoutOrder = 5
	raster.Parent = blad
	local rasterLayout = Instance.new("UIGridLayout")
	rasterLayout.CellSize = UDim2.fromOffset(Theme.size.cardMin, 300)
	rasterLayout.CellPadding = UDim2.fromOffset(Theme.size.cardGap, Theme.size.cardGap)
	rasterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rasterLayout.Parent = raster

	for i, k in KAARTEN do
		tegel(raster, k, ga).LayoutOrder = i
	end

	-- ---------- .season-strip ----------
	-- De aftelklok van de sprint, met rechts wat elke plek oplevert.
	local strip = UI.panel(blad, "Season")
	strip.LayoutOrder = 6
	UI.list(strip, 4)
	local sprintKop = UI.label(strip, "SPRINT 1 OF 4", {
		size = Theme.text.small, color = Theme.color.muted,
	})
	local klok = UI.label(strip, "\u{2014}", {
		size = 30, color = Theme.color.neon, font = Theme.font.num,
	})
	klok.Size = UDim2.new(1, 0, 0, 38)
	UI.label(strip, "until the standings reset to zero \u{00B7} whoever gains the most takes the title and a VIP pass", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	local regel2 = UI.label(strip, "\u{2014}", { size = Theme.text.tiny, color = Theme.color.muted })

	local prijzen = Instance.new("Frame")
	prijzen.AnchorPoint = Vector2.new(1, 0)
	prijzen.Position = UDim2.new(1, 0, 0, 6)
	prijzen.Size = UDim2.fromOffset(460, 26)
	prijzen.BackgroundTransparency = 1
	prijzen.Parent = strip
	local prijsLijst = UI.list(prijzen, 8, Enum.FillDirection.Horizontal)
	prijsLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right
	prijsLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	type Prijs = { naam: string, wat: string, kleur: Color3 }
	local PRIJZEN: { Prijs } = {
		{ naam = "\u{265B} House Boss", wat = "VIP PASS + TITLE", kleur = Theme.color.gold },
		{ naam = "\u{1F396} Challenger", wat = "TITLE", kleur = Theme.color.text },
		{ naam = "\u{1F396} Podium", wat = "TITLE", kleur = Theme.color.gold },
	}
	for i, pr in PRIJZEN do
		local vak = Instance.new("Frame")
		vak.LayoutOrder = i
		vak.Size = UDim2.fromOffset(0, 26)
		vak.AutomaticSize = Enum.AutomaticSize.X
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = Theme.alpha.buttonBg
		vak.BorderSizePixel = 0
		UI.corner(vak, Theme.radius.button)
		UI.stroke(vak)
		UI.padding4(vak, 0, 10, 0, 10)
		local rij = UI.list(vak, 6, Enum.FillDirection.Horizontal)
		rij.VerticalAlignment = Enum.VerticalAlignment.Center
		vak.Parent = prijzen

		local naam = UI.label(vak, pr.naam, { size = Theme.text.tiny, color = pr.kleur })
		naam.AutomaticSize = Enum.AutomaticSize.X
		naam.Size = UDim2.new(0, 0, 1, 0)
		naam.LayoutOrder = 1
		local wat = UI.label(vak, pr.wat, {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
		})
		wat.AutomaticSize = Enum.AutomaticSize.X
		wat.Size = UDim2.new(0, 0, 1, 0)
		wat.LayoutOrder = 2
	end

	-- ---------- LIVE LEADERBOARD ----------
	local lbKop = Instance.new("Frame")
	lbKop.Size = UDim2.new(1, 0, 0, 34)
	lbKop.BackgroundTransparency = 1
	lbKop.LayoutOrder = 7
	lbKop.Parent = blad
	local _, lbTelling = UI.sectionHeading(lbKop, "LIVE LEADERBOARD", "\u{25CF} 1 ACTIVE")
	lbTelling.TextColor3 = Theme.color.neon

	local lbRij = Instance.new("Frame")
	lbRij.Size = UDim2.new(1, 0, 0, 0)
	lbRij.AutomaticSize = Enum.AutomaticSize.Y
	lbRij.BackgroundTransparency = 1
	lbRij.LayoutOrder = 8
	lbRij.Parent = blad
	local lbLijst = UI.list(lbRij, 14, Enum.FillDirection.Horizontal)
	lbLijst.VerticalAlignment = Enum.VerticalAlignment.Top

	type Kolom = { vak: Frame, lijst: Frame, leeg: TextLabel }
	local kolommen: { [string]: Kolom } = {}
	local KOLOMMEN = {
		{ id = "money", kop = "MOST MONEY", sub = "TOP 10" },
		{ id = "ratio", kop = "WIN / LOSS RATIO", sub = "TOP 10 \u{00B7} MIN. 10 ROUNDS" },
		{ id = "sprint", kop = "SPRINT PROFIT", sub = "TITLE AND A VIP PASS" },
	}
	for i, kol in KOLOMMEN do
		local vak = UI.panel(lbRij, kol.id)
		vak.LayoutOrder = i
		vak.Size = UDim2.new(1 / 3, -10, 0, 0)
		UI.list(vak, 4)
		local kopRegel = Instance.new("Frame")
		kopRegel.Size = UDim2.new(1, 0, 0, 18)
		kopRegel.BackgroundTransparency = 1
		kopRegel.Parent = vak
		UI.label(kopRegel, "\u{25BA} " .. kol.kop, {
			size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
		})
		UI.label(kopRegel, kol.sub, {
			size = Theme.text.tiny, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
		})
		local lijst = Instance.new("Frame")
		lijst.Size = UDim2.new(1, 0, 0, 0)
		lijst.AutomaticSize = Enum.AutomaticSize.Y
		lijst.BackgroundTransparency = 1
		lijst.Parent = vak
		UI.list(lijst, 3)
		local leeg = UI.label(lijst, "Nog niemand op de lijst.", {
			size = Theme.text.tiny, color = Theme.color.muted,
		})
		kolommen[kol.id] = { vak = vak, lijst = lijst, leeg = leeg }
	end

	-- ---------- ODDS & FAIRNESS ----------
	local oddsKop = Instance.new("Frame")
	oddsKop.Size = UDim2.new(1, 0, 0, 34)
	oddsKop.BackgroundTransparency = 1
	oddsKop.LayoutOrder = 9
	oddsKop.Parent = blad
	UI.sectionHeading(oddsKop, "ODDS & FAIRNESS", "EVERY MODE CHECKED")

	local oddsVak = UI.panel(blad, "Fairness")
	oddsVak.LayoutOrder = 10
	UI.list(oddsVak, 2)

	type OddsRij = { spel: string, rtp: string, huis: string, uitleg: string, kop: boolean? }
	local RIJEN: { OddsRij } = {
		{ spel = "GAME", rtp = "RTP", huis = "HOUSE", uitleg = "HOW IT WORKS", kop = true },
		{ spel = "CRASH", rtp = "97.0%", huis = "3.0%", uitleg = "The chance a flight reaches multiplier M = 0.97 / M. Every cash-out strategy has the same expectation." },
		{ spel = "ROULETTE", rtp = "97.3%", huis = "2.7%", uitleg = "European wheel with 37 pockets. Straight 35:1, dozen/column 2:1, red/black 1:1." },
		{ spel = "DRAGON TOWER", rtp = "97.0%", huis = "3.0%", uitleg = "Multiplier per floor = 0.97 x (tiles / safe tiles)^level." },
		{ spel = "MINES", rtp = "97.0%", huis = "3.0%", uitleg = "Multiplier = 0.97 x the inverse chance of finding k safe tiles in a row." },
		{ spel = "PLINKO", rtp = "97.0%", huis = "3.0%", uitleg = "Every row is a 50/50 left or right. The payout table per risk level is normalised to 97%." },
		{ spel = "SCRATCH CARDS", rtp = "97.0%", huis = "3.0%", uitleg = "Nine cells, three matching pay 1.25x to 50x. The card is fixed when you buy it; 21.6% of them pay." },
		{ spel = "HORSE RACE", rtp = "97.0%", huis = "3.0%", uitleg = "Every horse has a fixed win chance; payout = 0.97 / that chance. The finishing order is drawn before the start." },
		{ spel = "BLACKJACK", rtp = "~99%", huis = "~1%", uitleg = "6 decks, continuously shuffled, dealer stands on all 17s, blackjack 3:2, double on any two cards, no split." },
		{ spel = "WHEEL", rtp = "97.0%", huis = "3.0%", uitleg = "Twenty equal segments paying 19.4x between them: 19.4 / 20 = 0.97." },
		{ spel = "777 \u{00B7} VIP", rtp = "97.0%", huis = "3.0%", uitleg = "Three reels. Three of a kind pay 3x to 40x, two cherries 1.5x. 17% of spins pay." },
		{ spel = "RIDE THE BUS \u{00B7} VIP", rtp = "97.0%", huis = "3.0%", uitleg = "Every multiplier is 0.97 divided by the chance of getting that far, counted off the cards still in the deck." },
	}
	for i, r in RIJEN do
		local rij = Instance.new("Frame")
		rij.Size = UDim2.new(1, 0, 0, 22)
		rij.BackgroundTransparency = 1
		rij.LayoutOrder = i
		rij.Parent = oddsVak
		local isKop = r.kop == true
		local kleur = if isKop then Theme.color.muted else Theme.color.text
		local function cel(tekst: string, x: number, breed: number, c: Color3, font: Enum.Font?)
			local t = UI.label(rij, tekst, {
				size = Theme.text.tiny, color = c, font = font or Theme.font.ui,
			})
			t.Position = UDim2.new(x, 0, 0, 0)
			t.Size = UDim2.new(breed, -8, 1, 0)
			t.TextTruncate = Enum.TextTruncate.AtEnd
			return t
		end
		cel(r.spel, 0, 0.17, kleur, if isKop then Theme.font.ui else Theme.font.uiMed)
		cel(r.rtp, 0.17, 0.07, if isKop then Theme.color.muted else Theme.color.neon, Theme.font.num)
		cel(r.huis, 0.24, 0.07, if isKop then Theme.color.muted else Theme.color.gold, Theme.font.num)
		cel(r.uitleg, 0.31, 0.69, Theme.color.muted)
	end

	-- ---------- de klok en de ranglijst bijhouden ----------
	local function vulLeaderboard()
		local res = Common.call("Leaderboard")
		if not res then return end
		sprintKop.Text = string.upper(res.label)
		klok.Text = Season.countdown(res.endsAt, res.now)
		regel2.Text = "SEASON ENDS IN " .. Season.countdown(res.seasonEndsAt, res.now)
			.. " \u{00B7} " .. res.sprintsLeft .. " SPRINTS LEFT TO EARN A PASS"

		for _, kol in kolommen do
			for _, k in kol.lijst:GetChildren() do
				if k:IsA("Frame") then k:Destroy() end
			end
			kol.leeg.Visible = #res.top == 0
		end
		for _, plek in res.top do
			local naam = "#" .. plek.rank .. "  " .. plek.name
			local a = Common.statRow(kolommen.sprint.lijst, naam,
				(if plek.profit >= 0 then "+$" else "-$") .. Money.fmt(math.abs(plek.profit)))
			a.TextColor3 = if plek.profit >= 0 then Theme.color.neon else Theme.color.red
			local b = Common.statRow(kolommen.money.lijst, naam, "\u{2014}")
			b.TextColor3 = Theme.color.muted
		end
	end

	task.spawn(function()
		while true do
			vulLeaderboard()
			task.wait(30)
		end
	end)

	return function(nieuw: number)
		bedrag.Text = Money.fmt(nieuw)
	end
end

return Home
]],
	["Horse"] = [[
--!strict
-- Paardenrace: zes banen, zes paarden, en een race waarin je pas op het eind ziet wie er
-- wint. De uitslag staat vanaf de eerste tel vast -- die komt van de server -- maar het
-- tempo per paard verschilt en er zit een golf in de looplijn, zodat de kop wisselt.
-- Zonder dat zag je meteen welk paard ging winnen, en dat haalde de spanning eruit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Horse = {}

type Loop = {
	pace: number,   -- hoe een paard zijn tempo verdeelt: laag = snelle start, hoog = eindsprint
	amp: number,    -- hoe ver hij van de zuivere lijn afwijkt
	freq: number,
	fase: number,
	eind: number,   -- wanneer hij over de streep is
}

function Horse.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "HORSE RACE")

	local baan = UI.panel(bord, "Track")
	UI.list(baan, 8)
	UI.panelTitle(baan, "the field")

	local veld = Instance.new("Frame")
	veld.Size = UDim2.new(1, 0, 0, 0)
	veld.AutomaticSize = Enum.AutomaticSize.Y
	veld.BackgroundTransparency = 1
	veld.Parent = baan
	UI.list(veld, 6)

	local balk = Common.banner(baan)
	balk.set("PICK A HORSE", nil)

	local lopers: { Frame } = {}
	local naamLabels: { TextLabel } = {}
	local quoteLabels: { TextLabel } = {}
	local inzetLabels: { TextLabel } = {}
	local inzetten: { [number]: number } = {}
	local betBox: Common.BetBox
	local ververs: () -> ()

	for i, h in Odds.HORSES do
		local rij = Instance.new("Frame")
		rij.Name = "Lane" .. i
		rij.Size = UDim2.new(1, 0, 0, 34)
		rij.BackgroundColor3 = Theme.color.bg
		rij.BackgroundTransparency = 0.5
		rij.BorderSizePixel = 0
		rij.LayoutOrder = i
		UI.corner(rij, Theme.radius.chip)
		rij.Parent = veld

		local kleur = Color3.fromHex(h.color)

		-- Het paard zelf: een gekleurd blokje dat over de baan schuift.
		local loper = Instance.new("Frame")
		loper.AnchorPoint = Vector2.new(0.5, 0.5)
		loper.Position = UDim2.new(0, 22, 0.5, 0)
		loper.Size = UDim2.fromOffset(26, 20)
		loper.BackgroundColor3 = kleur
		loper.BorderSizePixel = 0
		loper.ZIndex = 3
		UI.corner(loper, Theme.radius.chip)
		loper.Parent = rij
		lopers[i] = loper

		local nr = UI.label(loper, tostring(i), {
			size = Theme.text.tiny, color = Theme.color.bg, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center,
		})
		nr.Size = UDim2.fromScale(1, 1)
		nr.ZIndex = 4

		local naam = UI.label(rij, h.name, { size = Theme.text.tiny, color = kleur, font = Theme.font.uiMed })
		naam.Position = UDim2.new(0, 44, 0, 2)
		naam.Size = UDim2.new(0, 110, 0, 14)
		naamLabels[i] = naam

		local quote = UI.label(rij, "\u{2014}", {
			size = Theme.text.tiny, color = Theme.color.muted, font = Theme.font.num,
		})
		quote.Position = UDim2.new(0, 44, 0, 16)
		quote.Size = UDim2.new(0, 110, 0, 14)
		quoteLabels[i] = quote

		local inzet = UI.label(rij, "", {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
			align = Enum.TextXAlignment.Right,
		})
		inzet.AnchorPoint = Vector2.new(1, 0.5)
		inzet.Position = UDim2.new(1, -8, 0.5, 0)
		inzet.Size = UDim2.new(0, 90, 0, 16)
		inzetLabels[i] = inzet

		local knop = Instance.new("TextButton")
		knop.Text = ""
		knop.BackgroundTransparency = 1
		knop.Size = UDim2.fromScale(1, 1)
		knop.ZIndex = 5
		knop.Parent = rij
		knop.Activated:Connect(function()
			local bedrag = betBox.get()
			if bedrag < Money.MIN_BET then
				Common.toast("MINIMUM STAKE $" .. Money.fmt(Money.MIN_BET), "red")
				return
			end
			inzetten[i] = Money.round2((inzetten[i] or 0) + bedrag)
			ververs()
		end)
	end

	-- De paarden terug naar de start, en de baan leeg.
	local function opstellen()
		for i, loper in lopers do
			loper.Position = UDim2.new(0, 22, 0.5, 0)
		end
	end

	-- De race afspelen. `volgorde` komt van de server: plaats 1 wint. De looplijn is
	-- alleen versiering -- elk paard komt precies op zijn eigen plaats binnen.
	local function race(volgorde: { number }, kansen: { number })
		local loop: { [number]: Loop } = {}
		for plaats, paard in volgorde do
			loop[paard] = {
				-- Een lage pace start hard en zakt terug, een hoge komt van achteren. Door
				-- dat te schudden weet je aan de start niet wie er gaat winnen.
				pace = 0.55 + math.random() * 1.35,
				amp = 0.05 + math.random() * 0.07,
				freq = 1.6 + math.random() * 2.2,
				fase = math.random() * math.pi * 2,
				eind = 5.0 + (plaats - 1) * 0.28 + math.random() * 0.16,
			}
		end

		local langste = 0
		for _, l in loop do
			if l.eind > langste then langste = l.eind end
		end

		local start = os.clock()
		local verbinding: RBXScriptConnection
		local klaar = false
		verbinding = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			for i, loper in lopers do
				local l = loop[i]
				local u = math.min(1, t / l.eind)
				local pos = u ^ l.pace
				-- De golf is nul aan het begin en aan het eind, dus hij verandert de
				-- uitslag niet, alleen het beeld ertussenin.
				pos += l.amp * math.sin(l.freq * t + l.fase) * math.sin(math.pi * u)
				pos = math.clamp(pos, 0, 1)
				local baanBreedte = loper.Parent :: Frame
				local ruimte = math.max(0, baanBreedte.AbsoluteSize.X - 44)
				loper.Position = UDim2.new(0, 22 + pos * ruimte, 0.5, 0)
			end
			if t >= langste and not klaar then
				klaar = true
				verbinding:Disconnect()
			end
		end)

		while not klaar do
			task.wait(0.05)
		end
	end

	-- ---------- de bediening ----------
	betBox = Common.betBox(bediening, 10)

	local overzicht = UI.panel(bediening, "Slip")
	UI.list(overzicht, 4)
	UI.panelTitle(overzicht, "your slip")
	local totaalLabel = Common.statRow(overzicht, "TOTAL STAKED", "$0.00")

	local wissen = UI.secondary(bediening, "CLEAR BETS")
	local starten = UI.primary(bediening, "START RACE")

	function ververs()
		local t = 0
		for i, b in inzetten do
			t += b
		end
		totaalLabel.Text = "$" .. Money.fmt(Money.round2(t))
		for i, label in inzetLabels do
			local b = inzetten[i]
			label.Text = if b then "$" .. Money.fmt(b) else ""
		end
	end

	wissen.Activated:Connect(function()
		table.clear(inzetten)
		ververs()
	end)

	local bezig = false
	starten.Activated:Connect(function()
		if bezig then return end
		local totaal = 0
		for _, b in inzetten do totaal += b end
		if totaal < Money.MIN_BET then
			Common.toast("BACK A HORSE FIRST", "red")
			return
		end
		bezig = true
		starten.Text = "RACING..."
		balk.set("AND THEY'RE OFF", nil)
		opstellen()

		local kopie: { [number]: number } = {}
		for i, b in inzetten do kopie[i] = b end
		local res = Common.call("Bet", "horse", kopie)
		if not res then
			bezig = false
			starten.Text = "START RACE"
			return
		end

		-- De quotes pas tonen als de race loopt: daarvoor weet je ze nog niet.
		for i, p in res.probs do
			quoteLabels[i].Text = Money.fmt(Odds.horseMultiplier(p)) .. "\u{00D7}"
		end

		race(res.order, res.probs)

		local winnaar = Odds.HORSES[res.winner]
		if res.payout > 0 then
			balk.set(winnaar.name .. " WINS  \u{00B7}  +$" .. Money.fmt(res.payout), "green")
			Common.toast("+$" .. Money.fmt(res.payout), "green")
		else
			balk.set(winnaar.name .. " WINS  \u{00B7}  -$" .. Money.fmt(Money.round2(totaal)), "red")
		end
		table.clear(inzetten)
		ververs()
		bezig = false
		starten.Text = "START RACE"
	end)

	ververs()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "horse")
	Common.oddsPanel(bediening, "odds", "Every horse has its own win chance, shown as a percentage. Payout = 0.97 / win chance, so RTP 97% on every horse, favourite or longshot. The result is drawn before the start; the race just plays it out.")

end

return Horse
]],
	["Mines"] = [[
--!strict
-- Mines: vijfentwintig tegels, een aantal mijnen ertussen. Waar ze liggen weet alleen de
-- server; een tegel die al open ligt telt niet nog een keer mee.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Mines = {}

local SNEL = {1, 3, 5, 10, 24}

function Mines.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "MINES")

	local veld = UI.panel(bord, "Field")
	UI.list(veld, 8)
	UI.panelTitle(veld, "mines")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = veld
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 64, 0, 64)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = raster

	local balk = Common.banner(veld)
	balk.set("SET THE MINES AND START", nil)

	local mijnen = 3
	local actief = false
	local gepakt = 0
	local tegels: { TextButton } = {}
	local betBox: Common.BetBox
	local startKnop: TextButton
	local uitKnop: TextButton

	local function zetTegel(i: number, tekst: string, kleur: Color3, open: boolean)
		local b = tegels[i]
		b.Text = tekst
		b.TextColor3 = kleur
		b.BackgroundTransparency = if open then 0.2 else 0.5
	end

	local function leeg()
		for i = 1, Odds.MINES_TILES do
			zetTegel(i, "", Theme.color.text, false)
		end
	end

	-- Het hele veld openleggen als de ronde voorbij is.
	local function toonAlles(grid: { boolean })
		for i, mijn in grid do
			if mijn then
				zetTegel(i, "\u{2716}", Theme.color.red, true)
			elseif tegels[i].Text == "" then
				zetTegel(i, "\u{25C6}", Theme.color.muted, false)
			end
		end
	end

	local function zetActief()
		for _, b in tegels do
			b.Active = actief
		end
		startKnop.Visible = not actief
		uitKnop.Visible = actief
		uitKnop.Active = gepakt > 0
		betBox.lock(actief)
	end

	local function pak(i: number)
		if not actief then return end
		local res = Common.call("Act", "mines", i)
		if not res then return end

		if res.mine then
			zetTegel(i, "\u{2716}", Theme.color.red, true)
			toonAlles(res.grid)
			actief = false
			gepakt = 0
			zetActief()
			balk.set("BOOM", "red")
			return
		end

		zetTegel(i, "\u{25C6}", Theme.color.neon, true)
		if res.done then
			actief = false
			gepakt = 0
			zetActief()
			balk.set("FIELD CLEARED  \u{00B7}  +$" .. Money.fmt(res.payout), "gold")
			Common.toast("+$" .. Money.fmt(res.payout), "gold")
			return
		end

		gepakt = res.picked
		zetActief()
		balk.set(gepakt .. " SAFE  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		uitKnop.Text = "CASH OUT  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}"
	end

	for i = 1, Odds.MINES_TILES do
		local b = Instance.new("TextButton")
		b.Name = "Tile" .. i
		b.Text = ""
		b.Font = Theme.font.ui
		b.TextSize = 26
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.bg
		b.BackgroundTransparency = 0.5
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.button)
		UI.stroke(b, Theme.color.border)
		b.Parent = raster
		b.Activated:Connect(function()
			pak(i)
		end)
		tegels[i] = b
	end

	-- ---------- de bediening ----------
	local keuze = UI.panel(bediening, "Mines")
	UI.list(keuze, 6)
	UI.panelTitle(keuze, "mines")
	local aantalLabel = Common.statRow(keuze, "MINES", tostring(mijnen))
	local eersteLabel = Common.statRow(keuze, "FIRST PICK PAYS", Money.fmt(Odds.minesMultiplier(mijnen, 1)) .. "\u{00D7}")
	local snelRij = Common.row(keuze, 26)
	local snelKnoppen: { [number]: TextButton } = {}

	local function markeer()
		aantalLabel.Text = tostring(mijnen)
		eersteLabel.Text = Money.fmt(Odds.minesMultiplier(mijnen, 1)) .. "\u{00D7}"
		for n, b in snelKnoppen do
			local aan = n == mijnen
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.bg
			b.BackgroundTransparency = if aan then 0.1 else 0.5
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
		end
	end

	for _, n in SNEL do
		local b = UI.chip(snelRij, tostring(n))
		b.Size = UDim2.new(1 / #SNEL, -5, 0, 26)
		b.Activated:Connect(function()
			if actief then return end
			mijnen = n
			markeer()
		end)
		snelKnoppen[n] = b
	end

	betBox = Common.betBox(bediening, 10)
	startKnop = UI.primary(bediening, "START GAME")
	uitKnop = UI.primary(bediening, "CASH OUT")
	uitKnop.Visible = false

	startKnop.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "mines", betBox.get(), mijnen)
		if not res then return end
		actief = true
		gepakt = 0
		leeg()
		zetActief()
		uitKnop.Text = "CASH OUT"
		balk.set("PICK A TILE", nil)
	end)

	uitKnop.Activated:Connect(function()
		if not actief or gepakt < 1 then return end
		local res = Common.call("CashOut", "mines")
		if not res then return end
		actief = false
		gepakt = 0
		toonAlles(res.grid)
		zetActief()
		balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		Common.toast("+$" .. Money.fmt(res.payout), "green")
	end)

	leeg()
	zetActief()
	markeer()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "mines")
	Common.oddsPanel(bediening, "odds", "25 tiles. Multiplier after k diamonds = 0.97 / chance(k safe in a row). RTP 97% at every cash-out. The mines are placed before your first click.")

end

return Mines
]],
	["Plinko"] = [[
--!strict
-- Plinko: de pinnen, het balletje dat langs het pad van de server valt, en de bakjes
-- eronder. De cijfers in de bakjes staan onder elkaar in plaats van in het midden, net als
-- na de laatste fix in de webversie, zodat ze op een smal scherm niet over elkaar vallen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Plinko = {}

local RIJEN = {8, 12, 16}
local RISICO = {"low", "medium", "high"}

-- Warme kleuren aan de randen, koel in het midden: zo leest een speler de tabel in één
-- oogopslag, precies als de CSS-klassen in de webversie.
local function bakKleur(mult: number): Color3
	if mult >= 20 then return Color3.fromHex("e0616e") end
	if mult >= 5 then return Color3.fromHex("e08a55") end
	if mult >= 1.5 then return Theme.color.gold end
	if mult >= 1 then return Color3.fromHex("4a7f63") end
	return Color3.fromHex("2a323d")
end

function Plinko.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "PLINKO")

	local vak = UI.panel(bord, "Board")
	UI.list(vak, 8)
	UI.panelTitle(vak, "plinko")

	local veld = Instance.new("Frame")
	veld.Name = "Field"
	veld.Size = UDim2.new(1, 0, 0, 320)
	veld.BackgroundColor3 = Theme.color.bg
	veld.BackgroundTransparency = 0.4
	veld.BorderSizePixel = 0
	UI.corner(veld, Theme.radius.button)
	veld.Parent = vak

	local bakkenRij = Instance.new("Frame")
	bakkenRij.Name = "Buckets"
	bakkenRij.Size = UDim2.new(1, 0, 0, 44)
	bakkenRij.BackgroundTransparency = 1
	bakkenRij.Parent = vak

	local balk = Common.banner(vak)
	balk.set("DROP A BALL", nil)

	local rijen = 12
	local risico = "medium"
	local pinnen: { Frame } = {}
	local bakken: { Frame } = {}

	-- Het veld opnieuw tekenen als het aantal rijen of het risico verandert.
	local function teken()
		for _, p in pinnen do p:Destroy() end
		table.clear(pinnen)
		for _, b in bakken do b:Destroy() end
		table.clear(bakken)

		local hoogteStap = 1 / (rijen + 1)
		for r = 1, rijen do
			for k = 0, r do
				local p = Instance.new("Frame")
				p.AnchorPoint = Vector2.new(0.5, 0.5)
				-- Elke rij is een pin breder; het midden blijft het midden.
				p.Position = UDim2.fromScale(0.5 + (k - r / 2) / (rijen + 1), hoogteStap * (r + 0.2))
				p.Size = UDim2.fromOffset(5, 5)
				p.BackgroundColor3 = Theme.color.muted
				p.BorderSizePixel = 0
				UI.corner(p, 3)
				p.Parent = veld
				table.insert(pinnen, p)
			end
		end

		local tabel = Odds.plinkoTable(rijen, risico)
		for i, m in tabel do
			local b = Instance.new("Frame")
			b.Name = "Bucket" .. i
			b.Size = UDim2.new(1 / #tabel, -2, 1, 0)
			b.Position = UDim2.new((i - 1) / #tabel, 1, 0, 0)
			b.BackgroundColor3 = bakKleur(m)
			b.BorderSizePixel = 0
			UI.corner(b, Theme.radius.chip)
			b.Parent = bakkenRij

			-- De multiplier bovenin, het nummer van het bakje onderin. Nooit allebei in het
			-- midden: dan staan ze op een telefoon over elkaar.
			local boven = UI.label(b, Money.fmt(m) .. "\u{00D7}", {
				size = Theme.text.tiny, color = Theme.color.bg, font = Theme.font.num,
				align = Enum.TextXAlignment.Center,
			})
			boven.Position = UDim2.new(0, 0, 0, 2)
			boven.Size = UDim2.new(1, 0, 0, 14)

			local onder = UI.label(b, tostring(i - 1), {
				size = Theme.text.tiny, color = Theme.color.bg, font = Theme.font.num,
				align = Enum.TextXAlignment.Center,
			})
			onder.AnchorPoint = Vector2.new(0, 1)
			onder.Position = UDim2.new(0, 0, 1, -2)
			onder.Size = UDim2.new(1, 0, 0, 12)
			onder.TextTransparency = 0.45

			table.insert(bakken, b)
		end
	end

	-- Het balletje langs het pad laten vallen dat de server heeft getrokken.
	local function laatVallen(pad: { number }, bak: number)
		local bal = Instance.new("Frame")
		bal.AnchorPoint = Vector2.new(0.5, 0.5)
		bal.Position = UDim2.fromScale(0.5, 0)
		bal.Size = UDim2.fromOffset(11, 11)
		bal.BackgroundColor3 = Theme.color.neon
		bal.BorderSizePixel = 0
		bal.ZIndex = 4
		UI.corner(bal, 6)
		bal.Parent = veld

		local x = 0
		local hoogteStap = 1 / (#pad + 1)
		for r, stap in pad do
			x += stap - 0.5
			local doel = UDim2.fromScale(0.5 + x / (#pad + 1), hoogteStap * (r + 0.6))
			local tw = TweenService:Create(bal, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = doel,
			})
			tw:Play()
			tw.Completed:Wait()
		end
		local eind = bakken[bak + 1]
		if eind then
			local tw = TweenService:Create(bal, TweenInfo.new(0.12), { Position = UDim2.fromScale((bak + 0.5) / #bakken, 1) })
			tw:Play()
			tw.Completed:Wait()
			-- Het bakje knippert even op, zodat je ziet waar hij viel.
			local oud = eind.BackgroundColor3
			eind.BackgroundColor3 = Theme.color.text
			task.delay(0.25, function()
				if eind.Parent then eind.BackgroundColor3 = oud end
			end)
		end
		task.delay(0.2, function()
			bal:Destroy()
		end)
	end

	-- ---------- de bediening ----------
	local keuzes = UI.panel(bediening, "Setup")
	UI.list(keuzes, 6)
	UI.panelTitle(keuzes, "rows")
	local rijRij = Common.row(keuzes, 28)
	local rijKnoppen: { [number]: TextButton } = {}
	UI.panelTitle(keuzes, "risk")
	local riskRij = Common.row(keuzes, 28)
	local riskKnoppen: { [string]: TextButton } = {}

	local function markeer()
		for n, b in rijKnoppen do
			b.BackgroundTransparency = if n == rijen then 0.1 else 0.5
			b.TextColor3 = if n == rijen then Theme.color.bg else Theme.color.text
			b.BackgroundColor3 = if n == rijen then Theme.color.neon else Theme.color.bg
		end
		for k, b in riskKnoppen do
			b.BackgroundTransparency = if k == risico then 0.1 else 0.5
			b.TextColor3 = if k == risico then Theme.color.bg else Theme.color.text
			b.BackgroundColor3 = if k == risico then Theme.color.neon else Theme.color.bg
		end
	end

	for _, n in RIJEN do
		local b = UI.chip(rijRij, tostring(n))
		b.Size = UDim2.new(1 / #RIJEN, -4, 0, 28)
		b.Activated:Connect(function()
			rijen = n
			teken()
			markeer()
		end)
		rijKnoppen[n] = b
	end
	for _, k in RISICO do
		local b = UI.chip(riskRij, string.upper(k))
		b.Size = UDim2.new(1 / #RISICO, -4, 0, 28)
		b.Activated:Connect(function()
			risico = k
			teken()
			markeer()
		end)
		riskKnoppen[k] = b
	end

	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "DROP BALL")

	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "DROPPING..."
		local res = Common.call("Bet", "plinko", betBox.get(), rijen, risico)
		if not res then
			bezig = false
			knop.Text = "DROP BALL"
			return
		end
		laatVallen(res.path, res.bucket)
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 10 then "gold" else "green")
		else
			balk.set(Money.fmt(res.mult) .. "\u{00D7}", "red")
		end
		bezig = false
		knop.Text = "DROP BALL"
	end)

	teken()
	markeer()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "plinko")
	Common.oddsPanel(bediening, "odds", "Every row is a fair 50/50. The payout table is normalised to RTP 97% per row count and risk level. Higher risk means bigger outliers and more small losses.")

end

return Plinko
]],
	["Profile"] = [[
--!strict
-- Profiel: je saldo, je totalen en per spel wat je ervan gebakken hebt. Alles komt uit het
-- profiel dat de server stuurt; de client rekent hier niets uit wat geld raakt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Profile = {}

-- Dezelfde volgorde en namen als op de homepagina, plus de twee VIP-spellen.
local SPELLEN = {
	{ id = "crash", label = "CRASH" },
	{ id = "roulette", label = "ROULETTE" },
	{ id = "tower", label = "DRAGON TOWER" },
	{ id = "mines", label = "MINES" },
	{ id = "plinko", label = "PLINKO" },
	{ id = "blackjack", label = "BLACKJACK" },
	{ id = "scratch", label = "SCRATCH CARDS" },
	{ id = "wheel", label = "WHEEL" },
	{ id = "slots", label = "777" },
	{ id = "horse", label = "HORSE RACE" },
	{ id = "bus", label = "RIDE THE BUS" },
}

local function tekenGetal(n: number): string
	return string.format("%d", n)
end

-- Winst rood of groen, met een teken ervoor. Nul is grijs, want dat is geen van beide.
local function winstKleur(n: number): Color3
	if n > 0.005 then return Theme.color.neon end
	if n < -0.005 then return Theme.color.red end
	return Theme.color.muted
end

local function winstTekst(n: number): string
	local teken = if n > 0.005 then "+" elseif n < -0.005 then "-" else ""
	return teken .. "$" .. Money.fmt(math.abs(n))
end

function Profile.build(ouder: Instance): (any) -> ()
	local blad = Common.sheet(ouder)

	-- ---------- de kaart bovenaan ----------
	local kaart = UI.panel(blad, "Card")
	UI.list(kaart, 6)
	local naam = UI.label(kaart, Players.LocalPlayer.DisplayName, {
		size = Theme.text.big, color = Theme.color.text, font = Theme.font.uiMed,
	})
	naam.Size = UDim2.new(1, 0, 0, 28)
	local titel = UI.label(kaart, "\u{2014}", { size = Theme.text.small, color = Theme.color.gold })

	local saldo = UI.label(kaart, "$" .. Money.fmt(Money.START), {
		size = Theme.text.huge, color = Theme.color.neon, font = Theme.font.num,
	})
	saldo.Size = UDim2.new(1, 0, 0, 46)

	-- ---------- de totalen ----------
	local totalen = UI.panel(blad, "Totals")
	UI.list(totalen, 4)
	UI.panelTitle(totalen, "lifetime")
	local rondes = Common.statRow(totalen, "ROUNDS PLAYED", "0")
	local gewonnen = Common.statRow(totalen, "ROUNDS WON", "0")
	local verloren = Common.statRow(totalen, "ROUNDS LOST", "0")
	local winkans = Common.statRow(totalen, "WIN RATE", "\u{2014}")
	local winst = Common.statRow(totalen, "NET PROFIT", "$0.00")

	-- ---------- per spel ----------
	local perSpel = UI.panel(blad, "PerGame")
	UI.list(perSpel, 4)
	UI.panelTitle(perSpel, "by game")

	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, 18)
	kop.BackgroundTransparency = 1
	kop.Parent = perSpel
	local function kolomLabel(tekst: string, x: number, breed: number, rechts: boolean)
		local t = UI.label(kop, tekst, {
			size = Theme.text.tiny, color = Theme.color.muted, font = Theme.font.uiMed,
			align = if rechts then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		})
		t.Position = UDim2.new(x, 0, 0, 0)
		t.Size = UDim2.new(breed, 0, 1, 0)
	end
	kolomLabel("GAME", 0, 0.34, false)
	kolomLabel("ROUNDS", 0.34, 0.16, true)
	kolomLabel("WON", 0.5, 0.12, true)
	kolomLabel("BEST", 0.62, 0.16, true)
	kolomLabel("PROFIT", 0.78, 0.22, true)

	type Regel = { rondes: TextLabel, gewonnen: TextLabel, beste: TextLabel, winst: TextLabel }
	local regels: { [string]: Regel } = {}

	for i, spel in SPELLEN do
		local rij = Instance.new("Frame")
		rij.Name = spel.id
		rij.Size = UDim2.new(1, 0, 0, 20)
		rij.BackgroundTransparency = 1
		rij.LayoutOrder = i
		rij.Parent = perSpel

		local function cel(tekst: string, x: number, breed: number, rechts: boolean, kleur: Color3?): TextLabel
			local t = UI.label(rij, tekst, {
				size = Theme.text.small, color = kleur or Theme.color.text,
				font = if rechts then Theme.font.num else Theme.font.ui,
				align = if rechts then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			})
			t.Position = UDim2.new(x, 0, 0, 0)
			t.Size = UDim2.new(breed, 0, 1, 0)
			return t
		end

		cel(spel.label, 0, 0.34, false, Theme.color.muted)
		regels[spel.id] = {
			rondes = cel("0", 0.34, 0.16, true),
			gewonnen = cel("0", 0.5, 0.12, true),
			beste = cel("\u{2014}", 0.62, 0.16, true),
			winst = cel("$0.00", 0.78, 0.22, true, Theme.color.muted),
		}
	end

	-- Het profiel binnenkrijgen en alles bijwerken.
	return function(p: any)
		if typeof(p) ~= "table" then return end
		saldo.Text = "$" .. Money.fmt(tonumber(p.balance) or 0)
		titel.Text = if typeof(p.title) == "string" and p.title ~= "" then p.title else "NO TITLE YET"

		local r = tonumber(p.rounds) or 0
		local w = tonumber(p.won) or 0
		local l = tonumber(p.lost) or 0
		rondes.Text = tekenGetal(r)
		gewonnen.Text = tekenGetal(w)
		verloren.Text = tekenGetal(l)
		winkans.Text = if r > 0 then string.format("%.1f%%", w / r * 100) else "\u{2014}"
		local nettoWinst = tonumber(p.profit) or 0
		winst.Text = winstTekst(nettoWinst)
		winst.TextColor3 = winstKleur(nettoWinst)

		local stats = if typeof(p.stats) == "table" then p.stats else {}
		for id, regel in regels do
			local s = stats[id]
			if typeof(s) == "table" then
				regel.rondes.Text = tekenGetal(tonumber(s.rounds) or 0)
				regel.gewonnen.Text = tekenGetal(tonumber(s.won) or 0)
				local beste = tonumber(s.highest) or 0
				regel.beste.Text = if beste > 0 then Money.fmt(beste) .. "\u{00D7}" else "\u{2014}"
				local sw = tonumber(s.profit) or 0
				regel.winst.Text = winstTekst(sw)
				regel.winst.TextColor3 = winstKleur(sw)
			end
		end
	end
end

return Profile
]],
	["Roulette"] = [[
--!strict
-- Roulette: een echt rad met zevenendertig vakken, daaronder het inzetvlak, en links de
-- fichewaarde. Europees, dus één groene nul. De fiches blijven op het bord liggen tot je
-- SPIN geeft; pas dan gaan alle inzetten in één keer naar de server, die het getal trekt
-- en afrekent. Het rad laat alleen zien wat er al besloten is.
--
-- Elke maat hieronder komt uit de webversie: .rl-wheel-wrap, .rl-result, .rl-board,
-- .rl-cell, .rl-chip, .rl-hist en de tekenroutine rlDraw() in crash.html.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Roulette = {}

-- ---------- de kleuren uit de CSS ----------
-- Het bord heeft zijn eigen rood en zwart; die staan los van --red en --text uit het thema,
-- want een roulettekleed is donkerder dan de rest van de site.
local ROOD = Color3.fromHex("b3122e")         -- .rl-cell.red
local ZWART = Color3.fromHex("141414")        -- .rl-cell.black
local GROEN = Color3.fromHex("0b7a3b")        -- .rl-cell.green
local BUITEN_ROOD = Color3.fromHex("6a0a1a")  -- .rl-cell.outside.red
local BUITEN_ZWART = Color3.fromHex("222222") -- .rl-cell.outside.black
local POCKET_ZWART = Color3.fromHex("151515") -- rlDraw(): de zwarte vakken in het rad
local GOUD_RAD = Color3.fromHex("cc9900")     -- de rand, de spaken en de naafpin
local RAND_BUITEN = Color3.fromHex("3a2410")  -- de houten buitenring
local RAND_BINNEN = Color3.fromHex("1a0a0a")  -- de donkere schijf daarbinnen
local NAAF = Color3.fromHex("2a1408")
local FICHE_RAND = Color3.fromHex("fff3b0")   -- .rl-chip border
local STREEP = Color3.fromHex("1a3a1a")       -- .payout-line border-bottom
local RES_ROOD_RAND = Color3.fromHex("ff6b81")-- .rl-result.red border
local RES_ZWART = Color3.fromHex("111111")
local RES_ZWART_RAND = Color3.fromHex("666666")
local HIST_ZWART = Color3.fromHex("222222")   -- .rl-hist.black
local HIST_ZWART_RAND = Color3.fromHex("555555")

local function kleurVan(n: number): Color3
	local k = Odds.rouletteColor(n)
	return if k == "green" then GROEN elseif k == "red" then ROOD else ZWART
end

-- ---------- maten ----------
local WIEL = 300                   -- .rl-wheel-wrap: width min(300px, 90vw), aspect-ratio 1
local STRAAL = WIEL / 2 - 6        -- rlDraw(): R = min(w,h)/2 - 6
local VAKKEN = 37
local STAP = 360 / VAKKEN

-- .rl-board: grid-template-columns 40px repeat(12, 1fr) 40px, gap 3, max-width 760.
local BORD_B = 760
local GAT = 3
local ZIJKOLOM = 40
local KOLOM = (BORD_B - ZIJKOLOM * 2 - GAT * 13) / 12   -- 53.42, de breedte van één nummer
local RIJ_H = { 44, 44, 44, 36, 36 }                    -- grid-template-rows
local BORD_H = 44 * 3 + 36 * 2 + GAT * 4                -- 216
-- De fiches steken zeven pixels buiten hun vak; de groep eromheen krijgt die lucht erbij,
-- anders knipt hij ze eraf.
local LUCHT = 10

-- De x van een rasterkolom (1 = de nul, 2..13 de nummers, 14 de 2:1-kolom).
local function kolomX(j: number): number
	if j <= 1 then return 0 end
	return ZIJKOLOM + GAT + (j - 2) * (KOLOM + GAT)
end

-- De breedte van een vak dat over `aantal` nummerkolommen loopt.
local function kolomBreedte(aantal: number): number
	return aantal * KOLOM + (aantal - 1) * GAT
end

local function rijY(r: number): number
	local y = 0
	for i = 1, r - 1 do
		y += RIJ_H[i] + GAT
	end
	return y
end

-- ---------- kleine bouwsteentjes ----------
local function schijf(ouder: Instance, diameter: number, kleur: Color3, naam: string): Frame
	local f = Instance.new("Frame")
	f.Name = naam
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.BackgroundColor3 = kleur
	f.BorderSizePixel = 0
	UI.corner(f, diameter / 2)
	f.Parent = ouder
	return f
end

-- .payout-line: naam links, waarde rechts in het cijferlettertype, en een haarlijntje eronder.
local function payoutRegel(ouder: Instance, naam: string, waarde: string, kleur: Color3): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, 28)   -- padding 6 boven en onder om een regel van 11
	rij.BackgroundTransparency = 1
	rij.Parent = ouder

	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.text, name = "Key" })
	local v = UI.label(rij, waarde, {
		size = Theme.text.small, color = kleur, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Value",
	})

	local lijn = Instance.new("Frame")
	lijn.Name = "Rule"
	lijn.AnchorPoint = Vector2.new(0, 1)
	lijn.Position = UDim2.new(0, 0, 1, 0)
	lijn.Size = UDim2.new(1, 0, 0, 1)
	lijn.BackgroundColor3 = STREEP
	lijn.BackgroundTransparency = 0.5   -- rgba(26,58,26,0.5)
	lijn.BorderSizePixel = 0
	lijn.Parent = rij
	return v
end

function Roulette.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "ROULETTE")
	-- .board zet 18 pixels tussen het rad en het inzetvlak; de gedeelde kolomhulp gebruikt 14.
	local bordLijst = bord:FindFirstChildOfClass("UIListLayout")
	if bordLijst then bordLijst.Padding = UDim.new(0, 18) end

	-- ---------- .rl-top: het rad naast de uitslag ----------
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(1, 0, 0, 0)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.BackgroundTransparency = 1
	top.LayoutOrder = 1
	top.Parent = bord
	local topLijst = UI.list(top, 24, Enum.FillDirection.Horizontal)
	topLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	-- Het rad van 300 plus de uitslagkolom van 200 met 24 ertussen is 524 breed. Past dat
	-- niet, dan gaat de uitslag eronder staan -- dat is wat .rl-top onder de 900 pixels doet.
	local gestapeld: boolean? = nil
	local function meetTop()
		local breed = top.AbsoluteSize.X
		if breed <= 0 then return end
		local smal = breed < WIEL + 24 + 200
		if smal == gestapeld then return end
		gestapeld = smal
		topLijst.FillDirection = if smal then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	end
	top:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetTop)
	task.defer(meetTop)

	-- ---------- het rad ----------
	local radVak = Instance.new("Frame")
	radVak.Name = "Wheel"
	radVak.Size = UDim2.fromOffset(WIEL, WIEL)
	radVak.BackgroundTransparency = 1
	radVak.LayoutOrder = 1
	radVak.Parent = top

	schijf(radVak, (STRAAL + 4) * 2, RAND_BUITEN, "Rim")
	schijf(radVak, STRAAL * 2, RAND_BINNEN, "Well")

	-- Alleen deze ring draait; de naald en de bal hangen erbuiten en blijven dus staan.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 2
	ring.Parent = radVak

	-- Roblox kent geen taartpunten. Elk vak is daarom een rechthoekje dat op het midden van
	-- de ring staat en met de hoek meedraait: even breed als de punt daar is, even lang als
	-- de ring dik is (van 0.55R tot 0.98R, net als in rlDraw). De taps toelopende zijkant
	-- gaat verloren; met 37 vakken van nog geen tien graden valt dat niet op.
	local vakBreed = 2 * math.pi * (STRAAL * 0.765) / VAKKEN
	local vakLang = STRAAL * (0.98 - 0.55)
	for i, n in Odds.ROULETTE_ORDER do
		local hoek = -90 + (i - 0.5) * STAP           -- het midden van vak i
		local rad = math.rad(hoek)
		local v = Instance.new("Frame")
		v.Name = "P" .. n
		v.AnchorPoint = Vector2.new(0.5, 0.5)
		v.Position = UDim2.new(0.5, math.cos(rad) * STRAAL * 0.765, 0.5, math.sin(rad) * STRAAL * 0.765)
		v.Size = UDim2.fromOffset(vakBreed, vakLang)
		v.Rotation = hoek + 90                        -- de lange kant wijst naar het midden
		v.BackgroundColor3 = if n == 0 then GROEN elseif Odds.rouletteColor(n) == "red" then ROOD else POCKET_ZWART
		v.BorderSizePixel = 0
		v.Parent = ring
		-- De gouden scheidingslijntjes: in de CSS 0.8 pixel, hier 1 -- dunner kan Roblox niet.
		UI.stroke(v, GOUD_RAD, 1)

		local cijfer = UI.label(v, tostring(n), {
			size = Theme.text.tiny, color = Theme.color.white, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center, name = "N",
		})
		cijfer.AnchorPoint = Vector2.new(0.5, 0.5)
		-- rlDraw zet het cijfer op 0.86R; het vakmidden ligt op 0.765R, dus een stukje
		-- naar buiten, en dat is in dit gedraaide vakje omhoog.
		cijfer.Position = UDim2.new(0.5, 0, 0.5, -(0.86 - 0.765) * STRAAL)
		cijfer.Size = UDim2.fromOffset(vakBreed + 8, Theme.text.tiny + 4)
	end

	-- De naaf met de vier spaken draait mee.
	local naaf = schijf(ring, STRAAL * 0.55 * 2, NAAF, "Hub")
	naaf.ZIndex = 2
	UI.stroke(naaf, GOUD_RAD, 2)
	for i = 0, 3 do
		local spaak = Instance.new("Frame")
		spaak.Name = "Spoke" .. i
		spaak.AnchorPoint = Vector2.new(0, 0.5)
		spaak.Position = UDim2.fromScale(0.5, 0.5)
		spaak.Size = UDim2.fromOffset(STRAAL * 0.5, 3)
		spaak.Rotation = i * 90
		spaak.BackgroundColor3 = GOUD_RAD
		spaak.BorderSizePixel = 0
		spaak.ZIndex = 3
		spaak.Parent = ring
	end
	schijf(ring, STRAAL * 0.16 * 2, GOUD_RAD, "Pin").ZIndex = 4

	-- De bal loopt de andere kant op en zakt tegen het eind naar binnen.
	local bal = schijf(radVak, math.max(4, STRAAL * 0.04) * 2, Theme.color.white, "Ball")
	bal.ZIndex = 3
	local function zetBal(hoek: number, straalDeel: number)
		local rad = math.rad(hoek)
		local r = STRAAL * straalDeel
		bal.Position = UDim2.new(0.5, math.cos(rad) * r, 0.5, math.sin(rad) * r)
	end
	zetBal(-90, 0.93)

	-- De naald bovenaan. Een driehoek kan Roblox niet vullen, dus het is het teken ervoor.
	local naald = UI.label(radVak, "\u{25BC}", {
		size = 20, color = Theme.color.gold, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center, name = "Pointer",
	})
	naald.AnchorPoint = Vector2.new(0.5, 0.5)
	naald.Position = UDim2.new(0.5, 0, 0, WIEL / 2 - STRAAL + 4)
	naald.Size = UDim2.fromOffset(24, 24)
	naald.ZIndex = 4

	-- ---------- .rl-result en de strook met de laatste getallen ----------
	local kolom = Instance.new("Frame")
	kolom.Name = "Result"
	kolom.Size = UDim2.fromOffset(200, 0)
	kolom.AutomaticSize = Enum.AutomaticSize.Y
	kolom.BackgroundTransparency = 1
	kolom.LayoutOrder = 2
	kolom.Parent = top
	local kolomLijst = UI.list(kolom, 14)
	kolomLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local bol = Instance.new("TextLabel")
	bol.Name = "Marker"
	bol.Size = UDim2.fromOffset(110, 110)
	bol.BackgroundTransparency = 1
	bol.Text = "?"
	bol.Font = Theme.font.num
	bol.TextSize = 54
	bol.TextColor3 = Theme.color.muted
	bol.RichText = false
	UI.corner(bol, 55)
	local bolRand = UI.stroke(bol, Theme.color.border, 3)
	bol.Parent = kolom

	local strook = Instance.new("Frame")
	strook.Name = "History"
	strook.Size = UDim2.new(1, 0, 0, 0)
	strook.AutomaticSize = Enum.AutomaticSize.Y
	strook.BackgroundTransparency = 1
	strook.Parent = kolom
	local strookRaster = Instance.new("UIGridLayout")
	strookRaster.CellSize = UDim2.fromOffset(28, 28)
	strookRaster.CellPadding = UDim2.fromOffset(6, 6)
	strookRaster.HorizontalAlignment = Enum.HorizontalAlignment.Center
	strookRaster.SortOrder = Enum.SortOrder.LayoutOrder
	strookRaster.Parent = strook
	local strookMin = Instance.new("UISizeConstraint")
	strookMin.MinSize = Vector2.new(0, 26)   -- .result-strip min-height
	strookMin.Parent = strook

	local geschiedenis: { number } = {}
	local function toonGeschiedenis()
		for _, k in strook:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		for i, n in geschiedenis do
			local k = Odds.rouletteColor(n)
			local d = UI.label(strook, tostring(n), {
				size = Theme.text.tiny, color = Theme.color.white, font = Theme.font.num,
				align = Enum.TextXAlignment.Center, name = "H" .. i,
			})
			d.LayoutOrder = i
			d.BackgroundTransparency = 0
			d.BackgroundColor3 = if k == "green" then GROEN elseif k == "red" then ROOD else HIST_ZWART
			d.Size = UDim2.fromOffset(28, 28)
			UI.corner(d, 14)
			if k == "black" then UI.stroke(d, HIST_ZWART_RAND, 1) end
		end
	end

	-- ---------- .rl-board: het inzetvlak ----------
	-- Het bord is 760 breed; past dat niet, dan krimpt alles gelijkmatig mee. De webversie
	-- geeft het onder 900 pixels een schuifbalk, maar schuiven in een Roblox-paneel is
	-- lastiger dan een bord dat gewoon kleiner wordt.
	local houder = Instance.new("Frame")
	houder.Name = "BoardHolder"
	houder.Size = UDim2.new(1, 0, 0, BORD_H + LUCHT * 2)
	houder.BackgroundTransparency = 1
	houder.LayoutOrder = 2
	houder.Parent = bord

	-- Een CanvasGroup, want .rl-locked zet het hele bord tijdens het draaien op opacity 0.7;
	-- dat is per vak niet na te doen zonder elke kleur apart te verbleken.
	local groep = Instance.new("CanvasGroup")
	groep.Name = "Board"
	groep.AnchorPoint = Vector2.new(0.5, 0)
	groep.Position = UDim2.fromScale(0.5, 0)
	groep.Size = UDim2.fromOffset(BORD_B + LUCHT * 2, BORD_H + LUCHT * 2)
	groep.BackgroundTransparency = 1
	groep.BorderSizePixel = 0
	groep.Parent = houder
	local schaal = Instance.new("UIScale")
	schaal.Parent = groep

	local gemeten = -1
	local function meetBord()
		local breed = houder.AbsoluteSize.X
		if breed <= 0 then return end
		local s = math.min(1, breed / (BORD_B + LUCHT * 2))
		if math.abs(s - gemeten) < 0.001 then return end
		gemeten = s
		schaal.Scale = s
		houder.Size = UDim2.new(1, 0, 0, (BORD_H + LUCHT * 2) * s)
	end
	houder:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetBord)
	task.defer(meetBord)

	-- ---------- de inzetten ----------
	-- `win` onthoudt of dit vak de vorige ronde gewonnen heeft; dan blijft de gouden ring
	-- staan ook als de muis er weer af gaat.
	type Vakje = { knop: TextButton, fiche: TextLabel, gloed: UIStroke, win: boolean }

	local inzetten: { [string]: number } = {}
	local laatste: { [string]: number } = {}
	local vakjes: { [string]: Vakje } = {}
	local fiche = 10          -- RL.chip: de ficheknop die aan staat
	local bezig = false
	local ververs: () -> ()

	local function telOp(): number
		local t = 0
		for _, b in inzetten do t += b end
		return Money.round2(t)
	end

	local function plaats(key: string)
		if bezig then return end
		if fiche > Common.balance() - telOp() + 1e-9 then
			Common.toast("NOT ENOUGH BALANCE", "red")
			return
		end
		inzetten[key] = Money.round2((inzetten[key] or 0) + fiche)
		ververs()
	end

	-- Eén vak van het kleed: .rl-cell, met het fiche dat rechtsonder buiten de rand hangt.
	local function vak(key: string, tekst: string, kleur: Color3, j: number, kolommen: number, r: number, rijen: number, buiten: boolean)
		local hoogte = 0
		for i = r, r + rijen - 1 do
			hoogte += RIJ_H[i]
		end
		hoogte += GAT * (rijen - 1)

		local b = Instance.new("TextButton")
		b.Name = key
		b.Text = tekst
		b.Font = Theme.font.uiBold                       -- .rl-cell font-weight 700
		b.TextSize = if buiten then Theme.text.tiny else 13
		b.TextColor3 = if buiten then Theme.color.text else Theme.color.white
		b.BackgroundColor3 = kleur
		b.BackgroundTransparency = if buiten and kleur == Theme.color.black then 0.45 else 0
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Position = UDim2.fromOffset(LUCHT + kolomX(j), LUCHT + rijY(r))
		b.Size = UDim2.fromOffset(if j == 1 or j == 14 then ZIJKOLOM else kolomBreedte(kolommen), hoogte)
		b.RichText = false
		UI.corner(b, Theme.radius.button)
		local rand = UI.stroke(b, Theme.color.white, 1)
		rand.Transparency = 0.85                          -- border rgba(255,255,255,0.15)
		b.Parent = groep

		-- :hover is een gouden lijn eromheen, .win een gouden ring met gloed. Roblox kent
		-- geen box-shadow, dus beide worden dezelfde tweede rand -- de winnaar dikker.
		local gloed = Instance.new("UIStroke")
		gloed.Color = Theme.color.gold
		gloed.Thickness = 2
		gloed.Transparency = 1
		gloed.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		gloed.Parent = b

		local f = UI.label(b, "", {
			size = Theme.text.tiny, color = Theme.color.black, font = Theme.font.uiBold,
			align = Enum.TextXAlignment.Center, name = "Chip",
		})
		f.AnchorPoint = Vector2.new(1, 1)
		f.Position = UDim2.new(1, 7, 1, 7)               -- bottom -7, right -7
		f.Size = UDim2.fromOffset(24, 24)
		f.AutomaticSize = Enum.AutomaticSize.X
		f.BackgroundTransparency = 0
		f.BackgroundColor3 = Theme.color.gold
		f.Visible = false
		f.ZIndex = 4
		UI.corner(f, 12)
		UI.stroke(f, FICHE_RAND, 2)
		UI.padding4(f, 0, 5, 0, 5)
		local fMin = Instance.new("UISizeConstraint")
		fMin.MinSize = Vector2.new(24, 24)
		fMin.Parent = f

		b.MouseEnter:Connect(function()
			if not bezig then gloed.Transparency = 0 end
		end)
		b.MouseLeave:Connect(function()
			local v = vakjes[key]
			if not (v and v.win) then gloed.Transparency = 1 end
		end)
		b.Activated:Connect(function()
			plaats(key)
		end)

		vakjes[key] = { knop = b, fiche = f, gloed = gloed, win = false }
	end

	-- De nul staat links over de drie nummerrijen heen; daarna twaalf kolommen van drie,
	-- van onder naar boven geteld (n = kolom * 3 - rij), met de 2:1-kolom erachter.
	vak("n:0", "0", GROEN, 1, 1, 1, 3, false)
	for r = 0, 2 do
		for c = 1, 12 do
			local n = c * 3 - r
			vak("n:" .. n, tostring(n), kleurVan(n), c + 1, 1, r + 1, 1, false)
		end
		vak("c" .. (3 - r), "2:1", Theme.color.black, 14, 1, r + 1, 1, true)
	end
	for i, d in { { "1-12", "d1" }, { "13-24", "d2" }, { "25-36", "d3" } } do
		vak(d[2], d[1], Theme.color.black, 2 + (i - 1) * 4, 4, 4, 1, true)
	end
	for i, o in {
		{ "1-18", "low" }, { "EVEN", "even" }, { "RED", "red" },
		{ "BLACK", "black" }, { "ODD", "odd" }, { "19-36", "high" },
	} do
		local k = o[2]
		local kleur = if k == "red" then BUITEN_ROOD elseif k == "black" then BUITEN_ZWART else Theme.color.black
		vak(k, o[1], kleur, 2 + (i - 1) * 2, 2, 5, 1, true)
	end

	-- ---------- de bediening links ----------
	local vakBediening = UI.panel(bediening, "Controls")
	UI.list(vakBediening, 6)

	-- .field-group: "CHIP VALUE" links, het dollarteken in neon als hint rechts.
	local veld = Instance.new("Frame")
	veld.Name = "ChipField"
	veld.Size = UDim2.new(1, 0, 0, 0)
	veld.AutomaticSize = Enum.AutomaticSize.Y
	veld.BackgroundTransparency = 1
	veld.Parent = vakBediening
	UI.list(veld, 6)
	UI.padding4(veld, 0, 0, 8, 0)   -- .field-group margin-bottom 14, met de 6 uit de lijst erbij

	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	kop.BackgroundTransparency = 1
	kop.Parent = veld
	UI.label(kop, "CHIP VALUE", { size = Theme.text.small, color = Theme.color.muted })
	local hint = UI.label(kop, "$", {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
	})
	hint.TextTransparency = 0.3     -- .field-label .hint opacity 0.7

	-- .seg: vijf gelijke knoppen met 4 pixels ertussen; de aangeklikte is neon.
	local seg = Instance.new("Frame")
	seg.Name = "ChipSeg"
	seg.Size = UDim2.new(1, 0, 0, 30)
	seg.BackgroundTransparency = 1
	seg.Parent = veld
	UI.list(seg, 4, Enum.FillDirection.Horizontal)

	local segKnoppen: { [number]: TextButton } = {}
	local function zetFiche(waarde: number)
		fiche = waarde
		for v, b in segKnoppen do
			local aan = v == waarde
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			b.BackgroundTransparency = if aan then 0 else Theme.alpha.buttonBg
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			b.Font = if aan then Theme.font.uiBold else Theme.font.ui
			-- .seg button.on krijgt ook een neon rand, net als bij hover.
			local rand = b:FindFirstChildOfClass("UIStroke")
			if rand then rand.Color = if aan then Theme.color.neon else Theme.color.border end
		end
	end
	for i, waarde in { 1, 5, 10, 25, 100 } do
		local b = Instance.new("TextButton")
		b.Name = "Chip" .. waarde
		b.Text = tostring(waarde)
		b.Font = Theme.font.ui
		b.TextSize = Theme.text.tiny
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.new(0.2, -3.2, 1, 0)
		UI.corner(b, Theme.radius.chip)
		local rand = UI.stroke(b, Theme.color.border)
		b.MouseEnter:Connect(function()
			if fiche ~= waarde then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if fiche == waarde then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			if bezig then return end
			zetFiche(waarde)
		end)
		b.Parent = seg
		segKnoppen[waarde] = b
	end

	local totaalLabel = payoutRegel(vakBediening, "TOTAL STAKE", "$0.00", Theme.color.gold)
	local laatsteLabel = payoutRegel(vakBediening, "LAST RESULT", "\u{2014}", Theme.color.neon)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, over de volle breedte.
	local draaien = UI.primary(vakBediening, "SPIN")
	draaien.Font = Theme.font.uiBold
	UI.gradient(draaien, Theme.color.neon, Theme.color.neonDim, 135)

	local knoprij = Common.row(vakBediening, 36)
	UI.padding4(knoprij, 2, 0, 0, 0)   -- .btn-row margin-top 8, waarvan 6 uit de lijst komt
	local wissen = UI.secondary(knoprij, "CLEAR")
	wissen.Size = UDim2.new(0.5, -3, 0, 36)
	local herhalen = UI.secondary(knoprij, "REPEAT")
	herhalen.Size = UDim2.new(0.5, -3, 0, 36)

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "roulette")
	Common.oddsPanel(bediening, "payouts", "Straight number 35:1 \u{00B7} Dozen / column 2:1 \u{00B7} Red / black / even / odd / 1-18 / 19-36 1:1. One zero, so RTP 97.3% on every bet.")

	zetFiche(fiche)

	-- ---------- bijwerken ----------
	local function heeftLaatste(): boolean
		for _ in laatste do return true end
		return false
	end

	function ververs()
		for key, v in vakjes do
			local bedrag = inzetten[key]
			v.fiche.Visible = bedrag ~= nil and bedrag > 0
			-- rlRenderBets toont een rond bedrag zonder centen; alleen een half fiche
			-- krijgt de twee decimalen erbij.
			v.fiche.Text = if bedrag then (if bedrag % 1 == 0 then string.format("%d", bedrag) else Money.fmt(bedrag)) else ""
			-- Het vak met een fiche erop moet boven zijn buren liggen, anders verdwijnt
			-- het fiche onder het volgende vak.
			v.knop.ZIndex = if v.fiche.Visible then 2 else 1
		end
		totaalLabel.Text = "$" .. Money.fmt(telOp())
		UI.setEnabled(draaien, not bezig)
		UI.setEnabled(wissen, not bezig and telOp() > 0)
		UI.setEnabled(herhalen, not bezig and heeftLaatste())
		groep.GroupTransparency = if bezig then 0.3 else 0   -- .rl-locked opacity 0.7
		for _, v in vakjes do
			v.knop.Active = not bezig
		end
	end

	local function leegmaken()
		for key in inzetten do
			inzetten[key] = nil
		end
		ververs()
	end

	wissen.Activated:Connect(function()
		if bezig then return end
		leegmaken()
	end)

	herhalen.Activated:Connect(function()
		if bezig then return end
		local totaal = 0
		for _, b in laatste do totaal += b end
		if totaal <= 0 then return end
		if totaal > Common.balance() - telOp() + 1e-9 then
			Common.toast("NOT ENOUGH BALANCE", "red")
			return
		end
		for k, b in laatste do
			inzetten[k] = Money.round2((inzetten[k] or 0) + b)
		end
		ververs()
	end)

	-- ---------- draaien ----------
	-- De uitslag staat vast zodra de server geantwoord heeft; het rad laat hem alleen zien.
	-- Dezelfde beweging als in de webversie: vijf tot zeven slagen van het rad, acht tot tien
	-- van de bal de andere kant op, in 4,2 seconde met een cubic-out.
	local function toonUitslag(n: number?)
		if n == nil then
			bol.Text = "\u{2026}"
			bol.BackgroundTransparency = 1
			bol.TextColor3 = Theme.color.muted
			bolRand.Color = Theme.color.border
			return
		end
		local k = Odds.rouletteColor(n)
		bol.Text = tostring(n)
		bol.BackgroundTransparency = 0
		bol.TextColor3 = Theme.color.white
		if k == "red" then
			bol.BackgroundColor3 = ROOD
			bolRand.Color = RES_ROOD_RAND
		elseif k == "black" then
			bol.BackgroundColor3 = RES_ZWART
			bolRand.Color = RES_ZWART_RAND
		else
			bol.BackgroundColor3 = GROEN
			bolRand.Color = Theme.color.neon
		end
	end

	draaien.Activated:Connect(function()
		if bezig then return end
		local inzet = telOp()
		if inzet < Money.MIN_BET then
			Common.toast("PLACE A BET FIRST", "red")
			return
		end

		laatste = {}
		local kopie: { [string]: number } = {}
		for k, v in inzetten do
			laatste[k] = v
			kopie[k] = v
		end
		bezig = true
		for _, v in vakjes do
			v.win = false                -- de winnaars van de vorige ronde doven
			v.gloed.Transparency = 1
		end
		ververs()
		toonUitslag(nil)

		local res = Common.call("Bet", "roulette", kopie)
		if not res then
			bezig = false
			toonUitslag(geschiedenis[1])
			ververs()
			return
		end

		local plek = (table.find(Odds.ROULETTE_ORDER, res.number) or 1) - 1
		local start = ring.Rotation % 360
		local doel = -(plek + 0.5) * STAP               -- dat vak recht onder de naald
		local slagen = 5 + math.random(0, 2)
		local eind = start + 360 * slagen + ((doel - start) % 360 + 360) % 360
		local balSlagen = 8 + math.random(0, 2)
		local duur = 4.2

		ring.Rotation = start
		local t0 = os.clock()
		while true do
			local t = math.min(1, (os.clock() - t0) / duur)
			local e = 1 - (1 - t) ^ 3
			ring.Rotation = start + (eind - start) * e
			zetBal(-90 - 360 * balSlagen * e, 0.93 - 0.16 * math.max(0, (t - 0.55) / 0.45))
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		ring.Rotation = eind % 360

		toonUitslag(res.number)
		table.insert(geschiedenis, 1, res.number)
		if #geschiedenis > 12 then table.remove(geschiedenis) end
		toonGeschiedenis()

		-- De winnende vakken krijgen hun gouden ring, net als .rl-cell.win.
		for key in inzetten do
			local v = vakjes[key]
			if v and Odds.roulettePayout(key, res.number) > 0 then
				v.win = true
				v.gloed.Transparency = 0
			end
		end

		local netto = Money.round2(res.payout - inzet)
		laatsteLabel.Text = (if netto >= 0 then "+$" else "-$") .. Money.fmt(math.abs(netto))
		laatsteLabel.TextColor3 = if netto >= 0 then Theme.color.neon else Theme.color.red

		local naam = string.upper(res.color)
		if res.payout > 0 then
			Common.toast(res.number .. " " .. naam .. " \u{00B7} +$" .. Money.fmt(res.payout), if netto >= 0 then "green" else "gold")
		else
			Common.toast(res.number .. " " .. naam .. " \u{00B7} -$" .. Money.fmt(inzet), "red")
		end

		bezig = false
		leegmaken()
	end)

	ververs()
end

return Roulette
]],
	["Scratch"] = [[
--!strict
-- Krasloten: negen vakjes die je één voor één openkrast. De server houdt de symbolen vast
-- tot je een vakje aanraakt, dus je kunt niet vooruit kijken -- en de rand blijft grijs tot
-- het hele lot open ligt, zodat de spanning erin blijft.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Scratch = {}

function Scratch.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "SCRATCH CARDS")

	local kaart = UI.panel(bord, "Card")
	UI.list(kaart, 10)
	UI.panelTitle(kaart, "scratch card")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = kaart
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 96, 0, 96)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = raster

	local balk = Common.banner(kaart)
	balk.set("BUY A CARD", nil)

	local vakjes: { TextButton } = {}
	local randen: { UIStroke } = {}
	local actief = false
	local open = 0
	local krasAlles: TextButton

	local function zetVak(i: number, tekst: string, opgekrast: boolean)
		local b = vakjes[i]
		b.Text = tekst
		b.BackgroundColor3 = if opgekrast then Theme.color.panelLight else Theme.color.bg
		b.TextTransparency = if opgekrast then 0 else 1
		randen[i].Color = Theme.color.border
	end

	local function kras(i: number)
		if not actief then return end
		local res = Common.call("Act", "scratch", i)
		if not res then return end
		open += 1
		zetVak(i, res.symbol, true)
		if not res.done then
			balk.set(open .. " / " .. Odds.SCRATCH_CELLS .. " REVEALED", nil)
			return
		end

		-- Pas nu mag de kaart verklappen of er gewonnen is.
		actief = false
		krasAlles.Visible = false
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 15 then "gold" else "green")
			for j = 1, Odds.SCRATCH_CELLS do
				randen[j].Color = Theme.color.neon
			end
		else
			balk.set("NO MATCH", "red")
		end
	end

	for i = 1, Odds.SCRATCH_CELLS do
		local b = Instance.new("TextButton")
		b.Name = "Cell" .. i
		b.Text = ""
		b.Font = Theme.font.ui
		b.TextSize = 40
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.bg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.button)
		randen[i] = UI.stroke(b, Theme.color.border)
		b.Parent = raster
		b.Activated:Connect(function()
			kras(i)
		end)
		vakjes[i] = b
	end

	-- ---------- de bediening ----------
	local tabel = UI.panel(bediening, "Paytable")
	UI.list(tabel, 4)
	UI.panelTitle(tabel, "three of a kind pays")
	for _, p in Odds.SCRATCH_PRIZES do
		Common.statRow(tabel, p.sym .. p.sym .. p.sym, Money.fmt(p.mult) .. "\u{00D7}")
	end

	local betBox = Common.betBox(bediening, 10)
	local kopen = UI.primary(bediening, "BUY CARD")
	krasAlles = UI.secondary(bediening, "REVEAL ALL")
	krasAlles.Visible = false

	kopen.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "scratch", betBox.get())
		if not res then return end
		actief = true
		open = 0
		krasAlles.Visible = true
		for i = 1, Odds.SCRATCH_CELLS do
			zetVak(i, "", false)
		end
		balk.set("SCRATCH THE SQUARES", nil)
	end)

	krasAlles.Activated:Connect(function()
		if not actief then return end
		for i = 1, Odds.SCRATCH_CELLS do
			if actief and vakjes[i].TextTransparency == 1 then
				kras(i)
				task.wait(0.08)
			end
		end
	end)
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "scratch")
	Common.oddsPanel(bediening, "odds", "Nine cells; three matching symbols pay. The card is fixed the moment you buy it, so scratching only reveals what was already drawn. RTP 97%, chance of a prize 21.6%.")

end

return Scratch
]],
	["Slots"] = [[
--!strict
-- 777: drie rollen die uitrollen en dan stilvallen. De uitslag komt van de server; het
-- rollen is alleen het wachten aankleden.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Slots = {}

function Slots.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "777")

	local kast = UI.panel(bord, "Machine")
	UI.list(kast, 10)
	UI.panelTitle(kast, "777")

	local rollen = Instance.new("Frame")
	rollen.Size = UDim2.new(1, 0, 0, 160)
	rollen.BackgroundTransparency = 1
	rollen.Parent = kast
	local rollenLayout = UI.list(rollen, 10, Enum.FillDirection.Horizontal)
	rollenLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rollenLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local vensters: { TextLabel } = {}
	for i = 1, 3 do
		local venster = Instance.new("Frame")
		venster.Size = UDim2.fromOffset(110, 150)
		venster.BackgroundColor3 = Theme.color.bg
		venster.BorderSizePixel = 0
		venster.LayoutOrder = i
		UI.corner(venster, Theme.radius.card)
		UI.stroke(venster, Theme.color.border)
		venster.Parent = rollen

		local sym = UI.label(venster, Odds.SLOT_SYMBOLS[1], {
			size = 56, align = Enum.TextXAlignment.Center,
		})
		sym.Size = UDim2.fromScale(1, 1)
		sym.TextYAlignment = Enum.TextYAlignment.Center
		vensters[i] = sym
	end

	local balk = Common.banner(kast)
	balk.set("PULL THE LEVER", nil)

	-- De uitbetalingstabel, met dezelfde regels als slotPayout in Odds.
	local tabel = UI.panel(bediening, "Paytable")
	UI.list(tabel, 4)
	UI.panelTitle(tabel, "paytable")
	for _, p in Odds.SLOT_PRIZES do
		local naam = if p.kind == "triple" then p.sym .. p.sym .. p.sym else p.sym .. p.sym .. " \u{00B7} any"
		Common.statRow(tabel, naam, Money.fmt(p.mult) .. "\u{00D7}")
	end

	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "SPIN")

	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "SPINNING..."
		betBox.lock(true)
		balk.set("...", nil)

		local res = Common.call("Bet", "slots", betBox.get())
		if not res then
			bezig = false
			knop.Text = "SPIN"
			betBox.lock(false)
			balk.set("PULL THE LEVER", nil)
			return
		end

		-- De rollen vallen van links naar rechts stil; dat is de hele spanning.
		local klaar = { false, false, false }
		local eind = { 0.6, 1.0, 1.4 }
		local start = os.clock()
		while true do
			local t = os.clock() - start
			local alles = true
			for i = 1, 3 do
				if t >= eind[i] then
					if not klaar[i] then
						klaar[i] = true
						vensters[i].Text = res.reels[i]
					end
				else
					alles = false
					vensters[i].Text = Odds.SLOT_SYMBOLS[math.random(#Odds.SLOT_SYMBOLS)]
				end
			end
			if alles then break end
			task.wait(0.06)
		end

		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 15 then "gold" else "green")
		else
			balk.set("NO WIN", "red")
		end
		bezig = false
		knop.Text = "SPIN"
		betBox.lock(false)
	end)
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "slots")
	Common.oddsPanel(bediening, "odds", "The result is drawn before the reels stop; the animation only shows it. RTP 97%, chance of a prize 17%.")

end

return Slots
]],
	["Tower"] = [[
--!strict
-- Dragon Tower: negen verdiepingen omhoog, per verdieping één tegel kiezen. De indeling
-- staat op de server; de client weet pas wat er onder een tegel zat als hij hem aanraakt.
--
-- Het beeld komt regel voor regel uit de webversie: `#towerView` in de markup en
-- `.tower`, `.tower-row`, `.tower-mult`, `.tower-tiles` en `.tile` in de CSS. De negen
-- rijen staan onder elkaar met de bovenste verdieping bovenaan, de multiplier staat links
-- in een kolom van 76 pixels, en daarnaast liggen de twee tot vier tegels van 44 hoog.
--
-- Wat Roblox niet heeft: letter-spacing (de 1px uit `.tower-mult` is weggelaten), de
-- box-shadow van een aangeklikte tegel (hier een gouden rand van 2) en het optillen van een
-- tegel bij hover (de lijstindeling bepaalt de positie, dus daar blijft de neonrand over).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Tower = {}

-- De volgorde van de knoppenbalk in de markup: EASY / MED / HARD / EXP / MSTR.
local MOEILIJK = { "easy", "medium", "hard", "expert", "master" }
local KORT = {
	easy = "EASY", medium = "MED", hard = "HARD", expert = "EXP", master = "MSTR",
}

-- ---------- maten uit de CSS ----------
local TOREN_B = 540        -- .tower max-width
local RIJ_GAT = 6          -- .tower gap
local MULT_KOL = 76        -- .tower-row grid-template-columns: 76px 1fr
local KOL_GAT = 10         -- .tower-row gap
local TEGEL_H = 44         -- .tile height
local TEGEL_GAT = 6        -- .tower-tiles gap
local TOREN_H = Odds.TOWER_LEVELS * TEGEL_H + (Odds.TOWER_LEVELS - 1) * RIJ_GAT

-- .tower-row opacity: 0.4 gewoon, 0.85 als de verdieping gehaald is, 1 als hij aan de
-- beurt is. Een CanvasGroup kan dat als geheel, net zoals de browser dat met opacity doet.
local RIJ_DOF = 0.6
local RIJ_KLAAR = 0.15
local RIJ_AAN = 0

-- .tile: background rgba(0,0,0,0.5); .tile.gem rgba(62,207,142,0.16); .tile.egg
-- rgba(224,97,110,0.16). En .tile.dim is opacity 0.45.
local VULLING = 0.84
local DOF = 0.55

local STREEP = Color3.fromHex("1a3a1a")   -- .payout-line border-bottom
local GOUD_DONKER = Color3.fromHex("cc9900")  -- .btn-cashout, het eind van het verloop

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .field-label: de naam links, de hint in neon rechts. Geeft de hint terug, want die
-- verandert mee met de moeilijkheid ("2 of 3 safe").
local function veldKop(ouder: Instance, naam: string, hint: string): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted })
	local h = UI.label(rij, hint, {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
		name = "Hint",
	})
	h.TextTransparency = 0.3    -- .field-label .hint opacity 0.7
	return h
end

-- .payout-line: naam links, waarde rechts in het cijferlettertype, haarlijntje eronder.
local function payoutRegel(ouder: Instance, naam: string, kleur: Color3, orde: number): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, 28)   -- 11px tekst met padding 6 boven en onder
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
	rij.Parent = ouder

	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.text, name = "Key" })
	local v = UI.label(rij, "\u{2014}", {
		size = Theme.text.small, color = kleur, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Value",
	})

	local lijn = Instance.new("Frame")
	lijn.Name = "Rule"
	lijn.AnchorPoint = Vector2.new(0, 1)
	lijn.Position = UDim2.new(0, 0, 1, 0)
	lijn.Size = UDim2.new(1, 0, 0, 1)
	lijn.BackgroundColor3 = STREEP
	lijn.BackgroundTransparency = 0.5   -- rgba(26,58,26,0.5)
	lijn.BorderSizePixel = 0
	lijn.Parent = rij
	return v
end

function Tower.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "TOWER")

	-- ---------- het bord ----------
	-- `.tower`: een kolom van negen rijen, volle breedte tot 540 pixels.
	local toren = Instance.new("Frame")
	toren.Name = "Tower"
	toren.Size = UDim2.new(1, 0, 0, TOREN_H)
	toren.BackgroundTransparency = 1
	toren.Parent = bord
	UI.list(toren, RIJ_GAT)
	local breedte = Instance.new("UISizeConstraint")
	breedte.MaxSize = Vector2.new(TOREN_B, math.huge)
	breedte.Parent = toren

	-- ---------- de stand van de ronde ----------
	local diff = "easy"
	local actief = false
	local niveau = 0                                -- hoeveel verdiepingen gehaald zijn
	local inzet = 0                                 -- wat er in deze ronde op staat
	local over = false                              -- ronde afgelopen, het bord ligt open
	-- In de browser gebeurt een zet meteen; hier ligt er een vraag aan de server tussen. Een
	-- tweede klik binnen die wachttijd zou een tweede inzet doen of op de volgende
	-- verdieping landen, dus zolang er een antwoord onderweg is neemt het scherm niets aan.
	local bezig = false
	local keuzes: { [number]: number } = {}         -- per verdieping de aangeklikte tegel
	local rijen: { [number]: { boolean } } = {}     -- wat de server van een rij prijsgaf

	local teken: () -> ()

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, de moeilijkheid, de twee uitbetaalregels en de
	-- knoppen in één `.panel`. Common.betBox maakt dat paneel, dus de rest gaat erbij in.
	-- De volgorde in de aside komt uit de volgorde van toevoegen; de LayoutOrder hieronder
	-- geldt alleen bínnen dit paneel, waar het inzetveld op nul staat en dus voorop blijft.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel

	-- .field-group met de knoppenbalk. De 8 boven is de margin-bottom van het
	-- inzetveld erboven, de 8 onder die van deze groep zelf (14 min de 6 uit de lijst).
	local diffVeld = Instance.new("Frame")
	diffVeld.Name = "DifficultyField"
	diffVeld.Size = UDim2.new(1, 0, 0, 0)
	diffVeld.AutomaticSize = Enum.AutomaticSize.Y
	diffVeld.BackgroundTransparency = 1
	diffVeld.LayoutOrder = 10
	diffVeld.Parent = paneel
	UI.list(diffVeld, 6)
	UI.padding4(diffVeld, 8, 0, 8, 0)

	local hint = veldKop(diffVeld, "DIFFICULTY", Odds.TOWER_DIFF[diff].label)

	-- .seg: vijf gelijke knoppen met 4 pixels ertussen, de gekozene in neon.
	local seg = Instance.new("Frame")
	seg.Name = "Seg"
	seg.Size = UDim2.new(1, 0, 0, 30)   -- 11px tekst met padding 8 boven en onder
	seg.BackgroundTransparency = 1
	seg.Parent = diffVeld
	UI.list(seg, 4, Enum.FillDirection.Horizontal)

	local segKnoppen: { [string]: TextButton } = {}
	local segRanden: { [string]: UIStroke } = {}

	local function markeerSeg()
		for naam, b in segKnoppen do
			local aan = naam == diff
			local rand = segRanden[naam]
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			b.Font = if aan then Theme.font.uiBold else Theme.font.ui
			rand.Color = if aan then Theme.color.neon else Theme.color.border
			-- .seg button:disabled { opacity: 0.4 } zolang er een ronde loopt.
			local vol = if aan then 0 else Theme.alpha.buttonBg
			b.Active = not actief
			b.BackgroundTransparency = if actief then math.min(1, vol + 0.4) else vol
			b.TextTransparency = if actief then 0.6 else 0
			rand.Transparency = if actief then 0.6 else 0
		end
		hint.Text = Odds.TOWER_DIFF[diff].label
	end

	for i, naam in MOEILIJK do
		local b = Instance.new("TextButton")
		b.Name = "Seg" .. naam
		b.Text = KORT[naam]
		b.Font = Theme.font.ui
		b.TextSize = Theme.text.tiny
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.new(0.2, -3.2, 1, 0)   -- vijf kolommen met vier keer 4 pixels lucht
		b.RichText = false
		UI.corner(b, Theme.radius.chip)
		local rand = UI.stroke(b, Theme.color.border)
		b.MouseEnter:Connect(function()
			if diff ~= naam and not actief then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if diff == naam then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			if actief then return end
			diff = naam
			teken()
		end)
		b.Parent = seg
		segKnoppen[naam] = b
		segRanden[naam] = rand
	end

	local huidigLabel = payoutRegel(paneel, "CURRENT WIN", Theme.color.neon, 11)
	local volgendLabel = payoutRegel(paneel, "NEXT FLOOR", Theme.color.gold, 12)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local startKnop = UI.primary(paneel, "START THE CLIMB")
	startKnop.LayoutOrder = 13
	startKnop.Font = Theme.font.uiBold
	UI.gradient(startKnop, Theme.color.neon, Theme.color.neonDim, 135)

	-- .btn-primary.btn-cashout: goud, en hij klopt één keer per seconde. Die klop is in de
	-- CSS een box-shadow; hier is het een gouden rand die op en neer gaat.
	local uitKnop = UI.primary(paneel, "CASH OUT")
	uitKnop.LayoutOrder = 14
	uitKnop.Font = Theme.font.uiBold
	uitKnop.BackgroundColor3 = Theme.color.gold
	uitKnop.TextColor3 = Theme.color.bg
	uitKnop.Visible = false
	UI.gradient(uitKnop, Theme.color.gold, GOUD_DONKER, 135)
	local klopRand = UI.stroke(uitKnop, Theme.color.gold, 2)
	klopRand.Transparency = 1
	local klop = TweenService:Create(
		klopRand,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.5 }   -- rgba(224,181,85,0.5) uit @keyframes pulse-gold
	)

	-- Het verloop uit .btn-bet en .btn-cashout blijft staan, dus de hover van UI.primary
	-- zou niets doen; de knoppen houden hun kleur en dat is precies wat de CSS ook doet.

	-- ---------- de tegels ----------
	local tegels: { { TextButton } } = {}
	local multLabels: { TextLabel } = {}
	local rijGroepen: { CanvasGroup } = {}

	local function kies(r: number, k: number)
		if bezig or not actief or r ~= niveau + 1 then return end
		bezig = true
		local res = Common.call("Act", "tower", k)
		bezig = false
		if not res then return end
		keuzes[r] = k

		if not res.safe then
			rijen[r] = res.row
			actief = false
			over = true
			teken()
			Common.toast("DRAGON EGG! -$" .. Money.fmt(inzet), "red")
			return
		end

		if res.done then
			-- De negende verdieping rekent de server meteen af, net als twPick() in de
			-- webversie, die daar zelf twCashOut() aanroept.
			rijen[r] = res.row
			niveau = Odds.TOWER_LEVELS
			actief = false
			over = true
			teken()
			Common.toast("+$" .. Money.fmt(res.payout) .. " @ " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			return
		end

		niveau = res.level
		teken()
	end

	-- Eén tegel in de vorm die bij zijn toestand hoort. De webversie kent de hele indeling
	-- en legt aan het eind alles open; hier houdt de server de rijen achter, dus een
	-- verdieping gaat alleen open als de server hem meestuurt -- bij een ei, en bovenaan.
	local function kleedTegel(b: TextButton, rand: UIStroke, r: number, k: number)
		local gekozen = keuzes[r] == k
		local rij = rijen[r]
		local veilig: boolean? = nil
		if rij then
			veilig = rij[k]
		elseif r <= niveau and gekozen then
			veilig = true   -- deze tegel hebben we zelf aangeraakt en die hield stand
		end

		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.TextColor3 = Theme.color.text
		b.TextTransparency = 0
		rand.Color = Theme.color.border
		rand.Thickness = 1
		rand.Transparency = 0
		b.Active = false

		if veilig ~= nil then
			local kleur = if veilig then Theme.color.neon else Theme.color.red
			b.Text = if veilig then "\u{25C6}" else "\u{1F95A}"   -- ◆ en het drakenei
			b.TextColor3 = kleur
			b.BackgroundColor3 = kleur
			b.BackgroundTransparency = VULLING
			rand.Color = kleur
			if gekozen then
				-- .tile.picked: box-shadow 0 0 0 2px var(--gold), hier een dikke gouden rand.
				rand.Color = Theme.color.gold
				rand.Thickness = 2
			else
				-- .tile.dim: alles wat je niet zelf aanwees blijft op de achtergrond.
				b.TextTransparency = DOF
				rand.Transparency = DOF
				b.BackgroundTransparency = VULLING + (1 - VULLING) * DOF
			end
		elseif actief and r == niveau + 1 then
			b.Text = "?"
			b.Active = true
		else
			b.Text = "\u{00B7}"
			if r <= niveau then
				b.TextTransparency = DOF
				rand.Transparency = DOF
			end
		end
	end

	-- De toren opnieuw opbouwen. Dat gebeurt alleen als het aantal tegels verandert; bij
	-- een zet blijven de knoppen staan en krijgen ze alleen een andere jas.
	local function bouwRijen()
		for _, kind in toren:GetChildren() do
			if kind:IsA("CanvasGroup") then kind:Destroy() end
		end
		table.clear(tegels)
		table.clear(multLabels)
		table.clear(rijGroepen)

		local d = Odds.TOWER_DIFF[diff]
		for r = Odds.TOWER_LEVELS, 1, -1 do
			-- De bovenste verdieping bovenaan, dus van negen naar één.
			local groep = Instance.new("CanvasGroup")
			groep.Name = "Row" .. r
			groep.Size = UDim2.new(1, 0, 0, TEGEL_H)
			groep.BackgroundTransparency = 1
			groep.BorderSizePixel = 0
			groep.LayoutOrder = Odds.TOWER_LEVELS - r
			groep.Parent = toren

			local mult = UI.label(groep, Money.fmt(Odds.towerMultiplier(diff, r)) .. "\u{00D7}", {
				size = Theme.text.tiny, color = Theme.color.gold,
				align = Enum.TextXAlignment.Right, name = "Mult",
			})
			mult.Size = UDim2.new(0, MULT_KOL, 1, 0)

			local vak = Instance.new("Frame")
			vak.Name = "Tiles"
			vak.Position = UDim2.fromOffset(MULT_KOL + KOL_GAT, 0)
			vak.Size = UDim2.new(1, -(MULT_KOL + KOL_GAT), 1, 0)
			vak.BackgroundTransparency = 1
			vak.Parent = groep
			UI.list(vak, TEGEL_GAT, Enum.FillDirection.Horizontal)

			local kolom: { TextButton } = {}
			for k = 1, d.tiles do
				local b = Instance.new("TextButton")
				b.Name = "T" .. r .. "_" .. k
				b.Text = "\u{00B7}"
				b.Font = Theme.font.ui
				b.TextSize = 18                  -- .tile font-size
				b.TextColor3 = Theme.color.text
				b.BackgroundColor3 = Theme.color.black
				b.BackgroundTransparency = Theme.alpha.buttonBg
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				b.Active = false
				b.LayoutOrder = k
				b.RichText = false
				b.Size = UDim2.new(1 / d.tiles, -TEGEL_GAT * (d.tiles - 1) / d.tiles, 1, 0)
				UI.corner(b, Theme.radius.panel)   -- .tile border-radius 4
				local rand = UI.stroke(b, Theme.color.border)
				b.MouseEnter:Connect(function()
					if b.Active then rand.Color = Theme.color.neon end
				end)
				b.MouseLeave:Connect(function()
					if b.Active then rand.Color = Theme.color.border end
				end)
				b.Activated:Connect(function()
					kies(r, k)
				end)
				b.Parent = vak
				kolom[k] = b
			end
			tegels[r] = kolom
			multLabels[r] = mult
			rijGroepen[r] = groep
		end
	end

	-- Alles bijwerken wat van de stand afhangt: de rijen, de bediening en de twee regels.
	function teken()
		local d = Odds.TOWER_DIFF[diff]
		if #tegels ~= Odds.TOWER_LEVELS or #(tegels[1] :: { TextButton }) ~= d.tiles then
			bouwRijen()
		end

		for r = 1, Odds.TOWER_LEVELS do
			local groep = rijGroepen[r]
			local aanBeurt = actief and r == niveau + 1
			local gehaald = r <= niveau
			-- Voor de start staat de hele toren vol in beeld, precies als in twRender().
			groep.GroupTransparency = if aanBeurt or (not actief and not over) then RIJ_AAN
				elseif gehaald then RIJ_KLAAR
				else RIJ_DOF

			local mult = multLabels[r]
			mult.Text = Money.fmt(Odds.towerMultiplier(diff, r)) .. "\u{00D7}"
			-- .tower-row.active .tower-mult: het cijferlettertype, en neon in plaats van goud.
			mult.Font = if aanBeurt then Theme.font.num else Theme.font.ui
			mult.TextColor3 = if aanBeurt then Theme.color.neon else Theme.color.gold

			for k, b in tegels[r] do
				local rand = b:FindFirstChildOfClass("UIStroke")
				if rand then kleedTegel(b, rand, r, k) end
			end
		end

		markeerSeg()
		betBox.lock(actief)
		startKnop.Visible = not actief
		uitKnop.Visible = actief

		if actief then
			local mult = Odds.towerMultiplier(diff, niveau)
			local nu = Money.floor2(inzet * mult)
			huidigLabel.Text = if niveau > 0
				then "$" .. Money.fmt(nu) .. " (" .. Money.fmt(mult) .. "\u{00D7})"
				else "\u{2014}"
			volgendLabel.Text = Money.fmt(Odds.towerMultiplier(diff, niveau + 1)) .. "\u{00D7}"
			uitKnop.Text = if niveau > 0 then "CASH OUT $" .. Money.fmt(nu) else "PICK A TILE"
			-- Uitstappen kan pas als er een verdieping staat; tot dan is de knop dood.
			UI.setEnabled(uitKnop, niveau > 0)
			uitKnop.BackgroundTransparency = if niveau > 0 then 0 else 0.4
			if niveau > 0 then
				klop:Play()
			else
				klop:Pause()
				klopRand.Transparency = 1
			end
		else
			huidigLabel.Text = "\u{2014}"
			volgendLabel.Text = Money.fmt(Odds.towerMultiplier(diff, 1)) .. "\u{00D7}"
			klop:Pause()
			klopRand.Transparency = 1
		end
	end

	startKnop.Activated:Connect(function()
		if bezig or actief then return end
		local bedrag = betBox.get()
		bezig = true
		local res = Common.call("Bet", "tower", bedrag, diff)
		bezig = false
		if not res then return end
		inzet = bedrag
		actief = true
		over = false
		niveau = 0
		table.clear(keuzes)
		table.clear(rijen)
		teken()
	end)

	uitKnop.Activated:Connect(function()
		if bezig or not actief or niveau < 1 then return end
		bezig = true
		local res = Common.call("CashOut", "tower")
		bezig = false
		if not res then return end
		actief = false
		over = true
		teken()
		Common.toast("+$" .. Money.fmt(res.payout) .. " @ " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
	end)

	-- De eerste teken() bouwt de rijen meteen op; daarna gebeurt dat alleen nog als de
	-- moeilijkheid een ander aantal tegels per verdieping vraagt.
	teken()

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "tower")
	Common.oddsPanel(bediening, "odds", "Every floor has fixed odds. Multiplier = 0.97 x (tiles / safe)^floor, so RTP 97% at every point you cash out. The whole tower is fixed before your first click.")
end

return Tower
]],
	["Vip"] = [[
--!strict
-- De VIP-zone. Wie een sprint van drie dagen op nummer één afsluit, mag het hele seizoen
-- naar binnen: twee spellen die nergens anders in het casino staan.
--
-- De poort staat op de server, bij de spellen zelf. Dit scherm laat alleen zien of hij open
-- is; de knoppen uitzetten is netjes, maar het is niet wat je tegenhoudt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Vip = {}

local PERKS = {
	{ "\u{1F3B0}", "777", "Three reels. Three sevens pay 40x. Nowhere else in the casino." },
	{ "\u{1F68C}", "Ride the Bus", "Four calls through a shuffled deck, cash out after any of them." },
	{ "\u{1F39F}", "Four ways in", "Every three-day sprint crowns a new number one, so a season has four." },
}

local KAARTEN = {
	{ id = "slots", label = "777", desc = "Three reels, three sevens pay 40x.",
	  van = Color3.fromHex("4a3a12"), tot = Color3.fromHex("1e1707") },
	{ id = "bus", label = "RIDE THE BUS", desc = "Four calls through one deck.",
	  van = Color3.fromHex("2a3550"), tot = Color3.fromHex("141a28") },
}

function Vip.build(ouder: Instance, ga: (string) -> ()): (any) -> ()
	local blad = Common.sheet(ouder)

	-- ---------- de poort ----------
	local poort = UI.panel(blad, "Gate")
	UI.list(poort, 6)
	local slot = UI.label(poort, "\u{1F512}", { size = 40, align = Enum.TextXAlignment.Center })
	slot.Size = UDim2.new(1, 0, 0, 46)

	local kop = UI.label(poort, "THE ZONE IS CLOSED", {
		size = Theme.text.big, color = Theme.color.gold, font = Theme.font.uiMed,
		align = Enum.TextXAlignment.Center,
	})
	kop.Size = UDim2.new(1, 0, 0, 28)

	local onder = UI.label(poort, "\u{25BA} FINISH A SPRINT AT #1 AND THE ZONE IS YOURS FOR THE SEASON", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
	})
	onder.TextWrapped = true
	onder.Size = UDim2.new(1, 0, 0, 30)

	local klok = UI.label(poort, "", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
	})

	-- ---------- wat je ermee krijgt ----------
	local voordelen = UI.panel(blad, "Perks")
	UI.list(voordelen, 6)
	UI.panelTitle(voordelen, "what a pass gets you")
	for _, perk in PERKS do
		local rij = Instance.new("Frame")
		rij.Size = UDim2.new(1, 0, 0, 36)
		rij.BackgroundTransparency = 1
		rij.Parent = voordelen

		local ic = UI.label(rij, perk[1], { size = 22, align = Enum.TextXAlignment.Center })
		ic.Size = UDim2.fromOffset(30, 30)

		local t = UI.label(rij, perk[2], {
			size = Theme.text.small, color = Theme.color.gold, font = Theme.font.uiMed,
		})
		t.Position = UDim2.new(0, 36, 0, 0)
		t.Size = UDim2.new(1, -40, 0, 16)

		local d = UI.label(rij, perk[3], { size = Theme.text.tiny, color = Theme.color.muted })
		d.Position = UDim2.new(0, 36, 0, 16)
		d.Size = UDim2.new(1, -40, 0, 18)
	end

	-- ---------- de twee spellen ----------
	local spellen = UI.panel(blad, "Games")
	UI.list(spellen, 6)
	UI.panelTitle(spellen, "vip games")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = spellen
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 250, 0, 150)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = raster

	local kaartRanden: { UIStroke } = {}
	local kaartSloten: { TextLabel } = {}

	for i, k in KAARTEN do
		local f = Instance.new("Frame")
		f.Name = k.id
		f.BackgroundColor3 = Theme.color.panel
		f.BorderSizePixel = 0
		f.LayoutOrder = i
		UI.corner(f, Theme.radius.card)
		kaartRanden[i] = UI.stroke(f, Theme.color.border)
		f.Parent = raster

		local beeld = Instance.new("Frame")
		beeld.Size = UDim2.new(1, 0, 0, 78)
		beeld.BackgroundColor3 = k.van
		beeld.BorderSizePixel = 0
		beeld.Parent = f
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(k.van, k.tot)
		g.Rotation = 90
		g.Parent = beeld
		UI.corner(beeld, Theme.radius.card)

		local body = Instance.new("Frame")
		body.Position = UDim2.new(0, 0, 0, 78)
		body.Size = UDim2.new(1, 0, 1, -78)
		body.BackgroundTransparency = 1
		body.Parent = f
		UI.padding(body, 10)
		UI.list(body, 4)
		UI.label(body, k.label, { size = Theme.text.label, color = Theme.color.gold, font = Theme.font.uiMed })
		local d = UI.label(body, k.desc, { size = Theme.text.tiny, color = Theme.color.muted })
		d.TextWrapped = true
		d.Size = UDim2.new(1, 0, 0, 28)

		local hangslot = UI.label(f, "\u{1F512}", { size = 26, align = Enum.TextXAlignment.Center })
		hangslot.AnchorPoint = Vector2.new(0.5, 0.5)
		hangslot.Position = UDim2.fromScale(0.5, 0.26)
		hangslot.Size = UDim2.fromOffset(40, 40)
		hangslot.ZIndex = 4
		kaartSloten[i] = hangslot

		local knop = Instance.new("TextButton")
		knop.Text = ""
		knop.BackgroundTransparency = 1
		knop.Size = UDim2.fromScale(1, 1)
		knop.ZIndex = 5
		knop.Parent = f
		knop.Activated:Connect(function()
			if hangslot.Visible then
				Common.toast("VIP PASS REQUIRED", "red")
				return
			end
			ga(k.id)
		end)
	end

	local function zetPoort(open: boolean, tot: number?, nu: number?)
		slot.Text = if open then "\u{1F511}" else "\u{1F512}"
		kop.Text = if open then "THE ZONE IS OPEN" else "THE ZONE IS CLOSED"
		kop.TextColor3 = if open then Theme.color.neon else Theme.color.gold
		onder.Text = if open
			then "\u{25BA} YOUR PASS RUNS UNTIL THE END OF THIS SEASON"
			else "\u{25BA} FINISH A SPRINT AT #1 AND THE ZONE IS YOURS FOR THE SEASON"
		klok.Text = if open and tot then "PASS EXPIRES IN " .. Season.countdown(tot, nu) else ""
		for i = 1, #KAARTEN do
			kaartSloten[i].Visible = not open
			kaartRanden[i].Color = if open then Theme.color.gold else Theme.color.border
		end
	end

	zetPoort(false)

	-- De server zegt of de pas geldt; de klok komt er bij de ranglijst mee.
	task.spawn(function()
		while true do
			local res = Common.call("Leaderboard")
			if res then
				zetPoort(res.vipActive == true, res.seasonEndsAt, res.now)
			end
			task.wait(30)
		end
	end)

	return function(p: any)
		if typeof(p) ~= "table" then return end
		-- Het profiel draagt het seizoen van de pas; dat is genoeg om het scherm meteen
		-- goed te zetten zonder op de ranglijst te wachten.
		zetPoort(Season.vipActive(tonumber(p.vipSeason)), nil, nil)
	end
end

return Vip
]],
	["Wheel"] = [[
--!strict
-- Rad van fortuin: twintig even grote vakken, één betaalt tien keer. De ring draait en de
-- naald blijft staan, net als bij roulette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Wheel = {}

-- Dezelfde kleurcodes als de webversie: hoe hoger de multiplier, hoe warmer het vak.
local function kleurVan(m: number): Color3
	if m >= 10 then return Theme.color.gold end
	if m >= 2 then return Theme.color.neon end
	if m > 0 then return Color3.fromHex("2d6f52") end
	return Color3.fromHex("222a33")
end

function Wheel.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "WHEEL")

	local vak = UI.panel(bord, "Wheel")
	UI.list(vak, 8)
	UI.panelTitle(vak, "wheel of fortune")

	local houder = Instance.new("Frame")
	houder.Size = UDim2.new(1, 0, 0, 260)
	houder.BackgroundTransparency = 1
	houder.Parent = vak

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = houder

	local straal = 110
	local vakjes: { TextLabel } = {}
	for i, m in Odds.WHEEL do
		local hoek = (i - 1) / #Odds.WHEEL * math.pi * 2 - math.pi / 2
		local v = Instance.new("TextLabel")
		v.AnchorPoint = Vector2.new(0.5, 0.5)
		v.Position = UDim2.new(0.5, math.cos(hoek) * straal, 0.5, math.sin(hoek) * straal)
		v.Size = UDim2.fromOffset(40, 26)
		v.BackgroundColor3 = kleurVan(m)
		v.BorderSizePixel = 0
		v.Text = if m > 0 then Money.fmt(m) .. "\u{00D7}" else "\u{2014}"
		v.Font = Theme.font.num
		v.TextSize = Theme.text.tiny
		v.TextColor3 = if m >= 2 then Theme.color.bg else Theme.color.muted
		v.RichText = false
		UI.corner(v, Theme.radius.chip)
		v.Parent = ring
		vakjes[i] = v
	end

	local naald = Instance.new("Frame")
	naald.AnchorPoint = Vector2.new(0.5, 1)
	naald.Position = UDim2.new(0.5, 0, 0.5, 0)
	naald.Size = UDim2.fromOffset(3, 84)
	naald.BackgroundColor3 = Theme.color.neon
	naald.BorderSizePixel = 0
	naald.ZIndex = 3
	naald.Parent = houder

	local groot = Common.bigNumber(vak, "\u{2014}", Theme.color.muted)
	local balk = Common.banner(vak)
	balk.set("SPIN THE WHEEL", nil)

	-- De uitbetalingstabel ernaast, zodat je ziet wat er in het rad zit.
	local tabel = UI.panel(bediening, "Paytable")
	UI.list(tabel, 4)
	UI.panelTitle(tabel, "paytable")
	local telling: { [number]: number } = {}
	for _, m in Odds.WHEEL do
		telling[m] = (telling[m] or 0) + 1
	end
	local soorten = {}
	for m in telling do table.insert(soorten, m) end
	table.sort(soorten, function(a, b) return a > b end)
	for _, m in soorten do
		local naam = if m > 0 then Money.fmt(m) .. "\u{00D7}" else "NOTHING"
		Common.statRow(tabel, naam, telling[m] .. " / " .. #Odds.WHEEL)
	end

	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "SPIN")

	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "SPINNING..."
		betBox.lock(true)

		local res = Common.call("Bet", "wheel", betBox.get())
		if not res then
			bezig = false
			knop.Text = "SPIN"
			betBox.lock(false)
			return
		end

		local hoek = -(res.slot - 1) / #Odds.WHEEL * 360
		ring.Rotation = ring.Rotation % 360 - 360 * 3
		local tw = TweenService:Create(ring, TweenInfo.new(2.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Rotation = 360 * 3 + hoek,
		})
		tw:Play()
		tw.Completed:Wait()

		groot.Text = if res.mult > 0 then Money.fmt(res.mult) .. "\u{00D7}" else "\u{2014}"
		groot.TextColor3 = kleurVan(res.mult)
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout), "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 10 then "gold" else "green")
		else
			balk.set("NO WIN", "red")
		end
		bezig = false
		knop.Text = "SPIN"
		betBox.lock(false)
	end)
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "wheel")
	Common.oddsPanel(bediening, "odds", "Twenty equal segments: one 10.00x, two 2.00x, two 1.50x, two 1.20x and thirteen blanks. Together 19.4 / 20 = RTP 97%.")

end

return Wheel
]],
	["Icons"] = [[
--!strict
-- De pictogrammen uit de zijbalk. In de webversie zijn dat lijntekeningen van 24 bij 24 met
-- een streekdikte van 1,8; losse tekens zagen er daarnaast uit als een noodoplossing.
--
-- Roblox kan geen paden tekenen, dus elk pictogram wordt opgebouwd uit dunne balkjes en
-- rondjes. Alles rekent in dezelfde 24x24 als de SVG, zodat de coördinaten uit crash.html
-- rechtstreeks over te nemen zijn. Wat een boog is in het origineel wordt hier een paar
-- korte segmenten -- op vierentwintig pixels ziet niemand het verschil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.Shared.UI)

local Icons = {}

local V = 24         -- viewBox
local STREEK = 1.8   -- stroke-width

function Icons.build(ouder: Instance, naam: string, maat: number): Frame
	local vak = Instance.new("Frame")
	vak.Name = "Icon"
	vak.Size = UDim2.fromOffset(maat, maat)
	vak.BackgroundTransparency = 1
	vak.Parent = ouder

	local schaal = maat / V
	local dikte = math.max(1, math.round(STREEK * schaal))

	local function lijn(x1: number, y1: number, x2: number, y2: number)
		local dx, dy = x2 - x1, y2 - y1
		local lengte = math.sqrt(dx * dx + dy * dy) * schaal
		local f = Instance.new("Frame")
		f.Name = "Stroke"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset((x1 + x2) / 2 * schaal, (y1 + y2) / 2 * schaal)
		f.Size = UDim2.fromOffset(math.max(lengte, dikte), dikte)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Rotation = math.deg(math.atan2(dy, dx))
		UI.corner(f, dikte / 2)
		f.Parent = vak
	end

	-- Een rondje: hol (alleen een rand) of vol.
	local function rond(cx: number, cy: number, r: number, vol: boolean?)
		local f = Instance.new("Frame")
		f.Name = "Stroke"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx * schaal, cy * schaal)
		f.Size = UDim2.fromOffset(r * 2 * schaal, r * 2 * schaal)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = if vol then 0 else 1
		f.BorderSizePixel = 0
		UI.corner(f, r * schaal)
		if not vol then
			UI.stroke(f, Color3.new(1, 1, 1), dikte)
		end
		f.Parent = vak
	end

	-- Een rechthoek met alleen een rand.
	local function kader(x: number, y: number, w: number, h: number, radius: number)
		local f = Instance.new("Frame")
		f.Name = "Stroke"
		f.Position = UDim2.fromOffset(x * schaal, y * schaal)
		f.Size = UDim2.fromOffset(w * schaal, h * schaal)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		UI.corner(f, radius * schaal)
		UI.stroke(f, Color3.new(1, 1, 1), dikte)
		f.Parent = vak
		return f
	end

	-- Een reeks punten aan elkaar: een gebroken lijn.
	local function boog(punten: { { number } })
		for i = 1, #punten - 1 do
			lijn(punten[i][1], punten[i][2], punten[i + 1][1], punten[i + 1][2])
		end
	end

	-- Een cirkelboog in stapjes, voor schouders en oren.
	local function arc(cx: number, cy: number, r: number, vanGraden: number, totGraden: number, stappen: number)
		local punten = {}
		for i = 0, stappen do
			local h = math.rad(vanGraden + (totGraden - vanGraden) * i / stappen)
			table.insert(punten, { cx + math.cos(h) * r, cy + math.sin(h) * r })
		end
		boog(punten)
	end

	if naam == "home" then
		boog({ {3, 12}, {12, 4}, {21, 12} })
		boog({ {5, 10}, {5, 20}, {19, 20}, {19, 10} })
	elseif naam == "crash" then
		lijn(3, 20, 20, 4)
		boog({ {14, 4}, {20, 4}, {20, 10} })
	elseif naam == "roulette" then
		rond(12, 12, 9)
		rond(12, 12, 4)
		lijn(12, 3, 12, 7)
		lijn(12, 17, 12, 21)
		lijn(3, 12, 7, 12)
		lijn(17, 12, 21, 12)
	elseif naam == "tower" then
		boog({ {12, 2}, {4, 7}, {4, 13} })
		arc(12, 13, 8, 180, 90, 5)
		arc(12, 13, 8, 0, 90, 5)
		boog({ {20, 13}, {20, 7}, {12, 2} })
		boog({ {9, 12}, {11, 14}, {15, 10} })
	elseif naam == "mines" then
		kader(4, 4, 16, 16, 2)
		for _, p in {{9, 9}, {15, 9}, {12, 12}, {9, 15}, {15, 15}} do
			rond(p[1], p[2], 1.5, true)
		end
	elseif naam == "plinko" then
		for _, p in {{6, 6}, {12, 6}, {18, 6}, {9, 12}, {15, 12}, {6, 18}, {12, 18}, {18, 18}} do
			rond(p[1], p[2], 1.5, true)
		end
	elseif naam == "blackjack" then
		kader(3, 5, 14, 18, 2)
		kader(7, 1, 14, 18, 2).BackgroundTransparency = 0.15
	elseif naam == "scratch" then
		kader(2, 6, 20, 12, 2)
		-- de gestippelde scheidingen worden hier korte streepjes
		for _, x in {8, 16} do
			for _, y in {7, 11, 15} do
				lijn(x, y, x, y + 2)
			end
		end
		lijn(11, 11, 13, 13)
		lijn(13, 11, 11, 13)
	elseif naam == "wheel" then
		rond(12, 13, 8)
		lijn(12, 5, 12, 21)
		lijn(4, 13, 20, 13)
		lijn(6.3, 7.3, 17.7, 18.7)
		lijn(17.7, 7.3, 6.3, 18.7)
	elseif naam == "slots" then
		-- 777 heeft in de webversie geen eigen pictogram: drie rollen naast elkaar.
		for _, x in {5, 10, 15} do
			kader(x, 5, 4, 14, 1)
		end
	elseif naam == "horse" then
		boog({ {4, 20}, {7, 12}, {11, 10}, {14, 5}, {17, 6}, {20, 10}, {18, 11}, {16, 9},
		       {15, 12}, {17, 16}, {15, 17}, {12, 12}, {8, 14}, {6, 20} })
	elseif naam == "bus" then
		-- ook zonder eigen pictogram: een bus als een doos met twee wielen.
		kader(3, 5, 18, 12, 2)
		lijn(3, 11, 21, 11)
		rond(7, 19, 2)
		rond(17, 19, 2)
	elseif naam == "profile" then
		rond(12, 8, 4)
		arc(12, 21, 8, 180, 360, 8)
	elseif naam == "vip" then
		boog({ {3, 8}, {7, 11}, {12, 5}, {17, 11}, {21, 8}, {19, 19}, {5, 19}, {3, 8} })
	elseif naam == "friends" then
		rond(9, 8, 3.2)
		arc(9, 20, 6.5, 180, 360, 7)
		arc(16.5, 8.5, 3.2, -80, 80, 5)
		boog({ {18, 14.6}, {20.5, 15.6}, {21.9, 19} })
	elseif naam == "achievements" then
		lijn(8, 21, 16, 21)
		lijn(12, 17, 12, 21)
		lijn(6, 4, 18, 4)
		lijn(6, 4, 6, 8)
		lijn(18, 4, 18, 8)
		arc(12, 8, 6, 0, 180, 6)
		boog({ {6, 6}, {3, 6}, {3, 8} })
		arc(7, 8, 4, 180, 90, 4)
		boog({ {18, 6}, {21, 6}, {21, 8} })
		arc(17, 8, 4, 0, 90, 4)
	end

	return vak
end

-- De kleur van een heel pictogram in één keer zetten.
function Icons.tint(vak: Frame, kleur: Color3, doorzicht: number): ()
	for _, k in vak:GetDescendants() do
		if k:IsA("Frame") then
			k.BackgroundColor3 = kleur
			if k.BackgroundTransparency < 0.9 then
				k.BackgroundTransparency = doorzicht
			end
		elseif k:IsA("UIStroke") then
			k.Color = kleur
			k.Transparency = doorzicht
		end
	end
end

return Icons
]],
}
