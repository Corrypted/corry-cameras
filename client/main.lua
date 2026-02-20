local QBCore = exports['qb-core']:GetCoreObject()

local target = exports.ox_target
local inventory = exports.ox_inventory

local ObjectList = {} 
local ObjectTypes = {
    "none",
    "container",
}
local ObjectParams = {
    ["none"] = {SpawnRange = 200},
}

local PlacingObject, LoadedObjects = false, false
local CurrentModel, CurrentObject, CurrentObjectType, CurrentObjectName, CurrentSpawnRange, CurrentCoords = nil, nil, nil, nil, nil, nil
local viewingCamera = false
local activeCam = nil
local currentCameraData = nil
local PlacedCameras = {} 

local function CancelPlacement()
    DeleteObject(CurrentObject)
    PlacingObject = false
    CurrentObject = nil
    CurrentObjectType = nil
    CurrentObjectName = nil
    CurrentSpawnRange = nil
    CurrentCoords = nil
    local data = {
        one = config.cameraItem.itemName,
        two = 1,
    }
    TriggerServerEvent('cameras:server:cancelPlacement', data)
end

local function ButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

local function Button(ControlButton)
    N_0xe83a3e3557a56640(ControlButton)
end

local function setupScaleform(scaleform)
    local scaleform = RequestScaleformMovie(scaleform)
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end

    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 0, 0)

    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()
    
    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()


    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    Button(GetControlInstructionalButton(2, 152, true))
    ButtonMessage("Cancel")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    Button(GetControlInstructionalButton(2, 153, true))
    ButtonMessage("Place object")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(2)
    Button(GetControlInstructionalButton(2, 190, true))
    Button(GetControlInstructionalButton(2, 189, true))
    ButtonMessage("Left/Right")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(3)
    Button(GetControlInstructionalButton(2, 188, true))
    Button(GetControlInstructionalButton(2, 187, true))
    ButtonMessage("Up/Down")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end

local function RequestSpawnObject()
    local hash = GetHashKey("prop_ing_camera_01")
    lib.requestModel(hash, 1000)
end

local function RotationToDirection(rotation)
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

local function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
	local direction = RotationToDirection(cameraRotation)
	local destination =
	{
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}
	local a, b, c, d, e = GetShapeTestResult(StartShapeTestSweptSphere(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, 0.2, 339, PlayerPedId(), 4))
	return b, c, e
end

local PLACEMENT_DISTANCE = 2.0

local function GetSurfaceNormal(x, y, z)
    local rayHandle = StartShapeTestRay(x, y, z + 0.1, x, y, z - 0.1, -1, PlayerPedId(), 0)
    local _, hit, hitCoords, surfaceNormal, _ = GetShapeTestResult(rayHandle)
    
    if hit then
        return surfaceNormal
    else
        return vector3(0, 0, 1) 
    end
end

local function PlaceSpawnedObject(heading)
    local ObjectType = 'prop' 
    local Options = { SpawnRange = tonumber(CurrentSpawnRange) }
    if ObjectParams[CurrentObjectType] ~= nil then
        Options = { event = ObjectParams[CurrentObjectType].event, icon = ObjectParams[CurrentObjectType].icon, label = ObjectParams[CurrentObjectType].label, SpawnRange = ObjectParams[CurrentObjectType].SpawnRange}
    end
    
    local objectRotation = GetEntityRotation(CurrentObject, 2)
    local actualPitch = tonumber(string.format("%.2f", objectRotation.x))
    local actualHeading = tonumber(string.format("%.2f", objectRotation.z))
    
    local finalCoords = vector4(CurrentCoords.x, CurrentCoords.y, CurrentCoords.z, actualHeading)
    local input = lib.inputDialog('Camera Name', {
        {
            type = 'input',
            label = 'Enter a name for the camera:',
            icon = 'camera',
            required = true,
            default = 'Camera '..math.random(1000, 9999),
            attributes = {
                maxlength = 30,
            },
        },
    })
    if input then
        local ped = PlayerPedId()
        
        RequestAnimDict(config.animations.place.dict)
        while not HasAnimDictLoaded(config.animations.place.dict) do
            Wait(100)
        end
        
        TaskPlayAnim(ped, config.animations.place.dict, config.animations.place.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
        
        if lib.progressBar({
            duration = config.animations.place.duration,
            label = config.animations.place.label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
            },
        }) then
            local cameraName = input[1]
            TriggerServerEvent('camera:server:CreateNewCamera', finalCoords, actualHeading, actualPitch, cameraName)
            DeleteObject(CurrentObject)
            PlacingObject = false
            CurrentObject = nil
            CurrentObjectType = nil
            CurrentObjectName = nil
            CurrentSpawnRange = nil
            CurrentCoords = nil
            CurrentModel = nil
            ClearPedTasks(ped)
        else
            ClearPedTasks(ped)
            CancelPlacement()
            return
        end
    else
        CancelPlacement()
    end
