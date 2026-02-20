local QBCore = exports['qb-core']:GetCoreObject()

local inventory = exports.ox_inventory

RegisterServerEvent('cameras:server:cancelPlacement', function(data)
    local src = source
    local data = data or {}

    if inventory:CanCarryItem(src, data.one, data.two) then
        inventory:AddItem(src, data.one, data.two)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have enough space in your inventory.', 'error')
    end
end)

RegisterServerEvent('camera:server:CreateNewCamera', function(coords, heading, pitch, name)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cameraId = math.random(0001, 9999)

    Cameras = Cameras or {}
    Cameras = {
        owner = src,
        coords = coords,
        heading = heading,
        pitch = pitch,
        name = name,
    }
    local users = {}
    table.insert(users, Player.PlayerData.citizenid)
    MySQL.query.await("INSERT INTO corry_cameras (id, coords, heading, pitch, name, users) VALUES (?, ?, ?, ?, ?, ?)", { cameraId, json.encode(coords), heading, pitch, name, json.encode(users) })

    TriggerClientEvent('camera:client:spawnCamera', -1, cameraId, coords, heading, pitch)
    
    TriggerClientEvent('camera:client:PlaceCamera', -1, cameraId, coords, pitch)
end)

local function OpenCameraTablet()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local count = inventory:GetItem(src, config.tablet.tabletItemName, nil, true)
    if count > 0 then
        local result = MySQL.query.await("SELECT * FROM corry_cameras WHERE JSON_CONTAINS(users, '\""..Player.PlayerData.citizenid.."\"')", {})
        if result[1] then
            local cameras = {}
            for _, v in pairs(result) do
                table.insert(cameras, {
                    id = v.id,
                    coords = json.decode(v.coords),
                    heading = v.heading or 0.0,
                    pitch = v.pitch,
                    name = v.name,
                    location = '', 
                    active = true, 
                    placed = os.date("%m/%d/%Y")
                })
            end
            TriggerClientEvent('camera:client:openTablet', src, cameras)
        else
            TriggerClientEvent('QBCore:Notify', src, 'You do not have any cameras registered to your tablet.', 'error')
            return
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have a camera tablet to access the tablet.', 'error')
        return
    end
end
RegisterNetEvent('camera:server:OpenCameraTablet', OpenCameraTablet)

QBCore.Functions.CreateCallback('camera:server:getCameras', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local result = MySQL.query.await("SELECT * FROM corry_cameras WHERE JSON_CONTAINS(users, '\""..Player.PlayerData.citizenid.."\"')", {})
    
    if result and #result > 0 then
        local cameras = {}
        for _, v in pairs(result) do
            table.insert(cameras, {
                id = v.id,
                coords = json.decode(v.coords),
                heading = v.heading or 0.0,
                pitch = v.pitch,
                name = v.name,
                location = '', 
                active = true, 
                placed = os.date("%m/%d/%Y") 
            })
        end
        cb(cameras)
    else
        cb({})
    end
end)

QBCore.Functions.CreateCallback('camera:server:getCameraById', function(source, cb, cameraId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local result = MySQL.query.await("SELECT * FROM corry_cameras WHERE id = ? AND JSON_CONTAINS(users, '\""..Player.PlayerData.citizenid.."\"')", { cameraId })
    
    if result and #result > 0 then
        local camera = result[1]
        cb({
            id = camera.id,
            coords = json.decode(camera.coords),
            heading = camera.heading or 0.0,
            pitch = camera.pitch,
            name = camera.name,
            location = '', 
            active = true
        })
    else
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback('camera:server:getAllCameras', function(source, cb)
    local result = MySQL.query.await("SELECT * FROM corry_cameras", {})
    
    if result and #result > 0 then
        local cameras = {}
        for _, v in pairs(result) do
            table.insert(cameras, {
                id = v.id,
                coords = json.decode(v.coords),
                heading = v.heading or 0.0,
                pitch = v.pitch
            })
        end
        cb(cameras)
    else
        cb({})
    end
end)

RegisterServerEvent('camera:server:addCameraAccess', function(cameraId, stateId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local result = MySQL.query.await("SELECT * FROM corry_cameras WHERE id = ? AND JSON_CONTAINS(users, '\""..Player.PlayerData.citizenid.."\"')", { cameraId })
    
    if result and #result > 0 then
        local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(stateId)
        
        if not TargetPlayer then
            local targetSrc = tonumber(stateId)
            if targetSrc then
                TargetPlayer = QBCore.Functions.GetPlayer(targetSrc)
            end
        end
        
        if TargetPlayer then
            local users = json.decode(result[1].users)
            
            local hasAccess = false
            for _, citizenid in pairs(users) do
                if citizenid == TargetPlayer.PlayerData.citizenid then
                    hasAccess = true
                    break
                end
            end
            
            if not hasAccess then
                table.insert(users, TargetPlayer.PlayerData.citizenid)
                MySQL.query.await("UPDATE corry_cameras SET users = ? WHERE id = ?", { json.encode(users), cameraId })
                
                TriggerClientEvent('QBCore:Notify', src, 'Camera access granted to State ID: '..stateId, 'success')
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, 'You have been granted access to a camera', 'success')
            else
                TriggerClientEvent('QBCore:Notify', src, 'This player already has access to this camera', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'Player with State ID '..stateId..' not found', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to share this camera', 'error')
    end
end)

RegisterServerEvent('camera:server:destroyCamera', function(cameraId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local result = MySQL.query.await("SELECT * FROM corry_cameras WHERE id = ?", { cameraId })
    
    if result and #result > 0 then
        MySQL.query.await("DELETE FROM corry_cameras WHERE id = ?", { cameraId })
        
        TriggerClientEvent('camera:client:removePhysicalCamera', -1, cameraId)
        
        TriggerClientEvent('QBCore:Notify', src, 'Camera destroyed', 'success')
        
        if config.debug then
            print('[Camera Server] Camera #' .. cameraId .. ' destroyed by player ' .. src)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Camera not found', 'error')
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
end)