--!strict
-- De VIP-zone, zoals `#vipView` in de markup: een hero van 40 pixels, de poort met de drie
-- voordelen erin, de seizoenstrip, en dan EXCLUSIVE GAMES met de twee spellen die nergens
-- anders in het casino staan.
--
-- Wie een sprint van drie dagen op nummer één afsluit, mag het hele seizoen naar binnen.
-- De poort zelf staat op de server, bij de spellen; dit scherm laat alleen zien of hij open
-- is. De kaarten dimmen is netjes, maar het is niet wat je tegenhoudt.
--
-- Wat Roblox niet heeft, en hoe het hier benaderd is:
--  * `filter: grayscale(0.7)` op een gesloten kaart -- alleen de `opacity: 0.45` is na te
--    doen, met een laag in de achtergrondkleur over de kaart heen.
--  * letter-spacing (`.home-subtitle`, `.game-card-desc`, `.season-label`) -- weggelaten.
--  * box-shadow onder een kaart bij hover -- daar blijft de neonrand van over.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Season = require(ReplicatedStorage.Shared.Season)
local Art = require(script.Parent.Art)
local Common = require(script.Parent.Common)

local Vip = {}

-- VIP_PERKS uit crash.html, woord voor woord.
local PERKS = {
	{ "\u{1F3B0}", "777", "Three reels. Three sevens pay 40x. Nowhere else in the casino." },
	{ "\u{1F68C}", "Ride the Bus", "Four calls through a shuffled deck, cash out after any of them." },
	{ "\u{1F39F}", "Four ways in", "Every three-day sprint crowns a new number one, so a season has four." },
}

-- De drie plekken die een sprint uitbetaalt, met de tekens uit RANKS. Geen geld: een titel,
-- en voor de winnaar de pas. De breedte staat er per chip bij, want de rij hangt rechts in
-- de strip: met AutomaticSize zou hij pas een frame later de goede maat hebben en dan
-- zichtbaar op zijn plek springen.
local PRIJZEN = {
	{ teken = "\u{1F451}", naam = "House Boss", wat = Season.PRIZES[1], breed = 240 },
	{ teken = "\u{1F948}", naam = "Challenger", wat = Season.PRIZES[2], breed = 160 },
	{ teken = "\u{1F949}", naam = "Podium", wat = Season.PRIZES[3], breed = 140 },
}

-- `.game-card.vip-card` heeft een gouden rand van rgba(224,181,85,0.35). Staat de kaart op
-- slot, dan gaat er in de CSS opacity 0.45 overheen; die twee samen zijn hier één getal,
-- want een UIStroke ligt buiten de CanvasGroup en dimt dus niet met de inhoud mee.
local KAART_RAND_OPEN = 0.65
local KAART_RAND_DICHT = 0.8

-- `.game-card-desc` is 11 op line-height 1.6; de langste omschrijving (Ride the Bus) loopt
-- over vier regels. In de CSS rekt de kaart met de tekst mee en zijn de kaarten in een rij
-- daarna even hoog; een UIGridLayout heeft één maat voor alle cellen, dus staat de hoogte
-- van het tekstvak hier vast op die vier regels.
local DESC_HOOG = 4 * 18   -- 11 * 1.6, naar boven afgerond
local KAART_HOOG = 330

-- Een blok met een rand kan zijn marge niet zelf dragen: padding valt binnen de rand en
-- maakt het paneel gewoon hoger. Zo'n blok krijgt daarom een omhulsel dat niets doet
-- behalve de marge uit de CSS onder zich openhouden.
local function omhulsel(ouder: Instance, naam: string, margeOnder: number, volgorde: number): Frame
	local f = Instance.new("Frame")
	f.Name = naam
	f.LayoutOrder = volgorde
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	UI.padding4(f, 0, 0, margeOnder, 0)
	f.Parent = ouder
	return f
end

type Kaart = { id: string, label: string, desc: string, rtp: string }

local KAARTEN: { Kaart } = {
	{ id = "slots", label = "777", rtp = "RTP 97%",
	  desc = "Three reels. Three sevens pay 40x, two cherries pay small." },
	{ id = "bus", label = "RIDE THE BUS", rtp = "RTP 97%",
	  desc = "Four calls through a shuffled deck: colour, higher or lower, inside or outside, then the suit. Cash out after any of them." },
}

