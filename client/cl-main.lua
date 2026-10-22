local Config <const> = require "config.config"
local Cameras <const> = require "config.cameras"

local OFFLINE_KEY <const> = "hype-camera:offline"
local HEAD_BONE <const> = 31086
local SHAPE_TEST_FLAGS <const> = 1 | 16 -- world + objects

local Keys <const> = {
    up = 32,          -- W
    down = 33,        -- S
    left = 34,        -- A
    right = 35,       -- D
    fast = 21,        -- SHIFT
    zoomIn = 241,     -- Scroll up
    zoomOut = 242,    -- Scroll down
    prev = 44,        -- Q
    next = 38,        -- E
    prevAlt = 174,    -- Left arrow
    nextAlt = 175,    -- Right arrow
    back = 194,       -- BACKSPACE
    exit = 200,       -- ESC
    copy = 26,        -- C (Debug)
}

---@type table<string, table>
local cameraById = {}
for index, camera in ipairs(Cameras) do
    camera.index = index
    cameraById[camera.id] = camera
end

local categoryLabels = {}
for _, category in ipairs(Config.Categories) do categoryLabels[category.id] = category.label end

local menuOpen = false
local viewing = nil ---@type table?
local cam = nil
local switching = false
local signalLost = false
local terminalCoords = nil ---@type vector3?
local radarWasHidden = false
local view = { yaw = 0.0, pitch = 0.0, baseYaw = 0.0, fov = 60.0, targetFov = 60.0 }

-- Face recognition state (kept while the camera list stays open)
local identities, failedAt, pending = {}, {}, {}
local headshots = {}
local lock = nil
local lastTargetKey, lastHudKey = nil, nil
local lastDebugReason, debugHead, debugHit = nil, nil, nil

--#region Helpers

---Sends a notification through the notify module, so the resource configured in
---Config.Notifications is used.
---@param description string Text to display
---@param notifyType string? Notification type, defaults to "inform"
---@return nil
local function notify(description, notifyType)
    Modules.Client.Notify.SendNotify(locale("title"), description, 5000, notifyType or "inform")
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

---Prints why recognition is (not) working, only when the reason changes so the console is not flooded.
---@param reason string Short key of the current state
---@param message string Format string
---@param ... any Format arguments
local function debugRecognition(reason, message, ...)
    if not Config.Debug or reason == lastDebugReason then return end
    lastDebugReason = reason
    Debug(reason:find("^identified") and "success" or "info", "[recognition] " .. message, ...)
end

local function normalizeAngle(angle)
    return (angle + 180.0) % 360.0 - 180.0
end

local function rotationToDirection(pitch, yaw)
    local p, y = math.rad(pitch), math.rad(yaw)
    local c = math.cos(p)
    return vec3(-math.sin(y) * c, math.cos(y) * c, math.sin(p))
end

local function getLimits(camera)
    local limits, defaults = camera.limits or {}, Config.Defaults
    return {
        yaw = limits.yaw or defaults.yawLimit,
        pitchMin = limits.pitchMin or defaults.pitchMin,
        pitchMax = limits.pitchMax or defaults.pitchMax,
        minFov = limits.minFov or defaults.minFov,
        maxFov = limits.maxFov or defaults.maxFov,
    }
end

local function isOnline(id, offline)
    offline = offline or GlobalState[OFFLINE_KEY]
    return not (offline and offline[id])
end

---Seconds left until a shot camera comes back online, nil otherwise
local function offlineRemaining(id, offline)
    offline = offline or GlobalState[OFFLINE_KEY]
    local value = offline and offline[id]
    if type(value) ~= "number" then return nil end
    return math.max(0, value - GetCloudTimeAsInt())
end

local function cameraPayload(camera, offline)
    return {
        id = camera.id,
        code = ("CAM-%02d"):format(camera.index),
        label = camera.label,
        category = camera.category,
        categoryLabel = categoryLabels[camera.category] or camera.category,
        online = isOnline(camera.id, offline),
        remaining = offlineRemaining(camera.id, offline),
        index = camera.index,
        total = #Cameras,
    }
end

local function cameraList(offline)
    local list = {}
    for index, camera in ipairs(Cameras) do list[index] = cameraPayload(camera, offline) end
    return list
end

--#endregion

--#region Mask / face checks

