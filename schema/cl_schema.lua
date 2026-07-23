
-- Here is where all of your clientside functions should go.

ix.util.Include("derma/cl_leopardrp_character_preview.lua")
ix.util.Include("derma/cl_leopardrp_helix_compat.lua")
ix.util.Include("derma/cl_leopardrp_charmenu_polish.lua")
ix.util.Include("derma/cl_leopardrp_menu.lua")
ix.util.Include("derma/cl_leopardrp_news_panel.lua")
ix.util.Include("derma/cl_leopardrp_gm_itemspawner.lua")
ix.util.Include("derma/cl_leopardrp_menu_hooks.lua")

local function getPreferredMenuMusicPath()
	local candidates = {
		"leopardrp/menu/main_menu_theme.ogg",
		"leopardrp/menu/main_menu_theme.mp3"
	}

	for _, path in ipairs(candidates) do
		if (file.Exists("sound/" .. path, "GAME")) then
			return path
		end
	end

	return nil
end

local function enforcePreferredMenuMusic()
	local preferredPath = getPreferredMenuMusicPath()

	if (!preferredPath) then
		return nil
	end

	if (ix and ix.config and ix.config.Set and ix.config.Get and ix.config.Get("music") ~= preferredPath) then
		ix.config.Set("music", preferredPath)
	end

	return preferredPath
end

local function playPreferredMenuMusic(menu)
	local preferredPath = enforcePreferredMenuMusic()

	if (!IsValid(menu) or !preferredPath) then
		return
	end

	if (IsValid(menu.channel)) then
		menu.channel:Stop()
		menu.channel = nil
	end

	local path = "sound/" .. preferredPath
	sound.PlayFile(path, "noplay", function(channel)
		if (!IsValid(menu) or !IsValid(channel)) then
			if (IsValid(channel)) then
				channel:Stop()
			end
			return
		end

		menu.channel = channel
		channel:SetVolume((menu.volume or 1) * 0.5)
		channel:Play()
	end)
end

hook.Add("InitializedConfig", "LeopardRP.EnsureMenuMusicClient", function()
	enforcePreferredMenuMusic()
end)

hook.Add("OnCharacterMenuCreated", "LeopardRP.EnsureMenuMusicChannel", function(menu)
	if (!IsValid(menu)) then
		return
	end

	timer.Simple(0, function()
		if (!IsValid(menu)) then
			return
		end

		playPreferredMenuMusic(menu)
	end)
end)

local reloadedMenuScripts = {
	"derma/cl_leopardrp_helix_compat.lua",
	"derma/cl_leopardrp_character_preview.lua",
	"derma/cl_leopardrp_charmenu_polish.lua",
	"derma/cl_leopardrp_menu.lua",
	"derma/cl_leopardrp_news_panel.lua",
	"derma/cl_leopardrp_gm_itemspawner.lua",
	"derma/cl_leopardrp_menu_hooks.lua"
}

local function reloadMenuScripts()
	local loadedCount = 0
	local failedScripts = {}

	for _, scriptPath in ipairs(reloadedMenuScripts) do
		local schemaPath = "schema/" .. scriptPath

		if (file.Exists(schemaPath, "LUA")) then
			include(schemaPath)
			loadedCount = loadedCount + 1
		elseif (file.Exists(scriptPath, "LUA")) then
			include(scriptPath)
			loadedCount = loadedCount + 1
		else
			failedScripts[#failedScripts + 1] = scriptPath
		end
	end

	return loadedCount, failedScripts
end

local function rebuildOpenMenus()
	if (IsValid(ix.gui.characterMenu)) then
		ix.gui.characterMenu:Remove()
		vgui.Create("ixCharMenu")
	end

	if (IsValid(ix.gui.menu)) then
		ix.gui.menu:Remove()
		vgui.Create("ixMenu")
	end
end

concommand.Add("leopardrp_reload_menu", function()
	local loadedCount, failedScripts = reloadMenuScripts()
	rebuildOpenMenus()

	if (IsValid(LocalPlayer())) then
		LocalPlayer():ChatPrint("[LeopardRP] Reloaded " .. tostring(loadedCount) .. " menu scripts.")

		if (#failedScripts > 0) then
			LocalPlayer():ChatPrint("[LeopardRP] Missing scripts: " .. table.concat(failedScripts, ", "))
		end
	end
end)

-- Example client function that will print to the chatbox.
function Schema:ExampleFunction(text, ...)
	if (text:sub(1, 1) == "@") then
		text = L(text:sub(2), ...)
	end

	LocalPlayer():ChatPrint(text)
end
