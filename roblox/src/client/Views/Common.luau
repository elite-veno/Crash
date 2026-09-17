--!strict
-- Wat elk speelscherm nodig heeft: een blad om op te bouwen, een inzetvak met de ficheknoppen
-- eronder, en een lijntje naar de server. Eén plek, zodat de tien schermen er hetzelfde
-- uitzien en zich hetzelfde gedragen -- precies zoals bindBet() en takeBet() dat in de
-- webversie doen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

function Common.setBalance(n: number): ()
	saldo = n
	local tekst = Money.fmt(n)
	for _, l in saldoLabels do
		if l.Parent then l.Text = tekst end
	end
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
function Common.columns(ouder: Instance, titel: string?): (Frame, ScrollingFrame)
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
	UI.gradient(bordVak, Theme.color.panel, Theme.color.panelLight)
	UI.corner(bordVak, Theme.radius.panel)
	UI.stroke(bordVak)
	bordVak.Parent = vak

	-- Waar het spel zelf in komt: gecentreerd, zoals het bord in de webversie.
	local bord = Instance.new("Frame")
	bord.Name = "Board"
	bord.Size = UDim2.new(1, -Theme.size.panelPad * 2, 1, -Theme.size.panelPad * 2)
	bord.Position = UDim2.fromOffset(Theme.size.panelPad, Theme.size.panelPad)
	bord.BackgroundTransparency = 1
	bord.Parent = bordVak
	local bordLijst = UI.list(bord, Theme.size.asideGap)
	bordLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bordLijst.VerticalAlignment = Enum.VerticalAlignment.Center

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

		local terug = UI.backButton(kop)
		terug.LayoutOrder = 1
		terug.Activated:Connect(function()
			Common.navigate("home")
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
			local w = tonumber(st.profit) or 0
			v.winst.Text = (if w >= 0 then "+$" else "-$") .. Money.fmt(math.abs(w))
			v.winst.TextColor3 = if w >= 0 then Theme.color.neon else Theme.color.red
		end
	end
end

-- .odds-note: het uitlegblokje onder ODDS of PAYOUTS. De vetgedrukte stukken zijn in de
-- CSS goud; die staan hier tussen sterretjes en worden goud gekleurd.
function Common.oddsPanel(ouder: Instance, kop: string, tekst: string): Frame
	local vak = UI.panel(ouder, "Odds")
	UI.list(vak, 6)
	UI.panelTitle(vak, "\u{25BA} " .. kop)
	local t = UI.label(vak, tekst, { size = Theme.text.tiny, color = Theme.color.muted })
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
	rij.Size = UDim2.new(1, 0, 0, 20)
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
