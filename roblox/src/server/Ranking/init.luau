--!strict
-- De ranglijst. Elke sprint van drie dagen heeft zijn eigen lijst, gescoord op wat een
-- speler er binnen die sprint aan overhoudt. Wie als eerste eindigt krijgt een titel en een
-- pas voor de VIP-zone; nummer twee en drie krijgen een titel.
--
-- In de webversie stond dit in een tabel met RLS erop. Hier is het een OrderedDataStore:
-- die kan gesorteerd lezen, wat een gewone DataStore niet kan. Hij bewaart alleen getallen,
-- dus de winst gaat er in centen in, en de namen worden apart opgezocht.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Gedeeld = game:GetService("ReplicatedStorage").Shared
local Money = require(Gedeeld.Money)

local Ranking = {}

local PLAATSEN = 25
local lijsten: { [number]: OrderedDataStore } = {}
local naamCache: { [number]: string } = {}
local aanUit = not RunService:IsStudio()

local function lijstVan(sprint: number): OrderedDataStore?
	if not aanUit then return nil end
	local l = lijsten[sprint]
	if l then return l end
	local ok, nieuw = pcall(function()
		return DataStoreService:GetOrderedDataStore("NeonSprint_v1_" .. sprint)
	end)
	if not ok then return nil end
	lijsten[sprint] = nieuw
	return nieuw
end

-- Centen, want een OrderedDataStore neemt alleen hele getallen. De grens houdt hem binnen
-- wat een DataStore aankan, ook als iemand een absurd saldo bij elkaar speelt.
function Ranking.toScore(winst: number): number
	return math.clamp(math.floor(winst * 100), -1e12, 1e12)
end

function Ranking.fromScore(score: number): number
	return Money.round2(score / 100)
end

-- De stand van deze speler in de lopende sprint wegschrijven. Wordt bij elke save gedaan,
-- dus ongeveer elke twee minuten en bij het weggaan.
function Ranking.publish(speler: Player, sprint: number, winst: number): ()
	local l = lijstVan(sprint)
	if not l then return end
	naamCache[speler.UserId] = speler.DisplayName
	pcall(function()
		l:SetAsync(tostring(speler.UserId), Ranking.toScore(winst))
	end)
end

local function naamVan(id: number): string
	local c = naamCache[id]
	if c then return c end
	local speler = Players:GetPlayerByUserId(id)
	if speler then
		naamCache[id] = speler.DisplayName
		return speler.DisplayName
	end
	local ok, naam = pcall(function()
		return Players:GetNameFromUserIdAsync(id)
	end)
	local uit = if ok and typeof(naam) == "string" then naam else "speler " .. id
	naamCache[id] = uit
	return uit
end

export type Plek = { rank: number, userId: number, name: string, profit: number }

-- De bovenste plaatsen van een sprint, hoogste winst eerst.
function Ranking.top(sprint: number, hoeveel: number?): { Plek }
	local l = lijstVan(sprint)
	if not l then return {} end
	local n = math.clamp(hoeveel or PLAATSEN, 1, 100)
	local ok, pagina = pcall(function()
		return l:GetSortedAsync(false, n)
	end)
	if not ok then return {} end
	local ok2, rij = pcall(function()
		return pagina:GetCurrentPage()
	end)
	if not ok2 then return {} end

	local uit: { Plek } = {}
	for i, item in rij do
		local id = tonumber(item.key)
		if id then
			table.insert(uit, {
				rank = i,
				userId = id,
				name = naamVan(id),
				profit = Ranking.fromScore(item.value),
			})
		end
	end
	return uit
end

-- Op welke plaats stond deze speler in die sprint? nil als hij er niet bij zat.
function Ranking.placeOf(sprint: number, userId: number): number?
	for _, plek in Ranking.top(sprint, PLAATSEN) do
		if plek.userId == userId then return plek.rank end
	end
	return nil
end

return Ranking
