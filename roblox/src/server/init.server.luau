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

Net.build()

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

-- ---------- de aanvragen ----------
-- Eén ingang per soort, met de naam van het spel erbij. Elke tak controleert zelf wat er
-- binnenkomt; niets wordt op zijn woord geloofd.
Net.fn("GetProfile").OnServerInvoke = function(speler)
	return Profiles.view(speler)
end

-- De stand van de gedeelde crashronde, voor een speler die er net binnenkomt.
Net.fn("RoundState").OnServerInvoke = function(_speler, spel)
	if spel == "crash" then return Crash.state() end
	return { ok = false, err = "geen gedeelde tafel" }
end

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
	elseif spel == "crash" then uit = Crash.bet(speler, inzet)
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
