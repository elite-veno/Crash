--!strict
-- SHA-256, met de hand in Luau. Roblox heeft geen ingebouwde hashfunctie en de webversie
-- rekent hem in Postgres uit (`encode(sha256(...), 'hex')`), dus hier moet hij zelf.
--
-- Waar hij voor is: eerlijk spel bewijzen. Voordat een crashronde begint publiceert de
-- server sha256("commit:" .. zaad). Na afloop geeft hij het zaad vrij. Iedereen kan dan
-- narekenen dat het zaad bij de belofte hoort en dat het crashpunt eruit volgt -- de
-- server kon het dus niet achteraf aanpassen.
local Sha256 = {}

local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local START = {
	0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
	0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

local band, bxor, bnot = bit32.band, bit32.bxor, bit32.bnot
local rrot, rshift, lshift = bit32.rrotate, bit32.rshift, bit32.lshift

-- De boodschap aanvullen: een 1-bit, dan nullen, dan de lengte in bits als 64-bits getal.
local function vullen(bericht: string): string
	local lengte = #bericht
	local bits = lengte * 8
	local staart = "\128"
	local nullen = (56 - (lengte + 1) % 64) % 64
	staart ..= string.rep("\0", nullen)
	-- De bovenste 32 bits zijn nul zolang het bericht kleiner is dan 512 MB; dat is het
	-- hier altijd (een zaad is een paar tientallen tekens).
	staart ..= string.pack(">I4>I4", math.floor(bits / 4294967296), bits % 4294967296)
	return bericht .. staart
end

function Sha256.hash(bericht: string): string
	local data = vullen(bericht)
	local h = table.clone(START)
	local w = table.create(64, 0)

	for blok = 1, #data, 64 do
		for i = 1, 16 do
			w[i] = (string.unpack(">I4", data, blok + (i - 1) * 4))
		end
		for i = 17, 64 do
			local a, b = w[i - 15], w[i - 2]
			local s0 = bxor(rrot(a, 7), rrot(a, 18), rshift(a, 3))
			local s1 = bxor(rrot(b, 17), rrot(b, 19), rshift(b, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
		end

		local a, b, c, d = h[1], h[2], h[3], h[4]
		local e, f, g, hh = h[5], h[6], h[7], h[8]

		for i = 1, 64 do
			local S1 = bxor(rrot(e, 6), rrot(e, 11), rrot(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (hh + S1 + ch + K[i] + w[i]) % 4294967296
			local S0 = bxor(rrot(a, 2), rrot(a, 13), rrot(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local t2 = (S0 + maj) % 4294967296

			hh = g
			g = f
			f = e
			e = (d + t1) % 4294967296
			d = c
			c = b
			b = a
			a = (t1 + t2) % 4294967296
		end

		local deel = {a, b, c, d, e, f, g, hh}
		for i = 1, 8 do
			h[i] = (h[i] + deel[i]) % 4294967296
		end
	end

	local stukken = table.create(8, "")
	for i = 1, 8 do
		stukken[i] = string.format("%08x", h[i])
	end
	return table.concat(stukken)
end

-- Wat de webversie publiceert voordat een ronde begint.
function Sha256.commit(zaad: string): string
	return Sha256.hash("commit:" .. zaad)
end

-- De eerste dertien hexcijfers als getal tussen 0 en 1 -- dezelfde greep als de webversie
-- gebruikt om een zaad in een crashpunt om te zetten.
function Sha256.unit(hex: string): number
	local stuk = string.sub(hex, 1, 13)
	return (tonumber(stuk, 16) :: number) / 2 ^ 52
end

-- Geen geheim, maar wel onvoorspelbaar genoeg voor een zaad: tijd, een teller en de
-- toevalsgenerator door elkaar.
local teller = 0
function Sha256.seed(): string
	teller += 1
	return string.format("%d-%d-%d-%d", os.time(), teller,
		math.random(0, 2 ^ 31 - 1), math.random(0, 2 ^ 31 - 1))
end

local _ = lshift   -- bit32.lshift blijft hier staan voor toekomstige varianten
return Sha256
