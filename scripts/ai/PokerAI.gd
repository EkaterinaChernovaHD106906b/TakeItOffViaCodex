class_name PokerAI
extends RefCounted

const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")

const PREFLOP_CHECK_RAISE_THRESHOLD := 0.86
const PREFLOP_CALL_FOLD_THRESHOLD := 0.36
const DEFAULT_CALL_FOLD_THRESHOLD := 0.28
const PERSONALITY_PROFILES := {
	"balanced": {
		"bluff_chance": 0.12,
		"preflop_call_fold_threshold": 0.36,
		"default_call_fold_threshold": 0.28,
		"raise_threshold_adjust": 0.0,
		"all_in_call_threshold": 0.68,
	},
	"cautious": {
		"bluff_chance": 0.06,
		"preflop_call_fold_threshold": 0.42,
		"default_call_fold_threshold": 0.31,
		"raise_threshold_adjust": 0.04,
		"all_in_call_threshold": 0.76,
	},
	"aggressive": {
		"bluff_chance": 0.18,
		"preflop_call_fold_threshold": 0.32,
		"default_call_fold_threshold": 0.25,
		"raise_threshold_adjust": -0.04,
		"all_in_call_threshold": 0.64,
	},
}

var bluff_chance := 0.12
var preflop_call_fold_threshold := PREFLOP_CALL_FOLD_THRESHOLD
var default_call_fold_threshold := DEFAULT_CALL_FOLD_THRESHOLD
var raise_threshold_adjust := 0.0
var all_in_call_threshold := 0.68
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func configure(profile_name: String) -> void:
	var profile: Dictionary = PERSONALITY_PROFILES.get(profile_name, PERSONALITY_PROFILES["balanced"])
	bluff_chance = profile.get("bluff_chance", bluff_chance)
	preflop_call_fold_threshold = profile.get("preflop_call_fold_threshold", preflop_call_fold_threshold)
	default_call_fold_threshold = profile.get("default_call_fold_threshold", default_call_fold_threshold)
	raise_threshold_adjust = profile.get("raise_threshold_adjust", raise_threshold_adjust)
	all_in_call_threshold = profile.get("all_in_call_threshold", all_in_call_threshold)


func decide_action(
	hole_cards: Array[CardData],
	community_cards: Array[CardData],
	call_amount: int,
	can_check: bool,
	available_chips: int,
	phase: PokerRules.Phase,
	pot: int = 0
) -> Dictionary:
	var strength := estimate_strength(hole_cards, community_cards, phase)
	var wants_to_bluff := _wants_to_bluff(call_amount, can_check, pot)
	var has_strong_made_hand := strength >= _strong_made_hand_threshold(phase)

	if _should_force_turn_river_all_in(hole_cards, community_cards, phase, available_chips):
		return _make_action(PokerRules.Action.ALL_IN, available_chips)

	if can_check:
		if phase == PokerRules.Phase.PRE_FLOP:
			if strength >= PREFLOP_CHECK_RAISE_THRESHOLD + raise_threshold_adjust or wants_to_bluff:
				return _make_action(PokerRules.Action.RAISE, _raise_size(available_chips))
			return _make_action(PokerRules.Action.CHECK, 0)
		if has_strong_made_hand or wants_to_bluff:
			return _make_action(PokerRules.Action.RAISE, _raise_size(available_chips))
		return _make_action(PokerRules.Action.CHECK, 0)

	if call_amount >= available_chips:
		if strength >= all_in_call_threshold or wants_to_bluff:
			return _make_action(PokerRules.Action.ALL_IN, available_chips)
		return _make_action(PokerRules.Action.FOLD, 0)

	if strength < _call_fold_threshold(phase, call_amount, pot) and not wants_to_bluff:
		return _make_action(PokerRules.Action.FOLD, 0)

	if has_strong_made_hand or wants_to_bluff:
		return _make_action(PokerRules.Action.RAISE, _raise_size(available_chips))

	return _make_action(PokerRules.Action.CALL, call_amount)


func estimate_strength(
	hole_cards: Array[CardData],
	community_cards: Array[CardData],
	phase: PokerRules.Phase
) -> float:
	if hole_cards.size() + community_cards.size() >= 5:
		var all_cards: Array[CardData] = []
		all_cards.append_array(hole_cards)
		all_cards.append_array(community_cards)
		var result := HandEvaluatorScript.evaluate(all_cards)
		return _made_hand_strength(result, phase)

	return _estimate_preflop_strength(hole_cards, phase)


