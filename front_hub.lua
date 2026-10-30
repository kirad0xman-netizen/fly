--// ============================================================
--//  FRONT HUB  -  Fly / Teleport / Image -> Pixels
--// ============================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

--------------------------------------------------------------------
-- PARENT + NETTOYAGE ANCIENNE VERSION
--------------------------------------------------------------------
local function getParent()
	local ok, gui = pcall(function()
		return (gethui and gethui()) or game:GetService("CoreGui")
	end)
	if ok and gui then return gui end
	return player:WaitForChild("PlayerGui")
end
local parentGui = getParent()

local old = parentGui:FindFirstChild("FrontHub")
if old then old:Destroy() end
local oldPix = workspace:FindFirstChild("FrontHub_Pixels")
if oldPix then oldPix:Destroy() end

--------------------------------------------------------------------
-- THEME
--------------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(16, 16, 24),
	panel = Color3.fromRGB(24, 24, 36),
	item = Color3.fromRGB(36, 36, 54),
	accent = Color3.fromRGB(0, 162, 255),
	accent2 = Color3.fromRGB(130, 90, 255),
	green = Color3.fromRGB(46, 190, 110),
	red = Color3.fromRGB(205, 60, 75),
	text = Color3.fromRGB(235, 235, 245),
	dim = Color3.fromRGB(150, 150, 175),
}

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	if props.Parent then o.Parent = props.Parent end
	return o
end

local function corner(o, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o })
end

local function stroke(o, color, th)
	return new("UIStroke", { Color = color, Thickness = th or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end

local function label(parent, text, pos, size, textSize, color, font, alignX)
	return new("TextLabel", {
		Parent = parent, Position = pos, Size = size, BackgroundTransparency = 1,
		Text = text, TextColor3 = color or C.text, Font = font or Enum.Font.GothamMedium,
		TextSize = textSize or 14, TextXAlignment = alignX or Enum.TextXAlignment.Left,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local function mkButton(parent, text, pos, size, color)
	local b = new("TextButton", {
		Parent = parent, Position = pos, Size = size, BackgroundColor3 = color,
		Text = text, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
		TextSize = 14, AutoButtonColor = false,
	})
	corner(b, 8)
	b:SetAttribute("base", color)
	local sc = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = b:GetAttribute("base"):Lerp(Color3.new(1, 1, 1), 0.15) })
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = b:GetAttribute("base") })
		tween(sc, 0.1, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.08, { Scale = 0.95 }) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back) end)
	return b
end

local function setBtn(b, color, text)
	b:SetAttribute("base", color)
	if text then b.Text = text end
	tween(b, 0.2, { BackgroundColor3 = color })
end

--------------------------------------------------------------------
-- ETAT
--------------------------------------------------------------------
local flying, noclip, clickTp = false, false, false
local speed = 50
local MIN_SPEED, MAX_SPEED, STEP = 10, 500, 10
local resolution = 32
local savedCFrame
local bv, bg, flyConn
local buildToken = 0

--------------------------------------------------------------------
-- UI : FENETRE
--------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "FrontHub", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentGui })

local FULL = UDim2.new(0, 460, 0, 320)
local MINI = UDim2.new(0, 460, 0, 40)

local main = new("Frame", {
	Name = "Main", Parent = gui, Size = FULL, Position = UDim2.new(0.5, -230, 0.5, -160),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
})
corner(main, 12)
stroke(main, C.accent2, 2)
local mainScale = new("UIScale", { Parent = main, Scale = 0.6 })

