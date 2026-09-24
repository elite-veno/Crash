--!strict
-- Blackjack: zes stapels, dealer pakt bij tot 17. De dichte kaart van de dealer staat hier
-- niet in het geheugen van de client -- die komt pas over als de dealer speelt.
--
-- Het beeld komt regel voor regel uit `#blackjackView` in de markup en uit het blok
-- "Blackjack" in de CSS. Het bord is `.bj-table`: een kolom van hoogstens 720 breed met 22
-- pixels lucht, met bovenin de hand van de dealer, daaronder de regel `.bj-message` en
-- daaronder je eigen hand. Elk kopje is een `.hand-label` met een pilletje (`.val`) waar de
-- stand in staat; achter YOU staat de inzet in goud.
--
-- Links staan het inzetveld, DEAL en de drie knoppen van `.bj-actions` in één `.panel`,
-- daarna STATISTICS en dan RULES -- precies de volgorde van de markup. De knoppen
-- verdwijnen niet als je niet aan zet bent, ze gaan uit, net als in de webversie.
--
-- De dubbele inzet wordt er overal bij gezet ("DOUBLED"), want zonder dat leek het alsof
-- je bij een gedubbelde hand te weinig kreeg. Het bedrag klopte altijd; wat ontbrak was
-- dat het scherm liet zien waar het over ging.
--
-- Wat Roblox niet heeft: letter-spacing (0.8px op `.hand-label` en `.bj-message`), de
-- box-shadow onder een kaart, en het herhalende verloop van de kaartrug -- die is hieronder
-- nagemaakt met losse balkjes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Blackjack = {}

type Kaart = { r: string, s: string }

-- ---------- maten uit de CSS ----------
local TAFEL_B = 720        -- .bj-table max-width
local TAFEL_GAT = 22       -- .bj-table gap
local HAND_GAT = 8         -- .hand gap
local LABEL_GAT = 12       -- .hand-label gap
local PIL_MIN = 32         -- .hand-label .val min-width
local PIL_H = 20           -- 11px tekst (regel 14) met padding 2 en rand 1 boven en onder
local KAART_B = 66         -- .card width
local KAART_H = 96         -- .card height
local KAART_GAT = 8        -- .cards gap
local KAARTEN_H = 100      -- .cards min-height
local RUG_RAND = 4         -- .card.back border: 4px solid
local RUG_BAND = 6         -- de bandbreedte uit het repeating-linear-gradient
local BERICHT_H = 32       -- .bj-message min-height
local ACTIE_GAT = 6        -- .bj-actions gap
local ACTIE_MARGE = 8      -- .bj-actions margin-top
local ACTIE_H = 40         -- .btn-secondary: 11px tekst (regel 14), padding 12 en rand 1
-- Boven DEAL zit twee keer lucht: de margin-bottom van de `.field-group` met het inzetveld
-- en de margin-top van `.btn-primary` zelf. Samen 22, en dat is meer dan de 6 die de lijst
-- van het paneel ertussen zet -- vandaar dat de knop hier in een eigen vakje hangt.
local DEAL_MARGE = 8       -- .btn-primary { margin-top: 8px }; de 14 van de
                           -- `.field-group` erboven draagt die groep zelf

-- .btn-primary:disabled is opacity 0.6 en .btn-secondary:disabled 0.35. UI.setEnabled kent
-- dat verschil niet en dimt alles even hard, dus DEAL wordt hier zelf gezet.
local DEAL_DOF = 0.4       -- 1 - 0.6