local maskLookup = { all = {}, [`mp_m_freemode_01`] = {}, [`mp_f_freemode_01`] = {} }
for _, drawable in ipairs(Config.Mask.drawables or {}) do maskLookup.all[drawable] = true end
for _, drawable in ipairs(Config.Mask.male or {}) do maskLookup[`mp_m_freemode_01`][drawable] = true end
for _, drawable in ipairs(Config.Mask.female or {}) do maskLookup[`mp_f_freemode_01`][drawable] = true end

local propLookup = {}
for prop, list in pairs(Config.FaceProps or {}) do
    propLookup[prop] = {}
    for _, drawable in ipairs(list) do propLookup[prop][drawable] = true end
end

local function isFaceHidden(ped)
    local mask = Config.Mask
    local drawable = GetPedDrawableVariation(ped, mask.component)

    if drawable > 0 then
        local modelList = maskLookup[GetEntityModel(ped)]
        if mask.anyDrawable or maskLookup.all[drawable] or (modelList and modelList[drawable]) then
            return true, ("component %s drawable %s"):format(mask.component, drawable)
        end
    end

    for prop, list in pairs(propLookup) do
        local index = GetPedPropIndex(ped, prop)
        if index ~= -1 and list[index] then return true, ("prop %s drawable %s"):format(prop, index) end
    end

    return false
end

local function isFacing(ped, camCoords, head)
    local forward = GetEntityForwardVector(ped)
    local dx, dy = camCoords.x - head.x, camCoords.y - head.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.05 then return true, 0.0 end

    local dot = (forward.x * dx + forward.y * dy) / length
    local angle = math.deg(math.acos(clamp(dot, -1.0, 1.0)))
    return angle <= Config.Recognition.facingAngle, angle
end

