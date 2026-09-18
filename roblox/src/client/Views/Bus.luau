--!strict
-- Ride the Bus: vier keer raden door één geschudde stapel -- kleur, hoger of lager, binnen
-- of buiten, en de soort. De kans wordt geteld op wat er nog in de stapel ligt, dus
-- uitstappen levert na elke call precies 97% op, hoe goed of slecht je ook geraden hebt.
--
-- Het beeld komt regel voor regel uit `#busView` in de markup en uit het blok "Ride the
-- Bus" in de CSS. Het bord is `.bus-table`: een kolom van hoogstens 640 breed met 22
-- pixels lucht, met daarin de kaarten, de vraagregel `.bj-message` en de knoppenrij
-- `.bu-options`. Links het inzetveld, de twee `.payout-line`-regels en de twee knoppen in
-- één `.panel`, daarna STATISTICS en ODDS -- precies de volgorde van de markup.
--
-- De kaarten staan ONDER elkaar, niet naast elkaar. Dat ziet er vreemd uit, maar het is
-- letterlijk wat de webversie doet: `#buCards` draagt de klasse `.bj-hand`, en die klasse
-- staat nergens in de CSS. Het is dus een gewone blok-div, en blok-divs stapelen. In de
-- browser nagemeten: het vak is 66 breed en drie kaarten staan alle drie op x=935, 96 uit
-- elkaar. Blackjack gebruikt wél een opgemaakte klasse (`.cards`, flex met 8 ertussen) en
-- legt ze daarom wél naast elkaar -- vandaar het verschil tussen die twee schermen.
--
-- Wat Roblox niet heeft: letter-spacing (0.8px op `.bj-message`, 0.4px op `.bu-option
-- .lb`), de box-shadow onder een kaart, en het herhalende verloop van de kaartrug -- die
-- is hieronder nagemaakt met losse balkjes. Het raster `.bu-options` is
-- `repeat(auto-fit, minmax(130px, 1fr))`; bij twee of vier calls komt dat neer op twee of
-- vier gelijke kolommen die samen de volle breedte vullen, en dat is hier uitgerekend.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Common = require(script.Parent.Common)

local Bus = {}

type Kaart = { r: string, s: string }
type Optie = { key: string, label: string, chance: number }

-- ---------- maten uit de CSS ----------
local TAFEL_B = 640        -- .bus-table max-width
local TAFEL_GAT = 22       -- .bus-table gap
local KAART_B = 66         -- .card width
local KAART_H = 96         -- .card height
local RUG_RAND = 4         -- .card.back border: 4px solid
local RUG_BAND = 6         -- de bandbreedte uit het repeating-linear-gradient
local BERICHT_H = 32       -- .bj-message min-height
local OPT_GAT = 8          -- .bu-options gap
local OPT_H = 61           -- .bu-option: 12 + 17 + 4 + 14 + 12, plus de rand van 1
local OPT_PAD_Y = 12       -- .bu-option padding: 12px 10px
local OPT_PAD_X = 10
local OPT_GAP = 4          -- .bu-option gap
local OPT_LB = 14          -- .bu-option .lb font-size
local OPT_LB_H = 17        -- de regelhoogte die daarbij hoort
local OPT_MU_H = 14        -- .bu-option .mu, 11px
local OPT_DOF = 0.6        -- .bu-option.dead { opacity: 0.4 }

-- De kleuren van een speelkaart staan in de CSS als losse hex in `.card` en `.card.back`,
-- niet als variabele; ze horen dus hier en niet in het Theme. Dezelfde waarden als in
-- Blackjack.luau, want het is dezelfde kaart uit dezelfde CSS-regels.
local KAART_WIT = Color3.fromHex("fdfdf5")
local KAART_INKT = Color3.fromHex("151515")
local KAART_ROOD = Color3.fromHex("c8102e")
local RUG_DONKER = Color3.fromHex("0b3d1f")
local RUG_LICHT = Color3.fromHex("14602f")
local GOUD_DONKER = Color3.fromHex("cc9900")   -- .btn-cashout, het eind van het verloop

-- BU_ASK in de webversie: de vraag die bij elke call hoort. Geen hoofdletters -- dit is
-- de enige regel in het spel die gewoon een zin is, en dat is hij in de markup ook.
local VRAGEN = {
	"Red or black?",
	"Higher or lower than that card?",
	"Inside or outside the two?",
	"Which suit?",
}

