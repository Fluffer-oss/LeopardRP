local MENU_MUSIC_CANDIDATES = {
    "gamemodes/LeopardRP/sound/leopardrp/menu/main_menu_theme.ogg",
    "gamemodes/LeopardRP/sound/leopardrp/menu/main_menu_theme.mp3",
    "sound/leopardrp/menu/main_menu_theme.ogg",
    "sound/leopardrp/menu/main_menu_theme.mp3",
}

local musicChannel = nil
local pendingOpen = false

local function getResolvedMenuMusicPath()
    for _, path in ipairs(MENU_MUSIC_CANDIDATES) do
        if (file.Exists(path, "GAME")) then
            return path
        end
    end

    return MENU_MUSIC_CANDIDATES[1]
end

local function hasMenuOpen()
    return IsValid(ix.gui.characterMenu) or IsValid(ix.gui.menu)
end

local function stopMenuMusic()
    pendingOpen = false

    if musicChannel then
        musicChannel:Stop()
        musicChannel = nil
    end
end

local function startMenuMusic()
    if musicChannel or pendingOpen then
        return
    end

    pendingOpen = true

    local resolvedPath = getResolvedMenuMusicPath()

    sound.PlayFile(resolvedPath, "noplay noblock", function(channel, errCode, errName)
        pendingOpen = false

        if not hasMenuOpen() then
            if channel then
                channel:Stop()
            end
            return
        end

        if not IsValid(channel) then
            if errName and errName ~= "" then
                MsgN("[LeopardRP] Menu music failed to load from '" .. tostring(resolvedPath) .. "': " .. tostring(errName))
            end
            return
        end

        musicChannel = channel
        musicChannel:SetVolume(0.45)
        musicChannel:EnableLooping(true)
        musicChannel:Play()
    end)
end

hook.Add("OnCharacterMenuCreated", "LeopardRP.MenuMusicStart", function()
    startMenuMusic()
end)

hook.Add("Think", "LeopardRP.MenuMusicWatch", function()
    if hasMenuOpen() then
        if not musicChannel and not pendingOpen then
            startMenuMusic()
        end
    elseif musicChannel or pendingOpen then
        stopMenuMusic()
    end
end)

hook.Add("ShutDown", "LeopardRP.MenuMusicShutdown", function()
    stopMenuMusic()
end)