func _should_force_turn_river_all_in(
	hole_cards: Array[CardData],
	community_cards: Array[CardData],
	phase: PokerRules.Phase,
	available_chips: int
) -> bool:
	if available_chips <= 0:
		return false
	if phase != PokerRules.Phase.TURN and phase != PokerRules.Phase.RIVER:
		return false
	if hole_cards.size() + community_cards.size() < 5:
		return false

	var all_cards: Array[CardData] = []
	all_cards.append_array(hole_cards)
	all_cards.append_array(community_cards)
	var result := HandEvaluatorScript.evaluate(all_cards)
	var rank: int = result.get("rank", PokerRules.HandRank.HIGH_CARD)
	return rank >= PokerRules.HandRank.STRAIGHT


func _estimate_preflop_strength(hole_cards: Array[CardData], phase: PokerRules.Phase) -> float:
	if hole_cards.size() < 2:
		return 0.0

	var first := hole_cards[0]
	var second := hole_cards[1]
	var high_rank := maxi(first.rank, second.rank)
	var low_rank := mini(first.rank, second.rank)
	var strength := float(high_rank + low_rank) / 28.0

	if first.rank == second.rank:
		strength += 0.25
	if first.suit == second.suit:
		strength += 0.08
	if abs(first.rank - second.rank) == 1:
		strength += 0.06
	if phase == PokerRules.Phase.PRE_FLOP and high_rank >= 13:
		strength += 0.05

	return clampf(strength, 0.0, 1.0)


func _made_hand_strength(result: Dictionary, phase: PokerRules.Phase) -> float:
	var rank: int = result.get("rank", PokerRules.HandRank.HIGH_CARD)
	var tiebreakers: Array = result.get("tiebreakers", [])
	var top_value := 0.0

	if not tiebreakers.is_empty():
		top_value = float(tiebreakers[0]) / 14.0

	match rank:
		PokerRules.HandRank.STRAIGHT_FLUSH:
			return 1.0
		PokerRules.HandRank.FOUR_OF_A_KIND:
			return 0.97
		PokerRules.HandRank.FULL_HOUSE:
			return 0.93
		PokerRules.HandRank.FLUSH:
			return 0.87 + top_value * 0.03
		PokerRules.HandRank.STRAIGHT:
			return 0.82 + top_value * 0.03
		PokerRules.HandRank.THREE_OF_A_KIND:
			return 0.76 + top_value * 0.04
		PokerRules.HandRank.TWO_PAIR:
			return 0.62 + top_value * 0.06
		PokerRules.HandRank.ONE_PAIR:
			return 0.34 + top_value * 0.14
		_:
			return 0.08 + top_value * 0.18


func _strong_made_hand_threshold(phase: PokerRules.Phase) -> float:
	match phase:
		PokerRules.Phase.RIVER:
			return clampf(0.70 + raise_threshold_adjust, 0.0, 1.0)
		PokerRules.Phase.TURN:
			return clampf(0.73 + raise_threshold_adjust, 0.0, 1.0)
		PokerRules.Phase.FLOP:
			return clampf(0.76 + raise_threshold_adjust, 0.0, 1.0)
		_:
			return clampf(0.72 + raise_threshold_adjust, 0.0, 1.0)


func _call_fold_threshold(phase: PokerRules.Phase, call_amount: int, pot: int) -> float:
	var threshold := preflop_call_fold_threshold if phase == PokerRules.Phase.PRE_FLOP else default_call_fold_threshold
	var odds := _pot_odds(call_amount, pot)
	if odds <= 0.08:
		threshold -= 0.08
	elif odds >= 0.35:
		threshold += 0.10
	elif odds >= 0.22:
		threshold += 0.04

	return clampf(threshold, 0.05, 0.9)


func _wants_to_bluff(call_amount: int, can_check: bool, pot: int) -> bool:
	var adjusted_bluff_chance := bluff_chance
	if can_check:
		adjusted_bluff_chance *= 1.25
	elif _pot_odds(call_amount, pot) >= 0.35:
		adjusted_bluff_chance *= 0.35

	return rng.randf() < adjusted_bluff_chance


func _pot_odds(call_amount: int, pot: int) -> float:
	if call_amount <= 0:
		return 0.0

	return float(call_amount) / float(maxi(pot + call_amount, 1))


func _raise_size(available_chips: int) -> int:
	return mini(PokerRulesScript.MIN_RAISE, maxi(available_chips, 0))


func _make_action(action: PokerRules.Action, amount: int) -> Dictionary:
	return {
		"action": action,
		"amount": maxi(amount, 0),
	}
