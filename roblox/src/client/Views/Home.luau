--!strict
-- De lobby, zoals #homeView in de webversie: rechtsboven de twee chips naar profiel en VIP,
-- daaronder de hero van 64 pixels, de saldokaart met neonrand, en dan het raster met
-- speltegels.
--
-- De previews zijn geen plaatjes maar verlopen, precies de `.preview-*` klassen uit de CSS.
-- Daardoor hoeft er niets geüpload te worden voordat het er goed uitziet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Art = require(script.Parent.Art)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

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

-- De kleuren komen uit de `preview-*` klassen van de CSS; de teksten en de volgorde staan
-- hier zoals ze in de markup staan, woord voor woord.
local KAARTEN: { Kaart } = {
	{ id = "crash", label = "CRASH", rtp = "RTP 97%",
	  desc = "Ride along and cash out before it crashes. Multipliers up to 1000x.",
	  van = Color3.fromHex("5fb8ff"), tot = Color3.fromHex("4a8a2a") },
	{ id = "roulette", label = "ROULETTE", rtp = "RTP 97.3%",
	  desc = "European roulette with a single green zero. Red, black, dozens or a straight number.",
	  van = Color3.fromHex("2a1010"), tot = Color3.fromHex("0a0505") },
	{ id = "tower", label = "DRAGON TOWER", rtp = "RTP 97%",
	  desc = "Climb nine floors, dodge the dragon eggs. Cash out whenever you want.",
	  van = Color3.fromHex("2a0a3a"), tot = Color3.fromHex("0a0510") },
	{ id = "mines", label = "MINES", rtp = "RTP 97%",
	  desc = "Collect diamonds, dodge the mines. You choose how many mines are buried.",
	  van = Color3.fromHex("1a1a2a"), tot = Color3.fromHex("0a0a14"), rotatie = 135 },
	{ id = "plinko", label = "PLINKO", rtp = "RTP 97%",
	  desc = "Drop the ball. Pick 8, 12 or 16 rows and your risk level.",
	  van = Color3.fromHex("1a0a2a"), tot = Color3.fromHex("0a0518") },
	{ id = "blackjack", label = "BLACKJACK", rtp = "RTP ~99%",
	  desc = "Against the dealer, 6 decks, dealer stands on 17. Blackjack pays 3:2.",
	  van = Color3.fromHex("0a3a1a"), tot = Color3.fromHex("051a0a") },
	{ id = "horse", label = "HORSE RACE", rtp = "RTP 97%",
	  desc = "Six horses, new odds every race. Back the winner, favourite or longshot.",
	  van = Color3.fromHex("2f5a1a"), tot = Color3.fromHex("13260b") },
	{ id = "scratch", label = "SCRATCH CARDS", rtp = "RTP 97%",
	  desc = "Buy a card and scratch nine cells. Three matching symbols pay up to 50x.",
	  van = Color3.fromHex("1f4a4a"), tot = Color3.fromHex("0c1f1f") },
	{ id = "wheel", label = "WHEEL OF FORTUNE", rtp = "RTP 97%",
	  desc = "Twenty segments, seven of them pay. One 10x segment for the patient.",
	  van = Color3.fromHex("4a3a12"), tot = Color3.fromHex("1e1707") },
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

	-- De preview is een getekende scène, zoals de SVG in de webversie. Een egaal verloop
	-- zag er naast het origineel uit als een lege doos.
	local teken = Art.BY_ID[k.id]
	local beeld: Frame
	if teken then
		teken(f)
		beeld = f:FindFirstChild("Art") :: Frame
	else
		beeld = Instance.new("Frame")
		beeld.Name = "Preview"
		beeld.Size = UDim2.new(1, 0, 0, Theme.size.cardPreview)
		beeld.BackgroundColor3 = k.van
		beeld.BorderSizePixel = 0
		beeld.Parent = f
		UI.gradient(beeld, k.van, k.tot, k.rotatie or 90)
	end

	local onderRand = Instance.new("Frame")
	onderRand.AnchorPoint = Vector2.new(0, 1)
	onderRand.Position = UDim2.fromScale(0, 1)
	onderRand.Size = UDim2.new(1, 0, 0, 1)
	onderRand.BackgroundColor3 = Theme.color.border
	onderRand.BorderSizePixel = 0
	onderRand.ZIndex = 2
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
	d.LineHeight = 1.6                       -- .game-card-desc { line-height: 1.6 }
	d.Size = UDim2.new(1, 0, 0, 36)          -- twee regels van 11 op 1,6
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

-- Een chip in de topbar: `.home-chip`. In de markup is dat een flexregel -- een icoon, de
-- naam, en bij de VIP-zone een klein pilletje erachter. Dus geen tekst op de knop zelf maar
-- een rij erin, anders staat het pilletje over de naam heen.
local function topChip(ouder: Instance, tekst: string, ga: () -> (), goud: boolean?): (TextButton, TextLabel)
	local b = Instance.new("TextButton")
	b.Name = "HomeChip"
	b.Text = ""
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 32)
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b, if goud then Theme.color.gold else Theme.color.border)
	UI.padding4(b, 0, 14, 0, 14)
	local rij = UI.list(b, 8, Enum.FillDirection.Horizontal)
	rij.VerticalAlignment = Enum.VerticalAlignment.Center
	rij.HorizontalAlignment = Enum.HorizontalAlignment.Center
	b.Parent = ouder

	local naam = UI.label(b, tekst, {
		size = Theme.text.tiny, color = if goud then Theme.color.gold else Theme.color.text,
	})
	naam.Name = "ChipLabel"
	naam.LayoutOrder = 1
	naam.AutomaticSize = Enum.AutomaticSize.X
	naam.Size = UDim2.new(0, 0, 1, 0)

	-- `.home-chip-badge`: een klein goud pilletje achter de naam. Er staat een slotje in
	-- zolang de zone dicht is en OPEN zodra de pas geldt.
	local slotje = Instance.new("TextLabel")
	slotje.Name = "ChipBadge"
	slotje.Text = "\u{1F512}"
	slotje.Font = Theme.font.ui
	slotje.TextSize = 10
	slotje.TextColor3 = Theme.color.gold
	slotje.BackgroundColor3 = Theme.color.gold
	slotje.BackgroundTransparency = 0.88            -- rgba(224,181,85,0.12)
	slotje.BorderSizePixel = 0
	slotje.LayoutOrder = 2
	slotje.Size = UDim2.fromOffset(0, 18)
	slotje.AutomaticSize = Enum.AutomaticSize.X
	slotje.RichText = false
	slotje.Visible = false
	UI.corner(slotje, Theme.radius.chip)
	UI.padding4(slotje, 0, 6, 0, 6)
	UI.stroke(slotje, Theme.color.gold).Transparency = 0.65   -- rgba(224,181,85,0.35)
	slotje.Parent = b

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
	-- `.home-balance-card` heeft `margin-top: 30`; het blad zet er zelf al 18 tussen, dus
	-- de kaart draagt de twaalf die ontbreken zelf. Zo ook hieronder voor de 50 van
	-- `.home-hero` en de 24 van `.section-heading`.
	saldoKaart.Position = UDim2.fromOffset(0, 12)
	UI.gradient(saldoKaart, Theme.color.panel, Theme.color.panelLight, 135)
	UI.corner(saldoKaart, Theme.radius.panel)
	UI.stroke(saldoKaart, Theme.color.neon)
	UI.padding4(saldoKaart, 24, 32, 24, 32)
	UI.list(saldoKaart, 6)
	saldoKaart.Parent = blad

	UI.label(saldoKaart, "YOUR BALANCE", { size = Theme.text.small, color = Theme.color.muted })
	local bedrag = UI.moneyLabel(saldoKaart, Money.fmt(Money.START), Theme.text.balanceL)

	-- `.account-bar`: hier staat er "SIGNED IN AS" voor de naam, anders dan in een
	-- speelscherm. Uitloggen bestaat niet in Roblox, dus die twee spans blijven weg.
	local rekening = UI.label(saldoKaart, "", { size = Theme.text.tiny, color = Theme.color.muted })
	rekening.Name = "AccountBar"
	rekening.RichText = true
	rekening.Text = Common.accent("SIGNED IN AS *" .. Players.LocalPlayer.DisplayName .. "*",
		Theme.color.neon)
	rekening.Size = UDim2.new(1, 0, 0, Theme.text.tiny + 10)   -- 11px tekst, margin-top 10

	-- `.js-broke` staat ook in deze kaart, boven de account-regel: dezelfde knop als in de
	-- aside van een speelscherm, en ook hier alleen zichtbaar als je blut bent.
	Common.brokeButton(saldoKaart, 2)
	rekening.LayoutOrder = 3
	rekening.TextYAlignment = Enum.TextYAlignment.Bottom

	-- ---------- .section-heading + .games-grid ----------
	local kopRij = Instance.new("Frame")
	-- 34 voor de kop zelf, plus wat `.home-hero` erboven en `.section-heading` eronder aan
	-- marge vragen bovenop de 18 van het blad: (50 - 18) en (24 - 18).
	kopRij.Size = UDim2.new(1, 0, 0, 34 + (50 - 18) + (24 - 18))
	kopRij.BackgroundTransparency = 1
	kopRij.LayoutOrder = 4
	kopRij.Parent = blad
	UI.padding4(kopRij, 50 - 18, 0, 24 - 18, 0)
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

	Common.rekKolommen(raster, rasterLayout, Theme.size.cardMin, Theme.size.cardGap, 300)

	for i, k in KAARTEN do
		tegel(raster, k, ga).LayoutOrder = i
	end

	-- ---------- .season-strip ----------
	-- De aftelklok van de sprint, met rechts wat elke plek oplevert.
	local strip = UI.panel(blad, "Season")
	strip.LayoutOrder = 6
	UI.list(strip, 4)
	local sprintKop = UI.label(strip, "SPRINT 1 OF 4", {
		size = Theme.text.small, color = Theme.color.muted,
	})
	local klok = UI.label(strip, "\u{2014}", {
		size = 26, color = Theme.color.neon, font = Theme.font.num,   -- .season-time
	})
	klok.Size = UDim2.new(1, 0, 0, 38)
	UI.label(strip, "until the standings reset to zero \u{00B7} whoever gains the most takes the title and a VIP pass", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	local regel2 = UI.label(strip, "\u{2014}", { size = Theme.text.tiny, color = Theme.color.muted })

	local prijzen = Instance.new("Frame")
	prijzen.AnchorPoint = Vector2.new(1, 0)
	prijzen.Position = UDim2.new(1, 0, 0, 6)
	prijzen.Size = UDim2.fromOffset(460, 26)
	prijzen.BackgroundTransparency = 1
	prijzen.Parent = strip
	local prijsLijst = UI.list(prijzen, 8, Enum.FillDirection.Horizontal)
	prijsLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right
	prijsLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	type Prijs = { naam: string, wat: string, kleur: Color3 }
	local PRIJZEN: { Prijs } = {
		-- De iconen en de namen uit RANKS, en de prijzen uit SPRINT_PRIZE. De naam staat in
		-- `<b>`, dus in de tekstkleur; alleen het bedrag ernaast is goud (`.amount`).
		{ naam = "\u{1F451} House Boss", wat = "VIP PASS + TITLE", kleur = Theme.color.text },
		{ naam = "\u{1F948} Challenger", wat = "TITLE", kleur = Theme.color.text },
		{ naam = "\u{1F949} Podium", wat = "TITLE", kleur = Theme.color.text },
	}
	for i, pr in PRIJZEN do
		local vak = Instance.new("Frame")
		vak.LayoutOrder = i
		vak.Size = UDim2.fromOffset(0, 26)
		vak.AutomaticSize = Enum.AutomaticSize.X
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = Theme.alpha.buttonBg
		vak.BorderSizePixel = 0
		UI.corner(vak, Theme.radius.button)
		UI.stroke(vak)
		UI.padding4(vak, 0, 10, 0, 10)
		local rij = UI.list(vak, 6, Enum.FillDirection.Horizontal)
		rij.VerticalAlignment = Enum.VerticalAlignment.Center
		vak.Parent = prijzen

		local naam = UI.label(vak, pr.naam, { size = Theme.text.tiny, color = pr.kleur })
		naam.AutomaticSize = Enum.AutomaticSize.X
		naam.Size = UDim2.new(0, 0, 1, 0)
		naam.LayoutOrder = 1
		local wat = UI.label(vak, pr.wat, {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
		})
		wat.AutomaticSize = Enum.AutomaticSize.X
		wat.Size = UDim2.new(0, 0, 1, 0)
		wat.LayoutOrder = 2
	end

	-- ---------- LIVE LEADERBOARD ----------
	local lbKop = Instance.new("Frame")
	lbKop.Size = UDim2.new(1, 0, 0, 34)
	lbKop.BackgroundTransparency = 1
	lbKop.LayoutOrder = 7
	lbKop.Parent = blad
	local _, lbTelling = UI.sectionHeading(lbKop, "LIVE LEADERBOARD", "\u{25CF} \u{2014}")
	lbTelling.TextColor3 = Theme.color.neon

	local lbRij = Instance.new("Frame")
	lbRij.Size = UDim2.new(1, 0, 0, 0)
	lbRij.AutomaticSize = Enum.AutomaticSize.Y
	lbRij.BackgroundTransparency = 1
	lbRij.LayoutOrder = 8
	lbRij.Parent = blad
	local lbLijst = UI.list(lbRij, 20, Enum.FillDirection.Horizontal)   -- .lb-grid { gap: 20px }
	lbLijst.VerticalAlignment = Enum.VerticalAlignment.Top

	type Kolom = { vak: Frame, lijst: Frame, leeg: TextLabel }
	local kolommen: { [string]: Kolom } = {}
	local KOLOMMEN = {
		{ id = "money", kop = "MOST MONEY", sub = "TOP 10" },
		{ id = "ratio", kop = "WIN / LOSS RATIO", sub = "TOP 10 \u{00B7} MIN. 10 ROUNDS" },
		{ id = "sprint", kop = "SPRINT PROFIT", sub = "TITLE AND A VIP PASS" },
	}
	for i, kol in KOLOMMEN do
		local vak = UI.panel(lbRij, kol.id)
		vak.LayoutOrder = i
		-- Drie gelijke kolommen met 20 ertussen: elk een derde min twee derde van een gat.
		vak.Size = UDim2.new(1 / 3, -40 / 3, 0, 0)
		UI.list(vak, 4)
		local kopRegel = Instance.new("Frame")
		kopRegel.Size = UDim2.new(1, 0, 0, 18)
		kopRegel.BackgroundTransparency = 1
		kopRegel.Parent = vak
		UI.label(kopRegel, "\u{25BA} " .. kol.kop, {
			size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
		})
		UI.label(kopRegel, kol.sub, {
			size = Theme.text.tiny, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
		})
		local lijst = Instance.new("Frame")
		lijst.Size = UDim2.new(1, 0, 0, 0)
		lijst.AutomaticSize = Enum.AutomaticSize.Y
		lijst.BackgroundTransparency = 1
		lijst.Parent = vak
		UI.list(lijst, 3)
		-- De regel die de webversie neerzet als er nog niemand gespeeld heeft; hij wordt
		-- als `.odds-note` getekend, dus hij loopt door over meerdere regels.
		local leeg = UI.label(lijst, "Nobody has played this sprint yet. The first round puts you on top.", {
			size = Theme.text.tiny, color = Theme.color.muted,
		})
		leeg.TextWrapped = true
		leeg.AutomaticSize = Enum.AutomaticSize.Y
		leeg.Size = UDim2.new(1, 0, 0, 0)
		leeg.TextYAlignment = Enum.TextYAlignment.Top
		leeg.LineHeight = 1.7
		kolommen[kol.id] = { vak = vak, lijst = lijst, leeg = leeg }
	end

	-- `.lb-note`: de regel onder de ranglijst. In Roblox komt de stand van de server, dus
	-- daar staat wat hier waar is.
	local lbNoot = UI.label(blad, "Real players, pulled live from the server. No bots.", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	lbNoot.Name = "LbNote"
	lbNoot.LayoutOrder = 9
	lbNoot.Size = UDim2.new(1, 0, 0, Theme.text.tiny + 8)

	-- ---------- ODDS & FAIRNESS ----------
	local oddsKop = Instance.new("Frame")
	oddsKop.Size = UDim2.new(1, 0, 0, 34)
	oddsKop.BackgroundTransparency = 1
	oddsKop.LayoutOrder = 10
	oddsKop.Parent = blad
	UI.sectionHeading(oddsKop, "ODDS & FAIRNESS", "EVERY MODE CHECKED")

	local oddsVak = UI.panel(blad, "Fairness")
	oddsVak.LayoutOrder = 11
	UI.list(oddsVak, 2)

	type OddsRij = { spel: string, rtp: string, huis: string, uitleg: string, kop: boolean? }
	local RIJEN: { OddsRij } = {
		{ spel = "GAME", rtp = "RTP", huis = "HOUSE", uitleg = "HOW IT WORKS", kop = true },
		{ spel = "CRASH", rtp = "97.0%", huis = "3.0%", uitleg = "The chance a flight reaches multiplier M = 0.97 / M. Every cash-out strategy has the same expectation." },
		{ spel = "ROULETTE", rtp = "97.3%", huis = "2.7%", uitleg = "European wheel with 37 pockets. Straight 35:1, dozen/column 2:1, red/black 1:1." },
		{ spel = "DRAGON TOWER", rtp = "97.0%", huis = "3.0%", uitleg = "Multiplier per floor = 0.97 x (tiles / safe tiles)^level." },
		{ spel = "MINES", rtp = "97.0%", huis = "3.0%", uitleg = "Multiplier = 0.97 x the inverse chance of finding k safe tiles in a row." },
		{ spel = "PLINKO", rtp = "97.0%", huis = "3.0%", uitleg = "Every row is a 50/50 left or right. The payout table per risk level is normalised to 97%." },
		{ spel = "SCRATCH CARDS", rtp = "97.0%", huis = "3.0%", uitleg = "Nine cells, three matching pay 1.25x to 50x. The card is fixed when you buy it; 21.6% of them pay." },
		{ spel = "SAFETY NET", rtp = "\u{2014}", huis = "\u{2014}", uitleg = "No stake. Only available when you are broke: stop the marker near the middle and get $10 to $40 to play on." },
		{ spel = "HORSE RACE", rtp = "97.0%", huis = "3.0%", uitleg = "Every horse has a fixed win chance; payout = 0.97 / that chance. The finishing order is drawn before the start and the animation follows it." },
		{ spel = "BLACKJACK", rtp = "~99%", huis = "~1%", uitleg = "6 decks, continuously shuffled, dealer stands on all 17s, blackjack 3:2, double on any two cards, no split." },
		{ spel = "WHEEL", rtp = "97.0%", huis = "3.0%", uitleg = "Twenty equal segments paying 19.4x between them: 19.4 / 20 = 0.97." },
		{ spel = "777 \u{00B7} VIP", rtp = "97.0%", huis = "3.0%", uitleg = "Three reels. Three of a kind pay 3x to 40x, two cherries 1.5x. 17% of spins pay." },
		{ spel = "RIDE THE BUS \u{00B7} VIP", rtp = "97.0%", huis = "3.0%", uitleg = "Every multiplier is 0.97 divided by the chance of getting that far, counted off the cards still in the deck. So stopping after any call returns 97%." },
	}
	-- `.odds-table th, td { padding: 10px 14px; border-bottom: 1px solid var(--border) }`.
	-- De uitleg is de langste kolom en loopt door over meerdere regels; afkappen zou juist
	-- het stuk weglaten waar de tabel voor bestaat. De rij groeit dus mee met zijn tekst.
	for i, r in RIJEN do
		local rij = Instance.new("Frame")
		rij.Size = UDim2.new(1, 0, 0, 0)
		rij.AutomaticSize = Enum.AutomaticSize.Y
		rij.BackgroundTransparency = 1
		rij.LayoutOrder = i
		rij.Parent = oddsVak
		UI.padding4(rij, 10, 0, 10, 0)

		local isKop = r.kop == true
		local kleur = if isKop then Theme.color.muted else Theme.color.text
		local function cel(tekst: string, x: number, breed: number, c: Color3, font: Enum.Font?): TextLabel
			local t = UI.label(rij, tekst, {
				size = Theme.text.tiny, color = c, font = font or Theme.font.ui,
			})
			t.Position = UDim2.new(x, 0, 0, 0)
			t.Size = UDim2.new(breed, -14, 0, Theme.text.tiny + 6)
			t.TextYAlignment = Enum.TextYAlignment.Top
			return t
		end
		cel(r.spel, 0, 0.17, kleur, if isKop then Theme.font.ui else Theme.font.uiMed)
		cel(r.rtp, 0.17, 0.07, if isKop then Theme.color.muted else Theme.color.neon, Theme.font.num)
		cel(r.huis, 0.24, 0.07, if isKop then Theme.color.muted else Theme.color.gold, Theme.font.num)

		-- De uitleg bepaalt de hoogte van de rij, dus die krijgt AutomaticSize.
		local uitleg = cel(r.uitleg, 0.31, 0.69, Theme.color.muted)
		uitleg.TextWrapped = true
		uitleg.AutomaticSize = Enum.AutomaticSize.Y
		uitleg.Size = UDim2.new(0.69, -14, 0, 0)

		-- De haarlijn onder elke rij, ook onder de laatste: zo staat het in de CSS.
		local lijn = Instance.new("Frame")
		lijn.Name = "Border"
		lijn.AnchorPoint = Vector2.new(0, 1)
		lijn.Position = UDim2.new(0, 0, 1, 10)
		lijn.Size = UDim2.new(1, 0, 0, 1)
		lijn.BackgroundColor3 = Theme.color.border
		lijn.BorderSizePixel = 0
		lijn.Parent = rij
	end

	-- ---------- de klok en de ranglijst bijhouden ----------
	local function vulLeaderboard()
		local res = Common.call("Leaderboard")
		if not res then return end
		local actief = tonumber(res.active) or 0
		lbTelling.Text = "\u{25CF} " .. actief .. " ACTIVE"

		-- `.home-chip-badge`: het slotje wordt OPEN zodra de pas geldt, en de chip krijgt
		-- de gouden rand van `.home-chip-vip.vip-open`.
		local vipAan = res.vipActive == true
		vipSlot.Text = if vipAan then "OPEN" else "\u{1F512}"
		vipChip.BackgroundColor3 = if vipAan then Theme.color.gold else Theme.color.black
		vipChip.BackgroundTransparency = if vipAan then 0.9 else Theme.alpha.buttonBg

		-- `SPRINT n OF 4`; het seizoensnummer hoort in de regel eronder.
		sprintKop.Text = Season.sprintHeading(tonumber(res.sprint) or 0)
		klok.Text = Season.countdown(res.endsAt, res.now)
		local n = tonumber(res.sprintsLeft) or 0
		regel2.Text = "SEASON " .. Season.seasonNoOf(tonumber(res.sprint) or 0)
			.. " ends in " .. Season.countdown(res.seasonEndsAt, res.now)
			.. " \u{00B7} " .. n .. (if n == 1 then " sprint" else " sprints")
			.. " left to earn a pass \u{00B7} a pass runs until the season ends"

		for _, kol in kolommen do
			for _, k in kol.lijst:GetChildren() do
				if k:IsA("Frame") then k:Destroy() end
			end
		end

		-- Elke kolom heeft zijn eigen lijst van de server en zijn eigen lege regel: een
		-- ranglijst die nog niemand heeft is niet hetzelfde als een die wel gevuld is.
		local function vul(kol: Kolom, rijen: any, waarde: (any) -> (string, Color3))
			local n = if typeof(rijen) == "table" then #rijen else 0
			kol.leeg.Visible = n == 0
			if n == 0 then return end
			for _, plek in rijen do
				local tekst, kleur = waarde(plek)
				local r = Common.statRow(kol.lijst, "#" .. plek.rank .. "  " .. plek.name, tekst)
				r.TextColor3 = kleur
			end
		end

		vul(kolommen.sprint, res.top, function(plek)
			local w = tonumber(plek.profit) or 0
			return (if w >= 0 then "+$" else "-$") .. Money.fmt(math.abs(w)),
				if w >= 0 then Theme.color.neon else Theme.color.red
		end)
		vul(kolommen.money, res.money, function(plek)
			return "$" .. Money.fmt(tonumber(plek.profit) or 0), Theme.color.gold
		end)
		vul(kolommen.ratio, res.ratio, function(plek)
			return string.format("%.2f", tonumber(plek.profit) or 0), Theme.color.gold
		end)
	end

	task.spawn(function()
		while true do
			vulLeaderboard()
			task.wait(30)
		end
	end)

	return function(nieuw: number)
		bedrag.Text = Money.fmt(nieuw)
	end
end

return Home
