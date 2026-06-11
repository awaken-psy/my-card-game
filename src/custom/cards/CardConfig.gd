# This class defines how the properties of the [Card] definition are to be
# used during `setup()`
#
# All the properties defined on the card json will attempt to find a matching
# label node inside the cards _card_labels dictionary.
# If one was not found, an error will be printed.
#
# The exception is properties starting with _underscore. This are considered
# Meta properties and the game will not attempt to display them on the card
# front.
class_name CardConfig
extends RefCounted

# Properties which are placed as they are in appropriate labels
const PROPERTIES_STRINGS := ["Type", "Abilities"]
# Properties which are converted into string using a format defined in setup()
const PROPERTIES_NUMBERS := ["Cost","Damage","Block"]
# The name of these properties will be prepended before their value to their label.
const NUMBER_WITH_LABEL := []
# Properties provided in a list which are converted into a string for the
# label text, using the array_join() method
const PROPERTIES_ARRAYS := ["Tags"]
# This property matches the name of the scene file (without the .tscn file)
# which is used as a template for this card.
const SCENE_PROPERTY = "Type"
# These are number carrying properties, which we want to hide their label
# when they're 0, to allow more space for other labels.
const NUMBERS_HIDDEN_ON_0 := ["Damage", "Block"]
# If any strings in this array are found in the value of a PROPERTIES_NUMBERS property
# Then during comparisons, they are treated as if they were 0
const VALUES_TREATED_AS_ZERO := ['X', 'null', null]
# The cards where their [SCENE_PROPERTY](#SCENE_PROPERTY) value is in this list
# will not be shown in the deckbuilder.
const TYPES_TO_HIDE_IN_CARDVIEWER := []
# If this property exists in a card and is set to true, the card will not be
# displayed in the cardviewer
const BOOL_PROPERTY_TO_HIDE_IN_CARDVIEWER := "_hide_in_deckbuilder"
# When these keys are detected in the "Tag" or "_keyword" fields, they
# will add extra info panel with the specified information to the player.
const EXPLANATIONS = {}
# Allows the Card object and Card Viewer to replace specific entries during display.
# Maps internal English identifiers to Chinese display text.
# canonical_name stays English (used by scripts, deck state, rewards, etc.).
const REPLACEMENTS = {
	"Name": {
		"Strike": "打击",
		"Defend": "防御",
		"Bash": "痛击",
		"Cleave": "顺劈",
		"Iron Wave": "铁浪",
		"Shrug It Off": "耸肩",
		"Pommel Strike": "刺击",
		"Inflame": "燃烧",
		"Bloodletting": "放血",
		"Heavy Blow": "重击",
		"Poison Stab": "毒刺",
		"Crippling Blow": "致残打击",
		"Bandage": "绷带",
		"Thorns": "荆棘",
		"Shield Bash": "盾击",
		"Fiend Fire": "魔焰",
	},
	"Type": {
		"Attack": "攻击",
		"Skill": "技能",
		"Power": "能力",
	},
	"Tags": {
		"Starter": "初始",
		"Common": "普通",
		"Uncommon": "稀有",
		"Rare": "史诗",
	},
}
# Defined bbcode which will replace the specified string in RichTextLabels
const CARD_BBCODE := {}