-- De kleuren van een speelkaart staan in de CSS als losse hex in `.card` en `.card.back`,
-- niet als variabele. Ze horen dus hier en niet in het Theme; Theme.color.card is een tint
-- ernaast en wordt door de andere kaartspellen gebruikt.
local KAART_WIT = Color3.fromHex("fdfdf5")
local KAART_INKT = Color3.fromHex("151515")
local KAART_ROOD = Color3.fromHex("c8102e")
local RUG_DONKER = Color3.fromHex("0b3d1f")
local RUG_LICHT = Color3.fromHex("14602f")

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .card: 66 bij 96, wit, de rang linksboven en het teken rechtsonder. Harten en ruiten zijn
-- rood. De box-shadow onder de kaart kan Roblox niet en is weggelaten.
local function kaartVlak(ouder: Instance, kaart: Kaart, volgorde: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Card"
	f.Size = UDim2.fromOffset(KAART_B, KAART_H)
	f.LayoutOrder = volgorde
	f.BackgroundColor3 = KAART_WIT
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.card)
	f.Parent = ouder

	local rood = kaart.s == "\u{2665}" or kaart.s == "\u{2666}"
	local kleur = if rood then KAART_ROOD else KAART_INKT

	-- .card .rank { top: 6px; left: 8px; font-size: 18px }
	local rang = UI.label(f, kaart.r, {
		size = 18, color = kleur, font = Theme.font.num, name = "Rank",
	})
	rang.Position = UDim2.fromOffset(8, 6)
	rang.Size = UDim2.fromOffset(0, 22)
	rang.AutomaticSize = Enum.AutomaticSize.X

	-- .card .suit { bottom: 4px; right: 8px; font-size: 28px }
	local teken = UI.label(f, kaart.s, {
		size = 28, color = kleur, font = Theme.font.num, align = Enum.TextXAlignment.Right,
		name = "Suit",
	})
	teken.AnchorPoint = Vector2.new(1, 1)
	teken.Position = UDim2.new(1, -8, 1, -4)
	teken.Size = UDim2.fromOffset(0, 34)
	teken.AutomaticSize = Enum.AutomaticSize.X
	return f
end

-- .card.back: schuine strepen achter een witte rand van vier. Die rand zit in de CSS
-- binnen de 66 bij 96 (box-sizing: border-box), dus het is hier een wit vlak met een groen
-- vlak van vier pixels kleiner erin.
--
-- Roblox kent geen repeating-linear-gradient. De strepen zijn daarom balkjes van 6 breed
-- die schuin staan, met 6 ertussen; het groene vlak snijdt af wat erbuiten valt.
local function rugVlak(ouder: Instance, volgorde: number): Frame
	local f = Instance.new("Frame")
	f.Name = "CardBack"
	f.Size = UDim2.fromOffset(KAART_B, KAART_H)
	f.LayoutOrder = volgorde
	f.BackgroundColor3 = KAART_WIT
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.card)
	f.Parent = ouder

	local binnen = Instance.new("Frame")
	binnen.Name = "Pattern"
	binnen.Position = UDim2.fromOffset(RUG_RAND, RUG_RAND)
	binnen.Size = UDim2.new(1, -RUG_RAND * 2, 1, -RUG_RAND * 2)
	binnen.BackgroundColor3 = RUG_DONKER
	binnen.BorderSizePixel = 0
	binnen.ClipsDescendants = true
	UI.corner(binnen, Theme.radius.card - RUG_RAND)
	binnen.Parent = f

	local breedte = KAART_B - RUG_RAND * 2
	local hoogte = KAART_H - RUG_RAND * 2
	local lengte = breedte + hoogte                 -- lang genoeg om er schuin overheen te lopen
	-- Dwars op een streep van 45 graden telt alleen de helft van de stap mee, dus om 6 om 6
	-- te krijgen staan de balkjes wortel twee keer zo ver uit elkaar.
	local stap = RUG_BAND * 2 * math.sqrt(2)
	local aantal = math.ceil(lengte / stap)
	for i = 0, aantal do
		local streep = Instance.new("Frame")
		streep.Name = "Stripe"
		streep.AnchorPoint = Vector2.new(0.5, 0.5)
		streep.Position = UDim2.fromOffset(
			math.round(breedte / 2 + (i - aantal / 2) * stap),
			math.round(hoogte / 2)
		)
		streep.Size = UDim2.fromOffset(RUG_BAND, lengte)
		-- `linear-gradient(45deg, ...)` loopt naar rechtsboven, dus de banden zelf liggen
		-- daar haaks op: van linksboven naar rechtsonder. Roblox draait met de klok mee,
		-- net als de webversie, en dat is voor een staand balkje juist de andere diagonaal
		-- -- vandaar min 45 en niet plus 45.
		streep.Rotation = -45
		streep.BackgroundColor3 = RUG_LICHT
		streep.BorderSizePixel = 0
		streep.Parent = binnen
	end
	return f
end

