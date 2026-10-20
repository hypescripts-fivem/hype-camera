local Config <const> = require "config.config"
local Cameras <const> = require "config.cameras"

local scriptName <const> = GetCurrentResourceName()

local OFFLINE_KEY <const> = "hype-camera:offline"
local IDENTIFY_COOLDOWN <const> = 400
local SHOOT_COOLDOWN <const> = 500

---@type table<string, table>
local cameras = {}
for _, camera in ipairs(Cameras) do cameras[camera.id] = camera end

---@type table<number, string> Viewer source to camera id
local viewers = {}
local lastIdentify = {}
local lastShot = {}

---@type table<string, true|number> true = switched off by hand, number = shot (os.time when it comes back)
local offline = {}
for _, camera in ipairs(Cameras) do
    if camera.online == false then offline[camera.id] = true end
end
GlobalState[OFFLINE_KEY] = offline

Debug("info", "camera server loaded: %s cameras, requireDuty=%s, ace=%s, destroy=%s",
    #Cameras, Config.Access.requireDuty, Config.Access.ace or "off", Config.Destroy and Config.Destroy.enabled)

Debug("info", "framework bridge: %s", Framework.Name or "none")

---Logs a suspicious request to the server console with the player's name and id.
---@param source number Player server id
---@param message string Format string
---@param ... any Format arguments
---@return nil
local function suspicious(source, message, ...)
    local ok, text = pcall(string.format, message, ...)
    print(("^3[%s] Suspicious request from ^7%s (%s): %s^0"):format(scriptName, GetPlayerName(source) or "?", source, ok and text or message))
end

---Checks a player against Config.Access: the ace bypass first, then job, grade and duty.
---@param source number Player server id
---@return boolean allowed
local function hasAccess(source)
    local access = Config.Access
    if access.ace and IsPlayerAceAllowed(source, access.ace) then
        Debug("success", "%s may watch through the ace %s", source, access.ace)
        return true
    end

    if not Framework.Server.GetPlayerJob then
        Debug("error", "access check failed: no framework bridge is active")
        return false
    end

    local job = Framework.Server.GetPlayerJob(source)
    if not job then
        Debug("error", "access check failed for %s: no player or job data", source)
        return false
    end

    local required = access.groups[job.name]
    if required == nil then
        Debug("error", "access check for %s: job %s is not in the allowed list", source, job.name)
        return false
    end

    local grade = job.grade and job.grade.level or 0
    if grade < required then
        Debug("error", "access check for %s: grade %s of job %s is below the required %s", source, grade, job.name, required)
        return false
    end

    if access.requireDuty and job.onDuty ~= true then
        Debug("error", "access check for %s: job %s is not on duty", source, job.name)
        return false
    end

    return true
end

---Field getters for the recognition panel, keyed by the names used in Config.Recognition.fields.
---@type table<string, fun(info: table): any>
local identityFields <const> = {
    name = function(info)
        return ("%s %s"):format(info.firstname or "", info.lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end,
    birthdate = function(info) return info.birthdate end,
    gender = function(info) return info.gender end,
    nationality = function(info) return info.nationality end,
    citizenid = function(info) return info.identifier end,
    job = function(info) return info.job end,
    phone = function(info) return info.phone end,
}

---Tells a client whether it may open the camera list.
---@param source number Player server id
---@return boolean allowed
lib.callback.register("hype-camera:server:access", function(source)
    local allowed = hasAccess(source)
    Debug(allowed and "success" or "error", "camera access check for %s: %s", source, allowed)
    return allowed
end)

---Tells a client whether it holds the ace that bypasses the group check, so the
---terminal option can be shown to it without a job.
---@param source number Player server id
---@return boolean allowed
lib.callback.register("hype-camera:server:ace", function(source)
    return Config.Access.ace and IsPlayerAceAllowed(source, Config.Access.ace) or false
end)

---Grants a viewer access to a camera.
---@param source number Player server id
---@param id string Camera id
---@return boolean success
---@return string? error
lib.callback.register("hype-camera:server:view", function(source, id)
    if type(id) ~= "string" or not cameras[id] then
        suspicious(source, "invalid camera: %s", tostring(id))
        return false, "invalid"
    end
    if not hasAccess(source) then
        suspicious(source, "unauthorized camera access: %s", id)
        return false, "no_access"
    end
    if offline[id] then return false, "offline" end

    viewers[source] = id
    Debug("info", "%s is watching camera %s", source, id)
    return true
end)

RegisterNetEvent("hype-camera:server:leave", function()
    viewers[source] = nil
end)

---Returns the identity of a player seen through the camera the requester is watching.
---@param source number Player server id
---@param target number Server id of the recognised player
---@return table? identity Only the fields listed in Config.Recognition.fields
lib.callback.register("hype-camera:server:identify", function(source, target)
    local camera = cameras[viewers[source]]
    if not camera then
        suspicious(source, "identity request without watching a camera")
        return nil
    end

    local now = GetGameTimer()
    if lastIdentify[source] and now - lastIdentify[source] < IDENTIFY_COOLDOWN then return nil end
    lastIdentify[source] = now

    target = tonumber(target)
    local info = target and Framework.Server.GetCharacterInfo and Framework.Server.GetCharacterInfo(target)
    if not info then return nil end

    local ped = GetPlayerPed(target)
    if ped == 0 or #(GetEntityCoords(ped) - camera.coords) > Config.Recognition.maxDistance + 10.0 then
        suspicious(source, "identity request out of camera range (target: %s, camera: %s)", target, camera.id)
        return nil
    end

    local identity = {}
    for _, field in ipairs(Config.Recognition.fields) do
        local getter = identityFields[field]
        if getter then identity[field] = getter(info) end
    end

    Debug("info", "%s identified %s (%s)", source, target, camera.id)
    return identity
end)

AddEventHandler("playerDropped", function()
    viewers[source] = nil
    lastIdentify[source] = nil
    lastShot[source] = nil
end)

---Switches a camera online or offline (e.g. cut the cameras during a robbery).
---@param id string Camera id
---@param online boolean
---@return boolean success
local function setCameraOnline(id, online)
    if not cameras[id] then return false end

    offline[id] = (not online) or nil
    GlobalState[OFFLINE_KEY] = offline
    Debug("info", "camera %s set %s", id, online and "online" or "offline")
    return true
end

---Takes a camera offline as damaged for a while.
---@param id string Camera id
---@param duration number? Seconds, defaults to Config.Destroy.duration
---@param source number? Player who shot it
---@return boolean success
local function destroyCamera(id, duration, source)
    local camera = cameras[id]
    if not camera or offline[id] then return false end

    duration = duration or Config.Destroy.duration
    offline[id] = os.time() + duration
    GlobalState[OFFLINE_KEY] = offline

    TriggerClientEvent("hype-camera:client:destroyed", -1, id)
    -- For dispatch / log resources: AddEventHandler("hype-camera:server:cameraDestroyed", function(id, source, coords, label) end)
    TriggerEvent("hype-camera:server:cameraDestroyed", id, source, camera.coords, camera.label)

    Debug("info", "camera %s was shot (%s), offline for %ss", id, tostring(source), duration)
    return true
end

RegisterNetEvent("hype-camera:server:shoot", function(id, impact)
    local src = source
    local destroy = Config.Destroy
    if not destroy or not destroy.enabled then return end

    local camera = type(id) == "string" and cameras[id]
    if not camera or camera.destroyable == false then
        return suspicious(src, "invalid camera shot: %s", tostring(id))
    end
    if offline[id] then return end

    local now = GetGameTimer()
    if lastShot[src] and now - lastShot[src] < SHOOT_COOLDOWN then return end
    lastShot[src] = now

    local ped = GetPlayerPed(src)
    if ped == 0 or GetSelectedPedWeapon(ped) == `WEAPON_UNARMED` then
        return suspicious(src, "camera shot without a weapon: %s", id)
    end
    if #(GetEntityCoords(ped) - camera.coords) > destroy.maxDistance + 5.0 then
        return suspicious(src, "camera shot from out of range: %s", id)
    end
    if type(impact) ~= "vector3" or #(impact - camera.coords) > (camera.hitRadius or destroy.hitRadius) + 2.5 then
        return suspicious(src, "invalid impact point: %s", id)
    end

    destroyCamera(id, nil, src)
end)

-- Bring shot cameras back online once their time is up
CreateThread(function()
    while true do
        Wait(5000)

        local now, changed = os.time(), false
        for id, value in pairs(offline) do
            if type(value) == "number" and value <= now then
                offline[id] = nil
                changed = true
                Debug("info", "camera %s is back online", id)
            end
        end
        if changed then GlobalState[OFFLINE_KEY] = offline end
    end
end)

exports("SetCameraOnline", setCameraOnline)
exports("DestroyCamera", destroyCamera)
exports("IsCameraOnline", function(id) return cameras[id] ~= nil and not offline[id] end)
exports("GetViewers", function(id)
    local list = {}
    for source, cameraId in pairs(viewers) do
        if not id or cameraId == id then list[#list + 1] = source end
    end
    return list
end)

if Config.AdminCommand then
    lib.addCommand(Config.AdminCommand, {
        help = "Switch a security camera online or offline",
        params = {
            { name = "id", type = "string", help = "Camera id (config/cameras.lua)" },
            { name = "state", type = "number", help = "1 = online, 0 = offline" },
        },
        restricted = "group.admin",
    }, function(source, args)
        local ok = setCameraOnline(args.id, args.state == 1)
        Modules.Server.Notify.SendNotify(source, locale("title"),
            ok and locale("notify.status_set", args.id, args.state == 1 and "ON" or "OFF") or locale("notify.invalid"),
            5000, ok and "success" or "error")
    end)
end
