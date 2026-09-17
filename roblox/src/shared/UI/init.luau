--!strict
-- De bouwstenen uit de CSS, als Roblox-objecten. Eén plek waar een paneel, een knop en een
-- fiche vandaan komen, zodat elk scherm er hetzelfde uitziet.
local Theme = require(script.Parent.Theme)

local UI = {}

-- ---------- kleine hulpjes ----------
function UI.corner(parent: GuiObject, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.size.radius)
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

function UI.list(parent: GuiObject, gap: number?, dir: Enum.FillDirection?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or Theme.size.gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

-- ---------- paneel ----------
-- In de CSS: een verloop van --panel naar --panel-light, een rand en afgeronde hoeken.
function UI.panel(parent: Instance, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Panel"
	f.BackgroundColor3 = Theme.color.panel
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y

	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Theme.color.panel, Theme.color.panelLight)
	g.Rotation = 90
	g.Parent = f

	UI.corner(f, Theme.size.radiusPanel)
	UI.stroke(f)
	UI.padding(f, Theme.size.panelPad)
	f.Parent = parent
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

-- Een kopje zoals `.panel-title` in de CSS: klein, hoofdletters, met een pijltje ervoor.
function UI.panelTitle(parent: Instance, text: string): TextLabel
	return UI.label(parent, "\u{25BA} " .. string.upper(text), {
		size = Theme.text.small,
		color = Theme.color.neon,
		font = Theme.font.uiBold,
		name = "PanelTitle",
	})
end

-- ---------- knoppen ----------
export type Button = TextButton

local function pressable(b: TextButton, normal: Color3, hoverColor: Color3)
	b.MouseEnter:Connect(function()
		if b.Active then b.BackgroundColor3 = hoverColor end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = normal
	end)
end

-- De grote groene knop: `.btn-primary`.
function UI.primary(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Primary"
	b.Text = text
	b.Font = Theme.font.uiBold
	b.TextSize = Theme.text.label
	b.TextColor3 = Theme.color.bg
	b.BackgroundColor3 = Theme.color.neon
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 44)
	UI.corner(b, Theme.size.radius)
	pressable(b, Theme.color.neon, Theme.color.neonDim)
	b.Parent = parent
	return b
end

-- De donkere knop met rand: `.btn-secondary`.
function UI.secondary(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Secondary"
	b.Text = text
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.small
	b.TextColor3 = Theme.color.text
	b.BackgroundColor3 = Theme.color.bg
	b.BackgroundTransparency = 0.5
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 32)
	UI.corner(b, Theme.size.radius)
	UI.stroke(b)
	b.Parent = parent
	return b
end

-- Een fiche: `.chip`, de ½ / 2× / MIN / MAX knopjes onder een inzetveld.
function UI.chip(parent: Instance, text: string): Button
	local b = Instance.new("TextButton")
	b.Name = "Chip"
	b.Text = text
	b.Font = Theme.font.ui
	b.TextSize = Theme.text.small
	b.TextColor3 = Theme.color.text
	b.BackgroundColor3 = Theme.color.bg
	b.BackgroundTransparency = 0.5
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(0, 0, 0, 26)
	UI.corner(b, Theme.size.radiusSmall)
	UI.stroke(b)
	b.Parent = parent
	return b
end

-- ---------- invoerveld ----------
-- `input[type=number]`: donker, rand, cijferlettertype. Op een telefoon hoort er een
-- toetsenbord bij dat je weer weg kunt doen; in Roblox sluit de TextBox zelf bij Enter.
function UI.numberBox(parent: Instance, start: string): TextBox
	local t = Instance.new("TextBox")
	t.Name = "NumberBox"
	t.Text = start
	t.PlaceholderText = "0"
	t.Font = Theme.font.num
	t.TextSize = 16
	t.TextColor3 = Theme.color.text
	t.BackgroundColor3 = Theme.color.bg
	t.BackgroundTransparency = 0.4
	t.BorderSizePixel = 0
	t.ClearTextOnFocus = false
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, 38)
	UI.corner(t, Theme.size.radius)
	local s = UI.stroke(t)
	t.Focused:Connect(function()
		s.Color = Theme.color.neon
	end)
	t.FocusLost:Connect(function()
		s.Color = Theme.color.border
	end)
	UI.padding(t, 10)
	t.Parent = parent
	return t
end

-- ---------- melding ----------
-- `.toast`: verschijnt rechtsboven het speelveld en verdwijnt vanzelf.
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
	UI.corner(f, Theme.size.radius)
	UI.stroke(f, color)

	local t = UI.label(f, text, { size = Theme.text.small, color = color, font = Theme.font.uiBold })
	t.Size = UDim2.new(0, 0, 1, 0)
	t.AutomaticSize = Enum.AutomaticSize.X
	UI.padding(f, 10)
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

return UI
