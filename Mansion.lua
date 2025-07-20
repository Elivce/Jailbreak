-- [[ Load Game ]]

if not game:IsLoaded() then game.Loaded:Wait() task.wait(3) end
queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Hackerman694200/tester/main/codetemp.lua'))()")

-- [[ Luraph Macros ]]

if not LPH_OBFUSCATED then
	LPH_JIT_MAX = function(...) return(...) end;
	LPH_NO_VIRTUALIZE = function(...) return(...) end;
    LRM_IsUserPremium = true;
	script_key = "a"
end

-- [[ Settings + Stats ]]

if getgenv().Enabled == nil then
	getgenv().Enabled = true
end

if getgenv().StartingTime == nil then
	getgenv().StartingTime = os.time()
end

if getgenv().StartingMoney == nil then
	getgenv().StartingMoney = game:GetService("Players").LocalPlayer.leaderstats.Money.Value 
end

if getgenv().Advertise == nil then
	getgenv().Advertise = false
end

if getgenv().PickUpCash == nil then
	getgenv().PickUpCash = true
end

if getgenv().Mobile == nil then
	getgenv().Mobile = false
end

if getgenv().RobCrate == nil then
	getgenv().RobCrate = true
end

if getgenv().RobShip == nil then
	getgenv().RobShip = true
end

if getgenv().RobMansion == nil then
	getgenv().RobMansion = true
end

if getgenv().AutoOpenSafes == nil then
	getgenv().AutoOpenSafes = false
end

if getgenv().LogWebhook == nil then
	getgenv().LogWebhook = false
end

if getgenv().WebhookUrl == nil then
	getgenv().WebhookUrl = ""
end

-- [[ Check If Executed ]]

if getgenv().Dropfarm == true then print("// Already executed [Dropfarm]") return end

-- [[ Set Executed ]]

getgenv().Dropfarm = true

-- [[ Directory ]]

local Directory = "x2zu"
if not isfolder(Directory) then
	makefolder(Directory)
end

-- [[ Queuening + UI ]]

local MoneyMade, RunTime = 0, 0
local queue = ""
local queued = false
local ui_options = {
	main_color = Color3.fromRGB(41, 74, 122),
	min_size = Vector2.new(400, 300),
	toggle_key = Enum.KeyCode.RightShift,
	can_resize = true,
}

-- [[ Formating functions ]]

function TickToHM(seconds)
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60
	local hours = math.floor(minutes / 60)
	minutes = minutes % 60

	return hours .. "h/" .. minutes .. "m"
end

function FormatCash(number)
	local totalnum = tostring(number):split("")

	if #totalnum == 7 then
		return totalnum[1].."."..totalnum[2].."M"
	elseif #totalnum >= 10 then
		return totalnum[1].."."..totalnum[2].."B"
	elseif #totalnum == 4 and #totalnum[2] == 0 then
		return totalnum[1].."k"
	elseif #totalnum == 4  then
		return totalnum[1].."."..totalnum[2].."k"
	elseif #totalnum == 5  then
		return totalnum[1]..totalnum[2].."."..totalnum[3].."k"
	elseif #totalnum == 6  then
		return totalnum[1]..totalnum[2]..totalnum[3].."k"
	else
		return number
	end
end

-- [[ Webhook ]]

local SentWebhookServerhop = false

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

-- [[ Config ]]

local config = {
	HeliSpeed = 700,
	VehicleSpeed = 650,
	FlightSpeed = 150,
	PathSpeed = 45
}

if LRM_IsUserPremium then
    config.HeliSpeed = 5000
	config.VehicleSpeed = 650
	config.FlightSpeed = 175
	config.PathSpeed = 180
end

-- [[ Resume shit ]]

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

-- [[ Ray + Vehicle vars ]]

local GetVehiclePacket = Modules.Vehicle.GetLocalVehiclePacket
local RayIgnore = Modules.Raycast.RayIgnoreNonCollideWithIgnoreList

-- [[ Player Variables ]]

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local char, root, humanoid, vehicle, vehicleRoot

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

-- [[ Bypass Anticheat ]]

local OverwriteCnt = 0
local ExitFunc = nil 

LPH_NO_VIRTUALIZE(function()
	for i, v in pairs(getgc(true)) do
		if typeof(v) =="function" then
			if debug.info(v, "n"):match("CheatCheck") then
				hookfunction(v, function() end)
			end
		end

		if typeof(v) == "function" and getfenv(v).script == player.PlayerScripts.LocalScript then
			local con = getconstants(v)
			if table.find(con, "LastVehicleExit") and table.find(con, "tick") then
				ExitFunc = v
			end
		end
	end
end)()

