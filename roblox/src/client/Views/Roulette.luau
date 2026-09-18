--!strict
-- Roulette: een echt rad met zevenendertig vakken, daaronder het inzetvlak, en links de
-- fichewaarde. Europees, dus één groene nul. De fiches blijven op het bord liggen tot je
-- SPIN geeft; pas dan gaan alle inzetten in één keer naar de server, die het getal trekt
-- en afrekent. Het rad laat alleen zien wat er al besloten is.
--
-- Elke maat hieronder komt uit de webversie: .rl-wheel-wrap, .rl-result, .rl-board,
-- .rl-cell, .rl-chip, .rl-hist en de tekenroutine rlDraw() in crash.html.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Roulette = {}

-- ---------- de kleuren uit de CSS ----------
-- Het bord heeft zijn eigen rood en zwart; die staan los van --red en --text uit het thema,
-- want een roulettekleed is donkerder dan de rest van de site.
local ROOD = Color3.fromHex("b3122e")         -- .rl-cell.red
local ZWART = Color3.fromHex("141414")        -- .rl-cell.black
local GROEN = Color3.fromHex("0b7a3b")        -- .rl-cell.green
local BUITEN_ROOD = Color3.fromHex("6a0a1a")  -- .rl-cell.outside.red
local BUITEN_ZWART = Color3.fromHex("222222") -- .rl-cell.outside.black
local POCKET_ZWART = Color3.fromHex("151515") -- rlDraw(): de zwarte vakken in het rad
local GOUD_RAD = Color3.fromHex("cc9900")     -- de rand, de spaken en de naafpin
local RAND_BUITEN = Color3.fromHex("3a2410")  -- de houten buitenring
local RAND_BINNEN = Color3.fromHex("1a0a0a")  -- de donkere schijf daarbinnen
local NAAF = Color3.fromHex("2a1408")
local FICHE_RAND = Color3.fromHex("fff3b0")   -- .rl-chip border
local STREEP = Color3.fromHex("1a3a1a")       -- .payout-line border-bottom
local RES_ROOD_RAND = Color3.fromHex("ff6b81")-- .rl-result.red border
local RES_ZWART = Color3.fromHex("111111")
local RES_ZWART_RAND = Color3.fromHex("666666")
local HIST_ZWART = Color3.fromHex("222222")   -- .rl-hist.black
local HIST_ZWART_RAND = Color3.fromHex("555555")

local function kleurVan(n: number): Color3
	local k = Odds.rouletteColor(n)
	return if k == "green" then GROEN elseif k == "red" then ROOD else ZWART
end

-- ---------- maten ----------
local WIEL = 300                   -- .rl-wheel-wrap: width min(300px, 90vw), aspect-ratio 1
local STRAAL = WIEL / 2 - 6        -- rlDraw(): R = min(w,h)/2 - 6
local VAKKEN = 37
local STAP = 360 / VAKKEN

-- .rl-board: grid-template-columns 40px repeat(12, 1fr) 40px, gap 3, max-width 760.
local BORD_B = 760
local GAT = 3
local ZIJKOLOM = 40
local KOLOM = (BORD_B - ZIJKOLOM * 2 - GAT * 13) / 12   -- 53.42, de breedte van één nummer
local RIJ_H = { 44, 44, 44, 36, 36 }                    -- grid-template-rows
local BORD_H = 44 * 3 + 36 * 2 + GAT * 4                -- 216
-- De fiches steken zeven pixels buiten hun vak; de groep eromheen krijgt die lucht erbij,
-- anders knipt hij ze eraf.
local LUCHT = 10

-- De x van een rasterkolom (1 = de nul, 2..13 de nummers, 14 de 2:1-kolom).
local function kolomX(j: number): number
	if j <= 1 then return 0 end
	return ZIJKOLOM + GAT + (j - 2) * (KOLOM + GAT)
end

-- De breedte van een vak dat over `aantal` nummerkolommen loopt.
local function kolomBreedte(aantal: number): number
	return aantal * KOLOM + (aantal - 1) * GAT
end

local function rijY(r: number): number
	local y = 0
	for i = 1, r - 1 do
		y += RIJ_H[i] + GAT
	end
	return y
end

