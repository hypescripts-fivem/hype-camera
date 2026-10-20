return {
    -- Dev only: lets you recognise yourself, draws the target zones, copies the camera
    -- position/angle to your clipboard with [C] while viewing and enables /camerapos.
    -- Keep false on a live server.
    Debug = false,

    -- Notification resource: "auto" picks okokNotify, ps-ui or ox_lib, whichever is running.
    -- Set it to one of those names to force it.
    Notifications = "auto",

    -- Who may watch the cameras
    Access = {
        groups = { police = 0, sheriff = 0 },  -- job name -> minimum grade level
        requireDuty = true,                    -- Player must be on duty (ESX has no duty, so it is ignored there)
        ace = "group.admin",                   -- Holders of this ace bypass the group check (false = disabled)
    },

    Command = false,             -- Command that opens the camera list (e.g. "cameras"); false = terminals only
    AdminCommand = "camerastatus", -- Admin command that switches a camera on/off (group.admin); false = disabled

    -- Viewing terminals (ox_target / qb-target). Walking away from the terminal closes the viewer.
    -- Defaults match the hype-bodycam computers, so a single PC offers both options.
    Terminals = {
        { coords = vec3(441.85, -978.92, 30.69), radius = 0.8, label = "Mission Row PD" },
        { coords = vec3(1853.18, 3689.62, 34.27), radius = 0.8, label = "Sandy Shores Sheriff" },
        { coords = vec3(-448.29, 6011.95, 31.72), radius = 0.8, label = "Paleto Bay Sheriff" },
    },
    TerminalDistance = 3.0,      -- m, viewer closes past this distance from the terminal

    Controls = {
        rotateSpeed = 32.0,      -- degrees per second (slows down automatically when zoomed in)
        fastMultiplier = 2.5,    -- while [SHIFT] is held
        zoomFactor = 1.18,       -- FOV changes by this ratio on every scroll step
        zoomSmooth = 10.0,       -- Zoom smoothing (higher = faster)
    },

    -- Can be overridden per camera with "fov" and "limits"
    Defaults = {
        fov = 60.0,
        minFov = 7.0,            -- Maximum zoom in
        maxFov = 70.0,           -- Maximum zoom out
        yawLimit = 80.0,         -- Maximum turn left/right from the starting angle (180 = unlimited)
        pitchMin = -80.0,        -- Maximum look down
        pitchMax = 10.0,         -- Maximum look up
    },

    -- Picture effect (timecycle modifier). false = disabled
    Filter = {
        timecycle = "CAMERA_secuirity",
        extra = "CAMERA_secuirity_FUZZ",
        strength = 1.0,
    },

    -- Shooting a camera takes it offline for a while. Disable per camera with destroyable = false
    Destroy = {
        enabled = true,
        duration = 20 * 60,      -- seconds the camera stays offline
        hitRadius = 0.6,         -- m, the bullet must land at most this close to the camera
        maxDistance = 80.0,      -- m, the shooter can be at most this far from the camera (server check)
        -- When the map has no CCTV object at the camera position, this prop is placed so it can be shot
        -- (per camera: prop = false disables it, prop = `model` replaces it, propRot = vec3() rotates it)
        spawnProp = true,
        prop = `prop_cctv_cam_01a`,
        effects = true,          -- Spark effect when hit
    },

    LoadTimeout = 3000,          -- ms to wait at most for the area to load when switching to a distant camera
    SwitchDelay = 450,           -- ms of static shown on every camera switch

    -- Face recognition
    Recognition = {
        range = 9.0,             -- m at which a face can be recognised at referenceFov; grows as you zoom in
        referenceFov = 50.0,
        maxDistance = 60.0,      -- m, hard limit however far you zoom in
        aimRadius = 0.55,        -- m, the crosshair must be at most this far from the person's head
        scanTime = 1800,         -- ms the person must stay in focus to be recognised
        requireFacing = true,    -- A person facing away from the camera cannot be recognised
        facingAngle = 100.0,     -- Maximum angle of the face relative to the camera (degrees)
        -- Fields shown once recognised (the order is the order in the UI)
        -- Available: name, birthdate, gender, nationality, citizenid, job, phone
        fields = { "name", "birthdate", "gender", "nationality", "citizenid", "job" },
    },

    -- Mask: a player wearing one of these drawables in this component cannot be recognised
    Mask = {
        component = 1,           -- 1 = Mask
        anyDrawable = false,     -- true = every drawable except 0 counts as a mask (the list is ignored)
        drawables = {            -- Mask drawable ids for both genders (adjust to your server's clothing)
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
            21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
        },
        male = {},               -- Extra drawables for mp_m_freemode_01 only
        female = {},             -- Extra drawables for mp_f_freemode_01 only
    },

    -- Accessories that cover the face: [prop index] = { drawable ids }. 0 = hat/helmet, 1 = glasses
    -- e.g. [0] = { 16, 17, 18 } -> closed helmets
    FaceProps = {},

    UI = {
        brand = "LSPD CCTV",
        locale = "en-US",        -- Date format (Intl locale tag)
        clock = "real",          -- "real" = the player's clock, "game" = in-game clock
    },

    -- Categories in the camera list (the order is the order in the UI). icon: bank, store, fuel, bottle, gem, camera
    Categories = {
        { id = "bank",    label = "Banks",          icon = "bank" },
        { id = "store",   label = "24/7 Stores",    icon = "store" },
        { id = "ltd",     label = "LTD Gasoline",   icon = "fuel" },
        { id = "liquor",  label = "Liquor Stores",  icon = "bottle" },
        { id = "jewelry", label = "Jewelry Stores", icon = "gem" },
    },
}
