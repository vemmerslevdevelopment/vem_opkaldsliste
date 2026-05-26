local ESX = exports['es_extended']:getSharedObject()

local isOpen = false
local playerReady = false
local callIdsSeen = {}
local callsReady = false
local cachedCalls = {}
local refreshBusy = false
local notifySound = true
local notifySoundId = ''

local function jobAllowed(name)
    for i = 1, #Config.AllowedJobs do
        if Config.AllowedJobs[i] == name then
            return true
        end
    end
end

local function hasAccess()
    if not playerReady or not ESX.PlayerData or not ESX.PlayerData.job then
        return false
    end
    if not jobAllowed(ESX.PlayerData.job.name) then
        return false
    end
    if Config.RequireOnDuty and not ESX.PlayerData.job.onDuty then
        return false
    end
    return true
end

local function closeUi()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function toNuiCalls(calls)
    local myId = ESX.PlayerData and ESX.PlayerData.identifier
    local out = {}

    for i = 1, #(calls or {}) do
        local call = calls[i]
        local responders = call.responders or {}
        local names = {}
        local onCall = false

        for j = 1, #responders do
            if myId and responders[j].identifier == myId then
                onCall = true
            end
            if responders[j].name then
                names[#names + 1] = responders[j].name
            end
        end

        out[#out + 1] = {
            id = call.id,
            type = call.type,
            location = call.location,
            caller = call.caller,
            callerPhone = call.callerPhone,
            message = call.message,
            description = call.description or call.message,
            isPhoneCall = call.isPhoneCall,
            time = call.time,
            x = call.x,
            y = call.y,
            responderCount = #responders,
            responderNames = names,
            selfAssigned = onCall,
        }
    end

    return out
end

local function sendCalls(calls, newId)
    SendNUIMessage({
        action = 'setCalls',
        calls = toNuiCalls(calls),
        newCallId = newId,
    })
end

local function refreshCalls()
    if refreshBusy or not hasAccess() then return end
    refreshBusy = true

    ESX.TriggerServerCallback('vem-opkaldsliste:getCalls', function(calls)
        refreshBusy = false
        cachedCalls = calls or {}

        if not callsReady then
            for i = 1, #cachedCalls do
                callIdsSeen[cachedCalls[i].id] = true
            end
            callsReady = true
        end

        if isOpen then
            sendCalls(cachedCalls)
        end
    end)
end

local function playAlert()
    if not notifySound or not Config.CallAlert or not Config.CallAlert.Enabled then return end
    SendNUIMessage({ action = 'playAlertSound', sound = notifySoundId })
end

local function onCallsUpdated(calls, newCallId)
    cachedCalls = calls or {}
    local alertId

    if not callsReady then
        for i = 1, #cachedCalls do
            callIdsSeen[cachedCalls[i].id] = true
        end
        callsReady = true
        if isOpen then sendCalls(cachedCalls) end
        return
    end

    if newCallId and not callIdsSeen[newCallId] then
        callIdsSeen[newCallId] = true
        alertId = newCallId
    else
        for i = 1, #cachedCalls do
            local id = cachedCalls[i].id
            if not callIdsSeen[id] then
                callIdsSeen[id] = true
                if not alertId then alertId = id end
            end
        end
    end

    local live = {}
    for i = 1, #cachedCalls do
        live[cachedCalls[i].id] = true
    end
    for id in pairs(callIdsSeen) do
        if not live[id] then callIdsSeen[id] = nil end
    end

    if alertId and hasAccess() then
        playAlert()
    end

    if isOpen then
        sendCalls(cachedCalls, alertId)
    end
end

local function openUi()
    if not hasAccess() then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', calls = toNuiCalls(cachedCalls) })
    CreateThread(function()
        for _ = 1, 25 do
            Wait(100)
            if not isOpen then return end
            SendNUIMessage({ action = 'open', calls = toNuiCalls(cachedCalls) })
        end
    end)
    refreshCalls()
end

RegisterCommand(Config.Command, function()
    if isOpen then closeUi() else openUi() end
end, false)

RegisterCommand('opkaldsliste_fix', closeUi, false)
RegisterKeyMapping(Config.Command, 'Åbn opkaldsliste', 'keyboard', Config.Key)

CreateThread(function()
    while not ESX.PlayerLoaded do
        local data = ESX.GetPlayerData()
        if data and data.job then
            ESX.PlayerData = data
            playerReady = true
            break
        end
        Wait(200)
    end
    ESX.PlayerData = ESX.GetPlayerData()
    playerReady = true
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    playerReady = true
    CreateThread(function()
        Wait(1000)
        refreshCalls()
    end)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    playerReady = false
    callIdsSeen = {}
    callsReady = false
    cachedCalls = {}
    if isOpen then closeUi() end
end)

RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
    callIdsSeen = {}
    callsReady = false
    if hasAccess() then
        refreshCalls()
    else
        cachedCalls = {}
        if isOpen then sendCalls({}) end
    end
end)

RegisterNetEvent('vem-opkaldsliste:syncCalls', onCallsUpdated)

RegisterNetEvent('vem-opkaldsliste:resolveLocation', function(requestId, x, y, z)
    local coords = vector3(x, y, z or 0.0)
    local hash, cross = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(hash) or 'Ukendt lokation'

    if cross ~= 0 then
        local name = GetStreetNameFromHashKey(cross)
        if name and name ~= '' then
            street = street .. ' / ' .. name
        end
    end

    TriggerServerEvent('vem-opkaldsliste:locationResult', requestId, street)
end)

RegisterNUICallback('ready', function(_, cb)
    if isOpen then
        SendNUIMessage({ action = 'open', calls = toNuiCalls(cachedCalls) })
    end
    cb({ ok = true })
end)

RegisterNUICallback('syncSettings', function(data, cb)
    if data.notifySound ~= nil then
        notifySound = data.notifySound == true
    end
    if data.notifySoundId and data.notifySoundId ~= '' then
        notifySoundId = data.notifySoundId
    end
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('takeCall', function(data, cb)
    if data.id then TriggerServerEvent('vem-opkaldsliste:takeCall', data.id) end
    cb({ ok = true })
end)

RegisterNUICallback('leaveCall', function(data, cb)
    if data.id then TriggerServerEvent('vem-opkaldsliste:leaveCall', data.id) end
    cb({ ok = true })
end)

RegisterNUICallback('deleteCall', function(data, cb)
    if data.id then TriggerServerEvent('vem-opkaldsliste:deleteCall', data.id) end
    cb({ ok = true })
end)

RegisterNUICallback('setGps', function(data, cb)
    for i = 1, #cachedCalls do
        local call = cachedCalls[i]
        if call.id == data.id and call.x and call.y then
            SetNewWaypoint(call.x, call.y)
            cb({ ok = true })
            return
        end
    end
    cb({ ok = false })
end)

CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 322, true)
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustReleased(0, 322) or IsDisabledControlJustReleased(0, 200) then
                closeUi()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if isOpen and hasAccess() then
            Wait(10000)
            refreshCalls()
        else
            Wait(1500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then closeUi() end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeUi()
    callsReady = false
    callIdsSeen = {}
    local data = ESX.GetPlayerData()
    if data and data.job then
        ESX.PlayerData = data
        playerReady = true
    end
    CreateThread(function()
        Wait(1500)
        refreshCalls()
    end)
end)
