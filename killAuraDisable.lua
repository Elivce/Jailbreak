getgenv().toggled = false -- Change this to false to stop kill aura.

if getgenv().killauraloaded then return end

local old = require(game:GetService("ReplicatedStorage").Module.RayCast).RayIgnoreNonCollideWithIgnoreList

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

local function getNearestEnemy()
    local nearestDistance, nearestEnemy = 1000, nil
    local myTeam = tostring(game:GetService("Players").LocalPlayer.Team)

    for _, v in pairs(game:GetService("Players"):GetPlayers()) do
        local theirTeam = tostring(v.Team)
        
        if ((myTeam == "Police" and theirTeam == "Criminal") or theirTeam == "Police") and 
           theirTeam ~= myTeam and 
           v.Character and 
           v.Character:FindFirstChild("HumanoidRootPart") then
           
            local distance = (v.Character.HumanoidRootPart.Position - 
                              game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                              
            if distance < nearestDistance then
                nearestDistance, nearestEnemy = distance, v
            end
        end
    end
    
    return nearestEnemy
end

local function shoot()
    local currentGun = require(game:GetService("ReplicatedStorage").Game:WaitForChild("ItemSystem"):WaitForChild("ItemSystem")).GetLocalEquipped()
    
    if not currentGun then return end
    
    require(game:GetService("ReplicatedStorage").Game:WaitForChild("Item"):WaitForChild("Gun"))._attemptShoot(currentGun)
end

getgenv().killauraloaded = true

local function getPistol()
    local serverHash = getServerHash()
    local pistolHash = getEventValue("l5cuht8e")
    local args = {
        [1] = pistolHash,
        [2] = "Pistol",
    }
    game:GetService("ReplicatedStorage"):FindFirstChild(serverHash):FireServer(unpack(args))
end

while wait(0.5) do
    if getgenv().toggled == false then continue end
    if not game:GetService("Players").LocalPlayer.Character then continue end
    if not game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then continue end
    
    local nearestEnemy = getNearestEnemy()
    
    if nearestEnemy then
        require(game:GetService("ReplicatedStorage").Module.RayCast).RayIgnoreNonCollideWithIgnoreList = function(...)
            local arg = {old(...)}
            
            if (tostring(getfenv(2).script) == "BulletEmitter" or tostring(getfenv(2).script) == "Taser") and 
                nearestEnemy and 
                nearestEnemy.Character and 
                nearestEnemy.Character:FindFirstChild("HumanoidRootPart") and 
                nearestEnemy.Character:FindFirstChild("Humanoid") and 
                (nearestEnemy.Character.HumanoidRootPart.Position - 
                 game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 600 and 
                nearestEnemy.Character.Humanoid.Health > 0 then
                
                arg[1] = nearestEnemy.Character.HumanoidRootPart
                arg[2] = nearestEnemy.Character.HumanoidRootPart.Position
            end
            
            return unpack(arg)
        end
        
        if not game:GetService("Players").LocalPlayer.Folder:FindFirstChild("Pistol") then
            getPistol()
        end
        
        if game:GetService("Players").LocalPlayer.Folder:FindFirstChild("Pistol") then
            while game:GetService("Players").LocalPlayer.Folder:FindFirstChild("Pistol") and 
                  nearestEnemy and 
                  nearestEnemy.Character and 
                  nearestEnemy.Character:FindFirstChild("HumanoidRootPart") and 
                  nearestEnemy.Character:FindFirstChild("Humanoid") and 
                  (nearestEnemy.Character.HumanoidRootPart.Position - 
                   game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 600 and 
                  nearestEnemy.Character.Humanoid.Health > 0 do
                  
                game:GetService("Players").LocalPlayer.Folder.Pistol.InventoryEquipRemote:FireServer(true)
                wait()
                shoot()
            end
        end
        
        if game:GetService("Players").LocalPlayer.Folder:FindFirstChild("Pistol") then
            game:GetService("Players").LocalPlayer.Folder.Pistol.InventoryEquipRemote:FireServer(false)
        end
    else
        require(game:GetService("ReplicatedStorage").Module.RayCast).RayIgnoreNonCollideWithIgnoreList = old
    end
end
