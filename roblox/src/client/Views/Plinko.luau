--!strict
-- Plinko: een driehoek van pinnen die het hele bord vult, en onderlangs de rij bakjes met
-- hun multiplier erin -- roze aan de buitenkant, via oranje en goud naar groen in het
-- midden. Het balletje valt langs het pad dat de server heeft getrokken.
--
-- Het beeld komt regel voor regel uit de webversie: `#plinkoView` in de markup, `.board`,
-- `.plinko-wrap`, `.seg`, `.payout-line` en `.pk-chip` in de CSS, en pkGeometry()/pkDraw()
-- in het script. Die laatste twee tekenen op een canvas; hier is elke pin, elk bakje en het
-- balletje een Frame, uitgerekend met dezelfde pixelformules.
--
-- Wat Roblox niet heeft: letter-spacing (de 1px uit `.seg button` is weggelaten), de
-- box-shadow onder het balletje (hier een tweede, grotere en doorzichtige neonstip
-- eromheen), flex-wrap op de uitslagbalk (de webversie bewaart er tien, en tien passen er
-- naast elkaar) en een vette variant van het cijferlettertype (`.pk-chip` is 700).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Plinko = {}

-- De twee knoppenbalken uit de markup: 8 / 12 / 16 en LOW / MID / HIGH. Het opschrift van
-- het middelste risico is "MID", de waarde die naar de server gaat blijft "medium".
local RIJEN = { 8, 12, 16 }
local RISICO = {
	{ key = "low", label = "LOW" },
	{ key = "medium", label = "MID" },
	{ key = "high", label = "HIGH" },
}

-- ---------- maten uit de CSS en uit pkGeometry() ----------
local WRAP_MIN = 340        -- .plinko-wrap min-height
local STRIP_H = 26          -- .result-strip min-height
local STRIP_GAT = 6         -- .result-strip gap
local TOP_Y = 24            -- g.topY
local ONDER = 70            -- (h - 70): de ruimte die de bakjes onderaan overhouden
local BAK_GAT = 6           -- g.bucketY = topY + rows * spacingY + 6
local BAK_H = 30            -- g.bucketH
local BAK_R = 4             -- roundRect(..., 4)
local RIJ_S = 0.14          -- PK_ROW_MS: hoe lang het balletje over één rij doet
local VAL_S = 0.22          -- de val van de laatste pin in het bakje
local FLITS_S = 0.5         -- zo lang licht het geraakte bakje op (now - lastHit < 500)
local MAX_UITSLAGEN = 10    -- PK.results wordt afgekapt op tien

-- rgba(216,255,216,0.85): een bleekgroene pin.
local PIN = Color3.fromRGB(216, 255, 216)
local PIN_DOORZICHT = 0.15
-- De twee kleuren uit pkColor() die niet in de :root staan; de andere twee zijn --red
-- en --gold.
local ORANJE = Color3.fromHex("ff8c3a")
local BAK_GROEN = Color3.fromHex("3fa96a")
local BAK_DOORZICHT = 0.2   -- globalAlpha 0.8 voor een bakje dat niet net geraakt is

local STREEP = Color3.fromHex("1a3a1a")   -- .payout-line border-bottom

-- Een bord waar nog niemand naar gekeken heeft. AbsoluteSize is pas een frame later bekend,
-- dus zonder deze maat staat het bord bij het openen van het scherm nog even leeg.
local NOMINAAL = Vector2.new(900, 520)

type Meetkunde = {
	w: number, h: number,
	cx: number, topY: number, sx: number, sy: number, bakY: number, bakH: number,
}

-- pkGeometry(): de pinafstand is de kleinste van "breed genoeg" en "hoog genoeg", zodat de
-- driehoek altijd binnen het vak past.
local function meetkunde(w: number, h: number, rijen: number): Meetkunde
	local sx = math.min(w / (rijen + 3), (h - ONDER) / rijen * 1.1)
	local sy = (h - ONDER) / rijen
	return {
		w = w, h = h, cx = w / 2, topY = TOP_Y, sx = sx, sy = sy,
		bakY = TOP_Y + rijen * sy + BAK_GAT, bakH = BAK_H,
	}
end