local function hasLineOfSight(from, to, ignore)
    -- Start slightly ahead of the lens so the camera's own prop or the ceiling does not block the ray
    local dir = to - from
    from = from + dir / #dir * 0.35

    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, SHAPE_TEST_FLAGS, ignore or 0, 4)
    local _, hit, endCoords, _, entity = GetShapeTestResult(handle)
    -- hit is a boolean in FiveM's Lua runtime (false ~= 0), accept the integer form as well
    if hit ~= true and hit ~= 1 then return true end

    ---@type table Debug: what blocked the ray
    local blocker = { coords = endCoords, fromLens = #(endCoords - from) + 0.35, toHead = #(to - endCoords), entity = entity }
    return false, blocker
end

local function effectiveRange()
    local recognition = Config.Recognition
    return math.min(recognition.maxDistance, recognition.range * (recognition.referenceFov / view.fov))
end

--#endregion

--#region Target / identity

local function releaseHeadshots()
    for _, shot in pairs(headshots) do
        if shot.handle and shot.handle ~= 0 then UnregisterPedheadshot(shot.handle) end
    end
    headshots = {}
end

local function clearTarget()
    if lock then releaseHeadshots() end
    lock = nil

    if lastTargetKey ~= nil then
        lastTargetKey = nil
        SendNUIMessage({ action = "nui/target", payload = false })
    end
end

---@return string|false|nil url Nil while loading, false when unavailable
local function getHeadshot(serverId, ped)
    local shot = headshots[serverId]
    if shot then return shot.url end

    shot = { handle = RegisterPedheadshot(ped) }
    headshots[serverId] = shot

    CreateThread(function()
        local timeout = GetGameTimer() + 3000
        while headshots[serverId] == shot and GetGameTimer() < timeout
            and not (IsPedheadshotReady(shot.handle) and IsPedheadshotValid(shot.handle)) do
            Wait(50)
        end
        if headshots[serverId] ~= shot then return end

        if IsPedheadshotReady(shot.handle) and IsPedheadshotValid(shot.handle) then
            local txd = GetPedheadshotTxdString(shot.handle)
            shot.url = ("https://nui-img/%s/%s"):format(txd, txd)
        else
            shot.url = false
        end
    end)

    return nil
end

local function requestIdentity(serverId, now)
    if pending[serverId] or (failedAt[serverId] and now - failedAt[serverId] < 2500) then return end
    pending[serverId] = true

    CreateThread(function()
        local data = lib.callback.await("hype-camera:server:identify", false, serverId)
        pending[serverId] = nil

        if type(data) == "table" then
            identities[serverId] = data
        else
            failedAt[serverId] = GetGameTimer()
            Debug("error", "[recognition] server returned no identity for %s, retrying in 2.5s (see the server console)", serverId)
        end
    end)
end

local function findTarget(camCoords, forward)
    local recognition = Config.Recognition
    local best, bestAngle
    local closest -- Debug: the player nearest to the crosshair, even outside the aim radius

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= cache.playerId or Config.Debug then
            local ped = GetPlayerPed(player)

            if DoesEntityExist(ped) and not IsEntityDead(ped) and IsEntityVisible(ped) then
                local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
                local offset = head - camCoords
                local distance = #offset

                if distance > 0.5 and distance <= recognition.maxDistance then
                    local dir = offset / distance
                    local dot = dir.x * forward.x + dir.y * forward.y + dir.z * forward.z
                    local angle = math.deg(math.acos(clamp(dot, -1.0, 1.0)))
                    local tolerance = math.deg(math.atan(recognition.aimRadius, distance))

                    if angle <= tolerance and (not best or angle < bestAngle) then
                        best = { player = player, ped = ped, head = head, distance = distance }
                        bestAngle = angle
                    end

                    if Config.Debug and (not closest or angle < closest.angle) then
                        closest = { player = player, head = head, distance = distance, angle = angle, tolerance = tolerance }
                    end
                end
            end
        end
    end

    return best, closest
end

local function updateTarget(now)
    debugHead, debugHit = nil, nil
    if signalLost then
        debugRecognition("signal", "signal lost, recognition paused")
        return clearTarget()
    end

    local camCoords = GetCamCoord(cam)
    local target, closest = findTarget(camCoords, rotationToDirection(view.pitch, view.yaw))

    if Config.Debug then
        debugHead = closest and closest.head
        if not closest then
            debugRecognition("none", "no living, visible player within maxDistance (%.0fm)%s", Config.Recognition.maxDistance,
                #GetActivePlayers() <= 1 and " - you are the only player in scope (OneSync culling?)" or "")
        elseif not target then
            debugRecognition("aim:" .. GetPlayerServerId(closest.player), "player %s is %.1f deg off the crosshair, allowed %.1f deg (aimRadius %.2fm at %.1fm)",
                GetPlayerServerId(closest.player), closest.angle, closest.tolerance, Config.Recognition.aimRadius, closest.distance)
        end
    end

    if target then
        local prop = GetCameraProp(viewing.id)
        local visible, blocker = hasLineOfSight(camCoords, target.head, prop)

        if not visible then
            if Config.Debug then
                debugHit = blocker.coords
                local entity = blocker.entity
                local what = "world geometry (map collision)"
                if entity and entity ~= 0 then
                    -- The ray can return map buildings that are not script entities; the entity natives throw on those
                    local ok, model, kind = pcall(function() return GetEntityModel(entity), GetEntityType(entity) end)
                    what = ok and ("entity %s, model %s, type %s"):format(entity, model, kind)
                        or ("map building %s"):format(entity)
                    if entity == prop then what = what .. " (the camera prop itself)" end
                end
                debugRecognition("los:" .. GetPlayerServerId(target.player),
                    "line of sight to player %s is blocked by %s at %s - %.2fm from the camera, %.2fm before the head (camera prop: %s)",
                    GetPlayerServerId(target.player), what, blocker.coords, blocker.fromLens, blocker.toHead, tostring(prop))
            end
            target = nil
        end
    end
    if not target then return clearTarget() end

    local serverId = GetPlayerServerId(target.player)
    if not lock or lock.serverId ~= serverId then
        if lock then releaseHeadshots() end
        lock = { serverId = serverId, since = now }
    end

    local recognition = Config.Recognition
    local status
    local hidden, hiddenBy = isFaceHidden(target.ped)
    local facing, faceAngle = isFacing(target.ped, camCoords, target.head)

    if target.distance > effectiveRange() then
        status = "far"
        lock.since = now
        debugRecognition("far:" .. serverId, "player %s at %.1fm is beyond the range %.1fm at FOV %.1f (zoom in, maxDistance %.0fm)",
            serverId, target.distance, effectiveRange(), view.fov, recognition.maxDistance)
    elseif now - lock.since < recognition.scanTime then
        status = "scanning"
        debugRecognition("scanning:" .. serverId, "scanning player %s (%sms)", serverId, recognition.scanTime)
    elseif hidden then
        status = "masked"
        debugRecognition("masked:" .. serverId, "player %s is masked: %s", serverId, hiddenBy)
    elseif recognition.requireFacing and not facing then
        status = "obscured"
        debugRecognition("obscured:" .. serverId, "player %s faces away: %.0f deg from the camera, allowed %.0f deg", serverId, faceAngle, recognition.facingAngle)
    elseif identities[serverId] then
        status = "identified"
        debugRecognition("identified:" .. serverId, "player %s identified", serverId)
    else
        status = "matching"
        debugRecognition("matching:" .. serverId, "requesting the identity of player %s from the server", serverId)
        requestIdentity(serverId, now)
    end

    local payload = {
        id = serverId,
        status = status,
        distance = round(target.distance, 1),
        scanTime = recognition.scanTime,
        scanKey = lock.since,
    }

    if status == "identified" then
        payload.data = identities[serverId]
        payload.photo = getHeadshot(serverId, target.ped) or nil
    end

    local key = ("%s|%s|%s|%s|%s"):format(serverId, status, payload.distance, lock.since, tostring(payload.photo))
    if key == lastTargetKey then return end

    lastTargetKey = key
    SendNUIMessage({ action = "nui/target", payload = payload })
end

--#endregion

--#region Camera

local function loadArea(coords)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)

    local timeout = GetGameTimer() + Config.LoadTimeout
    if NewLoadSceneStartSphere(coords.x, coords.y, coords.z, 60.0, 0) then
        while not IsNewLoadSceneLoaded() and GetGameTimer() < timeout do Wait(0) end
        NewLoadSceneStop()
    end

    local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        while not IsInteriorReady(interior) and GetGameTimer() < timeout do Wait(0) end
    end
end

local function applyFilter()
    local filter = Config.Filter
    if not filter then return end

    if filter.timecycle then
        SetTimecycleModifier(filter.timecycle)
        SetTimecycleModifierStrength(filter.strength or 1.0)
    end
    if filter.extra then SetExtraTimecycleModifier(filter.extra) end
end

local function setCamera(camera)
    local fov = camera.fov or Config.Defaults.fov
    view.baseYaw = camera.rot.z
    view.yaw, view.pitch = camera.rot.z, camera.rot.x
    view.fov, view.targetFov = fov, fov
    lastHudKey = nil
    HideCameraProp(camera.id)

    local coords = camera.coords
    if not cam then
        cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x, coords.y, coords.z, view.pitch, 0.0, view.yaw, fov, true, 2)
        RenderScriptCams(true, false, 0, true, true)
    else
        SetCamCoord(cam, coords.x, coords.y, coords.z)
        SetCamRot(cam, view.pitch, 0.0, view.yaw, 2)
        SetCamFov(cam, fov)
    end
