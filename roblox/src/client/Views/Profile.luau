--!strict
-- Profiel, zoals #profileView in de webversie: geen aside maar een blad over de volle
-- breedte, net als de lobby. Van boven naar beneden precies de volgorde uit profRender():
-- de hero met je naam en je titel, de drie uitgelichte badges, de erelijst met gewonnen
-- titels, TOTALS naast PER GAME, en dan de kop BADGES met het hele rek.
--
-- Dit scherm kijkt alleen: het toont wat de server stuurt. Badges oppakken en weer afleggen
-- doe je op het prestatiescherm, dat daar SetFeatured voor aanroept. Hier gaat geen enkele
-- aanroep naar de server -- de client rekent hier niets uit wat geld raakt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Ach = require(ReplicatedStorage.Shared.Achievements)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Profile = {}

-- GAMES uit de webversie: eerst de negen gewone spellen, dan de twee uit de VIP-zone. De
-- korte namen komen uit GAME_LABEL; die zijn daar korter dan op de homepagina (RACE, niet
-- HORSE RACE) omdat ze in een smalle kolom moeten passen.
local SPELLEN = {
	{ id = "crash", label = "CRASH" },
	{ id = "roulette", label = "ROULETTE" },
	{ id = "tower", label = "TOWER" },
	{ id = "mines", label = "MINES" },
	{ id = "plinko", label = "PLINKO" },
	{ id = "blackjack", label = "BLACKJACK" },
	{ id = "horse", label = "RACE" },
	{ id = "scratch", label = "SCRATCH" },
	{ id = "wheel", label = "WHEEL" },
	{ id = "slots", label = "777" },
	{ id = "bus", label = "BUS" },
}

-- De randkleuren van een behaalde badge, uit `.ach-card.done.<tier>` in de CSS. Let op dat
-- brons daar geen bruin is maar juist neongroen; zilver en goud spreken voor zich. De CSS
-- zet ze met rgba(), dus hier de kleur plus de doorzichtigheid die daarbij hoort.
local NIVEAU: { [string]: { kleur: Color3, doorzicht: number } } = {
	gold = { kleur = Color3.fromHex("e0b555"), doorzicht = 0.45 },   -- rgba(224,181,85,0.55)
	silver = { kleur = Color3.fromHex("c8d0dc"), doorzicht = 0.55 }, -- rgba(200,208,220,0.45)
	bronze = { kleur = Color3.fromHex("3ecf8e"), doorzicht = 0.60 }, -- rgba(62,207,142,0.4)
}

-- De sorteervolgorde van het rek: wat je hebt eerst, en daarbinnen goud voor zilver voor brons.
local RANG: { [string]: number } = { gold = 0, silver = 1, bronze = 2 }

-- De plek die een badge in Ach.LIST heeft. De webversie sorteert met Array.sort(), en die is
-- stabiel: badges van dezelfde rang houden daar de volgorde waarin ze in de lijst staan.
-- table.sort() in Luau is niet stabiel, dus die volgorde staat hier als laatste sleutel in
-- de vergelijking -- anders wisselt het rek van indeling bij elk profiel dat binnenkomt.
local PLEK: { [string]: number } = {}
for i, a in Ach.LIST do
	PLEK[a.id] = i
end

-- Het rek op volgorde: behaald voor niet-behaald, goud voor zilver voor brons, en daarbinnen
-- de volgorde uit de lijst. Precies de sortering uit profRender().
local function opVolgorde(open: { [string]: any })
	local rij = table.clone(Ach.LIST)
	table.sort(rij, function(a, b)
		local ao, bo = open[a.id] ~= nil, open[b.id] ~= nil
		if ao ~= bo then return ao end
		local ar, br = RANG[a.tier] or 9, RANG[b.tier] or 9
		if ar ~= br then return ar < br end
		return (PLEK[a.id] or 0) < (PLEK[b.id] or 0)
	end)
	return rij
end