-- [[ Remove All Benches ]]

LPH_NO_VIRTUALIZE(function()
	for i, v in pairs(game.Workspace:GetChildren()) do
		if v.Name == "Bench" then
			v:Destroy()
		end
	end
end)()

-- [[ Robbery States ]]

local function WaitForReward()
	if player.PlayerGui.AppUI:FindFirstChild("RewardSpinner") then
		repeat 
			task.wait() 
		until not player.PlayerGui.AppUI:FindFirstChild("RewardSpinner")
	end
end

local robberyState = ReplicatedStorage.RobberyState
local robberyConsts = Modules.RobberyConsts

local robberies = {
	mansion = {open = false, hasRobbed = false},
	ship = {open = false, hasRobbed = false},
	plane = {open = false, hasRobbed = false},
	crate = {open = false},
}

local UpdateStatus = function(robbery, var, val, checkStart, special)
	if not robberyState:FindFirstChild(robbery) then robberies[var][val] = false return end
	local status = robberyState:FindFirstChild(robbery).Value
	robberies[var][val] = ((status == 1 and not checkStart) and true) or ((status == 2 and not special) and true) or false
	if val == 'open' and robberies[var][val] == false then robberies[var]['hasRobbed'] = false end
end

coroutine.wrap(LPH_JIT_MAX(function()
	while task.wait() do
		UpdateStatus(robberyConsts.ENUM_ROBBERY.MANSION, 'mansion', 'open', false, true)
		UpdateStatus(robberyConsts.ENUM_ROBBERY.CARGO_SHIP, 'ship', 'open')
		robberies['crate'].open = (game.Workspace:FindFirstChild('Drop') and true) or false
	end
end))()

local function GetClosestAirdrop()
	if game.Workspace:FindFirstChild("Drop") then
		return game.Workspace:FindFirstChild("Drop")
	end

	return nil
end

-- [[ No Falldamage ]]

Modules.TagUtils.isPointInTag = LPH_NO_VIRTUALIZE(function(_, Tag)
	if Tag == 'NoFallDamage' or Tag == 'NoRagdoll' or Tag == 'NoParachute' then
		return true
	end
end)

-- [[ Vehicle stuff ]]

local InHeli = function() return ((vehicle and vehicle.Name == 'Heli') and true) or false end
local InCar = function() return ((vehicle and vehicle.Name == 'Jeep' or "Camaro") and true) or false end

local ExitVehicle = function()
	if player.Character.Humanoid.Health <= 0 or not vehicle then return end
	Modules.CharUtils.OnJump()

	repeat 
		task.wait()  
	until not vehicle or player.Character.Humanoid.Health <= 0
end

-- [[ Rendering ]]

local viableLocations = {
	Vector3.new(-846, 39, -6231), 
	Vector3.new(-1541, 39, 3311), 
	Vector3.new(-363, 39, -6340), 
	Vector3.new(-820, 39, 3306), 
	Vector3.new(44, 39, -6409), 
	Vector3.new(811, 39, 3206), 
	Vector3.new(308, 39, -6350), 
	Vector3.new(979, 39, 3173), 
	Vector3.new(683, 39, -6267), 
	Vector3.new(1303, 39, 3150), 
	Vector3.new(1350, 39, -5764), 
	Vector3.new(1976, 39, 3028), 
	Vector3.new(2698, 39, -5365) 
}

local function LoadMap()
	local originalCameraType = game:GetService("Workspace").CurrentCamera.CameraType
	game:GetService("Workspace").CurrentCamera.CameraType = Enum.CameraType.Scriptable
	for _, position in ipairs(viableLocations) do
		local tweenInfo = TweenInfo.new(
			0.6,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out,
			0,
			false,
			0
		)

		pcall(function()
			local tween = game:GetService("TweenService"):Create(game:GetService("Workspace").CurrentCamera, tweenInfo, {CFrame = CFrame.new(position)})
			tween:Play() 

			tween.Completed:Wait()
		end)
	end
	game:GetService("Workspace").CurrentCamera.CameraType = originalCameraType
end

-- [[ Gun stuff ]]

