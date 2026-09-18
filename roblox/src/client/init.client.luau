--!strict
-- De schil: de zijbalk links, het scherm rechts, en de routing ertussen. Zelfde indeling als
-- de webversie: een balk van 64 pixels die naar 240 uitklapt, met een pictogram per scherm
-- en het label ernaast zodra hij open staat.
--
-- Wat er bewust NIET is: een vaste bovenbalk met je saldo. In de webversie staat het saldo
-- in het linkerpaneel van elk spel, en op de lobby in de grote kaart. Dat is hier ook zo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Season)
local Home = require(script.Views.Home)
local ProfileView = require(script.Views.Profile)
local AchievementsView = require(script.Views.Achievements)
local VipView = require(script.Views.Vip)
local FriendsView = require(script.Views.Friends)
local Common = require(script.Views.Common)
local Icons = require(script.Icons)

-- De speelschermen. Elk bouwt zichzelf in het vak dat het krijgt; ze weten niets van
-- elkaar en praten alleen met de server.
local SPELLEN: { [string]: { build: (Instance) -> () } } = {
	crash = require(script.Views.Crash),
	roulette = require(script.Views.Roulette),
	tower = require(script.Views.Tower),
	mines = require(script.Views.Mines),
	plinko = require(script.Views.Plinko),
	blackjack = require(script.Views.Blackjack),
	scratch = require(script.Views.Scratch),
	wheel = require(script.Views.Wheel),
	slots = require(script.Views.Slots),
	horse = require(script.Views.Horse),
	bus = require(script.Views.Bus),
}

local speler = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NeonCasino"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = speler:WaitForChild("PlayerGui")

-- body: de donkere achtergrond.
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Theme.color.bg
root.BorderSizePixel = 0
root.Parent = gui

