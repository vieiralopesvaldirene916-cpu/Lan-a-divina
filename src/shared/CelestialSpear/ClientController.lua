--[[
	ClientController — lado do cliente da Lança do Juízo Celestial.

	• Renderiza a lança de TODOS os jogadores que estiverem com ela equipada
	  (levitação e ataques são animados localmente = movimento sem tremores)
	• Lê os comandos do jogador (mouse/teclado, toque, controle)
	• A CÂMERA define a direção; ela NUNCA dispara ataques sozinha
	• Sem mira automática: o ponto mirado é exatamente o centro da câmera
	• Predição local: a animação começa no mesmo quadro do clique, e o
	  servidor valida recarga/energia e aplica o dano
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = script.Parent
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local VFX = require(Shared.VFX)
local Sounds = require(Shared.Sounds)
local SpearRenderer = require(Shared.SpearRenderer)
local SpearActions = require(Shared.SpearActions)
local CombatUI = require(Shared.CombatUI)

local LocalPlayer = Players.LocalPlayer

local ClientController = {}

local remotes
local renderers = {} -- [character] = SpearRenderer
local ui
local equipped = false

-- estado local (predição)
local localCooldownEnd = {} -- [action] = tempo do servidor
local busyUntil = 0
local lastBasicTime = -math.huge
local comboIndex = 0 -- último golpe executado

local function serverNow()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- Renderização das lanças
---------------------------------------------------------------------------
local function refreshCharacter(character)
	local isEquipped = character:GetAttribute(Util.EQUIPPED_ATTRIBUTE) == true
	local current = renderers[character]
	if isEquipped and not current then
		renderers[character] = SpearRenderer.new(character, Players:GetPlayerFromCharacter(character))
	elseif not isEquipped and current then
		renderers[character] = nil
		current:destroy(true)
	end
end

local function watchCharacter(character)
	refreshCharacter(character)
	character:GetAttributeChangedSignal(Util.EQUIPPED_ATTRIBUTE):Connect(function()
		refreshCharacter(character)
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent and renderers[character] then
			renderers[character]:destroy(false)
			renderers[character] = nil
		end
	end)
end

local function watchPlayer(player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

local function getRenderer(player)
	return player and player.Character and renderers[player.Character]
end

---------------------------------------------------------------------------
-- Mira (centro da câmera)
---------------------------------------------------------------------------
local function aimParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character, VFX.folder() }
	return params
end

local function computeAim(root)
	local camera = workspace.CurrentCamera
	local camCF = camera.CFrame
	local look = camCF.LookVector
	local params = aimParams()
	local result = workspace:Raycast(camCF.Position, look * 1000, params)
	local aim = result and result.Position or (camCF.Position + look * 1000)
	local chest = Util.chest(root)
	local toAim = aim - chest
	local dir
	-- se o ponto mirado estiver colado/atrás do jogador, usa a direção da câmera
	if toAim.Magnitude < 4 or toAim.Unit:Dot(look) < 0.2 then
		dir = look
		aim = chest + look * 60
	else
		dir = toAim.Unit
	end
	return dir, aim, params
end

-- Ponto no chão para habilidades de área (Queda do Firmamento / Sentença)
local function computeGroundTarget(root, aim, maxRange, params)
	local chest = Util.chest(root)
	local point = Util.clampRange(chest, aim, maxRange)
	local ground = Util.groundBelow(point, params, 400)
	return ground or point
end

---------------------------------------------------------------------------
-- Estado / recargas
---------------------------------------------------------------------------
local function cooldownTotal(action)
	if action == "Basic" then
		local step = Config.Basic.Steps[math.max(comboIndex, 1)]
		return step.Interval
	end
	return Config.Abilities[action].Cooldown
end

local function cooldownRemaining(action)
	local attr = LocalPlayer:GetAttribute(Util.COOLDOWN_PREFIX .. action) or 0
	local finish = math.max(attr, localCooldownEnd[action] or 0)
	return math.max(0, finish - serverNow())
end

local function getEnergy()
	return LocalPlayer:GetAttribute(Util.ESSENCE_ATTRIBUTE) or 0, Config.Essence.Max
end

local function nextCombo()
	if os.clock() - lastBasicTime > Config.Basic.ComboResetTime then
		return 1
	end
	return (comboIndex % 3) + 1
end

local function faceDirection(root, dir)
	if Config.FaceAttackDirection then
		local flat = Util.flatten(dir)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

---------------------------------------------------------------------------
-- Ações
---------------------------------------------------------------------------
local function tryBasic()
	if not equipped then
		return
	end
	local character = LocalPlayer.Character
	local root = Util.getRoot(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < busyUntil or cooldownRemaining("Basic") > 0 then
		return
	end
	local index = nextCombo()
	local step = Config.Basic.Steps[index]
	comboIndex = index
	lastBasicTime = now
	busyUntil = now + step.Interval * 0.9
	localCooldownEnd.Basic = serverNow() + step.Interval

	local dir, aim = computeAim(root)
	faceDirection(root, dir)
	local payload = { dir = dir, aim = aim, combo = index }
	SpearActions.play(renderers[character], "Basic", {
		dir = dir,
		aim = aim,
		combo = index,
	})
	if ui then
		ui:pressFeedback("Basic", true)
	end
	remotes.Action:FireServer("Basic", payload)
end

local function tryAbility(name)
	if not equipped then
		return
	end
	local def = Config.Abilities[name]
	if not def then
		return
	end
	local character = LocalPlayer.Character
	local root = Util.getRoot(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local energy = getEnergy()
	if now < busyUntil or cooldownRemaining(name) > 0 or energy < Config.GetCost(name) - 0.01 then
		if ui then
			ui:pressFeedback(name, false)
		end
		return
	end
	busyUntil = now + def.Lock
	localCooldownEnd[name] = serverNow() + def.Cooldown

	local dir, aim, params = computeAim(root)
	local payload = { dir = dir, aim = aim }
	if def.MaxRange then
		payload.target = computeGroundTarget(root, aim, def.MaxRange, params)
	end
	faceDirection(root, dir)
	SpearActions.play(renderers[character], name, {
		dir = payload.dir,
		aim = payload.aim,
		target = payload.target,
	})
	if ui then
		ui:pressFeedback(name, true)
	end
	remotes.Action:FireServer(name, payload)
end

---------------------------------------------------------------------------
-- Entrada (computador / controle)
---------------------------------------------------------------------------
local keyToAbility = {}
local padToAbility = {}
for name, def in pairs(Config.Abilities) do
	if def.Key then
		keyToAbility[def.Key] = name
	end
end
for name, key in pairs(Config.Keys.GamepadAbilities) do
	padToAbility[key] = name
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed or not equipped then
		return
	end
	for _, inputType in ipairs(Config.Keys.Basic) do
		if input.UserInputType == inputType then
			tryBasic()
			return
		end
	end
	if input.KeyCode == Config.Keys.BasicKeyboard or input.KeyCode == Config.Keys.BasicGamepad then
		tryBasic()
		return
	end
	local ability = keyToAbility[input.KeyCode] or padToAbility[input.KeyCode]
	if ability then
		tryAbility(ability)
	end
end

---------------------------------------------------------------------------
-- Ferramenta equipada (jogador local)
---------------------------------------------------------------------------
local function setEquipped(value)
	equipped = value
	if ui then
		ui:setVisible(value)
	end
end

local function watchLocalCharacter(character)
	setEquipped(false)
	busyUntil = 0
	local function check()
		local tool = character:FindFirstChildOfClass("Tool")
		setEquipped(tool ~= nil and tool:GetAttribute(Util.TOOL_ATTRIBUTE) == true)
	end
	character.ChildAdded:Connect(check)
	character.ChildRemoved:Connect(check)
	check()
end

---------------------------------------------------------------------------
-- Inicialização
---------------------------------------------------------------------------
function ClientController.start()
	remotes = Shared:WaitForChild("Remotes")
	remotes = {
		Action = remotes:WaitForChild("Action"),
		Broadcast = remotes:WaitForChild("Broadcast"),
		Rejected = remotes:WaitForChild("Rejected"),
		Hit = remotes:WaitForChild("Hit"),
	}

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	ui = CombatUI.new(LocalPlayer, {
		onBasic = tryBasic,
		onAbility = tryAbility,
		getEnergy = getEnergy,
		getCooldown = function(name)
			return cooldownRemaining(name), cooldownTotal(name)
		end,
		getAuthority = function()
			return LocalPlayer:GetAttribute(Util.AUTHORITY_ATTRIBUTE) or 0
		end,
		getCombo = nextCombo,
	})

	if LocalPlayer.Character then
		watchLocalCharacter(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(watchLocalCharacter)

	UserInputService.InputBegan:Connect(onInputBegan)

	-- Ataques de outros jogadores
	remotes.Broadcast.OnClientEvent:Connect(function(player, action, payload)
		if player == LocalPlayer then
			return
		end
		SpearActions.play(getRenderer(player), action, payload)
	end)

	-- Servidor recusou a ação (raro: atraso de rede / energia)
	remotes.Rejected.OnClientEvent:Connect(function(action)
		localCooldownEnd[action] = 0
		busyUntil = 0
		local r = getRenderer(LocalPlayer)
		if r then
			r:cancel()
		end
		if ui then
			ui:pressFeedback(action, false)
		end
	end)

	-- Confirmação de acerto (faíscas para todos, números de dano para quem acertou)
	remotes.Hit.OnClientEvent:Connect(function(attacker, position, damage)
		if typeof(position) ~= "Vector3" then
			return
		end
		VFX.hitSpark(position)
		Sounds.play("Hit", position)
		if attacker == LocalPlayer and Config.ShowDamageNumbers and type(damage) == "number" then
			VFX.damageNumber(position, damage)
		end
	end)
end

return ClientController
