--[[
	Sigil — desenho vetorial com elementos de interface.

	Runas, círculos mágicos e ícones são montados com Frames + UICorner +
	UIStroke. Assim a arma não depende de nenhuma imagem enviada ao Roblox e
	os desenhos permanecem nítidos em qualquer resolução.
]]

local Sigil = {}

local function baseFrame(parent, props)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	for k, v in pairs(props or {}) do
		frame[k] = v
	end
	frame.Parent = parent
	return frame
end

-- Contorno circular. `size` em escala do pai (0..1)
function Sigil.ring(parent, size, color, thickness, transparency)
	local frame = baseFrame(parent, {
		Name = "Ring",
		Size = UDim2.fromScale(size, size),
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = frame
	return frame, stroke
end

-- Círculo preenchido
function Sigil.disc(parent, size, color, transparency, position)
	local frame = baseFrame(parent, {
		Name = "Disc",
		Size = UDim2.fromScale(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		Position = position or UDim2.fromScale(0.5, 0.5),
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = frame
	return frame
end

-- Quadrado girado (losango) apenas com contorno
function Sigil.diamond(parent, size, color, thickness, rotation, transparency)
	local frame = baseFrame(parent, {
		Name = "Diamond",
		Size = UDim2.fromScale(size, size),
		Rotation = rotation or 45,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.Parent = frame
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = frame
	return frame, stroke
end

-- Losango preenchido
function Sigil.solidDiamond(parent, size, color, position, transparency)
	local frame = baseFrame(parent, {
		Name = "SolidDiamond",
		Size = UDim2.fromScale(size, size),
		Rotation = 45,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		Position = position or UDim2.fromScale(0.5, 0.5),
	})
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = frame
	return frame
end

-- Barra (linha) girada, comprimento e espessura em escala do pai
function Sigil.bar(parent, length, thickness, rotation, color, position, transparency)
	return baseFrame(parent, {
		Name = "Bar",
		Size = UDim2.fromScale(length, thickness),
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		Position = position or UDim2.fromScale(0.5, 0.5),
	})
end

-- Barra com espessura em pixels (para linhas finas e nítidas)
function Sigil.line(parent, length, pixels, rotation, color, position, transparency)
	return baseFrame(parent, {
		Name = "Line",
		Size = UDim2.new(length, 0, 0, pixels),
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		Position = position or UDim2.fromScale(0.5, 0.5),
	})
end

-- Quatro runas diferentes usadas ao redor da lança e nos círculos mágicos
function Sigil.rune(parent, index, color, thickness)
	thickness = thickness or 2
	local holder = baseFrame(parent, { Name = "Rune", Size = UDim2.fromScale(1, 1) })
	index = ((index - 1) % 6) + 1
	if index == 1 then
		Sigil.diamond(holder, 0.62, color, thickness)
		Sigil.disc(holder, 0.16, color)
		Sigil.bar(holder, 0.06, 0.95, 0, color)
	elseif index == 2 then
		Sigil.ring(holder, 0.8, color, thickness)
		Sigil.bar(holder, 0.07, 0.8, 0, color)
		Sigil.bar(holder, 0.45, 0.07, 0, color, UDim2.fromScale(0.5, 0.32))
	elseif index == 3 then
		Sigil.ring(holder, 0.85, color, thickness)
		Sigil.bar(holder, 0.07, 0.75, 45, color)
		Sigil.bar(holder, 0.07, 0.75, -45, color)
	elseif index == 4 then
		Sigil.diamond(holder, 0.7, color, thickness)
		Sigil.bar(holder, 0.9, 0.07, 0, color)
		Sigil.disc(holder, 0.14, color, 0, UDim2.fromScale(0.5, 0.2))
	elseif index == 5 then
		Sigil.bar(holder, 0.07, 0.9, 0, color)
		Sigil.bar(holder, 0.07, 0.5, 40, color, UDim2.fromScale(0.62, 0.35))
		Sigil.bar(holder, 0.07, 0.5, -40, color, UDim2.fromScale(0.38, 0.35))
		Sigil.disc(holder, 0.16, color, 0, UDim2.fromScale(0.5, 0.82))
	else
		Sigil.diamond(holder, 0.45, color, thickness)
		Sigil.diamond(holder, 0.8, color, thickness, 0)
		Sigil.disc(holder, 0.12, color)
	end
	return holder
end

--[[
	Círculo mágico completo (desenhado em um SurfaceGui).
	Retorna uma tabela com as camadas que podem girar independentemente.
]]
function Sigil.magicCircle(parent, color, accent, options)
	options = options or {}
	local thick = options.Thickness or 6
	local layers = {}

	local root = baseFrame(parent, { Name = "MagicCircle", Size = UDim2.fromScale(1, 1) })
	layers.Root = root

	-- Camada externa: dois anéis + runas em volta
	local outer = baseFrame(root, { Name = "Outer", Size = UDim2.fromScale(1, 1) })
	Sigil.ring(outer, 0.98, color, thick)
	Sigil.ring(outer, 0.86, color, math.max(2, thick * 0.5))
	local runeCount = options.RuneCount or 12
	for i = 1, runeCount do
		local angle = (i / runeCount) * math.pi * 2
		local r = 0.46
		local holder = baseFrame(outer, {
			Name = "RuneSlot",
			Size = UDim2.fromScale(0.075, 0.075),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * r * 0.92, 0.5 + math.sin(angle) * r * 0.92),
			Rotation = math.deg(angle) + 90,
		})
		Sigil.rune(holder, i, accent or color, math.max(2, thick * 0.4))
	end
	layers.Outer = outer

	-- Camada média: estrela de oito pontas (dois quadrados)
	local middle = baseFrame(root, { Name = "Middle", Size = UDim2.fromScale(1, 1) })
	Sigil.diamond(middle, 0.58, color, thick * 0.8, 45)
	Sigil.diamond(middle, 0.58, color, thick * 0.8, 0)
	Sigil.ring(middle, 0.72, accent or color, math.max(2, thick * 0.45))
	for i = 1, 8 do
		local angle = i * 45
		Sigil.line(middle, 0.13, math.max(2, thick * 0.5), angle, color,
			UDim2.fromScale(0.5 + math.cos(math.rad(angle)) * 0.39, 0.5 + math.sin(math.rad(angle)) * 0.39))
	end
	layers.Middle = middle

	-- Núcleo: anel + losango central
	local inner = baseFrame(root, { Name = "Inner", Size = UDim2.fromScale(1, 1) })
	Sigil.ring(inner, 0.34, color, thick)
	Sigil.diamond(inner, 0.17, accent or color, thick * 0.8)
	Sigil.disc(inner, 0.06, accent or color)
	layers.Inner = inner

	if options.Fill then
		local glow = Sigil.disc(root, 0.95, color, options.FillTransparency or 0.85)
		glow.ZIndex = 0
		layers.Fill = glow
	end

	return layers
end

-- Cache (fraco) com os elementos de cada desenho e suas transparências originais
local fadeCache = setmetatable({}, { __mode = "k" })

local function collect(root)
	local list = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("UIStroke") then
			table.insert(list, { d, "Transparency", d.Transparency })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			table.insert(list, { d, "BackgroundTransparency", d.BackgroundTransparency })
		end
	end
	fadeCache[root] = list
	return list
end

-- Ajusta a transparência de todos os elementos desenhados dentro de `root`
-- alpha = 0 → aparência original, alpha = 1 → invisível
function Sigil.setTransparency(root, alpha)
	local list = fadeCache[root] or collect(root)
	for _, entry in ipairs(list) do
		local base = entry[3]
		entry[1][entry[2]] = base + (1 - base) * alpha
	end
end

return Sigil
