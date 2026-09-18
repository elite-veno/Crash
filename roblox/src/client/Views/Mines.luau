--!strict
-- Mines: vijfentwintig tegels, een aantal mijnen ertussen. Waar ze liggen weet alleen de
-- server; een tegel die al open ligt telt niet nog een keer mee.
--
-- Het beeld komt regel voor regel uit de webversie: `#minesView` in de markup en
-- `.mines-grid`, `.tile`, `.field-group`, `.seg` en `.payout-line` in de CSS. Rechts het
-- bord met niets anders dan een raster van vijf bij vijf, links één paneel met daarin het
-- inzetveld, NUMBER OF MINES met de knoppenbalk eronder, de twee uitbetaalregels en de
-- knop. Precies de volgorde uit de markup.
--
-- Wat Roblox niet heeft en de CSS wel: letter-spacing (de 1px uit `.seg button` is
-- weggelaten), box-shadow (de gloed om een aangeklikte tegel is een los ringetje om de
-- tegel heen, de klop van de uitstapknop een gouden rand die op en neer gaat) en
-- `transform` (een tegel komt bij hover niet omhoog; de neonrand blijft over).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Mines = {}

-- De vijf knoppen uit `#mnQuickSeg`, in de volgorde van de markup.
local SNEL = { 1, 3, 5, 10, 24 }

-- ---------- maten uit de CSS ----------
local RASTER_MAX = 400     -- .mines-grid max-width
local RASTER_GAT = 8       -- .mines-grid gap
local KOLOMMEN = 5         -- .mines-grid grid-template-columns: repeat(5, 1fr)
local BORD_PAD = 22        -- .board padding
local TEGEL_TEKST = 26     -- .mines-grid .tile font-size

-- .tile.gem is rgba(62,207,142,0.16), .tile.egg rgba(224,97,110,0.16): in Roblox is dat de
-- kleur zelf plus de doorzichtigheid die daarbij hoort. .tile.dim is opacity 0.45.
local VULLING = 0.84
local DOF = 0.55
-- Een vlak van 0.16 dat ook nog eens op 0.45 staat: de twee doorzichtigheden op elkaar.
local VULLING_DOF = VULLING + (1 - VULLING) * DOF

local STREEP = Color3.fromHex("1a3a1a")       -- .payout-line border-bottom
local GOUD_DONKER = Color3.fromHex("cc9900")  -- .btn-cashout, het eind van het verloop

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .field-label: de naam links, de hint in neon rechts ("1 – 24").
local function veldKop(ouder: Instance, naam: string, hint: string): ()
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)   -- margin-bottom 6 onder een regel van 11
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted })
	local h = UI.label(rij, hint, {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
		name = "Hint",
	})
	h.TextTransparency = 0.3    -- .field-label .hint opacity 0.7
end

-- .payout-line: naam links, waarde rechts in het cijferlettertype, haarlijntje eronder.
-- 6 boven en 6 onder om een regel van 11 (die in de browser een regelvak van veertien
-- wordt) plus het haarlijntje zelf: zevenentwintig hoog. De twee regels staan in de CSS
-- pal tegen elkaar, dus ze komen in een eigen omhulsel zonder tussenruimte -- zie
-- payoutBlok hieronder.
local PAYOUT_HOOG = 27

local function payoutRegel(ouder: Instance, naam: string, kleur: Color3): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, PAYOUT_HOOG)
	rij.BackgroundTransparency = 1
	rij.Parent = ouder

	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.text, name = "Key" })
	local v = UI.label(rij, "\u{2014}", {
		size = Theme.text.small, color = kleur, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Value",
	})

	local lijn = Instance.new("Frame")
	lijn.Name = "Rule"
	lijn.AnchorPoint = Vector2.new(0, 1)
	lijn.Position = UDim2.new(0, 0, 1, 0)
	lijn.Size = UDim2.new(1, 0, 0, 1)
	lijn.BackgroundColor3 = STREEP
	lijn.BackgroundTransparency = 0.5   -- rgba(26,58,26,0.5)
	lijn.BorderSizePixel = 0
	lijn.Parent = rij
	return v
end

