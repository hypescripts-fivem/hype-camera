Modules = {
    Server = {
        Notify = {},
    },
    Client = {
        Notify = {},
        Target = {},
    }
}

--- Returns the Modules table or a specific side's module group.
--- Exported as `GetModules` for use by other resources.
---@param targetModule string|nil Pass "Notify" or "Target" to get only that module. Pass nil to get every module of the current side.
---@return table The requested module group or the current side's modules.
exports('GetModules', function(targetModule)
    local isServer = IsDuplicityVersion() and 'Server' or 'Client'
    if targetModule and Modules[isServer][targetModule] then
        return Modules[isServer][targetModule]
    end

    return Modules[isServer]
end)
