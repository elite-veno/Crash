--!strict
-- De tekeningen op de speltegels. In de webversie is elke preview een SVG van 280 bij 160:
-- een vliegtuigje boven gras, een roulettewiel, tegels met een draken-ei. Egale verlopen
-- zagen er naast het origineel uit als een lege doos, dus die scènes worden hier nagetekend
-- met Frames.
--
-- Alles rekent in dezelfde 280x160 die de SVG gebruikt, zodat de coördinaten uit crash.html
-- rechtstreeks over te nemen zijn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)

local Art = {}

local B = 280   -- viewBox breedte
local H = 160   -- viewBox hoogte

export type Doek = {
	vak: Frame,
	rect: (number, number, number, number, Color3, number?, number?) -> Frame,
	rond: (number, number, number, Color3, number?) -> Frame,
	ovaal: (number, number, number, number, Color3, number?) -> Frame,
	lijn: (number, number, number, number, number, Color3, number?) -> Frame,
	tekst: (number, number, string, number, Color3, Enum.Font?) -> TextLabel,
}

function Art.canvas(ouder: Instance, achtergrondVan: Color3, achtergrondTot: Color3, rotatie: number?): Doek
	local vak = Instance.new("Frame")
	vak.Name = "Art"
	vak.Size = UDim2.new(1, 0, 0, Theme.size.cardPreview)
	vak.BackgroundColor3 = achtergrondVan
	vak.BorderSizePixel = 0
	vak.ClipsDescendants = true
	vak.Parent = ouder
	UI.gradient(vak, achtergrondVan, achtergrondTot, rotatie or 90)

	local doek = {} :: any
	doek.vak = vak

	-- Een rechthoek. x en y zijn de linkerbovenhoek, net als in de SVG.
	function doek.rect(x: number, y: number, w: number, h: number, kleur: Color3, radius: number?, doorzicht: number?): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(x / B, y / H)
		f.Size = UDim2.fromScale(w / B, h / H)
		if radius and radius > 0 then UI.corner(f, radius) end
		f.Parent = vak
		return f
	end

	-- Een cirkel met het middelpunt op cx, cy. De maat gaat in pixels, want een cirkel die
	-- met het vak meerekt wordt een ovaal.
	function doek.rond(cx: number, cy: number, r: number, kleur: Color3, doorzicht: number?): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(cx / B, cy / H)
		f.Size = UDim2.fromOffset(r * 2, r * 2)
		UI.corner(f, r)
		f.Parent = vak
		return f
	end

	function doek.ovaal(cx: number, cy: number, rx: number, ry: number, kleur: Color3, doorzicht: number?): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(cx / B, cy / H)
		f.Size = UDim2.fromOffset(rx * 2, ry * 2)
		UI.corner(f, math.min(rx, ry))
		f.Parent = vak
		return f
	end

	-- Een lijn tussen twee punten: een gedraaid balkje op het midden.
	function doek.lijn(x1: number, y1: number, x2: number, y2: number, dikte: number, kleur: Color3, doorzicht: number?): Frame
		local dx, dy = x2 - x1, y2 - y1
		local lengte = math.sqrt(dx * dx + dy * dy)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = kleur
		f.BackgroundTransparency = doorzicht or 0
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale((x1 + x2) / 2 / B, (y1 + y2) / 2 / H)
		f.Size = UDim2.fromOffset(lengte, dikte)
		f.Rotation = math.deg(math.atan2(dy, dx))
		f.Parent = vak
		return f
	end

	function doek.tekst(cx: number, cy: number, tekst: string, maat: number, kleur: Color3, font: Enum.Font?): TextLabel
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(cx / B, cy / H)
		t.Size = UDim2.fromOffset(120, maat + 8)
		t.Text = tekst
		t.TextSize = maat
		t.TextColor3 = kleur
		t.Font = font or Theme.font.uiMed
		t.RichText = false
		t.Parent = vak
		return t
	end

	return doek
end

-- ---------- de negen scènes ----------
-- De coördinaten komen één op één uit de SVG's in crash.html.

local WIT = Color3.fromHex("ffffff")

