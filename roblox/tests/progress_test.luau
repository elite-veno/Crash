--!nolint
-- Seizoenen, sprints, prestaties en de VIP-poort, op de echte servercode. Dit is de kant
-- waar een speler iets verdient dat blijft staan, dus hier telt het dat het klopt.
local Stub = require("./roblox_stub")
local h = require("./harness")

local function wereld()
	return Stub.wereld()
end

-- ---------- de VIP-poort ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)

	h.check("zonder pas kom je niet bij 777", false, w.Games.slots(s, 10).ok)
	h.check("en niet bij de bus", false, w.Multi.busStart(s, 10).ok)
	h.check("er is niets afgeschreven", 1000, p.balance)
	h.check("de reden staat erbij", "vip pass required", w.Games.slots(s, 10).err)

	-- Een pas voor dit seizoen zet de deur open.
	p.vipSeason = w.Season.seasonId()
	h.check("met een pas mag 777 wel", true, w.Games.slots(s, 10).ok)
	h.check("en de bus ook", true, w.Multi.busStart(s, 10).ok)

	-- Een pas van een vorig seizoen niet.
	w.Multi.busCashOut(s)
	p.vipSeason = w.Season.seasonId() - 1
	h.check("een verlopen pas telt niet", false, w.Games.slots(s, 10).ok)
	-- En een pas voor een seizoen dat nog moet komen ook niet.
	p.vipSeason = w.Season.seasonId() + 1
	h.check("een pas voor later telt ook niet", false, w.Games.slots(s, 10).ok)
end

-- ---------- het seizoen slaat om ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)

	p.balance = 12000
	p.resetSeason = w.Season.seasonId() - 1
	w.Profiles.rollOver(s, p)
	h.check("je houdt duizend plus een tiende van de rest", 2100, p.balance)
	h.check("het seizoen staat bij", w.Season.seasonId(), p.resetSeason)
	h.check("en de sprintstand begint opnieuw", 0, p.sprintProfit)

	-- Nog een keer omslaan in hetzelfde seizoen doet niets.
	w.Profiles.rollOver(s, p)
	h.check("binnen een seizoen verandert er niets meer", 2100, p.balance)
end

do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.balance = 400
	p.resetSeason = w.Season.seasonId() - 1
	w.Profiles.rollOver(s, p)
	h.check("onder de duizend ga je terug naar duizend", 1000, p.balance)
end

do
	-- Een verlopen pas wordt bij binnenkomst opgeruimd.
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.vipSeason = w.Season.seasonId() - 2
	w.Profiles.rollOver(s, p)
	h.check("een verlopen pas verdwijnt", nil, p.vipSeason)

	p.vipSeason = w.Season.seasonId()
	w.Profiles.rollOver(s, p)
	h.check("een geldige pas blijft staan", w.Season.seasonId(), p.vipSeason)
end

-- ---------- de prijzen van de vorige sprint ----------
local function metUitslag(plaats)
	local w = wereld()
	w.Profiles.setPlaceLookup(function(_sprint, _id)
		return plaats
	end)
	-- De uitslag staat klaar voordat het profiel geladen wordt, want Profiles.load doet
	-- de omslag zelf. Nog een keer rollOver aanroepen hoeft dus niet.
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	return w, s, p
end