local function ShootGun()
	local currentGun = require(game:GetService("ReplicatedStorage").Game:WaitForChild("ItemSystem"):WaitForChild("ItemSystem")).GetLocalEquipped()
	if not currentGun then return end
	require(game:GetService("ReplicatedStorage").Game:WaitForChild("Item"):WaitForChild("Gun"))._attemptShoot(currentGun)
end

local function GetGun()
	local SetThreadId = (setidentity or set_thread_identity or (syn and syn.set_thread_identity) or setthreadcontext or set_thread_context)
	local IsOpen = pcall(Modules.GunShopUI.open)

	SetThreadId(2)
	Modules.GunShopUI.displayList(Modules.GunShopUtils.getCategoryData("Held"))
	SetThreadId(7)

	repeat 
		for i, v in next, Modules.GunShopUI.gui.Container.Container.Main.Container.Slider:GetChildren() do
			if v:IsA("ImageLabel") and v.Name == "Pistol" and (v.Bottom.Action.Text == "FREE" or v.Bottom.Action.Text == "EQUIP") then
				firesignal(v.Bottom.Action.MouseButton1Down)
			end
		end    

		task.wait()
	until player.Folder:FindFirstChild("Pistol")

	pcall(Modules.GunShopUI.close)
end

-- [[ Teleporting requirements ]]

local heliSpawnPos = {
	Vector3.new(725, 76, 1111),
	Vector3.new(-1255, 46, -1572),
	Vector3.new(840, 24, -3678),
	Vector3.new(-2875, 199, -4059)
}

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
	local Signal = part:GetPropertyChangedSignal("CFrame"):Connect(LPH_NO_VIRTUALIZE(function()
		local CurrentPosition = part.Position

		if DistanceXZ(CurrentPosition, OldPosition) > 7 then
			LaggedBack = true
			task.delay(0.2, function()
				LaggedBack = false
			end)
		end
	end))

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

local GetVehiclePos = LPH_JIT_MAX(function(playerPos)
	playerPos = Vector3.new(playerPos.x, 0, playerPos.z)
	local targetVehicle
	local minDist = math.huge

	for _, vehicle in pairs(game.Workspace.Vehicles:GetChildren()) do
		if vehicle.name ~= 'Heli' then continue end
		if vehicle.Seat.position.y > 300 then continue end
		local pos = vehicle.Seat.Position
		pos = Vector3.new(pos.x, 0, pos.z)
		local dist = (pos - playerPos).Magnitude
		if dist > minDist or dist < 1 then continue end
		local hit, _ = rayCast(vehicle.Seat.Position, rayDirs.up)
		if hit then continue end
		minDist = dist
		targetVehicle = vehicle
	end

	if targetVehicle then return targetVehicle.Seat.Position, targetVehicle end

	local positions = heliSpawnPos
	for _, pos in pairs(positions) do
		local dist = (pos - playerPos).Magnitude
		if dist > minDist or dist < 1 then continue end
		minDist = dist
		targetVehicle = pos
	end

	return targetVehicle, nil
end)

local function NoclipStart()
	local NoclipLoop = LPH_NO_VIRTUALIZE(function()
		pcall(function()
			for i, child in pairs(char:GetDescendants()) do
				if child:IsA("BasePart") and child.CanCollide == true then
					child.CanCollide = false
				end
			end
		end)
	end)

	local Noclipper = RunService.Stepped:Connect(NoclipLoop)

	return {
		Stop = function()
			Noclipper:Disconnect()
		end
	}
end

local function IsArrested()
	if player.PlayerGui.MainGui.CellTime.Visible or player.Folder:FindFirstChild("Cuffed") then
		return true
	end

	return false
end

local function FlightMove(pos)
	LPH_NO_VIRTUALIZE(function()
		local LagCheck = LagBackCheck(root)
		local LagbackCount = 0
		local speed = (InHeli() and -config['HeliSpeed']) or (vehicle and -config['VehicleSpeed']) or -config['FlightSpeed']
		local GetPos = function() return Vector3.new(pos.x, 500, pos.z) end
		char:PivotTo(CFrame.new(root.Position.x, 500, root.Position.z))

		local dist = GetRoot().Position - GetPos()
		while dist.Magnitude > 10 do	
			dist = GetRoot().Position - GetPos()
			local velocity = dist.Unit * speed
			velocity = Vector3.new(velocity.x, 0, velocity.z)

			GetRoot().Velocity = velocity
			char:PivotTo(CFrame.new(root.Position.x, 500, root.Position.z))
			task.wait()
		end

		GetRoot().Velocity = Vector3.zero
		char:PivotTo(CFrame.new(GetPos()))
	end)()
