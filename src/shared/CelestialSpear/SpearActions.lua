--[[
	SpearActions — coreografia de cada golpe e habilidade (cliente).

	Cada ação controla a lança por trajetórias visíveis (nada de teleporte)
	e agenda os efeitos visuais/sonoros no momento exato do movimento.

	Regra importante: efeitos "do mundo" (explosões, colunas, círculos) são
	agendados de forma independente da pose da lança. Assim, se o jogador
	encadear outro ataque logo após o fim do bloqueio, o efeito anterior
	continua acontecendo normalmente — permitindo combos físico + mágico.

	payload = {
		dir    : Vector3  direção da câmera (normalizada)
		aim    : Vector3  ponto mirado pela câmera
		target : Vector3  ponto no chão (habilidades de área)
		combo  : number   1, 2 ou 3 (ataque básico)
	}
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local VFX = require(script.Parent.VFX)
local Sounds = require(script.Parent.Sounds)
local Projectiles = require(script.Parent.Projectiles)
local SpearModel = require(script.Parent.SpearModel)

local C = Config.Colors
local Ease = Util.Ease
local A = Config.Abilities

local SpearActions = {}

local UP = Vector3.yAxis
local DOWN = -Vector3.yAxis

---------------------------------------------------------------------------
-- Auxiliares
---------------------------------------------------------------------------
local function rayParams(renderer)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { renderer.character, VFX.folder() }
	return params
end

local function ringFacing(position, normal)
	return Util.lookAlong(position, normal) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function groundCF(position)
	return CFrame.new(position + Vector3.new(0, 0.12, 0))
end

-- Ponto do arco ao redor do peito (para cortes horizontais)
local function arcPose(root, basis, angle, radius, lift)
	local radial = basis.RightVector * math.sin(angle) + basis.LookVector * math.cos(angle)
	local pos = Util.chest(root) + radial * radius + basis.UpVector * (lift or 0)
	return Util.lookAlong(pos, radial, basis.UpVector)
end

-- Ponto atingido pelo ataque descendente (M3) — mesma regra do servidor
function SpearActions.descendTarget(root, dir, params)
	local step = Config.Basic.Steps[3]
	local chest = Util.chest(root)
	local result = workspace:Raycast(chest, dir * step.Range, params)
	if result then
		return result.Position
	end
	return chest + dir * step.Range
end

local function shakeSpear(cf, t, amount)
	return cf * CFrame.new(math.sin(t * 70) * amount, math.cos(t * 63) * amount, 0)
end

---------------------------------------------------------------------------
-- ATAQUE BÁSICO
---------------------------------------------------------------------------
local Basic = {}

-- M1 — Estocada frontal: recua atrás do jogador e perfura na direção da câmera
Basic[1] = function(r, p)
	local root = r.root
	local dir = p.dir
	local step = Config.Basic.Steps[1]
	local ctx = r:beginAction()
	r:setTrail(true)
	Sounds.play("Whoosh", r.refs.core, { Volume = 0.35 })

	local right = r:base().RightVector
	local function behind()
		return Util.lookAlong(Util.chest(root) - dir * 2.4 + right * 1.2 + UP * 0.5, dir)
	end
	if not ctx:moveTo(behind, 0.11, Ease.outQuad) then
		return
	end
	Sounds.play("M1", r.refs.core)
	local goal = Util.lookAlong(Util.chest(root) + dir * (step.Range - Util.SPEAR_TIP_DISTANCE), dir)
	if not ctx:moveTo(goal, 0.1, Ease.outExpo) then
		return
	end
	local tip = r:tipPosition()
	VFX.ring(ringFacing(tip, dir), 1, 6, 0.25, C.LightGold, 8)
	VFX.burst(tip, { Count = 10, Size = 0.4, Direction = dir, Spread = Vector2.new(25, 25), Speed = NumberRange.new(10, 20) })
	if ctx:wait(0.07) then
		ctx:finish()
	end
end

-- M2 — Corte horizontal: varre um arco na região indicada pela câmera
Basic[2] = function(r, p)
	local root = r.root
	local basis = Util.aimBasis(root, p.dir)
	local ctx = r:beginAction()
	r:setTrail(true)
	local radius = 5.2
	local from, to = math.rad(118), math.rad(-118)
	if not ctx:moveTo(function()
		return arcPose(root, basis, from, radius, 0.2)
	end, 0.12, Ease.outQuad) then
		return
	end
	Sounds.play("M2", r.refs.core)
	local sparked = false
	if not ctx:path(function(a)
		if a > 0.5 and not sparked then
			sparked = true
			local mid = Util.chest(root) + basis.LookVector * radius
			VFX.burst(mid, { Count = 14, Size = 0.45, Speed = NumberRange.new(6, 14) })
		end
		return arcPose(root, basis, from + (to - from) * a, radius, 0.2)
	end, 0.17, Ease.inOutQuad) then
		return
	end
	if ctx:wait(0.05) then
		ctx:finish()
	end
end

-- M3 — Ataque descendente: sobe (ataque ascendente) e golpeia de cima para baixo
Basic[3] = function(r, p)
	local root = r.root
	local target = SpearActions.descendTarget(root, p.dir, rayParams(r))
	local ctx = r:beginAction()
	r:setTrail(true)
	Sounds.play("Whoosh", r.refs.core, { Volume = 0.4, PlaybackSpeed = 1.1 })
	local high = Util.lookAlong(target + UP * 8, DOWN, r:base().LookVector)
	local rise = r.worldCF
	if not ctx:path(function(a)
		-- arco ascendente até acima do alvo
		local pos = rise.Position:Lerp(high.Position, a) + UP * math.sin(a * math.pi) * 2
		return CFrame.new(pos) * rise.Rotation:Lerp(high.Rotation, a)
	end, 0.2, Ease.outQuad) then
		return
	end
	Sounds.play("M3", r.refs.core)
	local slam = Util.lookAlong(target + UP * (Util.SPEAR_TIP_DISTANCE - 0.6), DOWN, r:base().LookVector)
	if not ctx:moveTo(slam, 0.13, Ease.inExpo) then
		return
	end
	Sounds.play("Impact", target, { Volume = 0.6 })
	local _, normal = Util.groundBelow(target, rayParams(r), 3)
	if normal then
		VFX.ring(groundCF(target), 2, 13, 0.4, C.Gold, 10)
		VFX.groundCracks(target, normal, 6, 5, 0.6)
	else
		VFX.ring(ringFacing(target, UP), 2, 11, 0.4, C.Gold, 10)
	end
	VFX.flash(target, 3, 0.25, C.White)
	VFX.burst(target, { Count = 20, Size = 0.6, Speed = NumberRange.new(8, 20), Acceleration = Vector3.new(0, -25, 0) })
	if ctx:wait(0.1) then
		ctx:finish()
	end
end

---------------------------------------------------------------------------
-- HABILIDADE 1 — CORTE CELESTIAL
---------------------------------------------------------------------------
local function travelCrescent(r, origin, dir, up)
	local def = A.CelestialSlash
	local wave = VFX.crescent(def.Width, def.Thickness)
	local params = rayParams(r)
	local travelled = 0
	local basis = Util.lookAlong(origin, dir, up)
	wave:setCFrame(basis)
	local last = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		local step = def.Speed * dt
		local pos = basis.Position + dir * travelled
		local result = workspace:Raycast(pos, dir * (step + 1), params)
		if result and not Util.findHumanoidFromPart(result.Instance) then
			conn:Disconnect()
			wave:setCFrame(CFrame.new(result.Position) * basis.Rotation)
			VFX.flash(result.Position, 5, 0.3, C.Gold, 0.2)
			VFX.burst(result.Position, { Count = 25, Size = 0.7, Speed = NumberRange.new(10, 24) })
			Sounds.play("Impact", result.Position, { Volume = 0.6 })
			wave:dissipate(0.2)
			return
		end
		travelled = travelled + step
		wave:setCFrame(CFrame.new(basis.Position + dir * travelled) * basis.Rotation)
		if travelled >= def.MaxDistance then
			conn:Disconnect()
			wave:dissipate(0.25)
		end
	end)
end

local function celestialSlash(r, p)
	local def = A.CelestialSlash
	local root = r.root
	local basis = Util.aimBasis(root, p.dir)
	local ctx = r:beginAction()
	r:setCharge(0.7)
	Sounds.play("Charge", r.refs.core)

	-- preparação: recolhe para trás à direita, deitada na horizontal
	local radius = 4.2
	local from, to = math.rad(135), math.rad(-135)
	VFX.burst(r.refs.core.Position, { Count = 20, Size = 0.4, Speed = NumberRange.new(2, 5) })

	task.delay(def.ReleaseDelay, function()
		local origin = Util.chest(root) + basis.LookVector * 3
		Sounds.play("SlashWave", origin)
		VFX.flash(origin, 4, 0.25, C.White, 0.2)
		travelCrescent(r, origin, p.dir, basis.UpVector)
	end)

	if not ctx:moveTo(function()
		return shakeSpear(arcPose(root, basis, from, radius, 0.4), os.clock(), 0.04)
	end, 0.3, Ease.outCubic) then
		return
	end
	r:setTrail(true)
	Sounds.play("M2", r.refs.core, { PlaybackSpeed = 0.9 })
	if not ctx:path(function(a)
		return arcPose(root, basis, from + (to - from) * a, radius + math.sin(a * math.pi) * 1.5, 0.4)
	end, 0.18, Ease.inOutQuad) then
		return
	end
	if ctx:wait(0.08) then
		ctx:finish()
	end
end

---------------------------------------------------------------------------
-- HABILIDADE 2 — QUEDA DO FIRMAMENTO
---------------------------------------------------------------------------
local function firmamentFall(r, p)
	local def = A.FirmamentFall
	local root = r.root
	local target = p.target
	local ctx = r:beginAction()
	r:setCharge(1)
	Sounds.play("Charge", r.refs.core, { PlaybackSpeed = 0.5 })

	-- efeitos do mundo (independentes da pose)
	local circle = VFX.magicCircle(groundCF(target), def.Radius * 2.1, {
		Appear = 0.4,
		Spin = 0.8,
		Duration = def.ImpactDelay + 0.25,
		FadeTime = 0.5,
	})
	task.delay(0.35, function()
		local tip = r:tipPosition()
		VFX.flash(tip, 2.5, 0.3, C.White)
		VFX.column(tip, 0.25, 70, 0.12, 0.35)
	end)
	task.delay(def.ImpactDelay - 0.25, function()
		Sounds.play("Column", target)
		VFX.column(target, def.Radius * 0.42, 150, 0.25, 0.5)
	end)
	task.delay(def.ImpactDelay, function()
		Sounds.play("Explosion", target)
		VFX.explosion(target + UP * 1.5, def.Radius, { Ground = target, Intensity = 1.4, Lightning = 6 })
		VFX.groundCracks(target, UP, 12, def.Radius, 1.1)
		circle:fade(0.4)
	end)

	-- a lança sobe acima do jogador apontando para o céu
	local function above(t)
		local pos = Util.chest(root) + UP * 7.5 + r:base().RightVector * 0.6
		return Util.lookAlong(pos, UP, r:base().LookVector) * CFrame.Angles(0, 0, t * 6)
	end
	if not ctx:moveTo(function()
		return above(os.clock())
	end, 0.3, Ease.outBack) then
		return
	end
	ctx:hold(function(now)
		return shakeSpear(above(now), now, 0.05)
	end)
	if ctx:wait(def.ImpactDelay - 0.3) then
		ctx:finish()
	end
end

---------------------------------------------------------------------------
-- HABILIDADE 3 — RUPTURA DIVINA
---------------------------------------------------------------------------
function SpearActions.ruptureTarget(root, dir, params)
	local def = A.DivineRupture
	local flat = Util.flatten(dir)
	local point = root.Position + flat * def.ForwardOffset
	local ground = Util.groundBelow(point, params, 12)
	return ground or (point - Vector3.new(0, 3, 0))
end

local function divineRupture(r, p)
	local def = A.DivineRupture
	local root = r.root
	local params = rayParams(r)
	local target = SpearActions.ruptureTarget(root, p.dir, params)
	local ctx = r:beginAction()
	r:setCharge(0.8)
	r:setTrail(true)
	Sounds.play("Charge", r.refs.core, { PlaybackSpeed = 0.7 })

	task.delay(def.ImpactDelay, function()
		Sounds.play("Rupture", target)
		Sounds.play("Explosion", target, { Volume = 0.6, PlaybackSpeed = 0.6 })
		VFX.flash(target, 6, 0.3, C.White)
		local circle = VFX.magicCircle(groundCF(target), def.Radius * 1.1, { Appear = 0.15, Spin = 1.6, Duration = 0.6 })
		VFX.ring(groundCF(target), 3, def.Radius * 2.1, 0.55, C.Gold, 14, Ease.outQuad)
		task.delay(0.08, function()
			VFX.ring(groundCF(target) * CFrame.new(0, 0.03, 0), 2, def.Radius * 1.7, 0.5, C.White, 8)
		end)
		VFX.disc(groundCF(target) * CFrame.new(0, -0.02, 0), 2, def.Radius * 2, 0.5, C.Gold, 0.5)
		VFX.groundCracks(target, UP, 14, def.Radius * 0.8, 1.2)
		VFX.shards(target, 12, 30, 0.9)
		VFX.burst(target, {
			Count = 40,
			Size = 0.8,
			Speed = NumberRange.new(15, 35),
			Spread = Vector2.new(80, 80),
			Direction = UP,
			Acceleration = Vector3.new(0, -30, 0),
		})
		VFX.light(target + UP * 2, C.Gold, 6, 40, 0.6)
		task.delay(0.5, function()
			circle:fade(0.3)
		end)
	end)

	local look = r:base().LookVector
	if not ctx:moveTo(Util.lookAlong(target + UP * 9, DOWN, look), 0.25, Ease.outQuad) then
		return
	end
	local hang = r.worldCF
	ctx:hold(function(now)
		return shakeSpear(hang, now, 0.08)
	end)
	if not ctx:wait(def.ImpactDelay - 0.25 - 0.15) then
		return
	end
	Sounds.play("Whoosh", r.refs.core, { PlaybackSpeed = 0.8 })
	if not ctx:moveTo(Util.lookAlong(target + UP * (Util.SPEAR_TIP_DISTANCE - 1.2), DOWN, look), 0.15, Ease.inExpo) then
		return
	end
	if ctx:wait(0.18) then
		ctx:finish()
	end
end

---------------------------------------------------------------------------
-- HABILIDADE 4 — SENTENÇA DOS DEUSES (suprema)
---------------------------------------------------------------------------
local function sentenceLighting(target, def)
	local player = Players.LocalPlayer
	local char = player and player.Character
	local root = Util.getRoot(char)
	if root and (root.Position - target).Magnitude > def.DarkenRadius then
		return
	end
	local cc = VFX.colorCorrection()
	local function tween(t, props, style)
		TweenService:Create(cc, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props):Play()
	end
	-- escurecimento leve durante a preparação
	tween(0.9, { Brightness = -0.16, Saturation = -0.35, Contrast = 0.12, TintColor = Color3.fromRGB(255, 238, 205) })
	task.delay(def.ImpactDelay, function()
		-- clarão dourado no impacto (sem tremer a câmera)
		cc.Brightness = 0.35
		cc.Contrast = 0.25
		cc.TintColor = Color3.fromRGB(255, 236, 170)
		tween(0.7, { Brightness = -0.05, Contrast = 0.1 }, Enum.EasingStyle.Quart)
		task.delay(0.9, function()
			tween(1.4, { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
		end)
	end)
end

local function godsSentence(r, p)
	local def = A.GodsSentence
	local root = r.root
	local target = p.target
	local impact = def.ImpactDelay
	local skyHeight = 150
	local ctx = r:beginAction()
	r:setCharge(1)

	sentenceLighting(target, def)
	Sounds.play("SentencePrep", r.refs.core)
	Sounds.play("SentencePrep", target, { PlaybackSpeed = 0.25 })

	-- Círculos rúnicos no chão (três camadas)
	local circles = {}
	local sizes = { def.Radius * 2.3, def.Radius * 1.55, def.Radius * 0.85 }
	local spins = { 0.35, -0.7, 1.2 }
	for i = 1, 3 do
		task.delay((i - 1) * 0.25, function()
			circles[i] = VFX.magicCircle(groundCF(target) * CFrame.new(0, i * 0.03, 0), sizes[i], {
				Appear = 0.5,
				Spin = spins[i],
				Thickness = 9 - i,
				RuneCount = 16 - i * 2,
				Brightness = 4,
				Canvas = 1024,
				Duration = impact + 1.6 - (i - 1) * 0.25,
				FadeTime = 0.8,
			})
		end)
	end

	-- Pilares de luz na borda do círculo
	for i = 1, 8 do
		task.delay(0.3 + i * 0.12, function()
			local angle = i / 8 * math.pi * 2
			local pos = target + Vector3.new(math.cos(angle), 0, math.sin(angle)) * def.Radius * 1.05
			VFX.column(pos, 0.45, 45, 0.18, impact - 0.3 - i * 0.12)
			VFX.burst(pos, { Count = 8, Size = 0.5, Direction = UP, Spread = Vector2.new(15, 15), Speed = NumberRange.new(10, 25) })
		end)
	end

	-- Partículas sagradas subindo do círculo durante a preparação
	for i = 0, 5 do
		task.delay(0.4 + i * 0.35, function()
			VFX.burst(target + UP, {
				Count = 25,
				Size = 0.7,
				Direction = UP,
				Spread = Vector2.new(60, 60),
				Speed = NumberRange.new(6, 18),
				Acceleration = Vector3.new(0, 10, 0),
				Lifetime = NumberRange.new(0.8, 1.4),
			})
		end)
	end

	-- A lança chama o céu: feixe para cima e círculo celestial no céu
	local skyPoint = target + UP * skyHeight
	local skyCircle
	task.delay(0.9, function()
		local tip = r:tipPosition()
		VFX.column(tip, 0.4, 220, 0.15, 1.2)
		VFX.flash(tip, 4, 0.4, C.White)
		skyCircle = VFX.magicCircle(CFrame.new(skyPoint) * CFrame.Angles(math.pi, 0, 0), def.Radius * 1.8, {
			Appear = 0.6,
			Spin = 0.5,
			Brightness = 5,
			Canvas = 1024,
		})
	end)

	-- Lança gigante de energia celestial
	task.delay(1.6, function()
		local giant = SpearModel.build(9, { Runes = false, Name = "LancaGigante" })
		giant.model.Parent = VFX.folder()
		local startCF = Util.lookAlong(skyPoint + UP * 4, DOWN)
		local endCF = Util.lookAlong(target + UP * (Util.SPEAR_TIP_DISTANCE * 9 - 6), DOWN)
		giant.core.CFrame = startCF
		giant.trail.Enabled = true
		giant.crystalLight.Range = 60
		SpearModel.setFade(giant, 1)
		-- materializa
		VFX.animate(0.6, function(a)
			SpearModel.setFade(giant, 1 - a)
			giant.core.CFrame = startCF * CFrame.Angles(0, 0, a * 2)
		end)
		VFX.burst(skyPoint, { Count = 40, Size = 4, Speed = NumberRange.new(20, 50) })
		-- desce do céu
		task.delay(impact - 1.6 - 0.55, function()
			Sounds.play("SentenceDescend", target)
			local from = giant.core.CFrame
			VFX.animate(0.55, function(a)
				giant.core.CFrame = from:Lerp(endCF, Ease.inCubic(a))
			end, function()
				giant.trail.Enabled = false
			end)
		end)
		-- permanece cravada, brilha e se desfaz em luz (encerramento)
		task.delay(impact - 1.6 + 0.9, function()
			Sounds.play("SentenceEnd", target)
			local embedded = giant.core.CFrame
			for i = 0, 4 do
				task.delay(i * 0.18, function()
					VFX.burst(embedded.Position + UP * (i * 10), {
						Count = 30,
						Size = 1.2,
						Speed = NumberRange.new(4, 12),
						Acceleration = Vector3.new(0, 25, 0),
						Lifetime = NumberRange.new(0.9, 1.6),
					})
				end)
			end
			VFX.animate(0.9, function(a)
				SpearModel.setFade(giant, a)
				giant.core.CFrame = embedded * CFrame.new(0, 0, -a * 6)
			end, function()
				giant.model:Destroy()
			end)
			if skyCircle then
				skyCircle:fade(0.8)
			end
		end)
	end)

	-- IMPACTO
	task.delay(impact, function()
		Sounds.play("SentenceImpact", target)
		Sounds.play("Explosion", target, { PlaybackSpeed = 0.35 })
		VFX.explosion(target + UP * 3, def.Radius, { Ground = target, Intensity = 2.6, Lightning = 14 })
		VFX.flash(target, def.Radius * 1.5, 0.9, C.Gold, 0.55)
		VFX.column(target, def.Radius * 0.55, 260, 0.08, 0.7)
		VFX.groundCracks(target, UP, 20, def.Radius * 1.1, 1.8)
		for i = 1, 3 do
			task.delay(i * 0.14, function()
				VFX.ring(groundCF(target) * CFrame.new(0, i * 0.02, 0), def.Radius * 0.4, def.Radius * (2.4 + i * 0.6), 0.8 + i * 0.15, i == 2 and C.White or C.Gold, 14 - i * 2)
			end)
		end
		for i = 1, 3 do
			task.delay(i * 0.1, function()
				VFX.ring(ringFacing(target + UP * (4 + i * 6), UP), 4, def.Radius * (1.2 + i * 0.3), 0.6, C.LightGold, 6)
			end)
		end
		VFX.light(target + UP * 6, C.Gold, 10, 60, 1.5)
	end)

	-- Pose da lança do jogador: sobe acima dele e canaliza
	local function above(now)
		local pos = Util.chest(root) + UP * 9
		return Util.lookAlong(pos, UP, r:base().LookVector) * CFrame.Angles(0, 0, now * 9)
	end
	if not ctx:moveTo(function()
		return above(os.clock())
	end, 0.5, Ease.outBack) then
		return
	end
	ctx:hold(function(now)
		return shakeSpear(above(now), now, 0.07)
	end)
	if not ctx:wait(impact - 0.5 - 0.55) then
		return
	end
	-- aponta para o alvo durante a descida da lança gigante
	local function pointAt()
		local pos = Util.chest(root) + UP * 9
		return Util.lookAlong(pos, (target - pos).Unit)
	end
	if not ctx:moveTo(pointAt, 0.25, Ease.outCubic) then
		return
	end
	ctx:hold(pointAt)
	if ctx:wait(0.3) then
		ctx:finish()
	end
end

---------------------------------------------------------------------------
-- PROJÉTEIS CELESTIAIS
---------------------------------------------------------------------------
local function castPoseFn(r, p, pullBack)
	return function()
		local cf = Util.castPose(r.root, p.aim, p.dir)
		return cf * CFrame.new(0, 0, pullBack or 0)
	end
end

local function fireFromPose(r, kind, p)
	local _, tip, dir = Util.castPose(r.root, p.aim, p.dir)
	Projectiles.fire(kind, tip, dir, { r.character })
end

-- Orbe que cresce na ponta durante a concentração de energia
local function chargeOrb(r, duration, maxSize)
	local orb = VFX.part({ Shape = Enum.PartType.Ball, Color = C.White, Size = Vector3.new(0.2, 0.2, 0.2) })
	local halo = VFX.part({ Shape = Enum.PartType.Ball, Color = C.Gold, Transparency = 0.5, Size = Vector3.new(0.4, 0.4, 0.4) })
	VFX.animate(duration, function(a)
		local tip = r:tipPosition()
		local s = 0.2 + maxSize * Ease.outQuad(a)
		orb.Size = Vector3.one * s
		halo.Size = Vector3.one * (s * 1.9 + math.sin(os.clock() * 30) * 0.1)
		orb.CFrame = CFrame.new(tip)
		halo.CFrame = CFrame.new(tip)
	end, function()
		orb:Destroy()
		halo:Destroy()
	end)
end

local function celestialBurst(r, p)
	local def = A.CelestialBurst
	local ctx = r:beginAction()
	r:setCharge(0.5)
	for i, delay in ipairs(def.ShotDelays) do
		task.delay(delay, function()
			Sounds.play("Projectile", r.refs.core, { PlaybackSpeed = 1.7 + i * 0.1 })
			fireFromPose(r, "CelestialBurst", p)
		end)
	end
	if not ctx:moveTo(castPoseFn(r, p, 0.6), 0.13, Ease.outQuad) then
		return
	end
	-- três estocadas rápidas, sincronizadas com cada disparo
	local start = os.clock() - 0.13
	ctx:hold(function(now)
		local t = now - start
		local pull = 0.6
		for _, delay in ipairs(def.ShotDelays) do
			local d = t - delay
			if d >= 0 and d < 0.12 then
				pull = 0.6 - 1.8 * math.sin(d / 0.12 * math.pi)
			end
		end
		return castPoseFn(r, p, pull)()
	end)
	if ctx:wait(def.Lock - 0.13) then
		ctx:finish()
	end
end

local function sacredPierce(r, p)
	local def = A.SacredPierce
	local ctx = r:beginAction()
	r:setCharge(1)
	Sounds.play("Charge", r.refs.core, { PlaybackSpeed = 0.9 })
	task.delay(0.12, function()
		chargeOrb(r, def.FireDelay - 0.12, 1.1)
		for i = 0, 3 do
			task.delay(i * 0.12, function()
				VFX.burst(r:tipPosition(), {
					Count = 10,
					Size = 0.35,
					Speed = NumberRange.new(-8, -4),
					Lifetime = NumberRange.new(0.2, 0.3),
					Drag = 0,
					Acceleration = Vector3.zero,
				})
			end)
		end
	end)
	task.delay(def.FireDelay, function()
		Sounds.play("ProjectileHeavy", r.refs.core)
		fireFromPose(r, "SacredPierce", p)
	end)
	if not ctx:moveTo(castPoseFn(r, p, 1), 0.2, Ease.outQuad) then
		return
	end
	local holdStart = os.clock()
	ctx:hold(function(now)
		return shakeSpear(castPoseFn(r, p, 1 + (now - holdStart) * 0.8)(), now, 0.03)
	end)
	if not ctx:wait(def.FireDelay - 0.2) then
		return
	end
	-- recuo do disparo
	if not ctx:moveTo(castPoseFn(r, p, 2.2), 0.08, Ease.outExpo) then
		return
	end
	if ctx:wait(0.05) then
		r:setCharge(0)
		ctx:finish()
	end
end

local function divineImpact(r, p)
	local def = A.DivineImpact
	local ctx = r:beginAction()
	r:setCharge(0.7)
	Sounds.play("Charge", r.refs.core, { PlaybackSpeed = 1.3 })
	task.delay(0.08, function()
		chargeOrb(r, def.FireDelay - 0.08, 1.6)
	end)
	task.delay(def.FireDelay, function()
		Sounds.play("ProjectileHeavy", r.refs.core, { PlaybackSpeed = 0.9 })
		fireFromPose(r, "DivineImpact", p)
	end)
	if not ctx:moveTo(castPoseFn(r, p, 0.6), 0.15, Ease.outQuad) then
		return
	end
	if not ctx:wait(def.FireDelay - 0.15) then
		return
	end
	if not ctx:moveTo(castPoseFn(r, p, 1.8), 0.08, Ease.outExpo) then
		return
	end
	if ctx:wait(0.1) then
		ctx:finish()
	end
end

---------------------------------------------------------------------------
-- Tabela pública
---------------------------------------------------------------------------
local handlers = {
	CelestialSlash = celestialSlash,
	FirmamentFall = firmamentFall,
	DivineRupture = divineRupture,
	GodsSentence = godsSentence,
	CelestialBurst = celestialBurst,
	SacredPierce = sacredPierce,
	DivineImpact = divineImpact,
}

function SpearActions.play(renderer, action, payload)
	if not renderer or renderer.destroyed or not renderer.root then
		return
	end
	if typeof(payload) ~= "table" or not Util.isFiniteVector(payload.dir) then
		return
	end
	payload.dir = payload.dir.Unit
	if not Util.isFiniteVector(payload.aim) then
		payload.aim = Util.chest(renderer.root) + payload.dir * 60
	end
	if not Util.isFiniteVector(payload.target) then
		payload.target = payload.aim
	end
	local fn
	if action == "Basic" then
		fn = Basic[payload.combo or 1]
	else
		fn = handlers[action]
	end
	if fn then
		task.spawn(fn, renderer, payload)
	end
end

return SpearActions
