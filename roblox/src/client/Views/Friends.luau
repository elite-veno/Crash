--!strict
-- Vrienden, zoals #friendsView in de webversie: geen aside maar een blad over de volle
-- breedte met de hero erboven, en daaronder `.lb-grid` -- twee kolommen naast elkaar.
-- Links ADD A FRIEND met REQUESTS en TABLE INVITES eronder, rechts YOUR FRIENDS met de
-- telling rechts in de paneelkop.
--
-- Onder die jas zit Roblox in plaats van Supabase, en dat is met opzet: de webversie moest
-- een eigen vriendentabel bijhouden, met verzoeken en RLS eromheen, omdat Supabase geen
-- vrienden kent. Roblox kent ze al, en heeft ook al privéservers. Wat dat per blok betekent:
--
--   * SEND REQUEST opent het uitnodigingsvenster van Roblox zelf (PromptGameInvite) in
--     plaats van friend_request. Een naam intikken kan hier niets worden -- het platform
--     gaat over wie er vrienden zijn -- dus het veld ernaast zegt dat, op precies de plek
--     waar je in de webversie zou typen.
--   * REQUESTS blijft als kop staan, maar een verzoek accepteer je in Roblox zelf.
--   * TABLE INVITES is de lijst tafels waar je heen kunt: je eigen gereserveerde server en
--     de publieke tafel, elk als rij met een knop rechts -- dezelfde vorm als een invite.
--   * REMOVE staat er in de :disabled-stand uit de CSS: een vriendschap die van Roblox is
--     kun je niet vanuit een spel opzeggen.
--
-- De aanroepen eronder zijn ongewijzigd: list, reserve, join en quick op het Friends-kanaal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Common = require(script.Parent.Common)

local Friends = {}

-- De maten uit `.fr-row`, `.fr-btn`, `.fr-dot` en `.lb-grid`.
local RIJ_PAD = 9       -- .fr-row padding: 9px 0
local RIJ_GAT = 10      -- .fr-row gap
local TEKST_HOOG = 34   -- .fr-name (12px) met .sub (10px) eronder, zoals UI.label ze neerzet
local RIJ_HOOG = RIJ_PAD * 2 + TEKST_HOOG
local STIP = 7          -- .fr-dot
local KNOP_TEKST = 10   -- .fr-btn font-size
local KNOP_HOOG = 24    -- 10px tekst met padding 6 boven en onder, plus de rand
local KNOP_PAD = 10     -- .fr-btn padding links en rechts
local VELD_HOOG = 40    -- het invoerveld, net als UI.numberBox er een neerzet
local KOLOM_GAT = 20    -- .lb-grid gap
local VELD_GAT = 8      -- .fr-add gap
local KNOP_BREED = 104  -- de breedte die de SEND REQUEST-knop op de pagina meet

-- `@media (max-width: 900px) { .lb-grid { grid-template-columns: 1fr } }` meet het venster,
-- niet het raster. Hier is alleen het raster te meten, dus trek eraf wat er in de webversie
-- links en om het raster heen staat: de balk (64) en de 50 padding aan weerszijden.
local SMAL = 900 - Theme.size.railWidth - Theme.size.homePadX * 2

-- Hoeveel ruimte de knoppen rechts in een rij krijgen. Roblox kent geen flex, dus de
-- naamkolom moet zelf weten hoeveel er naast hem staat: anders loopt een lange naam
-- onder de knoppen door.
local RUIMTE_VRIEND = 150 -- INVITE naast REMOVE
local RUIMTE_TAFEL = 80   -- één knop

-- .fr-btn: zwart met een rand, 10px, padding 6 om 10, radius 3. Bij hover wordt hij neon,
-- of rood als het een .fr-btn.danger is. De :hover:not(:disabled) uit de CSS zit in de
-- controle op Active: een uitgezette knop licht niet op.
local function frKnop(ouder: Instance, tekst: string, gevaar: boolean?): TextButton
	local b = Instance.new("TextButton")
	b.Name = "FrButton"
	b.Text = tekst
	b.Font = Theme.font.ui
	b.TextSize = KNOP_TEKST
	b.TextColor3 = Theme.color.text
	-- Staat er expliciet bij omdat de knop in `.fr-add` breder is dan zijn tekst: daar moet
	-- het opschrift midden in het vlak staan, zoals een knop in de browser dat ook doet.
	b.TextXAlignment = Enum.TextXAlignment.Center
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, KNOP_HOOG)
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b)
	UI.padding4(b, 0, KNOP_PAD, 0, KNOP_PAD)

	local aan = if gevaar then Theme.color.red else Theme.color.neon
	b.MouseEnter:Connect(function()
		if not b.Active then return end
		rand.Color = aan
		b.TextColor3 = aan
	end)
	b.MouseLeave:Connect(function()
		rand.Color = Theme.color.border
		b.TextColor3 = Theme.color.text
	end)
	b.Parent = ouder
	return b
