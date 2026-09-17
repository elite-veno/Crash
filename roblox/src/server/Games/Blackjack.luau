--!strict
-- Blackjack, afgerekend op de server. Zes stapels, dealer pakt bij tot 17 en blijft staan
-- op zacht 17 -- dezelfde regels als de webversie, en dus dezelfde 99%.
--
-- Het belangrijkste verschil met de browser: de dichte kaart van de dealer gaat hier NIET
-- mee naar de client. Die krijgt hij pas als de dealer speelt. In de webversie stond die
-- kaart in het geheugen van de pagina en was hij in principe te lezen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage.Shared.Odds)
local Money = require(ReplicatedStorage.Shared.Money)
local Profiles = require(script.Parent.Parent.Profiles)

local Blackjack = {}

-- Onder dit aantal kaarten gaat er een verse schoen in; zo houdt niemand de telling bij
-- over de bodem van de stapel heen.
local HERSCHUD = 60

type Ronde = {
	bet: number,
	speler: { Odds.Card },
	dealer: { Odds.Card },
	doubled: boolean,
}

local open: { [number]: Ronde } = {}
-- De schoen blijft tussen handen door staan, net als in de webversie: hij wordt pas
-- vervangen als er te weinig kaarten over zijn.
local schoenen: { [number]: { Odds.Card } } = {}

function Blackjack.get(speler: Player): Ronde?
	return open[speler.UserId]
end

-- Weggaan terwijl er nog een hand loopt: de inzet terug, de dubbele inzet ook.
function Blackjack.refund(speler: Player): number
	local r = open[speler.UserId]
	if not r then return 0 end
	open[speler.UserId] = nil
	local terug = r.bet * (if r.doubled then 2 else 1)
	Profiles.give(speler, terug)
	return terug
end

local function trek(speler: Player): Odds.Card
	local huidig = schoenen[speler.UserId]
	local schoen: { Odds.Card }
	if huidig and #huidig >= HERSCHUD then
		schoen = huidig
	else
		schoen = Odds.bjNewShoe(6)
		schoenen[speler.UserId] = schoen
	end
	return table.remove(schoen) :: Odds.Card
end

local function saldo(speler: Player): number
	local p = Profiles.get(speler)
	return if p then p.balance else 0
end

-- Wat de speler mag zien zolang hij aan zet is: zijn eigen hand, en één kaart van de
-- dealer. De tweede is bewust afwezig -- niet verborgen in een veld, maar er niet.
local function beeld(r: Ronde): any
	local waarde, zacht = Odds.bjValue(r.speler)
	return {
		player = r.speler,
		playerValue = waarde,
		playerSoft = zacht,
		dealerUp = r.dealer[1],
		dealerValue = (Odds.bjValue({ r.dealer[1] })),
		doubled = r.doubled,
		bet = r.bet * (if r.doubled then 2 else 1),
	}
end

-- De hand afrekenen: de dealer speelt uit, en dan pas komt alles op tafel.
local function afrekenen(speler: Player, r: Ronde, dealerSpeelt: boolean): any
	if dealerSpeelt then
		Odds.bjDealerPlay(r.dealer, function()
			return trek(speler)
		end)
	end
	local inzet = r.bet * (if r.doubled then 2 else 1)
	local factor = Odds.bjSettle(r.speler, r.dealer)
	local uit = Money.floor2(inzet * factor)
	open[speler.UserId] = nil
	if uit > 0 then Profiles.give(speler, uit) end
	Profiles.record(speler, "blackjack", inzet, uit, factor, {
		natural = Odds.bjIsBlackjack(r.speler),
		doubled = r.doubled,
	})

	local spelerWaarde = (Odds.bjValue(r.speler))
	local dealerWaarde = (Odds.bjValue(r.dealer))
	local uitslag = if factor > 1 then "win" elseif factor == 1 then "push" else "loss"
	return {
		ok = true, done = true,
		player = r.speler, playerValue = spelerWaarde,
		dealer = r.dealer, dealerValue = dealerWaarde,
		natural = Odds.bjIsBlackjack(r.speler),
		doubled = r.doubled,
		bet = inzet,
		result = uitslag,
		mult = factor,
		payout = uit,
		balance = saldo(speler),
	}
end

function Blackjack.deal(speler: Player, inzet: any): any
	local p = Profiles.get(speler)
	if not p then return { ok = false, err = "geen profiel" } end
	if open[speler.UserId] then return { ok = false, err = "je hebt nog een hand open" } end
	local bet = Money.cleanBet(inzet, p.balance)
	if not bet then return { ok = false, err = "ongeldige inzet" } end
	if not Profiles.take(speler, bet) then return { ok = false, err = "onvoldoende saldo" } end

	local r: Ronde = {
		bet = bet,
		speler = {},
		dealer = {},
		doubled = false,
	}
	-- Om de beurt, zoals aan een echte tafel.
	table.insert(r.speler, trek(speler))
	table.insert(r.dealer, trek(speler))
	table.insert(r.speler, trek(speler))
	table.insert(r.dealer, trek(speler))
	open[speler.UserId] = r

	-- Blackjack ligt meteen op tafel; dan hoeft er niets meer gekozen te worden.
	if Odds.bjIsBlackjack(r.speler) or Odds.bjIsBlackjack(r.dealer) then
		return afrekenen(speler, r, false)
	end

	local b = beeld(r)
	b.ok = true
	b.done = false
	b.balance = saldo(speler)
	return b
end

function Blackjack.act(speler: Player, zet: any): any
	local r = open[speler.UserId]
	if not r then return { ok = false, err = "geen hand" } end
	local k = tostring(zet)

	if k == "hit" then
		table.insert(r.speler, trek(speler))
		if (Odds.bjValue(r.speler)) > 21 then
			return afrekenen(speler, r, false)
		end
		local b = beeld(r)
		b.ok = true
		b.done = false
		b.balance = saldo(speler)
		return b
	end

	if k == "stand" then
		return afrekenen(speler, r, true)
	end

	if k == "double" then
		if #r.speler ~= 2 then return { ok = false, err = "dubbelen kan alleen op de eerste twee kaarten" } end
		if r.doubled then return { ok = false, err = "je hebt al gedubbeld" } end
		-- De tweede helft van de inzet wordt nu pas afgeschreven; lukt dat niet, dan
		-- verandert er niets aan de hand.
		if not Profiles.take(speler, r.bet) then return { ok = false, err = "onvoldoende saldo om te dubbelen" } end
		r.doubled = true
		table.insert(r.speler, trek(speler))
		if (Odds.bjValue(r.speler)) > 21 then
			return afrekenen(speler, r, false)
		end
		return afrekenen(speler, r, true)
	end

	return { ok = false, err = "die zet niet" }
end

Profiles.onLeave(function(sp: Player)
	Blackjack.refund(sp)
	schoenen[sp.UserId] = nil
end)

return Blackjack
