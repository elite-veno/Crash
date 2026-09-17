--!strict
-- 777: drie rollen die uitrollen en dan stilvallen. De uitslag komt van de server; het
-- rollen is alleen het wachten aankleden.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Slots = {}

function Slots.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, "777")

	local kast = UI.panel(bord, "Machine")
	UI.list(kast, 10)
	UI.panelTitle(kast, "777")

	local rollen = Instance.new("Frame")
	rollen.Size = UDim2.new(1, 0, 0, 160)
	rollen.BackgroundTransparency = 1
	rollen.Parent = kast
	local rollenLayout = UI.list(rollen, 10, Enum.FillDirection.Horizontal)
	rollenLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rollenLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local vensters: { TextLabel } = {}
	for i = 1, 3 do
		local venster = Instance.new("Frame")
		venster.Size = UDim2.fromOffset(110, 150)
		venster.BackgroundColor3 = Theme.color.bg
		venster.BorderSizePixel = 0
		venster.LayoutOrder = i
		UI.corner(venster, Theme.radius.card)
		UI.stroke(venster, Theme.color.border)
		venster.Parent = rollen

		local sym = UI.label(venster, Odds.SLOT_SYMBOLS[1], {
			size = 56, align = Enum.TextXAlignment.Center,
		})
		sym.Size = UDim2.fromScale(1, 1)
		sym.TextYAlignment = Enum.TextYAlignment.Center
		vensters[i] = sym
	end

	local balk = Common.banner(kast)
	balk.set("PULL THE LEVER", nil)

	-- De uitbetalingstabel, met dezelfde regels als slotPayout in Odds.
	local tabel = UI.panel(bediening, "Paytable")
	UI.list(tabel, 4)
	UI.panelTitle(tabel, "paytable")
	for _, p in Odds.SLOT_PRIZES do
		local naam = if p.kind == "triple" then p.sym .. p.sym .. p.sym else p.sym .. p.sym .. " \u{00B7} any"
		Common.statRow(tabel, naam, Money.fmt(p.mult) .. "\u{00D7}")
	end

	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "SPIN")

	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "SPINNING..."
		betBox.lock(true)
		balk.set("...", nil)

		local res = Common.call("Bet", "slots", betBox.get())
		if not res then
			bezig = false
			knop.Text = "SPIN"
			betBox.lock(false)
			balk.set("PULL THE LEVER", nil)
			return
		end

		-- De rollen vallen van links naar rechts stil; dat is de hele spanning.
		local klaar = { false, false, false }
		local eind = { 0.6, 1.0, 1.4 }
		local start = os.clock()
		while true do
			local t = os.clock() - start
			local alles = true
			for i = 1, 3 do
				if t >= eind[i] then
					if not klaar[i] then
						klaar[i] = true
						vensters[i].Text = res.reels[i]
					end
				else
					alles = false
					vensters[i].Text = Odds.SLOT_SYMBOLS[math.random(#Odds.SLOT_SYMBOLS)]
				end
			end
			if alles then break end
			task.wait(0.06)
		end

		if res.payout > 0 then
			balk.set("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			Common.toast("+$" .. Money.fmt(res.payout), if res.mult >= 15 then "gold" else "green")
		else
			balk.set("NO WIN", "red")
		end
		bezig = false
		knop.Text = "SPIN"
		betBox.lock(false)
	end)
end

return Slots