end

type Rij = {
	vak: Frame,
	lijn: Frame,
	stip: Frame?,
	naam: TextLabel,
	onder: TextLabel,
	knoppen: Frame,
}

-- .fr-row: links een stip, dan de naam met zijn toestand eronder, en rechts de knoppen.
-- De lijn onderin is `border-bottom`; bij de laatste rij zet de aanroeper hem uit, want
-- dat is wat `.fr-row:last-child { border-bottom: 0 }` doet.
local function frRij(ouder: Instance, metStip: boolean, ruimte: number): Rij
	local vak = Instance.new("Frame")
	vak.Name = "FrRow"
	vak.Size = UDim2.new(1, 0, 0, RIJ_HOOG)
	vak.BackgroundTransparency = 1
	vak.Parent = ouder

	local lijn = Instance.new("Frame")
	lijn.Name = "Line"
	lijn.Size = UDim2.new(1, 0, 0, 1)
	lijn.Position = UDim2.new(0, 0, 1, -1)
	lijn.BackgroundColor3 = Theme.color.border
	lijn.BorderSizePixel = 0
	lijn.Parent = vak

	local stip: Frame? = nil
	local links = 0
	if metStip then
		local s = Instance.new("Frame")
		s.Name = "Dot"
		s.AnchorPoint = Vector2.new(0, 0.5)
		s.Position = UDim2.new(0, 0, 0.5, 0)
		s.Size = UDim2.fromOffset(STIP, STIP)
		s.BackgroundColor3 = Theme.color.border
		s.BorderSizePixel = 0
		UI.corner(s, STIP / 2) -- border-radius: 50%
		s.Parent = vak
		stip = s
		links = STIP + RIJ_GAT
	end

	local tekstVak = Instance.new("Frame")
	tekstVak.Name = "Name"
	tekstVak.AnchorPoint = Vector2.new(0, 0.5)
	tekstVak.Position = UDim2.new(0, links, 0.5, 0)
	tekstVak.Size = UDim2.new(1, -(links + ruimte), 0, TEKST_HOOG)
	tekstVak.BackgroundTransparency = 1
	tekstVak.Parent = vak
	UI.list(tekstVak, 0)

	-- .fr-name is 12px in de gewone tekstkleur, .fr-name .sub eronder 10px in muted.
	-- Roblox kent geen letter-spacing, dus de 0.4px van de sub valt weg.
	local naam = UI.label(tekstVak, "", { size = Theme.text.body })
	local onder = UI.label(tekstVak, "", { size = 10, color = Theme.color.muted })

	local knoppen = Instance.new("Frame")
	knoppen.Name = "Actions"
	knoppen.AnchorPoint = Vector2.new(1, 0.5)
	knoppen.Position = UDim2.new(1, 0, 0.5, 0)
	knoppen.Size = UDim2.new(0, 0, 0, KNOP_HOOG)
	knoppen.AutomaticSize = Enum.AutomaticSize.X
	knoppen.BackgroundTransparency = 1
	knoppen.Parent = vak
	local knopIndeling = UI.list(knoppen, RIJ_GAT, Enum.FillDirection.Horizontal)
	knopIndeling.HorizontalAlignment = Enum.HorizontalAlignment.Right
	knopIndeling.VerticalAlignment = Enum.VerticalAlignment.Center

	return { vak = vak, lijn = lijn, stip = stip, naam = naam, onder = onder, knoppen = knoppen }
end

