# Centralized audio manager for game sound effects.
#
# Preloads all SFX assets at _ready time and provides a single play_sfx() entry
# point.  Each call creates a new AudioStreamPlayer so multiple sounds can play
# concurrently; the player auto-frees when playback finishes.
extends Node

# --- Configurable volume offsets (dB) per sound category ---
const VOL_FX := 0.0        # default
const VOL_UI := -3.0       # UI sounds slightly softer
const VOL_HIT := 2.0       # combat hits slightly louder
const VOL_MUSIC := 0.0

# Map of sfx name -> AudioStream (loaded at _ready)
var _sfx: Dictionary = {}

# Audio bus for SFX output (set in _ready; falls back to "Master")
var _bus: String = "Master"


func _ready() -> void:
	_load_all_sfx()


func _load_all_sfx() -> void:
	var dir := "res://assets/audio/sfx/"
	var files := {
		"card_play":     dir + "card_play.ogg",
		"card_draw":     dir + "card_draw.ogg",
		"card_hover":    dir + "card_hover.wav",
		"hit_player":    dir + "hit_player.wav",
		"hit_enemy":     dir + "hit_enemy.wav",
		"enemy_attack":  dir + "enemy_attack.ogg",
		"turn_start":    dir + "turn_start.wav",
		"button_click":  dir + "button_click.wav",
		"block_gain":    dir + "block_gain.ogg",
		"victory":       dir + "victory.wav",
		"defeat":        dir + "defeat.wav",
		"reward_select": dir + "reward_select.wav",
	}
	for key in files:
		var stream := load(files[key])
		if stream:
			_sfx[key] = stream
		else:
			push_warning("AudioManager: failed to load %s" % files[key])


# Play a sound effect by name.
# Each call spawns a new AudioStreamPlayer for concurrent playback.
# The player auto-frees when playback finishes.
func play_sfx(name: String, volume_db: float = VOL_FX) -> void:
	if not _sfx.has(name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _sfx[name]
	player.volume_db = volume_db
	player.bus = _bus
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