-- Barre du haut
local top = new("Frame", { Name = "Top", Parent = main, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel, BorderSizePixel = 0 })
new("UIGradient", {
	Parent = top, Rotation = 0,
	Color = ColorSequence.new(Color3.fromRGB(30, 30, 50), Color3.fromRGB(24, 24, 36)),
})
local titleLbl = new("TextLabel", {
	Parent = top, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -100, 1, 0),
	BackgroundTransparency = 1, Text = "FRONT HUB", Font = Enum.Font.GothamBlack, TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left,
})
local titleGrad = new("UIGradient", {
	Parent = titleLbl,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.accent),
		ColorSequenceKeypoint.new(0.5, C.accent2),
		ColorSequenceKeypoint.new(1, C.accent),
	}),
})
-- Animation du degrade du titre
bind(RunService.RenderStepped, function()
	titleGrad.Offset = Vector2.new(math.sin(os.clock() * 1.5) * 0.5, 0)
end)

local minBtn = mkButton(top, "–", UDim2.new(1, -68, 0.5, -13), UDim2.new(0, 26, 0, 26), C.item)
local closeBtn = mkButton(top, "✕", UDim2.new(1, -36, 0.5, -13), UDim2.new(0, 26, 0, 26), C.red)

-- Barre laterale
local side = new("Frame", { Name = "Side", Parent = main, Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(0, 112, 1, -40), BackgroundColor3 = C.panel, BorderSizePixel = 0 })
local indicator = new("Frame", { Parent = side, Size = UDim2.new(0, 4, 0, 30), Position = UDim2.new(0, 0, 0, 12), BackgroundColor3 = C.accent, BorderSizePixel = 0 })
corner(indicator, 2)

-- Zone des pages
local pagesHolder = new("Frame", { Name = "Pages", Parent = main, Position = UDim2.new(0, 120, 0, 48), Size = UDim2.new(1, -130, 1, -58), BackgroundTransparency = 1 })

-- Notification (toast)
local toast = new("TextLabel", {
	Parent = main, Size = UDim2.new(0, 300, 0, 30), Position = UDim2.new(0.5, 56, 1, 40),
	AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.accent2, Text = "",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 10,
})
corner(toast, 8)
local toastId = 0
local function notify(msg, color)
	toastId += 1
	local id = toastId
	toast.Text = msg
	toast.BackgroundColor3 = color or C.accent2
	tween(toast, 0.3, { Position = UDim2.new(0.5, 56, 1, -40) }, Enum.EasingStyle.Back)
	task.delay(2.5, function()
		if id == toastId then
			tween(toast, 0.3, { Position = UDim2.new(0.5, 56, 1, 40) })
		end
	end)
end

--------------------------------------------------------------------
-- PAGES + ONGLETS
--------------------------------------------------------------------
local pages, tabBtns = {}, {}
local currentTab

local function makePage(name)
	local p = new("CanvasGroup", {
		Name = name, Parent = pagesHolder, Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1, Visible = false, GroupTransparency = 1,
	})
	pages[name] = p
	return p
end