end

local function updateView()
    local limits = getLimits(viewing)
    local controls = Config.Controls
    local dt = GetFrameTime()

    local speed = controls.rotateSpeed * (view.fov / Config.Defaults.fov) * dt
    if IsDisabledControlPressed(0, Keys.fast) then speed = speed * controls.fastMultiplier end

    if IsDisabledControlPressed(0, Keys.left) then view.yaw = view.yaw + speed end
    if IsDisabledControlPressed(0, Keys.right) then view.yaw = view.yaw - speed end
    if IsDisabledControlPressed(0, Keys.up) then view.pitch = view.pitch + speed end
    if IsDisabledControlPressed(0, Keys.down) then view.pitch = view.pitch - speed end

    if limits.yaw < 180.0 then
        view.yaw = view.baseYaw + clamp(normalizeAngle(view.yaw - view.baseYaw), -limits.yaw, limits.yaw)
    else
        view.yaw = normalizeAngle(view.yaw)
    end
    view.pitch = clamp(view.pitch, limits.pitchMin, limits.pitchMax)

    if IsDisabledControlJustPressed(0, Keys.zoomIn) then
        view.targetFov = math.max(limits.minFov, view.targetFov / controls.zoomFactor)
    elseif IsDisabledControlJustPressed(0, Keys.zoomOut) then
        view.targetFov = math.min(limits.maxFov, view.targetFov * controls.zoomFactor)
    end
    view.fov = view.fov + (view.targetFov - view.fov) * math.min(1.0, dt * controls.zoomSmooth)

    SetCamRot(cam, view.pitch, 0.0, view.yaw, 2)
    SetCamFov(cam, view.fov)
end

local function sendHud()
    local limits = getLimits(viewing)
    local hud = {
        heading = round((360.0 - view.yaw) % 360.0, 1),
        pan = round(-normalizeAngle(view.yaw - view.baseYaw), 1),
        tilt = round(view.pitch, 1),
        fov = round(view.fov, 1),
        zoom = round((viewing.fov or Config.Defaults.fov) / view.fov, 1),
        zoomLevel = round((limits.maxFov - view.fov) / (limits.maxFov - limits.minFov), 3),
    }

    if Config.UI.clock == "game" then
        hud.clock = { GetClockYear(), GetClockMonth() + 1, GetClockDayOfMonth(), GetClockHours(), GetClockMinutes(), GetClockSeconds() }
    end

    local key = json.encode(hud)
    if key == lastHudKey then return end

    lastHudKey = key
    SendNUIMessage({ action = "nui/hud", payload = hud })
