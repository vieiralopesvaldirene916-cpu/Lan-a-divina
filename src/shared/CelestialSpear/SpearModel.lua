--[[
	SpearModel — constrói a Lança do Juízo Celestial peça por peça.

	Eixo da lança: a PONTA fica no -Z local do "Core" (LookVector).
	O centro (Core) fica no cristal celestial.

	Tudo é procedural (sem malhas externas): haste branca de mármore,
	anéis dourados, cristal central com luz, ponta dourada em quatro faces,
	asas ornamentais, pomo dourado, runas flutuantes, aura e partículas.
]]

local Config = require(script.Parent.Config)
local Sigil = require(script.Parent.Sigil)
local Util = require(script.Parent.Util)

local C = Config.Colors

local SpearModel = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function seq(a, b)
	return NumberSequence.new(a, b)
end

local function newPart(className, props)
	local part = Instance.new(className)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		part[k] = v
	end
	return part
end

--[[
	build(scale, options) → refs
	options.Runes (bool)       – cria runas flutuantes (padrão: true)
	options.Highlight (bool)   – contorno dourado (padrão: true)
	options.Name (string)
]]
function SpearModel.build(scale, options)
	scale = scale or 1
	options = options or {}
	local S = scale

	local model = Instance.new("Model")
	model.Name = options.Name or "LancaDoJuizoCelestial"

	local core = newPart("Part", {
		Name = "Core",
		Size = Vector3.new(0.2, 0.2, 0.2) * S,
		Transparency = 1,
		Anchored = true,
		Massless = false,
	})
	core.Parent = model
	model.PrimaryPart = core

	local refs = {
		model = model,
		core = core,
		scale = S,
		fadeParts = {}, -- { part, baseTransparency }
		emitters = {},
		lights = {},
		guis = {},
		runes = {},
	}

	local function add(className, name, size, offset, props, noFade)
		local part = newPart(className, props or {})
		part.Name = name
		part.Size = size * S
		part.CFrame = core.CFrame * CFrame.new(offset.Position * S) * (offset - offset.Position)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = core
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		if not noFade then
			table.insert(refs.fadeParts, { part, part.Transparency })
		end
		return part
	end

	local alongZ = CFrame.Angles(0, math.pi / 2, 0) -- cilindros têm o eixo em X

	local function cylinder(name, length, diameter, z, props)
		return add("Part", name, Vector3.new(length, diameter, diameter), CFrame.new(0, 0, z) * alongZ, props)
	end

	local marble = { Material = Enum.Material.Marble, Color = C.Ivory, Shape = Enum.PartType.Cylinder }
	local gold = { Material = Enum.Material.Foil, Color = C.Gold, Reflectance = 0.2, Shape = Enum.PartType.Cylinder }
	local neonRing = { Material = Enum.Material.Neon, Color = C.LightGold, Shape = Enum.PartType.Cylinder }

	-- Haste (dividida pelo cristal)
	cylinder("ShaftLower", 2.75, 0.3, 1.95, marble)
	cylinder("ShaftUpper", 1.9, 0.28, -1.6, marble)

	-- Anéis dourados e filetes luminosos
	for _, z in ipairs({ 0.72, 1.55, 2.55, 3.2, -0.72, -1.35, -2.4 }) do
		cylinder("GoldBand", 0.14, 0.4, z, gold)
	end
	for _, z in ipairs({ 1.15, 2.1, 2.9, -1.05, -1.9 }) do
		cylinder("GlowBand", 0.05, 0.33, z, neonRing)
	end

	-- Cristal celestial (octaedro) + núcleo luminoso
	local crystal = add("Part", "Crystal", Vector3.new(0.5, 0.5, 0.5),
		CFrame.Angles(math.rad(45), math.rad(35.26), 0), {
			Material = Enum.Material.Glass,
			Color = C.Crystal,
			Transparency = 0.15,
			Reflectance = 0.3,
		})
	local crystalCore = add("Part", "CrystalCore", Vector3.new(0.3, 0.3, 0.3), CFrame.new(), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = C.Radiant,
	})
	local crystalGlow = add("Part", "CrystalGlow", Vector3.new(0.75, 0.75, 0.75), CFrame.new(), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = C.Gold,
		Transparency = 0.82,
	})
	refs.crystal = crystal
	refs.crystalCore = crystalCore
	refs.crystalGlow = crystalGlow

	local crystalLight = Instance.new("PointLight")
	crystalLight.Color = C.Gold
	crystalLight.Brightness = 1.4
	crystalLight.Range = 8 * S
	crystalLight.Shadows = false
	crystalLight.Parent = crystalCore
	refs.crystalLight = crystalLight
	table.insert(refs.lights, { crystalLight, crystalLight.Brightness })

	-- Gaiola dourada do cristal
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		add("Part", "CageProng", Vector3.new(0.06, 0.06, 1.3),
			CFrame.new(math.cos(angle) * 0.4, math.sin(angle) * 0.4, 0), {
				Material = Enum.Material.Foil,
				Color = C.Gold,
				Reflectance = 0.2,
			})
	end
	cylinder("CageRing", 0.08, 0.55, 0.62, gold)
	cylinder("CageRing", 0.08, 0.55, -0.62, gold)

	-- Colar da ponta
	cylinder("HeadCollar", 0.28, 0.48, -2.55, gold)
	cylinder("HeadCollarGlow", 0.06, 0.52, -2.72, neonRing)

	-- Asas ornamentais (varridas para trás)
	local wingProps = { Material = Enum.Material.Foil, Color = C.Gold, Reflectance = 0.2 }
	add("Part", "WingRight", Vector3.new(0.95, 0.1, 0.2), CFrame.new(0.55, 0, -2.42) * CFrame.Angles(0, math.rad(-32), 0), wingProps)
	add("Part", "WingLeft", Vector3.new(0.95, 0.1, 0.2), CFrame.new(-0.55, 0, -2.42) * CFrame.Angles(0, math.rad(32), 0), wingProps)
	add("Part", "WingUp", Vector3.new(0.1, 0.6, 0.16), CFrame.new(0, 0.38, -2.45) * CFrame.Angles(math.rad(32), 0, 0), wingProps)
	add("Part", "WingDown", Vector3.new(0.1, 0.6, 0.16), CFrame.new(0, -0.38, -2.45) * CFrame.Angles(math.rad(-32), 0, 0), wingProps)
	local wingGlow = { Material = Enum.Material.Neon, Color = C.Radiant }
	add("Part", "WingTipR", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.96, 0, -2.16) * CFrame.Angles(0, 0, math.rad(45)), wingGlow)
	add("Part", "WingTipL", Vector3.new(0.16, 0.16, 0.16), CFrame.new(-0.96, 0, -2.16) * CFrame.Angles(0, 0, math.rad(45)), wingGlow)

	-- Lâmina dourada (quatro cunhas formam uma ponta piramidal afiada)
	local bladeLength = 1.65
	local bladeZ = -2.65 - bladeLength / 2
	local W = 0.44
	local W2 = 0.28
	local bladeGold = { Material = Enum.Material.Foil, Color = C.Gold, Reflectance = 0.25 }
	local bladeLight = { Material = Enum.Material.Foil, Color = C.LightGold, Reflectance = 0.3 }
	add("WedgePart", "BladeA", Vector3.new(0.1, W, bladeLength), CFrame.new(0, W / 2, bladeZ), bladeGold)
	add("WedgePart", "BladeB", Vector3.new(0.1, W, bladeLength), CFrame.new(0, -W / 2, bladeZ) * CFrame.Angles(0, 0, math.pi), bladeGold)
	add("WedgePart", "BladeC", Vector3.new(0.1, W2, bladeLength), CFrame.new(-W2 / 2, 0, bladeZ) * CFrame.Angles(0, 0, math.pi / 2), bladeLight)
	add("WedgePart", "BladeD", Vector3.new(0.1, W2, bladeLength), CFrame.new(W2 / 2, 0, bladeZ) * CFrame.Angles(0, 0, -math.pi / 2), bladeLight)

	-- Brilho envolvendo a lâmina
	local shellProps = { Material = Enum.Material.Neon, Color = C.LightGold, Transparency = 0.78 }
	local shellA = add("WedgePart", "BladeShellA", Vector3.new(0.2, W * 1.18, bladeLength * 1.1), CFrame.new(0, W * 1.18 / 2, bladeZ - 0.05), shellProps)
	local shellB = add("WedgePart", "BladeShellB", Vector3.new(0.2, W * 1.18, bladeLength * 1.1), CFrame.new(0, -W * 1.18 / 2, bladeZ - 0.05) * CFrame.Angles(0, 0, math.pi), shellProps)
	refs.bladeShells = { shellA, shellB }

	-- Pomo traseiro
	add("Part", "Pommel", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 0, 3.45), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Foil,
		Color = C.Gold,
		Reflectance = 0.2,
	})
	add("Part", "PommelGem", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 0, 3.72) * CFrame.Angles(math.rad(45), math.rad(45), 0), {
		Material = Enum.Material.Neon,
		Color = C.Radiant,
	})

	-- Brilho da ponta (fica intenso no nível 4 da Autoridade Celestial)
	local tipGlow = add("Part", "TipGlow", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 0, -Util.SPEAR_TIP_DISTANCE), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = C.White,
		Transparency = 1,
	}, true)
	refs.tipGlow = tipGlow
	local tipLight = Instance.new("PointLight")
	tipLight.Color = C.Radiant
	tipLight.Brightness = 0
	tipLight.Range = 10 * S
	tipLight.Shadows = false
	tipLight.Parent = tipGlow
	refs.tipLight = tipLight

	-- Volume invisível usado pela aura de partículas
	local auraVolume = add("Part", "AuraVolume", Vector3.new(0.7, 0.7, 7.6), CFrame.new(0, 0, -0.3), { Transparency = 1 }, true)

	-------------------------------------------------------------------------
	-- Attachments, trilha e partículas
	-------------------------------------------------------------------------
	local function attach(name, z)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(0, 0, z * S)
		a.Parent = core
		return a
	end
	refs.tipAttachment = attach("Tip", -Util.SPEAR_TIP_DISTANCE)
	refs.bladeBaseAttachment = attach("BladeBase", -2.6)
	refs.midAttachment = attach("Mid", 0)
	refs.buttAttachment = attach("Butt", 3.8)

	local trail = Instance.new("Trail")
	trail.Name = "AttackTrail"
	trail.Attachment0 = refs.tipAttachment
	trail.Attachment1 = refs.midAttachment
	trail.Color = ColorSequence.new(C.White, C.Gold)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.Enabled = false
	trail.Parent = core
	refs.trail = trail

	local tipTrail = Instance.new("Trail")
	tipTrail.Name = "TipTrail"
	local tipA = Instance.new("Attachment")
	tipA.Position = Vector3.new(0, 0.12 * S, -Util.SPEAR_TIP_DISTANCE * S)
	tipA.Parent = core
	local tipB = Instance.new("Attachment")
	tipB.Position = Vector3.new(0, -0.12 * S, -Util.SPEAR_TIP_DISTANCE * S)
	tipB.Parent = core
	tipTrail.Attachment0 = tipA
	tipTrail.Attachment1 = tipB
	tipTrail.Color = ColorSequence.new(C.Radiant)
	tipTrail.Transparency = seq(0.3, 1)
	tipTrail.LightEmission = 1
	tipTrail.Lifetime = 0.45
	tipTrail.Enabled = true
	tipTrail.Parent = core
	refs.tipTrail = tipTrail

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Texture = SPARKLE
	aura.Color = ColorSequence.new(C.Radiant, C.Gold)
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.32 * S),
		NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = seq(0.1, 1)
	aura.Lifetime = NumberRange.new(0.6, 1.3)
	aura.Speed = NumberRange.new(0.3 * S, 1.2 * S)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Acceleration = Vector3.new(0, 1.2 * S, 0)
	aura.Rate = 14
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-90, 90)
	aura.Parent = auraVolume
	refs.aura = aura
	table.insert(refs.emitters, { aura, aura.Rate })

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = SPARKLE
	motes.Color = ColorSequence.new(C.White, C.LightGold)
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Size = seq(0.18 * S, 0)
	motes.Transparency = seq(0, 1)
	motes.Lifetime = NumberRange.new(0.5, 0.9)
	motes.Speed = NumberRange.new(0)
	motes.Rate = 22
	motes.LockedToPart = false
	motes.Parent = refs.tipAttachment
	refs.motes = motes
	table.insert(refs.emitters, { motes, motes.Rate })

	-- Emissor de faíscas da ponta (nível 4)
	local tipSparks = Instance.new("ParticleEmitter")
	tipSparks.Name = "TipSparks"
	tipSparks.Texture = SPARKLE
	tipSparks.Color = ColorSequence.new(C.White, C.Radiant)
	tipSparks.LightEmission = 1
	tipSparks.LightInfluence = 0
	tipSparks.Size = seq(0.45 * S, 0)
	tipSparks.Transparency = seq(0, 1)
	tipSparks.Lifetime = NumberRange.new(0.25, 0.5)
	tipSparks.Speed = NumberRange.new(2 * S, 5 * S)
	tipSparks.SpreadAngle = Vector2.new(180, 180)
	tipSparks.Rate = 0
	tipSparks.Parent = refs.tipAttachment
	refs.tipSparks = tipSparks

	-------------------------------------------------------------------------
	-- Runas flutuantes
	-------------------------------------------------------------------------
	if options.Runes ~= false then
		for i = 1, 4 do
			local a = Instance.new("Attachment")
			a.Name = "Rune" .. i
			a.Parent = core
			local gui = Instance.new("BillboardGui")
			gui.Name = "RuneGui"
			gui.Size = UDim2.fromScale(0.75 * S, 0.75 * S)
			gui.LightInfluence = 0
			gui.Brightness = 2.5
			gui.MaxDistance = 160
			gui.Adornee = a
			gui.Parent = a
			local rune = Sigil.rune(gui, i, C.LightGold, 2)
			table.insert(refs.runes, { attachment = a, gui = gui, drawing = rune, index = i })
			table.insert(refs.guis, gui)
		end
	end

	-------------------------------------------------------------------------
	-- Contorno dourado (aura permanente)
	-------------------------------------------------------------------------
	if options.Highlight ~= false then
		local hl = Instance.new("Highlight")
		hl.Name = "DivineAura"
		hl.FillColor = C.Gold
		hl.FillTransparency = 0.9
		hl.OutlineColor = C.LightGold
		hl.OutlineTransparency = 0.55
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = model
		hl.Parent = model
		refs.highlight = hl
	end

	return refs
end

--[[
	Aplica um nível de "fade" (0 = totalmente visível, 1 = invisível).
	Usado nas animações de equipar e desequipar.
]]
function SpearModel.setFade(refs, f)
	for _, entry in ipairs(refs.fadeParts) do
		local part, base = entry[1], entry[2]
		part.Transparency = base + (1 - base) * f
	end
	for _, entry in ipairs(refs.lights) do
		entry[1].Brightness = entry[2] * (1 - f)
	end
	for _, entry in ipairs(refs.emitters) do
		entry[1].Rate = entry[2] * (1 - f)
	end
	for _, gui in ipairs(refs.guis) do
		gui.Enabled = f < 0.95
	end
	if refs.highlight then
		refs.highlight.Enabled = f < 0.9
	end
	if refs.tipTrail then
		refs.tipTrail.Enabled = f < 0.9
	end
end

return SpearModel