function Mines.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "MINES")

	-- ---------- het bord ----------
	-- `.board` houdt 22 pixels lucht aan; de gedeelde kolomhulp gebruikt de 18 van een
	-- gewoon paneel. Hier staat maar één ding in, dus dat scheelt zichtbaar.
	bord.Position = UDim2.fromOffset(BORD_PAD, BORD_PAD)
	bord.Size = UDim2.new(1, -BORD_PAD * 2, 1, -BORD_PAD * 2)

	-- `.mines-grid`: vijf gelijke kolommen met 8 ertussen, volle breedte tot 400, en tegels
	-- met aspect-ratio 1. Vijf vierkante cellen naast elkaar maken het raster zelf vierkant,
	-- dus het krijgt de kleinste kant van het bord als zijde (hooguit 400).
	local raster = Instance.new("Frame")
	raster.Name = "Grid"
	raster.Size = UDim2.fromOffset(RASTER_MAX, RASTER_MAX)
	raster.BackgroundTransparency = 1
	raster.Parent = bord

	local indeling = Instance.new("UIGridLayout")
	-- Een cel is een vijfde van de breedte min zijn deel van de vier gaten: 4 * 8 / 5.
	indeling.CellSize = UDim2.new(
		1 / KOLOMMEN, -RASTER_GAT * (KOLOMMEN - 1) / KOLOMMEN,
		1 / KOLOMMEN, -RASTER_GAT * (KOLOMMEN - 1) / KOLOMMEN
	)
	indeling.CellPadding = UDim2.fromOffset(RASTER_GAT, RASTER_GAT)
	indeling.SortOrder = Enum.SortOrder.LayoutOrder
	indeling.FillDirectionMaxCells = KOLOMMEN
	indeling.Parent = raster

	-- Het bord is niet altijd even breed als hoog; het raster volgt de kleinste kant mee.
	local function meet()
		local vak = bord.AbsoluteSize
		if vak.X <= 0 or vak.Y <= 0 then return end
		local zijde = math.min(vak.X, vak.Y, RASTER_MAX)
		raster.Size = UDim2.fromOffset(zijde, zijde)
	end
	bord:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	-- ---------- de stand van de ronde ----------
	local mijnen = 3                          -- #minesCount value="3"
	local actief = false
	local inzet = 0                           -- wat er in deze ronde op staat
	local gepakt = 0                          -- hoeveel diamanten er al liggen
	local geopend: { [number]: boolean } = {}
	local raak = -1                           -- de tegel waar het misging (MN.hit)
	local veld: { boolean }? = nil            -- de indeling, pas bekend als de ronde voorbij is
	-- In de browser gebeurt een klik meteen; hier ligt er een vraag aan de server tussen.
	-- Een tweede klik binnen die wachttijd zou een tweede tegel of een tweede inzet doen,
	-- dus zolang er een antwoord onderweg is neemt het scherm niets aan.
	local bezig = false

	local tegels: { TextButton } = {}
	local tegelRanden: { UIStroke } = {}
	local tegelRingen: { Frame } = {}
	local tegelSchalen: { UIScale } = {}
	local teken: () -> ()

	-- @keyframes tilePop: 0.7 -> 1.12 -> 1. Een Back-tween naar buiten schiet net zo voorbij
	-- de 1 en zakt daarna terug, dus dat is dezelfde beweging in één keer.
	local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local function pop(i: number)
		local s = tegelSchalen[i]
		s.Scale = 0.7
		TweenService:Create(s, POP, { Scale = 1 }):Play()
	end

	local function pak(i: number)
		if bezig or not actief or geopend[i] then return end
		bezig = true
		local res = Common.call("Act", "mines", i)
		bezig = false
		if not res then return end

		if res.mine then
			raak = i
			veld = res.grid
			actief = false
			teken()
			pop(i)
			Common.toast("BOOM! -$" .. Money.fmt(inzet), "red")
			return
		end

		geopend[i] = true
		if res.done then
			-- Het veld is leeg: de server rekent meteen af en stuurt geen indeling mee. Dat
			-- hoeft ook niet -- alles wat nu nog dicht ligt is per definitie een mijn.
			local alles = table.create(Odds.MINES_TILES, false)
			for t = 1, Odds.MINES_TILES do
				alles[t] = not geopend[t]
			end
			gepakt = Odds.MINES_TILES - mijnen
			veld = alles
			actief = false
			teken()
			pop(i)
			Common.toast("+$" .. Money.fmt(res.payout) .. " @ " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			return
		end

		gepakt = res.picked
		teken()
		pop(i)
	end

	for i = 1, Odds.MINES_TILES do
		local b = Instance.new("TextButton")
		b.Name = "Tile" .. i
		b.Text = ""
		b.Font = Theme.font.ui
		b.TextSize = TEGEL_TEKST
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg   -- .tile background rgba(0,0,0,0.5)
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Active = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.panel)                  -- .tile border-radius 4
		local rand = UI.stroke(b, Theme.color.border)

		-- .tile.picked legt er een `box-shadow: 0 0 0 2px var(--gold)` omheen: een gouden
		-- ring buiten de rand, die de rode rand van de mijn dus laat staan. Een tweede rand
		-- op dezelfde knop kan Roblox niet, dus het is een leeg vlakje van twee pixels groter
		-- aan elke kant met zijn eigen rand eromheen.
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.new(1, 4, 1, 4)
		ring.BackgroundTransparency = 1
		ring.BorderSizePixel = 0
		ring.Visible = false
		UI.corner(ring, Theme.radius.panel + 2)
		UI.stroke(ring, Theme.color.gold, 2)
		ring.Parent = b

		local schaal = Instance.new("UIScale")
		schaal.Parent = b
		-- .tile.clickable:hover kleurt de rand neon; het optillen doet een lijstindeling niet.
		b.MouseEnter:Connect(function()
			if b.Active then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			if b.Active then rand.Color = Theme.color.border end
		end)
		b.Activated:Connect(function()
			pak(i)
		end)
		b.Parent = raster
		tegels[i] = b
		tegelRanden[i] = rand
		tegelRingen[i] = ring
		tegelSchalen[i] = schaal
	end

	-- Eén tegel de jas geven die bij zijn toestand hoort, in dezelfde volgorde als mnRender().
	local function kleedTegel(i: number)
		local b = tegels[i]
		local rand = tegelRanden[i]
		local over = not actief and veld ~= nil

		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.TextColor3 = Theme.color.text
		b.TextTransparency = 0
		rand.Color = Theme.color.border
		rand.Thickness = 1
		rand.Transparency = 0
		b.Text = ""
		b.Active = false
		tegelRingen[i].Visible = false

		if geopend[i] then
			-- .tile.gem: de diamanten die je zelf hebt opgegraven.
			b.Text = "\u{25C6}"
			b.TextColor3 = Theme.color.neon
			b.BackgroundColor3 = Theme.color.neon
			b.BackgroundTransparency = VULLING
			rand.Color = Theme.color.neon
		elseif over then
			local mijn = (veld :: { boolean })[i]
			local kleur = if mijn then Theme.color.red else Theme.color.neon
			b.Text = if mijn then "\u{2738}" else "\u{25C6}"
			b.TextColor3 = kleur
			b.BackgroundColor3 = kleur
			b.BackgroundTransparency = VULLING
			rand.Color = kleur
			if i == raak then
				-- .tile.picked houdt zijn eigen (rode) rand en krijgt de gouden ring erbuiten;
				-- hij is ook de enige die niet naar .tile.dim zakt.
				tegelRingen[i].Visible = true
			else
				-- .tile.dim: de rest van het veld blijft op de achtergrond.
				b.TextTransparency = DOF
				rand.Transparency = DOF
				b.BackgroundTransparency = VULLING_DOF
			end
		elseif actief then
			b.Active = true    -- .tile.clickable
		end
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, het aantal mijnen, de twee uitbetaalregels en de
	-- knoppen in één `.panel`. Common.betBox maakt dat paneel, dus de rest gaat erbij in.
	-- De LayoutOrder hieronder geldt alleen bínnen dit paneel, waar het inzetveld op nul
	-- staat en dus voorop blijft.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel

	-- .field-group met het aantal mijnen. De 8 boven is de margin-bottom van het inzetveld
	-- erboven, de 8 onder die van deze groep zelf (14 min de 6 uit de lijst).
	local mijnVeld = Instance.new("Frame")
	mijnVeld.Name = "MinesField"
	mijnVeld.Size = UDim2.new(1, 0, 0, 0)
	mijnVeld.AutomaticSize = Enum.AutomaticSize.Y
	mijnVeld.BackgroundTransparency = 1
	mijnVeld.LayoutOrder = 10
	mijnVeld.Parent = paneel
	UI.list(mijnVeld, 6)
	UI.padding4(mijnVeld, 8, 0, 8, 0)

	veldKop(mijnVeld, "NUMBER OF MINES", "1 \u{2013} 24")
	local mijnVak = UI.numberBox(mijnVeld, tostring(mijnen))

	-- .seg: vijf gelijke knoppen met 4 pixels ertussen, de gekozene in neon.
	local seg = Instance.new("Frame")
	seg.Name = "Seg"
	-- 8 boven en 8 onder om een regel van 11 (regelvak veertien) plus twee randen van 1.
	seg.Size = UDim2.new(1, 0, 0, 32)
	seg.BackgroundTransparency = 1
	seg.Parent = mijnVeld
	UI.list(seg, 4, Enum.FillDirection.Horizontal)

	local segKnoppen: { [number]: TextButton } = {}
	local segRanden: { [number]: UIStroke } = {}

	for i, n in SNEL do
		local b = Instance.new("TextButton")
		b.Name = "Seg" .. n
		b.Text = tostring(n)
		b.Font = Theme.font.ui
		b.TextSize = Theme.text.tiny
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / #SNEL, -4 * (#SNEL - 1) / #SNEL, 1, 0)
		b.RichText = false
		-- Het cijfer staat midden in zijn hokje, zoals elke `.seg button`. UI.label zet in
		-- dit project alles links uit, dus hier staat het er los bij om geen twijfel te laten.
		b.TextXAlignment = Enum.TextXAlignment.Center
		UI.corner(b, Theme.radius.chip)
		local rand = UI.stroke(b, Theme.color.border)
		b.MouseEnter:Connect(function()
			if mijnen ~= n and not actief then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if mijnen == n then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			if actief then return end
			mijnen = n
			-- Een ander aantal mijnen betekent een ander veld: het bord gaat weer dicht.
			table.clear(geopend)
			gepakt = 0
			raak = -1
			veld = nil
			teken()
		end)
		b.Parent = seg
		segKnoppen[n] = b
		segRanden[n] = rand
	end

	-- De twee `.payout-line`-regels raken elkaar in de CSS: geen marge, geen tussenruimte,
	-- het haarlijntje van de bovenste is meteen de bovenkant van de onderste. Het paneel
	-- houdt zes pixels tussen zijn kinderen, dus de twee regels gaan samen in één blok dat
	-- zelf niets tussen zijn kinderen laat. De twee pixels onderaan maken van die zes de
	-- acht van `.btn-primary { margin-top: 8px }` onder het blok.
	local payoutBlok = Instance.new("Frame")
	payoutBlok.Name = "PayoutLines"
	payoutBlok.Size = UDim2.new(1, 0, 0, PAYOUT_HOOG * 2 + 2)
	payoutBlok.BackgroundTransparency = 1
	payoutBlok.LayoutOrder = 11
	payoutBlok.Parent = paneel
	UI.list(payoutBlok, 0)

	local huidigLabel = payoutRegel(payoutBlok, "CURRENT WIN", Theme.color.neon)
	local volgendLabel = payoutRegel(payoutBlok, "NEXT TILE", Theme.color.gold)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local startKnop = UI.primary(paneel, "START")
	startKnop.LayoutOrder = 13
	startKnop.Font = Theme.font.uiBold
	startKnop.TextXAlignment = Enum.TextXAlignment.Center
	UI.gradient(startKnop, Theme.color.neon, Theme.color.neonDim, 135)

	-- .btn-primary.btn-cashout: goud, en hij klopt één keer per seconde. Die klop is in de
	-- CSS een box-shadow; hier is het een gouden rand die op en neer gaat.
	local uitKnop = UI.primary(paneel, "CASH OUT")
	uitKnop.LayoutOrder = 14
	uitKnop.Font = Theme.font.uiBold
	uitKnop.TextXAlignment = Enum.TextXAlignment.Center
	uitKnop.BackgroundColor3 = Theme.color.gold
	uitKnop.TextColor3 = Theme.color.bg
	uitKnop.Visible = false
	UI.gradient(uitKnop, Theme.color.gold, GOUD_DONKER, 135)
	local klopRand = UI.stroke(uitKnop, Theme.color.gold, 2)
	klopRand.Transparency = 1
	local klop = TweenService:Create(
		klopRand,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.5 }   -- rgba(224,181,85,0.5) uit @keyframes pulse-gold
	)

	-- Het verloop uit .btn-bet en .btn-cashout blijft staan, dus de hover van UI.primary
	-- zou niets doen; de knoppen houden hun kleur en dat is precies wat de CSS ook doet.

	-- ---------- alles bijwerken wat van de stand afhangt ----------
	function teken()
		for i = 1, Odds.MINES_TILES do
			kleedTegel(i)
		end

		-- .seg button.on krijgt neon achter zich, .seg button:disabled zakt naar opacity 0.4.
		for n, b in segKnoppen do
			local aan = n == mijnen
			local rand = segRanden[n]
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			b.Font = if aan then Theme.font.uiBold else Theme.font.ui
			rand.Color = if aan then Theme.color.neon else Theme.color.border
			local vol = if aan then 0 else Theme.alpha.buttonBg
			b.Active = not actief
			b.BackgroundTransparency = if actief then math.min(1, vol + 0.4) else vol
			b.TextTransparency = if actief then 0.6 else 0
			rand.Transparency = if actief then 0.6 else 0
		end

		-- #minesCount is disabled zolang er een ronde loopt, net als #minesBet.
		mijnVak.Text = tostring(mijnen)
		mijnVak.TextEditable = not actief
		mijnVak.TextTransparency = if actief then 0.5 else 0
		betBox.lock(actief)

		startKnop.Visible = not actief
		uitKnop.Visible = actief

		local rest = Odds.MINES_TILES - mijnen   -- maxK: zoveel diamanten liggen er hoogstens
		if actief then
			local mult = Odds.minesMultiplier(mijnen, gepakt)
			local nu = Money.floor2(inzet * mult)
			huidigLabel.Text = if gepakt > 0
				then "$" .. Money.fmt(nu) .. " (" .. Money.fmt(mult) .. "\u{00D7})"
				else "\u{2014}"
			volgendLabel.Text = if gepakt < rest
				then Money.fmt(Odds.minesMultiplier(mijnen, gepakt + 1)) .. "\u{00D7}"
				else "\u{2014}"
			uitKnop.Text = if gepakt > 0 then "CASH OUT $" .. Money.fmt(nu) else "PICK A TILE"
			-- Uitstappen kan pas als er een diamant ligt; tot dan is de knop dood.
			UI.setEnabled(uitKnop, gepakt > 0)
			uitKnop.BackgroundTransparency = if gepakt > 0 then 0 else 0.4
			if gepakt > 0 then
				klop:Play()
			else
				klop:Pause()
				klopRand.Transparency = 1
			end
		else
			huidigLabel.Text = "\u{2014}"
			volgendLabel.Text = Money.fmt(Odds.minesMultiplier(mijnen, 1)) .. "\u{00D7}"
			klop:Pause()
			klopRand.Transparency = 1
		end
	end

	-- mnSetMines(): hele getallen tussen 1 en 24, en wat er niet door kan blijft staan
	-- zoals het was. Het veld gaat dicht, want een ander aantal mijnen is een ander veld.
	local function zetMijnen(ruw: string)
		local n = tonumber(ruw)
		if not n then
			teken()   -- zet de tekst terug op wat er echt staat
			return
		end
		mijnen = math.clamp(math.floor(n), 1, 24)
		if not actief then
			table.clear(geopend)
			gepakt = 0
			raak = -1
			veld = nil
		end
		teken()
	end
	mijnVak.FocusLost:Connect(function()
		zetMijnen(mijnVak.Text)
	end)

	startKnop.Activated:Connect(function()
		if bezig or actief then return end
		-- mnStart() leest het veld eerst uit, zodat een net getypt getal ook meetelt.
		zetMijnen(mijnVak.Text)
		local bedrag = betBox.get()
		bezig = true
		local res = Common.call("Bet", "mines", bedrag, mijnen)
		bezig = false
		if not res then return end
		inzet = bedrag
		actief = true
		gepakt = 0
		raak = -1
		veld = nil
		table.clear(geopend)
		teken()
	end)

	uitKnop.Activated:Connect(function()
		if bezig or not actief or gepakt < 1 then return end
		bezig = true
		local res = Common.call("CashOut", "mines")
		bezig = false
		if not res then return end
		actief = false
		veld = res.grid
		teken()
		Common.toast("+$" .. Money.fmt(res.payout) .. " @ " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
	end)

	teken()

	-- De twee panelen waar elke aside in de webversie mee afsluit. De vetgedrukte stukken
	-- in de `.odds-note` zijn in de CSS goud, maar twee kleuren in één regel zou RichText
	-- vragen en dat staat in dit project uit, dus het is één kleur.
	Common.statsPanel(bediening, "mines")
	Common.oddsPanel(bediening, "odds", "25 tiles. Multiplier after k diamonds = *0.97 / chance(k safe in a row)*. RTP *97%* at every cash-out. The mines are placed before your first click.")
end

return Mines
