class_name PokerRoundManager
extends Node

signal round_started(state: Dictionary)
signal phase_changed(phase: PokerRules.Phase, state: Dictionary)
signal player_updated(state: Dictionary)
signal ai_acted(action: Dictionary, state: Dictionary)
signal showdown_finished(result: Dictionary, state: Dictionary)
signal round_finished(result: Dictionary, state: Dictionary)

const DeckScript := preload("res://scripts/poker/Deck.gd")
const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")
const PokerAIScript := preload("res://scripts/ai/PokerAI.gd")
const PokerPlayerStateScript := preload("res://scripts/game/PokerPlayerState.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")

var player := PokerPlayerState.new("You")
var opponent := PokerPlayerState.new("Opponent")
var ai := PokerAI.new()
var deck := Deck.new()
var community_cards: Array[CardData] = []
var phase := PokerRules.Phase.PRE_FLOP
var pot := 0
var current_bet := 0


func setup_match(player_chips: int = PokerRules.STARTING_CHIPS, opponent_chips: int = PokerRules.STARTING_CHIPS) -> void:
	player = PokerPlayerStateScript.new("You", player_chips)
	opponent = PokerPlayerStateScript.new("Opponent", opponent_chips)
	start_new_round()


func start_new_round() -> void:
	pot = 0
	current_bet = 0
	phase = PokerRules.Phase.PRE_FLOP
	community_cards.clear()
	player.reset_for_round()
	opponent.reset_for_round()
	deck.rebuild_and_shuffle()

	player.receive_cards(deck.draw_cards(PokerRules.CARDS_PER_PLAYER))
	opponent.receive_cards(deck.draw_cards(PokerRules.CARDS_PER_PLAYER))
	_post_blinds()

	round_started.emit(get_state())


func player_action(action: PokerRules.Action, raise_amount: int = PokerRules.MIN_RAISE) -> void:
	if phase == PokerRules.Phase.ROUND_OVER:
		return

	_apply_action(player, action, raise_amount)
	player_updated.emit(get_state())

	if _finish_if_folded():
		return

	_take_ai_turn()

	if _finish_if_folded():
		return

	_advance_phase_or_showdown()


func get_state() -> Dictionary:
	return {
		"phase": phase,
		"phase_name": PokerRulesScript.get_phase_name(phase),
		"pot": pot,
		"current_bet": current_bet,
		"community_cards": community_cards,
		"player": player.to_summary(),
		"opponent": opponent.to_summary(),
		"call_amount": get_call_amount(player),
	}


func get_call_amount(actor: PokerPlayerState) -> int:
	return maxi(current_bet - actor.current_bet, 0)


func _post_blinds() -> void:
	pot += player.pay_chips(PokerRules.SMALL_BLIND)
	pot += opponent.pay_chips(PokerRules.BIG_BLIND)
	current_bet = PokerRules.BIG_BLIND


func _take_ai_turn() -> void:
	var call_amount := get_call_amount(opponent)
	var action := ai.decide_action(
		opponent.hole_cards,
		community_cards,
		call_amount,
		call_amount == 0,
		opponent.chips,
		phase
	)
	_apply_action(opponent, action["action"], action["amount"])
	ai_acted.emit(action, get_state())


func _apply_action(actor: PokerPlayerState, action: PokerRules.Action, amount: int) -> void:
	match action:
		PokerRules.Action.FOLD:
			actor.fold()
		PokerRules.Action.CHECK:
			pass
		PokerRules.Action.CALL:
			pot += actor.pay_chips(get_call_amount(actor))
		PokerRules.Action.RAISE:
			var call_amount := get_call_amount(actor)
			var raise_amount := maxi(amount, PokerRules.MIN_RAISE)
			pot += actor.pay_chips(call_amount + raise_amount)
			current_bet = maxi(current_bet, actor.current_bet)
		PokerRules.Action.ALL_IN:
			pot += actor.pay_chips(actor.chips)
			current_bet = maxi(current_bet, actor.current_bet)


func _finish_if_folded() -> bool:
	if player.has_folded:
		_finish_round(opponent, "Player folded")
		return true
	if opponent.has_folded:
		_finish_round(player, "Opponent folded")
		return true
	return false


func _advance_phase_or_showdown() -> void:
	player.current_bet = 0
	opponent.current_bet = 0
	current_bet = 0

	match phase:
		PokerRules.Phase.PRE_FLOP:
			_deal_community_cards(3)
			phase = PokerRules.Phase.FLOP
			phase_changed.emit(phase, get_state())
		PokerRules.Phase.FLOP:
			_deal_community_cards(1)
			phase = PokerRules.Phase.TURN
			phase_changed.emit(phase, get_state())
		PokerRules.Phase.TURN:
			_deal_community_cards(1)
			phase = PokerRules.Phase.RIVER
			phase_changed.emit(phase, get_state())
		PokerRules.Phase.RIVER:
			phase = PokerRules.Phase.SHOWDOWN
			_resolve_showdown()


func _deal_community_cards(amount: int) -> void:
	community_cards.append_array(deck.draw_cards(amount))


func _resolve_showdown() -> void:
	var player_cards: Array[CardData] = []
	var opponent_cards: Array[CardData] = []
	player_cards.append_array(player.hole_cards)
	player_cards.append_array(community_cards)
	opponent_cards.append_array(opponent.hole_cards)
	opponent_cards.append_array(community_cards)

	var player_result := HandEvaluatorScript.evaluate(player_cards)
	var opponent_result := HandEvaluatorScript.evaluate(opponent_cards)
	var comparison := HandEvaluatorScript.compare_results(player_result, opponent_result)
	var result := {
		"reason": "Showdown",
		"player_hand": player_result,
		"opponent_hand": opponent_result,
		"winner": "tie",
	}

	if comparison > 0:
		player.win_chips(pot)
		result["winner"] = "player"
	elif comparison < 0:
		opponent.win_chips(pot)
		result["winner"] = "opponent"
	else:
		var split_pot := floori(float(pot) / 2.0)
		player.win_chips(split_pot)
		opponent.win_chips(pot - split_pot)

	showdown_finished.emit(result, get_state())
	phase = PokerRules.Phase.ROUND_OVER
	round_finished.emit(result, get_state())


func _finish_round(winner: PokerPlayerState, reason: String) -> void:
	winner.win_chips(pot)
	var result := {
		"reason": reason,
		"winner": "player" if winner == player else "opponent",
	}
	phase = PokerRules.Phase.ROUND_OVER
	round_finished.emit(result, get_state())
