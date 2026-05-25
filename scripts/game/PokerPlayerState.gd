class_name PokerPlayerState
extends RefCounted

const PokerRulesScript := preload("res://scripts/poker/PokerRules.gd")

var display_name := "Player"
var chips := PokerRulesScript.STARTING_CHIPS
var current_bet := 0
var has_folded := false
var is_all_in := false
var hole_cards: Array[CardData] = []


func _init(player_name: String = "Player", starting_chips: int = PokerRulesScript.STARTING_CHIPS) -> void:
	display_name = player_name
	chips = starting_chips


func reset_for_round() -> void:
	current_bet = 0
	has_folded = false
	is_all_in = false
	hole_cards.clear()


func receive_cards(cards: Array[CardData]) -> void:
	hole_cards = cards


func pay_chips(amount: int) -> int:
	var paid_amount := mini(maxi(amount, 0), chips)
	chips -= paid_amount
	current_bet += paid_amount
	is_all_in = chips == 0
	return paid_amount


func win_chips(amount: int) -> void:
	chips += maxi(amount, 0)


func fold() -> void:
	has_folded = true


func to_summary() -> Dictionary:
	return {
		"name": display_name,
		"chips": chips,
		"current_bet": current_bet,
		"has_folded": has_folded,
		"is_all_in": is_all_in,
		"hole_cards": hole_cards,
	}