end

local function CreateSpawnedObject(data)
    local object = "prop_ing_camera_01"
    local objectType = "none"
    CurrentObjectName = "Random Object"
    CurrentSpawnRange = 15
    
    RequestSpawnObject(object)
    CurrentModel = object
    CurrentObject = CreateObject(object, 1.0, 1.0, 1.0, true, true, false)
    local heading = 0.0
    local pitch = 0.0
    SetEntityHeading(CurrentObject, 0)
    
    SetEntityAlpha(CurrentObject, 150)
    SetEntityCollision(CurrentObject, false, false)
    -- SetEntityInvincible(CurrentObject, true)
    FreezeEntityPosition(CurrentObject, true)

    CreateThread(function()
        form = setupScaleform("instructional_buttons")
        while PlacingObject do
            local hit, coords, entity = RayCastGamePlayCamera(20.0)
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local canPlace = false
            
            if hit then
                local surfaceNormal = GetSurfaceNormal(coords.x, coords.y, coords.z)
                local offset = 0.15
                coords = vector3(
                    coords.x + (surfaceNormal.x * offset),
                    coords.y + (surfaceNormal.y * offset),
                    coords.z + (surfaceNormal.z * offset)
                )
                
                local dist = #(playerCoords - coords)
                canPlace = dist <= PLACEMENT_DISTANCE
            end
            
            CurrentCoords = coords

            DrawScaleformMovieFullscreen(form, 255, 255, 255, 255, 0)

            if hit then
                SetEntityCoords(CurrentObject, coords.x, coords.y, coords.z)
                
                if canPlace then
                    SetEntityAlpha(CurrentObject, 150, false)
                else
                    SetEntityAlpha(CurrentObject, 50, false)
                end
            end
            
            if IsControlPressed(0, 174) then
                heading = heading + 1
                if heading > 360 then heading = 0.0 end
            end
    
            if IsControlPressed(0, 175) then
                heading = heading - 1
                if heading < 0 then heading = 360.0 end
            end

            if IsControlPressed(0, 172) then
                pitch = pitch - 1
                if pitch < 0 then pitch = 360.0 end
            end
            if IsControlPressed(0, 173) then
                pitch = pitch + 1
                if pitch > 360 then pitch = 0.0 end
            end
            
            SetEntityRotation(CurrentObject, pitch, 0.0, heading, 2, true)
            
            local objCoords = GetEntityCoords(CurrentObject)
            local objRotation = GetEntityRotation(CurrentObject, 2)
            local radH = math.rad(objRotation.z)
            local radP = math.rad(objRotation.x)
            
            local forwardVector = vector3(
                -math.sin(radH) * math.cos(radP),
                math.cos(radH) * math.cos(radP),
                math.sin(radP)
            )
            
            local lineLength = 2.5
            local endPoint = vector3(
                objCoords.x - forwardVector.x * lineLength,
                objCoords.y - forwardVector.y * lineLength,
                objCoords.z - forwardVector.z * lineLength
            )
            DrawLine(objCoords.x, objCoords.y, objCoords.z, endPoint.x, endPoint.y, endPoint.z, 255, 255, 255, 255)
            
            if IsControlJustPressed(0, 44) then
                CancelPlacement()
            end

            if IsControlJustPressed(0, 38) then
                local currentPlayerCoords = GetEntityCoords(PlayerPedId())
                local objectCoords = GetEntityCoords(CurrentObject)
                local placeDist = #(currentPlayerCoords - objectCoords)
                if placeDist <= PLACEMENT_DISTANCE then
                    PlaceSpawnedObject(heading)
                else
                    QBCore.Functions.Notify('Too far away! Maximum placement distance is ' .. PLACEMENT_DISTANCE .. ' meters', 'error')
                end
            end
            
            Wait(1)
        end
    end)
end
exports("CreateSpawnedObject", CreateSpawnedObject)

local CAMERA_RENDER_DISTANCE = 15.0

