--// services
local replicated_storage = game:GetService("ReplicatedStorage")
local run_service = game:GetService("RunService")
local pathfinding_service = game:GetService("PathfindingService")
local players = game:GetService("Players")
local tween_service = game:GetService("TweenService")

--// variables
local player = players.LocalPlayer

local dependencies = {
    variables = {
        up_vector = Vector3.new(0, 500, 0),
        path = pathfinding_service:CreatePath({WaypointSpacing = 3}),
        player_speed = 150, 
        vehicle_speed = 650,
        teleporting = false,
        stopVelocity = false,
        rayDirs = {
            up = Vector3.new(0, 999, 0),
            down = Vector3.new(0, -999, 0)
        }
    },
    modules = {
        ui = require(replicated_storage.Module.UI),
        store = require(replicated_storage.App.store),
        player_utils = require(replicated_storage.Game.PlayerUtils),
        vehicle_data = require(replicated_storage.Game.Garage.VehicleData),
        character_util = require(replicated_storage.Game.CharacterUtil),
        paraglide = require(replicated_storage.Game.Paraglide)
    },
    helicopters = { Heli = true },
    motorcycles = { Volt = true },
    free_vehicles = { Camaro = true, Model3 = true },
    unsupported_vehicles = { SWATVan = true, Dirtbike = true },
    door_positions = { }    
}

local movement = { }
local utilities = { }

--// Improved raycast function
function utilities:rayCast(pos, dir)
    local ignoreList = {}
    if player.Character then table.insert(ignoreList, player.Character) end
    if workspace:FindFirstChild("Rain") then table.insert(ignoreList, workspace.Rain) end
    
    local params = RaycastParams.new()
    params.RespectCanCollide = true
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = true
    local result = workspace:Raycast(pos, dir, params)
    if result then return result.Instance, result.Position else return nil, nil end
end

function utilities:toggle_door_collision(door, toggle)
    for _, child in next, door.Model:GetChildren() do 
        if child:IsA("BasePart") then 
            child.CanCollide = toggle
        end 
    end
end

function utilities:get_nearest_vehicle(tried)
    local nearest
    local distance = math.huge

    for _, action in next, dependencies.modules.ui.CircleAction.Specs do
        if action.IsVehicle and action.ShouldAllowEntry == true and action.Enabled == true and action.Name == "Enter Driver" then
            local vehicle = action.ValidRoot

            if not table.find(tried, vehicle) and workspace.VehicleSpawns:FindFirstChild(vehicle.Name) then
                if not dependencies.unsupported_vehicles[vehicle.Name] and 
                   (dependencies.modules.store._state.garageOwned.Vehicles[vehicle.Name] or dependencies.free_vehicles[vehicle.Name]) and 
                   not vehicle.Seat.Player.Value then
                    
                    local _, pos = utilities:rayCast(vehicle.Seat.Position, dependencies.variables.rayDirs.up)
                    if not pos then
                        local magnitude = (vehicle.Seat.Position - player.Character.HumanoidRootPart.Position).Magnitude

                        if magnitude < distance then 
                            distance = magnitude
                            nearest = action
                        end
                    end
                end
            end
        end
    end

    return nearest
end

function utilities:is_in_vehicle()
    if not player.Character then return false end
    return player.Character:FindFirstChild("InVehicle") ~= nil
end

function utilities:get_current_vehicle()
    if not utilities:is_in_vehicle() then return nil end
    
    for _, vehicle in ipairs(workspace.Vehicles:GetChildren()) do
        if vehicle:FindFirstChild("Seat") and vehicle.Seat.PlayerName.Value == player.Name then
            return vehicle
        end
    end
    
    return nil
end

function movement:pathfind(tried)
    local distance = math.huge
    local nearest

    local tried = tried or { }
    
    for _, value in next, dependencies.door_positions do
        if not table.find(tried, value) then
            local magnitude = (value.position - player.Character.HumanoidRootPart.Position).Magnitude
            
            if magnitude < distance then 
                distance = magnitude
                nearest = value
            end
        end
    end

    table.insert(tried, nearest)

    utilities:toggle_door_collision(nearest.instance, false)

    local path = dependencies.variables.path
    path:ComputeAsync(player.Character.HumanoidRootPart.Position, nearest.position)

    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()

        for _, waypoint in ipairs(waypoints) do 
            player.Character.HumanoidRootPart.CFrame = CFrame.new(waypoint.Position + Vector3.new(0, 2.5, 0))

            local _, pos = utilities:rayCast(player.Character.HumanoidRootPart.Position, dependencies.variables.rayDirs.up)
            if not pos then
                utilities:toggle_door_collision(nearest.instance, true)
                return
            end

            task.wait(0.05)
        end
    end

    utilities:toggle_door_collision(nearest.instance, true)
    movement:pathfind(tried)
end

function movement:move_to_position(part, cframe, speed, car, target_vehicle, tried_vehicles)
    local vector_position = cframe.Position
    
    local _, pos = utilities:rayCast(part.Position, dependencies.variables.rayDirs.up)
    if not car and pos then
        movement:pathfind()
        task.wait(0.5)
    end
    
    local y_level = 500
    local higher_position = Vector3.new(vector_position.X, y_level, vector_position.Z)

    repeat
        local velocity_unit = (higher_position - part.Position).Unit * speed
        part.Velocity = Vector3.new(velocity_unit.X, 0, velocity_unit.Z)

        task.wait()

        part.CFrame = CFrame.new(part.CFrame.X, y_level, part.CFrame.Z)

        if target_vehicle and target_vehicle.Seat.Player.Value then
            table.insert(tried_vehicles, target_vehicle)

            local nearest_vehicle = utilities:get_nearest_vehicle(tried_vehicles)
            local vehicle_object = nearest_vehicle and nearest_vehicle.ValidRoot

            if vehicle_object then 
                movement:move_to_position(player.Character.HumanoidRootPart, vehicle_object.Seat.CFrame, 135, false, vehicle_object)
            end

            return
        end
    until (part.Position - higher_position).Magnitude < 10

    part.CFrame = CFrame.new(part.Position.X, vector_position.Y, part.Position.Z)
    part.Velocity = Vector3.zero