end

local function GoToGround()
	while task.wait() do
		local _, pos = rayCast(root.Position, rayDirs.down)
		if pos then 
			char:PivotTo(CFrame.new(root.Position.x, pos.y + 2, root.Position.z)) 
			task.wait(0.3) 
			GetRoot().Velocity = Vector3.zero 
			return 
		end
	end
end

-- [[ Teleporting stuff + Car stuff + Raycasting ]]

local TeleportParams = RaycastParams.new()
local GetVehicleModel = Modules.Vehicle.GetLocalVehicleModel
local Packet = Modules.Vehicle.GetLocalVehiclePacket

local function CheckRaycast(Position, Vector)
	local Raycasted = game.Workspace:Raycast(Position, Vector, TeleportParams)

	return Raycasted ~= nil
end

local function TeleporterC(pos, duration)
	local tper = game:GetService("RunService").Heartbeat:Connect(function()
		vehicleRoot.CFrame = pos
	end)

	wait(duration)

	tper:Disconnect()
end

local function HidePickingTeam()
	local TeamChooseUI = require(game:GetService("ReplicatedStorage").TeamSelect.TeamChooseUI)


	repeat task.wait() pcall(function() TeamChooseUI.Hide() end) until playerGui:FindFirstChild("TeamSelectGui") == nil or playerGui:FindFirstChild("TeamSelectGui").Enabled == false or game:GetService("Players").LocalPlayer.TeamColor == BrickColor.new("Bright red") or player.Character.Humanoid.Health <= 0
end

local function Travel()
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
						if v:IsA("Part") or v:IsA("MeshPart") then
							v.CanCollide = false
						end
					end
					break 
				end
			end
		else
      local function TeleportToLocation(CFrame)
    game.Players.LocalPlayer.Character.Humanoid.Health = 0
    game.Players.LocalPlayer.CharacterAdded:Wait()
    game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').CFrame = CFrame
      end
			for i, v in next, heliSpawnPos do
				TeleportToLocation(v)
				GoToGround()
				task.wait(1)
				pos1, targetVehicle = GetVehiclePos(root.Position)
				if targetVehicle then
					for i,v in pairs(targetVehicle:GetDescendants()) do
						if v:IsA("Part") or v:IsA("MeshPart") then
							v.CanCollide = false
						end
					end
					break
				end
			end
		end 
		task.wait()
	end
end

local function SmallTP(cframe, speed)
	if not char or not root or IsArrested() then
		return false
	end

	if speed == nil then
		speed = 95
	end

	local IsTargetMoving = type(cframe) == "function"
	local LagCheck = LagBackCheck(root)
	local Noclip = NoclipStart()
	local TargetPos = (IsTargetMoving and cframe() or cframe).Position
	local LagbackCount = 0
	local Success = true

	local Mover = Instance.new("BodyVelocity", root)
	Mover.P = 3000
	Mover.MaxForce = Vector3.new(9e9, 9e9, 9e9)

	repeat
		if not root or humanoid.Health == 0 or IsArrested() then
			Success = false
		else
			TargetPos = (IsTargetMoving and cframe() or cframe).Position
			Mover.Velocity = CFrame.new(root.Position, TargetPos).LookVector * speed

			humanoid:SetStateEnabled("Running", false)
			humanoid:SetStateEnabled("Climbing", false)

			task.wait(0.03) 

			if LaggedBack then
				LagbackCount = LagbackCount + 1
				Mover.Velocity = Vector3.zero
				task.wait(1)

				if LagbackCount == 4 then
					Mover:Destroy()
					Noclip:Stop()
					LagCheck:Stop()

					humanoid.Health = 0
					Success = false
					task.wait(5)
				end
			end
		end
	until (root.Position - TargetPos).Magnitude <= 5 or not Success

	if Success then
		Mover.Velocity = Vector3.new(0, 0, 0)
		TargetPos = (IsTargetMoving and cframe() or cframe).Position
		root.CFrame = CFrame.new(TargetPos)
		task.wait(0.001)

		humanoid:SetStateEnabled("Running", true)
		humanoid:SetStateEnabled("Climbing", true)

		Mover:Destroy()
		Noclip:Stop()
		LagCheck:Stop()
	end

	return Success
end

local function sendMessage(msg)
    game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral"):SendAsync(msg)