-- De twee gloedvlekken die `body` over die achtergrond legt:
--   radial-gradient(ellipse at top left,     #16202a 0%, transparent 55%)
--   radial-gradient(ellipse at bottom right, #131b23 0%, transparent 55%)
--
-- Roblox kent geen radiaal verloop, alleen een lineair. Een verloop dat vanuit de hoek
-- schuin wegvalt komt er dicht bij: in de hoek precies de goede kleur, en op 55% van de
-- diagonaal weg. De vorm van de uitdoving is een lijn in plaats van een ellips, maar dat
-- is over een verschil van een paar tinten niet te zien -- en zonder deze twee is de hele
-- achtergrond overal even donker, terwijl hij op de site naar de hoeken toe oplicht.
local function gloed(kleur: Color3, hoek: number)
    local f = Instance.new("Frame")
    f.Name = "Glow"
    f.Size = UDim2.fromScale(1, 1)
    f.BackgroundColor3 = kleur
    f.BorderSizePixel = 0
    f.ZIndex = 0
    f.Parent = root
    local g = Instance.new("UIGradient")
    g.Rotation = hoek
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.55, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    g.Parent = f
end

gloed(Color3.fromHex("16202a"), 45)    -- vanuit linksboven
gloed(Color3.fromHex("131b23"), 225)   -- vanuit rechtsonder

-- ---------- de schermen ----------
-- `groep` is nil voor een scherm dat wel bestaat maar niet in de balk staat: de twee
-- VIP-spellen zijn alleen vanaf de zone zelf te bereiken, net als in de markup.
type Scherm = { id: string, label: string, icon: string, groep: string?, badge: string? }

local SCHERMEN: { Scherm } = {
	{ id = "home",         label = "HOME",          icon = "home", groep = "PLAY" },
	{ id = "crash",        label = "CRASH",         icon = "crash", groep = "PLAY", badge = "LIVE" },
	{ id = "roulette",     label = "ROULETTE",      icon = "roulette", groep = "PLAY", badge = "LIVE" },
	{ id = "tower",        label = "DRAGON TOWER",  icon = "tower", groep = "PLAY", badge = "LIVE" },
	{ id = "mines",        label = "MINES",         icon = "mines", groep = "PLAY", badge = "LIVE" },
	{ id = "plinko",       label = "PLINKO",        icon = "plinko", groep = "PLAY", badge = "LIVE" },
	{ id = "blackjack",    label = "BLACKJACK",     icon = "blackjack", groep = "PLAY", badge = "LIVE" },
	{ id = "scratch",      label = "SCRATCH CARDS", icon = "scratch", groep = "PLAY", badge = "LIVE" },
	{ id = "wheel",        label = "WHEEL",         icon = "wheel", groep = "PLAY", badge = "LIVE" },
	{ id = "horse",        label = "HORSE RACE",    icon = "horse", groep = "PLAY", badge = "LIVE" },
	-- 777 en Ride the Bus staan bewust NIET in de balk: geen groep, dus geen regel. In de
	-- markup heeft de zijbalk twee kopjes, PLAY en ACCOUNT, en veertien items; de twee
	-- VIP-spellen hebben er geen eigen regel en zijn alleen vanaf de zone zelf te bereiken.
	-- Daarom blijft VIP ZONE oplichten zolang je er een speelt. De schermen worden hier wel
	-- gebouwd -- ze moeten immers te spelen zijn.
	{ id = "slots",        label = "777",           icon = "slots" },
	{ id = "bus",          label = "RIDE THE BUS",  icon = "bus" },
	{ id = "profile",      label = "PROFILE",       icon = "profile", groep = "ACCOUNT" },
	{ id = "vip",          label = "VIP ZONE",      icon = "vip", groep = "ACCOUNT", badge = "\u{1F512}" },
	-- De telling staat in de markup op `hidden` met een 0 erin, en licht pas op als er een
	-- verzoek wacht. Hier wacht er nooit een: vriendschappen zijn van Roblox, dus je stuurt
	-- en accepteert ze daar. De badge zit er wel, op nul, precies zoals hij daar staat.
	{ id = "friends",      label = "FRIENDS",       icon = "friends", groep = "ACCOUNT", badge = "0" },
	{ id = "achievements", label = "ACHIEVEMENTS",  icon = "achievements", groep = "ACCOUNT" },
}

-- De twee VIP-spellen zijn alleen bereikbaar zolang de pas geldt; anders kom je uit bij de
-- zone zelf. Precies zoals VIP_ROUTES in de webversie.
local VIP_ROUTES = { slots = true, bus = true }
local vipOpen = false

-- ---------- het vlak rechts van de balk ----------
local inhoud = Instance.new("Frame")
inhoud.Name = "Content"
inhoud.Position = UDim2.new(0, Theme.size.railWidth, 0, 0)
inhoud.Size = UDim2.new(1, -Theme.size.railWidth, 1, 0)
inhoud.BackgroundTransparency = 1
inhoud.Parent = root

local views: { [string]: Frame } = {}
local huidige = "home"

local function view(id: string): Frame
	local v = views[id]
	if v then return v end
	local f = Instance.new("Frame")
	f.Name = id .. "View"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = inhoud
	views[id] = f
	return f
end

-- ---------- de zijbalk ----------
local rail = Instance.new("Frame")
rail.Name = "Sidebar"
rail.Size = UDim2.new(0, Theme.size.railWidth, 1, 0)
rail.BackgroundColor3 = Theme.color.panel
rail.BorderSizePixel = 0
rail.ClipsDescendants = true
rail.ZIndex = 10
rail.Parent = root
UI.gradient(rail, Theme.color.panel, Theme.color.panelLight)

-- De rand rechts, met de neongloed erin (nav.sidebar::after).
local railRand = Instance.new("Frame")
railRand.Name = "Edge"
railRand.AnchorPoint = Vector2.new(1, 0)
railRand.Position = UDim2.fromScale(1, 0)
railRand.Size = UDim2.new(0, 1, 1, 0)
railRand.BackgroundColor3 = Theme.glow.color
railRand.BorderSizePixel = 0
railRand.ZIndex = 12
railRand.Parent = rail
local randVerloop = Instance.new("UIGradient")
randVerloop.Rotation = 90
randVerloop.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.6),
	NumberSequenceKeypoint.new(0.7, 0.6),
	NumberSequenceKeypoint.new(1, 1),
})
randVerloop.Parent = railRand

