--!strict
-- Prestaties, zoals #achievementsView in de webversie: geen aside maar een blad over de
-- volle breedte. Van boven naar beneden precies de volgorde uit de markup: de hero met
-- ACHIEVEMENTS, de seizoenstrip, dan LAST SPRINT naast WHAT EACH PLACE IS WORTH, en
-- onderaan de kop YOUR ACHIEVEMENTS met de voortgangsbalk en het hele rek.
--
-- Alleen om naar te kijken: kiezen welke drie badges je laat zien doe je op het profiel,
-- net als in de webversie. Hier stonden die vakjes een tijd lang ook, omdat het profiel
-- toen nog niets aan te klikken had -- anders kon je een badge wel oppakken maar nooit
-- meer neerleggen. Nu het profiel ze allebei kan, horen ze daar en alleen daar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Ach = require(ReplicatedStorage.Shared.Achievements)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Achievements = {}

-- De tien plekken met hun teken, hun naam en wat ze opleveren staan in Season.RANKS --
-- dezelfde lijst waar de seizoenstrip zijn drie prijsvakjes uit haalt. Dit scherm tekent
-- er #rankLadder mee, en zet de tekens ook voor de namen in LAST SPRINT.
local RANGEN = Season.RANKS

-- De randkleuren van een behaalde badge, uit `.ach-card.done.<tier>`. Brons is daar geen
-- bruin maar juist neongroen. De CSS zet ze met rgba(), dus hier de kleur plus de
-- doorzichtigheid die daarbij hoort.
local NIVEAU: { [string]: { kleur: Color3, doorzicht: number } } = {
	gold = { kleur = Color3.fromHex("e0b555"), doorzicht = 0.45 },   -- rgba(224,181,85,0.55)
	silver = { kleur = Color3.fromHex("c8d0dc"), doorzicht = 0.55 }, -- rgba(200,208,220,0.45)
	bronze = { kleur = Color3.fromHex("3ecf8e"), doorzicht = 0.60 }, -- rgba(62,207,142,0.4)
}

-- De sorteervolgorde van het rek, gelijk aan achRender(): wat je hebt eerst, en daarbinnen
-- goud voor zilver voor brons.
local RANG: { [string]: number } = { gold = 0, silver = 1, bronze = 2 }

-- Waar een prestatie in ACHIEVEMENTS staat. Zie zetVolgorde(): dit houdt de volgorde van
-- de webversie vast als twee kaarten verder gelijk staan.
local PLEK: { [string]: number } = {}
for i, a in Ach.LIST do
	PLEK[a.id] = i
end

-- `.ach-grid` is `repeat(auto-fill, minmax(260px, 1fr))` met 12 ertussen: de 260 is een
-- bodem, en de kolommen die passen rekken daarna de rij vol. `Common.rekKolommen` rekent
-- dat uit -- dezelfde maten als op het profiel, zodat de twee rekken naast elkaar te
-- leggen zijn.
local KAART_MIN = 260
local KAART_HOOG = 75
local KAART_GAT = 12

-- `.lb-row` heeft border-bottom rgba(26,58,26,0.5); `.rank-row` rgba(42,50,61,0.6). Roblox
-- kent geen rand aan één kant, dus staat er onderaan een streepje van één pixel.
local function streep(ouder: GuiObject, kleur: Color3, doorzicht: number): ()
	local l = Instance.new("Frame")
	l.Name = "Border"
	l.AnchorPoint = Vector2.new(0, 1)
	l.Position = UDim2.new(0, 0, 1, 0)
	l.Size = UDim2.new(1, 0, 0, 1)
	l.BackgroundColor3 = kleur
	l.BackgroundTransparency = doorzicht
	l.BorderSizePixel = 0
	l.Parent = ouder
end

-- `.lb-panel .panel-title` is een flexregel met de kop links en `.sub` grijs rechts.
local function paneelKop(paneel: Frame, kop: string, sub: string): ()
	local rij = Instance.new("Frame")
	rij.Name = "Title"
	rij.Size = UDim2.new(1, 0, 0, Theme.lineBox(Theme.text.small) + UI.PANEL_TITLE_MARGE)
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = 1
	rij.Parent = paneel

	UI.panelTitle(rij, kop)
	local s = UI.label(rij, sub, {
		size = Theme.text.small, color = Theme.color.muted,
		align = Enum.TextXAlignment.Right, name = "Sub",
	})
	s.Size = UDim2.fromScale(1, 1)
