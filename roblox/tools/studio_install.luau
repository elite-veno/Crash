-- ============================================================================
--  NEON CASINO -- installeren in Studio
--  Plak dit hele blok in de command bar van Studio (View > Command Bar) en druk
--  op enter. Het haalt de laatste code van GitHub en zet hem op zijn plek.
--  Nog een keer plakken werkt alles bij; oude mappen worden eerst weggegooid.
-- ============================================================================
local TAK = "claude/game-odds-balance-q15z5q"
local URL = "https://raw.githubusercontent.com/elite-veno/Crash/" .. TAK .. "/roblox/build/install.json"

local Http = game:GetService("HttpService")
-- In Studio mag dit vanaf de command bar; zonder dit weigert GetAsync.
local hadHttp = Http.HttpEnabled
if not hadHttp then Http.HttpEnabled = true end

local ok, ruw = pcall(function()
	return Http:GetAsync(URL)
end)
assert(ok, "downloaden mislukt: " .. tostring(ruw) ..
	"\nStaat 'Allow HTTP Requests' aan onder Game Settings > Security?")

local plan = Http:JSONDecode(ruw)

local function bouw(knoop, ouder)
	local inst = Instance.new(knoop.class)
	inst.Name = knoop.name
	if knoop.source then
		inst.Source = knoop.source
	end
	for _, kind in ipairs(knoop.children or {}) do
		bouw(kind, inst)
	end
	inst.Parent = ouder
	return inst
end

-- "StarterPlayer.StarterPlayerScripts" van de DataModel af aflopen.
local function zoek(pad)
	local hier = game
	for stuk in string.gmatch(pad, "[^%.]+") do
		local volgende = if hier == game then game:GetService(stuk) else hier:FindFirstChild(stuk)
		assert(volgende, "niet gevonden: " .. pad)
		hier = volgende
	end
	return hier
end

local geplaatst = 0
for _, wortel in ipairs(plan.roots) do
	local ouder = zoek(wortel.parent)
	local oud = ouder:FindFirstChild(wortel.node.name)
	if oud then oud:Destroy() end
	bouw(wortel.node, ouder)
	geplaatst += 1
	print(("  %s -> %s"):format(wortel.node.name, wortel.parent))
end

-- Een eerder ingevoegd model uit Workspace opruimen, zodat er niets dubbel staat.
local rommel = workspace:FindFirstChild(plan.name)
if rommel then rommel:Destroy() end

print(("Neon Casino geinstalleerd (%d mappen). Druk op Play."):format(geplaatst))