local function selectTab(name)
	if currentTab == name then return end
	local oldPage = currentTab and pages[currentTab]
	currentTab = name
	for n, b in pairs(tabBtns) do
		tween(b, 0.2, { TextColor3 = (n == name) and Color3.new(1, 1, 1) or C.dim })
		if n == name then
			tween(indicator, 0.25, { Position = UDim2.new(0, 0, 0, b.Position.Y.Offset + 3) }, Enum.EasingStyle.Back)
		end
	end
	if oldPage then
		tween(oldPage, 0.15, { GroupTransparency = 1 })
		task.delay(0.15, function() if pages[currentTab] ~= oldPage then oldPage.Visible = false end end)
	end
	local pg = pages[name]
	pg.Visible = true
	pg.Position = UDim2.new(0, 18, 0, 0)
	pg.GroupTransparency = 1
	tween(pg, 0.25, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
end

local tabNames = { "Fly", "Teleport", "Builder", "Infos" }
local tabIcons = { Fly = "✈  Fly", Teleport = "📍  Teleport", Builder = "🧱  Builder", Infos = "ℹ  Infos" }
for i, n in ipairs(tabNames) do
	local b = new("TextButton", {
		Parent = side, Name = n, Position = UDim2.new(0, 8, 0, 9 + (i - 1) * 42), Size = UDim2.new(1, -16, 0, 36),
		BackgroundTransparency = 1, Text = tabIcons[n], TextColor3 = C.dim, Font = Enum.Font.GothamBold,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
	})
	new("UIPadding", { Parent = b, PaddingLeft = UDim.new(0, 10) })
	b.MouseButton1Click:Connect(function() selectTab(n) end)
	b.MouseEnter:Connect(function() if currentTab ~= n then tween(b, 0.15, { TextColor3 = C.text }) end end)
	b.MouseLeave:Connect(function() if currentTab ~= n then tween(b, 0.15, { TextColor3 = C.dim }) end end)
	tabBtns[n] = b
end

--------------------------------------------------------------------
-- LOGIQUE FLY / NOCLIP
--------------------------------------------------------------------
local flyBtn, noclipBtn, speedValue

local function stopFly()
	flying = false
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end

local function startFly()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return false end

	flying = true
	hum.PlatformStand = true

	bv = new("BodyVelocity", { MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero, Parent = hrp })
	bg = new("BodyGyro", { MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, CFrame = hrp.CFrame, Parent = hrp })

	flyConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not (cam and hrp.Parent and bv and bg) then return end
		local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
		local fLook = Vector3.new(look.X, 0, look.Z)
		local fRight = Vector3.new(right.X, 0, right.Z)
		if fLook.Magnitude > 0 then fLook = fLook.Unit end
		if fRight.Magnitude > 0 then fRight = fRight.Unit end

		local move = hum.MoveDirection
		local vel = look * move:Dot(fLook) + right * move:Dot(fRight)

		local up = 0
		if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then up += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q) then up -= 1 end

		bv.Velocity = vel * speed + Vector3.new(0, up * speed, 0)
		bg.CFrame = cam.CFrame
	end)
	return true
end

local function refreshFly()
	if flying then setBtn(flyBtn, C.green, "FLY : ON") else setBtn(flyBtn, C.red, "FLY : OFF") end
end

local function toggleFly()
	if flying then stopFly() else
		if not startFly() then notify("Personnage introuvable", C.red) end
	end
	refreshFly()
end

local function setSpeed(v)
	speed = math.clamp(v, MIN_SPEED, MAX_SPEED)
	speedValue.Text = tostring(speed)
end

bind(RunService.Stepped, function()
	if noclip and player.Character then
		for _, p in ipairs(player.Character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end)

--------------------------------------------------------------------
-- PAGE FLY
--------------------------------------------------------------------
local pFly = makePage("Fly")

flyBtn = mkButton(pFly, "FLY : OFF", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 52), C.red)
flyBtn.TextSize = 20
flyBtn.MouseButton1Click:Connect(toggleFly)

label(pFly, "VITESSE", UDim2.new(0, 0, 0, 64), UDim2.new(1, 0, 0, 16), 12, C.dim)
local minusBtn = mkButton(pFly, "-", UDim2.new(0, 0, 0, 84), UDim2.new(0, 60, 0, 40), C.item)
local plusBtn = mkButton(pFly, "+", UDim2.new(1, -60, 0, 84), UDim2.new(0, 60, 0, 40), C.item)
minusBtn.TextSize = 26
plusBtn.TextSize = 26
stroke(minusBtn, C.accent2, 1.5)
stroke(plusBtn, C.accent2, 1.5)
speedValue = new("TextLabel", {
	Parent = pFly, Position = UDim2.new(0, 68, 0, 84), Size = UDim2.new(1, -136, 0, 40),
	BackgroundColor3 = C.panel, Text = tostring(speed), TextColor3 = Color3.fromRGB(130, 255, 170),
	Font = Enum.Font.GothamBold, TextSize = 22,
})
corner(speedValue, 8)
minusBtn.MouseButton1Click:Connect(function() setSpeed(speed - STEP) end)
plusBtn.MouseButton1Click:Connect(function() setSpeed(speed + STEP) end)

