--// Fly GUI - Roblox (Lua)
--// Boutons: FLY ON/OFF, + / - (vitesse), minimiser (-), fermer (X)
--// Touches: Z/Q/S/D ou fleches pour bouger, ESPACE/E = monter, SHIFT/Q = descendre

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Parent de l'interface (compatible executors)
local function getParent()
	local ok, gui = pcall(function()
		return (gethui and gethui()) or game:GetService("CoreGui")
	end)
	if ok and gui then return gui end
	return player:WaitForChild("PlayerGui")
end
local parentGui = getParent()

-- Supprime l'ancienne version si le script est relance
local old = parentGui:FindFirstChild("FlyGui_Pro")
if old then old:Destroy() end

--------------------------------------------------------------------
-- ETAT
--------------------------------------------------------------------
local flying = false
local speed = 50
local MIN_SPEED, MAX_SPEED, STEP = 10, 500, 10
local bv, bg, flyConn

--------------------------------------------------------------------
-- LOGIQUE DU FLY
--------------------------------------------------------------------
local function stopFly()
	flying = false
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end

local function startFly()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return false end

	flying = true
	hum.PlatformStand = true

	bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp

	bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bg.P = 9e4
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	flyConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not (cam and hrp.Parent and bv and bg) then return end

		local look = cam.CFrame.LookVector
		local right = cam.CFrame.RightVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local flatRight = Vector3.new(right.X, 0, right.Z)
		if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
		if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

		-- MoveDirection marche aussi sur mobile (joystick)
		local move = hum.MoveDirection
		local fwd = move:Dot(flatLook)
		local side = move:Dot(flatRight)

		local vel = look * fwd + right * side

		local up = 0
		if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then up += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q) then up -= 1 end

		bv.Velocity = vel * speed + Vector3.new(0, up * speed, 0)
		bg.CFrame = cam.CFrame
	end)
	return true
end

--------------------------------------------------------------------
-- INTERFACE
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "FlyGui_Pro"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local function round(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
	return c
end

local function stroke(obj, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local FULL_SIZE = UDim2.new(0, 240, 0, 190)
local MINI_SIZE = UDim2.new(0, 240, 0, 38)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = FULL_SIZE
main.Position = UDim2.new(0.5, -120, 0.4, 0)
main.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
round(main, 12)
stroke(main, Color3.fromRGB(90, 80, 220), 2)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(30, 30, 44), Color3.fromRGB(16, 16, 22))
grad.Rotation = 90
grad.Parent = main

-- Barre de titre
local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, 0, 0, 38)
top.BackgroundColor3 = Color3.fromRGB(90, 80, 220)
top.BorderSizePixel = 0
top.Parent = main
round(top, 12)

local topGrad = Instance.new("UIGradient")
topGrad.Color = ColorSequence.new(Color3.fromRGB(110, 90, 240), Color3.fromRGB(70, 60, 190))
topGrad.Rotation = 0
topGrad.Parent = top

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "✈  FLY MENU"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local function topButton(text, xOffset, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 26, 0, 26)
	b.Position = UDim2.new(1, xOffset, 0.5, -13)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.AutoButtonColor = true
	b.Parent = top
	round(b, 7)
	return b
end

local minBtn = topButton("–", -62, Color3.fromRGB(60, 55, 160))
local closeBtn = topButton("✕", -32, Color3.fromRGB(200, 60, 70))

-- Contenu (cache quand reduit)
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, -38)
content.Position = UDim2.new(0, 0, 0, 38)
content.BackgroundTransparency = 1
content.Parent = main

-- Bouton FLY
local flyBtn = Instance.new("TextButton")
flyBtn.Size = UDim2.new(1, -30, 0, 48)
flyBtn.Position = UDim2.new(0, 15, 0, 14)
flyBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 70)
flyBtn.Text = "FLY : OFF"
flyBtn.TextColor3 = Color3.new(1, 1, 1)
flyBtn.Font = Enum.Font.GothamBold
flyBtn.TextSize = 20
flyBtn.AutoButtonColor = true
flyBtn.Parent = content
round(flyBtn, 10)

-- Zone vitesse
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -30, 0, 20)
speedLabel.Position = UDim2.new(0, 15, 0, 76)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "VITESSE"
speedLabel.TextColor3 = Color3.fromRGB(170, 170, 200)
speedLabel.Font = Enum.Font.GothamMedium
speedLabel.TextSize = 12
speedLabel.Parent = content

local function sBtn(text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 56, 0, 40)
	b.Position = UDim2.new(0, x, 0, 98)
	b.BackgroundColor3 = Color3.fromRGB(50, 48, 80)
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 26
	b.AutoButtonColor = true
	b.Parent = content
	round(b, 10)
	stroke(b, Color3.fromRGB(90, 80, 220), 1.5)
	return b
end

local minusBtn = sBtn("-", 15)
local plusBtn = sBtn("+", 169)

local speedValue = Instance.new("TextLabel")
speedValue.Size = UDim2.new(0, 84, 0, 40)
speedValue.Position = UDim2.new(0, 78, 0, 98)
speedValue.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
speedValue.Text = tostring(speed)
speedValue.TextColor3 = Color3.fromRGB(130, 255, 170)
speedValue.Font = Enum.Font.GothamBold
speedValue.TextSize = 22
speedValue.Parent = content
round(speedValue, 10)

--------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------
local function refreshFlyBtn()
	local goal = flying and Color3.fromRGB(50, 190, 110) or Color3.fromRGB(200, 60, 70)
	flyBtn.Text = flying and "FLY : ON" or "FLY : OFF"
	TweenService:Create(flyBtn, TweenInfo.new(0.2), { BackgroundColor3 = goal }):Play()
end

flyBtn.MouseButton1Click:Connect(function()
	if flying then
		stopFly()
	else
		startFly()
	end
	refreshFlyBtn()
end)

local function setSpeed(v)
	speed = math.clamp(v, MIN_SPEED, MAX_SPEED)
	speedValue.Text = tostring(speed)
end

plusBtn.MouseButton1Click:Connect(function() setSpeed(speed + STEP) end)
minusBtn.MouseButton1Click:Connect(function() setSpeed(speed - STEP) end)

-- Reduire / agrandir
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "–"
	if minimized then
		content.Visible = false
	end
	local tween = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = minimized and MINI_SIZE or FULL_SIZE,
	})
	tween:Play()
	if not minimized then
		tween.Completed:Connect(function()
			if not minimized then content.Visible = true end
		end)
	end
end)

-- Fermer
closeBtn.MouseButton1Click:Connect(function()
	stopFly()
	gui:Destroy()
end)

-- Raccourci clavier: touche F pour activer/desactiver
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.F then
		flyBtn.MouseButton1Click:Fire()
	end
end)

-- Si le perso meurt / respawn
player.CharacterAdded:Connect(function()
	stopFly()
	refreshFlyBtn()
end)

--------------------------------------------------------------------
-- DEPLACEMENT DE LA FENETRE (drag sur la barre du haut)
--------------------------------------------------------------------
local dragging, dragStart, startPos
top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)
