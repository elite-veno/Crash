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

function Common.setBalance(n: number): ()
	saldo = n
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

-- Twee kolommen: links het speelveld, rechts de bediening. Zoals `.game-layout` in de CSS.
-- Onder de 760 pixels gaan ze onder elkaar staan, net als de media query daar.
function Common.columns(ouder: Instance, rechtsBreed: number?): (Frame, Frame)
	local breedte = rechtsBreed or 300
	local rij = Instance.new("Frame")
	rij.Name = "Columns"
	rij.Size = UDim2.new(1, 0, 0, 0)
	rij.AutomaticSize = Enum.AutomaticSize.Y
	rij.BackgroundTransparency = 1
	rij.Parent = ouder

	local links = Instance.new("Frame")
	links.Name = "Board"
	links.Size = UDim2.new(1, -(breedte + 12), 0, 0)
	links.AutomaticSize = Enum.AutomaticSize.Y
	links.BackgroundTransparency = 1
	links.Parent = rij
	UI.list(links, Theme.size.gap)

	local rechts = Instance.new("Frame")
	rechts.Name = "Controls"
	rechts.AnchorPoint = Vector2.new(1, 0)
	rechts.Position = UDim2.fromScale(1, 0)
	rechts.Size = UDim2.new(0, breedte, 0, 0)
	rechts.AutomaticSize = Enum.AutomaticSize.Y
	rechts.BackgroundTransparency = 1
	rechts.Parent = rij
	UI.list(rechts, Theme.size.gap)

	-- Smal scherm: alles onder elkaar. Roblox heeft geen media queries, dus dit gaat met
	-- de hand, op dezelfde grens als de CSS.
	local function meet()
		local smal = rij.AbsoluteSize.X < 760
		if smal then
			links.Size = UDim2.new(1, 0, 0, 0)
			rechts.AnchorPoint = Vector2.new(0, 0)
			rechts.Position = UDim2.new(0, 0, 0, links.AbsoluteSize.Y + 12)
			rechts.Size = UDim2.new(1, 0, 0, 0)
			rij.Size = UDim2.new(1, 0, 0, links.AbsoluteSize.Y + rechts.AbsoluteSize.Y + 12)
			rij.AutomaticSize = Enum.AutomaticSize.None
		else
			links.Size = UDim2.new(1, -(breedte + 12), 0, 0)
			rechts.AnchorPoint = Vector2.new(1, 0)
			rechts.Position = UDim2.fromScale(1, 0)
			rechts.Size = UDim2.new(0, breedte, 0, 0)
			rij.AutomaticSize = Enum.AutomaticSize.Y
		end
	end
	rij:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	links:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	rechts:GetPropertyChangedSignal("AbsoluteSize"):Connect(meet)
	task.defer(meet)

	return links, rechts
end

-- Een rij knoppen naast elkaar, gelijk verdeeld.
function Common.row(ouder: Instance, hoogte: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.Size = UDim2.new(1, 0, 0, hoogte or 30)
	f.BackgroundTransparency = 1
	f.Parent = ouder
	local l = UI.list(f, 6, Enum.FillDirection.Horizontal)
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
	UI.panelTitle(paneel, "bet amount")

	local vak = UI.numberBox(paneel, Money.fmt(start or 10))
	local ficherij = Common.row(paneel, 26)

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
		local b = UI.chip(ficherij, fiche.naam)
		b.Size = UDim2.new(0.25, -5, 0, 26)
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
	UI.label(rij, naam, { size = Theme.text.small, color = Theme.color.muted })
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
	UI.corner(f, Theme.size.radius)
	local rand = UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	local t = UI.label(f, "", {
		size = Theme.text.label, color = Theme.color.muted, font = Theme.font.uiBold,
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
