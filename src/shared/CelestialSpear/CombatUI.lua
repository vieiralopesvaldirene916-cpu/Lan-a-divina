--[[
	CombatUI — interface de combate da Lança do Juízo Celestial.

	• Botão de ataque básico (M1 → M2 → M3) com indicador do próximo golpe
	• Quatro botões de habilidades principais + três de Projéteis Celestiais
	• Ícone próprio (desenho vetorial), indicador de recarga, estado de
	  disponibilidade (energia insuficiente / barra cheia) e feedback ao toque
	• Barra de Essência Divina e indicador da Autoridade Celestial
	• Layout automático: computador (barra inferior com teclas) ou
	  celular (arco de botões acima do botão de pulo, sem cobrir a visão)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Sigil = require(script.Parent.Sigil)
local Sounds = require(script.Parent.Sounds)

local C = Config.Colors

local CombatUI = {}
CombatUI.__index = CombatUI

local KEY_NAMES = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.Z] = "Z",
	[Enum.KeyCode.X] = "X",
	[Enum.KeyCode.C] = "C",
	[Enum.KeyCode.T] = "T",
}

local function keyName(code)
	return KEY_NAMES[code] or (code and code.Name) or ""
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0.5, 0)
	c.Parent = parent
	return c
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = C.LightGold
	l.TextStrokeTransparency = 0.5
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

---------------------------------------------------------------------------
-- Ícones
---------------------------------------------------------------------------
local Icons = {}

function Icons.Basic(p)
	Sigil.bar(p, 0.09, 0.62, 45, C.Ivory, UDim2.fromScale(0.45, 0.55))
	Sigil.solidDiamond(p, 0.26, C.Gold, UDim2.fromScale(0.66, 0.34))
	Sigil.bar(p, 0.32, 0.06, -45, C.Gold, UDim2.fromScale(0.56, 0.44))
end

function Icons.CelestialSlash(p)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Rotation = -30
	holder.Parent = p
	Sigil.disc(holder, 0.7, C.Gold, 0, UDim2.fromScale(0.5, 0.5))
	Sigil.disc(holder, 0.62, C.UIBackground, 0, UDim2.fromScale(0.62, 0.42))
	Sigil.disc(holder, 0.08, C.Radiant, 0, UDim2.fromScale(0.3, 0.72))
end

function Icons.FirmamentFall(p)
	Sigil.bar(p, 0.2, 0.62, 0, C.Radiant, UDim2.fromScale(0.5, 0.38))
	Sigil.bar(p, 0.08, 0.62, 0, C.White, UDim2.fromScale(0.5, 0.38))
	local ring, stroke = Sigil.ring(p, 0.7, C.Gold, 3)
	ring:FindFirstChildOfClass("UIAspectRatioConstraint"):Destroy()
	ring.Size = UDim2.fromScale(0.72, 0.24)
	ring.Position = UDim2.fromScale(0.5, 0.74)
	stroke.Thickness = 3
	Sigil.bar(p, 0.06, 0.18, 35, C.Gold, UDim2.fromScale(0.25, 0.25))
	Sigil.bar(p, 0.06, 0.18, -35, C.Gold, UDim2.fromScale(0.75, 0.25))
end

function Icons.DivineRupture(p)
	Sigil.ring(p, 0.82, C.Gold, 3)
	Sigil.ring(p, 0.5, C.LightGold, 2)
	Sigil.bar(p, 0.09, 0.42, 0, C.Ivory, UDim2.fromScale(0.5, 0.36))
	Sigil.solidDiamond(p, 0.18, C.Radiant, UDim2.fromScale(0.5, 0.6))
	for i = 0, 3 do
		Sigil.bar(p, 0.16, 0.05, i * 45 + 22, C.Gold, UDim2.fromScale(0.5 + math.cos(math.rad(i * 45 + 22)) * 0.44, 0.5 + math.sin(math.rad(i * 45 + 22)) * 0.44))
	end
end

function Icons.GodsSentence(p)
	for i = 0, 3 do
		Sigil.bar(p, 0.05, 0.95, i * 45, C.Gold, nil, 0.45)
	end
	Sigil.ring(p, 0.6, C.LightGold, 2)
	Sigil.bar(p, 0.1, 0.7, 0, C.White, UDim2.fromScale(0.5, 0.58))
	Sigil.solidDiamond(p, 0.26, C.Radiant, UDim2.fromScale(0.5, 0.24))
	Sigil.bar(p, 0.38, 0.06, 0, C.Gold, UDim2.fromScale(0.5, 0.38))
