--!strict
-- De kleuren, letters en maten uit de CSS van de webversie, één op één overgenomen. Waar
-- de webversie een getal noemt staat dat getal hier ook; waar hij rgba() gebruikt staat de
-- kleur plus de doorzichtigheid die daarbij hoort, want zo werkt Roblox.
--
-- Eén plek zet de toon: als hier iets verandert, verandert het overal.

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local Theme = {}

-- ---------- :root ----------
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
	black      = hex("000000"),
	white      = hex("ffffff"),
}

-- --neon-glow is rgba(62,207,142,0.28): in Roblox is dat de kleur plus doorzichtigheid.
Theme.glow = { color = hex("3ecf8e"), transparency = 0.72 }

-- De doorzichtigheden die in de CSS als rgba() staan.
Theme.alpha = {
	inputBg    = 0.4,    -- rgba(0,0,0,0.6)
	buttonBg   = 0.5,    -- rgba(0,0,0,0.5)
	hoverBg    = 0.96,   -- rgba(255,255,255,0.04)
	activeNav  = 0.90,   -- rgba(62,207,142,0.10)
	tagNeon    = 0.88,   -- rgba(62,207,142,0.12)
	tagGold    = 0.90,   -- rgba(224,181,85,0.10)
	locked     = 0.65,   -- opacity 0.35
	disabled   = 0.40,   -- opacity 0.6
}

Theme.font = {
	ui     = Enum.Font.Gotham,        -- Inter, gewoon
	uiMed  = Enum.Font.GothamMedium,  -- Inter 600
	uiBold = Enum.Font.GothamBold,    -- Inter 700
	num    = Enum.Font.Code,          -- JetBrains Mono
}

-- ---------- maten ----------
-- De border-radius waarden uit de CSS, per onderdeel.
Theme.radius = {
	chip   = 2,
	button = 3,
	input  = 3,
	panel  = 4,
	card   = 6,
	pill   = 8,
}

Theme.size = {
	railWidth   = 64,    -- nav.sidebar
	railOpen    = 240,   -- nav.sidebar.open
	asideWidth  = 320,   -- .game-view grid-template-columns: 320px 1fr
	viewPad     = 16,    -- .game-view padding
	viewGap     = 16,    -- .game-view gap
	asideGap    = 14,    -- aside.game-aside gap
	panelPad    = 18,    -- .panel padding
	homePadY    = 40,    -- #homeView padding
	homePadX    = 50,
	gap         = 8,
	cardMin     = 280,   -- .games-grid minmax(280px, 1fr)
	cardGap     = 20,
	cardPreview = 160,   -- .game-card-preview height
	navIcon     = 24,    -- .nav-icon
	navPadY     = 14,    -- .nav-item padding
	navPadX     = 20,
	navGap      = 16,
	pad         = 12,
}

-- De lettergroottes uit de CSS, met de naam van waar ze vandaan komen.
Theme.text = {
	badge    = 8,    -- .nav-badge
	tiny     = 11,   -- .game-card-desc, .odds-note, .chip, .btn-secondary
	small    = 11,   -- .panel-title, .balance-label, .nav-section-label
	body     = 12,   -- .nav-label, .home-subtitle
	label    = 13,
	toast    = 13,   -- .toast
	button   = 15,   -- .btn-primary
	input    = 16,   -- input[type=number]
	card     = 18,   -- .game-card-title
	title    = 22,   -- .crash-header-title, .section-heading h2
	big      = 22,
	balance  = 30,   -- .balance-amount
	balanceL = 36,   -- .home-balance-card .balance-value
	huge     = 36,
	hero     = 64,   -- .home-title
	giant    = 64,
}

return Theme
