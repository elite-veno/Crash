--!strict
-- Het opstartpunt van de server: de kanalen aanmaken, profielen laden, en elke aanvraag
-- van een speler langs de afrekening leiden. Geen enkele aanvraag draagt een bedrag; de
-- server rekent zelf uit wat eruit komt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Profiles = require(script.Profiles)
local Games = require(script.Games)
local Multi = require(script.Games.Multi)
local Blackjack = require(script.Games.Blackjack)
local Crash = require(script.Crash)
local Ranking = require(script.Ranking)
local Social = require(script.Social)
local Season = require(ReplicatedStorage.Shared.Season)
local Achievements = require(ReplicatedStorage.Shared.Achievements)

Net.build()

-- Profiles regelt het profiel en weet niets van ranglijsten of het netwerk; hier worden
-- die draadjes aan elkaar geknoopt.
Profiles.setPublisher(function(speler, sprint, winst)
	Ranking.publish(speler, sprint, winst)
end)
Profiles.setPlaceLookup(function(sprint, userId)
	return Ranking.placeOf(sprint, userId)
end)
Profiles.onUnlock(function(speler, ids)
	for _, id in ids do
		local a = Achievements.BY_ID[id]
		if a then
			Net.ev("Toast"):FireClient(speler, a.icon .. "  " .. string.upper(a.title), "gold")
		end
	end
end)

local function stuurProfiel(speler: Player)
	local p = Profiles.view(speler)
	if p then
		Net.ev("Profile"):FireClient(speler, p)
	end
end

Players.PlayerAdded:Connect(function(speler)
	Profiles.load(speler)
	stuurProfiel(speler)
end)

-- Weggaan wordt niet hier afgehandeld. Games en Multi hangen hun teruggave als haakje
-- aan Profiles, en Profiles draait die haakjes zelf af voordat het profiel wordt
-- opgeslagen. Met twee losse PlayerRemoving-verbindingen hing dat af van de volgorde
-- waarin ze toevallig gemaakt zijn, en verdween de inzet als het profiel eerst weg was.

for _, speler in Players:GetPlayers() do
	Profiles.load(speler)
	stuurProfiel(speler)
end

-- De gedeelde tafel loopt door, met of zonder spelers erbij.
Crash.start()

-- Het noodfonds is er alleen voor wie echt niets meer heeft. Elk spel dat geld kan
-- vasthouden meldt zich hier aan; Games kent ze dan zonder ze te hoeven vereisen.
Games.addInPlayCheck(Multi.inPlay)
Games.addInPlayCheck(Blackjack.inPlay)
Games.addInPlayCheck(Crash.inPlay)

-- ---------- de aanvragen ----------
-- Eén ingang per soort, met de naam van het spel erbij. Elke tak controleert zelf wat er
-- binnenkomt; niets wordt op zijn woord geloofd.
Net.fn("GetProfile").OnServerInvoke = function(speler)
	return Profiles.view(speler)
end

-- De ranglijst van de lopende sprint, plus waar deze speler zelf staat.
Net.fn("Leaderboard").OnServerInvoke = function(speler, welke)
	local sprint = if welke == "previous" then Season.sprintId() - 1 else Season.sprintId()
	local p = Profiles.get(speler)
	return {
		ok = true,
		sprint = sprint,
		label = Season.sprintLabel(sprint),
		endsAt = Season.sprintEndsAt(sprint),
		seasonEndsAt = Season.seasonEndsAt(Season.seasonId()),
		sprintsLeft = Season.sprintsLeft(),
		now = os.time(),
		top = Ranking.top(sprint, 25),
		mine = if p then p.sprintProfit else 0,
		vipActive = Profiles.vipActive(speler),
	}
end

-- Vrienden en tafels. Roblox kent de vrienden al en heeft al privéservers; die worden
-- gebruikt in plaats van er een eigen, slechtere versie naast te zetten.
Net.fn("Friends").OnServerInvoke = function(speler, actie, gegevens)
	if actie == "list" then
		return { ok = true, friends = Social.friends(speler), here = Social.here() }
	elseif actie == "reserve" then
		return Social.reserve(speler)
	elseif actie == "join" then
		return Social.join(speler, gegevens)
	elseif actie == "quick" then
		return Social.quick(speler)
	end
	return { ok = false, err = "onbekende actie" }
