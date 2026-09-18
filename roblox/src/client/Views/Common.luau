--!strict
-- Wat elk speelscherm nodig heeft: een blad om op te bouwen, een inzetvak met de ficheknoppen
-- eronder, en een lijntje naar de server. Eén plek, zodat de tien schermen er hetzelfde
-- uitzien en zich hetzelfde gedragen -- precies zoals bindBet() en takeBet() dat in de
-- webversie doen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Money = require(ReplicatedStorage.Shared.Money)
local TextService = game:GetService("TextService")
local Season = require(ReplicatedStorage.Shared.Season)

local Common = {}

-- `.stat-row` is een regel zonder marge in een raster met `line-height: 1`, dus zo hoog als
-- de letter zelf. Met de zes pixels van `.stats-grid` ertussen komen de regels twintig uit
-- elkaar te staan, en dat is wat de site laat zien.
local STAT_REGEL = 14

-- `.crash-header { gap: 12px; padding: 10px 0 }` om een terugknop van 32 (een regel van 14
-- met acht lucht boven en onder plus twee randen): samen 52 hoog. `.crash-header-title` is
-- 22px, dus een regel van 26.
local KOP_GAT = 12
local KOP_PAD = 10
local KOP_REGEL = 26        -- regelvak van 22px
local TERUG_REGEL = 8 + 14 + 8   -- `.back-btn { padding: 8px 0 }` om een regel van 14

-- ---------- saldo en meldingen ----------
-- De schil weet het saldo en heeft het meldingenvak; de schermen vragen het hier op.
local saldo = Money.START
local melder: ((string, UI.ToastKind?) -> ())? = nil
local ga: ((string) -> ())? = nil
-- Elk speelscherm heeft links een saldopaneel, net als in de webversie. Ze staan hier
-- allemaal in, zodat één bericht van de server ze in één keer bijwerkt.
local saldoLabels: { TextLabel } = {}
-- De noodfondsknop staat in datzelfde paneel en hoort alleen te verschijnen als je blut
-- bent, dus hij wordt met het saldo mee bijgewerkt.
local noodKnoppen: { TextButton } = {}
local modalHost: Instance? = nil

local function verversNood(): ()
	-- De webversie kijkt ook of er nog een ronde loopt (roundInProgress). Dat weet alleen
	-- de server zeker, want daar staat de stand; de knop gaat hier dus af op het saldo, en
	-- als er toch nog geld in het spel staat weigert de server het fonds en zegt dat.
	local blut = saldo < Money.MIN_BET
	for _, b in noodKnoppen do
		if b.Parent then b.Visible = blut end
	end
end

function Common.setBalance(n: number): ()
	saldo = n
	local tekst = Money.fmt(n)
	for _, l in saldoLabels do
		if l.Parent then l.Text = tekst end
	end
	verversNood()
end

function Common.setNavigate(f: (string) -> ()): ()
	ga = f
end

function Common.navigate(route: string): ()
	local f = ga
	if f then f(route) end
end

function Common.balance(): number
	return saldo
end

function Common.setToaster(f: (string, UI.ToastKind?) -> ()): ()
	melder = f
end

-- Waar een venster over het hele scherm in mag hangen; de schil wijst het aan.
function Common.setModalHost(f: Instance): ()
	modalHost = f
end

-- frBadge(): het aantal vriendschapsverzoeken op de FRIENDS-regel in de balk. Het scherm
-- Friends telt ze, de schil tekent ze -- die kent de balk.
local vriendTeller: ((number) -> ())? = nil

function Common.setFriendCounter(f: (number) -> ()): ()
	vriendTeller = f
end

function Common.setFriendRequests(n: number): ()
	local f = vriendTeller
	if f then f(n) end
end

-- ---------- een ronde die niet onderbroken mag worden ----------
-- De VIP-spellen zijn dicht zodra de pas afloopt, maar een rit die al loopt moet je kunnen
-- uitspelen. Zou de schil je er middenin uit gooien, dan blijft die ronde op de server
-- openstaan: je kunt er niet meer bij, je kunt niets anders beginnen, en je inzet staat
-- vast. De webversie maakt er dezelfde uitzondering voor (`!(route === 'bus' && BU.active)`).
local ritOpen: { [string]: boolean } = {}

function Common.setRideOpen(spel: string, open: boolean): ()
	if open then
		ritOpen[spel] = true
	else
		ritOpen[spel] = nil
	end
end

function Common.rideOpen(spel: string): boolean
	return ritOpen[spel] == true
end

function Common.toast(tekst: string, soort: UI.ToastKind?): ()
	local f = melder
	if f then f(tekst, soort) end
end

-- Een uitslag van de server. Klapt de aanroep, dan zegt het scherm dat, in plaats van
-- stil te blijven staan.
function Common.call(kanaal: string, ...): any
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Net.fn(kanaal):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		Common.toast("DE SERVER ANTWOORDT NIET", "red")
		return nil
	end
	if typeof(res) == "table" and res.ok == false then
		Common.toast(string.upper(tostring(res.err or "dat ging niet")), "red")
		return nil
	end
	return res
end

-- ---------- het noodfonds ----------
-- Het spelletje voor wie blut is: een streepje loopt heen en weer over een balk en je
-- drukt op stop. Tien dollar is gegarandeerd, veertig bij een stop precies in het midden.
--
-- De client tekent alleen. De server heeft de klok en bepaalt waar het streepje stond toen
-- "stop" binnenkwam; wat hier op het scherm staat is een weergave van diezelfde golf, niet
-- de bron ervan. Loopt het beeld een frame achter, dan is de uitslag nog steeds die van de
-- server.
local NOOD_PERIODE = 1.1

-- Dezelfde driehoeksgolf als bkPos() in de webversie: 0 naar 1 en terug.
local function noodPositie(verstreken: number): number
	local fase = (verstreken % NOOD_PERIODE) / NOOD_PERIODE
	return if fase < 0.5 then fase * 2 else 2 - fase * 2
end

