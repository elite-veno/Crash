--!strict
-- Blackjack: zes stapels, dealer pakt bij tot 17. De dichte kaart van de dealer staat hier
-- niet in het geheugen van de client -- die komt pas over als de dealer speelt.
--
-- De dubbele inzet wordt er overal bij gezet ("DOUBLED"), want zonder dat leek het alsof
-- je bij een gedubbelde hand te weinig kreeg. Het bedrag klopte altijd; wat ontbrak was
-- dat het scherm liet zien waar het over ging.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Money = require(ReplicatedStorage.Shared.Money)
local Common = require(script.Parent.Common)

local Blackjack = {}

type Kaart = { r: string, s: string }

local function kaartVlak(ouder: Instance, kaart: Kaart?, volgorde: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(70, 98)
	f.LayoutOrder = volgorde
	f.BackgroundColor3 = if kaart then Theme.color.card else Color3.fromHex("1b222c")
	f.BorderSizePixel = 0
	UI.corner(f, Theme.size.radiusBig)
	UI.stroke(f, Theme.color.border)
	f.Parent = ouder

	local tekst = if kaart then kaart.r .. "\n" .. kaart.s else "\u{2756}"
	local rood = kaart ~= nil and (kaart.s == "\u{2665}" or kaart.s == "\u{2666}")
	local kleur = if not kaart then Theme.color.muted
		elseif rood then Color3.fromHex("c0392b")
		else Color3.fromHex("14181f")
	local t = UI.label(f, tekst, {
		size = 22, color = kleur, font = Theme.font.uiBold, align = Enum.TextXAlignment.Center,
	})
	t.Size = UDim2.fromScale(1, 1)
	t.TextYAlignment = Enum.TextYAlignment.Center
	return f
end

function Blackjack.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local bord, bediening = Common.columns(blad, 300)

	local tafel = UI.panel(bord, "Table")
	UI.list(tafel, 8)
	UI.panelTitle(tafel, "blackjack \u{00B7} dealer stands on all 17s")

	local dealerKop = UI.label(tafel, "DEALER", {
		size = Theme.text.small, color = Theme.color.muted, font = Theme.font.uiBold,
	})
	local dealerRij = Instance.new("Frame")
	dealerRij.Size = UDim2.new(1, 0, 0, 104)
	dealerRij.BackgroundTransparency = 1
	dealerRij.Parent = tafel
	local dl = UI.list(dealerRij, 8, Enum.FillDirection.Horizontal)
	dl.VerticalAlignment = Enum.VerticalAlignment.Center

	local spelerKop = UI.label(tafel, "YOU", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiBold,
	})
	local spelerRij = Instance.new("Frame")
	spelerRij.Size = UDim2.new(1, 0, 0, 104)
	spelerRij.BackgroundTransparency = 1
	spelerRij.Parent = tafel
	local sl = UI.list(spelerRij, 8, Enum.FillDirection.Horizontal)
	sl.VerticalAlignment = Enum.VerticalAlignment.Center

	local balk = Common.banner(tafel)
	balk.set("PLACE YOUR BET", nil)

	local actief = false
	local gedubbeld = false
	local betBox: Common.BetBox
	local dealKnop: TextButton
	local hitKnop: TextButton
	local standKnop: TextButton
	local doubleKnop: TextButton

	local function wis(rij: Frame)
		for _, k in rij:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
	end

	local function toonHand(rij: Frame, kaarten: { Kaart }, dicht: boolean)
		wis(rij)
		for i, k in kaarten do
			kaartVlak(rij, k, i)
		end
		if dicht then
			kaartVlak(rij, nil, #kaarten + 1)
		end
	end

	-- De inzetregel: hier komt (DOUBLED) bij te staan zodra er gedubbeld is.
	local function zetKoppen(spelerWaarde: number?, dealerWaarde: number?, inzet: number?)
		local dub = if gedubbeld then "  \u{00B7}  DOUBLED" else ""
		spelerKop.Text = "YOU" .. (if spelerWaarde then "  \u{00B7}  " .. spelerWaarde else "")
			.. (if inzet then "  \u{00B7}  STAKE $" .. Money.fmt(inzet) else "") .. dub
		dealerKop.Text = "DEALER" .. (if dealerWaarde then "  \u{00B7}  " .. dealerWaarde else "")
	end

	local function zetKnoppen()
		dealKnop.Visible = not actief
		hitKnop.Visible = actief
		standKnop.Visible = actief
		doubleKnop.Visible = actief
		betBox.lock(actief)
	end

	local function toonEinde(res: any)
		actief = false
		gedubbeld = res.doubled == true
		toonHand(spelerRij, res.player, false)
		toonHand(dealerRij, res.dealer, false)
		zetKoppen(res.playerValue, res.dealerValue, res.bet)
		zetKnoppen()

		local dub = if res.doubled then "  (DOUBLED)" else ""
		if res.result == "win" then
			local wat = if res.natural then "BLACKJACK" else "YOU WIN"
			balk.set(wat .. "  \u{00B7}  +$" .. Money.fmt(res.payout) .. dub, if res.natural then "gold" else "green")
			Common.toast("+$" .. Money.fmt(res.payout) .. dub, if res.natural then "gold" else "green")
		elseif res.result == "push" then
			balk.set("PUSH  \u{00B7}  $" .. Money.fmt(res.payout) .. " BACK" .. dub, nil)
		else
			balk.set("DEALER WINS  \u{00B7}  -$" .. Money.fmt(res.bet) .. dub, "red")
		end
	end

	local function toonSpel(res: any)
		actief = true
		gedubbeld = res.doubled == true
		toonHand(spelerRij, res.player, false)
		toonHand(dealerRij, { res.dealerUp }, true)
		zetKoppen(res.playerValue, res.dealerValue, res.bet)
		-- Dubbelen mag alleen op de eerste twee kaarten, net als aan een echte tafel.
		doubleKnop.Active = #res.player == 2 and not gedubbeld
		doubleKnop.BackgroundTransparency = if doubleKnop.Active then 0.1 else 0.6
		zetKnoppen()
		balk.set("HIT, STAND OR DOUBLE", nil)
	end

	local function verwerk(res: any)
		if not res then return end
		if res.done then
			toonEinde(res)
		else
			toonSpel(res)
		end
	end

	-- ---------- de bediening ----------
	local regels = UI.panel(bediening, "Rules")
	UI.list(regels, 4)
	UI.panelTitle(regels, "rules")
	Common.statRow(regels, "DECKS", "6")
	Common.statRow(regels, "BLACKJACK PAYS", "3:2")
	Common.statRow(regels, "DEALER", "STANDS ON 17")
	Common.statRow(regels, "DOUBLE", "FIRST TWO CARDS")
	Common.statRow(regels, "RTP", "99%")

	betBox = Common.betBox(bediening, 10)
	dealKnop = UI.primary(bediening, "DEAL")
	hitKnop = UI.primary(bediening, "HIT")
	standKnop = UI.secondary(bediening, "STAND")
	standKnop.Size = UDim2.new(1, 0, 0, 40)
	doubleKnop = UI.secondary(bediening, "DOUBLE")
	doubleKnop.Size = UDim2.new(1, 0, 0, 40)

	dealKnop.Activated:Connect(function()
		if actief then return end
		gedubbeld = false
		verwerk(Common.call("Bet", "blackjack", betBox.get()))
	end)
	hitKnop.Activated:Connect(function()
		if not actief then return end
		verwerk(Common.call("Act", "blackjack", "hit"))
	end)
	standKnop.Activated:Connect(function()
		if not actief then return end
		verwerk(Common.call("Act", "blackjack", "stand"))
	end)
	doubleKnop.Activated:Connect(function()
		if not actief or not doubleKnop.Active then return end
		verwerk(Common.call("Act", "blackjack", "double"))
	end)

	zetKnoppen()
	zetKoppen(nil, nil, nil)
end

return Blackjack
