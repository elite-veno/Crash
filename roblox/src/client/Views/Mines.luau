--!strict
-- Mines: vijfentwintig tegels, een aantal mijnen ertussen. Waar ze liggen weet alleen de
-- server; een tegel die al open ligt telt niet nog een keer mee.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Mines = {}

local SNEL = {1, 3, 5, 10, 24}

function Mines.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, "MINES")

	local veld = UI.panel(bord, "Field")
	UI.list(veld, 8)
	UI.panelTitle(veld, "mines")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = veld
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 64, 0, 64)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = raster

	local balk = Common.banner(veld)
	balk.set("SET THE MINES AND START", nil)

	local mijnen = 3
	local actief = false
	local gepakt = 0
	local tegels: { TextButton } = {}
	local betBox: Common.BetBox
	local startKnop: TextButton
	local uitKnop: TextButton

	local function zetTegel(i: number, tekst: string, kleur: Color3, open: boolean)
		local b = tegels[i]
		b.Text = tekst
		b.TextColor3 = kleur
		b.BackgroundTransparency = if open then 0.2 else 0.5
	end

	local function leeg()
		for i = 1, Odds.MINES_TILES do
			zetTegel(i, "", Theme.color.text, false)
		end
	end

	-- Het hele veld openleggen als de ronde voorbij is.
	local function toonAlles(grid: { boolean })
		for i, mijn in grid do
			if mijn then
				zetTegel(i, "\u{2716}", Theme.color.red, true)
			elseif tegels[i].Text == "" then
				zetTegel(i, "\u{25C6}", Theme.color.muted, false)
			end
		end
	end

	local function zetActief()
		for _, b in tegels do
			b.Active = actief
		end
		startKnop.Visible = not actief
		uitKnop.Visible = actief
		uitKnop.Active = gepakt > 0
		betBox.lock(actief)
	end

	local function pak(i: number)
		if not actief then return end
		local res = Common.call("Act", "mines", i)
		if not res then return end

		if res.mine then
			zetTegel(i, "\u{2716}", Theme.color.red, true)
			toonAlles(res.grid)
			actief = false
			gepakt = 0
			zetActief()
			balk.set("BOOM", "red")
			return
		end

		zetTegel(i, "\u{25C6}", Theme.color.neon, true)
		if res.done then
			actief = false
			gepakt = 0
			zetActief()
			balk.set("FIELD CLEARED  \u{00B7}  +$" .. Money.fmt(res.payout), "gold")
			Common.toast("+$" .. Money.fmt(res.payout), "gold")
			return
		end

		gepakt = res.picked
		zetActief()
		balk.set(gepakt .. " SAFE  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		uitKnop.Text = "CASH OUT  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}"
	end

	for i = 1, Odds.MINES_TILES do
		local b = Instance.new("TextButton")
		b.Name = "Tile" .. i
		b.Text = ""
		b.Font = Theme.font.ui
		b.TextSize = 26
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.bg
		b.BackgroundTransparency = 0.5
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.button)
		UI.stroke(b, Theme.color.border)
		b.Parent = raster
		b.Activated:Connect(function()
			pak(i)
		end)
		tegels[i] = b
	end

	-- ---------- de bediening ----------
	local keuze = UI.panel(bediening, "Mines")
	UI.list(keuze, 6)
	UI.panelTitle(keuze, "mines")
	local aantalLabel = Common.statRow(keuze, "MINES", tostring(mijnen))
	local eersteLabel = Common.statRow(keuze, "FIRST PICK PAYS", Money.fmt(Odds.minesMultiplier(mijnen, 1)) .. "\u{00D7}")
	local snelRij = Common.row(keuze, 26)
	local snelKnoppen: { [number]: TextButton } = {}

	local function markeer()
		aantalLabel.Text = tostring(mijnen)
		eersteLabel.Text = Money.fmt(Odds.minesMultiplier(mijnen, 1)) .. "\u{00D7}"
		for n, b in snelKnoppen do
			local aan = n == mijnen
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.bg
			b.BackgroundTransparency = if aan then 0.1 else 0.5
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
		end
	end

	for _, n in SNEL do
		local b = UI.chip(snelRij, tostring(n))
		b.Size = UDim2.new(1 / #SNEL, -5, 0, 26)
		b.Activated:Connect(function()
			if actief then return end
			mijnen = n
			markeer()
		end)
		snelKnoppen[n] = b
	end

	betBox = Common.betBox(bediening, 10)
	startKnop = UI.primary(bediening, "START GAME")
	uitKnop = UI.primary(bediening, "CASH OUT")
	uitKnop.Visible = false

	startKnop.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "mines", betBox.get(), mijnen)
		if not res then return end
		actief = true
		gepakt = 0
		leeg()
		zetActief()
		uitKnop.Text = "CASH OUT"
		balk.set("PICK A TILE", nil)
	end)

	uitKnop.Activated:Connect(function()
		if not actief or gepakt < 1 then return end
		local res = Common.call("CashOut", "mines")
		if not res then return end
		actief = false
		gepakt = 0
		toonAlles(res.grid)
		zetActief()
		balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		Common.toast("+$" .. Money.fmt(res.payout), "green")
	end)

	leeg()
	zetActief()
	markeer()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "mines")
	Common.oddsPanel(bediening, "odds", "25 tiles. Multiplier after k diamonds = 0.97 / chance(k safe in a row). RTP 97% at every cash-out. The mines are placed before your first click.")

end

return Mines
