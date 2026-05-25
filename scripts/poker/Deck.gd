class_name Deck
extends RefCounted

const CardDataScript := preload("res://scripts/poker/CardData.gd")

var cards: Array[CardData] = []


func _init(auto_build: bool = true) -> void:
	if auto_build:
		reset()


func reset() -> void:
	cards.clear()

	for suit in CardDataScript.SUITS:
		for rank in range(2, 15):
			cards.append(CardData.new(rank, suit))


func shuffle_deck() -> void:
	cards.shuffle()


func draw_card() -> CardData:
	if cards.is_empty():
		push_warning("Deck is empty. Returning a fallback card.")
		return CardData.new()

	return cards.pop_back()


func draw_cards(amount: int) -> Array[CardData]:
	var drawn_cards: Array[CardData] = []
	var safe_amount := maxi(amount, 0)

	for index in range(safe_amount):
		if cards.is_empty():
			break
		drawn_cards.append(draw_card())

	return drawn_cards


func remaining_count() -> int:
	return cards.size()


func rebuild_and_shuffle() -> void:
	reset()
	shuffle_deck()
