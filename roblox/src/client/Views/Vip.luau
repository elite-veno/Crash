--!strict
-- De VIP-zone. Wie een sprint van drie dagen op nummer één afsluit, mag het hele seizoen
-- naar binnen: twee spellen die nergens anders in het casino staan.
--
-- De poort staat op de server, bij de spellen zelf. Dit scherm laat alleen zien of hij open
-- is; de knoppen uitzetten is netjes, maar het is niet wat je tegenhoudt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Vip = {}

local PERKS = {
	{ "\u{1F3B0}", "777", "Three reels. Three sevens pay 40x. Nowhere else in the casino." },
	{ "\u{1F68C}", "Ride the Bus", "Four calls through a shuffled deck, cash out after any of them." },
	{ "\u{1F39F}", "Four ways in", "Every three-day sprint crowns a new number one, so a season has four." },
}

local KAARTEN = {
	{ id = "slots", label = "777", desc = "Three reels, three sevens pay 40x.",
	  van = Color3.fromHex("4a3a12"), tot = Color3.fromHex("1e1707") },
	{ id = "bus", label = "RIDE THE BUS", desc = "Four calls through one deck.",
	  van = Color3.fromHex("2a3550"), tot = Color3.fromHex("141a28") },
}

function Vip.build(ouder: Instance, ga: (string) -> ()): (any) -> ()
	local blad = Common.sheet(ouder)

	-- ---------- de poort ----------
	local poort = UI.panel(blad, "Gate")
	UI.list(poort, 6)
	local slot = UI.label(poort, "\u{1F512}", { size = 40, align = Enum.TextXAlignment.Center })
	slot.Size = UDim2.new(1, 0, 0, 46)

	local kop = UI.label(poort, "THE ZONE IS CLOSED", {
		size = Theme.text.big, color = Theme.color.gold, font = Theme.font.uiBold,
		align = Enum.TextXAlignment.Center,
	})
	kop.Size = UDim2.new(1, 0, 0, 28)

	local onder = UI.label(poort, "\u{25BA} FINISH A SPRINT AT #1 AND THE ZONE IS YOURS FOR THE SEASON", {
		size = Theme.text.small, color = Theme.color.muted, align = Enum.TextXAlignment.Center,
	})
	onder.TextWrapped = true
	onder.Size = UDim2.new(1, 0, 0, 30)

	local klok = UI.label(poort, "", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
	})

	-- ---------- wat je ermee krijgt ----------
	local voordelen = UI.panel(blad, "Perks")
	UI.list(voordelen, 6)
	UI.panelTitle(voordelen, "what a pass gets you")
	for _, perk in PERKS do
		local rij = Instance.new("Frame")
		rij.Size = UDim2.new(1, 0, 0, 36)
		rij.BackgroundTransparency = 1
		rij.Parent = voordelen

		local ic = UI.label(rij, perk[1], { size = 22, align = Enum.TextXAlignment.Center })
		ic.Size = UDim2.fromOffset(30, 30)

		local t = UI.label(rij, perk[2], {
			size = Theme.text.small, color = Theme.color.gold, font = Theme.font.uiBold,
		})
		t.Position = UDim2.new(0, 36, 0, 0)
		t.Size = UDim2.new(1, -40, 0, 16)

		local d = UI.label(rij, perk[3], { size = Theme.text.tiny, color = Theme.color.muted })
		d.Position = UDim2.new(0, 36, 0, 16)
		d.Size = UDim2.new(1, -40, 0, 18)
	end

	-- ---------- de twee spellen ----------
	local spellen = UI.panel(blad, "Games")
	UI.list(spellen, 6)
	UI.panelTitle(spellen, "vip games")

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = spellen
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 250, 0, 150)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = raster

	local kaartRanden: { UIStroke } = {}
	local kaartSloten: { TextLabel } = {}

	for i, k in KAARTEN do
		local f = Instance.new("Frame")
		f.Name = k.id
		f.BackgroundColor3 = Theme.color.panel
		f.BorderSizePixel = 0
		f.LayoutOrder = i
		UI.corner(f, Theme.size.radiusBig)
		kaartRanden[i] = UI.stroke(f, Theme.color.border)
		f.Parent = raster

		local beeld = Instance.new("Frame")
		beeld.Size = UDim2.new(1, 0, 0, 78)
		beeld.BackgroundColor3 = k.van
		beeld.BorderSizePixel = 0
		beeld.Parent = f
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(k.van, k.tot)
		g.Rotation = 90
		g.Parent = beeld
		UI.corner(beeld, Theme.size.radiusBig)

		local body = Instance.new("Frame")
		body.Position = UDim2.new(0, 0, 0, 78)
		body.Size = UDim2.new(1, 0, 1, -78)
		body.BackgroundTransparency = 1
		body.Parent = f
		UI.padding(body, 10)
		UI.list(body, 4)
		UI.label(body, k.label, { size = Theme.text.label, color = Theme.color.gold, font = Theme.font.uiBold })
		local d = UI.label(body, k.desc, { size = Theme.text.tiny, color = Theme.color.muted })
		d.TextWrapped = true
		d.Size = UDim2.new(1, 0, 0, 28)

		local hangslot = UI.label(f, "\u{1F512}", { size = 26, align = Enum.TextXAlignment.Center })
		hangslot.AnchorPoint = Vector2.new(0.5, 0.5)
		hangslot.Position = UDim2.fromScale(0.5, 0.26)
		hangslot.Size = UDim2.fromOffset(40, 40)
		hangslot.ZIndex = 4
		kaartSloten[i] = hangslot

		local knop = Instance.new("TextButton")
		knop.Text = ""
		knop.BackgroundTransparency = 1
		knop.Size = UDim2.fromScale(1, 1)
		knop.ZIndex = 5
		knop.Parent = f
		knop.Activated:Connect(function()
			if hangslot.Visible then
				Common.toast("VIP PASS REQUIRED", "red")
				return
			end
			ga(k.id)
		end)
	end

	local function zetPoort(open: boolean, tot: number?, nu: number?)
		slot.Text = if open then "\u{1F511}" else "\u{1F512}"
		kop.Text = if open then "THE ZONE IS OPEN" else "THE ZONE IS CLOSED"
		kop.TextColor3 = if open then Theme.color.neon else Theme.color.gold
		onder.Text = if open
			then "\u{25BA} YOUR PASS RUNS UNTIL THE END OF THIS SEASON"
			else "\u{25BA} FINISH A SPRINT AT #1 AND THE ZONE IS YOURS FOR THE SEASON"
		klok.Text = if open and tot then "PASS EXPIRES IN " .. Season.countdown(tot, nu) else ""
		for i = 1, #KAARTEN do
			kaartSloten[i].Visible = not open
			kaartRanden[i].Color = if open then Theme.color.gold else Theme.color.border
		end
	end

	zetPoort(false)

	-- De server zegt of de pas geldt; de klok komt er bij de ranglijst mee.
	task.spawn(function()
		while true do
			local res = Common.call("Leaderboard")
			if res then
				zetPoort(res.vipActive == true, res.seasonEndsAt, res.now)
			end
			task.wait(30)
		end
	end)

	return function(p: any)
		if typeof(p) ~= "table" then return end
		-- Het profiel draagt het seizoen van de pas; dat is genoeg om het scherm meteen
		-- goed te zetten zonder op de ranglijst te wachten.
		zetPoort(Season.vipActive(tonumber(p.vipSeason)), nil, nil)
	end
end

return Vip