noclipBtn = mkButton(pFly, "NOCLIP : OFF", UDim2.new(0, 0, 0, 136), UDim2.new(1, 0, 0, 40), C.item)
noclipBtn.MouseButton1Click:Connect(function()
	noclip = not noclip
	setBtn(noclipBtn, noclip and C.green or C.item, noclip and "NOCLIP : ON" or "NOCLIP : OFF")
end)

label(pFly, "Touche F = fly ON/OFF\nZ/Q/S/D = bouger  •  Espace = monter  •  Shift = descendre", UDim2.new(0, 0, 0, 188), UDim2.new(1, 0, 0, 50), 12, C.dim)

--------------------------------------------------------------------
-- PAGE TELEPORT
--------------------------------------------------------------------
local pTp = makePage("Teleport")

local function getHRP(plr)
	local ch = plr and plr.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local saveBtn = mkButton(pTp, "💾 Sauver", UDim2.new(0, 0, 0, 0), UDim2.new(1 / 3, -4, 0, 34), C.item)
local goBtn = mkButton(pTp, "📍 TP pos", UDim2.new(1 / 3, 2, 0, 0), UDim2.new(1 / 3, -4, 0, 34), C.item)
local clickBtn = mkButton(pTp, "Ctrl+Clic: OFF", UDim2.new(2 / 3, 4, 0, 0), UDim2.new(1 / 3, -4, 0, 34), C.item)
saveBtn.TextSize = 12
goBtn.TextSize = 12
clickBtn.TextSize = 12

saveBtn.MouseButton1Click:Connect(function()
	local hrp = getHRP(player)
	if hrp then
		savedCFrame = hrp.CFrame
		notify("Position sauvegardée ✔", C.green)
	end
end)
goBtn.MouseButton1Click:Connect(function()
	local hrp = getHRP(player)
	if hrp and savedCFrame then
		hrp.CFrame = savedCFrame
		notify("Téléporté ✔", C.green)
	else
		notify("Aucune position sauvegardée", C.red)
	end
end)
clickBtn.MouseButton1Click:Connect(function()
	clickTp = not clickTp
	setBtn(clickBtn, clickTp and C.green or C.item, clickTp and "Ctrl+Clic: ON" or "Ctrl+Clic: OFF")
end)

bind(UIS.InputBegan, function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and clickTp and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local hrp = getHRP(player)
		if hrp and mouse.Hit then
			hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		toggleFly()
	end
end)

label(pTp, "JOUEURS (clique pour te téléporter)", UDim2.new(0, 0, 0, 42), UDim2.new(1, 0, 0, 14), 11, C.dim)
local list = new("ScrollingFrame", {
	Parent = pTp, Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 1, -60),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
corner(list, 8)
new("UIListLayout", { Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.Name })
new("UIPadding", { Parent = list, PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) })

local function refreshPlayers()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local b = mkButton(list, plr.DisplayName .. "  (@" .. plr.Name .. ")", UDim2.new(), UDim2.new(1, 0, 0, 32), C.item)
			b.Name = plr.Name
			b.TextSize = 13
			b.TextXAlignment = Enum.TextXAlignment.Left
			new("UIPadding", { Parent = b, PaddingLeft = UDim.new(0, 10) })
			b.MouseButton1Click:Connect(function()
				local target, me = getHRP(plr), getHRP(player)
				if target and me then
					me.CFrame = target.CFrame * CFrame.new(0, 0, 3)
					notify("TP vers " .. plr.DisplayName .. " ✔", C.green)
				else
					notify("Joueur introuvable", C.red)
				end
			end)
		end
	end
end
bind(Players.PlayerAdded, refreshPlayers)
bind(Players.PlayerRemoving, function() task.defer(refreshPlayers) end)
refreshPlayers()

