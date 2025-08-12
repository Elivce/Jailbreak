-- [[ Important modules ]]
local Services = setmetatable({}, {
	__index = function(self, service)
		return game:GetService(service)
	end
})

local Players = Services.Players
local HttpService = Services.HttpService
local Lighting = Services.Lighting
local ReplicatedStorage = Services.ReplicatedStorage
local PathfindingService = Services.PathfindingService
local RunService = Services.RunService
local TeleportService = Services.TeleportService
local CoreGui = Services.CoreGui

local Modules = {
	Vehicle = require(ReplicatedStorage.Vehicle.VehicleUtils),
	SidebarUI = require(ReplicatedStorage.Game.SidebarUI),
	DefaultActions = require(ReplicatedStorage.Game.DefaultActions),
	ItemSystem = require(ReplicatedStorage.Game.ItemSystem.ItemSystem),
	GunItem = require(ReplicatedStorage.Game.Item.Gun),
	PlayerUtils = require(ReplicatedStorage.Game.PlayerUtils),
	Paraglide = require(ReplicatedStorage.Game.Paraglide),
	CharUtils = require(ReplicatedStorage.Game.CharacterUtil),
	Notification = require(ReplicatedStorage.Game.Notification),
	PuzzleFlow = require(ReplicatedStorage.Game.Robbery.PuzzleFlow),
	Heli = require(ReplicatedStorage.Game.Vehicle.Heli),
	Raycast = require(ReplicatedStorage.Module.RayCast),
	UI = require(ReplicatedStorage.Module.UI),
	GunShopUI = require(ReplicatedStorage.Game.GunShop.GunShopUI),
	GunShopUtils = require(ReplicatedStorage.Game.GunShop.GunShopUtils),
	AlexChassis = require(ReplicatedStorage.Module.AlexChassis),
	Store = require(ReplicatedStorage.App.store),
	TagUtils = require(ReplicatedStorage.Tag.TagUtils),
	RobberyConsts = require(ReplicatedStorage.Robbery.RobberyConsts),
	NpcShared = require(ReplicatedStorage.GuardNPC.GuardNPCShared),
	Npc = require(ReplicatedStorage.NPC.NPC),
	SafeConsts = require(ReplicatedStorage.Safes.SafesConsts),
	MansionUtils = require(ReplicatedStorage.MansionRobbery.MansionRobberyUtils),
	BossConsts = require(ReplicatedStorage.MansionRobbery.BossNPCConsts),
	BulletEmitter = require(ReplicatedStorage.Game.ItemSystem.BulletEmitter),
	EquipThing = ReplicatedStorage.Inventory.InventoryItem
}

local GetVehiclePacket = Modules.Vehicle.GetLocalVehiclePacket
local RayIgnore = Modules.Raycast.RayIgnoreNonCollideWithIgnoreList
local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local char, root, humanoid, vehicle, vehicleRoot

-- [[ Helicopter Stuff ]]
local heliSpawnPos = {
	Vector3.new(725, 76, 1111),
	Vector3.new(-1255, 46, -1572),
	Vector3.new(840, 24, -3678),
	Vector3.new(-2875, 199, -4059)
}

local config = {
	HeliSpeed = 3000,
	VehicleSpeed = 650,
	FlightSpeed = 150,
	PathSpeed = 45
}

-- No Fall Damage
Modules.TagUtils.isPointInTag = function(_, Tag)
	if Tag == 'NoFallDamage' or Tag == 'NoRagdoll' or Tag == 'NoParachute' then
		return true
	end
end

local InHeli = function() return ((vehicle and vehicle.Name == 'Heli') and true) or false end
local InCar = function() return ((vehicle and vehicle.Name == 'Jeep' or "Camaro") and true) or false end

local ExitVehicle = function()
	if player.Character.Humanoid.Health <= 0 or not vehicle then return end
	Modules.CharUtils.OnJump()

	repeat 
		task.wait()  
	until not vehicle or player.Character.Humanoid.Health <= 0
end

local UpdatePlayerVars = function()
	char = player.Character
	root = char:WaitForChild('HumanoidRootPart')
	humanoid = char:WaitForChild('Humanoid')
end

local UpdateVehicleVars = function()
	local vehicleModel = Modules.Vehicle.GetLocalVehicleModel()
	if vehicleModel == false then
		vehicle = nil
		vehicleRoot = nil
	else
		vehicle = vehicleModel
		vehicleRoot = vehicle.PrimaryPart
	end
end

if player.Character then UpdatePlayerVars() end

player.characterAdded:Connect(UpdatePlayerVars)
player.characterRemoving:Connect(UpdatePlayerVars)

UpdateVehicleVars()
Modules.Vehicle.OnVehicleEntered:Connect(UpdateVehicleVars)
Modules.Vehicle.OnVehicleExited:Connect(UpdateVehicleVars)

-- [[ Teleporting requirements ]]
local GetRoot = function() return (vehicle and vehicleRoot) or root end
local rayDirs = { up = Vector3.new(0, 999, 0), down = Vector3.new(0, -999, 0) }

