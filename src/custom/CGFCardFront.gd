extends CardFront

var _damage_icon: TextureRect
var _block_icon: TextureRect

func _ready() -> void:
	_card_text = find_child("CardText")
	# Map card front labels to scene nodes
	card_labels["Name"] = find_child("Name")
	card_labels["Type"] = find_child("Type")
	card_labels["Tags"] = find_child("Tags")
	card_labels["Abilities"] = find_child("Abilities")
	card_labels["Cost"] = find_child("Cost")
	card_labels["Damage"] = find_child("Damage")
	card_labels["Block"] = find_child("Block")

	# Store icon references for visibility toggling
	_damage_icon = find_child("DamageIcon")
	_block_icon = find_child("BlockIcon")

	# Label minimum sizes for font auto-shrinking
	card_label_min_sizes["Name"] = Vector2(CFConst.CARD_SIZE.x - 4, 19)
	card_label_min_sizes["Type"] = Vector2(CFConst.CARD_SIZE.x - 4, 13)
	card_label_min_sizes["Tags"] = Vector2(CFConst.CARD_SIZE.x - 4, 13)
	card_label_min_sizes["Abilities"] = Vector2(CFConst.CARD_SIZE.x - 4, 100)
	card_label_min_sizes["Cost"] = Vector2(14, 14)
	card_label_min_sizes["Damage"] = Vector2(14, 14)
	card_label_min_sizes["Block"] = Vector2(14, 14)

	for l in card_label_min_sizes:
		card_labels[l].custom_minimum_size = card_label_min_sizes[l]

	# Store original font sizes for auto-shrinking
	for label in card_labels:
		match label:
			"Cost", "Damage", "Block":
				original_font_sizes[label] = 14
			"Abilities":
				original_font_sizes[label] = 20
			_:
				original_font_sizes[label] = 14


# Override to toggle icon visibility when Damage/Block values change
func set_label_text(node: Label, value, scale: float = 1):
	super.set_label_text(node, value, scale)
	match node.name:
		"Damage":
			if _damage_icon:
				_damage_icon.visible = node.text != "" and node.text != "0"
		"Block":
			if _block_icon:
				_block_icon.visible = node.text != "" and node.text != "0"
