--[[
    Notes: 

    - This script is in early development and can be buggy
    - Some of this code is old and unoptimized
    - This is mainly meant for longer teleports, short teleports inside of buldings and what not would be better to be implemented yourself
    - You have to wait for the current teleport to finish to use it again

    Anticheat Explanation: 

    - Jailbreak has two main movement related security measures: anti teleport and anti noclip
    - Jailbreaks anti noclip works in a way where not only can you not walk through objects, but you also get flagged if you teleport through them
    - Due to cars in jailbreak being faster than players, the anti teleport allows you to move a lot faster if youre inside a car
    - Jailbreaks anti teleport does not flag you for teleporting directly up or directly down
    - The goal of this script is to combine a few methods to make the fastest possible teleporation method while not triggering any of the security measures
    
    Teleportation Steps:

    - Check if the player is under a roof/any object
    - If the player is under a roof, use pathfinding to get to an area which has no roof above it (to avoid getting flagged by the anti noclip when we try to teleport up)
    - Once the player is in an area with no roof above it, teleport into the sky (if we move in the sky, we can avoid going into objects and getting flagged by the anti noclip)
    - Check if the target position is closer than the nearest vehicle, if so, move directly to the target position in the sky and then teleport down to it, if not, continue to next step
    - Move towards the position of above the nearest vehicle 
    - Teleport directly downwards to the vehicle and enter it
    - Teleport the vehicle into the sky 
    - Move the vehicle to the target position in the sky 
    - Teleport the vehicle directly downwards to the target position 
    - Exit the vehicle
]]

--// services

--// services
local replicated_storage = game:GetService("ReplicatedStorage")
local pathfinding_service = game:GetService("PathfindingService")
local players = game:GetService("Players")
local run_service = game:GetService("RunService")

--// variables
local player = players.LocalPlayer

local dependencies = {
    variables = {
        up_vector = Vector3.new(0, 500, 0),
        raycast_params = RaycastParams.new(),
        path = pathfinding_service:CreatePath({WaypointSpacing = 3}),
        player_speed = 150, 
        vehicle_speed = 400,
        teleporting = false,
        stopVelocity = false,
        debug_part = Instance.new("Part") -- For visual debugging
    },
    -- ... (rest of your dependencies table remains the same)
}

-- Configure debug part
dependencies.variables.debug_part.Anchored = true
dependencies.variables.debug_part.CanCollide = false
dependencies.variables.debug_part.Transparency = 0.7
dependencies.variables.debug_part.Color = Color3.new(1, 0, 0)
dependencies.variables.debug_part.Size = Vector3.new(2, 2, 2)
dependencies.variables.debug_part.Parent = workspace

--// Improved raycast filter setup
local function updateRaycastFilter(character)
    if not character then return end
    
    local filterList = {workspace.Vehicles}
    if workspace:FindFirstChild("Rain") then
        table.insert(filterList, workspace.Rain)
    end
    
    -- Add all character parts to filter
    local function addParts(object)
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("BasePart") then
                table.insert(filterList, child)
            end
        end
    end
    
    addParts(character)
    dependencies.variables.raycast_params.FilterDescendantsInstances = filterList
end

player.CharacterAdded:Connect(function(character)
    updateRaycastFilter(character)
    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            table.insert(dependencies.variables.raycast_params.FilterDescendantsInstances, descendant)
        end
    end)
end)

-- Initialize filter if character already exists
if player.Character then
    updateRaycastFilter(player.Character)
end

