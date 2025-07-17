--[[
    Enhanced Jailbreak Teleport Script
    
    Improvements made:
    1. More accurate collision detection
    2. Better pathfinding fallback
    3. Optimized vehicle handling
    4. Smoother movement transitions
    5. Fixed roof detection issues
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--// Variables
local player = Players.LocalPlayer
local Character = player.Character or player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local dependencies = {
    variables = {
        up_vector = Vector3.new(0, 500, 0),
        raycast_params = RaycastParams.new(),
        path = PathfindingService:CreatePath({WaypointSpacing = 3}),
        player_speed = 150, 
        vehicle_speed = 450,
        teleporting = false,
        stopVelocity = false,
        roof_check_height = 100, -- Increased from 500 to 100 for more accurate detection
        min_clearance_height = 20 -- Minimum clearance needed to teleport up
    },
    modules = {
        ui = require(ReplicatedStorage.Module.UI),
        store = require(ReplicatedStorage.App.store),
        player_utils = require(ReplicatedStorage.Game.PlayerUtils),
        vehicle_data = require(ReplicatedStorage.Game.Garage.VehicleData),
        character_util = require(ReplicatedStorage.Game.CharacterUtil),
        paraglide = require(ReplicatedStorage.Game.Paraglide)
    },
    vehicle_types = {
        helicopters = { Heli = true },
        motorcycles = { Volt = true },
        free_vehicles = { Camaro = true },
        unsupported_vehicles = { SWATVan = true }
    },
    door_positions = {}    
}

local movement = {}
local utilities = {}

--// Improved collision detection system
function utilities:is_position_clear(position)
    -- Check multiple points above to ensure clear path
    for height = 5, dependencies.variables.roof_check_height, 20 do
        local check_pos = position + Vector3.new(0, height, 0)
        local raycast_result = workspace:Raycast(
            position,
            Vector3.new(0, height, 0),
            dependencies.variables.raycast_params
        )
        
        if raycast_result then
            return false, raycast_result.Position.Y - position.Y
        end
    end
    return true, dependencies.variables.roof_check_height
end

--// Improved door collision toggle
function utilities:toggle_door_collision(door, toggle)
    if not door or not door:FindFirstChild("Model") then return end
    
    for _, child in ipairs(door.Model:GetChildren()) do 
        if child:IsA("BasePart") then 
            child.CanCollide = toggle
        end
    end
end

--// Optimized vehicle finding
function utilities:get_nearest_vehicle(tried)
    local nearest, min_distance = nil, math.huge
    tried = tried or {}

    for _, action in pairs(dependencies.modules.ui.CircleAction.Specs) do
        if action.IsVehicle and action.ShouldAllowEntry and action.Enabled and action.Name == "Enter Driver" then
            local vehicle = action.ValidRoot
            
            -- Skip if vehicle is in tried list or doesn't meet requirements
            if not table.find(tried, vehicle) and workspace.VehicleSpawns:FindFirstChild(vehicle.Name) then
                if not dependencies.vehicle_types.unsupported_vehicles[vehicle.Name] and 
                   (dependencies.modules.store._state.garageOwned.Vehicles[vehicle.Name] or 
                    dependencies.vehicle_types.free_vehicles[vehicle.Name]) and 
                   not vehicle.Seat.Player.Value then
                    
                    -- Check if position above vehicle is clear
                    local is_clear, clearance = utilities:is_position_clear(vehicle.Seat.Position)
                    if is_clear or clearance > dependencies.variables.min_clearance_height then
                        local distance = (vehicle.Seat.Position - HumanoidRootPart.Position).Magnitude
                        
                        if distance < min_distance then 
                            min_distance = distance
                            nearest = action
                        end
                    end
                end
            end
        end
    end

    return nearest
end

--// Enhanced pathfinding with better clearance checks
function movement:pathfind_to_clear_area(tried_positions)
    local best_position, min_distance = nil, math.huge
    tried_positions = tried_positions or {}

    -- First check immediate vicinity for clear spots
    for angle = 0, 360, 45 do
        local offset = Vector3.new(math.cos(math.rad(angle)) * 10, 0, math.sin(math.rad(angle)) * 10)
        local check_pos = HumanoidRootPart.Position + offset
        
        local is_clear = utilities:is_position_clear(check_pos)
        if is_clear and not table.find(tried_positions, check_pos) then
            local distance = (check_pos - HumanoidRootPart.Position).Magnitude
            if distance < min_distance then
                min_distance = distance
                best_position = check_pos
            end
        end
    end

    -- If no clear spot found nearby, use door positions
    if not best_position then
        for _, door_data in ipairs(dependencies.door_positions) do
            if not table.find(tried_positions, door_data.position) then
                local is_clear = utilities:is_position_clear(door_data.position)
                if is_clear then
                    local distance = (door_data.position - HumanoidRootPart.Position).Magnitude
                    if distance < min_distance then
                        min_distance = distance
                        best_position = door_data.position
                    end
                end
            end
        end
    end

    if best_position then
        -- Compute path to the clear position
        local path = dependencies.variables.path
        path:ComputeAsync(HumanoidRootPart.Position, best_position)

        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            
            for _, waypoint in ipairs(waypoints) do
                HumanoidRootPart.CFrame = CFrame.new(waypoint.Position + Vector3.new(0, 2.5, 0))
                
                -- Early exit if we find a clear spot along the path
                local is_clear = utilities:is_position_clear(HumanoidRootPart.Position)
                if is_clear then
                    return true
                end
                
                task.wait(0.05)
            end
            return true
        end
    end
    
    return false
end

--// Improved movement function with better collision handling
function movement:move_to_position(target_cframe, speed, is_vehicle, vehicle_object, tried_vehicles)
    local target_position = target_cframe.Position
    local current_position = is_vehicle and vehicle_object.Engine.Position or HumanoidRootPart.Position
    local part_to_move = is_vehicle and vehicle_object.Engine or HumanoidRootPart
    
    -- Check if we need to pathfind first
    local is_clear, clearance = utilities:is_position_clear(current_position)
    if not is_clear and clearance < dependencies.variables.min_clearance_height then
        movement:pathfind_to_clear_area()
        task.wait(0.5)
    end
    
    -- Move up to safe height if needed
    if not is_vehicle then
        local desired_height = math.max(target_position.Y, current_position.Y) + 50
        local ascent_cframe = CFrame.new(current_position.X, desired_height, current_position.Z)
        
        part_to_move.CFrame = ascent_cframe
        task.wait(0.1)
    end
    
    -- Horizontal movement
    local horizontal_target = Vector3.new(target_position.X, part_to_move.Position.Y, target_position.Z)
    local distance = (horizontal_target - part_to_move.Position).Magnitude
    local direction = (horizontal_target - part_to_move.Position).Unit
    
    while distance > 10 do
        local move_step = direction * math.min(speed * 0.1, distance)
        part_to_move.CFrame = CFrame.new(part_to_move.Position + move_step)
        
        distance = (horizontal_target - part_to_move.Position).Magnitude
        task.wait()
    end
    
    -- Final descent
    part_to_move.CFrame = target_cframe
    part_to_move.Velocity = Vector3.zero
end

--// Initialize raycast parameters
dependencies.variables.raycast_params.FilterType = Enum.RaycastFilterType.Blacklist
dependencies.variables.raycast_params.FilterDescendantsInstances = { Character, workspace.Vehicles }

--// Dynamic environment handling
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Rain" then 
        table.insert(dependencies.variables.raycast_params.FilterDescendantsInstances, child)
    end
end)

player.CharacterAdded:Connect(function(new_character)
    Character = new_character
    HumanoidRootPart = new_character:WaitForChild("HumanoidRootPart")
    table.insert(dependencies.variables.raycast_params.FilterDescendantsInstances, new_character)
end)

--// Vehicle type categorization
for _, vehicle_data in pairs(dependencies.modules.vehicle_data) do
    if vehicle_data.Type == "Heli" then
        dependencies.vehicle_types.helicopters[vehicle_data.Make] = true
    elseif vehicle_data.Type == "Motorcycle" then
        dependencies.vehicle_types.motorcycles[vehicle_data.Make] = true
    end

    if vehicle_data.Type ~= "Chassis" and vehicle_data.Type ~= "Motorcycle" and 
       vehicle_data.Type ~= "Heli" and vehicle_data.Type ~= "DuneBuggy" and 
       vehicle_data.Make ~= "Volt" then
        dependencies.vehicle_types.unsupported_vehicles[vehicle_data.Make] = true
    end
    
    if not vehicle_data.Price then
        dependencies.vehicle_types.free_vehicles[vehicle_data.Make] = true
    end
end

--// Precompute clear positions near doors
for _, door in ipairs(workspace:GetDescendants()) do
    if door.Name:sub(-4) == "Door" then 
        local touch_part = door:FindFirstChild("Touch")
        
        if touch_part and touch_part:IsA("BasePart") then
            -- Check in 4 directions around door
            for angle = 0, 270, 90 do
                local offset = touch_part.CFrame.LookVector * 10
                offset = CFrame.Angles(0, math.rad(angle), 0) * offset
                local check_pos = touch_part.Position + offset
                
                local is_clear = utilities:is_position_clear(check_pos)
                if is_clear then
                    table.insert(dependencies.door_positions, {
                        instance = door,
                        position = check_pos
                    })
                    break
                end
            end
        end
    end
end

--// Anti-cheat bypass hooks
local original_isPointInTag = dependencies.modules.player_utils.isPointInTag
dependencies.modules.player_utils.isPointInTag = function(point, tag)
    if dependencies.variables.teleporting and (tag == "NoRagdoll" or tag == "NoFallDamage") then
        return true
    end
    return original_isPointInTag(point, tag)
end

local originalIsFlying = dependencies.modules.paraglide.IsFlying
dependencies.modules.paraglide.IsFlying = function(...)
    if dependencies.variables.teleporting and getinfo(2, "s").source:find("Falling") then
        return true
    end
    return originalIsFlying(...)
end

--// Velocity control system
task.spawn(function()
    while task.wait() do
        if dependencies.variables.stopVelocity and HumanoidRootPart then
            HumanoidRootPart.Velocity = Vector3.zero
        end
    end
end)

--// Main teleport function with improved logic
local function teleport(target_cframe, tried_vehicles)
    -- Initial checks
    if not HumanoidRootPart then return end
    
    local target_position = target_cframe.Position
    local current_position = HumanoidRootPart.Position
    local distance = (target_position - current_position).Magnitude
    
    -- Direct teleport if close enough and clear path
    if distance <= 50 then
        local raycast_result = workspace:Raycast(
            current_position,
            (target_position - current_position).Unit * distance,
            dependencies.variables.raycast_params
        )
        
        if not raycast_result then
            HumanoidRootPart.CFrame = target_cframe
            return
        end
    end
    
    -- Vehicle handling
    tried_vehicles = tried_vehicles or {}
    local nearest_vehicle = utilities:get_nearest_vehicle(tried_vehicles)
    local vehicle_object = nearest_vehicle and nearest_vehicle.ValidRoot
    
    dependencies.variables.teleporting = true
    
    if vehicle_object then
        local vehicle_distance = (vehicle_object.Seat.Position - current_position).Magnitude
        
        -- Decide whether to use vehicle or go directly
        if distance < vehicle_distance * 0.7 then -- Vehicle only if significantly closer
            movement:move_to_position(target_cframe, dependencies.variables.player_speed, false)
        else
            -- Approach vehicle
            movement:move_to_position(
                vehicle_object.Seat.CFrame, 
                dependencies.variables.player_speed, 
                false, 
                nil, 
                tried_vehicles
            )
            
            -- Enter vehicle
            dependencies.variables.stopVelocity = true
            local enter_attempts = 0
            
            repeat
                nearest_vehicle:Callback(true)
                enter_attempts += 1
                task.wait(0.1)
            until enter_attempts >= 5 or vehicle_object.Seat.PlayerName.Value == player.Name
            
            dependencies.variables.stopVelocity = false
            
            if vehicle_object.Seat.PlayerName.Value ~= player.Name then
                table.insert(tried_vehicles, vehicle_object)
                return teleport(target_cframe, tried_vehicles)
            end
            
            -- Move vehicle to target
            movement:move_to_position(
                target_cframe, 
                dependencies.variables.vehicle_speed, 
                true, 
                vehicle_object
            )
            
            -- Exit vehicle
            repeat
                task.wait(0.15)
                dependencies.modules.character_util.OnJump()
            until not vehicle_object or vehicle_object.Seat.PlayerName.Value ~= player.Name
        end
    else
        -- Direct movement without vehicle
        movement:move_to_position(target_cframe, dependencies.variables.player_speed, false)
    end
    
    task.wait(0.5)
    dependencies.variables.teleporting = false
end

return teleport
