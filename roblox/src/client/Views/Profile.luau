--!strict
-- Profiel: je saldo, je totalen en per spel wat je ervan gebakken hebt. Alles komt uit het
-- profiel dat de server stuurt; de client rekent hier niets uit wat geld raakt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Profile = {}

-- Dezelfde volgorde en namen als op de homepagina, plus de twee VIP-spellen.
local SPELLEN = {
	{ id = "crash", label = "CRASH" },
	{ id = "roulette", label = "ROULETTE" },
	{ id = "tower", label = "DRAGON TOWER" },
	{ id = "mines", label = "MINES" },
	{ id = "plinko", label = "PLINKO" },
	{ id = "blackjack", label = "BLACKJACK" },
	{ id = "scratch", label = "SCRATCH CARDS" },
	{ id = "wheel", label = "WHEEL" },
	{ id = "slots", label = "777" },
	{ id = "horse", label = "HORSE RACE" },
	{ id = "bus", label = "RIDE THE BUS" },
}

local function tekenGetal(n: number): string
	return string.format("%d", n)
end

-- Winst rood of groen, met een teken ervoor. Nul is grijs, want dat is geen van beide.
local function winstKleur(n: number): Color3
	if n > 0.005 then return Theme.color.neon end
	if n < -0.005 then return Theme.color.red end
	return Theme.color.muted
end

local function winstTekst(n: number): string
	local teken = if n > 0.005 then "+" elseif n < -0.005 then "-" else ""
	return teken .. "$" .. Money.fmt(math.abs(n))
end

function Profile.build(ouder: Instance): (any) -> ()
	local blad = Common.sheet(ouder)

	-- ---------- de kaart bovenaan ----------
	local kaart = UI.panel(blad, "Card")
	UI.list(kaart, 6)
	local naam = UI.label(kaart, Players.LocalPlayer.DisplayName, {
		size = Theme.text.big, color = Theme.color.text, font = Theme.font.uiBold,
	})
	naam.Size = UDim2.new(1, 0, 0, 28)
	local titel = UI.label(kaart, "\u{2014}", { size = Theme.text.small, color = Theme.color.gold })

	local saldo = UI.label(kaart, "$" .. Money.fmt(Money.START), {
		size = Theme.text.huge, color = Theme.color.neon, font = Theme.font.num,
	})
	saldo.Size = UDim2.new(1, 0, 0, 46)

	-- ---------- de totalen ----------
	local totalen = UI.panel(blad, "Totals")
	UI.list(totalen, 4)
	UI.panelTitle(totalen, "lifetime")
	local rondes = Common.statRow(totalen, "ROUNDS PLAYED", "0")
	local gewonnen = Common.statRow(totalen, "ROUNDS WON", "0")
	local verloren = Common.statRow(totalen, "ROUNDS LOST", "0")
	local winkans = Common.statRow(totalen, "WIN RATE", "\u{2014}")
	local winst = Common.statRow(totalen, "NET PROFIT", "$0.00")

	-- ---------- per spel ----------
	local perSpel = UI.panel(blad, "PerGame")
	UI.list(perSpel, 4)
	UI.panelTitle(perSpel, "by game")

	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, 18)
	kop.BackgroundTransparency = 1
	kop.Parent = perSpel
	local function kolomLabel(tekst: string, x: number, breed: number, rechts: boolean)
		local t = UI.label(kop, tekst, {
			size = Theme.text.tiny, color = Theme.color.muted, font = Theme.font.uiBold,
			align = if rechts then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		})
		t.Position = UDim2.new(x, 0, 0, 0)
		t.Size = UDim2.new(breed, 0, 1, 0)
	end
	kolomLabel("GAME", 0, 0.34, false)
	kolomLabel("ROUNDS", 0.34, 0.16, true)
	kolomLabel("WON", 0.5, 0.12, true)
	kolomLabel("BEST", 0.62, 0.16, true)
	kolomLabel("PROFIT", 0.78, 0.22, true)

	type Regel = { rondes: TextLabel, gewonnen: TextLabel, beste: TextLabel, winst: TextLabel }
	local regels: { [string]: Regel } = {}

	for i, spel in SPELLEN do
		local rij = Instance.new("Frame")
		rij.Name = spel.id
		rij.Size = UDim2.new(1, 0, 0, 20)
		rij.BackgroundTransparency = 1
		rij.LayoutOrder = i
		rij.Parent = perSpel

		local function cel(tekst: string, x: number, breed: number, rechts: boolean, kleur: Color3?): TextLabel
			local t = UI.label(rij, tekst, {
				size = Theme.text.small, color = kleur or Theme.color.text,
				font = if rechts then Theme.font.num else Theme.font.ui,
				align = if rechts then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			})
			t.Position = UDim2.new(x, 0, 0, 0)
			t.Size = UDim2.new(breed, 0, 1, 0)
			return t
		end

		cel(spel.label, 0, 0.34, false, Theme.color.muted)
		regels[spel.id] = {
			rondes = cel("0", 0.34, 0.16, true),
			gewonnen = cel("0", 0.5, 0.12, true),
			beste = cel("\u{2014}", 0.62, 0.16, true),
			winst = cel("$0.00", 0.78, 0.22, true, Theme.color.muted),
		}
	end

	-- Het profiel binnenkrijgen en alles bijwerken.
	return function(p: any)
		if typeof(p) ~= "table" then return end
		saldo.Text = "$" .. Money.fmt(tonumber(p.balance) or 0)
		titel.Text = if typeof(p.title) == "string" and p.title ~= "" then p.title else "NO TITLE YET"

		local r = tonumber(p.rounds) or 0
		local w = tonumber(p.won) or 0
		local l = tonumber(p.lost) or 0
		rondes.Text = tekenGetal(r)
		gewonnen.Text = tekenGetal(w)
		verloren.Text = tekenGetal(l)
		winkans.Text = if r > 0 then string.format("%.1f%%", w / r * 100) else "\u{2014}"
		local nettoWinst = tonumber(p.profit) or 0
		winst.Text = winstTekst(nettoWinst)
		winst.TextColor3 = winstKleur(nettoWinst)

		local stats = if typeof(p.stats) == "table" then p.stats else {}
		for id, regel in regels do
			local s = stats[id]
			if typeof(s) == "table" then
				regel.rondes.Text = tekenGetal(tonumber(s.rounds) or 0)
				regel.gewonnen.Text = tekenGetal(tonumber(s.won) or 0)
				local beste = tonumber(s.highest) or 0
				regel.beste.Text = if beste > 0 then Money.fmt(beste) .. "\u{00D7}" else "\u{2014}"
				local sw = tonumber(s.profit) or 0
				regel.winst.Text = winstTekst(sw)
				regel.winst.TextColor3 = winstKleur(sw)
			end
		end
	end
end

return Profile
