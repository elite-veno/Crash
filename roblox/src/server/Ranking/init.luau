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
local naamCache: { [number]: string } = {}
local aanUit = not RunService:IsStudio()

-- Drie ranglijsten, want de pagina heeft er drie naast elkaar staan. Een OrderedDataStore
-- sorteert op één getal, dus elke kolom heeft zijn eigen lijst:
--   sprint -- wat je deze sprint overhoudt; hier hangen de titels en de VIP-pas aan
--   money  -- je saldo, over sprints heen
--   ratio  -- gewonnen gedeeld door verloren, voor wie genoeg rondes heeft gespeeld
--
-- De laatste twee staan niet per sprint maar over het hele spel, net als in de webversie:
-- daar komen ze uit dezelfde spelerstabel en resetten ze niet mee.
local WINST_MIN_RONDES = 10

local lijsten: { [string]: OrderedDataStore } = {}

local function lijstMet(naam: string): OrderedDataStore?
	if not aanUit then return nil end
	local l = lijsten[naam]
	if l then return l end
	local ok, nieuw = pcall(function()
		return DataStoreService:GetOrderedDataStore(naam)
	end)
	if not ok then return nil end
	lijsten[naam] = nieuw
	return nieuw
end

local function lijstVan(sprint: number): OrderedDataStore?
	return lijstMet("NeonSprint_v1_" .. sprint)
end

-- Centen, want een OrderedDataStore neemt alleen hele getallen. De grens houdt hem binnen
-- wat een DataStore aankan, ook als iemand een absurd saldo bij elkaar speelt.
function Ranking.toScore(winst: number): number
	return math.clamp(math.floor(winst * 100), -1e12, 1e12)
end

function Ranking.fromScore(score: number): number
	return Money.round2(score / 100)
end

-- De verhouding gewonnen/verloren als geheel getal, want een OrderedDataStore kan niet
-- anders: twee decimalen, dus 1,75 wordt 175. Delen door minstens één, net als lbRatio in
-- de webversie -- zonder verliezen zou de verhouding oneindig zijn.
function Ranking.ratioScore(gewonnen: number, verloren: number): number
	return math.clamp(math.floor(gewonnen / math.max(1, verloren) * 100), 0, 1e9)
end

-- De stand van deze speler wegschrijven. Wordt bij elke save gedaan, dus ongeveer elke
-- minuut en bij het weggaan.
--
-- Drie schrijfbeurten in plaats van één. Dat past ruim binnen wat Roblox per speler
-- toestaat, en het is de enige manier om op drie dingen te kunnen sorteren.
function Ranking.publish(speler: Player, sprint: number, winst: number, saldo: number?, gewonnen: number?, verloren: number?): ()
	naamCache[speler.UserId] = speler.DisplayName
	local sleutel = tostring(speler.UserId)

	local l = lijstVan(sprint)
	if l then
		pcall(function()
			l:SetAsync(sleutel, Ranking.toScore(winst))
		end)
	end

	if saldo then
		local m = lijstMet("NeonMoney_v1")
		if m then
			pcall(function()
				m:SetAsync(sleutel, Ranking.toScore(saldo))
			end)
		end
	end

	-- Onder de tien rondes telt een verhouding niet mee: met één gewonnen ronde en nul
	-- verloren zou je bovenaan staan. `MIN. 10 ROUNDS` staat ook op het kopje.
	if gewonnen and verloren and gewonnen + verloren >= WINST_MIN_RONDES then
		local r = lijstMet("NeonRatio_v1")
		if r then
			pcall(function()
				r:SetAsync(sleutel, Ranking.ratioScore(gewonnen, verloren))
			end)
		end
	end
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

-- De bovenste plaatsen van een lijst, hoogste eerst. `waarde` zet het opgeslagen getal om
-- naar wat de pagina wil zien.
local function bovenaan(l: OrderedDataStore?, hoeveel: number, waarde: (number) -> number): { Plek }
	if not l then return {} end
	local n = math.clamp(hoeveel, 1, 100)
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
				profit = waarde(item.value),
			})
		end
	end
	return uit
end

-- `MOST MONEY`: het saldo, over sprints heen.
function Ranking.topMoney(hoeveel: number?): { Plek }
	return bovenaan(lijstMet("NeonMoney_v1"), hoeveel or 10, Ranking.fromScore)
end

-- `WIN / LOSS RATIO`: alleen spelers met genoeg rondes staan erin, want dat filtert
-- Ranking.publish er al uit.
function Ranking.topRatio(hoeveel: number?): { Plek }
	return bovenaan(lijstMet("NeonRatio_v1"), hoeveel or 10, function(v: number): number
		return v / 100
	end)
end

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
