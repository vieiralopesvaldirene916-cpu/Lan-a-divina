--[[
	⚜️ LANÇA DO JUÍZO CELESTIAL — Servidor (ServerScriptService)

	Responsável por:
	  • Criar a ferramenta e entregá-la aos jogadores
	  • Marcar quem está com a lança equipada (para todos verem a levitação)
	  • Validar cada comando: recarga, bloqueio, Essência Divina, alcance
	  • Detecção de acerto, dano, empurrão e projéteis (autoritativo)
	  • Essência Divina (consumo, regeneração, recuperação por acertos)
	  • Autoridade Celestial (nível visual por habilidades consecutivas)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPack = game:GetService("StarterPack")

local Shared = ReplicatedStorage:WaitForChild("CelestialSpear")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Combat = require(script.Combat)
local ServerProjectiles = require(script.ServerProjectiles)
local Dummies = require(script.Dummies)

local A = Config.Abilities
local UP = Vector3.yAxis

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local remoteFolder = Shared:FindFirstChild("Remotes") or Instance.new("Folder")
remoteFolder.Name = "Remotes"
remoteFolder.Parent = Shared

local function remote(name)
	local r = remoteFolder:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remoteFolder
	return r
end

local ActionRemote = remote("Action")
local BroadcastRemote = remote("Broadcast")
local RejectedRemote = remote("Rejected")
local HitRemote = remote("Hit")

---------------------------------------------------------------------------
-- Estado por jogador
---------------------------------------------------------------------------
local states = {}

local function newState(player)
	local state = {
		energy = Config.Essence.Start,
		lastAttack = -math.huge,
		lastBasic = -math.huge,
		combo = 0,
		basicReadyAt = 0,
		busyUntil = 0,
		readyAt = {},
		streak = 0,
		lastHit = -math.huge,
		authority = 0,
		lastAbility = -math.huge,
		lastSentEnergy = -1,
	}
	states[player] = state
	player:SetAttribute(Util.ESSENCE_ATTRIBUTE, state.energy)
	player:SetAttribute(Util.AUTHORITY_ATTRIBUTE, 0)
	return state
end

local function syncEnergy(player, state)
	local rounded = math.floor(state.energy * 10 + 0.5) / 10
	if rounded ~= state.lastSentEnergy then
		state.lastSentEnergy = rounded
		player:SetAttribute(Util.ESSENCE_ATTRIBUTE, rounded)
	end
end

local function setCooldown(player, action, duration)
	player:SetAttribute(Util.COOLDOWN_PREFIX .. action, workspace:GetServerTimeNow() + duration)
end

-- Acertos consecutivos recuperam um pouco de Essência Divina
local function onHit(attacker)
	local state = states[attacker]
	if not state then
		return
	end
	local E = Config.Essence
	local now = os.clock()
	if now - state.lastHit <= E.StreakWindow then
		state.streak = state.streak + 1
	else
		state.streak = 1
	end
	state.lastHit = now
	local bonus = math.min(state.streak - 1, E.StreakMaxBonusSteps) * E.StreakBonus
	state.energy = math.min(E.Max, state.energy + E.HitGain + bonus)
	syncEnergy(attacker, state)
end

Combat.init(HitRemote, onHit)

---------------------------------------------------------------------------
-- Ferramenta
---------------------------------------------------------------------------
local function makeTool()
	local tool = Instance.new("Tool")
	tool.Name = Config.WeaponName
	tool.RequiresHandle = false -- a lança nunca fica na mão
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true -- tocar/clicar na tela não ativa nada sozinho
	tool.ToolTip = Config.ToolTip
	tool.TextureId = Config.ToolTextureId
	tool:SetAttribute(Util.TOOL_ATTRIBUTE, true)
	return tool
end

local function hasTool(player)
	local function check(container)
		if not container then
			return false
		end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute(Util.TOOL_ATTRIBUTE) then
				return true
			end
		end
		return false
	end
	return check(player:FindFirstChildOfClass("Backpack")) or check(player.Character)
end

local function isEquipped(character)
	if not character then
		return false
	end
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute(Util.TOOL_ATTRIBUTE) == true
end

---------------------------------------------------------------------------
-- Personagens
---------------------------------------------------------------------------
local function onCharacter(player, character)
	local state = states[player]
	if state then
		state.authority = 0
		state.busyUntil = 0
		player:SetAttribute(Util.AUTHORITY_ATTRIBUTE, 0)
	end
	character:SetAttribute(Util.EQUIPPED_ATTRIBUTE, false)
	local function refresh()
		character:SetAttribute(Util.EQUIPPED_ATTRIBUTE, isEquipped(character))
	end
	character.ChildAdded:Connect(refresh)
	character.ChildRemoved:Connect(refresh)
	if Config.GiveToolToEveryone then
		task.delay(0.5, function()
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack and not hasTool(player) then
				makeTool().Parent = backpack
			end
		end)
	end
end

local function onPlayer(player)
	newState(player)
	if player.Character then
		onCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

-- A ferramenta fica no StarterPack (renasce com o jogador)
if Config.GiveToolToEveryone then
	if not StarterPack:FindFirstChild(Config.WeaponName) then
		makeTool().Parent = StarterPack
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

---------------------------------------------------------------------------
-- Habilidades (lógica de servidor)
---------------------------------------------------------------------------
local function groundParams(player)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { player.Character }
	local fx = workspace:FindFirstChild(Util.FX_FOLDER_NAME)
	if fx then
		table.insert(list, fx)
	end
	params.FilterDescendantsInstances = list
	return params
end

local function alive(player, character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return player.Character == character and humanoid and humanoid.Health > 0 and Util.getRoot(character) ~= nil
end

local Basic = {}

Basic[1] = function(player, character, root, p)
	local step = Config.Basic.Steps[1]
	task.delay(step.HitDelay, function()
		if not alive(player, character) then
			return
		end
		local chest = Util.chest(root)
		for _, target in ipairs(Combat.capsule(player, chest, chest + p.dir * step.Range, step.Radius)) do
			if Combat.damage(player, target, step.Damage, target.root.Position) then
				Combat.knockback(target, p.dir * 18 + UP * 6, 0.1)
			end
		end
	end)
end

Basic[2] = function(player, character, root, p)
	local step = Config.Basic.Steps[2]
	task.delay(step.HitDelay, function()
		if not alive(player, character) then
			return
		end
		for _, target in ipairs(Combat.cone(player, Util.chest(root), p.dir, step.Range, step.Angle)) do
			if Combat.damage(player, target, step.Damage, target.root.Position) then
				Combat.knockback(target, Util.flatten(p.dir) * 14 + UP * 5, 0.1)
			end
		end
	end)
end

Basic[3] = function(player, character, root, p)
	local step = Config.Basic.Steps[3]
	-- mesmo ponto calculado pela animação (raycast a partir do peito)
	local chest = Util.chest(root)
	local result = workspace:Raycast(chest, p.dir * step.Range, groundParams(player))
	local point = result and result.Position or (chest + p.dir * step.Range)
	task.delay(step.HitDelay, function()
		if not alive(player, character) then
			return
		end
		for _, target in ipairs(Combat.collectTargets(player, point, step.Radius)) do
			if Combat.damage(player, target, step.Damage, target.root.Position) then
				Combat.radialKnockback(target, point, 10, 20)
			end
		end
	end)
end

local Abilities = {}

function Abilities.CelestialSlash(player, character, root, p)
	local def = A.CelestialSlash
	local basis = Util.aimBasis(root, p.dir)
	task.delay(def.ReleaseDelay, function()
		if not alive(player, character) then
			return
		end
		local origin = Util.chest(root) + basis.LookVector * 3
		ServerProjectiles.crescent(player, origin, p.dir, basis.UpVector)
	end)
end

function Abilities.FirmamentFall(player, _character, _root, p)
	local def = A.FirmamentFall
	local target = p.target
	task.delay(def.ImpactDelay, function()
		if not states[player] then
			return
		end
		for _, t in ipairs(Combat.collectTargets(player, target, def.Radius)) do
			if Combat.damage(player, t, def.Damage, t.root.Position) then
				Combat.radialKnockback(t, target, 20, 30)
			end
		end
	end)
end

function Abilities.DivineRupture(player, _character, root, p)
	local def = A.DivineRupture
	local flat = Util.flatten(p.dir)
	local point = root.Position + flat * def.ForwardOffset
	local target = Util.groundBelow(point, groundParams(player), 12) or (point - Vector3.new(0, 3, 0))
	task.delay(def.ImpactDelay, function()
		if not states[player] then
			return
		end
		for _, t in ipairs(Combat.collectTargets(player, target, def.Radius)) do
			if math.abs(t.root.Position.Y - target.Y) <= 14 then
				if Combat.damage(player, t, def.Damage, t.root.Position) then
					Combat.radialKnockback(t, target, def.KnockbackHorizontal, def.KnockbackVertical)
				end
			end
		end
	end)
end

function Abilities.GodsSentence(player, _character, _root, p)
	local def = A.GodsSentence
	local target = p.target
	task.delay(def.ImpactDelay, function()
		if not states[player] then
			return
		end
		for _, t in ipairs(Combat.collectTargets(player, target, def.Radius)) do
			local dist = (t.root.Position - target).Magnitude
			local falloff = Util.lerp(1, def.EdgeDamageMultiplier, math.clamp(dist / def.Radius, 0, 1))
			if Combat.damage(player, t, def.Damage * falloff, t.root.Position) then
				Combat.radialKnockback(t, target, def.KnockbackHorizontal, def.KnockbackVertical)
			end
		end
	end)
end

local function fireAfter(player, character, root, p, kind, delay)
	task.delay(delay, function()
		if not alive(player, character) then
			return
		end
		local _, tip, dir = Util.castPose(root, p.aim, p.dir)
		ServerProjectiles.fire(player, kind, tip, dir)
	end)
end

function Abilities.CelestialBurst(player, character, root, p)
	for _, delay in ipairs(A.CelestialBurst.ShotDelays) do
		fireAfter(player, character, root, p, "CelestialBurst", delay)
	end
end

function Abilities.SacredPierce(player, character, root, p)
	fireAfter(player, character, root, p, "SacredPierce", A.SacredPierce.FireDelay)
end

function Abilities.DivineImpact(player, character, root, p)
	fireAfter(player, character, root, p, "DivineImpact", A.DivineImpact.FireDelay)
end

---------------------------------------------------------------------------
-- Validação dos comandos
---------------------------------------------------------------------------
local function reject(player, action)
	RejectedRemote:FireClient(player, action)
end

local function broadcast(player, action, payload)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			BroadcastRemote:FireClient(other, player, action, payload)
		end
	end
end

ActionRemote.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" or type(payload) ~= "table" then
		return
	end
	local state = states[player]
	local character = player.Character
	if not state or not character or not isEquipped(character) or not alive(player, character) then
		reject(player, action)
		return
	end
	local root = Util.getRoot(character)

	-- direção (câmera) e ponto mirado
	local dir = payload.dir
	if not Util.isFiniteVector(dir) or dir.Magnitude < 0.5 then
		reject(player, action)
		return
	end
	dir = dir.Unit
	local chest = Util.chest(root)
	local aim = payload.aim
	if not Util.isFiniteVector(aim) then
		aim = chest + dir * 60
	end
	aim = Util.clampRange(chest, aim, 1200)

	local now = os.clock()
	local tol = Config.NetworkTolerance

	if action == "Basic" then
		local index = (now - state.lastBasic > Config.Basic.ComboResetTime) and 1 or (state.combo % 3) + 1
		local step = Config.Basic.Steps[index]
		if now < state.basicReadyAt - tol or now < state.busyUntil - tol then
			reject(player, action)
			return
		end
		state.combo = index
		state.lastBasic = now
		state.lastAttack = now
		state.basicReadyAt = now + step.Interval
		state.busyUntil = now + step.Interval * 0.9
		setCooldown(player, "Basic", step.Interval)
		local p = { dir = dir, aim = aim, combo = index }
		broadcast(player, "Basic", p)
		Basic[index](player, character, root, p)
		return
	end

	local def = A[action]
	local handler = Abilities[action]
	if not def or not handler then
		return
	end
	if now < (state.readyAt[action] or 0) - tol or now < state.busyUntil - tol then
		reject(player, action)
		return
	end
	local cost = Config.GetCost(action)
	if state.energy < cost - 0.01 then
		reject(player, action)
		return
	end

	-- ponto alvo das habilidades de área (sem mira automática: usa o ponto enviado)
	local target
	if def.MaxRange then
		target = payload.target
		if not Util.isFiniteVector(target) then
			target = Util.groundBelow(Util.clampRange(chest, aim, def.MaxRange), groundParams(player), 400)
				or Util.clampRange(chest, aim, def.MaxRange)
		end
		target = Util.clampRange(chest, target, def.MaxRange + 15)
	end

	state.energy = math.max(0, state.energy - cost)
	syncEnergy(player, state)
	state.readyAt[action] = now + def.Cooldown
	state.busyUntil = now + def.Lock
	state.lastAttack = now
	setCooldown(player, action, def.Cooldown)

	-- Autoridade Celestial (visual): sobe a cada habilidade consecutiva
	state.authority = math.min(Config.Authority.MaxLevel, state.authority + 1)
	state.lastAbility = now
	player:SetAttribute(Util.AUTHORITY_ATTRIBUTE, state.authority)

	local p = { dir = dir, aim = aim, target = target }
	broadcast(player, action, p)
	handler(player, character, root, p)
end)

---------------------------------------------------------------------------
-- Regeneração de Essência Divina e fim da Autoridade Celestial
---------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local E = Config.Essence
	for player, state in pairs(states) do
		if state.energy < E.Max and now - state.lastAttack >= E.RegenDelay then
			state.energy = math.min(E.Max, state.energy + E.RegenPerSecond * dt)
			syncEnergy(player, state)
		end
		if state.authority > 0 and now - state.lastAbility >= Config.Authority.ResetTime then
			state.authority = 0
			player:SetAttribute(Util.AUTHORITY_ATTRIBUTE, 0)
		end
	end
end)

---------------------------------------------------------------------------
-- Inicialização
---------------------------------------------------------------------------
if Config.SpawnTrainingDummies then
	task.defer(Dummies.spawn)
end

print("[Lança do Juízo Celestial] servidor pronto.")