end

function Icons.CelestialBurst(p)
	for i = 0, 2 do
		local x = 0.28 + i * 0.22
		Sigil.disc(p, 0.22, C.Gold, 0, UDim2.fromScale(x, 0.72 - i * 0.22))
		Sigil.disc(p, 0.11, C.White, 0, UDim2.fromScale(x, 0.72 - i * 0.22))
	end
end

function Icons.SacredPierce(p)
	Sigil.bar(p, 0.7, 0.07, -45, C.White, UDim2.fromScale(0.45, 0.55))
	Sigil.bar(p, 0.7, 0.16, -45, C.Gold, UDim2.fromScale(0.45, 0.55), 0.55)
	Sigil.solidDiamond(p, 0.2, C.Radiant, UDim2.fromScale(0.74, 0.26))
	local r = Sigil.ring(p, 0.28, C.LightGold, 2)
	r.Position = UDim2.fromScale(0.4, 0.6)
end

function Icons.DivineImpact(p)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		Sigil.bar(p, 0.2, 0.06, i * 45, C.Gold, UDim2.fromScale(0.5 + math.cos(a) * 0.32, 0.5 + math.sin(a) * 0.32))
	end
	Sigil.disc(p, 0.36, C.Gold)
	Sigil.disc(p, 0.2, C.White)
end