-- `.ach-grid` is `repeat(auto-fill, minmax(260px, 1fr))` met 12 ertussen: de 260 is een
-- bodem, en de kolommen die passen rekken daarna de rij vol. Roblox kent die regel niet,
-- dus `rekKolommen` rekent het uit -- net als bij het spelraster op het beginscherm.
--
-- De hoogte is de padding van 12 boven en onder om een vak van 51: nagemeten op de site,
-- waar de kaarten 87 pixels uit elkaar staan met 12 ertussen.
local KAART_MIN = 260
local KAART_HOOG = 75
local KAART_GAT = 12

local function bedrag(n: number): string
	return (if n >= 0 then "+$" else "-$") .. Money.fmt(math.abs(n))
end

function Profile.build(ouder: Instance): (any) -> ()
	local blad = Common.sheet(ouder)

	-- #profileView heeft `padding: 40px 50px`, dezelfde ruime marge als de lobby. De schil
	-- geeft dit scherm er al viewPad van mee, dus hier komt alleen het verschil er nog bij.
	local marge = blad:FindFirstChildOfClass("UIPadding")
	if marge then
		local y = UDim.new(0, Theme.size.homePadY - Theme.size.viewPad)
		local x = UDim.new(0, Theme.size.homePadX - Theme.size.viewPad)
		marge.PaddingTop, marge.PaddingBottom = y, y
		marge.PaddingLeft, marge.PaddingRight = x, x
	end

	-- De marges tussen de blokken verschillen in de CSS (26, 22, 8, 24). Eén UIListLayout
	-- kent maar één tussenruimte, dus staat die op de kleinste en krijgt elk blok de rest
	-- als padding aan zijn onderkant mee.
	local lijst = blad:FindFirstChildOfClass("UIListLayout")
	if lijst then lijst.Padding = UDim.new(0, 8) end

	-- ---------- .home-hero ----------
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.BackgroundTransparency = 1
	hero.LayoutOrder = 1
	hero.Parent = blad
	UI.list(hero, 12)
	UI.padding4(hero, 0, 0, 18, 0) -- margin-bottom: 26px, waarvan 8 uit de lijst komt

	-- `#profName` staat op 40px in plaats van de 64 van de lobby; `.home-title` is 700 zwaar
	-- en neon. Roblox kent geen letter-spacing, dus de -1px eromheen valt weg.
	local naam = UI.label(hero, Players.LocalPlayer.DisplayName, {
		size = 40, color = Theme.color.neon, font = Theme.font.uiBold,
	})
	naam.Size = UDim2.new(1, 0, 0, 40) -- `.home-title` heeft line-height: 1, dus precies de tekstgrootte

	-- `.home-subtitle`: grijs zolang je geen titel hebt, goud zodra je er een gewonnen hebt.
	local titel = UI.label(hero, "No title yet", {
		size = Theme.text.body, color = Theme.color.muted,
	})

	-- ---------- .prof-featured ----------
	local etalage = Instance.new("Frame")
	etalage.Name = "Featured"
	etalage.Size = UDim2.new(1, 0, 0, 92 + 14)
	etalage.BackgroundTransparency = 1
	etalage.LayoutOrder = 2
	etalage.Parent = blad
	UI.list(etalage, KAART_GAT, Enum.FillDirection.Horizontal)
	UI.padding4(etalage, 0, 0, 14, 0) -- margin-bottom: 22px

	type Vakje = { vak: Frame, rand: UIStroke, icoon: TextLabel, naam: TextLabel }
	local vakjes: { Vakje } = {}

	for i = 1, 3 do
		local vak = Instance.new("Frame")
		vak.Name = "Slot" .. i
		-- Drie gelijke kolommen: `auto-fit, minmax(150px, 1fr)` met 12 ertussen.
		vak.Size = UDim2.new(1 / 3, -(KAART_GAT * 2 / 3), 0, 92)
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = 0.8 -- rgba(0,0,0,0.2)
		vak.BorderSizePixel = 0
		vak.LayoutOrder = i
		UI.corner(vak, Theme.radius.pill)
		-- Een leeg vakje heeft in de CSS `border: 1px dashed`. UIStroke kan alleen doorlopend,
		-- dus staat hij hier half doorzichtig: een streepjeslijn dekt ook maar de helft van de
		-- rand, en zo blijft het verschil met een gevuld (doorgetrokken) vakje zichtbaar.
		local rand = UI.stroke(vak, Theme.color.border)
		rand.Transparency = 0.45
		UI.padding4(vak, 18, 12, 18, 12)
		vak.Parent = etalage
		local binnen = UI.list(vak, 6)
		binnen.HorizontalAlignment = Enum.HorizontalAlignment.Center
		binnen.VerticalAlignment = Enum.VerticalAlignment.Center

		local icoon = UI.label(vak, "\u{2014}", {
			size = 30, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
		})
		icoon.Size = UDim2.new(1, 0, 0, 34)
		-- De webversie zet hier "empty" op andermans profiel en "pick a badge below" op dat
		-- van jezelf. Dit scherm is altijd dat van jezelf, dus altijd die tweede.
		local badgeNaam = UI.label(vak, "pick a badge below", {
			size = Theme.text.body, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
		})

		vakjes[i] = { vak = vak, rand = rand, icoon = icoon, naam = badgeNaam }
	end

	-- ---------- de erelijst met gewonnen titels ----------
	-- Staat er alleen als je er een hebt; in de webversie wordt het paneel dan niet gebouwd.
	local erelijst = UI.panel(blad, "Titles")
	erelijst.LayoutOrder = 3
	erelijst.Visible = false
	UI.list(erelijst, 6)
	UI.panelTitle(erelijst, "\u{25BA} titles won")
	local titelRij = Instance.new("Frame")
	titelRij.Name = "Chips"
	titelRij.Size = UDim2.new(1, 0, 0, 0)
	titelRij.AutomaticSize = Enum.AutomaticSize.Y
	titelRij.BackgroundTransparency = 1
	titelRij.Parent = erelijst
	local titelIndeling = UI.list(titelRij, 6, Enum.FillDirection.Horizontal)
	titelIndeling.Wraps = true

	-- ---------- .prof-grid: TOTALS naast PER GAME ----------
	local TOTALEN_REGELS = 7

	-- Hoe hoog de rij moet zijn om zoveel regels te laten passen: de padding van .panel,
	-- de paneelkop met zijn marge, en dan de regels van .stats-grid met 6 ertussen.
	local function rijHoogte(aantal: number): number
		local regelH = 14 -- zoals Common.statRow er een neerzet: .stat-row bij line-height 1
		local kopH = Theme.text.small + 8   -- zoals UI.panelTitle
		return Theme.size.panelPad * 2 + kopH + 6 + aantal * regelH + math.max(0, aantal - 1) * 6
	end

	local cijfers = Instance.new("Frame")
	cijfers.Name = "ProfGrid"
	-- TOTALS heeft zeven regels; die bepalen de hoogte tot er een profiel binnenkomt met
	-- meer regels aan de PER GAME-kant.
	cijfers.Size = UDim2.new(1, 0, 0, rijHoogte(TOTALEN_REGELS))
	cijfers.BackgroundTransparency = 1
	cijfers.LayoutOrder = 4
	cijfers.Parent = blad
	UI.list(cijfers, KAART_GAT, Enum.FillDirection.Horizontal)

	-- Een paneel van de halve breedte dat de rij helemaal vult. Beide panelen zitten in de
	-- CSS in één grid-rij en zijn daarom even hoog; Roblox rekt een paneel niet mee, dus
	-- de hoogte staat op de rij en de panelen volgen hem.
	local function halfPaneel(naamVanVak: string, kop: string, volgorde: number): Frame
		local vak = UI.panel(cijfers, naamVanVak)
		vak.AutomaticSize = Enum.AutomaticSize.None
		vak.Size = UDim2.new(0.5, -(KAART_GAT / 2), 1, 0)
		vak.LayoutOrder = volgorde
		UI.list(vak, 6)
		UI.panelTitle(vak, kop)
		local regels = Instance.new("Frame")
		regels.Name = "Rows"
		regels.Size = UDim2.new(1, 0, 0, 0)
		regels.AutomaticSize = Enum.AutomaticSize.Y
		regels.BackgroundTransparency = 1
		regels.Parent = vak
		UI.list(regels, 6) -- .stats-grid gap: 6px
		return regels
	end

	local totalenRegels = halfPaneel("Totals", "\u{25BA} totals", 1)
	local saldo = Common.statRow(totalenRegels, "BALANCE", "$" .. Money.fmt(Money.START))
	saldo.TextColor3 = Theme.color.neon
	local rondes = Common.statRow(totalenRegels, "ROUNDS", "0")
	local gewonnen = Common.statRow(totalenRegels, "WON", "0")
	gewonnen.TextColor3 = Theme.color.neon
	local verloren = Common.statRow(totalenRegels, "LOST", "0")
	verloren.TextColor3 = Theme.color.red
	local verhouding = Common.statRow(totalenRegels, "WIN / LOSS", "0.00")
	verhouding.TextColor3 = Theme.color.gold
	local winst = Common.statRow(totalenRegels, "PROFIT", "+$0.00")
	winst.TextColor3 = Theme.color.neon
	local badgeTeller = Common.statRow(totalenRegels, "BADGES", "0 / " .. #Ach.LIST)
	badgeTeller.TextColor3 = Theme.color.gold
	local perSpelRegels = halfPaneel("PerGame", "\u{25BA} per game", 2)

	-- Zet er meteen de regel neer die de webversie toont als je nog niets gespeeld hebt,
	-- zodat het paneel geen leeg vlak is voordat het eerste profiel binnen is.
	local function leegPerSpel(): TextLabel
		local leeg = Common.statRow(perSpelRegels, "\u{2014}", "no rounds played yet")
		leeg.TextColor3 = Theme.color.muted
		return leeg
	end
	leegPerSpel()

	-- ---------- .section-heading + .ach-grid ----------
	local badgeKop = Instance.new("Frame")
	badgeKop.Name = "BadgesHeading"
	badgeKop.Size = UDim2.new(1, 0, 0, 30 + 16)
	badgeKop.BackgroundTransparency = 1
	badgeKop.LayoutOrder = 5
	badgeKop.Parent = blad
	UI.padding4(badgeKop, 0, 0, 16, 0) -- margin-bottom: 24px
	-- Ook hier de tekst van je eigen profiel: de telling "n EARNED" hoort bij dat van een
	-- ander, en dat bestaat hier niet.
	UI.sectionHeading(badgeKop, "BADGES",
		"CLICK TO SHOW UP TO THREE \u{00B7} CLICK A SLOT ABOVE TO REMOVE")

	local rek = Instance.new("Frame")
	rek.Name = "AchGrid"
	rek.Size = UDim2.new(1, 0, 0, 0)
	rek.AutomaticSize = Enum.AutomaticSize.Y
	rek.BackgroundTransparency = 1
	rek.LayoutOrder = 6
	rek.Parent = blad
	local rekIndeling = Instance.new("UIGridLayout")
	rekIndeling.CellSize = UDim2.fromOffset(KAART_MIN, KAART_HOOG)
	rekIndeling.CellPadding = UDim2.fromOffset(KAART_GAT, KAART_GAT)
	rekIndeling.SortOrder = Enum.SortOrder.LayoutOrder
	rekIndeling.Parent = rek
	Common.rekKolommen(rek, rekIndeling, KAART_MIN, KAART_GAT, KAART_HOOG)

	type Kaartje = { vak: Frame, rand: UIStroke, icoon: TextLabel, niveau: TextLabel }
	local kaartjes: { [string]: Kaartje } = {}

	-- `.ach-card`: `grid-template-columns: 40px 1fr auto` met 12 ertussen en padding 12/14.
	-- In Roblox is dat drie vaste plekken naast elkaar; de middelste krijgt wat overblijft.
	local ICOON_BREED, NIVEAU_BREED, KAART_PAD = 40, 48, 14
	local TEKST_LINKS = KAART_PAD + ICOON_BREED + KAART_GAT

	-- Meteen op volgorde bouwen met nog niets behaald, want zo staat het rek er in de webversie
	-- ook bij: goud bovenaan. Anders staat het rek in de rauwe lijstvolgorde totdat het eerste
	-- profiel binnen is, en dat springt zichtbaar om.
	for i, a in opVolgorde({}) do
		local vak = Instance.new("Frame")
		vak.Name = a.id
		vak.LayoutOrder = i
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = 0.8 -- rgba(0,0,0,0.2), zoals een nog gesloten kaart
		vak.BorderSizePixel = 0
		UI.corner(vak, Theme.radius.card)
		local rand = UI.stroke(vak, Theme.color.border)
		rand.Transparency = 0.3 -- rgba(42,50,61,0.7)
		vak.Parent = rek

		local icoon = UI.label(vak, "\u{1F512}", { size = 24, align = Enum.TextXAlignment.Center })
		icoon.Position = UDim2.fromOffset(KAART_PAD, 0)
		icoon.Size = UDim2.new(0, ICOON_BREED, 1, 0)

		local tekstVak = Instance.new("Frame")
		tekstVak.Name = "Body"
		tekstVak.Position = UDim2.fromOffset(TEKST_LINKS, 10)
		tekstVak.Size = UDim2.new(1, -(TEKST_LINKS + KAART_GAT + NIVEAU_BREED + KAART_PAD), 1, -20)
		tekstVak.BackgroundTransparency = 1
		tekstVak.Parent = vak
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

		local niveau = UI.label(vak, string.upper(a.tier), {
			size = Theme.text.tiny, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
		})
		niveau.Position = UDim2.new(1, -(KAART_PAD + NIVEAU_BREED), 0, 0)
		niveau.Size = UDim2.new(0, NIVEAU_BREED, 1, 0)

		kaartjes[a.id] = { vak = vak, rand = rand, icoon = icoon, niveau = niveau }
	end

	-- Het profiel binnenkrijgen en alles bijwerken.
	return function(p: any)
		if typeof(p) ~= "table" then return end
		local open = if typeof(p.achievements) == "table" then p.achievements else {}

		-- ---------- hero ----------
		local mijnTitel = if typeof(p.title) == "string" and p.title ~= "" then p.title else nil
		titel.Text = if mijnTitel then Season.titleLabel(mijnTitel) else "No title yet"
		titel.TextColor3 = if mijnTitel then Theme.color.gold else Theme.color.muted

		-- ---------- de drie vakjes ----------
		local uitgelicht: { string } = {}
		if typeof(p.featured) == "table" then
			for _, id in p.featured do
				if typeof(id) == "string" and Ach.BY_ID[id] and #uitgelicht < 3 then
					table.insert(uitgelicht, id)
				end
			end
		end
		for i, v in vakjes do
			local a = if uitgelicht[i] then Ach.BY_ID[uitgelicht[i]] else nil
			if a then
				local n = NIVEAU[a.tier]
				v.icoon.Text = a.icon
				v.icoon.TextColor3 = Theme.color.text
				v.naam.Text = a.title
				v.naam.TextColor3 = Theme.color.text
				v.naam.Font = Theme.font.uiMed
				v.vak.BackgroundColor3 = Theme.color.panelLight
				v.vak.BackgroundTransparency = 0
				v.rand.Color = if n then n.kleur else Theme.color.border
				v.rand.Transparency = if n then n.doorzicht else 0
			else
				v.icoon.Text = "\u{2014}"
				v.icoon.TextColor3 = Theme.color.muted
				v.naam.Text = "pick a badge below"
				v.naam.TextColor3 = Theme.color.muted
				v.naam.Font = Theme.font.ui
				v.vak.BackgroundColor3 = Theme.color.black
				v.vak.BackgroundTransparency = 0.8
				v.rand.Color = Theme.color.border
				v.rand.Transparency = 0.45 -- weer de gestreepte rand van een leeg vakje
			end
		end

		-- ---------- de erelijst ----------
		for _, k in titelRij:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		local titels = if typeof(p.titles) == "table" then p.titles else {}
		erelijst.Visible = #titels > 0
		-- De webversie toont de laatste twaalf, nieuwste eerst.
		for i = #titels, math.max(1, #titels - 11), -1 do
			if typeof(titels[i]) == "string" then
				UI.tag(titelRij, "\u{1F3C6} " .. Season.titleLabel(titels[i]), Theme.color.gold)
			end
		end

		-- ---------- TOTALS ----------
		local w = tonumber(p.won) or 0
		local l = tonumber(p.lost) or 0
		local nettoWinst = tonumber(p.profit) or 0
		saldo.Text = "$" .. Money.fmt(tonumber(p.balance) or 0)
		rondes.Text = string.format("%d", tonumber(p.rounds) or 0)
		gewonnen.Text = string.format("%d", w)
		verloren.Text = string.format("%d", l)
		-- Delen door minstens één, precies zoals in de webversie: zonder verliezen zou de
		-- verhouding anders oneindig zijn.
		verhouding.Text = string.format("%.2f", w / math.max(1, l))
		winst.Text = bedrag(nettoWinst)
		winst.TextColor3 = if nettoWinst >= 0 then Theme.color.neon else Theme.color.red

		local aantalOpen = 0
		for _, a in Ach.LIST do
			if open[a.id] ~= nil then aantalOpen += 1 end
		end
		badgeTeller.Text = aantalOpen .. " / " .. #Ach.LIST

		-- ---------- PER GAME ----------
		for _, k in perSpelRegels:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		local stats = if typeof(p.stats) == "table" then p.stats else {}
		local getoond = 0
		for _, spel in SPELLEN do
			local s = stats[spel.id]
			local r = if typeof(s) == "table" then tonumber(s.rounds) or 0 else 0
			if r > 0 then
				getoond += 1
				local sw = if typeof(s) == "table" then tonumber(s.profit) or 0 else 0
				local regel = Common.statRow(perSpelRegels, spel.label,
					r .. " \u{00B7} " .. bedrag(sw))
				regel.TextColor3 = if sw >= 0 then Theme.color.neon else Theme.color.red
			end
		end
		if getoond == 0 then
			leegPerSpel()
			getoond = 1
		end
		cijfers.Size = UDim2.new(1, 0, 0, rijHoogte(math.max(TOTALEN_REGELS, getoond)))

		-- ---------- het rek met badges ----------
		-- Wat je hebt staat vooraan, daarbinnen goud voor zilver voor brons -- dezelfde
		-- sortering als profRender(). De volgorde zet ik op LayoutOrder, dan hoeft er geen
		-- kaartje verplaatst te worden.
		for i, a in opVolgorde(open) do
			local k = kaartjes[a.id]
			if not k then continue end
			k.vak.LayoutOrder = i
			local heeft = open[a.id] ~= nil
			local n = NIVEAU[a.tier]
			k.icoon.Text = if heeft then a.icon else "\u{1F512}"
			-- `.ach-card .ach-icon { opacity: 0.5 }`: alleen het icoon dooft, de tekst niet.
			k.icoon.TextTransparency = if heeft then 0 else 0.5
			k.vak.BackgroundColor3 = if heeft then Theme.color.panelLight else Theme.color.black
			k.vak.BackgroundTransparency = if heeft then 0 else 0.8
			k.rand.Color = if heeft and n then n.kleur else Theme.color.border
			k.rand.Transparency = if heeft then (if n then n.doorzicht else 0) else 0.3
			-- Alleen goud krijgt in de CSS een gekleurd niveaulabel; zilver en brons blijven grijs.
			k.niveau.Text = string.upper(a.tier)
			k.niveau.TextColor3 = if heeft and a.tier == "gold" then Theme.color.gold else Theme.color.muted

			-- `.ach-card.shown`: een badge die je in een vakje hierboven hebt staan zegt niet zijn
			-- rang maar "shown", in het goud. De CSS zet er ook een gouden lijn binnenin
			-- (`box-shadow: inset 0 0 0 1px`); Roblox kent geen box-shadow, dus doet de rand van
			-- de kaart dat hier -- die lag toch al op de rand van het vak.
			if table.find(uitgelicht, a.id) then
				k.niveau.Text = "SHOWN"
				k.niveau.TextColor3 = Theme.color.gold
				k.rand.Color = Theme.color.gold
				k.rand.Transparency = 0
			end
		end
	end
end

return Profile
