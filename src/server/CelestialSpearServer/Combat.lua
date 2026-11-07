--[[
	Combat — dano, detecção de acerto e empurrão (servidor).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CelestialSpear")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Combat = {}

local hitRemote
local onHitCallback

function Combat.init(remote, onHit)
	hitRemote = remote
	onHitCallback = onHit
end

---------------------------------------------------------------------------
-- Filtros
---------------------------------------------------------------------------
function Combat.canHit(attacker, model, humanoid)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if attacker.Character == model then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		if not Config.PvPEnabled then
			return false
		end
		if Config.TeamCheck and not attacker.Neutral and not victim.Neutral and attacker.Team ~= nil and attacker.Team == victim.Team then
			return false
		end
	end
	return true
end

local function rootOf(model, fallback)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or fallback
end

-- Todos os alvos válidos em uma esfera. Retorna { {humanoid, model, root} }
function Combat.collectTargets(attacker, center, radius, exclude)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { attacker.Character }
	if exclude then
		for model in pairs(exclude) do
			table.insert(list, model)
		end
	end
	params.FilterDescendantsInstances = list
	local seen = {}
	local targets = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, params)) do
		local humanoid, model = Util.findHumanoidFromPart(part)
		if humanoid and not seen[model] then
			seen[model] = true
			if Combat.canHit(attacker, model, humanoid) then
				table.insert(targets, { humanoid = humanoid, model = model, root = rootOf(model, part) })
			end
		end
	end
	return targets
end

---------------------------------------------------------------------------
-- Dano e empurrão
---------------------------------------------------------------------------
function Combat.damage(attacker, target, amount, hitPosition)
	local humanoid = target.humanoid
	if not Combat.canHit(attacker, target.model, humanoid) then
		return false
	end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = attacker
	tag.Parent = humanoid
	Debris:AddItem(tag, 2)
	humanoid:TakeDamage(amount)
	local pos = hitPosition or (target.root and target.root.Position) or Vector3.zero
	if hitRemote then
		hitRemote:FireAllClients(attacker, pos, amount)
	end
	if onHitCallback then
		onHitCallback(attacker)
	end
	return true
end

function Combat.knockback(target, velocity, duration)
	local root = target.root
	if not root or not root:IsA("BasePart") or root.Anchored then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "CelestialKnockback"
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.Parent = root
	Debris:AddItem(lv, duration or 0.18)
	Debris:AddItem(attachment, duration or 0.18)
end

-- Empurra para fora a partir de um centro
function Combat.radialKnockback(target, center, horizontal, vertical)
	if not target.root then
		return
	end
	local away = target.root.Position - center
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, 1)
	end
	Combat.knockback(target, away.Unit * horizontal + Vector3.new(0, vertical, 0), 0.2)
end

---------------------------------------------------------------------------
-- Formatos de acerto
---------------------------------------------------------------------------
local function distanceToSegment(p, a, b)
	local ab = b - a
	local t = 0
	if ab.Magnitude > 1e-4 then
		t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	end
	return (p - (a + ab * t)).Magnitude
end

-- Cápsula (estocada / perfuração)
function Combat.capsule(attacker, a, b, radius)
	local center = (a + b) / 2
	local reach = (b - a).Magnitude / 2 + radius + 3
	local result = {}
	for _, target in ipairs(Combat.collectTargets(attacker, center, reach)) do
		if distanceToSegment(target.root.Position, a, b) <= radius + 1.5 then
			table.insert(result, target)
		end
	end
	return result
end

-- Arco (corte)
function Combat.cone(attacker, origin, dir, range, halfAngleDeg)
	local cosLimit = math.cos(math.rad(halfAngleDeg))
	local result = {}
	for _, target in ipairs(Combat.collectTargets(attacker, origin, range + 2)) do
		local delta = target.root.Position - origin
		if delta.Magnitude < 3.5 or delta.Unit:Dot(dir) >= cosLimit then
			table.insert(result, target)
		end
	end
	return result
end

return Combat