end

-- Initialize vehicle data
for _, vehicle_data in next, dependencies.modules.vehicle_data do
    if vehicle_data.Type == "Heli" then
        dependencies.helicopters[vehicle_data.Make] = true
    elseif vehicle_data.Type == "Motorcycle" then
        dependencies.motorcycles[vehicle_data.Make] = true
    end

    if vehicle_data.Type ~= "Chassis" and vehicle_data.Type ~= "Motorcycle" and vehicle_data.Type ~= "Heli" and vehicle_data.Type ~= "DuneBuggy" and vehicle_data.Make ~= "Volt" then
        dependencies.unsupported_vehicles[vehicle_data.Make] = true
    end
    
    if not vehicle_data.Price then
        dependencies.free_vehicles[vehicle_data.Make] = true
    end
end

-- Initialize door positions
for _, value in next, workspace:GetDescendants() do
    if value.Name:sub(-4, -1) == "Door" then 
        local touch_part = value:FindFirstChild("Touch")

        if touch_part and touch_part:IsA("BasePart") then
            for distance = 5, 100, 5 do 
                local forward_position = touch_part.Position + touch_part.CFrame.LookVector * (distance + 3)
                local backward_position = touch_part.Position + touch_part.CFrame.LookVector * -(distance + 3)
                
                local _, forward_pos = utilities:rayCast(forward_position, dependencies.variables.rayDirs.up)
                if not forward_pos then
                    table.insert(dependencies.door_positions, { instance = value, position = forward_position })
                    break
                else
                    local _, backward_pos = utilities:rayCast(backward_position, dependencies.variables.rayDirs.up)
                    if not backward_pos then
                        table.insert(dependencies.door_positions, { instance = value, position = backward_position })
                        break
                    end
                end
            end
        end
    end
end

-- Hook functions to prevent fall damage while teleporting
local old_is_point_in_tag = dependencies.modules.player_utils.isPointInTag
dependencies.modules.player_utils.isPointInTag = function(point, tag)
    if dependencies.variables.teleporting and (tag == "NoRagdoll" or tag == "NoFallDamage") then
        return true
    end
    
    return old_is_point_in_tag(point, tag)
end

local oldIsFlying = dependencies.modules.paraglide.IsFlying
dependencies.modules.paraglide.IsFlying = function(...)
    if dependencies.variables.teleporting and getinfo(2, "s").source:find("Falling") then
        return true
    end
    
    return oldIsFlying(...)
end

-- Velocity stopper
task.spawn(function()
    while task.wait() do
        if dependencies.variables.stopVelocity and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.Velocity = Vector3.zero
        end
    end
end)

local function spawnCar()
    local args = {
        [1] = "Chassis",
        [2] = "Model3"
    }
    game:GetService("ReplicatedStorage").GarageSpawnVehicle:FireServer(unpack(args))
end

local function teleport(cframe, tried)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local relative_position = (cframe.Position - player.Character.HumanoidRootPart.Position)
    local target_distance = relative_position.Magnitude

    local _, hit_pos = utilities:rayCast(player.Character.HumanoidRootPart.Position, relative_position.Unit * target_distance)
    if target_distance <= 20 and not hit_pos then 
        player.Character.HumanoidRootPart.CFrame = cframe 
        return
    end 

    local tried = tried or {}
    local current_vehicle = utilities:get_current_vehicle()
    
    dependencies.variables.teleporting = true

    if current_vehicle then
        movement:move_to_position(current_vehicle.Engine, cframe, dependencies.variables.vehicle_speed, true)
    else
        local nearest_vehicle = utilities:get_nearest_vehicle(tried)
        local vehicle_object = nearest_vehicle and nearest_vehicle.ValidRoot

        if vehicle_object then 
            local vehicle_distance = (vehicle_object.Seat.Position - player.Character.HumanoidRootPart.Position).Magnitude
            
            if vehicle_object.Seat.PlayerName.Value ~= player.Name then
                movement:move_to_position(player.Character.HumanoidRootPart, vehicle_object.Seat.CFrame, dependencies.variables.player_speed, false, vehicle_object, tried)

                dependencies.variables.stopVelocity = true

                local enter_attempts = 1

                repeat
                    nearest_vehicle:Callback(true)
                    enter_attempts = enter_attempts + 1
                    task.wait(0.1)
                until enter_attempts == 10 or vehicle_object.Seat.PlayerName.Value == player.Name

                dependencies.variables.stopVelocity = false

                if vehicle_object.Seat.PlayerName.Value ~= player.Name then
                    table.insert(tried, vehicle_object)
                    return teleport(cframe, tried)
                end
            end

            movement:move_to_position(vehicle_object.Engine, cframe, dependencies.variables.vehicle_speed, true)
        else
            movement:move_to_position(player.Character.HumanoidRootPart, cframe, dependencies.variables.player_speed);
        end
    end

    task.wait(0.5)
    dependencies.variables.teleporting = false
end

return teleport
