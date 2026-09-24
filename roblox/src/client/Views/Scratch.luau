--!strict
-- Krasloten: negen vakjes die je één voor één openkrast. De server houdt de symbolen vast
-- tot je een vakje aanraakt, dus je kunt niet vooruit kijken -- en pas als het hele lot
-- open ligt, verklapt het scherm welke drie het geworden zijn.
--
-- Het beeld komt uit `#scratchView` in de markup en uit `.scratch-grid`, `.tile`,
-- `.sc-legend` en `.payout-line` in de CSS. Rechts één vierkant rooster van drie bij drie,
-- volle breedte tot 360 pixels, en verder niets: geen balk eronder, want die staat in de
-- webversie ook niet op het bord. Links het inzetvak -- dat hier PRICE PER CARD heet in
-- plaats van STAKE -- met de RESULT-regel en de twee knoppen erin, en daaronder PRIZES,
-- STATISTICS en ODDS, in die volgorde.
--
-- Wat Roblox niet heeft: letter-spacing (de 1px uit `.sc-prize .sy` is weggelaten), de
-- box-shadow onder de knoppen, en de gloedring om een winnend vakje -- daarvoor staat hier
-- alleen de neonrand. De klop van `.btn-cashout` is een gouden rand die op en neer gaat, en
-- de `tilePop` van een net opengekrast vakje zit in de lettergrootte in plaats van in het
-- vakje zelf: een cel van een UIGridLayout heeft zijn maat niet zelf in de hand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Scratch = {}

-- ---------- maten uit de CSS ----------
local RASTER_MAX = 360     -- .scratch-grid max-width
local GAT = 10             -- .scratch-grid gap
-- Drie kolommen met twee keer 10 pixels lucht binnen 360: 113 per vakje.
local CEL = (RASTER_MAX - 2 * GAT) // 3
local SYMBOOL = 30         -- .scratch-grid .tile font-size

-- .tile background rgba(0,0,0,0.5), .tile.gem rgba(62,207,142,0.16), .tile.dim opacity 0.45.
local GEM_VUL = 0.84
local DOF = 0.55

local STREEP = Color3.fromHex("1a3a1a")       -- .payout-line border-bottom
local GOUD_DONKER = Color3.fromHex("cc9900")  -- .btn-cashout, het eind van het verloop

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .payout-line: naam links, waarde rechts in het cijferlettertype, haarlijntje eronder.
-- Geeft allebei de labels terug, want hier verandert ook de naam mee: TO GO zolang je
-- krast, RESULT zodra het lot af is.
local function payoutRegel(ouder: Instance, naam: string, orde: number): (TextLabel, TextLabel)
	-- De regel is 27 hoog: 11px tekst met padding 6 boven en onder plus de haarlijn. De
	-- `.field-group` erboven draagt zijn eigen marge, dus er hoeft hier niets bij.
	local LUCHT = 0
	local HOOG = Theme.size.payoutRow

	local rij = Instance.new("Frame")
	rij.Name = "PayoutLine"
	rij.Size = UDim2.new(1, 0, 0, LUCHT + HOOG)
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
	rij.Parent = ouder

	local k = UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.text, name = "Key" })
	local v = UI.label(rij, "\u{2014}", {
		size = Theme.text.small, color = Theme.color.gold, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Value",
	})
	-- De 6 pixels padding boven en onder uit .payout-line: de tekst staat midden in de regel,
	-- onder de lucht, en de haarlijn onderaan sluit hem af.
	for _, t in { k, v } do
		t.Position = UDim2.fromOffset(0, LUCHT)
		t.Size = UDim2.new(1, 0, 0, HOOG)
		t.TextYAlignment = Enum.TextYAlignment.Center
	end

	local lijn = Instance.new("Frame")
	lijn.Name = "Rule"
	lijn.AnchorPoint = Vector2.new(0, 1)
	lijn.Position = UDim2.new(0, 0, 1, 0)
	lijn.Size = UDim2.new(1, 0, 0, 1)
	lijn.BackgroundColor3 = STREEP
	lijn.BackgroundTransparency = 0.5   -- rgba(26,58,26,0.5)
	lijn.BorderSizePixel = 0
	lijn.Parent = rij
	return k, v
