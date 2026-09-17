--!strict
-- De bouwstenen uit de CSS, als Roblox-objecten. Elke maat hier komt uit `crash.html`; waar
-- de webversie padding van 18 zegt, staat er 18. Eén plek waar een paneel, een knop en een
-- fiche vandaan komen, zodat elk scherm er hetzelfde uitziet.
--
-- Wat Roblox niet heeft en de CSS wel: letter-spacing, box-shadow en transitions. De eerste
-- twee zijn weggelaten, de derde wordt door TweenService gedaan waar hij opvalt.
local Theme = require(script.Parent.Theme)

local UI = {}

-- ---------- kleine hulpjes ----------
function UI.corner(parent: GuiObject, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.radius.button)
	c.Parent = parent
	return c
end

function UI.stroke(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.color.border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UI.padding(parent: GuiObject, all: number?): UIPadding
	local p = Instance.new("UIPadding")
	local n = all or Theme.size.pad
	p.PaddingTop = UDim.new(0, n)
	p.PaddingBottom = UDim.new(0, n)
	p.PaddingLeft = UDim.new(0, n)
	p.PaddingRight = UDim.new(0, n)
	p.Parent = parent
	return p
end

function UI.padding4(parent: GuiObject, boven: number, rechts: number, onder: number, links: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, boven)
	p.PaddingRight = UDim.new(0, rechts)
	p.PaddingBottom = UDim.new(0, onder)
	p.PaddingLeft = UDim.new(0, links)
	p.Parent = parent
	return p
end

function UI.list(parent: GuiObject, gap: number?, dir: Enum.FillDirection?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or Theme.size.gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

-- Het verloop van 180 graden dat door de hele CSS loopt: panel naar panel-light.
function UI.gradient(parent: GuiObject, van: Color3, tot: Color3, rotatie: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(van, tot)
	g.Rotation = rotatie or 90
	g.Parent = parent
	return g
end

-- ---------- paneel ----------
-- .panel: verloop van --panel naar --panel-light, 1px rand, radius 4, padding 18, en
-- bovenlangs een haarlijn in de neongloed (.panel::before).
function UI.panel(parent: Instance, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Panel"
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	UI.gradient(f, Theme.color.panel, Theme.color.panelLight)
	UI.corner(f, Theme.radius.panel)
	UI.stroke(f)
	UI.padding(f, Theme.size.panelPad)
	f.Parent = parent

	-- De haarlijn bovenaan: doorzichtig aan de randen, neon in het midden.
	local lijn = Instance.new("Frame")
	lijn.Name = "TopLine"
	lijn.AnchorPoint = Vector2.new(0.5, 0)
	lijn.Position = UDim2.new(0.5, 0, 0, -Theme.size.panelPad)
	lijn.Size = UDim2.new(1, Theme.size.panelPad * 2, 0, 1)
	lijn.BackgroundColor3 = Theme.glow.color
	lijn.BorderSizePixel = 0
	lijn.ZIndex = 2
	lijn.Parent = f
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = lijn

	return f
end

-- ---------- tekst ----------
export type LabelOpts = {
	size: number?,
	color: Color3?,
	font: Enum.Font?,
	align: Enum.TextXAlignment?,
	name: string?,
}

local LEEG: LabelOpts = {}

function UI.label(parent: Instance, text: string, opts: LabelOpts?): TextLabel
	local o: LabelOpts = opts or LEEG
	local t = Instance.new("TextLabel")
	t.Name = o.name or "Label"
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = o.size or Theme.text.body
	t.TextColor3 = o.color or Theme.color.text
	t.Font = o.font or Theme.font.ui
	t.TextXAlignment = o.align or Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, (o.size or Theme.text.body) + 6)
	t.RichText = false        -- spelersnamen komen hier langs; nooit als opmaak uitvoeren
	t.Parent = parent
	return t
end

-- .panel-title: neon, 11px, en 8 pixels lucht eronder.
function UI.panelTitle(parent: Instance, text: string): TextLabel
	local t = UI.label(parent, string.upper(text), {
		size = Theme.text.small,
		color = Theme.color.neon,
		font = Theme.font.uiMed,
		name = "PanelTitle",
	})
	t.Size = UDim2.new(1, 0, 0, Theme.text.small + 8)
	return t
end

-- .section-heading: een kop van 22, een telling, en een lijn die naar rechts uitdooft.
function UI.sectionHeading(parent: Instance, kop: string, telling: string?): (TextLabel, TextLabel)
	local rij = Instance.new("Frame")
	rij.Name = "SectionHeading"
	rij.Size = UDim2.new(1, 0, 0, 30)
	rij.BackgroundTransparency = 1
	rij.Parent = parent

	local h = UI.label(rij, kop, {
		size = Theme.text.title, color = Theme.color.text, font = Theme.font.uiMed,
	})
	h.Size = UDim2.new(0, 0, 1, 0)
	h.AutomaticSize = Enum.AutomaticSize.X

	local c = UI.label(rij, telling or "", { size = Theme.text.small, color = Theme.color.muted })
	c.Position = UDim2.new(0, 0, 0, 0)
	c.Size = UDim2.new(0, 0, 1, 0)
	c.AutomaticSize = Enum.AutomaticSize.X

	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 20)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = rij
	h.LayoutOrder = 1
	c.LayoutOrder = 2

	local streep = Instance.new("Frame")
	streep.Name = "Divider"
	streep.LayoutOrder = 3
	streep.Size = UDim2.new(1, -260, 0, 1)
	streep.BackgroundColor3 = Theme.color.border
	streep.BorderSizePixel = 0
	streep.Parent = rij
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = streep

	return h, c
end

-- ---------- knoppen ----------
export type Button = TextButton

-- Een knop die op zijn plek blijft als je erover gaat, maar wel reageert.
local function hover(b: TextButton, aan: () -> (), uit: () -> ())
	b.MouseEnter:Connect(function()
		if b.Active then aan() end
	end)
	b.MouseLeave:Connect(uit)
end

-- .btn-primary: volle breedte, padding 16, 15px, radius 3.
function UI.primary(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Primary"
	b.Text = text
	b.Font = Theme.font.uiMed
	b.TextSize = Theme.text.button
	b.TextColor3 = Theme.color.bg
	b.BackgroundColor3 = Theme.color.neon
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 48)
	UI.corner(b, Theme.radius.button)
	hover(b, function()
		b.BackgroundColor3 = Theme.color.neonDim
	end, function()
		b.BackgroundColor3 = Theme.color.neon
	end)
	b.Parent = parent
	return b
end

-- .btn-primary.btn-danger: het verloop naar donkerrood, voor uitstappen.
function UI.danger(parent: Instance, text: string): Button
	local b = UI.primary(parent, text)
	b.Name = "Danger"
	b.BackgroundColor3 = Theme.color.red
	b.TextColor3 = Theme.color.white
	b.Font = Theme.font.uiBold
	UI.gradient(b, Theme.color.red, Color3.fromHex("8a0e1e"), 135)
	return b
end

-- .btn-secondary: zwart met een rand, 11px, padding 12 boven en onder.
function UI.secondary(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Secondary"
	b.Text = text
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = Theme.color.text
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 36)
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b)
	hover(b, function()
		rand.Color = Theme.color.neon
		b.TextColor3 = Theme.color.neon
	end, function()
		rand.Color = Theme.color.border
		b.TextColor3 = Theme.color.text
	end)
	b.Parent = parent
	return b
end

-- .chip: hetzelfde, maar kleiner en met radius 2.
function UI.chip(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Chip"
	b.Text = text
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = Theme.color.text
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(0, 0, 0, 24)
	UI.corner(b, Theme.radius.chip)
	local rand = UI.stroke(b)
	hover(b, function()
		rand.Color = Theme.color.neon
		b.TextColor3 = Theme.color.neon
	end, function()
		rand.Color = Theme.color.border
		b.TextColor3 = Theme.color.text
	end)
	b.Parent = parent
	return b
end

-- .back-btn: "← LOBBY", neon tekst, en bij hover keert hij om.
function UI.backButton(parent: Instance, text: string?): Button
	local b = Instance.new("TextButton")
	b.Name = "Back"
	b.Text = text or "\u{2190} LOBBY"
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.tiny
	b.TextColor3 = Theme.color.neon
	b.BackgroundColor3 = Theme.color.black
	b.BackgroundTransparency = Theme.alpha.buttonBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(86, 30)
	UI.corner(b, Theme.radius.button)
	local rand = UI.stroke(b)
	hover(b, function()
		b.BackgroundColor3 = Theme.color.neon
		b.BackgroundTransparency = 0
		b.TextColor3 = Theme.color.bg
		rand.Color = Theme.color.neon
	end, function()
		b.BackgroundColor3 = Theme.color.black
		b.BackgroundTransparency = Theme.alpha.buttonBg
		b.TextColor3 = Theme.color.neon
		rand.Color = Theme.color.border
	end)
	b.Parent = parent
	return b
end

-- Een pilletje: .game-card-tag en .nav-badge.
function UI.tag(parent: Instance, text: string, kleur: Color3?): TextLabel
	local k = kleur or Theme.color.neon
	local f = Instance.new("TextLabel")
	f.Name = "Tag"
	f.Text = text
	f.Font = Theme.font.ui
	f.TextSize = Theme.text.tiny
	f.TextColor3 = k
	f.BackgroundColor3 = k
	f.BackgroundTransparency = Theme.alpha.tagNeon
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 20)
	f.RichText = false
	UI.corner(f, Theme.radius.pill)
	local s = UI.stroke(f, k)
	s.Transparency = 0.6
	UI.padding4(f, 0, 8, 0, 8)
	f.Parent = parent
	return f
end

-- ---------- invoerveld ----------
-- input[type=number]: zwart, rand, cijferlettertype 16, radius 3. Bij focus wordt de rand
-- neon en komt er een gloedring omheen -- dat is de box-shadow uit de CSS.
function UI.numberBox(parent: Instance, start: string): TextBox
	local t = Instance.new("TextBox")
	t.Name = "NumberBox"
	t.Text = start
	t.PlaceholderText = "0"
	t.Font = Theme.font.num
	t.TextSize = Theme.text.input
	t.TextColor3 = Theme.color.text
	t.BackgroundColor3 = Theme.color.black
	t.BackgroundTransparency = Theme.alpha.inputBg
	t.BorderSizePixel = 0
	t.ClearTextOnFocus = false
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, 40)
	UI.corner(t, Theme.radius.input)
	local s = UI.stroke(t)
	UI.padding4(t, 10, 12, 10, 12)

	local ring = Instance.new("UIStroke")
	ring.Color = Theme.glow.color
	ring.Thickness = 2
	ring.Transparency = 1
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = t

	t.Focused:Connect(function()
		s.Color = Theme.color.neon
		ring.Transparency = Theme.glow.transparency
	end)
	t.FocusLost:Connect(function()
		s.Color = Theme.color.border
		ring.Transparency = 1
	end)
	t.Parent = parent
	return t