end

local function getServerHash()
    for _, child in pairs(game:GetService("ReplicatedStorage"):GetChildren()) do
        if select(2, string.gsub(child.Name, "%-", "")) == 4 then
            return child.Name
        end
    end
    return nil
end

local function getEventValue(key)
    local EventTable = (function()
        for i, v in ipairs(getgc(false)) do
            if typeof(v) == "function" and islclosure(v) and debug.info(v, "n") == "EventFireServer" then
                local upvalues = debug.getupvalues(v)
                if typeof(upvalues[3]) == "table" then
                    return upvalues[3]
                end
            end
        end
    end)()
    return EventTable and EventTable[key]
end

local function teamMenu()
    local serverHash = getServerHash()
    local switchHash = getEventValue("jwfcps55")
    local args = {
        [1] = switchHash
    }
    game:GetService("ReplicatedStorage"):FindFirstChild(serverHash):FireServer(unpack(args))
end

local function selectTeam(team)
    local serverHash = getServerHash()
    local prisonerHash = getEventValue("mto4108g")
    local args = {
        [1] = prisonerHash,
        [2] = team,
    }
    game:GetService("ReplicatedStorage"):FindFirstChild(serverHash):FireServer(unpack(args))
end

local function getPistol()
    local serverHash = getServerHash()
    local pistolHash = getEventValue("l5cuht8e")
    local args = {
        [1] = pistolHash,
        [2] = "Pistol",
    }
    game:GetService("ReplicatedStorage"):FindFirstChild(serverHash):FireServer(unpack(args))
end

