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
	-- Het lot is al getrokken, dus we weten wat het waard is.
	local lot = w.Games.openOf(b)
	local waard = w.Money.floor2(40 * w.Odds.scratchPayout(lot.cells))

	for _, f in w.sluiters do f() end
	h.check("de toren is terugbetaald voor het opslaan", 1000, w.store.data["speler_1"].balance)
	-- Een kraslot wordt niet terugbetaald maar uitbetaald: de prijs zat er al in.
	h.check("het kraslot is afgerekend, niet teruggegeven", 960 + waard, w.store.data["speler_2"].balance)
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

-- ---------- weglopen van een beslist kraslot ----------
-- Dit is het lek dat de review vond: de prijs staat vast zodra je het lot koopt, dus wie
-- acht vakjes openkrast en dan weggaat zou elk verliezend lot gratis spelen.
do
	local w = wereld()
	local s, p = meldEen(w)

	-- Net zo lang kopen tot er een verliezend lot tussen zit.
	local verlies = 0
	for _ = 1, 200 do
		p.balance = 1000
		w.Games.scratchBuy(s, 100)
		local lot = w.Games.openOf(s)
		if w.Odds.scratchPayout(lot.cells) == 0 then
			verlies += 1
			break
		end
		-- geen verliezer: afmaken en opnieuw
		for i = 1, 9 do w.Games.scratchReveal(s, i) end
	end
	h.check("er is een verliezend lot gevonden", 1, verlies)
	h.check("de inzet is afgeschreven", 900, p.balance)

	-- Acht vakjes open: je ziet nu dat er niets in zit.
	for i = 1, 8 do w.Games.scratchReveal(s, i) end
	h.check("het lot ligt nog open", true, w.Games.openOf(s) ~= nil)

	w.vertrek(s)
	h.check("weglopen van een verliezend lot geeft niets terug", 900, w.store.data["speler_1"].balance)
end

-- Een winnend lot wordt bij weglopen wel uitbetaald: de prijs zat er al in.
do
	local w = wereld()
	local s, p = meldEen(w)
	local gevonden = false
	for _ = 1, 300 do
		p.balance = 1000
		w.Games.scratchBuy(s, 100)
		local lot = w.Games.openOf(s)
		local mult = w.Odds.scratchPayout(lot.cells)
		if mult > 0 then
			gevonden = true
			w.vertrek(s)
			h.check("een winnend lot wordt uitbetaald bij weglopen",
				w.Money.round2(900 + w.Money.floor2(100 * mult)), w.store.data["speler_1"].balance)
			break
		end
		for i = 1, 9 do w.Games.scratchReveal(s, i) end
	end
	h.check("er is een winnend lot gevonden", true, gevonden)
end

-- ---------- het noodfonds ----------
-- Het fonds is een geschenk: er staat geen inzet tegenover. Alles hangt er dus aan dat
-- hij alleen opengaat voor wie echt niets meer heeft, en dat de server zelf bepaalt waar
-- het streepje stond.
local PERIODE = 1.1
-- De tijd waarop het streepje op `pos` staat, op de heenweg van de driehoeksgolf.
local function tijdVoor(pos: number): number
	return pos / 2 * PERIODE
end

do
	local w = wereld()
	local s, p = meldEen(w)

	h.check("met geld op zak gaat het fonds niet open", false, w.Games.safetyOpen(s).ok)
	h.check("en hij is ook niet beschikbaar", false, w.Games.safetyAvailable(s))

	p.balance = 0
	h.check("blut is hij wel beschikbaar", true, w.Games.safetyAvailable(s))
	local r = w.Games.safetyOpen(s)
	h.check("en gaat hij open", true, r.ok)
	h.check("de server geeft de periode mee", PERIODE, r.period)

	-- Twee keer openen zou twee klokken geven; dan kies je achteraf de beste.
	h.check("twee keer openen is geweigerd", false, w.Games.safetyOpen(s).ok)

	-- Precies in het midden: de volle veertig.
	w.wacht(tijdVoor(0.5))
	local uit = w.Games.safetyStop(s)
	h.check("een perfecte stop lukt", true, uit.ok)
	h.check("het streepje stond in het midden", 0.5, w.Money.round2(uit.position))
	h.check("dat is de volle veertig", 40, uit.payout)
	h.check("en het staat op de rekening", 40, p.balance)
	h.check("stoppen zonder ronde kan niet", false, w.Games.safetyStop(s).ok)
