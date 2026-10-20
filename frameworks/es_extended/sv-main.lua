---@diagnostic disable: duplicate-set-field
if GetResourceState('es_extended') ~= 'started' then return end

Framework.Server = {}

local ESX = exports.es_extended:getSharedObject()

--- Returns the name of the active framework.
---@return string Always returns "es_extended".
function Framework.Server.GetFrameworkName()
    return 'es_extended'
end

-- Player Actions

--- Returns the server ids of every loaded player.
---@return number[] Array of player server ids.
function Framework.Server.GetPlayers()
    local players = {}
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        players[#players + 1] = xPlayer.source
    end
    return players
end

exports('GetPlayers', Framework.Server.GetPlayers)

--- Returns the framework player object.
---@param playerId number The player's server id.
---@return table|nil The xPlayer object, or nil when the player is not loaded.
function Framework.Server.GetPlayer(playerId)
    local Player = ESX.GetPlayerFromId(playerId)
    return Player and Player or nil
end

exports('GetPlayer', Framework.Server.GetPlayer)

--- Returns the character name of a player.
--- ESX stores one display name, so `split` returns the first and last word of it.
---@param playerId number The player's server id.
---@param split boolean|nil True to return firstname and lastname separately.
---@return string|nil name The full name, or the firstname when `split` is true.
---@return string|nil lastname Only returned when `split` is true.
function Framework.Server.GetCharacterName(playerId, split)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return nil end

    local name = Player.getName()
    if not name then return nil end

    if split then
        local firstname, lastname = name:match("^(%S+)%s+(.*)$")
        return firstname or name, lastname
    end

    return name
end

exports('GetCharacterName', Framework.Server.GetCharacterName)

--- Returns the unique character identifier of a player.
---@param playerId number The player's server id.
---@return string|nil The identifier, or nil when the player is not loaded.
function Framework.Server.GetPlayerIdentifier(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return nil end
    return Player.getIdentifier() or nil
end

exports('GetPlayerIdentifier', Framework.Server.GetPlayerIdentifier)

--- Returns the radio callsign of a player, normalised to nil when unset.
--- ESX has no callsign field, so the `callsign` metadata is read when a resource sets it.
---@param playerId number The player's server id.
---@return string|nil The callsign, or nil when the player has none.
function Framework.Server.GetPlayerCallsign(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.getMeta then return nil end

    local callsign = Player.getMeta('callsign')
    if type(callsign) ~= "string" or callsign == "" or callsign == "NO CALLSIGN" then return nil end
    return callsign
end

exports('GetPlayerCallsign', Framework.Server.GetPlayerCallsign)

-- Job Actions

--- Returns a normalised job data table for a player.
--- ESX has no duty system, so `onDuty` reads the `onDuty` metadata when a job
--- resource sets it and reports true otherwise.
---@param playerId number The player's server id.
---@return table|nil A table with fields: name, label, grade.name, grade.level, isBoss, onDuty.
function Framework.Server.GetPlayerJob(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.job then return nil end

    local jobData = Player.job
    if not jobData.grade then return nil end

    local duty = Player.getMeta and Player.getMeta('onDuty')

    return {
        name   = jobData.name,
        label  = jobData.label,
        grade  = {
            name  = jobData.grade_name,
            level = jobData.grade,
        },
        isBoss = jobData.grade_name == "boss",
        onDuty = duty == nil and true or duty == true,
    }
end

exports('GetPlayerJob', Framework.Server.GetPlayerJob)

-- Identity Actions

--- Returns a normalised identity table for a player, used by face recognition.
--- Reads the esx_identity fields; nationality and phone are only filled when another
--- resource stores them on the player.
---@param playerId number The player's server id.
---@return table|nil A table with fields: firstname, lastname, birthdate, gender (0 male, 1 female), nationality, phone, identifier, job.
function Framework.Server.GetCharacterInfo(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player then return nil end

    local firstname, lastname = Player.get('firstName'), Player.get('lastName')
    if not firstname then
        firstname, lastname = Framework.Server.GetCharacterName(playerId, true)
    end

    local sex = Player.get('sex')
    local gender = nil
    if sex ~= nil then
        gender = (sex == 'f' or sex == 'F' or tonumber(sex) == 1) and 1 or 0
    end

    return {
        firstname   = firstname,
        lastname    = lastname,
        birthdate   = Player.get('dateofbirth'),
        gender      = gender,
        nationality = Player.get('nationality'),
        phone       = Player.get('phoneNumber') or Player.get('phone_number'),
        identifier  = Player.getIdentifier(),
        job         = Player.job and Player.job.label,
    }
end

exports('GetCharacterInfo', Framework.Server.GetCharacterInfo)

return Framework
