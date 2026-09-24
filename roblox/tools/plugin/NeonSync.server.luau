--[[ NEON SYNC -- een Studio-plugin die de laatste code van GitHub haalt en in deze place
     zet. Eén knop in de werkbalk; daarna hoef je nooit meer iets te plakken.

     Installeren: dit script staat in ServerStorage. Rechtsklik erop in de Explorer en kies
     "Save as Local Plugin". Studio vraagt één keer toestemming om scripts te mogen
     schrijven; daarna staat de knop er elke keer dat je Studio opent.

     Automatisch synchroniseren staat UIT. Dat is expres: dan overschrijft de plugin nooit
     zomaar iets waar je net aan zat te werken. Zet je hem aan, dan haalt hij de code op
     zodra Studio de place opent. ]]

local TAK = "claude/game-odds-balance-q15z5q"
local URL = "https://raw.githubusercontent.com/elite-veno/Crash/" .. TAK .. "/roblox/build/install.json"
local INSTELLING = "NeonSync_AutoSync"

local Http = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local toolbar = plugin:CreateToolbar("Neon Casino")
local knop = toolbar:CreateButton("Sync", "Haal de laatste code van GitHub en zet hem in deze place", "rbxasset://textures/ui/GuiImagePlaceholder.png")
local autoKnop = toolbar:CreateButton("Auto", "Automatisch synchroniseren zodra Studio de place opent", "rbxasset://textures/ui/GuiImagePlaceholder.png")

local function bouw(knoop, ouder)
	local i = Instance.new(knoop.class)
	i.Name = knoop.name
	if knoop.source then
		i.Source = knoop.source
	end
	for _, kind in ipairs(knoop.children or {}) do
		bouw(kind, i)
	end
	i.Parent = ouder
	return i
end

local function zoek(pad)
	local hier = game
	for stuk in string.gmatch(pad, "[^%.]+") do
		hier = (hier == game) and game:GetService(stuk) or hier:FindFirstChild(stuk)
		if not hier then
			error("Neon Sync: niet gevonden: " .. pad, 0)
		end
	end
	return hier
end

local bezig = false

local function sync(stil)
	if bezig then return end
	bezig = true
	knop:SetActive(true)

	local ok, ruw = pcall(function()
		return Http:GetAsync(URL)
	end)
	if not ok then
		pcall(function() Http.HttpEnabled = true end)
		ok, ruw = pcall(function()
			return Http:GetAsync(URL)
		end)
	end

	if not ok then
		warn("Neon Sync: downloaden mislukt (" .. tostring(ruw) ..
			"). Zet Allow HTTP Requests aan onder File > Game Settings > Security.")
		bezig = false
		knop:SetActive(false)
		return
	end

	local gelukt, plan = pcall(function()
		return Http:JSONDecode(ruw)
	end)
	if not gelukt or typeof(plan) ~= "table" or typeof(plan.roots) ~= "table" then
		warn("Neon Sync: het antwoord van GitHub was niet te lezen.")
		bezig = false
		knop:SetActive(false)
		return
	end

	-- Alles in één ongedaanmaakstap, zodat ctrl-z de hele sync terugdraait.
	local opname = ChangeHistoryService:TryBeginRecording("NeonSync", "Neon Casino synchroniseren")
	local n = 0
	local fout = nil
	for _, wortel in ipairs(plan.roots) do
		local gelukte, err = pcall(function()
			local ouder = zoek(wortel.parent)
			local oud = ouder:FindFirstChild(wortel.node.name)
			if oud then
				oud:Destroy()
			end
			bouw(wortel.node, ouder)
			n = n + 1
		end)
		if not gelukte then
			fout = err
			break
		end
	end

	local rommel = workspace:FindFirstChild(plan.name)
	if rommel then
		rommel:Destroy()
	end

	if opname then
		ChangeHistoryService:FinishRecording(opname,
			fout and Enum.FinishRecordingOperation.Cancel or Enum.FinishRecordingOperation.Commit)
	end

	if fout then
		warn("Neon Sync: " .. tostring(fout))
	elseif not stil then
		print("Neon Sync: " .. n .. " mappen bijgewerkt. Druk op Play.")
	end

	bezig = false
	knop:SetActive(false)
end

local function zetAuto(aan)
	plugin:SetSetting(INSTELLING, aan)
	autoKnop:SetActive(aan)
	print("Neon Sync: automatisch synchroniseren staat " .. (aan and "AAN" or "UIT") .. ".")
end

knop.Click:Connect(function()
	sync(false)
end)

autoKnop.Click:Connect(function()
	zetAuto(not plugin:GetSetting(INSTELLING))
end)

autoKnop:SetActive(plugin:GetSetting(INSTELLING) == true)

if plugin:GetSetting(INSTELLING) == true then
	task.defer(function()
		sync(true)
	end)
end
