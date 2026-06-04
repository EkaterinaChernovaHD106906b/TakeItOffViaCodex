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

const MAX_PREFLOP_AI_RAISES := 5
const PREFLOP_CAPPED_CALL_STRENGTH := 0.58

var player := PokerPlayerState.new("You")
var opponent := PokerPlayerState.new("AI 1")
var opponents: Array[PokerPlayerState] = [
	opponent,
	PokerPlayerState.new("AI 2"),
]
var ais: Array[PokerAI] = [
	PokerAI.new(),
	PokerAI.new(),
]
var deck := Deck.new()
var community_cards: Array[CardData] = []
var phase := PokerRules.Phase.PRE_FLOP
var pot := 0
var current_bet := 0
var blinds_posted := false
var awaiting_player_response := false
var big_blind_opponent_index := 0
var preflop_ai_raise_count := 0
var rng := RandomNumberGenerator.new()


func setup_match(player_chips: int = PokerRules.STARTING_CHIPS, opponent_chips: int = PokerRules.STARTING_CHIPS) -> void:
	player = PokerPlayerStateScript.new("You", player_chips)
	opponents = [
		PokerPlayerStateScript.new("AI 1", opponent_chips),
		PokerPlayerStateScript.new("AI 2", opponent_chips),
	]
	opponent = opponents[0]
	start_new_round()


func start_new_round() -> void:
	rng.randomize()
	if _is_match_busted():
		_reset_match_chips()

	pot = 0
	current_bet = 0
	blinds_posted = false
	awaiting_player_response = false
	preflop_ai_raise_count = 0
	phase = PokerRules.Phase.PRE_FLOP
	community_cards.clear()
	player.reset_for_round()
	for ai_player in opponents:
		ai_player.reset_for_round()
	deck.rebuild_and_shuffle()

	player.receive_cards(deck.draw_cards(PokerRules.CARDS_PER_PLAYER))
	for ai_player in opponents:
		ai_player.receive_cards(deck.draw_cards(PokerRules.CARDS_PER_PLAYER))
	big_blind_opponent_index = rng.randi_range(0, opponents.size() - 1)

	round_started.emit(get_state())


func post_blinds() -> void:
	if blinds_posted or phase != PokerRules.Phase.PRE_FLOP:
		return

	pot += player.pay_chips(PokerRules.SMALL_BLIND)
	pot += opponents[big_blind_opponent_index].pay_chips(PokerRules.BIG_BLIND)
	current_bet = PokerRules.BIG_BLIND
	blinds_posted = true
	player_updated.emit(get_state())


func player_action(action: PokerRules.Action, raise_amount: int = PokerRules.MIN_RAISE) -> void:
	if phase == PokerRules.Phase.ROUND_OVER or not blinds_posted or player.is_all_in:
		return

	_apply_action(player, action, raise_amount)
	var was_answering_ai_raise := awaiting_player_response
	awaiting_player_response = false
	player_updated.emit(get_state())

	if _finish_if_folded():
		return
	if _finish_if_all_active_players_are_all_in():
		return
	if _finish_if_all_in_betting_is_closed():
		return

	if was_answering_ai_raise and action != PokerRules.Action.RAISE and action != PokerRules.Action.ALL_IN:
		_take_ai_turn(true)
		if _finish_if_folded():
			return
		if _finish_if_all_active_players_are_all_in():
			return
		if _finish_if_all_in_betting_is_closed():
			return
		if get_call_amount(player) > 0:
			awaiting_player_response = true
			player_updated.emit(get_state())
			return
		_advance_phase_or_showdown()
		return

	_take_ai_turn()

	if _finish_if_folded():
		return
	if _finish_if_all_active_players_are_all_in():
		return
	if _finish_if_all_in_betting_is_closed():
		return

	if player.is_all_in:
		_settle_unmatched_ai_bets_after_player_all_in()
		return

	if get_call_amount(player) > 0:
		awaiting_player_response = true
		player_updated.emit(get_state())
		return

	_advance_phase_or_showdown()


func _settle_unmatched_ai_bets_after_player_all_in() -> void:
	while _has_unmatched_ai_bets():
		_take_ai_turn(true)
		if _finish_if_folded():
			return
		if _finish_if_all_active_players_are_all_in():
			return
		if _finish_if_all_in_betting_is_closed():
			return

	if _finish_if_all_in_betting_is_closed():
		return

	_advance_phase_or_showdown()