-- ---------- bouwsteentjes ----------
-- .card: 66 bij 96, wit, de rang linksboven en het teken rechtsonder. Harten en ruiten
-- zijn rood. De box-shadow onder de kaart kan Roblox niet en is weggelaten.
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
-- binnen de 66 bij 96 (box-sizing: border-box), dus het is hier een wit vlak met een
-- groen vlak van vier pixels kleiner erin.
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

-- .payout-line: naam links, waarde rechts in het cijferlettertype, haarlijntje eronder.
local STREEP = Color3.fromHex("1a3a1a")   -- .payout-line border-bottom

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

function Bus.build(ouder: Instance): ()
	-- `data-route="vip"`: de bus zit achter de VIP-zone, dus de terugknop gaat daarheen
	-- en niet naar de lobby.
	local bord, bediening = Common.columns(ouder, "RIDE THE BUS", "vip", "\u{2190} VIP ZONE")

	-- ---------- het bord ----------
	local tafel = Instance.new("Frame")
	tafel.Name = "BusTable"
	tafel.Size = UDim2.new(1, 0, 0, 0)
	tafel.AutomaticSize = Enum.AutomaticSize.Y
	tafel.BackgroundTransparency = 1
	tafel.Parent = bord
	local tafelLijst = UI.list(tafel, TAFEL_GAT)
	tafelLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center   -- .bus-table align-items: center
	local breedte = Instance.new("UISizeConstraint")
	breedte.MaxSize = Vector2.new(TAFEL_B, math.huge)
	breedte.Parent = tafel

	-- `#buCards`: 66 breed en zonder lucht ertussen, want de kaarten stapelen (zie boven).
	local kaarten = Instance.new("Frame")
	kaarten.Name = "Cards"
	kaarten.Size = UDim2.fromOffset(KAART_B, 0)
	kaarten.AutomaticSize = Enum.AutomaticSize.Y
	kaarten.BackgroundTransparency = 1
	kaarten.LayoutOrder = 1
	kaarten.Parent = tafel
	UI.list(kaarten, 0)

	-- .bj-message: 22px, halfvet, gecentreerd, en minstens 32 hoog zodat de rij knoppen
	-- niet verspringt als de regel korter wordt.
	local bericht = UI.label(tafel, "Place a bet and get on the bus.", {
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

	local keuzes = Instance.new("Frame")
	keuzes.Name = "Options"
	keuzes.Size = UDim2.new(1, 0, 0, 0)
	keuzes.AutomaticSize = Enum.AutomaticSize.Y
	keuzes.BackgroundTransparency = 1
	keuzes.LayoutOrder = 3
	keuzes.Parent = tafel
	UI.list(keuzes, OPT_GAT, Enum.FillDirection.Horizontal)

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld, de twee uitbetaalregels en de twee knoppen in één
	-- `.panel`. Common.betBox maakt dat paneel, dus de rest gaat erbij in; de LayoutOrder
	-- geldt alleen bínnen dit paneel, waar het inzetveld op nul staat en dus voorop blijft.
	local betBox = Common.betBox(bediening, 10)
	local paneel = betBox.panel

	local callLabel = payoutRegel(paneel, "CALL", Theme.color.gold, 11)
	-- `.payout-line .v.neon` op CURRENT WIN, de enige van de twee die neon is.
	local multLabel = payoutRegel(paneel, "CURRENT WIN", Theme.color.neon, 12)

	Common.buttonGap(paneel, 12)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local startKnop = UI.primary(paneel, "GET ON THE BUS")
	startKnop.LayoutOrder = 13
	startKnop.Font = Theme.font.uiBold
	UI.gradient(startKnop, Theme.color.neon, Theme.color.neonDim, 135)

	-- .btn-primary.btn-cashout: goud. Hij staat er alleen als er iets te verzilveren is.
	local uitKnop = UI.primary(paneel, "CASH OUT")
	uitKnop.LayoutOrder = 14
	uitKnop.Font = Theme.font.uiBold
	uitKnop.BackgroundColor3 = Theme.color.gold
	uitKnop.TextColor3 = Theme.color.bg
	uitKnop.Visible = false
	UI.gradient(uitKnop, Theme.color.gold, GOUD_DONKER, 135)
	-- `.btn-cashout { animation: pulse-gold 1s infinite }`: dezelfde kloppende gouden rand
	-- als bij mines en de toren. In de CSS is het een box-shadow; hier een rand die op en
	-- neer gaat, want Roblox kent geen schaduw.
	local klopRand = UI.stroke(uitKnop, Theme.color.gold, 2)
	klopRand.Transparency = 1
	local klop = TweenService:Create(
		klopRand,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.5 }   -- rgba(224,181,85,0.5) uit @keyframes pulse-gold
	)

	-- ---------- de stand van de rit ----------
	local actief = false
	local stap = 0          -- het aantal calls dat goed ging
	local inzet = 0
	local mult = 0
	-- De kans om hier te zijn gekomen, zoals BU.prob in de webversie: nodig om per knop te
	-- laten zien wat de rit waard wordt als die call goed gaat. De server rekent zijn eigen
	-- multiplier uit; dit is puur om de knoppen te kunnen tekenen.
	local prob = 1
	local opties: { Optie } = {}

	local function wisKaarten()
		for _, k in kaarten:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
	end

	local function wisKeuzes()
		for _, k in keuzes:GetChildren() do
			if k:IsA("TextButton") then k:Destroy() end
		end
	end

	-- De regel boven de knoppen, met de kleuren van `.bj-message.win` en `.lose`.
	local function zetBericht(tekst: string, soort: string?)
		bericht.Text = tekst
		bericht.TextColor3 = if soort == "win" then Theme.color.neon
			elseif soort == "lose" then Theme.color.red
			else Theme.color.text
	end

	local roep: (string) -> ()
	-- Wanneer de vorige call werd gedaan, voor de dubbelklikbeveiliging hieronder.
	local laatsteCall = 0

	-- .bu-option: het label erboven, en eronder wat de rit waard wordt als deze call goed
	-- gaat plus de kans erop. Een call die niet kan uitkomen is `.dead`: doorzichtig, niet
	-- aanklikbaar, en met "impossible" in plaats van een getal -- de server weigert hem
	-- toch, en dat hoor je te zien voordat je klikt.
	local function toonOpties(lijst: { Optie })
		wisKeuzes()
		opties = lijst
		local aantal = #lijst
		for i, o in lijst do
			local kan = o.chance > 0
			local b = Instance.new("TextButton")
			b.Name = o.key
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundColor3 = Theme.color.panelLight
			b.BorderSizePixel = 0
			b.LayoutOrder = i
			b.Active = kan
			-- Gelijke kolommen: elk kind draagt zijn deel van de tussenruimte mee.
			b.Size = UDim2.new(1 / aantal, -OPT_GAT * (aantal - 1) / aantal, 0, OPT_H)
			UI.corner(b, Theme.radius.card)   -- border-radius: 6px
			local rand = UI.stroke(b, Theme.color.border)
			b.Parent = keuzes

			-- `.bu-option:hover:not(:disabled)`: de rand wordt neon. De `translateY(-2px)`
			-- die daar in de CSS bij staat kan niet: een kind van een UIListLayout krijgt
			-- zijn Position van de layout en houdt een eigen verschuiving niet vast. Alleen
			-- de rand licht dus op. De `:not(:disabled)` is hier `kan`: een call die niet
			-- kan uitkomen reageert nergens op.
			b.MouseEnter:Connect(function()
				if kan then rand.Color = Theme.color.neon end
			end)
			b.MouseLeave:Connect(function()
				rand.Color = Theme.color.border
			end)
			UI.padding4(b, OPT_PAD_Y, OPT_PAD_X, OPT_PAD_Y, OPT_PAD_X)
			local binnen = UI.list(b, OPT_GAP)
			binnen.HorizontalAlignment = Enum.HorizontalAlignment.Center

			local lb = UI.label(b, o.label, {
				size = OPT_LB, color = Theme.color.text, font = Theme.font.uiMed,
				align = Enum.TextXAlignment.Center, name = "Lb",
			})
			lb.Size = UDim2.new(1, 0, 0, OPT_LB_H)

			local mu = UI.label(b, if kan
					then Money.fmt(Odds.busMultiplier(prob * o.chance))
						.. "\u{00D7} \u{00B7} " .. string.format("%d%%", math.round(o.chance * 100))
					else "impossible", {
				size = Theme.text.tiny, color = Theme.color.muted, font = Theme.font.num,
				align = Enum.TextXAlignment.Center, name = "Mu",
			})
			mu.Size = UDim2.new(1, 0, 0, OPT_MU_H)

			if not kan then
				lb.TextTransparency = OPT_DOF
				mu.TextTransparency = OPT_DOF
				rand.Transparency = OPT_DOF
				b.BackgroundTransparency = OPT_DOF
			end

			b.Activated:Connect(function()
				if kan then roep(o.key) end
			end)
		end
	end

	-- Alles wat van de stand afhangt in één keer bijwerken, zoals buRender() dat doet.
	local function teken()
		startKnop.Visible = not actief
		uitKnop.Visible = actief and stap > 0
		if actief and stap > 0 then
			uitKnop.Text = "CASH OUT $" .. Money.fmt(Money.floor2(inzet * mult))
			klop:Play()
		else
			klop:Pause()
			klopRand.Transparency = 1
		end
		callLabel.Text = if actief then (stap + 1) .. " / 4" else "\u{2014}"
		multLabel.Text = if actief and stap > 0 then Money.fmt(mult) .. "\u{00D7}" else "\u{2014}"
		betBox.lock(actief)
	end

	-- De dichte kaart bovenop de stapel: die ligt er zolang er nog een call te maken is.
	local function zetRug()
		local oud = kaarten:FindFirstChild("CardBack")
		if oud then oud:Destroy() end
		if actief and stap < 4 then rugVlak(kaarten, stap + 1) end
	end

	function roep(keuze: string)
		if not actief then return end
		-- De knoppenrij wordt na elke call opnieuw opgebouwd, dus de tweede tik van een
		-- dubbelklik landt op de knop van de VOLGENDE call. Die tik is nooit gewild, en
		-- hier hangt er een hele rit aan. De webversie negeert daarom alles binnen 350
		-- milliseconde na de vorige call, en dat doet dit ook.
		local nu = os.clock()
		if nu - laatsteCall < 0.35 then return end
		laatsteCall = nu

		-- De kans van deze call onthouden voordat de server antwoordt: de knoppen van de
		-- volgende stap zijn er straks mee uit te rekenen.
		local kans = 0
		for _, o in opties do
			if o.key == keuze then kans = o.chance end
		end

		local res = Common.call("Act", "bus", keuze)
		if not res then return end

		prob *= kans
		kaartVlak(kaarten, res.card, stap + 1)

		if not res.hit then
			actief = false
			Common.setRideOpen("bus", actief)
			wisKeuzes()
			zetRug()
			teken()
			zetBericht("OFF THE BUS \u{00B7} -$" .. Money.fmt(inzet), "lose")
			Common.toast("OFF THE BUS \u{00B7} -$" .. Money.fmt(inzet), "red")
			return
		end

		if res.done then
			-- Vier calls is de hele rit: er valt niets meer te roepen, dus hij betaalt uit.
			actief = false
			Common.setRideOpen("bus", actief)
			stap = 4
			mult = tonumber(res.mult) or 0
			local uit = tonumber(res.payout) or 0
			wisKeuzes()
			zetRug()
			teken()
			zetBericht("+$" .. Money.fmt(uit) .. " \u{00B7} " .. Money.fmt(mult) .. "\u{00D7}", "win")
			Common.toast("FULL RIDE \u{00B7} +$" .. Money.fmt(uit), "gold")
			return
		end

		stap = tonumber(res.step) or (stap + 1)
		mult = tonumber(res.mult) or 0
		zetBericht(VRAGEN[stap + 1])
		toonOpties(res.options)
		zetRug()
		teken()
	end

	startKnop.Activated:Connect(function()
		if actief then return end
		local bedrag = betBox.get()
		local res = Common.call("Bet", "bus", bedrag)
		if not res then return end
		actief = true
		Common.setRideOpen("bus", actief)
		stap = 0
		inzet = bedrag
		mult = 0
		prob = 1
		wisKaarten()
		zetBericht(VRAGEN[1])
		toonOpties(res.options)
		zetRug()
		teken()
	end)

	uitKnop.Activated:Connect(function()
		if not actief or stap < 1 then return end
		local res = Common.call("CashOut", "bus")
		if not res then return end
		actief = false
		Common.setRideOpen("bus", actief)
		mult = tonumber(res.mult) or mult
		local uit = tonumber(res.payout) or 0
		wisKeuzes()
		zetRug()
		teken()
		local regel = "+$" .. Money.fmt(uit) .. " \u{00B7} " .. Money.fmt(mult) .. "\u{00D7}"
		zetBericht(regel, "win")
		Common.toast(regel, "green")
	end)

	teken()

	-- De twee panelen waar elke aside in de webversie mee afsluit. De vetgedrukte stukken
	-- in de `.odds-note` zijn in de CSS goud, maar twee kleuren in één regel zou RichText
	-- vragen en dat staat in dit project uit, dus het is één kleur.
	Common.statsPanel(bediening, "bus")
	Common.oddsPanel(bediening, "odds", "One shuffled 52-card deck. Every button shows your chance and what the ride becomes worth: the multiplier is *0.97 / the chance of getting that far*, counted off the cards still in the deck. So stopping after any call returns *97%*. A tie always loses.")
end

return Bus
