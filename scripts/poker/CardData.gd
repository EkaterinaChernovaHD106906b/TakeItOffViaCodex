class_name CardData
extends RefCounted

const SUITS := ["clubs", "diamonds", "hearts", "spades"]
const RANKS := {
	"2": 2,
	"3": 3,
	"4": 4,
	"5": 5,
	"6": 6,
	"7": 7,
	"8": 8,
	"9": 9,
	"T": 10,
	"J": 11,
	"Q": 12,
	"K": 13,
	"A": 14,
}

var rank: int
var suit: String


func _init(card_rank: int = 2, card_suit: String = "clubs") -> void:
	rank = clampi(card_rank, 2, 14)
	suit = card_suit if SUITS.has(card_suit) else "clubs"


static func from_code(code: String) -> CardData:
	var normalized := code.strip_edges().to_upper()
	if normalized.length() < 2:
		return CardData.new()

	var rank_text := normalized.substr(0, normalized.length() - 1)
	var suit_text := normalized.substr(normalized.length() - 1, 1)
	var parsed_rank: int = RANKS.get(rank_text, 2)
	var parsed_suit: String = _suit_from_short_code(suit_text)
	return CardData.new(parsed_rank, parsed_suit)


func get_rank_label() -> String:
	match rank:
		14:
			return "A"
		13:
			return "K"
		12:
			return "Q"
		11:
			return "J"
		10:
			return "T"
		_:
			return str(rank)


func get_suit_label() -> String:
	match suit:
		"clubs":
			return "C"
		"diamonds":
			return "D"
		"hearts":
			return "H"
		"spades":
			return "S"
		_:
			return "?"


func get_code() -> String:
	return "%s%s" % [get_rank_label(), get_suit_label()]


func duplicate_card() -> CardData:
	return CardData.new(rank, suit)


static func _suit_from_short_code(short_code: String) -> String:
	match short_code:
		"C":
			return "clubs"
		"D":
			return "diamonds"
		"H":
			return "hearts"
		"S":
			return "spades"
		_:
			return "clubs"
