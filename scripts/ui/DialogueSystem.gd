class_name DialogueSystem
extends RefCounted

var rng := RandomNumberGenerator.new()
var lines := {
	"round_start": [
		"Let's play a clean hand.",
		"Cards first, nerves later.",
	],
	"player_win": [
		"Nice hand. I will remember that.",
		"You got me this time.",
	],
	"opponent_win": [
		"That pot is mine.",
		"Looks like luck likes me today.",
	],
	"tie": [
		"Split pot. Fair enough.",
		"Nobody gets to brag about that one.",
	],
	"opponent_fold": [
		"I will let this one go.",
		"Not worth chasing.",
	],
	"player_fold": [
		"Careful play, huh?",
		"I will take the pot.",
	],
	"clothing_removed": [
		"Okay, that one stung.",
		"Rules are rules...",
	],
	"bluff": [
		"Maybe I have it. Maybe I do not.",
		"Feeling brave?",
	],
}


func _init() -> void:
	rng.randomize()


func get_line(context: String) -> String:
	var options: Array = lines.get(context, [])
	if options.is_empty():
		return ""

	return options[rng.randi_range(0, options.size() - 1)]


func set_lines(context: String, new_lines: Array[String]) -> void:
	lines[context] = new_lines


func add_line(context: String, line: String) -> void:
	if not lines.has(context):
		lines[context] = []
	lines[context].append(line)
