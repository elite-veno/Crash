--!nolint
-- De gedeelde crashronde, gedraaid op de echte servercode. Hier wordt bewezen waar het bij
-- crash om draait: de server bepaalt de multiplier op zijn eigen klok, het crashpunt ligt
-- vast voordat er iemand inzet, en dat is achteraf na te rekenen.
local Stub = require("./roblox_stub")
local h = require("./harness")

local function wereld()
	return Stub.wereld()
end

-- Een zaad zoeken dat een lange ronde geeft, zodat er tijd is om uit te stappen. Het is
-- een gewone zoektocht door vaste zaden: elke keer dezelfde uitkomst.
local function zaadMetCrashBoven(w, ondergrens: number): (string, number)
	for i = 1, 5000 do
		local zaad = "test-zaad-" .. i
		local c = w.Odds.crashPoint(w.Sha256.unit(w.Sha256.hash(zaad)))
		if c >= ondergrens then return zaad, c end
	end
	error("geen zaad gevonden")
end

-- ---------- de belofte vooraf ----------
do
	local w = wereld()
	local zaad, crash = zaadMetCrashBoven(w, 3)
	w.Crash.setSeeder(function() return zaad end)
	w.Crash.begin()

	local st = w.Crash.state()
	h.check("de ronde staat op inzetten", "waiting", st.phase)
	h.check("er is een belofte gepubliceerd", w.Sha256.commit(zaad), st.commit)
	h.check("het zaad is nog niet vrijgegeven", nil, st.seed)
	h.check("het crashpunt is nog niet vrijgegeven", nil, st.crashAt)
	h.check("het eindtijdstip ook niet", nil, st.endsAt)
	h.check("het inzetvenster sluit acht seconden later", 8, st.startsAt - st.now)

	-- Precies dit is het bewijs: het crashpunt volgt uit het zaad, en het zaad zat al in
	-- de belofte. De server kon het dus niet bijstellen toen hij de inzetten zag.
	w.Crash.takeOff()
	w.Crash.blowUp()
	local na = w.Crash.state()
	h.check("na afloop komt het zaad vrij", zaad, na.seed)
	h.check("de belofte hoort bij dat zaad", na.commit, w.Sha256.commit(na.seed))
	h.check("het crashpunt volgt uit het zaad", crash, na.crashAt)
	h.check("en dat is na te rekenen zonder de code",
		w.Odds.crashPoint(w.Sha256.unit(w.Sha256.hash(na.seed))), na.crashAt)
end

-- ---------- inzetten ----------
do
	local w = wereld()
	local zaad = zaadMetCrashBoven(w, 5)
	w.Crash.setSeeder(function() return zaad end)
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Crash.begin()

	local r = w.Crash.bet(s, 100)
	h.check("inzetten mag in het venster", true, r.ok)
	h.check("de inzet is afgeschreven", 900, w.Profiles.get(s).balance)

	local nog = w.Crash.bet(s, 50)
	h.check("twee keer inzetten in één ronde mag niet", false, nog.ok)
	h.check("en er is niets extra afgeschreven", 900, w.Profiles.get(s).balance)

	h.check("uitstappen voor de start mag niet", false, w.Crash.cashOut(s).ok)

	w.wacht(8)
	w.Crash.takeOff()
	h.check("inzetten na de start mag niet", false, w.Crash.bet(s, 10).ok)
end

-- ---------- uitstappen op de klok van de server ----------
do
	local w = wereld()
	local zaad, crash = zaadMetCrashBoven(w, 20)
	w.Crash.setSeeder(function() return zaad end)
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Crash.begin()
	w.Crash.bet(s, 100)
	w.wacht(8)
	w.Crash.takeOff()

	-- Vier seconden in de vlucht.
	w.wacht(4)
	local r = w.Crash.cashOut(s)
	h.check("uitstappen lukt tijdens de vlucht", true, r.ok)
	h.near("de multiplier hoort bij vier seconden", w.Crash.multAt(4), r.mult, 1e-9)
	h.check("de uitbetaling is inzet maal multiplier", w.Money.floor2(100 * r.mult), r.payout)
	h.check("het saldo klopt", w.Money.round2(900 + r.payout), w.Profiles.get(s).balance)

	h.check("twee keer uitstappen mag niet", false, w.Crash.cashOut(s).ok)