--------------------------------------------------------------------
-- DECODEUR PNG (pur Lua) : inflate + filtres
--------------------------------------------------------------------
local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CLORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function buildHuff(lengths, n)
	local count = {}
	for i = 0, 15 do count[i] = 0 end
	for i = 0, n - 1 do count[lengths[i]] += 1 end
	local offs = { [1] = 0 }
	for i = 1, 14 do offs[i + 1] = offs[i] + count[i] end
	local symbol = {}
	for i = 0, n - 1 do
		local l = lengths[i]
		if l ~= 0 then
			symbol[offs[l]] = i
			offs[l] += 1
		end
	end
	return { count = count, symbol = symbol }
end

local function inflate(data, pos)
	local out, outn = {}, 0
	local bitbuf, bitcnt = 0, 0

	local function getbits(n)
		if n == 0 then return 0 end
		while bitcnt < n do
			local b = string.byte(data, pos)
			pos += 1
			bitbuf = bit32.bor(bitbuf, bit32.lshift(b, bitcnt))
			bitcnt += 8
		end
		local v = bit32.band(bitbuf, bit32.lshift(1, n) - 1)
		bitbuf = bit32.rshift(bitbuf, n)
		bitcnt -= n
		return v
	end

	local function decode(h)
		local code, first, index = 0, 0, 0
		for len = 1, 15 do
			code = bit32.bor(code, getbits(1))
			local cnt = h.count[len]
			if code - cnt < first then
				return h.symbol[index + (code - first)]
			end
			index += cnt
			first = (first + cnt) * 2
			code = code * 2
		end
		error("Code Huffman invalide")
	end

	local fixedLit, fixedDist
	repeat
		local final = getbits(1)
		local typ = getbits(2)
		if typ == 0 then
			bitbuf, bitcnt = 0, 0
			local len = string.byte(data, pos) + string.byte(data, pos + 1) * 256
			pos += 4
			for i = 0, len - 1 do
				outn += 1
				out[outn] = string.byte(data, pos + i)
			end
			pos += len
		elseif typ == 1 or typ == 2 then
			local lit, dist
			if typ == 1 then
				if not fixedLit then
					local l = {}
					for i = 0, 143 do l[i] = 8 end
					for i = 144, 255 do l[i] = 9 end
					for i = 256, 279 do l[i] = 7 end
					for i = 280, 287 do l[i] = 8 end
					fixedLit = buildHuff(l, 288)
					local d = {}
					for i = 0, 29 do d[i] = 5 end
					fixedDist = buildHuff(d, 30)
				end
				lit, dist = fixedLit, fixedDist
			else
				local nlen = getbits(5) + 257
				local ndist = getbits(5) + 1
				local ncode = getbits(4) + 4
				local cl = {}
				for i = 0, 18 do cl[i] = 0 end
				for i = 1, ncode do cl[CLORDER[i]] = getbits(3) end
				local clh = buildHuff(cl, 19)
				local lens = {}
				local idx = 0
				while idx < nlen + ndist do
					local sym = decode(clh)
					if sym < 16 then
						lens[idx] = sym
						idx += 1
					else
						local prev, rep = 0, 0
						if sym == 16 then
							prev = lens[idx - 1]
							rep = 3 + getbits(2)
						elseif sym == 17 then
							rep = 3 + getbits(3)
						else
							rep = 11 + getbits(7)
						end
						for _ = 1, rep do
							lens[idx] = prev
							idx += 1
						end
					end
				end
				local ll, dl = {}, {}
				for i = 0, nlen - 1 do ll[i] = lens[i] end
				for i = 0, ndist - 1 do dl[i] = lens[nlen + i] end
				lit = buildHuff(ll, nlen)
				dist = buildHuff(dl, ndist)
			end
			while true do
				local sym = decode(lit)
				if sym < 256 then
					outn += 1
					out[outn] = sym
				elseif sym == 256 then
					break
				else
					sym -= 257
					local len = LBASE[sym + 1] + getbits(LEXT[sym + 1])
					local ds = decode(dist)
					local d = DBASE[ds + 1] + getbits(DEXT[ds + 1])
					for _ = 1, len do
						outn += 1
						out[outn] = out[outn - d]
					end
				end
			end
		else
			error("Bloc deflate invalide")
		end
	until final == 1
	return out
