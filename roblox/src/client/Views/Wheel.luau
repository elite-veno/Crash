--!strict
-- Rad van fortuin: twintig even grote vakken, één betaalt tien keer. De ring draait en de
-- naald blijft staan, net als bij roulette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Wheel = {}

-- Dezelfde kleurcodes als de webversie: hoe hoger de multiplier, hoe warmer het vak.
local function kleurVan(m: number): Color3
	if m >= 10 then return Theme.color.gold end
	if m >= 2 then return Theme.color.neon end
	if m > 0 then return Color3.fromHex("2d6f52") end
	return Color3.fromHex("222a33")
end

function Wheel.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, 300)

	local vak = UI.panel(bord, "Wheel")
	UI.list(vak, 8)
	UI.panelTitle(vak, "wheel of fortune")

	local houder = Instance.new("Frame")
	houder.Size = UDim2.new(1, 0, 0, 260)
	houder.BackgroundTransparency = 1
	houder.Parent = vak

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = houder

	local straal = 110
	local vakjes: { TextLabel } = {}
	for i, m in Odds.WHEEL do
		local hoek = (i - 1) / #Odds.WHEEL * math.pi * 2 - math.pi / 2
		local v = Instance.new("TextLabel")
		v.AnchorPoint = Vector2.new(0.5, 0.5)
		v.Position = UDim2.new(0.5, math.cos(hoek) * straal, 0.5, math.sin(hoek) * straal)
		v.Size = UDim2.fromOffset(40, 26)
		v.BackgroundColor3 = kleurVan(m)
		v.BorderSizePixel = 0
		v.Text = if m > 0 then Money.fmt(m) .. "\u{00D7}" else "\u{2014}"
		v.Font = Theme.font.num
		v.TextSize = Theme.text.tiny
		v.TextColor3 = if m >= 2 then Theme.color.bg else Theme.color.muted
		v.RichText = false
		UI.corner(v, Theme.size.radiusSmall)
		v.Parent = ring
		vakjes[i] = v
	end

	local naald = Instance.new("Frame")
	naald.AnchorPoint = Vector2.new(0.5, 1)
	naald.Position = UDim2.new(0.5, 0, 0.5, 0)
	naald.Size = UDim2.fromOffset(3, 84)
	naald.BackgroundColor3 = Theme.color.neon
	naald.BorderSizePixel = 0
	naald.ZIndex = 3
	naald.Parent = houder

	local groot = Common.bigNumber(vak, "\u{2014}", Theme.color.muted)
	local balk = Common.banner(vak)
	balk.set("SPIN THE WHEEL", nil)

	-- De uitbetalingstabel ernaast, zodat je ziet wat er in het rad zit.
	local tabel = UI.panel(bediening, "Paytable")
	UI.list(tabel, 4)
	UI.panelTitle(tabel, "paytable")
	local telling: { [number]: number } = {}
	for _, m in Odds.WHEEL do
		telling[m] = (telling[m] or 0) + 1
	end
	local soorten = {}
	for m in telling do table.insert(soorten, m) end
	table.sort(soorten, function(a, b) return a > b end)
	for _, m in soorten do
		local naam = if m > 0 then Money.fmt(m) .. "\u{00D7}" else "NOTHING"
		Common.statRow(tabel, naam, telling[m] .. " / " .. #Odds.WHEEL)
	end

	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "SPIN")

	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "SPINNING..."
		betBox.lock(true)

		local res = Common.call("Bet", "wheel", betBox.get())
		if not res then
			bezig = false
			knop.Text = "SPIN"
			betBox.lock(false)
			return
		end

		local hoek = -(res.slot - 1) / #Odds.WHEEL * 360
		ring.Rotation = ring.Rotation % 360 - 360 * 3
		local tw = TweenService:Create(ring, TweenInfo.new(2.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Rotation = 360 * 3 + hoek,
		})
		tw:Play()
		tw.Completed:Wait()

		groot.Text = if res.mult > 0 then Money.fmt(res.mult) .. "\u{00D7}" else "\u{2014}"
		groot.TextColor3 = kleurVan(res.mult)
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout), "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 10 then "gold" else "green")
		else
			balk.set("NO WIN", "red")
		end
		bezig = false
		knop.Text = "SPIN"
		betBox.lock(false)
	end)
end

return Wheel