local function rayCast(pos, dir)
	local ignoreList = {}
	if char then table.insert(ignoreList, char) end
	if vehicle then table.insert(ignoreList, vehicle) end
	local rain = game.Workspace:FindFirstChild('Rain')
	if rain then table.insert(ignoreList, rain) end

	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = ignoreList
	params.IgnoreWater = true
	local result = game.Workspace:Raycast(pos, dir, params)
	if result then return result.Instance, result.Position else return nil, nil end
end

local function DistanceXZ(firstPos, secondPos)
	local XZVector = Vector3.new(firstPos.X, 0, firstPos.Z) - Vector3.new(secondPos.X, 0, secondPos.Z)
	return XZVector.Magnitude 
end

local ActivateSpec = function(spec)
	spec.Duration = 0
	spec.Timed = true
	spec:Callback(true)
end

local function LagBackCheck(part)
	local ShouldStop = false
	local OldPosition = part.Position
	local Signal = part:GetPropertyChangedSignal("CFrame"):Connect(function()
		local CurrentPosition = part.Position

		if DistanceXZ(CurrentPosition, OldPosition) > 7 then
			LaggedBack = true
			task.delay(0.2, function()
				LaggedBack = false
			end)
		end
	end)

	task.spawn(function()
		while part and ShouldStop == false do
			OldPosition = part.Position
			task.wait()
		end
	end)

	return {
		Stop = function()
			ShouldStop = true
			Signal:Disconnect()
		end
	}
end

local function GetVehiclePos(playerPos)
	playerPos = Vector3.new(playerPos.x, 0, playerPos.z)
	local targetVehicle
	local minDist = math.huge

	-- Scan for nearby helicopters
	for _, vehicle in pairs(game.Workspace.Vehicles:GetChildren()) do
		if vehicle.Name == 'Heli' and vehicle.Seat.Position.y <= 300 then
			local pos = vehicle.Seat.Position
			pos = Vector3.new(pos.x, 0, pos.z)
			local dist = (pos - playerPos).Magnitude
			if dist < minDist and dist > 1 then
				local hit, _ = rayCast(vehicle.Seat.Position, rayDirs.up)
				if not hit then
					minDist = dist
					targetVehicle = vehicle
				end
			end
		end
	end

	-- If a nearby helicopter is found, return its position
	if targetVehicle then
		return targetVehicle.Seat.Position, targetVehicle
	end

	-- If no nearby helicopter is found, check the predefined spawn positions
	local positions = heliSpawnPos
	for _, pos in pairs(positions) do
		local dist = (pos - playerPos).Magnitude
		if dist < minDist and dist > 1 then
			minDist = dist
			targetVehicle = pos
		end
	end

	return targetVehicle, nil
end

local FlightMove = function(pos)
	local LagCheck = LagBackCheck(root)
	local LagbackCount = 0
	local speed = (InHeli() and -config['HeliSpeed']) or (vehicle and -config['VehicleSpeed']) or -config['FlightSpeed']
	local GetPos = function() return Vector3.new(pos.x, 1000, pos.z) end
	char:PivotTo(CFrame.new(root.Position.x, 1000, root.Position.z))

	local dist = GetRoot().Position - GetPos()
	while dist.Magnitude > 10 do	
		dist = GetRoot().Position - GetPos()
		local velocity = dist.Unit * speed
		velocity = Vector3.new(velocity.x, 0, velocity.z)

		GetRoot().Velocity = velocity
		char:PivotTo(CFrame.new(root.Position.x, 1000, root.Position.z))
		task.wait()
	end

	GetRoot().Velocity = Vector3.zero
	char:PivotTo(CFrame.new(GetPos()))
end

local function GoToGround()
	while task.wait() do
		local _, pos = rayCast(root.Position, rayDirs.down)
		if pos then 
			char:PivotTo(CFrame.new(root.Position.x, pos.y + 0.2, root.Position.z)) 
			task.wait(0.3) 
			GetRoot().Velocity = Vector3.zero 
			return 
		end
	end
end

local function Travel(location)
	while not vehicle do
		local pos1, targetVehicle = GetVehiclePos(root.Position)
		FlightMove(pos1)
		GoToGround()
		if targetVehicle and targetVehicle.PrimaryPart and (targetVehicle.PrimaryPart.Position - root.Position).Magnitude < 30 then
			for _ = 1, 9 do
				for _, spec in pairs(Modules.UI.CircleAction.Specs) do
					if spec.Part and spec.Part == targetVehicle.Seat then ActivateSpec(spec) end
				end
				task.wait(0.25)
				if vehicle then 
					for i,v in pairs(targetVehicle:GetDescendants()) do
						if v:IsA("Part") then
							v.CanCollide = false
						end
					end
					break 
				end
			end
		else
			for i, v in next, heliSpawnPos do
				FlightMove(v) 
				GoToGround()
				task.wait(1)
				pos1, targetVehicle = GetVehiclePos(root.Position)
				if targetVehicle then
					for i,v in pairs(targetVehicle:GetDescendants()) do
						if v:IsA("Part") then
							v.CanCollide = false
						end
					end
					break
				end
			end
		end 
		task.wait()
	end
	FlightMove(location)
	GoToGround()
end

return Travel
