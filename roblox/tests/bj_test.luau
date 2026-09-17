--!nolint
-- Blackjack op de echte servercode. Twee dingen worden hier bewezen: dat de dichte kaart
-- van de dealer niet naar de client gaat zolang de speler aan zet is, en dat het geld bij
-- elke hand klopt -- ook bij een dubbele inzet, want daar ging de webversie de mist in.
local Stub = require("./roblox_stub")
local h = require("./harness")

math.randomseed(20260917)

local function wereld()
	return Stub.wereld()
end

-- Een hand uitspelen tot hij klaar is. Stopt ook als de server "geen hand" zegt: dat
-- gebeurt na een dubbel, want dat rekent de hand meteen af.
local function speelUit(w, s, r)
	while r and r.ok ~= false and not r.done do
		r = w.Blackjack.act(s, if r.playerValue >= 17 then "stand" else "hit")
	end
	return r
end

-- ---------- de dichte kaart ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)

	local lek, handen = 0, 0
	for _ = 1, 200 do
		local r = w.Blackjack.deal(s, 10)
		if not r.done then
			handen += 1
			-- De hele tweede kaart van de dealer hoort er niet in te zitten. Niet
			-- verborgen in een veld: er niet.
			if r.dealer ~= nil then lek += 1 end
			if r.dealerUp == nil then lek += 1 end
			-- Doorhitten tot het klaar is, en bij elke tussenstand opnieuw kijken.
			while r.ok ~= false and not r.done do
				if r.playerValue >= 17 then
					r = w.Blackjack.act(s, "stand")
				else
					r = w.Blackjack.act(s, "hit")
					if not r.done and r.dealer ~= nil then lek += 1 end
				end
			end
		end
		-- De hand is uit: nu mag de hele hand van de dealer er wel in zitten.
		if r.dealer == nil then lek += 1 end
	end
	h.check("de dichte kaart lekt nooit", 0, lek)
	h.check("er zijn handen gespeeld waarbij gekozen moest worden", true, handen > 50)
end

-- ---------- het geld klopt bij elke hand ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.balance = 1000000   -- ruim genoeg om vierhonderd handen te spelen

	local gezien = { win = 0, loss = 0, push = 0, natural = 0, bust = 0 }
	local fout = 0
	for _ = 1, 400 do
		local voor = w.Profiles.get(s).balance
		local inzet = 10
		local r = speelUit(w, s, w.Blackjack.deal(s, inzet))
		local na = w.Profiles.get(s).balance
		-- Wat er van het saldo af ging min wat erop kwam, moet precies de inzet en de
		-- uitbetaling zijn. Geen cent ertussen.
		if math.abs(na - (voor - r.bet + r.payout)) > 1e-9 then fout += 1 end
		if r.playerValue > 21 then gezien.bust += 1 end
		if r.natural then gezien.natural += 1 end
		gezien[r.result] += 1
	end
	h.check("elke hand is tot op de cent geboekt", 0, fout)
	h.check("er is gewonnen", true, gezien.win > 20)
	h.check("er is verloren", true, gezien.loss > 20)
	h.check("er is gelijkgespeeld", true, gezien.push > 5)
	h.check("er lag blackjack op tafel", true, gezien.natural > 5)
	h.check("er is doorgeslagen", true, gezien.bust > 5)
end

-- ---------- blackjack betaalt drie op twee ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.balance = 1000000
	local gevonden = 0
	for _ = 1, 600 do
		local r = w.Blackjack.deal(s, 20)
		if r.done and r.natural and r.result == "win" then
			gevonden += 1
			h.near("blackjack betaalt 2,5 keer de inzet", 50, r.payout, 1e-9)
			if gevonden >= 3 then break end
		end
		speelUit(w, s, r)
	end
	h.check("er is minstens één blackjack gezien", true, gevonden >= 1)
end