func _has_unmatched_ai_bets() -> bool:
	for ai_player in opponents:
		if ai_player.has_folded or ai_player.is_all_in:
			continue
		if get_call_amount(ai_player) > 0:
			return true

	return false


func get_state() -> Dictionary:
	return {
		"phase": phase,
		"phase_name": PokerRulesScript.get_phase_name(phase),
		"pot": pot,
		"current_bet": current_bet,
		"blinds_posted": blinds_posted,
		"awaiting_player_response": awaiting_player_response,
		"big_blind_opponent": opponents[big_blind_opponent_index].display_name,
		"big_blind_opponent_index": big_blind_opponent_index,
		"community_cards": community_cards,
		"player": player.to_summary(),
		"opponent": opponents[0].to_summary(),
		"opponents": _get_opponent_summaries(),
		"call_amount": get_call_amount(player),
	}


func get_call_amount(actor: PokerPlayerState) -> int:
	return maxi(current_bet - actor.current_bet, 0)


func _take_ai_turn(only_unmatched: bool = false) -> void:
	for index in range(opponents.size()):
		var ai_player := opponents[index]
		if ai_player.has_folded or ai_player.is_all_in:
			continue

		var call_amount := get_call_amount(ai_player)
		if only_unmatched and call_amount == 0:
			continue

		var action := ais[index].decide_action(
			ai_player.hole_cards,
			community_cards,
			call_amount,
			call_amount == 0,
			ai_player.chips,
			phase
		)
		action = _normalize_ai_action(action, call_amount)
		action = _normalize_preflop_ai_action(ais[index], ai_player, action, call_amount)
		_apply_action(ai_player, action["action"], action["amount"])
		if phase == PokerRules.Phase.PRE_FLOP and action["action"] == PokerRules.Action.RAISE:
			preflop_ai_raise_count += 1
		action["actor"] = ai_player.display_name
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
		_deal_remaining_community_cards()
		_resolve_showdown("Player folded")
		return true

	var active_players := _get_active_players()
	if active_players.size() == 1:
		_finish_round(active_players[0], "%s is the last active player" % active_players[0].display_name)
		return true

	return false


func _finish_if_all_active_players_are_all_in() -> bool:
	var active_players := _get_active_players()
	if active_players.size() < 2:
		return false

	for active_player in active_players:
		if not active_player.is_all_in:
			return false

	_deal_remaining_community_cards()
	_resolve_showdown("All active players are all in")
	return true


func _finish_if_all_in_betting_is_closed() -> bool:
	var active_players := _get_active_players()
	var has_all_in_player := false

	for active_player in active_players:
		if active_player.is_all_in:
			has_all_in_player = true
		if get_call_amount(active_player) > 0:
			return false

	if not has_all_in_player:
		return false

	_deal_remaining_community_cards()
	_resolve_showdown("All-in betting is closed")
	return true


func _advance_phase_or_showdown() -> void:
	player.current_bet = 0
	for ai_player in opponents:
		ai_player.current_bet = 0
	current_bet = 0
	awaiting_player_response = false

	match phase:
		PokerRules.Phase.PRE_FLOP:
			preflop_ai_raise_count = 0
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


func _resolve_showdown(reason: String = "Showdown") -> void:
	var contenders := _get_active_players()
	var hand_results := {}
	var winners: Array[PokerPlayerState] = []
	var best_result := {}

	for contender in contenders:
		var cards: Array[CardData] = []
		cards.append_array(contender.hole_cards)
		cards.append_array(community_cards)
		var hand_result := HandEvaluatorScript.evaluate(cards)
		hand_result = HandEvaluatorScript.apply_personal_showdown_tiebreakers(hand_result, contender.hole_cards)
		hand_results[contender.display_name] = hand_result

		if winners.is_empty():
			winners.append(contender)
			best_result = hand_result
			continue

		var comparison := HandEvaluatorScript.compare_results(hand_result, best_result)
		if comparison > 0:
			winners = [contender]
			best_result = hand_result
		elif comparison == 0:
			winners.append(contender)

	var result := {
		"reason": reason,
		"hands": hand_results,
		"hole_cards": _get_revealed_hole_cards(),
		"showdown": true,
		"player_hand": hand_results.get(player.display_name, {}),
		"opponent_hand": hand_results.get(opponents[0].display_name, {}),
		"winner": "tie" if winners.size() > 1 else winners[0].display_name,
	}

	var split_pot := floori(float(pot) / float(winners.size()))
	var remainder := pot - (split_pot * winners.size())
	for index in range(winners.size()):
		winners[index].win_chips(split_pot + (remainder if index == 0 else 0))

	phase = PokerRules.Phase.ROUND_OVER
	showdown_finished.emit(result, get_state())
	round_finished.emit(result, get_state())