end

-- ---------- melding ----------
-- .toast: verschijnt rechtsboven het speelveld en verdwijnt vanzelf.
export type ToastKind = "green" | "red" | "gold"

function UI.toast(host: Instance, text: string, kind: ToastKind?): ()
	local k = kind or "green"
	local color = if k == "red" then Theme.color.red
		elseif k == "gold" then Theme.color.gold
		else Theme.color.neon

	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.Size = UDim2.new(0, 0, 0, 34)
	f.AutomaticSize = Enum.AutomaticSize.X
	UI.corner(f, Theme.radius.button)
	UI.stroke(f, color)

	local t = UI.label(f, text, { size = Theme.text.tiny, color = color, font = Theme.font.uiMed })
	t.Size = UDim2.new(0, 0, 1, 0)
	t.AutomaticSize = Enum.AutomaticSize.X
	UI.padding4(f, 0, 12, 0, 12)
	f.Parent = host

	task.delay(2.6, function()
		if f.Parent then f:Destroy() end
	end)
end

-- ---------- bedragen ----------
-- Dezelfde weergave als fmt() in de webversie: altijd twee decimalen.
function UI.money(n: number): string
	return string.format("%.2f", n)
end

-- .balance-amount: het dollarteken staat er gedimd voor, apart van het getal. Geeft het
-- label met het getal terug, en het vak eromheen.
function UI.moneyLabel(parent: Instance, bedrag: string, groot: number?, midden: boolean?): (TextLabel, Frame)
	local maat = groot or Theme.text.balance
	local rij = Instance.new("Frame")
	rij.Name = "Money"
	rij.Size = UDim2.new(1, 0, 0, maat + 10)
	rij.BackgroundTransparency = 1
	rij.Parent = parent

	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = if midden then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 1)
	l.Parent = rij

	local teken = UI.label(rij, "$", { size = maat, color = Theme.color.neon, font = Theme.font.num })
	teken.LayoutOrder = 1
	teken.AutomaticSize = Enum.AutomaticSize.X
	teken.Size = UDim2.new(0, 0, 1, 0)
	teken.TextTransparency = 0.4

	local getal = UI.label(rij, bedrag, {
		size = maat, color = Theme.color.neon, font = Theme.font.num, name = "Amount",
	})
	getal.LayoutOrder = 2
	getal.AutomaticSize = Enum.AutomaticSize.X
	getal.Size = UDim2.new(0, 0, 1, 0)
	return getal, rij
end

-- Een knop uitzetten zoals :disabled in de CSS: nog zichtbaar, maar niet aan te klikken.
function UI.setEnabled(b: TextButton, aan: boolean): ()
	b.Active = aan
	b.AutoButtonColor = false
	b.TextTransparency = if aan then 0 else Theme.alpha.disabled
	if b.BackgroundTransparency < 0.9 then
		b.BackgroundTransparency = if aan then (if b.Name == "Primary" or b.Name == "Danger" then 0 else Theme.alpha.buttonBg) else 0.7
	end
end

return UI
