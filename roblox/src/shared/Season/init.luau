--!strict
-- Twee klokken naast elkaar, precies als in de webversie. Een SPRINT duurt drie dagen: daar
-- wordt de ranglijst op gescoord, en wie hem wint krijgt een titel. Een SEIZOEN duurt twaalf
-- dagen -- vier sprints -- en is hoe lang een VIP-pas geldig blijft.
--
-- Alles hier is rekenwerk op een tijdstempel, zonder Roblox-type erin. Daardoor is het te
-- bewijzen zonder Studio, net als de kansen in Odds.
local Season = {}

Season.SPRINT_SECONDS = 3 * 24 * 3600
Season.SEASON_SECONDS = 12 * 24 * 3600
Season.SPRINTS_PER_SEASON = 4

-- Wat elke plek in een sprint oplevert. Geen geld: een titel, en voor de winnaar een pas
-- voor de VIP-zone tot het einde van het seizoen.
Season.PRIZES = {"VIP PASS + TITLE", "TITLE", "TITLE"}

-- De dag dat het casino openging (16 september 2026, UTC). De blokken worden vanaf het
-- epoch geteld en zijn daardoor enorm; spelers zien het aantal sinds de opening.
Season.OPENING = 1789516800   -- os.time van 2026-09-16 00:00 UTC

function Season.sprintId(nu: number?): number
	return math.floor((nu or os.time()) / Season.SPRINT_SECONDS)
end

function Season.seasonId(nu: number?): number
	return math.floor((nu or os.time()) / Season.SEASON_SECONDS)
end

function Season.sprintEndsAt(id: number): number
	return (id + 1) * Season.SPRINT_SECONDS
end

function Season.seasonEndsAt(id: number): number
	return (id + 1) * Season.SEASON_SECONDS
end

local EERSTE = math.floor(Season.OPENING / Season.SEASON_SECONDS)

function Season.seasonNoOf(sprint: number): number
	return math.floor(sprint / Season.SPRINTS_PER_SEASON) - EERSTE + 1
end

function Season.sprintNoOf(sprint: number): number
	return sprint - math.floor(sprint / Season.SPRINTS_PER_SEASON) * Season.SPRINTS_PER_SEASON + 1
end

function Season.seasonNo(nu: number?): number
	return Season.seasonId(nu) - EERSTE + 1
end

function Season.sprintNo(nu: number?): number
	return Season.sprintNoOf(Season.sprintId(nu))
end

-- Uitslagen van voor de opening zouden anders als seizoen 0 of lager gelezen worden.
function Season.sprintLabel(sprint: number): string
	local se = Season.seasonNoOf(sprint)
	local kop = if se >= 1 then "SEASON " .. se else "PRESEASON"
	return kop .. " \u{00B7} SPRINT " .. Season.sprintNoOf(sprint)
end

-- Hoeveel sprints er nog in dit seizoen zitten, deze meegerekend.
function Season.sprintsLeft(nu: number?): number
	return Season.SPRINTS_PER_SEASON
		- (Season.sprintId(nu) - Season.seasonId(nu) * Season.SPRINTS_PER_SEASON)
end

-- Een sprint winnen opent de zone op het moment dat die sprint afloopt, en hij blijft open
-- tot het seizoen waar dat moment in valt voorbij is. Win je de laatste sprint van een
-- seizoen, dan dekt de pas het seizoen dat begint -- nooit een dat al voorbij is.
function Season.vipSeasonFor(sprint: number): number
	return Season.seasonId((sprint + 1) * Season.SPRINT_SECONDS)
end

function Season.vipActive(vipSeason: number?, nu: number?): boolean
	return vipSeason ~= nil and vipSeason == Season.seasonId(nu)
end

-- Wat er van een saldo overblijft als het seizoen omslaat: $1000 plus een tiende van wat
-- je daarboven had. Naar beneden op de cent, nooit in het voordeel van de speler.
function Season.balanceAfter(saldo: number): number
	local b = math.floor(saldo * 100 + 0.5) / 100
	local boven = math.max(0, b - 1000)
	return math.floor((1000 + math.floor(boven * 0.10 * 100) / 100) * 100 + 0.5) / 100
end

-- "2d 5h 12m", of korter als er minder over is.
function Season.countdown(tot: number, nu: number?): string
	local over = math.max(0, tot - (nu or os.time()))
	local d = math.floor(over / 86400)
	local u = math.floor(over / 3600) % 24
	local m = math.floor(over / 60) % 60
	if d > 0 then return string.format("%dd %dh %dm", d, u, m) end
	if u > 0 then return string.format("%dh %dm", u, m) end
	return string.format("%dm", m)
end

-- De titels worden opgeslagen als "Kampioen S<sprint>"; dit maakt er leesbare tekst van
-- zonder aan het opgeslagen veld te komen.
local RANG = { Kampioen = "Champion", Tweede = "Runner-up", Derde = "Third" }

function Season.titleLabel(titel: string?): string
	local t = titel or ""
	local rang, sprint = string.match(t, "^(%a+) S(%-?%d+)$")
	if rang and sprint and RANG[rang] then
		return RANG[rang] .. " \u{00B7} " .. Season.sprintLabel(tonumber(sprint) :: number)
	end
	return t
end

function Season.titleFor(plaats: number, sprint: number): string?
	local rang = if plaats == 1 then "Kampioen" elseif plaats == 2 then "Tweede" elseif plaats == 3 then "Derde" else nil
	return if rang then rang .. " S" .. sprint else nil
end

return Season