func _finish_round(winner: PokerPlayerState, reason: String) -> void:
	_deal_remaining_community_cards()
	winner.win_chips(pot)
	var result := {
		"reason": reason,
		"hole_cards": _get_revealed_hole_cards(),
		"showdown": false,
		"winner": winner.display_name,
	}
	phase = PokerRules.Phase.ROUND_OVER
	round_finished.emit(result, get_state())


func _deal_remaining_community_cards() -> void:
	var cards_to_deal := PokerRules.MAX_COMMUNITY_CARDS - community_cards.size()
	if cards_to_deal > 0:
		_deal_community_cards(cards_to_deal)


func _normalize_ai_action(action: Dictionary, call_amount: int) -> Dictionary:
	if not _any_player_all_in():
		return action

	if action.get("action", PokerRules.Action.CHECK) == PokerRules.Action.RAISE:
		return {
			"action": PokerRules.Action.CALL if call_amount > 0 else PokerRules.Action.CHECK,
			"amount": call_amount,
		}

	return action


func _normalize_preflop_ai_action(
	ai: PokerAI,
	ai_player: PokerPlayerState,
	action: Dictionary,
	call_amount: int
) -> Dictionary:
	if phase != PokerRules.Phase.PRE_FLOP:
		return action
	if preflop_ai_raise_count < MAX_PREFLOP_AI_RAISES:
		return action

	if call_amount == 0:
		return {
			"action": PokerRules.Action.CHECK,
			"amount": 0,
		}

	var strength := ai.estimate_strength(ai_player.hole_cards, community_cards, phase)
	if call_amount >= ai_player.chips:
		if strength >= 0.68:
			return {
				"action": PokerRules.Action.ALL_IN,
				"amount": ai_player.chips,
			}

		return {
			"action": PokerRules.Action.FOLD,
			"amount": 0,
		}

	if strength >= PREFLOP_CAPPED_CALL_STRENGTH:
		return {
			"action": PokerRules.Action.CALL,
			"amount": call_amount,
		}

	return {
		"action": PokerRules.Action.FOLD,
		"amount": 0,
	}


func _get_opponent_summaries() -> Array:
	var summaries := []
	for ai_player in opponents:
		summaries.append(ai_player.to_summary())
	return summaries


func _get_revealed_hole_cards() -> Dictionary:
	var revealed_cards := {
		player.display_name: _card_codes(player.hole_cards),
	}

	for ai_player in opponents:
		revealed_cards[ai_player.display_name] = _card_codes(ai_player.hole_cards)

	return revealed_cards


func _card_codes(cards: Array[CardData]) -> Array[String]:
	var codes: Array[String] = []

	for card in cards:
		codes.append(card.get_code())

	return codes


func _card_log_code(card: CardData) -> String:
	return "%s%s" % [card.get_rank_label(), _safe_suit_symbol(card.suit)]


func _safe_suit_symbol(suit: String) -> String:
	match suit:
		"clubs":
			return "♣"
		"diamonds":
			return "♦"
		"hearts":
			return "♥"
		"spades":
			return "♠"
		_:
			return "?"


func _suit_symbol(suit: String) -> String:
	match suit:
		"clubs":
			return "♣"
		"diamonds":
			return "♦"
		"hearts":
			return "♥"
		"spades":
			return "♠"
		_:
			return "?"


func _get_active_players() -> Array[PokerPlayerState]:
	var active_players: Array[PokerPlayerState] = []
	if not player.has_folded:
		active_players.append(player)
	for ai_player in opponents:
		if not ai_player.has_folded:
			active_players.append(ai_player)
	return active_players


func _get_first_active_opponent() -> PokerPlayerState:
	for ai_player in opponents:
		if not ai_player.has_folded:
			return ai_player

	return opponents[0]


func _any_player_all_in() -> bool:
	if player.is_all_in:
		return true
	for ai_player in opponents:
		if ai_player.is_all_in:
			return true
	return false


func _is_match_busted() -> bool:
	if player.chips <= 0:
		return true
	for ai_player in opponents:
		if ai_player.chips <= 0:
			return true
	return false


func _reset_match_chips() -> void:
	player.chips = PokerRules.STARTING_CHIPS
	for ai_player in opponents:
		ai_player.chips = PokerRules.STARTING_CHIPS