end

-- De drie badges die een speler aan anderen laat zien.
Net.fn("SetFeatured").OnServerInvoke = function(speler, lijst)
	local ok = Profiles.setFeatured(speler, lijst)
	stuurProfiel(speler)
	return { ok = ok }
end

-- De stand van de gedeelde crashronde, voor een speler die er net binnenkomt.
Net.fn("RoundState").OnServerInvoke = function(speler, spel)
	if spel == "crash" then return Crash.state() end
	-- Het paardenveld dat klaarstaat, zodat de quotes op het scherm staan voordat er wordt
	-- ingezet. Zonder deze vraag zou je blind moeten inzetten.
	if spel == "horse" then return Games.horseField(speler) end
	return { ok = false, err = "geen gedeelde tafel" }
end

-- Automatisch uitstappen bijstellen terwijl de ronde loopt.
Net.fn("SetAuto").OnServerInvoke = function(speler, doel)
	local uit = Crash.setAuto(speler, doel)
	stuurProfiel(speler)
	return uit
end

-- NEW ODDS: een nieuw veld voor wie het huidige niet bevalt.
Net.fn("NewOdds").OnServerInvoke = function(speler, spel)
	if spel == "horse" then return Games.horseNewOdds(speler) end
	return { ok = false, err = "dat spel kent geen nieuwe quotes" }
end

-- De VIP-poort staat bij de spellen zelf (Games.slots en Multi.busStart), niet hier: zo kan
-- geen enkele route eromheen, ook geen die er later bij komt.
Net.fn("Bet").OnServerInvoke = function(speler, spel, inzet, a, b)
	local uit
	if spel == "roulette" then uit = Games.roulette(speler, inzet)
	elseif spel == "plinko" then uit = Games.plinko(speler, inzet, a, b)
	elseif spel == "scratch" then uit = Games.scratchBuy(speler, inzet)
	elseif spel == "slots" then uit = Games.slots(speler, inzet)
	elseif spel == "wheel" then uit = Games.wheel(speler, inzet)
	elseif spel == "horse" then uit = Games.horse(speler, inzet)
	elseif spel == "tower" then uit = Multi.towerStart(speler, inzet, a)
	elseif spel == "mines" then uit = Multi.minesStart(speler, inzet, a)
	elseif spel == "bus" then uit = Multi.busStart(speler, inzet)
	elseif spel == "blackjack" then uit = Blackjack.deal(speler, inzet)
	-- Bij crash draagt `a` het doel voor automatisch uitstappen, of niets.
	elseif spel == "crash" then uit = Crash.bet(speler, inzet, a)
	elseif spel == "safety" then uit = Games.safetyOpen(speler)
	else uit = { ok = false, err = "onbekend spel" } end
	stuurProfiel(speler)
	return uit
end

Net.fn("Act").OnServerInvoke = function(speler, spel, zet)
	local uit
	if spel == "tower" then uit = Multi.towerPick(speler, zet)
	elseif spel == "mines" then uit = Multi.minesPick(speler, zet)
	elseif spel == "bus" then uit = Multi.busCall(speler, zet)
	elseif spel == "scratch" then uit = Games.scratchReveal(speler, zet)
	elseif spel == "blackjack" then uit = Blackjack.act(speler, zet)
	elseif spel == "safety" then uit = Games.safetyStop(speler)
	else uit = { ok = false, err = "onbekende zet" } end
	stuurProfiel(speler)
	return uit
end

Net.fn("CashOut").OnServerInvoke = function(speler, spel)
	local uit
	if spel == "tower" then uit = Multi.towerCashOut(speler)
	elseif spel == "mines" then uit = Multi.minesCashOut(speler)
	elseif spel == "bus" then uit = Multi.busCashOut(speler)
	elseif spel == "crash" then uit = Crash.cashOut(speler)
	else uit = { ok = false, err = "dat spel kent geen uitstappen" } end
	stuurProfiel(speler)
	return uit
end

return nil
