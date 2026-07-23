LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

LeopardRP.Config.EnableCharacterSelection = true
LeopardRP.Config.EnableCharacterCreation = true
LeopardRP.Config.EnableSpeciesSelection = true
LeopardRP.Config.EnableHeadSelection = true
LeopardRP.Config.EnableBodySelection = true
LeopardRP.Config.EnableBonemerge = true
LeopardRP.Config.AllowCustomHeads = false
LeopardRP.Config.AutoApplyOnSpawn = true
LeopardRP.Config.AutoRespawnOnCharacterSwitch = true
LeopardRP.Config.NormalCharacterSlots = 5
LeopardRP.Config.MaxCharactersPerSteamID = 4
LeopardRP.Config.CharacterStorageDirectory = "leopardrp/characters"
LeopardRP.Config.DefaultSpecies = "Human"
LeopardRP.Config.DefaultGender = "Male"
LeopardRP.Config.DefaultDivision = "Operations"
LeopardRP.Config.DefaultUniformType = "Standard"
LeopardRP.Config.OpenMenuCommand = "!leopardrp"
LeopardRP.Config.DiscordInviteURL = "https://discord.gg/7XUrywCGKU"

LeopardRP.Config.KeybindOpenMainMenu = KEY_F2
LeopardRP.Config.KeybindOpenCharacterSelection = KEY_NONE
LeopardRP.Config.KeybindOpenGameMasterMenu = KEY_F4
LeopardRP.Config.KeybindOpenAdministrationMenu = KEY_F4
LeopardRP.Config.KeybindOpenInventory = KEY_I
LeopardRP.Config.KeybindVoiceRangeCycle = KEY_COMMA
LeopardRP.Config.KeybindOpenCrewManager = KEY_F9
LeopardRP.Config.KeybindOpenAdminPanel = KEY_F10
LeopardRP.Config.KeybindOpenTrainingManagement = KEY_NONE

LeopardRP.Config.EnableCrewManager = true
LeopardRP.Config.EnableAdministrationPanel = true
LeopardRP.Config.CommandStaffMinimumRankOrder = 12

LeopardRP.Config.MainMenuNewsPages = {
	{
		title = "Latest Update",
		description = "LeopardRP now features a modular full-screen front end, a dynamic character creator, and persistent character data that can grow with future systems.",
		moreInfoLabel = "Click for more information"
	},
	{
		title = "Character Systems",
		description = "Characters, rank progression, and creation data all flow through centralized tables so future departments, jobs, and ships can integrate cleanly.",
		moreInfoLabel = "Click for more information"
	},
	{
		title = "Framework Ready",
		description = "The UI stack is designed to scale across 1080p, ultrawide, and 4K while keeping panels lightweight and reusable.",
		moreInfoLabel = "Click for more information"
	}
}