---------------------------------------------------------------------------
-- Botão
---------------------------------------------------------------------------
local function makeButton(parent, size, name, keyText, isMobile)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Parent = holder

	-- brilho externo (quando pronto)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.18, 1.18)
	glow.BackgroundColor3 = C.Gold
	glow.BackgroundTransparency = 0.8
	glow.BorderSizePixel = 0
	glow.Parent = holder
	corner(glow)

	local body = Instance.new("CanvasGroup")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = C.UIBackground
	body.BorderSizePixel = 0
	body.Parent = holder
	corner(body)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(60, 46, 20), C.UIDark)
	gradient.Rotation = 90
	gradient.Parent = body

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.66, 0.66)
	icon.Parent = body
	if Icons[name] then
		Icons[name](icon)
	end

	-- indisponível (energia insuficiente)
	local locked = Instance.new("Frame")
	locked.Name = "Locked"
	locked.Size = UDim2.fromScale(1, 1)
	locked.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	locked.BackgroundTransparency = 1
	locked.BorderSizePixel = 0
	locked.ZIndex = 3
	locked.Parent = body

	-- recarga (preenchimento que desce)
	local cd = Instance.new("Frame")
	cd.Name = "Cooldown"
	cd.AnchorPoint = Vector2.new(0, 1)
	cd.Position = UDim2.fromScale(0, 1)
	cd.Size = UDim2.fromScale(1, 0)
	cd.BackgroundColor3 = Color3.new(0, 0, 0)
	cd.BackgroundTransparency = 0.35
	cd.BorderSizePixel = 0
	cd.ZIndex = 4
	cd.Parent = body

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = C.White
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = body

	-- moldura dourada por cima de tudo
	local frameRing = Instance.new("Frame")
	frameRing.Name = "Border"
	frameRing.BackgroundTransparency = 1
	frameRing.Size = UDim2.fromScale(1, 1)
	frameRing.ZIndex = 6
	frameRing.Parent = holder
	corner(frameRing)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Gold
	stroke.Thickness = isMobile and 2.5 or 2
	stroke.Parent = frameRing

	local cdText = label(holder, {
		Name = "CooldownText",
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = math.floor(size * 0.32),
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.White,
		Text = "",
		ZIndex = 7,
	})

	local cost = label(holder, {
		Name = "Cost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(size + 20, 14),
		TextSize = 11,
		Text = "",
		ZIndex = 7,
	})

	local key
	if keyText and keyText ~= "" and not isMobile then
		local keyBg = Instance.new("Frame")
		keyBg.Name = "Key"
		keyBg.AnchorPoint = Vector2.new(0.5, 0.5)
		keyBg.Position = UDim2.new(1, -4, 0, 4)
		keyBg.Size = UDim2.fromOffset(math.max(20, #keyText * 8 + 6), 20)
		keyBg.BackgroundColor3 = C.UIDark
		keyBg.BorderSizePixel = 0
		keyBg.ZIndex = 8
		keyBg.Parent = holder
		corner(keyBg, UDim.new(0, 5))
		local ks = Instance.new("UIStroke")
		ks.Color = C.Gold
		ks.Thickness = 1
		ks.Parent = keyBg
		key = label(keyBg, { Size = UDim2.fromScale(1, 1), TextSize = 12, Text = keyText, TextColor3 = C.White, ZIndex = 9 })
	end

	local button = Instance.new("TextButton")
	button.Name = "Hitbox"
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 10
	button.AutoButtonColor = false
	button.Parent = holder

	return {
		holder = holder,
		body = body,
		glow = glow,
		locked = locked,
		cd = cd,
		cdText = cdText,
		cost = cost,
		stroke = stroke,
		flash = flash,
		scale = scale,
		button = button,
		key = key,
		size = size,
	}
end

---------------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------------
function CombatUI.new(player, callbacks)
	local self = setmetatable({}, CombatUI)
	self.callbacks = callbacks
	self.buttons = {}
	self.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	self.displayEnergy = 0

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "CelestialSpearUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui
	self.gui = gui

	-- Mira central (sempre manual; apenas indica o centro da câmera)
	local crossGui = Instance.new("ScreenGui")
	crossGui.Name = "CelestialSpearCrosshair"
	crossGui.ResetOnSpawn = false
	crossGui.IgnoreGuiInset = true
	crossGui.Enabled = false
	crossGui.Parent = playerGui
	self.crossGui = crossGui
	if Config.ShowCrosshair then
		local cross = Instance.new("Frame")
		cross.BackgroundTransparency = 1
		cross.AnchorPoint = Vector2.new(0.5, 0.5)
		cross.Position = UDim2.fromScale(0.5, 0.5)
		cross.Size = UDim2.fromOffset(22, 22)
		cross.Parent = crossGui
		Sigil.diamond(cross, 0.7, C.LightGold, 1.5, 45, 0.25)
		Sigil.disc(cross, 0.18, C.White, 0.1)
	end

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	self.uiScale = uiScale

	if self.isMobile then
		self:buildMobile(root)
	else
		self:buildDesktop(root)
	end

	-- conexões dos botões
	local function connect(name, entry)
		entry.button.MouseButton1Down:Connect(function()
			if name == "Basic" then
				callbacks.onBasic()
			else
				callbacks.onAbility(name)
			end
		end)
	end
	for name, entry in pairs(self.buttons) do
		connect(name, entry)
	end

	self:applyScale()
	self.viewportConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:applyScale()
	end)

	self.renderConn = RunService.RenderStepped:Connect(function(dt)
		if gui.Enabled then
			self:update(dt)
		end
	end)
	return self
end

function CombatUI:applyScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local minDim = math.min(vp.X, vp.Y)
	if self.isMobile then
		self.uiScale.Scale = math.clamp(minDim / 420, 0.62, 1.1)
	else
		self.uiScale.Scale = math.clamp(vp.X / 1400, 0.75, 1.15)
	end
end

local function buildEnergyBar(self, parent, width, height)
	local bar = Instance.new("Frame")
	bar.Name = "EssenceBar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = UDim2.fromOffset(width, height)
	bar.BackgroundColor3 = C.UIDark
	bar.BackgroundTransparency = 0.15
	bar.BorderSizePixel = 0
	bar.Parent = parent
	corner(bar, UDim.new(0, height / 2))
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.DeepGold
	stroke.Thickness = 1.5
	stroke.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C.White
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner(fill, UDim.new(0, height / 2))
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.DeepGold),
		ColorSequenceKeypoint.new(0.6, C.Gold),
		ColorSequenceKeypoint.new(1, C.Radiant),
	})
	gradient.Parent = fill

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.25, 0, 1, 0)
	shine.BackgroundColor3 = C.White
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Parent = fill
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Parent = shine

	local title = label(bar, {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 0, -2),
		Size = UDim2.fromOffset(200, 14),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "ESSÊNCIA DIVINA",
	})
	local value = label(bar, {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 0, -2),
		Size = UDim2.fromOffset(120, 14),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.White,
		Text = "100 / 100",
	})

	-- Autoridade Celestial (4 losangos)
	local pips = {}
	local pipHolder = Instance.new("Frame")
	pipHolder.Name = "Authority"
	pipHolder.BackgroundTransparency = 1
	pipHolder.AnchorPoint = Vector2.new(0.5, 1)
	pipHolder.Position = UDim2.new(0.5, 0, 0, -3)
	pipHolder.Size = UDim2.fromOffset(4 * 16, 12)
	pipHolder.Parent = bar
	for i = 1, Config.Authority.MaxLevel do
		local pip = Sigil.solidDiamond(pipHolder, 0.7, C.UIDark, UDim2.fromOffset((i - 0.5) * 16, 6))
		pip.Size = UDim2.fromOffset(9, 9)
		local s = Instance.new("UIStroke")
		s.Color = C.Gold
		s.Thickness = 1
		s.Parent = pip
		pips[i] = pip
	end

	self.energy = { bar = bar, fill = fill, stroke = stroke, value = value, title = title, shine = shine, pips = pips }
	return bar
