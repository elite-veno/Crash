--!nolint
-- De serverbestanden zelf, gedraaid in een nagemaakte Roblox-omgeving. Dit is de test die
-- de valsspeelwegen dichthoudt: wat hier faalt, kan een speler straks echt proberen.
local Stub = require("./roblox_stub")
local h = require("./harness")

local function wereld(opties)
	local w = Stub.wereld(opties)
	-- Games heeft bij het laden zijn eigen trekker in Odds gezet; die loopt via w.trek,
	-- dus met w.volgende is elke uitslag af te dwingen.
	return w
end

local function meldEen(w)
	local s = w.speler(1, "Aap")
	w.Players.PlayerAdded:Fire(s)
	w.Profiles.load(s)
	return s, w.Profiles.get(s)
end

-- ---------- mines: dezelfde tegel twee keer ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	local saldoVooraf = p.balance

	-- Eén mijn, en we zorgen dat tegel 1 zeker veilig is door de hele grid te kennen.
	local r = w.Multi.minesStart(s, 100, 1)
	h.check("mines start lukt", true, r.ok)
	local o = w.Multi.get(s)
	local veilig = 0
	for i = 1, 25 do
		if not o.grid[i] then veilig = i break end
	end

	local eerste = w.Multi.minesPick(s, veilig)
	h.check("de eerste veilige tegel telt", true, eerste.ok and eerste.mine == false)
	h.check("na één tegel staat de teller op 1", 1, o.picked)

	-- Precies het lek: dezelfde tegel opnieuw insturen.
	local herhaling = w.Multi.minesPick(s, veilig)
	h.check("dezelfde tegel nog eens wordt geweigerd", false, herhaling.ok)
	h.check("de teller loopt niet op van een herhaling", 1, o.picked)

	-- En twintig keer achter elkaar verandert daar niets aan.
	for _ = 1, 20 do w.Multi.minesPick(s, veilig) end
	h.check("twintig herhalingen tikken de teller niet op", 1, o.picked)

	local uit = w.Multi.minesCashOut(s)
	local eerlijk = w.Money.floor2(100 * w.Odds.minesMultiplier(1, 1))
	h.check("uitbetaling hoort bij één tegel, niet bij eenentwintig", eerlijk, uit.payout)
	h.check("het saldo klopt na de ronde", w.Money.round2(saldoVooraf - 100 + eerlijk), p.balance)
end

-- ---------- mines: een tegelnummer dat geen tegelnummer is ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	w.Multi.minesStart(s, 100, 1)
	local o = w.Multi.get(s)

	for _, raar in {1.5, 2.000001, 0 / 0, -0, 26, 0, "tegel", nil, math.huge} do
		local r = w.Multi.minesPick(s, raar)
		h.check("mines weigert " .. tostring(raar), false, r.ok)
	end
	h.check("geen van die pogingen telde mee", 0, o.picked)
	h.check("het saldo is niet stiekem veranderd", 900, p.balance)
end

-- ---------- roulette en paarden: een inzet van NaN ----------
do
	local w = wereld()
	local s, p = meldEen(w)

	local r = w.Games.roulette(s, { red = 0 / 0 })
	h.check("roulette weigert een inzet van NaN", false, r.ok)
	h.check("het saldo blijft een getal", 1000, p.balance)
	h.check("het saldo is geen NaN", true, p.balance == p.balance)

	local r2 = w.Games.roulette(s, { red = "nan", black = math.huge })
	h.check("roulette weigert nan als tekst en oneindig", false, r2.ok)
	h.check("het saldo staat er nog", 1000, p.balance)

	local r3 = w.Games.horse(s, { [1] = 0 / 0 })
	h.check("paarden weigert een inzet van NaN", false, r3.ok)
	h.check("het saldo staat er nog na de paarden", 1000, p.balance)

	local r4 = w.Games.horse(s, { [1.5] = 50 })
	h.check("paarden weigert een halve startplaats", false, r4.ok)
	h.check("er is niets afgeschreven", 1000, p.balance)

	-- En een gewone inzet werkt nog wel.
	local r5 = w.Games.roulette(s, { red = 10 })
	h.check("een gewone inzet gaat gewoon door", true, r5.ok)
end

