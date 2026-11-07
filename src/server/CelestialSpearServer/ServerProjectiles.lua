--[[
	ServerProjectiles — simulação autoritativa dos projéteis (dano).
	Mesma origem, direção, velocidade e alcance usados pelos visuais.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CelestialSpear")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Combat = require(script.Parent.Combat)

local ServerProjectiles = {}

local function baseParams(attacker, extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { attacker.Character }
	for _, inst in ipairs(extra or {}) do
		table.insert(list, inst)
	end
	local fx = workspace:FindFirstChild(Util.FX_FOLDER_NAME)
	if fx then
		table.insert(list, fx)
	end
	params.FilterDescendantsInstances = list
	return params, list
end

local function explode(attacker, def, position)
	for _, target in ipairs(Combat.collectTargets(attacker, position, def.ExplosionRadius)) do
		if Combat.damage(attacker, target, def.ExplosionDamage, target.root.Position) then
			Combat.radialKnockback(target, position, 35, 22)
		end
	end
end

--[[
	Projéteis: CelestialBurst, SacredPierce, DivineImpact
]]
function ServerProjectiles.fire(attacker, kind, origin, direction)
	local def = Config.Abilities[kind]
	if not def then
		return
	end
	direction = direction.Unit
	local params, list = baseParams(attacker)
	local position = origin
	local travelled = 0
	local pierceLeft = def.Pierce or 0
	local hitModels = {}
	local conn

	local function stop(at, hitSomething)
		conn:Disconnect()
		if kind == "DivineImpact" and (hitSomething or travelled >= def.MaxDistance - 0.01) then
			explode(attacker, def, at)
		end
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		local step = math.min(def.Speed * dt, def.MaxDistance - travelled)
		local from = position
		local remaining = step
		while remaining > 0.01 do
			local result = workspace:Spherecast(from, def.Radius, direction * remaining, params)
			if not result then
				break
			end
			local humanoid, model = Util.findHumanoidFromPart(result.Instance)
			if humanoid and not hitModels[model] then
				hitModels[model] = true
				table.insert(list, model)
				params.FilterDescendantsInstances = list
				local target = { humanoid = humanoid, model = model, root = model:FindFirstChild("HumanoidRootPart") or result.Instance }
				Combat.damage(attacker, target, def.Damage, result.Position)
				if kind == "SacredPierce" then
					Combat.knockback(target, direction * 30 + Vector3.new(0, 10, 0), 0.12)
				end
				if pierceLeft > 0 then
					pierceLeft = pierceLeft - 1
					local advanced = (result.Position - from):Dot(direction)
					remaining = remaining - math.max(advanced, 0.05)
					from = from + direction * math.max(advanced, 0.05)
				else
					stop(result.Position, true)
					return
				end
			elseif humanoid then
				-- já atingido: ignora
				table.insert(list, model)
				params.FilterDescendantsInstances = list
			else
				stop(result.Position, true)
				return
			end
		end
		position = position + direction * step
		travelled = travelled + step
		if travelled >= def.MaxDistance - 0.01 then
			stop(position, false)
		end
	end)
end

--[[
	Lâmina de energia do Corte Celestial: viaja e atinge cada inimigo uma vez.
]]
function ServerProjectiles.crescent(attacker, origin, direction, up)
	local def = Config.Abilities.CelestialSlash
	local basis = Util.lookAlong(origin, direction, up)
	local params = baseParams(attacker)
	local travelled = 0
	local hit = {}
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = def.Speed * dt
		local pos = basis.Position + direction * travelled
		-- paredes param a lâmina (personagens não)
		local wall = workspace:Raycast(pos, direction * (step + 1), params)
		while wall and Util.findHumanoidFromPart(wall.Instance) do
			local _, model = Util.findHumanoidFromPart(wall.Instance)
			local list = params.FilterDescendantsInstances
			table.insert(list, model)
			params.FilterDescendantsInstances = list
			wall = workspace:Raycast(pos, direction * (step + 1), params)
		end
		local nextPos = pos + direction * step
		local center = (pos + nextPos) / 2
		for _, target in ipairs(Combat.collectTargets(attacker, center, def.Width / 2 + step + 3, hit)) do
			local rel = basis:PointToObjectSpace(target.root.Position)
			local along = -rel.Z - travelled - step / 2
			if math.abs(rel.X) <= def.Width / 2 + 1.5 and math.abs(rel.Y) <= def.Thickness + 2.5 and math.abs(along) <= step / 2 + 3 then
				hit[target.model] = true
				if Combat.damage(attacker, target, def.Damage, target.root.Position) then
					Combat.knockback(target, direction * 28 + Vector3.new(0, 12, 0), 0.15)
				end
			end
		end
		travelled = travelled + step
		if wall or travelled >= def.MaxDistance then
			conn:Disconnect()
		end
	end)
end

return ServerProjectiles
