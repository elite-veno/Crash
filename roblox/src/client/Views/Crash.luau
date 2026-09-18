--!strict
-- Crash: één ronde voor iedereen tegelijk. De client tekent de vlucht en telt de multiplier
-- mee op de servertijd, maar wat een cashout oplevert bepaalt de server -- de knop stuurt
-- alleen "ik stap uit", nooit een bedrag of een multiplier.
--
-- Het scherm volgt de webversie op de voet: rechts de RECENT-balk, daaronder de lucht waar
-- het vliegtuigje in klimt, en onderaan twee lijsten naast elkaar. Links de aside met het
-- saldo, het inzetpaneel met de schakelaar voor automatisch uitstappen, en de twee
-- panelen STATISTICS en ODDS.
--
-- Wat de webversie op een <canvas> tekent staat hier in Frames: wolken, gras, een spoor en
-- een vliegtuigje. Art.canvas is daar bewust niet voor gebruikt: die rekent alles om naar
-- een vast vak van 280 bij 160 en zet zijn lijnen in pixels van dát vak, terwijl deze lucht
-- met het venster meegroeit en elk beeldje verschuift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Crash = {}

-- Dezelfde getallen als crash.html.
local GROEI = 0.103995
local GRAS = 40          -- GRASS_HEIGHT
local STAPPEN = 50       -- updatePathPoints() tekent de baan in vijftig stukjes
local WOLKEN = 8         -- initClouds()
local SPRIETEN = 180     -- drawGrass() zet een spriet per 6 pixels; op een lucht van ruim
                         -- duizend breed zijn dat er zoveel
local DONKER = 77        -- en per 14 pixels een donkerder, hoger sprietje
local BLOEMEN = 14       -- drawGrass() zet een bloem per 80 pixels
local HISTORIE = 15      -- state.history.length > 15 -> pop()
local WINSTEN = 20       -- zoveel regels passen er in de feed voordat hij begint te schuiven
local TAFEL = 50         -- de gedeelde tafel haalt er vijftig op (limit=50)

-- main.crash-main: grid-template-rows: auto 1fr auto met gap 14.
local RIJGAT = 14
local BALK_H = 42        -- .history-bar: padding 10 boven en onder om een fiche van 22
local SPELERS_H = 180    -- .players-section max-height
local KOP_H = 30         -- .players-list h3 plus zijn margin-bottom van 10
local REGEL_H = 24       -- .player-row: 11 pixels tekst met padding 6 boven en onder
local NOTITIE_H = 20     -- de lege regel: één regel van 11 op line-height 1.7
local LUCHT_MIN = 320    -- .game-area { min-height: 320px }

-- De kleuren die alleen op dit scherm voorkomen; de rest komt uit Theme.
local KLEUR = {
	luchtOnder  = Color3.fromHex("b8e4ff"),
	wolkSchaduw = Color3.fromRGB(180, 200, 220),
	grasDiep    = Color3.fromHex("3d7a1f"),
	grasLicht   = Color3.fromHex("7ec045"),
	grasDonker  = Color3.fromHex("5aa030"),
	grasSpriet  = Color3.fromHex("4a8a25"),
	romp        = Color3.fromHex("e63946"),
	rompRand    = Color3.fromHex("8a0e1e"),
	vleugel     = Color3.fromHex("c91e2e"),
	ruit        = Color3.fromHex("87ceeb"),
	ruitRand    = Color3.fromHex("2a5570"),
	tekstRand   = Color3.fromHex("1a4a8a"),   -- -webkit-text-stroke van .multiplier-display
	crashRand   = Color3.fromHex("6a0011"),   -- .multiplier-display.crashed
	crashTekst  = Color3.fromHex("ffdddd"),
	pil         = Color3.fromRGB(10, 30, 60), -- .status-label achtergrond
	vuur        = Color3.fromRGB(255, 140, 50),
	vonk        = Color3.fromRGB(255, 220, 80),
	rook        = Color3.fromRGB(100, 100, 100),
	spoorCrash  = Color3.fromRGB(255, 80, 80),
	rijRand     = Color3.fromRGB(26, 58, 26), -- border-bottom van .player-row
	goudDonker  = Color3.fromHex("cc9900"),   -- .btn-cashout loopt naar dit goud
}

local function multBij(t: number): number
	if t <= 0 then return 1 end
	return math.max(1, math.floor(math.exp(GROEI * t) * 100) / 100)
end

