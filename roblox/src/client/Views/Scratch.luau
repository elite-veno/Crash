--!strict
-- Krasloten: negen vakjes die je één voor één openkrast. De server houdt de symbolen vast
-- tot je een vakje aanraakt, dus je kunt niet vooruit kijken -- en de rand blijft grijs tot
-- het hele lot open ligt, zodat de spanning erin blijft.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Scratch = {}

function Scratch.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, "SCRATCH CARDS")

	local kaart = UI.panel(bord, "Card")
	UI.list(kaart, 10)
	UI.panelTitle(kaart, "scratch card")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = kaart
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 96, 0, 96)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = raster

	local balk = Common.banner(kaart)
	balk.set("BUY A CARD", nil)

	local vakjes: { TextButton } = {}
	local randen: { UIStroke } = {}
	local actief = false
	local open = 0
	local krasAlles: TextButton

	local function zetVak(i: number, tekst: string, opgekrast: boolean)
		local b = vakjes[i]
		b.Text = tekst
		b.BackgroundColor3 = if opgekrast then Theme.color.panelLight else Theme.color.bg
		b.TextTransparency = if opgekrast then 0 else 1
		randen[i].Color = Theme.color.border
	end

	local function kras(i: number)
		if not actief then return end
		local res = Common.call("Act", "scratch", i)
		if not res then return end
		open += 1
		zetVak(i, res.symbol, true)
		if not res.done then
			balk.set(open .. " / " .. Odds.SCRATCH_CELLS .. " REVEALED", nil)
			return
		end

		-- Pas nu mag de kaart verklappen of er gewonnen is.
		actief = false
		krasAlles.Visible = false
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 15 then "gold" else "green")
			for j = 1, Odds.SCRATCH_CELLS do
				randen[j].Color = Theme.color.neon
			end
		else
			balk.set("NO MATCH", "red")
		end
	end

	for i = 1, Odds.SCRATCH_CELLS do
		local b = Instance.new("TextButton")
		b.Name = "Cell" .. i
		b.Text = ""
		b.Font = Theme.font.ui
		b.TextSize = 40
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.bg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.button)
		randen[i] = UI.stroke(b, Theme.color.border)
		b.Parent = raster
		b.Activated:Connect(function()
			kras(i)
		end)
		vakjes[i] = b
	end

	-- ---------- de bediening ----------
	local tabel = UI.panel(bediening, "Paytable")
	UI.list(tabel, 4)
	UI.panelTitle(tabel, "three of a kind pays")
	for _, p in Odds.SCRATCH_PRIZES do
		Common.statRow(tabel, p.sym .. p.sym .. p.sym, Money.fmt(p.mult) .. "\u{00D7}")
	end

	local betBox = Common.betBox(bediening, 10)
	local kopen = UI.primary(bediening, "BUY CARD")
	krasAlles = UI.secondary(bediening, "REVEAL ALL")
	krasAlles.Visible = false

	kopen.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "scratch", betBox.get())
		if not res then return end
		actief = true
		open = 0
		krasAlles.Visible = true
		for i = 1, Odds.SCRATCH_CELLS do
			zetVak(i, "", false)
		end
		balk.set("SCRATCH THE SQUARES", nil)
	end)

	krasAlles.Activated:Connect(function()
		if not actief then return end
		for i = 1, Odds.SCRATCH_CELLS do
			if actief and vakjes[i].TextTransparency == 1 then
				kras(i)
				task.wait(0.08)
			end
		end
	end)
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "scratch")
	Common.oddsPanel(bediening, "odds", "Nine cells; three matching symbols pay. The card is fixed the moment you buy it, so scratching only reveals what was already drawn. RTP 97%, chance of a prize 21.6%.")

end

return Scratch
