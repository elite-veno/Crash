--!strict
-- De lobby: de titel, je saldo, en de tegels van alle spellen, zoals de homepagina in de
-- webversie. De tegels zijn geen plaatjes maar getekende vlakken, zodat er niets geupload
-- hoeft te worden voordat het er goed uitziet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)

local Home = {}

export type Kaart = {
	id: string,
	label: string,
	desc: string,
	rtp: string,
	van: Color3,
	tot: Color3,
}

-- De kleuren komen uit de `preview-*` klassen van de CSS, zodat elke tegel dezelfde sfeer
-- houdt als op de webpagina.
local KAARTEN: { Kaart } = {
	{ id = "crash", label = "CRASH", rtp = "97%",
	  desc = "Ride along and cash out before it crashes. Multipliers up to 1000x.",
	  van = Color3.fromHex("5fb8ff"), tot = Color3.fromHex("2f7fd0") },
	{ id = "roulette", label = "ROULETTE", rtp = "97.3%",
	  desc = "European roulette with a single green zero.",
	  van = Color3.fromHex("6b1f1f"), tot = Color3.fromHex("2a0d0d") },
	{ id = "tower", label = "DRAGON TOWER", rtp = "97%",
	  desc = "Climb nine floors, dodge the dragon eggs.",
	  van = Color3.fromHex("3b1f6b"), tot = Color3.fromHex("170d2a") },
	{ id = "mines", label = "MINES", rtp = "97%",
	  desc = "Collect diamonds, dodge the mines.",
	  van = Color3.fromHex("2a3550"), tot = Color3.fromHex("141a28") },
	{ id = "plinko", label = "PLINKO", rtp = "97%",
	  desc = "Drop a ball and watch where it lands.",
	  van = Color3.fromHex("2b1a45"), tot = Color3.fromHex("120b1e") },
	{ id = "blackjack", label = "BLACKJACK", rtp = "99%",
	  desc = "Six decks, dealer stands on all 17s.",
	  van = Color3.fromHex("14472c"), tot = Color3.fromHex("082013") },
	{ id = "scratch", label = "SCRATCH CARDS", rtp = "97%",
	  desc = "Nine squares, three of a kind pays.",
	  van = Color3.fromHex("1f4a4a"), tot = Color3.fromHex("0c1f1f") },
	{ id = "wheel", label = "WHEEL", rtp = "97%",
	  desc = "Twenty segments, one pays ten times.",
	  van = Color3.fromHex("4a3a12"), tot = Color3.fromHex("1e1707") },
	{ id = "horse", label = "HORSE RACE", rtp = "97%",
	  desc = "Six horses, back the one you fancy.",
	  van = Color3.fromHex("2f5a1a"), tot = Color3.fromHex("13260b") },
}

-- Een tegel: een gekleurd vlak met de naam, de omschrijving en het uitbetalingspercentage.
local function tegel(ouder: Instance, k: Kaart, ga: (string) -> ()): Frame
	local f = Instance.new("Frame")
	f.Name = k.id
	f.Size = UDim2.new(0, 260, 0, 190)
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	UI.corner(f, Theme.size.radiusBig)
	UI.stroke(f)
	f.Parent = ouder

	local beeld = Instance.new("Frame")
	beeld.Size = UDim2.new(1, 0, 0, 96)
	beeld.BackgroundColor3 = k.van
	beeld.BorderSizePixel = 0
	beeld.Parent = f
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(k.van, k.tot)
	g.Rotation = 90
	g.Parent = beeld
	local hoek = Instance.new("UICorner")
	hoek.CornerRadius = UDim.new(0, Theme.size.radiusBig)
	hoek.Parent = beeld

	local body = Instance.new("Frame")
	body.Position = UDim2.new(0, 0, 0, 96)
	body.Size = UDim2.new(1, 0, 1, -96)
	body.BackgroundTransparency = 1
	body.Parent = f
	UI.padding(body, 12)
	UI.list(body, 4)

	UI.label(body, k.label, { size = Theme.text.label, color = Theme.color.neon, font = Theme.font.uiBold })
	local d = UI.label(body, k.desc, { size = Theme.text.tiny, color = Theme.color.muted })
	d.TextWrapped = true
	d.Size = UDim2.new(1, 0, 0, 30)
	UI.label(body, "RTP " .. k.rtp, { size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num })

	local knop = Instance.new("TextButton")
	knop.Text = ""
	knop.BackgroundTransparency = 1
	knop.Size = UDim2.fromScale(1, 1)
	knop.ZIndex = 3
	knop.Parent = f
	knop.Activated:Connect(function()
		ga(k.id)
	end)
	knop.MouseEnter:Connect(function()
		f.BackgroundColor3 = Theme.color.panelLight
	end)
	knop.MouseLeave:Connect(function()
		f.BackgroundColor3 = Theme.color.panel
	end)
	return f
end

-- Bouwt het scherm en geeft terug hoe je het saldo bijwerkt.
function Home.build(ouder: Instance, ga: (string) -> ()): (number) -> ()
	local blad = Instance.new("ScrollingFrame")
	blad.Size = UDim2.fromScale(1, 1)
	blad.BackgroundTransparency = 1
	blad.BorderSizePixel = 0
	blad.ScrollBarThickness = 4
	blad.ScrollBarImageColor3 = Theme.color.border
	blad.CanvasSize = UDim2.new()
	blad.AutomaticCanvasSize = Enum.AutomaticSize.Y
	blad.Parent = ouder
	UI.padding(blad, 4)
	UI.list(blad, 18)

	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, 0)
	kop.AutomaticSize = Enum.AutomaticSize.Y
	kop.BackgroundTransparency = 1
	kop.LayoutOrder = 1
	kop.Parent = blad
	UI.list(kop, 6)

	UI.label(kop, "NEON CASINO", {
		size = Theme.text.huge, color = Theme.color.neon, font = Theme.font.uiBold,
	}).Size = UDim2.new(1, 0, 0, 48)
	UI.label(kop, "\u{25BA} FAIR ODDS \u{00B7} PLAY MONEY ONLY", {
		size = Theme.text.small, color = Theme.color.muted,
	})

	local saldoKaart = UI.panel(blad, "BalanceCard")
	saldoKaart.LayoutOrder = 2
	saldoKaart.Size = UDim2.new(0, 280, 0, 0)
	UI.stroke(saldoKaart, Theme.color.neon)
	UI.label(saldoKaart, "YOUR BALANCE", { size = Theme.text.tiny, color = Theme.color.muted })
	local bedrag = UI.label(saldoKaart, "$" .. Money.fmt(Money.START), {
		size = Theme.text.huge, color = Theme.color.neon, font = Theme.font.num,
	})
	bedrag.Size = UDim2.new(1, 0, 0, 46)

	local kopje = Instance.new("Frame")
	kopje.Size = UDim2.new(1, 0, 0, 24)
	kopje.BackgroundTransparency = 1
	kopje.LayoutOrder = 3
	kopje.Parent = blad
	UI.label(kopje, "AVAILABLE GAMES", {
		size = Theme.text.big, color = Theme.color.text, font = Theme.font.uiBold,
	})

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.LayoutOrder = 4
	raster.Parent = blad
	local rasterLayout = Instance.new("UIGridLayout")
	rasterLayout.CellSize = UDim2.new(0, 260, 0, 190)
	rasterLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	rasterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rasterLayout.Parent = raster

	for i, k in KAARTEN do
		tegel(raster, k, ga).LayoutOrder = i
	end

	return function(nieuw: number)
		bedrag.Text = "$" .. Money.fmt(nieuw)
	end
end

return Home
