--!strict
-- Dezelfde bewijzen als odds_test.js in de webversie: elk spel keert 97% uit.
local Odds = require("../src/shared/Odds")
local h = require("./harness")

local function pct(x: number): string
	return string.format("%.4f%%", x * 100)
end

-- ---------- crash ----------
-- P(crash >= M) = 0.97 / M. Met u gelijkmatig over [0,1) is de verwachte uitbetaling bij
-- uitstappen op M gelijk aan M * P(crash >= M) = 0.97.
do
	-- Het crashpunt wordt naar BOVEN afgerond op de cent. Dat kan alleen in het voordeel
	-- van de speler uitvallen, en het effect is het grootst bij lage multipliers omdat een
	-- hele cent daar relatief zwaarder weegt. Dus: nooit onder de 97%, en naar 97% toe
	-- naarmate je later uitstapt.
	local vorige = math.huge
	for _, m in {1.1, 1.5, 2, 5, 10, 100} do
		local hits, N = 0, 200000
		for i = 0, N - 1 do
			local u = (i + 0.5) / N
			if Odds.crashPoint(u) >= m then hits += 1 end
		end
		local rtp = (hits / N) * m
		h.check("crash op " .. m .. "x keert nooit minder dan 97% uit", true, rtp >= 0.9699)
		h.check("crash op " .. m .. "x keert hoogstens 98% uit", true, rtp <= 0.98)
		h.check("crash op " .. m .. "x ligt dichter bij 97% dan de vorige", true, rtp <= vorige + 1e-6)
		vorige = rtp
	end
	h.near("ver uitstappen komt precies op 97% uit", 0.97,
		(function()
			local hits, N = 0, 200000
			for i = 0, N - 1 do
				if Odds.crashPoint((i + 0.5) / N) >= 100 then hits += 1 end
			end
			return (hits / N) * 100
		end)(), 0.002)
	h.check("crash begint op 1.00", 1, Odds.crashPoint(0))
	h.check("crash loopt tot 1000", 1000, Odds.crashPoint(0.9999999))
end

