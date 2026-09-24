--!strict
-- De twee klokken. Hier gaat het om data die maanden vooruit lopen, dus alles wordt
-- nagerekend op vaste tijdstempels in plaats van op "nu".
local Season = require("../src/shared/Season")
local h = require("./harness")

local OPEN = Season.OPENING

h.check("een sprint duurt drie dagen", 259200, Season.SPRINT_SECONDS)
h.check("een seizoen duurt twaalf dagen", 1036800, Season.SEASON_SECONDS)
h.check("een seizoen is vier sprints", 4, Season.SEASON_SECONDS / Season.SPRINT_SECONDS)

-- De opening valt precies op het begin van een seizoen en van een sprint.
h.check("de opening valt op een seizoensgrens", 0, OPEN % Season.SEASON_SECONDS)
h.check("de opening valt op een sprintgrens", 0, OPEN % Season.SPRINT_SECONDS)
h.check("op de openingsdag is het seizoen 1", 1, Season.seasonNo(OPEN))
h.check("en sprint 1", 1, Season.sprintNo(OPEN))

-- De vier sprints van het eerste seizoen.
for i = 0, 3 do
	local t = OPEN + i * Season.SPRINT_SECONDS + 3600
	h.check("dag " .. (i * 3) .. " zit in seizoen 1", 1, Season.seasonNo(t))
	h.check("dag " .. (i * 3) .. " is sprint " .. (i + 1), i + 1, Season.sprintNo(t))
	h.check("er zijn dan " .. (4 - i) .. " sprints over", 4 - i, Season.sprintsLeft(t))
end

-- En dan begint seizoen 2.
local tweede = OPEN + Season.SEASON_SECONDS + 60
h.check("na twaalf dagen begint seizoen 2", 2, Season.seasonNo(tweede))
h.check("en dat begint weer bij sprint 1", 1, Season.sprintNo(tweede))

-- ---------- de VIP-pas ----------
-- Wie sprint 1 wint, mag de rest van seizoen 1 naar binnen.
local sprint1 = Season.sprintId(OPEN)
h.check("de pas van sprint 1 geldt voor seizoen 1", Season.seasonId(OPEN), Season.vipSeasonFor(sprint1))
h.check("en die pas is geldig tijdens seizoen 1", true, Season.vipActive(Season.vipSeasonFor(sprint1), OPEN + 3600))

-- Wie de laatste sprint van een seizoen wint, krijgt het seizoen dat begint -- niet dat
-- net voorbij is. Anders zou de pas al verlopen zijn op het moment dat je hem wint.
local laatste = Season.sprintId(OPEN + 3 * Season.SPRINT_SECONDS)
local pas = Season.vipSeasonFor(laatste)
h.check("de laatste sprint geeft het volgende seizoen", Season.seasonId(tweede), pas)
h.check("die pas geldt niet meer in seizoen 1", false, Season.vipActive(pas, OPEN + 3600))
h.check("maar wel in seizoen 2", true, Season.vipActive(pas, tweede))
h.check("en niet in seizoen 3", false, Season.vipActive(pas, OPEN + 2 * Season.SEASON_SECONDS + 60))
h.check("zonder pas kom je er niet in", false, Season.vipActive(nil, tweede))

-- ---------- het saldo bij een nieuw seizoen ----------
h.check("precies duizend blijft duizend", 1000, Season.balanceAfter(1000))
h.check("minder dan duizend gaat naar duizend", 1000, Season.balanceAfter(12.5))
h.check("nul gaat ook naar duizend", 1000, Season.balanceAfter(0))
h.check("van tweeduizend hou je honderd over de duizend", 1100, Season.balanceAfter(2000))
h.check("van elfduizend hou je duizend over de duizend", 2000, Season.balanceAfter(11000))
h.check("de centen gaan naar beneden", 1000.05, Season.balanceAfter(1000.55))
h.check("en nooit naar boven", 1000.09, Season.balanceAfter(1000.99))
-- Twee keer omslaan mag nooit onder de duizend uitkomen.
local b = 50000
for _ = 1, 6 do
	b = Season.balanceAfter(b)
	h.check("het saldo zakt nooit onder duizend", true, b >= 1000)
end

-- ---------- de labels ----------
h.check("sprint 1 van seizoen 1", "SEASON 1 \u{00B7} SPRINT 1", Season.sprintLabel(sprint1))
h.check("sprint 4 van seizoen 1", "SEASON 1 \u{00B7} SPRINT 4", Season.sprintLabel(laatste))
h.check("voor de opening heet het voorseizoen", true,
	string.find(Season.sprintLabel(sprint1 - 4), "PRESEASON") ~= nil)

h.check("een titel wordt leesbaar gemaakt",
	"Champion \u{00B7} SEASON 1 \u{00B7} SPRINT 1", Season.titleLabel("Kampioen S" .. sprint1))
h.check("tweede ook", "Runner-up \u{00B7} SEASON 1 \u{00B7} SPRINT 1", Season.titleLabel("Tweede S" .. sprint1))
h.check("iets anders blijft staan zoals het is", "gewoon iets", Season.titleLabel("gewoon iets"))
h.check("niets geeft niets", "", Season.titleLabel(nil))

h.check("plaats 1 krijgt Kampioen", "Kampioen S5", Season.titleFor(1, 5))
h.check("plaats 2 krijgt Tweede", "Tweede S5", Season.titleFor(2, 5))
h.check("plaats 3 krijgt Derde", "Derde S5", Season.titleFor(3, 5))
h.check("plaats 4 krijgt niets", nil, Season.titleFor(4, 5))

-- ---------- de aftelklok ----------
h.check("twee dagen en wat", "2d 1h 1m", Season.countdown(OPEN + 2 * 86400 + 3660, OPEN))
h.check("uren en minuten", "5h 30m", Season.countdown(OPEN + 5 * 3600 + 1800, OPEN))
h.check("alleen minuten", "45m", Season.countdown(OPEN + 2700, OPEN))
h.check("voorbij is nul", "0m", Season.countdown(OPEN - 500, OPEN))

h.report("SEIZOEN")
