--[[
	Dummies — bonecos de treino para testar a lança (Config.SpawnTrainingDummies).
	Renascem automaticamente após serem derrotados.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CelestialSpear")
local Config = require(Shared.Config)

local Dummies = {}

local folder

local function part(model, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function build(home, index)
	local model = Instance.new("Model")
	model.Name = "Boneco de Treino " .. index

	local stone = Color3.fromRGB(205, 200, 190)
	local accent = Color3.fromRGB(150, 120, 70)
	local rootCF = home * CFrame.new(0, 3, 0)

	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), rootCF, stone)
	root.Transparency = 1
	root.CanCollide = false
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), rootCF, accent)
	local head = part(model, "Head", Vector3.new(2, 1, 1), rootCF * CFrame.new(0, 1.5, 0), stone)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local la = part(model, "Left Arm", Vector3.new(1, 2, 1), rootCF * CFrame.new(-1.5, 0, 0), stone)
	local ra = part(model, "Right Arm", Vector3.new(1, 2, 1), rootCF * CFrame.new(1.5, 0, 0), stone)
	local ll = part(model, "Left Leg", Vector3.new(1, 2, 1), rootCF * CFrame.new(-0.5, -2, 0), stone)
	local rl = part(model, "Right Leg", Vector3.new(1, 2, 1), rootCF * CFrame.new(0.5, -2, 0), stone)
	la.CanCollide = false
	ra.CanCollide = false

	for _, p in ipairs({ torso, head, la, ra, ll, rl }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = Config.TrainingDummyHealth
	humanoid.Health = Config.TrainingDummyHealth
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	humanoid.Died:Connect(function()
		task.wait(3)
		model:Destroy()
		build(home, index)
	end)

	-- volta para casa se for arremessado muito longe
	task.spawn(function()
		while model.Parent do
			task.wait(4)
			if model.Parent and humanoid.Health > 0 then
				local offset = (root.Position - rootCF.Position).Magnitude
				if offset > 50 or root.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
					root.AssemblyLinearVelocity = Vector3.zero
					model:PivotTo(rootCF)
				end
			end
		end
	end)
	return model
end

function Dummies.spawn()
	folder = workspace:FindFirstChild("BonecosDeTreino")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BonecosDeTreino"
		folder.Parent = workspace
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local origin = spawn and spawn.CFrame or CFrame.new(0, 0.5, 0)
	origin = CFrame.new(origin.Position + Vector3.new(0, (spawn and spawn.Size.Y / 2 or 0), 0))
	local count = Config.TrainingDummyCount
	for i = 1, count do
		local angle = math.rad(-40 + (i - 1) * (80 / math.max(count - 1, 1)))
		local pos = origin.Position + Vector3.new(math.sin(angle) * 30, 0, -math.cos(angle) * 30)
		-- encontra o chão
		local result = workspace:Raycast(pos + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0))
		if result then
			pos = result.Position
		end
		build(CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)), i)
	end
end

return Dummies
