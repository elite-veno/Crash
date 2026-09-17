--!strict
-- Crash: één ronde voor iedereen tegelijk. De client tekent de curve en telt de multiplier
-- mee op de servertijd, maar wat een cashout oplevert bepaalt de server -- de knop stuurt
-- alleen "ik stap uit", nooit een bedrag of een multiplier.
--
-- Onder de grafiek staat de belofte van de ronde. Na afloop komt het zaad erbij, zodat
-- iedereen kan narekenen dat het crashpunt al vastlag voordat er iemand inzette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Crash = {}

local GROEI = 0.103995
local SPOOR = 90   -- zoveel stipjes vormen de curve

local function multBij(t: number): number
	if t <= 0 then return 1 end
	return math.max(1, math.floor(math.exp(GROEI * t) * 100) / 100)
end

function Crash.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, "CRASH")

	local vak = UI.panel(bord, "Flight")
	UI.list(vak, 8)
	UI.panelTitle(vak, "crash")

	-- De lucht waar de curve in getekend wordt.
	local lucht = Instance.new("Frame")
	lucht.Name = "Sky"
	lucht.Size = UDim2.new(1, 0, 0, 300)
	lucht.BackgroundColor3 = Color3.fromHex("101922")
	lucht.BorderSizePixel = 0
	UI.corner(lucht, Theme.radius.button)
	lucht.ClipsDescendants = true
	lucht.Parent = vak

	local verloop = Instance.new("UIGradient")
	verloop.Color = ColorSequence.new(Color3.fromHex("16283a"), Color3.fromHex("0c131a"))
	verloop.Rotation = 90
	verloop.Parent = lucht

	local stippen: { Frame } = {}
	for i = 1, SPOOR do
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(4, 4)
		d.BackgroundColor3 = Theme.color.neon
		d.BorderSizePixel = 0
		d.Visible = false
		d.ZIndex = 2
		UI.corner(d, 2)
		d.Parent = lucht
		stippen[i] = d
	end

	local raket = Instance.new("TextLabel")
	raket.AnchorPoint = Vector2.new(0.5, 0.5)
	raket.Size = UDim2.fromOffset(28, 28)
	raket.BackgroundTransparency = 1
	raket.Text = "\u{25B2}"
	raket.Font = Theme.font.uiMed
	raket.TextSize = 20
	raket.TextColor3 = Theme.color.neon
	raket.ZIndex = 3
	raket.Visible = false
	raket.Parent = lucht

	local groot = UI.label(lucht, "\u{2014}", {
		size = Theme.text.giant, color = Theme.color.text, font = Theme.font.num,
		align = Enum.TextXAlignment.Center,
	})
	groot.AnchorPoint = Vector2.new(0.5, 0.5)
	groot.Position = UDim2.fromScale(0.5, 0.42)
	groot.Size = UDim2.new(1, 0, 0, 70)
	groot.ZIndex = 4

	local status = UI.label(lucht, "WAITING", {
		size = Theme.text.label, color = Theme.color.muted, font = Theme.font.uiMed,
		align = Enum.TextXAlignment.Center,
	})
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0.42, 38)
	status.Size = UDim2.new(1, 0, 0, 20)
	status.ZIndex = 4

	-- De belofte en het zaad: het bewijs dat de ronde niet is bijgesteld.
	local eerlijk = UI.panel(bord, "Fairness")
	UI.list(eerlijk, 4)
	UI.panelTitle(eerlijk, "provably fair")
	local commitLabel = Common.statRow(eerlijk, "COMMIT", "\u{2014}")
	local seedLabel = Common.statRow(eerlijk, "SEED", "\u{2014}")
	local puntLabel = Common.statRow(eerlijk, "CRASHED AT", "\u{2014}")
	local uitlegLabel = UI.label(eerlijk, "sha256(\"commit:\" + seed) hoort bij de belofte hierboven.", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	uitlegLabel.TextWrapped = true
	uitlegLabel.Size = UDim2.new(1, 0, 0, 26)

	-- ---------- de bediening ----------
	local betBox = Common.betBox(bediening, 10)
	local knop = UI.primary(bediening, "PLACE BET")

	local tafel = UI.panel(bediening, "Players")
	UI.list(tafel, 4)
	UI.panelTitle(tafel, "this round")
	local spelersVak = Instance.new("Frame")
	spelersVak.Size = UDim2.new(1, 0, 0, 0)
	spelersVak.AutomaticSize = Enum.AutomaticSize.Y
	spelersVak.BackgroundTransparency = 1
	spelersVak.Parent = tafel
	UI.list(spelersVak, 2)

	-- ---------- de stand ----------
	-- Wie er in deze ronde zit leest het scherm uit wat de server stuurt, niet uit een
	-- eigen vlaggetje: dan klopt het ook als je net binnenkwam of even weg was.
	local stand: any = nil
	local mijnNaam = game:GetService("Players").LocalPlayer.DisplayName

	local function toonSpelers()
		for _, k in spelersVak:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		if not stand or not stand.bets then return end
		local lijst = stand.bets
		table.sort(lijst, function(a, b)
			return a.bet > b.bet
		end)
		for i, b in lijst do
			if i > 10 then break end
			local waarde = if b.cashed
				then Money.fmt(b.cashed) .. "\u{00D7}  +$" .. Money.fmt(b.payout or 0)
				else "$" .. Money.fmt(b.bet)
			local rij = Common.statRow(spelersVak, b.naam, waarde)
			rij.TextColor3 = if b.cashed then Theme.color.neon else Theme.color.text
		end
	end

	local function mijnInzet(): any
		if not stand or not stand.bets then return nil end
		for _, b in stand.bets do
			if b.naam == mijnNaam then return b end
		end
		return nil
	end

	local function zetKnop()
		local fase = if stand then stand.phase else "idle"
		local mijn = mijnInzet()
		if fase == "waiting" then
			knop.Text = if mijn then "BET PLACED" else "PLACE BET"
			knop.Active = mijn == nil
			betBox.lock(mijn ~= nil)
		elseif fase == "flying" then
			if mijn and not mijn.cashed then
				knop.Text = "CASH OUT"
				knop.Active = true
			else
				knop.Text = if mijn then "CASHED OUT" else "IN FLIGHT"
				knop.Active = false
			end
			betBox.lock(true)
		else
			knop.Text = "ROUND OVER"
			knop.Active = false
			betBox.lock(true)
		end
		knop.BackgroundTransparency = if knop.Active then 0 else 0.55
	end

	-- De curve tekenen tot punt u van de vlucht.
	local function tekenCurve(tNu: number, hoogste: number)
		raket.Visible = true
		for i = 1, SPOOR do
			local deel = i / SPOOR
			local t = tNu * deel
			local m = multBij(t)
			local x = deel * 0.9 + 0.05
			-- De y-as schaalt mee met de hoogste stand, zodat de curve in beeld blijft.
			local y = 0.92 - (m - 1) / math.max(0.2, hoogste - 1) * 0.8
			local d = stippen[i]
			d.Visible = true
			d.Position = UDim2.fromScale(x, math.clamp(y, 0.05, 0.95))
		end
		local laatste = stippen[SPOOR]
		raket.Position = laatste.Position
	end

	local function wisCurve()
		for _, d in stippen do
			d.Visible = false
		end
		raket.Visible = false
	end

	local function zetKleur(kleur: Color3)
		groot.TextColor3 = kleur
		raket.TextColor3 = kleur
		for _, d in stippen do
			d.BackgroundColor3 = kleur
		end
	end

	local function toonFairness()
		if not stand then return end
		commitLabel.Text = if stand.commit then string.sub(stand.commit, 1, 16) .. "\u{2026}" else "\u{2014}"
		seedLabel.Text = if stand.seed then string.sub(stand.seed, 1, 18) .. "\u{2026}" else "hidden until the crash"
		puntLabel.Text = if stand.crashAt then Money.fmt(stand.crashAt) .. "\u{00D7}" else "\u{2014}"
	end

	local function nieuweStand(s: any)
		if typeof(s) ~= "table" then return end
		if stand and s.id and stand.id and s.id ~= stand.id then
			wisCurve()
		end
		stand = s
		toonSpelers()
		toonFairness()
		zetKnop()
	end

	-- Elke frame de klok aflezen en de curve bijwerken. De servertijd is op beide kanten
	-- hetzelfde, dus dit loopt gelijk met wat de server rekent.
	RunService.RenderStepped:Connect(function()
		if not stand then return end
		local nu = workspace:GetServerTimeNow()
		local fase = stand.phase

		if fase == "waiting" then
			local over = math.max(0, (stand.startsAt or nu) - nu)
			groot.Text = string.format("%.1f", over)
			zetKleur(Theme.color.text)
			status.Text = "NEXT ROUND IN"
			wisCurve()
		elseif fase == "flying" then
			local t = nu - (stand.startsAt or nu)
			local m = multBij(t)
			groot.Text = Money.fmt(m) .. "\u{00D7}"
			zetKleur(Theme.color.neon)
			status.Text = "IN FLIGHT"
			tekenCurve(t, m)
		else
			local c = stand.crashAt or 1
			groot.Text = Money.fmt(c) .. "\u{00D7}"
			zetKleur(Theme.color.red)
			status.Text = "CRASHED"
			tekenCurve((stand.endsAt or nu) - (stand.startsAt or nu), c)
		end
	end)

	knop.Activated:Connect(function()
		if not stand or not knop.Active then return end
		if stand.phase == "waiting" then
			if Common.call("Bet", "crash", betBox.get()) then
				Common.toast("BET PLACED", "green")
			end
		elseif stand.phase == "flying" then
			local res = Common.call("CashOut", "crash")
			if res then
				Common.toast("+$" .. Money.fmt(res.payout) .. "  \u{00B7}  " .. Money.fmt(res.mult) .. "\u{00D7}", "green")
			end
		end
		zetKnop()
	end)

	-- De server duwt elke faseverandering; bij binnenkomst één keer zelf vragen.
	Net.ev("Round").OnClientEvent:Connect(function(s: any)
		if typeof(s) == "table" and s.game == "crash" then
			nieuweStand(s)
		end
	end)

	task.spawn(function()
		local ok, res = pcall(function()
			return Net.fn("RoundState"):InvokeServer("crash")
		end)
		if ok then nieuweStand(res) end
	end)

	zetKnop()
	-- De twee panelen waar elke aside in de webversie mee afsluit.
	Common.statsPanel(bediening, "crash")
	Common.oddsPanel(bediening, "odds", "RTP 97%. The chance a flight reaches Mx is 0.97 / M. Around 3% of rounds crash straight away at 1.00x.")

end

return Crash