end

-- ---------- te laat is te laat ----------
do
	local w = wereld()
	local zaad, crash = zaadMetCrashBoven(w, 10)
	w.Crash.setSeeder(function() return zaad end)
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Crash.begin()
	w.Crash.bet(s, 100)
	w.wacht(8)
	w.Crash.takeOff()
	w.wacht(w.Crash.durationFor(crash) + 0.01)

	local r = w.Crash.cashOut(s)
	h.check("na het crashpunt kun je er niet meer uit", false, r.ok)
	h.check("de inzet is weg", 900, w.Profiles.get(s).balance)

	w.Crash.blowUp()
	h.check("de ronde staat op gecrasht", "crashed", w.Crash.state().phase)
end

-- ---------- de multiplier loopt nooit voorbij het crashpunt ----------
do
	local w = wereld()
	local zaad, crash = zaadMetCrashBoven(w, 2)
	w.Crash.setSeeder(function() return zaad end)
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Crash.begin()
	w.Crash.bet(s, 100)
	w.wacht(8)
	w.Crash.takeOff()
	-- Net voor het eind uitstappen: de multiplier mag nooit boven het crashpunt uitkomen.
	w.wacht(w.Crash.durationFor(crash) - 0.0001)
	local r = w.Crash.cashOut(s)
	h.check("uitstappen op de valreep lukt", true, r.ok)
	h.check("de multiplier blijft onder het crashpunt", true, r.mult <= crash)
end

-- ---------- de rekensom zelf ----------
do
	local w = wereld()
	h.near("bij nul seconden staat hij op 1", 1, w.Crash.multAt(0), 1e-9)
	h.check("negatieve tijd geeft ook 1", 1, w.Crash.multAt(-5))
	for _, c in {1.5, 2, 5, 10, 100} do
		local t = w.Crash.durationFor(c)
		h.near("na de duur van " .. c .. " staat hij op " .. c, c, w.Crash.multAt(t), 0.01)
	end
	h.check("de multiplier loopt op", true, w.Crash.multAt(10) > w.Crash.multAt(5))
end

-- ---------- wat er naar de clients gaat ----------
do
	local w = wereld()
	local zaad = zaadMetCrashBoven(w, 4)
	w.Crash.setSeeder(function() return zaad end)
	w.Crash.begin()
	w.wacht(8)
	w.Crash.takeOff()

	local lek = 0
	for _, bericht in w.geduwd do
		local l = bericht.lading
		if l and l.phase ~= "crashed" and (l.seed or l.crashAt) then lek += 1 end
	end
	h.check("voor de crash gaat er geen zaad of crashpunt naar de client", 0, lek)
	h.check("er is wel iets geduwd", true, #w.geduwd >= 2)

	w.Crash.blowUp()
	local laatste = w.geduwd[#w.geduwd].lading
	h.check("de laatste boodschap is de crash", "crashed", laatste.phase)
	h.check("en die draagt het zaad", zaad, laatste.seed)
end

-- ---------- weggaan ----------
do
	local w = wereld()
	local zaad = zaadMetCrashBoven(w, 8)
	w.Crash.setSeeder(function() return zaad end)
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Crash.begin()
	w.Crash.bet(s, 200)
	h.check("de inzet staat in het spel", 800, w.Profiles.get(s).balance)
	w.vertrek(s)
	h.check("weggaan voor de start geeft de inzet terug", 1000, w.store.data["speler_1"].balance)
end

do
	local w = wereld()
	local zaad = zaadMetCrashBoven(w, 8)
	w.Crash.setSeeder(function() return zaad end)
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	w.Crash.begin()
	w.Crash.bet(s, 200)
	w.wacht(8)
	w.Crash.takeOff()
	w.vertrek(s)
	h.check("weggaan tijdens de vlucht is gewoon verloren", 800, w.store.data["speler_1"].balance)
end

h.report("CRASH")