do
	local w, s, p = metUitslag(1)
	local vorige = w.Season.sprintId() - 1
	h.check("de winnaar krijgt de titel Kampioen", "Kampioen S" .. vorige, p.title)
	h.check("die titel staat in zijn kast", 1, #p.titles)
	h.check("en hij krijgt een pas", w.Season.vipSeasonFor(vorige), p.vipSeason)
	h.check("die pas geldt nu", true, w.Season.vipActive(p.vipSeason))
	h.check("dus mag hij naar 777", true, w.Games.slots(s, 10).ok)
	h.check("de sprint is afgehandeld", vorige, p.awardedSprint)

	-- En niet nog een keer, ook niet als de teller wordt teruggezet.
	local titels = #p.titles
	w.Profiles.rollOver(s, p)
	h.check("dezelfde sprint levert niet twee keer een titel op", titels, #p.titles)
	p.awardedSprint = nil
	w.Profiles.rollOver(s, p)
	h.check("en zelfs met de teller terug niet", titels, #p.titles)
end

do
	local w, _s, p = metUitslag(2)
	h.check("nummer twee krijgt een titel", "Tweede S" .. (w.Season.sprintId() - 1), p.title)
	h.check("maar geen pas", nil, p.vipSeason)
end

do
	local w, _s, p = metUitslag(3)
	h.check("nummer drie krijgt een titel", "Derde S" .. (w.Season.sprintId() - 1), p.title)
	h.check("en ook geen pas", nil, p.vipSeason)
end

do
	local w, _s, p = metUitslag(4)
	h.check("nummer vier krijgt niets", nil, p.title)
	h.check("en geen pas", nil, p.vipSeason)
	h.check("maar de sprint is wel afgehandeld", w.Season.sprintId() - 1, p.awardedSprint)
end

do
	local _w, _s, p = metUitslag(nil)
	h.check("wie er niet bij stond krijgt niets", nil, p.title)
end

-- ---------- de sprintstand ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	h.check("een verse speler staat op nul", 0, p.sprintProfit)

	-- Een gewonnen ronde telt op, een verloren telt af.
	w.Profiles.record(s, "wheel", 100, 250, 2.5)
	h.check("winst telt op", 150, p.sprintProfit)
	w.Profiles.record(s, "wheel", 100, 0, 0)
	h.check("verlies telt af", 50, p.sprintProfit)

	-- Bij een nieuwe sprint begint hij opnieuw.
	p.sprint = w.Season.sprintId() - 1
	w.Profiles.record(s, "wheel", 10, 20, 2)
	h.check("een nieuwe sprint begint bij nul", 10, p.sprintProfit)
	h.check("en staat op de lopende sprint", w.Season.sprintId(), p.sprint)
end

-- ---------- prestaties gaan open door te spelen ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)

	local gemeld = {}
	w.Profiles.onUnlock(function(_sp, ids)
		for _, id in ids do table.insert(gemeld, id) end
	end)

	h.check("een verse speler heeft niets", 0, (function()
		local n = 0
		for _ in p.achievements do n += 1 end
		return n
	end)())

	w.Games.wheel(s, 10)
	h.check("de eerste inzet gaat open", true, p.achievements.first_bet ~= nil)
	h.check("en dat wordt gemeld", true, table.find(gemeld, "first_bet") ~= nil)
	h.check("de tijd staat erbij", true, p.achievements.first_bet > 0)

	-- Wat al open staat gaat niet nog een keer open.
	local voor = #gemeld
	w.Games.wheel(s, 10)
	local nogSteeds = 0
	for _, id in gemeld do
		if id == "first_bet" then nogSteeds += 1 end
	end
	h.check("de eerste inzet gaat maar één keer open", 1, nogSteeds)
end

do
	-- Een grote winst opent er meteen een paar.
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.balance = 20000
	w.Profiles.record(s, "crash", 100, 3000, 30)
	h.check("saldo boven 2500", true, p.achievements.balance_2500 ~= nil)
	h.check("saldo boven 10000", true, p.achievements.balance_10k ~= nil)
	h.check("grote klapper", true, p.achievements.big_win_500 ~= nil)
	h.check("hoog gevlogen", true, p.achievements.crash_5x ~= nil)
	h.check("stratosfeer", true, p.achievements.crash_20x ~= nil)
	h.check("het record voor crash staat genoteerd", 30, p.extra.max.crash)
end

do
	-- Een gewonnen dubbele hand bij blackjack.
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	w.Profiles.record(s, "blackjack", 20, 40, 2, { doubled = true })
	h.check("een gewonnen dubbele hand telt", true, p.achievements.bj_double ~= nil)
	h.check("maar blackjack nog niet", nil, p.achievements.bj_natural)
end

do
	-- De toren op master.
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	-- Eraf vallen boekt niets: `Tower keeper` gaat over uitstappen, niet over klimmen.
	w.Profiles.record(s, "tower", 10, 0, 0, { level = 9, diff = "master" })
	h.check("een gevallen ronde telt niet", nil, p.achievements.tw_top)
	h.check("en master ook niet", nil, p.achievements.tw_master)

	w.Profiles.record(s, "tower", 10, 500, 50, { level = 5, diff = "master" })
	h.check("gewonnen op master telt wel", true, p.achievements.tw_master ~= nil)
	h.check("maar vijf verdiepingen is nog geen negen", nil, p.achievements.tw_top)

	w.Profiles.record(s, "tower", 10, 900, 90, { level = 9, diff = "easy" })
	h.check("negen verdiepingen binnengehaald telt wel", true, p.achievements.tw_top ~= nil)
end

-- ---------- de drie badges ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	w.Games.wheel(s, 10)

	h.check("een badge die je niet hebt kun je niet uitlichten", true, w.Profiles.setFeatured(s, {"crash_20x"}))
	h.check("en die staat er dus ook niet", 0, #p.featured)

	h.check("een badge die je wel hebt mag", true, w.Profiles.setFeatured(s, {"first_bet"}))
	h.check("die staat er dan", 1, #p.featured)
	h.check("en het is de goeie", "first_bet", p.featured[1])

	-- Hoogstens drie, en geen dubbele.
	p.achievements.first_win = 1
	p.achievements.rounds_50 = 1
	p.achievements.streak_5 = 1
	w.Profiles.setFeatured(s, {"first_bet", "first_win", "rounds_50", "streak_5"})
	h.check("hoogstens drie badges", 3, #p.featured)
	w.Profiles.setFeatured(s, {"first_bet", "first_bet", "first_win"})
	h.check("geen dubbele", 2, #p.featured)
	w.Profiles.setFeatured(s, {})
	h.check("leeg mag ook", 0, #p.featured)
	h.check("iets dat geen lijst is wordt geweigerd", false, w.Profiles.setFeatured(s, "first_bet"))
end

-- ---------- het boekje overleeft een herstart ----------
do
	local gedeeld = Stub.nieuweStore()
	local a = Stub.wereld({ store = gedeeld })
	local sa = a.speler(9, "Aap")
	local pa = a.Profiles.load(sa)
	a.Profiles.record(sa, "crash", 100, 900, 9, {})
	local record = pa.extra.max.crash
	local reeks = pa.extra.bestStreak
	a.vertrek(sa)

	local b = Stub.wereld({ store = gedeeld })
	local sb = b.speler(9, "Aap")
	local pb = b.Profiles.load(sb)
	h.check("het record staat er na een herstart nog", record, pb.extra.max.crash)
	h.check("de reeks ook", reeks, pb.extra.bestStreak)
	h.check("en de prestaties", true, pb.achievements.crash_5x ~= nil)
end

h.report("VOORTGANG")