function Common.safetyNet(): ()
	local host = modalHost
	if not host then return end
	-- Twee vensters tegelijk zou twee klokken geven; de server weigert het ook.
	if host:FindFirstChild("BrokeModal") then return end

	local start = Common.call("Bet", "safety")
	if not start then return end

	-- .modal: over alles heen, met een donkere waas erachter.
	local waas = Instance.new("TextButton")
	waas.Name = "BrokeModal"
	waas.Text = ""
	waas.AutoButtonColor = false
	waas.Size = UDim2.fromScale(1, 1)
	waas.BackgroundColor3 = Theme.color.black
	waas.BackgroundTransparency = 0.25
	waas.BorderSizePixel = 0
	waas.ZIndex = 100
	waas.Parent = host

	-- .modal-panel: width min(420px, 100%), padding 24.
	local vak = UI.panel(waas, "Panel")
	vak.AnchorPoint = Vector2.new(0.5, 0.5)
	vak.Position = UDim2.fromScale(0.5, 0.5)
	vak.Size = UDim2.new(0, 420, 0, 0)
	vak.AutomaticSize = Enum.AutomaticSize.Y
	vak.ZIndex = 101
	UI.padding(vak, 24)
	UI.list(vak, 0)

	UI.panelTitle(vak, "\u{25BA} SAFETY NET").Size = UDim2.new(1, 0, 0, Theme.lineBox(Theme.text.small) + 12)

	-- De vetgedrukte stukken zijn in de CSS goud, net als in elk ander `.odds-note`.
	local uitleg = UI.label(vak, "", { size = Theme.text.tiny, color = Theme.color.muted })
	uitleg.RichText = true
	uitleg.Text = Common.accent(
		"You are broke. Stop the marker as close to the middle as you can. *$10* is guaranteed; a perfect stop is worth *$40*.")
	uitleg.TextWrapped = true
	uitleg.Size = UDim2.new(1, 0, 0, 34)

	local hint = UI.label(vak, "", { size = Theme.text.tiny, color = Theme.color.muted })
	hint.RichText = true
	hint.Text = Common.accent("Hit *SPACE* or tap STOP.")
	hint.Size = UDim2.new(1, 0, 0, Theme.text.tiny + 6)

	-- .bk-bar: 34 hoog, met 18 lucht erboven en 10 eronder.
	local balkVak = Instance.new("Frame")
	balkVak.Name = "BarWrap"
	balkVak.Size = UDim2.new(1, 0, 0, 34 + 18 + 10)
	balkVak.BackgroundTransparency = 1
	balkVak.ZIndex = 101
	balkVak.Parent = vak

	local balk = Instance.new("Frame")
	balk.Name = "Bar"
	balk.Position = UDim2.fromOffset(0, 18)
	balk.Size = UDim2.new(1, 0, 0, 34)
	balk.BackgroundColor3 = Theme.color.black
	balk.BorderSizePixel = 0
	balk.ClipsDescendants = true
	balk.ZIndex = 101
	UI.corner(balk, Theme.radius.panel)
	UI.stroke(balk)
	balk.Parent = balkVak

	-- Hetzelfde verloop als in de CSS: rood aan de randen, goud ertussen, neon in het
	-- midden. Waar je stopt is dus af te lezen aan de kleur eronder.
	local verloop = Instance.new("UIGradient")
	verloop.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromHex("3a0a14")),
		ColorSequenceKeypoint.new(0.30, Color3.fromHex("6a4a00")),
		ColorSequenceKeypoint.new(0.48, Theme.color.neon),
		ColorSequenceKeypoint.new(0.52, Theme.color.neon),
		ColorSequenceKeypoint.new(0.70, Color3.fromHex("6a4a00")),
		ColorSequenceKeypoint.new(1.00, Color3.fromHex("3a0a14")),
	})
	verloop.Parent = balk

	-- .bk-bar::after: het witte streepje dat het midden markeert.
	local midden = Instance.new("Frame")
	midden.Name = "Centre"
	midden.AnchorPoint = Vector2.new(0.5, 0)
	midden.Position = UDim2.fromScale(0.5, 0)
	midden.Size = UDim2.new(0, 2, 1, 0)
	midden.BackgroundColor3 = Theme.color.white
	midden.BackgroundTransparency = 0.2
	midden.BorderSizePixel = 0
	midden.ZIndex = 102
	midden.Parent = balk

	-- .bk-marker: zes breed, twee buiten de balk aan weerszijden.
	local streep = Instance.new("Frame")
	streep.Name = "Marker"
	streep.AnchorPoint = Vector2.new(0.5, 0)
	streep.Position = UDim2.new(0, 0, 0, 16)
	streep.Size = UDim2.new(0, 6, 0, 38)
	streep.BackgroundColor3 = Theme.color.white
	streep.BorderSizePixel = 0
	streep.ZIndex = 103
	UI.corner(streep, 2)
	streep.Parent = balkVak

	-- .bk-scale: $10 -- $40 -- $10 onder de balk.
	local schaal = Instance.new("Frame")
	schaal.Name = "Scale"
	schaal.Size = UDim2.new(1, 0, 0, Theme.text.tiny + 14)
	schaal.BackgroundTransparency = 1
	schaal.ZIndex = 101
	schaal.Parent = vak
	for i, tekst in { "$10", "$40", "$10" } do
		local l = UI.label(schaal, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
		l.Size = UDim2.fromScale(1 / 3, 1)
		l.Position = UDim2.fromScale((i - 1) / 3, 0)
		l.TextXAlignment = if i == 1 then Enum.TextXAlignment.Left
			elseif i == 2 then Enum.TextXAlignment.Center
			else Enum.TextXAlignment.Right
		l.ZIndex = 101
	end

	-- .bk-result: de uitslag, 22px neon, met de hoogte alvast gereserveerd zodat het
	-- venster niet opspringt als hij verschijnt.
	local uitslag = UI.label(vak, "", {
		size = 22, color = Theme.color.neon, font = Theme.font.uiMed,
		align = Enum.TextXAlignment.Center,
	})
	uitslag.Size = UDim2.new(1, 0, 0, 38)

	local stopKnop = UI.primary(vak, "STOP")
	local sluitKnop = UI.secondary(vak, "CLOSE")
	sluitKnop.Visible = false

	local loopt = true
	-- De server heeft gezegd wanneer de ronde begon, op zijn eigen klok. Die klok is hier
	-- ook te lezen -- Roblox houdt hem gelijk -- dus het streepje op het scherm staat waar
	-- de server het heeft staan, en niet ergens in de buurt daarvan.
	local t0 = tonumber(start.startsAt) or workspace:GetServerTimeNow()
	local verstrekenBijStop = 0

	local function teken(verstreken: number)
		streep.Position = UDim2.new(noodPositie(verstreken), 0, 0, 16)
	end
	teken(workspace:GetServerTimeNow() - t0)

	local verbinding: RBXScriptConnection? = nil
	verbinding = RunService.RenderStepped:Connect(function()
		teken(if loopt then workspace:GetServerTimeNow() - t0 else verstrekenBijStop)
	end)

	local function sluit()
		loopt = false
		if verbinding then verbinding:Disconnect() end
		waas:Destroy()
	end

	local function stop()
		if not loopt then return end
		loopt = false
		local r = Common.call("Act", "safety")
		if not r then
			-- De server heeft de ronde hoe dan ook gesloten; blijven staan met een
			-- streepje dat niet meer telt zou misleiden.
			sluit()
			return
		end
		-- Het streepje springt naar waar de server zegt dat het stond. Dat is de enige
		-- stand die geld waard is, dus die hoort de speler te zien.
		verstrekenBijStop = (tonumber(r.position) or 0) / 2 * NOOD_PERIODE
		teken(verstrekenBijStop)
		uitslag.Text = "+$" .. Money.fmt(r.payout)
		stopKnop.Visible = false
		sluitKnop.Visible = true
		hint.Visible = false
		if r.balance then Common.setBalance(r.balance) end
		Common.toast(string.format("SAFETY NET +$%s \u{B7} %d%% accuracy",
			Money.fmt(r.payout), math.round((tonumber(r.accuracy) or 0) * 100)), "gold")
	end

	stopKnop.Activated:Connect(stop)
	sluitKnop.Activated:Connect(sluit)
	-- Buiten het venster klikken sluit het, maar niet terwijl het streepje nog loopt: dan
	-- zou een misklik je ronde kosten. Zo doet de webversie het ook.
	waas.Activated:Connect(function()
		if not loopt then sluit() end
	end)

	-- De spatiebalk stopt het streepje, net als in de webversie.
	local toets: RBXScriptConnection? = nil
	toets = UserInputService.InputBegan:Connect(function(input, bezig)
		if bezig then return end
		if not waas.Parent then
			if toets then toets:Disconnect() end
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Space then return end
		if loopt then stop() end
	end)
	waas.Destroying:Connect(function()
		if toets then toets:Disconnect() end
	end)
end

-- `.js-broke`: normaal weg, en goud zodra je blut bent. Staat in de saldokaart op het
-- beginscherm en in het saldopaneel van elk speelscherm, dus hij staat hier één keer.
--
-- De lijstafstand in zo'n paneel is kleiner dan de `margin-top: 10` die de CSS wil, dus de
-- knop draagt de pixels die ontbreken zelf.
function Common.brokeButton(ouder: Instance, orde: number?): TextButton
	local vak = Instance.new("Frame")
	vak.Name = "BrokeWrap"
	vak.Size = UDim2.new(1, 0, 0, 44)
	vak.BackgroundTransparency = 1
	if orde then vak.LayoutOrder = orde end
	vak.Parent = ouder

	local knop = UI.secondary(vak, "\u{1F4B8} BROKE? PLAY THE SAFETY NET")
	knop.Name = "Broke"
	knop.Position = UDim2.fromOffset(0, 8)
	knop.TextColor3 = Theme.color.gold
	local rand = knop:FindFirstChildOfClass("UIStroke")
	if rand then rand.Color = Theme.color.gold end
	knop.Activated:Connect(function()
		Common.safetyNet()
	end)
	table.insert(noodKnoppen, knop)
	-- Het vak volgt de knop: staat hij er niet, dan hoort die 44 pixels er ook niet te zijn.
	knop:GetPropertyChangedSignal("Visible"):Connect(function()
		vak.Visible = knop.Visible
	end)
	vak.Visible = false
	knop.Visible = false
	return knop
end

-- ---------- indeling ----------
-- Het blad waar een scherm op gebouwd wordt: scrollt, en groeit met zijn inhoud mee.
function Common.sheet(ouder: Instance): ScrollingFrame
	local blad = Instance.new("ScrollingFrame")
	blad.Name = "Sheet"
	blad.Size = UDim2.fromScale(1, 1)
	blad.BackgroundTransparency = 1
	blad.BorderSizePixel = 0
	blad.ScrollBarThickness = 4
	blad.ScrollBarImageColor3 = Theme.color.border
	blad.CanvasSize = UDim2.new()
	blad.AutomaticCanvasSize = Enum.AutomaticSize.Y
	blad.Parent = ouder
	UI.padding(blad, 4)
	UI.list(blad, Theme.size.gap + 4)
	return blad
end

-- Een speelscherm zoals `.game-view` in de CSS: `grid-template-columns: 320px 1fr` en
-- `height: 100vh`. Dus links een aside van 320 breed die zelf scrolt, en rechts een vlak dat
-- de rest van het scherm vult -- in de hoogte ook. Daar staat het speelveld in, gecentreerd.
--
-- Dat laatste was het grootste verschil met de webversie: alles onder elkaar in een
-- scrollende lijst maakt van een bord van 600 pixels een streepje van 200.
--
-- Boven in de aside staat de kop van het spel (`← LOBBY` plus de naam) en daaronder het
-- saldopaneel, precies de volgorde uit de markup.
--
-- De terugknop wijst standaard naar de lobby. De twee VIP-spellen (777 en Ride the Bus)
-- hebben in de markup `data-route="vip"` en `← VIP ZONE`; die geven het hier mee.
-- `kaal` is voor een scherm waarvan de rechterkolom geen paneel is. De meeste spellen
-- hebben daar `<main class="game-main"><div class="panel board">`: één paneel dat de kolom
-- vult. Crash niet -- daar staan de RECENT-balk, de lucht en de twee spelerslijsten los
-- onder elkaar in de kolom, met veertien pixels ertussen en zonder rand eromheen.
function Common.columns(
	ouder: Instance,
	titel: string?,
	terugNaar: string?,
	terugTekst: string?,
	kaal: boolean?
): (Frame, ScrollingFrame)
	local breedte = Theme.size.asideWidth
	local vak = Instance.new("Frame")
	vak.Name = "GameView"
	vak.Size = UDim2.fromScale(1, 1)
	vak.BackgroundTransparency = 1
	vak.Parent = ouder

	-- links: de aside, met een eigen schuifbalk zoals `aside.game-aside { overflow-y: auto }`
	local aside = Instance.new("ScrollingFrame")
	aside.Name = "Aside"
	aside.Size = UDim2.new(0, breedte, 1, 0)
	aside.BackgroundTransparency = 1
	aside.BorderSizePixel = 0
	aside.ScrollBarThickness = 0
	aside.CanvasSize = UDim2.new()
	aside.AutomaticCanvasSize = Enum.AutomaticSize.Y
	aside.Parent = vak
	UI.list(aside, Theme.size.asideGap + Theme.size.strokeGap)

	-- rechts: het speelveld, een paneel dat de rest vult
	local bordVak = Instance.new("Frame")
	bordVak.Name = "Main"
	bordVak.Position = UDim2.new(0, breedte + Theme.size.viewGap, 0, 0)
	bordVak.Size = UDim2.new(1, -(breedte + Theme.size.viewGap), 1, 0)
	bordVak.BackgroundColor3 = Theme.color.panel
	bordVak.BorderSizePixel = 0
	bordVak.ClipsDescendants = true
	if kaal then
		bordVak.BackgroundTransparency = 1
	else
		UI.gradient(bordVak, Theme.color.panel, Theme.color.panelLight)
		UI.corner(bordVak, Theme.radius.panel)
		UI.stroke(bordVak)
	end
	bordVak.Parent = vak

	-- Waar het spel zelf in komt: gecentreerd, zoals het bord in de webversie.
	local bord = Instance.new("Frame")
	bord.Name = "Board"
	-- `.board` is ruimer dan `.panel`: 22 padding en 18 tussen zijn kinderen, niet 18 en 14.
	local pad = if kaal then 0 else Theme.size.boardPad
	bord.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	bord.Position = UDim2.fromOffset(pad, pad)
	bord.BackgroundTransparency = 1
	bord.Parent = bordVak
	local bordLijst = UI.list(bord, if kaal then Theme.size.asideGap else Theme.size.boardGap)
	if not kaal then
		bordLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
		bordLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	-- .crash-header: de terugknop en de naam van het spel, naast elkaar.
	if titel then
		-- Geen LayoutOrder: die staat overal op nul, en bij gelijke waarde houdt Roblox de
		-- volgorde waarin de kinderen zijn toegevoegd. De kop wordt als eerste toegevoegd,
		-- dus hij staat bovenaan. Zette ik hier 1 neer, dan kwam hij juist onder alles wat
		-- een scherm daarna toevoegt -- want dat staat op nul.
		local kop = Instance.new("Frame")
		kop.Name = "Header"
		-- `.crash-header { padding: 10px 0 }` om de terugknop, en die is 32 in border-box:
		-- een regel van 14 met acht lucht boven en onder plus twee randen. Samen 52. Hier
		-- stond 34 -- de tien pixels lucht ontbraken aan beide kanten, en daardoor begon
		-- alles in de zijkolom achttien pixels te hoog.
		kop.Size = UDim2.new(1, 0, 0, KOP_PAD * 2 + TERUG_REGEL + UI.RAND * 2)
		kop.BackgroundTransparency = 1
		kop.Parent = aside
		local kopIndeling = UI.list(kop, KOP_GAT, Enum.FillDirection.Horizontal)
		kopIndeling.VerticalAlignment = Enum.VerticalAlignment.Center

		local terug = UI.backButton(kop, terugTekst)
		terug.LayoutOrder = 1
		if terugTekst then
			-- `.back-btn` heeft geen vaste breedte maar padding van 8 om 12; met een
			-- langere tekst dan "← LOBBY" moet de knop dus meegroeien.
			terug.AutomaticSize = Enum.AutomaticSize.X
			terug.Size = UDim2.fromOffset(0, terug.Size.Y.Offset)
			UI.padding4(terug, 0, 12 + UI.RAND, 0, 12 + UI.RAND)
		end
		terug.Activated:Connect(function()
			Common.navigate(terugNaar or "home")
		end)

		local naam = UI.label(kop, string.upper(titel), {
			size = Theme.text.title, color = Theme.color.neon, font = Theme.font.uiMed,
		})
		naam.LayoutOrder = 2
		naam.Size = UDim2.new(0, 0, 1, 0)
		naam.AutomaticSize = Enum.AutomaticSize.X

		-- `.crash-header` is een flexregel met `flex-wrap`. Past de naam niet naast de
		-- terugknop, dan breekt de browser allebei over twee regels en wordt de kop hoger --
		-- dat gebeurt bij WHEEL OF FORTUNE, en daar zakt de hele zijkolom twintig pixels
		-- mee. Roblox wikkelt niet uit zichzelf, dus wordt het hier nagemeten en nagedaan.
		local breed = TextService:GetTextSize(
			naam.Text, naam.TextSize, naam.Font, Vector2.new(9999, 9999)).X
		if terug.Size.X.Offset + KOP_GAT + breed > Theme.size.asideWidth then
			naam.AutomaticSize = Enum.AutomaticSize.None
			naam.TextWrapped = true
			naam.Size = UDim2.new(1, -(terug.Size.X.Offset + KOP_GAT), 0, KOP_REGEL * 2)
			terug.TextWrapped = true
			terug.Size = UDim2.fromOffset(terug.Size.X.Offset, TERUG_REGEL * 2)
			kop.Size = UDim2.new(1, 0, 0, KOP_PAD * 2 + KOP_REGEL * 2)
		end
	end

	-- Het saldopaneel, zoals `.panel.balance` in de markup: alles gecentreerd.
	-- `.balance { text-align: center; padding: 16px }`: smaller dan de 18 van `.panel`.
	local saldoVak = UI.panel(aside, "Balance")
	local saldoPad = saldoVak:FindFirstChildOfClass("UIPadding")
	if saldoPad then
		-- `.balance { padding: 16px }`, smaller dan de 18 van `.panel`; de rand komt erbij,
		-- zoals bij elk vak met een streep eromheen.
		local p = UDim.new(0, 16 + UI.RAND)
		saldoPad.PaddingTop, saldoPad.PaddingRight = p, p
		saldoPad.PaddingBottom, saldoPad.PaddingLeft = p, p
	end
	-- Geen tussenruimte: net als in de CSS draagt elk blok zijn eigen marge.
	UI.list(saldoVak, 0)
	local kopje = UI.label(saldoVak, "BALANCE", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
	})
	-- `.balance-label`: een regel van 14 met `margin-bottom: 6`.
	kopje.Size = UDim2.new(1, 0, 0, Theme.lineBox(Theme.text.small) + 6)
	kopje.TextYAlignment = Enum.TextYAlignment.Top
	local bedrag = UI.moneyLabel(saldoVak, Money.fmt(saldo), Theme.text.balance, true)
	table.insert(saldoLabels, bedrag)

	Common.brokeButton(saldoVak)

	-- `.account-bar`: één gecentreerde regel met de naam in neon, zoals de markup van een
	-- speelscherm hem heeft. Uitloggen vervalt in Roblox -- de speler is zijn eigen
	-- account -- dus die twee spans blijven weg. De regel is hoger dan de tekst omdat de
	-- CSS er tien pixels lucht boven zet en de lijstafstand hier twee is.
	local naamVak = UI.label(saldoVak, Players.LocalPlayer.DisplayName, {
		size = Theme.text.tiny, color = Theme.color.neon, align = Enum.TextXAlignment.Center,
	})
	naamVak.Name = "AccountBar"
	-- `.account-bar { margin-top: 10px }` boven een regel van 14.
	naamVak.Size = UDim2.new(1, 0, 0, 10 + Theme.lineBox(Theme.text.tiny))
	naamVak.TextYAlignment = Enum.TextYAlignment.Bottom
	verversNood()

	-- Onder de 900 pixels gaat de aside erboven staan; dan is het bord nog steeds groot.
	local smalNu: boolean? = nil
	local function meet()
		local breed = vak.AbsoluteSize.X
		if breed <= 0 then return end
		local smal = breed < 900
		if smal == smalNu then return end
		smalNu = smal
		if smal then
			aside.Size = UDim2.new(1, 0, 0, 300)
			aside.Position = UDim2.new()
			bordVak.Position = UDim2.new(0, 0, 0, 300 + Theme.size.viewGap)
			bordVak.Size = UDim2.new(1, 0, 1, -(300 + Theme.size.viewGap))
		else
			aside.Size = UDim2.new(0, breedte, 1, 0)
			aside.Position = UDim2.new()
			bordVak.Position = UDim2.new(0, breedte + Theme.size.viewGap, 0, 0)
			bordVak.Size = UDim2.new(1, -(breedte + Theme.size.viewGap), 1, 0)
		end
	end
	vak:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	return bord, aside
