--!strict
-- Dragon Tower: negen verdiepingen omhoog, per verdieping één tegel kiezen. De indeling
-- staat op de server; de client weet pas wat er onder een tegel zat als hij hem aanraakt.
--
-- Het beeld komt regel voor regel uit de webversie: `#towerView` in de markup en
-- `.tower`, `.tower-row`, `.tower-mult`, `.tower-tiles` en `.tile` in de CSS. De negen
-- rijen staan onder elkaar met de bovenste verdieping bovenaan, de multiplier staat links
-- in een kolom van 76 pixels, en daarnaast liggen de twee tot vier tegels van 44 hoog.
--
-- Wat Roblox niet heeft: letter-spacing (de 1px uit `.tower-mult` is weggelaten), de
-- box-shadow van een aangeklikte tegel (hier een gouden rand van 2) en het optillen van een
-- tegel bij hover (de lijstindeling bepaalt de positie, dus daar blijft de neonrand over).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Tower = {}

-- De volgorde van de knoppenbalk in de markup: EASY / MED / HARD / EXP / MSTR.
local MOEILIJK = { "easy", "medium", "hard", "expert", "master" }
local KORT = {
	easy = "EASY", medium = "MED", hard = "HARD", expert = "EXP", master = "MSTR",
}

-- ---------- maten uit de CSS ----------
local TOREN_B = 540        -- .tower max-width
local RIJ_GAT = 6          -- .tower gap
local MULT_KOL = 76        -- .tower-row grid-template-columns: 76px 1fr
local KOL_GAT = 10         -- .tower-row gap
local TEGEL_H = 44         -- .tile height
local TEGEL_GAT = 6        -- .tower-tiles gap
local TOREN_H = Odds.TOWER_LEVELS * TEGEL_H + (Odds.TOWER_LEVELS - 1) * RIJ_GAT

-- .tower-row opacity: 0.4 gewoon, 0.85 als de verdieping gehaald is, 1 als hij aan de
-- beurt is. Een CanvasGroup kan dat als geheel, net zoals de browser dat met opacity doet.
local RIJ_DOF = 0.6
local RIJ_KLAAR = 0.15
local RIJ_AAN = 0

-- .tile: background rgba(0,0,0,0.5); .tile.gem rgba(62,207,142,0.16); .tile.egg
-- rgba(224,97,110,0.16). En .tile.dim is opacity 0.45.
local VULLING = 0.84
local DOF = 0.55

local STREEP = Color3.fromHex("1a3a1a")   -- .payout-line border-bottom
local GOUD_DONKER = Color3.fromHex("cc9900")  -- .btn-cashout, het eind van het verloop

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .field-label: de naam links, de hint in neon rechts. Geeft de hint terug, want die
-- verandert mee met de moeilijkheid ("2 of 3 safe").
local function veldKop(ouder: Instance, naam: string, hint: string): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted })
	local h = UI.label(rij, hint, {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
		name = "Hint",
	})
	h.TextTransparency = 0.3    -- .field-label .hint opacity 0.7
	return h
end

-- .payout-line: naam links, waarde rechts in het cijferlettertype, haarlijntje eronder.
local function payoutRegel(ouder: Instance, naam: string, kleur: Color3, orde: number): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, Theme.size.payoutRow)
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
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