end

local function u32(s, p)
	local a, b, c, d = s:byte(p, p + 3)
	return a * 16777216 + b * 65536 + c * 256 + d
end

-- Retourne largeur, hauteur, fonction getPixel(x, y) -> r, g, b, a (0-255)
local function decodePNG(s)
	if s:sub(1, 8) ~= "\137PNG\r\n\26\n" then
		error("Ce n'est pas un PNG valide (lien d'image incorrect ?)")
	end
	local p = 9
	local w, h, depth, ctype, interlace
	local idat, plte, trns = {}, nil, nil
	while p <= #s do
		local len = u32(s, p)
		local name = s:sub(p + 4, p + 7)
		local ds = p + 8
		if name == "IHDR" then
			w, h = u32(s, ds), u32(s, ds + 4)
			depth, ctype, interlace = s:byte(ds + 8), s:byte(ds + 9), s:byte(ds + 12)
		elseif name == "PLTE" then
			plte = s:sub(ds, ds + len - 1)
		elseif name == "tRNS" then
			trns = s:sub(ds, ds + len - 1)
		elseif name == "IDAT" then
			idat[#idat + 1] = s:sub(ds, ds + len - 1)
		elseif name == "IEND" then
			break
		end
		p = ds + len + 4
	end
	if not w then error("PNG illisible") end
	if depth ~= 8 or interlace ~= 0 then error("Format PNG non supporté") end

	local bppMap = { [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 }
	local bpp = bppMap[ctype]
	if not bpp then error("Type de PNG non supporté") end

	local raw = inflate(table.concat(idat), 3)
	local stride = w * bpp
	local rows = {}
	local prev = {}
	for i = 1, stride do prev[i] = 0 end
	local q = 1
	for y = 1, h do
		local ft = raw[q]
		q += 1
		local cur = {}
		for i = 1, stride do
			local x = raw[q + i - 1]
			local a = (i > bpp) and cur[i - bpp] or 0
			local b = prev[i]
			local c = (i > bpp) and prev[i - bpp] or 0
			local v
			if ft == 0 then
				v = x
			elseif ft == 1 then
				v = x + a
			elseif ft == 2 then
				v = x + b
			elseif ft == 3 then
				v = x + math.floor((a + b) / 2)
			else
				local pp = a + b - c
				local pa, pb, pc = math.abs(pp - a), math.abs(pp - b), math.abs(pp - c)
				local pr
				if pa <= pb and pa <= pc then pr = a elseif pb <= pc then pr = b else pr = c end
				v = x + pr
			end
			cur[i] = v % 256
		end
		q += stride
		rows[y] = cur
		prev = cur
	end

	local function getPixel(x, y)
		local row = rows[y]
		if ctype == 6 then
			local i = (x - 1) * 4
			return row[i + 1], row[i + 2], row[i + 3], row[i + 4]
		elseif ctype == 2 then
			local i = (x - 1) * 3
			return row[i + 1], row[i + 2], row[i + 3], 255
		elseif ctype == 0 then
			local g = row[x]
			return g, g, g, 255
		elseif ctype == 4 then
			local i = (x - 1) * 2
			return row[i + 1], row[i + 1], row[i + 1], row[i + 2]
		else
			local idx = row[x]
			local r, g, b = plte:byte(idx * 3 + 1, idx * 3 + 3)
			local a = trns and trns:byte(idx + 1) or 255
			return r, g, b, a
		end
	end
	return w, h, getPixel
end

--------------------------------------------------------------------
-- TELECHARGEMENT IMAGE
--------------------------------------------------------------------
local function httpGetBinary(url)
	local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and res and res.Body and (res.StatusCode == nil or res.StatusCode == 200) then
			return res.Body
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok then return body end
	return nil
end

--------------------------------------------------------------------
-- PAGE BUILDER
--------------------------------------------------------------------
local pBuild = makePage("Builder")

local urlBox = new("TextBox", {
	Parent = pBuild, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = C.panel, Text = "", PlaceholderText = "Colle le lien de l'image (jpg, png, webp...)",
	PlaceholderColor3 = C.dim, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13,
	ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
})
corner(urlBox, 8)
local urlStroke = stroke(urlBox, C.item, 1.5)
urlBox.Focused:Connect(function() tween(urlStroke, 0.2, { Color = C.accent }) end)
urlBox.FocusLost:Connect(function() tween(urlStroke, 0.2, { Color = C.item }) end)

label(pBuild, "RÉSOLUTION (pixels max par côté)", UDim2.new(0, 0, 0, 50), UDim2.new(1, 0, 0, 14), 11, C.dim)
local resMinus = mkButton(pBuild, "-", UDim2.new(0, 0, 0, 68), UDim2.new(0, 50, 0, 36), C.item)
local resPlus = mkButton(pBuild, "+", UDim2.new(1, -50, 0, 68), UDim2.new(0, 50, 0, 36), C.item)
resMinus.TextSize = 24
resPlus.TextSize = 24
local resValue = new("TextLabel", {
	Parent = pBuild, Position = UDim2.new(0, 58, 0, 68), Size = UDim2.new(1, -116, 0, 36),
	BackgroundColor3 = C.panel, Text = tostring(resolution), TextColor3 = Color3.fromRGB(130, 255, 170),
	Font = Enum.Font.GothamBold, TextSize = 20,
})
corner(resValue, 8)
local function setRes(v)
	resolution = math.clamp(v, 8, 64)
	resValue.Text = tostring(resolution)
end
resMinus.MouseButton1Click:Connect(function() setRes(resolution - 8) end)
resPlus.MouseButton1Click:Connect(function() setRes(resolution + 8) end)

local buildBtn = mkButton(pBuild, "🧱 CONSTRUIRE", UDim2.new(0, 0, 0, 114), UDim2.new(0.5, -4, 0, 40), C.accent)
local clearBtn = mkButton(pBuild, "🗑 EFFACER", UDim2.new(0.5, 4, 0, 114), UDim2.new(0.5, -4, 0, 40), C.red)

local statusLbl = label(pBuild, "Colle un lien direct vers une image puis clique sur CONSTRUIRE.\nL'image apparaît devant toi en pixels (visible par toi).", UDim2.new(0, 0, 0, 164), UDim2.new(1, 0, 0, 70), 12, C.dim)
local function status(t, col)
	statusLbl.Text = t
	statusLbl.TextColor3 = col or C.dim
end

local function clearPixels()
	buildToken += 1
	local f = workspace:FindFirstChild("FrontHub_Pixels")
	if f then f:Destroy() end
end

local function buildImage()
	local link = urlBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if link == "" then
		notify("Colle d'abord un lien d'image", C.red)
		return
	end
	local hrp = getHRP(player)
	if not hrp then
		notify("Personnage introuvable", C.red)
		return
	end

	clearPixels()
	local myToken = buildToken
	status("⏳ Téléchargement de l'image...", C.accent)

	-- Conversion jpg/png/webp/gif -> petit PNG via un service de redimensionnement
	local api = ("https://images.weserv.nl/?url=%s&w=%d&h=%d&fit=inside&output=png"):format(
		HttpService:UrlEncode(link), resolution, resolution
	)
	local body = httpGetBinary(api)
	if myToken ~= buildToken then return end
	if not body then
		status("❌ Impossible de télécharger l'image (lien invalide ou HTTP bloqué par ton executor).", C.red)
		return
	end

	local ok, w, h, getPixel = pcall(decodePNG, body)
	if not ok then
		status("❌ " .. tostring(w), C.red)
		return
	end

	status("🧱 Construction...", C.accent)
	local folder = new("Folder", { Name = "FrontHub_Pixels", Parent = workspace })

	local ps = 40 / math.max(w, h) -- taille d'un pixel en studs
	local hrpPos = hrp.Position
	local center = hrpPos + hrp.CFrame.LookVector * 30 + Vector3.new(0, (h * ps) / 2 - 2, 0)
	local base = CFrame.lookAt(center, Vector3.new(hrpPos.X, center.Y, hrpPos.Z))
	local animate = (w * h) <= 1500
	local total = w * h
	local done = 0

	for y = 1, h do
		if myToken ~= buildToken then return end
		for x = 1, w do
			local r, g, b, a = getPixel(x, y)
			if a >= 128 then
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.fromRGB(r, g, b)
				part.CFrame = base * CFrame.new(-(x - w / 2 - 0.5) * ps, (h / 2 - y + 0.5) * ps, 0)
				local full = Vector3.new(ps, ps, 0.5)
				if animate then
					part.Size = Vector3.new(0.05, 0.05, 0.05)
					part.Parent = folder
					TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = full }):Play()
				else
					part.Size = full
					part.Parent = folder
				end
			end
			done += 1
		end
		status(("🧱 Construction... %d%%"):format(math.floor(done / total * 100)), C.accent)
		task.wait(0.02)
	end
	status(("✅ Terminé ! Image %dx%d construite devant toi."):format(w, h), C.green)
	notify("Image construite ✔", C.green)
