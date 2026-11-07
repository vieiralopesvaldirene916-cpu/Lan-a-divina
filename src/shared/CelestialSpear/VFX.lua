--[[
	VFX — biblioteca de efeitos visuais celestiais (somente cliente).

	Partículas, trilhas, raios, círculos mágicos, ondas de choque, colunas de
	luz e explosões. Todos os efeitos são criados localmente em cada cliente,
	garantindo suavidade total sem custo de rede.

	Paleta: branco, dourado e amarelo luminoso.
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local Sigil = require(script.Parent.Sigil)
local Util = require(script.Parent.Util)

local C = Config.Colors
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local VFX = {}

local renderSignal = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat

---------------------------------------------------------------------------
-- Básico
---------------------------------------------------------------------------
function VFX.folder()
	local folder = workspace:FindFirstChild(Util.FX_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Util.FX_FOLDER_NAME
		folder.Parent = workspace
	end
	return folder
end

function VFX.part(props, className)
	local part = Instance.new(className or "Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = C.Gold
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		part[k] = v
	end
	if not part.Parent then
		part.Parent = VFX.folder()
	end
	return part
end

function VFX.tween(instance, duration, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Executa `step(alpha)` a cada quadro durante `duration` segundos
function VFX.animate(duration, step, done)
	local start = os.clock()
	local conn
	conn = renderSignal:Connect(function()
		local alpha = (os.clock() - start) / duration
		if alpha >= 1 then
			conn:Disconnect()
			step(1)
			if done then
				done()
			end
			return
		end
		step(alpha)
	end)
	step(0)
	return conn
end

function VFX.light(position, color, brightness, range, duration)
	local holder = VFX.part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position) })
	local light = Instance.new("PointLight")
	light.Color = color or C.Gold
	light.Brightness = brightness or 4
	light.Range = math.min(range or 16, 60)
	light.Shadows = false
	light.Parent = holder
	VFX.tween(light, duration or 0.5, { Brightness = 0 })
	Debris:AddItem(holder, (duration or 0.5) + 0.1)
	return holder
end

---------------------------------------------------------------------------
-- Partículas
---------------------------------------------------------------------------
function VFX.burst(position, opts)
	opts = opts or {}
	local holder = VFX.part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position) })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = opts.Texture or SPARKLE
	emitter.Color = opts.Color or ColorSequence.new(C.White, C.Gold)
	emitter.LightEmission = opts.LightEmission or 1
	emitter.LightInfluence = 0
	local size = opts.Size or 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = opts.Transparency or NumberSequence.new(0, 1)
	local life = opts.Lifetime or NumberRange.new(0.4, 0.9)
	emitter.Lifetime = life
	emitter.Speed = opts.Speed or NumberRange.new(6, 18)
	emitter.SpreadAngle = opts.Spread or Vector2.new(180, 180)
	emitter.Drag = opts.Drag or 3
	emitter.Acceleration = opts.Acceleration or Vector3.new(0, 2, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Rate = 0
	if opts.Direction then
		attachment.WorldCFrame = Util.lookAlong(position, opts.Direction) * CFrame.Angles(-math.pi / 2, 0, 0)
		emitter.EmissionDirection = Enum.NormalId.Top
	end
	emitter.Parent = attachment
	emitter:Emit(opts.Count or 25)
	Debris:AddItem(holder, life.Max + 0.2)
	return holder
end

-- Faíscas de acerto
function VFX.hitSpark(position, direction)
	VFX.burst(position, {
		Count = 18,
		Size = 0.5,
		Speed = NumberRange.new(10, 26),
		Lifetime = NumberRange.new(0.2, 0.45),
		Direction = direction,
		Spread = direction and Vector2.new(55, 55) or Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -20, 0),
	})
	local flash = VFX.part({
		Shape = Enum.PartType.Ball,
		Color = C.White,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position),
	})
	VFX.animate(0.18, function(a)
		flash.Size = Vector3.one * (1 + a * 3.5)
		flash.Transparency = a
	end, function()
		flash:Destroy()
	end)
	-- pequena estrela cruzada
	for i = 0, 1 do
		local bar = VFX.part({ Color = C.Radiant, Size = Vector3.new(0.15, 0.15, 3.2) })
		local base = CFrame.new(position) * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, i * math.pi / 2)
		VFX.animate(0.2, function(a)
			bar.CFrame = base
			bar.Size = Vector3.new(0.15 * (1 - a), 0.15 * (1 - a), 3.2 + a * 2)
			bar.Transparency = a
		end, function()
			bar:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Formas que expandem
---------------------------------------------------------------------------
function VFX.flash(position, radius, duration, color, transparencyStart)
	local sphere = VFX.part({
		Shape = Enum.PartType.Ball,
		Color = color or C.White,
		Size = Vector3.one * radius * 0.2,
		CFrame = CFrame.new(position),
	})
	local t0 = transparencyStart or 0
	VFX.animate(duration or 0.35, function(a)
		local e = Util.Ease.outCubic(a)
		sphere.Size = Vector3.one * (radius * 0.2 + radius * 1.8 * e)
		sphere.Transparency = t0 + (1 - t0) * Util.Ease.inQuad(a)
	end, function()
		sphere:Destroy()
	end)
	return sphere
end

-- Cria uma superfície plana com um SurfaceGui (para anéis e círculos mágicos)
local function flatCanvas(cframe, diameter, canvas, brightness)
	local part = VFX.part({
		Transparency = 1,
		Size = Vector3.new(diameter, 0.05, diameter),
		CFrame = cframe,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(canvas, canvas)
	gui.LightInfluence = 0
	gui.Brightness = brightness or 3
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.Adornee = part
	gui.Parent = part
	return part, gui
end
VFX.flatCanvas = flatCanvas

-- Onda de choque em anel. `cframe.UpVector` é a normal do anel.
function VFX.ring(cframe, fromDiameter, toDiameter, duration, color, thickness, easing)
	local part, gui = flatCanvas(cframe, fromDiameter, 256, 4)
	local _, stroke = Sigil.ring(gui, 0.97, color or C.Gold, thickness or 8)
	local glow = Sigil.ring(gui, 0.9, C.White, math.max(1, (thickness or 8) * 0.4), 0.3)
	local ease = easing or Util.Ease.outCubic
	VFX.animate(duration, function(a)
		local d = fromDiameter + (toDiameter - fromDiameter) * ease(a)
		part.Size = Vector3.new(d, 0.05, d)
		part.CFrame = cframe
		stroke.Transparency = Util.Ease.inQuad(a)
		Sigil.setTransparency(glow, Util.Ease.inQuad(a))
	end, function()
		part:Destroy()
	end)
	return part
end

-- Disco translúcido que se expande (preenchimento da onda de choque)
function VFX.disc(cframe, fromDiameter, toDiameter, duration, color, startTransparency)
	local part, gui = flatCanvas(cframe, fromDiameter, 128, 2)
	local disc = Sigil.disc(gui, 1, color or C.Gold, startTransparency or 0.55)
	local t0 = startTransparency or 0.55
	VFX.animate(duration, function(a)
		local d = fromDiameter + (toDiameter - fromDiameter) * Util.Ease.outCubic(a)
		part.Size = Vector3.new(d, 0.05, d)
		disc.BackgroundTransparency = t0 + (1 - t0) * a
	end, function()
		part:Destroy()
	end)
end

--[[
	Círculo mágico com runas.
	opts: Appear (s), Duration (s, nil = manual), Spin (rad/s), Color, Accent, Fill
	Retorna um handle com :fade(t) e :destroy()
]]
function VFX.magicCircle(cframe, diameter, opts)
	opts = opts or {}
	local part, gui = flatCanvas(cframe, diameter * 0.2, opts.Canvas or 768, opts.Brightness or 3)
	local layers = Sigil.magicCircle(gui, opts.Color or C.Gold, opts.Accent or C.Radiant, {
		Thickness = opts.Thickness or 7,
		RuneCount = opts.RuneCount or 12,
		Fill = opts.Fill ~= false,
		FillTransparency = opts.FillTransparency or 0.86,
	})
	local handle = { part = part, gui = gui, layers = layers, alive = true }
	local spin = opts.Spin or 0.6
	local appear = opts.Appear or 0.35
	local start = os.clock()
	local fadeStart, fadeDuration = nil, nil
	Sigil.setTransparency(layers.Root, 1)

	local conn
	conn = renderSignal:Connect(function()
		if not handle.alive then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		local a = Util.clamp01(t / appear)
		local size = diameter * (0.2 + 0.8 * Util.Ease.outBack(a))
		part.Size = Vector3.new(size, 0.05, size)
		part.CFrame = cframe * CFrame.Angles(0, t * spin, 0)
		layers.Middle.Rotation = -math.deg(t * spin * 2.2)
		layers.Inner.Rotation = math.deg(t * spin * 3)
		local alpha = 1 - a
		if fadeStart then
			local f = Util.clamp01((os.clock() - fadeStart) / fadeDuration)
			alpha = math.max(alpha, f)
			if f >= 1 then
				handle:destroy()
				return
			end
		end
		Sigil.setTransparency(layers.Root, alpha)
	end)

	function handle:setCFrame(cf)
		cframe = cf
	end
	function handle:fade(duration)
		if not fadeStart then
			fadeStart = os.clock()
			fadeDuration = duration or 0.4
		end
	end
	function handle:destroy()
		if handle.alive then
			handle.alive = false
			part:Destroy()
		end
	end

	if opts.Duration then
		task.delay(opts.Duration, function()
			handle:fade(opts.FadeTime or 0.4)
		end)
	end
	return handle
end

---------------------------------------------------------------------------
-- Raios
---------------------------------------------------------------------------
function VFX.lightning(a, b, opts)
	opts = opts or {}
	local segments = opts.Segments or 8
	local offset = opts.Offset or (a - b).Magnitude * 0.12
	local thickness = opts.Thickness or 0.25
	local duration = opts.Duration or 0.25
	local color = opts.Color or C.Radiant
	local dir = b - a
	if dir.Magnitude < 0.01 then
		return
	end
	local basis = Util.lookAlong(a, dir)
	local points = { a }
	for i = 1, segments - 1 do
		local t = i / segments
		local jitter = basis.RightVector * (math.random() - 0.5) * 2 * offset
			+ basis.UpVector * (math.random() - 0.5) * 2 * offset
		table.insert(points, a + dir * t + jitter)
	end
	table.insert(points, b)
	local parts = {}
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		local len = (p1 - p0).Magnitude
		local seg = VFX.part({
			Color = i % 2 == 0 and C.White or color,
			Size = Vector3.new(thickness, thickness, len),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
		})
		table.insert(parts, seg)
	end
	VFX.animate(duration, function(t)
		local flicker = (math.random() < 0.25) and 0.6 or 0
		for _, seg in ipairs(parts) do
			seg.Transparency = math.min(1, Util.Ease.inQuad(t) + flicker)
		end
	end, function()
		for _, seg in ipairs(parts) do
			seg:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Coluna de luz celestial (desce do céu até o chão)
---------------------------------------------------------------------------
function VFX.column(groundPosition, radius, height, descendTime, holdTime)
	holdTime = holdTime or 0.35
	local top = groundPosition + Vector3.new(0, height, 0)
	local vertical = CFrame.Angles(0, 0, math.pi / 2) -- eixo do cilindro (X) → Y
	local outer = VFX.part({
		Shape = Enum.PartType.Cylinder,
		Color = C.Gold,
		Transparency = 0.45,
		Size = Vector3.new(0.1, radius * 2, radius * 2),
	})
	local inner = VFX.part({
		Shape = Enum.PartType.Cylinder,
		Color = C.White,
		Size = Vector3.new(0.1, radius * 1.1, radius * 1.1),
	})
	local function place(bottomY, widthScale)
		local len = math.max(0.1, top.Y - bottomY)
		local mid = Vector3.new(groundPosition.X, bottomY + len / 2, groundPosition.Z)
		outer.Size = Vector3.new(len, radius * 2 * widthScale, radius * 2 * widthScale)
		inner.Size = Vector3.new(len, radius * 1.1 * widthScale, radius * 1.1 * widthScale)
		outer.CFrame = CFrame.new(mid) * vertical
		inner.CFrame = CFrame.new(mid) * vertical
	end
	place(top.Y - 0.1, 0.6)
	VFX.animate(descendTime, function(a)
		local e = Util.Ease.inQuad(a)
		place(top.Y - height * e, 0.6 + 0.4 * e)
	end, function()
		VFX.animate(holdTime, function(a)
			place(groundPosition.Y, 1 + a * 0.4)
			outer.Transparency = 0.45 + 0.55 * a
			inner.Transparency = a
		end, function()
			outer:Destroy()
			inner:Destroy()
		end)
	end)
end

---------------------------------------------------------------------------
-- Rachaduras douradas no chão
---------------------------------------------------------------------------
function VFX.groundCracks(position, normal, count, length, duration)
	normal = normal or Vector3.yAxis
	local base = Util.lookAlong(position, normal:Cross(Vector3.xAxis).Magnitude > 0.1 and normal:Cross(Vector3.xAxis) or Vector3.zAxis, normal)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local len = length * (0.6 + math.random() * 0.5)
		local dirCF = base * CFrame.Angles(0, angle, 0)
		local crack = VFX.part({ Color = C.LightGold, Size = Vector3.new(0.25, 0.08, 0.1) })
		VFX.animate(duration or 0.9, function(a)
			local grow = Util.Ease.outExpo(math.min(1, a * 2.5))
			local l = len * grow
			crack.Size = Vector3.new(0.3 * (1 - a * 0.5), 0.08, math.max(0.1, l))
			crack.CFrame = dirCF * CFrame.new(0, 0.05, -l / 2)
			crack.Transparency = Util.Ease.inQuad(a)
		end, function()
			crack:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Estilhaços de luz
---------------------------------------------------------------------------
function VFX.shards(position, count, speed, duration)
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9 + 0.2, math.random() - 0.5).Unit
		local vel = dir * speed * (0.5 + math.random() * 0.6)
		local shard = VFX.part({
			Color = math.random() < 0.5 and C.Gold or C.White,
			Size = Vector3.new(0.25, 0.25, 1.2 + math.random()),
		}, "WedgePart")
		local pos = position
		local last = os.clock()
		VFX.animate(duration or 0.8, function(a)
			local now = os.clock()
			local dt = now - last
			last = now
			vel = vel + Vector3.new(0, -60, 0) * dt
			pos = pos + vel * dt
			if vel.Magnitude > 0.1 then
				shard.CFrame = CFrame.lookAt(pos, pos + vel)
			end
			shard.Transparency = Util.Ease.inQuad(a)
		end, function()
			shard:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Explosão celestial
---------------------------------------------------------------------------
function VFX.explosion(position, radius, opts)
	opts = opts or {}
	local intensity = opts.Intensity or 1
	local ground, normal = opts.Ground, opts.Normal or Vector3.yAxis

	VFX.flash(position, radius * 0.9, 0.35 + 0.1 * intensity, C.White)
	VFX.flash(position, radius * 1.25, 0.6 + 0.15 * intensity, C.Gold, 0.45)
	VFX.light(position, C.Gold, 5 * intensity, radius * 3, 0.7)

	local ringCF
	if ground then
		ringCF = Util.lookAlong(ground, normal:Cross(Vector3.xAxis).Magnitude > 0.1 and normal:Cross(Vector3.xAxis) or Vector3.zAxis, normal)
			* CFrame.new(0, 0.1, 0)
	else
		ringCF = CFrame.new(position)
	end
	VFX.ring(ringCF, radius * 0.4, radius * 2.8, 0.55, C.Gold, 10)
	task.delay(0.07, function()
		VFX.ring(ringCF * CFrame.new(0, 0.02, 0), radius * 0.3, radius * 2.1, 0.5, C.White, 6)
	end)
	if ground then
		VFX.disc(ringCF * CFrame.new(0, 0.01, 0), radius * 0.5, radius * 2.2, 0.45, C.Gold, 0.5)
	end

	VFX.burst(position, {
		Count = math.floor(30 * intensity),
		Size = 0.9,
		Speed = NumberRange.new(radius * 1.2, radius * 3),
		Lifetime = NumberRange.new(0.4, 0.9),
		Drag = 4,
	})
	VFX.burst(position, {
		Count = math.floor(10 * intensity),
		Texture = SMOKE,
		Color = ColorSequence.new(C.LightGold, C.Ivory),
		LightEmission = 0.6,
		Size = radius * 0.5,
		Transparency = NumberSequence.new(0.5, 1),
		Speed = NumberRange.new(radius * 0.5, radius * 1.4),
		Lifetime = NumberRange.new(0.6, 1.1),
		Drag = 5,
	})
	if not opts.NoShards then
		VFX.shards(position, math.floor(8 * intensity), radius * 3, 0.8)
	end
	if opts.Lightning then
		for _ = 1, opts.Lightning do
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
			VFX.lightning(position, position + dir * radius * (1 + math.random()), {
				Segments = 7,
				Thickness = 0.3 * intensity,
				Duration = 0.3,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Lâmina de energia do Corte Celestial
---------------------------------------------------------------------------
function VFX.crescent(width, thickness)
	local model = Instance.new("Model")
	model.Name = "CelestialCrescent"
	local root = VFX.part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
	root.Parent = model
	model.PrimaryPart = root

	local segments = 13
	local span = math.rad(70)
	local R = (width / 2) / math.sin(span)
	local parts = {}
	local function weldTo(part)
		part.Anchored = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		table.insert(parts, { part, part.Transparency })
	end

	for i = 1, segments do
		local t0 = (i - 1) / segments
		local t1 = i / segments
		local a0 = -span + 2 * span * t0
		local a1 = -span + 2 * span * t1
		local p0 = Vector3.new(R * math.sin(a0), 0, -R * math.cos(a0) + R * math.cos(span))
		local p1 = Vector3.new(R * math.sin(a1), 0, -R * math.cos(a1) + R * math.cos(span))
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.3
		local taper = math.sin(math.pi * (t0 + t1) / 2) -- mais grossa no centro
		local cf = CFrame.lookAt(mid, mid + (p1 - p0)) * CFrame.Angles(0, math.pi / 2, 0)
		local core = VFX.part({
			Color = C.White,
			Size = Vector3.new(len, thickness * (0.25 + 0.75 * taper), 0.45),
			CFrame = cf,
		})
		weldTo(core)
		local glow = VFX.part({
			Color = C.Gold,
			Transparency = 0.45,
			Size = Vector3.new(len, thickness * (0.35 + 0.95 * taper), 1.3 * (0.3 + 0.7 * taper)),
			CFrame = cf * CFrame.new(0, 0, 0.35),
		})
		weldTo(glow)
	end

	-- trilhas nas pontas e no centro
	local function trailAt(pos, w)
		local a0 = Instance.new("Attachment")
		a0.Position = pos + Vector3.new(0, w / 2, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = pos - Vector3.new(0, w / 2, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(C.Radiant, C.Gold)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.25
		trail.Parent = root
	end
	trailAt(Vector3.new(0, 0, -R + R * math.cos(span)), thickness)
	trailAt(Vector3.new(width / 2, 0, 0), thickness * 0.3)
	trailAt(Vector3.new(-width / 2, 0, 0), thickness * 0.3)

	local emitterAttachment = Instance.new("Attachment")
	emitterAttachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(C.White, C.Gold)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(2, 8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 120
	emitter.Parent = emitterAttachment

	model.Parent = VFX.folder()

	local handle = { model = model, root = root }
	function handle:setCFrame(cf)
		root.CFrame = cf
	end
	function handle:dissipate(duration)
		emitter.Enabled = false
		VFX.animate(duration or 0.25, function(a)
			for _, entry in ipairs(parts) do
				entry[1].Transparency = entry[2] + (1 - entry[2]) * a
			end
		end, function()
			model:Destroy()
		end)
	end
	return handle
end

---------------------------------------------------------------------------
-- Números de dano (somente para quem acertou)
---------------------------------------------------------------------------
function VFX.damageNumber(position, amount)
	local holder = VFX.part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.StudsOffset = Vector3.new(math.random() - 0.5, 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(math.floor(amount + 0.5))
	label.TextColor3 = C.LightGold
	label.TextStrokeColor3 = Color3.fromRGB(70, 40, 0)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 1.5
	scale.Parent = label
	VFX.tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	VFX.animate(0.8, function(a)
		gui.StudsOffset = Vector3.new(gui.StudsOffset.X, 2 + a * 2.5, 0)
		label.TextTransparency = Util.Ease.inQuad(a)
		label.TextStrokeTransparency = 0.2 + 0.8 * Util.Ease.inQuad(a)
	end, function()
		holder:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Correção de cor (escurecer o céu na Sentença dos Deuses)
---------------------------------------------------------------------------
function VFX.colorCorrection()
	local cc = Lighting:FindFirstChild("CelestialSpearCC")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CelestialSpearCC"
		cc.Parent = Lighting
	end
	return cc
end

return VFX