-- ---------- roulette ----------
do
	local keys = {"red","black","even","odd","low","high","d1","d2","d3","c1","c2","c3"}
	for _, k in keys do
		local s = 0
		for n = 0, 36 do s += Odds.roulettePayout(k, n) end
		h.near("roulette " .. k .. " keert 97.3% uit", 0.973, s / 37, 0.0005)
	end
	local s = 0
	for n = 0, 36 do s += Odds.roulettePayout("n:17", n) end
	h.near("roulette op een getal keert 97.3% uit", 0.973, s / 37, 0.0005)
	h.check("nul is groen", "green", Odds.rouletteColor(0))
	h.check("32 is rood", "red", Odds.rouletteColor(32))
	h.check("15 is zwart", "black", Odds.rouletteColor(15))
	h.check("het wiel heeft 37 vakken", 37, #Odds.ROULETTE_ORDER)
end

-- ---------- dragon tower ----------
do
	for diff, d in Odds.TOWER_DIFF do
		local p = (d.safe / d.tiles) ^ Odds.TOWER_LEVELS
		local m = Odds.towerMultiplier(diff, Odds.TOWER_LEVELS)
		h.near("tower " .. diff .. " op de top keert hoogstens 97% uit", 0.97, p * m, 0.02)
		-- elke rij heeft precies `safe` veilige tegels
		local rows = Odds.towerLayout(diff)
		h.check("tower " .. diff .. " heeft 9 rijen", 9, #rows)
		for _, row in rows do
			local veilig = 0
			for _, v in row do if v then veilig += 1 end end
			h.check("tower " .. diff .. " rij heeft " .. d.safe .. " veilig", d.safe, veilig)
		end
	end
end

-- ---------- mines ----------
do
	for _, mines in {1, 3, 5, 10, 24} do
		local k = math.min(3, 25 - mines)
		local p = 1
		for i = 0, k - 1 do p *= (25 - mines - i) / (25 - i) end
		h.near("mines " .. mines .. " keert hoogstens 97% uit", 0.97,
			p * Odds.minesMultiplier(mines, k), 0.02)
	end
	for _, mines in {1, 5, 24} do
		local grid = Odds.minesLayout(mines)
		local n = 0
		for _, v in grid do if v then n += 1 end end
		h.check("mines legt er " .. mines .. " neer", mines, n)
	end
end

-- ---------- plinko ----------
do
	for _, rows in {8, 12, 16} do
		for _, risk in {"low", "medium", "high"} do
			local t = Odds.plinkoTable(rows, risk)
			h.check("plinko " .. rows .. "/" .. risk .. " heeft " .. (rows + 1) .. " vakken", rows + 1, #t)
			h.near("plinko " .. rows .. "/" .. risk .. " keert 97% uit", 0.97, Odds.plinkoRtp(rows, t), 0.005)
			-- links en rechts moeten gelijk zijn
			for i = 1, math.floor(#t / 2) do
				h.check("plinko " .. rows .. "/" .. risk .. " is symmetrisch op " .. i, t[i], t[#t + 1 - i])
			end
		end
	end
end

-- ---------- paardenrace ----------
do
	local probs = Odds.horseField()
	local sum = 0
	for _, p in probs do sum += p end
	h.near("de kansen tellen op tot 1", 1, sum, 1e-9)
	for _, p in probs do
		h.near("paard op " .. string.format("%.3f", p) .. " keert 97% uit", 0.97,
			p * Odds.horseMultiplier(p), 0.01)
	end
	-- de volgorde bevat elk paard precies een keer
	local order = Odds.horseRanking(probs)
	h.check("de volgorde telt zes paarden", 6, #order)
	local gezien = {}
	for _, i in order do gezien[i] = (gezien[i] or 0) + 1 end
	for i = 1, 6 do h.check("paard " .. i .. " staat er een keer in", 1, gezien[i]) end
end

-- ---------- krasloten ----------
do
	h.near("krasloten keren 97% uit", 0.97, Odds.scratchRtp(), 1e-12)
	-- de trekking volgt de gewichten
	-- Het is gewicht x bedrag dat op 9700 van de 10000 uitkomt; de gewichten zelf tellen op
	-- tot de kans om uberhaupt iets te winnen.
	local uitkering, kans = 0, 0
	for _, p in Odds.SCRATCH_PRIZES do
		uitkering += p.weight * p.mult
		kans += p.weight
	end
	h.check("gewicht x bedrag is 9700 van de 10000", 9700, uitkering)
	h.check("de kans om iets te winnen is 21.6%", 2160, kans)
	-- een winnend rooster betaalt het bedrag van dat symbool, een verliezend niets
	for i = 1, #Odds.SCRATCH_PRIZES do
		local cells = Odds.scratchGrid(i)
		h.check("winnend lot heeft negen vakjes", 9, #cells)
		h.near("lot " .. i .. " betaalt " .. Odds.SCRATCH_PRIZES[i].mult, Odds.SCRATCH_PRIZES[i].mult,
			Odds.scratchPayout(cells), 1e-9)
	end
	for _ = 1, 200 do
		h.near("een verliezend lot betaalt niets", 0, Odds.scratchPayout(Odds.scratchGrid(0)), 1e-9)
	end
end

-- ---------- 777 ----------
do
	h.near("777 keert 97% uit", 0.97, Odds.slotRtp(), 1e-12)
	for i = 1, #Odds.SLOT_PRIZES do
		local reels = Odds.slotReels(i)
		h.near("777 prijs " .. i .. " betaalt " .. Odds.SLOT_PRIZES[i].mult, Odds.SLOT_PRIZES[i].mult,
			Odds.slotPayout(reels), 1e-9)
	end
	for _ = 1, 300 do
		h.near("een verliezend beeld betaalt niets", 0, Odds.slotPayout(Odds.slotReels(0)), 1e-9)
	end
end

-- ---------- rad ----------
do
	h.near("het rad keert 97% uit", 0.97, Odds.wheelRtp(), 1e-12)
	h.check("het rad heeft twintig vakken", 20, #Odds.WHEEL)
end

-- ---------- ride the bus ----------
do
	-- Elke call: de multiplier is 0,97 gedeeld door de kans, dus kans x multiplier is 0,97.
	local deck = Odds.bjNewShoe(1)
	local shown: { Odds.Card } = {}
	local prob = 1
	for step = 1, 4 do
		local opties = Odds.busOptions(step)
		local keuze = opties[1][1]
		local p = Odds.busChance(deck, step, keuze, shown)
		if p > 0 then
			prob *= p
			h.near("bus call " .. step .. " keert 97% uit", 0.97,
				prob * Odds.busMultiplier(prob), 0.01)
		end
		-- pak een kaart die de call haalt, zodat we door kunnen
		local idx = nil
		for i, c in deck do
			if Odds.busHit(c, step, keuze, shown) then idx = i break end
		end
		if not idx then break end
		table.insert(shown, table.remove(deck, idx) :: Odds.Card)
	end
	h.check("gelijke rang verliest bij hoger", false,
		Odds.busHit({ r = "7", s = "♠" }, 2, "higher", { { r = "7", s = "♥" } }))
	h.check("gelijke rang verliest ook bij lager", false,
		Odds.busHit({ r = "7", s = "♠" }, 2, "lower", { { r = "7", s = "♥" } }))
end

-- ---------- blackjack ----------
do
	local shoe = Odds.bjNewShoe(6)
	h.check("de schoen telt 312 kaarten", 312, #shoe)
	local telling: { [string]: number } = {}
	for _, c in shoe do
		local k = c.r .. c.s
		telling[k] = (telling[k] or 0) + 1
	end
	local soorten, allesZes = 0, true
	for _, n in telling do
		soorten += 1
		if n ~= 6 then allesZes = false end
	end
	h.check("52 soorten kaarten", 52, soorten)
	h.check("elke kaart zit er zes keer in", true, allesZes)

	h.check("aas plus boer is 21", 21, (Odds.bjValue({ { r = "A", s = "♠" }, { r = "J", s = "♥" } })))
	h.check("twee azen en een negen is 21", 21,
		(Odds.bjValue({ { r = "A", s = "♠" }, { r = "A", s = "♥" }, { r = "9", s = "♦" } })))
	h.check("drie plaatjes barsten", 30,
		(Odds.bjValue({ { r = "K", s = "♠" }, { r = "Q", s = "♥" }, { r = "J", s = "♦" } })))
	h.check("blackjack wordt herkend", true, Odds.bjIsBlackjack({ { r = "A", s = "♠" }, { r = "K", s = "♥" } }))
	h.check("21 uit drie kaarten is geen blackjack", false,
		Odds.bjIsBlackjack({ { r = "7", s = "♠" }, { r = "7", s = "♥" }, { r = "7", s = "♦" } }))

	local AK = { { r = "A", s = "♠" }, { r = "K", s = "♥" } }
	local twintig = { { r = "10", s = "♠" }, { r = "10", s = "♥" } }
	local bust = { { r = "K", s = "♠" }, { r = "Q", s = "♥" }, { r = "J", s = "♦" } }
	h.near("blackjack betaalt 2.5", 2.5, Odds.bjSettle(AK, twintig), 1e-9)
	h.near("blackjack tegen blackjack is push", 1, Odds.bjSettle(AK, { { r = "A", s = "♦" }, { r = "K", s = "♣" } }), 1e-9)
	h.near("dealer blackjack wint", 0, Odds.bjSettle(twintig, AK), 1e-9)
	h.near("barsten betaalt niets", 0, Odds.bjSettle(bust, twintig), 1e-9)
	h.near("dealer barst, speler wint", 2, Odds.bjSettle(twintig, bust), 1e-9)
	h.near("gelijkspel geeft de inzet terug", 1,
		Odds.bjSettle(twintig, { { r = "9", s = "♠" }, { r = "J", s = "♥" }, { r = "A", s = "♣" } }), 1e-9)
	h.check("die dealerhand is inderdaad ook 20", 20,
		(Odds.bjValue({ { r = "9", s = "♠" }, { r = "J", s = "♥" }, { r = "A", s = "♣" } })))

	-- de dealer stopt op 17 of meer
	local hand = { { r = "2", s = "♠" }, { r = "3", s = "♥" } }
	local i = 0
	Odds.bjDealerPlay(hand, function()
		i += 1
		return { r = "4", s = "♦" }
	end)
	h.check("de dealer staat op 17 of meer", true, (Odds.bjValue(hand)) >= 17)
end

print("crash 97% | roulette 97.3% | tower, mines, plinko, paarden, krasloten, 777, rad, bus, blackjack")
h.report("ODDS")