end

-- `.odds-note`: 11px grijs met line-height 1.7, over meerdere regels.
local function notitie(ouder: Instance, tekst: string): TextLabel
	local t = UI.label(ouder, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
	t.TextWrapped = true
	t.LineHeight = 1.7
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Size = UDim2.new(1, 0, 0, 0)
	t.TextYAlignment = Enum.TextYAlignment.Top
	return t
end

function Achievements.build(ouder: Instance): (any) -> ()
	local blad = Common.sheet(ouder)

	-- #achievementsView heeft `padding: 40px 50px`, net als de lobby en het profiel. De
	-- schil geeft het scherm al viewPad mee, dus hier komt alleen het verschil erbij.
	local marge = blad:FindFirstChildOfClass("UIPadding")
	if marge then
		local y = UDim.new(0, Theme.size.homePadY - Theme.size.viewPad)
		local x = UDim.new(0, Theme.size.homePadX - Theme.size.viewPad)
		marge.PaddingTop, marge.PaddingBottom = y, y
		marge.PaddingLeft, marge.PaddingRight = x, x
	end

	-- De marges tussen de blokken verschillen in de CSS (30, 26, 50, 24, 18). Eén
	-- UIListLayout kent maar één tussenruimte, dus die staat op de kleinste en elk blok
	-- krijgt de rest als padding aan zijn onderkant mee.
	local BLAD_GAT = 8
	local lijst = blad:FindFirstChildOfClass("UIListLayout")
	if lijst then lijst.Padding = UDim.new(0, BLAD_GAT) end

	-- ---------- .home-hero ----------
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.BackgroundTransparency = 1
	hero.LayoutOrder = 1
	hero.Parent = blad
	UI.list(hero, 12)
	UI.padding4(hero, 0, 0, 22, 0) -- margin-bottom: 30px, waarvan 8 uit de lijst komt

	-- De kop staat hier op 40px in plaats van de 64 van `.home-title`; verder hetzelfde:
	-- 700 zwaar en neon. Roblox kent geen letter-spacing, dus de -1px eromheen valt weg.
	local kop = UI.label(hero, "ACHIEVEMENTS", {
		size = 40, color = Theme.color.neon, font = Theme.font.uiBold,
	})
	kop.Size = UDim2.new(1, 0, 0, 40)   -- `.home-title` heeft line-height: 1, dus precies de tekstgrootte

	UI.label(hero, "\u{25BA} EARN THEM BY PLAYING \u{00B7} THEY SHOW NEXT TO YOUR NAME ON THE BOARD", {
		size = Theme.text.body, color = Theme.color.muted,
	})

	-- ---------- .season-strip ----------
	-- Dezelfde strip als in de lobby en de VIP-zone, uit Common: in de webversie tekent
	-- renderSeasonStrip() ze alle drie, dus hier ook één bouwer.
	local seizoen = Common.seasonStrip(blad)
	seizoen.frame.LayoutOrder = 2

	-- De strip zit in een vak dat de marge eronder draagt; de strip zelf groeit met zijn
	-- tekst mee en kan er dus niet zelf een padding onder krijgen.
	local stripMarge = Instance.new("Frame")
	stripMarge.Name = "SeasonGap"
	-- `.season-strip { margin-bottom: 26px }`. Dit vak staat tussen de strip en het blok
	-- eronder, en de lijst van het blad zet er aan beide kanten acht bij -- dat is de
	-- tussenruimte die hierboven op de kleinste marge is gezet. Blijft over: tien.
	stripMarge.Size = UDim2.new(1, 0, 0, 26 - BLAD_GAT * 2)
	stripMarge.BackgroundTransparency = 1
	stripMarge.LayoutOrder = 3
	stripMarge.Parent = blad

	local zetStrip = seizoen.zet

	-- ---------- .lb-grid: twee panelen naast elkaar ----------
	local tweeluik = Instance.new("Frame")
	tweeluik.Name = "LbGrid"
	tweeluik.Size = UDim2.new(1, 0, 0, 0)
	tweeluik.AutomaticSize = Enum.AutomaticSize.Y
	tweeluik.BackgroundTransparency = 1
	tweeluik.LayoutOrder = 4
	tweeluik.Parent = blad
	UI.padding4(tweeluik, 0, 0, 42, 0) -- margin-bottom: 50px
	-- `align-items: start`: de twee panelen zijn even breed maar niet even hoog.
	local tweeluikLijst = UI.list(tweeluik, 20, Enum.FillDirection.Horizontal)
	tweeluikLijst.VerticalAlignment = Enum.VerticalAlignment.Top

	local sprintVak = UI.panel(tweeluik, "LastSprint")
	sprintVak.Size = UDim2.new(0.5, -10, 0, 0)
	sprintVak.LayoutOrder = 1
	UI.list(sprintVak, 0)
	paneelKop(sprintVak, "\u{25BA} last sprint", "EVERY 3 DAYS")

	local sprintLijst = Instance.new("Frame")
	sprintLijst.Name = "Rows"
	sprintLijst.Size = UDim2.new(1, 0, 0, 0)
	sprintLijst.AutomaticSize = Enum.AutomaticSize.Y
	sprintLijst.BackgroundTransparency = 1
	sprintLijst.LayoutOrder = 2
	sprintLijst.Parent = sprintVak
	UI.list(sprintLijst, 0)

	-- De kop van de uitslag ("► SEASON 1 · SPRINT 2") staat er alleen als er een uitslag is.
	local sprintUitslagKop = UI.panelTitle(sprintLijst, "")
	sprintUitslagKop.LayoutOrder = 1
	sprintUitslagKop.Visible = false

	local sprintNotitie = notitie(sprintLijst,
		"No sprint has finished yet. The first result shows up as soon as this one is over.")
	sprintNotitie.LayoutOrder = 2

	-- ---------- #rankLadder ----------
	local ladderVak = UI.panel(tweeluik, "RankLadder")
	ladderVak.Size = UDim2.new(0.5, -10, 0, 0)
	ladderVak.LayoutOrder = 2
	UI.list(ladderVak, 0)
	paneelKop(ladderVak, "\u{25BA} what each place is worth", "TOP 10")

	local ladder = Instance.new("Frame")
	ladder.Name = "Rows"
	ladder.Size = UDim2.new(1, 0, 0, 0)
	ladder.AutomaticSize = Enum.AutomaticSize.Y
	ladder.BackgroundTransparency = 1
	ladder.LayoutOrder = 2
	ladder.Parent = ladderVak
	UI.list(ladder, 0)

	-- `.rank-row`: `grid-template-columns: 70px 130px 1fr` met 12 ertussen, padding 9px 4px.
	local RANG_NR, RANG_NAAM, RANG_GAT, RANG_PAD = 70, 130, 12, 4
	for i, r in RANGEN do
		local rij = Instance.new("Frame")
		rij.Name = "Rank" .. i
		rij.Size = UDim2.new(1, 0, 0, 35) -- 12px tekst, regelhoogte plus 9 boven en onder
		rij.BackgroundTransparency = 1
		rij.LayoutOrder = i
		rij.Parent = ladder
		streep(rij, Theme.color.border, 0.4) -- rgba(42,50,61,0.6)

		local nr = UI.label(rij, r.teken .. " #" .. i, {
			size = Theme.text.body, color = Theme.color.gold, font = Theme.font.num,
		})
		nr.Position = UDim2.fromOffset(RANG_PAD, 0)
		nr.Size = UDim2.new(0, RANG_NR, 1, 0)

		local naam = UI.label(rij, r.naam, {
			size = Theme.text.body, color = Theme.color.text, font = Theme.font.uiMed,
		})
		naam.Position = UDim2.fromOffset(RANG_PAD + RANG_NR + RANG_GAT, 0)
		naam.Size = UDim2.new(0, RANG_NAAM, 1, 0)

		local links = RANG_PAD + RANG_NR + RANG_GAT + RANG_NAAM + RANG_GAT
		local wat = UI.label(rij, r.wat, { size = Theme.text.tiny, color = Theme.color.muted })
		wat.Position = UDim2.fromOffset(links, 0)
		wat.Size = UDim2.new(1, -(links + RANG_PAD), 1, 0)
		wat.TextTruncate = Enum.TextTruncate.AtEnd
	end

	-- ---------- .section-heading ----------
	local achKop = Instance.new("Frame")
	achKop.Name = "AchHeading"
	achKop.Size = UDim2.new(1, 0, 0, Theme.lineBox(Theme.text.title) + 16)
	achKop.BackgroundTransparency = 1
	achKop.LayoutOrder = 5
	achKop.Parent = blad
	UI.padding4(achKop, 0, 0, 16, 0) -- margin-bottom: 24px
	local _, telling = UI.sectionHeading(achKop, "YOUR ACHIEVEMENTS", "0 / " .. #Ach.LIST)

	-- ---------- .ach-head > .ach-progress ----------
	local balkVak = Instance.new("Frame")
	balkVak.Name = "AchHead"
	balkVak.Size = UDim2.new(1, 0, 0, 8 + 10)
	balkVak.BackgroundTransparency = 1
	balkVak.LayoutOrder = 6
	balkVak.Parent = blad

	local balk = Instance.new("Frame")
	balk.Name = "Progress"
	balk.Size = UDim2.new(1, 0, 0, 8)
	balk.BackgroundColor3 = Theme.color.black
	balk.BackgroundTransparency = 0.5 -- rgba(0,0,0,0.5)
	balk.BorderSizePixel = 0
	balk.ClipsDescendants = true
	UI.corner(balk, 4)
	UI.stroke(balk, Theme.color.border)
	balk.Parent = balkVak

	local vulling = Instance.new("Frame")
	vulling.Name = "Fill"
	vulling.Size = UDim2.new(0, 0, 1, 0)
	vulling.BackgroundColor3 = Theme.color.neon
	vulling.BorderSizePixel = 0
	UI.corner(vulling, 4)
	-- `linear-gradient(90deg, var(--neon-dim), var(--neon))`
	UI.gradient(vulling, Theme.color.neonDim, Theme.color.neon, 0)
	vulling.Parent = balk

	-- Wat je hebt, en welke drie er op je profiel in de vakjes staan. Het rek gebruikt ze
	-- allebei: een behaalde kaart ziet er anders uit (`.ach-card.done`), en een die je laat
	-- zien zegt "SHOWN" (`.ach-card.shown`).
	local uitgelicht: { string } = {}
	local open: { [string]: number } = {}
	local zetUitgelicht: () -> ()

	-- ---------- .ach-grid ----------
	local rek = Instance.new("Frame")
	rek.Name = "AchGrid"
	rek.Size = UDim2.new(1, 0, 0, 0)
	rek.AutomaticSize = Enum.AutomaticSize.Y
	rek.BackgroundTransparency = 1
	rek.LayoutOrder = 8
	rek.Parent = blad
	local rekIndeling = Instance.new("UIGridLayout")
	rekIndeling.CellSize = UDim2.fromOffset(KAART_MIN, KAART_HOOG)
	rekIndeling.CellPadding = UDim2.fromOffset(KAART_GAT, KAART_GAT)
	rekIndeling.SortOrder = Enum.SortOrder.LayoutOrder
	rekIndeling.Parent = rek
	Common.rekKolommen(rek, rekIndeling, KAART_MIN, KAART_GAT, KAART_HOOG)

	-- De lucht onder het rek, uit `<div style="height: 40px">` onderaan de markup.
	local staart = Instance.new("Frame")
	staart.Name = "Tail"
	staart.Size = UDim2.new(1, 0, 0, 40)
	staart.BackgroundTransparency = 1
	staart.LayoutOrder = 9
	staart.Parent = blad

	type Kaartje = { knop: TextButton, rand: UIStroke, icoon: TextLabel, niveau: TextLabel }
	local kaartjes: { [string]: Kaartje } = {}

	-- `.ach-card`: `grid-template-columns: 40px 1fr auto` met 12 ertussen en padding 12/14.
	-- In Roblox is dat drie vaste plekken naast elkaar; de middelste krijgt wat overblijft.
	local ICOON_BREED, NIVEAU_BREED, KAART_PAD = 40, 48, 14
	local TEKST_LINKS = KAART_PAD + ICOON_BREED + KAART_GAT

	for _, a in Ach.LIST do
		-- Een knop en geen vak, want `.ach-card.pickable` is hier aanklikbaar: een badge die
		-- je hebt leg je ermee in een vrij vakje bovenaan.
		local knop = Instance.new("TextButton")
		knop.Name = a.id
		knop.Text = ""
		knop.BackgroundColor3 = Theme.color.black
		knop.BackgroundTransparency = 0.8 -- rgba(0,0,0,0.2), zoals een nog gesloten kaart
		knop.BorderSizePixel = 0
		knop.AutoButtonColor = false
		UI.corner(knop, Theme.radius.card)
		local rand = UI.stroke(knop, Theme.color.border)
		rand.Transparency = 0.3 -- rgba(42,50,61,0.7)
		knop.Parent = rek

		local icoon = UI.label(knop, "\u{1F512}", { size = 24, align = Enum.TextXAlignment.Center })
		-- `.ach-card .ach-icon { opacity: 0.5 }` geldt vanaf de eerste tekening, niet pas
		-- zodra het profiel binnen is; anders staan alle slotjes even fel te branden.
		icoon.TextTransparency = 0.5
		icoon.Position = UDim2.fromOffset(KAART_PAD, 0)
		icoon.Size = UDim2.new(0, ICOON_BREED, 1, 0)

		local tekstVak = Instance.new("Frame")
		tekstVak.Name = "Body"
		tekstVak.Position = UDim2.fromOffset(TEKST_LINKS, 10)
		tekstVak.Size = UDim2.new(1, -(TEKST_LINKS + KAART_GAT + NIVEAU_BREED + KAART_PAD), 1, -20)
		tekstVak.BackgroundTransparency = 1
		tekstVak.Parent = knop
		UI.list(tekstVak, 2)

		local kaartTitel = UI.label(tekstVak, a.title, {
			size = Theme.text.label, color = Theme.color.text, font = Theme.font.uiMed,
		})
		kaartTitel.Size = UDim2.new(1, 0, 0, 18)

		local uitleg = UI.label(tekstVak, a.desc, { size = Theme.text.tiny, color = Theme.color.muted })
		uitleg.Size = UDim2.new(1, 0, 0, 36)
		uitleg.TextWrapped = true
		uitleg.TextYAlignment = Enum.TextYAlignment.Top
		uitleg.LineHeight = 1.5

		local niveau = UI.label(knop, string.upper(a.tier), {
			size = Theme.text.tiny, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
		})
		niveau.Position = UDim2.new(1, -(KAART_PAD + NIVEAU_BREED), 0, 0)
		niveau.Size = UDim2.new(0, NIVEAU_BREED, 1, 0)

		kaartjes[a.id] = { knop = knop, rand = rand, icoon = icoon, niveau = niveau }
	end

	-- Hoe een kaartje eruitziet hangt van twee dingen af: heb je hem (`.ach-card.done`) en
	-- staat hij in een vakje hierboven (`.ach-card.shown`). Die twee door elkaar heen laten
	-- tekenen ging mis -- de een overschreef de rand van de ander -- dus doet één lus ze
	-- allebei, en roepen beide kanten die lus aan.
	local function zetKaarten(): ()
		for _, a in Ach.LIST do
			local k = kaartjes[a.id]
			if not k then continue end
			local heeft = open[a.id] ~= nil
			local n = NIVEAU[a.tier]
			k.icoon.Text = if heeft then a.icon else "\u{1F512}"
			-- `.ach-card .ach-icon { opacity: 0.5 }`: alleen het icoon dooft, de tekst niet.
			k.icoon.TextTransparency = if heeft then 0 else 0.5
			k.knop.BackgroundColor3 = if heeft then Theme.color.panelLight else Theme.color.black
			k.knop.BackgroundTransparency = if heeft then 0 else 0.8
			k.rand.Color = if heeft and n then n.kleur else Theme.color.border
			k.rand.Transparency = if heeft then (if n then n.doorzicht else 0) else 0.3
			-- Alleen goud krijgt in de CSS een gekleurd niveaulabel; zilver en brons blijven grijs.
			k.niveau.Text = string.upper(a.tier)
			k.niveau.TextColor3 = if heeft and a.tier == "gold" then Theme.color.gold else Theme.color.muted

			-- `.ach-card.shown`: een badge die in een vakje hierboven staat zegt niet zijn rang
			-- maar "shown", in het goud. De CSS zet er ook een gouden lijn binnenin
			-- (`box-shadow: inset 0 0 0 1px`); Roblox kent geen box-shadow, dus doet de rand
			-- van de kaart dat hier -- die lag toch al op de rand van het vak.
			if table.find(uitgelicht, a.id) then
				k.niveau.Text = "SHOWN"
				k.niveau.TextColor3 = Theme.color.gold
				k.rand.Color = Theme.color.gold
				k.rand.Transparency = 0
			end
		end
	end

	-- De sortering van achRender(): wat je hebt vooraan, daarbinnen goud voor zilver voor
	-- brons. Array.prototype.sort is in JavaScript stabiel, dus bij gelijke stand blijft de
	-- volgorde van ACHIEVEMENTS staan; table.sort is dat niet, vandaar PLEK als laatste
	-- vergelijking. Zonder die regel stond het rek op id op alfabet en dus in een heel
	-- andere volgorde dan de webversie.
	local function zetVolgorde(): ()
		local volgorde = table.clone(Ach.LIST)
		table.sort(volgorde, function(a, b)
			local ao, bo = open[a.id] ~= nil, open[b.id] ~= nil
			if ao ~= bo then return ao end
			local ar, br = RANG[a.tier] or 9, RANG[b.tier] or 9
			if ar ~= br then return ar < br end
			return PLEK[a.id] < PLEK[b.id]
		end)
		for i, a in volgorde do
			local k = kaartjes[a.id]
			if k then k.knop.LayoutOrder = i end
		end
	end

	-- Ook zonder profiel ligt het rek al op rang, net als achRender() dat meteen bij het
	-- eerste tekenen doet. De kaartjes zelf tekent zetUitgelicht() hieronder.
	zetVolgorde()

	-- Welke badges er in de vakjes op het profiel staan bepaalt hier alleen of een kaart
	-- "SHOWN" zegt; kiezen gebeurt daar.
	function zetUitgelicht()
		zetKaarten()
	end

	zetUitgelicht()

	-- ---------- de uitslag van de vorige sprint ----------
	-- `#seasonLast` toont in de webversie de uitslagen uit season_awards. Hier levert de
	-- server dezelfde gegevens als de ranglijst van de vorige sprint; de plek erin bepaalt
	-- precies zo de titel, en voor de winnaar de pas naar de VIP-zone.
	local function zetVorige(res: any)
		for _, k in sprintLijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		local top = if typeof(res) == "table" and typeof(res.top) == "table" then res.top else {}
		sprintUitslagKop.Visible = #top > 0
		sprintNotitie.Visible = #top == 0
		if #top == 0 then return end

		sprintUitslagKop.Text = "\u{25BA} " .. string.upper(tostring(res.label or ""))

		-- Alleen wie er echt iets aan overhoudt. De webversie loopt over `SEASON.awards`,
		-- en dat zijn de plaatsen waar een prijs aan hangt -- drie. Alle vijfentwintig
		-- rijen afdrukken zou nummer vier tot en met vijfentwintig vertellen dat ze een
		-- TITLE hebben gewonnen, en dat is niet zo.
		for i, plek in top do
			if i > #Season.PRIZES then break end
			local rang = tonumber(plek.rank) or i
			local r = RANGEN[math.clamp(rang, 1, #RANGEN)]

			-- `.lb-row`: `grid-template-columns: 28px 1fr auto`, padding 7px 6px, 11px tekst.
			local rij = Instance.new("Frame")
			rij.Name = "Row" .. i
			rij.Size = UDim2.new(1, 0, 0, 29)
			rij.BackgroundTransparency = 1
			rij.LayoutOrder = 2 + i
			rij.Parent = sprintLijst
			streep(rij, Color3.fromHex("1a3a1a"), 0.5) -- rgba(26,58,26,0.5)

			local teken = UI.label(rij, r.teken, {
				size = Theme.text.small, align = Enum.TextXAlignment.Center,
			})
			teken.Position = UDim2.fromOffset(6, 0)
			teken.Size = UDim2.new(0, 28, 1, 0)

			local naam = UI.label(rij, tostring(plek.name or "\u{2014}"), { size = Theme.text.small })
			naam.Position = UDim2.fromOffset(44, 0)
			naam.AutomaticSize = Enum.AutomaticSize.X
			naam.Size = UDim2.new(0, 0, 1, 0)

			-- `.lb-row .meta`: de naam van de plaats, zes pixels achter de spelersnaam.
			-- `nameSpan` zet hem er in de webversie ook achter.
			local plaats = UI.label(rij, r.naam, {
				size = Theme.text.small, color = Theme.color.muted,
			})
			plaats.AutomaticSize = Enum.AutomaticSize.X
			plaats.Size = UDim2.new(0, 0, 1, 0)
			naam:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				plaats.Position = UDim2.fromOffset(44 + naam.AbsoluteSize.X + 6, 0)
			end)
			plaats.Position = UDim2.fromOffset(44 + naam.AbsoluteSize.X + 6, 0)

			-- Een plek levert geen geld meer op; wat je eraan overhoudt is de titel, en voor
			-- de winnaar de pas naar de VIP-zone.
			local waarde = UI.label(rij, if rang == 1 then "VIP PASS" else "TITLE", {
				size = Theme.text.small, color = Theme.color.gold, font = Theme.font.num,
				align = Enum.TextXAlignment.Right,
			})
			waarde.Position = UDim2.new(1, -(90 + 6), 0, 0)
			waarde.Size = UDim2.new(0, 90, 1, 0)
		end
	end

	-- ---------- de klokken bij de server ophalen ----------
	local function ververs()
		local res = Common.call("Leaderboard")
		if typeof(res) == "table" then
			local sprint = tonumber(res.sprint) or Season.sprintId()
			zetStrip(sprint, tonumber(res.endsAt) or Season.sprintEndsAt(sprint),
				tonumber(res.seasonEndsAt) or Season.seasonEndsAt(Season.seasonId()),
				tonumber(res.sprintsLeft) or Season.sprintsLeft(), tonumber(res.now))
		end
		zetVorige(Common.call("Leaderboard", "previous"))
	end

	-- Meteen invullen uit het rekenwerk, zodat de strip niet leeg staat te wachten.
	local nuSprint = Season.sprintId()
	zetStrip(nuSprint, Season.sprintEndsAt(nuSprint), Season.seasonEndsAt(Season.seasonId()),
		Season.sprintsLeft(), nil)

	task.spawn(function()
		while true do
			ververs()
			task.wait(30)
		end
	end)

	-- ---------- het profiel binnenkrijgen ----------
	return function(p: any)
		if typeof(p) ~= "table" then return end
		open = if typeof(p.achievements) == "table" then p.achievements else {}
		uitgelicht = {}
		if typeof(p.featured) == "table" then
			for _, id in p.featured do
				if typeof(id) == "string" and Ach.BY_ID[id] and #uitgelicht < 3 then
					table.insert(uitgelicht, id)
				end
			end
		end
		-- zetUitgelicht() tekent ook de kaartjes, dus dit zet het rek in één keer goed.
		zetUitgelicht()
		zetVolgorde()

		local aantal = 0
		for _, a in Ach.LIST do
			if open[a.id] ~= nil then aantal += 1 end
		end

		telling.Text = aantal .. " / " .. #Ach.LIST
		vulling.Size = UDim2.fromScale(aantal / math.max(1, #Ach.LIST), 1)
	end
end

return Achievements