-- De plek van een pin, een bakje of het balletje. Het rekenwerk gaat in pixels, precies als
-- op het canvas, maar de uitkomst wordt als verhouding neergezet: dan blijft het bord
-- kloppen zolang de gemeten maat nog niet binnen is, in plaats van in de hoek te kruipen.
local function plek(m: Meetkunde, x: number, y: number, yBij: number?): UDim2
	return UDim2.new(x / m.w, 0, y / m.h, yBij or 0)
end

-- Hoe groot iets op het bord is, in datzelfde stelsel. Een maat in kale pixels naast een
-- plek in verhoudingen loopt uit elkaar zodra de gemeten maat niet die van het vak is: de
-- bakjes komen dan dichter bij elkaar te staan dan ze breed zijn en schuiven over elkaar
-- heen. Plek en maat allebei als verhouding houdt het bord in vorm, hoe groot het vak ook is.
local function formaat(m: Meetkunde, breed: number, hoog: number): UDim2
	return UDim2.fromScale(breed / m.w, hoog / m.h)
end

-- pkColor(): warm aan de randen, koel in het midden. De grens hangt aan de hoogste
-- multiplier van de tabel, dus hij verschuift mee met het risico.
local function bakKleur(mult: number, tabel: { number }): Color3
	local hoogste = 0
	for _, m in tabel do
		if m > hoogste then hoogste = m end
	end
	if mult >= hoogste * 0.5 then return Theme.color.red end
	if mult >= 3 then return ORANJE end
	if mult >= 1 then return Theme.color.gold end
	return BAK_GROEN
end

-- Hoe breed wordt dit opschrift. Het canvas heeft measureText() en meet de echte letters;
-- hier is het een schatting. Opmeten kan met TextService, maar dat is een aanroep per bakje
-- bij elke hertekening, en een bakje bevat nooit meer dan een getal. In een vette
-- schreefloze letter is een cijfer ongeveer 0,56 keer de tekstgrootte breed, een punt 0,30
-- en de x 0,52. Aan de ruime kant schatten mag: dan kiest een bakje liever een korter
-- opschrift dan eentje dat uitsteekt.
local function tekstBreedte(txt: string, px: number): number
	local som = 0
	for i = 1, #txt do
		local c = string.sub(txt, i, i)
		som += if c == "." then 0.30 elseif c == "x" then 0.52 else 0.56
	end
	return som * px
end

