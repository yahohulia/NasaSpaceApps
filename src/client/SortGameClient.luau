--!strict
-- Sorting mini game at the sorting table. The server decides right or wrong
-- (Crafting.luau, "Sorting table"); this script only shows it.
--
-- The camera looks down at the table. Samples from the bag come out one at a time and float
-- in front of the boxes. The kid clicks or taps the box the sample belongs in (or presses 1-4).
-- Right box: the sample flies into it. Wrong box: the sample shakes, the box flashes, a hint
-- shows, and the kid tries again after a short wait.
--
-- The table is built in Studio: Workspace.SortStation (TableTop is tagged Craft_SortStation),
-- with box parts named Bin<BoxId>Floor and Bin<BoxId>Wall. Box ids: CraftConfig.SortBoxOrder.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local SortGameClient = {}

local CAMERA_BACK = 4.2 -- studs from the middle of the boxes toward the player
local CAMERA_UP = 3.2
local CAMERA_SECONDS = 0.5 -- camera move into and out of the table view
local SAMPLE_SIZE = 0.9 -- studs, the biggest side of the floating sample
local SAMPLE_FRONT = 1.25 -- studs from the boxes toward the player
local SAMPLE_UP = 0.8
local FLY_SECONDS = 0.45
local SHAKE_SECONDS = 0.45

local GOOD = Color3.fromRGB(140, 235, 150)
local BAD = Color3.fromRGB(255, 150, 90)
local HOVER = Color3.fromRGB(255, 236, 170)
local TEXT = Color3.fromRGB(232, 236, 244)
local DIM_TEXT = Color3.fromRGB(170, 178, 196)

type Box = { id: string, index: number, centre: Vector3, target: BasePart, outline: SelectionBox }
type Flight = { model: Model, from: Vector3, to: Vector3, start: number }

local FREEZE_ACTIONS = {
	Enum.PlayerActions.CharacterForward,
	Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft,
	Enum.PlayerActions.CharacterRight,
	Enum.PlayerActions.CharacterJump,
}

local function smooth(a: number): number
	local x = math.clamp(a, 0, 1)
	return x * x * (3 - 2 * x)
end

function SortGameClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local function t(key: string, vars: { [string]: string | number }?): string
		return Strings.get(key, lang, vars)
	end
	local remote = ReplicatedStorage:WaitForChild("CraftSort") :: RemoteEvent

	local boxOf: { [string]: string } = {}
	for _, boxId in CraftConfig.SortBoxOrder do
		for _, kind in CraftConfig.SortBoxes[boxId] do
			boxOf[kind] = boxId
		end
	end

	-- A slim strip near the bottom (above the bag): samples left + right/wrong messages. No rules text
	-- and nothing at the top, so the boxes stay fully visible. "Stop" sits in the top-right corner.
	local gui = Instance.new("ScreenGui")
	gui.Name = "SortGame"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -118)
	panel.Size = UDim2.fromOffset(560, 64)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.3
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(90, 100, 120)
	panelStroke.Parent = panel

	local function label(size: number, pos: UDim2, dim: UDim2, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamMedium
		l.TextSize = size
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color
		l.Position = pos
		l.Size = dim
		l.Parent = panel
		return l
	end

	local title = label(16, UDim2.fromOffset(14, 6), UDim2.new(1, -170, 0, 20), Color3.fromRGB(255, 220, 120))
	title.Font = Enum.Font.GothamBold
	title.Text = ""
	local message = label(16, UDim2.fromOffset(14, 28), UDim2.new(1, -170, 0, 30), TEXT)
	message.Font = Enum.Font.GothamBold
	local info = label(15, UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 30), DIM_TEXT)
	info.Visible = false -- the rules / key hint text covered the boxes; the boxes are numbered on the table

	local stop = Instance.new("TextButton")
	stop.AnchorPoint = Vector2.new(1, 0.5)
	stop.Position = UDim2.new(1, -12, 0.5, 0)
	stop.Size = UDim2.fromOffset(130, 32)
	stop.BackgroundColor3 = Color3.fromRGB(44, 52, 74)
	stop.Font = Enum.Font.GothamBold
	stop.TextSize = 18
	stop.TextColor3 = TEXT
	stop.Text = t("craft.sort.stop")
	stop.Modal = true -- frees the first-person mouse while the game is open
	stop.Parent = panel
	local stopCorner = Instance.new("UICorner")
	stopCorner.CornerRadius = UDim.new(0, 6)
	stopCorner.Parent = stop

	-- Click targets over the real boxes (made on this client only) ------------------------
	local helpers = Instance.new("Folder")
	helpers.Name = "SortGameHelpers"
	helpers.Parent = workspace

	local boxes: { [string]: Box } = {}
	local boxList: { Box } = {}
	local targets: { [BasePart]: Box } = {}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include

	local function buildBoxes(): boolean
		helpers:ClearAllChildren()
		table.clear(boxes)
		table.clear(boxList)
		table.clear(targets)
		local station: Instance? = nil
		for _, inst in CollectionService:GetTagged(CraftConfig.SortStationTag) do
			if inst:IsA("BasePart") and inst.Parent then
				station = inst.Parent
				break
			end
		end
		if not station then
			return false
		end
		local list: { BasePart } = {}
		for i, boxId in CraftConfig.SortBoxOrder do
			local floor = station:FindFirstChild("Bin" .. boxId .. "Floor")
			if floor and floor:IsA("BasePart") then
				local target = Instance.new("Part")
				target.Name = "SortTarget_" .. boxId
				target.Anchored = true
				target.CanCollide = false
				target.CanTouch = false
				target.CastShadow = false
				target.Transparency = 1
				target.Size = Vector3.new(floor.Size.X, 1.2, floor.Size.Z)
				target.CFrame = floor.CFrame * CFrame.new(0, 0.5, 0)
				target.Parent = helpers
				local outline = Instance.new("SelectionBox")
				outline.Adornee = target
				outline.LineThickness = 0.05
				outline.SurfaceTransparency = 1
				outline.Visible = false
				outline.Parent = helpers
				local box: Box = { id = boxId, index = i, centre = floor.Position, target = target, outline = outline }
				boxes[boxId] = box
				table.insert(boxList, box)
				targets[target] = box
				table.insert(list, target)
			end
		end
		rayParams.FilterDescendantsInstances = list
		return #boxList > 0
	end

	-- State -------------------------------------------------------------------------------
	local isOpen = false
	local waiting = false -- a choice was sent, or a wrong box made us wait
	local hovered: Box? = nil
	local chosen: Box? = nil -- the box picked last, flashes red if it was wrong
	local flashUntil: { [Box]: number } = {}
	local flashColor: { [Box]: Color3 } = {}
	local sample: Model? = nil
	local samplePos = Vector3.zero
	local shakeStart = -math.huge
	local flights: { Flight } = {}
	local camFrom = CFrame.identity
	local camTo = CFrame.identity
	local camStart = 0
	local closing = false

	local function viewFor(): (CFrame, Vector3)
		local centre = Vector3.zero
		for _, box in boxList do
			centre += box.centre
		end
		centre /= math.max(#boxList, 1)
		-- the row of boxes runs along `along`; the player stands on the `front` side of it
		local along = if #boxList > 1
			then (boxList[#boxList].centre - boxList[1].centre) * Vector3.new(1, 0, 1)
			else Vector3.new(0, 0, 1)
		along = if along.Magnitude > 0.01 then along.Unit else Vector3.new(0, 0, 1)
		local front = Vector3.new(0, 1, 0):Cross(along)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - centre):Dot(front) < 0 then
			front = -front
		end
		local eye = centre + front * CAMERA_BACK + Vector3.new(0, CAMERA_UP, 0)
		local cam = CFrame.lookAt(eye, centre + front * 0.6)
		return cam, centre + front * SAMPLE_FRONT + Vector3.new(0, SAMPLE_UP, 0)
	end

	local function makeSample(item: Instance?): Model?
		if not item then
			return nil
		end
		local model = Instance.new("Model")
		model.Name = "SortSample"
		local copy = item:Clone()
		copy.Parent = model
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local cf, size = model:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		if biggest > 0 then
			model:ScaleTo(model:GetScale() * SAMPLE_SIZE / biggest)
		end
		cf = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(cf.Position) -- spin around the centre of the sample
		model.Parent = helpers
		return model
	end

	local function flyAway(boxId: string?)
		local current = sample
		sample = nil
		if not current then
			return
		end
		local box = if boxId then boxes[boxId] else nil
		if not box then
			current:Destroy()
			return
		end
		flashUntil[box] = os.clock() + 0.6
		flashColor[box] = GOOD
		table.insert(flights, {
			model = current,
			from = current:GetPivot().Position,
			to = box.centre + Vector3.new(0, 0.15, 0),
			start = os.clock(),
		})
	end

	local function setInfo()
		if hovered then
			info.Text = t("craft.sort.hover", {
				n = hovered.index,
				name = t("craft.sort.box." .. hovered.id),
				look = t("craft.sort.look." .. hovered.id),
			})
		else
			info.Text = t("craft.sort.keys")
		end
	end

	local function setHover(box: Box?)
		if hovered ~= box then
			hovered = box
			setInfo()
		end
	end

	local function freeze(on: boolean)
		if on then
			ContextActionService:BindActionAtPriority("SortGameFreeze", function()
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 1, table.unpack(FREEZE_ACTIONS))
		else
			ContextActionService:UnbindAction("SortGameFreeze")
		end
	end

	local function open()
		if isOpen or not buildBoxes() then
			return
		end
		isOpen = true
		closing = false
		local camera = workspace.CurrentCamera
		camFrom = camera.CFrame
		local view, pos = viewFor()
		camTo = view
		samplePos = pos
		camStart = os.clock()
		camera.CameraType = Enum.CameraType.Scriptable
		gui.Enabled = true
		UserInputService.MouseIconEnabled = true
		freeze(true)
		setInfo()
	end

	local function finishClose()
		isOpen = false
		closing = false
		gui.Enabled = false
		UserInputService.MouseIconEnabled = false -- first person hides the cursor
		freeze(false)
		setHover(nil)
		for _, box in boxList do
			box.outline.Visible = false
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
	end

	local function close()
		if not isOpen or closing then
			return
		end
		closing = true
		waiting = true
		gui.Enabled = false
		-- the camera glides back to the head; the render step finishes the close
		camFrom = workspace.CurrentCamera.CFrame
		camStart = os.clock()
	end

	local function choose(boxId: string)
		if not isOpen or closing or waiting or not sample then
			return
		end
		waiting = true
		chosen = boxes[boxId]
		remote:FireServer("box", boxId)
	end

	-- Every frame: camera, the floating sample, flights, box outlines ---------------------
	RunService:BindToRenderStep("SortGame", Enum.RenderPriority.Camera.Value + 2, function()
		if not isOpen then
			return
		end
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local a = smooth((now - camStart) / CAMERA_SECONDS)
		if closing then
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			local back = if head and head:IsA("BasePart")
				then CFrame.lookAt(head.Position, head.Position + camFrom.LookVector)
				else camFrom
			camera.CFrame = camFrom:Lerp(back, a)
			if a >= 1 and #flights == 0 then
				finishClose()
				return
			end
		else
			camera.CFrame = camFrom:Lerp(camTo, a)
		end

		-- hide your own body, it would stand between the camera and the table
		local character = player.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				end
			end
		end

		local current = sample
		if current then
			local shake = now - shakeStart
			local dx = if shake < SHAKE_SECONDS then math.sin(shake * 60) * 0.12 * (1 - shake / SHAKE_SECONDS) else 0
			local bob = math.sin(now * 2.2) * 0.06
			current:PivotTo(
				CFrame.new(samplePos + camera.CFrame.RightVector * dx + Vector3.new(0, bob, 0))
					* CFrame.Angles(0.3, now * 0.9, 0)
			)
		end

		for i = #flights, 1, -1 do
			local f = flights[i]
			local k = (now - f.start) / FLY_SECONDS
			if k >= 1 then
				f.model:Destroy()
				table.remove(flights, i)
			else
				local pos = f.from:Lerp(f.to, smooth(k)) + Vector3.new(0, math.sin(k * math.pi) * 0.9, 0)
				f.model:ScaleTo(math.max(f.model:GetScale() * (1 - 0.02), 0.05))
				f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(k * 4, k * 6, 0))
			end
		end

		for _, box in boxList do
			local until_ = flashUntil[box]
			if until_ and now < until_ then
				box.outline.Visible = true
				box.outline.Color3 = flashColor[box] or GOOD
			elseif hovered == box and not closing then
				box.outline.Visible = true
				box.outline.Color3 = HOVER
			else
				box.outline.Visible = false
			end
		end
	end)

	-- Input ---------------------------------------------------------------------------------
	local function boxAt(screen: Vector3): Box?
		local ray = workspace.CurrentCamera:ScreenPointToRay(screen.X, screen.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 50, rayParams)
		if hit and hit.Instance:IsA("BasePart") then
			return targets[hit.Instance]
		end
		return nil
	end

	UserInputService.InputChanged:Connect(function(input)
		if isOpen and not closing and input.UserInputType == Enum.UserInputType.MouseMovement then
			setHover(boxAt(input.Position))
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not isOpen or closing or processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local box = boxAt(input.Position)
			if box then
				setHover(box)
				choose(box.id)
			end
			return
		end
		local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
		for i, code in keys do
			if input.KeyCode == code and CraftConfig.SortBoxOrder[i] then
				choose(CraftConfig.SortBoxOrder[i])
			end
		end
	end)

	stop.Activated:Connect(function()
		remote:FireServer("stop")
		if sample then
			sample:Destroy()
			sample = nil
		end
		close()
	end)

	-- Server messages -----------------------------------------------------------------------
	local wrongId = 0
	remote.OnClientEvent:Connect(function(state: string, data: { [string]: any })
		if state == "show" then
			open()
			if not isOpen then
				return
			end
			if data.kind then
				flyAway(boxOf[tostring(data.kind)])
				message.Text = t("craft.sort.right." .. tostring(data.kind))
				message.TextColor3 = GOOD
			else
				message.Text = ""
			end
			if sample then
				sample:Destroy()
			end
			sample = makeSample(data.item)
			setInfo()
			title.Text = t("craft.sort.left", { n = data.left or 0 })
			waiting = false
		elseif state == "wrong" then
			message.Text = t("craft.sort.wrong." .. tostring(data.kind))
			message.TextColor3 = BAD
			shakeStart = os.clock()
			if chosen then
				flashUntil[chosen] = os.clock() + 0.6
				flashColor[chosen] = BAD
			end
			wrongId += 1
			local id = wrongId
			task.delay(tonumber(data.wait) or 2, function()
				if id == wrongId then
					waiting = false
				end
			end)
		elseif state == "close" then
			if data.kind and isOpen then
				flyAway(boxOf[tostring(data.kind)])
			elseif sample then
				sample:Destroy()
				sample = nil
			end
			close()
		end
	end)

	player.CharacterRemoving:Connect(function()
		if isOpen then
			if sample then
				sample:Destroy()
				sample = nil
			end
			finishClose()
		end
	end)
end

return SortGameClient