end

buildBtn.MouseButton1Click:Connect(function()
	task.spawn(function()
		local ok, err = pcall(buildImage)
		if not ok then status("❌ Erreur : " .. tostring(err), C.red) end
	end)
end)
clearBtn.MouseButton1Click:Connect(function()
	clearPixels()
	status("Image effacée.", C.dim)
end)

--------------------------------------------------------------------
-- PAGE INFOS
--------------------------------------------------------------------
local pInfo = makePage("Infos")
label(pInfo, "FRONT HUB  v1.0", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 24), 18, C.text, Enum.Font.GothamBlack)
label(pInfo,
	"• Fly : touche F, vitesse + / -\n• Noclip : traverse les murs\n• Teleport : clique sur un joueur, sauvegarde de position, Ctrl+Clic\n• Builder : colle un lien d'image, elle apparaît en pixels\n\nGlisse la barre du haut pour déplacer le menu, '–' pour réduire, '✕' pour fermer.",
	UDim2.new(0, 0, 0, 30), UDim2.new(1, 0, 0, 190), 13, C.dim)

--------------------------------------------------------------------
-- REDUIRE / FERMER / DRAG
--------------------------------------------------------------------
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "–"
	if minimized then
		side.Visible = false
		pagesHolder.Visible = false
	end
	local tw = tween(main, 0.25, { Size = minimized and MINI or FULL })
	if not minimized then
		tw.Completed:Connect(function()
			if not minimized then
				side.Visible = true
				pagesHolder.Visible = true
			end
		end)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	stopFly()
	noclip = false
	clearPixels()
	tween(mainScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.3, function()
		for _, c in ipairs(conns) do c:Disconnect() end
		gui:Destroy()
	end)
end)

local dragging, dragStart, startPos
top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
bind(UIS.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

bind(player.CharacterAdded, function()
	stopFly()
	refreshFly()
end)

--------------------------------------------------------------------
-- ANIMATION D'OUVERTURE
--------------------------------------------------------------------
tween(mainScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
selectTab("Fly")
task.delay(0.5, function() notify("Bienvenue sur FRONT HUB 👋") end)
