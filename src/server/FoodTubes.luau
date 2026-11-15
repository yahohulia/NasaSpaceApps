--!strict
-- The food tube crate in the storage room (Workspace.FoodTubeCrate, its PromptPart tagged TAG, built in
-- Studio). Each player may take PER_PLAYER tubes for the whole mission ("Start over" gives them back).
-- A tube goes into the shared bag as a harvest item (Player.CropBag StringValue "Produce", Value "FoodTube",
-- attribute Food), so CropClient's "Eat [G]" button eats it through Crops.luau, and CropModels draws it.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local CraftConfig = require(game:GetService("ReplicatedStorage").Shared.CraftConfig)
local Notice = require(script.Parent.Notice)
local Strings = require(game:GetService("ReplicatedStorage").Shared.Strings)

local TAG = "FoodTubeCrate"
local PER_PLAYER = 2 -- game value, TODO balance: tubes each player can take in one mission
local FOOD = 40 -- game value, TODO balance: food one tube gives (Food is 0..100)

local FoodTubes = {}

local taken: { [number]: number } = {} -- UserId -> tubes taken this mission (kept if the player rejoins)

local function bagOf(player: Player): Folder
	local existing = player:FindFirstChild("CropBag")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CropBag"
	folder.Parent = player
	return folder
end

local function take(player: Player)
	local n = taken[player.UserId] or 0
	if n >= PER_PLAYER then
		Notice.send(player, "food.tube.none_left", "warn", { max = PER_PLAYER })
		return
	end
	local samples = player:GetAttribute("BagSamples")
	local used = #bagOf(player):GetChildren() + (if typeof(samples) == "number" then samples else 0)
	if used >= CraftConfig.BagSize then
		Notice.send(player, "food.tube.bag_full", "warn")
		return
	end
	taken[player.UserId] = n + 1
	local item = Instance.new("StringValue")
	item.Name = "Produce"
	item.Value = "FoodTube"
	item:SetAttribute("Order", os.clock())
	item:SetAttribute("Food", FOOD)
	item.Parent = bagOf(player)
	Notice.send(player, "food.tube.took", "info", { n = n + 1, max = PER_PLAYER })
end

FoodTubes.take = take -- also what the crate prompt does (handy for tests)

local function bind(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("FoodTubePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FoodTubePrompt"
	prompt.ActionText = Strings.get("food.tube.prompt", "en")
	prompt.ObjectText = Strings.get("food.tube.object", "en")
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(take)
end

function FoodTubes.start()
	for _, part in CollectionService:GetTagged(TAG) do
		bind(part)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)

	-- A new mission gives everyone their tubes back.
	local function bindReset(child: Instance)
		if child.Name == "MB_ResetMission" and child:IsA("BindableEvent") then
			child.Event:Connect(function()
				table.clear(taken)
			end)
		end
	end
	for _, child in ServerStorage:GetChildren() do
		bindReset(child)
	end
	ServerStorage.ChildAdded:Connect(bindReset)
end

return FoodTubes
