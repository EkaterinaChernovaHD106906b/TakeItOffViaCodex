class_name ClothingSystem
extends Node

signal layer_removed(layer_name: String, remaining_layers: int)
signal clothing_reset

@export var layer_names: Array[String] = [
	"Accessories",
	"Shirt",
	"Skirt",
	"Bra",
]

var removed_layers: Array[String] = []


func reset_clothing() -> void:
	removed_layers.clear()

	for layer_name in layer_names:
		var layer := get_node_or_null(NodePath(layer_name))
		if layer is CanvasItem:
			layer.visible = true

	clothing_reset.emit()


func remove_next_layer() -> String:
	for layer_name in layer_names:
		if removed_layers.has(layer_name):
			continue

		var layer := get_node_or_null(NodePath(layer_name))
		if layer is CanvasItem:
			layer.visible = false

		removed_layers.append(layer_name)
		layer_removed.emit(layer_name, get_remaining_layer_count())
		return layer_name

	return ""


func remove_layers_for_chip_loss(previous_chips: int, current_chips: int, chip_step: int = 250) -> Array[String]:
	var removed_now: Array[String] = []
	var safe_step := maxi(chip_step, 1)
	var previous_threshold := floori(float(previous_chips) / float(safe_step))
	var current_threshold := floori(float(current_chips) / float(safe_step))
	var layers_to_remove := maxi(previous_threshold - current_threshold, 0)

	for index in range(layers_to_remove):
		var layer_name := remove_next_layer()
		if layer_name.is_empty():
			break
		removed_now.append(layer_name)

	return removed_now


func get_remaining_layer_count() -> int:
	return maxi(layer_names.size() - removed_layers.size(), 0)


func is_fully_removed() -> bool:
	return get_remaining_layer_count() == 0
