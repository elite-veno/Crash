--!strict
-- Roulette: het inzetvlak met de nullen tot en met 36, de buitenkansen eronder, en het rad
-- dat naar het gewonnen vak draait. Europees, dus één groene nul -- zelfde bord als de
-- webversie.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Roulette = {}

local ROOD = Color3.fromHex("c0392b")
local ZWART = Color3.fromHex("1c2129")
local GROEN = Color3.fromHex("1e7a4f")

local function kleurVan(n: number): Color3
	local k = Odds.rouletteColor(n)
	return if k == "green" then GROEN elseif k == "red" then ROOD else ZWART
end

-- De buitenkansen, met wat ze uitbetalen erbij, zoals op het echte bord.
local BUITEN = {
	{ key = "d1", label = "1st 12", breed = 1 / 3 },
	{ key = "d2", label = "2nd 12", breed = 1 / 3 },
	{ key = "d3", label = "3rd 12", breed = 1 / 3 },
	{ key = "low", label = "1-18", breed = 1 / 6 },
	{ key = "even", label = "EVEN", breed = 1 / 6 },
	{ key = "red", label = "RED", breed = 1 / 6 },
	{ key = "black", label = "BLACK", breed = 1 / 6 },
	{ key = "odd", label = "ODD", breed = 1 / 6 },
	{ key = "high", label = "19-36", breed = 1 / 6 },
}

