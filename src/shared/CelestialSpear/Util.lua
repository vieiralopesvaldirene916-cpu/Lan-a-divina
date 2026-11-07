--[[
	Funções matemáticas e utilitárias compartilhadas entre servidor e cliente.
	Mantê-las em um único lugar garante que a animação vista pelo jogador e a
	detecção de acerto do servidor usem exatamente as mesmas posições.
]]

local Util = {}

Util.SPEAR_TIP_DISTANCE = 4.3 -- distância do centro (cristal) até a ponta
Util.SPEAR_BUTT_DISTANCE = 3.6 -- distância do centro até a extremidade traseira
Util.CHEST_OFFSET = Vector3.new(0, 0.9, 0)
Util.CAST_OFFSET = Vector3.new(2.1, 1.5, -0.8) -- pose da lança ao disparar projéteis

Util.FX_FOLDER_NAME = "CelestialSpearFX"
Util.EQUIPPED_ATTRIBUTE = "CelestialSpearEquipped"
Util.TOOL_ATTRIBUTE = "IsCelestialSpear"
Util.ESSENCE_ATTRIBUTE = "DivineEssence"
Util.AUTHORITY_ATTRIBUTE = "CelestialAuthority"
Util.COOLDOWN_PREFIX = "CelestialCD_"

---------------------------------------------------------------------------
-- Matemática
---------------------------------------------------------------------------
function Util.clamp01(x)
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

-- Fator de suavização independente da taxa de quadros
function Util.smooth(sharpness, dt)
	return 1 - math.exp(-sharpness * dt)
end

Util.Ease = {
	linear = function(t)
		return t
	end,
	outQuad = function(t)
		return 1 - (1 - t) * (1 - t)
	end,
	inQuad = function(t)
		return t * t
	end,
	inOutQuad = function(t)
		if t < 0.5 then
			return 2 * t * t
		end
		return 1 - ((-2 * t + 2) ^ 2) / 2
	end,
	outCubic = function(t)
		return 1 - (1 - t) ^ 3
	end,
	inCubic = function(t)
		return t * t * t
	end,
	outBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
	end,
	inBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return c3 * t * t * t - c1 * t * t
	end,
	outExpo = function(t)
		if t >= 1 then
			return 1
		end
		return 1 - 2 ^ (-10 * t)
	end,
	inExpo = function(t)
		if t <= 0 then
			return 0
		end
		return 2 ^ (10 * t - 10)
	end,
}

function Util.flatten(v)
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- CFrame na posição do HumanoidRootPart, girado apenas no eixo Y
function Util.yawCFrame(rootPart)
	local look = Util.flatten(rootPart.CFrame.LookVector)
	local pos = rootPart.Position
	return CFrame.lookAt(pos, pos + look)
end

function Util.chest(rootPart)
	return rootPart.Position + Util.CHEST_OFFSET
end

-- CFrame olhando na direção `dir`, com um vetor "up" seguro
function Util.lookAlong(position, dir, up)
	dir = dir.Unit
	up = up or Vector3.yAxis
	if math.abs(dir:Dot(up)) > 0.98 then
		up = Vector3.zAxis
	end
	return CFrame.lookAt(position, position + dir, up)
end

-- Base usada pelos ataques: posição do peito, olhando para a mira (inclui inclinação)
function Util.aimBasis(rootPart, dir)
	return Util.lookAlong(Util.chest(rootPart), dir)
end

-- Direção do ataque a partir de uma origem até o ponto mirado.
function Util.resolveDirection(origin, aimPoint, fallbackDir)
	if typeof(aimPoint) == "Vector3" then
		local delta = aimPoint - origin
		if delta.Magnitude > 0.5 then
			return delta.Unit
		end
	end
	if typeof(fallbackDir) == "Vector3" and fallbackDir.Magnitude > 0.01 then
		return fallbackDir.Unit
	end
	return Vector3.new(0, 0, -1)
end

-- Pose da lança ao disparar projéteis (mesma no cliente e no servidor)
function Util.castPose(rootPart, aimPoint, fallbackDir)
	local center = Util.yawCFrame(rootPart) * Util.CAST_OFFSET
	local dir = Util.resolveDirection(center, aimPoint, fallbackDir)
	local cf = Util.lookAlong(center, dir)
	return cf, cf.Position + dir * Util.SPEAR_TIP_DISTANCE, dir
end

-- Validação de vetores vindos da rede
function Util.isFiniteVector(v)
	if typeof(v) ~= "Vector3" then
		return false
	end
	local x, y, z = v.X, v.Y, v.Z
	return x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6
end

---------------------------------------------------------------------------
-- Personagens
---------------------------------------------------------------------------
function Util.getRoot(character)
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

function Util.findHumanoidFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

-- Raycast para baixo procurando o chão
function Util.groundBelow(position, params, depth)
	depth = depth or 200
	local result = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -(depth + 4), 0), params)
	if result then
		return result.Position, result.Normal
	end
	return nil, nil
end

-- Limita um ponto mirado ao alcance máximo
function Util.clampRange(origin, point, maxRange)
	local delta = point - origin
	if delta.Magnitude > maxRange then
		return origin + delta.Unit * maxRange
	end
	return point
end

return Util