end

-- Een rij knoppen naast elkaar, gelijk verdeeld.
-- De standaardafstand is de 4 van `.chips`; `.btn-row` wil er 6, dus die is mee te geven.
function Common.row(ouder: Instance, hoogte: number?, gat: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.Size = UDim2.new(1, 0, 0, hoogte or 30)
	f.BackgroundTransparency = 1
	f.Parent = ouder
	local l = UI.list(f, gat or 4, Enum.FillDirection.Horizontal)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

-- ---------- het inzetvak ----------
export type BetBox = {
	panel: Frame,
	get: () -> number,
	set: (number) -> (),
	lock: (boolean) -> (),
}

-- Het inzetveld met ½, 2×, MIN en MAX eronder. Dezelfde vier knoppen en dezelfde rekenregels
-- als bindBet() in de webversie; het afronden gebeurt hier alleen om het netjes te tonen,
-- de server rekent zelf na.
-- `.btn-primary { margin-top: 8px }`: elke grote knop onderin een inzetpaneel heeft acht
-- pixels lucht boven zich. Een `.panel` houdt zelf niets tussen zijn kinderen, dus die acht
-- staan als een leeg vakje in de rij. Los van de knop, want een knop die verdwijnt (CASH
-- OUT staat er alleen als er iets te verzilveren is) mag zijn marge niet meenemen -- in de
-- CSS blijft de marge van het blok erboven dan ook gewoon staan.
function Common.buttonGap(paneel: Instance, orde: number?): Frame
	local v = Instance.new("Frame")
	v.Name = "ButtonGap"
	v.Size = UDim2.new(1, 0, 0, 8)
	v.BackgroundTransparency = 1
	if orde then v.LayoutOrder = orde end
	v.Parent = paneel
	return v
end

function Common.betBox(ouder: Instance, start: number?): BetBox
	local paneel = UI.panel(ouder, "BetPanel")
	-- Een `.panel` heeft geen tussenruimte: elk blok erin draagt zijn eigen marge. Hier
	-- stond zes, en dan kreeg elk blok dat een scherm er later bij zette er twaalf bij --
	-- zes boven en zes onder -- in plaats van de marge die de CSS vraagt.
	UI.list(paneel, 0)

	-- `.field-group { margin-bottom: 14px }`: het kopje, het invoerveld en de ficherij
	-- horen bij elkaar, met zes ertussen (`.field-label { margin-bottom: 6px }` en
	-- `.chips { margin-top: 6px }`).
	local veldGroep = Instance.new("Frame")
	veldGroep.Name = "FieldGroup"
	veldGroep.Size = UDim2.new(1, 0, 0, 0)
	veldGroep.AutomaticSize = Enum.AutomaticSize.Y
	veldGroep.BackgroundTransparency = 1
	veldGroep.Parent = paneel
	UI.list(veldGroep, 6)
	UI.padding4(veldGroep, 0, 0, 14, 0)

	-- .field-label: "STAKE" links, het dollarteken als hint rechts.
	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, Theme.lineBox(Theme.text.small))
	kop.BackgroundTransparency = 1
	kop.Parent = veldGroep
	UI.label(kop, "STAKE", { size = Theme.text.small, color = Theme.color.muted })
	-- `.field-label .hint { color: var(--neon); opacity: 0.7 }`: het dollarteken is neon en
	-- iets doorzichtig, niet grijs.
	local hint = UI.label(kop, "$", {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
	})
	hint.TextTransparency = 0.3

	local vak = UI.numberBox(veldGroep, Money.fmt(start or 10))
	-- `.chips`: de rij is precies zo hoog als een fiche met zijn rand eromheen.
	local ficherij = Common.row(veldGroep, 28)

	local function huidig(): number
		return tonumber(vak.Text) or 0
	end
	local function zet(n: number)
		vak.Text = Money.fmt(math.max(0, Money.round2(n)))
	end

	type Fiche = { naam: string, maak: () -> number }
	local knoppen: { Fiche } = {
		{ naam = "\u{00BD}", maak = function() return math.max(Money.MIN_BET, Money.round2(huidig() / 2)) end },
		{ naam = "2\u{00D7}", maak = function() return math.min(saldo, Money.round2(huidig() * 2)) end },
		{ naam = "MIN", maak = function() return Money.MIN_BET end },
		{ naam = "MAX", maak = function() return saldo end },
	}
	for _, fiche in knoppen do
		-- .chips is een raster van vier gelijke kolommen met 4 pixels ertussen.
		local b = UI.chip(ficherij, fiche.naam)
		-- Alleen de breedte; de hoogte komt van `.chip` zelf.
		b.Size = UDim2.new(0.25, -3, 0, b.Size.Y.Offset)
		b.Activated:Connect(function()
			zet(fiche.maak())
		end)
	end

	-- Enter sluit het toetsenbord; dat was op de telefoon in de webversie een aparte
	-- knop, hier doet Roblox het zelf. Wel meteen netjes tonen wat er staat.
	vak.FocusLost:Connect(function()
		zet(huidig())
	end)

	return {
		panel = paneel,
		get = huidig,
		set = zet,
		lock = function(op: boolean)
			vak.TextEditable = not op
			vak.TextTransparency = if op then 0.5 else 0
			for _, k in ficherij:GetChildren() do
				if k:IsA("TextButton") then
					k.Active = not op
					k.TextTransparency = if op then 0.5 else 0
				end
			end
		end,
	}
