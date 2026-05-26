local ESX = exports['es_extended']:getSharedObject()

local Calls = {}
local callCounter = 0
local pendingLocations = {}

local function jobAllowed(name)
    for i = 1, #Config.AllowedJobs do
        if Config.AllowedJobs[i] == name then
            return true
        end
    end
end

local function canAccess(xPlayer)
    if not xPlayer or not xPlayer.job then return false end
    if not jobAllowed(xPlayer.job.name) then return false end
    if Config.RequireOnDuty and not xPlayer.job.onDuty then return false end
    return true
end

local function findCall(id)
    for i = 1, #Calls do
        if Calls[i].id == id then
            return i, Calls[i]
        end
    end
end

local function callForJob(job)
    local list = {}
    for i = 1, #Calls do
        local call = Calls[i]
        for j = 1, #(call.jobs or {}) do
            if call.jobs[j] == job then
                list[#list + 1] = call
                break
            end
        end
    end
    return list
end

local function parseJobs(jobs)
    if type(jobs) ~= 'table' then return end

    local out = {}
    for i = 1, #jobs do
        local name = jobs[i]
        if type(name) == 'string' and name ~= '' and jobAllowed(name) then
            local dup = false
            for j = 1, #out do
                if out[j] == name then dup = true break end
            end
            if not dup then out[#out + 1] = name end
        end
    end

    if #out == 0 then return end
    return out
end

local function alertIdForJob(newCall, newCallId, job)
    if not newCall or not newCall.jobs then return end
    for i = 1, #newCall.jobs do
        if newCall.jobs[i] == job then
            return newCallId
        end
    end
end

local function syncCalls(newCallId)
    local newCall
    if newCallId then
        local _, call = findCall(newCallId)
        newCall = call
    end

    if ESX.GetExtendedPlayers then
        for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
            if canAccess(xPlayer) then
                local job = xPlayer.job.name
                TriggerClientEvent(
                    'vem-opkaldsliste:syncCalls',
                    xPlayer.source,
                    callForJob(job),
                    alertIdForJob(newCall, newCallId, job)
                )
            end
        end
        return
    end

    for _, src in ipairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(src)
        if canAccess(xPlayer) then
            local job = xPlayer.job.name
            TriggerClientEvent(
                'vem-opkaldsliste:syncCalls',
                src,
                callForJob(job),
                alertIdForJob(newCall, newCallId, job)
            )
        end
    end
end

function GetIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(tonumber(src))
    return xPlayer and xPlayer.identifier
end

function GetPhoneNumber(identifier)
    if not identifier then return end

    if GetResourceState('oxmysql') == 'started' then
        local ok, phone = pcall(function()
            return exports.oxmysql:scalar_sync(
                'SELECT phone_number FROM phone_phones WHERE id = ? LIMIT 1',
                { identifier }
            )
        end)
        if ok and type(phone) == 'string' and phone ~= '' then
            return phone
        end
    end

    if MySQL and MySQL.Sync then
        local rows = MySQL.Sync.fetchAll(
            'SELECT phone_number FROM phone_phones WHERE id = @identifier LIMIT 1',
            { ['@identifier'] = identifier }
        )
        if rows[1] and rows[1].phone_number and rows[1].phone_number ~= '' then
            return rows[1].phone_number
        end
    end

    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if xPlayer and GetResourceState('lb-phone') == 'started' then
        local ok, phone = pcall(function()
            return exports['lb-phone']:GetEquippedPhoneNumber(xPlayer.source)
        end)
        if ok and type(phone) == 'string' and phone ~= '' then
            return phone
        end
    end
end

local function callerPhone(src, preset)
    if type(preset) == 'string' and preset ~= '' then
        return preset
    end
    if not src then
        return Config.AutomaticMessage
    end
    local id = GetIdentifier(src)
    return (id and GetPhoneNumber(id)) or Config.AutomaticMessage
end

local function playerCoords(src)
    local ped = GetPlayerPed(tonumber(src))
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    return c.x, c.y, c.z
end

function ResolveLocationFromCoords(x, y, z)
    local players = GetPlayers()
    if not players[1] then
        return 'Ukendt lokation'
    end

    local requestId = ('loc-%s'):format(math.random(100000, 999999))
    local done

    pendingLocations[requestId] = function(street)
        done = street
    end

    TriggerClientEvent('vem-opkaldsliste:resolveLocation', players[1], requestId, x, y, z or 0.0)

    local till = GetGameTimer() + 3000
    while done == nil and GetGameTimer() < till do
        Wait(0)
    end

    pendingLocations[requestId] = nil
    return done or 'Ukendt lokation'
end

RegisterNetEvent('vem-opkaldsliste:locationResult', function(requestId, location)
    local fn = pendingLocations[requestId]
    if not fn then return end
    pendingLocations[requestId] = nil
    fn(location ~= '' and location or 'Ukendt lokation')
end)

function AddCall(data)
    if type(data) ~= 'table' then return end
    data.type = data.type or data.message or 'Opkald'

    if not data.x or not data.y then
        local x, y, z = playerCoords(data.source)
        if not x then return end
        data.x, data.y, data.z = x, y, z
    end

    if data.id then
        local _, existing = findCall(data.id)
        if existing then return existing end
    end

    local jobs = parseJobs(data.jobs) or parseJobs(Config.DefaultCallJobs)
    if not jobs then return end

    local phone = Config.AutomaticMessage
    if not data.anonymousPhone then
        phone = callerPhone(data.source, data.callerPhone)
    elseif type(data.callerPhone) == 'string' and data.callerPhone ~= '' then
        phone = data.callerPhone
    end
    local location = data.location
    if not location or location == '' then
        location = ResolveLocationFromCoords(data.x, data.y, data.z)
    end

    callCounter = callCounter + 1

    local call = {
        id = data.id or ('call-%s'):format(callCounter),
        type = data.type,
        location = location,
        caller = data.caller or 'Anonym',
        callerPhone = phone,
        description = data.description or data.message,
        message = data.message,
        isPhoneCall = data.isPhoneCall == true or phone ~= '',
        time = data.time or os.date('%H:%M'),
        x = data.x + 0.0,
        y = data.y + 0.0,
        jobs = jobs,
        responders = {},
    }

    Calls[#Calls + 1] = call
    syncCalls(call.id)
    return call
end

Opkaldsliste = {
    AddCall = AddCall,
    GetIdentifier = GetIdentifier,
    GetPhoneNumber = GetPhoneNumber,
    ResolveLocationFromCoords = ResolveLocationFromCoords,
    ResolvePlayerCoords = playerCoords,
}

ESX.RegisterServerCallback('vem-opkaldsliste:getCalls', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not canAccess(xPlayer) then
        cb({})
        return
    end
    cb(callForJob(xPlayer.job.name))
end)

RegisterNetEvent('vem-opkaldsliste:takeCall', function(id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not canAccess(xPlayer) then return end

    local _, call = findCall(id)
    if not call then return end

    local matches = false
    for i = 1, #(call.jobs or {}) do
        if call.jobs[i] == xPlayer.job.name then
            matches = true
            break
        end
    end
    if not matches then return end

    call.responders = call.responders or {}
    for i = 1, #call.responders do
        if call.responders[i].identifier == xPlayer.identifier then
            return
        end
    end

    call.responders[#call.responders + 1] = {
        identifier = xPlayer.identifier,
        name = xPlayer.getName and xPlayer.getName() or GetPlayerName(source),
    }

    syncCalls()
end)

RegisterNetEvent('vem-opkaldsliste:leaveCall', function(id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not canAccess(xPlayer) then return end

    local _, call = findCall(id)
    if not call or not call.responders then return end

    local okJob = false
    for i = 1, #(call.jobs or {}) do
        if call.jobs[i] == xPlayer.job.name then
            okJob = true
            break
        end
    end
    if not okJob then return end

    for i = 1, #call.responders do
        if call.responders[i].identifier == xPlayer.identifier then
            table.remove(call.responders, i)
            syncCalls()
            return
        end
    end
end)

RegisterNetEvent('vem-opkaldsliste:deleteCall', function(id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not canAccess(xPlayer) then return end

    local index, call = findCall(id)
    if not index then return end

    for i = 1, #(call.jobs or {}) do
        if call.jobs[i] == xPlayer.job.name then
            table.remove(Calls, index)
            syncCalls()
            return
        end
    end
end)
