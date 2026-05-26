local ESX = exports['es_extended']:getSharedObject()

local function coordsFromInput(coords)
    if not coords then return end
    if type(coords) == 'vector3' or type(coords) == 'vector4' then
        return coords.x, coords.y, coords.z or 0.0
    end
    if type(coords) == 'table' and coords.x and coords.y then
        return coords.x, coords.y, coords.z or 0.0
    end
end

local function callerName(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getName then
        return xPlayer.getName()
    end
    return GetPlayerName(src) or 'Anonym'
end

local function buildSimple(source, message, job, arg4, arg5, anonymous)
    if type(message) ~= 'string' or message == '' then return end
    if type(job) ~= 'string' or job == '' then return end

    local coords, description
    if source == nil then
        coords = arg4
        description = arg5
    elseif type(arg4) == 'string' and arg4 ~= '' then
        description = arg4
    end

    local data = {
        type = 'Opkald',
        message = message,
        description = description or message,
        jobs = { job },
        anonymousPhone = anonymous == true,
    }

    if source == nil then
        local x, y, z = coordsFromInput(coords)
        if not x then return end
        data.x, data.y, data.z = x, y, z
        data.caller = 'Anonym'
    else
        data.source = tonumber(source)
        if not data.source then return end
        data.caller = callerName(data.source)
    end

    return data
end

function AddCall(source, message, job, arg4, arg5)
    if type(source) == 'table' then
        source.anonymousPhone = false
        return Opkaldsliste.AddCall(source)
    end
    local data = buildSimple(source, message, job, arg4, arg5, false)
    if not data then return end
    return Opkaldsliste.AddCall(data)
end

function AddAnonymousCall(source, message, job, arg4, arg5)
    if type(source) == 'table' then
        source.anonymousPhone = true
        return Opkaldsliste.AddCall(source)
    end
    local data = buildSimple(source, message, job, arg4, arg5, true)
    if not data then return end
    return Opkaldsliste.AddCall(data)
end

exports('AddCall', AddCall)
exports('AddAnonymousCall', AddAnonymousCall)
