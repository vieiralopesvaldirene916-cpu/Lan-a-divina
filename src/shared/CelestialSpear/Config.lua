--[[
	⚜️ LANÇA DO JUÍZO CELESTIAL — Configuração central

	Todos os valores de equilíbrio (dano, alcance, tempos, custo de energia),
	teclas, cores e sons ficam aqui. Servidor e cliente leem o MESMO módulo,
	então qualquer ajuste vale para os dois lados automaticamente.
]]

local Config = {}

---------------------------------------------------------------------------
-- Identidade
---------------------------------------------------------------------------
Config.WeaponName = "Lança do Juízo Celestial"
Config.ToolTip = "Arma lendária • Flutua ao seu lado e obedece à sua mira"
Config.ToolTextureId = "" -- ícone da ferramenta na mochila (opcional, rbxassetid://...)

-- Entrega a arma automaticamente a todos os jogadores (StarterPack + mochila atual)
Config.GiveToolToEveryone = true

-- Cria bonecos de treino perto do spawn para testar a arma
Config.SpawnTrainingDummies = true
Config.TrainingDummyCount = 4
Config.TrainingDummyHealth = 600

---------------------------------------------------------------------------
-- Regras de combate
---------------------------------------------------------------------------
Config.PvPEnabled = true -- permite atingir outros jogadores
Config.TeamCheck = true -- não atinge jogadores do mesmo time (se Teams forem usados)
Config.FaceAttackDirection = true -- o personagem gira para a direção da mira ao atacar
Config.ShowCrosshair = true -- pequena mira no centro da tela (a mira é sempre manual)
Config.ShowDamageNumbers = true

-- Tolerância de rede do servidor (segundos) para validar tempos de recarga
Config.NetworkTolerance = 0.12

---------------------------------------------------------------------------
-- Cores (branco, dourado e amarelo luminoso)
---------------------------------------------------------------------------
Config.Colors = {
	White = Color3.fromRGB(255, 252, 240),
	Ivory = Color3.fromRGB(246, 240, 226),
	Gold = Color3.fromRGB(255, 196, 64),
	DeepGold = Color3.fromRGB(214, 150, 30),
	LightGold = Color3.fromRGB(255, 226, 140),
	Radiant = Color3.fromRGB(255, 244, 170),
	Crystal = Color3.fromRGB(255, 248, 205),
	UIBackground = Color3.fromRGB(22, 18, 12),
	UIDark = Color3.fromRGB(12, 10, 6),
}

---------------------------------------------------------------------------
-- Levitação
---------------------------------------------------------------------------
Config.Levitation = {
	Offset = Vector3.new(2.7, 1.1, 0.6), -- lado direito do jogador (X = direita, Y = cima, Z = trás)
	BobAmplitude = 0.22, -- movimento vertical suave
	BobSpeed = 1.7,
	SpinSpeed = 0.7, -- giro lento (rad/s)
	Tilt = 12, -- inclinação para fora (graus)
	FollowSharpness = 22, -- quanto maior, mais "colada" ao jogador (sem tremores)
	ReturnSharpness = 9, -- velocidade do retorno após um ataque (trajetória visível)
	MaxLagDistance = 7, -- nunca fica mais longe que isso da posição ideal
}

---------------------------------------------------------------------------
-- Essência Divina (energia)
---------------------------------------------------------------------------
Config.Essence = {
	Max = 100,
	Start = 100,
	RegenPerSecond = 7, -- regeneração lenta
	RegenDelay = 2.5, -- segundos sem atacar antes de regenerar
	HitGain = 1.5, -- energia por acerto
	StreakBonus = 0.5, -- bônus por acerto consecutivo
	StreakMaxBonusSteps = 4,
	StreakWindow = 2.5, -- tempo máximo entre acertos para manter a sequência
}

---------------------------------------------------------------------------
-- Autoridade Celestial (passiva exclusivamente visual)
---------------------------------------------------------------------------
Config.Authority = {
	MaxLevel = 4,
	ResetTime = 7, -- segundos sem usar habilidades para voltar ao normal
}

---------------------------------------------------------------------------
-- Ataque básico (M1 → M2 → M3, um golpe por clique)
---------------------------------------------------------------------------
Config.Basic = {
	ComboResetTime = 1.25, -- parar de atacar por esse tempo reinicia a sequência
	Steps = {
		[1] = { -- Estocada frontal
			Name = "Estocada Frontal",
			Damage = 12,
			Interval = 0.36, -- tempo mínimo até o próximo clique
			HitDelay = 0.2, -- momento do impacto na animação
			Range = 14,
			Radius = 3.4,
		},
		[2] = { -- Corte horizontal
			Name = "Corte Horizontal",
			Damage = 13,
			Interval = 0.4,
			HitDelay = 0.22,
			Range = 11.5,
			Angle = 80, -- meio ângulo do arco (graus)
		},
		[3] = { -- Ataque descendente
			Name = "Ataque Descendente",
			Damage = 18,
			Interval = 0.62, -- intervalo maior após fechar a sequência
			HitDelay = 0.34,
			Range = 10, -- distância máxima do ponto de impacto
			Radius = 7,
		},
	},
}

---------------------------------------------------------------------------
-- Habilidades
--   Cost      = Essência Divina consumida ("FULL" = exige a barra cheia)
--   Cooldown  = recarga (s)
--   Lock      = tempo em que a lança está ocupada (impede outra ação)
---------------------------------------------------------------------------
Config.Abilities = {
	CelestialSlash = {
		DisplayName = "Corte Celestial",
		Key = Enum.KeyCode.Q,
		Order = 1,
		Cost = 20,
		Cooldown = 5,
		Lock = 0.55,
		ReleaseDelay = 0.42,
		Damage = 28,
		Speed = 110,
		MaxDistance = 85,
		Width = 13, -- largura da lâmina de energia
		Thickness = 4,
	},
	FirmamentFall = {
		DisplayName = "Queda do Firmamento",
		Key = Enum.KeyCode.E,
		Order = 2,
		Cost = 30,
		Cooldown = 9,
		Lock = 1.15,
		ImpactDelay = 1.25,
		Damage = 42,
		Radius = 14,
		MaxRange = 90,
	},
	DivineRupture = {
		DisplayName = "Ruptura Divina",
		Key = Enum.KeyCode.R,
		Order = 3,
		Cost = 25,
		Cooldown = 8,
		Lock = 0.7,
		ImpactDelay = 0.56,
		Damage = 30,
		Radius = 21,
		ForwardOffset = 4,
		KnockbackHorizontal = 62,
		KnockbackVertical = 38,
	},
	GodsSentence = {
		DisplayName = "Sentença dos Deuses",
		Key = Enum.KeyCode.F,
		Order = 4,
		Cost = "FULL",
		Cooldown = 40,
		Lock = 2.9,
		ImpactDelay = 2.9,
		Damage = 125,
		EdgeDamageMultiplier = 0.6, -- dano na borda da explosão
		Radius = 32,
		MaxRange = 130,
		KnockbackHorizontal = 80,
		KnockbackVertical = 55,
		DarkenRadius = 400, -- jogadores dentro desse raio veem o céu escurecer
	},

	-- Projéteis Celestiais (ataques mágicos à distância)
	CelestialBurst = {
		DisplayName = "Rajada Celestial",
		Key = Enum.KeyCode.Z,
		Order = 5,
		Projectile = true,
		Cost = 12,
		Cooldown = 3,
		Lock = 0.6,
		ShotDelays = { 0.16, 0.31, 0.46 },
		Damage = 9,
		Speed = 170,
		Radius = 1.2,
		MaxDistance = 140,
	},
	SacredPierce = {
		DisplayName = "Perfuração Sagrada",
		Key = Enum.KeyCode.X,
		Order = 6,
		Projectile = true,
		Cost = 22,
		Cooldown = 6,
		Lock = 0.8,
		FireDelay = 0.62,
		Damage = 34,
		Speed = 360,
		Radius = 1.4,
		MaxDistance = 220,
		Pierce = 6, -- atravessa até N inimigos
	},
	DivineImpact = {
		DisplayName = "Impacto Divino",
		Key = Enum.KeyCode.C,
		Order = 7,
		Projectile = true,
		Cost = 22,
		Cooldown = 7,
		Lock = 0.5,
		FireDelay = 0.3,
		Damage = 14, -- dano direto
		ExplosionDamage = 26,
		ExplosionRadius = 12,
		Speed = 120,
		Radius = 1.8,
		MaxDistance = 160,
	},
}

-- Ordem dos botões na interface
Config.MainAbilityOrder = { "CelestialSlash", "FirmamentFall", "DivineRupture", "GodsSentence" }
Config.ProjectileOrder = { "CelestialBurst", "SacredPierce", "DivineImpact" }

---------------------------------------------------------------------------
-- Controles
---------------------------------------------------------------------------
Config.Keys = {
	Basic = { Enum.UserInputType.MouseButton1 }, -- clique esquerdo
	BasicKeyboard = Enum.KeyCode.T, -- alternativa no teclado
	BasicGamepad = Enum.KeyCode.ButtonR2,
	GamepadAbilities = {
		CelestialSlash = Enum.KeyCode.ButtonX,
		FirmamentFall = Enum.KeyCode.ButtonY,
		DivineRupture = Enum.KeyCode.ButtonB,
		GodsSentence = Enum.KeyCode.ButtonL2,
		CelestialBurst = Enum.KeyCode.DPadLeft,
		SacredPierce = Enum.KeyCode.DPadUp,
		DivineImpact = Enum.KeyCode.DPadRight,
	},
}

---------------------------------------------------------------------------
-- Sons
--   Deixe Id = "" para silenciar, ou coloque seu próprio "rbxassetid://123".
--   Os ids "rbxasset://sounds/..." são sons que já vêm com o Roblox e
--   funcionam como substitutos temporários.
---------------------------------------------------------------------------
Config.Sounds = {
	Equip = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.7, Pitch = 1.25 },
	Unequip = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5, Pitch = 0.8 },
	Hum = { Id = "", Volume = 0.25, Pitch = 1 }, -- zumbido contínuo da lança (loop)
	Whoosh = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.55, Pitch = 1.3 }, -- movimentação
	M1 = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.8, Pitch = 1.15 },
	M2 = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.8, Pitch = 1.05 },
	M3 = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.9, Pitch = 0.8 },
	Hit = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.6 },
	Charge = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.6 }, -- preparação
	Projectile = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.45, Pitch = 1.8 },
	ProjectileHeavy = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.7, Pitch = 1.2 },
	Impact = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7, Pitch = 1 },
	Explosion = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 1, Pitch = 0.45 },
	SlashWave = { Id = "rbxasset://sounds/swordslash.wav", Volume = 1, Pitch = 0.65 },
	Column = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.9, Pitch = 0.7 },
	Rupture = { Id = "rbxasset://sounds/collide.wav", Volume = 1, Pitch = 0.55 },
	SentencePrep = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Pitch = 0.35 },
	SentenceDescend = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 1, Pitch = 0.5 },
	SentenceImpact = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 1, Pitch = 0.3 },
	SentenceEnd = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.2 },
	UIPress = { Id = "", Volume = 0.4, Pitch = 1 },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function Config.GetAbility(name)
	return Config.Abilities[name]
end

function Config.GetCost(name)
	local ability = Config.Abilities[name]
	if not ability then
		return 0
	end
	if ability.Cost == "FULL" then
		return Config.Essence.Max
	end
	return ability.Cost
end

function Config.RequiresFull(name)
	local ability = Config.Abilities[name]
	return ability ~= nil and ability.Cost == "FULL"
end

return Config
