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
	disabled   = 0.40,   -- .btn-primary:disabled opacity 0.6
	disabledSec = 0.65,  -- .btn-secondary:disabled opacity 0.35 -- veel doffer dan een primaire
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
	-- `.payout-line { font-size: 11px; padding: 6px 0; border-bottom: 1px solid }`: een
	-- regelvak van 14, zes lucht boven en onder, plus het haarlijntje eronder. Zeven
	-- schermen tekenen zo'n regel, dus het getal staat hier en niet zeven keer los.
	payoutRow   = 27,
	-- `.board { padding: 22px; gap: 18px }`: het speelveld rechts is ruimer dan een gewoon
	-- paneel, dat 18 padding heeft. Plinko en de paardenrace zetten hem in de markup zelf
	-- op 14 terug.
	boardPad    = 22,
	boardGap    = 18,
	boardPadSm  = 14,
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

-- ---------- regelvakken ----------
-- Hoe hoog één regel tekst is. De CSS zet nergens een line-height op deze labels, dus de
-- browser kiest `normal`: niet de lettergrootte maal een vast getal, maar wat het font zelf
-- opgeeft -- en dat verschilt per font en springt onregelmatig (17px Inter is even hoog als
-- 16px). Roblox heeft geen `normal`, dus zou je hier moeten gokken. Deze twee tabellen zijn
-- daarom in de browser opgemeten, op de pagina zelf, voor elke maat die de port gebruikt:
-- links de lettergrootte, rechts de hoogte van het regelvak in pixels.
--
-- Zonder dit staat elk label een pixel of drie te hoog, en omdat schermen tientallen labels
-- onder elkaar zetten, telt dat op tot tientallen pixels onderaan de bladzijde.
local REGEL_UI: { [number]: number } = {
	[8] = 10, [9] = 11, [10] = 12, [11] = 14, [12] = 15, [13] = 16, [14] = 17, [15] = 19, [16] = 20, [17] = 20,
	[18] = 21, [19] = 23, [20] = 24, [21] = 25, [22] = 26, [23] = 28, [24] = 29, [25] = 30, [26] = 31, [27] = 33,
	[28] = 34, [29] = 35, [30] = 36, [31] = 37, [32] = 39, [33] = 40, [34] = 41, [35] = 42, [36] = 44, [37] = 45,
	[38] = 46, [39] = 47, [40] = 49, [41] = 50, [42] = 51, [43] = 52, [44] = 54, [45] = 55, [46] = 56, [47] = 57,
	[48] = 59, [49] = 59, [50] = 60, [51] = 61, [52] = 63, [53] = 64, [54] = 65, [55] = 66, [56] = 68, [57] = 69,
	[58] = 70, [59] = 71, [60] = 72, [61] = 74, [62] = 75, [63] = 76, [64] = 77, [65] = 79, [66] = 80, [67] = 81,
	[68] = 82, [69] = 84, [70] = 85,
}

local REGEL_NUM: { [number]: number } = {
	[8] = 10, [9] = 12, [10] = 13, [11] = 14, [12] = 16, [13] = 17, [14] = 18, [15] = 20, [16] = 21, [17] = 22,
	[18] = 23, [19] = 25, [20] = 26, [21] = 27, [22] = 29, [23] = 30, [24] = 31, [25] = 34, [26] = 35, [27] = 36,
	[28] = 37, [29] = 39, [30] = 40, [31] = 41, [32] = 43, [33] = 44, [34] = 45, [35] = 47, [36] = 48, [37] = 49,
	[38] = 50, [39] = 52, [40] = 53, [41] = 54, [42] = 56, [43] = 57, [44] = 58, [45] = 60, [46] = 61, [47] = 62,
	[48] = 63, [49] = 65, [50] = 66, [51] = 67, [52] = 69, [53] = 70, [54] = 71, [55] = 73, [56] = 74, [57] = 75,
	[58] = 76, [59] = 78, [60] = 79, [61] = 80, [62] = 82, [63] = 83, [64] = 84, [65] = 86, [66] = 87, [67] = 88,
	[68] = 89, [69] = 91, [70] = 92,
}

-- De hoogte van één regel bij deze lettergrootte en dit font. Buiten de opgemeten maten
-- schaalt hij door met de verhouding die de tabel laat zien.
function Theme.lineBox(maat: number, font: Enum.Font?): number
	local mono = font == Theme.font.num
	local tabel = if mono then REGEL_NUM else REGEL_UI
	local afgerond = math.floor(maat + 0.5)
	local gevonden = tabel[afgerond]
	if gevonden then return gevonden end
	return math.floor(maat * (if mono then 1.325 else 1.215) + 0.5)
end

return Theme