-- ---------- ride the bus: een call die niet uit kan komen ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	-- De bus zit achter de VIP-zone; zonder pas begint er niets.
	h.check("zonder pas geen bus", false, w.Multi.busStart(s, 50).ok)
	p.vipSeason = w.Season.seasonId()
	w.Multi.busStart(s, 50)
	local o = w.Multi.get(s)

	-- Stap 1 is al gezet: leg er een aas neer, dan is "lower" bij stap 2 onmogelijk.
	o.step = 1
	o.shown = { { r = "A", s = "\u{2660}" } }
	local kaarten = #o.deck

	local r = w.Multi.busCall(s, "lower")
	h.check("een call met kans nul wordt geweigerd", false, r.ok)
	h.check("er is geen kaart getrokken", kaarten, #o.deck)
	h.check("de ronde loopt nog", true, w.Multi.get(s) ~= nil)
	h.check("de inzet staat nog in het spel", 950, p.balance)

	-- "higher" kan wel: boven een aas ligt bijna alles.
	local r2 = w.Multi.busCall(s, "higher")
	h.check("een call die wel kan uitkomen gaat door", true, r2.ok)

	-- De client krijgt de kansen mee, zodat hij de onmogelijke knop grijs kan zetten.
	local w2 = wereld()
	local s2 = w2.speler(2, "Beer")
	local p2 = w2.Profiles.load(s2)
	p2.vipSeason = w2.Season.seasonId()
	local start = w2.Multi.busStart(s2, 50)
	h.check("bus geeft twee opties bij de start", 2, #start.options)
	h.check("een optie draagt zijn kans mee", true, start.options[1].chance > 0)
	h.check("een optie draagt zijn naam mee", "RED", start.options[1].label)
end

-- ---------- kraslot: een vakje dat geen vakje is ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	w.Games.scratchBuy(s, 20)
	for _, raar in {0 / 0, 1.5, 0, 10, "vakje", math.huge} do
		local ok, r = pcall(w.Games.scratchReveal, s, raar)
		h.check("kraslot klapt niet op " .. tostring(raar), true, ok)
		h.check("kraslot weigert " .. tostring(raar), false, r.ok)
	end
	local r = w.Games.scratchReveal(s, 1)
	h.check("een echt vakje mag wel", true, r.ok)
end

-- ---------- uitbetalen op de cent ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	-- Vak 6 van het rad is 1,5x; u tussen 0,25 en 0,30 komt daar uit.
	w.volgende = {0.26}
	local r = w.Games.wheel(s, 1.2)
	h.check("het rad staat op 1,5x", 1.5, r.mult)
	h.near("1,20 op 1,5x betaalt 1,80, niet 1,79", 1.8, r.payout, 1e-9)
	h.near("en dat staat ook zo op het saldo", 1000 - 1.2 + 1.8, p.balance, 1e-9)
end

-- ---------- weggaan met een ronde open ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	w.Multi.minesStart(s, 300, 3)
	h.check("de inzet is afgeschreven", 700, p.balance)

	w.vertrek(s)

	local bewaard = w.store.data["speler_1"]
	h.check("er is opgeslagen", true, bewaard ~= nil)
	h.check("de inzet zit in wat er is opgeslagen", 1000, bewaard.balance)
	h.check("het slot is losgelaten", nil, bewaard.lockJob)
end

-- ---------- de server gaat dicht met rondes open ----------
do
	local w = wereld()
	local a = w.speler(1, "Aap")
	local b = w.speler(2, "Beer")
	w.Profiles.load(a)
	w.Profiles.load(b)
	w.Multi.towerStart(a, 200, "easy")
	w.Games.scratchBuy(b, 40)
	h.check("beide inzetten zijn afgeschreven", 800, w.Profiles.get(a).balance)

	for _, f in w.sluiters do f() end
	h.check("de toren is terugbetaald voor het opslaan", 1000, w.store.data["speler_1"].balance)
	h.check("het kraslot ook", 1000, w.store.data["speler_2"].balance)
end

-- ---------- weggaan terwijl het profiel nog gelezen wordt ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	-- Midden in het lezen vertrekt de speler weer.
	w.store.tijdens = function()
		w.vertrek(s)
	end
	w.Profiles.load(s)
	h.check("er blijft geen profiel hangen", nil, w.Profiles.get(s))

	-- En een nieuwe sessie van dezelfde speler begint gewoon opnieuw.
	local s2 = w.speler(1, "Aap")
	local p2 = w.Profiles.load(s2)
	h.check("de speler kan zo weer binnenkomen", true, p2 ~= nil)
	h.check("en zijn profiel is dan wel geladen", true, w.Profiles.get(s2) ~= nil)
end

-- ---------- de DataStore hapert ----------
do
	local w = wereld()
	w.store.kapot = 2   -- de eerste twee aanroepen mislukken
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	h.check("na twee mislukte pogingen is er toch gelezen", true, w.Profiles.get(s) ~= nil)
	h.check("en dan wordt er wel opgeslagen", 1000, p.balance)
	w.Games.wheel(s, 10)
	w.vertrek(s)
	h.check("de sessie is bewaard", true, w.store.data["speler_1"] ~= nil)
end

do
	local w = wereld()
	w.store.kapot = 99   -- lezen lukt helemaal niet
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Games.wheel(s, 10)
	w.vertrek(s)
	h.check("een profiel dat niet gelezen kon worden, wordt niet overschreven", nil, w.store.data["speler_1"])
end

-- ---------- twee servers, één speler ----------
do
	local gedeeld = Stub.nieuweStore()
	local a = wereld({ store = gedeeld, jobId = "server-A" })
	local sa = a.speler(7, "Aap")
	a.Profiles.load(sa)
	a.Games.wheel(sa, 100)
	local saldoA = a.Profiles.get(sa).balance

	-- Server B probeert dezelfde speler te laden terwijl A hem nog vasthoudt. Wat er op
	-- dat moment in de opslag staat, is de claim van A; die mag B niet aanraken.
	local voorB = gedeeld.data["speler_7"].balance
	local b = wereld({ store = gedeeld, jobId = "server-B" })
	local sb = b.speler(7, "Aap")
	b.Profiles.load(sb)
	b.Games.wheel(sb, 500)
	b.vertrek(sb)
	h.check("server B heeft niets overschreven", voorB, gedeeld.data["speler_7"].balance)
	h.check("het slot is nog van A", "server-A", gedeeld.data["speler_7"].lockJob)
	local gewaarschuwd = false
	for _, m in b.waarschuwingen do
		if string.find(m, "andere server") then gewaarschuwd = true end
	end
	h.check("en B zegt hardop dat hij niet opslaat", true, gewaarschuwd)

	-- A laat netjes los, en dan mag B wel.
	a.vertrek(sa)
	h.check("A heeft zijn eigen sessie wel bewaard", saldoA, gedeeld.data["speler_7"].balance)
	h.check("en het slot staat weer open", nil, gedeeld.data["speler_7"].lockJob)

	local c = wereld({ store = gedeeld, jobId = "server-C" })
	local sc = c.speler(7, "Aap")
	local pc = c.Profiles.load(sc)
	h.check("server C pakt het saldo van A op", saldoA, pc.balance)
end

-- ---------- het vervallen slot ----------
do
	local nu = os.time()
	local P = wereld().Profiles
	h.check("een leeg profiel is vrij", true, P.slotVrij(nil, "A", nu))
	h.check("zonder slot is het vrij", true, P.slotVrij({}, "A", nu))
	h.check("je eigen slot is vrij", true, P.slotVrij({ lockJob = "A", lockAt = nu }, "A", nu))
	h.check("andermans verse slot is bezet", false, P.slotVrij({ lockJob = "B", lockAt = nu }, "A", nu))
	h.check("na een minuut nog steeds bezet", false, P.slotVrij({ lockJob = "B", lockAt = nu - 60 }, "A", nu))
	h.check("na twee minuten vervallen", true, P.slotVrij({ lockJob = "B", lockAt = nu - 120 }, "A", nu))
end

-- ---------- het profiel dat naar de client gaat ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	local v = w.Profiles.view(s)
	h.check("de client ziet geen slot", nil, v.lockJob)
	h.check("de client ziet geen serverstempel", nil, v.lockAt)
	-- En het kraslot geeft zijn vakjes niet weg voordat ze open zijn.
	local koop = w.Games.scratchBuy(s, 20)
	h.check("het lot noemt alleen hoeveel vakjes er zijn", 9, koop.cells)
	h.check("een gekocht lot verklapt de symbolen niet", "number", typeof(koop.cells))
	h.check("en ook de prijs niet", nil, koop.prize)
end

h.report("SERVER")
