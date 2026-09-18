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
	-- Dit is waar het slot om draait. Het levensteken komt met elke tussentijdse
	-- schrijfbeurt mee, dus een slot dat eerder vervalt dan de volgende schrijfbeurt laat
	-- een speler die gewoon zit te spelen er verlaten uitzien -- en dan pakt een tweede
	-- server zijn profiel op. Twee servers op hetzelfde saldo is geld dat verdwijnt of
	-- geld dat er ineens twee keer is.
	h.check("het slot vervalt later dan de volgende schrijfbeurt", true, P.SLOT_VERVAL > P.AUTOSAVE)
	h.check("en niet op het nippertje: drie beurten mogen missen", true, P.SLOT_VERVAL >= P.AUTOSAVE * 3)

	-- Een levensteken van vlak geleden is nooit vervallen, hoe je de getallen ook zet.
	h.check("een verse schrijfbeurt houdt het slot vast", false,
		P.slotVrij({ lockJob = "B", lockAt = nu - P.AUTOSAVE }, "A", nu))
	h.check("twee gemiste beurten ook nog", false,
		P.slotVrij({ lockJob = "B", lockAt = nu - P.AUTOSAVE * 2 }, "A", nu))
	-- En een server die echt weg is blokkeert de speler niet voor altijd.
	h.check("na lang stil te zijn valt het slot vrij", true,
		P.slotVrij({ lockJob = "B", lockAt = nu - P.SLOT_VERVAL - 1 }, "A", nu))
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

	-- Daarna staat er een nieuw veld klaar voor de volgende race, en het komt meteen mee
	-- met de uitslag: anders zou de volgende inzet weer blind zijn tot het scherm er zelf
	-- om vraagt.
	h.check("de uitslag draagt het veld voor de volgende race", #w.Odds.HORSES,
		if typeof(uitslag.nextProbs) == "table" then #uitslag.nextProbs else 0)
	local na = w.Games.horseField(s)
	for i = 1, #na.probs do
		h.check("en dat is het veld dat klaarstaat", uitslag.nextProbs[i], na.probs[i])
	end
	local zelfde = true
	for i = 1, #eerst.probs do
		if na.probs[i] ~= eerst.probs[i] then zelfde = false break end
	end
	h.check("het is een ander veld dan de race die net liep", false, zelfde)
end

do
	-- De ronde wordt geboekt op de quote van het winnende paard, niet op de uitbetaling
	-- gedeeld door alles wat er lag. Zet je op vijf paarden, dan win je misschien maar het
	-- dubbele van je totale inzet terwijl het paard acht keer betaalde -- en `Longshot`
	-- gaat over dat laatste.
	local w = wereld()
	local s, p = meldEen(w)
	local veld = w.Games.horseField(s).probs

	p.balance = 1000
	local inzetten = {}
	for i = 1, #w.Odds.HORSES do inzetten[i] = 10 end
	local uitslag = w.Games.horse(s, inzetten)
	h.check("de race loopt", true, uitslag.ok)

	-- Op alle paarden inzetten betekent dat de winnaar er altijd bij zit.
	local quote = w.Odds.horseMultiplier(veld[uitslag.winner])
	h.check("de geboekte multiplier is de quote van de winnaar", quote, p.stats.horse.highest)
	h.check("en niet de uitbetaling gedeeld door de totale inzet", true,
		math.abs(quote - (uitslag.payout / 60)) > 0.01)
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

-- ---------- crash: weglopen tijdens de vlucht ----------
do
	-- Het inzetvenster staat nog open: de inzet hoort terug, en er is niets gespeeld.
	local w = wereld()
	local s, p = meldEen(w)
	w.Crash.begin()
	p.balance = 100
	w.Crash.bet(s, 100)
	h.check("de inzet is afgeschreven", 0, p.balance)
	w.vertrek(s)
	h.check("wie voor de start weggaat krijgt zijn inzet terug", 100, w.store.data["speler_1"].balance)
	h.check("en er is geen ronde geboekt", 0, w.store.data["speler_1"].stats.crash.rounds)
end

do
	-- De vlucht loopt al. Uitstappen kan niet meer, dus de inzet is weg -- en dat hoort in
	-- zijn statistieken te staan. Gebeurt dat niet, dan is het geld wel afgeschreven maar
	-- telt de ronde nergens mee.
	local w = wereld()
	local s, p = meldEen(w)
	w.Crash.begin()
	p.balance = 100
	w.Crash.bet(s, 100)
	w.Crash.takeOff()
	w.vertrek(s)

	local bewaard = w.store.data["speler_1"]
	h.check("de inzet komt niet terug", 0, bewaard.balance)
	h.check("de ronde is geboekt", 1, bewaard.stats.crash.rounds)
	h.check("als verloren", 1, bewaard.stats.crash.lost)
	h.check("met de inzet als verlies", -100, w.Money.round2(bewaard.stats.crash.profit))

	-- En aan het eind van de ronde niet nog een keer.
	w.Crash.blowUp()
	h.check("de ronde wordt niet dubbel geboekt", 1, bewaard.stats.crash.rounds)
end

-- ---------- crash: twee spelers met dezelfde weergavenaam ----------
do
	-- In Roblox is een weergavenaam niet uniek. Herkende het scherm zijn eigen inzet aan
	-- die naam, dan las een speler de stand van zijn naamgenoot: uitgestapt terwijl zijn
	-- eigen geld nog in de lucht hing, of andersom. Daarom gaat het nummer mee.
	local w = wereld()
	local een = w.speler(1, "aap", "Lucky")
	local twee = w.speler(2, "noot", "Lucky")
	w.Players.PlayerAdded:Fire(een)
	w.Players.PlayerAdded:Fire(twee)
	w.Profiles.load(een)
	w.Profiles.load(twee)

	w.Crash.begin()
	w.Crash.bet(een, 10)
	w.Crash.bet(twee, 20)

	local rijen = w.Crash.state().bets
	h.check("beide inzetten staan in het beeld", 2, #rijen)

	local perId = {}
	for _, b in rijen do
		h.check("elke rij draagt een spelersnummer", "number", typeof(b.id))
		perId[b.id] = b
	end
	h.check("de eerste speler vindt zijn eigen inzet", 10, perId[1].bet)
	h.check("en de tweede die van hem", 20, perId[2].bet)
	h.check("ze delen wel dezelfde weergavenaam", perId[1].naam, perId[2].naam)

	-- Stapt de een uit, dan verandert alleen zijn eigen rij.
	w.Crash.takeOff()
	w.Crash.cashOut(een)
	local na = {}
	for _, b in w.Crash.state().bets do na[b.id] = b end
	h.check("de uitstapper staat als uitgestapt", true, na[1].cashed ~= nil)
	h.check("zijn naamgenoot niet", nil, na[2].cashed)
end

-- ---------- crash: automatisch uitstappen ----------
-- Dit hoort op de server te gebeuren. Deed het scherm het, dan moest het de multiplier
-- zien, de vraag over de lijn sturen en wachten tot de server hem oppakte -- en bij een
-- haperende verbinding komt hij na de klap aan. Dan ben je je hele inzet kwijt terwijl het
-- spel een vast getal belooft. De server kent het crashpunt al, dus hij kan op de cent.
do
	local w = wereld()
	local s, p = meldEen(w)

	-- Een zaad dat een ronde geeft die ver genoeg komt.
	w.Crash.setSeeder(function() return "test-hoog" end)
	for _ = 1, 200 do
		w.Crash.begin()
		if w.Crash.state().phase == "waiting" then break end
	end

	p.balance = 100
	local gezet = w.Crash.bet(s, 100, 2)
	h.check("de inzet met een doel lukt", true, gezet.ok)
	h.check("de server geeft het doel terug", 2, gezet.auto)

	local rij = w.Crash.state().bets[1]
	h.check("het doel staat in het beeld", 2, rij.auto)

	w.Crash.takeOff()
	local crashAt = w.Crash.huidigCrashPunt()
	if crashAt >= 2 then
		-- De vlucht haalt het doel: uitstappen op precies twee keer, niet op wat de klok
		-- toevallig aanwees toen een verzoek binnenkwam.
		w.Crash.autoSettle(2)
		local na = w.Crash.state().bets[1]
		h.check("er is automatisch uitgestapt", 2, na.cashed)
		h.check("en wel op precies het doel", 200, na.payout)
		h.check("het saldo klopt", 200, p.balance)

		-- Nog eens afrekenen mag niets meer doen.
		w.Crash.autoSettle(5)
		h.check("niet twee keer uitbetaald", 200, p.balance)

		w.Crash.blowUp()
		h.check("en de ronde is een keer geboekt", 1, w.Profiles.get(s).stats.crash.rounds)
		h.check("als gewonnen", 1, w.Profiles.get(s).stats.crash.won)
	end
end

do
	-- Een doel boven het crashpunt wordt niet gehaald; dan is de inzet gewoon weg.
	local w = wereld()
	local s, p = meldEen(w)
	w.Crash.begin()
	p.balance = 100
	w.Crash.bet(s, 100, 1000000)
	w.Crash.takeOff()
	w.Crash.autoSettle(1000000)
	h.check("een doel boven het crashpunt haalt het niet", nil, w.Crash.state().bets[1].cashed)
	w.Crash.blowUp()
	h.check("en de inzet is weg", 0, p.balance)
	h.check("de ronde telt als verloren", 1, w.Profiles.get(s).stats.crash.lost)
end

do
	-- Wat de client als doel opstuurt gaat door dezelfde zeef als een bedrag.
	local w = wereld()
	local s, p = meldEen(w)
	local function doelNa(waarde: any): any
		w.Crash.begin()
		p.balance = 1000
		local r = w.Crash.bet(s, 10, waarde)
		local uit = if r.ok then r.auto else nil
		w.Crash.takeOff()
		w.Crash.blowUp()
		return uit
	end
	h.check("geen doel is geen doel", nil, doelNa(nil))
	h.check("tekst is geen doel", nil, doelNa("straks"))
	h.check("onder 1,01 telt niet", nil, doelNa(1))
	h.check("nul telt niet", nil, doelNa(0))
	h.check("negatief telt niet", nil, doelNa(-5))
	h.check("oneindig telt niet", nil, doelNa(math.huge))
	h.check("NaN telt niet", nil, doelNa(0 / 0))
	h.check("belachelijk hoog telt niet", nil, doelNa(1e12))
	h.check("een gewoon doel telt wel", 2.5, doelNa(2.5))
	h.check("en wordt op de cent gezet", 1.34, doelNa(1.3357))
end

-- ---------- blackjack: eenentwintig staat vanzelf ----------
-- In de webversie blijft de hand staan zodra hij precies eenentwintig is
-- (`else if (v === 21) bjStand()`). Zonder dat kan een speler op eenentwintig nog een kaart
-- vragen en zich kapot trekken -- een verlies dat nergens door hoeft.
do
	local w = wereld()
	local s, p = meldEen(w)

	local zag21, zagMinder = false, false
	for _ = 1, 400 do
		if zag21 and zagMinder then break end
		p.balance = 1000
		local gedeeld = w.Blackjack.deal(s, 10)
		local r = w.Blackjack.get(s)
		if gedeeld.ok and r then
			-- Een hand van elf: de volgende kaart maakt er twaalf tot eenentwintig van.
			r.speler = { { r = "5", s = "\u{2660}" }, { r = "6", s = "\u{2665}" } }
			local na = w.Blackjack.act(s, "hit")
			local totaal = (w.Odds.bjValue(na.player or {}))
			if totaal == 21 and not zag21 then
				zag21 = true
				h.check("op eenentwintig is de hand afgerekend", true, na.done == true)
				h.check("en er staat niets meer open", nil, w.Blackjack.get(s))
			elseif totaal < 21 and not zagMinder then
				zagMinder = true
				h.check("onder eenentwintig loopt de hand door", false, na.done == true)
				h.check("en de hand staat nog open", true, w.Blackjack.get(s) ~= nil)
				w.Blackjack.act(s, "stand")
			elseif w.Blackjack.get(s) then
				w.Blackjack.refund(s)
			end
		end
	end
	h.check("er is een hand van precies eenentwintig gezien", true, zag21)
	h.check("en een hand die eronder bleef", true, zagMinder)
end

-- ---------- crash: het doel bijstellen terwijl de ronde loopt ----------
do
	local w = wereld()
	local s, p = meldEen(w)
	w.Crash.begin()
	p.balance = 100
	w.Crash.bet(s, 100)
	h.check("zonder doel begonnen", nil, w.Crash.state().bets[1].auto)

	local gezet = w.Crash.setAuto(s, 3)
	h.check("een doel bijzetten lukt", true, gezet.ok)
	h.check("en staat in het beeld", 3, w.Crash.state().bets[1].auto)

	h.check("weer uitzetten lukt ook", true, w.Crash.setAuto(s, nil).ok)
	h.check("en dan staat er geen doel meer", nil, w.Crash.state().bets[1].auto)

	-- Wat de client stuurt gaat door dezelfde zeef als bij het inzetten.
	w.Crash.setAuto(s, "straks")
	h.check("tekst wordt geen doel", nil, w.Crash.state().bets[1].auto)
	w.Crash.setAuto(s, 0 / 0)
	h.check("NaN wordt geen doel", nil, w.Crash.state().bets[1].auto)
	w.Crash.setAuto(s, 1)
	h.check("onder 1,01 wordt geen doel", nil, w.Crash.state().bets[1].auto)
end

do
	-- Een doel onder de multiplier van dit moment is al voorbij. Dan is het hetzelfde als
	-- op de knop drukken: meteen afrekenen op de stand van nu, niet op het lagere doel.
	-- Zo levert laag zetten nooit minder op dan zelf uitstappen.
	local w = wereld()
	local s, p = meldEen(w)

	-- Een ronde zoeken die ver genoeg komt, zodat de tak hieronder altijd draait.
	local crashAt = 0
	for _ = 1, 500 do
		w.Crash.begin()
		crashAt = w.Crash.huidigCrashPunt()
		if crashAt > 3 then break end
		w.Crash.takeOff()
		w.Crash.blowUp()
	end
	h.check("er is een ronde gevonden die ver genoeg komt", true, crashAt > 3)

	p.balance = 100
	w.Crash.bet(s, 100)
	w.Crash.takeOff()
	w.wacht(10)   -- de vlucht is een eind op weg

	local nu = math.min(w.Crash.multAt(10), crashAt)
	if nu > 1.2 then
		local uit = w.Crash.setAuto(s, 1.01)
		h.check("een doel dat al voorbij is rekent meteen af", true, uit.ok)
		h.check("en wel op de stand van nu, niet op 1,01", true, (uit.mult or 0) > 1.01)
		h.check("dus meer dan het lage doel zou geven", true, (uit.payout or 0) > 101)
	end
end

do
	-- Een inzet die al beslist is kun je niet meer bijstellen.
	local w = wereld()
	local s, p = meldEen(w)
	w.Crash.begin()
	p.balance = 100
	w.Crash.bet(s, 100)
	w.Crash.takeOff()
	w.Crash.cashOut(s)
	h.check("na uitstappen is er niets meer bij te stellen", false, w.Crash.setAuto(s, 5).ok)

	-- En zonder inzet ook niet.
	local w2 = wereld()
	local s2 = meldEen(w2)
	w2.Crash.begin()
	h.check("zonder inzet kan het niet", false, w2.Crash.setAuto(s2, 5).ok)
end

-- ---------- de ranglijst krijgt alles wat de drie kolommen nodig hebben ----------
-- De pagina heeft MOST MONEY, WIN / LOSS RATIO en SPRINT PROFIT naast elkaar staan. Een
-- OrderedDataStore sorteert op één getal, dus er moeten drie getallen langskomen. Ging er
-- alleen de sprintwinst mee -- zoals eerst -- dan blijven twee van de drie kolommen leeg.
do
	local w = wereld()
	local s, p = meldEen(w)

	local gezien: any = nil
	w.Profiles.setPublisher(function(speler, sprint, winst, saldo, gewonnen, verloren)
		gezien = {
			id = speler.UserId, sprint = sprint, winst = winst,
			saldo = saldo, gewonnen = gewonnen, verloren = verloren,
		}
	end)

	p.balance = 1234.5
	p.sprintProfit = 234.5
	p.stats.crash = { rounds = 6, won = 4, lost = 2, profit = 100, highest = 3 }
	p.stats.mines = { rounds = 5, won = 1, lost = 4, profit = -50, highest = 0 }

	w.Profiles.save(s)
	h.check("de ranglijst is bijgewerkt", true, gezien ~= nil)
	h.check("met de juiste speler", 1, gezien.id)
	h.check("de sprintwinst gaat mee", 234.5, gezien.winst)
	h.check("het saldo ook", 1234.5, gezien.saldo)
	-- Alle spellen bij elkaar opgeteld, zoals lbRatio het in de webversie doet.
	h.check("en het aantal gewonnen rondes over alle spellen", 5, gezien.gewonnen)
	h.check("en het aantal verloren rondes", 6, gezien.verloren)
end

h.report("SERVER")
