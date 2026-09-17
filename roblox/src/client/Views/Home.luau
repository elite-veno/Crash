--!strict
-- De lobby, zoals #homeView in de webversie: rechtsboven de twee chips naar profiel en VIP,
-- daaronder de hero van 64 pixels, de saldokaart met neonrand, en dan het raster met
-- speltegels.
--
-- De previews zijn geen plaatjes maar verlopen, precies de `.preview-*` klassen uit de CSS.
-- Daardoor hoeft er niets geüpload te worden voordat het er goed uitziet.
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
	rotatie: number?,
}

-- De kleuren komen uit de `preview-*` klassen van de CSS.
local KAARTEN: { Kaart } = {
	{ id = "crash", label = "CRASH", rtp = "97% RTP",
	  desc = "Ride along and cash out before it crashes. Multipliers up to 1000x.",
	  van = Color3.fromHex("5fb8ff"), tot = Color3.fromHex("4a8a2a") },
	{ id = "roulette", label = "ROULETTE", rtp = "97.3% RTP",
	  desc = "European roulette with a single green zero.",
	  van = Color3.fromHex("2a1010"), tot = Color3.fromHex("0a0505") },
	{ id = "tower", label = "DRAGON TOWER", rtp = "97% RTP",
	  desc = "Climb nine floors, dodge the dragon eggs.",
	  van = Color3.fromHex("2a0a3a"), tot = Color3.fromHex("0a0510") },
	{ id = "mines", label = "MINES", rtp = "97% RTP",
	  desc = "Collect diamonds, dodge the mines.",
	  van = Color3.fromHex("1a1a2a"), tot = Color3.fromHex("0a0a14"), rotatie = 135 },
	{ id = "plinko", label = "PLINKO", rtp = "97% RTP",
	  desc = "Drop a ball and watch where it lands.",
	  van = Color3.fromHex("1a0a2a"), tot = Color3.fromHex("0a0518") },
	{ id = "blackjack", label = "BLACKJACK", rtp = "99% RTP",
	  desc = "Six decks, dealer stands on all 17s.",
	  van = Color3.fromHex("0a3a1a"), tot = Color3.fromHex("051a0a") },
	{ id = "scratch", label = "SCRATCH CARDS", rtp = "97% RTP",
	  desc = "Nine squares, three of a kind pays.",
	  van = Color3.fromHex("1f4a4a"), tot = Color3.fromHex("0c1f1f") },
	{ id = "wheel", label = "WHEEL", rtp = "97% RTP",
	  desc = "Twenty segments, one pays ten times.",
	  van = Color3.fromHex("4a3a12"), tot = Color3.fromHex("1e1707") },
	{ id = "horse", label = "HORSE RACE", rtp = "97% RTP",
	  desc = "Six horses, back the one you fancy.",
	  van = Color3.fromHex("2f5a1a"), tot = Color3.fromHex("13260b") },
}

-- .game-card: radius 6, preview van 160 met een rand eronder, body met padding 18, en
-- onderin een pilletje plus een pijl die bij hover naar rechts schuift.
local function tegel(ouder: Instance, k: Kaart, ga: (string) -> ()): Frame
	local f = Instance.new("Frame")
	f.Name = k.id
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	UI.gradient(f, Theme.color.panel, Theme.color.panelLight)
	UI.corner(f, Theme.radius.card)
	local rand = UI.stroke(f)
	f.Parent = ouder

	local beeld = Instance.new("Frame")
	beeld.Name = "Preview"
	beeld.Size = UDim2.new(1, 0, 0, Theme.size.cardPreview)
	beeld.BackgroundColor3 = k.van
	beeld.BorderSizePixel = 0
	beeld.Parent = f
	UI.gradient(beeld, k.van, k.tot, k.rotatie or 90)

	local onderRand = Instance.new("Frame")
	onderRand.AnchorPoint = Vector2.new(0, 1)
	onderRand.Position = UDim2.fromScale(0, 1)
	onderRand.Size = UDim2.new(1, 0, 0, 1)
	onderRand.BackgroundColor3 = Theme.color.border
	onderRand.BorderSizePixel = 0
	onderRand.Parent = beeld

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, Theme.size.cardPreview)
	body.Size = UDim2.new(1, 0, 1, -Theme.size.cardPreview)
	body.BackgroundTransparency = 1
	body.Parent = f
	UI.padding(body, Theme.size.panelPad)
	UI.list(body, 6)

	local titel = UI.label(body, k.label, {
		size = Theme.text.card, color = Theme.color.neon, font = Theme.font.uiMed,
	})
	titel.Size = UDim2.new(1, 0, 0, Theme.text.card + 6)

	local d = UI.label(body, k.desc, { size = Theme.text.tiny, color = Theme.color.muted })
	d.TextWrapped = true
	d.Size = UDim2.new(1, 0, 0, 34)
	d.TextYAlignment = Enum.TextYAlignment.Top

	-- .game-card-footer
	local voet = Instance.new("Frame")
	voet.Size = UDim2.new(1, 0, 0, 22)
	voet.BackgroundTransparency = 1
	voet.Parent = body

	UI.tag(voet, k.rtp, Theme.color.neon)

	local pijl = UI.label(voet, "\u{2192}", {
		size = Theme.text.card, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
	})
	pijl.AnchorPoint = Vector2.new(1, 0.5)
	pijl.Position = UDim2.new(1, 0, 0.5, 0)
	pijl.Size = UDim2.fromOffset(24, 22)

	local knop = Instance.new("TextButton")
	knop.Text = ""
	knop.BackgroundTransparency = 1
	knop.Size = UDim2.fromScale(1, 1)
	knop.ZIndex = 3
	knop.Parent = f
	knop.Activated:Connect(function()
		ga(k.id)
	end)
	-- .game-card.available:hover: de rand wordt neon en de pijl schuift op.
	knop.MouseEnter:Connect(function()
		rand.Color = Theme.color.neon
		pijl.TextColor3 = Theme.color.neon
		pijl.Position = UDim2.new(1, 4, 0.5, 0)
	end)
	knop.MouseLeave:Connect(function()
		rand.Color = Theme.color.border
		pijl.TextColor3 = Theme.color.muted
		pijl.Position = UDim2.new(1, 0, 0.5, 0)
	end)
	return f
