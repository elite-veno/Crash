--!strict
-- De schil: de zijbalk links, het scherm rechts, en de routing ertussen. Hetzelfde
-- indelingsprincipe als de webversie: een smalle balk met pictogrammen die uitklapt, en
-- per spel een scherm dat je erin schuift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Net = require(ReplicatedStorage.Shared.Net)
local Money = require(ReplicatedStorage.Shared.Money)
local Home = require(script.Views.Home)
local Common = require(script.Views.Common)

-- De speelschermen. Elk bouwt zichzelf in het vak dat het krijgt; ze weten niets van
-- elkaar en praten alleen met de server.
local SPELLEN: { [string]: { build: (Instance) -> () } } = {
	roulette = require(script.Views.Roulette),
	tower = require(script.Views.Tower),
	mines = require(script.Views.Mines),
	plinko = require(script.Views.Plinko),
	scratch = require(script.Views.Scratch),
	wheel = require(script.Views.Wheel),
	slots = require(script.Views.Slots),
	horse = require(script.Views.Horse),
}

local speler = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "NeonCasino"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = speler:WaitForChild("PlayerGui")

-- De achtergrond, zoals de body in de CSS: donker met twee zachte gloeden.
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Theme.color.bg
root.BorderSizePixel = 0
root.Parent = gui

-- ---------- de schermen ----------
local SCHERMEN = {
	{ id = "home",    label = "HOME",          groep = "PLAY" },
	{ id = "crash",   label = "CRASH",         groep = "PLAY" },
	{ id = "roulette",label = "ROULETTE",      groep = "PLAY" },
	{ id = "tower",   label = "DRAGON TOWER",  groep = "PLAY" },
	{ id = "mines",   label = "MINES",         groep = "PLAY" },
	{ id = "plinko",  label = "PLINKO",        groep = "PLAY" },
	{ id = "blackjack",label = "BLACKJACK",    groep = "PLAY" },
	{ id = "scratch", label = "SCRATCH CARDS", groep = "PLAY" },
	{ id = "wheel",   label = "WHEEL",         groep = "PLAY" },
	{ id = "slots",   label = "777",           groep = "PLAY" },
	{ id = "horse",   label = "HORSE RACE",    groep = "PLAY" },
	{ id = "profile", label = "PROFILE",       groep = "ACCOUNT" },
	{ id = "vip",     label = "VIP ZONE",      groep = "ACCOUNT" },
	{ id = "friends", label = "FRIENDS",       groep = "ACCOUNT" },
	{ id = "achievements", label = "ACHIEVEMENTS", groep = "ACCOUNT" },
}

local inhoud = Instance.new("Frame")
inhoud.Name = "Content"
inhoud.Position = UDim2.new(0, Theme.size.railWidth, 0, 0)
inhoud.Size = UDim2.new(1, -Theme.size.railWidth, 1, 0)
inhoud.BackgroundTransparency = 1
inhoud.Parent = root

local views: { [string]: Frame } = {}
local _huidige = "home"

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
rail.Name = "Rail"
rail.Size = UDim2.new(0, Theme.size.railWidth, 1, 0)
rail.BackgroundColor3 = Theme.color.panel
rail.BorderSizePixel = 0
rail.ZIndex = 5
rail.Parent = root

local railLijst = Instance.new("ScrollingFrame")
railLijst.Size = UDim2.new(1, 0, 1, -56)
railLijst.Position = UDim2.new(0, 0, 0, 56)
railLijst.BackgroundTransparency = 1
railLijst.BorderSizePixel = 0
railLijst.ScrollBarThickness = 0
railLijst.CanvasSize = UDim2.new()
railLijst.AutomaticCanvasSize = Enum.AutomaticSize.Y
railLijst.Parent = rail
UI.list(railLijst, 2)

local navKnoppen: { [string]: TextButton } = {}
local navigate: (string) -> ()

local function navItem(item: { id: string, label: string, groep: string }, volgorde: number)
	local b = Instance.new("TextButton")
	b.Name = item.id
	b.Text = string.sub(item.label, 1, 2)
	b.Font = Theme.font.uiBold
	b.TextSize = Theme.text.small
	b.TextColor3 = Theme.color.muted
	b.BackgroundColor3 = Theme.color.neon
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Size = UDim2.new(1, 0, 0, 48)
	b.LayoutOrder = volgorde
	b.Parent = railLijst
	b.Activated:Connect(function()
		navigate(item.id)
	end)
	navKnoppen[item.id] = b