local function SpawnCameraObject(id, coords, heading, pitch)
    if PlacedCameras[id] and PlacedCameras[id].object then
        return
    end
    
    local hash = GetHashKey("prop_ing_camera_01")
    lib.requestModel(hash, 1000)
    
    local object = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityRotation(object, pitch, 0.0, heading, 2, true)
    FreezeEntityPosition(object, true)
    SetEntityAsMissionEntity(object, true, true)
    
    exports.ox_target:addLocalEntity(object, {
        {
            name = 'camera_destroy_' .. id,
            icon = 'fas fa-trash',
            label = 'Destroy Camera',
            onSelect = function()
                local ped = PlayerPedId()
                
                RequestAnimDict(config.animations.destroy.dict)
                while not HasAnimDictLoaded(config.animations.destroy.dict) do
                    Wait(100)
                end
                
                TaskPlayAnim(ped, config.animations.destroy.dict, config.animations.destroy.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
                
                if lib.progressBar({
                    duration = config.animations.destroy.duration,
                    label = config.animations.destroy.label,
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        car = true,
                        move = true,
                        combat = true,
                    },
                }) then
                    TriggerServerEvent('camera:server:destroyCamera', id)
                    ClearPedTasks(ped)
                else
                    ClearPedTasks(ped)
                    QBCore.Functions.Notify('Cancelled', 'error')
                end
            end,
            canInteract = function(entity, distance, coords, name)
                return distance < 2.0
            end
        }
    })
    
    PlacedCameras[id] = {
        id = id,
        coords = coords,
        heading = heading,
        pitch = pitch,
        object = object,
        isRendered = true
    }
    
    if config.debug then
        print('[Camera] Spawned camera object #' .. id)
    end
end

local function DespawnCameraObject(id)
    if PlacedCameras[id] and PlacedCameras[id].object then
        local obj = PlacedCameras[id].object
        if DoesEntityExist(obj) then
            exports.ox_target:removeLocalEntity(obj)
            
            SetEntityAsMissionEntity(obj, false, true)
            DeleteEntity(obj)
        end
        PlacedCameras[id].object = nil
        PlacedCameras[id].isRendered = false
        
        if config.debug then
            print('[Camera] Despawned camera object #' .. id)
        end
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        
        for id, camera in pairs(PlacedCameras) do
            local camCoords = vector3(camera.coords.x, camera.coords.y, camera.coords.z)
            local dist = #(playerCoords - camCoords)
            
            if dist < CAMERA_RENDER_DISTANCE then
                if not camera.isRendered then
                    SpawnCameraObject(id, camera.coords, camera.heading, camera.pitch)
                end
            else
                if camera.isRendered and camera.object then
                    DespawnCameraObject(id)
                end
            end
        end
        
        Wait(1500)
    end
end)

RegisterNetEvent('camera:client:spawnCamera', function(id, coords, heading, pitch)
    if config.debug then
        print('[Camera] Received camera placement #' .. id)
    end
    
    PlacedCameras[id] = {
        id = id,
        coords = coords,
        heading = heading,
        pitch = pitch,
        object = nil,
        isRendered = false
    }
    
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local camCoords = vector3(coords.x, coords.y, coords.z)
    local dist = #(playerCoords - camCoords)
    
    if dist < CAMERA_RENDER_DISTANCE then
        SpawnCameraObject(id, coords, heading, pitch)
    end
end)

