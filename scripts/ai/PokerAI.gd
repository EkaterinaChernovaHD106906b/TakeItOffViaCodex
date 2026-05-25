class_name PokerAI
extends RefCounted

const HandEvaluatorScript := preload("res://scripts/poker/HandEvaluator.gd")
const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")

var bluff_chance := 0.12
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func decide_action(
	hole_cards: Array[CardData],
	community_cards: Array[CardData],
	call_amount: int,
	can_check: bool,
	available_chips: int,
	phase: PokerRules.Phase
) -> Dictionary:
	var strength := estimate_strength(hole_cards, community_cards, phase)
	var wants_to_bluff := rng.randf() < bluff_chance

	if can_check:
		if strength >= 0.74 or wants_to_bluff:
			return _make_action(PokerRules.Action.RAISE, _raise_size(available_chips))
		return _make_action(PokerRules.Action.CHECK, 0)

	if call_amount >= available_chips:
		if strength >= 0.68 or wants_to_bluff:
			return _make_action(PokerRules.Action.ALL_IN, available_chips)
		return _make_action(PokerRules.Action.FOLD, 0)

	if strength < 0.28 and not wants_to_bluff:
		return _make_action(PokerRules.Action.FOLD, 0)

	if strength >= 0.72 or wants_to_bluff:
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
		var rank: int = result.get("rank", PokerRules.HandRank.HIGH_CARD)
		return clampf(float(rank) / float(PokerRules.HandRank.STRAIGHT_FLUSH), 0.0, 1.0)

	return _estimate_preflop_strength(hole_cards, phase)


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


func _raise_size(available_chips: int) -> int:
	return mini(PokerRulesScript.MIN_RAISE, maxi(available_chips, 0))


func _make_action(action: PokerRules.Action, amount: int) -> Dictionary:
	return {
		"action": action,
		"amount": maxi(amount, 0),
	}
