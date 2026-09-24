--!strict
-- Vrienden en privélobby's.
--
-- Hier wijkt de Roblox-versie bewust af van de webversie, en het wordt er beter van. Daar
-- moest een eigen vriendenlijst gebouwd worden, met uitnodigingen, een tabel en RLS eromheen,
-- omdat Supabase geen vrienden kent. Roblox kent ze wel: een speler heeft al vrienden, en
-- het platform heeft al privéservers. Die opnieuw nabouwen zou een slechtere kopie zijn van
-- iets dat er al staat -- en een eigen lijst zou bovendien niet weten wie er echt bij elkaar
-- horen.
--
-- Wat blijft: je ziet je vrienden, je ziet wie er nu meespeelt, je kunt een privétafel
-- openen en daar mensen bij halen, en je kunt met één knop terug naar de publieke tafel.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Social = {}

export type Vriend = {
	userId: number,
	name: string,
	displayName: string,
	here: boolean,
}

-- De vrienden van deze speler, met erbij wie er nu in deze server zit. GetFriendsAsync is
-- een webaanroep die kan hangen of falen; dan komt er een lege lijst uit in plaats van een
-- foutmelding op het scherm.
function Social.friends(speler: Player): { Vriend }
	local uit: { Vriend } = {}
	local ok, pagina = pcall(function()
		return Players:GetFriendsAsync(speler.UserId)
	end)
	if not ok then return uit end

	local hier: { [number]: boolean } = {}
	for _, p in Players:GetPlayers() do
		hier[p.UserId] = true
	end

	-- Hoogstens honderd; daarboven wordt het scherm toch onleesbaar en kost het paginaas.
	local geteld = 0
	while geteld < 100 do
		local okPagina, rij = pcall(function()
			return pagina:GetCurrentPage()
		end)
		if not okPagina then break end
		for _, v in rij do
			local id = tonumber(v.Id)
			if id then
				geteld += 1
				table.insert(uit, {
					userId = id,
					name = tostring(v.Username),
					displayName = tostring(v.DisplayName or v.Username),
					here = hier[id] == true,
				})
			end
		end
		local okKlaar, klaar = pcall(function()
			return pagina.IsFinished
		end)
		if not okKlaar or klaar then break end
		local okStap = pcall(function()
			pagina:AdvanceToNextPageAsync()
		end)
		if not okStap then break end
	end

	-- Wie er nu meespeelt bovenaan.
	table.sort(uit, function(a, b)
		if a.here ~= b.here then return a.here end
		return a.displayName < b.displayName
	end)
	return uit
end

-- Wie er nu in deze server zit, vrienden of niet.
function Social.here(): { { userId: number, displayName: string } }
	local uit = {}
	for _, p in Players:GetPlayers() do
		table.insert(uit, { userId = p.UserId, displayName = p.DisplayName })
	end
	return uit
end

-- Een privétafel openen: Roblox geeft er een code voor, en daar teleporteert de speler
-- naartoe. Wie hij erbij wil hebben kan met dezelfde code mee.
local codes: { [number]: string } = {}

function Social.reserve(speler: Player): any
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok or typeof(code) ~= "string" then
		return { ok = false, err = "private tables are not available here" }
	end
	codes[speler.UserId] = code
	return { ok = true, code = code }
end

function Social.join(speler: Player, code: any): any
	local c = if typeof(code) == "string" and #code > 0 then code else codes[speler.UserId]
	if not c then return { ok = false, err = "no table to join" } end
	local ok, err = pcall(function()
		TeleportService:TeleportToPrivateServer(game.PlaceId, c, { speler })
	end)
	if not ok then return { ok = false, err = "teleport failed: " .. tostring(err) } end
	return { ok = true }
end

-- Terug naar de publieke tafel.
function Social.quick(speler: Player): any
	local ok, err = pcall(function()
		TeleportService:Teleport(game.PlaceId, speler)
	end)
	if not ok then return { ok = false, err = "teleport failed: " .. tostring(err) } end
	return { ok = true }
end

Players.PlayerRemoving:Connect(function(speler)
	codes[speler.UserId] = nil
end)

return Social
