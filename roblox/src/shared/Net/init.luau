--!strict
-- Alles wat client en server tegen elkaar zeggen, op één plek. De client roept nooit iets
-- aan dat hier niet staat, en de server rekent alles zelf af: de client stuurt hooguit een
-- inzet en een keuze, nooit een bedrag dat hij zelf heeft uitgerekend.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- De namen van de kanalen. Eén tabel, zodat een typefout niet stilletjes een nieuw
-- RemoteEvent aanmaakt dat nooit geluisterd wordt.
Net.FUNCTIONS = {
	"Bet",          -- (spel, inzet, opties) -> uitslag
	"Act",          -- (spel, zet) -> uitslag, voor spellen met meerdere beurten
	"CashOut",      -- (spel) -> uitbetaling
	"GetProfile",   -- () -> het hele profiel
	"SetFeatured",  -- (lijst) -> de drie uitgelichte badges
	"Leaderboard",  -- () -> de ranglijst
	"Friends",      -- (actie, naam) -> de vriendenlijst
	"Lobby",        -- (actie, gegevens) -> de lobby
}

Net.EVENTS = {
	"Profile",      -- server -> client: saldo, stats, prestaties
	"Round",        -- server -> client: de stand van een gedeelde ronde
	"Toast",        -- server -> client: een melding
	"Lobbies",      -- server -> client: wie er aan tafel zit
}

local folder: Folder? = nil

local function ensure(): Folder
	local gevonden = folder
	if gevonden then return gevonden end

	local bestaand = ReplicatedStorage:FindFirstChild("NeonNet")
	if bestaand then
		folder = bestaand :: Folder
		return bestaand :: Folder
	end

	if RunService:IsServer() then
		local nieuw = Instance.new("Folder")
		nieuw.Name = "NeonNet"
		nieuw.Parent = ReplicatedStorage
		folder = nieuw
		return nieuw
	end

	-- De client wacht: de server maakt de map bij het opstarten.
	local gewacht = ReplicatedStorage:WaitForChild("NeonNet", 30) :: Folder
	folder = gewacht
	return gewacht
end

-- Maakt de kanalen aan. Alleen de server roept dit aan, bij het opstarten.
function Net.build(): ()
	assert(RunService:IsServer(), "alleen de server maakt de kanalen")
	local f = ensure()
	for _, naam in Net.FUNCTIONS do
		if not f:FindFirstChild(naam) then
			local r = Instance.new("RemoteFunction")
			r.Name = naam
			r.Parent = f
		end
	end
	for _, naam in Net.EVENTS do
		if not f:FindFirstChild(naam) then
			local r = Instance.new("RemoteEvent")
			r.Name = naam
			r.Parent = f
		end
	end
end

function Net.fn(naam: string): RemoteFunction
	return ensure():WaitForChild(naam, 30) :: RemoteFunction
end

function Net.ev(naam: string): RemoteEvent
	return ensure():WaitForChild(naam, 30) :: RemoteEvent
end

return Net