--// Improved obstruction check function
function utilities:isPositionObstructed(position, direction)
    -- Visualize the raycast
    dependencies.variables.debug_part.Position = position
    dependencies.variables.debug_part.Size = Vector3.new(2, direction.Magnitude, 2)
    dependencies.variables.debug_part.CFrame = CFrame.new(position, position + direction) * CFrame.new(0, 0, -direction.Magnitude/2)
    
    local result = workspace:Raycast(position, direction, dependencies.variables.raycast_params)
    
    if result then
        print("[Obstruction] Detected:", result.Instance:GetFullName())
        -- Check if the obstruction is actually part of our character (shouldn't happen with proper filtering)
        if result.Instance:IsDescendantOf(player.Character) then
            print("[Warning] Character part detected as obstruction - filter may not be working properly!")
            return false
        end
        return true
    end
    return false
end

--// Modified pathfind function
function movement:pathfind(tried)
    print("[Pathfinding] Starting pathfind...")
    
    -- First verify there's actually an obstruction
    if not utilities:isPositionObstructed(
        player.Character.HumanoidRootPart.Position, 
        dependencies.variables.up_vector
    ) then
        print("[Pathfinding] No real obstruction found - aborting pathfind")
        return
    end

    -- Rest of your pathfind implementation...
    -- ... (keep your existing pathfind code, but it will now only run when there's a real obstruction)
end

--// function to interpolate characters position to a position
function movement:move_to_position(part, cframe, speed, car, target_vehicle, tried_vehicles)
    local vector_position = cframe.Position
    
    if not car then
        -- Only pathfind if there's a real obstruction
        if utilities:isPositionObstructed(part.Position, dependencies.variables.up_vector) then
            print("[Movement] Real obstruction detected above player")
            movement:pathfind()
            task.wait(0.5)
        else
            print("[Movement] No obstruction - proceeding directly")
        end
    end
    
    local y_level = 500;
    local higher_position = Vector3.new(vector_position.X, y_level, vector_position.Z);

    print("[Movement] Moving to sky position:", higher_position)
    
    repeat
        local velocity_unit = (higher_position - part.Position).Unit * speed;
        part.Velocity = Vector3.new(velocity_unit.X, 0, velocity_unit.Z);

        task.wait();

        part.CFrame = CFrame.new(part.CFrame.X, y_level, part.CFrame.Z);

        if target_vehicle and target_vehicle.Seat.Player.Value then
            table.insert(tried_vehicles, target_vehicle);
            local nearest_vehicle = utilities:get_nearest_vehicle(tried_vehicles);
            local vehicle_object = nearest_vehicle and nearest_vehicle.ValidRoot;

            if vehicle_object then 
                movement:move_to_position(player.Character.HumanoidRootPart, vehicle_object.Seat.CFrame, 135, false, vehicle_object);
            end;
            return;
        end;
    until (part.Position - higher_position).Magnitude < 10;

    part.CFrame = CFrame.new(part.Position.X, vector_position.Y, part.Position.Z);
    part.Velocity = Vector3.zero;
    print("[Movement] Reached target position")
end;

--// raycast filter

dependencies.variables.raycast_params.FilterType = Enum.RaycastFilterType.Exclude;
dependencies.variables.raycast_params.FilterDescendantsInstances = { player.Character, workspace.Vehicles };

-- Add Rain to the filter if it exists
local rain = workspace:FindFirstChild("Rain")
if rain then
    table.insert(dependencies.variables.raycast_params.FilterDescendantsInstances, rain)
end


workspace.ChildAdded:Connect(function(child) -- if it starts raining, add rain to collision ignore list
    if child.Name == "Rain" then 
        table.insert(dependencies.variables.raycast_params.FilterDescendantsInstances, child);
    end;
end);

player.CharacterAdded:Connect(function(character)
    -- Replace the character in the filter list
    for i, instance in ipairs(dependencies.variables.raycast_params.FilterDescendantsInstances) do
        if instance == player.Character then
            dependencies.variables.raycast_params.FilterDescendantsInstances[i] = character
            return
        end
    end
    -- If not found, add it
    table.insert(dependencies.variables.raycast_params.FilterDescendantsInstances, character)
end)


--// get free vehicles, owned helicopters, motorcycles and unsupported/new vehicles

for index, vehicle_data in next, dependencies.modules.vehicle_data do
    if vehicle_data.Type == "Heli" then -- helicopters
        dependencies.helicopters[vehicle_data.Make] = true;
    elseif vehicle_data.Type == "Motorcycle" then --- motorcycles
        dependencies.motorcycles[vehicle_data.Make] = true;
    end;

    if vehicle_data.Type ~= "Chassis" and vehicle_data.Type ~= "Motorcycle" and vehicle_data.Type ~= "Heli" and vehicle_data.Type ~= "DuneBuggy" and vehicle_data.Make ~= "Volt" then -- weird vehicles that are not supported
        dependencies.unsupported_vehicles[vehicle_data.Make] = true;
    end;
    
    if not vehicle_data.Price then -- free vehicles
        dependencies.free_vehicles[vehicle_data.Make] = true;
    end;
end;

--// get all positions near a door which have no collision above them

for index, value in next, workspace:GetDescendants() do
    if value.Name:sub(-4, -1) == "Door" then 
        local touch_part = value:FindFirstChild("Touch");

        if touch_part and touch_part:IsA("BasePart") then
            for distance = 5, 100, 5 do 
                local forward_position, backward_position = touch_part.Position + touch_part.CFrame.LookVector * (distance + 3), touch_part.Position + touch_part.CFrame.LookVector * -(distance + 3); -- distance + 3 studs forward and backward from the door
                
                if not workspace:Raycast(forward_position, dependencies.variables.up_vector, dependencies.variables.raycast_params) then -- if there is nothing above the forward position from the door
                    table.insert(dependencies.door_positions, { instance = value, position = forward_position });

                    break;
                elseif not workspace:Raycast(backward_position, dependencies.variables.up_vector, dependencies.variables.raycast_params) then -- if there is nothing above the backward position from the door
                    table.insert(dependencies.door_positions, { instance = value, position = backward_position });

                    break;
                end;
            end;
        end;
    end;
end;

--// no fall damage or ragdoll 

local old_is_point_in_tag = dependencies.modules.player_utils.isPointInTag;
dependencies.modules.player_utils.isPointInTag = function(point, tag)
    if dependencies.variables.teleporting and tag == "NoRagdoll" or tag == "NoFallDamage" then
        return true;
    end;
    
    return old_is_point_in_tag(point, tag);
end;

--// anti skydive

local oldIsFlying = dependencies.modules.paraglide.IsFlying
dependencies.modules.paraglide.IsFlying = function(...)
    if dependencies.variables.teleporting and getinfo(2, "s").source:find("Falling") then
        return true
    end
    
    return oldIsFlying(...)
end

--// stop velocity

task.spawn(function()
    while task.wait() do
        if dependencies.variables.stopVelocity and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.Velocity = Vector3.zero;
        end;
    end;
end);

--// main teleport function (not returning a new function directly because of recursion)

local function isInVehicle()
    local Players = game:GetService("Players")
    local Player = Players.LocalPlayer
    local Character = Player.Character or Player.CharacterAdded:Wait()
    if Character:FindFirstChild("InVehicle") then
        return true
    else
        return false
    end
end

local function teleport(cframe, tried) -- unoptimized
    local relative_position = (cframe.Position - player.Character.HumanoidRootPart.Position);
    local target_distance = relative_position.Magnitude;

    if target_distance <= 20 and not workspace:Raycast(player.Character.HumanoidRootPart.Position, relative_position.Unit * target_distance, dependencies.variables.raycast_params) then 
        player.Character.HumanoidRootPart.CFrame = cframe; 
        
        return;
    end; 

    local tried = tried or { };
    local nearest_vehicle = utilities:get_nearest_vehicle(tried);
    local vehicle_object = nearest_vehicle and nearest_vehicle.ValidRoot;

    dependencies.variables.teleporting = true;

    if vehicle_object then 
        local vehicle_distance = (vehicle_object.Seat.Position - player.Character.HumanoidRootPart.Position).Magnitude;
        if 1+1 == 3 then
            print("no")
        else 
            if vehicle_object.Seat.PlayerName.Value ~= player.Name then
                movement:move_to_position(player.Character.HumanoidRootPart, vehicle_object.Seat.CFrame, dependencies.variables.player_speed, false, vehicle_object, tried);

                dependencies.variables.stopVelocity = true;

                local enter_attempts = 1;

                repeat -- attempt to enter car
                    nearest_vehicle:Callback(true)
                    
                    enter_attempts = enter_attempts + 1;

                    task.wait(0.1);
                until enter_attempts == 10 or vehicle_object.Seat.PlayerName.Value == player.Name;

                dependencies.variables.stopVelocity = false;

                if vehicle_object.Seat.PlayerName.Value ~= player.Name then -- if it failed to enter, try a new car
                    table.insert(tried, vehicle_object);

                    return teleport(cframe, tried or { vehicle_object });
                end;
            end;

            movement:move_to_position(vehicle_object.Engine, cframe, dependencies.variables.vehicle_speed, true);
        end;
    else
        movement:move_to_position(player.Character.HumanoidRootPart, cframe, dependencies.variables.player_speed);
    end;

    task.wait(0.5);
    dependencies.variables.teleporting = false;
end;

return teleport;