-- Het opschrift van een bakje: van uitgebreid naar zo kort als het nog netjes leest, en
-- pas daarna kleiner. Precies de volgorde uit pkDraw().
local function bakOpschrift(m: number, ruimte: number, basis: number): (string, number)
	local opties = {
		Money.fmt(m) .. "x",
		Money.fmt(m),
		if m >= 10 then string.format("%d", math.round(m)) else string.format("%g", math.round(m * 10) / 10),
	}
	local label = opties[#opties]
	for _, optie in opties do
		if tekstBreedte(optie, basis) <= ruimte then
			label = optie
			break
		end
	end
	local px = basis
	while px > 5 and tekstBreedte(label, px) > ruimte do
		px -= 0.5
	end
	return label, px
end

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .field-label: alleen een naam, want ROWS en RISK hebben geen hint.
local function veldKop(ouder: Instance, naam: string): TextLabel
	local t = UI.label(ouder, naam, { size = Theme.text.small, color = Theme.color.muted })
	t.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	return t
end

-- .payout-line: naam links, waarde rechts in het cijferlettertype, haarlijntje eronder.
local function payoutRegel(ouder: Instance, naam: string, orde: number): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, Theme.size.payoutRow)
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
	rij.Parent = ouder

	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.text, name = "Key" })
	local v = UI.label(rij, "\u{2014}", {
		size = Theme.text.small, color = Theme.color.gold, font = Theme.font.num,
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

-- .seg: gelijke knoppen met 4 pixels ertussen, de gekozene in neon. Geeft de knoppen terug
-- plus de randen, want beide veranderen mee met de keuze.
local function segRij(ouder: Instance, aantal: number, orde: number): (Frame, (string, string) -> (TextButton, UIStroke))
	local seg = Instance.new("Frame")
	seg.Name = "Seg"
	-- `.seg button { padding: 8px 0 }` om een regel van 11 (regelvak 14) plus twee randen is
	-- 32; de rand ligt buiten het vak, dus het vak is er twee kleiner.
	seg.Size = UDim2.new(1, 0, 0, 32 - 2)   -- 11px tekst met padding 8 boven en onder
	seg.BackgroundTransparency = 1
	seg.LayoutOrder = orde
	seg.Parent = ouder
	UI.list(seg, 4, Enum.FillDirection.Horizontal)

	local gat = 4 * (aantal - 1) / aantal
	local function knop(naam: string, tekst: string): (TextButton, UIStroke)
		local b = Instance.new("TextButton")
		b.Name = naam
		b.Text = tekst
		b.Font = Theme.font.ui
		b.TextSize = Theme.text.tiny
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.RichText = false
		-- Roblox centreert knoptekst zelf al; expliciet gezet zodat de schermafdruk uit
		-- tools/preview hetzelfde laat zien als het spel.
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.Size = UDim2.new(1 / aantal, -gat, 1, 0)
		UI.corner(b, Theme.radius.chip)
		local rand = UI.stroke(b, Theme.color.border)
		b.Parent = seg
		return b, rand
	end
	return seg, knop
end

function Plinko.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "PLINKO")

	-- `.panel.board` staat bij dit scherm in de markup op `padding: 14px`, smaller dan de
	-- 22 die `.board` aanhoudt. Net als bij de paardenrace: aan alle kanten acht pixels
	-- minder rand, dus acht pixels meer bord.
	local pad = Theme.size.boardPadSm
	bord.Position = UDim2.fromOffset(pad, pad)
	bord.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)

	-- ---------- het bord ----------
	-- `.plinko-wrap` vult wat het bord overhoudt, met de uitslagbalk eronder: hoogte min de
	-- balk en de tussenruimte. De min-height van 340 staat er ook in de CSS.
	local vak = Instance.new("Frame")
	vak.Name = "PlinkoWrap"
	vak.Size = UDim2.new(1, 0, 1, -(STRIP_H + Theme.size.boardGap))
	vak.BackgroundTransparency = 1
	vak.Parent = bord
	local minHoogte = Instance.new("UISizeConstraint")
	minHoogte.MinSize = Vector2.new(0, WRAP_MIN)
	minHoogte.Parent = vak

	-- .result-strip: de laatste tien multipliers, de nieuwste vooraan.
	local strip = Instance.new("Frame")
	strip.Name = "Results"
	strip.Size = UDim2.new(1, 0, 0, STRIP_H)
	strip.BackgroundTransparency = 1
	strip.Parent = bord
	local striplijst = UI.list(strip, STRIP_GAT, Enum.FillDirection.Horizontal)
	striplijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	striplijst.VerticalAlignment = Enum.VerticalAlignment.Center

	-- ---------- de stand van het scherm ----------
	local rijen = 12
	local risico = "medium"
	-- Zolang de server nog antwoordt of het balletje nog valt neemt het scherm geen tweede
	-- worp aan; in de webversie vallen er meerdere tegelijk, maar daar is de uitslag er
	-- meteen en hier hangt hij aan een aanroep.
	local bezig = false
	local pinnen: { Frame } = {}
	local bakken: { Frame } = {}
	local uitslagen: { { mult: number, kleur: Color3 } } = {}
	local g: Meetkunde? = nil
	-- Waarmee het bord dat er nu staat getekend is. AbsoluteSize komt tijdens het slepen van
	-- een venster tientallen keren per seconde langs; tweehonderd Frames opnieuw maken voor
	-- dezelfde maat is zonde.
	local getekend: Vector2? = nil

	-- Het bord opnieuw neerzetten: bij een ander aantal rijen, een ander risico, en als het
	-- vak van maat verandert -- in de webversie doet de resize-handler precies dat.
	local function tekenBord(altijd: boolean?)
		-- Zolang het vak nog niet gemeten is, of zo laag staat dat er geen pinafstand
		-- overblijft, rekent het bord met het nominale formaat; de verhoudingen uit plek()
		-- zetten hem dan alsnog over de volle breedte neer.
		local gemeten = vak.AbsoluteSize
		local maat = if gemeten.X > 0 and (gemeten.Y - ONDER) > rijen then gemeten else NOMINAAL
		if not altijd and maat == getekend then return end
		getekend = maat

		for _, p in pinnen do p:Destroy() end
		table.clear(pinnen)
		for _, b in bakken do b:Destroy() end
		table.clear(bakken)

		local m = meetkunde(maat.X, maat.Y, rijen)
		g = m

		-- De pinnen: rij i heeft i+3 pinnen, gecentreerd om het midden.
		local straal = math.max(2, m.sx * 0.09)
		for i = 0, rijen - 1 do
			local y = m.topY + (i + 0.5) * m.sy
			for j = 0, i + 2 do
				local p = Instance.new("Frame")
				p.Name = "Peg"
				p.AnchorPoint = Vector2.new(0.5, 0.5)
				p.Position = plek(m, m.cx + (j - (i + 2) / 2) * m.sx, y)
				p.Size = formaat(m, straal * 2, straal * 2)
				p.BackgroundColor3 = PIN
				p.BackgroundTransparency = PIN_DOORZICHT
				p.BorderSizePixel = 0
				-- Roblox knipt een te grote CornerRadius bij tot de halve zijde, dus deze
				-- straal in pixels houdt de pin rond ook als het vak kleiner uitvalt.
				UI.corner(p, straal)
				p.Parent = vak
				table.insert(pinnen, p)
			end
		end

		-- De bakjes: één meer dan er rijen zijn, 90% van de pinafstand breed.
		local tabel = Odds.plinkoTable(rijen, risico)
		local bw = m.sx * 0.9
		local basis = math.max(7, math.min(11, m.sx * 0.32))
		for b = 0, rijen do
			local mult = tabel[b + 1]
			local f = Instance.new("Frame")
			f.Name = "Bucket" .. b
			f.AnchorPoint = Vector2.new(0.5, 0)
			f.Position = plek(m, m.cx + (b - rijen / 2) * m.sx, m.bakY)
			f.Size = formaat(m, bw, m.bakH)
			f.BackgroundColor3 = bakKleur(mult, tabel)
			f.BackgroundTransparency = BAK_DOORZICHT
			f.BorderSizePixel = 0
			UI.corner(f, BAK_R)
			f.Parent = vak

			local tekst, px = bakOpschrift(mult, bw - 2, basis)
			local l = UI.label(f, tekst, {
				size = px, color = Theme.color.black, font = Theme.font.uiBold,
				align = Enum.TextXAlignment.Center,
			})
			l.Size = UDim2.fromScale(1, 1)
			l.TextYAlignment = Enum.TextYAlignment.Center
			table.insert(bakken, f)
		end
	end

	-- De uitslagbalk opnieuw vullen: `.pk-chip` heeft de kleur van het bakje, als tekst en
	-- als rand, op een zwarte ondergrond.
	local function tekenStrip()
		for _, k in strip:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		for i, r in uitslagen do
			local c = Instance.new("TextLabel")
			c.Name = "Chip" .. i
			c.LayoutOrder = i
			c.Text = Money.fmt(r.mult) .. "\u{00D7}"
			c.Font = Theme.font.num
			c.TextSize = Theme.text.tiny
			c.TextColor3 = r.kleur
			c.BackgroundColor3 = Theme.color.black
			c.BackgroundTransparency = 0.6   -- rgba(0,0,0,0.4)
			c.BorderSizePixel = 0
			c.RichText = false
			c.AutomaticSize = Enum.AutomaticSize.X
			c.Size = UDim2.fromOffset(0, STRIP_H)
			UI.corner(c, 10)
			UI.stroke(c, r.kleur)
			UI.padding4(c, 4, 9, 4, 9)
			c.Parent = strip
		end
	end

	-- Het balletje langs het pad laten vallen dat de server heeft getrokken. De baan is
	-- dezelfde formule als in pkDraw(): per rij een halve pinafstand opzij, en na de pin een
	-- boogje omhoog voordat hij de volgende raakt.
	local function laatVallen(pad: { number }, bak: number)
		local m = g
		if not m then return end

		local straal = math.max(4, m.sx * 0.22)

		-- shadowBlur 10 in de kleur van het balletje: hier een grotere, doorzichtige stip
		-- eromheen, want Roblox kent geen schaduw op een Frame. Het balletje zelf is het
		-- kind, want een kind tekent altijd boven zijn ouder -- andersom zou de waas
		-- eroverheen liggen in plaats van erachter.
		local gloed = Instance.new("Frame")
		gloed.Name = "Ball"
		gloed.AnchorPoint = Vector2.new(0.5, 0.5)
		gloed.Size = formaat(m, (straal + 5) * 2, (straal + 5) * 2)
		gloed.BackgroundColor3 = Theme.color.neon
		gloed.BackgroundTransparency = Theme.glow.transparency
		gloed.BorderSizePixel = 0
		gloed.ZIndex = 4
		UI.corner(gloed, straal + 5)
		gloed.Parent = vak

		local bal = Instance.new("Frame")
		bal.Name = "Core"
		bal.AnchorPoint = Vector2.new(0.5, 0.5)
		bal.Position = UDim2.fromScale(0.5, 0.5)
		bal.Size = UDim2.fromScale(straal / (straal + 5), straal / (straal + 5))
		bal.BackgroundColor3 = Theme.color.neon
		bal.BorderSizePixel = 0
		UI.corner(bal, straal)
		bal.Parent = gloed

		local n = #pad
		local totaal = n * RIJ_S + VAL_S
		local t0 = os.clock()
		while true do
			local nu = os.clock() - t0
			local rowF = math.min(n, nu / RIJ_S)
			local i = math.floor(rowF)
			local frac = rowF - i
			local x = m.cx
			for k = 1, math.min(i, n) do
				x += (if pad[k] == 1 then 0.5 else -0.5) * m.sx
			end
			local y: number
			if i < n then
				local richting = if pad[i + 1] == 1 then 0.5 else -0.5
				-- Voorbij de pin (frac > 0.5) schuift hij naar de volgende stand, met een wipje.
				local p = math.max(0, (frac - 0.5) / 0.5)
				x += richting * m.sx * p
				y = m.topY + rowF * m.sy - math.sin(p * math.pi) * m.sy * 0.25
			else
				local p = math.min(1, (nu - n * RIJ_S) / VAL_S)
				y = m.topY + n * m.sy + p * (m.bakY - m.topY - n * m.sy + 8)
			end
			gloed.Position = plek(m, x, y)
			if nu >= totaal or not gloed.Parent then break end
			RunService.Heartbeat:Wait()
		end
		gloed:Destroy()

		-- Het geraakte bakje licht op en zakt vier pixels: dat is de hit-tak in pkDraw().
		local eind = bakken[bak + 1]
		if eind then
			local rust = eind.Position
			eind.BackgroundTransparency = 0
			eind.Position = UDim2.new(rust.X, UDim.new(rust.Y.Scale, rust.Y.Offset + 4))
			task.delay(FLITS_S, function()
				-- Tussendoor kan het bord opnieuw getekend zijn; dan is dit bakje weg.
				if eind.Parent then
					eind.BackgroundTransparency = BAK_DOORZICHT
					eind.Position = rust
				end
			end)
		end
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, ROWS, RISK, de maxregel en DROP in één `.panel`.
	-- Common.betBox maakt dat paneel, dus de rest gaat erbij in; de LayoutOrder geldt alleen
	-- binnen dit paneel, waar het inzetveld op nul staat en dus voorop blijft.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel

	-- Een `.field-group` heeft alleen `margin-bottom: 14`. Het paneel zet zelf al 6 pixels
	-- tussen zijn kinderen, dus elke groep legt er 8 onder bij. Het inzetblok erboven komt
	-- uit Common.betBox en heeft die 8 niet, dus de eerste groep zet ze ook boven zichzelf.
	local function veldGroep(orde: number, eerste: boolean?): Frame
		local f = Instance.new("Frame")
		f.Name = "FieldGroup"
		f.Size = UDim2.new(1, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.BackgroundTransparency = 1
		f.LayoutOrder = orde
		f.Parent = paneel
		UI.list(f, 6)
		UI.padding4(f, if eerste then 8 else 0, 0, 8, 0)
		return f
	end

	local rijenVeld = veldGroep(10, true)
	veldKop(rijenVeld, "ROWS")
	local _, rijKnop = segRij(rijenVeld, #RIJEN, 2)
	local rijKnoppen: { [number]: { knop: TextButton, rand: UIStroke } } = {}

	local risicoVeld = veldGroep(11)
	veldKop(risicoVeld, "RISK")
	local _, riskKnop = segRij(risicoVeld, #RISICO, 2)
	local riskKnoppen: { [string]: { knop: TextButton, rand: UIStroke } } = {}

	-- De maxregel raakt in de CSS de knop eronder met de 8 van `.btn-primary`. Het paneel
	-- geeft er 6, dus de regel gaat in een blokje dat er 2 onder legt.
	local uitbetaling = Instance.new("Frame")
	uitbetaling.Name = "Payout"
	uitbetaling.Size = UDim2.new(1, 0, 0, 0)
	uitbetaling.AutomaticSize = Enum.AutomaticSize.Y
	uitbetaling.BackgroundTransparency = 1
	uitbetaling.LayoutOrder = 12
	uitbetaling.Parent = paneel
	UI.list(uitbetaling, 0)
	UI.padding4(uitbetaling, 0, 0, 2, 0)

	local maxLabel = payoutRegel(uitbetaling, "MAX MULTIPLIER", 1)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local dropKnop = UI.primary(paneel, "DROP")
	dropKnop.LayoutOrder = 13
	dropKnop.Font = Theme.font.uiBold
	dropKnop.TextXAlignment = Enum.TextXAlignment.Center
	UI.gradient(dropKnop, Theme.color.neon, Theme.color.neonDim, 135)

	-- pkRender(): de gekozen knoppen aanzetten en de hoogste multiplier bijwerken.
	local function markeer()
		for n, k in rijKnoppen do
			local aan = n == rijen
			k.knop.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			k.knop.BackgroundTransparency = if aan then 0 else Theme.alpha.buttonBg
			k.knop.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			k.knop.Font = if aan then Theme.font.uiBold else Theme.font.ui
			k.rand.Color = if aan then Theme.color.neon else Theme.color.border
		end
		for key, k in riskKnoppen do
			local aan = key == risico
			k.knop.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			k.knop.BackgroundTransparency = if aan then 0 else Theme.alpha.buttonBg
			k.knop.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			k.knop.Font = if aan then Theme.font.uiBold else Theme.font.ui
			k.rand.Color = if aan then Theme.color.neon else Theme.color.border
		end
		local tabel = Odds.plinkoTable(rijen, risico)
		local hoogste = 0
		for _, m in tabel do
			if m > hoogste then hoogste = m end
		end
		maxLabel.Text = Money.fmt(hoogste) .. "\u{00D7}"
	end

	for i, n in RIJEN do
		local b, rand = rijKnop("Rows" .. n, tostring(n))
		b.LayoutOrder = i
		b.MouseEnter:Connect(function()
			if rijen ~= n then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if rijen == n then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			-- Midden in een worp van rijen wisselen zet het balletje op een bord dat er niet
			-- meer is; de webversie laat oude ballen daarom ook staan tot ze klaar zijn.
			if bezig then return end
			rijen = n
			tekenBord(true)
			markeer()
		end)
		rijKnoppen[n] = { knop = b, rand = rand }
	end

	for i, r in RISICO do
		local b, rand = riskKnop("Risk" .. r.key, r.label)
		b.LayoutOrder = i
		b.MouseEnter:Connect(function()
			if risico ~= r.key then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if risico == r.key then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			if bezig then return end
			risico = r.key
			tekenBord(true)
			markeer()
		end)
		riskKnoppen[r.key] = { knop = b, rand = rand }
	end

	dropKnop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		-- De webversie laat de knop staan; hier duurt de aanroep merkbaar, dus hij zegt wat
		-- hij doet in plaats van dood te lijken.
		dropKnop.Text = "DROPPING..."
		local res = Common.call("Bet", "plinko", betBox.get(), rijen, risico)
		if not res then
			bezig = false
			dropKnop.Text = "DROP"
			return
		end
		laatVallen(res.path, res.bucket)

		local tabel = Odds.plinkoTable(rijen, risico)
		table.insert(uitslagen, 1, { mult = res.mult, kleur = bakKleur(res.mult, tabel) })
		if #uitslagen > MAX_UITSLAGEN then table.remove(uitslagen) end
		tekenStrip()
		-- flash() in pkUpdate(): alleen bij een multiplier van 1 of hoger, goud vanaf 3.
		if res.mult >= 1 then
			Common.toast(
				Money.fmt(res.mult) .. "\u{00D7} \u{00B7} +$" .. Money.fmt(res.payout),
				if res.mult >= 3 then "gold" else "green"
			)
		end
		bezig = false
		dropKnop.Text = "DROP"
	end)

	-- Het vak wordt pas na de eerste frame gemeten, en het schuift mee als het venster van
	-- maat verandert; allebei vragen om hetzelfde bord opnieuw.
	vak:GetPropertyChangedSignal("AbsoluteSize"):Connect(tekenBord)
	task.defer(tekenBord)
	markeer()

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "plinko")
	Common.oddsPanel(bediening, "odds", "Every row is a fair 50/50. The payout table is normalised to RTP *97%* per row count and risk level. Higher risk means bigger outliers and more small losses.")
end

return Plinko