-- ---------- kleine bouwsteentjes ----------
local function schijf(ouder: Instance, diameter: number, kleur: Color3, naam: string): Frame
	local f = Instance.new("Frame")
	f.Name = naam
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.BackgroundColor3 = kleur
	f.BorderSizePixel = 0
	UI.corner(f, diameter / 2)
	f.Parent = ouder
	return f
end

-- .payout-line: naam links, waarde rechts in het cijferlettertype, en een haarlijntje eronder.
local function payoutRegel(ouder: Instance, naam: string, waarde: string, kleur: Color3): TextLabel
	local rij = Instance.new("Frame")
	rij.Name = naam
	rij.Size = UDim2.new(1, 0, 0, 28)   -- padding 6 boven en onder om een regel van 11
	rij.BackgroundTransparency = 1
	rij.Parent = ouder

	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.text, name = "Key" })
	local v = UI.label(rij, waarde, {
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

function Roulette.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "ROULETTE")
	-- .board zet 18 pixels tussen het rad en het inzetvlak; de gedeelde kolomhulp gebruikt 14.
	local bordLijst = bord:FindFirstChildOfClass("UIListLayout")
	if bordLijst then bordLijst.Padding = UDim.new(0, 18) end

	-- ---------- .rl-top: het rad naast de uitslag ----------
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(1, 0, 0, 0)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.BackgroundTransparency = 1
	top.LayoutOrder = 1
	top.Parent = bord
	local topLijst = UI.list(top, 24, Enum.FillDirection.Horizontal)
	topLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	-- Het rad van 300 plus de uitslagkolom met 24 ertussen moet naast elkaar passen. Past dat
	-- niet, dan gaat de uitslag eronder staan -- dat is wat .rl-top onder de 900 pixels doet.
	-- De kolom is zo breed als de bol tot de geschiedenisstrook hem verder opduwt; die
	-- breedte staat hier al klaar omdat meetTop eerder gemaakt wordt dan de kolom zelf.
	local kolomBreed = 110
	local gestapeld: boolean? = nil
	local function meetTop()
		local breed = top.AbsoluteSize.X
		if breed <= 0 then return end
		local smal = breed < WIEL + 24 + kolomBreed
		if smal == gestapeld then return end
		gestapeld = smal
		topLijst.FillDirection = if smal then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	end
	top:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetTop)
	task.defer(meetTop)

	-- ---------- het rad ----------
	local radVak = Instance.new("Frame")
	radVak.Name = "Wheel"
	radVak.Size = UDim2.fromOffset(WIEL, WIEL)
	radVak.BackgroundTransparency = 1
	radVak.LayoutOrder = 1
	radVak.Parent = top

	schijf(radVak, (STRAAL + 4) * 2, RAND_BUITEN, "Rim")
	schijf(radVak, STRAAL * 2, RAND_BINNEN, "Well")

	-- Alleen deze ring draait; de naald en de bal hangen erbuiten en blijven dus staan.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 2
	ring.Parent = radVak

	-- Roblox kent geen taartpunten. Elk vak is daarom een rechthoekje dat op het midden van
	-- de ring staat en met de hoek meedraait: even breed als de punt daar is, even lang als
	-- de ring dik is (van 0.55R tot 0.98R, net als in rlDraw). De taps toelopende zijkant
	-- gaat verloren; met 37 vakken van nog geen tien graden valt dat niet op.
	local vakBreed = 2 * math.pi * (STRAAL * 0.765) / VAKKEN
	local vakLang = STRAAL * (0.98 - 0.55)
	for i, n in Odds.ROULETTE_ORDER do
		local hoek = -90 + (i - 0.5) * STAP           -- het midden van vak i
		local rad = math.rad(hoek)
		local v = Instance.new("Frame")
		v.Name = "P" .. n
		v.AnchorPoint = Vector2.new(0.5, 0.5)
		v.Position = UDim2.new(0.5, math.cos(rad) * STRAAL * 0.765, 0.5, math.sin(rad) * STRAAL * 0.765)
		v.Size = UDim2.fromOffset(vakBreed, vakLang)
		v.Rotation = hoek + 90                        -- de lange kant wijst naar het midden
		v.BackgroundColor3 = if n == 0 then GROEN elseif Odds.rouletteColor(n) == "red" then ROOD else POCKET_ZWART
		v.BorderSizePixel = 0
		v.Parent = ring
		-- De gouden scheidingslijntjes: in de CSS 0.8 pixel, hier 1 -- dunner kan Roblox niet.
		UI.stroke(v, GOUD_RAD, 1)

		local cijfer = UI.label(v, tostring(n), {
			size = Theme.text.tiny, color = Theme.color.white, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center, name = "N",
		})
		cijfer.AnchorPoint = Vector2.new(0.5, 0.5)
		-- rlDraw zet het cijfer op 0.86R; het vakmidden ligt op 0.765R, dus een stukje
		-- naar buiten, en dat is in dit gedraaide vakje omhoog.
		cijfer.Position = UDim2.new(0.5, 0, 0.5, -(0.86 - 0.765) * STRAAL)
		cijfer.Size = UDim2.fromOffset(vakBreed + 8, Theme.text.tiny + 4)
	end

	-- De naaf met de vier spaken draait mee.
	local naaf = schijf(ring, STRAAL * 0.55 * 2, NAAF, "Hub")
	naaf.ZIndex = 2
	UI.stroke(naaf, GOUD_RAD, 2)
	-- Vier armen vanuit het midden. Twee balken door het hart, niet vier staafjes met een
	-- ankerpunt aan hun kop: Roblox draait een vak om zijn eigen midden, dus zo'n staafje
	-- zwaait om zijn halverwege-punt en komt naast de naaf terecht in plaats van eruit.
	for i = 0, 1 do
		local spaak = Instance.new("Frame")
		spaak.Name = "Spoke" .. i
		spaak.AnchorPoint = Vector2.new(0.5, 0.5)
		spaak.Position = UDim2.fromScale(0.5, 0.5)
		spaak.Size = UDim2.fromOffset(STRAAL * 1.1, 3)
		spaak.Rotation = i * 90
		spaak.BackgroundColor3 = GOUD_RAD
		spaak.BorderSizePixel = 0
		spaak.ZIndex = 3
		spaak.Parent = ring
	end
	schijf(ring, STRAAL * 0.16 * 2, GOUD_RAD, "Pin").ZIndex = 4

	-- De bal loopt de andere kant op en zakt tegen het eind naar binnen.
	local bal = schijf(radVak, math.max(4, STRAAL * 0.04) * 2, Theme.color.white, "Ball")
	bal.ZIndex = 3
	local function zetBal(hoek: number, straalDeel: number)
		local rad = math.rad(hoek)
		local r = STRAAL * straalDeel
		bal.Position = UDim2.new(0.5, math.cos(rad) * r, 0.5, math.sin(rad) * r)
	end
	zetBal(-90, 0.93)

	-- De naald bovenaan. Een driehoek kan Roblox niet vullen, dus het is het teken ervoor.
	local naald = UI.label(radVak, "\u{25BC}", {
		size = 20, color = Theme.color.gold, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center, name = "Pointer",
	})
	naald.AnchorPoint = Vector2.new(0.5, 0.5)
	naald.Position = UDim2.new(0.5, 0, 0, WIEL / 2 - STRAAL + 4)
	naald.Size = UDim2.fromOffset(24, 24)
	naald.ZIndex = 4

	-- ---------- .rl-result en de strook met de laatste getallen ----------
	local kolom = Instance.new("Frame")
	kolom.Name = "Result"
	-- De uitslagkolom heeft in de webversie geen vaste breedte: hij is zo breed als zijn
	-- inhoud, dus 110 (de bol) zolang de strook leeg is. Een vaste 200 duwde het rad scheef,
	-- want .rl-top centreert het rad en deze kolom samen. AutomaticSize.X kan hier niet:
	-- een kind van een lijst meet dan als nul en het rad schuift over de bol heen. De
	-- breedte wordt daarom bij elke uitslag uitgerekend, in toonGeschiedenis.
	kolom.Size = UDim2.fromOffset(110, 0)
	kolom.AutomaticSize = Enum.AutomaticSize.Y
	kolom.BackgroundTransparency = 1
	kolom.LayoutOrder = 2
	kolom.Parent = top
	local kolomLijst = UI.list(kolom, 14)
	kolomLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local bol = Instance.new("TextLabel")
	bol.Name = "Marker"
	bol.Size = UDim2.fromOffset(110, 110)
	bol.BackgroundTransparency = 1
	bol.Text = "?"
	bol.Font = Theme.font.num
	bol.TextSize = 54
	bol.TextColor3 = Theme.color.muted
	-- .rl-result centreert zijn cijfer in beide richtingen.
	bol.TextXAlignment = Enum.TextXAlignment.Center
	bol.TextYAlignment = Enum.TextYAlignment.Center
	bol.RichText = false
	UI.corner(bol, 55)
	local bolRand = UI.stroke(bol, Theme.color.border, 3)
	bol.Parent = kolom

	-- .result-strip is een flexrij van 6 tussenruimte. Hij mag afbreken, maar omdat de
	-- kolom op zijn inhoud meegroeit komt het daar nooit van; een rij volstaat dus.
	local strook = Instance.new("Frame")
	strook.Name = "History"
	strook.Size = UDim2.new(1, 0, 0, 0)
	strook.AutomaticSize = Enum.AutomaticSize.Y
	strook.BackgroundTransparency = 1
	strook.Parent = kolom
	local strookLijst = UI.list(strook, 6, Enum.FillDirection.Horizontal)
	strookLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	strookLijst.VerticalAlignment = Enum.VerticalAlignment.Center
	local strookMin = Instance.new("UISizeConstraint")
	strookMin.MinSize = Vector2.new(0, 26)   -- .result-strip min-height
	strookMin.Parent = strook

	local geschiedenis: { number } = {}
	local function toonGeschiedenis()
		for _, k in strook:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		for i, n in geschiedenis do
			local k = Odds.rouletteColor(n)
			local d = UI.label(strook, tostring(n), {
				size = Theme.text.tiny, color = Theme.color.white, font = Theme.font.num,
				align = Enum.TextXAlignment.Center, name = "H" .. i,
			})
			d.LayoutOrder = i
			d.BackgroundTransparency = 0
			d.BackgroundColor3 = if k == "green" then GROEN elseif k == "red" then ROOD else HIST_ZWART
			d.Size = UDim2.fromOffset(28, 28)
			UI.corner(d, 14)
			if k == "black" then UI.stroke(d, HIST_ZWART_RAND, 1) end
		end
		-- De kolom is zo breed als zijn breedste kind: de bol van 110, of de strook zodra
		-- daar meer dan drie getallen in staan. Zo blijft rad plus kolom samen gecentreerd,
		-- net als in .rl-top.
		local n = #geschiedenis
		kolomBreed = math.max(110, if n > 0 then n * 28 + (n - 1) * 6 else 0)
		kolom.Size = UDim2.fromOffset(kolomBreed, 0)
		meetTop()
	end

	-- ---------- .rl-board: het inzetvlak ----------
	-- Het bord is 760 breed; past dat niet, dan krimpt alles gelijkmatig mee. De webversie
	-- geeft het onder 900 pixels een schuifbalk, maar schuiven in een Roblox-paneel is
	-- lastiger dan een bord dat gewoon kleiner wordt.
	-- De houder is precies zo hoog als het bord zelf, zonder de lucht voor de fiches: in de
	-- webversie hangen die buiten het raster en tellen ze niet mee voor de hoogte. Telde de
	-- lucht wel mee, dan werd het gecentreerde geheel twintig pixels hoger en schoof het rad
	-- zichtbaar omhoog.
	local houder = Instance.new("Frame")
	houder.Name = "BoardHolder"
	houder.Size = UDim2.new(1, 0, 0, BORD_H)
	houder.BackgroundTransparency = 1
	houder.LayoutOrder = 2
	houder.Parent = bord

	-- Een CanvasGroup, want .rl-locked zet het hele bord tijdens het draaien op opacity 0.7;
	-- dat is per vak niet na te doen zonder elke kleur apart te verbleken.
	local groep = Instance.new("CanvasGroup")
	groep.Name = "Board"
	groep.AnchorPoint = Vector2.new(0.5, 0)
	groep.Position = UDim2.new(0.5, 0, 0, -LUCHT)
	groep.Size = UDim2.fromOffset(BORD_B + LUCHT * 2, BORD_H + LUCHT * 2)
	groep.BackgroundTransparency = 1
	groep.BorderSizePixel = 0
	groep.Parent = houder
	local schaal = Instance.new("UIScale")
	schaal.Parent = groep

	local gemeten = -1
	local function meetBord()
		local breed = houder.AbsoluteSize.X
		if breed <= 0 then return end
		-- Krimpen gebeurt op de bordbreedte zelf; de lucht eromheen is overloop voor de
		-- fiches en mag er, net als in de webversie, buiten hangen.
		local s = math.min(1, breed / BORD_B)
		if math.abs(s - gemeten) < 0.001 then return end
		gemeten = s
		schaal.Scale = s
		-- De groep begint een lucht hoger dan de houder, zodat het eerste vak precies op
		-- de bovenrand van de houder valt. Die verschuiving krimpt mee met de schaal.
		groep.Position = UDim2.new(0.5, 0, 0, -LUCHT * s)
		houder.Size = UDim2.new(1, 0, 0, BORD_H * s)
	end
	houder:GetPropertyChangedSignal("AbsoluteSize"):Connect(meetBord)
	task.defer(meetBord)

	-- ---------- de inzetten ----------
	-- `win` onthoudt of dit vak de vorige ronde gewonnen heeft; dan blijft de gouden ring
	-- staan ook als de muis er weer af gaat.
	type Vakje = { knop: TextButton, fiche: TextLabel, gloed: UIStroke, win: boolean }

	local inzetten: { [string]: number } = {}
	local laatste: { [string]: number } = {}
	local vakjes: { [string]: Vakje } = {}
	local fiche = 10          -- RL.chip: de ficheknop die aan staat
	local bezig = false
	local ververs: () -> ()

	local function telOp(): number
		local t = 0
		for _, b in inzetten do t += b end
		return Money.round2(t)
	end

	local function plaats(key: string)
		if bezig then return end
		if fiche > Common.balance() - telOp() + 1e-9 then
			Common.toast("NOT ENOUGH BALANCE", "red")
			return
		end
		inzetten[key] = Money.round2((inzetten[key] or 0) + fiche)
		ververs()
	end

	-- Eén vak van het kleed: .rl-cell, met het fiche dat rechtsonder buiten de rand hangt.
	local function vak(key: string, tekst: string, kleur: Color3, j: number, kolommen: number, r: number, rijen: number, buiten: boolean)
		local hoogte = 0
		for i = r, r + rijen - 1 do
			hoogte += RIJ_H[i]
		end
		hoogte += GAT * (rijen - 1)

		local b = Instance.new("TextButton")
		b.Name = key
		b.Text = tekst
		b.Font = Theme.font.uiBold                       -- .rl-cell font-weight 700
		b.TextSize = if buiten then Theme.text.tiny else 13
		b.TextColor3 = if buiten then Theme.color.text else Theme.color.white
		-- .rl-cell is een flexvak met justify-content en align-items op center.
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextYAlignment = Enum.TextYAlignment.Center
		b.BackgroundColor3 = kleur
		b.BackgroundTransparency = if buiten and kleur == Theme.color.black then 0.45 else 0
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Position = UDim2.fromOffset(LUCHT + kolomX(j), LUCHT + rijY(r))
		b.Size = UDim2.fromOffset(if j == 1 or j == 14 then ZIJKOLOM else kolomBreedte(kolommen), hoogte)
		b.RichText = false
		UI.corner(b, Theme.radius.button)
		local rand = UI.stroke(b, Theme.color.white, 1)
		rand.Transparency = 0.85                          -- border rgba(255,255,255,0.15)
		b.Parent = groep

		-- :hover is een gouden lijn eromheen, .win een gouden ring met gloed. Roblox kent
		-- geen box-shadow, dus beide worden dezelfde tweede rand -- de winnaar dikker.
		local gloed = Instance.new("UIStroke")
		gloed.Color = Theme.color.gold
		gloed.Thickness = 2
		gloed.Transparency = 1
		gloed.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		gloed.Parent = b

		local f = UI.label(b, "", {
			size = Theme.text.tiny, color = Theme.color.black, font = Theme.font.uiBold,
			align = Enum.TextXAlignment.Center, name = "Chip",
		})
		f.AnchorPoint = Vector2.new(1, 1)
		f.Position = UDim2.new(1, 7, 1, 7)               -- bottom -7, right -7
		f.Size = UDim2.fromOffset(24, 24)
		f.AutomaticSize = Enum.AutomaticSize.X
		f.BackgroundTransparency = 0
		f.BackgroundColor3 = Theme.color.gold
		f.Visible = false
		f.ZIndex = 4
		UI.corner(f, 12)
		UI.stroke(f, FICHE_RAND, 2)
		UI.padding4(f, 0, 5, 0, 5)
		local fMin = Instance.new("UISizeConstraint")
		fMin.MinSize = Vector2.new(24, 24)
		fMin.Parent = f

		b.MouseEnter:Connect(function()
			if not bezig then gloed.Transparency = 0 end
		end)
		b.MouseLeave:Connect(function()
			local v = vakjes[key]
			if not (v and v.win) then gloed.Transparency = 1 end
		end)
		b.Activated:Connect(function()
			plaats(key)
		end)

		vakjes[key] = { knop = b, fiche = f, gloed = gloed, win = false }
	end

	-- De nul staat links over de drie nummerrijen heen; daarna twaalf kolommen van drie,
	-- van onder naar boven geteld (n = kolom * 3 - rij), met de 2:1-kolom erachter.
	vak("n:0", "0", GROEN, 1, 1, 1, 3, false)
	for r = 0, 2 do
		for c = 1, 12 do
			local n = c * 3 - r
			vak("n:" .. n, tostring(n), kleurVan(n), c + 1, 1, r + 1, 1, false)
		end
		vak("c" .. (3 - r), "2:1", Theme.color.black, 14, 1, r + 1, 1, true)
	end
	for i, d in { { "1-12", "d1" }, { "13-24", "d2" }, { "25-36", "d3" } } do
		vak(d[2], d[1], Theme.color.black, 2 + (i - 1) * 4, 4, 4, 1, true)
	end
	for i, o in {
		{ "1-18", "low" }, { "EVEN", "even" }, { "RED", "red" },
		{ "BLACK", "black" }, { "ODD", "odd" }, { "19-36", "high" },
	} do
		local k = o[2]
		local kleur = if k == "red" then BUITEN_ROOD elseif k == "black" then BUITEN_ZWART else Theme.color.black
		vak(k, o[1], kleur, 2 + (i - 1) * 2, 2, 5, 1, true)
	end

	-- ---------- de bediening links ----------
	local vakBediening = UI.panel(bediening, "Controls")
	UI.list(vakBediening, 6)

	-- .field-group: "CHIP VALUE" links, het dollarteken in neon als hint rechts.
	local veld = Instance.new("Frame")
	veld.Name = "ChipField"
	veld.Size = UDim2.new(1, 0, 0, 0)
	veld.AutomaticSize = Enum.AutomaticSize.Y
	veld.BackgroundTransparency = 1
	veld.Parent = vakBediening
	UI.list(veld, 6)
	UI.padding4(veld, 0, 0, 8, 0)   -- .field-group margin-bottom 14, met de 6 uit de lijst erbij

	local kop = Instance.new("Frame")
	kop.Size = UDim2.new(1, 0, 0, Theme.text.small + 6)
	kop.BackgroundTransparency = 1
	kop.Parent = veld
	UI.label(kop, "CHIP VALUE", { size = Theme.text.small, color = Theme.color.muted })
	local hint = UI.label(kop, "$", {
		size = Theme.text.small, color = Theme.color.neon, align = Enum.TextXAlignment.Right,
	})
	hint.TextTransparency = 0.3     -- .field-label .hint opacity 0.7

	-- .seg: vijf gelijke knoppen met 4 pixels ertussen; de aangeklikte is neon.
	local seg = Instance.new("Frame")
	seg.Name = "ChipSeg"
	-- `.seg button { padding: 8px 0 }` om een regel van 11 (regelvak 14), plus twee randen.
	seg.Size = UDim2.new(1, 0, 0, 32)
	seg.BackgroundTransparency = 1
	seg.Parent = veld
	UI.list(seg, 4, Enum.FillDirection.Horizontal)

	local segKnoppen: { [number]: TextButton } = {}
	local function zetFiche(waarde: number)
		fiche = waarde
		for v, b in segKnoppen do
			local aan = v == waarde
			b.BackgroundColor3 = if aan then Theme.color.neon else Theme.color.black
			b.BackgroundTransparency = if aan then 0 else Theme.alpha.buttonBg
			b.TextColor3 = if aan then Theme.color.bg else Theme.color.text
			b.Font = if aan then Theme.font.uiBold else Theme.font.ui
			-- .seg button.on krijgt ook een neon rand, net als bij hover.
			local rand = b:FindFirstChildOfClass("UIStroke")
			if rand then rand.Color = if aan then Theme.color.neon else Theme.color.border end
		end
	end
	for i, waarde in { 1, 5, 10, 25, 100 } do
		local b = Instance.new("TextButton")
		b.Name = "Chip" .. waarde
		b.Text = tostring(waarde)
		b.Font = Theme.font.ui
		b.TextSize = Theme.text.tiny
		b.TextColor3 = Theme.color.text
		-- Een knop centreert zijn opschrift; .seg button laat dat zo.
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.new(0.2, -3.2, 1, 0)
		UI.corner(b, Theme.radius.chip)
		local rand = UI.stroke(b, Theme.color.border)
		b.MouseEnter:Connect(function()
			if fiche ~= waarde then rand.Color = Theme.color.neon end
		end)
		b.MouseLeave:Connect(function()
			rand.Color = if fiche == waarde then Theme.color.neon else Theme.color.border
		end)
		b.Activated:Connect(function()
			if bezig then return end
			zetFiche(waarde)
		end)
		b.Parent = seg
		segKnoppen[waarde] = b
	end

	local totaalLabel = payoutRegel(vakBediening, "TOTAL STAKE", "$0.00", Theme.color.gold)
	local laatsteLabel = payoutRegel(vakBediening, "LAST RESULT", "\u{2014}", Theme.color.neon)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, over de volle breedte.
	local draaien = UI.primary(vakBediening, "SPIN")
	draaien.Font = Theme.font.uiBold
	UI.gradient(draaien, Theme.color.neon, Theme.color.neonDim, 135)

	local knoprij = Common.row(vakBediening, 36, 6)   -- .btn-row { gap: 6px }
	UI.padding4(knoprij, 2, 0, 0, 0)   -- .btn-row margin-top 8, waarvan 6 uit de lijst komt
	local wissen = UI.secondary(knoprij, "CLEAR")
	wissen.Size = UDim2.new(0.5, -3, 0, 36)
	local herhalen = UI.secondary(knoprij, "REPEAT")
	herhalen.Size = UDim2.new(0.5, -3, 0, 36)

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "roulette")
	Common.oddsPanel(bediening, "payouts", "Straight number *35:1* \u{00B7} Dozen / column *2:1* \u{00B7} Red / black / even / odd / 1-18 / 19-36 *1:1*. One zero, so RTP *97.3%* on every bet.")

	zetFiche(fiche)

	-- ---------- bijwerken ----------
	local function heeftLaatste(): boolean
		for _ in laatste do return true end
		return false
	end

	function ververs()
		for key, v in vakjes do
			local bedrag = inzetten[key]
			v.fiche.Visible = bedrag ~= nil and bedrag > 0
			-- rlRenderBets toont een rond bedrag zonder centen; alleen een half fiche
			-- krijgt de twee decimalen erbij.
			v.fiche.Text = if bedrag then (if bedrag % 1 == 0 then string.format("%d", bedrag) else Money.fmt(bedrag)) else ""
			-- Het vak met een fiche erop moet boven zijn buren liggen, anders verdwijnt
			-- het fiche onder het volgende vak.
			v.knop.ZIndex = if v.fiche.Visible then 2 else 1
		end
		totaalLabel.Text = "$" .. Money.fmt(telOp())
		UI.setEnabled(draaien, not bezig)
		UI.setEnabled(wissen, not bezig and telOp() > 0)
		UI.setEnabled(herhalen, not bezig and heeftLaatste())
		groep.GroupTransparency = if bezig then 0.3 else 0   -- .rl-locked opacity 0.7
		for _, v in vakjes do
			v.knop.Active = not bezig
		end
	end

	local function leegmaken()
		for key in inzetten do
			inzetten[key] = nil
		end
		ververs()
	end

	wissen.Activated:Connect(function()
		if bezig then return end
		leegmaken()
	end)

	herhalen.Activated:Connect(function()
		if bezig then return end
		local totaal = 0
		for _, b in laatste do totaal += b end
		if totaal <= 0 then return end
		if totaal > Common.balance() - telOp() + 1e-9 then
			Common.toast("NOT ENOUGH BALANCE", "red")
			return
		end
		for k, b in laatste do
			inzetten[k] = Money.round2((inzetten[k] or 0) + b)
		end
		ververs()
	end)

	-- ---------- draaien ----------
	-- De uitslag staat vast zodra de server geantwoord heeft; het rad laat hem alleen zien.
	-- Dezelfde beweging als in de webversie: vijf tot zeven slagen van het rad, acht tot tien
	-- van de bal de andere kant op, in 4,2 seconde met een cubic-out.
	local function toonUitslag(n: number?)
		if n == nil then
			bol.Text = "\u{2026}"
			bol.BackgroundTransparency = 1
			bol.TextColor3 = Theme.color.muted
			bolRand.Color = Theme.color.border
			return
		end
		local k = Odds.rouletteColor(n)
		bol.Text = tostring(n)
		bol.BackgroundTransparency = 0
		bol.TextColor3 = Theme.color.white
		if k == "red" then
			bol.BackgroundColor3 = ROOD
			bolRand.Color = RES_ROOD_RAND
		elseif k == "black" then
			bol.BackgroundColor3 = RES_ZWART
			bolRand.Color = RES_ZWART_RAND
		else
			bol.BackgroundColor3 = GROEN
			bolRand.Color = Theme.color.neon
		end
	end

	draaien.Activated:Connect(function()
		if bezig then return end
		local inzet = telOp()
		if inzet < Money.MIN_BET then
			Common.toast("PLACE A BET FIRST", "red")
			return
		end

		laatste = {}
		local kopie: { [string]: number } = {}
		for k, v in inzetten do
			laatste[k] = v
			kopie[k] = v
		end
		bezig = true
		for _, v in vakjes do
			v.win = false                -- de winnaars van de vorige ronde doven
			v.gloed.Transparency = 1
		end
		ververs()
		toonUitslag(nil)

		local res = Common.call("Bet", "roulette", kopie)
		if not res then
			bezig = false
			toonUitslag(geschiedenis[1])
			ververs()
			return
		end

		local plek = (table.find(Odds.ROULETTE_ORDER, res.number) or 1) - 1
		local start = ring.Rotation % 360
		local doel = -(plek + 0.5) * STAP               -- dat vak recht onder de naald
		local slagen = 5 + math.random(0, 2)
		local eind = start + 360 * slagen + ((doel - start) % 360 + 360) % 360
		local balSlagen = 8 + math.random(0, 2)
		local duur = 4.2

		ring.Rotation = start
		local t0 = os.clock()
		while true do
			local t = math.min(1, (os.clock() - t0) / duur)
			local e = 1 - (1 - t) ^ 3
			ring.Rotation = start + (eind - start) * e
			zetBal(-90 - 360 * balSlagen * e, 0.93 - 0.16 * math.max(0, (t - 0.55) / 0.45))
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		ring.Rotation = eind % 360

		toonUitslag(res.number)
		table.insert(geschiedenis, 1, res.number)
		if #geschiedenis > 12 then table.remove(geschiedenis) end
		toonGeschiedenis()

		-- De winnende vakken krijgen hun gouden ring, net als .rl-cell.win.
		for key in inzetten do
			local v = vakjes[key]
			if v and Odds.roulettePayout(key, res.number) > 0 then
				v.win = true
				v.gloed.Transparency = 0
			end
		end

		local netto = Money.round2(res.payout - inzet)
		laatsteLabel.Text = (if netto >= 0 then "+$" else "-$") .. Money.fmt(math.abs(netto))
		laatsteLabel.TextColor3 = if netto >= 0 then Theme.color.neon else Theme.color.red

		local naam = string.upper(res.color)
		if res.payout > 0 then
			Common.toast(res.number .. " " .. naam .. " \u{00B7} +$" .. Money.fmt(res.payout), if netto >= 0 then "green" else "gold")
		else
			Common.toast(res.number .. " " .. naam .. " \u{00B7} -$" .. Money.fmt(inzet), "red")
		end

		bezig = false
		leegmaken()
	end)

	ververs()
end

return Roulette
