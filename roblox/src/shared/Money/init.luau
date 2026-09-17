--!strict
-- Bedragen. In de webversie is dit round2/floor2 door de hele code heen; hier staat het
-- op één plek, zodat client en server het op de cent eens zijn.
local Money = {}

Money.START = 1000
Money.MIN_BET = 1

-- Naar beneden op twee decimalen: zo rekent de webversie een uitbetaling af. De epsilon
-- staat er omdat 1.2 * 1.5 in drijvende komma 1.7999999... is: zonder hem is elke
-- uitbetaling een cent te laag. De webversie doet hetzelfde (floor2 in crash.html).
function Money.floor2(x: number): number
	return math.floor(x * 100 + 1e-9) / 100
end

-- Naar de dichtstbijzijnde cent: zo wordt een saldo bewaard.
function Money.round2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function Money.fmt(x: number): string
	return string.format("%.2f", x)
end

-- Is dit uberhaupt een bedrag? NaN glipt door elke gewone vergelijking heen (NaN < 1 is
-- false, en NaN is truthy), dus dat moet apart. Spellen met meerdere inzetten tegelijk
-- gebruiken deze, en tellen daarna pas op.
function Money.cleanAmount(raw: any): number?
	local n = tonumber(raw)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	-- Een inzet gaat naar de dichtstbijzijnde cent, net als takeBet() in de webversie;
	-- naar beneden afkappen is alleen voor wat er uitbetaald wordt.
	n = Money.round2(n)
	if n < Money.MIN_BET then return nil end
	return n
end

-- Een inzet die een speler opstuurt: nooit vertrouwen, altijd door deze zeef.
function Money.cleanBet(raw: any, saldo: number): number?
	local n = Money.cleanAmount(raw)
	if not n then return nil end
	if n > saldo + 1e-9 then return nil end
	return n
end

-- Een geheel getal binnen een bereik: tegelnummers, rijen, aantallen mijnen. Zonder deze
-- controle leest grid[1.5] als nil, en nil is niet "een mijn".
function Money.cleanIndex(raw: any, min: number, max: number): number?
	local n = tonumber(raw)
	if not n or n ~= n or n ~= math.floor(n) then return nil end
	if n < min or n > max then return nil end
	return n
end

return Money
