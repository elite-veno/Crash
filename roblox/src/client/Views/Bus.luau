--!strict
-- Ride the Bus: vier keer raden door één stapel -- kleur, hoger of lager, binnen of buiten,
-- en de soort. De kans wordt geteld op wat er nog in de stapel ligt, dus uitstappen levert
-- na elke call precies hetzelfde percentage op, hoe goed of slecht je ook geraden hebt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Bus = {}

local STAPNAMEN = {"COLOUR", "HIGHER OR LOWER", "INSIDE OR OUTSIDE", "SUIT"}

-- Een speelkaart: wit vlak, rode of zwarte tekst, zoals in de webversie.
local function kaartVlak(ouder: Instance, kaart: { r: string, s: string }?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(74, 104)
	f.BackgroundColor3 = if kaart then Theme.color.card else Theme.color.panelLight
	f.BorderSizePixel = 0
	UI.corner(f, Theme.radius.card)
	UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	if kaart then
		local rood = kaart.s == "\u{2665}" or kaart.s == "\u{2666}"
		local kleur = if rood then Color3.fromHex("c0392b") else Color3.fromHex("14181f")
		local t = UI.label(f, kaart.r .. "\n" .. kaart.s, {
			size = 22, color = kleur, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center,
		})
		t.Size = UDim2.fromScale(1, 1)
		t.TextYAlignment = Enum.TextYAlignment.Center
	else
		local t = UI.label(f, "?", {
			size = 30, color = Theme.color.muted, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center,
		})
		t.Size = UDim2.fromScale(1, 1)
		t.TextYAlignment = Enum.TextYAlignment.Center
	end
	return f
end

function Bus.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, "RIDE THE BUS")

	local tafel = UI.panel(bord, "Table")
	UI.list(tafel, 10)
	UI.panelTitle(tafel, "ride the bus")

	local stapLabel = UI.label(tafel, "STEP 1 \u{00B7} " .. STAPNAMEN[1], {
		size = Theme.text.label, color = Theme.color.neon, font = Theme.font.uiMed,
	})

	local kaarten = Instance.new("Frame")
	kaarten.Size = UDim2.new(1, 0, 0, 110)
	kaarten.BackgroundTransparency = 1
	kaarten.Parent = tafel
	local kaartLayout = UI.list(kaarten, 10, Enum.FillDirection.Horizontal)
	kaartLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local keuzes = Instance.new("Frame")
	keuzes.Size = UDim2.new(1, 0, 0, 40)
	keuzes.BackgroundTransparency = 1
	keuzes.Parent = tafel
	UI.list(keuzes, 8, Enum.FillDirection.Horizontal)

	local balk = Common.banner(tafel)
	balk.set("FOUR CALLS, ONE DECK", nil)

	local actief = false
	local stap = 0
	local betBox: Common.BetBox
	local startKnop: TextButton
	local uitKnop: TextButton

	local function wisKaarten()
		for _, k in kaarten:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
	end

	local function wisKeuzes()
		for _, k in keuzes:GetChildren() do
			if k:IsA("TextButton") then k:Destroy() end
		end
	end

	local roep: (string) -> ()

	-- De knoppen voor deze stap, met de kans erbij. Een kans van nul is geen knop maar een
	-- grijs vlak: de server weigert die call toch, en dat hoor je te zien voordat je klikt.
	local function toonOpties(opties: { { key: string, label: string, chance: number } })
		wisKeuzes()
		for i, o in opties do
			local b = Instance.new("TextButton")
			b.Name = o.key
			b.Text = o.label .. "   " .. string.format("%d%%", math.floor(o.chance * 100 + 0.5))
			b.Font = Theme.font.uiMed
			b.TextSize = Theme.text.small
			b.LayoutOrder = i
			b.Size = UDim2.new(1 / #opties, -8, 1, 0)
			b.BorderSizePixel = 0
			b.AutoButtonColor = false
			b.RichText = false
			local kan = o.chance > 0
			b.Active = kan
			b.BackgroundColor3 = if kan then Theme.color.neon else Theme.color.bg
			b.BackgroundTransparency = if kan then 0.1 else 0.6
			b.TextColor3 = if kan then Theme.color.bg else Theme.color.muted
			UI.corner(b, Theme.radius.button)
			b.Parent = keuzes
			b.Activated:Connect(function()
				if kan then roep(o.key) end
			end)
		end
	end

	local function zetActief()
		startKnop.Visible = not actief
		uitKnop.Visible = actief
		uitKnop.Active = stap > 0
		keuzes.Visible = actief
		betBox.lock(actief)
	end

	function roep(keuze: string)
		if not actief then return end
		local res = Common.call("Act", "bus", keuze)
		if not res then return end

		kaartVlak(kaarten, res.card).LayoutOrder = stap + 1
		if not res.hit then
			actief = false
			stap = 0
			wisKeuzes()
			zetActief()
			balk.set("WRONG CALL", "red")
			return
		end

		if res.done then
			actief = false
			stap = 0
			wisKeuzes()
			zetActief()
			balk.set("ALL FOUR  \u{00B7}  +$" .. Money.fmt(res.payout), "gold")
			Common.toast("+$" .. Money.fmt(res.payout), "gold")
			return
		end

		stap = res.step
		stapLabel.Text = "STEP " .. (stap + 1) .. " \u{00B7} " .. STAPNAMEN[stap + 1]
		balk.set(Money.fmt(res.mult) .. "\u{00D7} SO FAR", "green")
		uitKnop.Text = "CASH OUT  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}"
		toonOpties(res.options)
		zetActief()
	end

	-- ---------- de bediening ----------
	local uitleg = UI.panel(bediening, "Steps")
	UI.list(uitleg, 4)
	UI.panelTitle(uitleg, "the four calls")
	for i, naam in STAPNAMEN do
		Common.statRow(uitleg, i .. ". " .. naam, "")
	end

	betBox = Common.betBox(bediening, 10)
	startKnop = UI.primary(bediening, "START THE RIDE")
	uitKnop = UI.primary(bediening, "CASH OUT")
	uitKnop.Visible = false

	startKnop.Activated:Connect(function()
		if actief then return end
		local res = Common.call("Bet", "bus", betBox.get())
		if not res then return end
		actief = true
		stap = 0
		wisKaarten()
		stapLabel.Text = "STEP 1 \u{00B7} " .. STAPNAMEN[1]
		uitKnop.Text = "CASH OUT"
		toonOpties(res.options)
		zetActief()
		balk.set("RED OR BLACK?", nil)
	end)

	uitKnop.Activated:Connect(function()
		if not actief or stap < 1 then return end
		local res = Common.call("CashOut", "bus")
		if not res then return end
		actief = false
		stap = 0
		wisKeuzes()
		zetActief()
		balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
		Common.toast("+$" .. Money.fmt(res.payout), "green")
	end)

	wisKaarten()
	zetActief()
end

return Bus
