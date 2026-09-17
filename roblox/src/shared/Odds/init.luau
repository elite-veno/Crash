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