-- .sidebar-toggle: het hamburgertje en de merknaam.
local schakelaar = Instance.new("TextButton")
schakelaar.Name = "Toggle"
schakelaar.Text = ""
schakelaar.Size = UDim2.new(1, 0, 0, 64)
schakelaar.BackgroundTransparency = 1
schakelaar.BorderSizePixel = 0
schakelaar.AutoButtonColor = false
schakelaar.ZIndex = 11
schakelaar.Parent = rail

local streepjes = Instance.new("Frame")
streepjes.Size = UDim2.fromOffset(24, 18)
streepjes.Position = UDim2.new(0, Theme.size.navPadX, 0.5, -9)
streepjes.BackgroundTransparency = 1
streepjes.ZIndex = 11
streepjes.Parent = schakelaar
local streepLijst = UI.list(streepjes, 6)
streepLijst.VerticalAlignment = Enum.VerticalAlignment.Center
for i = 1, 3 do
	local l = Instance.new("Frame")
	l.Size = UDim2.new(1, 0, 0, 2)
	l.BackgroundColor3 = Theme.color.neon
	l.BorderSizePixel = 0
	l.LayoutOrder = i
	l.ZIndex = 11
	l.Parent = streepjes
end

local merk = UI.label(schakelaar, "NEON CASINO", {
	size = Theme.text.body + 2, color = Theme.color.neon, font = Theme.font.uiMed,
})
merk.Position = UDim2.new(0, 58, 0, 0)
merk.Size = UDim2.new(1, -66, 1, 0)
merk.TextTransparency = 1
merk.ZIndex = 11

local railOnder = Instance.new("Frame")
railOnder.Size = UDim2.new(1, 0, 0, 1)
railOnder.Position = UDim2.new(0, 0, 0, 64)
railOnder.BackgroundColor3 = Theme.color.border
railOnder.BorderSizePixel = 0
railOnder.ZIndex = 11
railOnder.Parent = rail

local railLijst = Instance.new("ScrollingFrame")
railLijst.Size = UDim2.new(1, 0, 1, -65)
railLijst.Position = UDim2.new(0, 0, 0, 65)
railLijst.BackgroundTransparency = 1
railLijst.BorderSizePixel = 0
railLijst.ScrollBarThickness = 0
railLijst.CanvasSize = UDim2.new()
railLijst.AutomaticCanvasSize = Enum.AutomaticSize.Y
railLijst.ZIndex = 11
railLijst.Parent = rail
UI.list(railLijst, 0)

local navKnoppen: { [string]: TextButton } = {}
local hoverOp: string? = nil
local verfBalk: () -> ()
local navLabels: { TextLabel } = {}
local navBadges: { TextLabel } = {}
-- Twee badges veranderen tijdens het spelen: het slotje bij VIP ZONE wordt OPEN zodra de
-- pas geldt, en FRIENDS telt hoeveel verzoeken er op je wachten.
local navBadgePerId: { [string]: TextLabel } = {}
local groepLabels: { TextLabel } = {}
local navigate: (string) -> ()

local function groepLabel(tekst: string, volgorde: number)
	local t = UI.label(railLijst, tekst, {
		size = Theme.text.small, color = Theme.color.muted, name = "Section",
	})
	t.Size = UDim2.new(1, -Theme.size.navPadX, 0, 36)
	t.Position = UDim2.new(0, Theme.size.navPadX + 2, 0, 0)
	t.LayoutOrder = volgorde
	t.TextTransparency = 1
	t.TextYAlignment = Enum.TextYAlignment.Bottom
	t.ZIndex = 11
	table.insert(groepLabels, t)
end