function Art.crash(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("5fb8ff"), Color3.fromHex("b8e4ff"))
	-- gras
	d.rect(0, 128, 280, 32, Color3.fromHex("5aa030"))
	d.rect(0, 128, 280, 6, Color3.fromHex("7ac050"))
	-- wolken
	d.ovaal(50, 40, 20, 8, WIT, 0.2)
	d.ovaal(200, 30, 25, 10, WIT, 0.15)
	-- de vliegbaan: de kromme uit de SVG in korte stukjes
	local punten = {
		{20, 130}, {50, 124}, {80, 116}, {105, 105}, {128, 92},
		{148, 78}, {168, 64}, {190, 52}, {214, 41}, {240, 30},
	}
	for i = 1, #punten - 1 do
		d.lijn(punten[i][1], punten[i][2], punten[i + 1][1], punten[i + 1][2], 3, WIT, 0.1)
	end
	-- het vliegtuigje
	local romp = d.ovaal(240, 30, 22, 6, Color3.fromHex("e63946"))
	romp.Rotation = -25
	local staart = d.rect(222, 18, 10, 8, Color3.fromHex("c91e2e"), 1)
	staart.Rotation = -25
	d.rond(248, 26, 3, Color3.fromHex("87ceeb"))
end

function Art.roulette(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("2a1010"), Color3.fromHex("0a0505"))
	local goud = Color3.fromHex("cc9900")
	d.rond(140, 80, 60, Color3.fromHex("1a0a0a"))
	local ring = d.rond(140, 80, 60, Color3.fromHex("8a2020"))
	ring.BackgroundTransparency = 1
	UI.stroke(ring, Color3.fromHex("8a2020"), 2)
	local binnen = d.rond(140, 80, 55, goud)
	binnen.BackgroundTransparency = 1
	UI.stroke(binnen, goud, 1)
	d.lijn(140, 25, 140, 135, 1, goud, 0.5)
	d.lijn(85, 80, 195, 80, 1, goud, 0.5)
	d.lijn(101, 41, 179, 119, 1, goud, 0.5)
	d.lijn(179, 41, 101, 119, 1, goud, 0.5)
	local naaf = d.rond(140, 80, 20, Color3.fromHex("3a1010"))
	UI.stroke(naaf, goud, 1.5)
	d.rond(140, 80, 6, goud)
	d.rond(180, 60, 4, WIT)
end

function Art.tower(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("2a0a3a"), Color3.fromHex("0a0510"))
	local paars = Color3.fromHex("8a4ac9")
	local vulling = Color3.fromHex("2a0a4a")
	for i = 0, 3 do
		local rij = d.rect(90, 30 + i * 25, 100, 20, vulling, 2)
		UI.stroke(rij, paars, 1)
	end
	-- de bovenste rij ligt open: twee groene en een rode
	d.rond(110, 40, 6, Theme.color.neon, 0.3)
	d.rond(140, 40, 6, Theme.color.neon, 0.3)
	d.rond(170, 40, 6, Theme.color.red, 0.2)
	for r = 1, 3 do
		for _, x in {110, 140, 170} do
			local c = d.rond(x, 40 + r * 25, 6, vulling)
			UI.stroke(c, paars, 1)
		end
	end
	-- het ei bovenop
	local ei = d.ovaal(140, 14, 10, 7, Color3.fromHex("e0616e"))
	UI.stroke(ei, Color3.fromHex("8a0e1e"), 1)
	d.rond(137, 11, 1.5, Theme.color.gold)
	d.rond(143, 11, 1.5, Theme.color.gold)
end

function Art.mines(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("1a1a2a"), Color3.fromHex("0a0a14"), 135)
	local vulling = Color3.fromHex("2a2a4a")
	local rand = Color3.fromHex("4a4a7a")
	for r = 0, 3 do
		for k = 0, 4 do
			local x, y = 80 + k * 30, 20 + r * 30
			local kleur, doorzicht = vulling, 0
			if r == 1 and k == 1 then kleur, doorzicht = Theme.color.neon, 0.3
			elseif r == 2 and k == 2 then kleur, doorzicht = Theme.color.red, 0.2
			elseif r == 2 and k == 3 then kleur, doorzicht = Theme.color.neon, 0.3
			end
			local t = d.rect(x, y, 24, 24, kleur, 3, doorzicht)
			UI.stroke(t, rand, 1)
		end
	end
	d.tekst(152, 92, "\u{2726}", 14, WIT)
