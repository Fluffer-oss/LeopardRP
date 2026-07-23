util.AddNetworkString("LeopardRP.UpdateMenuCameraPVS")

net.Receive("LeopardRP.UpdateMenuCameraPVS", function(_, client)
    if (!IsValid(client) or !client:IsPlayer()) then
        return
    end

    local points = net.ReadTable()

    if (isvector(points)) then
        client.ixLeopardMenuPVS = { points }
        return
    end

    if (!istable(points)) then
        client.ixLeopardMenuPVS = nil
        return
    end

    local positions = {}

    for _, point in ipairs(points) do
        if (isvector(point)) then
            positions[#positions + 1] = point
        end
    end

    client.ixLeopardMenuPVS = #positions > 0 and positions or nil
end)

hook.Add("SetupPlayerVisibility", "LeopardRP.MenuCameraPVS", function(client)
    local positions = client and client.ixLeopardMenuPVS

    if (isvector(positions)) then
        AddOriginToPVS(positions)
        return
    end

    if (!istable(positions)) then
        return
    end

    for _, position in ipairs(positions) do
        if (isvector(position)) then
            AddOriginToPVS(position)
        end
    end
end)

hook.Add("PlayerDisconnected", "LeopardRP.MenuCameraPVSCleanup", function(client)
    if (IsValid(client)) then
        client.ixLeopardMenuPVS = nil
    end
end)