end

-- ---------- de twee panelen die elk speelscherm heeft ----------
-- In de webversie sluit elke aside af met een STATISTICS- en een ODDS-paneel. Die horen
-- erbij: ze vertellen wat het spel met je gedaan heeft en waarom de kansen zijn wat ze zijn.

-- Per spel de regels uit renderStats(): rondes, gewonnen, verloren, de beste multiplier en
-- de winst. Ze worden bijgewerkt zodra de server een profiel stuurt.
local statsVakken: { { spel: string, rondes: TextLabel, won: TextLabel, lost: TextLabel, best: TextLabel, winst: TextLabel } } = {}

function Common.statsPanel(ouder: Instance, spel: string): Frame
	local vak = UI.panel(ouder, "Stats")
	-- Een paneel in de CSS heeft geen tussenruimte: de kop draagt zijn eigen acht pixels
	-- marge, en de regels eronder staan er direct tegenaan.
	UI.list(vak, 0)
	UI.panelTitle(vak, "\u{25BA} statistics")

	local regels = Common.statRows(vak)
	local rondes = Common.statRow(regels, "ROUNDS", "0")
	local won = Common.statRow(regels, "WON", "0")
	won.TextColor3 = Theme.color.neon
	local lost = Common.statRow(regels, "LOST", "0")
	lost.TextColor3 = Theme.color.red
	-- Bij crash heet het BEST, bij de rest BEST MULT -- net als in renderStats.
	local best = Common.statRow(regels, if spel == "crash" then "BEST" else "BEST MULT", "\u{2014}")
	best.TextColor3 = Theme.color.gold
	local bestRij = best.Parent :: Frame
	bestRij.Visible = spel == "crash"
	local winst = Common.statRow(regels, "PROFIT", "+$0.00")
	winst.TextColor3 = Theme.color.neon

	table.insert(statsVakken, {
		spel = spel, rondes = rondes, won = won, lost = lost, best = best, winst = winst,
	})
	return vak