end

for i, item in SCHERMEN do
	navItem(item, i)
end

-- ---------- routing ----------
local titelBalk = Instance.new("Frame")
titelBalk.Name = "Header"
titelBalk.Size = UDim2.new(1, 0, 0, 52)
titelBalk.BackgroundColor3 = Theme.color.panel
titelBalk.BackgroundTransparency = 0.15
titelBalk.BorderSizePixel = 0
titelBalk.ZIndex = 4
titelBalk.Parent = inhoud

local titel = UI.label(titelBalk, "HOME", {
	size = Theme.text.title, color = Theme.color.neon, font = Theme.font.uiBold, name = "Title",
})
titel.Position = UDim2.new(0, 16, 0, 0)
titel.Size = UDim2.new(1, -220, 1, 0)
titel.ZIndex = 4

local saldoLabel = UI.label(titelBalk, "$1000.00", {
	size = Theme.text.big, color = Theme.color.neon, font = Theme.font.num,
	align = Enum.TextXAlignment.Right, name = "Balance",
})
saldoLabel.Position = UDim2.new(1, -200, 0, 0)
saldoLabel.Size = UDim2.new(0, 184, 1, 0)
saldoLabel.ZIndex = 4

local toasts = Instance.new("Frame")
toasts.Name = "Toasts"
toasts.AnchorPoint = Vector2.new(1, 0)
toasts.Position = UDim2.new(1, -16, 0, 64)
toasts.Size = UDim2.new(0, 320, 0, 0)
toasts.AutomaticSize = Enum.AutomaticSize.Y
toasts.BackgroundTransparency = 1
toasts.ZIndex = 20
toasts.Parent = inhoud
local toastLijst = UI.list(toasts, 6)
toastLijst.HorizontalAlignment = Enum.HorizontalAlignment.Right

function navigate(id: string)
	for naam, v in views do
		v.Visible = naam == id
	end
	for naam, b in navKnoppen do
		local aan = naam == id
		b.TextColor3 = if aan then Theme.color.neon else Theme.color.muted
		b.BackgroundTransparency = if aan then 0.88 else 1
	end
	for _, item in SCHERMEN do
		if item.id == id then
			titel.Text = item.label
			break
		end
	end
	_huidige = id
end

-- ---------- de schermen vullen ----------
local zetSaldoHome: ((number) -> ())? = nil

for _, item in SCHERMEN do
	local v = view(item.id)
	local vak = Instance.new("Frame")
	vak.Size = UDim2.new(1, -32, 1, -68)
	vak.Position = UDim2.new(0, 16, 0, 60)
	vak.BackgroundTransparency = 1
	vak.Parent = v

	local spel = SPELLEN[item.id]
	if item.id == "home" then
		zetSaldoHome = Home.build(vak, navigate)
	elseif spel then
		spel.build(vak)
	else
		UI.list(vak, Theme.size.gap)
		local paneel = UI.panel(vak, item.id .. "Panel")
		UI.panelTitle(paneel, item.label)
		UI.label(paneel, "Dit scherm komt in een volgende stap.", {
			size = Theme.text.small, color = Theme.color.muted,
		})
	end
end

navigate("home")

-- ---------- wat de server stuurt ----------
local function toon(p: any)
	if typeof(p) ~= "table" then return end
	local b = tonumber(p.balance)
	if b then
		saldoLabel.Text = "$" .. Money.fmt(b)
		Common.setBalance(b)
		local zet = zetSaldoHome
		if zet then zet(b) end
	end
end

-- De schermen laten hun meldingen door de schil lopen; die weet waar het meldingenvak zit.
Common.setToaster(function(tekst: string, soort: UI.ToastKind?)
	UI.toast(toasts, tekst, soort)
end)

task.spawn(function()
	local ev = Net.ev("Profile")
	ev.OnClientEvent:Connect(toon)

	local toast = Net.ev("Toast")
	toast.OnClientEvent:Connect(function(tekst: any, soort: any)
		UI.toast(toasts, tostring(tekst), soort)
	end)

	-- Eén keer ophalen bij het opstarten.
	local ok, res = pcall(function()
		return Net.fn("GetProfile"):InvokeServer()
	end)
	if ok then toon(res) end
end)

return nil