local function navItem(item: Scherm, volgorde: number)
	local b = Instance.new("TextButton")
	b.Name = item.id
	b.Text = ""
	-- `.nav-item { padding: 14px 20px }` om een `.nav-icon` van 24 bij 24: 24 + 14 + 14.
	-- Het icoon is hoger dan de regel tekst ernaast, dus dat bepaalt de hoogte.
	b.Size = UDim2.new(1, 0, 0, Theme.size.navIcon + Theme.size.navPadY * 2)
	b.BackgroundColor3 = Theme.color.neon
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.LayoutOrder = volgorde
	b.ZIndex = 11
	b.Parent = railLijst

	-- .nav-item.active: een streepje van 2px links in neon.
	local streep = Instance.new("Frame")
	streep.Name = "Marker"
	streep.Size = UDim2.new(0, 2, 1, 0)
	streep.BackgroundColor3 = Theme.color.neon
	streep.BorderSizePixel = 0
	streep.BackgroundTransparency = 1
	streep.ZIndex = 12
	streep.Parent = b

	-- .nav-icon: een lijntekening van 24 bij 24, geen letterteken.
	local icoonVak = Instance.new("Frame")
	icoonVak.Name = "IconBox"
	icoonVak.AnchorPoint = Vector2.new(0, 0.5)
	icoonVak.Position = UDim2.new(0, Theme.size.navPadX, 0.5, 0)
	icoonVak.Size = UDim2.fromOffset(Theme.size.navIcon, Theme.size.navIcon)
	icoonVak.BackgroundTransparency = 1
	icoonVak.ZIndex = 11
	icoonVak.Parent = b
	local icoon = Icons.build(icoonVak, item.icon, Theme.size.navIcon)
	icoon.ZIndex = 11
	for _, k in icoon:GetDescendants() do
		if k:IsA("GuiObject") then k.ZIndex = 11 end
	end

	local label = UI.label(b, item.label, {
		size = Theme.text.body, color = Theme.color.text, name = "NavLabel",
	})
	label.Position = UDim2.new(0, Theme.size.navPadX + Theme.size.navIcon + Theme.size.navGap, 0, 0)
	label.Size = UDim2.new(1, -150, 1, 0)
	label.TextTransparency = 1
	label.ZIndex = 11
	table.insert(navLabels, label)

	if item.badge then
		-- LIVE is neon; het slotje bij de zone en de telling bij FRIENDS zijn goud, zoals
		-- de inline stijlen in de markup ze zetten.
		local kleur = if item.badge == "LIVE" then Theme.color.neon else Theme.color.gold
		local badge = UI.tag(b, item.badge, kleur)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -16, 0.5, 0)
		badge.TextSize = Theme.text.badge + 1
		badge.Size = UDim2.fromOffset(0, 16)
		badge.TextTransparency = 1
		badge.BackgroundTransparency = 1
		badge.ZIndex = 11
		local s = badge:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = 1 end
		-- `hidden` in de markup: een telling van nul hoort er niet te staan.
		if item.id == "friends" then badge.Visible = false end
		table.insert(navBadges, badge)
		navBadgePerId[item.id] = badge
	end

	b.Activated:Connect(function()
		navigate(item.id)
	end)
	b.MouseEnter:Connect(function()
		hoverOp = item.id
		verfBalk()
	end)
	b.MouseLeave:Connect(function()
		if hoverOp == item.id then hoverOp = nil end
		verfBalk()
	end)
	navKnoppen[item.id] = b
end

do
	local volgorde = 0
	local vorigeGroep: string? = nil
	for _, item in SCHERMEN do
		local groep = item.groep
		if not groep then continue end
		if groep ~= vorigeGroep then
			volgorde += 1
			groepLabel(groep, volgorde)
			vorigeGroep = groep
		end
		volgorde += 1
		navItem(item, volgorde)
	end
end

-- .sidebar-footer
local voet = UI.label(rail, "v3.0 \u{00B7} FAIR ODDS", {
	size = Theme.text.small, color = Theme.color.muted,
})
voet.AnchorPoint = Vector2.new(0, 1)
voet.Position = UDim2.new(0, Theme.size.navPadX, 1, -16)
voet.Size = UDim2.new(1, -Theme.size.navPadX, 0, 18)
voet.TextTransparency = 1
voet.ZIndex = 11

