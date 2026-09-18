--!strict
-- Rad van fortuin: twintig even grote vakken, één betaalt tien keer. Het rad draait en de
-- wijzer bovenaan blijft staan, net als bij roulette.
--
-- Het beeld komt uit `#wheelView` in de markup en uit whDraw() in de webversie. Rechts één
-- rad dat het hele bord vult -- `.wheel-wrap` is `width: 100%; flex: 1; min-height: 320px`
-- -- met daaronder de rij laatste uitslagen (`.sl-history-row`), en verder niets: geen groot
-- getal en geen uitslagbalk, want die staan in de webversie ook niet op het bord. De uitslag
-- komt als melding voorbij, precies zoals flash() dat daar doet. Links het inzetvak met de
-- knop SPIN THE WHEEL er in hetzelfde paneel bij, en daaronder STATISTICS en ODDS.
--
-- Wat Roblox niet heeft: taartpunten, een gevulde driehoek, box-shadow en letter-spacing.
-- Elk vak is daarom een waaier van smalle balkjes vanuit het midden (zie straal()), de wijzer
-- is het teken ▼ in goud, en de spatiëring van `.odds-note` is weggelaten. De ronde buitenrand
-- van een vak kan niet gestreept worden; alleen de twee rechte zijkanten krijgen hun lijntje.
--
-- Het rad wordt op de gemeten straal gebouwd en bij elke maatverandering opnieuw op maat
-- gezet (pasStraal). Een UIScale over een vast rad zou korter zijn, maar dan hangt het beeld
-- aan een schaalfactor die niet overal meegerekend wordt; de balkjesbreedte moet sowieso per
-- straal opnieuw uit de boogformule komen, dus de maten staan hier gewoon in pixels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Wheel = {}

-- ---------- maten uit whDraw() en de CSS ----------
local VAKKEN = #Odds.WHEEL         -- twintig
local STAP = 360 / VAKKEN          -- achttien graden per vak
local MIN_WRAP = 320               -- .wheel-wrap min-height (onder 900 pixels wordt dat 260)
local HIST_H = 24 - 2              -- .sl-hist is 24 in de CSS; de rand ligt buiten het vak
-- Tussen het rad en de uitslagenrij zit `.board { gap: 18px }` plus de eigen
-- `.wheel-wrap { margin-bottom: 14px }`. Dat is bij elkaar 32, ook als de rij nog leeg is.
local TUSSEN = 32
local LABEL_IN = 20                -- c.fillText(label, R - 20, 0)
local RAND = 5                     -- de velg loopt tot R + 5
local NAAF_F = 0.18                -- c.arc(cx, cy, R * 0.18) -- het donkere hart
local START_R = 200                -- straal voor het eerste beeld, tot meet() de echte weet

-- Elk vak wordt opgebouwd uit zes balkjes naast elkaar. Dat is genoeg: bij drie graden per
-- balkje is de bocht die eraf valt een kwart pixel diep, en dat zie je niet.
local SPAKEN = 6
local SUB = STAP / SPAKEN

-- Een balkje dat om het middelpunt draait dekt aan de buitenkant 2*asin(b / 2r) graden. Net
-- zo breed maken als die stap, plus een pixel, anders schijnt er licht tussen de balkjes door.
local function spaakBreedte(r: number): number
	return math.ceil(2 * r * math.sin(math.rad(SUB / 2))) + 1
end

-- whColor(): canvas kent geen CSS-variabelen, dus daar staan echte kleuren. Hier ook.
type Kleur = { vul: Color3, tekst: Color3, rand: Color3 }
local GOUD_VAK: Kleur = { vul = Color3.fromHex("3a2f12"), tekst = Theme.color.gold, rand = Theme.color.gold }
local GROEN_VAK: Kleur = { vul = Color3.fromHex("14301f"), tekst = Theme.color.neon, rand = Theme.color.neon }
local BLAUW_VAK: Kleur = { vul = Color3.fromHex("152634"), tekst = Theme.color.sky, rand = Theme.color.sky }
local LEEG_VAK: Kleur = { vul = Color3.fromHex("1a1f27"), tekst = Theme.color.muted, rand = Theme.color.border }

local function kleurVan(m: number): Kleur
	if m >= 10 then return GOUD_VAK end
	if m >= 2 then return GROEN_VAK end
	if m > 0 then return BLAUW_VAK end
	return LEEG_VAK