-- .hand-label .val: het pilletje met de stand erin. Zwart met een rand, radius 8, en het
-- is minstens 32 breed zodat "21" en "7/17" allebei netjes in dezelfde kolom staan.
local function waardePil(ouder: Instance, volgorde: number): TextLabel
	local t = UI.label(ouder, "\u{2014}", {
		size = Theme.text.small, color = Theme.color.text, font = Theme.font.num,
		align = Enum.TextXAlignment.Center, name = "Val",
	})
	t.LayoutOrder = volgorde
	t.BackgroundColor3 = Theme.color.black
	t.BackgroundTransparency = Theme.alpha.buttonBg   -- rgba(0,0,0,0.5)
	t.Size = UDim2.fromOffset(PIL_MIN, PIL_H)
	t.AutomaticSize = Enum.AutomaticSize.X
	UI.corner(t, Theme.radius.pill)
	UI.stroke(t)
	UI.padding4(t, 0, 8 + UI.RAND, 0, 8 + UI.RAND)

	local minstens = Instance.new("UISizeConstraint")
	minstens.MinSize = Vector2.new(PIL_MIN, PIL_H)
	minstens.Parent = t
	return t
end

-- .hand: het kopje met de stand, en daaronder de kaarten. Geeft het kopje terug (daar hangt
-- bij de speler het inzetlabel nog achter), het vak met de kaarten en het pilletje.
local function maakHand(ouder: Instance, naam: string, volgorde: number): (Frame, Frame, TextLabel)
	local hand = Instance.new("Frame")
	hand.Name = naam
	hand.Size = UDim2.new(1, 0, 0, 0)
	hand.AutomaticSize = Enum.AutomaticSize.Y
	hand.BackgroundTransparency = 1
	hand.LayoutOrder = volgorde
	hand.Parent = ouder
	UI.list(hand, HAND_GAT)

	local kop = Instance.new("Frame")
	kop.Name = "Label"
	kop.Size = UDim2.new(1, 0, 0, PIL_H)
	kop.BackgroundTransparency = 1
	kop.Parent = hand
	local kopLijst = UI.list(kop, LABEL_GAT, Enum.FillDirection.Horizontal)
	kopLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	local titel = UI.label(kop, naam, { size = Theme.text.small, color = Theme.color.muted })
	titel.LayoutOrder = 1
	titel.Size = UDim2.new(0, 0, 1, 0)
	titel.AutomaticSize = Enum.AutomaticSize.X

	local pil = waardePil(kop, 2)

	-- .cards heeft min-height 100, dus het bord staat al op zijn plek voordat er is gedeeld,
	-- en flex-wrap: een hand die breder wordt dan de tafel valt door naar een tweede rij.
	local kaarten = Instance.new("Frame")
	kaarten.Name = "Cards"
	kaarten.Size = UDim2.new(1, 0, 0, KAARTEN_H)
	kaarten.AutomaticSize = Enum.AutomaticSize.Y
	kaarten.BackgroundTransparency = 1
	kaarten.Parent = hand
	local kaartLijst = UI.list(kaarten, KAART_GAT, Enum.FillDirection.Horizontal)
	-- Een kaart is 96 hoog en het vak minstens 100; in de CSS blijft zo'n kaart met
	-- `align-items: stretch` gewoon boven in de regel hangen, dus hier ook.
	kaartLijst.VerticalAlignment = Enum.VerticalAlignment.Top
	kaartLijst.Wraps = true
	local kaartHoogte = Instance.new("UISizeConstraint")
	kaartHoogte.MinSize = Vector2.new(0, KAARTEN_H)
	kaartHoogte.Parent = kaarten

	return kop, kaarten, pil
end