end

do
	-- Aan de rand van de golf blijft de bodem van tien staan, nooit minder.
	local w = wereld()
	local s, p = meldEen(w)
	p.balance = 0
	w.Games.safetyOpen(s)
	-- Helemaal aan het begin staat het streepje op 0: zo ver van het midden als het gaat.
	local uit = w.Games.safetyStop(s)
	h.check("aan de rand is het de gegarandeerde tien", 10, uit.payout)
	h.check("nooit minder dan de bodem", 10, p.balance)

	p.balance = 0
	w.Games.safetyOpen(s)
	w.wacht(PERIODE / 2)
	local ander = w.Games.safetyStop(s)
	h.check("de andere rand van de golf ook", 10, ander.payout)
end

do
	-- Halverwege heen: het streepje op een kwart, dus de helft van de bonus erbovenop.
	local w = wereld()
	local s, p = meldEen(w)
	p.balance = 0
	w.Games.safetyOpen(s)
	w.wacht(tijdVoor(0.25))
	local uit = w.Games.safetyStop(s)
	h.check("halve nauwkeurigheid geeft de helft van de bonus", 25, uit.payout)
	h.check("de nauwkeurigheid wordt meegegeven", 0.5, w.Money.round2(uit.accuracy))
end

do
	-- De golf loopt door: na een hele periode staat het streepje weer waar het begon.
	local w = wereld()
	local s, p = meldEen(w)
	p.balance = 0
	w.Games.safetyOpen(s)
	w.wacht(PERIODE * 3 + tijdVoor(0.5))
	h.check("drie perioden later telt alleen waar het streepje staat", 40, w.Games.safetyStop(s).payout)
end

do
	-- Dit is de geldpers die de webversie met roundInProgress() dichthoudt: zet alles in,
	-- sta daardoor op nul, pak het fonds, en stap daarna alsnog uit je ronde.
	local w = wereld()
	local s, p = meldEen(w)
	p.balance = 100
	w.Multi.minesStart(s, 100, 1)
	h.check("de inzet is afgeschreven", 0, p.balance)
	h.check("maar met een ronde open ben je niet blut", false, w.Games.safetyAvailable(s))
	h.check("dus het fonds gaat niet open", false, w.Games.safetyOpen(s).ok)
	w.Multi.minesCashOut(s)
end

do
	-- Hetzelfde met een blackjackhand die nog loopt.
	local w = wereld()
	local s, p = meldEen(w)
	p.balance = 100
	w.Blackjack.deal(s, 100)
	if w.Blackjack.inPlay(s) then
		h.check("een lopende hand telt ook als geld in het spel", false, w.Games.safetyOpen(s).ok)
	else
		-- Een natural is meteen afgerekend; dan staat er niets meer open.
		h.check("na een afgeronde hand is het fonds weer bereikbaar", true, p.balance > 0 or w.Games.safetyAvailable(s))
	end
end

do
	-- En met een inzet die in de lucht hangt.
	local w = wereld()
	local s, p = meldEen(w)
	w.Crash.begin()
	p.balance = 100
	h.check("de inzet lukt", true, w.Crash.bet(s, 100).ok)
	h.check("het saldo staat op nul", 0, p.balance)
	w.Crash.takeOff()
	h.check("maar een vlucht met je geld erin is geen blut", false, w.Games.safetyOpen(s).ok)
	w.Crash.cashOut(s)
end

