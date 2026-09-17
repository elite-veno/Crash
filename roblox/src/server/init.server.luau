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

Players.PlayerRemoving:Connect(function(speler)
	-- Een openstaande ronde krijgt zijn inzet terug voordat het profiel wordt bewaard.
	Multi.refund(speler)
	Games.refund(speler)
end)

for _, speler in Players:GetPlayers() do
	Profiles.load(speler)
	stuurProfiel(speler)
end

-- ---------- de aanvragen ----------
-- Eén ingang per soort, met de naam van het spel erbij. Elke tak controleert zelf wat er
-- binnenkomt; niets wordt op zijn woord geloofd.
Net.fn("GetProfile").OnServerInvoke = function(speler)
	return Profiles.view(speler)
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
	else uit = { ok = false, err = "onbekende zet" } end
	stuurProfiel(speler)
	return uit
end

Net.fn("CashOut").OnServerInvoke = function(speler, spel)
	local uit
	if spel == "tower" then uit = Multi.towerCashOut(speler)
	elseif spel == "mines" then uit = Multi.minesCashOut(speler)
	elseif spel == "bus" then uit = Multi.busCashOut(speler)
	else uit = { ok = false, err = "dat spel kent geen uitstappen" } end
	stuurProfiel(speler)
	return uit
end

return nil