function Blackjack.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "BLACKJACK")

	-- ---------- het bord ----------
	-- `.bj-table`: volle breedte tot 720, alles onder elkaar met 22 ertussen.
	local tafel = Instance.new("Frame")
	tafel.Name = "BjTable"
	tafel.Size = UDim2.new(1, 0, 0, 0)
	tafel.AutomaticSize = Enum.AutomaticSize.Y
	tafel.BackgroundTransparency = 1
	tafel.Parent = bord
	UI.list(tafel, TAFEL_GAT)
	local breedte = Instance.new("UISizeConstraint")
	breedte.MaxSize = Vector2.new(TAFEL_B, math.huge)
	breedte.Parent = tafel

	local _, dealerKaarten, dealerPil = maakHand(tafel, "DEALER", 1)

	-- .bj-message: 22px, halfvet, gecentreerd, en minstens 32 hoog zodat de kaarten niet
	-- verspringen als er even niets staat.
	local bericht = UI.label(tafel, "PLACE A BET AND DEAL", {
		size = Theme.text.big, color = Theme.color.text, font = Theme.font.uiMed,
		align = Enum.TextXAlignment.Center, name = "Message",
	})
	bericht.LayoutOrder = 2
	bericht.Size = UDim2.new(1, 0, 0, 0)
	bericht.AutomaticSize = Enum.AutomaticSize.Y
	bericht.TextWrapped = true
	local berichtHoogte = Instance.new("UISizeConstraint")
	berichtHoogte.MinSize = Vector2.new(0, BERICHT_H)
	berichtHoogte.Parent = bericht

	local spelerKop, spelerKaarten, spelerPil = maakHand(tafel, "YOU", 3)

	-- #bjBetLabel: de inzet in goud, achter het pilletje.
	local inzetLabel = UI.label(spelerKop, "", {
		size = Theme.text.small, color = Theme.color.gold, name = "Stake",
	})
	inzetLabel.LayoutOrder = 3
	inzetLabel.Size = UDim2.new(0, 0, 1, 0)
	inzetLabel.AutomaticSize = Enum.AutomaticSize.X

	-- .bj-message.win is neon, .lose rood, .push goud, en anders gewoon de tekstkleur.
	local function zetBericht(tekst: string, soort: string?)
		bericht.Text = tekst
		bericht.TextColor3 = if soort == "win" then Theme.color.neon
			elseif soort == "lose" then Theme.color.red
			elseif soort == "push" then Theme.color.gold
			else Theme.color.text
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, DEAL en de drie knoppen in één `.panel`.
	-- Common.betBox maakt dat paneel, dus de rest gaat erbij in.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel

	-- De fiches sluiten de `.field-group` af; daarna komt DEAL. Een UIPadding op een knop
	-- schuift alleen de tekst op, niet de knop, dus de lucht erboven zit in een vakje
	-- eromheen; de 6 die de lijst van het paneel al geeft gaat eraf.
	local dealVak = Instance.new("Frame")
	dealVak.Name = "DealSlot"
	dealVak.Size = UDim2.new(1, 0, 0, 0)
	dealVak.AutomaticSize = Enum.AutomaticSize.Y
	dealVak.BackgroundTransparency = 1
	dealVak.LayoutOrder = 10
	dealVak.Parent = paneel
	UI.padding4(dealVak, DEAL_MARGE, 0, 0, 0)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	--
	-- In de webversie heet deze knop JOIN THE TABLE zodra je aan de gedeelde tafel zit; die
	-- tafel bestaat in deze poort niet, dus hij houdt de naam uit de markup zelf: DEAL.
	local dealKnop = UI.primary(dealVak, "DEAL")
	dealKnop.Font = Theme.font.uiBold
	UI.gradient(dealKnop, Theme.color.neon, Theme.color.neonDim, 135)

	-- .bj-actions: twee gelijke kolommen met 6 ertussen en 8 lucht erboven; DOUBLE staat
	-- eronder over de volle breedte (grid-column: 1 / 3).
	local acties = Instance.new("Frame")
	acties.Name = "Actions"
	acties.Size = UDim2.new(1, 0, 0, 0)
	acties.AutomaticSize = Enum.AutomaticSize.Y
	acties.BackgroundTransparency = 1
	acties.LayoutOrder = 11
	acties.Parent = paneel
	UI.list(acties, ACTIE_GAT)
	-- `.bj-actions` heeft margin-top 8. Het paneel van betBox zet zijn onderdelen al met 6
	-- uit elkaar, dus er hoeft hier nog 2 bij om op diezelfde 8 uit te komen.
	UI.padding4(acties, ACTIE_MARGE, 0, 0, 0)

	local bovenRij = Instance.new("Frame")
	bovenRij.Name = "Row"
	bovenRij.Size = UDim2.new(1, 0, 0, ACTIE_H)
	bovenRij.BackgroundTransparency = 1
	bovenRij.Parent = acties
	UI.list(bovenRij, ACTIE_GAT, Enum.FillDirection.Horizontal)

	local hitKnop = UI.secondary(bovenRij, "HIT")
	hitKnop.LayoutOrder = 1
	hitKnop.Size = UDim2.new(0.5, -ACTIE_GAT / 2, 1, 0)
	local standKnop = UI.secondary(bovenRij, "STAND")
	standKnop.LayoutOrder = 2
	standKnop.Size = UDim2.new(0.5, -ACTIE_GAT / 2, 1, 0)
	local doubleKnop = UI.secondary(acties, "DOUBLE")
	doubleKnop.LayoutOrder = 2
	doubleKnop.Size = UDim2.new(1, 0, 0, ACTIE_H)

	-- ---------- de stand van de hand ----------
	local actief = false
	local gedubbeld = false

	-- Een knop uit `.bj-actions` aan- of uitzetten. UI.setEnabled dimt de tekst en de
	-- vulling; in de CSS zakt met `opacity: 0.35` ook de rand mee, dus die gaat hier mee.
	local function zetActie(b: TextButton, aan: boolean)
		UI.setEnabled(b, aan)
		local rand = b:FindFirstChildOfClass("UIStroke")
		if rand then rand.Transparency = if aan then 0 else 0.65 end
	end

	-- DEAL aan- of uitzetten met de 0.6 van `.btn-primary:disabled`. UI.setEnabled dimt elke
	-- knop even hard, en dat maakt de grote groene knop veel donkerder dan op de site.
	-- Active uit is genoeg om de hover-kleur tegen te houden; die kijkt daarnaar.
	local function zetDeal(aan: boolean)
		dealKnop.Active = aan
		dealKnop.TextTransparency = if aan then 0 else DEAL_DOF
		dealKnop.BackgroundTransparency = if aan then 0 else DEAL_DOF
	end

	-- De knoppen blijven staan en gaan uit, zoals `disabled` in de webversie: DEAL kan
	-- alleen tussen twee handen door, de andere drie alleen als je aan zet bent.
	local function zetKnoppen(kanDubbelen: boolean)
		zetDeal(not actief)
		zetActie(hitKnop, actief)
		zetActie(standKnop, actief)
		zetActie(doubleKnop, actief and kanDubbelen)
		betBox.lock(actief)
	end

	local function wis(rij: Frame)
		for _, k in rij:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
	end

	local function toonHand(rij: Frame, kaarten: { Kaart }, dicht: boolean)
		wis(rij)
		for i, k in kaarten do
			kaartVlak(rij, k, i)
		end
		if dicht then
			rugVlak(rij, #kaarten + 1)
		end
	end

	-- Wat er in het pilletje komt te staan. Bij een zachte hand allebei de waarden, net als
	-- bjRender() in de webversie: met een aas erin is 7 ook 17.
	local function pilTekst(waarde: any, zacht: boolean?): string
		local n = tonumber(waarde)
		if not n then return "\u{2014}" end
		if zacht and n <= 21 then return string.format("%d/%d", n - 10, n) end
		return string.format("%d", n)
	end

	-- #bjBetLabel: "· STAKE $100.00", met (DOUBLED) erachter zodra er gedubbeld is.
	local function zetInzet(inzet: any)
		local n = tonumber(inzet)
		if not n or n <= 0 then
			inzetLabel.Text = ""
			return
		end
		inzetLabel.Text = "\u{00B7} STAKE $" .. Money.fmt(n) .. (if gedubbeld then " (DOUBLED)" else "")
	end

	local function toonSpel(res: any)
		actief = true
		gedubbeld = res.doubled == true
		toonHand(spelerKaarten, res.player, false)
		-- De dichte kaart van de dealer is er niet: de server stuurt alleen de open kaart.
		toonHand(dealerKaarten, { res.dealerUp }, true)
		spelerPil.Text = pilTekst(res.playerValue, res.playerSoft)
		dealerPil.Text = pilTekst(res.dealerValue, false)
		zetInzet(res.bet)
		-- Dubbelen mag alleen op de eerste twee kaarten, net als aan een echte tafel -- en
		-- alleen als er genoeg op de rekening staat voor de tweede helft van de inzet.
		-- Staat de knop aan zonder dekking, dan weigert de server hem alsnog en heb je een
		-- knop ingedrukt die nooit iets kon doen.
		local dekking = Common.balance() + 1e-9 >= (tonumber(res.bet) or 0)
		zetKnoppen(#res.player == 2 and not gedubbeld and dekking)
		zetBericht("HIT, STAND OR DOUBLE?", nil)
	end

	local function toonEinde(res: any)
		actief = false
		gedubbeld = res.doubled == true
		toonHand(spelerKaarten, res.player, false)
		toonHand(dealerKaarten, res.dealer, false)
		spelerPil.Text = pilTekst(res.playerValue, false)
		dealerPil.Text = pilTekst(res.dealerValue, false)
		zetInzet(res.bet)
		zetKnoppen(false)

		-- Dezelfde regels als bjFinish() in de webversie, in dezelfde volgorde.
		local dub = if gedubbeld then " (DOUBLED)" else ""
		local inzet = tonumber(res.bet) or 0
		local uit = tonumber(res.payout) or 0
		local winst = uit - inzet
		local speler = tonumber(res.playerValue) or 0
		local dealer = tonumber(res.dealerValue) or 0
		local spelerBJ = res.natural == true
		local dealerBJ = #res.dealer == 2 and dealer == 21
		if spelerBJ and dealerBJ then
			zetBericht("BOTH BLACKJACK \u{00B7} PUSH", "push")
		elseif spelerBJ then
			zetBericht("BLACKJACK! +$" .. Money.fmt(winst), "win")
		elseif dealerBJ then
			zetBericht("DEALER BLACKJACK" .. dub, "lose")
		elseif speler > 21 then
			zetBericht("BUST" .. dub, "lose")
		elseif dealer > 21 then
			zetBericht("DEALER BUST" .. dub .. " \u{00B7} +$" .. Money.fmt(winst), "win")
		elseif res.result == "win" then
			zetBericht("WON" .. dub .. " \u{00B7} +$" .. Money.fmt(winst), "win")
		elseif res.result == "push" then
			zetBericht("PUSH" .. dub .. " \u{00B7} STAKE RETURNED", "push")
		else
			zetBericht("LOST" .. dub .. " \u{00B7} -$" .. Money.fmt(inzet), "lose")
		end

		-- Geen melding bij winst: bjFinish zet alleen het bericht onder de hand en tekent
		-- opnieuw. De uitslag staat daar al, groot en in kleur; er nog een melding
		-- overheen gooien is iets wat de webversie niet doet.
	end

	local function verwerk(res: any)
		if not res then return end
		if res.done then
			toonEinde(res)
		else
			toonSpel(res)
		end
	end

	dealKnop.Activated:Connect(function()
		if actief then return end
		gedubbeld = false
		verwerk(Common.call("Bet", "blackjack", betBox.get()))
	end)
	hitKnop.Activated:Connect(function()
		if not actief then return end
		verwerk(Common.call("Act", "blackjack", "hit"))
	end)
	standKnop.Activated:Connect(function()
		if not actief then return end
		verwerk(Common.call("Act", "blackjack", "stand"))
	end)
	doubleKnop.Activated:Connect(function()
		-- Active staat uit zodra dubbelen niet meer mag; dat is hier ook de grendel.
		if not actief or not doubleKnop.Active then return end
		local res = Common.call("Act", "blackjack", "double")
		if not res then return end
		-- Hardop zeggen dat het gelukt is. Zonder dit verandert alleen het kleine label
		-- naast je hand, en kun je achteraf niet zien of de verdubbeling is aangekomen of
		-- stil geweigerd werd.
		Common.toast("DOUBLED \u{00B7} STAKE $" .. Money.fmt(res.bet or 0), "gold")
		verwerk(res)
	end)

	zetKnoppen(false)

	-- De twee panelen waar de aside in de markup mee afsluit. Bij blackjack is het tweede
	-- paneel RULES in plaats van ODDS; de tekst is die van de `.odds-note` daar. De
	-- vetgedrukte stukken (3:2 en 1%) zijn in de CSS goud, maar twee kleuren in één regel
	-- zou RichText vragen en dat staat in dit project uit, dus het is één kleur.
	Common.statsPanel(bediening, "blackjack")
	Common.oddsPanel(bediening, "rules", "6 decks, continuously shuffled (a fresh shoe every hand). Dealer stands on all 17s. Blackjack pays *3:2* and a dealer blackjack is checked straight away. Double on any first two cards. No split, no insurance. House edge around *1%*.")
end

return Blackjack
