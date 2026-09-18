--!strict
-- 777: drie rollen achter een gouden venster. De uitslag komt van de server; het rollen is
-- alleen het wachten aankleden.
--
-- Het beeld komt uit `#slotsView` in de markup en uit `.slot-machine`, `.slot-reels`,
-- `.slot-reel` en `.sl-hist` in de CSS. Rechts staat alleen de rollenkast met daaronder de
-- rij laatste uitslagen -- geen kop boven het bord en geen uitslagbalk eronder, want die
-- staan in de webversie ook niet op het bord: daar komt de uitslag als melding voorbij,
-- precies zoals flash() dat doet. Links het inzetvak met SPIN in hetzelfde paneel, en
-- daaronder PAYOUTS, STATISTICS en ODDS, in die volgorde.
--
-- 777 is een VIP-spel, dus de terugknop wijst hier naar de VIP-zone en niet naar de lobby
-- (`data-route="vip"`, `← VIP ZONE` in de markup).
--
-- Wat Roblox niet heeft: de box-shadow onder `.btn-bet`, de letter-spacing van
-- `.panel-title`, en `flex-wrap` op de uitslagenrij -- die blijft hier altijd één regel,
-- wat op een bord van deze breedte met acht vakjes ook zo uitpakt. De rgba()-kleuren uit
-- de CSS staan hier als kleur plus doorzichtigheid, want zo werkt Roblox.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Slots = {}

-- ---------- maten uit de CSS ----------
local ROL_B = 108                 -- .slot-reel width
local ROL_H = 128                 -- .slot-reel height
local ROL_GAT = 10                -- .slot-reels gap
local KAST_PAD = 16               -- .slot-reels padding
local SYMBOOL = 54                -- .slot-reel font-size
-- Drie rollen, twee keer tussenruimte, en aan weerskanten de padding van de kast.
local KAST_B = ROL_B * 3 + ROL_GAT * 2 + KAST_PAD * 2
local KAST_H = ROL_H + KAST_PAD * 2
local MACHINE_GAT = 18            -- .slot-machine gap
local HIST_H = 24 - 2             -- .sl-hist is 24 in de CSS; de rand ligt buiten het vak
local HIST_GAT = 6                -- .sl-history-row gap
local MAX_HIST = 8                -- SL.history.length > 8 -> pop()

-- De rgba()-waarden van de kast: achtergrond rgba(0,0,0,0.35), rand rgba(224,181,85,0.45).
local KAST_VUL = 0.65
local KAST_RAND = 0.55
-- .slot-reel.spin { opacity: 0.55 }. Eén vlak in Roblox doorzichtig maken kan niet in één
-- greep, dus vulling, rand en teken doven alle drie even ver weg.
local DRAAI_DOF = 0.45

-- Het rollen zelf, uit slSpin(): elke rol staat 60 ms op een symbool en ze vallen op
-- 750, 1150 en 1600 ms stil. Hier in seconden.
local TIK = 0.06
local STOP = { 0.75, 1.15, 1.6 }

-- ---------- bouwsteentjes die alleen dit scherm gebruikt ----------
-- .sl-hist: de drie symbolen, en bij winst de multiplier erachter. Een vakje dat uitbetaald
-- heeft krijgt neon tekst en een neonrand (.sl-hist.win), de rest blijft grijs.
local function histVakje(ouder: Instance, symbolen: string, mult: number, orde: number): ()
	local won = mult > 0
	local tekst = if won then symbolen .. " " .. Money.fmt(mult) .. "\u{00D7}" else symbolen
	local t = UI.label(ouder, tekst, {
		size = Theme.text.tiny,
		color = if won then Theme.color.neon else Theme.color.muted,
		font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
		name = "Hist",
	})
	t.Size = UDim2.new(0, 0, 0, HIST_H)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.LayoutOrder = orde
	t.BackgroundColor3 = Theme.color.black
	t.BackgroundTransparency = 0.75                 -- rgba(0,0,0,0.25)
	UI.corner(t, 6)                                 -- .sl-hist border-radius
	-- .sl-hist.win: rgba(62,207,142,0.45) -- kleur plus doorzichtigheid.
	local rand = UI.stroke(t, if won then Theme.color.neon else Theme.color.border)
	if won then rand.Transparency = 0.55 end
	UI.padding4(t, 0, 8, 0, 8)
end

