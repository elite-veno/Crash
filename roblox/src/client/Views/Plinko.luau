--!strict
-- Plinko: de pinnen, het balletje dat langs het pad van de server valt, en de bakjes
-- eronder. De cijfers in de bakjes staan onder elkaar in plaats van in het midden, net als
-- na de laatste fix in de webversie, zodat ze op een smal scherm niet over elkaar vallen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Plinko = {}

local RIJEN = {8, 12, 16}
local RISICO = {"low", "medium", "high"}

-- Warme kleuren aan de randen, koel in het midden: zo leest een speler de tabel in één
-- oogopslag, precies als de CSS-klassen in de webversie.
local function bakKleur(mult: number): Color3
	if mult >= 20 then return Color3.fromHex("e0616e") end
	if mult >= 5 then return Color3.fromHex("e08a55") end
	if mult >= 1.5 then return Theme.color.gold end
	if mult >= 1 then return Color3.fromHex("4a7f63") end
	return Color3.fromHex("2a323d")
end

function Plinko.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "PLINKO")

	local vak = UI.panel(bord, "Board")
	UI.list(vak, 8)
	UI.panelTitle(vak, "plinko")

	local veld = Instance.new("Frame")
	veld.Name = "Field"
	veld.Size = UDim2.new(1, 0, 0, 320)
	veld.BackgroundColor3 = Theme.color.bg
	veld.BackgroundTransparency = 0.4
	veld.BorderSizePixel = 0
	UI.corner(veld, Theme.radius.button)
	veld.Parent = vak

	local bakkenRij = Instance.new("Frame")
	bakkenRij.Name = "Buckets"
	bakkenRij.Size = UDim2.new(1, 0, 0, 44)
	bakkenRij.BackgroundTransparency = 1
	bakkenRij.Parent = vak

	local balk = Common.banner(vak)
	balk.set("DROP A BALL", nil)

	local rijen = 12
	local risico = "medium"
	local pinnen: { Frame } = {}
	local bakken: { Frame } = {}

	-- Het veld opnieuw tekenen als het aantal rijen of het risico verandert.
	local function teken()
		for _, p in pinnen do p:Destroy() end
		table.clear(pinnen)
		for _, b in bakken do b:Destroy() end
		table.clear(bakken)

		local hoogteStap = 1 / (rijen + 1)
		for r = 1, rijen do
			for k = 0, r do
				local p = Instance.new("Frame")
				p.AnchorPoint = Vector2.new(0.5, 0.5)
				-- Elke rij is een pin breder; het midden blijft het midden.
				p.Position = UDim2.fromScale(0.5 + (k - r / 2) / (rijen + 1), hoogteStap * (r + 0.2))
				p.Size = UDim2.fromOffset(5, 5)
				p.BackgroundColor3 = Theme.color.muted
				p.BorderSizePixel = 0
				UI.corner(p, 3)
				p.Parent = veld
				table.insert(pinnen, p)
			end
		end

		local tabel = Odds.plinkoTable(rijen, risico)
		for i, m in tabel do
			local b = Instance.new("Frame")
			b.Name = "Bucket" .. i
			b.Size = UDim2.new(1 / #tabel, -2, 1, 0)
			b.Position = UDim2.new((i - 1) / #tabel, 1, 0, 0)
			b.BackgroundColor3 = bakKleur(m)
			b.BorderSizePixel = 0
			UI.corner(b, Theme.radius.chip)
			b.Parent = bakkenRij

			-- De multiplier bovenin, het nummer van het bakje onderin. Nooit allebei in het
			-- midden: dan staan ze op een telefoon over elkaar.
			local boven = UI.label(b, Money.fmt(m) .. "\u{00D7}", {
				size = Theme.text.tiny, color = Theme.color.bg, font = Theme.font.num,
				align = Enum.TextXAlignment.Center,
			})
			boven.Position = UDim2.new(0, 0, 0, 2)
			boven.Size = UDim2.new(1, 0, 0, 14)

			local onder = UI.label(b, tostring(i - 1), {
				size = Theme.text.tiny, color = Theme.color.bg, font = Theme.font.num,
				align = Enum.TextXAlignment.Center,
			})
			onder.AnchorPoint = Vector2.new(0, 1)
			onder.Position = UDim2.new(0, 0, 1, -2)
			onder.Size = UDim2.new(1, 0, 0, 12)
			onder.TextTransparency = 0.45

			table.insert(bakken, b)
		end
	end

	-- Het balletje langs het pad laten vallen dat de server heeft getrokken.
	local function laatVallen(pad: { number }, bak: number)
		local bal = Instance.new("Frame")
		bal.AnchorPoint = Vector2.new(0.5, 0.5)
		bal.Position = UDim2.fromScale(0.5, 0)
		bal.Size = UDim2.fromOffset(11, 11)
		bal.BackgroundColor3 = Theme.color.neon
		bal.BorderSizePixel = 0
		bal.ZIndex = 4
		UI.corner(bal, 6)
		bal.Parent = veld

		local x = 0
		local hoogteStap = 1 / (#pad + 1)
		for r, stap in pad do
			x += stap - 0.5
			local doel = UDim2.fromScale(0.5 + x / (#pad + 1), hoogteStap * (r + 0.6))
			local tw = TweenService:Create(bal, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = doel,
			})
			tw:Play()
			tw.Completed:Wait()
		end
		local eind = bakken[bak + 1]
		if eind then
			local tw = TweenService:Create(bal, TweenInfo.new(0.12), { Position = UDim2.fromScale((bak + 0.5) / #bakken, 1) })
			tw:Play()
			tw.Completed:Wait()
			-- Het bakje knippert even op, zodat je ziet waar hij viel.
			local oud = eind.BackgroundColor3
			eind.BackgroundColor3 = Theme.color.text
			task.delay(0.25, function()
				if eind.Parent then eind.BackgroundColor3 = oud end
			end)
		end
		task.delay(0.2, function()
			bal:Destroy()
		end)
	end

	-- ---------- de bediening ----------
	local keuzes = UI.panel(bediening, "Setup")
	UI.list(keuzes, 6)
	UI.panelTitle(keuzes, "rows")
	local rijRij = Common.row(keuzes, 28)
	local rijKnoppen: { [number]: TextButton } = {}
	UI.panelTitle(keuzes, "risk")
	local riskRij = Common.row(keuzes, 28)
	local riskKnoppen: { [string]: TextButton } = {}

	local function markeer()
		for n, b in rijKnoppen do
			b.BackgroundTransparency = if n == rijen then 0.1 else 0.5
			b.TextColor3 = if n == rijen then Theme.color.bg else Theme.color.text
			b.BackgroundColor3 = if n == rijen then Theme.color.neon else Theme.color.bg
		end
		for k, b in riskKnoppen do
			b.BackgroundTransparency = if k == risico then 0.1 else 0.5
			b.TextColor3 = if k == risico then Theme.color.bg else Theme.color.text
			b.BackgroundColor3 = if k == risico then Theme.color.neon else Theme.color.bg
		end
	end

	for _, n in RIJEN do
		local b = UI.chip(rijRij, tostring(n))
		b.Size = UDim2.new(1 / #RIJEN, -4, 0, 28)
		b.Activated:Connect(function()
			rijen = n
			teken()
			markeer()
		end)
		rijKnoppen[n] = b
	end
	for _, k in RISICO do
		local b = UI.chip(riskRij, string.upper(k))
		b.Size = UDim2.new(1 / #RISICO, -4, 0, 28)
		b.Activated:Connect(function()
			risico = k
			teken()
			markeer()
		end)
		riskKnoppen[k] = b
	end

	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "DROP BALL")

	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "DROPPING..."
		local res = Common.call("Bet", "plinko", betBox.get(), rijen, risico)
		if not res then
			bezig = false
			knop.Text = "DROP BALL"
			return
		end
		laatVallen(res.path, res.bucket)
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 10 then "gold" else "green")
		else
			balk.set(Money.fmt(res.mult) .. "\u{00D7}", "red")
		end
		bezig = false
		knop.Text = "DROP BALL"
	end)

	teken()
	markeer()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "plinko")
	Common.oddsPanel(bediening, "odds", "Every row is a fair 50/50. The payout table is normalised to RTP 97% per row count and risk level. Higher risk means bigger outliers and more small losses.")

end

return Plinko
