--!strict
-- Paardenrace: zes banen, zes paarden, en een race waarin je pas op het eind ziet wie er
-- wint. De uitslag staat vanaf de eerste tel vast -- die komt van de server -- maar het
-- tempo per paard verschilt en er zit een golf in de looplijn, zodat de kop wisselt.
-- Zonder dat zag je meteen welk paard ging winnen, en dat haalde de spanning eruit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Horse = {}

type Loop = {
	pace: number,   -- hoe een paard zijn tempo verdeelt: laag = snelle start, hoog = eindsprint
	amp: number,    -- hoe ver hij van de zuivere lijn afwijkt
	freq: number,
	fase: number,
	eind: number,   -- wanneer hij over de streep is
}

function Horse.build(ouder: Instance): ()
	local bord, bediening = Common.columns(ouder, "HORSE RACE")

	local baan = UI.panel(bord, "Track")
	UI.list(baan, 8)
	UI.panelTitle(baan, "the field")

	local veld = Instance.new("Frame")
	veld.Size = UDim2.new(1, 0, 0, 0)
	veld.AutomaticSize = Enum.AutomaticSize.Y
	veld.BackgroundTransparency = 1
	veld.Parent = baan
	UI.list(veld, 6)

	local balk = Common.banner(baan)
	balk.set("PICK A HORSE", nil)

	local lopers: { Frame } = {}
	local naamLabels: { TextLabel } = {}
	local quoteLabels: { TextLabel } = {}
	local inzetLabels: { TextLabel } = {}
	local inzetten: { [number]: number } = {}
	local betBox: Common.BetBox
	local ververs: () -> ()

	for i, h in Odds.HORSES do
		local rij = Instance.new("Frame")
		rij.Name = "Lane" .. i
		rij.Size = UDim2.new(1, 0, 0, 34)
		rij.BackgroundColor3 = Theme.color.bg
		rij.BackgroundTransparency = 0.5
		rij.BorderSizePixel = 0
		rij.LayoutOrder = i
		UI.corner(rij, Theme.radius.chip)
		rij.Parent = veld

		local kleur = Color3.fromHex(h.color)

		-- Het paard zelf: een gekleurd blokje dat over de baan schuift.
		local loper = Instance.new("Frame")
		loper.AnchorPoint = Vector2.new(0.5, 0.5)
		loper.Position = UDim2.new(0, 22, 0.5, 0)
		loper.Size = UDim2.fromOffset(26, 20)
		loper.BackgroundColor3 = kleur
		loper.BorderSizePixel = 0
		loper.ZIndex = 3
		UI.corner(loper, Theme.radius.chip)
		loper.Parent = rij
		lopers[i] = loper

		local nr = UI.label(loper, tostring(i), {
			size = Theme.text.tiny, color = Theme.color.bg, font = Theme.font.uiMed,
			align = Enum.TextXAlignment.Center,
		})
		nr.Size = UDim2.fromScale(1, 1)
		nr.ZIndex = 4

		local naam = UI.label(rij, h.name, { size = Theme.text.tiny, color = kleur, font = Theme.font.uiMed })
		naam.Position = UDim2.new(0, 44, 0, 2)
		naam.Size = UDim2.new(0, 110, 0, 14)
		naamLabels[i] = naam

		local quote = UI.label(rij, "\u{2014}", {
			size = Theme.text.tiny, color = Theme.color.muted, font = Theme.font.num,
		})
		quote.Position = UDim2.new(0, 44, 0, 16)
		quote.Size = UDim2.new(0, 110, 0, 14)
		quoteLabels[i] = quote

		local inzet = UI.label(rij, "", {
			size = Theme.text.tiny, color = Theme.color.gold, font = Theme.font.num,
			align = Enum.TextXAlignment.Right,
		})
		inzet.AnchorPoint = Vector2.new(1, 0.5)
		inzet.Position = UDim2.new(1, -8, 0.5, 0)
		inzet.Size = UDim2.new(0, 90, 0, 16)
		inzetLabels[i] = inzet

		local knop = Instance.new("TextButton")
		knop.Text = ""
		knop.BackgroundTransparency = 1
		knop.Size = UDim2.fromScale(1, 1)
		knop.ZIndex = 5
		knop.Parent = rij
		knop.Activated:Connect(function()
			local bedrag = betBox.get()
			if bedrag < Money.MIN_BET then
				Common.toast("MINIMUM STAKE $" .. Money.fmt(Money.MIN_BET), "red")
				return
			end
			inzetten[i] = Money.round2((inzetten[i] or 0) + bedrag)
			ververs()
		end)
	end

	-- De paarden terug naar de start, en de baan leeg.
	local function opstellen()
		for i, loper in lopers do
			loper.Position = UDim2.new(0, 22, 0.5, 0)
		end
	end

	-- De race afspelen. `volgorde` komt van de server: plaats 1 wint. De looplijn is
	-- alleen versiering -- elk paard komt precies op zijn eigen plaats binnen.
	local function race(volgorde: { number }, kansen: { number })
		local loop: { [number]: Loop } = {}
		for plaats, paard in volgorde do
			loop[paard] = {
				-- Een lage pace start hard en zakt terug, een hoge komt van achteren. Door
				-- dat te schudden weet je aan de start niet wie er gaat winnen.
				pace = 0.55 + math.random() * 1.35,
				amp = 0.05 + math.random() * 0.07,
				freq = 1.6 + math.random() * 2.2,
				fase = math.random() * math.pi * 2,
				eind = 5.0 + (plaats - 1) * 0.28 + math.random() * 0.16,
			}
		end

		local langste = 0
		for _, l in loop do
			if l.eind > langste then langste = l.eind end
		end

		local start = os.clock()
		local verbinding: RBXScriptConnection
		local klaar = false
		verbinding = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			for i, loper in lopers do
				local l = loop[i]
				local u = math.min(1, t / l.eind)
				local pos = u ^ l.pace
				-- De golf is nul aan het begin en aan het eind, dus hij verandert de
				-- uitslag niet, alleen het beeld ertussenin.
				pos += l.amp * math.sin(l.freq * t + l.fase) * math.sin(math.pi * u)
				pos = math.clamp(pos, 0, 1)
				local baanBreedte = loper.Parent :: Frame
				local ruimte = math.max(0, baanBreedte.AbsoluteSize.X - 44)
				loper.Position = UDim2.new(0, 22 + pos * ruimte, 0.5, 0)
			end
			if t >= langste and not klaar then
				klaar = true
				verbinding:Disconnect()
			end
		end)

		while not klaar do
			task.wait(0.05)
		end
	end

	-- ---------- de bediening ----------
	betBox = Common.betBox(bediening, 10)

	local overzicht = UI.panel(bediening, "Slip")
	UI.list(overzicht, 4)
	UI.panelTitle(overzicht, "your slip")
	local totaalLabel = Common.statRow(overzicht, "TOTAL STAKED", "$0.00")

	local wissen = UI.secondary(bediening, "CLEAR BETS")
	local starten = UI.primary(bediening, "START RACE")

	function ververs()
		local t = 0
		for i, b in inzetten do
			t += b
		end
		totaalLabel.Text = "$" .. Money.fmt(Money.round2(t))
		for i, label in inzetLabels do
			local b = inzetten[i]
			label.Text = if b then "$" .. Money.fmt(b) else ""
		end
	end

	wissen.Activated:Connect(function()
		table.clear(inzetten)
		ververs()
	end)

	local bezig = false
	starten.Activated:Connect(function()
		if bezig then return end
		local totaal = 0
		for _, b in inzetten do totaal += b end
		if totaal < Money.MIN_BET then
			Common.toast("BACK A HORSE FIRST", "red")
			return
		end
		bezig = true
		starten.Text = "RACING..."
		balk.set("AND THEY'RE OFF", nil)
		opstellen()

		local kopie: { [number]: number } = {}
		for i, b in inzetten do kopie[i] = b end
		local res = Common.call("Bet", "horse", kopie)
		if not res then
			bezig = false
			starten.Text = "START RACE"
			return
		end

		-- De quotes pas tonen als de race loopt: daarvoor weet je ze nog niet.
		for i, p in res.probs do
			quoteLabels[i].Text = Money.fmt(Odds.horseMultiplier(p)) .. "\u{00D7}"
		end

		race(res.order, res.probs)

		local winnaar = Odds.HORSES[res.winner]
		if res.payout > 0 then
			balk.set(winnaar.name .. " WINS  \u{00B7}  +$" .. Money.fmt(res.payout), "green")
			Common.toast("+$" .. Money.fmt(res.payout), "green")
		else
			balk.set(winnaar.name .. " WINS  \u{00B7}  -$" .. Money.fmt(Money.round2(totaal)), "red")
		end
		table.clear(inzetten)
		ververs()
		bezig = false
		starten.Text = "START RACE"
	end)

	ververs()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "horse")
	Common.oddsPanel(bediening, "odds", "Every horse has its own win chance, shown as a percentage. Payout = 0.97 / win chance, so RTP 97% on every horse, favourite or longshot. The result is drawn before the start; the race just plays it out.")

end

return Horse