end

-- Een rond vlak. De straal staat in pixels en niet als halve schaal: Roblox knipt een te
-- grote CornerRadius bij tot de halve zijde, dus de helft van de diameter is precies rond.
-- De hoek wordt bewaard omdat hij met de schijf mee moet groeien.
type Schijf = { vlak: Frame, hoek: UICorner }
local function schijf(ouder: Instance, diameter: number, kleur: Color3, naam: string): Schijf
	local f = Instance.new("Frame")
	f.Name = naam
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.BackgroundColor3 = kleur
	f.BorderSizePixel = 0
	f.Parent = ouder
	return { vlak = f, hoek = UI.corner(f, diameter / 2) }
end

local function zetSchijf(s: Schijf, diameter: number): ()
	s.vlak.Size = UDim2.fromOffset(diameter, diameter)
	s.hoek.CornerRadius = UDim.new(0, diameter / 2)
end

-- Een balkje dat vanuit het midden van het rad naar buiten wijst, over de hele straal.
--
-- Een Frame draait om zijn eigen middelpunt. Het balkje wordt daarom niet met zijn voet op
-- de as gezet, maar met zijn hart op halve straal langs de richting waar het heen wijst: dan
-- valt het draaipunt samen met het hart en staat het balkje na de draaiing precies goed.
-- Onbedraaid wijst een Frame omhoog en omhoog is -90 graden, vandaar de +90; de richting die
-- daar bij hoort is (cos hoek, sin hoek), dezelfde als waarmee de opschriften geplaatst zijn.
type Spaak = { vlak: Frame, hoek: number, waaier: boolean }
local function straal(ouder: Instance, hoek: number, kleur: Color3, laag: number, waaier: boolean): Spaak
	local f = Instance.new("Frame")
	f.Name = if waaier then "Ray" else "Edge"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Rotation = hoek + 90
	f.BackgroundColor3 = kleur
	f.BorderSizePixel = 0
	f.ZIndex = laag
	f.Parent = ouder
	return { vlak = f, hoek = hoek, waaier = waaier }
end

-- De maat en de plek van zo'n balkje bij een gegeven straal.
local function zetStraal(s: Spaak, r: number, breed: number): ()
	s.vlak.Size = UDim2.fromOffset(if s.waaier then breed else 1, r)
	s.vlak.Position = UDim2.new(
		0.5, math.cos(math.rad(s.hoek)) * r / 2,
		0.5, math.sin(math.rad(s.hoek)) * r / 2
	)
end

-- .sl-hist: het cijferlettertype, een randje, en neon zodra er iets uitbetaald is.
local function histVakje(ouder: Instance, m: number, orde: number): ()
	local won = m > 0
	local t = UI.label(ouder, if won then Money.fmt(m) .. "\u{00D7}" else "\u{2014}", {
		size = Theme.text.tiny,
		color = if won then Theme.color.neon else Theme.color.muted,
		font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
		name = "Hist",
	})
	t.Size = UDim2.new(0, 0, 0, HIST_H)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.LayoutOrder = orde
	t.BackgroundColor3 = Theme.color.black
	t.BackgroundTransparency = 0.75                 -- rgba(0,0,0,0.25)
	UI.corner(t, 6)                                 -- .sl-hist border-radius
	-- .sl-hist.win: rgba(62,207,142,0.45) -- in Roblox de kleur plus de doorzichtigheid.
	local rand = UI.stroke(t, if won then Theme.color.neon else Theme.color.border)
	if won then rand.Transparency = 0.55 end
	UI.padding4(t, 0, 8, 0, 8)
end