end

-- Een chip in de topbar: .home-chip.
local function topChip(ouder: Instance, tekst: string, ga: () -> (), goud: boolean?): (TextButton, TextLabel)
	local b = Instance.new("TextButton")
	b.Name = "HomeChip"
	b.Text = tekst
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = if goud then Theme.color.gold else Theme.color.text
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 32)
	b.RichText = false
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b, if goud then Theme.color.gold else Theme.color.border)
	UI.padding4(b, 0, 14, 0, 14)
	b.Parent = ouder

	local slotje = UI.label(b, "\u{1F512}", { size = Theme.text.tiny, align = Enum.TextXAlignment.Right })
	slotje.AnchorPoint = Vector2.new(0, 0.5)
	slotje.Position = UDim2.new(1, 2, 0.5, 0)
	slotje.Size = UDim2.fromOffset(16, 16)
	slotje.Visible = false

	b.Activated:Connect(ga)
	b.MouseEnter:Connect(function()
		rand.Color = Theme.color.neon
	end)
	b.MouseLeave:Connect(function()
		rand.Color = if goud then Theme.color.gold else Theme.color.border
	end)
	return b, slotje
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
	-- #homeView heeft padding 40/50; de marge van 40 zit al in de schil, dus hier alleen
	-- de extra breedte naar links en rechts.
	UI.padding4(blad, 0, Theme.size.homePadX - Theme.size.homePadY, 24, Theme.size.homePadX - Theme.size.homePadY)
	UI.list(blad, 18)

	-- ---------- .home-topbar ----------
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 32)
	topbar.BackgroundTransparency = 1
	topbar.LayoutOrder = 1
	topbar.Parent = blad
	local topLijst = UI.list(topbar, 10, Enum.FillDirection.Horizontal)
	topLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right
	topLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	topChip(topbar, "PROFILE", function()
		ga("profile")
	end).LayoutOrder = 1
	local vipChip, vipSlot = topChip(topbar, "VIP ZONE", function()
		ga("vip")
	end, true)
	vipChip.LayoutOrder = 2
	vipSlot.Visible = true

	-- ---------- .home-hero ----------
	local hero = Instance.new("Frame")
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.BackgroundTransparency = 1
	hero.LayoutOrder = 2
	hero.Parent = blad
	UI.list(hero, 12)

	local kop = UI.label(hero, "NEON CASINO", {
		size = Theme.text.hero, color = Theme.color.neon, font = Theme.font.uiMed,
	})
	kop.Size = UDim2.new(1, 0, 0, Theme.text.hero + 6)

	UI.label(hero, "\u{25BA} FAIR ODDS \u{00B7} PLAY MONEY ONLY", {
		size = Theme.text.body, color = Theme.color.muted,
	})

	-- ---------- .home-balance-card ----------
	local saldoKaart = Instance.new("Frame")
	saldoKaart.Name = "BalanceCard"
	saldoKaart.Size = UDim2.fromOffset(320, 0)
	saldoKaart.AutomaticSize = Enum.AutomaticSize.Y
	saldoKaart.BackgroundColor3 = Theme.color.panel
	saldoKaart.BorderSizePixel = 0
	saldoKaart.LayoutOrder = 3
	UI.gradient(saldoKaart, Theme.color.panel, Theme.color.panelLight, 135)
	UI.corner(saldoKaart, Theme.radius.panel)
	UI.stroke(saldoKaart, Theme.color.neon)
	UI.padding4(saldoKaart, 24, 32, 24, 32)
	UI.list(saldoKaart, 6)
	saldoKaart.Parent = blad

	UI.label(saldoKaart, "YOUR BALANCE", { size = Theme.text.small, color = Theme.color.muted })
	local bedrag = UI.moneyLabel(saldoKaart, Money.fmt(Money.START), Theme.text.balanceL)

	-- ---------- .section-heading + .games-grid ----------
	local kopRij = Instance.new("Frame")
	kopRij.Size = UDim2.new(1, 0, 0, 34)
	kopRij.BackgroundTransparency = 1
	kopRij.LayoutOrder = 4
	kopRij.Parent = blad
	UI.sectionHeading(kopRij, "AVAILABLE GAMES", #KAARTEN .. " LIVE")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.LayoutOrder = 5
	raster.Parent = blad
	local rasterLayout = Instance.new("UIGridLayout")
	rasterLayout.CellSize = UDim2.fromOffset(Theme.size.cardMin, 300)
	rasterLayout.CellPadding = UDim2.fromOffset(Theme.size.cardGap, Theme.size.cardGap)
	rasterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rasterLayout.Parent = raster

	for i, k in KAARTEN do
		tegel(raster, k, ga).LayoutOrder = i
	end

	return function(nieuw: number)
		bedrag.Text = Money.fmt(nieuw)
	end
end

return Home