-- Wat een kaart nodig heeft om van open naar dicht te gaan en terug.
type KaartDelen = {
	titel: TextLabel,
	label: string,
	pil: TextLabel,
	pijl: TextLabel,
	rand: UIStroke,
	kaart: CanvasGroup,
}

function Vip.build(ouder: Instance, ga: (string) -> ()): (any) -> ()
	local blad = Common.sheet(ouder)

	-- `#vipView` heeft `padding: 40px 50px`, dezelfde marge als de lobby. De schil zet er al
	-- Theme.size.viewPad omheen, dus komt alleen het verschil hier nog bovenop.
	local bladRand = blad:FindFirstChildOfClass("UIPadding")
	if bladRand then
		bladRand.PaddingTop = UDim.new(0, Theme.size.homePadY - Theme.size.viewPad)
		bladRand.PaddingBottom = UDim.new(0, Theme.size.homePadY - Theme.size.viewPad)
		bladRand.PaddingLeft = UDim.new(0, Theme.size.homePadX - Theme.size.viewPad)
		bladRand.PaddingRight = UDim.new(0, Theme.size.homePadX - Theme.size.viewPad)
	end
	-- De blokken staan in de CSS niet op gelijke afstand: de hero heeft 26 onder zich, de
	-- poort 22, de strip 26 en de sectiekop 24. Een UIListLayout kent maar één tussenruimte,
	-- dus staat die op nul en draagt elk blok zijn eigen marge.
	local bladLijst = blad:FindFirstChildOfClass("UIListLayout")
	if bladLijst then bladLijst.Padding = UDim.new(0, 0) end

	-- ---------- .home-hero ----------
	-- Op dit scherm staat de titel op 40 in plaats van 64 (inline style in de markup).
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.LayoutOrder = 1
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.BackgroundTransparency = 1
	hero.Parent = blad
	-- `.home-title` heeft 12 onder zich; de hero zelf 26 (inline style in de markup).
	UI.padding4(hero, 0, 0, 26, 0)
	UI.list(hero, 12)

	local heroKop = UI.label(hero, "VIP ZONE", {
		size = 40, color = Theme.color.neon, font = Theme.font.uiBold,
	})
	heroKop.Size = UDim2.new(1, 0, 0, 46)

	UI.label(hero, "\u{25BA} FINISH A SPRINT AT #1 AND THE ZONE IS YOURS FOR THE SEASON", {
		size = Theme.text.body, color = Theme.color.muted,
	})

	-- ---------- .panel.vip-gate ----------
	local poort = UI.panel(omhulsel(blad, "GateWrap", 22, 2), "Gate")
	UI.list(poort, 16)
	-- `.vip-gate` heeft een egale gouden rand; de neongloed die elk paneel bovenaan heeft
	-- moet er dus af.
	-- `.vip-gate.open` legt daar bovenop een gouden waas:
	-- linear-gradient(180deg, rgba(224,181,85,0.07), transparent 60%) over var(--panel).
	-- Roblox kent geen twee lagen achtergrond, dus wordt de waas in het bestaande verloop
	-- van het paneel meegemengd.
	local poortVlak = poort:FindFirstChildOfClass("UIGradient")
	local POORT_DICHT = ColorSequence.new(Theme.color.panel, Theme.color.panelLight)
	local POORT_OPEN = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(
			Theme.color.panel.R + (Theme.color.gold.R - Theme.color.panel.R) * 0.07,
			Theme.color.panel.G + (Theme.color.gold.G - Theme.color.panel.G) * 0.07,
			Theme.color.panel.B + (Theme.color.gold.B - Theme.color.panel.B) * 0.07
		)),
		ColorSequenceKeypoint.new(0.6, Theme.color.panel),
		ColorSequenceKeypoint.new(1, Theme.color.panelLight),
	})

	local poortRand = poort:FindFirstChildOfClass("UIStroke")
	if poortRand then
		local gloed = poortRand:FindFirstChildOfClass("UIGradient")
		if gloed then gloed:Destroy() end
		poortRand.Color = Theme.color.gold
		poortRand.Transparency = 0.7   -- rgba(224,181,85,0.3)
	end

	-- .vip-head
	local kopVak = Instance.new("Frame")
	kopVak.Name = "Head"
	kopVak.Size = UDim2.new(1, 0, 0, 0)
	kopVak.AutomaticSize = Enum.AutomaticSize.Y
	kopVak.BackgroundTransparency = 1
	kopVak.Parent = poort
	UI.list(kopVak, 4)

	local stand = UI.label(kopVak, "\u{1F512} Locked", {
		size = Theme.text.card, color = Theme.color.text, font = Theme.font.uiMed,
	})
	stand.Size = UDim2.new(1, 0, 0, 24)

	local uitleg = UI.label(kopVak, "", { size = Theme.text.body, color = Theme.color.muted })
	uitleg.TextWrapped = true
	uitleg.AutomaticSize = Enum.AutomaticSize.Y
	uitleg.Size = UDim2.new(1, 0, 0, 0)
	uitleg.TextYAlignment = Enum.TextYAlignment.Top
	uitleg.LineHeight = 1.6

	-- .vip-perks: drie vakken naast elkaar met 12 ertussen.
	local perkRij = Instance.new("Frame")
	perkRij.Name = "Perks"
	perkRij.Size = UDim2.new(1, 0, 0, 0)
	perkRij.AutomaticSize = Enum.AutomaticSize.Y
	perkRij.BackgroundTransparency = 1
	perkRij.Parent = poort
	UI.list(perkRij, 12, Enum.FillDirection.Horizontal)

	for i, perk in PERKS do
		local vak = Instance.new("Frame")
		vak.Name = "Perk" .. i
		vak.LayoutOrder = i
		-- Drie gelijke kolommen: elk een derde, min zijn deel van de twee tussenruimtes.
		vak.Size = UDim2.new(1 / 3, -8, 0, 0)
		vak.AutomaticSize = Enum.AutomaticSize.Y
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = 0.8   -- rgba(0,0,0,0.2)
		vak.BorderSizePixel = 0
		UI.corner(vak, Theme.radius.card)
		UI.stroke(vak, Theme.color.border)
		UI.padding4(vak, 10, 12, 10, 12)
		vak.Parent = perkRij
		local vakLijst = UI.list(vak, 10, Enum.FillDirection.Horizontal)
		vakLijst.VerticalAlignment = Enum.VerticalAlignment.Center

		local ic = UI.label(vak, perk[1], { size = 20, align = Enum.TextXAlignment.Center })
		ic.LayoutOrder = 1
		ic.Size = UDim2.fromOffset(28, 28)

		local tekstVak = Instance.new("Frame")
		tekstVak.LayoutOrder = 2
		tekstVak.Size = UDim2.new(1, -38, 0, 0)
		tekstVak.AutomaticSize = Enum.AutomaticSize.Y
		tekstVak.BackgroundTransparency = 1
		tekstVak.Parent = vak
		UI.list(tekstVak, 2)

		UI.label(tekstVak, perk[2], { size = Theme.text.label, font = Theme.font.uiMed })

		local ds = UI.label(tekstVak, perk[3], { size = Theme.text.tiny, color = Theme.color.muted })
		ds.TextWrapped = true
		ds.AutomaticSize = Enum.AutomaticSize.Y
		ds.Size = UDim2.new(1, 0, 0, 0)
		ds.TextYAlignment = Enum.TextYAlignment.Top
		ds.LineHeight = 1.5
	end

	-- ---------- .season-strip ----------
	-- Dezelfde strip als in de lobby: links de aftelklok van de sprint, rechts wat elke
	-- plek oplevert.
	local strip = Instance.new("Frame")
	strip.Name = "Season"
	strip.Size = UDim2.new(1, 0, 0, 0)
	strip.AutomaticSize = Enum.AutomaticSize.Y
	strip.BackgroundColor3 = Theme.color.panel
	strip.BorderSizePixel = 0
	UI.gradient(strip, Theme.color.panel, Theme.color.panelLight)
	UI.corner(strip, Theme.radius.card)
	UI.stroke(strip, Theme.color.border)
	UI.padding4(strip, 18, 22, 18, 22)
	strip.Parent = omhulsel(blad, "SeasonWrap", 26, 3)

	local stripLinks = Instance.new("Frame")
	stripLinks.Name = "Now"
	stripLinks.Size = UDim2.new(1, -580, 0, 0)
	stripLinks.AutomaticSize = Enum.AutomaticSize.Y
	stripLinks.BackgroundTransparency = 1
	stripLinks.Parent = strip
	UI.list(stripLinks, 4)

	-- `.season-label` staat op 10, een maat lager dan de gewone paneelkopjes.
	local sprintKop = UI.label(stripLinks, "", { size = 10, color = Theme.color.muted })

	local klok = UI.label(stripLinks, "", {
		size = 26, color = Theme.color.neon, font = Theme.font.num,
	})
	klok.Size = UDim2.new(1, 0, 0, 34)

	UI.label(stripLinks, "until the standings reset to zero \u{00B7} whoever gains the most takes the title and a VIP pass", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	local seizoenRegel = UI.label(stripLinks, "", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})

	-- De twee klokken zijn rekenwerk op een tijdstempel, dus de strip kan zichzelf meteen
	-- vullen -- net als in de webversie, waar renderSeasonStrip() ook niets aan de server
	-- vraagt. De ranglijst zet er daarna de tijd van de server overheen.
	local function zetStrip(sprint: number, sprintEinde: number, seizoenEinde: number, sprintsOver: number, nu: number?)
		sprintKop.Text = "SPRINT " .. Season.sprintNoOf(sprint) .. " OF 4"
		klok.Text = Season.countdown(sprintEinde, nu)
		seizoenRegel.Text = "SEASON " .. Season.seasonNoOf(sprint) .. " ends in "
			.. Season.countdown(seizoenEinde, nu) .. " \u{00B7} "
			.. sprintsOver .. (if sprintsOver == 1 then " sprint" else " sprints")
			.. " left to earn a pass \u{00B7} a pass runs until the season ends"
	end

	-- .season-prizes staan rechts in de strip, verticaal in het midden.
	local prijzen = Instance.new("Frame")
	prijzen.Name = "Prizes"
	prijzen.AnchorPoint = Vector2.new(1, 0.5)
	prijzen.Position = UDim2.new(1, 0, 0.5, 0)
	prijzen.Size = UDim2.fromOffset(560, 30)
	prijzen.BackgroundTransparency = 1
	prijzen.Parent = strip
	local prijsLijst = UI.list(prijzen, 10, Enum.FillDirection.Horizontal)
	prijsLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right
	prijsLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	for i, pr in PRIJZEN do
		local vak = Instance.new("Frame")
		vak.Name = "Prize" .. i
		vak.LayoutOrder = i
		vak.Size = UDim2.fromOffset(pr.breed, 30)
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = 0.65   -- rgba(0,0,0,0.35)
		vak.BorderSizePixel = 0
		UI.corner(vak, Theme.radius.panel)
		UI.stroke(vak, Theme.color.border)
		UI.padding4(vak, 0, 12, 0, 12)
		vak.Parent = prijzen
		local rij = UI.list(vak, 8, Enum.FillDirection.Horizontal)
		rij.VerticalAlignment = Enum.VerticalAlignment.Center

		local teken = UI.label(vak, pr.teken, { size = Theme.text.body, align = Enum.TextXAlignment.Center })
		teken.LayoutOrder = 1
		teken.Size = UDim2.fromOffset(16, 30)

		local naam = UI.label(vak, pr.naam, { size = Theme.text.body, font = Theme.font.uiMed })
		naam.LayoutOrder = 2
		naam.AutomaticSize = Enum.AutomaticSize.X
		naam.Size = UDim2.new(0, 0, 1, 0)

		local bedrag = UI.label(vak, pr.wat, {
			size = Theme.text.body, color = Theme.color.gold, font = Theme.font.num,
		})
		bedrag.LayoutOrder = 3
		bedrag.AutomaticSize = Enum.AutomaticSize.X
		bedrag.Size = UDim2.new(0, 0, 1, 0)
	end

	-- ---------- .section-heading + .games-grid ----------
	local kopRij = Instance.new("Frame")
	kopRij.Name = "GamesHeading"
	kopRij.LayoutOrder = 4
	-- De kopregel is 34 hoog; de 24 van `.section-heading { margin-bottom }` staat eronder.
	kopRij.Size = UDim2.new(1, 0, 0, 34 + 24)
	kopRij.BackgroundTransparency = 1
	kopRij.Parent = blad
	UI.sectionHeading(kopRij, "EXCLUSIVE GAMES", "NOWHERE ELSE")

	local raster = Instance.new("Frame")
	raster.Name = "Grid"
	raster.LayoutOrder = 5
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = blad
	UI.padding4(raster, 0, 0, 50, 0)   -- `.games-grid { margin-bottom: 50px }`
	local rasterLijst = Instance.new("UIGridLayout")
	-- De kaarten zijn hoger dan in de lobby: de omschrijving van Ride the Bus loopt over
	-- vier regels.
	rasterLijst.CellSize = UDim2.fromOffset(Theme.size.cardMin, KAART_HOOG)
	rasterLijst.CellPadding = UDim2.fromOffset(Theme.size.cardGap, Theme.size.cardGap)
	rasterLijst.SortOrder = Enum.SortOrder.LayoutOrder
	rasterLijst.Parent = raster

	-- `repeat(auto-fill, minmax(280px, 1fr))`: de CSS legt zoveel kolommen van minstens 280
	-- naast elkaar als erin passen en rekt ze daarna op tot de rij vol is. Twee kaarten in
	-- een raster van vier kolommen zijn dus breder dan 280, niet smaller. UIGridLayout kan
	-- geen breuken, dus wordt de celbreedte hier uitgerekend zodra de breedte bekend is.
	local celNu = 0
	local function meetRaster()
		local breed = raster.AbsoluteSize.X
		if breed <= 0 then return end
		local gat = Theme.size.cardGap
		local kolommen = math.max(1, math.floor((breed + gat) / (Theme.size.cardMin + gat)))
		local cel = math.floor((breed - gat * (kolommen - 1)) / kolommen)
		if cel == celNu then return end
		celNu = cel
		rasterLijst.CellSize = UDim2.fromOffset(cel, KAART_HOOG)
	end
	raster:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetRaster)
	task.defer(meetRaster)

	local delen: { KaartDelen } = {}

	for i, k in KAARTEN do
		-- Een CanvasGroup, want `.vip-card.locked` zet `opacity: 0.45` over de hele kaart.
		-- Zo'n kaart tekent zichzelf eerst en gaat daarna als geheel doorschijnen; een
		-- donkere laag eroverheen legt alleen iets bovenop en laat felle kleuren fel.
		local f = Instance.new("CanvasGroup")
		f.Name = k.id
		f.LayoutOrder = i
		f.BackgroundColor3 = Theme.color.panel
		f.BorderSizePixel = 0
		f.ClipsDescendants = true
		UI.gradient(f, Theme.color.panel, Theme.color.panelLight)
		UI.corner(f, Theme.radius.card)
		-- `.game-card.vip-card` heeft een gouden rand in plaats van de grijze.
		local rand = UI.stroke(f, Theme.color.gold)
		rand.Transparency = KAART_RAND_DICHT
		f.Parent = raster

		-- De preview is de SVG uit de markup, nagetekend in Art.
		local teken = Art.BY_ID[k.id]
		if teken then teken(f) end
		local beeld = f:FindFirstChild("Art") :: Frame

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
		d.Size = UDim2.new(1, 0, 0, DESC_HOOG)
		d.TextYAlignment = Enum.TextYAlignment.Top
		d.LineHeight = 1.6

		-- .game-card-footer
		local voet = Instance.new("Frame")
		voet.Name = "Footer"
		voet.Size = UDim2.new(1, 0, 0, 22)
		voet.BackgroundTransparency = 1
		voet.Parent = body

		local pil = UI.tag(voet, k.rtp, Theme.color.gold)

		local pijl = UI.label(voet, "\u{2192}", {
			size = Theme.text.card, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
		})
		pijl.AnchorPoint = Vector2.new(1, 0.5)
		pijl.Position = UDim2.new(1, 0, 0.5, 0)
		pijl.Size = UDim2.fromOffset(24, 22)

		delen[i] = { titel = titel, label = k.label, pil = pil, pijl = pijl, rand = rand, kaart = f }

		local knop = Instance.new("TextButton")
		knop.Name = "Open"
		knop.Text = ""
		knop.BackgroundTransparency = 1
		knop.Size = UDim2.fromScale(1, 1)
		knop.ZIndex = 5
		knop.Parent = f
		knop.Activated:Connect(function()
			if f.GroupTransparency > 0 then
				Common.toast("VIP PASS REQUIRED", "red")
				return
			end
			ga(k.id)
		end)
		-- `.game-card.available:hover`, maar niet als de kaart dicht is (`cursor: not-allowed`).
		knop.MouseEnter:Connect(function()
			if f.GroupTransparency > 0 then return end
			rand.Transparency = 0
			rand.Color = Theme.color.neon
			pijl.TextColor3 = Theme.color.neon
			pijl.Position = UDim2.new(1, 4, 0.5, 0)
		end)
		knop.MouseLeave:Connect(function()
			rand.Transparency = if f.GroupTransparency > 0 then KAART_RAND_DICHT else KAART_RAND_OPEN
			rand.Color = Theme.color.gold
			pijl.TextColor3 = Theme.color.muted
			pijl.Position = UDim2.new(1, 0, 0.5, 0)
		end)
	end

	-- ---------- de stand van de poort ----------
	local function zetPoort(open: boolean, seizoenEinde: number?, nu: number?, sprintsOver: number?)
		local tot = seizoenEinde or Season.seasonEndsAt(Season.seasonId())
		local over = Season.countdown(tot, nu)
		if open then
			stand.Text = "\u{1F451} Your pass is valid"
			stand.TextColor3 = Theme.color.gold
			uitleg.Text = "You finished a sprint at #1. The zone stays open for "
				.. over .. ", until this season ends."
		else
			local n = sprintsOver or Season.sprintsLeft()
			stand.Text = "\u{1F512} Locked"
			stand.TextColor3 = Theme.color.text
			-- De webversie zet hier de namen van de pashouders neer als die er zijn. De
			-- server stuurt die lijst niet mee, dus blijft het bij de uitleg hoe je zelf
			-- binnenkomt -- dezelfde zin als wanneer nog niemand de zone heeft.
			uitleg.Text = "Finish a three-day sprint at the top of SPRINT PROFIT and the zone is yours "
				.. "for the rest of the season. " .. n .. (if n == 1 then " sprint" else " sprints")
				.. " left this season."
		end
		if poortRand then
			poortRand.Transparency = if open then 0.4 else 0.7   -- .vip-gate.open: rand 0.6
		end
		if poortVlak then
			poortVlak.Color = if open then POORT_OPEN else POORT_DICHT
		end
		for _, deel in delen do
			-- `.vip-card.locked { opacity: 0.45; filter: grayscale(0.7) }`.
			deel.kaart.GroupTransparency = if open then 0 else 0.55
			UI.grayscale(deel.kaart, if open then 0 else 0.7)
			-- `.locked .game-card-title::after { content: ' 🔒' }`
			deel.titel.Text = if open then deel.label else deel.label .. " \u{1F512}"
			deel.pil.TextColor3 = if open then Theme.color.neon else Theme.color.gold
			deel.pil.BackgroundColor3 = if open then Theme.color.neon else Theme.color.gold
			-- rgba(62,207,142,0.12) open, rgba(224,181,85,0.10) op slot
			deel.pil.BackgroundTransparency = if open then Theme.alpha.tagNeon else Theme.alpha.tagGold
			deel.pijl.Visible = open   -- `.locked .game-card-arrow { display: none }`
			deel.rand.Transparency = if open then KAART_RAND_OPEN else KAART_RAND_DICHT
		end
	end

	zetPoort(false)
	do
		local sprint = Season.sprintId()
		zetStrip(sprint, Season.sprintEndsAt(sprint), Season.seasonEndsAt(Season.seasonId()),
			Season.sprintsLeft(), nil)
	end

	-- ---------- de klokken ----------
	-- De server zegt of de pas geldt, en houdt de sprint- en seizoenklok bij; één aanroep
	-- voedt zowel de poort als de strip.
	task.spawn(function()
		while true do
			local res = Common.call("Leaderboard")
			if res then
				local sprint = tonumber(res.sprint) or Season.sprintId()
				local nu = tonumber(res.now)
				local seizoenEinde = tonumber(res.seasonEndsAt) or Season.seasonEndsAt(Season.seasonId())
				local over = tonumber(res.sprintsLeft) or Season.sprintsLeft(nu)
				zetStrip(sprint, tonumber(res.endsAt) or Season.sprintEndsAt(sprint), seizoenEinde, over, nu)
				zetPoort(res.vipActive == true, seizoenEinde, nu, over)
			end
			task.wait(30)
		end
	end)

	return function(p: any)
		if typeof(p) ~= "table" then return end
		-- Het profiel draagt het seizoen van de pas; dat is genoeg om het scherm meteen
		-- goed te zetten zonder op de ranglijst te wachten.
		zetPoort(Season.vipActive(tonumber(p.vipSeason)), nil, nil, nil)
	end
end

return Vip
