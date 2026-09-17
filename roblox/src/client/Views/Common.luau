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

-- Een speelscherm zoals `.game-view` in de CSS: `grid-template-columns: 320px 1fr`, dus de
-- bediening LINKS in een aside van 320 breed en het speelveld rechts. Boven in de aside
-- staat de kop van het spel (`← LOBBY` plus de naam) en daaronder het saldopaneel -- precies
-- de volgorde uit de markup.
--
-- Onder de 760 pixels gaan ze onder elkaar staan, net als de media query. Het omschakelen
-- gebeurt door de richting van de UIListLayout te draaien en niet door de vakken zelf te
-- verplaatsen: wie posities uitrekent uit AbsoluteSize en die vervolgens zet, verandert
-- AbsoluteSize weer, en dan blijft het heen en weer meten.
function Common.columns(ouder: Instance, titel: string?): (Frame, Frame)
	local breedte = Theme.size.asideWidth
	local rij = Instance.new("Frame")
	rij.Name = "GameView"
	rij.Size = UDim2.new(1, 0, 0, 0)
	rij.AutomaticSize = Enum.AutomaticSize.Y
	rij.BackgroundTransparency = 1
	rij.Parent = ouder
	local indeling = UI.list(rij, Theme.size.viewGap, Enum.FillDirection.Horizontal)
	indeling.VerticalAlignment = Enum.VerticalAlignment.Top

	-- links: de aside
	local aside = Instance.new("Frame")
	aside.Name = "Aside"
	aside.LayoutOrder = 1
	aside.Size = UDim2.new(0, breedte, 0, 0)
	aside.AutomaticSize = Enum.AutomaticSize.Y
	aside.BackgroundTransparency = 1
	aside.Parent = rij
	UI.list(aside, Theme.size.asideGap)

	-- rechts: het speelveld
	local bord = Instance.new("Frame")
	bord.Name = "Board"
	bord.LayoutOrder = 2
	bord.Size = UDim2.new(1, -(breedte + Theme.size.viewGap), 0, 0)
	bord.AutomaticSize = Enum.AutomaticSize.Y
	bord.BackgroundTransparency = 1
	bord.Parent = rij
	UI.list(bord, Theme.size.asideGap)

	-- .crash-header: de terugknop en de naam van het spel, naast elkaar.
	if titel then
		local kop = Instance.new("Frame")
		kop.Name = "Header"
		kop.LayoutOrder = 1
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

	-- Het saldopaneel, zoals `.panel.balance` in de markup.
	local saldoVak = UI.panel(aside, "Balance")
	saldoVak.LayoutOrder = 2
	UI.list(saldoVak, 4)
	UI.label(saldoVak, "BALANCE", { size = Theme.text.small, color = Theme.color.muted })
	local bedrag = UI.moneyLabel(saldoVak, Money.fmt(saldo), Theme.text.balance)
	table.insert(saldoLabels, bedrag)

	local smalNu: boolean? = nil
	local function meet()
		local smal = rij.AbsoluteSize.X > 0 and rij.AbsoluteSize.X < 760
		if smal == smalNu then return end
		smalNu = smal
		if smal then
			indeling.FillDirection = Enum.FillDirection.Vertical
			aside.Size = UDim2.new(1, 0, 0, 0)
			bord.Size = UDim2.new(1, 0, 0, 0)
		else
			indeling.FillDirection = Enum.FillDirection.Horizontal
			aside.Size = UDim2.new(0, breedte, 0, 0)
			bord.Size = UDim2.new(1, -(breedte + Theme.size.viewGap), 0, 0)
		end
	end
	rij:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
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
