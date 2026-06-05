# Shared data model for combat participants (player and enemy).
#
# Encapsulates HP, block, strength, and status effects (vulnerable, weak).
# Emits signals when any value changes, allowing UI to update reactively.
#
# Used by both the player and the (M4 placeholder) enemy.
# M5 will expand enemies with intent display and AI patterns.
# class_name CombatEntity  # removed: causes load-order issues with Godot parser
extends RefCounted

signal hp_changed(current, maximum)
signal block_changed(new_block)
signal stats_changed()

var display_name: String = ""
var hp: int = 0
var max_hp: int = 0
var block: int = 0
var strength: int = 0
var vulnerable: int = 0  # turns remaining
var weak: int = 0        # turns remaining


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
func tick_status() -> void:
	if vulnerable > 0:
		vulnerable -= 1
	if weak > 0:
		weak -= 1
	stats_changed.emit()


# Reset block to 0. Called at the start of the entity's turn (before draw).
func reset_block() -> void:
	block = 0
	block_changed.emit(0)


# Reset temporary combat status (vulnerable, weak, block).
# Strength persists across combats (Power cards). Called when setting up
# a new encounter in a multi-fight run.
func reset_combat_status() -> void:
	vulnerable = 0
	weak = 0
	block = 0
	block_changed.emit(0)
	stats_changed.emit()