end

local function copyCameraPosition()
    local coords = GetCamCoord(cam)
    local text = ("coords = vec3(%.3f, %.3f, %.3f), rot = vec3(%.2f, 0.0, %.2f), fov = %.1f"):format(
        coords.x, coords.y, coords.z, view.pitch, view.yaw, view.fov)

    lib.setClipboard(text)
    print(text)
    notify(locale("notify.copied"), "success")
end

local function exitCamera()
    if not viewing then return end
    viewing = nil
    signalLost = false
    clearTarget()

    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end

    HideCameraProp(nil)
    ClearFocus()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    if not radarWasHidden then DisplayRadar(true) end

    TriggerServerEvent("hype-camera:server:leave")
end

--#endregion

--#region Flow

local startViewLoop

function CloseCameras()
    if not menuOpen and not viewing then return end

    exitCamera()
    menuOpen = false
    terminalCoords = nil
    identities, failedAt = {}, {}

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "nui/hide" })
end

local function backToMenu()
    exitCamera()
    menuOpen = true

    SendNUIMessage({ action = "nui/menu", payload = { cameras = cameraList() } })
    SetNuiFocus(true, true)
end

---@return boolean success, string? error
local function connect(id)
    local camera = cameraById[id]
    if not camera then return false, "invalid" end
    if not isOnline(id) then return false, "offline" end
    if switching then return false, "busy" end

    switching = true
    local ok, err = lib.callback.await("hype-camera:server:view", false, id)
    if not ok or (not menuOpen and not viewing) then
        switching = false
        return false, err or "invalid"
    end

    local first = not viewing
    viewing = camera
    signalLost = false
    clearTarget()

    SendNUIMessage({ action = "nui/connecting", payload = cameraPayload(camera) })
    PlaySoundFrontend(-1, "Change_Cam", "MP_CCTV_SOUNDSET", true)

    if first then
        menuOpen = false
        SetNuiFocus(false, false)
        radarWasHidden = IsRadarHidden()
        DisplayRadar(false)
        applyFilter()
        startViewLoop()
    end

    local started = GetGameTimer()
    loadArea(camera.coords)
    if viewing ~= camera then
        switching = false
        return false, "cancelled"
    end

    setCamera(camera)

    local remaining = Config.SwitchDelay - (GetGameTimer() - started)
    if remaining > 0 then Wait(remaining) end

    switching = false
    if viewing ~= camera then return false, "cancelled" end

    SendNUIMessage({ action = "nui/view", payload = cameraPayload(camera) })
    return true
end

local function cycle(direction)
    local count = #Cameras
    local index = viewing.index

    for _ = 1, count - 1 do
        index = (index - 1 + direction) % count + 1
        if isOnline(Cameras[index].id) then
            CreateThread(function()
                local ok, err = connect(Cameras[index].id)
                if not ok and err ~= "cancelled" and err ~= "busy" then notify(locale("notify." .. err), "error") end
            end)
            return
        end
    end
end

local function shouldAbort()
    if IsEntityDead(cache.ped) or IsPedRagdoll(cache.ped) then return true end
    return terminalCoords ~= nil and #(GetEntityCoords(cache.ped) - terminalCoords) > Config.TerminalDistance
end

