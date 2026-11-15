--!strict
-- Base lights. Gives every lamp inside the base a cinematic look (a warm ceiling spot with
-- shadows + a soft fill) and lets players switch the lights of each room on and off from the
-- light panel in the power room (part tagged LightsConfig.PanelTag).
-- Lights off never means pitch black: a faint cold night glow stays on (kids 7-12).
-- State per room: the room's zone part gets the attribute "LightsOn" (replicates to clients).
-- Clients ask with ReplicatedStorage.BaseLightsToggle:FireServer(roomId | "all", on).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LightsConfig = require(ReplicatedStorage.Shared.LightsConfig)

type Lamp = {
	fill: PointLight,
	spot: SpotLight,
	glass: BasePart?,
}
type Room = {
	id: string,
	zone: BasePart,
	lamps: { Lamp },
	on: boolean,
	version: number, -- bumps on every switch so an old ripple stops
}

local BaseLights = {}

local rooms: { [string]: Room } = {}
local lastClick: { [Player]: number } = {}

local function findPath(path: { string }): Instance?
	local node: Instance? = workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function contains(zone: BasePart, pos: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2 + Vector3.new(0.5, 3, 0.5) -- lamps hang at the ceiling, near the top
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function volume(part: BasePart): number
	return part.Size.X * part.Size.Y * part.Size.Z
end

-- The smallest room that holds this point (the corridor box overlaps the rooms' doors).
local function roomAt(pos: Vector3): Room?
	local best: Room? = nil
	for _, room in rooms do
		if contains(room.zone, pos) and (best == nil or volume(room.zone) < volume(best.zone)) then
			best = room
		end
	end
	return best
end

local function lightPosition(light: Light): Vector3?
	local holder = light.Parent
	if holder and holder:IsA("BasePart") then
		return holder.Position
	elseif holder and holder:IsA("Attachment") then
		return holder.WorldPosition
	end
	return nil
end

-- Turns one existing PointLight into a cinematic lamp: adds the ceiling spot next to it.
local function makeLamp(fill: PointLight): Lamp?
	local pos = lightPosition(fill)
	if not pos then
		return nil
	end
	local holder = fill.Parent :: Instance
	local mount = holder:FindFirstChild("CineMount")
	if not (mount and mount:IsA("Attachment")) then
		local a = Instance.new("Attachment")
		a.Name = "CineMount"
		a.Parent = holder
		mount = a
	end
	local att = mount :: Attachment
	att.WorldCFrame = CFrame.lookAt(pos, pos - Vector3.yAxis) -- front (-Z) points down
	local spot = att:FindFirstChild("CineSpot")
	if not (spot and spot:IsA("SpotLight")) then
		local s = Instance.new("SpotLight")
		s.Name = "CineSpot"
		s.Face = Enum.NormalId.Front
		s.Parent = att
		spot = s
	end
	local cine = spot :: SpotLight
	cine.Shadows = true
	cine.Angle = LightsConfig.SpotAngle
	fill.Shadows = false

	local glass = if holder:IsA("BasePart") then holder else nil
	return { fill = fill, spot = cine, glass = glass }
end

local function collectRooms()
	local zones = findPath(LightsConfig.ZonesFolder)
	if not zones then
		warn("[lights] no Workspace.Base.Zones; base lights are off")
		return
	end
	for _, zone in zones:GetChildren() do
		local id = string.gsub(zone.Name, "Zone$", "")
		if zone:IsA("BasePart") and not LightsConfig.SkipZones[id] then
			rooms[id] = { id = id, zone = zone, lamps = {}, on = true, version = 0 }
		end
	end
	local count = 0
	for _, folderName in LightsConfig.LampFolders do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, d in folder:GetDescendants() do
				if d:IsA("PointLight") then
					local pos = lightPosition(d)
					local room = pos and roomAt(pos)
					if room then
						local lamp = makeLamp(d)
						if lamp then
							table.insert(room.lamps, lamp)
							count += 1
						end
					end
				end
			end
		end
	end
	for _, room in rooms do
		-- Lamps along the room: the ripple goes from one end to the other.
		local axis = if room.zone.Size.X >= room.zone.Size.Z then room.zone.CFrame.XVector else room.zone.CFrame.ZVector
		table.sort(room.lamps, function(a, b)
			return (lightPosition(a.fill) :: Vector3):Dot(axis) < (lightPosition(b.fill) :: Vector3):Dot(axis)
		end)
		room.zone:SetAttribute("LampCount", #room.lamps)
		if #room.lamps > 0 then
			room.zone:SetAttribute("LightsOn", true)
		end
	end
	print(`[lights] {count} lamps in base rooms`)
end

local function setLook(lamp: Lamp, look: LightsConfig.LampLook, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	lamp.fill.Range = look.fillRange
	lamp.spot.Range = look.spotRange
	if seconds <= 0 then
		lamp.fill.Brightness = look.fillBrightness
		lamp.fill.Color = look.color
		lamp.spot.Brightness = look.spotBrightness
		lamp.spot.Color = look.color
		lamp.spot.Enabled = look.spotBrightness > 0
		if lamp.glass then
			lamp.glass.Color = look.glassColor
		end
		return
	end
	lamp.spot.Enabled = true
	TweenService:Create(lamp.fill, info, { Brightness = look.fillBrightness, Color = look.color }):Play()
	local spotTween = TweenService:Create(lamp.spot, info, { Brightness = look.spotBrightness, Color = look.color })
	spotTween.Completed:Connect(function()
		lamp.spot.Enabled = lamp.spot.Brightness > 0
	end)
	spotTween:Play()
	if lamp.glass then
		TweenService:Create(lamp.glass, info, { Color = look.glassColor }):Play()
	end
end

-- Lights coming on: lamp after lamp, each with a short tube-light flicker.
local function rippleOn(room: Room, version: number)
	local on = LightsConfig.On
	for i, lamp in room.lamps do
		task.delay((i - 1) * LightsConfig.RippleSeconds, function()
			local steps = { 0.55, 0.1, 0.8, 1 }
			for _, k in steps do
				if room.version ~= version then
					return
				end
				lamp.spot.Enabled = true
				lamp.fill.Color = on.color
				lamp.spot.Color = on.color
				lamp.fill.Brightness = on.fillBrightness * k
				lamp.spot.Brightness = on.spotBrightness * k
				if lamp.glass then
					lamp.glass.Color = LightsConfig.Off.glassColor:Lerp(on.glassColor, k)
				end
				task.wait(0.05)
			end
		end)
	end
end

-- How many rooms are lit, for the power drain (MB_BaseState@LitRooms, read by MB_ResourceServer).
local function publishLitRooms()
	local baseState = ReplicatedStorage:FindFirstChild("MB_BaseState")
	if not baseState then
		return
	end
	local lit = 0
	for _, room in rooms do
		if room.on and #room.lamps > 0 then
			lit += 1
		end
	end
	baseState:SetAttribute("LitRooms", lit)
end

local function setRoom(room: Room, on: boolean, instant: boolean?)
	if #room.lamps == 0 or (room.on == on and not instant) then
		return
	end
	room.on = on
	room.version += 1
	room.zone:SetAttribute("LightsOn", on)
	publishLitRooms()
	if instant then
		for _, lamp in room.lamps do
			setLook(lamp, if on then LightsConfig.On else LightsConfig.Off, 0)
		end
	elseif on then
		rippleOn(room, room.version)
	else
		for _, lamp in room.lamps do
			setLook(lamp, LightsConfig.Off, LightsConfig.FadeSeconds)
		end
	end
end

local function nearPanel(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, panel in CollectionService:GetTagged(LightsConfig.PanelTag) do
		if panel:IsA("BasePart") and (panel.Position - root.Position).Magnitude <= LightsConfig.PanelDistance + 6 then
			return true
		end
	end
	return false
end

local function onToggle(player: Player, roomId: unknown, on: unknown)
	if type(roomId) ~= "string" or type(on) ~= "boolean" then
		return
	end
	local now = os.clock()
	if (lastClick[player] or 0) + LightsConfig.ToggleCooldown > now then
		return
	end
	lastClick[player] = now
	if not nearPanel(player) then
		return
	end
	if roomId == "all" then
		for _, id in LightsConfig.Rooms do
			local room = rooms[id]
			if room then
				setRoom(room, on)
			end
		end
	else
		local room = rooms[roomId]
		if room then
			setRoom(room, on)
		end
	end
end

function BaseLights.isOn(roomId: string): boolean
	local room = rooms[roomId]
	return room ~= nil and room.on
end

function BaseLights.start()
	collectRooms()
	for _, room in rooms do
		setRoom(room, true, true)
	end
	-- MB_BaseState may appear after us; publish once it exists.
	task.spawn(function()
		ReplicatedStorage:WaitForChild("MB_BaseState", 30)
		publishLitRooms()
	end)

	local remote = ReplicatedStorage:FindFirstChild("BaseLightsToggle")
	if not (remote and remote:IsA("RemoteEvent")) then
		local r = Instance.new("RemoteEvent")
		r.Name = "BaseLightsToggle"
		r.Parent = ReplicatedStorage
		remote = r
	end
	(remote :: RemoteEvent).OnServerEvent:Connect(onToggle)
	Players.PlayerRemoving:Connect(function(player)
		lastClick[player] = nil
	end)
end

return BaseLights