function Tower.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "TOWER")

	-- ---------- het bord ----------
	-- `.tower`: een kolom van negen rijen, volle breedte tot 540 pixels.
	local toren = Instance.new("Frame")
	toren.Name = "Tower"
	toren.Size = UDim2.new(1, 0, 0, TOREN_H)
	toren.BackgroundTransparency = 1
	toren.Parent = bord
	UI.list(toren, RIJ_GAT)
	local breedte = Instance.new("UISizeConstraint")
	breedte.MaxSize = Vector2.new(TOREN_B, math.huge)
	breedte.Parent = toren

	-- ---------- de stand van de ronde ----------
	-- `class="on"` staat in de markup op MED, en TW.diff begint in de webversie ook op
	-- 'medium'. Dat bepaalt meteen het bord: drie tegels per verdieping, niet vier.
	local diff = "medium"
	local actief = false
	local niveau = 0                                -- hoeveel verdiepingen gehaald zijn
	local inzet = 0                                 -- wat er in deze ronde op staat
	local over = false                              -- ronde afgelopen, het bord ligt open
	-- In de browser gebeurt een zet meteen; hier ligt er een vraag aan de server tussen. Een
	-- tweede klik binnen die wachttijd zou een tweede inzet doen of op de volgende
	-- verdieping landen, dus zolang er een antwoord onderweg is neemt het scherm niets aan.
	local bezig = false
	local keuzes: { [number]: number } = {}         -- per verdieping de aangeklikte tegel
	local rijen: { [number]: { boolean } } = {}     -- wat de server van een rij prijsgaf

	local teken: () -> ()

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, de moeilijkheid, de twee uitbetaalregels en de
	-- knoppen in één `.panel`. Common.betBox maakt dat paneel, dus de rest gaat erbij in.
	-- De volgorde in de aside komt uit de volgorde van toevoegen; de LayoutOrder hieronder
	-- geldt alleen bínnen dit paneel, waar het inzetveld op nul staat en dus voorop blijft.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel

	-- .field-group met de knoppenbalk. De 8 boven is de margin-bottom van het
	-- inzetveld erboven, de 8 onder die van deze groep zelf (14 min de 6 uit de lijst).
	local diffVeld = Instance.new("Frame")
	diffVeld.Name = "DifficultyField"
	diffVeld.Size = UDim2.new(1, 0, 0, 0)
	diffVeld.AutomaticSize = Enum.AutomaticSize.Y
	diffVeld.BackgroundTransparency = 1
	diffVeld.LayoutOrder = 10
	diffVeld.Parent = paneel
	UI.list(diffVeld, 6)
	UI.padding4(diffVeld, 8, 0, 8, 0)

	local hint = veldKop(diffVeld, "DIFFICULTY", Odds.TOWER_DIFF[diff].label)

	-- .seg: vijf gelijke knoppen met 4 pixels ertussen, de gekozene in neon.
	local seg = Instance.new("Frame")
	seg.Name = "Seg"
	-- `.seg button { padding: 8px 0 }` om een regel van 11 (regelvak 14) plus twee randen is
	-- 32; de rand ligt buiten het vak, dus het vak is er twee kleiner.
	seg.Size = UDim2.new(1, 0, 0, 32 - 2)   -- 11px tekst met padding 8 boven en onder
	seg.BackgroundTransparency = 1
	seg.Parent = diffVeld
	UI.list(seg, 4, Enum.FillDirection.Horizontal)

	local segKnoppen: { [string]: TextButton } = {}
	local segRanden: { [string]: UIStroke } = {}

	local function markeerSeg()
		for naam, b in segKnoppen do
			local aan = naam == diff
			local rand = segRanden[naam]
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			b.Font = if aan then Theme.font.uiBold else Theme.font.ui
			rand.Color = if aan then Theme.color.neon else Theme.color.border
			-- .seg button:disabled { opacity: 0.4 } zolang er een ronde loopt.
			local vol = if aan then 0 else Theme.alpha.buttonBg
			b.Active = not actief
			b.BackgroundTransparency = if actief then math.min(1, vol + 0.4) else vol
			b.TextTransparency = if actief then 0.6 else 0
			rand.Transparency = if actief then 0.6 else 0
		end
		hint.Text = Odds.TOWER_DIFF[diff].label
	end

	for i, naam in MOEILIJK do
		local b = Instance.new("TextButton")
		b.Name = "Seg" .. naam
		b.Text = KORT[naam]
		b.Font = Theme.font.ui
		b.TextSize = Theme.text.tiny
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.new(0.2, -3.2, 1, 0)   -- vijf kolommen met vier keer 4 pixels lucht
		b.RichText = false
		-- Roblox centreert knoptekst zelf al; expliciet gezet zodat de schermafdruk uit
		-- tools/preview hetzelfde laat zien als het spel.
		b.TextXAlignment = Enum.TextXAlignment.Center
		UI.corner(b, Theme.radius.chip)
		local rand = UI.stroke(b, Theme.color.border)
		b.MouseEnter:Connect(function()
			if diff ~= naam and not actief then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if diff == naam then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			if actief then return end
			diff = naam
			-- Een andere moeilijkheid is een andere toren: andere breedte, andere quotes.
			-- Het afgelopen bord laten staan zou een rij van vier tegels naast een knop van
			-- drie zetten en een uitbetaling tonen die bij de vorige toren hoorde. De
			-- webversie gooit hem daarom leeg (`TW.rows = []; TW.picks = []; TW.level = 0`).
			niveau = 0
			over = false
			table.clear(keuzes)
			table.clear(rijen)
			teken()
		end)
		b.Parent = seg
		segKnoppen[naam] = b
		segRanden[naam] = rand
	end

	-- De twee `.payout-line`s raken elkaar in de CSS: geen marge, alleen het haarlijntje
	-- ertussen. Het paneel zet zelf 6 pixels tussen zijn kinderen, dus ze gaan samen in een
	-- eigen blok met ruimte nul. De 2 eronder maakt van die 6 de 8 van `.btn-primary`.
	local uitbetaling = Instance.new("Frame")
	uitbetaling.Name = "Payout"
	uitbetaling.Size = UDim2.new(1, 0, 0, 0)
	uitbetaling.AutomaticSize = Enum.AutomaticSize.Y
	uitbetaling.BackgroundTransparency = 1
	uitbetaling.LayoutOrder = 11
	uitbetaling.Parent = paneel
	UI.list(uitbetaling, 0)
	UI.padding4(uitbetaling, 0, 0, 2, 0)

	local huidigLabel = payoutRegel(uitbetaling, "CURRENT WIN", Theme.color.neon, 1)
	local volgendLabel = payoutRegel(uitbetaling, "NEXT FLOOR", Theme.color.gold, 2)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local startKnop = UI.primary(paneel, "START THE CLIMB")
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

	-- ---------- de tegels ----------
	local tegels: { { TextButton } } = {}
	local multLabels: { TextLabel } = {}
	local rijGroepen: { CanvasGroup } = {}

	local function kies(r: number, k: number)
		if bezig or not actief or r ~= niveau + 1 then return end
		bezig = true
		local res = Common.call("Act", "tower", k)
		bezig = false
		if not res then return end
		keuzes[r] = k

		if not res.safe then
			rijen[r] = res.row
			actief = false
			over = true
			teken()
			Common.toast("DRAGON EGG! -$" .. Money.fmt(inzet), "red")
			return
		end

		if res.done then
			-- De negende verdieping rekent de server meteen af, net als twPick() in de
			-- webversie, die daar zelf twCashOut() aanroept.
			rijen[r] = res.row
			niveau = Odds.TOWER_LEVELS
			actief = false
			over = true
			teken()
			Common.toast("+$" .. Money.fmt(res.payout) .. " @ " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			return
		end

		niveau = res.level
		teken()
	end

	-- Eén tegel in de vorm die bij zijn toestand hoort. De webversie kent de hele indeling
	-- en legt aan het eind alles open; hier houdt de server de rijen achter, dus een
	-- verdieping gaat alleen open als de server hem meestuurt -- bij een ei, en bovenaan.
	local function kleedTegel(b: TextButton, rand: UIStroke, r: number, k: number)
		local gekozen = keuzes[r] == k
		local rij = rijen[r]
		local veilig: boolean? = nil
		if rij then
			veilig = rij[k]
		elseif r <= niveau and gekozen then
			veilig = true   -- deze tegel hebben we zelf aangeraakt en die hield stand
		end

		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.TextColor3 = Theme.color.text
		b.TextTransparency = 0
		rand.Color = Theme.color.border
		rand.Thickness = 1
		rand.Transparency = 0
		b.Active = false

		if veilig ~= nil then
			local kleur = if veilig then Theme.color.neon else Theme.color.red
			b.Text = if veilig then "\u{25C6}" else "\u{1F95A}"   -- ◆ en het drakenei
			b.TextColor3 = kleur
			b.BackgroundColor3 = kleur
			b.BackgroundTransparency = VULLING
			rand.Color = kleur
			if gekozen then
				-- .tile.picked: box-shadow 0 0 0 2px var(--gold), hier een dikke gouden rand.
				rand.Color = Theme.color.gold
				rand.Thickness = 2
			else
				-- .tile.dim: alles wat je niet zelf aanwees blijft op de achtergrond.
				b.TextTransparency = DOF
				rand.Transparency = DOF
				b.BackgroundTransparency = VULLING + (1 - VULLING) * DOF
			end
		elseif actief and r == niveau + 1 then
			b.Text = "?"
			b.Active = true
		else
			b.Text = "\u{00B7}"
			if r <= niveau then
				b.TextTransparency = DOF
				rand.Transparency = DOF
			end
		end
	end

	-- De toren opnieuw opbouwen. Dat gebeurt alleen als het aantal tegels verandert; bij
	-- een zet blijven de knoppen staan en krijgen ze alleen een andere jas.
	local function bouwRijen()
		for _, kind in toren:GetChildren() do
			if kind:IsA("CanvasGroup") then kind:Destroy() end
		end
		table.clear(tegels)
		table.clear(multLabels)
		table.clear(rijGroepen)

		local d = Odds.TOWER_DIFF[diff]
		for r = Odds.TOWER_LEVELS, 1, -1 do
			-- De bovenste verdieping bovenaan, dus van negen naar één.
			local groep = Instance.new("CanvasGroup")
			groep.Name = "Row" .. r
			groep.Size = UDim2.new(1, 0, 0, TEGEL_H)
			groep.BackgroundTransparency = 1
			groep.BorderSizePixel = 0
			groep.LayoutOrder = Odds.TOWER_LEVELS - r
			groep.Parent = toren

			local mult = UI.label(groep, Money.fmt(Odds.towerMultiplier(diff, r)) .. "\u{00D7}", {
				size = Theme.text.tiny, color = Theme.color.gold,
				align = Enum.TextXAlignment.Right, name = "Mult",
			})
			mult.Size = UDim2.new(0, MULT_KOL, 1, 0)

			local vak = Instance.new("Frame")
			vak.Name = "Tiles"
			vak.Position = UDim2.fromOffset(MULT_KOL + KOL_GAT, 0)
			vak.Size = UDim2.new(1, -(MULT_KOL + KOL_GAT), 1, 0)
			vak.BackgroundTransparency = 1
			vak.Parent = groep
			UI.list(vak, TEGEL_GAT, Enum.FillDirection.Horizontal)

			local kolom: { TextButton } = {}
			for k = 1, d.tiles do
				local b = Instance.new("TextButton")
				b.Name = "T" .. r .. "_" .. k
				b.Text = "\u{00B7}"
				b.Font = Theme.font.ui
				b.TextSize = 18                  -- .tile font-size
				b.TextColor3 = Theme.color.text
				b.BackgroundColor3 = Theme.color.black
				b.BackgroundTransparency = Theme.alpha.buttonBg
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				b.Active = false
				b.LayoutOrder = k
				b.RichText = false
				b.TextXAlignment = Enum.TextXAlignment.Center
				b.Size = UDim2.new(1 / d.tiles, -TEGEL_GAT * (d.tiles - 1) / d.tiles, 1, 0)
				UI.corner(b, Theme.radius.panel)   -- .tile border-radius 4
				local rand = UI.stroke(b, Theme.color.border)
				b.MouseEnter:Connect(function()
					if b.Active then rand.Color = Theme.color.neon end
				end)
				b.MouseLeave:Connect(function()
					if b.Active then rand.Color = Theme.color.border end
				end)
				b.Activated:Connect(function()
					kies(r, k)
				end)
				b.Parent = vak
				kolom[k] = b
			end
			tegels[r] = kolom
			multLabels[r] = mult
			rijGroepen[r] = groep
		end
	end

	-- Alles bijwerken wat van de stand afhangt: de rijen, de bediening en de twee regels.
	function teken()
		local d = Odds.TOWER_DIFF[diff]
		if #tegels ~= Odds.TOWER_LEVELS or #(tegels[1] :: { TextButton }) ~= d.tiles then
			bouwRijen()
		end

		for r = 1, Odds.TOWER_LEVELS do
			local groep = rijGroepen[r]
			local gehaald = r <= niveau
			-- twRender() zet `.tower-row.active` op de verdieping die aan de beurt is, en
			-- vóór de eerste inzet op álle verdiepingen. Dat is één klasse, dus het geldt
			-- ook voor de multiplier ernaast: niet alleen de rij is dan vol in beeld, de
			-- hele kolom staat in neon in plaats van goud.
			local rijAan = if actief then r == niveau + 1 else not over
			groep.GroupTransparency = if rijAan then RIJ_AAN
				elseif gehaald then RIJ_KLAAR
				else RIJ_DOF

			local mult = multLabels[r]
			mult.Text = Money.fmt(Odds.towerMultiplier(diff, r)) .. "\u{00D7}"
			-- .tower-row.active .tower-mult: het cijferlettertype, en neon in plaats van goud.
			mult.Font = if rijAan then Theme.font.num else Theme.font.ui
			mult.TextColor3 = if rijAan then Theme.color.neon else Theme.color.gold

			for k, b in tegels[r] do
				local rand = b:FindFirstChildOfClass("UIStroke")
				if rand then kleedTegel(b, rand, r, k) end
			end
		end

		markeerSeg()
		betBox.lock(actief)
		startKnop.Visible = not actief
		uitKnop.Visible = actief

		if actief then
			local mult = Odds.towerMultiplier(diff, niveau)
			local nu = Money.floor2(inzet * mult)
			huidigLabel.Text = if niveau > 0
				then "$" .. Money.fmt(nu) .. " (" .. Money.fmt(mult) .. "\u{00D7})"
				else "\u{2014}"
			volgendLabel.Text = Money.fmt(Odds.towerMultiplier(diff, niveau + 1)) .. "\u{00D7}"
			uitKnop.Text = if niveau > 0 then "CASH OUT $" .. Money.fmt(nu) else "PICK A TILE"
			-- Uitstappen kan pas als er een verdieping staat; tot dan is de knop dood.
			UI.setEnabled(uitKnop, niveau > 0)
			uitKnop.BackgroundTransparency = if niveau > 0 then 0 else 0.4
			-- @keyframes pulse-gold hangt aan .btn-cashout zelf, niet aan :enabled: in de
			-- webversie klopt de knop dus ook terwijl hij nog "PICK A TILE" zegt.
			klop:Play()
		else
			huidigLabel.Text = "\u{2014}"
			volgendLabel.Text = Money.fmt(Odds.towerMultiplier(diff, 1)) .. "\u{00D7}"
			klop:Pause()
			klopRand.Transparency = 1
		end
	end

	startKnop.Activated:Connect(function()
		if bezig or actief then return end
		local bedrag = betBox.get()
		bezig = true
		local res = Common.call("Bet", "tower", bedrag, diff)
		bezig = false
		if not res then return end
		inzet = bedrag
		actief = true
		over = false
		niveau = 0
		table.clear(keuzes)
		table.clear(rijen)
		teken()
	end)

	uitKnop.Activated:Connect(function()
		if bezig or not actief or niveau < 1 then return end
		bezig = true
		local res = Common.call("CashOut", "tower")
		bezig = false
		if not res then return end
		actief = false
		over = true
		teken()
		Common.toast("+$" .. Money.fmt(res.payout) .. " @ " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
	end)

	-- De eerste teken() bouwt de rijen meteen op; daarna gebeurt dat alleen nog als de
	-- moeilijkheid een ander aantal tegels per verdieping vraagt.
	teken()

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "tower")
	Common.oddsPanel(bediening, "odds", "Every floor has fixed odds. Multiplier = *0.97 x (tiles / safe)^floor*, so RTP *97%* at every point you cash out. The whole tower is fixed before your first click.")
end

return Tower
