extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and persists them to user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


## Select an ending entry without changing flags or starting dialogue.
## Exactly one reading flag must be true. Empty means the caller must resolve it.
## Missing trust/contact flags default to false, matching get_flag().
func get_ending_entry() -> String:
	var believes := bool(get_flag("believer", false))
	var doubts := bool(get_flag("skeptic", false))
	if believes == doubts:
		push_error("GameState: ending requires exactly one of believer or skeptic.")
		return ""
	var trusts_edith := bool(get_flag("trusted_edith", false))
	var contacted_tom := bool(get_flag("radioed_tom", false))
	var reading := "believer" if believes else "skeptic"
	var trust := "trust" if trusts_edith else "distrust"
	var entry := "ending_%s_%s" % [reading, trust]
	if contacted_tom:
		entry += "_radioed_tom"
	return entry


func new_game() -> void:
	flags.clear()
	current_scene = "res://scenes/game.tscn"
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	# Future-proofing: migrate older save versions here.
	current_scene = data.get("scene", "res://scenes/game.tscn")
	var loaded_flags: Variant = data.get("flags", {})
	flags = loaded_flags if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
