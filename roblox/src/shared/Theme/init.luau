--!strict
-- De kleuren, letters en maten uit de CSS van de webversie, één op één.
-- Alles wat in de CSS een variabele was staat hier, zodat de Roblox-versie er hetzelfde
-- uitziet en één plek de toon zet.

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local Theme = {}

Theme.color = {
	bg         = hex("0e1116"),
	panel      = hex("151a21"),
	panelLight = hex("1a212a"),
	border     = hex("2a323d"),
	neon       = hex("3ecf8e"),
	neonDim    = hex("2d9e6d"),
	gold       = hex("e0b555"),
	green      = hex("3ecf8e"),
	red        = hex("e0616e"),
	text       = hex("e7ebf1"),
	muted      = hex("8d97a6"),
	-- achtergronden van de speelvelden, zoals in de CSS
	felt       = hex("2f5a1a"),
	feltLight  = hex("579a2f"),
	feltDark   = hex("4f8f2a"),
	sky        = hex("5fb8ff"),
	card       = hex("f7f9fc"),
}

-- De neon-gloed is in de CSS rgba(62,207,142,0.28); in Roblox is dat kleur + transparantie.
Theme.glow = { color = hex("3ecf8e"), transparency = 0.72 }

Theme.font = {
	ui  = Enum.Font.GothamMedium,
	uiBold = Enum.Font.GothamBold,
	num = Enum.Font.Code,      -- staat het dichtst bij JetBrains Mono
}

-- De maten die in de CSS het vaakst voorkomen.
Theme.size = {
	radiusSmall = 2,
	radius      = 3,
	radiusPanel = 4,
	radiusBig   = 8,
	gap         = 8,
	pad         = 12,
	panelPad    = 14,
	railWidth   = 64,      -- de smalle zijbalk
	navWidth    = 240,     -- de uitgeklapte zijbalk
}

Theme.text = {
	tiny   = 10,
	small  = 11,
	body   = 12,
	label  = 13,
	title  = 18,
	big    = 22,
	huge   = 40,
	giant  = 64,
}

-- Een halfdoorzichtige variant, zoals rgba(0,0,0,0.5) in de CSS.
function Theme.alpha(c: Color3, a: number): (Color3, number)
	return c, 1 - a
end

return Theme
