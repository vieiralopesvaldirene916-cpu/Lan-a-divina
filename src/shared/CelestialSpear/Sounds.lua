--[[
	Sounds — reprodução dos efeitos sonoros da lança.

	Os IDs ficam em Config.Sounds. Se um ID estiver vazio, o som é
	simplesmente ignorado (espaço preparado para inserir o áudio depois).
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)

local Sounds = {}

local function getFolder()
	local folder = workspace:FindFirstChild(require(script.Parent.Util).FX_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = require(script.Parent.Util).FX_FOLDER_NAME
		folder.Parent = workspace
	end
	return folder
end

local function makeSound(name, overrides)
	local def = Config.Sounds[name]
	if not def or def.Id == nil or def.Id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "CelestialSound_" .. name
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.6
	sound.PlaybackSpeed = def.Pitch or 1
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 260
	if overrides then
		for k, v in pairs(overrides) do
			sound[k] = v
		end
	end
	return sound
end

--[[
	Toca um som.
	where pode ser: BasePart/Attachment (som 3D preso ao objeto), Vector3
	(som 3D na posição) ou nil (som 2D, ouvido apenas pelo jogador local).
]]
function Sounds.play(name, where, overrides)
	local sound = makeSound(name, overrides)
	if not sound then
		return nil
	end
	local holder
	if typeof(where) == "Vector3" then
		holder = Instance.new("Part")
		holder.Name = "SoundEmitter"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(where)
		holder.Parent = getFolder()
		sound.Parent = holder
	elseif typeof(where) == "Instance" then
		sound.Parent = where
	else
		sound.Parent = SoundService
	end

	if sound.Parent == SoundService then
		SoundService:PlayLocalSound(sound)
	else
		sound:Play()
	end
	local life = 6
	if sound.TimeLength > 0 then
		life = sound.TimeLength / math.max(sound.PlaybackSpeed, 0.05) + 0.5
	end
	Debris:AddItem(holder or sound, life)
	return sound
end

-- Som contínuo (loop). Retorna o Sound para ser destruído depois.
function Sounds.loop(name, parent)
	local sound = makeSound(name, { Looped = true })
	if not sound then
		return nil
	end
	sound.Parent = parent
	sound:Play()
	return sound
end

return Sounds