end

function CombatUI:buildDesktop(root)
	local container = Instance.new("Frame")
	container.Name = "Bar"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -18)
	container.Size = UDim2.fromOffset(600, 130)
	container.Parent = root

	local bar = buildEnergyBar(self, container, 380, 16)
	bar.Position = UDim2.new(0.5, 0, 0, 22)

	local sizeMain, sizeProj, gap = 64, 50, 10
	local items = {
		{ "Basic", sizeMain, "LMB" },
	}
	for _, name in ipairs(Config.MainAbilityOrder) do
		table.insert(items, { name, sizeMain, keyName(Config.Abilities[name].Key) })
	end
	table.insert(items, { "_sep", 14 })
	for _, name in ipairs(Config.ProjectileOrder) do
		table.insert(items, { name, sizeProj, keyName(Config.Abilities[name].Key) })
	end
	local total = 0
	for _, item in ipairs(items) do
		total = total + item[2] + gap
	end
	total = total - gap
	local x = 300 - total / 2
	for _, item in ipairs(items) do
		local name, size = item[1], item[2]
		if name ~= "_sep" then
			local b = makeButton(container, size, name, item[3], false)
			b.holder.Position = UDim2.fromOffset(x + size / 2, 82 + (sizeMain - size) / 2)
			self.buttons[name] = b
		end
		x = x + size + gap
	end
	self:buildComboPips(self.buttons.Basic)
end

function CombatUI:buildMobile(root)
	-- barra de energia discreta no topo
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 26)
	top.Size = UDim2.fromOffset(250, 30)
	top.Parent = root
	local bar = buildEnergyBar(self, top, 240, 13)
	bar.Position = UDim2.new(0.5, 0, 0, 18)

	-- arco de botões acima do botão de pulo
	local anchor = Instance.new("Frame")
	anchor.Name = "Cluster"
	anchor.BackgroundTransparency = 1
	anchor.AnchorPoint = Vector2.new(0.5, 0.5)
	anchor.Position = UDim2.new(1, -112, 1, -262)
	anchor.Size = UDim2.fromOffset(1, 1)
	anchor.Parent = root

	local basic = makeButton(anchor, 92, "Basic", nil, true)
	basic.holder.Position = UDim2.fromOffset(0, 0)
	self.buttons.Basic = basic
	self:buildComboPips(basic)

	local mainAngles = { 175, 215, 255, 295 }
	for i, name in ipairs(Config.MainAbilityOrder) do
		local a = math.rad(mainAngles[i])
		local b = makeButton(anchor, 62, name, nil, true)
		b.holder.Position = UDim2.fromOffset(math.cos(a) * 98, math.sin(a) * 98)
		self.buttons[name] = b
	end
	local projAngles = { 190, 222, 254 }
	for i, name in ipairs(Config.ProjectileOrder) do
		local a = math.rad(projAngles[i])
		local b = makeButton(anchor, 48, name, nil, true)
		b.holder.Position = UDim2.fromOffset(math.cos(a) * 172, math.sin(a) * 172)
		self.buttons[name] = b
	end
end

