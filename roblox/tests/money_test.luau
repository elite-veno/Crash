--!strict
-- De zeef waar elke inzet doorheen moet. Dit is de plek waar een speler zou proberen
-- iets binnen te smokkelen, dus hier wordt het hardst gecontroleerd.
local Money = require("../src/shared/Money")
local h = require("./harness")

h.near("floor2 rondt naar beneden", 12.34, Money.floor2(12.349), 1e-9)
h.near("round2 rondt naar de cent", 12.35, Money.round2(12.345), 1e-9)
h.check("fmt geeft altijd twee decimalen", "7.00", Money.fmt(7))
h.check("fmt rondt niet weg", "1000.00", Money.fmt(1000))

-- ---------- wat een speler mag insturen ----------
local saldo = 100

h.check("een gewone inzet mag", 10, Money.cleanBet(10, saldo))
h.check("een inzet met centen mag", 10.5, Money.cleanBet(10.5, saldo))
h.check("meer dan je saldo mag niet", nil, Money.cleanBet(101, saldo))
h.check("precies je saldo mag wel", 100, Money.cleanBet(100, saldo))
h.check("onder het minimum mag niet", nil, Money.cleanBet(0.5, saldo))
h.check("nul mag niet", nil, Money.cleanBet(0, saldo))
h.check("negatief mag niet", nil, Money.cleanBet(-50, saldo))
h.check("tekst mag niet", nil, Money.cleanBet("tien", saldo))
h.check("niets mag niet", nil, Money.cleanBet(nil, saldo))
h.check("een tabel mag niet", nil, Money.cleanBet({}, saldo))
h.check("oneindig mag niet", nil, Money.cleanBet(math.huge, saldo))
h.check("min oneindig mag niet", nil, Money.cleanBet(-math.huge, saldo))
h.check("geen getal mag niet", nil, Money.cleanBet(0 / 0, saldo))
-- een getal als tekst is wel te vertrouwen: het komt door tonumber en dan door de rest
h.check("een getal als tekst mag", 10, Money.cleanBet("10", saldo))
-- een inzet gaat naar de dichtstbijzijnde cent, net als takeBet() in de webversie
h.check("meer decimalen gaan naar de cent", 11, Money.cleanBet(10.999, saldo))
h.check("naar beneden als dat dichterbij is", 10.99, Money.cleanBet(10.991, saldo))
h.check("een bedrag net boven het saldo mag niet", nil, Money.cleanBet(100.01, saldo))
-- afronden mag je nooit over je saldo tillen
h.check("afronden duwt je niet over je saldo", nil, Money.cleanBet(100.006, saldo))

-- ---------- de cent die drijvende komma opeet ----------
-- 1.2 * 1.5 is in drijvende komma 1.7999999999999998. Zonder de epsilon in floor2 werd
-- dat 1.79 en kwam elke uitbetaling een cent tekort.
h.near("1.2 x 1.5 betaalt 1.80", 1.8, Money.floor2(1.2 * 1.5), 1e-9)
h.near("1.2 x 3 betaalt 3.60", 3.6, Money.floor2(1.2 * 3), 1e-9)
h.near("1.4 x 1.45 betaalt 2.03", 2.03, Money.floor2(1.4 * 1.45), 1e-9)
h.near("1.38 x 1.5 betaalt 2.07", 2.07, Money.floor2(1.38 * 1.5), 1e-9)
-- maar echt naar beneden blijft naar beneden: de epsilon is geen halve cent
h.near("floor2 kapt nog steeds af", 2.09, Money.floor2(2.0999), 1e-9)
h.near("floor2 kapt net onder de cent af", 1.99, Money.floor2(1.999999), 1e-9)

h.report("MONEY")
