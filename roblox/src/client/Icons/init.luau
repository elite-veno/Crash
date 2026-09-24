--!strict
-- De pictogrammen uit de zijbalk. In de webversie zijn dat lijntekeningen van 24 bij 24 met
-- een streekdikte van 1,8; losse tekens zagen er daarnaast uit als een noodoplossing.
--
-- Roblox kan geen paden tekenen, dus elk pictogram wordt opgebouwd uit dunne balkjes en
-- rondjes. Alles rekent in dezelfde 24x24 als de SVG, zodat de coördinaten uit crash.html
-- rechtstreeks over te nemen zijn. Wat een boog is in het origineel wordt hier een paar
-- korte segmenten -- op vierentwintig pixels ziet niemand het verschil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.Shared.UI)

local Icons = {}

local V = 24         -- viewBox
local STREEK = 1.8   -- stroke-width

function Icons.build(ouder: Instance, naam: string, maat: number): Frame
	local vak = Instance.new("Frame")
	vak.Name = "Icon"
	vak.Size = UDim2.fromOffset(maat, maat)
	vak.BackgroundTransparency = 1
	vak.Parent = ouder

	local schaal = maat / V
	local dikte = math.max(1, math.round(STREEK * schaal))

	local function lijn(x1: number, y1: number, x2: number, y2: number)
		local dx, dy = x2 - x1, y2 - y1
		local lengte = math.sqrt(dx * dx + dy * dy) * schaal
		local f = Instance.new("Frame")
		f.Name = "Stroke"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset((x1 + x2) / 2 * schaal, (y1 + y2) / 2 * schaal)
		f.Size = UDim2.fromOffset(math.max(lengte, dikte), dikte)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Rotation = math.deg(math.atan2(dy, dx))
		UI.corner(f, dikte / 2)
		f.Parent = vak
	end

	-- Een rondje: hol (alleen een rand) of vol.
	local function rond(cx: number, cy: number, r: number, vol: boolean?)
		local f = Instance.new("Frame")
		f.Name = "Stroke"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx * schaal, cy * schaal)
		f.Size = UDim2.fromOffset(r * 2 * schaal, r * 2 * schaal)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = if vol then 0 else 1
		f.BorderSizePixel = 0
		UI.corner(f, r * schaal)
		if not vol then
			UI.stroke(f, Color3.new(1, 1, 1), dikte)
		end
		f.Parent = vak
	end

	-- Een rechthoek met alleen een rand.
	local function kader(x: number, y: number, w: number, h: number, radius: number)
		local f = Instance.new("Frame")
		f.Name = "Stroke"
		f.Position = UDim2.fromOffset(x * schaal, y * schaal)
		f.Size = UDim2.fromOffset(w * schaal, h * schaal)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		UI.corner(f, radius * schaal)
		UI.stroke(f, Color3.new(1, 1, 1), dikte)
		f.Parent = vak
		return f
	end

	-- Een reeks punten aan elkaar: een gebroken lijn.
	local function boog(punten: { { number } })
		for i = 1, #punten - 1 do
			lijn(punten[i][1], punten[i][2], punten[i + 1][1], punten[i + 1][2])
		end
	end

	-- Een cirkelboog in stapjes, voor schouders en oren.
	local function arc(cx: number, cy: number, r: number, vanGraden: number, totGraden: number, stappen: number)
		local punten = {}
		for i = 0, stappen do
			local h = math.rad(vanGraden + (totGraden - vanGraden) * i / stappen)
			table.insert(punten, { cx + math.cos(h) * r, cy + math.sin(h) * r })
		end
		boog(punten)
	end

	if naam == "home" then
		boog({ {3, 12}, {12, 4}, {21, 12} })
		boog({ {5, 10}, {5, 20}, {19, 20}, {19, 10} })
	elseif naam == "crash" then
		lijn(3, 20, 20, 4)
		boog({ {14, 4}, {20, 4}, {20, 10} })
	elseif naam == "roulette" then
		rond(12, 12, 9)
		rond(12, 12, 4)
		lijn(12, 3, 12, 7)
		lijn(12, 17, 12, 21)
		lijn(3, 12, 7, 12)
		lijn(17, 12, 21, 12)
	elseif naam == "tower" then
		boog({ {12, 2}, {4, 7}, {4, 13} })
		arc(12, 13, 8, 180, 90, 5)
		arc(12, 13, 8, 0, 90, 5)
		boog({ {20, 13}, {20, 7}, {12, 2} })
		boog({ {9, 12}, {11, 14}, {15, 10} })
	elseif naam == "mines" then
		kader(4, 4, 16, 16, 2)
		for _, p in {{9, 9}, {15, 9}, {12, 12}, {9, 15}, {15, 15}} do
			rond(p[1], p[2], 1.5, true)
		end
	elseif naam == "plinko" then
		for _, p in {{6, 6}, {12, 6}, {18, 6}, {9, 12}, {15, 12}, {6, 18}, {12, 18}, {18, 18}} do
			rond(p[1], p[2], 1.5, true)
		end
	elseif naam == "blackjack" then
		kader(3, 5, 14, 18, 2)
		kader(7, 1, 14, 18, 2).BackgroundTransparency = 0.15
	elseif naam == "scratch" then
		kader(2, 6, 20, 12, 2)
		-- de gestippelde scheidingen worden hier korte streepjes
		for _, x in {8, 16} do
			for _, y in {7, 11, 15} do
				lijn(x, y, x, y + 2)
			end
		end
		lijn(11, 11, 13, 13)
		lijn(13, 11, 11, 13)
	elseif naam == "wheel" then
		rond(12, 13, 8)
		lijn(12, 5, 12, 21)
		lijn(4, 13, 20, 13)
		lijn(6.3, 7.3, 17.7, 18.7)
		lijn(17.7, 7.3, 6.3, 18.7)
	elseif naam == "slots" then
		-- 777 heeft in de webversie geen eigen pictogram: drie rollen naast elkaar.
		for _, x in {5, 10, 15} do
			kader(x, 5, 4, 14, 1)
		end
	elseif naam == "horse" then
		boog({ {4, 20}, {7, 12}, {11, 10}, {14, 5}, {17, 6}, {20, 10}, {18, 11}, {16, 9},
		       {15, 12}, {17, 16}, {15, 17}, {12, 12}, {8, 14}, {6, 20} })
	elseif naam == "bus" then
		-- ook zonder eigen pictogram: een bus als een doos met twee wielen.
		kader(3, 5, 18, 12, 2)
		lijn(3, 11, 21, 11)
		rond(7, 19, 2)
		rond(17, 19, 2)
	elseif naam == "profile" then
		rond(12, 8, 4)
		arc(12, 21, 8, 180, 360, 8)
	elseif naam == "vip" then
		boog({ {3, 8}, {7, 11}, {12, 5}, {17, 11}, {21, 8}, {19, 19}, {5, 19}, {3, 8} })
	elseif naam == "friends" then
		rond(9, 8, 3.2)
		arc(9, 20, 6.5, 180, 360, 7)
		arc(16.5, 8.5, 3.2, -80, 80, 5)
		boog({ {18, 14.6}, {20.5, 15.6}, {21.9, 19} })
	elseif naam == "achievements" then
		lijn(8, 21, 16, 21)
		lijn(12, 17, 12, 21)
		lijn(6, 4, 18, 4)
		lijn(6, 4, 6, 8)
		lijn(18, 4, 18, 8)
		arc(12, 8, 6, 0, 180, 6)
		boog({ {6, 6}, {3, 6}, {3, 8} })
		arc(7, 8, 4, 180, 90, 4)
		boog({ {18, 6}, {21, 6}, {21, 8} })
		arc(17, 8, 4, 0, 90, 4)
	end

	return vak
end

-- De kleur van een heel pictogram in één keer zetten.
function Icons.tint(vak: Frame, kleur: Color3, doorzicht: number): ()
	for _, k in vak:GetDescendants() do
		if k:IsA("Frame") then
			k.BackgroundColor3 = kleur
			if k.BackgroundTransparency < 0.9 then
				k.BackgroundTransparency = doorzicht
			end
		elseif k:IsA("UIStroke") then
			k.Color = kleur
			k.Transparency = doorzicht
		end
	end
end

return Icons