end

function Art.plinko(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("1a0a2a"), Color3.fromHex("0a0518"))
	local pin = Color3.fromHex("8a5ac9")
	for rij = 0, 4 do
		for k = 0, rij do
			local x = 140 - rij * 15 + k * 30
			d.rond(x, 30 + rij * 20, 2, pin)
		end
	end
	local bakken = {
		Color3.fromHex("e0616e"), Theme.color.gold, Theme.color.neon,
		Theme.color.neon, Theme.color.gold, Color3.fromHex("e0616e"),
	}
	for i, kleur in bakken do
		d.rect(70 + (i - 1) * 24, 130, 22, 20, kleur, 0, 0.4)
	end
	d.rond(155, 80, 4, Theme.color.neon)
end

function Art.blackjack(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("0a3a1a"), Color3.fromHex("051a0a"))
	local function kaart(x: number, rang: string, teken: string, kleur: Color3, draai: number)
		local k = d.rect(x, 50, 50, 70, Theme.color.card, 4)
		k.Rotation = draai
		local r = Instance.new("TextLabel")
		r.BackgroundTransparency = 1
		r.Size = UDim2.fromScale(1, 0.55)
		r.Text = rang
		r.TextSize = 20
		r.Font = Theme.font.uiBold
		r.TextColor3 = Color3.fromHex("1a1a1a")
		r.RichText = false
		r.Parent = k
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.5)
		s.Size = UDim2.fromScale(1, 0.45)
		s.Text = teken
		s.TextSize = 14
		s.Font = Theme.font.uiMed
		s.TextColor3 = kleur
		s.RichText = false
		s.Parent = k
		UI.stroke(k, Color3.fromHex("aaaaaa"), 1)
	end
	kaart(80, "A", "\u{2665}", Color3.fromHex("e0616e"), -8)
	kaart(150, "K", "\u{2660}", Color3.fromHex("1a1a1a"), 8)
	d.tekst(140, 140, "BLACKJACK", 12, Theme.color.gold, Theme.font.num)
end

function Art.horse(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("7ec8ff"), Color3.fromHex("b8e4ff"))
	d.rect(0, 88, 280, 72, Color3.fromHex("4a8a2a"))
	for _, y in {105, 125, 145} do
		d.lijn(0, y, 280, y, 1, WIT, 0.5)
	end
	d.rect(238, 88, 4, 70, WIT)
	d.rect(242, 88, 14, 10, Color3.fromHex("e0616e"))
	d.tekst(60, 112, "\u{1F3C7}", 20, WIT)
	d.tekst(120, 132, "\u{1F3C7}", 20, WIT)
	d.tekst(90, 152, "\u{1F3C7}", 20, WIT)
end

function Art.scratch(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("1d2a24"), Color3.fromHex("16181f"))
	local lot = d.rect(52, 26, 176, 110, Theme.color.panel, 8)
	UI.stroke(lot, Theme.color.neon, 2)
	for r = 0, 1 do
		for k = 0, 2 do
			local vakje = d.rect(70 + k * 48, 44 + r * 38, 44, 34, Theme.color.bg, 4)
			UI.stroke(vakje, Theme.color.border, 1)
		end
	end
	for k = 0, 2 do
		d.tekst(92 + k * 48, 61, "\u{1F48E}", 20, WIT)
	end
	for k = 0, 2 do
		d.tekst(92 + k * 48, 99, "?", 17, Theme.color.muted)
	end
end

