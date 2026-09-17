--!strict
-- Prestaties: de drie badges die je aan anderen laat zien, de stand van de sprint, en het
-- hele rek met wat er te halen valt.
--
-- Klikken op een badge in een gevuld vakje legt hem weer af. Dat was in de webversie een
-- aparte wens: zonder dat kon je een badge wel oppakken maar nooit meer neerleggen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Ach = require(ReplicatedStorage.Shared.Achievements)
local Season = require(ReplicatedStorage.Shared.Season)
local Common = require(script.Parent.Common)

local Achievements = {}

local NIVEAU = {
	bronze = Color3.fromHex("c98a4b"),
	silver = Color3.fromHex("b9c2cf"),
	gold = Color3.fromHex("e0b555"),
}

function Achievements.build(ouder: Instance): (any) -> ()
	local blad = Common.sheet(ouder)

	-- ---------- de drie vakjes ----------
	local etalage = UI.panel(blad, "Featured")
	UI.list(etalage, 6)
	UI.panelTitle(etalage, "featured \u{00B7} click a filled slot to take it off")

	local vakjesRij = Instance.new("Frame")
	vakjesRij.Size = UDim2.new(1, 0, 0, 72)
	vakjesRij.BackgroundTransparency = 1
	vakjesRij.Parent = etalage
	UI.list(vakjesRij, 8, Enum.FillDirection.Horizontal)

	local uitgelicht: { string } = {}
	local open: { [string]: number } = {}
	local vakjes: { TextButton } = {}
	local zetUitgelicht: () -> ()

	for i = 1, 3 do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. i
		b.Size = UDim2.fromOffset(72, 72)
		b.Text = "+"
		b.Font = Theme.font.ui
		b.TextSize = 30
		b.TextColor3 = Theme.color.muted
		b.BackgroundColor3 = Theme.color.bg
		b.BackgroundTransparency = 0.45
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.RichText = false
		UI.corner(b, Theme.size.radiusBig)
		UI.stroke(b, Theme.color.border)
		b.Parent = vakjesRij
		vakjes[i] = b

		-- Een gevuld vakje legt de badge weer af.
		b.Activated:Connect(function()
			local id = uitgelicht[i]
			if not id then return end
			table.remove(uitgelicht, i)
			Common.call("SetFeatured", uitgelicht)
			zetUitgelicht()
			Common.toast("BADGE TAKEN OFF", nil)
		end)
	end

	-- ---------- de sprint ----------
	local sprintVak = UI.panel(blad, "Sprint")
	UI.list(sprintVak, 4)
	UI.panelTitle(sprintVak, "sprint profit \u{00B7} title and a vip pass")
	local sprintNaam = Common.statRow(sprintVak, "SPRINT", "\u{2014}")
	local sprintKlok = Common.statRow(sprintVak, "ENDS IN", "\u{2014}")
	local seizoenKlok = Common.statRow(sprintVak, "SEASON ENDS IN", "\u{2014}")
	local mijnWinst = Common.statRow(sprintVak, "YOUR SPRINT PROFIT", "$0.00")
	local prijsUitleg = UI.label(sprintVak, "\u{25BA} FINISH A SPRINT AT #1 AND THE VIP ZONE IS YOURS FOR THE SEASON", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	prijsUitleg.TextWrapped = true
	prijsUitleg.Size = UDim2.new(1, 0, 0, 26)

	local standVak = UI.panel(blad, "Standings")
	UI.list(standVak, 3)
	UI.panelTitle(standVak, "standings")
	local standLijst = Instance.new("Frame")
	standLijst.Size = UDim2.new(1, 0, 0, 0)
	standLijst.AutomaticSize = Enum.AutomaticSize.Y
	standLijst.BackgroundTransparency = 1
	standLijst.Parent = standVak
	UI.list(standLijst, 2)
	local leegLabel = UI.label(standLijst, "Nog niemand op de lijst deze sprint.", {
		size = Theme.text.small, color = Theme.color.muted,
	})

	-- ---------- het rek ----------
	local rek = UI.panel(blad, "All")
	UI.list(rek, 6)
	local rekTitel = UI.label(rek, "\u{25BA} ACHIEVEMENTS \u{00B7} 0 / " .. #Ach.LIST, {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiBold,
	})

	local raster = Instance.new("Frame")
	raster.Size = UDim2.new(1, 0, 0, 0)
	raster.AutomaticSize = Enum.AutomaticSize.Y
	raster.BackgroundTransparency = 1
	raster.Parent = rek
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 168, 0, 74)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = raster

	type Kaartje = { knop: TextButton, rand: UIStroke, icoon: TextLabel, titel: TextLabel, tekst: TextLabel }
	local kaartjes: { [string]: Kaartje } = {}

	for i, a in Ach.LIST do
		local knop = Instance.new("TextButton")
		knop.Name = a.id
		knop.Text = ""
		knop.BackgroundColor3 = Theme.color.bg
		knop.BackgroundTransparency = 0.5
		knop.BorderSizePixel = 0
		knop.AutoButtonColor = false
		knop.LayoutOrder = i
		UI.corner(knop, Theme.size.radius)
		local rand = UI.stroke(knop, Theme.color.border)
		knop.Parent = raster

		local icoon = UI.label(knop, a.icon, {
			size = 26, align = Enum.TextXAlignment.Center,
		})
		icoon.Position = UDim2.new(0, 6, 0, 8)
		icoon.Size = UDim2.fromOffset(34, 34)

		local titel = UI.label(knop, a.title, {
			size = Theme.text.small, color = Theme.color.text, font = Theme.font.uiBold,
		})
		titel.Position = UDim2.new(0, 46, 0, 8)
		titel.Size = UDim2.new(1, -52, 0, 16)

		local tekst = UI.label(knop, a.desc, { size = Theme.text.tiny, color = Theme.color.muted })
		tekst.Position = UDim2.new(0, 46, 0, 26)
		tekst.Size = UDim2.new(1, -52, 0, 40)
		tekst.TextWrapped = true
		tekst.TextYAlignment = Enum.TextYAlignment.Top

		kaartjes[a.id] = { knop = knop, rand = rand, icoon = icoon, titel = titel, tekst = tekst }

		-- Een prestatie die je hebt kun je in een vrij vakje leggen.
		knop.Activated:Connect(function()
			if not open[a.id] then
				Common.toast("NOT UNLOCKED YET", "red")
				return
			end
			if table.find(uitgelicht, a.id) then
				Common.toast("ALREADY FEATURED", nil)
				return
			end
			if #uitgelicht >= 3 then
				Common.toast("ALL THREE SLOTS ARE FULL", "red")
				return
			end
			table.insert(uitgelicht, a.id)
			Common.call("SetFeatured", uitgelicht)
			zetUitgelicht()
		end)
	end

	function zetUitgelicht()
		for i, b in vakjes do
			local id = uitgelicht[i]
			local a = if id then Ach.BY_ID[id] else nil
			b.Text = if a then a.icon else "+"
			b.TextSize = if a then 34 else 30
			b.TextColor3 = if a then Theme.color.text else Theme.color.muted
			b.BackgroundTransparency = if a then 0.2 else 0.45
		end
	end

	-- ---------- de ranglijst ophalen ----------
	local function ververs()
		local res = Common.call("Leaderboard")
		if not res then return end
		sprintNaam.Text = res.label
		sprintKlok.Text = Season.countdown(res.endsAt, res.now)
		seizoenKlok.Text = Season.countdown(res.seasonEndsAt, res.now)
		mijnWinst.Text = "$" .. Money.fmt(res.mine or 0)

		for _, k in standLijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		leegLabel.Visible = #res.top == 0
		for _, plek in res.top do
			local naam = plek.rank .. ". " .. plek.name
			local rij = Common.statRow(standLijst, naam, "$" .. Money.fmt(plek.profit))
			rij.TextColor3 = if plek.rank <= 3 then Theme.color.gold else Theme.color.text
		end
	end

	task.spawn(function()
		while true do
			ververs()
			task.wait(30)
		end
	end)

	-- Het profiel binnenkrijgen.
	return function(p: any)
		if typeof(p) ~= "table" then return end
		open = if typeof(p.achievements) == "table" then p.achievements else {}
		uitgelicht = {}
		if typeof(p.featured) == "table" then
			for _, id in p.featured do
				if typeof(id) == "string" and Ach.BY_ID[id] then table.insert(uitgelicht, id) end
			end
		end
		zetUitgelicht()

		local aantal = 0
		for _, a in Ach.LIST do
			local k = kaartjes[a.id]
			local heeft = open[a.id] ~= nil
			if heeft then aantal += 1 end
			k.knop.BackgroundTransparency = if heeft then 0.15 else 0.55
			k.rand.Color = if heeft then NIVEAU[a.tier] else Theme.color.border
			k.icoon.TextTransparency = if heeft then 0 else 0.6
			k.titel.TextColor3 = if heeft then NIVEAU[a.tier] else Theme.color.muted
			k.tekst.TextTransparency = if heeft then 0 else 0.35
		end
		rekTitel.Text = "\u{25BA} ACHIEVEMENTS \u{00B7} " .. aantal .. " / " .. #Ach.LIST
	end
end

return Achievements