local RobMansion = function()
    local OriginalRaycast = Modules.Raycast.RayIgnoreNonCollideWithIgnoreList
    if InHeli() or InCar() then 
        ExitVehicle()
    end
    sendMessage("Entering Mansion")
    local MansionRobbery = workspace.MansionRobbery
    local TouchToEnter = MansionRobbery.Lobby.EntranceElevator.TouchToEnter
    local ElevatorDoor = MansionRobbery.ArrivalElevator.Floors:GetChildren()[1].DoorLeft.InnerModel.Door
    local MansionTeleportCFrame = TouchToEnter.CFrame - Vector3.new(0, TouchToEnter.Size.Y / 2 - player.Character.Humanoid.HipHeight * 2, -TouchToEnter.Size.Z)
    local MansionActivateDoor = CFrame.new(3154, -205, -4558)
    local FailMansion = false
    local FailedStart = false

    task.delay(10, function()
        FailMansion = true
    end)

    local tper1 = RunService.Heartbeat:Connect(function()
        root.CFrame = MansionTeleportCFrame		
    end)

    repeat
        task.wait()
        firetouchinterest(root, TouchToEnter, 0)
        task.wait()
        firetouchinterest(root, TouchToEnter, 1)
    until Modules.MansionUtils.isPlayerInElevator(MansionRobbery, player) or FailMansion

    tper1:Disconnect()
    if FailMansion then
        humanoid.Health = 0
        return
    end
    getPistol()
    repeat
        wait(0.1)
    until ElevatorDoor.Position.X > 3208
    for _, instance in pairs(MansionRobbery.Lasers:GetChildren()) do
        instance:Remove()
    end
    for _, instance in pairs(MansionRobbery.LaserTraps:GetChildren()) do
        instance:Remove()
    end  
    sendMessage("Skipping Mansion Obby")
    local tper2 = RunService.Heartbeat:Connect(function()
        root.CFrame = MansionActivateDoor		
    end)
    task.delay(12.5, function()
        FailedStart = true
    end)
    repeat task.wait() until MansionRobbery:GetAttribute("MansionRobberyProgressionState") == 3 or player.Character.Humanoid.Health <= 0 or not char or FailedStart
    tper2:Disconnect()

    if FailedStart then
        humanoid.Health = 0
        return
    end
    sendMessage("Waiting for Cutscene to end")
    Modules.MansionUtils.getProgressionStateChangedSignal(MansionRobbery):Wait()
    sendMessage("Killing the CEO")
    local BV = Instance.new("BodyVelocity", root)
    BV.P = 3000
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BV.Velocity = Vector3.new()
    local origY = root.CFrame.Y
    root.CFrame = CFrame.new(root.CFrame.X, root.CFrame.Y + 9, root.CFrame.Z - 30)
    local NPC_new = Modules.Npc.new
    local NPCShared_goTo = Modules.NpcShared.goTo
    Modules.Npc.new = function(NPCObject, ...)
        if NPCObject.Name ~= "ActiveBoss" then
            for i,v in pairs(NPCObject:GetDescendants()) do
                pcall(function()
                    v.Transparency = 1
                end)
            end
        end
        return NPC_new(NPCObject, ...)
    end
    Modules.Npc.GetTarget = function(...)
        return MansionRobbery and MansionRobbery:FindFirstChild("ActiveBoss") and MansionRobbery:FindFirstChild("ActiveBoss").HumanoidRootPart
    end
    Modules.NpcShared.goTo = function(NPCData, Pos)
        if MansionRobbery and MansionRobbery:FindFirstChild("ActiveBoss") then
            return NPCShared_goTo(NPCData, MansionRobbery:FindFirstChild("ActiveBoss").HumanoidRootPart.Position)
        end
    end
    game.Workspace.Items.DescendantAdded:Connect(function(Des)
        if Des:IsA("BasePart") then
            Des.Transparency = 1
            Des:GetPropertyChangedSignal("Transparency"):Connect(function()
                Des.Transparency = 1
            end)
        end
    end)
    for i,v in pairs(ReplicatedStorage.Game.Item:GetChildren()) do
        require(v).ReloadDropAmmoVisual = function() end
        require(v).ReloadDropAmmoSound = function() end
        require(v).ReloadRefillAmmoSound = function() end
        require(v).ShootSound = function() end
    end
    getfenv(Modules.BulletEmitter.Emit).Instance = {
        new = function()
            return {
                Destroy = function() end
            }
        end
    }
    local BossCEO = MansionRobbery:WaitForChild("ActiveBoss")
    local OldHealth = BossCEO.Humanoid.Health
    LPH_NO_VIRTUALIZE(function()
        Modules.Raycast.RayIgnoreNonCollideWithIgnoreList = function(...)
            local arg = {RayIgnore(...)}

            if (tostring(getfenv(2).script) == "BulletEmitter" or tostring(getfenv(2).script) == "Taser") then
                arg[1] = BossCEO.Head
                arg[2] = BossCEO.Head.Position
            end

            return unpack(arg)
        end
    end)()
    require(ReplicatedStorage.NPC.NPC).GetTarget = function()
        return BossCEO:FindFirstChild("Head")
    end
    while player.Folder:FindFirstChild("Pistol") and BossCEO and BossCEO:FindFirstChild("HumanoidRootPart") and BossCEO.Humanoid.Health ~= 1 do
        require(Modules.EquipThing).AttemptSetEquipped({obj = game:GetService("Players").LocalPlayer.Folder["Pistol"]}, true)
        player.Folder.Pistol.InventoryEquipRemote:FireServer(true)
        task.wait()
        ShootGun()
    end

    root.CFrame = CFrame.new(root.CFrame.X, origY, root.CFrame.Z)
    BV:Destroy()

    require(Modules.EquipThing).AttemptSetEquipped({obj = game:GetService("Players").LocalPlayer.Folder["Pistol"]}, false)

    player.Folder.Pistol.InventoryEquipRemote:FireServer(false)
    repeat task.wait() until playerGui.AppUI:FindFirstChild("RewardSpinner")

    sendMessage("Exiting Mansion")

    if not SmallTP(CFrame.new(3122, -205, -4527)) then return end
    if not SmallTP(CFrame.new(3119, -205, -4439)) then return end
    if not SmallTP(CFrame.new(3098, -205, -4440)) then return end
    if not SmallTP(CFrame.new(3097, -221, -4519)) then return end
    if not SmallTP(CFrame.new(3076, -221, -4518)) then return end
    if not SmallTP(CFrame.new(3075, -221, -4485)) then return end
    if not SmallTP(CFrame.new(3063, -221, -4486)) then return end
    if not SmallTP(CFrame.new(3064, -220, -4474)) then return end
    if not SmallTP(CFrame.new(3124, 51, -4415)) then return end
    if not SmallTP(CFrame.new(3106, 51, -4412)) then return end
    if not SmallTP(CFrame.new(3106, 57, -4377)) then return end
    sendMessage("Successfully Assisted Mansion!")
    Modules.Raycast.RayIgnoreNonCollideWithIgnoreList = OriginalRaycast
    teamMenu()
    task.wait(1)
    selectTeam("Prisoner")
    task.wait(.1)
end

RobMansion()
