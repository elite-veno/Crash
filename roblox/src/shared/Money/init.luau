--!strict
-- Bedragen. In de webversie is dit round2/floor2 door de hele code heen; hier staat het
-- op één plek, zodat client en server het op de cent eens zijn.
local Money = {}

Money.START = 1000
Money.MIN_BET = 1

-- Naar beneden op twee decimalen: zo rekent de webversie een uitbetaling af.
function Money.floor2(x: number): number
	return math.floor(x * 100) / 100
end

-- Naar de dichtstbijzijnde cent: zo wordt een saldo bewaard.
function Money.round2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function Money.fmt(x: number): string
	return string.format("%.2f", x)
end

-- Een inzet die een speler opstuurt: nooit vertrouwen, altijd door deze zeef.
function Money.cleanBet(raw: any, saldo: number): number?
	local n = tonumber(raw)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	n = Money.floor2(n)
	if n < Money.MIN_BET then return nil end
	if n > saldo + 1e-9 then return nil end
	return n
end

return Money
