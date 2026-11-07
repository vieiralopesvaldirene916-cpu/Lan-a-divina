--[[
	Projectiles — parte VISUAL dos Projéteis Celestiais (cliente).

	O servidor simula os mesmos projéteis (mesma origem, direção, velocidade)
	para aplicar dano; aqui cuidamos apenas da aparência:
	  • Rajada Celestial  — orbes dourados velozes com trilha
	  • Perfuração Sagrada — agulha de luz concentrada com anéis de pressão
	  • Impacto Divino     — orbe rúnico que explode ao tocar algo
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local VFX = require(script.Parent.VFX)
local Sigil = require(script.Parent.Sigil)
local Sounds = require(script.Parent.Sounds)

local C = Config.Colors
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local Projectiles = {}

local function weldVisual(root, part)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function addTrail(root, width, lifetime, color, transparency)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = color or ColorSequence.new(C.White, C.Gold)
	trail.Transparency = transparency or NumberSequence.new(0.1, 1)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = lifetime
	trail.FaceCamera = true
	trail.Parent = root
	-- segunda trilha perpendicular para dar volume
	local b0 = Instance.new("Attachment")
	b0.Position = Vector3.new(width / 2, 0, 0)
	b0.Parent = root
	local b1 = Instance.new("Attachment")
	b1.Position = Vector3.new(-width / 2, 0, 0)
	b1.Parent = root
	local trail2 = trail:Clone()
	trail2.Attachment0 = b0
	trail2.Attachment1 = b1
	trail2.FaceCamera = false
	trail2.Parent = root
	return trail
end

local function addSparkles(root, rate, size)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(C.White, C.Gold)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(0.5, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = rate
	emitter.Parent = root
	return emitter
end

local function addLight(root, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = C.Gold
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = root
	return light
end

---------------------------------------------------------------------------
-- Construção dos visuais (todos olham para -Z)
---------------------------------------------------------------------------
local builders = {}

function builders.CelestialBurst()
	local root = VFX.part({ Shape = Enum.PartType.Ball, Color = C.White, Size = Vector3.new(0.8, 0.8, 0.8) })
	local glow = VFX.part({ Shape = Enum.PartType.Ball, Color = C.Gold, Transparency = 0.5, Size = Vector3.new(1.6, 1.6, 1.6) })
	local bolt = VFX.part({ Color = C.LightGold, Transparency = 0.2, Size = Vector3.new(0.35, 0.35, 3.2) })
	glow.CFrame = root.CFrame
	bolt.CFrame = root.CFrame * CFrame.new(0, 0, 1.4)
	weldVisual(root, glow)
	weldVisual(root, bolt)
	glow.Parent = root
	bolt.Parent = root
	addTrail(root, 0.7, 0.2)
	addSparkles(root, 40, 0.4)
	addLight(root, 2, 10)
	return root
end

function builders.SacredPierce()
	local root = VFX.part({ Color = C.White, Size = Vector3.new(0.25, 0.25, 6) })
	local glow = VFX.part({ Color = C.Gold, Transparency = 0.45, Size = Vector3.new(0.7, 0.7, 7.5) })
	local tip = VFX.part({ Shape = Enum.PartType.Ball, Color = C.White, Size = Vector3.new(0.9, 0.9, 0.9) })
	glow.CFrame = root.CFrame * CFrame.new(0, 0, 0.5)
	tip.CFrame = root.CFrame * CFrame.new(0, 0, -3)
	weldVisual(root, glow)
	weldVisual(root, tip)
	glow.Parent = root
	tip.Parent = root
	addTrail(root, 1.2, 0.4, ColorSequence.new(C.White, C.Radiant))
	addSparkles(root, 70, 0.5)
	addLight(root, 3, 14)
	return root
end

function builders.DivineImpact()
	local root = VFX.part({ Shape = Enum.PartType.Ball, Color = C.White, Size = Vector3.new(1.6, 1.6, 1.6) })
	local glow = VFX.part({ Shape = Enum.PartType.Ball, Color = C.Gold, Transparency = 0.55, Size = Vector3.new(3, 3, 3) })
	glow.CFrame = root.CFrame
	weldVisual(root, glow)
	glow.Parent = root
	-- anel rúnico girando em volta do orbe
	local ringPart = VFX.part({ Transparency = 1, Size = Vector3.new(4.2, 0.05, 4.2) })
	ringPart.CFrame = root.CFrame * CFrame.Angles(math.pi / 2, 0, 0)
	ringPart.Parent = root -- ancorado: gira de forma independente
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(256, 256)
	gui.LightInfluence = 0
	gui.Brightness = 3
	gui.Adornee = ringPart
	gui.Parent = ringPart
	local back = gui:Clone()
	back.Face = Enum.NormalId.Bottom
	back.Parent = ringPart
	for _, g in ipairs({ gui, back }) do
		Sigil.ring(g, 0.95, C.Gold, 6)
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Size = UDim2.fromScale(0.18, 0.18)
			holder.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.4, 0.5 + math.sin(angle) * 0.4)
			holder.Parent = g
			Sigil.rune(holder, i, C.Radiant, 3)
		end
	end
	addTrail(root, 1.6, 0.3)
	addSparkles(root, 60, 0.7)
	addLight(root, 3, 16)
	return root, ringPart
end

---------------------------------------------------------------------------
-- Disparo
---------------------------------------------------------------------------
--[[
	Projectiles.fire(kind, origin, direction, ignore)
	kind: "CelestialBurst" | "SacredPierce" | "DivineImpact"
]]
function Projectiles.fire(kind, origin, direction, ignore)
	local def = Config.Abilities[kind]
	local builder = builders[kind]
	if not def or not builder then
		return
	end
	direction = direction.Unit
	local root, spinner = builder()
	local basis = Util.lookAlong(origin, direction)
	root.CFrame = basis

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { VFX.folder() }
	for _, inst in ipairs(ignore or {}) do
		table.insert(excluded, inst)
	end
	params.FilterDescendantsInstances = excluded

	-- clarão de disparo
	VFX.flash(origin, kind == "SacredPierce" and 2.5 or 1.6, 0.18, C.White)
	if kind == "SacredPierce" then
		VFX.ring(Util.lookAlong(origin, direction) * CFrame.Angles(-math.pi / 2, 0, 0), 1, 9, 0.3, C.Gold, 10)
	end

	local position = origin
	local travelled = 0
	local lastRing = 0
	local pierceLeft = def.Pierce or 0
	local finished = false
	local conn

	local function finish(hitPos, normal, hitHumanoid)
		if finished then
			return
		end
		finished = true
		conn:Disconnect()
		if hitPos then
			root.CFrame = CFrame.new(hitPos) * (basis - basis.Position)
		end
		if kind == "DivineImpact" then
			Sounds.play("Explosion", hitPos)
			VFX.explosion(hitPos, def.ExplosionRadius, {
				Intensity = 1.1,
				Ground = normal and hitPos or nil,
				Normal = normal,
				Lightning = 4,
			})
			if normal then
				VFX.groundCracks(hitPos, normal, 8, def.ExplosionRadius * 0.9, 1)
			end
		elseif hitPos then
			Sounds.play("Impact", hitPos, { Volume = 0.5 })
			VFX.hitSpark(hitPos, normal or -direction)
			VFX.flash(hitPos, kind == "SacredPierce" and 3 or 2, 0.25, C.Gold, 0.2)
		end
		-- desfazer o visual (as trilhas terminam naturalmente)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			elseif d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("SurfaceGui") then
				d.Enabled = false
			end
		end
		root.Transparency = 1
		Debris:AddItem(root, 0.6)
	end

	conn = RunService.RenderStepped:Connect(function(dt)
		local step = def.Speed * dt
		if travelled + step > def.MaxDistance then
			step = def.MaxDistance - travelled
		end
		local remaining = step
		local from = position
		while remaining > 0.01 do
			local result = workspace:Raycast(from, direction * remaining, params)
			if not result then
				break
			end
			local humanoid, model = Util.findHumanoidFromPart(result.Instance)
			if humanoid and pierceLeft > 0 then
				-- Perfuração Sagrada atravessa inimigos
				pierceLeft = pierceLeft - 1
				VFX.hitSpark(result.Position, direction)
				table.insert(excluded, model)
				params.FilterDescendantsInstances = excluded
				remaining = remaining - (result.Position - from).Magnitude
				from = result.Position
			else
				finish(result.Position, (not humanoid) and result.Normal or nil, humanoid)
				return
			end
		end
		position = position + direction * step
		travelled = travelled + step
		root.CFrame = CFrame.new(position) * (basis - basis.Position)
		if spinner then
			spinner.CFrame = root.CFrame * CFrame.Angles(math.pi / 2, os.clock() * 6, 0)
		end
		if kind == "SacredPierce" and travelled - lastRing > 28 then
			lastRing = travelled
			VFX.ring(Util.lookAlong(position, direction) * CFrame.Angles(-math.pi / 2, 0, 0), 1.5, 7, 0.35, C.LightGold, 6)
		end
		if travelled >= def.MaxDistance - 0.01 then
			if kind == "DivineImpact" then
				finish(position, nil, nil)
			else
				VFX.flash(position, 1.5, 0.2, C.Gold, 0.3)
				finish(nil, nil, nil)
			end
		end
	end)
end

return Projectiles