RegisterNetEvent('camera:client:removePhysicalCamera', function(id)
    DespawnCameraObject(id)
    PlacedCameras[id] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    QBCore.Functions.TriggerCallback('camera:server:getAllCameras', function(cameras)
        for _, camera in ipairs(cameras) do
            PlacedCameras[camera.id] = {
                id = camera.id,
                coords = camera.coords,
                heading = camera.heading,
                pitch = camera.pitch,
                object = nil,
                isRendered = false
            }
        end
        
        if config.debug then
            print('[Camera] Loaded ' .. #cameras .. ' cameras from database')
        end
    end)
end)

local function GetStreetNameFromCoords(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    
    if crossingHash ~= 0 then
        local crossingName = GetStreetNameFromHashKey(crossingHash)
        return streetName .. ' / ' .. crossingName
    else
        return streetName
    end
end

RegisterNetEvent('camera:client:useCamera', function()
    if config.debug then
        print('Camera used')
    end
    PlacingObject = true
    CreateSpawnedObject(data)
end)

RegisterNetEvent('camera:client:openTablet', function(cameras)
    if config.debug then
        print('Opening camera tablet with ' .. #cameras .. ' cameras.')
    end
    
    for i, camera in ipairs(cameras) do
        if camera.coords then
            camera.location = GetStreetNameFromCoords(camera.coords)
        end
    end
    
    OpenCameraListUI(cameras)
end)



RegisterNetEvent('camera:notify', function(text, icon) end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setTargets()
    
    QBCore.Functions.TriggerCallback('camera:server:getAllCameras', function(cameras)
        if cameras then
            for _, camera in ipairs(cameras) do
                PlacedCameras[camera.id] = {
                    id = camera.id,
                    coords = camera.coords,
                    heading = camera.heading or 0.0,
                    pitch = camera.pitch or 0.0,
                    object = nil,
                    isRendered = false
                }
            end
            
            if config.debug then
                print('[Camera] Loaded ' .. #cameras .. ' cameras on player spawn')
            end
        end
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerUnloaded', function()

end)

-- ======================================
-- Camera Viewing Functions
-- ======================================

local function ExitCameraView()
    if not viewingCamera then return end
    
    viewingCamera = false
    
    local ped = PlayerPedId()
    
    FreezeEntityPosition(ped, false)
    
    if activeCam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(activeCam, false)
        activeCam = nil
    end
    
    currentCameraData = nil
    ClearTimecycleModifier()
    
    ClearFocus()
    
    QBCore.Functions.TriggerCallback('camera:server:getCameras', function(cameras)
        for i, camera in ipairs(cameras) do
            if camera.coords then
                camera.location = GetStreetNameFromCoords(camera.coords)
            end
        end
        
        SendNUIMessage({
            action = 'openCameraList',
            cameras = cameras
        })
        
        Wait(100)
        SendNUIMessage({ action = 'showContainer' })
        SetNuiFocus(true, true)
    end)
    
    if config.debug then
        print('[Camera View] Exited camera view, returning to camera list')
    end
end

local function StartCameraView(cameraData)
    if viewingCamera then
        ExitCameraView()
    end
    
    if not cameraData or not cameraData.coords then
        if config.debug then
            print('[Camera View] Invalid camera data')
        end
        return
    end
    
    viewingCamera = true
    currentCameraData = cameraData
    
    local ped = PlayerPedId()
    
    FreezeEntityPosition(ped, true)
    
    local coords = cameraData.coords
    local pitch = tonumber(cameraData.pitch) or 0.0
    local heading = tonumber(cameraData.heading) or 0.0
    
    if config.debug then
        print('[Camera View] Using rotation - Pitch: ' .. pitch .. ', Heading: ' .. heading)
        print('[Camera View] Camera coords: ' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
    end
    
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    activeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(activeCam, coords.x, coords.y, coords.z)
    SetCamFov(activeCam, 80.0)
    
    local distance = 10.0
    local radH = math.rad(heading)
    local radP = math.rad(pitch)
    
    local targetX = coords.x + (math.sin(radH) * math.abs(math.cos(radP)) * distance)
    local targetY = coords.y - (math.cos(radH) * math.abs(math.cos(radP)) * distance)
    local targetZ = coords.z - (math.sin(radP) * distance)
    
    if config.debug then
        print('[Camera View] Target point: ' .. targetX .. ', ' .. targetY .. ', ' .. targetZ)
    end
    
    PointCamAtCoord(activeCam, targetX, targetY, targetZ)
    
    SetCamActive(activeCam, true)
    RenderScriptCams(true, false, 0, true, false)
    
    Wait(100)
    local currentRot = GetCamRot(activeCam, 2)
    if config.debug then
        print('[Camera View] Camera rotation after point: Pitch=' .. currentRot.x .. ', Roll=' .. currentRot.y .. ', Heading=' .. currentRot.z)
    end
    
    SetTimecycleModifier("scanline_cam_cheap")
    SetTimecycleModifierStrength(2.0)
    
    if config.debug then
        print('[Camera View] Started viewing camera #' .. cameraData.id)
    end
    
    CreateThread(function()
        while viewingCamera do
            SetTextFont(4)
            SetTextScale(0.5, 0.5)
            SetTextColour(0, 255, 0, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("◉ REC")
            DrawText(0.02, 0.02)
            
            SetTextFont(4)
            SetTextScale(0.4, 0.4)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("CAMERA #" .. currentCameraData.id)
            DrawText(0.02, 0.06)
            
            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 200)
            SetTextEntry("STRING")
            AddTextComponentString(currentCameraData.name or "Unknown")
            DrawText(0.02, 0.10)
            
            SetTextFont(4)
            SetTextScale(0.3, 0.3)
            SetTextColour(200, 200, 200, 200)
            SetTextEntry("STRING")
            AddTextComponentString(currentCameraData.location or "Unknown Location")
            DrawText(0.02, 0.14)
            
            SetTextFont(4)
            SetTextScale(0.3, 0.3)
            SetTextColour(255, 255, 255, 200)
            SetTextEntry("STRING")
            AddTextComponentString("Arrow Keys: Rotate Camera | ESC/Backspace: Exit")
            DrawText(0.02, 0.93)
            
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then
                ExitCameraView()
                break
            end
            
            local camRot = GetCamRot(activeCam, 2)
            local rotChanged = false
            
            if IsControlPressed(0, 174) then 
                camRot = vector3(camRot.x, camRot.y, camRot.z + 0.5)
                rotChanged = true
            end
            
            if IsControlPressed(0, 175) then 
                camRot = vector3(camRot.x, camRot.y, camRot.z - 0.5)
                rotChanged = true
            end
            
            if IsControlPressed(0, 172) then 
                camRot = vector3(camRot.x - 0.5, camRot.y, camRot.z)
                rotChanged = true
            end
            
            if IsControlPressed(0, 173) then 
                camRot = vector3(camRot.x + 0.5, camRot.y, camRot.z)
                rotChanged = true
            end
            
            if rotChanged then
                if camRot.x < -90.0 then camRot = vector3(-90.0, camRot.y, camRot.z) end
                if camRot.x > 90.0 then camRot = vector3(90.0, camRot.y, camRot.z) end
                SetCamRot(activeCam, camRot.x, camRot.y, camRot.z, 2)
            end
            
            Wait(0)
        end
    end)
end

RegisterNetEvent('camera:client:viewCamera', function(cameraId)
    if config.debug then
        print('[Camera View] Requesting to view camera #' .. tostring(cameraId))
    end
    
    QBCore.Functions.TriggerCallback('camera:server:getCameraById', function(cameraData)
        if cameraData then
            StartCameraView(cameraData)
        else
            QBCore.Functions.Notify('Camera not found or access denied', 'error')
        end
    end, cameraId)
end)

-- ======================================
-- Camera List NUI Functions
-- ======================================

local isCameraUIOpen = false
local tabletProp = nil
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"
local tabletModel = "prop_cs_tablet"

function OpenCameraListUI(cameras)
    if isCameraUIOpen then
        if config.debug then
            print('[Camera UI] UI already open')
        end
        return
    end

    isCameraUIOpen = true
    
    local ped = PlayerPedId()
    
    RequestAnimDict(tabletDict)
    while not HasAnimDictLoaded(tabletDict) do
        Wait(100)
    end
    
    RequestModel(tabletModel)
    while not HasModelLoaded(tabletModel) do
        Wait(100)
    end
    
    local coords = GetEntityCoords(ped)
    tabletProp = CreateObject(GetHashKey(tabletModel), coords.x, coords.y, coords.z, true, true, true)
    
    AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
    
    TaskPlayAnim(ped, tabletDict, tabletAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openCameraList',
        cameras = cameras
    })
    
    if config.debug then
        print('[Camera UI] Opened camera list with ' .. #cameras .. ' cameras')
    end
end

function CloseCameraListUI()
    if not isCameraUIOpen then return end
    
    isCameraUIOpen = false
    
    local ped = PlayerPedId()
    
    if DoesEntityExist(tabletProp) then
        DeleteObject(tabletProp)
        tabletProp = nil
    end
    
    ClearPedTasks(ped)
    
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeCameraList'
    })
    
    if config.debug then
        print('[Camera UI] Closed camera list')
    end
end

function UpdateCameraListUI(cameras)
    if not isCameraUIOpen then return end
    
    SendNUIMessage({
        action = 'updateCameraList',
        cameras = cameras
    })
    
    if config.debug then
        print('[Camera UI] Updated camera list with ' .. #cameras .. ' cameras')
    end
end

RegisterNUICallback('closeCameraUI', function(data, cb)
    if config.debug then
        print('[Camera UI] NUI Callback: closeCameraUI')
    end
    CloseCameraListUI()
    cb('ok')
end)

RegisterNUICallback('viewCamera', function(data, cb)
    if config.debug then
        print('[Camera UI] NUI Callback: viewCamera - Camera ID: ' .. tostring(data.cameraId))
    end
    
    SetNuiFocus(false, false)
    
    TriggerEvent('camera:client:viewCamera', data.cameraId)
    
    cb('ok')
end)

RegisterNUICallback('addCameraAccess', function(data, cb)
    if config.debug then
        print('[Camera UI] NUI Callback: addCameraAccess - Camera ID: ' .. tostring(data.cameraId) .. ', State ID: ' .. tostring(data.stateId))
    end
    
    TriggerServerEvent('camera:server:addCameraAccess', data.cameraId, data.stateId)
    
    cb('ok')
end)

exports('OpenCameraListUI', OpenCameraListUI)
exports('CloseCameraListUI', CloseCameraListUI)
exports('UpdateCameraListUI', UpdateCameraListUI)