end

-- .sc-prize: drie keer het symbool links, de multiplier rechts in goud. Twaalf pixels --
-- het paneel staat in de markup op 10, maar deze regel zet zijn eigen maat. De regel is
-- precies zo hoog als die tekst (16), zodat de 6 uit `.sc-legend` de enige lucht blijft.
local function prijsRegel(ouder: Instance, symbolen: string, mult: string, orde: number): ()
	local rij = Instance.new("Frame")
	rij.Name = "Prize"
	rij.Size = UDim2.new(1, 0, 0, 16)
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
	rij.Parent = ouder

	local sym = UI.label(rij, symbolen, { size = Theme.text.body, color = Theme.color.text, name = "Sym" })
	local mu = UI.label(rij, mult, {
		size = Theme.text.body, color = Theme.color.gold, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Mult",
	})
	-- UI.label geeft zichzelf tekstgrootte + 6; hier vult hij de regel, anders zakt hij
	-- er onderuit en staat de tekst niet meer in het midden.
	for _, t in { sym, mu } do
		t.Size = UDim2.fromScale(1, 1)
	end
end

function Scratch.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "SCRATCH CARDS")

	-- ---------- het bord ----------
	-- `.scratch-grid`: `repeat(3, 1fr)` met 10 pixels ertussen, volle breedte tot 360, en
	-- `aspect-ratio: 1` per vakje. Een vakje van hele pixels blijft alleen vierkant als het
	-- rooster het ook is, dus de maat wordt uitgerekend in plaats van geschaald: de breedte
	-- van het bord, afgetopt op 360, min twee keer de tussenruimte, door drie.
	local raster = Instance.new("Frame")
	raster.Name = "Grid"
	raster.Size = UDim2.fromOffset(CEL * 3 + 2 * GAT, CEL * 3 + 2 * GAT)
	raster.BackgroundTransparency = 1
	raster.Parent = bord

	local rooster = Instance.new("UIGridLayout")
	rooster.CellSize = UDim2.fromOffset(CEL, CEL)
	rooster.CellPadding = UDim2.fromOffset(GAT, GAT)
	-- Drie per rij vastzetten: anders zou één pixel te weinig het derde vakje naar de
	-- volgende rij duwen en stond er een kolom van negen.
	rooster.FillDirectionMaxCells = 3
	rooster.SortOrder = Enum.SortOrder.LayoutOrder
	rooster.Parent = raster

	-- Krimpt het bord onder de 360, dan krimpen de vakjes mee -- zoals `width: 100%` dat in
	-- de browser doet.
	local celNu = CEL
	local function meet()
		local breed = math.min(RASTER_MAX, bord.AbsoluteSize.X)
		if breed <= 0 then return end
		local cel = math.max(24, math.floor((breed - 2 * GAT) / 3))
		if cel == celNu then return end
		celNu = cel
		rooster.CellSize = UDim2.fromOffset(cel, cel)
		raster.Size = UDim2.fromOffset(cel * 3 + 2 * GAT, cel * 3 + 2 * GAT)
	end
	bord:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	-- ---------- de stand van de ronde ----------
	local actief = false                       -- er ligt een lot dat nog open moet
	local getoond = false                      -- SC.shown: er is een lot, gekocht of afgerekend
	local inzet = 0
	local mult = 0
	local symbolen: { [number]: string } = {}  -- wat de server per vakje prijsgaf
	local winnaar: string? = nil               -- het symbool van de winnende drie, na afloop
	-- In de browser gebeurt een kras meteen; hier ligt er een vraag aan de server tussen.
	-- Zolang die onderweg is neemt het scherm niets aan, anders krast een tweede klik een
	-- tweede vakje open zonder dat het eerste geschilderd is.
	local bezig = false

	local vakjes: { TextButton } = {}
	local randen: { UIStroke } = {}
	local teken: () -> ()

	-- `.tile.pop`: 0.7 -> 1.12 -> 1 in een kwart seconde. Een cel van een UIGridLayout kan
	-- niet zelf groeien, dus krimpt het symbool en veert het terug; Back-Out geeft dezelfde
	-- doorschieter als het middenbeeld van de keyframes.
	local function pop(i: number)
		local b = vakjes[i]
		b.TextSize = math.floor(SYMBOOL * 0.7)
		TweenService:Create(
			b,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ TextSize = SYMBOOL }
		):Play()
	end

	local function kras(i: number)
		if bezig or not actief or symbolen[i] then return end
		bezig = true
		local res = Common.call("Act", "scratch", i)
		bezig = false
		if not res then return end
		symbolen[i] = res.symbol
		if not res.done then
			teken()
			pop(i)
			return
		end

		-- Pas nu mag de kaart verklappen of er gewonnen is. Welk symbool de drie gelijke
		-- waren rekent het scherm zelf uit de negen vakjes uit; de server stuurt alleen de
		-- multiplier mee, en zonder dat symbool weet het bord niet wat het moet oplichten.
		actief = false
		mult = res.mult
		winnaar = nil
		if res.payout > 0 then
			for _, p in Odds.SCRATCH_PRIZES do
				local n = 0
				for j = 1, Odds.SCRATCH_CELLS do
					if symbolen[j] == p.sym then n += 1 end
				end
				if n >= 3 then
					winnaar = p.sym
					break
				end
			end
		end
		teken()
		pop(i)

		-- Dezelfde twee meldingen als scSettle() in de webversie.
		if res.payout > inzet then
			Common.toast((winnaar or "") .. " THREE OF A KIND \u{00B7} +$" .. Money.fmt(res.payout), "green")
		else
			Common.toast("NO THREE OF A KIND", "red")
		end
	end

	for i = 1, Odds.SCRATCH_CELLS do
		local b = Instance.new("TextButton")
		b.Name = "Cell" .. i
		b.Text = "\u{00B7}"
		b.Font = Theme.font.ui
		b.TextSize = SYMBOOL
		b.TextColor3 = Theme.color.text
		-- `.tile` is een flexvak dat zijn inhoud in beide richtingen centreert.
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextYAlignment = Enum.TextYAlignment.Center
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Active = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.radius.panel)   -- .tile border-radius 4
		local rand = UI.stroke(b, Theme.color.border)
		b.MouseEnter:Connect(function()
			-- .tile.clickable:hover: alleen een neonrand; optillen kan niet, de roosterplek
			-- ligt vast.
			if b.Active then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			if b.Active then rand.Color = Theme.color.border end
		end)
		b.Activated:Connect(function()
			kras(i)
		end)
		b.Parent = raster
		vakjes[i] = b
		randen[i] = rand
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, de uitslagregel en de twee knoppen in één `.panel`.
	-- Common.betBox maakt dat paneel, dus de rest gaat erbij in; de LayoutOrder hieronder
	-- geldt alleen bínnen dat paneel, waar het inzetveld op nul staat en dus voorop blijft.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel
	-- Het veld heet hier PRICE PER CARD: je koopt een lot, je zet niet in op een uitkomst.
	for _, kind in paneel:GetDescendants() do
		if kind:IsA("TextLabel") and kind.Text == "STAKE" then
			kind.Text = "PRICE PER CARD"
		end
	end

	local statusNaam, statusWaarde = payoutRegel(paneel, "RESULT", 11)

	Common.buttonGap(paneel, 11)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local kopen = UI.primary(paneel, "BUY A CARD")
	kopen.LayoutOrder = 12
	kopen.Font = Theme.font.uiBold
	UI.gradient(kopen, Theme.color.neon, Theme.color.neonDim, 135)

	-- .btn-primary.btn-cashout: goud, en hij klopt één keer per seconde. Die klop is in de
	-- CSS een box-shadow; hier is het een gouden rand die op en neer gaat.
	local krasAlles = UI.primary(paneel, "SCRATCH THEM ALL")
	krasAlles.LayoutOrder = 13
	krasAlles.Font = Theme.font.uiBold
	krasAlles.BackgroundColor3 = Theme.color.gold
	krasAlles.TextColor3 = Theme.color.bg
	krasAlles.Visible = false
	UI.gradient(krasAlles, Theme.color.gold, GOUD_DONKER, 135)
	local klopRand = UI.stroke(krasAlles, Theme.color.gold, 2)
	klopRand.Transparency = 1
	local klop = TweenService:Create(
		klopRand,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.5 }   -- rgba(224,181,85,0.5) uit @keyframes pulse-gold
	)

	-- ► PRIZES: de zes winnende rijen, drie keer het symbool en wat het uitkeert.
	local prijzen = UI.panel(bediening, "Prizes")
	UI.list(prijzen, 0)
	UI.panelTitle(prijzen, "\u{25BA} prizes")
	local prijsLijst = UI.panelBody(prijzen, 6)   -- .sc-legend gap
	for i, p in Odds.SCRATCH_PRIZES do
		prijsRegel(prijsLijst, p.sym .. p.sym .. p.sym, Money.fmt(p.mult) .. "\u{00D7}", i)
	end

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "scratch")
	Common.oddsPanel(bediening, "odds", "Nine cells; three matching symbols pay. The card is fixed the moment you buy it, so scratching only reveals what was already drawn. RTP *97%*, chance of a prize *21.6%*.")

	-- ---------- tekenen ----------
	-- Eén plek die de negen vakjes, de uitslagregel en de twee knoppen op de stand zet,
	-- precies zoals scRender() dat in de webversie doet.
	function teken()
		local dicht = 0
		for i = 1, Odds.SCRATCH_CELLS do
			local b = vakjes[i]
			local rand = randen[i]
			local sym = symbolen[i]
			local gem = sym ~= nil and sym == winnaar

			b.Text = if sym then sym else (if getoond then "?" else "\u{00B7}")
			b.Active = actief and sym == nil
			if b.Active then dicht += 1 end

			if gem then
				-- .tile.sc-open.gem: pas oplichten als het lot af is, anders verraadt de
				-- eerste treffer al welk symbool het wordt.
				b.BackgroundColor3 = Theme.color.neon
				b.BackgroundTransparency = GEM_VUL
				b.TextColor3 = Theme.color.neon
				rand.Color = Theme.color.neon
			elseif sym then
				-- .tile.sc-open: het opengekraste vakje wordt lichter dan de rest.
				b.BackgroundColor3 = Theme.color.panelLight
				b.BackgroundTransparency = 0
				b.TextColor3 = Theme.color.text
				rand.Color = Theme.color.border
			else
				b.BackgroundColor3 = Theme.color.black
				b.BackgroundTransparency = Theme.alpha.buttonBg
				b.TextColor3 = Theme.color.text
				rand.Color = Theme.color.border
			end

			-- .tile.dim: zonder lot ligt het hele bord op de achtergrond.
			b.TextTransparency = if getoond then 0 else DOF
			rand.Transparency = if getoond then 0 else DOF
			if not getoond then
				b.BackgroundTransparency += (1 - b.BackgroundTransparency) * DOF
			end
		end

		statusNaam.Text = if actief then "TO GO" else "RESULT"
		if actief then
			statusWaarde.Text = dicht .. (if dicht == 1 then " cell" else " cells")
		elseif getoond then
			statusWaarde.Text = if mult > 0 then Money.fmt(mult) .. "\u{00D7}" else "no prize"
		else
			statusWaarde.Text = "\u{2014}"
		end

		kopen.Visible = not actief
		krasAlles.Visible = actief
		if actief then
			klop:Play()
		else
			klop:Pause()
			klopRand.Transparency = 1
		end
	end

	kopen.Activated:Connect(function()
		if bezig or actief then return end
		local bedrag = betBox.get()
		bezig = true
		local res = Common.call("Bet", "scratch", bedrag)
		bezig = false
		if not res then return end
		inzet = bedrag
		actief = true
		getoond = true
		mult = 0
		winnaar = nil
		table.clear(symbolen)
		teken()
	end)

	krasAlles.Activated:Connect(function()
		if not actief then return end
		for i = 1, Odds.SCRATCH_CELLS do
			if actief and not symbolen[i] then
				kras(i)
				task.wait(0.08)
			end
		end
	end)

	teken()
end

return Scratch