function startViewLoop()
    CreateThread(function()
        local nextScan, nextHud = 0, 0

        while viewing do
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()

            if cam and not switching then
                updateView()

                local now = GetGameTimer()
                if now >= nextHud then
                    nextHud = now + 100
                    sendHud()
                end
                if now >= nextScan then
                    nextScan = now + 100
                    updateTarget(now)
                    if shouldAbort() then CloseCameras() end
                end

                -- Debug: marks the head bone of the player nearest to the crosshair
                if debugHead then
                    DrawMarker(28, debugHead.x, debugHead.y, debugHead.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.12, 0.12, 0.12, 255, 60, 60, 160, false, false, 2, false, nil, nil, false)
                end
                -- Debug: marks where the line of sight ray was blocked
                if debugHit then
                    DrawMarker(28, debugHit.x, debugHit.y, debugHit.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.08, 0.08, 0.08, 60, 255, 60, 200, false, false, 2, false, nil, nil, false)
                end
            end

            if not viewing then break end

            if IsDisabledControlJustReleased(0, Keys.exit) then
                CloseCameras()
            elseif IsDisabledControlJustReleased(0, Keys.back) then
                backToMenu()
            elseif not switching then
                if IsDisabledControlJustPressed(0, Keys.next) or IsDisabledControlJustPressed(0, Keys.nextAlt) then
                    cycle(1)
                elseif IsDisabledControlJustPressed(0, Keys.prev) or IsDisabledControlJustPressed(0, Keys.prevAlt) then
                    cycle(-1)
                elseif Config.Debug and cam and IsDisabledControlJustPressed(0, Keys.copy) then
                    copyCameraPosition()
                end
            end

            Wait(0)
        end
    end)
end

---@param fromTerminal vector3? Terminal position when opened from a terminal
function OpenCameras(fromTerminal)
    if menuOpen or viewing or IsPauseMenuActive() or IsNuiFocused() then return end

    if not lib.callback.await("hype-camera:server:access", false) then
        return notify(locale("notify.no_access"), "error")
    end

    terminalCoords = fromTerminal
    identities, failedAt = {}, {}
    menuOpen = true

    SendNUIMessage({
        action = "nui/open",
        payload = {
            locales = lib.getLocales(),
            ui = Config.UI,
            categories = Config.Categories,
            cameras = cameraList(),
        }
    })
    SetNuiFocus(true, true)
end

--#endregion

--#region NUI

RegisterNUICallback("nui/close", function(_, cb)
    cb({ success = true })
    CloseCameras()
end)

RegisterNUICallback("nui/view", function(data, cb)
    if not menuOpen then return cb({ success = false, error = "busy" }) end

    local ok, err = connect(type(data) == "table" and data.id or nil)
    cb({ success = ok, error = err })
end)

--#endregion

--#region State changes

AddStateBagChangeHandler(OFFLINE_KEY, "global", function(_, _, value)
    value = value or {}

    if menuOpen then
        SendNUIMessage({ action = "nui/cameras", payload = { cameras = cameraList(value) } })
    end

    if viewing then
        local lost = value[viewing.id] ~= nil
        if lost ~= signalLost then
            signalLost = lost
            if lost then clearTarget() end
            SendNUIMessage({ action = "nui/signal", payload = { lost = lost, remaining = offlineRemaining(viewing.id, value) } })
        end
    end
end)

--#endregion

--#region Terminals / commands

---Registers a target zone for every configured terminal, through the target module,
---so it works on both ox_target and qb-target.
---@return nil
CreateThread(function()
    Wait(500)

    if not Modules.Client.Target.AddSphereZone then
        return Debug("warning", "no supported target resource found, camera terminals were not created")
    end

    -- Ace holders get the option without a job; the server still checks access on open
    local ace = Config.Access.ace and lib.callback.await("hype-camera:server:ace", false)

    for index, terminal in ipairs(Config.Terminals) do
        local name = ("hype-camera:terminal:%s"):format(index)

        Modules.Client.Target.AddSphereZone(name, terminal.coords, terminal.radius or 0.8, {
            {
                name = name,
                icon = "fa-solid fa-video",
                label = locale("target_label"),
                groups = not ace and Config.Access.groups or nil,
                distance = 2.0,
                onSelect = function() OpenCameras(terminal.coords) end,
            },
        })
        Debug("info", "terminal %s registered: %s at %s", index, terminal.label or "unnamed", terminal.coords)
    end
end)

if Config.Command then
    RegisterCommand(Config.Command, function() OpenCameras() end, false)
end

if Config.Debug then
    -- Copies the gameplay camera position (noclip etc.) as a camera entry
    RegisterCommand("camerapos", function()
        local coords, rot = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
        local text = ("coords = vec3(%.3f, %.3f, %.3f), rot = vec3(%.2f, 0.0, %.2f)"):format(coords.x, coords.y, coords.z, rot.x, rot.z)

        lib.setClipboard(text)
        print(text)
        notify(locale("notify.copied"), "success")
    end, false)
end

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end
    CloseCameras()
end)

exports("Open", function() OpenCameras() end)
exports("Close", function() CloseCameras() end)
exports("IsOpen", function() return menuOpen or viewing ~= nil end)
exports("GetViewingCamera", function() return viewing and viewing.id or nil end)

--#endregion
