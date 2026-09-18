--!strict
-- Paardenrace: zes banen over de volle breedte in wisselende tinten groen, links een witte
-- startstreep, rechts een zwart-witte finishblokkade, en per baan een ruiter met een
-- genummerde schijf en een naambordje ernaast. De uitslag staat vanaf de eerste tel vast --
-- die komt van de server -- maar het tempo per paard verschilt en er zit een golf in de
-- looplijn, zodat de kop onderweg wisselt. Zonder dat zag je meteen welk paard ging winnen,
-- en dat haalde de spanning eruit.
--
-- Het beeld komt regel voor regel uit de webversie: `#horseView` in de markup, en `.board`,
-- `.hr-wrap`, `.hr-list`, `.hr-row`, `.hr-podium`, `.hr-chip`, `.payout-line` en `.btn-row`
-- in de CSS. Het speelveld zelf komt uit hrDraw(); dat tekent op een canvas, hier is elke
-- baan, elk finishblokje en elke ruiter een Frame, uitgerekend met dezelfde pixelformules.
--
-- Wat Roblox niet heeft: letter-spacing (de 1px uit `.hr-row .name` en `.hr-podium` is
-- weggelaten), box-shadow (de winnende regel krijgt alleen de gouden rand uit
-- `.hr-row.won`), een vette variant van het cijferlettertype (`.hr-row .mult` is 700) en
-- twee kleuren in één label (een podiumregel is in zijn geheel de kleur van het paard, in
-- plaats van alleen de naam).
--
-- Het veld wordt op de server geloot voordat er wordt ingezet, en het scherm vraagt het op
-- zodra je binnenkomt. De kansen die je ziet zijn dus de kansen waarop gelopen wordt en de
-- quotes die je uitbetaald krijgt -- net als in de browser, waar de pagina ze zelf loot.
-- NEW ODDS vraagt de server om een nieuw veld; dat mag zo vaak als je wilt, want elke
-- quote is 0,97 gedeeld door de kans en betaalt dus hoe dan ook 97% terug.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Horse = {}

-- ---------- maten uit de CSS en uit hrDraw() ----------
local WRAP_MIN = 340       -- .hr-wrap min-height
local PODIUM_H = 18        -- .hr-podium min-height
local PODIUM_GAT = 14      -- .hr-podium gap
local STRIP_H = 26         -- .result-strip min-height
local STRIP_GAT = 6        -- .result-strip gap
local BORD_PAD = 14        -- `.panel.board` heeft hier in de markup `padding: 14px`

local BAND = 26            -- hrDraw: `const top = 26`, de band voor de kopregel
local TAG_X = 6            -- het naambordje: fillRect(6, y - 9, 76, 18)
local TAG_B = 76
local TAG_H = 18
local START_X = 90         -- x0 = 90 + ruiterPx * 0.6
local FINISH_X = 60        -- x1 = w - 60

local RIJ_H = 48           -- .hr-row: knop min-height 34, padding 6 boven en onder, en aan
                           -- weerskanten een rand van 1 -- de CSS rekent in border-box, dus
                           -- die randen tellen mee in de hoogte van de regel
local RIJ_GAT = 4          -- .hr-list gap
local RIJ_PAD = 8          -- .hr-row padding links en rechts
local KOL_GAT = 8          -- .hr-row gap
local STIP = 12            -- .hr-row .dot
local INZET_B = 52         -- .hr-row .stake min-width
local BACK_B = 56          -- "BACK" op 11px plus padding 12 links en rechts
local BACK_H = 34          -- .hr-row button min-height
local PCT_PX = 9           -- de winkans staat in de markup op font-size: 9px
local MAX_UITSLAGEN = 10   -- HR.history wordt afgekapt op tien

local STREEP = Color3.fromHex("1a3a1a")    -- .payout-line border-bottom
local BLOK = Color3.fromHex("111111")      -- de zwarte blokjes van de finish
-- .hr-row button: rgba(62,207,142,0.12) op neon, rand rgba(62,207,142,0.35).
local BACK_VUL = 0.88
local BACK_RAND = 0.65
-- :disabled is opacity 0.35; op een doorzichtige ondergrond telt dat door.
local UIT_TEKST = Theme.alpha.locked
local UIT_VUL = 1 - (1 - BACK_VUL) * 0.35
local UIT_RAND = 1 - (1 - BACK_RAND) * 0.35

local AANTAL = #Odds.HORSES

-- De hoogte van het banenvak voordat het gemeten is. AbsoluteSize is pas een frame later
-- bekend; zolang klopt alleen de dikte van de ruiter en van de finishblokjes nog niet, want
-- alle plaatsen hieronder staan in schaal of in een offset vanaf een rand.
local NOMINAAL_H = 794