do
	-- De prestatie hangt aan het hoogste bedrag dat je ooit uit het fonds haalde, niet aan
	-- de optelsom: zo staat het ook in de webversie (Math.max in bkStop).
	local w = wereld()
	local s, p = meldEen(w)

	-- Vijfendertig dollar is de grens. Net eronder telt niet.
	local netNiet = (34.9 - 10) / 30
	p.balance = 0
	w.Games.safetyOpen(s)
	w.wacht(tijdVoor(0.5 - (1 - netNiet) / 2))
	local een = w.Games.safetyStop(s)
	h.check("net onder de grens", true, een.payout < 35 and een.payout > 34)
	h.check("de prestatie is nog niet open", nil, p.achievements["nood_precise"])

	p.balance = 0
	w.Games.safetyOpen(s)
	w.wacht(tijdVoor(0.5))
	h.check("en dan een volle veertig", 40, w.Games.safetyStop(s).payout)
	h.check("het hoogste bedrag is onthouden", 40, p.extra.noodfonds)
	h.check("de prestatie gaat open", true, p.achievements["nood_precise"] ~= nil)

	-- Een magere ronde daarna drukt het hoogste bedrag niet omlaag.
	p.balance = 0
	w.Games.safetyOpen(s)
	w.Games.safetyStop(s)
	h.check("een tientje daarna verlaagt het hoogste bedrag niet", 40, p.extra.noodfonds)
end

-- ---------- de paardenrace: de quotes staan vast voordat er wordt ingezet ----------
-- Dit is waar het bij een quote om gaat. Wordt het veld pas bij het startschot geloot, dan
-- zet je blind in en kan de server nog kiezen wat er slecht uitkomt voor wat er ligt.
do
	local w = wereld()
	local s, p = meldEen(w)

	local eerst = w.Games.horseField(s)
	h.check("het veld staat klaar voordat er iets ligt", true, eerst.ok)
	h.check("met een kans per paard", #w.Odds.HORSES, #eerst.probs)

	-- Twee keer vragen geeft hetzelfde veld: anders was de quote op het scherm niet de
	-- quote waarop gelopen wordt.
	local nogmaals = w.Games.horseField(s)
	for i = 1, #eerst.probs do
		h.check("dezelfde kans bij het tweede opvragen", eerst.probs[i], nogmaals.probs[i])
	end

	-- En de race loopt op precies dat veld.
	p.balance = 1000
	local uitslag = w.Games.horse(s, { [1] = 10 })
	h.check("de race loopt", true, uitslag.ok)
	for i = 1, #eerst.probs do
		h.check("de race gebruikt het getoonde veld", eerst.probs[i], uitslag.probs[i])
	end

	-- Daarna staat er een nieuw veld klaar voor de volgende race.
	local na = w.Games.horseField(s)
	local zelfde = true
	for i = 1, #eerst.probs do
		if na.probs[i] ~= eerst.probs[i] then zelfde = false break end
	end
	h.check("na de race wordt er opnieuw geloot", false, zelfde)
end

do
	-- NEW ODDS geeft een ander veld, en levert niets op: elke quote is 0,97 gedeeld door de
	-- kans, dus elk paard in elk veld betaalt 97% terug. Er valt niets uit te zoeken.
	local w = wereld()
	local s = meldEen(w)
	local eerst = w.Games.horseField(s).probs
	local nieuw = w.Games.horseNewOdds(s)
	h.check("nieuwe quotes lukken", true, nieuw.ok)
	local zelfde = true
	for i = 1, #eerst do
		if nieuw.probs[i] ~= eerst[i] then zelfde = false break end
	end
	h.check("en het is een ander veld", false, zelfde)

	for _, veld in { eerst, nieuw.probs } do
		local som = 0
		for _, kans in veld do
			som += kans
			-- De uitbetaling per ingezette dollar, maal de kans dat het gebeurt.
			h.near("elke quote betaalt 97% terug", 0.97,
				w.Odds.horseMultiplier(kans) * kans, 0.006)
		end
		h.check("de kansen tellen op tot een", 1, w.Money.round2(som))
	end
end

h.report("SERVER")