function Art.wheel(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("12222a"), Color3.fromHex("16181f"))
	local rand = Theme.color.border
	local schijf = d.rond(140, 88, 58, Theme.color.panel)
	schijf.ClipsDescendants = true
	UI.stroke(schijf, rand, 2)

	-- Twee gekleurde parten. Een taartpunt kan Roblox niet tekenen, dus het is een gedraaid
	-- kwart dat door de ronde rand wordt afgesneden -- dat leest hetzelfde.
	local function part(kleur: Color3, randKleur: Color3, draai: number)
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0, 1)
		p.Position = UDim2.fromScale(0.5, 0.5)
		p.Size = UDim2.fromScale(0.5, 0.5)
		p.BackgroundColor3 = kleur
		p.BorderSizePixel = 0
		p.Rotation = draai
		p.Parent = schijf
		UI.stroke(p, randKleur, 1)
	end
	part(Color3.fromHex("3a2f12"), Theme.color.gold, 45)
	part(Color3.fromHex("14301f"), Theme.color.neon, 180)

	for _, hoek in {0, 45, 90, 135} do
		local l = d.lijn(140 - 58, 88, 140 + 58, 88, 1, rand)
		l.Rotation = hoek
	end
	local naaf = d.rond(140, 88, 11, Theme.color.bg)
	UI.stroke(naaf, rand, 1)
	-- het pijltje bovenaan
	local punt = d.rect(133, 24, 14, 14, Theme.color.gold, 2)
	punt.Rotation = 45
	d.tekst(168, 52, "10\u{00D7}", 12, Theme.color.gold, Theme.font.num)
end

-- De twee VIP-tegels. Ze staan alleen op #vipView, want in de lobby zitten 777 en Ride the
-- Bus achter de poort.

function Art.slots(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("2a2112"), Color3.fromHex("16181f"))
	local kast = d.rect(40, 35, 200, 90, Theme.color.bg, 8)
	UI.stroke(kast, Theme.color.gold, 2)
	for k = 0, 2 do
		local venster = d.rect(56 + k * 58, 52, 52, 56, Theme.color.panel, 4)
		UI.stroke(venster, Theme.color.gold, 1)
		-- In de SVG staat de 7 op grondlijn y=92; hier is y het midden van het cijfer.
		local zeven = d.tekst(82 + k * 58, 81, "7", 30, Theme.color.gold, Theme.font.num)
		zeven.TextXAlignment = Enum.TextXAlignment.Center
	end
end

function Art.bus(ouder: Instance)
	local d = Art.canvas(ouder, Color3.fromHex("16222e"), Color3.fromHex("16181f"))

	-- Een kaart met zijn opschrift erin, zodat de tekst met de kaart meedraait -- in de SVG
	-- staat dezelfde rotate() op allebei.
	local function kaart(x: number, tekst: string, inkt: Color3, vulling: Color3, randKleur: Color3, maat: number, draai: number)
		local k = d.rect(x, 44, 52, 72, vulling, 5)
		k.Rotation = draai
		UI.stroke(k, randKleur, 1)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = tekst
		t.TextSize = maat
		t.Font = Theme.font.uiBold
		t.TextColor3 = inkt
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.RichText = false
		t.Parent = k
	end
	kaart(52, "7\u{2665}", Theme.color.red, WIT, Color3.fromHex("aaaaaa"), 22, -9)
	kaart(114, "K\u{2660}", Color3.fromHex("1a1a1a"), WIT, Color3.fromHex("aaaaaa"), 22, 0)
	kaart(176, "?", Theme.color.gold, Theme.color.panel, Theme.color.gold, 26, 9)

	-- De vier beurten onder de kaarten. De letter-spacing van 2 uit de SVG kent Roblox niet;
	-- de spaties om de punten geven ongeveer dezelfde lucht.
	local regel = d.tekst(140, 138, "RED \u{00B7} HIGHER \u{00B7} INSIDE \u{00B7} SUIT", 11, Theme.color.muted, Theme.font.num)
	regel.Size = UDim2.fromOffset(240, 18)
	regel.TextXAlignment = Enum.TextXAlignment.Center
end

Art.BY_ID = {
	crash = Art.crash, roulette = Art.roulette, tower = Art.tower, mines = Art.mines,
	plinko = Art.plinko, blackjack = Art.blackjack, horse = Art.horse,
	scratch = Art.scratch, wheel = Art.wheel, slots = Art.slots, bus = Art.bus,
} :: { [string]: (Instance) -> () }

return Art
