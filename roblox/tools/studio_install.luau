--[[ NEON CASINO installeren. Plak dit hele blok in de command bar van Studio
     (View > Command Bar) en druk op enter.

     Het zet de game in je place en legt daarnaast een plugin klaar in ServerStorage.
     Rechtsklik die plugin en kies "Save as Local Plugin"; daarna staat er een Sync-knop in
     je werkbalk en hoef je dit nooit meer te plakken.

     Alle uitleg staat in blokcommentaar en er staat nergens een los -- commentaar. De
     command bar is een veld van een regel: bij plakken worden de regels aan elkaar geplakt,
     en dan zou een -- commentaar de rest van het script opeten.

     Werkt het niet, dan staat HTTP uit:
     File > Game Settings > Security > Allow HTTP Requests. Daarna opnieuw plakken. ]]

local Http = game:GetService("HttpService")
pcall(function() Http.HttpEnabled = true end)
local URL = "https://raw.githubusercontent.com/elite-veno/Crash/claude/game-odds-balance-q15z5q/roblox/build/install.json"
local ok, ruw = pcall(function() return Http:GetAsync(URL) end)
if not ok then error("Neon Casino: downloaden mislukt (" .. tostring(ruw) .. "). Zet Allow HTTP Requests aan onder File > Game Settings > Security en plak dit opnieuw.", 0) end
local plan = Http:JSONDecode(ruw)
local function bouw(k, ouder) local i = Instance.new(k.class) i.Name = k.name if k.source then i.Source = k.source end for _, c in ipairs(k.children or {}) do bouw(c, i) end i.Parent = ouder return i end
local function zoek(pad) local hier = game for stuk in string.gmatch(pad, "[^%.]+") do hier = (hier == game) and game:GetService(stuk) or hier:FindFirstChild(stuk) if not hier then error("Neon Casino: niet gevonden: " .. pad, 0) end end return hier end
local n = 0
for _, wortel in ipairs(plan.roots) do local ouder = zoek(wortel.parent) local oud = ouder:FindFirstChild(wortel.node.name) if oud then oud:Destroy() end bouw(wortel.node, ouder) n = n + 1 print("  " .. wortel.node.name .. " -> " .. wortel.parent) end
local rommel = workspace:FindFirstChild(plan.name)
if rommel then rommel:Destroy() end
if plan.plugin then local opslag = game:GetService("ServerStorage") local oud = opslag:FindFirstChild(plan.plugin.name) if oud then oud:Destroy() end bouw(plan.plugin, opslag) print("Plugin klaargezet in ServerStorage: rechtsklik NeonSync en kies Save as Local Plugin. Daarna nooit meer plakken.") end
print("Neon Casino geinstalleerd (" .. n .. " mappen). Druk op Play.")
