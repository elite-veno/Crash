--!strict
-- De meerbeurtenspellen zonder Roblox: we rekenen de uitbetalingen na met dezelfde
-- formules die de server gebruikt, zodat de bedragen bewezen zijn voordat er iets in
-- Studio draait.
local Odds = require("../src/shared/Odds")
local Money = require("../src/shared/Money")
local h = require("./harness")

local zaad = 4242
Odds.setRandom(function()
	zaad = (zaad * 1103515245 + 12345) % 2147483648
	return zaad / 2147483648
end)

-- ---------- tower ----------
-- Uitstappen op elk niveau hoort 97% te betalen: kans om er te komen x multiplier.
for diff, d in Odds.TOWER_DIFF do
	for niveau = 1, Odds.TOWER_LEVELS do
		local kans = (d.safe / d.tiles) ^ niveau
		local mult = Odds.towerMultiplier(diff, niveau)
		local rtp = kans * mult
		h.check("tower " .. diff .. " niveau " .. niveau .. " betaalt hoogstens 97%", true, rtp <= 0.9701)
		h.check("tower " .. diff .. " niveau " .. niveau .. " betaalt bijna 97%", true, rtp > 0.93)
	end
end

-- ---------- mines ----------
for _, mijnen in {1, 3, 5, 12, 24} do
	local over = 25 - mijnen
	for k = 1, math.min(over, 6) do
		local kans = 1
		for i = 0, k - 1 do
			kans *= (25 - mijnen - i) / (25 - i)
		end
		local rtp = kans * Odds.minesMultiplier(mijnen, k)
		h.check("mines " .. mijnen .. " na " .. k .. " betaalt hoogstens 97%", true, rtp <= 0.9701)
		h.check("mines " .. mijnen .. " na " .. k .. " betaalt bijna 97%", true, rtp > 0.90)
	end
end
-- het veld leegspelen betaalt precies uit wat de tabel zegt
h.near("mines 24: één tegel over", 0.97 * 25 / 1, Odds.minesMultiplier(24, 1), 0.01)

-- ---------- ride the bus ----------
-- Vier calls door één stapel, telkens de kans geteld op wat er nog ligt.
do
	local deck = Odds.bjNewShoe(1)
	local shown: { Odds.Card } = {}
	local prob = 1
	for stap = 1, 4 do
		local keuze = Odds.busOptions(stap)[1][1]
		local kans = Odds.busChance(deck, stap, keuze, shown)
		if kans <= 0 then break end
		prob *= kans
		local mult = Odds.busMultiplier(prob)
		h.check("bus call " .. stap .. " betaalt hoogstens 97%", true, prob * mult <= 0.9701)
		h.check("bus call " .. stap .. " betaalt bijna 97%", true, prob * mult > 0.90)
		local idx = nil
		for i, c in deck do
			if Odds.busHit(c, stap, keuze, shown) then
				idx = i
				break
			end
		end
		if not idx then break end
		table.insert(shown, table.remove(deck, idx) :: Odds.Card)
	end
end

-- ---------- de uitbetaling wordt naar beneden afgerond ----------
-- Nooit in het voordeel van de speler, net als in de webversie.
h.near("een uitbetaling wordt afgekapt", 20.69, Money.floor2(10 * 2.069), 1e-9)
h.near("een saldo wordt op de cent bewaard", 20.7, Money.round2(20.695), 1e-9)

h.report("MEERBEURTENSPELLEN")
