
-- The shared init file. You'll want to fill out the info for your schema and include any other files that you need.

-- Schema info
Schema.name = "Star Trek RP"
Schema.author = "Dr,fluff"
Schema.description = "Please join our discord at discord.gg/tt3yrH8DTx for support and to report bugs. This is a work in progress and is not yet complete. Please be patient as we continue to develop this server."

-- Additional files that aren't auto-included should be included here. Note that ix.util.Include will take care of properly
-- using AddCSLuaFile, given that your files have the proper naming scheme.

-- You could technically put most of your schema code into a couple of files, but that makes your code a lot harder to manage -
-- especially once your project grows in size. The standard convention is to have your miscellaneous functions that don't belong
-- in a library reside in your cl/sh/sv_schema.lua files. Your gamemode hooks should reside in cl/sh/sv_hooks.lua. Logical
-- groupings of functions should be put into their own libraries in the libs/ folder. Everything in the libs/ folder is loaded
-- automatically.
ix.util.Include("cl_schema.lua")
ix.util.Include("sv_schema.lua")

ix.util.Include("cl_hooks.lua")
ix.util.Include("sh_hooks.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("libs/sh_inventory_debug.lua")
ix.util.Include("libs/sh_stm_compat.lua")
ix.util.Include("libs/sh_vrmod_compat.lua")

-- Ported LeopardRP example systems
ix.util.Include("leopardrp_port/config.lua")
ix.util.Include("leopardrp_port/config_owners.lua")
ix.util.Include("leopardrp_port/data/sh_ranks.lua")

ix.util.Include("leopardrp_port/character_creation/sh_character_creation.lua")
ix.util.Include("leopardrp_port/character_creation/ui/cl_fonts.lua")
ix.util.Include("leopardrp_port/character_creation/ui/cl_theme.lua")
ix.util.Include("leopardrp_port/character_creation/ui/cl_background.lua")
ix.util.Include("leopardrp_port/character_creation/ui/cl_buttons.lua")

ix.util.Include("leopardrp_port/game_master_system/sh_gm.lua")
ix.util.Include("leopardrp_port/game_master_system/sv_gm.lua")
ix.util.Include("leopardrp_port/game_master_system/cl_gm.lua")
ix.util.Include("leopardrp_port/game_master_system/ui/cl_gm_menu.lua")

ix.util.Include("leopardrp_port/personnel_management/sh_personnel.lua")
ix.util.Include("leopardrp_port/personnel_management/sv_personnel.lua")
ix.util.Include("leopardrp_port/personnel_management/cl_personnel.lua")
ix.util.Include("leopardrp_port/personnel_management/ui/cl_basepanel.lua")
ix.util.Include("leopardrp_port/personnel_management/ui/cl_adminpanel.lua")
ix.util.Include("leopardrp_port/personnel_management/ui/cl_crewmanager.lua")

ix.util.Include("leopardrp_port/combadge/sh_combadge.lua")
ix.util.Include("leopardrp_port/combadge/sv_combadge.lua")
ix.util.Include("leopardrp_port/combadge/cl_combadge.lua")

-- You'll need to manually include files in the meta/ folder, however.
ix.util.Include("meta/sh_character.lua")
ix.util.Include("meta/sh_player.lua")
