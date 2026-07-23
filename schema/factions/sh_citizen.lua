
-- You can define factions in the factions/ folder. You need to have at least one faction that is the default faction - i.e the
-- faction that will always be available without any whitelists and etc.

FACTION.name = "Starfleet"
FACTION.description = "Standard Starfleet personnel entering service through Starfleet Academy."
FACTION.isDefault = true
FACTION.color = Color(52, 120, 201)

FACTION.models = {
	"models/nova_canterra/star_trek/playermodels/bodies/2385/standard/male_cadet/startrek_male_cadet.mdl",
	"models/nova_canterra/star_trek/playermodels/bodies/2385/standard/female_cadet/startrek_female_cadet.mdl"
}

-- You should define a global variable for this faction's index for easy access wherever you need. FACTION.index is
-- automatically set, so you can simply assign the value.

-- Note that the player's team will also have the same value as their current character's faction index. This means you can use
-- client:Team() == FACTION_CITIZEN to compare the faction of the player's current character.
FACTION_STARFLEET = FACTION.index
