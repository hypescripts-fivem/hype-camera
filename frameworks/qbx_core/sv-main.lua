---@diagnostic disable: duplicate-set-field
if GetResourceState('qbx_core') ~= 'started' then return end
if GetResourceState('es_extended') == 'started' then return end

Framework.Server = {}

local QBX = exports.qbx_core

--- Returns the name of the active framework.
---@return string Always returns "qbx_core".
function Framework.Server.GetFrameworkName()
    return 'qbx_core'
end

-- Player Actions

--- Returns the server ids of every loaded player.
---@return number[] Array of player server ids.
function Framework.Server.GetPlayers()
    local players = QBX:GetQBPlayers()
    local filteredPlayers = {}
    for _, player in pairs(players) do
        filteredPlayers[#filteredPlayers + 1] = player.PlayerData.source
    end
    return filteredPlayers
end

exports('GetPlayers', Framework.Server.GetPlayers)

--- Returns the framework player object.
---@param playerId number The player's server id.
---@return table|nil The qbx player object, or nil when the player is not loaded.
function Framework.Server.GetPlayer(playerId)
    local Player = QBX:GetPlayer(playerId)
    return Player and Player or nil
end

exports('GetPlayer', Framework.Server.GetPlayer)

--- Returns the character name of a player.
---@param playerId number The player's server id.
---@param split boolean|nil True to return firstname and lastname separately.
---@return string|nil name The full name, or the firstname when `split` is true.
---@return string|nil lastname Only returned when `split` is true.
function Framework.Server.GetCharacterName(playerId, split)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData or not Player.PlayerData.charinfo then return nil end

    local firstname = Player.PlayerData.charinfo.firstname
    local lastname  = Player.PlayerData.charinfo.lastname

    if split then
        return firstname, lastname
    end

    if not firstname or not lastname then return nil end
    return firstname .. " " .. lastname
end

exports('GetCharacterName', Framework.Server.GetCharacterName)

--- Returns the unique character identifier of a player.
---@param playerId number The player's server id.
---@return string|nil The identifier, or nil when the player is not loaded.
function Framework.Server.GetPlayerIdentifier(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    return Player and Player.PlayerData and Player.PlayerData.citizenid or nil
end

exports('GetPlayerIdentifier', Framework.Server.GetPlayerIdentifier)

--- Returns the radio callsign of a player, normalised to nil when unset.
---@param playerId number The player's server id.
---@return string|nil The callsign, or nil when the player has none.
function Framework.Server.GetPlayerCallsign(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData or not Player.PlayerData.metadata then return nil end

    local callsign = Player.PlayerData.metadata.callsign
    if not callsign or callsign == "" or callsign == "NO CALLSIGN" then return nil end
    return callsign
end

exports('GetPlayerCallsign', Framework.Server.GetPlayerCallsign)

-- Job Actions

--- Returns a normalised job data table for a player.
---@param playerId number The player's server id.
---@return table|nil A table with fields: name, label, grade.name, grade.level, isBoss, onDuty.
function Framework.Server.GetPlayerJob(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return nil end

    local jobData = Player.PlayerData.job
    if not jobData.grade then return nil end

    return {
        name   = jobData.name,
        label  = jobData.label,
        grade  = {
            name  = jobData.grade.name,
            level = jobData.grade.level,
        },
        isBoss = jobData.isboss,
        onDuty = jobData.onduty,
    }
end

exports('GetPlayerJob', Framework.Server.GetPlayerJob)

-- Identity Actions

--- Returns a normalised identity table for a player, used by face recognition.
---@param playerId number The player's server id.
---@return table|nil A table with fields: firstname, lastname, birthdate, gender (0 male, 1 female), nationality, phone, identifier, job.
function Framework.Server.GetCharacterInfo(playerId)
    local Player = Framework.Server.GetPlayer(playerId)
    if not Player or not Player.PlayerData then return nil end

    local data = Player.PlayerData
    local charinfo = data.charinfo or {}

    return {
        firstname   = charinfo.firstname,
        lastname    = charinfo.lastname,
        birthdate   = charinfo.birthdate,
        gender      = tonumber(charinfo.gender),
        nationality = charinfo.nationality,
        phone       = charinfo.phone,
        identifier  = data.citizenid,
        job         = data.job and data.job.label,
    }
end

exports('GetCharacterInfo', Framework.Server.GetCharacterInfo)

return Framework