-- ---------- tekenhulpjes ----------
-- Alles in de lucht staat in pixels van de lucht zelf, want de wolken schuiven per pixel
-- en het gras is veertig pixels hoog, hoe breed het venster ook is.
local function rond(ouder: Instance, cx: number, cy: number, r: number, kleur: Color3, doorzicht: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(r * 2, r * 2)
	f.BackgroundColor3 = kleur
	f.BackgroundTransparency = doorzicht or 0
	f.BorderSizePixel = 0
	UI.corner(f, r)
	f.Parent = ouder
	return f
end

-- Een ovaal is in Roblox een rechthoek met de kleinste straal als hoekradius.
local function ovaal(ouder: Instance, cx: number, cy: number, rx: number, ry: number, kleur: Color3, doorzicht: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(rx * 2, ry * 2)
	f.BackgroundColor3 = kleur
	f.BackgroundTransparency = doorzicht or 0
	f.BorderSizePixel = 0
	UI.corner(f, math.min(rx, ry))
	f.Parent = ouder
	return f
end

local function blokje(ouder: Instance, cx: number, cy: number, b: number, h: number, kleur: Color3, hoek: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(b, h)
	f.BackgroundColor3 = kleur
	f.BorderSizePixel = 0
	f.Rotation = hoek or 0
	f.Parent = ouder
	return f
end

-- Een balkje dat als lijnstuk tussen twee punten gelegd wordt: het spoor van het vliegtuig
-- bestaat uit vijftig van deze, elk beeldje opnieuw gelegd.
local function zetLijn(f: Frame, x1: number, y1: number, x2: number, y2: number, dikte: number)
	local dx, dy = x2 - x1, y2 - y1
	local lengte = math.sqrt(dx * dx + dy * dy)
	f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromOffset(math.max(lengte, dikte), dikte)
	f.Rotation = math.deg(math.atan2(dy, dx))
end

-- .panel heeft padding 18. Waar de markup er iets anders bij zet -- de RECENT-balk staat op
-- `padding: 10px 14px` -- verzetten we de UIPadding die UI.panel al maakte, want twee
-- UIPaddings op één vak vechten met elkaar. De haarlijn van .panel::before hangt op diezelfde
-- marge, dus die schuift mee.
local function paneelMarge(paneel: Frame, boven: number, rechts: number, onder: number, links: number)
	local p = paneel:FindFirstChildOfClass("UIPadding")
	if p then
		p.PaddingTop = UDim.new(0, boven)
		p.PaddingRight = UDim.new(0, rechts)
		p.PaddingBottom = UDim.new(0, onder)
		p.PaddingLeft = UDim.new(0, links)
	end
end

-- Een binnenvak dat de indeling doet. Handig waar een paneel zowel een lijst als iets
-- absoluut geplaatsts moet dragen.
local function paneelInhoud(paneel: Frame, gap: number, richting: Enum.FillDirection?): Frame
	local vak = Instance.new("Frame")
	vak.Name = "Body"
	vak.Size = UDim2.fromScale(1, 1)
	vak.BackgroundTransparency = 1
	vak.Parent = paneel
	UI.list(vak, gap, richting)
	return vak
end

-- .history-chip: vier klassen, van rood via wit en goud naar neon.
local function ficheKleur(m: number): (Color3, Color3, number)
	if m < 1.5 then
		return Theme.color.red, Theme.color.red, 0.55       -- rgba(224,97,110,0.45)
	elseif m < 3 then
		return Theme.color.text, Theme.color.border, 0
	elseif m < 10 then
		return Theme.color.gold, Theme.color.gold, 0.5      -- rgba(224,181,85,0.5)
	end
	return Theme.color.neon, Theme.color.neon, 0
end

function Crash.build(ouder: Instance): ()
	-- Kaal: de rechterkolom van crash is geen paneel maar main.game-main zelf.
	local bord, bediening = Common.columns(ouder, "CRASH", nil, nil, true)

	-- Het scherm blijft bestaan als je naar een ander spel gaat; dan hoeft er ook niets
	-- getekend te worden. Het vak van de schil is wat er aan- en uitgezet wordt.
	local scherm: GuiObject? = nil
	local schil = ouder.Parent
	if schil and schil:IsA("GuiObject") then
		scherm = schil
	end

	-- main.crash-main. Het bord van Common centreert zijn kinderen, dus alles gaat in één
	-- vak dat de hele hoogte vult; de drie rijen staan daarbinnen op hun plek.
	local hoofd = Instance.new("Frame")
	hoofd.Name = "CrashMain"
	hoofd.Size = UDim2.fromScale(1, 1)
	hoofd.BackgroundTransparency = 1
	hoofd.Parent = bord

	-- ---------- de RECENT-balk ----------
	local balk = UI.panel(hoofd, "History")
	balk.AutomaticSize = Enum.AutomaticSize.None
	balk.Size = UDim2.new(1, 0, 0, BALK_H)
	paneelMarge(balk, 10, 14, 10, 14)
	local balkVak = paneelInhoud(balk, 6, Enum.FillDirection.Horizontal)
	local balkLijst = balkVak:FindFirstChildOfClass("UIListLayout")
	if balkLijst then
		balkLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	balkVak.ClipsDescendants = true

	local historieKop = UI.label(balkVak, "RECENT", {
		size = Theme.text.small, color = Theme.color.muted,
	})
	historieKop.LayoutOrder = 0
	historieKop.Size = UDim2.fromOffset(52, 20)   -- plus de margin-right van 8 uit de CSS
	historieKop.TextYAlignment = Enum.TextYAlignment.Center

	-- ---------- de lucht ----------
	-- .game-area: verloop van 180 graden van #5fb8ff via #8dd0ff naar #b8e4ff, een neonrand
	-- en radius 4. De box-shadow eronder kent Roblox niet; die is weggelaten.
	local lucht = Instance.new("Frame")
	lucht.Name = "GameArea"
	lucht.Position = UDim2.fromOffset(0, BALK_H + RIJGAT)
	lucht.Size = UDim2.new(1, 0, 1, -(BALK_H + RIJGAT + SPELERS_H + RIJGAT))
	lucht.BackgroundColor3 = Theme.color.sky
	lucht.BorderSizePixel = 0
	lucht.ClipsDescendants = true
	UI.corner(lucht, Theme.radius.panel)
	UI.stroke(lucht, Theme.color.neon)
	lucht.Parent = hoofd

	-- De CSS heeft drie stops: #5fb8ff, #8dd0ff op de helft, #b8e4ff onderaan. Die middelste
	-- ligt op de rechte lijn tussen de andere twee (#8bcfff), dus twee stops geven hetzelfde
	-- beeld.
	UI.gradient(lucht, Theme.color.sky, KLEUR.luchtOnder)

	-- de wolken: vier bollen en een schaduw, net als drawCloud()
	type Wolk = { vak: Frame, maat: number, snelheid: number, x: number, y: number }
	local wolken: { Wolk } = {}
	for i = 1, WOLKEN do
		local maat = 30 + math.random() * 50
		local vak = Instance.new("Frame")
		vak.Name = "Cloud"
		vak.Size = UDim2.fromOffset(0, 0)
		vak.BackgroundTransparency = 1
		vak.ZIndex = 1
		-- Tot de lucht zijn maat weet staan ze verdeeld over de breedte; zaaiWolken() zet ze
		-- daarna in pixels neer, want drijven gaat per pixel.
		vak.Position = UDim2.new((i - 1) / WOLKEN, 0, 0, 30 + (i * 37) % 110)
		vak.Parent = lucht
		rond(vak, 0, 0, maat * 0.5, Theme.color.white, 0.1)
		rond(vak, maat * 0.4, -maat * 0.2, maat * 0.4, Theme.color.white, 0.1)
		rond(vak, maat * 0.8, 0, maat * 0.45, Theme.color.white, 0.1)
		rond(vak, maat * 0.4, maat * 0.1, maat * 0.5, Theme.color.white, 0.1)
		ovaal(vak, maat * 0.4, maat * 0.35, maat * 0.6, maat * 0.15, KLEUR.wolkSchaduw, 0.65)
		wolken[i] = { vak = vak, maat = maat, snelheid = 0.2 + math.random() * 0.4, x = 0, y = 0 }
	end

	-- het gras: een strook van veertig met een lichtere bovenrand van twintig
	local grasvak = Instance.new("Frame")
	grasvak.Name = "Grass"
	grasvak.AnchorPoint = Vector2.new(0, 1)
	grasvak.Position = UDim2.fromScale(0, 1)
	grasvak.Size = UDim2.new(1, 0, 0, GRAS)
	grasvak.BackgroundColor3 = KLEUR.grasDiep
	grasvak.BorderSizePixel = 0
	grasvak.ZIndex = 2
	grasvak.Parent = lucht

	local grasRand = Instance.new("Frame")
	grasRand.Size = UDim2.new(1, 0, 0, 20)
	grasRand.BackgroundColor3 = KLEUR.grasLicht
	grasRand.BorderSizePixel = 0
	grasRand.ZIndex = 2
	grasRand.Parent = grasvak
	UI.gradient(grasRand, KLEUR.grasLicht, KLEUR.grasDonker)

	-- drawGrass() maakt twee rondes: lichte sprietjes per zes pixels, en daar tussendoor per
	-- veertien een donkerder sprietje dat hoger is. De lichte zijn in het origineel altijd
	-- precies 4 hoog -- `4 + ((x * 7) % 7)` met x per zes is een vast getal -- en het zijn de
	-- donkere, van 5 tot 10, die de rafelrand geven. Beide rondes staan hier dus apart; met
	-- alleen de lichte wordt het een kam van gelijke tandjes.
	--
	-- Ze hangen op een schaalpositie en rekken met de lucht mee in plaats van bij elke
	-- maatverandering opnieuw gebouwd te worden; de aantallen zijn die van een lucht van
	-- ruwweg elfhonderd breed, de maat die dit scherm op een monitor krijgt.
	for i = 0, SPRIETEN - 1 do
		local spriet = Instance.new("Frame")
		spriet.AnchorPoint = Vector2.new(0.5, 1)
		spriet.Position = UDim2.new(i / SPRIETEN, 0, 0, 1)
		spriet.Size = UDim2.fromOffset(2, 4)
		spriet.BackgroundColor3 = KLEUR.grasLicht
		spriet.BorderSizePixel = 0
		-- het paar uit het origineel leunt uit elkaar: de eerste naar rechts, de tweede terug
		spriet.Rotation = if i % 2 == 0 then -6 else 5
		spriet.ZIndex = 3
		spriet.Parent = grasvak
	end
	for j = 0, DONKER - 1 do
		-- dezelfde reeks als het origineel: x loopt van 2 met stappen van 14
		local x = 2 + j * 14
		local spriet = Instance.new("Frame")
		spriet.AnchorPoint = Vector2.new(0.5, 1)
		spriet.Position = UDim2.new(x / (DONKER * 14), 0, 0, 1)
		spriet.Size = UDim2.fromOffset(2, 5 + (x * 11) % 6)
		spriet.BackgroundColor3 = KLEUR.grasSpriet
		spriet.BorderSizePixel = 0
		spriet.Rotation = 8   -- de -1 in x over zijn hoogte
		spriet.ZIndex = 3
		spriet.Parent = grasvak
	end
	-- de bloemetjes uit drawGrass(): om en om goud en wit, in het origineel per tachtig pixels
	for i = 0, BLOEMEN - 1 do
		local bloem = Instance.new("Frame")
		bloem.AnchorPoint = Vector2.new(0.5, 0.5)
		bloem.Position = UDim2.new(i / BLOEMEN + 0.03, 0, 0, 8 + (i * 7) % 6)
		bloem.Size = UDim2.fromOffset(4, 4)
		bloem.BackgroundColor3 = if i % 2 == 0 then Theme.color.gold else Theme.color.white
		bloem.BorderSizePixel = 0
		bloem.ZIndex = 3
		UI.corner(bloem, 2)
		bloem.Parent = grasvak
	end

	-- het spoor: drawTrail() trekt één lijn van 6 en daaroverheen een van 2. Twee lagen zou
	-- honderd Frames per beeldje kosten, dus het is er één van vijf dik.
	local spoor: { Frame } = {}
	for i = 1, STAPPEN do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(1, 5)
		f.BackgroundColor3 = Theme.color.white
		f.BackgroundTransparency = 0.15
		f.BorderSizePixel = 0
		f.Visible = false
		f.ZIndex = 4
		UI.corner(f, 2)   -- lineCap: round
		f.Parent = lucht
		spoor[i] = f
	end

	-- het vliegtuigje. De onderdelen staan in de coördinaten van drawPlane(): de neus op
	-- x = 32, de staart op x = -32. Het vak zelf is nul groot, dus draaien draait om de neus
	-- van de curve mee, precies zoals ctx.translate + ctx.rotate.
	local vliegtuig = Instance.new("Frame")
	vliegtuig.Name = "Plane"
	vliegtuig.AnchorPoint = Vector2.new(0.5, 0.5)
	vliegtuig.Size = UDim2.fromOffset(0, 0)
	vliegtuig.BackgroundTransparency = 1
	vliegtuig.ZIndex = 5
	vliegtuig.Visible = false
	vliegtuig.Parent = lucht

	ovaal(vliegtuig, 0, 10, 28, 4, Theme.color.black, 0.88)
	local staartVlak = blokje(vliegtuig, -29, -2, 10, 4, KLEUR.vleugel)
	UI.stroke(staartVlak, KLEUR.rompRand, 2)
	local staart = blokje(vliegtuig, -24, -13, 9, 14, KLEUR.vleugel, -8)
	UI.stroke(staart, KLEUR.rompRand, 2)
	UI.corner(staart, 2)
	local vleugel = blokje(vliegtuig, 4, 12, 16, 12, KLEUR.vleugel, -6)
	UI.stroke(vleugel, KLEUR.rompRand, 2)
	UI.corner(vleugel, 2)
	local romp = blokje(vliegtuig, 0, 0, 64, 16, KLEUR.romp)
	UI.corner(romp, 8)
	UI.stroke(romp, KLEUR.rompRand, 2)
	local ruit = ovaal(vliegtuig, 16, -4, 8, 3.5, KLEUR.ruit)
	ruit.Rotation = -9   -- de -0.15 radialen uit drawPlane()
	UI.stroke(ruit, KLEUR.ruitRand, 1.5)
	for i = 0, 3 do
		rond(vliegtuig, 2 - i * 6, -2, 1.5, KLEUR.ruit)
	end
	local blad1 = blokje(vliegtuig, 33, 0, 2, 12, Theme.color.black)
	blad1.BackgroundTransparency = 0.5
	local blad2 = blokje(vliegtuig, 34, 0, 2, 8, Theme.color.black)
	blad2.BackgroundTransparency = 0.5
	rond(vliegtuig, 33, 0, 2, Color3.fromHex("333333"))

	-- de knal na de crash: drawCrashEffect() in acht Frames
	local knalVak = Instance.new("Frame")
	knalVak.Name = "Boom"
	knalVak.AnchorPoint = Vector2.new(0.5, 0.5)
	knalVak.Size = UDim2.fromOffset(0, 0)
	knalVak.BackgroundTransparency = 1
	knalVak.ZIndex = 6
	knalVak.Visible = false
	knalVak.Parent = lucht
	local vuur = rond(knalVak, 0, 0, 1, KLEUR.vuur, 0.3)
	local vonk = rond(knalVak, 0, 0, 1, KLEUR.vonk, 0.1)
	local rookbollen: { Frame } = {}
	for i = 1, 6 do
		rookbollen[i] = rond(knalVak, 0, 0, 1, KLEUR.rook, 0.5)
	end

	-- ---------- wat er over de lucht heen staat ----------
	-- Een groot wit cijfer met een donkere rand en een schaduw eronder: dat is wat
	-- `-webkit-text-stroke: 2px` en `text-shadow: 0 4px 0 rgba(0,0,0,0.3)` doen. De schaduw
	-- is een tweede label erachter, want text-shadow bestaat hier niet. De tweede schaduw
	-- uit dezelfde regel, `0 0 30px rgba(255,255,255,0.8)`, is een gloed zonder verspringing;
	-- die valt weg, want een UIStroke heeft een harde rand en zou een witte ring om de
	-- cijfers trekken in plaats van een waas.
	local function witCijfer(ouderVak: Instance, maat: number, randKleur: Color3, volgorde: number): (TextLabel, TextLabel, UIStroke)
		local vak = Instance.new("Frame")
		vak.LayoutOrder = volgorde
		vak.Size = UDim2.new(1, 0, 0, maat + 16)
		vak.BackgroundTransparency = 1
		vak.Parent = ouderVak

		local schaduw = UI.label(vak, "", {
			size = maat, color = Theme.color.black, font = Theme.font.num,
			align = Enum.TextXAlignment.Center,
		})
		schaduw.Position = UDim2.fromOffset(0, 4)
		schaduw.Size = UDim2.fromScale(1, 1)
		schaduw.TextTransparency = 0.7
		schaduw.TextYAlignment = Enum.TextYAlignment.Center

		local tekst = UI.label(vak, "", {
			size = maat, color = Theme.color.white, font = Theme.font.num,
			align = Enum.TextXAlignment.Center,
		})
		tekst.Size = UDim2.fromScale(1, 1)
		tekst.TextYAlignment = Enum.TextYAlignment.Center
		local rand = UI.stroke(tekst, randKleur, 2)
		-- Contextual in plaats van Border: op een label zonder achtergrond legt Roblox de rand
		-- dan om de letters. Met Border krijg je een kader om het vak, en dat is niet wat
		-- `-webkit-text-stroke` doet.
		rand.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		return tekst, schaduw, rand
	end

	-- .multiplier-display: 96 pixels, midden in de lucht.
	local multVak = Instance.new("Frame")
	multVak.Name = "Multiplier"
	multVak.AnchorPoint = Vector2.new(0.5, 0.5)
	multVak.Position = UDim2.fromScale(0.5, 0.5)
	multVak.Size = UDim2.new(1, 0, 0, 112)
	multVak.BackgroundTransparency = 1
	multVak.ZIndex = 7
	multVak.Visible = false
	multVak.Parent = lucht
	local multTekst, multSchaduw, multRand = witCijfer(multVak, 96, KLEUR.tekstRand, 1)

	-- .status-label: het pilletje 70 pixels onder het midden.
	local statusPil = Instance.new("Frame")
	statusPil.Name = "Status"
	statusPil.AnchorPoint = Vector2.new(0.5, 0.5)
	statusPil.Position = UDim2.new(0.5, 0, 0.5, 70)
	statusPil.Size = UDim2.fromOffset(0, 25)
	statusPil.AutomaticSize = Enum.AutomaticSize.X
	statusPil.BackgroundColor3 = KLEUR.pil
	statusPil.BackgroundTransparency = 0.28   -- rgba(10,30,60,0.72)
	statusPil.BorderSizePixel = 0
	statusPil.ZIndex = 7
	statusPil.Visible = false
	UI.corner(statusPil, 12)
	UI.padding4(statusPil, 0, 12, 0, 12)
	statusPil.Parent = lucht
	local statusTekst = UI.label(statusPil, "", {
		size = Theme.text.label, color = Theme.color.white, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center,
	})
	statusTekst.Size = UDim2.new(0, 0, 1, 0)
	statusTekst.AutomaticSize = Enum.AutomaticSize.X
	statusTekst.ZIndex = 7

	-- .countdown: "NEXT ROUND" met het aantal seconden eronder.
	local aftelVak = Instance.new("Frame")
	aftelVak.Name = "Countdown"
	aftelVak.AnchorPoint = Vector2.new(0.5, 0.5)
	aftelVak.Position = UDim2.fromScale(0.5, 0.5)
	aftelVak.Size = UDim2.new(1, 0, 0, 130)
	aftelVak.BackgroundTransparency = 1
	aftelVak.ZIndex = 7
	aftelVak.Visible = false
	aftelVak.Parent = lucht
	local aftelLijst = UI.list(aftelVak, 12)   -- .countdown-label margin-bottom: 12
	aftelLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	aftelLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	local aftelKop = UI.label(aftelVak, "NEXT ROUND", {
		size = Theme.text.body, color = Theme.color.white, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center,
	})
	aftelKop.ZIndex = 7
	aftelKop.LayoutOrder = 1
	local aftelTekst, aftelSchaduw = witCijfer(aftelVak, 80, KLEUR.tekstRand, 2)

	for _, l in { multTekst, multSchaduw, aftelTekst, aftelSchaduw } do
		l.ZIndex = 7
	end

	-- ---------- de twee lijsten eronder ----------
	local spelersRij = Instance.new("Frame")
	spelersRij.Name = "PlayersSection"
	spelersRij.AnchorPoint = Vector2.new(0, 1)
	spelersRij.Position = UDim2.fromScale(0, 1)
	spelersRij.Size = UDim2.new(1, 0, 0, 14 + KOP_H + NOTITIE_H + 14)
	spelersRij.BackgroundTransparency = 1
	spelersRij.Parent = hoofd

	-- .players-section is in het raster een rij `auto` met een max-height van 180: hij is zo
	-- hoog als zijn inhoud en niet hoger, en wat overblijft is lucht. Met twee lege lijsten
	-- is dat een kop en één regel, niet de volle 180 -- daar zit het grootste verschil met
	-- een vaste hoogte. Beide lijsten geven door hoe hoog hun inhoud is; het hoogste wint.
	local tafelHoog, winstHoog = NOTITIE_H, NOTITIE_H
	local function meetSpelers()
		-- de paneelmarge van 14 boven en onder, plus de kop met zijn marge van 10
		local wens = math.min(14 + KOP_H + math.max(tafelHoog, winstHoog) + 14, SPELERS_H)
		-- De lucht is de rij `1fr` en heeft voorrang: op een laag venster krimpt de onderste
		-- rij mee tot er weer 320 pixels overblijven om in te vliegen.
		local h = hoofd.AbsoluteSize.Y
		if h > 0 then
			wens = math.max(14 + KOP_H + NOTITIE_H + 14,
				math.min(wens, h - (BALK_H + RIJGAT + RIJGAT + LUCHT_MIN)))
		end
		spelersRij.Size = UDim2.new(1, 0, 0, wens)
		lucht.Size = UDim2.new(1, 0, 1, -(BALK_H + RIJGAT + wens + RIJGAT))
	end

	-- .players-list h3 .count: neon tekst op een neongroen vlak met een rand in --border.
	-- Bij de feed staat er een .live-dot in, dus de pil is een rijtje van stip plus tekst.
	local function telPil(ouderVak: Instance, tekst: string, metStip: boolean): (TextLabel, Frame?)
		local pil = Instance.new("Frame")
		pil.Name = "Count"
		pil.AnchorPoint = Vector2.new(1, 0.5)
		pil.Position = UDim2.new(1, 0, 0.5, 0)
		-- De maat hieronder is de ondergrens: een getal van drie cijfers of het woord LIVE.
		-- AutomaticSize rekt hem op als er meer in komt te staan.
		pil.Size = UDim2.fromOffset(if metStip then 54 else 30, 20)
		pil.AutomaticSize = Enum.AutomaticSize.X
		pil.BackgroundColor3 = Theme.color.neon
		pil.BackgroundTransparency = Theme.alpha.activeNav   -- rgba(62,207,142,0.10)
		pil.BorderSizePixel = 0
		UI.corner(pil, Theme.radius.pill)
		UI.stroke(pil)
		UI.padding4(pil, 0, 8, 0, 8)
		pil.Parent = ouderVak
		local pilRij = UI.list(pil, 5, Enum.FillDirection.Horizontal)
		pilRij.VerticalAlignment = Enum.VerticalAlignment.Center
		pilRij.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local stip: Frame? = nil
		if metStip then
			local s = Instance.new("Frame")
			s.Name = "LiveDot"
			s.LayoutOrder = 1
			s.Size = UDim2.fromOffset(7, 7)
			s.BackgroundColor3 = Theme.color.neon
			s.BorderSizePixel = 0
			UI.corner(s, 4)
			s.Parent = pil
			stip = s
		end

		-- De pil staat in de <h3> en erft dus diens vette letter.
		local t = UI.label(pil, tekst, {
			size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiBold,
		})
		t.LayoutOrder = 2
		t.Size = UDim2.new(0, 0, 1, 0)
		t.AutomaticSize = Enum.AutomaticSize.X
		t.TextYAlignment = Enum.TextYAlignment.Center
		return t, stip
	end

	-- .players-list: een paneel met padding 14, een kop, en daaronder een lijst die scrolt.
	local function lijstPaneel(links: boolean, titel: string, telling: string, metStip: boolean): (ScrollingFrame, TextLabel, Frame?)
		local paneel = UI.panel(spelersRij, "PlayersList")
		paneel.AutomaticSize = Enum.AutomaticSize.None
		paneel.Position = if links then UDim2.new() else UDim2.new(0.5, RIJGAT / 2, 0, 0)
		paneel.Size = UDim2.new(0.5, -RIJGAT / 2, 1, 0)
		paneel.ClipsDescendants = true
		paneelMarge(paneel, 14, 14, 14, 14)

		local kop = Instance.new("Frame")
		kop.Name = "Head"
		kop.Size = UDim2.new(1, 0, 0, KOP_H - 10)
		kop.BackgroundTransparency = 1
		kop.Parent = paneel
		local k = UI.label(kop, titel, {
			size = Theme.text.small, color = Theme.color.muted, font = Theme.font.uiBold,
		})
		k.Size = UDim2.new(1, -70, 1, 0)
		k.TextYAlignment = Enum.TextYAlignment.Center
		k.TextTruncate = Enum.TextTruncate.AtEnd
		local telLabel, stip = telPil(kop, telling, metStip)

		local lijst = Instance.new("ScrollingFrame")
		lijst.Name = "Rows"
		lijst.Position = UDim2.fromOffset(0, KOP_H)
		lijst.Size = UDim2.new(1, 0, 1, -KOP_H)
		lijst.BackgroundTransparency = 1
		lijst.BorderSizePixel = 0
		lijst.ScrollBarThickness = 4
		lijst.ScrollBarImageColor3 = Theme.color.border
		lijst.CanvasSize = UDim2.new()
		lijst.AutomaticCanvasSize = Enum.AutomaticSize.Y
		lijst.Parent = paneel
		UI.list(lijst, 0)
		return lijst, telLabel, stip
	end

	local tafelLijst, tafelTelling = lijstPaneel(true, "YOUR ROUND", "0", false)
	local winstLijst, _, levendStip = lijstPaneel(false, "LIVE WINS \u{00B7} ALL PLAYERS", "LIVE", true)

	-- .player-row: naam links, inzet en multiplier rechts, met een streepje eronder.
	type RijOpts = { zelf: boolean?, gecashed: boolean?, verloren: boolean?, meta: string? }
	local function spelerRij(ouderVak: Instance, volgorde: number, naam: string, bedrag: string, mult: string, o: RijOpts)
		local rij = Instance.new("Frame")
		rij.Name = "PlayerRow"
		rij.LayoutOrder = volgorde
		rij.Size = UDim2.new(1, 0, 0, 24)
		rij.BackgroundTransparency = 1
		rij.Parent = ouderVak
		UI.padding4(rij, 0, 4, 0, 4)

		-- .player-row.lost { opacity: 0.4 }: alles in de regel vervaagt mee.
		local vaag = if o.verloren then 0.6 else 0

		local n = UI.label(rij, string.sub(naam, 1, 16), {
			size = Theme.text.tiny,
			color = if o.zelf then Theme.color.neon else Theme.color.text,
			font = if o.zelf then Theme.font.uiBold else Theme.font.ui,
		})
		n.Size = UDim2.new(1, if o.meta then -226 else -150, 1, 0)
		n.TextYAlignment = Enum.TextYAlignment.Center
		n.TextTruncate = Enum.TextTruncate.AtEnd
		-- .player-row .name is 0.85 doorzichtig, tenzij het je eigen regel is
		n.TextTransparency = math.max(vaag, if o.zelf then 0 else 0.15)

		if o.meta then
			local m = UI.label(rij, o.meta, {
				size = Theme.text.tiny, color = Theme.color.muted, align = Enum.TextXAlignment.Right,
			})
			m.AnchorPoint = Vector2.new(1, 0)
			m.Position = UDim2.new(1, -152, 0, 0)
			m.Size = UDim2.fromOffset(70, 24)
			m.TextYAlignment = Enum.TextYAlignment.Center
			m.TextTransparency = vaag
		end

		local b = UI.label(rij, bedrag, {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
			align = Enum.TextXAlignment.Right,
		})
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -72, 0, 0)
		b.Size = UDim2.fromOffset(70, 24)
		b.TextYAlignment = Enum.TextYAlignment.Center
		b.TextTransparency = vaag

		local m = UI.label(rij, mult, {
			size = Theme.text.tiny,
			color = if o.gecashed then Theme.color.neon elseif o.verloren then Theme.color.red else Theme.color.muted,
			font = Theme.font.num,
			align = Enum.TextXAlignment.Right,
		})
		m.AnchorPoint = Vector2.new(1, 0)
		m.Position = UDim2.new(1, 0, 0, 0)
		m.Size = UDim2.fromOffset(60, 24)
		m.TextYAlignment = Enum.TextYAlignment.Center
		m.TextTransparency = vaag

		local streep = Instance.new("Frame")
		streep.AnchorPoint = Vector2.new(0, 1)
		streep.Position = UDim2.fromScale(0, 1)
		streep.Size = UDim2.new(1, 8, 0, 1)
		streep.BackgroundColor3 = KLEUR.rijRand
		streep.BackgroundTransparency = 0.5
		streep.BorderSizePixel = 0
		streep.Parent = rij
	end

	-- De lege lijst krijgt dezelfde regel als in de webversie, in de stijl van .odds-note.
	local function legeRegel(ouderVak: Instance, tekst: string)
		local t = UI.label(ouderVak, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Size = UDim2.new(1, -6, 0, 20)
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.LineHeight = 1.7
	end

	-- ---------- de aside ----------
	-- Eén paneel, precies zoals de markup: het inzetveld met de fiches, de schakelaar voor
	-- automatisch uitstappen, het doelveld dat daarbij hoort, en de knop.
	-- De volgorde in de aside is de volgorde waarin de panelen erbij komen: inzetvak,
	-- statistieken, kansen. Common.columns zette de kop en het saldo er al boven.
	local betBox = Common.betBox(bediening, 10)
	local zetPaneel = betBox.panel

	-- De UIListLayout van Common.betBox houdt overal 6 pixels aan -- dat is de `margin-top`
	-- van .chips. Waar de CSS meer vraagt komt er een leeg vakje bij, want één lijst kan
	-- geen twee verschillende gaten. Hier de `margin-bottom: 14px` van .field-group.
	local function ruimte(naam: string, hoogte: number)
		local v = Instance.new("Frame")
		v.Name = naam
		v.Size = UDim2.new(1, 0, 0, hoogte)
		v.BackgroundTransparency = 1
		v.Parent = zetPaneel
	end
	ruimte("GapStake", 14 - 6)

	-- .toggle-row: de schakelaar plus zijn etiket, samen aan te klikken.
	local schakelRij = Instance.new("TextButton")
	schakelRij.Name = "ToggleRow"
	schakelRij.Text = ""
	schakelRij.AutoButtonColor = false
	schakelRij.BackgroundTransparency = 1
	-- .toggle-row is 40 hoog (20 met padding 10 boven en onder) en er zit geen marge onder.
	-- De lijst zet er zelf 6 achter, dus het vak is 34 en de schakelaar hangt op zijn eigen
	-- 10 van boven: samen weer 40 tot het volgende veld.
	schakelRij.Size = UDim2.new(1, 0, 0, 34)
	schakelRij.Parent = zetPaneel

	local schakelaar = Instance.new("Frame")
	schakelaar.Name = "Switch"
	schakelaar.Position = UDim2.fromOffset(0, 10)
	schakelaar.Size = UDim2.fromOffset(38, 20)
	schakelaar.BackgroundColor3 = Theme.color.black
	schakelaar.BackgroundTransparency = Theme.alpha.inputBg
	schakelaar.BorderSizePixel = 0
	UI.corner(schakelaar, 12)
	local schakelRand = UI.stroke(schakelaar)
	schakelaar.Parent = schakelRij

	local knopje = Instance.new("Frame")
	knopje.Name = "Knob"
	knopje.Position = UDim2.fromOffset(2, 2)
	knopje.Size = UDim2.fromOffset(14, 14)
	knopje.BackgroundColor3 = Theme.color.muted
	knopje.BorderSizePixel = 0
	UI.corner(knopje, 7)
	knopje.Parent = schakelaar

	local schakelEtiket = UI.label(schakelRij, "AUTO CASHOUT", {
		size = Theme.text.small, color = Theme.color.muted,
	})
	schakelEtiket.Position = UDim2.fromOffset(48, 10)   -- 38 breed plus de gap van 10
	schakelEtiket.Size = UDim2.new(1, -48, 0, 20)
	schakelEtiket.TextYAlignment = Enum.TextYAlignment.Center

	-- #autoField staat op `opacity: 0.4` tot de schakelaar om gaat. Een CanvasGroup doet
	-- precies dat: alles wat erin staat wordt in één keer doorzichtig.
	local autoVak = Instance.new("CanvasGroup")
	autoVak.Name = "AutoField"
	autoVak.Size = UDim2.new(1, 0, 0, 63)
	autoVak.BackgroundTransparency = 1
	autoVak.GroupTransparency = 0.6
	autoVak.Parent = zetPaneel
	UI.list(autoVak, 6)

	local autoKop = Instance.new("Frame")
	autoKop.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	autoKop.BackgroundTransparency = 1
	autoKop.Parent = autoVak
	UI.label(autoKop, "CASH OUT AT", { size = Theme.text.small, color = Theme.color.muted })
	local autoHint = UI.label(autoKop, "\u{00D7}", {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
	})
	autoHint.TextTransparency = 0.3   -- .field-label .hint { opacity: 0.7 }

	local autoVeld = UI.numberBox(autoVak, "2.00")
	autoVeld.TextEditable = false     -- pointer-events: none zolang de schakelaar uit staat

	-- #autoField sluit af met dezelfde `margin-bottom: 14px` en .btn-primary zet er zijn
	-- eigen `margin-top: 8px` bovenop.
	ruimte("GapAuto", 14 + 8 - 6)

	local knop = UI.primary(zetPaneel, "PLACE BET")
	-- .btn-bet: verloop van 135 graden, neon naar neon-dim. De knop wisselt van kleur met
	-- de fase, net als de klassen btn-bet, btn-cashout en btn-waiting.
	local knopVerloop = UI.gradient(knop, Theme.color.neon, Theme.color.neonDim, 135)
	local knopRand = UI.stroke(knop)
	knopRand.Transparency = 1

	-- ---------- statistieken, kansen en het bewijs ----------
	Common.statsPanel(bediening, "crash")
	local oddsVak = Common.oddsPanel(bediening, "odds",
		"RTP *97%*. The chance a flight reaches Mx is 0.97 / M. Around 3% of rounds crash straight away at 1.00x. Auto cash-out pays exactly at your target.")

	-- #mpFair: de tweede .odds-note in hetzelfde paneel. In de CSS staat "Shared round #n"
	-- vet en dus goud, de rest grijs. Common.accent maakt daar RichText van en ontsmet de
	-- tekst onderweg, zodat aanzetten hier niets opent.
	local rondeRegel = UI.label(oddsVak, "", { size = Theme.text.tiny, color = Theme.color.muted })
	rondeRegel.RichText = true
	rondeRegel.TextWrapped = true
	rondeRegel.AutomaticSize = Enum.AutomaticSize.Y
	rondeRegel.Size = UDim2.new(1, 0, 0, 34)   -- twee regels; AutomaticSize rekt hem op
	rondeRegel.TextYAlignment = Enum.TextYAlignment.Top
	rondeRegel.LineHeight = 1.7

	local function fairRegel(): TextLabel
		local t = UI.label(oddsVak, "", { size = 10, color = Theme.color.muted, font = Theme.font.num })
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Size = UDim2.new(1, 0, 0, 14)
		t.TextYAlignment = Enum.TextYAlignment.Top
		return t
	end
	local commitRegel = fairRegel()
	local zaadRegel = fairRegel()
	local puntRegel = fairRegel()

	-- ---------- de stand ----------
	-- Wie er in deze ronde zit leest het scherm uit wat de server stuurt, niet uit een
	-- eigen vlaggetje: dan klopt het ook als je net binnenkwam of even weg was.
	local stand: any = nil
	-- Op nummer, niet op naam: twee spelers kunnen dezelfde weergavenaam hebben, en dan
	-- zou het scherm de stand van een naamgenoot voor die van jezelf aanzien.
	local mijnId = Players.LocalPlayer.UserId
	local historie: { number } = {}
	type Winst = { naam: string, bet: number, mult: number, zelf: boolean }
	local winsten: { Winst } = {}
	local gezien: { [string]: boolean } = {}
	local vorigeRonde: number = -1
	local knalMoment = 0
	local autoAan = false

	local function autoDoel(): number
		return math.max(1.01, Money.round2(tonumber(autoVeld.Text) or 1.01))
	end

	local function mijnInzet(): any
		if not stand or not stand.bets then return nil end
		for _, b in stand.bets do
			if b.id == mijnId then return b end
		end
		return nil
	end

	-- ---------- de lijsten vullen ----------
	local function wis(vak: Instance)
		for _, k in vak:GetChildren() do
			if k:IsA("GuiObject") then k:Destroy() end
		end
	end

	local function toonSpelers()
		wis(tafelLijst)
		local lijst = if stand and stand.bets then stand.bets else {}
		tafelTelling.Text = string.format("%d", #lijst)
		tafelHoog = if #lijst == 0 then NOTITIE_H else math.min(#lijst, TAFEL) * REGEL_H
		meetSpelers()
		if #lijst == 0 then
			legeRegel(tafelLijst, "Nobody has bet on this round yet. Be the first.")
			return
		end
		-- De gedeelde tafel in de webversie komt binnen op amount.desc; hier sorteren we
		-- hem zelf, zodat de grootste inzet bovenaan staat.
		table.sort(lijst, function(a, b)
			return a.bet > b.bet
		end)
		local gecrasht = stand.phase == "crashed"
		for i, b in lijst do
			if i > TAFEL then break end
			local verloren = gecrasht and not b.cashed
			local mult = if b.cashed
				then Money.fmt(b.cashed) .. "\u{00D7}"
				elseif verloren then "\u{2715}"
				else "\u{2014}"
			spelerRij(tafelLijst, i, b.naam, "$" .. Money.fmt(b.bet), mult, {
				zelf = b.id == mijnId,
				gecashed = b.cashed ~= nil,
				verloren = verloren,
			})
		end
	end

	-- De feed van de webversie haalt de winst van iedereen op bij de server. Die lijst is er
	-- hier niet; wat wel binnenkomt is elke cashout van deze tafel, en dat is precies wat
	-- eronder hoort te staan. Elke cashout telt één keer mee, per ronde bijgehouden.
	local function toonWinsten()
		wis(winstLijst)
		winstHoog = if #winsten == 0 then NOTITIE_H else #winsten * REGEL_H
		meetSpelers()
		if #winsten == 0 then
			legeRegel(winstLijst, "No wins yet. Yours will show up here for everyone.")
			return
		end
		for i, w in winsten do
			spelerRij(winstLijst, i, if w.zelf then "YOU" else w.naam,
				"$" .. Money.fmt(w.bet), Money.fmt(w.mult) .. "\u{00D7}", {
					zelf = w.zelf, gecashed = true, meta = "CRASH",
				})
		end
	end

	local function toonHistorie()
		for _, k in balkVak:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		for i, m in historie do
			local tekstKleur, randKleur, randDoorzicht = ficheKleur(m)
			local fiche = Instance.new("Frame")
			fiche.Name = "Chip"
			fiche.LayoutOrder = i
			-- De cijfers staan in het monospace-lettertype, dus de breedte is te rekenen:
			-- padding van 10 links en rechts plus 0,6 em per teken. AutomaticSize houdt hem
			-- ruim genoeg als een multiplier boven de honderd komt.
			local tekst = Money.fmt(m) .. "\u{00D7}"
			fiche.Size = UDim2.fromOffset(20 + math.ceil(#tekst * 6.6), 22)
			fiche.AutomaticSize = Enum.AutomaticSize.X
			fiche.BackgroundColor3 = Theme.color.black
			fiche.BackgroundTransparency = 0.6   -- rgba(0,0,0,0.4)
			fiche.BorderSizePixel = 0
			UI.corner(fiche, 12)
			local s = UI.stroke(fiche, randKleur)
			s.Transparency = randDoorzicht
			UI.padding4(fiche, 0, 10, 0, 10)
			fiche.Parent = balkVak

			local t = UI.label(fiche, tekst, {
				size = Theme.text.small, color = tekstKleur, font = Theme.font.num,
			})
			t.Size = UDim2.new(0, 0, 1, 0)
			t.AutomaticSize = Enum.AutomaticSize.X
			t.TextYAlignment = Enum.TextYAlignment.Center
		end
	end

	local function toonFairness()
		-- #mpFair staat op `hidden` zolang er geen gedeelde ronde is. Onzichtbare kinderen
		-- slaat een UIListLayout over, dus dan houdt het paneel ook geen ruimte vrij.
		local erisEen = stand ~= nil and stand.phase ~= "idle"
		rondeRegel.Visible = erisEen
		commitRegel.Visible = erisEen
		zaadRegel.Visible = erisEen
		if not erisEen then
			puntRegel.Visible = false
			return
		end
		local kort = function(s: any): string
			local t = tostring(s)
			return if #t > 32 then string.sub(t, 1, 32) .. "\u{2026}" else t
		end
		rondeRegel.Text = Common.accent(string.format(
			"*Shared round #%d* \u{00B7} the server drew the crash point before betting opened.",
			tonumber(stand.id) or 0))
		commitRegel.Text = "commit " .. (if stand.commit then kort(stand.commit) else "\u{2014}")
		zaadRegel.Text = "seed " .. (if stand.seed then kort(stand.seed) else "revealed when the flight is over")
		-- De regel met het crashpunt komt er pas bij als het zaad vrijgegeven is.
		puntRegel.Visible = stand.crashAt ~= nil
		puntRegel.Text = if stand.crashAt then "crashed at " .. Money.fmt(stand.crashAt) .. "x" else ""
	end

	-- ---------- de knop ----------
	-- updateButton() uit de webversie, met dezelfde teksten en dezelfde drie jasjes.
	local function zetKnop()
		local fase = if stand then stand.phase else "idle"
		local mijn = mijnInzet()
		local actief = false
		local tekst = "PLACE BET"

		if fase == "waiting" then
			if mijn then
				tekst = "WAITING\u{2026}"
			else
				tekst, actief = "PLACE BET", true
			end
		elseif fase == "flying" then
			if mijn and not mijn.cashed then
				tekst = "CASH OUT $" .. Money.fmt(Money.floor2(mijn.bet * (tonumber(stand.mult) or 1)))
				actief = true
			else
				tekst = if mijn then "CASHED OUT \u{2713}" else "IN FLIGHT"
			end
		elseif fase == "crashed" then
			tekst = "CRASHED"
		else
			-- "idle": de server heeft nog geen ronde. Wachten dus, net als tussen twee rondes.
			tekst = "WAITING\u{2026}"
		end

		knop.Text = tekst
		knop.Active = actief
		betBox.lock(fase ~= "waiting" or mijn ~= nil)

		if not actief then
			-- .btn-waiting: vlak --panel-light met een rand, plus de opacity 0.6 van :disabled
			knop.BackgroundColor3 = Theme.color.panelLight
			knopVerloop.Color = ColorSequence.new(Theme.color.panelLight)
			knop.BackgroundTransparency = Theme.alpha.disabled
			knop.TextColor3 = Theme.color.muted
			knop.Font = Theme.font.ui
			knopRand.Transparency = 0
		elseif fase == "flying" then
			-- .btn-cashout: goud, en in de webversie pulseert de gloed eromheen
			knop.BackgroundColor3 = Theme.color.gold
			knopVerloop.Color = ColorSequence.new(Theme.color.gold, KLEUR.goudDonker)
			knop.BackgroundTransparency = 0
			knop.TextColor3 = Theme.color.bg
			knop.Font = Theme.font.uiBold
			knopRand.Transparency = 1
		else
			knop.BackgroundColor3 = Theme.color.neon
			knopVerloop.Color = ColorSequence.new(Theme.color.neon, Theme.color.neonDim)
			knop.BackgroundTransparency = 0
			knop.TextColor3 = Theme.color.bg
			knop.Font = Theme.font.uiBold
			knopRand.Transparency = 1
		end
	end

	-- ---------- de schakelaar ----------
	local function zetSchakelaar()
		if autoAan then
			schakelaar.BackgroundColor3 = Theme.color.neon
			schakelaar.BackgroundTransparency = 0.85   -- rgba(62,207,142,0.15)
			schakelRand.Color = Theme.color.neon
			knopje.Position = UDim2.fromOffset(20, 2)
			knopje.BackgroundColor3 = Theme.color.neon
			autoVak.GroupTransparency = 0
			autoVeld.TextEditable = true
		else
			schakelaar.BackgroundColor3 = Theme.color.black
			schakelaar.BackgroundTransparency = Theme.alpha.inputBg
			schakelRand.Color = Theme.color.border
			knopje.Position = UDim2.fromOffset(2, 2)
			knopje.BackgroundColor3 = Theme.color.muted
			autoVak.GroupTransparency = 0.6            -- opacity: 0.4
			autoVeld.TextEditable = false
		end
	end

	schakelRij.Activated:Connect(function()
		autoAan = not autoAan
		zetSchakelaar()
	end)

	autoVeld.FocusLost:Connect(function()
		autoVeld.Text = Money.fmt(autoDoel())
	end)

	-- ---------- de vlucht tekenen ----------
	local baanX: { number } = {}
	local baanY: { number } = {}

	-- updatePathPoints(): dezelfde vensters en schalen als de webversie.
	local function rekenBaan(verstreken: number, mult: number, W: number, H: number)
		local xMax, xMin = W * 0.85, W * 0.08
		local yMax, yMin = H - GRAS - 10, H * 0.12
		local venster = math.max(8, verstreken * 1.1)
		local xSchaal = (xMax - xMin) / venster
		local getoond = math.max(2, mult * 1.3)
		local ySchaal = (yMax - yMin) / math.log(getoond)
		for i = 0, STAPPEN do
			local t = verstreken * i / STAPPEN
			local m = multBij(t)
			baanX[i + 1] = xMin + t * xSchaal
			baanY[i + 1] = yMax - math.log(math.max(1, m)) * ySchaal
		end
	end

	local function tekenSpoor(gecrasht: boolean)
		for i = 1, STAPPEN do
			local f = spoor[i]
			f.Visible = true
			f.BackgroundColor3 = if gecrasht then KLEUR.spoorCrash else Theme.color.white
			zetLijn(f, baanX[i], baanY[i], baanX[i + 1], baanY[i + 1], 5)
		end
	end

	local function wisSpoor()
		for _, f in spoor do
			f.Visible = false
		end
	end

	local function zetVliegtuig(x: number, y: number, hoek: number)
		vliegtuig.Visible = true
		vliegtuig.Position = UDim2.fromOffset(x, y)
		vliegtuig.Rotation = math.deg(hoek)
		-- de propeller: twee bladen die om en om lang en kort zijn
		local fase = os.clock() * 33
		blad1.Size = UDim2.fromOffset(2, (math.abs(math.sin(fase)) * 10 + 2) * 2)
		blad2.Size = UDim2.fromOffset(2, (math.abs(math.cos(fase)) * 10 + 2) * 1.2)
	end

	-- drawCrashEffect(): een oranje bol die uitdijt, een gele kern en zes rookpluimen.
	local function zetKnal(x: number, y: number, t: number)
		knalVak.Visible = true
		knalVak.Position = UDim2.fromOffset(x, y)
		local r = 10 + t * 60
		vuur.Size = UDim2.fromOffset(r * 2, r * 2)
		vuur.BackgroundTransparency = math.clamp(1 - (0.7 - t * 0.5), 0, 1)
		local vc = vuur:FindFirstChildOfClass("UICorner")
		if vc then vc.CornerRadius = UDim.new(0, r) end
		vonk.Size = UDim2.fromOffset(r * 1.2, r * 1.2)
		vonk.BackgroundTransparency = math.clamp(1 - (0.9 - t * 0.7), 0, 1)
		local nc = vonk:FindFirstChildOfClass("UICorner")
		if nc then nc.CornerRadius = UDim.new(0, r * 0.6) end
		for i, bol in rookbollen do
			local a = (i - 1) / 6 * math.pi * 2
			local straal = 8 + t * 8
			bol.Position = UDim2.fromOffset(math.cos(a) * r * 0.9, math.sin(a) * r * 0.9)
			bol.Size = UDim2.fromOffset(straal * 2, straal * 2)
			bol.BackgroundTransparency = math.clamp(1 - (0.5 - t * 0.4), 0, 1)
			local c = bol:FindFirstChildOfClass("UICorner")
			if c then c.CornerRadius = UDim.new(0, straal) end
		end
	end

	-- ---------- de wolken ----------
	local luchtW, luchtH = 0, 0
	local function zaaiWolken()
		for _, w in wolken do
			w.x = math.random() * luchtW * 1.2
			w.y = 30 + math.random() * (luchtH * 0.55)
			w.vak.Position = UDim2.fromOffset(w.x, w.y)
		end
	end

	-- De webversie schuift ze per beeldje op; hier gaat dat maal de tijd sinds het vorige
	-- beeldje, zodat ze op elke beeldsnelheid even hard drijven.
	local function drijf(dt: number)
		for _, w in wolken do
			w.x -= w.snelheid * dt * 60
			if w.x < -w.maat * 3 then
				w.x = luchtW + w.maat * 2
				w.y = 30 + math.random() * (luchtH * 0.55)
			end
			w.vak.Position = UDim2.fromOffset(w.x, w.y)
		end
	end

	-- resizeCanvas() + initClouds(): bij een andere maat opnieuw zaaien.
	local function meetLucht()
		local maat = lucht.AbsoluteSize
		if maat.X <= 0 or maat.Y <= 0 then return end
		if math.abs(maat.X - luchtW) < 1 and math.abs(maat.Y - luchtH) < 1 then return end
		luchtW, luchtH = maat.X, maat.Y
		zaaiWolken()
		-- @media (max-width: 720px) { .multiplier-display { font-size: 64px } }
		local groot = if luchtW < 720 then 64 else 96
		multTekst.TextSize = groot
		multSchaduw.TextSize = groot
	end
	lucht:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetLucht)
	task.defer(meetLucht)

	hoofd:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetSpelers)
	task.defer(meetSpelers)

	-- ---------- de overlay ----------
	local function toonMult(m: number, gecrasht: boolean)
		aftelVak.Visible = false
		multVak.Visible = true
		statusPil.Visible = true
		local tekst = Money.fmt(m) .. "\u{00D7}"
		multTekst.Text = tekst
		multSchaduw.Text = tekst
		multRand.Color = if gecrasht then KLEUR.crashRand else KLEUR.tekstRand
		local pilTekst = if gecrasht then "\u{25BA} CRASHED" else "\u{25BA} IN THE AIR"
		statusTekst.Text = pilTekst
		statusTekst.TextColor3 = if gecrasht then KLEUR.crashTekst else Theme.color.white
		-- ondergrens voor de pil: padding van 12 links en rechts plus ruwweg een halve em
		-- per teken. AutomaticSize maakt hem breder als de letters meer ruimte vragen.
		statusPil.Size = UDim2.fromOffset(24 + math.ceil(#pilTekst * 7.2), 25)
	end

	local function toonAftellen(seconden: number)
		multVak.Visible = false
		statusPil.Visible = false
		aftelVak.Visible = true
		local tekst = string.format("%d", math.max(0, math.ceil(seconden)))
		aftelTekst.Text = tekst
		aftelSchaduw.Text = tekst
	end

	-- ---------- een nieuwe stand van de server ----------
	local function nieuweStand(s: any)
		if typeof(s) ~= "table" then return end
		local id = tonumber(s.id) or -1
		if id ~= vorigeRonde then
			vorigeRonde = id
			gezien = {}
			wisSpoor()
			knalVak.Visible = false
		end

		-- Elke cashout die we nog niet gezien hebben gaat in de feed; per ronde telt een
		-- naam één keer, want de server duwt de hele tafel bij elke verandering opnieuw.
		if typeof(s.bets) == "table" then
			for _, b in s.bets do
				if b.cashed and not gezien[b.naam] then
					gezien[b.naam] = true
					table.insert(winsten, 1, {
						naam = b.naam, bet = b.bet, mult = b.cashed, zelf = b.id == mijnId,
					})
					if #winsten > WINSTEN then table.remove(winsten) end
				end
			end
		end

		-- De RECENT-balk: het crashpunt van elke ronde die voorbij is, nieuwste eerst.
		if s.phase == "crashed" and s.crashAt and not gezien["#crash"] then
			gezien["#crash"] = true
			knalMoment = os.clock()
			table.insert(historie, 1, s.crashAt)
			if #historie > HISTORIE then table.remove(historie) end
			toonHistorie()
		end

		stand = s
		toonSpelers()
		toonWinsten()
		toonFairness()
		zetKnop()
	end

	-- ---------- elke frame ----------
	-- De servertijd is op beide kanten hetzelfde, dus dit loopt gelijk met wat de server
	-- rekent. Staat het scherm niet aan, dan hoeft er ook niets getekend te worden.
	RunService.RenderStepped:Connect(function(dt: number)
		local zichtbaar = scherm == nil or scherm.Visible
		if not zichtbaar or luchtW <= 0 then return end
		drijf(dt)
		-- @keyframes livePulse: van vol naar een kwart en terug, in 1,6 seconden
		if levendStip then
			levendStip.BackgroundTransparency = 0.375 + 0.375 * math.cos(os.clock() * math.pi * 2 / 1.6)
		end

		if not stand then return end
		local nu = workspace:GetServerTimeNow()
		local fase = stand.phase

		if fase == "waiting" then
			toonAftellen((stand.startsAt or nu) - nu)
			wisSpoor()
			knalVak.Visible = false
			-- drawPlane(W * 0.08, H - GRASS_HEIGHT - 10, -0.15): klaar voor vertrek
			zetVliegtuig(luchtW * 0.08, luchtH - GRAS - 10, -0.15)
			stand.mult = 1
		elseif fase == "flying" then
			local t = nu - (stand.startsAt or nu)
			local m = multBij(t)
			stand.mult = m
			toonMult(m, false)
			rekenBaan(t, m, luchtW, luchtH)
			tekenSpoor(false)
			knalVak.Visible = false
			local hoek = math.atan2(baanY[STAPPEN + 1] - baanY[STAPPEN], baanX[STAPPEN + 1] - baanX[STAPPEN])
			zetVliegtuig(baanX[STAPPEN + 1], baanY[STAPPEN + 1], hoek)

			-- Automatisch uitstappen gebeurt op de server, op het doel dat met de inzet is
			-- meegegaan. Het scherm hoeft er niets voor te doen; het ziet de uitslag
			-- langskomen in de stand, net als bij iedere andere speler.
			--
			-- de knop telt mee met de multiplier: CASH OUT $12.34
			local mijn = mijnInzet()
			if mijn and not mijn.cashed then
				knop.Text = "CASH OUT $" .. Money.fmt(Money.floor2(mijn.bet * m))
			end
		elseif fase == "crashed" then
			local c = stand.crashAt or 1
			stand.mult = c
			toonMult(c, true)
			rekenBaan((stand.endsAt or nu) - (stand.startsAt or nu), c, luchtW, luchtH)
			tekenSpoor(true)
			-- Na de knal valt het toestel omlaag en draait het op zijn kop, net als in render().
			local sinds = os.clock() - knalMoment
			local x, y = baanX[STAPPEN + 1], baanY[STAPPEN + 1]
			zetKnal(x, y, math.min(1, sinds / 0.6))
			zetVliegtuig(x, y + math.min(80, sinds * 125), math.pi / 2 + math.min(0.5, sinds))
		else
			-- "idle": er loopt geen ronde. Dan staat er ook niets in de lucht.
			multVak.Visible = false
			statusPil.Visible = false
			aftelVak.Visible = false
			knalVak.Visible = false
			vliegtuig.Visible = false
			wisSpoor()
		end
	end)

	knop.Activated:Connect(function()
		if not stand or not knop.Active then return end
		if stand.phase == "waiting" then
			-- Het doel gaat mee met de inzet: de server stapt er zelf op uit, op zijn eigen
			-- klok. Zou het scherm dat doen, dan kost een haperende verbinding je de hele
			-- inzet terwijl het spel een vast getal belooft.
			if Common.call("Bet", "crash", betBox.get(), if autoAan then autoDoel() else nil) then
				Common.toast("BET PLACED", "green")
			end
		elseif stand.phase == "flying" then
			local res = Common.call("CashOut", "crash")
			if res then
				Common.toast("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			end
		end
		zetKnop()
	end)

	-- De server duwt elke faseverandering; bij binnenkomst één keer zelf vragen.
	Net.ev("Round").OnClientEvent:Connect(function(s: any)
		if typeof(s) == "table" and s.game == "crash" then
			nieuweStand(s)
		end
	end)

	task.spawn(function()
		local ok, res = pcall(function()
			return Net.fn("RoundState"):InvokeServer("crash")
		end)
		if ok then nieuweStand(res) end
	end)

	toonSpelers()
	toonWinsten()
	toonFairness()
	zetSchakelaar()
	zetKnop()
end

return Crash