end

-- Het profiel binnenkrijgen: alle statistiekpanelen in één keer bijwerken.
function Common.setProfile(p: any): ()
	if typeof(p) ~= "table" or typeof(p.stats) ~= "table" then return end
	for _, v in statsVakken do
		local st = p.stats[v.spel]
		if typeof(st) == "table" then
			v.rondes.Text = string.format("%d", tonumber(st.rounds) or 0)
			v.won.Text = string.format("%d", tonumber(st.won) or 0)
			v.lost.Text = string.format("%d", tonumber(st.lost) or 0)
			local beste = tonumber(st.highest) or 0
			v.best.Text = if beste > 0 then Money.fmt(beste) .. "\u{00D7}" else "\u{2014}"
			-- Bij crash staat de regel er altijd, met een streepje zolang er niets is. Bij
			-- de andere spellen komt hij pas als er een multiplier te melden valt; zo staat
			-- het in renderStats, en zonder dit staat er overal een lege regel te veel.
			local rij = v.best.Parent
			if rij and rij:IsA("GuiObject") then
				rij.Visible = v.spel == "crash" or beste > 0
			end
			local w = tonumber(st.profit) or 0
			v.winst.Text = (if w >= 0 then "+$" else "-$") .. Money.fmt(math.abs(w))
			v.winst.TextColor3 = if w >= 0 then Theme.color.neon else Theme.color.red
		end
	end