function Wheel.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "WHEEL OF FORTUNE")
	local bordLijst = bord:FindFirstChildOfClass("UIListLayout")
	if bordLijst then bordLijst.Padding = UDim.new(0, TUSSEN) end

	-- ---------- het rad ----------
	-- `.wheel-wrap` is zo breed als het bord en pakt de hoogte die overblijft; het rad zelf
	-- staat in het midden daarvan, want whDraw() rekent met cx = w/2 en cy = h/2.
	local wrap = Instance.new("Frame")
	wrap.Name = "WheelWrap"
	wrap.Size = UDim2.new(1, 0, 0, MIN_WRAP)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = 1
	wrap.Parent = bord

	-- Alleen deze ring draait; de velg, de naaf en de wijzer horen bij het vaste deel.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 2

	-- De buitenrand: c.arc(cx, cy, R + 5) in --panel-light met een rand van 2.
	local velg = schijf(wrap, (START_R + RAND) * 2, Theme.color.panelLight, "Rim")
	UI.stroke(velg.vlak, Theme.color.border, 2)
	ring.Parent = wrap

	-- De onderdelen die met de straal meegroeien, zodat pasStraal ze terug kan vinden.
	local balkjes: { Spaak } = {}
	local opschriften: { { tekst: TextLabel, mid: number } } = {}

	for i, m in Odds.WHEEL do
		local kleur = kleurVan(m)
		local begin = -90 + (i - 1) * STAP            -- a0 = -PI/2 + i * step
		-- De waaier: zes balkjes die samen de punt vullen. Bij het midden liggen ze over
		-- elkaar heen -- ze hebben dezelfde kleur, dus dat valt niet op.
		for j = 1, SPAKEN do
			table.insert(balkjes, straal(ring, begin + (j - 0.5) * SUB, kleur.vul, 1, true))
		end
		-- De twee rechte zijkanten, c.stroke() met lineWidth 1. Een vak dat uitbetaalt krijgt
		-- zijn lijntje bovenop dat van de donkere buren, zoals canvas dat ook doet: wie later
		-- getekend wordt, wint.
		local laag = if m > 0 then 3 else 2
		table.insert(balkjes, straal(ring, begin, kleur.rand, laag, false))
		table.insert(balkjes, straal(ring, begin + STAP, kleur.rand, laag, false))

		-- Het opschrift staat langs de punt, op R - 20, en klapt op de linkerhelft om --
		-- anders zou het daar op zijn kop staan. Het ankerpunt is ook het draaipunt, dus het
		-- ligt in allebei de gevallen op dezelfde plek en de tekst loopt naar binnen weg.
		-- De letters blijven 13 pixels, net als in whDraw(); alleen de afstand groeit mee.
		local mid = begin + STAP / 2
		local links = math.cos(math.rad(mid)) < 0
		local t = UI.label(ring, if m > 0 then Money.fmt(m) .. "\u{00D7}" else "\u{00B7}", {
			size = Theme.text.label, color = kleur.tekst, font = Theme.font.num,
			align = if links then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			name = "Seg",
		})
		t.AnchorPoint = Vector2.new(if links then 0 else 1, 0.5)
		t.Size = UDim2.fromOffset(70, 20)
		t.Rotation = if links then mid + 180 else mid
		t.ZIndex = 4
		table.insert(opschriften, { tekst = t, mid = mid })
	end

	-- De naaf: een donkere schijf over het midden, waar alle punten samenkomen.
	local naaf = schijf(wrap, START_R * NAAF_F * 2, Theme.color.panel, "Hub")
	naaf.vlak.ZIndex = 3
	UI.stroke(naaf.vlak, Theme.color.border)

	-- De wijzer staat boven en wijst naar beneden het rad in. Een gevulde driehoek kan Roblox
	-- niet tekenen, dus het is het teken ervoor, met zijn hart op de rand van het rad --
	-- daar ligt in whDraw() ook het midden van de driehoek (cy - R - 8 tot cy - R + 8).
	local wijzer = UI.label(wrap, "\u{25BC}", {
		size = 24, color = Theme.color.gold, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center, name = "Pointer",
	})
	wijzer.AnchorPoint = Vector2.new(0.5, 0.5)
	wijzer.Size = UDim2.fromOffset(28, 28)
	wijzer.ZIndex = 4

	-- Alles wat van de straal afhangt op maat zetten.
	local function pasStraal(r: number): ()
		local b = spaakBreedte(r)
		for _, s in balkjes do zetStraal(s, r, b) end
		for _, o in opschriften do
			o.tekst.Position = UDim2.new(
				0.5, math.cos(math.rad(o.mid)) * (r - LABEL_IN),
				0.5, math.sin(math.rad(o.mid)) * (r - LABEL_IN)
			)
		end
		zetSchijf(velg, (r + RAND) * 2)
		zetSchijf(naaf, r * NAAF_F * 2)
		wijzer.Position = UDim2.new(0.5, 0, 0.5, -r)
	end
	pasStraal(START_R)

	-- ---------- de uitslagenrij ----------
	local histRij = Instance.new("Frame")
	histRij.Name = "History"
	histRij.Size = UDim2.new(1, 0, 0, 0)
	histRij.BackgroundTransparency = 1
	histRij.LayoutOrder = 2
	histRij.Parent = bord
	local histLijst = UI.list(histRij, 6, Enum.FillDirection.Horizontal)
	histLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	histLijst.SortOrder = Enum.SortOrder.LayoutOrder

	local geschiedenis: { number } = {}

	-- Het rad vult het bord: `flex: 1` in de hoogte, `width: 100%` in de breedte. De
	-- uitslagenrij en de 32 pixels ertussen gaan er eerst af, en de straal is daarna
	-- min(w, h) / 2 - 10, precies zoals whDraw() hem uitrekent.
	local gemeten = -1
	local function meet()
		local vak = bord.AbsoluteSize
		if vak.X <= 0 or vak.Y <= 0 then return end
		-- Zolang er nog niet gedraaid is staat er niets in `.sl-history-row` en is die rij
		-- nul hoog; de tussenruimte eronder telt in de webversie dan wél gewoon mee.
		local hist = if #geschiedenis > 0 then HIST_H else 0
		local hoog = math.max(MIN_WRAP, vak.Y - hist - TUSSEN)
		local r = math.min(vak.X, hoog) / 2 - 10
		histRij.Size = UDim2.new(1, 0, 0, hist)
		wrap.Size = UDim2.new(1, 0, 0, hoog)
		if math.abs(r - gemeten) < 0.5 then return end
		gemeten = r
		pasStraal(r)
	end
	bord:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	local function toonGeschiedenis()
		for _, kind in histRij:GetChildren() do
			if kind:IsA("TextLabel") then kind:Destroy() end
		end
		for i, m in geschiedenis do
			histVakje(histRij, m, i)
		end
		meet()                                      -- de rij duwt het rad een stukje kleiner
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld met zijn ficheknoppen en de speelknop in één `.panel`.
	-- Common.betBox maakt dat paneel, dus de knop gaat erbij in.
	local betBox = Common.betBox(bediening, 10)

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local knop = UI.primary(betBox.panel, "SPIN THE WHEEL")
	knop.LayoutOrder = 11
	knop.Font = Theme.font.uiBold
	UI.gradient(knop, Theme.color.neon, Theme.color.neonDim, 135)

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "wheel")
	Common.oddsPanel(bediening, "odds", "Twenty equal segments: one 10.00x, two 2.00x, two 1.50x, two 1.20x and thirteen blanks. Together 19.4 / 20 = RTP *97%*.")

	-- ---------- draaien ----------
	local hoek = 0        -- WH.angle, hier in graden: Rotation rekent net als de canvas met
	                      -- de klok mee, dus de hoek uit whSpin() kan zo worden overgenomen.
	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		local inzet = betBox.get()
		bezig = true
		knop.Text = "SPINNING\u{2026}"
		UI.setEnabled(knop, false)
		betBox.lock(true)

		local res = Common.call("Bet", "wheel", inzet)
		if not res then
			bezig = false
			knop.Text = "SPIN THE WHEEL"
			UI.setEnabled(knop, true)
			betBox.lock(false)
			return
		end

		-- Vijf tot zeven slagen en dan het midden van het gelote vak onder de wijzer, in
		-- vier seconden die achteraan uitlopen: dezelfde beweging als in whSpin().
		local start = hoek
		local doel = -(res.slot - 1 + 0.5) * STAP
		local slagen = 5 + math.random(0, 2)
		local eind = start + 360 * slagen + ((doel - start) % 360 + 360) % 360
		local duur = 4
		local t0 = os.clock()
		while true do
			local t = math.min(1, (os.clock() - t0) / duur)
			ring.Rotation = start + (eind - start) * (1 - (1 - t) ^ 3)
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		hoek = eind % 360
		ring.Rotation = hoek

		table.insert(geschiedenis, 1, res.mult)
		if #geschiedenis > 8 then table.remove(geschiedenis) end
		toonGeschiedenis()

		if res.payout > inzet then
			Common.toast(
				Money.fmt(res.mult) .. "\u{00D7} \u{00B7} +$" .. Money.fmt(res.payout),
				if res.mult >= 10 then "gold" else "green"
			)
		else
			Common.toast("MISSED", "red")
		end

		bezig = false
		knop.Text = "SPIN THE WHEEL"
		UI.setEnabled(knop, true)
		betBox.lock(false)
	end)
end

return Wheel
