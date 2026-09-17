--!strict
-- Dragon Tower: negen verdiepingen omhoog, per verdieping één tegel kiezen. De indeling
-- staat op de server; de client weet pas wat er onder een tegel zat als hij hem aanraakt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Tower = {}

local MOEILIJK = {"easy", "medium", "hard", "expert", "master"}

function Tower.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, "DRAGON TOWER")

	local toren = UI.panel(bord, "Tower")
	UI.list(toren, 6)
	UI.panelTitle(toren, "dragon tower")

	local rijenVak = Instance.new("Frame")
	rijenVak.Size = UDim2.new(1, 0, 0, 0)
	rijenVak.AutomaticSize = Enum.AutomaticSize.Y
	rijenVak.BackgroundTransparency = 1
	rijenVak.Parent = toren
	UI.list(rijenVak, 4)

	local balk = Common.banner(toren)
	balk.set("PICK A DIFFICULTY", nil)

	local diff = "easy"
	local actief = false
	local niveau = 0
	local tegels: { { TextButton } } = {}
	local betBox: Common.BetBox
	local startKnop: TextButton
	local uitKnop: TextButton

	-- De toren opnieuw tekenen: bovenste verdieping bovenaan, zoals in de webversie.
	local function teken()
		for _, kind in rijenVak:GetChildren() do
			if kind:IsA("Frame") then kind:Destroy() end
		end
		table.clear(tegels)

		local d = Odds.TOWER_DIFF[diff]
		for r = Odds.TOWER_LEVELS, 1, -1 do
			local rij = Instance.new("Frame")
			rij.Name = "Row" .. r
			rij.Size = UDim2.new(1, 0, 0, 30)
			rij.BackgroundTransparency = 1
			rij.LayoutOrder = Odds.TOWER_LEVELS - r
			rij.Parent = rijenVak
			local l = UI.list(rij, 4, Enum.FillDirection.Horizontal)
			l.HorizontalAlignment = Enum.HorizontalAlignment.Left

			local mult = UI.label(rij, Money.fmt(Odds.towerMultiplier(diff, r)) .. "\u{00D7}", {
				size = Theme.text.tiny, color = Theme.color.muted, font = Theme.font.num,
				align = Enum.TextXAlignment.Right,
			})
			mult.AnchorPoint = Vector2.new(1, 0.5)
			mult.Position = UDim2.new(1, -4, 0.5, 0)
			mult.Size = UDim2.fromOffset(60, 20)
			mult.LayoutOrder = 99

			local kolom: { TextButton } = {}
			for k = 1, d.tiles do
				local b = Instance.new("TextButton")
				b.Name = "T" .. r .. "_" .. k
				b.Text = ""
				b.Font = Theme.font.ui
				b.TextSize = 16
				b.TextColor3 = Theme.color.text
				b.BackgroundColor3 = Theme.color.bg
				b.BackgroundTransparency = 0.35
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				b.LayoutOrder = k
				b.Size = UDim2.new((1 - 0.2) / d.tiles, -4, 1, 0)
				b.RichText = false
				UI.corner(b, Theme.radius.chip)
				UI.stroke(b, Theme.color.border)
				b.Parent = rij
				kolom[k] = b
			end
			tegels[r] = kolom
		end
	end

	local function zetActief()
		for r, kolom in tegels do
			local aanBeurt = actief and r == niveau + 1
			for _, b in kolom do
				b.Active = aanBeurt
				b.BackgroundTransparency = if aanBeurt then 0.1 else 0.55
			end
		end
		startKnop.Visible = not actief
		uitKnop.Visible = actief
		betBox.lock(actief)
	end

	-- De hele rij openleggen als een ronde afloopt, zodat je ziet wat er stond.
	local function toonRij(r: number, rij: { boolean })
		local kolom = tegels[r]
		if not kolom then return end
		for k, veilig in rij do
			local b = kolom[k]
			if b then
				b.Text = if veilig then "\u{25C6}" else "\u{2716}"
				b.TextColor3 = if veilig then Theme.color.neon else Theme.color.red
				b.BackgroundTransparency = 0.25
			end
		end
	end

	local function kies(r: number, k: number)
		if not actief or r ~= niveau + 1 then return end
		local res = Common.call("Act", "tower", k)
		if not res then return end

		if not res.safe then
			toonRij(r, res.row)
			actief = false
			zetActief()
			balk.set("THE DRAGON GOT YOU", "red")
			return
		end

		toonRij(r, res.row)
		if res.done then
			actief = false
			zetActief()
			balk.set("TOP FLOOR  \u{00B7}  +$" .. Money.fmt(res.payout), "gold")
			Common.toast("+$" .. Money.fmt(res.payout), "gold")
			return
		end

		niveau = res.level
		zetActief()
		balk.set("FLOOR " .. niveau .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		uitKnop.Text = "CASH OUT  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}"
	end

	-- De knoppen pas na het tekenen koppelen, zodat elke hertekening ze opnieuw krijgt.
	local function koppel()
		for r, kolom in tegels do
			for k, b in kolom do
				b.Activated:Connect(function()
					kies(r, k)
				end)
			end
		end
	end

	-- ---------- de bediening ----------
	local keuze = UI.panel(bediening, "Difficulty")
	UI.list(keuze, 6)
	UI.panelTitle(keuze, "difficulty")
	local diffKnoppen: { [string]: TextButton } = {}
	local uitleg = UI.label(keuze, Odds.TOWER_DIFF.easy.label, {
		size = Theme.text.tiny, color = Theme.color.muted,
	})

	local function markeer()
		for k, b in diffKnoppen do
			local aan = k == diff
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.bg
			b.BackgroundTransparency = if aan then 0.1 else 0.5
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
		end
		uitleg.Text = Odds.TOWER_DIFF[diff].label
	end

	for _, k in MOEILIJK do
		local b = UI.chip(keuze, string.upper(k))
		b.Size = UDim2.new(1, 0, 0, 26)
		b.Activated:Connect(function()
			if actief then return end
			diff = k
			teken()
			koppel()
			zetActief()
			markeer()
		end)
		diffKnoppen[k] = b
	end

	betBox = Common.betBox(bediening, 10)
	startKnop = UI.primary(bediening, "START CLIMB")
	uitKnop = UI.primary(bediening, "CASH OUT")
	uitKnop.Visible = false

	startKnop.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "tower", betBox.get(), diff)
		if not res then return end
		actief = true
		niveau = 0
		teken()
		koppel()
		zetActief()
		uitKnop.Text = "CASH OUT"
		balk.set("PICK A TILE ON FLOOR 1", nil)
	end)

	uitKnop.Activated:Connect(function()
		if not actief then return end
		local res = Common.call("CashOut", "tower")
		if not res then return end
		actief = false
		zetActief()
		balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		Common.toast("+$" .. Money.fmt(res.payout), "green")
	end)

	teken()
	koppel()
	zetActief()
	markeer()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "tower")
	Common.oddsPanel(bediening, "odds", "Every floor has fixed odds. Multiplier = 0.97 x (tiles / safe)^floor, so RTP 97% at every point you cash out. The whole tower is fixed before your first click.")

end

return Tower