end

-- .odds-note: het uitlegblokje onder ODDS of PAYOUTS. In de CSS zijn de <b>-stukken goud;
-- die staan hier tussen sterretjes.
--
-- Roblox kleurt een stuk tekst alleen met RichText, en dat staat in dit project overal
-- uit omdat spelersnamen langs labels komen. Hier gaat het aan, maar dan met alles wat
-- naar opmaak ruikt eerst onschadelijk gemaakt: wat er ook binnenkomt, het wordt als
-- tekst getoond en nooit als markup uitgevoerd.
local function veilig(tekst: string): string
	local uit = string.gsub(tekst, "&", "&amp;")
	uit = string.gsub(uit, "<", "&lt;")
	uit = string.gsub(uit, ">", "&gt;")
	uit = string.gsub(uit, '"', "&quot;")
	uit = string.gsub(uit, "'", "&apos;")
	return uit
end

local GOUD = "#" .. Theme.color.gold:ToHex()

-- Sterretjes eromheen betekent goud, net als <b> in de webversie. Wat tussen de sterretjes
-- staat wordt net zo goed ontsmet als de rest.
local function opmaak(tekst: string, kleur: string?): string
	local kl = kleur or GOUD
	local uit = {}
	local i = 1
	while true do
		local van, tot = string.find(tekst, "%*[^%*]+%*", i)
		if not van then break end
		table.insert(uit, veilig(string.sub(tekst, i, van - 1)))
		table.insert(uit, '<font color="' .. kl .. '">'
			.. veilig(string.sub(tekst, van + 1, (tot :: number) - 1)) .. "</font>")
		i = (tot :: number) + 1
	end
	table.insert(uit, veilig(string.sub(tekst, i)))
	return table.concat(uit)