function Roulette.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, 300)

	-- ---------- het rad ----------
	local radVak = UI.panel(bord, "Wheel")
	UI.list(radVak, 8)
	UI.panelTitle(radVak, "wheel")

	-- De houder blijft stilstaan; alleen de ring erin draait, zodat de naald op zijn plek
	-- blijft wijzen.
	local radHouder = Instance.new("Frame")
	radHouder.Name = "WheelBox"
	radHouder.Size = UDim2.new(1, 0, 0, 220)
	radHouder.BackgroundTransparency = 1
	radHouder.Parent = radVak

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = radHouder

	-- De 37 vakken op een cirkel. Geen plaatje nodig: elk vak is een klein blokje dat op
	-- zijn eigen hoek staat.
	local straal = 96
	local vakjes: { TextLabel } = {}
	for i, n in Odds.ROULETTE_ORDER do
		local hoek = (i - 1) / #Odds.ROULETTE_ORDER * math.pi * 2 - math.pi / 2
		local v = Instance.new("TextLabel")
		v.Name = "N" .. n
		v.AnchorPoint = Vector2.new(0.5, 0.5)
		v.Position = UDim2.new(0.5, math.cos(hoek) * straal, 0.5, math.sin(hoek) * straal)
		v.Size = UDim2.fromOffset(24, 24)
		v.BackgroundColor3 = kleurVan(n)
		v.BorderSizePixel = 0
		v.Text = tostring(n)
		v.Font = Theme.font.num
		v.TextSize = Theme.text.tiny
		v.TextColor3 = Theme.color.text
		v.RichText = false
		UI.corner(v, 12)
		v.Parent = ring
		vakjes[n] = v
	end

	local naald = Instance.new("Frame")
	naald.Name = "Pointer"
	naald.AnchorPoint = Vector2.new(0.5, 1)
	naald.Position = UDim2.new(0.5, 0, 0.5, 0)
	naald.Size = UDim2.fromOffset(3, 70)
	naald.BackgroundColor3 = Theme.color.neon
	naald.BorderSizePixel = 0
	naald.ZIndex = 3
	naald.Parent = radHouder

	local uitslag = Common.bigNumber(radVak, "-", Theme.color.muted)
	local balk = Common.banner(radVak)
	balk.set("PLACE YOUR BETS", nil)

	-- ---------- het inzetvlak ----------
	local bordVak = UI.panel(bord, "Table")
	UI.list(bordVak, 6)
	UI.panelTitle(bordVak, "table")

	local inzetten: { [string]: number } = {}
	local fiches: { [string]: TextLabel } = {}
	local betBox: Common.BetBox
	local ververs: () -> ()

	local function toonFiche(key: string)
		local label = fiches[key]
		if label then
			local bedrag = inzetten[key]
			label.Text = if bedrag and bedrag > 0 then "$" .. Money.fmt(bedrag) else ""
			label.Visible = bedrag ~= nil and bedrag > 0
		end
		ververs()
	end

	local function leegmaken()
		for key in inzetten do
			inzetten[key] = nil
		end
		for key in fiches do
			toonFiche(key)
		end
	end

	local function klik(key: string)
		local bedrag = betBox.get()
		if bedrag < Money.MIN_BET then
			Common.toast("MINIMUM STAKE $" .. Money.fmt(Money.MIN_BET), "red")
			return
		end
		inzetten[key] = Money.round2((inzetten[key] or 0) + bedrag)
		toonFiche(key)
	end

	-- Een vak op het bord: de knop plus het fiche dat erop komt te liggen.
	local function vak(ouder: Instance, key: string, tekst: string, kleur: Color3, hoogte: number): TextButton
		local b = Instance.new("TextButton")
		b.Name = key
		b.Text = tekst
		b.Font = Theme.font.uiBold
		b.TextSize = Theme.text.small
		b.TextColor3 = Theme.color.text
		b.BackgroundColor3 = kleur
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Size = UDim2.new(1, 0, 0, hoogte)
		b.RichText = false
		UI.corner(b, Theme.size.radiusSmall)
		UI.stroke(b, Theme.color.border)
		b.Parent = ouder

		local fiche = UI.label(b, "", {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
			align = Enum.TextXAlignment.Center, name = "Chip",
		})
		fiche.AnchorPoint = Vector2.new(0.5, 1)
		fiche.Position = UDim2.new(0.5, 0, 1, -1)
		fiche.Size = UDim2.new(1, 0, 0, 12)
		fiche.Visible = false
		fiches[key] = fiche

		b.Activated:Connect(function()
			klik(key)
		end)
		return b
	end

	-- De nul over de volle breedte, daarna drie rijen van twaalf.
	vak(bordVak, "n:0", "0", GROEN, 30)

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = bordVak
	local rasterLayout = Instance.new("UIGridLayout")
	rasterLayout.CellSize = UDim2.new(1 / 12, -4, 0, 28)
	rasterLayout.CellPadding = UDim2.fromOffset(4, 4)
	rasterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rasterLayout.Parent = raster
	for n = 1, 36 do
		local b = vak(raster, "n:" .. n, tostring(n), kleurVan(n), 28)
		b.Size = UDim2.new()
		b.LayoutOrder = n
	end

	local rij1 = Common.row(bordVak, 28)
	local rij2 = Common.row(bordVak, 28)
	for _, b in BUITEN do
		local waar = if b.breed > 0.25 then rij1 else rij2
		local kleur = if b.key == "red" then ROOD elseif b.key == "black" then ZWART else Theme.color.panelLight
		local knop = vak(waar, b.key, b.label, kleur, 28)
		knop.Size = UDim2.new(b.breed, -6, 0, 28)
	end

	-- ---------- de bediening ----------
	betBox = Common.betBox(bediening, 10)

	local totaalRegel = UI.panel(bediening, "Total")
	UI.list(totaalRegel, 4)
	UI.panelTitle(totaalRegel, "your bets")
	local totaalLabel = Common.statRow(totaalRegel, "TOTAL STAKED", "$0.00")
	local aantalLabel = Common.statRow(totaalRegel, "SPOTS", "0")

	local function telOp(): number
		local t = 0
		for _, b in inzetten do t += b end
		return Money.round2(t)
	end
	function ververs()
		local n = 0
		for _ in inzetten do n += 1 end
		totaalLabel.Text = "$" .. Money.fmt(telOp())
		aantalLabel.Text = tostring(n)
	end

	local wissen = UI.secondary(bediening, "CLEAR BETS")
	local draaien = UI.primary(bediening, "SPIN")

	wissen.Activated:Connect(function()
		leegmaken()
	end)

	local bezig = false
	draaien.Activated:Connect(function()
		if bezig then return end
		if telOp() < Money.MIN_BET then
			Common.toast("PLACE A BET FIRST", "red")
			return
		end
		bezig = true
		draaien.Text = "SPINNING..."
		balk.set("NO MORE BETS", nil)

		local kopie = {}
		for k, v in inzetten do kopie[k] = v end
		local res = Common.call("Bet", "roulette", kopie)
		if not res then
			bezig = false
			draaien.Text = "SPIN"
			balk.set("PLACE YOUR BETS", nil)
			return
		end

		-- Het rad draait een paar hele slagen en komt dan op het gewonnen vak uit.
		local plek = table.find(Odds.ROULETTE_ORDER, res.number) or 1
		local hoek = -(plek - 1) / #Odds.ROULETTE_ORDER * 360
		local tw = TweenService:Create(ring, TweenInfo.new(2.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Rotation = 360 * 4 + hoek,
		})
		ring.Rotation = ring.Rotation % 360 - 360 * 4
		tw:Play()
		tw.Completed:Wait()

		uitslag.Text = tostring(res.number)
		uitslag.TextColor3 = kleurVan(res.number)
		local inzet = telOp()
		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. string.upper(res.color) .. " " .. res.number, "green")
			Common.toast("+$" .. Money.fmt(res.payout), "green")
		else
			balk.set("-$" .. Money.fmt(inzet) .. "  \u{00B7}  " .. string.upper(res.color) .. " " .. res.number, "red")
		end
		leegmaken()
		bezig = false
		draaien.Text = "SPIN"
	end)

	ververs()
end

return Roulette