-- .sc-prize: de symbolen links, de multiplier rechts in goud in het cijferlettertype.
-- Twaalf pixels tekst in een regel van zestien; het paneel eromheen staat in de markup op
-- tien, maar deze regel zet zijn eigen maat.
local function prijsRegel(ouder: Instance, symbolen: string, mult: number, orde: number): ()
	local rij = Instance.new("Frame")
	rij.Name = "Prize"
	rij.Size = UDim2.new(1, 0, 0, 16)
	rij.BackgroundTransparency = 1
	rij.LayoutOrder = orde
	rij.Parent = ouder

	-- De letter-spacing van 1px uit `.sc-prize .sy` kan Roblox niet; die is weggelaten.
	local s = UI.label(rij, symbolen, { size = Theme.text.body, color = Theme.color.text, name = "Sym" })
	local m = UI.label(rij, Money.fmt(mult) .. "\u{00D7}", {
		size = Theme.text.body, color = Theme.color.gold, font = Theme.font.num,
		align = Enum.TextXAlignment.Right, name = "Mult",
	})
	for _, t in { s, m } do
		t.Size = UDim2.fromScale(1, 1)
		t.TextYAlignment = Enum.TextYAlignment.Center
	end
end

function Slots.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "777", "vip", "\u{2190} VIP ZONE")

	-- ---------- het bord ----------
	-- `.slot-machine`: één kolom, gecentreerd, met 18 pixels tussen de kast en de
	-- uitslagenrij. Als eigen vak, zodat de tussenruimte van het bord er niets aan verandert.
	local machine = Instance.new("Frame")
	machine.Name = "SlotMachine"
	machine.Size = UDim2.new(1, 0, 0, 0)
	machine.AutomaticSize = Enum.AutomaticSize.Y
	machine.BackgroundTransparency = 1
	machine.Parent = bord
	local machineLijst = UI.list(machine, MACHINE_GAT)
	machineLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- `.slot-reels`: de donkere kast met de gouden rand waar de drie vensters in staan.
	local kast = Instance.new("Frame")
	kast.Name = "Reels"
	kast.Size = UDim2.fromOffset(KAST_B, KAST_H)
	kast.BackgroundColor3 = Theme.color.black
	kast.BackgroundTransparency = KAST_VUL
	kast.BorderSizePixel = 0
	kast.LayoutOrder = 1
	kast.Parent = machine
	UI.corner(kast, 10)                             -- .slot-reels border-radius
	local kastRand = UI.stroke(kast, Theme.color.gold)
	kastRand.Transparency = KAST_RAND
	UI.padding(kast, KAST_PAD)
	local kastLijst = UI.list(kast, ROL_GAT, Enum.FillDirection.Horizontal)
	kastLijst.VerticalAlignment = Enum.VerticalAlignment.Center

	type Rol = { vak: Frame, sym: TextLabel, rand: UIStroke }
	local rollen: { Rol } = {}
	for i = 1, 3 do
		local vak = Instance.new("Frame")
		vak.Name = "Reel" .. i
		vak.Size = UDim2.fromOffset(ROL_B, ROL_H)
		vak.BackgroundColor3 = Theme.color.panelLight
		vak.BorderSizePixel = 0
		vak.LayoutOrder = i
		vak.Parent = kast
		UI.corner(vak, 8)                           -- .slot-reel border-radius
		local rand = UI.stroke(vak, Theme.color.border)

		local sym = UI.label(vak, Odds.SLOT_SYMBOLS[i], {
			size = SYMBOOL, align = Enum.TextXAlignment.Center, name = "Symbol",
		})
		sym.Size = UDim2.fromScale(1, 1)
		sym.TextYAlignment = Enum.TextYAlignment.Center
		rollen[i] = { vak = vak, sym = sym, rand = rand }
	end

	-- Een rol die draait dooft weg en komt weer op als hij stilvalt.
	local function dof(i: number, aan: boolean)
		local r = rollen[i]
		r.vak.BackgroundTransparency = if aan then DRAAI_DOF else 0
		r.rand.Transparency = if aan then DRAAI_DOF else 0
		r.sym.TextTransparency = if aan then DRAAI_DOF else 0
	end

	-- `.sl-history-row`: leeg is hij nul hoog, net als een lege div; pas als er een uitslag
	-- in staat neemt hij plaats in.
	local histRij = Instance.new("Frame")
	histRij.Name = "History"
	histRij.Size = UDim2.new(1, 0, 0, 0)
	histRij.BackgroundTransparency = 1
	histRij.LayoutOrder = 2
	histRij.Parent = machine
	local histLijst = UI.list(histRij, HIST_GAT, Enum.FillDirection.Horizontal)
	histLijst.HorizontalAlignment = Enum.HorizontalAlignment.Center
	histLijst.SortOrder = Enum.SortOrder.LayoutOrder

	local geschiedenis: { { symbolen: string, mult: number } } = {}
	local function toonGeschiedenis()
		for _, kind in histRij:GetChildren() do
			if kind:IsA("TextLabel") then kind:Destroy() end
		end
		for i, h in geschiedenis do
			histVakje(histRij, h.symbolen, h.mult, i)
		end
		histRij.Size = UDim2.new(1, 0, 0, if #geschiedenis > 0 then HIST_H else 0)
	end

	-- ---------- de bediening links ----------
	-- In de markup staan het inzetveld met zijn ficheknoppen en SPIN in één `.panel`.
	-- Common.betBox maakt dat paneel, dus de knop gaat erbij in.
	local betBox = Common.betBox(bediening, 10)

	-- Bij de andere spellen staat er nog een veld of een uitbetalingsregel tussen het
	-- inzetvak en de knop; hier volgt SPIN er meteen op, en dan valt op dat hij te hoog
	-- hangt. In de CSS sluit `.field-group` af met 14 pixels lucht en begint
	-- `.btn-primary` met 8, samen 22. De lijst van het paneel geeft er zelf 6 voor en 6 na
	-- een kind, dus een leeg vakje van 10 vult het aan. Padding op de knop zelf zou de
	-- tekst verschuiven in plaats van de knop.
	local lucht = Instance.new("Frame")
	lucht.Name = "Gap"
	lucht.Size = UDim2.new(1, 0, 0, 22 - 6 - 6)
	lucht.BackgroundTransparency = 1
	lucht.LayoutOrder = 10
	lucht.Parent = betBox.panel

	-- .btn-primary.btn-bet: het verloop van neon naar neon-dim, vet, volle breedte.
	local knop = UI.primary(betBox.panel, "SPIN")
	knop.LayoutOrder = 11
	knop.Font = Theme.font.uiBold
	UI.gradient(knop, Theme.color.neon, Theme.color.neonDim, 135)

	-- De uitbetalingstabel, dezelfde regels als slotPayout() in Odds: drie gelijke betalen
	-- volgens de tabel, twee kersen met wat dan ook erbij betalen klein -- vandaar het
	-- plusje achter het paar.
	local tabel = UI.panel(bediening, "Payouts")
	UI.list(tabel, 6)                               -- .sc-legend gap
	UI.panelTitle(tabel, "\u{25BA} payouts")
	for i, p in Odds.SLOT_PRIZES do
		local symbolen = if p.kind == "triple" then p.sym .. p.sym .. p.sym else p.sym .. p.sym .. " +"
		prijsRegel(tabel, symbolen, p.mult, i)
	end

	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "slots")
	Common.oddsPanel(bediening, "odds", "The result is drawn before the reels stop; the animation only shows it. RTP *97%*, chance of a prize *17%*.")

	-- ---------- draaien ----------
	local bezig = false
	knop.Activated:Connect(function()
		if bezig then return end
		bezig = true
		knop.Text = "SPINNING\u{2026}"
		UI.setEnabled(knop, false)
		betBox.lock(true)

		local inzet = betBox.get()
		local res = Common.call("Bet", "slots", inzet)
		if not res then
			bezig = false
			knop.Text = "SPIN"
			UI.setEnabled(knop, true)
			betBox.lock(false)
			return
		end

		-- De rollen vallen van links naar rechts stil; dat is de hele spanning. Tot dat
		-- moment loopt elke rol met een eigen voorsprong door de symbolen, net als in
		-- slSpin(): syms[(floor(t / 60) + i * 2) % syms.length].
		local aantal = #Odds.SLOT_SYMBOLS
		local stil = { false, false, false }
		for i = 1, 3 do dof(i, true) end
		local t0 = os.clock()
		while true do
			local t = os.clock() - t0
			local alles = true
			for i = 1, 3 do
				if t >= STOP[i] then
					if not stil[i] then
						stil[i] = true
						rollen[i].sym.Text = res.reels[i]
						dof(i, false)
					end
				else
					alles = false
					local stap = math.floor(t / TIK) + (i - 1) * 2
					rollen[i].sym.Text = Odds.SLOT_SYMBOLS[stap % aantal + 1]
				end
			end
			if alles then break end
			RunService.Heartbeat:Wait()
		end

		local symbolen = res.reels[1] .. res.reels[2] .. res.reels[3]
		table.insert(geschiedenis, 1, { symbolen = symbolen, mult = res.mult })
		if #geschiedenis > MAX_HIST then table.remove(geschiedenis) end
		toonGeschiedenis()

		-- slSettle(): pas boven de inzet is het een winst om te vieren, en vanaf twaalf keer
		-- wordt de melding goud.
		if res.payout > inzet then
			Common.toast(
				symbolen .. " \u{00B7} +$" .. Money.fmt(res.payout),
				if res.mult >= 12 then "gold" else "green"
			)
		else
			Common.toast("NO COMBINATION", "red")
		end

		bezig = false
		knop.Text = "SPIN"
		UI.setEnabled(knop, true)
		betBox.lock(false)
	end)
end

return Slots
