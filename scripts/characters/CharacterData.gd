class_name CharacterData
extends Resource

@export var display_name := "Opponent"
@export var age := 18
@export var personality := "balanced"
@export var portrait_path := ""
@export var expressions := {
	"neutral": "",
	"happy": "",
	"angry": "",
	"embarrassed": "",
	"shocked": "",
}
@export var clothing_layers: Array[String] = [
	"Accessories",
	"Shirt",
	"Skirt",
	"Bra",
]


func is_valid_for_game() -> bool:
	return age >= 18 and not display_name.strip_edges().is_empty()


func get_expression_path(expression_name: String) -> String:
	return expressions.get(expression_name, expressions.get("neutral", ""))
