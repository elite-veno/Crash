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

local Common = {}

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

	local start = Common.call("bet", "safety")
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

	UI.panelTitle(vak, "\u{25BA} SAFETY NET").Size = UDim2.new(1, 0, 0, Theme.text.small + 12)

	local uitleg = UI.label(vak,
		"You are broke. Stop the marker as close to the middle as you can. $10 is guaranteed; a perfect stop is worth $40.",
		{ size = Theme.text.tiny, color = Theme.color.muted })
	uitleg.TextWrapped = true
	uitleg.Size = UDim2.new(1, 0, 0, 34)

	local hint = UI.label(vak, "Hit SPACE or tap STOP.", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
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
		local r = Common.call("act", "safety")
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
		Common.toast(string.format("SAFETY NET +$%s \u{B7} %d%% ACCURACY",
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
	UI.list(aside, Theme.size.asideGap)

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
	local pad = if kaal then 0 else Theme.size.panelPad
	bord.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	bord.Position = UDim2.fromOffset(pad, pad)
	bord.BackgroundTransparency = 1
	bord.Parent = bordVak
	local bordLijst = UI.list(bord, Theme.size.asideGap)
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
		kop.Size = UDim2.new(1, 0, 0, 34)
		kop.BackgroundTransparency = 1
		kop.Parent = aside
		local kopIndeling = UI.list(kop, 12, Enum.FillDirection.Horizontal)
		kopIndeling.VerticalAlignment = Enum.VerticalAlignment.Center

		local terug = UI.backButton(kop, terugTekst)
		terug.LayoutOrder = 1
		if terugTekst then
			-- `.back-btn` heeft geen vaste breedte maar padding van 8 om 12; met een
			-- langere tekst dan "← LOBBY" moet de knop dus meegroeien.
			terug.AutomaticSize = Enum.AutomaticSize.X
			terug.Size = UDim2.fromOffset(0, 30)
			UI.padding4(terug, 0, 12, 0, 12)
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
	end

	-- Het saldopaneel, zoals `.panel.balance` in de markup: alles gecentreerd.
	local saldoVak = UI.panel(aside, "Balance")
	UI.list(saldoVak, 2)
	local kopje = UI.label(saldoVak, "BALANCE", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
	})
	kopje.Size = UDim2.new(1, 0, 0, 16)
	local bedrag = UI.moneyLabel(saldoVak, Money.fmt(saldo), Theme.text.balance, true)
	table.insert(saldoLabels, bedrag)

	-- `.js-broke`: normaal weg, en goud zodra je blut bent. De lijstafstand in dit paneel
	-- is 2 en de CSS wil er 10, dus de knop draagt de acht die ontbreken zelf.
	local noodVak = Instance.new("Frame")
	noodVak.Name = "BrokeWrap"
	noodVak.Size = UDim2.new(1, 0, 0, 44)
	noodVak.BackgroundTransparency = 1
	noodVak.Parent = saldoVak

	local nood = UI.secondary(noodVak, "\u{1F4B8} BROKE? PLAY THE SAFETY NET")
	nood.Name = "Broke"
	nood.Position = UDim2.fromOffset(0, 8)
	nood.TextColor3 = Theme.color.gold
	local noodRand = nood:FindFirstChildOfClass("UIStroke")
	if noodRand then noodRand.Color = Theme.color.gold end
	nood.Activated:Connect(function()
		Common.safetyNet()
	end)
	table.insert(noodKnoppen, nood)
	-- Het vak volgt de knop: staat hij er niet, dan hoort die 44 pixels er ook niet te zijn.
	nood:GetPropertyChangedSignal("Visible"):Connect(function()
		noodVak.Visible = nood.Visible
	end)
	noodVak.Visible = false
	nood.Visible = false

	-- `.account-bar`: één gecentreerde regel met de naam in neon, zoals de markup van een
	-- speelscherm hem heeft. Uitloggen vervalt in Roblox -- de speler is zijn eigen
	-- account -- dus die twee spans blijven weg. De regel is hoger dan de tekst omdat de
	-- CSS er tien pixels lucht boven zet en de lijstafstand hier twee is.
	local naamVak = UI.label(saldoVak, Players.LocalPlayer.DisplayName, {
		size = Theme.text.tiny, color = Theme.color.neon, align = Enum.TextXAlignment.Center,
	})
	naamVak.Name = "AccountBar"
	naamVak.Size = UDim2.new(1, 0, 0, Theme.text.tiny + 14)
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
function Common.row(ouder: Instance, hoogte: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.Size = UDim2.new(1, 0, 0, hoogte or 30)
	f.BackgroundTransparency = 1
	f.Parent = ouder
	local l = UI.list(f, 4, Enum.FillDirection.Horizontal)
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
function Common.betBox(ouder: Instance, start: number?): BetBox
	local paneel = UI.panel(ouder, "BetPanel")
	UI.list(paneel, 6)
	-- .field-label: "STAKE" links, het dollarteken als hint rechts.
	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	kop.BackgroundTransparency = 1
	kop.Parent = paneel
	UI.label(kop, "STAKE", { size = Theme.text.small, color = Theme.color.muted })
	UI.label(kop, "$", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
	})

	local vak = UI.numberBox(paneel, Money.fmt(start or 10))
	local ficherij = Common.row(paneel, 24)

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
		b.Size = UDim2.new(0.25, -3, 0, 24)
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
	UI.list(vak, 6)
	UI.panelTitle(vak, "\u{25BA} statistics")

	local rondes = Common.statRow(vak, "ROUNDS", "0")
	local won = Common.statRow(vak, "WON", "0")
	won.TextColor3 = Theme.color.neon
	local lost = Common.statRow(vak, "LOST", "0")
	lost.TextColor3 = Theme.color.red
	-- Bij crash heet het BEST, bij de rest BEST MULT -- net als in renderStats.
	local best = Common.statRow(vak, if spel == "crash" then "BEST" else "BEST MULT", "\u{2014}")
	best.TextColor3 = Theme.color.gold
	local bestRij = best.Parent :: Frame
	bestRij.Visible = spel == "crash"
	local winst = Common.statRow(vak, "PROFIT", "+$0.00")
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
	UI.list(vak, 6)
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

-- Een regel met een naam links en een waarde rechts, zoals `.stat-row` in de CSS. Geeft
-- het waardelabel terug, zodat het scherm het kan bijwerken.
function Common.statRow(ouder: Instance, naam: string, waarde: string): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = "StatRow"
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	rij.Size = UDim2.new(1, 0, 0, Theme.text.small + 8)
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted, name = "Key" })
	return UI.label(rij, waarde, {
		size = Theme.text.small, color = Theme.color.text, font = Theme.font.num,
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

return Common