type Maten = {
	baanH: number, ruiterPx: number, x0: number, sq: number, rijen: number,
	tagPx: number, straal: number,
}

-- hrDraw(): alles wat met de baanhoogte meeschaalt. De horizontale maten liggen vast ten
-- opzichte van de randen -- x0 vanaf links, x1 = w - 60 vanaf rechts -- dus die hoeven niet
-- gemeten te worden: Roblox kan een offset vanaf beide kanten neerzetten.
local function maten(baanH: number): Maten
	local ruiterPx = math.max(16, math.min(48, baanH * 0.62))
	local sq = math.max(6, baanH / 4)
	return {
		baanH = baanH,
		ruiterPx = ruiterPx,
		x0 = START_X + ruiterPx * 0.6,
		sq = sq,
		-- De lus in hrDraw() legt blokjes neer tot hij onderaan is; hier is het aantal rijen
		-- de maat, zodat ze de baan precies vullen wat de gemeten hoogte ook zegt.
		rijen = math.max(1, math.ceil(AANTAL * baanH / sq)),
		tagPx = math.max(8, math.min(11, baanH * 0.24)),
		straal = math.max(5, ruiterPx * 0.22),
	}
end

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .field-label: de naam links, de hint in neon rechts ("win chance").
local function veldKop(ouder: Instance, naam: string, hint: string, orde: number): ()
	local rij = Instance.new("Frame")
	rij.Name = "FieldLabel"
	rij.Size = UDim2.new(1, 0, 0, Theme.lineBox(Theme.text.small))   -- margin-bottom 6 onder een regel van 11
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
	rij.Parent = ouder
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted })
	local h = UI.label(rij, hint, {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
		name = "Hint",
	})
	h.TextTransparency = 0.3    -- .field-label .hint opacity 0.7
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
	local v = UI.label(rij, "$0.00", {
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

type Loop = {
	pace: number,   -- hoe een paard zijn tempo verdeelt: laag = snelle start, hoog = eindsprint
	amp: number,    -- hoe ver hij van de zuivere lijn afwijkt
	freq: number,
	fase: number,
	eind: number,   -- wanneer hij over de streep is
}

-- Eén regel in de aside: alles wat na een klik of een uitslag van tekst verandert.
type Regel = {
	rand: UIStroke,
	pct: TextLabel,
	mult: TextLabel,
	inzet: TextLabel,
	knop: TextButton,
	knopRand: UIStroke,
}

-- Eén ruiter op de baan: de figuur en de gekleurde schijf met zijn startnummer erin.
type Ruiter = { vak: Frame, fig: TextLabel, schijf: Frame, hoek: UICorner, nummer: TextLabel }

function Horse.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "HORSE RACE")

	-- `.panel.board` staat bij dit scherm in de markup op `padding: 14px`, smaller dan de 22
	-- uit de CSS die Common als paneelpadding aanhoudt. Hier wordt die overschrijving
	-- nagedaan: aan alle kanten vier pixels minder rand, dus vier pixels meer baan.
	bord.Position = UDim2.fromOffset(BORD_PAD, BORD_PAD)
	bord.Size = UDim2.new(1, -BORD_PAD * 2, 1, -BORD_PAD * 2)

	-- ---------- het speelveld ----------
	-- `.hr-wrap` vult wat het bord overhoudt; daaronder het podium en de uitslagbalk, elk
	-- met de tussenruimte van het bord ertussen.
	local vak = Instance.new("Frame")
	vak.Name = "HorseWrap"
	vak.Size = UDim2.new(1, 0, 1, -(PODIUM_H + STRIP_H + 2 * Theme.size.asideGap))
	vak.BackgroundColor3 = Theme.color.feltLight
	vak.BorderSizePixel = 0
	vak.ClipsDescendants = true
	UI.corner(vak, 4)   -- .hr-wrap canvas border-radius: 4px
	vak.Parent = bord
	local minHoogte = Instance.new("UISizeConstraint")
	minHoogte.MinSize = Vector2.new(0, WRAP_MIN)
	minHoogte.Parent = vak

	-- Onder de kopband ligt de baan zelf. Alles daarbinnen staat in schaal, zodat de zes
	-- banen het vak precies vullen zonder dat er iets gemeten hoeft te worden.
	local baanVak = Instance.new("Frame")
	baanVak.Name = "Lanes"
	baanVak.Position = UDim2.new(0, 0, 0, BAND)
	baanVak.Size = UDim2.new(1, 0, 1, -BAND)
	baanVak.BackgroundTransparency = 1
	baanVak.Parent = vak

	-- Twee lagen: het gras wordt bij elke hertekening opnieuw gemaakt, de merken
	-- (naambordjes en ruiters) blijven staan. In deze volgorde, want een kind tekent altijd
	-- over zijn oudere broertjes heen -- op ZIndex leunen zou betekenen dat de merken na
	-- elke hertekening onder het verse gras verdwijnen.
	local gras = Instance.new("Frame")
	gras.Name = "Turf"
	gras.Size = UDim2.fromScale(1, 1)
	gras.BackgroundTransparency = 1
	gras.Parent = baanVak

	local merken = Instance.new("Frame")
	merken.Name = "Marks"
	merken.Size = UDim2.fromScale(1, 1)
	merken.BackgroundTransparency = 1
	merken.Parent = baanVak

	-- De kopband, waar tijdens de race staat wie er aan de leiding gaat.
	local band = Instance.new("Frame")
	band.Name = "Banner"
	band.Size = UDim2.new(1, 0, 0, BAND)
	band.BackgroundColor3 = Theme.color.felt
	band.BorderSizePixel = 0
	band.Parent = vak
	local leider = UI.label(band, "", {
		size = Theme.text.tiny, color = Theme.color.white, font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
	})
	leider.Size = UDim2.fromScale(1, 1)
	leider.TextYAlignment = Enum.TextYAlignment.Center

	-- .hr-podium: de drie medailles, gecentreerd.
	local podium = Instance.new("Frame")
	podium.Name = "Podium"
	podium.Size = UDim2.new(1, 0, 0, PODIUM_H)
	podium.BackgroundTransparency = 1
	podium.Parent = bord
	local podiumLijst = UI.list(podium, PODIUM_GAT, Enum.FillDirection.Horizontal)
	podiumLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	podiumLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	-- .result-strip: de laatste tien winnaars, de nieuwste vooraan.
	local strip = Instance.new("Frame")
	strip.Name = "Results"
	strip.Size = UDim2.new(1, 0, 0, STRIP_H)
	strip.BackgroundTransparency = 1
	strip.Parent = bord
	local striplijst = UI.list(strip, STRIP_GAT, Enum.FillDirection.Horizontal)
	striplijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	striplijst.VerticalAlignment = Enum.VerticalAlignment.Center

	-- ---------- de stand van het scherm ----------
	local inzetten: { [number]: number } = {}
	local kansen: { number }? = nil          -- het veld waarop deze race gelopen wordt
	local winnaar: number? = nil             -- kleurt die regel goud, zoals `.hr-row.won`
	local voortgang: { number } = {}         -- per paard 0 tot 1 over de baan
	local historie: { { naam: string, kleur: Color3, mult: number } } = {}
	local bezig = false

	local kleuren: { Color3 } = {}
	for i, h in Odds.HORSES do
		kleuren[i] = Color3.fromHex(h.color)
		voortgang[i] = 0
	end

	-- ---------- de baan ----------
	local m: Maten = maten(NOMINAAL_H / AANTAL)
	local naamVakken: { Frame } = {}
	local naamLabels: { TextLabel } = {}
	local ruiters: { Ruiter } = {}

	-- Het naambordje en de ruiter blijven staan; een hertekening zet ze alleen opnieuw op
	-- maat. Anders zou een venster dat tijdens de race van grootte verandert de lopers
	-- weggooien en opnieuw op de start zetten.
	for i, h in Odds.HORSES do
		local tag = Instance.new("Frame")
		tag.Name = "Tag" .. i
		tag.AnchorPoint = Vector2.new(0, 0.5)
		tag.Size = UDim2.fromOffset(TAG_B, TAG_H)
		tag.BackgroundColor3 = Theme.color.black
		tag.BackgroundTransparency = 0.45   -- rgba(0,0,0,0.55)
		tag.BorderSizePixel = 0
		tag.Parent = merken
		naamVakken[i] = tag

		local naam = UI.label(tag, h.name, {
			size = Theme.text.tiny, color = kleuren[i], font = Theme.font.uiBold,
		})
		naam.Size = UDim2.fromScale(1, 1)
		naam.TextYAlignment = Enum.TextYAlignment.Center
		UI.padding4(naam, 0, 0, 0, 4)   -- de tekst begint op x = 10, het bordje op x = 6
		naamLabels[i] = naam

		local rvak = Instance.new("Frame")
		rvak.Name = "Rider" .. i
		rvak.AnchorPoint = Vector2.new(0.5, 0.5)
		rvak.Size = UDim2.fromOffset(1, 1)
		rvak.BackgroundTransparency = 1
		rvak.Parent = merken

		local fig = UI.label(rvak, "\u{1F3C7}", {
			size = Theme.text.big, color = Theme.color.black,
			align = Enum.TextXAlignment.Center,
		})
		fig.AnchorPoint = Vector2.new(0.5, 0.5)
		fig.TextYAlignment = Enum.TextYAlignment.Center

		-- De gekleurde schijf met het startnummer, links-boven op de ruiter, zoals het
		-- badge-rondje in hrDraw().
		local schijf = Instance.new("Frame")
		schijf.Name = "Badge"
		schijf.AnchorPoint = Vector2.new(0.5, 0.5)
		schijf.BackgroundColor3 = kleuren[i]
		schijf.BorderSizePixel = 0
		local hoek = UI.corner(schijf, m.straal)
		UI.stroke(schijf, Theme.color.black, 1.5)
		schijf.Parent = rvak

		local nummer = UI.label(schijf, tostring(i), {
			size = Theme.text.tiny, color = Theme.color.black, font = Theme.font.uiBold,
			align = Enum.TextXAlignment.Center,
		})
		nummer.Size = UDim2.fromScale(1, 1)
		nummer.TextYAlignment = Enum.TextYAlignment.Center

		ruiters[i] = { vak = rvak, fig = fig, schijf = schijf, hoek = hoek, nummer = nummer }
	end

	-- Eén paard op zijn plek zetten; dit draait ook per frame tijdens de race.
	local function plaatsRuiter(i: number)
		local p = voortgang[i] or 0
		-- x = x0 + (x1 - x0) * p, met x1 = breedte - 60. Uitgeschreven is dat schaal p plus
		-- een offset die van allebei de randen af rekent, dus zonder iets te hoeven meten.
		ruiters[i].vak.Position = UDim2.new(
			p, m.x0 * (1 - p) - FINISH_X * p, (i - 0.5) / AANTAL, 0
		)
	end

	local grasDelen: { GuiObject } = {}
	-- De baanhoogte waar het gras nu op staat. AbsoluteSize komt tijdens het slepen van een
	-- venster tientallen keren per seconde langs; dan alles opnieuw maken is zonde.
	local getekend = -1

	local function tekenBaan()
		local gemeten = baanVak.AbsoluteSize.Y
		local baanH = (if gemeten > AANTAL then gemeten else NOMINAAL_H) / AANTAL
		if math.abs(baanH - getekend) < 0.5 then return end
		getekend = baanH
		m = maten(baanH)

		for _, d in grasDelen do d:Destroy() end
		table.clear(grasDelen)

		-- De zes banen, om en om lichter en donkerder, met een haarlijn bovenlangs.
		for i = 1, AANTAL do
			local baan = Instance.new("Frame")
			baan.Name = "Lane" .. i
			baan.Position = UDim2.fromScale(0, (i - 1) / AANTAL)
			baan.Size = UDim2.fromScale(1, 1 / AANTAL)
			baan.BackgroundColor3 = if (i - 1) % 2 == 1 then Theme.color.feltDark else Theme.color.feltLight
			baan.BorderSizePixel = 0
			baan.Parent = gras
			table.insert(grasDelen, baan)

			local lijn = Instance.new("Frame")
			lijn.Name = "LaneRule" .. i
			lijn.Position = UDim2.fromScale(0, (i - 1) / AANTAL)
			lijn.Size = UDim2.new(1, 0, 0, 1)
			lijn.BackgroundColor3 = Theme.color.white
			lijn.BackgroundTransparency = 0.65   -- rgba(255,255,255,0.35)
			lijn.BorderSizePixel = 0
			lijn.Parent = gras
			table.insert(grasDelen, lijn)
		end

		-- De startstreep: twee pixels wit, vlak voor de neus van de paarden.
		local start = Instance.new("Frame")
		start.Name = "StartLine"
		start.Position = UDim2.new(0, m.x0 - 2, 0, 0)
		start.Size = UDim2.new(0, 2, 1, 0)
		start.BackgroundColor3 = Theme.color.white
		start.BackgroundTransparency = 0.4   -- rgba(255,255,255,0.6)
		start.BorderSizePixel = 0
		start.Parent = gras
		table.insert(grasDelen, start)

		-- De finish: twee kolommen blokjes, om en om zwart en wit, precies de dubbele lus
		-- uit hrDraw(). Ze beginnen 60 pixels voor de rechterrand en lopen door tot voorbij
		-- het vak; het overschot wordt weggeknipt, net als op het canvas.
		for r = 0, m.rijen - 1 do
			for k = 0, 1 do
				local blok = Instance.new("Frame")
				blok.Name = "Finish"
				blok.Position = UDim2.new(1, -FINISH_X + k * m.sq, r / m.rijen, 0)
				blok.Size = UDim2.new(0, m.sq, 1 / m.rijen, 0)
				blok.BackgroundColor3 = if (r + k) % 2 == 1 then BLOK else Theme.color.white
				blok.BorderSizePixel = 0
				blok.Parent = gras
				table.insert(grasDelen, blok)
			end
		end

		-- De naambordjes en de ruiters op de nieuwe maat.
		for i = 1, AANTAL do
			naamVakken[i].Position = UDim2.new(0, TAG_X, (i - 0.5) / AANTAL, 0)
			naamLabels[i].TextSize = m.tagPx

			local r = ruiters[i]
			r.fig.TextSize = m.ruiterPx
			r.fig.Size = UDim2.fromOffset(m.ruiterPx * 2, m.ruiterPx * 1.4)
			r.fig.Position = UDim2.fromOffset(0, m.baanH * 0.05)
			r.schijf.Size = UDim2.fromOffset(m.straal * 2, m.straal * 2)
			r.schijf.Position = UDim2.fromOffset(-m.ruiterPx * 0.5, -m.ruiterPx * 0.45)
			r.hoek.CornerRadius = UDim.new(0, m.straal)
			r.nummer.TextSize = math.max(8, m.straal * 1.3)
			plaatsRuiter(i)
		end
	end

	-- ---------- podium en uitslagbalk ----------
	-- `.hr-podium`: de drie medailles met de naam van het paard erachter. In de webversie is
	-- alleen de naam gekleurd; RichText staat in dit project uit, dus de hele regel krijgt
	-- de kleur van het paard.
	local MEDAILLE = { "\u{1F947}", "\u{1F948}", "\u{1F949}" }

	local function tekenPodium(volgorde: { number }?)
		for _, k in podium:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		if not volgorde then return end
		for plaats = 1, math.min(3, #volgorde) do
			local paard = volgorde[plaats]
			local l = UI.label(podium, MEDAILLE[plaats] .. " " .. Odds.HORSES[paard].name, {
				size = Theme.text.tiny, color = kleuren[paard], font = Theme.font.uiBold,
			})
			l.LayoutOrder = plaats
			l.AutomaticSize = Enum.AutomaticSize.X
			l.Size = UDim2.new(0, 0, 1, 0)
			l.TextYAlignment = Enum.TextYAlignment.Center
		end
	end

	-- `.hr-chip`: de naam en de uitbetaling van een gelopen race, in de kleur van de winnaar
	-- als tekst en als rand, op een zwarte ondergrond.
	local function tekenStrip()
		for _, k in strip:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		for i, w in historie do
			local c = Instance.new("TextLabel")
			c.Name = "Chip" .. i
			c.LayoutOrder = i
			c.Text = w.naam .. " " .. Money.fmt(w.mult) .. "\u{00D7}"
			c.Font = Theme.font.uiBold
			c.TextSize = Theme.text.tiny
			c.TextColor3 = w.kleur
			c.BackgroundColor3 = Theme.color.black
			c.BackgroundTransparency = 0.6   -- rgba(0,0,0,0.4)
			c.BorderSizePixel = 0
			c.RichText = false
			c.AutomaticSize = Enum.AutomaticSize.X
			c.Size = UDim2.fromOffset(0, STRIP_H)
			UI.corner(c, 10)
			UI.stroke(c, w.kleur)
			UI.padding4(c, 4 + UI.RAND, 9 + UI.RAND, 4 + UI.RAND, 9 + UI.RAND)
			c.Parent = strip
		end
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, de paardenlijst, de totaalregel en de drie knoppen in
	-- één `.panel`. Common.betBox maakt dat paneel, dus de rest gaat erbij in; de LayoutOrder
	-- hieronder geldt alleen bínnen dat paneel, waar het inzetveld op nul staat.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel
	-- Het veld heet hier STAKE PER HORSE: je zet per paard in, niet één keer per ronde.
	for _, kind in paneel:GetDescendants() do
		if kind:IsA("TextLabel") and kind.Text == "STAKE" then
			kind.Text = "STAKE PER HORSE"
		end
	end

	-- Het kopje `.field-label` met zijn `margin-bottom: 6px`, dan de lijst met de paarden
	-- en daaronder de `margin-bottom: 10px` van `.hr-list`. Het paneel houdt zelf niets
	-- tussen zijn kinderen, dus die tien staan hier.
	local lijstGroep = Instance.new("Frame")
	lijstGroep.Name = "HorseField"
	lijstGroep.Size = UDim2.new(1, 0, 0, 0)
	lijstGroep.AutomaticSize = Enum.AutomaticSize.Y
	lijstGroep.BackgroundTransparency = 1
	lijstGroep.LayoutOrder = 10
	lijstGroep.Parent = paneel
	UI.list(lijstGroep, 6)
	UI.padding4(lijstGroep, 0, 0, 10, 0)

	veldKop(lijstGroep, "HORSES & ODDS", "win chance", 1)

	local lijst = Instance.new("Frame")
	lijst.Name = "HorseList"
	lijst.Size = UDim2.new(1, 0, 0, AANTAL * RIJ_H + (AANTAL - 1) * RIJ_GAT)
	lijst.BackgroundTransparency = 1
	lijst.LayoutOrder = 2
	lijst.Parent = lijstGroep
	UI.list(lijst, RIJ_GAT)

	local regels: { Regel } = {}
	local ververs: () -> ()

	for i, h in Odds.HORSES do
		-- `.hr-row`: grid 14px | 1fr | auto | auto. De vaste kolommen staan links en rechts
		-- vast, het naamblok ertussen krijgt wat overblijft.
		local rij = Instance.new("Frame")
		rij.Name = "Row" .. i
		rij.Size = UDim2.new(1, 0, 0, RIJ_H)
		rij.BackgroundColor3 = Theme.color.black
		rij.BackgroundTransparency = 0.6   -- rgba(0,0,0,0.4)
		rij.BorderSizePixel = 0
		rij.LayoutOrder = i
		UI.corner(rij, Theme.radius.button)
		local rand = UI.stroke(rij, Theme.color.border)
		rij.Parent = lijst

		local stip = Instance.new("Frame")
		stip.Name = "Dot"
		stip.AnchorPoint = Vector2.new(0, 0.5)
		stip.Position = UDim2.new(0, RIJ_PAD, 0.5, 0)
		stip.Size = UDim2.fromOffset(STIP, STIP)
		stip.BackgroundColor3 = kleuren[i]
		stip.BorderSizePixel = 0
		UI.corner(stip, STIP / 2)
		stip.Parent = rij

		local knop = Instance.new("TextButton")
		knop.Name = "Back"
		knop.Text = "BACK"
		knop.Font = Theme.font.ui
		knop.TextSize = Theme.text.tiny
		knop.TextColor3 = Theme.color.neon
		knop.BackgroundColor3 = Theme.color.neon
		knop.BackgroundTransparency = BACK_VUL
		knop.BorderSizePixel = 0
		knop.AutoButtonColor = false
		knop.AnchorPoint = Vector2.new(1, 0.5)
		knop.Position = UDim2.new(1, -RIJ_PAD, 0.5, 0)
		knop.Size = UDim2.fromOffset(BACK_B, BACK_H)
		UI.corner(knop, Theme.radius.chip)
		local knopRand = UI.stroke(knop, Theme.color.neon)
		knopRand.Transparency = BACK_RAND
		knop.Parent = rij

		local inzet = UI.label(rij, "", {
			size = Theme.text.tiny, color = Theme.color.neon, font = Theme.font.num,
			align = Enum.TextXAlignment.Right, name = "Stake",
		})
		inzet.AnchorPoint = Vector2.new(1, 0.5)
		inzet.Position = UDim2.new(1, -(RIJ_PAD + BACK_B + KOL_GAT), 0.5, 0)
		inzet.Size = UDim2.fromOffset(INZET_B, 16)

		local blok = Instance.new("Frame")
		blok.Name = "Naming"
		blok.Position = UDim2.new(0, RIJ_PAD + STIP + KOL_GAT, 0, 0)
		blok.Size = UDim2.new(
			1, -(RIJ_PAD + STIP + KOL_GAT + INZET_B + KOL_GAT + BACK_B + RIJ_PAD), 1, 0
		)
		blok.BackgroundTransparency = 1
		blok.Parent = rij
		local blokLijst = UI.list(blok, 2)
		blokLijst.VerticalAlignment = Enum.VerticalAlignment.Center

		local naam = UI.label(blok, h.name, { size = Theme.text.tiny, color = Theme.color.text })
		naam.Size = UDim2.new(1, 0, 0, 14)

		-- De onderregel: de winkans klein en grijs, de uitbetaling ernaast in goud. Twee
		-- labels naast elkaar, want één label kent maar één kleur.
		local onder = Instance.new("Frame")
		onder.Name = "Odds"
		onder.Size = UDim2.new(1, 0, 0, 12)
		onder.BackgroundTransparency = 1
		onder.Parent = blok
		local onderLijst = UI.list(onder, 0, Enum.FillDirection.Horizontal)
		onderLijst.VerticalAlignment = Enum.VerticalAlignment.Center

		local pct = UI.label(onder, "\u{2014} \u{00B7} ", { size = PCT_PX, color = Theme.color.muted })
		pct.AutomaticSize = Enum.AutomaticSize.X
		pct.Size = UDim2.new(0, 0, 1, 0)
		pct.LayoutOrder = 1

		local mult = UI.label(onder, "\u{2014}", {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
		})
		mult.AutomaticSize = Enum.AutomaticSize.X
		mult.Size = UDim2.new(0, 0, 1, 0)
		mult.LayoutOrder = 2

		regels[i] = {
			rand = rand, pct = pct, mult = mult, inzet = inzet, knop = knop, knopRand = knopRand,
		}

		-- :hover keert de knop om: een neon vlak met donkere letters.
		knop.MouseEnter:Connect(function()
			if bezig then return end
			knop.BackgroundTransparency = 0
			knop.TextColor3 = Theme.color.bg
		end)
		knop.MouseLeave:Connect(function()
			if bezig then return end
			knop.BackgroundTransparency = BACK_VUL
			knop.TextColor3 = Theme.color.neon
		end)
		knop.Activated:Connect(function()
			if bezig then return end
			local bedrag = betBox.get()
			if bedrag < Money.MIN_BET then
				Common.toast("MINIMUM STAKE $" .. Money.fmt(Money.MIN_BET), "red")
				return
			end
			inzetten[i] = Money.round2((inzetten[i] or 0) + bedrag)
			ververs()
		end)
	end

	local totaalLabel = payoutRegel(paneel, "TOTAL STAKE", 11)

	Common.buttonGap(paneel, 12)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local startKnop = UI.primary(paneel, "START THE RACE")
	startKnop.LayoutOrder = 12
	startKnop.Font = Theme.font.uiBold
	UI.gradient(startKnop, Theme.color.neon, Theme.color.neonDim, 135)

	-- .btn-row: twee gelijke knoppen met 6 ertussen en 8 lucht erboven.
	local knoprij = Instance.new("Frame")
	knoprij.Name = "ButtonRow"
	knoprij.Size = UDim2.new(1, 0, 0, 40 + 8)
	knoprij.BackgroundTransparency = 1
	knoprij.LayoutOrder = 13
	knoprij.Parent = paneel
	UI.padding4(knoprij, 8, 0, 0, 0)
	local knoprijLijst = UI.list(knoprij, 6, Enum.FillDirection.Horizontal)
	knoprijLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	local wissen = UI.secondary(knoprij, "CLEAR")
	wissen.LayoutOrder = 1
	wissen.Size = UDim2.new(0.5, -3, 0, wissen.Size.Y.Offset)
	local nieuweOdds = UI.secondary(knoprij, "NEW ODDS")
	nieuweOdds.LayoutOrder = 2
	nieuweOdds.Size = UDim2.new(0.5, -3, 0, nieuweOdds.Size.Y.Offset)

	-- hrRender(): alle teksten en alle aan/uit-standen in één keer bijwerken.
	function ververs()
		local totaal = 0
		for _, b in inzetten do totaal += b end
		totaal = Money.round2(totaal)
		totaalLabel.Text = "$" .. Money.fmt(totaal)

		local k = kansen
		for i, r in regels do
			if k then
				r.pct.Text = string.format("%d%% \u{00B7} ", math.floor(k[i] * 100 + 0.5))
				r.mult.Text = Money.fmt(Odds.horseMultiplier(k[i])) .. "\u{00D7}"
			else
				r.pct.Text = "\u{2014} \u{00B7} "
				r.mult.Text = "\u{2014}"
			end
			local b = inzetten[i]
			r.inzet.Text = if b then "$" .. Money.fmt(b) else ""
			-- `.hr-row.won`: de winnende regel krijgt een gouden rand.
			r.rand.Color = if winnaar == i then Theme.color.gold else Theme.color.border
			r.knop.Active = not bezig
			r.knop.TextTransparency = if bezig then UIT_TEKST else 0
			r.knop.BackgroundTransparency = if bezig then UIT_VUL else BACK_VUL
			r.knop.TextColor3 = Theme.color.neon
			r.knopRand.Transparency = if bezig then UIT_RAND else BACK_RAND
		end

		startKnop.Text = if bezig then "RACE RUNNING\u{2026}" else "START THE RACE"
		UI.setEnabled(startKnop, not bezig)
		UI.setEnabled(wissen, not bezig and totaal > 0)
		UI.setEnabled(nieuweOdds, not bezig and totaal == 0)
		betBox.lock(bezig)
	end

	-- De paarden terug naar de start.
	local function opstellen()
		for i = 1, AANTAL do
			voortgang[i] = 0
			plaatsRuiter(i)
		end
	end

	-- De race afspelen. `volgorde` komt van de server: plaats 1 wint. De looplijn is alleen
	-- versiering -- elk paard komt precies op zijn eigen plaats binnen.
	local function race(volgorde: { number })
		local loop: { [number]: Loop } = {}
		for plaats, paard in volgorde do
			loop[paard] = {
				-- Een lage pace start hard en zakt terug, een hoge komt van achteren. Door
				-- dat te schudden weet je aan de start niet wie er gaat winnen.
				pace = 0.55 + math.random() * 1.35,
				amp = 0.05 + math.random() * 0.07,
				freq = 1.6 + math.random() * 2.2,
				fase = math.random() * math.pi * 2,
				eind = 5.0 + (plaats - 1) * 0.28 + math.random() * 0.16,
			}
		end

		local langste = 0
		for _, l in loop do
			if l.eind > langste then langste = l.eind end
		end

		local start = os.clock()
		while true do
			local t = os.clock() - start
			local kop, kopPos = volgorde[1], -1
			for i = 1, AANTAL do
				local l = loop[i]
				local u = math.min(1, t / l.eind)
				local pos = u ^ l.pace
				-- De golf is nul aan het begin en aan het eind, dus hij verandert de uitslag
				-- niet, alleen het beeld ertussenin.
				pos += l.amp * math.sin(l.freq * t + l.fase) * math.sin(math.pi * u)
				pos = math.clamp(pos, 0, 1)
				voortgang[i] = pos
				plaatsRuiter(i)
				if pos > kopPos then
					kop, kopPos = i, pos
				end
			end
			-- De kopregel in de band, zoals de LEADING-tak onderaan hrDraw().
			leider.Text = "LEADING: " .. Odds.HORSES[kop].name
			leider.TextColor3 = kleuren[kop]
			if t >= langste then break end
			RunService.Heartbeat:Wait()
		end
		leider.Text = ""
	end

	wissen.Activated:Connect(function()
		if bezig then return end
		table.clear(inzetten)
		ververs()
	end)

	nieuweOdds.Activated:Connect(function()
		-- Zoals hrNewField() in de webversie: een nieuw veld, en de inzetten eraf -- ze
		-- hoorden bij quotes die nu niet meer gelden.
		if bezig then return end
		local res = Common.call("NewOdds", "horse")
		if not res then return end
		kansen = res.probs
		winnaar = nil
		table.clear(inzetten)
		ververs()
	end)

	startKnop.Activated:Connect(function()
		if bezig then return end
		local totaal = 0
		for _, b in inzetten do totaal += b end
		totaal = Money.round2(totaal)
		if totaal < Money.MIN_BET then
			Common.toast("BACK A HORSE FIRST", "red")
			return
		end
		bezig = true
		winnaar = nil
		tekenPodium(nil)
		opstellen()
		ververs()

		local kopie: { [number]: number } = {}
		for i, b in inzetten do kopie[i] = b end
		local res = Common.call("Bet", "horse", kopie)
		if not res then
			bezig = false
			ververs()
			return
		end

		-- Vanaf hier zijn de kansen bekend: dit is het veld waarop deze race gelopen is.
		kansen = res.probs
		ververs()

		race(res.order)

		local paard = Odds.HORSES[res.winner]
		local mult = Odds.horseMultiplier(res.probs[res.winner])
		winnaar = res.winner
		tekenPodium(res.order)
		table.insert(historie, 1, { naam = paard.name, kleur = kleuren[res.winner], mult = mult })
		if #historie > MAX_UITSLAGEN then table.remove(historie) end
		tekenStrip()

		if res.payout > 0 then
			Common.toast(paard.name .. " WINS \u{00B7} +$" .. Money.fmt(res.payout), "green")
		else
			Common.toast(paard.name .. " WINS \u{00B7} -$" .. Money.fmt(totaal), "red")
		end
		table.clear(inzetten)
		bezig = false
		-- Het veld voor de volgende race kwam met de uitslag mee, dus de quotes staan er
		-- meteen weer -- zonder dat er eerst blind ingezet hoeft te worden.
		if typeof(res.nextProbs) == "table" then
			kansen = res.nextProbs
			winnaar = nil
		end
		ververs()
	end)

	-- Het vak wordt pas na de eerste frame gemeten, en het schuift mee als het venster van
	-- maat verandert; allebei vragen om dezelfde baan opnieuw.
	baanVak:GetPropertyChangedSignal("AbsoluteSize"):Connect(tekenBaan)
	task.defer(tekenBaan)
	ververs()

	-- Het veld ophalen dat op de server klaarstaat, zodat de quotes op het scherm staan
	-- voordat er iets ingezet wordt. Lukt het niet, dan blijven de streepjes staan en
	-- weigert de server de inzet ook -- liever geen quote dan een verzonnen quote.
	task.spawn(function()
		local res = Common.call("RoundState", "horse")
		if res and res.probs and not kansen then
			kansen = res.probs
			ververs()
		end
	end)

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "horse")
	Common.oddsPanel(bediening, "odds", "Every horse has its own win chance, shown as a percentage. Payout = *0.97 / win chance*, so RTP *97%* on every horse, favourite or longshot. The result is drawn before the start; the race just plays it out.")
end

return Horse
