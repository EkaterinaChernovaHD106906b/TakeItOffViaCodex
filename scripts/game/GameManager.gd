class_name GameManager
extends Node

signal match_started(state: Dictionary)
signal match_restarted(state: Dictionary)
signal dialogue_requested(line: String)

const DialogueSystemScript := preload("res://scripts/ui/DialogueSystem.gd")
const PokerRoundManagerScript := preload("res://scripts/game/PokerRoundManager.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")

@export var clothing_system_path: NodePath
@export var opponent_clothing_loss_step := 250

var round_manager: PokerRoundManager
var dialogue := DialogueSystem.new()
var last_opponent_chips := PokerRules.STARTING_CHIPS


func _ready() -> void:
	_ensure_round_manager()


func start_match() -> void:
	_ensure_round_manager()
	last_opponent_chips = PokerRules.STARTING_CHIPS
	var clothing_system := _get_clothing_system()
	if clothing_system != null:
		clothing_system.reset_clothing()

	round_manager.setup_match()
	dialogue_requested.emit(dialogue.get_line("round_start"))
	match_started.emit(round_manager.get_state())


func restart_match() -> void:
	start_match()
	match_restarted.emit(round_manager.get_state())


func choose_fold() -> void:
	round_manager.player_action(PokerRules.Action.FOLD)


func choose_check() -> void:
	round_manager.player_action(PokerRules.Action.CHECK)


func choose_call() -> void:
	round_manager.player_action(PokerRules.Action.CALL)


func choose_raise(amount: int = PokerRules.MIN_RAISE) -> void:
	round_manager.player_action(PokerRules.Action.RAISE, amount)


func choose_all_in() -> void:
	round_manager.player_action(PokerRules.Action.ALL_IN)


func _ensure_round_manager() -> void:
	if round_manager != null:
		return

	round_manager = PokerRoundManagerScript.new()
	add_child(round_manager)
	round_manager.round_finished.connect(_on_round_finished)


func _on_round_finished(result: Dictionary, state: Dictionary) -> void:
	var winner: String = result.get("winner", "tie")

	match winner:
		"player":
			dialogue_requested.emit(dialogue.get_line("player_win"))
		"opponent":
			dialogue_requested.emit(dialogue.get_line("opponent_win"))
		_:
			dialogue_requested.emit(dialogue.get_line("tie"))

	_apply_opponent_clothing_loss(state)


func _apply_opponent_clothing_loss(state: Dictionary) -> void:
	var opponent_state: Dictionary = state.get("opponent", {})
	var current_chips: int = opponent_state.get("chips", last_opponent_chips)
	var clothing_system := _get_clothing_system()

	if clothing_system != null:
		var removed_layers := clothing_system.remove_layers_for_chip_loss(
			last_opponent_chips,
			current_chips,
			opponent_clothing_loss_step
		)
		if not removed_layers.is_empty():
			dialogue_requested.emit(dialogue.get_line("clothing_removed"))

	last_opponent_chips = current_chips


func _get_clothing_system() -> ClothingSystem:
	if clothing_system_path == NodePath(""):
		return null

	var node := get_node_or_null(clothing_system_path)
	return node as ClothingSystem
