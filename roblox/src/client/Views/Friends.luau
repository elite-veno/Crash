--!strict
-- Vrienden en tafels. Je vrienden komen van Roblox zelf, want die kent ze al; wie er nu
-- meespeelt staat bovenaan. Een privétafel is een eigen server waar je mensen bij haalt,
-- en quick play zet je terug aan de publieke tafel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")
local Theme = require(ReplicatedStorage.Shared.Theme)
local UI = require(ReplicatedStorage.Shared.UI)
local Common = require(script.Parent.Common)

local Friends = {}

function Friends.build(ouder: Instance): ()
	local blad = Common.sheet(ouder)
	local links, rechts = Common.columns(blad, "FRIENDS")

	-- ---------- de lijst ----------
	local lijstVak = UI.panel(links, "Friends")
	UI.list(lijstVak, 4)
	local lijstTitel = UI.label(lijstVak, "\u{25BA} FRIENDS", {
		size = Theme.text.small, color = Theme.color.neon, font = Theme.font.uiMed,
	})

	local lijst = Instance.new("Frame")
	lijst.Size = UDim2.new(1, 0, 0, 0)
	lijst.AutomaticSize = Enum.AutomaticSize.Y
	lijst.BackgroundTransparency = 1
	lijst.Parent = lijstVak
	UI.list(lijst, 3)

	local leeg = UI.label(lijst, "Nog niemand opgehaald.", {
		size = Theme.text.small, color = Theme.color.muted,
	})

	-- ---------- wie er nu aan tafel zit ----------
	local tafelVak = UI.panel(links, "AtTable")
	UI.list(tafelVak, 4)
	UI.panelTitle(tafelVak, "at this table")
	local tafelLijst = Instance.new("Frame")
	tafelLijst.Size = UDim2.new(1, 0, 0, 0)
	tafelLijst.AutomaticSize = Enum.AutomaticSize.Y
	tafelLijst.BackgroundTransparency = 1
	tafelLijst.Parent = tafelVak
	UI.list(tafelLijst, 2)

	-- ---------- de knoppen ----------
	local uitleg = UI.panel(rechts, "Explain")
	UI.list(uitleg, 4)
	UI.panelTitle(uitleg, "tables")
	local tekst = UI.label(uitleg, "Een privétafel is een eigen server: alleen wie jij erbij haalt speelt mee, aan dezelfde crashronde en dezelfde blackjacktafel. Quick play zet je terug aan de publieke tafel.", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	tekst.TextWrapped = true
	tekst.Size = UDim2.new(1, 0, 0, 64)

	local prive = UI.primary(rechts, "PRIVATE TABLE")
	local nodig = UI.secondary(rechts, "INVITE FRIENDS")
	nodig.Size = UDim2.new(1, 0, 0, 40)
	local snel = UI.secondary(rechts, "QUICK PLAY")
	snel.Size = UDim2.new(1, 0, 0, 40)
	local ververs = UI.secondary(rechts, "REFRESH")
	ververs.Size = UDim2.new(1, 0, 0, 32)

	local codeVak = UI.panel(rechts, "Code")
	UI.list(codeVak, 4)
	UI.panelTitle(codeVak, "your table")
	local codeLabel = UI.label(codeVak, "geen privétafel open", {
		size = Theme.text.tiny, color = Theme.color.muted,
	})
	codeLabel.TextWrapped = true
	codeLabel.Size = UDim2.new(1, 0, 0, 30)

	-- ---------- vullen ----------
	local function rijVoor(ouderVak: Instance, naam: string, erbij: boolean): TextLabel
		local rij = Common.statRow(ouderVak, naam, if erbij then "AT THE TABLE" else "ELSEWHERE")
		rij.TextColor3 = if erbij then Theme.color.neon else Theme.color.muted
		return rij
	end

	local function vul()
		local res = Common.call("Friends", "list")
		if not res then return end

		for _, k in lijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		local n = 0
		local hier = 0
		for _, v in res.friends do
			n += 1
			if v.here then hier += 1 end
			rijVoor(lijst, v.displayName, v.here)
		end
		leeg.Visible = n == 0
		leeg.Text = if n == 0
			then "Geen vrienden gevonden. Roblox geeft die lijst alleen vrij als je hem gedeeld hebt."
			else ""
		lijstTitel.Text = "\u{25BA} FRIENDS \u{00B7} " .. hier .. " / " .. n .. " HERE"

		for _, k in tafelLijst:GetChildren() do
			if k:IsA("Frame") then k:Destroy() end
		end
		for _, p in res.here do
			local rij = Common.statRow(tafelLijst, p.displayName,
				if p.userId == Players.LocalPlayer.UserId then "YOU" else "")
			rij.TextColor3 = Theme.color.muted
		end
	end

	ververs.Activated:Connect(vul)

	prive.Activated:Connect(function()
		local res = Common.call("Friends", "reserve")
		if not res then return end
		codeLabel.Text = "Tafel klaar. Je wordt er nu naartoe gebracht; nodig daarna je vrienden uit."
		codeLabel.TextColor3 = Theme.color.neon
		Common.toast("OPENING YOUR TABLE", "green")
		task.wait(1)
		Common.call("Friends", "join")
	end)

	-- De uitnodiging is die van Roblox zelf: wie je aantikt komt in jouw server terecht.
	nodig.Activated:Connect(function()
		local ok, kan = pcall(function()
			return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
		end)
		if not ok or not kan then
			Common.toast("INVITES ARE NOT AVAILABLE HERE", "red")
			return
		end
		pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
	end)

	snel.Activated:Connect(function()
		Common.toast("BACK TO THE PUBLIC TABLE", nil)
		Common.call("Friends", "quick")
	end)

	task.spawn(function()
		while true do
			vul()
			task.wait(20)
		end
	end)
end

return Friends
