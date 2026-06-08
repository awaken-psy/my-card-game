# Shared data model for combat participants (player and enemy).
#
# Encapsulates HP, block, strength, and status effects (vulnerable, weak, poison, thorns).
# Emits signals when any value changes, allowing UI to update reactively.
#
# Used by both the player and the enemy.
extends RefCounted

signal hp_changed(current, maximum)
signal block_changed(new_block)
signal stats_changed()
signal poison_damaged(entity, amount)
signal healed(entity, amount)
signal thorns_triggered(source, damage)

var display_name: String = ""
var hp: int = 0
var max_hp: int = 0
var block: int = 0
var strength: int = 0
var vulnerable: int = 0  # turns remaining
var weak: int = 0        # turns remaining
var poison: int = 0      # stacks remaining
var thorns: int = 0      # damage returned to attacker this turn


func _init(entity_name: String, max_health: int, initial_hp: int = -1) -> void:
	display_name = entity_name
	max_hp = max_health
	hp = initial_hp if initial_hp > 0 else max_health


# Add to block pool. Block absorbs incoming damage before HP.
func gain_block(amount: int) -> void:
	block += amount
	block_changed.emit(block)
	stats_changed.emit()


# Apply raw (already-calculated) damage to this entity.
# Block absorbs first; remaining goes to HP.
# Returns the actual HP lost.
func take_damage(damage: int) -> int:
	var blocked := mini(block, damage)
	block -= blocked
	var actual := damage - blocked
	hp -= actual
	block_changed.emit(block)
	hp_changed.emit(hp, max_hp)
	return actual


# Direct HP loss (bypasses block, e.g. Bloodletting).
func lose_hp(amount: int) -> void:
	hp -= amount
	hp_changed.emit(hp, max_hp)
	stats_changed.emit()


# Restore HP (capped at max_hp). Used by heal effects.
func heal(amount: int) -> void:
	var old_hp := hp
	hp = mini(hp + amount, max_hp)
	if hp != old_hp:
		healed.emit(self, hp - old_hp)
		hp_changed.emit(hp, max_hp)
		stats_changed.emit()


# Add poison stacks to this entity.
func add_poison(amount: int) -> void:
	poison += amount
	stats_changed.emit()


# Add thorns — damage returned to attacker when hit. Cleared each turn.
func add_thorns(amount: int) -> void:
	thorns += amount
	stats_changed.emit()


func is_dead() -> bool:
	return hp <= 0


func add_strength(amount: int) -> void:
	strength += amount
	stats_changed.emit()


func add_vulnerable(amount: int) -> void:
	vulnerable += amount
	stats_changed.emit()


func add_weak(amount: int) -> void:
	weak += amount
	stats_changed.emit()


# Decrement status durations by 1. Called at the start of this entity's turn.
# Poison: deals damage equal to stacks, then decreases by 1. Bypasses block.
# Thorns: cleared at the start of this entity's turn.
func tick_status() -> void:
	if vulnerable > 0:
		vulnerable -= 1
	if weak > 0:
		weak -= 1
	if poison > 0:
		var dmg: int = poison
		hp -= dmg
		poison -= 1
		hp_changed.emit(hp, max_hp)
		poison_damaged.emit(self, dmg)
	# Thorns clears at the start of this entity's turn (before they act)
	thorns = 0
	stats_changed.emit()


# Reset block to 0. Called at the start of the entity's turn (before draw).
func reset_block() -> void:
	block = 0
	block_changed.emit(0)


# Reset temporary combat status (vulnerable, weak, poison, thorns, block).
# Strength persists across combats (Power cards). Called when setting up
# a new encounter in a multi-fight run.
func reset_combat_status() -> void:
	vulnerable = 0
	weak = 0
	poison = 0
	thorns = 0
	block = 0
	block_changed.emit(0)
	stats_changed.emit()