-- .fr-empty: de regel die in de plaats van een lijst komt als er niets in staat. De padding
-- zit op een vakje eromheen en niet op het label zelf, want een UIPadding op een TextLabel
-- verschuift alleen de tekst binnen het label -- de regel eronder zou er dwars doorheen
-- komen te staan. Geeft dat vakje terug, zodat de aanroeper de hele regel aan en uit zet.
local function frLeeg(ouder: Instance, tekst: string): Frame
	local vak = Instance.new("Frame")
	vak.Name = "FrEmpty"
	vak.Size = UDim2.new(1, 0, 0, 0)
	vak.AutomaticSize = Enum.AutomaticSize.Y
	vak.BackgroundTransparency = 1
	vak.Parent = ouder
	UI.padding4(vak, 10, 0, 10, 0) -- padding: 10px 0

	local t = UI.label(vak, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
	t.TextWrapped = true
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Size = UDim2.new(1, 0, 0, 0)
	return vak
end

-- Een paneelkop met lucht erboven, zoals de tweede en derde `.panel-title` in de markup,
-- die daar `style="margin-top: 22px"` meekrijgen. Ook hier draagt een vakje de marge.
local function kopMetMarge(ouder: Instance, tekst: string): TextLabel
	local vak = Instance.new("Frame")
	vak.Name = "TitleGap"
	vak.Size = UDim2.new(1, 0, 0, Theme.text.small + 8 + 22)
	vak.BackgroundTransparency = 1
	vak.Parent = ouder
	UI.padding4(vak, 22, 0, 0, 0)
	return UI.panelTitle(vak, tekst)
end

function Friends.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)

	-- #friendsView heeft `padding: 40px 50px`, dezelfde ruime marge als de lobby. De schil
	-- geeft dit scherm er al viewPad van mee, dus hier komt alleen het verschil erbij.
	local marge = blad:FindFirstChildOfClass("UIPadding")
	if marge then
		local y = UDim.new(0, Theme.size.homePadY - Theme.size.viewPad)
		local x = UDim.new(0, Theme.size.homePadX - Theme.size.viewPad)
		marge.PaddingTop, marge.PaddingBottom = y, y
		marge.PaddingLeft, marge.PaddingRight = x, x
	end

	-- Er staan maar twee blokken op dit blad en de hero draagt zijn eigen marge, dus de
	-- lijst hoeft er niets bij te doen.
	local bladIndeling = blad:FindFirstChildOfClass("UIListLayout")
	if bladIndeling then bladIndeling.Padding = UDim.new(0, 0) end

	-- ---------- .home-hero ----------
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.BackgroundTransparency = 1
	hero.LayoutOrder = 1
	hero.Parent = blad
	UI.list(hero, 12) -- .home-title margin-bottom: 12px
	UI.padding4(hero, 0, 0, 30, 0) -- .home-hero hier `style="margin-bottom: 30px"`

	-- `.home-title` staat hier op 40px in plaats van de 64 van de lobby; 700 zwaar en neon.
	-- Roblox kent geen letter-spacing, dus de -1px eromheen valt weg.
	local kop = UI.label(hero, "FRIENDS", {
		size = 40, color = Theme.color.neon, font = Theme.font.uiBold,
	})
	-- `.home-title` heeft `line-height: 1`: de regel is precies zo hoog als de letter groot
	-- is, zonder lucht erboven of eronder. Zet het vak dus op de tekstgrootte zelf, anders
	-- zakt de kop en schuift alles eronder mee naar beneden.
	kop.Size = UDim2.new(1, 0, 0, 40)

	UI.label(hero, "\u{25BA} ADD PEOPLE BY NAME \u{00B7} INVITE THEM TO A PRIVATE TABLE", {
		size = Theme.text.body, color = Theme.color.muted,
	})

	-- ---------- .lb-grid: twee panelen naast elkaar ----------
	local raster = Instance.new("Frame")
	raster.Name = "Grid"
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.LayoutOrder = 2
	raster.Parent = blad
	local rasterIndeling = UI.list(raster, KOLOM_GAT, Enum.FillDirection.Horizontal)
	rasterIndeling.VerticalAlignment = Enum.VerticalAlignment.Top -- .lb-grid align-items: start

	local halfBreed = UDim2.new(0.5, -KOLOM_GAT / 2, 0, 0)

	local linksVak = UI.panel(raster, "AddPanel")
	linksVak.Size = halfBreed
	linksVak.LayoutOrder = 1
	UI.list(linksVak, 0) -- elk blok draagt zijn eigen marge, net als in de CSS

	local rechtsVak = UI.panel(raster, "ListPanel")
	rechtsVak.Size = halfBreed
	rechtsVak.LayoutOrder = 2
	UI.list(rechtsVak, 0)

	-- Bij een smal venster zet de CSS de twee kolommen onder elkaar; zie SMAL hierboven.
	local smalNu: boolean? = nil
	local function meet()
		local breed = raster.AbsoluteSize.X
		if breed <= 0 then return end
		local smal = breed < SMAL
		if smal == smalNu then return end
		smalNu = smal
		rasterIndeling.FillDirection =
			if smal then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
		local maat = if smal then UDim2.new(1, 0, 0, 0) else halfBreed
		linksVak.Size = maat
		rechtsVak.Size = maat
	end
	raster:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	-- ---------- links: ADD A FRIEND ----------
	UI.panelTitle(linksVak, "\u{25BA} ADD A FRIEND")

	-- `.fr-add`: het veld en de knop naast elkaar met 8 ertussen, en 4 lucht eronder.
	local toevoegRij = Instance.new("Frame")
	toevoegRij.Name = "FrAdd"
	toevoegRij.Size = UDim2.new(1, 0, 0, VELD_HOOG + 4)
	toevoegRij.BackgroundTransparency = 1
	toevoegRij.Parent = linksVak
	UI.padding4(toevoegRij, 0, 0, 4, 0) -- margin-bottom: 4px

	local verstuur = frKnop(toevoegRij, "SEND REQUEST")
	verstuur.AnchorPoint = Vector2.new(1, 0.5)
	verstuur.Position = UDim2.new(1, 0, 0.5, 0)
	-- `.fr-add` is een flexrij zonder `align-items`, dus stretch: de knop wordt hier even
	-- hoog als het veld ernaast, en niet het lage knopje dat een `.fr-btn` in een rij is.
	--
	-- En hij krijgt de breedte die hij op de pagina heeft in plaats van mee te groeien met
	-- zijn tekst. Daar is "SEND REQUEST" op 10px met 0.5 letter-spacing plus 10 padding aan
	-- weerszijden samen KNOP_BREED breed; de letter van Roblox is smaller en kent die
	-- letter-spacing niet, dus een knop die zijn tekst omsluit valt zichtbaar kleiner uit
	-- dan het origineel. Beter een vaste maat met de tekst erin gecentreerd.
	verstuur.AutomaticSize = Enum.AutomaticSize.None
	verstuur.Size = UDim2.fromOffset(KNOP_BREED, VELD_HOOG)

	-- Het veld waar je in de webversie een naam intikte. Hier valt er niets in te tikken:
	-- Roblox houdt de vriendenlijst bij, dus staat er in de jas van het invoerveld --
	-- zwart, rand, mono 16, radius 3 -- waarom dat zo is, in plaats van een veld dat je
	-- laat typen en daarna niets doet.
	local veld = Instance.new("Frame")
	veld.Name = "NameField"
	-- `.fr-add input { flex: 1 }`: het veld krijgt wat er naast de knop overblijft.
	veld.Size = UDim2.new(1, -(KNOP_BREED + VELD_GAT), 0, VELD_HOOG)
	veld.BackgroundColor3 = Theme.color.black
	veld.BackgroundTransparency = Theme.alpha.inputBg
	veld.BorderSizePixel = 0
	UI.corner(veld, Theme.radius.input)
	UI.stroke(veld)
	UI.padding4(veld, 10, 12, 10, 12)
	veld.Parent = toevoegRij

	local veldTekst = UI.label(veld, "roblox keeps this list", {
		size = Theme.text.input, color = Theme.color.muted, font = Theme.font.num,
	})
	veldTekst.Size = UDim2.fromScale(1, 1)

	-- .odds-note, met dezelfde regelafstand van 1.7.
	local uitleg = UI.label(linksVak, "They have to accept before you can invite them anywhere.", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	uitleg.TextWrapped = true
	uitleg.TextYAlignment = Enum.TextYAlignment.Top
	uitleg.AutomaticSize = Enum.AutomaticSize.Y
	uitleg.Size = UDim2.new(1, 0, 0, 0)
	uitleg.LineHeight = 1.7

	-- ---------- links: REQUESTS ----------
	kopMetMarge(linksVak, "\u{25BA} REQUESTS")
	frLeeg(linksVak, "Friend requests belong to Roblox: you send and accept them there.")

	-- ---------- links: TABLE INVITES ----------
	kopMetMarge(linksVak, "\u{25BA} TABLE INVITES")

	local tafels = Instance.new("Frame")
	tafels.Name = "Tables"
	tafels.Size = UDim2.new(1, 0, 0, 0)
	tafels.AutomaticSize = Enum.AutomaticSize.Y
	tafels.BackgroundTransparency = 1
	tafels.Parent = linksVak
	UI.list(tafels, 0)

	-- Een uitnodiging in de webversie was een rij met een tafel erin en JOIN ernaast. Hier
	-- zijn de tafels die van Roblox: je eigen gereserveerde server, en de publieke.
	local prive = frRij(tafels, false, RUIMTE_TAFEL)
	prive.naam.Text = "Your private table"
	prive.onder.Text = "a server only your invites reach"
	local priveKnop = frKnop(prive.knoppen, "OPEN")

	local publiek = frRij(tafels, false, RUIMTE_TAFEL)
	publiek.naam.Text = "The public table"
	publiek.onder.Text = "everyone who is online"
	publiek.lijn.Visible = false -- :last-child
	local publiekKnop = frKnop(publiek.knoppen, "JOIN")

	-- ---------- rechts: YOUR FRIENDS ----------
	-- `.lb-panel .panel-title` is een flexrij met space-between: de kop links, de telling
	-- rechts in muted.
	local kopRij = Instance.new("Frame")
	kopRij.Name = "ListTitle"
	kopRij.Size = UDim2.new(1, 0, 0, Theme.text.small + 8)
	kopRij.BackgroundTransparency = 1
	kopRij.Parent = rechtsVak
	UI.label(kopRij, "\u{25BA} YOUR FRIENDS", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
	})
	local teller = UI.label(kopRij, "", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
	})

	local lijst = Instance.new("Frame")
	lijst.Name = "FriendList"
	lijst.Size = UDim2.new(1, 0, 0, 0)
	lijst.AutomaticSize = Enum.AutomaticSize.Y
	lijst.BackgroundTransparency = 1
	lijst.Parent = rechtsVak
	UI.list(lijst, 0)

	-- Staat in de lijst zelf, net als in de webversie, en gaat uit zodra er rijen zijn.
	local leeg = frLeeg(lijst, "Nobody yet. Roblox only hands over your friends list if you let it.")

	-- ---------- wat de knoppen doen ----------
	-- Uitnodigen is het venster van Roblox zelf: wie je daar aantikt komt in jouw server
	-- terecht. Zowel SEND REQUEST als INVITE bij een vriend komen hier uit, want een
	-- uitnodiging per naam bestaat in Roblox niet.
	local function nodigUit()
		local ok, kan = pcall(function()
			return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
		end)
		if not ok or not kan then
			Common.toast("INVITES ARE NOT AVAILABLE HERE", "red")
			return
		end
		pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
	end

	verstuur.Activated:Connect(nodigUit)

	-- De eerste druk reserveert een server en brengt je er meteen heen; staat hij er
	-- eenmaal, dan is het een gewone JOIN naar dezelfde code.
	local heeftTafel = false
	priveKnop.Activated:Connect(function()
		if heeftTafel then
			Common.call("Friends", "join")
			return
		end
		local res = Common.call("Friends", "reserve")
		if not res then return end
		heeftTafel = true
		priveKnop.Text = "JOIN"
		prive.onder.Text = "ready \u{00B7} invite your friends once you are there"
		prive.onder.TextColor3 = Theme.color.neon
		Common.toast("OPENING YOUR TABLE", "green")
		task.wait(1)
		Common.call("Friends", "join")
	end)

	publiekKnop.Activated:Connect(function()
		Common.toast("BACK TO THE PUBLIC TABLE", nil)
		Common.call("Friends", "quick")
	end)

	-- ---------- vullen ----------
	local function vul()
		local res = Common.call("Friends", "list")
		if not res then return end

		-- Alleen de rijen weg; de lege regel staat er als vakje tussen en blijft staan.
		for _, k in lijst:GetChildren() do
			if k.Name == "FrRow" then k:Destroy() end
		end

		local rijen: { Rij } = {}
		for _, v in res.friends do
			local rij = frRij(lijst, true, RUIMTE_VRIEND)
			rij.naam.Text = v.displayName
			rij.onder.Text = if v.here then "at this table" else "elsewhere"

			-- `.fr-dot.on` heeft er ook een box-shadow omheen; die kent Roblox niet, dus
			-- blijft het bij de neonvulling.
			local stip = rij.stip
			if stip then
				stip.BackgroundColor3 = if v.here then Theme.color.neon else Theme.color.border
			end

			local nodig = frKnop(rij.knoppen, "INVITE")
			nodig.LayoutOrder = 1
			nodig.Activated:Connect(nodigUit)

			-- `.fr-btn:disabled`: zichtbaar maar uit. Een vriendschap is van Roblox, dus
			-- die zeg je daar op en niet hier.
			local weg = frKnop(rij.knoppen, "REMOVE", true)
			weg.LayoutOrder = 2
			UI.setEnabled(weg, false)

			table.insert(rijen, rij)
		end
		if #rijen > 0 then rijen[#rijen].lijn.Visible = false end

		local n = #rijen
		leeg.Visible = n == 0
		teller.Text = if n == 0 then "" elseif n == 1 then "1 FRIEND" else n .. " FRIENDS"

		-- De publieke tafel krijgt de telling die een invite in de webversie ook had:
		-- hoeveel spelers er nu aan zitten.
		local hier = #res.here
		publiek.onder.Text = (if hier == 1 then "1 player" else hier .. " players") .. " here right now"
	end

	task.spawn(function()
		while true do
			vul()
			task.wait(20)
		end
	end)
end

return Friends
