--[[
	⚜️ Lança do Juízo Celestial — LocalScript (StarterPlayerScripts)
	Apenas inicia o controlador do cliente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CelestialSpear = ReplicatedStorage:WaitForChild("CelestialSpear")
local ClientController = require(CelestialSpear:WaitForChild("ClientController"))

ClientController.start()