-- Open- en dichtklappen, met dezelfde beweging als de CSS-transition.
local open = false
local INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function zetBalk(nu: boolean)
	open = nu
	local breed = if nu then Theme.size.railOpen else Theme.size.railWidth
	TweenService:Create(rail, INFO, { Size = UDim2.new(0, breed, 1, 0) }):Play()
	-- In de webversie is dit een flexrij: de balk wordt breder en het scherm ernaast
	-- smaller. Hij gaat er dus niet overheen liggen.
	TweenService:Create(inhoud, INFO, {
		Position = UDim2.new(0, breed, 0, 0),
		Size = UDim2.new(1, -breed, 1, 0),
	}):Play()
	local doorzichtig = if nu then 0 else 1
	for _, l in navLabels do
		TweenService:Create(l, INFO, { TextTransparency = doorzichtig }):Play()
	end
	-- Na het uitklappen opnieuw kleuren, zodat een gesloten VIP-spel gedimd blijft.
	task.delay(0.32, function()
		if open == nu then verfBalk() end
	end)
	for _, l in groepLabels do
		TweenService:Create(l, INFO, { TextTransparency = doorzichtig }):Play()
	end
	for _, badge in navBadges do
		TweenService:Create(badge, INFO, {
			TextTransparency = doorzichtig,
			BackgroundTransparency = if nu then Theme.alpha.tagNeon else 1,
		}):Play()
		local s = badge:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = if nu then 0.6 else 1 end
	end
	TweenService:Create(merk, INFO, { TextTransparency = doorzichtig }):Play()
	TweenService:Create(voet, INFO, { TextTransparency = doorzichtig }):Play()
end

schakelaar.Activated:Connect(function()
	zetBalk(not open)
end)

-- ---------- meldingen ----------
local toasts = Instance.new("Frame")
toasts.Name = "Toasts"
toasts.AnchorPoint = Vector2.new(1, 0)
toasts.Position = UDim2.new(1, -20, 0, 20)   -- .toast-host { padding: 20px }
toasts.Size = UDim2.new(0, 360, 0, 0)
toasts.AutomaticSize = Enum.AutomaticSize.Y
toasts.BackgroundTransparency = 1
toasts.ZIndex = 50
toasts.Parent = inhoud
local toastLijst = UI.list(toasts, 8)   -- .toast-host { gap: 8px }
toastLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right

-- ---------- vensters ----------
-- `.modal` hangt over alles heen, ook over de navigatiebalk. Het noodfonds gebruikt het.
local vensters = Instance.new("Frame")
vensters.Name = "Modals"
vensters.Size = UDim2.fromScale(1, 1)
vensters.BackgroundTransparency = 1
vensters.ZIndex = 100
vensters.Parent = root
Common.setModalHost(vensters)

-- ---------- routing ----------
-- De balk verven: welk item actief is, welke gedimd, en waar de muis hangt. Eén functie,
-- want hover en actief door elkaar heen zetten is precies hoe een highlight verdwijnt.
function verfBalk()
	for naam, b in navKnoppen do
		-- Een VIP-spel heeft geen eigen menu-item; dan blijft de zone oplichten. Precies
		-- een item actief, net als in de webversie: bij de zone zelf is dat de zone.
		local navRoute = if VIP_ROUTES[huidige] then "vip" else huidige
		local aan = naam == navRoute
		local zweeft = hoverOp == naam and not aan
		local streep = b:FindFirstChild("Marker") :: Frame?
		local icoonVak = b:FindFirstChild("IconBox") :: Frame?
		local label = b:FindFirstChild("NavLabel") :: TextLabel?

		if aan then
			-- .nav-item.active: rgba(62,207,142,0.10)
			b.BackgroundColor3 = Theme.color.neon
			b.BackgroundTransparency = Theme.alpha.activeNav
		elseif zweeft then
			-- .nav-item:hover: rgba(255,255,255,0.04)
			b.BackgroundColor3 = Theme.color.white
			b.BackgroundTransparency = Theme.alpha.hoverBg
		else
			b.BackgroundTransparency = 1
		end

		if streep then streep.BackgroundTransparency = if aan then 0 else 1 end

		local kleur = if aan then Theme.color.neon else Theme.color.text
		if icoonVak then
			local ic = icoonVak:FindFirstChild("Icon") :: Frame?
			if ic then Icons.tint(ic, kleur, 0) end
		end
		if label then
			-- `.nav-item.vip-open .nav-label`: zodra de pas geldt wordt de naam van de zone
			-- goud, ook als je ergens anders staat.
			label.TextColor3 = if naam == "vip" and vipOpen then Theme.color.gold else kleur
			if open then label.TextTransparency = 0 end
		end
	end