-- ---------- dubbelen ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.balance = 1000000

	local gedubbeld, fout = 0, 0
	for _ = 1, 400 do
		local voor = w.Profiles.get(s).balance
		local r = w.Blackjack.deal(s, 10)
		if not r.done then
			local naDeal = w.Profiles.get(s).balance
			h.check("de eerste helft van de inzet is afgeschreven", true, math.abs(voor - naDeal - 10) < 1e-9)
			local d = w.Blackjack.act(s, "double")
			if d.ok ~= false then
				gedubbeld += 1
				-- Dubbelen schrijft nog een keer de inzet af en rekent af op het dubbele.
				h.check("de hand telt als dubbel", true, d.doubled)
				h.check("de inzet is verdubbeld", 20, d.bet)
				h.check("de hand is meteen uit", true, d.done)
				local na = w.Profiles.get(s).balance
				if math.abs(na - (voor - 20 + d.payout)) > 1e-9 then fout += 1 end
				-- Na het dubbelen zijn het er precies drie: twee plus de dubbelkaart.
				if #d.player ~= 3 then fout += 1 end
				r = d
				if gedubbeld > 100 then break end
			end
		end
		speelUit(w, s, r)
	end
	h.check("er is gedubbeld", true, gedubbeld > 20)
	h.check("elke dubbele hand is goed geboekt", 0, fout)
end

-- ---------- dubbelen mag niet altijd ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	p.balance = 1000000

	-- Na een hit zijn het er drie, en dan mag dubbelen niet meer.
	local geprobeerd = 0
	for _ = 1, 200 do
		local r = w.Blackjack.deal(s, 10)
		if not r.done and r.playerValue < 12 then
			r = w.Blackjack.act(s, "hit")
			if not r.done then
				geprobeerd += 1
				h.check("dubbelen na een hit mag niet", false, w.Blackjack.act(s, "double").ok)
				if geprobeerd >= 5 then
					speelUit(w, s, r)
					break
				end
			end
		end
		speelUit(w, s, r)
	end
	h.check("dat is echt geprobeerd", true, geprobeerd >= 1)

	-- Twee keer dubbelen mag ook niet.
	for _ = 1, 200 do
		local r = w.Blackjack.deal(s, 10)
		if not r.done then
			local d = w.Blackjack.act(s, "double")
			if d.ok ~= false then
				-- Een dubbele hand is meteen uit, dus een tweede dubbel vindt geen hand.
				h.check("twee keer dubbelen mag niet", false, w.Blackjack.act(s, "double").ok)
				break
			end
			speelUit(w, s, r)
		end
	end

	h.check("een zet die niet bestaat wordt geweigerd", false, w.Blackjack.act(s, "split").ok)
	h.check("een zet zonder hand wordt geweigerd", false, w.Blackjack.act(s, "hit").ok)
end

-- ---------- weggaan met een hand open ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	local p = w.Profiles.load(s)
	-- Net zo lang delen tot er een hand open blijft staan; het saldo houden we op peil.
	local r = w.Blackjack.deal(s, 100)
	for _ = 1, 200 do
		if r.ok ~= false and not r.done then break end
		p.balance = 1000
		r = w.Blackjack.deal(s, 100)
	end
	h.check("er staat een hand open", true, r.ok ~= false and not r.done)
	h.check("de inzet staat in het spel", 900, p.balance)
	w.vertrek(s)
	h.check("weggaan met een hand open geeft de inzet terug", 1000, w.store.data["speler_1"].balance)
end

do
	local w = wereld()
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	h.check("zonder hand valt er niets terug te geven", 0, w.Blackjack.refund(s))
end

-- ---------- de inzet zelf ----------
do
	local w = wereld()
	local s = w.speler(1, "Aap")
	w.Profiles.load(s)
	h.check("een inzet van nul mag niet", false, w.Blackjack.deal(s, 0).ok)
	h.check("een inzet boven je saldo mag niet", false, w.Blackjack.deal(s, 5000).ok)
	h.check("een inzet van NaN mag niet", false, w.Blackjack.deal(s, 0 / 0).ok)
	h.check("tekst mag niet", false, w.Blackjack.deal(s, "veel").ok)
	h.check("het saldo staat er nog", 1000, w.Profiles.get(s).balance)
	-- Net zo lang delen tot er een hand blijft staan: een hand die meteen uit is (twee
	-- keer blackjack bijvoorbeeld) blokkeert de volgende terecht niet.
	local r = w.Blackjack.deal(s, 10)
	h.check("een gewone inzet mag wel", true, r.ok)
	for _ = 1, 50 do
		if not r.done then break end
		w.Profiles.get(s).balance = 1000
		r = w.Blackjack.deal(s, 10)
	end
	h.check("er staat een hand open", true, not r.done)
	h.check("twee handen tegelijk mag niet", false, w.Blackjack.deal(s, 10).ok)
end

h.report("BLACKJACK")
