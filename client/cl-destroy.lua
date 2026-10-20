local Config <const> = require "config.config"
local Cameras <const> = require "config.cameras"

local Destroy <const> = Config.Destroy

local targets = {}  ---@type table<string, { coords: vector3, entity: number? }>
local hiddenId = nil

---Hides the prop of the watched camera, so the camera does not end up inside it. nil = show all
---@param id string?
function HideCameraProp(id)
    for cameraId, target in pairs(targets) do
        if target.entity and DoesEntityExist(target.entity) then
            SetEntityVisible(target.entity, cameraId ~= id, false)
        end
    end
    hiddenId = id
end

---@param id string
---@return number entity 0 when there is none
function GetCameraProp(id)
    local target = targets[id]
    return target and target.entity or 0
end

if not Destroy or not Destroy.enabled then return end

local OFFLINE_KEY <const> = "hype-camera:offline"
local RESOLVE_DISTANCE <const> = 60.0    -- Map objects are streamed in within this distance
local RELEASE_DISTANCE <const> = 150.0
local SHOOT_COOLDOWN <const> = 1000

-- Security camera models that already exist on the map
local CCTV_MODELS <const> = {
    `prop_cctv_cam_01a`, `prop_cctv_cam_01b`, `prop_cctv_cam_02a`, `prop_cctv_cam_03a`,
    `prop_cctv_cam_04a`, `prop_cctv_cam_04b`, `prop_cctv_cam_04c`, `prop_cctv_cam_05a`,
    `prop_cctv_cam_06a`, `prop_cctv_cam_07a`, `hei_prop_bank_cctv_01`, `hei_prop_bank_cctv_02`,
    `p_cctv_s`, `prop_cs_cctv`,
}

local cameraById = {}
for _, camera in ipairs(Cameras) do cameraById[camera.id] = camera end

local nearby = {}
local lastShot = {}

local function findMapProp(coords)
    for _, model in ipairs(CCTV_MODELS) do
        local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, model, false, false, false)
        if object ~= 0 and GetEntityPopulationType(object) ~= 7 then return object end -- 7 = created by a script
    end
end

local function spawnProp(camera)
    local model = camera.prop or Destroy.prop
    if not pcall(lib.requestModel, model, 5000) then
        return Debug("error", "could not load the camera prop: %s", camera.id)
    end

    local coords = camera.coords
    local rot = camera.propRot or vec3(0.0, 0.0, camera.rot.z)
    local entity = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)

    SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, false)
    FreezeEntityPosition(entity, true)
    SetEntityVisible(entity, hiddenId ~= camera.id, false)
    return entity
end

local function resolveTarget(camera)
    if targets[camera.id] then return end

    local object = findMapProp(camera.coords)
    if object then
        targets[camera.id] = { coords = GetEntityCoords(object) }
    elseif Destroy.spawnProp and camera.prop ~= false then
        local entity = spawnProp(camera)
        if entity then targets[camera.id] = { coords = GetEntityCoords(entity), entity = entity } end
    else
        targets[camera.id] = { coords = camera.coords }
    end
end

local function release(id)
    local target = targets[id]
    if target and target.entity and DoesEntityExist(target.entity) then DeleteEntity(target.entity) end
    targets[id] = nil
end

-- Find nearby cameras, prepare their props, clean them up when far away
CreateThread(function()
    while true do
        local coords = GetEntityCoords(cache.ped)
        local list = {}

        for _, camera in ipairs(Cameras) do
            if camera.destroyable ~= false then
                local distance = #(coords - camera.coords)

                if distance <= RESOLVE_DISTANCE then resolveTarget(camera) end
                if distance > RELEASE_DISTANCE then
                    if targets[camera.id] then release(camera.id) end
                elseif distance <= Destroy.maxDistance and targets[camera.id] then
                    list[#list + 1] = camera
                end
            end
        end

        nearby = list
        Wait(2000)
    end
end)

-- Compare the impact point with nearby cameras
CreateThread(function()
    while true do
        if #nearby == 0 or not cache.weapon then
            Wait(500)
        else
            if IsPedShooting(cache.ped) then
                local hit, impact = GetPedLastWeaponImpactCoord(cache.ped)

                if hit then
                    local offline = GlobalState[OFFLINE_KEY] or {}
                    local now = GetGameTimer()

                    for _, camera in ipairs(nearby) do
                        local target = targets[camera.id]

                        if target and not offline[camera.id] and now - (lastShot[camera.id] or 0) > SHOOT_COOLDOWN
                            and #(impact - target.coords) <= (camera.hitRadius or Destroy.hitRadius) then
                            lastShot[camera.id] = now
                            TriggerServerEvent("hype-camera:server:shoot", camera.id, impact)
                            break
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

RegisterNetEvent("hype-camera:client:destroyed", function(id)
    local target = targets[id]
    if not Destroy.effects or not target or not cameraById[id] then return end

    if not pcall(lib.requestNamedPtfxAsset, "core", 3000) then return end

    local coords = target.coords
    for _ = 1, 3 do
        UseParticleFxAsset("core")
        StartParticleFxNonLoopedAtCoord("ent_sht_electrical_box", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
        Wait(180)
    end
    RemoveNamedPtfxAsset("core")
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end
    for id in pairs(targets) do release(id) end
end)
