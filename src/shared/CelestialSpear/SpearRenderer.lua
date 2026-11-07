--[[
	SpearRenderer — dá vida à lança de UM personagem (roda em cada cliente).

	• Levitação: flutua ao lado direito, sobe/desce suavemente, gira devagar.
	• Acompanhamento: suavização no espaço local do personagem (sem tremores,
	  acompanha corrida, pulo e queda sem ficar "presa" no ar).
	• Ações: cada ataque assume o controle da lança através de uma "pose"
	  avaliada a cada quadro; ao terminar, a lança voa de volta visivelmente.
	• Autoridade Celestial: aparência fica mais intensa (somente visual).
	• Equipar/Desequipar: materialização e dissolução em luz.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Util = require(script.Parent.Util)
local SpearModel = require(script.Parent.SpearModel)
local VFX = require(script.Parent.VFX)
local Sounds = require(script.Parent.Sounds)

local L = Config.Levitation
local C = Config.Colors

local SpearRenderer = {}
SpearRenderer.__index = SpearRenderer

---------------------------------------------------------------------------
-- Contexto de ação (usado por SpearActions)
---------------------------------------------------------------------------
local ActionContext = {}
ActionContext.__index = ActionContext

function ActionContext:alive()
	local r = self.renderer
	return not r.destroyed and r.token == self.token
end

function ActionContext:wait(t)
	if t and t > 0 then
		task.wait(t)
	end
	return self:alive()
end

-- Move a lança da posição atual até `target` (CFrame ou função → CFrame)
function ActionContext:moveTo(target, duration, ease)
	if not self:alive() then
		return false
	end
	local r = self.renderer
	local startCF = r.worldCF
	local t0 = os.clock()
	ease = ease or Util.Ease.outCubic
	r.pose = function(now)
		local a = Util.clamp01((now - t0) / duration)
		local goal = type(target) == "function" and target() or target
		return startCF:Lerp(goal, ease(a))
	end
	return self:wait(duration)
end

-- Trajetória arbitrária: fn(alpha) → CFrame
function ActionContext:path(fn, duration, ease)
	if not self:alive() then
		return false
	end
	local r = self.renderer
	local t0 = os.clock()
	ease = ease or Util.Ease.linear
	r.pose = function(now)
		return fn(ease(Util.clamp01((now - t0) / duration)))
	end
	return self:wait(duration)
end

-- Mantém a lança presa a uma pose (função → CFrame) até a próxima instrução
function ActionContext:hold(fn)
	if self:alive() then
		self.renderer.pose = fn
	end
end

function ActionContext:finish()
	if self:alive() then
		self.renderer:endAction()
	end
end

---------------------------------------------------------------------------
-- Renderer
---------------------------------------------------------------------------
function SpearRenderer.new(character, player)
	local self = setmetatable({}, SpearRenderer)
	self.character = character
	self.player = player or Players:GetPlayerFromCharacter(character)
	self.refs = SpearModel.build(1)
	self.model = self.refs.model
	self.root = Util.getRoot(character)
	self.time = math.random() * 10
	self.token = 0
	self.acting = false
	self.returning = true
	self.pose = nil
	self.fade = 1
	self.fadeTarget = 0
	self.charge = 0
	self.chargeTarget = 0
	self.authority = 0
	self.nextLightning = 0
	self.destroyed = false

	local idle = self:idleLocal()
	self.localCF = idle * CFrame.new(0, 0, -5) -- surge acima (eixo local da lança aponta para cima)
	self.worldCF = self.root and (Util.yawCFrame(self.root) * self.localCF) or CFrame.new()
	self.refs.core.CFrame = self.worldCF
	SpearModel.setFade(self.refs, 1)
	self.model.Parent = VFX.folder()

	self.hum = Sounds.loop("Hum", self.refs.core)

	-- animação de equipar: feixe de luz + materialização
	task.defer(function()
		if self.destroyed or not self.root then
			return
		end
		local pos = (Util.yawCFrame(self.root) * idle).Position
		Sounds.play("Equip", self.refs.core)
		VFX.flash(pos, 3, 0.4, C.White)
		VFX.burst(pos, { Count = 30, Size = 0.5, Speed = NumberRange.new(4, 12) })
		VFX.ring(CFrame.new(pos), 1, 7, 0.45, C.Gold, 8)
		VFX.column(pos - Vector3.new(0, 2, 0), 0.6, 18, 0.15, 0.25)
	end)

	self.conn = RunService.RenderStepped:Connect(function(dt)
		self:update(dt)
	end)
	return self
end

-- Pose de levitação (no espaço local "yaw" do personagem)
function SpearRenderer:idleLocal()
	local t = self.time
	local bob = math.sin(t * L.BobSpeed) * L.BobAmplitude
	local sway = math.sin(t * L.BobSpeed * 0.5) * math.rad(3)
	return CFrame.new(L.Offset + Vector3.new(0, bob, 0))
		* CFrame.Angles(0, 0, -math.rad(L.Tilt) + sway)
		* CFrame.Angles(math.pi / 2, 0, 0) -- ponta para cima
		* CFrame.Angles(0, 0, t * L.SpinSpeed) -- giro lento em torno do próprio eixo
end

function SpearRenderer:base()
	if self.root and self.root.Parent then
		return Util.yawCFrame(self.root)
	end
	return CFrame.new(self.worldCF.Position)
end

function SpearRenderer:tipPosition()
	return self.refs.core.CFrame * Vector3.new(0, 0, -Util.SPEAR_TIP_DISTANCE)
end

function SpearRenderer:setTrail(enabled)
	self.refs.trail.Enabled = enabled
end

function SpearRenderer:setCharge(value)
	self.chargeTarget = value
end

function SpearRenderer:beginAction()
	self.token = self.token + 1
	self.acting = true
	self.returning = false
	-- congela a pose atual até a nova ação definir a trajetória (combos sem saltos)
	local current = self.worldCF
	self.pose = function()
		return current
	end
	return setmetatable({ renderer = self, token = self.token }, ActionContext)
end

function SpearRenderer:endAction()
	self.acting = false
	self.pose = nil
	self.returning = true
	self.localCF = self:base():Inverse() * self.worldCF
	self:setTrail(false)
	self.chargeTarget = 0
end

function SpearRenderer:cancel()
	self.token = self.token + 1
	if self.acting then
		self:endAction()
	end
end

---------------------------------------------------------------------------
-- Atualização por quadro
---------------------------------------------------------------------------
function SpearRenderer:update(dt)
	if self.destroyed then
		return
	end
	if not self.root or not self.root.Parent then
		self.root = Util.getRoot(self.character)
		if not self.root then
			return
		end
	end
	self.time = self.time + dt

	local base = self:base()
	local idle = self:idleLocal()

	if self.acting and self.pose then
		local ok, cf = pcall(self.pose, os.clock())
		if ok and typeof(cf) == "CFrame" then
			self.worldCF = cf
		end
	else
		local sharp = self.returning and L.ReturnSharpness or L.FollowSharpness
		self.localCF = self.localCF:Lerp(idle, Util.smooth(sharp, dt))
		local delta = self.localCF.Position - idle.Position
		if self.returning then
			if delta.Magnitude < 0.35 then
				self.returning = false
			end
		elseif delta.Magnitude > L.MaxLagDistance then
			self.localCF = CFrame.new(idle.Position + delta.Unit * L.MaxLagDistance) * self.localCF.Rotation
		end
		self.worldCF = base * self.localCF
	end
	self.refs.core.CFrame = self.worldCF

	-- materializar / dissolver
	if self.fade ~= self.fadeTarget then
		local speed = dt / 0.4
		if self.fade < self.fadeTarget then
			self.fade = math.min(self.fadeTarget, self.fade + speed)
		else
			self.fade = math.max(self.fadeTarget, self.fade - speed)
		end
		SpearModel.setFade(self.refs, self.fade)
	end

	-- brilho do cristal (preparação de habilidades)
	self.charge = self.charge + (self.chargeTarget - self.charge) * Util.smooth(10, dt)

	self:updateAuthority(dt)
end

function SpearRenderer:updateAuthority(dt)
	local refs = self.refs
	local level = 0
	if self.player then
		level = self.player:GetAttribute(Util.AUTHORITY_ATTRIBUTE) or 0
	end
	self.authority = self.authority + (level - self.authority) * Util.smooth(6, dt)
	local a = self.authority
	local visible = 1 - self.fade
	local pulse = 0.5 + 0.5 * math.sin(self.time * 6)

	-- Nível 1: brilho dourado normal (base) — cresce um pouco com o nível e com a carga
	local charge = self.charge
	refs.crystalLight.Brightness = (1.4 + a * 0.5 + charge * 5) * visible
	refs.crystalLight.Range = 8 + a * 1.5 + charge * 10
	refs.crystalGlow.Size = Vector3.one * (0.75 + charge * 1.4 + a * 0.08 + pulse * 0.05 * (a + charge))
	refs.crystalGlow.Transparency = 1 - (0.18 + charge * 0.45 + a * 0.04) * visible
	refs.crystalCore.Color = C.Radiant:Lerp(C.White, math.min(1, charge + a * 0.15))

	-- Nível 2: runas começam a girar
	local orbit = a >= 1.5
	for i, rune in ipairs(refs.runes) do
		local angle, radius, z
		if orbit then
			angle = self.time * (2.4 + a * 0.4) + i * (math.pi / 2)
			radius = 1.25
			z = math.sin(self.time * 2 + i) * 0.8 - 0.4
			rune.gui.Brightness = 4
		else
			angle = self.time * 0.35 + i * (math.pi / 2)
			radius = 0.95 + math.sin(self.time * 1.3 + i) * 0.08
			z = -1.2 + i * 0.55
			rune.gui.Brightness = 2.5
		end
		rune.attachment.Position = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, z)
	end

	-- Nível 3: pequenos raios na haste
	if a >= 2.5 and visible > 0.5 and os.clock() >= self.nextLightning then
		self.nextLightning = os.clock() + 0.08 + math.random() * 0.18
		local cf = refs.core.CFrame
		local z0 = math.random() * 5 - 2.5
		local z1 = z0 + (math.random() < 0.5 and -1 or 1) * (0.8 + math.random() * 1.2)
		VFX.lightning(cf * Vector3.new(0, 0, z0), cf * Vector3.new(0, 0, z1), {
			Segments = 4,
			Offset = 0.22,
			Thickness = 0.06,
			Duration = 0.12,
		})
	end

	-- Nível 4: ponta extremamente brilhante
	local tipLevel = Util.clamp01(a - 3)
	refs.tipGlow.Transparency = 1 - tipLevel * (0.8 + 0.2 * pulse) * visible
	refs.tipGlow.Size = Vector3.one * (0.35 + tipLevel * (0.5 + pulse * 0.25))
	refs.tipLight.Brightness = tipLevel * 5 * visible
	refs.tipSparks.Rate = tipLevel * 45 * visible
	for _, shell in ipairs(refs.bladeShells) do
		shell.Transparency = 1 - (0.22 + tipLevel * 0.35) * visible
	end
end

---------------------------------------------------------------------------
-- Desequipar
---------------------------------------------------------------------------
function SpearRenderer:destroy(animated)
	if self.destroyed or (animated and self.unequipping) then
		return
	end
	if animated and self.root then
		self.unequipping = true
		self:cancel()
		self.fadeTarget = 1
		local pos = self.refs.core.Position
		Sounds.play("Unequip", pos)
		VFX.burst(pos, { Count = 35, Size = 0.5, Speed = NumberRange.new(3, 10), Acceleration = Vector3.new(0, 8, 0) })
		VFX.flash(pos, 2.5, 0.35, C.Gold, 0.3)
		-- sobe e se desfaz em luz
		local ctx = self:beginAction()
		local startCF = self.worldCF
		ctx:path(function(a)
			return startCF * CFrame.new(0, 0, -a * 3) * CFrame.Angles(0, 0, a * 8)
		end, 0.4, Util.Ease.outQuad)
		task.delay(0.42, function()
			self:destroy(false)
		end)
		return
	end
	self.destroyed = true
	if self.conn then
		self.conn:Disconnect()
	end
	if self.hum then
		self.hum:Destroy()
	end
	self.model:Destroy()
end

return SpearRenderer