function CombatUI:buildComboPips(basic)
	local holder = Instance.new("Frame")
	holder.Name = "Combo"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 0, -3)
	holder.Size = UDim2.fromOffset(36, 8)
	holder.Parent = basic.holder
	self.comboPips = {}
	for i = 1, 3 do
		local pip = Sigil.solidDiamond(holder, 1, C.UIDark, UDim2.fromOffset((i - 0.5) * 12, 4))
		pip.Size = UDim2.fromOffset(7, 7)
		local s = Instance.new("UIStroke")
		s.Color = C.Gold
		s.Thickness = 1
		s.Parent = pip
		self.comboPips[i] = pip
	end
	basic.comboLabel = label(basic.holder, {
		Name = "ComboLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(60, 12),
		TextSize = 10,
		TextColor3 = C.White,
		Text = "M1",
		ZIndex = 8,
	})
end

---------------------------------------------------------------------------
-- Atualização
---------------------------------------------------------------------------
function CombatUI:pressFeedback(name, accepted)
	local b = self.buttons[name]
	if not b then
		return
	end
	b.scale.Scale = 0.86
	tween(b.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if accepted ~= false then
		b.flash.BackgroundTransparency = 0.3
		tween(b.flash, 0.3, { BackgroundTransparency = 1 })
		Sounds.play("UIPress")
	else
		-- recusado (recarga/energia): pisca em vermelho
		b.stroke.Color = Color3.fromRGB(255, 80, 60)
		task.delay(0.18, function()
			b.stroke.Color = C.Gold
		end)
	end
end

function CombatUI:setVisible(visible)
	self.gui.Enabled = visible
	self.crossGui.Enabled = visible and Config.ShowCrosshair
end

function CombatUI:update(dt)
	local cb = self.callbacks
	local energy, maxEnergy = cb.getEnergy()
	self.displayEnergy = self.displayEnergy + (energy - self.displayEnergy) * math.min(1, dt * 10)
	local e = self.energy
	local ratio = math.clamp(self.displayEnergy / maxEnergy, 0, 1)
	e.fill.Size = UDim2.fromScale(ratio, 1)
	e.fill.Visible = ratio > 0.01
	e.value.Text = string.format("%d / %d", math.floor(energy + 0.5), maxEnergy)
	local full = energy >= maxEnergy - 0.01
	local t = os.clock()
	e.stroke.Color = full and C.Radiant or C.DeepGold
	e.stroke.Thickness = full and (1.5 + math.sin(t * 6) * 0.8 + 0.8) or 1.5
	e.shine.Position = UDim2.fromScale(((t * 0.6) % 1.5) - 0.25, 0)

	local authority = cb.getAuthority()
	for i, pip in ipairs(e.pips) do
		pip.BackgroundColor3 = (i <= authority) and C.Radiant or C.UIDark
	end

	local combo = cb.getCombo()
	if self.comboPips then
		for i, pip in ipairs(self.comboPips) do
			pip.BackgroundColor3 = (i == combo) and C.Radiant or C.UIDark
		end
		self.buttons.Basic.comboLabel.Text = "M" .. combo
	end

	for name, b in pairs(self.buttons) do
		local remaining, total = cb.getCooldown(name)
		local onCooldown = remaining > 0.02
		b.cd.Size = UDim2.fromScale(1, onCooldown and math.clamp(remaining / math.max(total, 0.01), 0, 1) or 0)
		if name ~= "Basic" and onCooldown and total > 1 then
			b.cdText.Text = remaining >= 10 and tostring(math.ceil(remaining)) or string.format("%.1f", remaining)
		else
			b.cdText.Text = ""
		end

		local affordable = true
		if name ~= "Basic" then
			local cost = Config.GetCost(name)
			affordable = energy >= cost - 0.01
			if Config.RequiresFull(name) then
				b.cost.Text = affordable and "PRONTA" or "BARRA CHEIA"
			else
				b.cost.Text = tostring(cost)
			end
			b.cost.TextColor3 = affordable and C.LightGold or Color3.fromRGB(255, 110, 90)
		end
		b.locked.BackgroundTransparency = affordable and 1 or 0.45
		local ready = affordable and not onCooldown
		b.stroke.Transparency = ready and 0 or 0.55
		if ready and name == "GodsSentence" then
			b.glow.BackgroundTransparency = 0.55 + math.sin(t * 5) * 0.2
		else
			b.glow.BackgroundTransparency = ready and 0.82 or 1
		end
	end
end

function CombatUI:destroy()
	if self.renderConn then
		self.renderConn:Disconnect()
	end
	if self.viewportConn then
		self.viewportConn:Disconnect()
	end
	self.gui:Destroy()
	self.crossGui:Destroy()
end

return CombatUI