end

function navigate(id: string)
	-- Een rit die al loopt speel je uit, ook als de pas net is afgelopen. Zou de schil je
	-- er middenin uit sturen, dan blijft die ronde op de server openstaan met je inzet
	-- erin: je kunt er niet meer bij en je kunt ook niets anders beginnen. De webversie
	-- maakt dezelfde uitzondering (`!(route === 'bus' && BU.active)` in navigate).
	if VIP_ROUTES[id] and not vipOpen and not Common.rideOpen(id) then
		id = "vip"
	end
	for naam, v in views do
		v.Visible = naam == id
	end
	huidige = id
	verfBalk()
	-- Op een smal scherm klapt de balk weer dicht, net als in de webversie.
	if root.AbsoluteSize.X <= 900 and open then
		zetBalk(false)
	end
end

Common.setNavigate(navigate)
Common.setToaster(function(tekst: string, soort: UI.ToastKind?)
	UI.toast(toasts, tekst, soort)
end)

-- ---------- de schermen vullen ----------
local zetSaldoHome: ((number) -> ())? = nil
local zetProfiel: ((any) -> ())? = nil
local zetPrestaties: ((any) -> ())? = nil
local zetVip: ((any) -> ())? = nil

for _, item in SCHERMEN do
	local v = view(item.id)
	-- #homeView heeft een ruime marge; een speelscherm heeft padding 16, zoals .game-view.
	local marge = if item.id == "home" then Theme.size.homePadY else Theme.size.viewPad
	local vak = Instance.new("Frame")
	vak.Size = UDim2.new(1, -marge * 2, 1, -marge * 2)
	vak.Position = UDim2.fromOffset(marge, marge)
	vak.BackgroundTransparency = 1
	vak.Parent = v

	local spel = SPELLEN[item.id]
	if item.id == "home" then
		zetSaldoHome = Home.build(vak, navigate)
	elseif item.id == "profile" then
		zetProfiel = ProfileView.build(vak)
	elseif item.id == "achievements" then
		zetPrestaties = AchievementsView.build(vak)
	elseif item.id == "vip" then
		zetVip = VipView.build(vak, navigate)
	elseif item.id == "friends" then
		FriendsView.build(vak)
	elseif spel then
		spel.build(vak)
	end
end

navigate("home")

-- ---------- wat de server stuurt ----------
local function toon(p: any)
	if typeof(p) ~= "table" then return end
	Common.setProfile(p)
	local b = tonumber(p.balance)
	if b then
		Common.setBalance(b)
		local zet = zetSaldoHome
		if zet then zet(b) end
	end
	local prof = zetProfiel
	if prof then prof(p) end
	local pres = zetPrestaties
	if pres then pres(p) end
	local vip = zetVip
	if vip then vip(p) end

	local was = vipOpen
	vipOpen = Season.vipActive(tonumber(p.vipSeason))
	-- `.nav-item.vip-open`: het slotje wordt OPEN en de naam wordt goud.
	local vipBadge = navBadgePerId["vip"]
	if vipBadge then
		vipBadge.Text = if vipOpen then "OPEN" else "\u{1F512}"
	end
	if was ~= vipOpen then
		verfBalk()
		navigate(huidige)
	end
end

-- frBadge(): hoeveel vriendschapsverzoeken er op je wachten. Nul betekent geen badge.
Common.setFriendCounter(function(n: number)
	local badge = navBadgePerId["friends"]
	if not badge then return end
	badge.Text = tostring(n)
	badge.Visible = n > 0
end)

task.spawn(function()
	Net.ev("Profile").OnClientEvent:Connect(toon)

	local toast = Net.ev("Toast")
	toast.OnClientEvent:Connect(function(tekst: any, soort: any)
		UI.toast(toasts, tostring(tekst), soort)
	end)

	local ok, res = pcall(function()
		return Net.fn("GetProfile"):InvokeServer()
	end)
	if ok then toon(res) end
end)

return nil
