-- Plak deze regels in de command bar van Studio nadat je build/NeonCasino.rbxmx hebt
-- ingevoegd (Model > Insert from File). Ze zetten de drie mappen op hun plek en ruimen
-- het lege omhulsel op. Doe dit voordat je op Play drukt.
local m = workspace:FindFirstChild("NeonCasino") or game.ServerStorage:FindFirstChild("NeonCasino")
assert(m, "NeonCasino niet gevonden -- eerst het model invoegen")
m.Shared.Parent = game:GetService("ReplicatedStorage")
m.Server.Parent = game:GetService("ServerScriptService")
m.Client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
m:Destroy()
print("Neon Casino staat klaar. Druk op Play.")