end

-- Ook los te gebruiken, voor een regel die niet in een kansenpaneel staat. Zet RichText
-- op het label aan en laat de tekst hier langs; dan is een gekleurd stuk geen reden om de
-- ontsmetting over te slaan. Zonder kleur erbij wordt het goud, zoals <b> in de CSS.
function Common.accent(tekst: string, kleur: Color3?): string
	return opmaak(tekst, if kleur then "#" .. kleur:ToHex() else nil)
end

function Common.oddsPanel(ouder: Instance, kop: string, tekst: string): Frame
	local vak = UI.panel(ouder, "Odds")
	UI.list(vak, 0)
	UI.panelTitle(vak, "\u{25BA} " .. kop)
	local t = UI.label(vak, "", { size = Theme.text.tiny, color = Theme.color.muted })
	t.RichText = true
	t.Text = opmaak(tekst)
	t.TextWrapped = true
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Size = UDim2.new(1, 0, 0, 0)
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.LineHeight = 1.7
	return vak
end

-- `repeat(auto-fill, minmax(<min>px, 1fr))`: zoveel kolommen van minstens `min` als er
-- passen, en die rekken daarna samen de rij vol. De minimumbreedte is dus een bodem, geen
-- maat. Roblox rekent dat niet zelf uit, dus het gebeurt hier, opnieuw bij elke
-- maatverandering.
function Common.rekKolommen(
	vak: GuiObject,
	raster: UIGridLayout,
	minBreedte: number,
	gat: number,
	hoogte: number
): ()
	local function meet()
		local breed = vak.AbsoluteSize.X
		if breed <= 0 then return end
		local kolommen = math.max(1, math.floor((breed + gat) / (minBreedte + gat)))
		local kolomBreedte = (breed - gat * (kolommen - 1)) / kolommen
		raster.CellSize = UDim2.fromOffset(math.floor(kolomBreedte), hoogte)
	end
	vak:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)
end

-- ---------- terugkerende stukjes ----------
-- Een groot vak met een getal erin: de multiplier bij crash, de stand bij blackjack.
function Common.bigNumber(ouder: Instance, tekst: string, kleur: Color3?): TextLabel
	local t = UI.label(ouder, tekst, {
		size = Theme.text.huge, color = kleur or Theme.color.neon, font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
	})
	t.Size = UDim2.new(1, 0, 0, 52)
	return t
end

-- `.stats-grid`: het vak om de regels heen, met zijn eigen afstand van zes. Een paneel zet
-- er meer lucht tussen zijn onderdelen, en die geldt hier niet.
function Common.statRows(ouder: Instance): Frame
	local vak = Instance.new("Frame")
	vak.Name = "StatRows"
	vak.BackgroundTransparency = 1
	vak.Size = UDim2.new(1, 0, 0, 0)
	vak.AutomaticSize = Enum.AutomaticSize.Y
	vak.Parent = ouder
	UI.list(vak, 6)
	return vak
end

-- Een regel met een naam links en een waarde rechts, zoals `.stat-row` in de CSS. Geeft
-- het waardelabel terug, zodat het scherm het kan bijwerken.
function Common.statRow(ouder: Instance, naam: string, waarde: string): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = "StatRow"
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	rij.Size = UDim2.new(1, 0, 0, STAT_REGEL)
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted, name = "Key" })
	-- De waarde staat in dezelfde letter als de rest: `.stats-grid` zet alleen de grootte,
	-- en `.stat-row` heeft geen eigen font-family. Alleen `.lb-row .val` en `.payout-line
	-- .v` gebruiken de cijferletter, en dat zijn andere regels.
	return UI.label(rij, waarde, {
		size = Theme.text.small, color = Theme.color.text,
		align = Enum.TextXAlignment.Right, name = "Value",
	})
end

-- De uitslagbalk onder een speelveld: groen bij winst, rood bij verlies, grijs als er
-- niets gebeurd is.
export type Banner = { set: (string, string?) -> () }

function Common.banner(ouder: Instance): Banner
	local f = Instance.new("Frame")
	f.Name = "Banner"
	f.Size = UDim2.new(1, 0, 0, 36)
	f.BackgroundColor3 = Theme.color.panel
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.button)
	local rand = UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	local t = UI.label(f, "", {
		size = Theme.text.label, color = Theme.color.muted, font = Theme.font.uiMed,
		align = Enum.TextXAlignment.Center,
	})
	t.Size = UDim2.fromScale(1, 1)

	return {
		set = function(tekst: string, soort: string?)
			t.Text = tekst
			local kleur = if soort == "green" then Theme.color.neon
				elseif soort == "red" then Theme.color.red
				elseif soort == "gold" then Theme.color.gold
				else Theme.color.muted
			t.TextColor3 = kleur
			rand.Color = kleur
		end,
	}
end

-- ---------- .season-strip ----------
-- De seizoenstrip: links de aftelklok van de sprint, rechts wat de eerste drie plekken
-- opleveren. De lobby, de VIP-zone en het prestatiescherm laten alle drie dezelfde strip
-- zien -- in de webversie tekent één renderSeasonStrip() ze alle drie, en op precies die
-- manier staat hij hier nu ook één keer. Daarvoor bouwde elk scherm zijn eigen versie, en
-- die liepen uiteen: de klok was er 34, 35 of 38 hoog, de prijsvakjes 26 of 32, en de
-- lobby zette er zelfs andere woorden in.
--
-- De maten komen uit de CSS: `padding: 18px 22px` om een linkerkolom van 75 (10px-regel 12,
-- 26px-klok 35, twee 11px-regels van 14, zonder ruimte ertussen) en prijsvakjes van 34
-- (`padding: 8px 12px` om een regel van 16, plus de rand). Dat is samen 113 hoog, en dat is
-- wat de pagina laat zien.
export type SeasonStrip = {
	frame: Frame,
	zet: (sprint: number, sprintEinde: number, seizoenEinde: number, sprintsOver: number, nu: number?) -> (),
}

local SEIZOEN_PRIJS_HOOG = 34

function Common.seasonStrip(ouder: Instance): SeasonStrip
	local strip = Instance.new("Frame")
	strip.Name = "Season"
	strip.Size = UDim2.new(1, 0, 0, 0)
	strip.AutomaticSize = Enum.AutomaticSize.Y
	strip.BackgroundColor3 = Theme.color.panel
	strip.BorderSizePixel = 0
	UI.gradient(strip, Theme.color.panel, Theme.color.panelLight)
	UI.corner(strip, Theme.radius.card)
	UI.stroke(strip, Theme.color.border)
	UI.padding4(strip, 18 + UI.RAND, 22 + UI.RAND, 18 + UI.RAND, 22 + UI.RAND)
	strip.Parent = ouder

	-- `.season-now` is een gewoon blok: de vier regels staan er zonder ruimte ertussen op
	-- elkaar, elk zo hoog als zijn eigen regelvak.
	local links = Instance.new("Frame")
	links.Name = "Now"
	links.Size = UDim2.new(1, -580, 0, 0)
	links.AutomaticSize = Enum.AutomaticSize.Y
	links.BackgroundTransparency = 1
	links.Parent = strip
	UI.list(links, 0)

	-- `.season-label` staat op 10, een maat lager dan de gewone paneelkopjes.
	local sprintKop = UI.label(links, "", { size = 10, color = Theme.color.muted })
	local klok = UI.label(links, "", {
		size = 26, color = Theme.color.neon, font = Theme.font.num,   -- .season-time
	})
	UI.label(links, "until the standings reset to zero \u{00B7} whoever gains the most takes the title and a VIP pass", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	local seizoenRegel = UI.label(links, "", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})

	-- `.season-prizes` staan rechts in de strip, verticaal in het midden.
	local prijzen = Instance.new("Frame")
	prijzen.Name = "Prizes"
	prijzen.AnchorPoint = Vector2.new(1, 0.5)
	prijzen.Position = UDim2.new(1, 0, 0.5, 0)
	prijzen.Size = UDim2.fromOffset(560, SEIZOEN_PRIJS_HOOG)
	prijzen.BackgroundTransparency = 1
	prijzen.Parent = strip
	local prijsLijst = UI.list(prijzen, 10, Enum.FillDirection.Horizontal)
	prijsLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right
	prijsLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	for i, wat in Season.PRIZES do
		local rang = Season.RANKS[i]
		local vak = Instance.new("Frame")
		vak.Name = "Prize" .. i
		vak.LayoutOrder = i
		vak.AutomaticSize = Enum.AutomaticSize.X
		vak.Size = UDim2.fromOffset(0, SEIZOEN_PRIJS_HOOG)
		vak.BackgroundColor3 = Theme.color.black
		vak.BackgroundTransparency = 0.65   -- rgba(0,0,0,0.35)
		vak.BorderSizePixel = 0
		UI.corner(vak, Theme.radius.panel)
		UI.stroke(vak, Theme.color.border)
		UI.padding4(vak, 0, 12 + UI.RAND, 0, 12 + UI.RAND)
		vak.Parent = prijzen
		local rij = UI.list(vak, 8, Enum.FillDirection.Horizontal)
		rij.VerticalAlignment = Enum.VerticalAlignment.Center

		local teken = UI.label(vak, rang.teken, {
			size = Theme.text.body, align = Enum.TextXAlignment.Center,
		})
		teken.LayoutOrder = 1
		teken.Size = UDim2.fromOffset(16, SEIZOEN_PRIJS_HOOG)

		-- De naam staat in `<b>`, dus vet en in de tekstkleur; alleen het bedrag ernaast
		-- is goud en mono (`.amount`).
		local naam = UI.label(vak, rang.naam, { size = Theme.text.body, font = Theme.font.uiBold })
		naam.LayoutOrder = 2
		naam.AutomaticSize = Enum.AutomaticSize.X
		naam.Size = UDim2.new(0, 0, 0, SEIZOEN_PRIJS_HOOG)

		local bedrag = UI.label(vak, wat, {
			size = Theme.text.body, color = Theme.color.gold, font = Theme.font.num,
		})
		bedrag.LayoutOrder = 3
		bedrag.AutomaticSize = Enum.AutomaticSize.X
		bedrag.Size = UDim2.new(0, 0, 0, SEIZOEN_PRIJS_HOOG)
	end

	-- De twee klokken zijn rekenwerk op een tijdstempel, dus de strip kan zichzelf meteen
	-- vullen -- net als renderSeasonStrip(), dat ook niets aan de server vraagt. De
	-- ranglijst zet er daarna de tijd van de server overheen.
	local function zet(sprint: number, sprintEinde: number, seizoenEinde: number, sprintsOver: number, nu: number?)
		sprintKop.Text = Season.sprintHeading(sprint)
		klok.Text = Season.countdown(sprintEinde, nu)
		seizoenRegel.Text = "SEASON " .. Season.seasonNoOf(sprint) .. " ends in "
			.. Season.countdown(seizoenEinde, nu) .. " \u{00B7} "
			.. sprintsOver .. (if sprintsOver == 1 then " sprint" else " sprints")
			.. " left to earn a pass \u{00B7} a pass runs until the season ends"
	end

	return { frame = strip, zet = zet }
end

return Common
