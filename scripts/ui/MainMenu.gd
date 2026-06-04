extends Control

signal resume_requested

const GAME_SCENE_PATH := "res://scenes/Game.tscn"
const MENU_BUTTON_MIN_SIZE := Vector2(560, 64)
const MENU_BUTTON_FONT_SIZE := 108
const CREDITS_POPUP_SIZE := Vector2i(1366, 768)
const CREDITS_BACKGROUND_PATH := "res://assets/background2.png"
const CREDITS_FONT_PATH := "res://fonts/Lumierepolis-Regular.otf"
const CREDITS_DIALOG_TITLE := "Developers Info"
const CREDITS_DIALOG_TEXT := "Developer - easy going\n\nAssets - https://spicylyon.itch.io, GPT\n\nMusic - Suno"
const POKER_RULES_DIALOG_TITLE := "Poker Rules"
const POKER_RULES_DIALOG_TEXT := "Texas Hold'em Rules

Each player gets 2 private cards.
5 community cards are placed on the table.
Make the best 5-card poker hand using any combination of your cards and the community cards.
Betting rounds:
Pre-Flop
Flop (3 cards)
Turn (1 card)
River (1 card)
The best hand wins the pot.

Hand Rankings (Highest → Lowest)

Royal Flush – A, K, Q, J, 10, same suit
Straight Flush – five consecutive cards, same suit
Four of a Kind – four cards of the same rank
Full House – three of a kind + a pair
Flush – five cards of the same suit
Straight – five consecutive cards
Three of a Kind – three cards of the same rank
Two Pair – two different pairs
One Pair – two cards of the same rank
High Card – highest card wins"

@onready var start_button: Button = %StartButton
@onready var poker_rules_button: Button = %PokerRulesButton
@onready var credits_button: Button = %CreditsButton
@onready var exit_button: Button = %ExitButton

var credits_popup: PopupPanel
var poker_rules_popup: PopupPanel
var resume_mode := false

func _ready() -> void:
	_setup_credits_popup()
	_setup_poker_rules_popup()
	_connect_buttons()
	_style_menu_buttons()
	_update_start_button_text()


func _setup_credits_popup() -> void:
	credits_popup = PopupPanel.new()
	credits_popup.title = CREDITS_DIALOG_TITLE
	add_child(credits_popup)
	var credits_font := load(CREDITS_FONT_PATH)

	var content := Control.new()
	content.custom_minimum_size = CREDITS_POPUP_SIZE
	credits_popup.add_child(content)

	var background := TextureRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = load(CREDITS_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.025, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(shade)

	var text_layout := VBoxContainer.new()
	text_layout.offset_left = 220
	text_layout.offset_top = 0
	text_layout.offset_right = CREDITS_POPUP_SIZE.x - 220
	text_layout.offset_bottom = CREDITS_POPUP_SIZE.y
	text_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	text_layout.add_theme_constant_override("separation", 18)
	content.add_child(text_layout)

	var title_label := Label.new()
	title_label.text = CREDITS_DIALOG_TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", credits_font)
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.87, 0.52))
	text_layout.add_child(title_label)

	var credits_label := Label.new()
	credits_label.text = CREDITS_DIALOG_TEXT
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_label.add_theme_font_override("font", credits_font)
	credits_label.add_theme_font_size_override("font_size", 28)
	credits_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	text_layout.add_child(credits_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.offset_left = CREDITS_POPUP_SIZE.x - 60
	close_button.offset_top = 16
	close_button.offset_right = CREDITS_POPUP_SIZE.x - 16
	close_button.offset_bottom = 60
	close_button.add_theme_font_override("font", credits_font)
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(func() -> void: credits_popup.hide())
	content.add_child(close_button)


func _setup_poker_rules_popup() -> void:
	poker_rules_popup = PopupPanel.new()
	poker_rules_popup.title = POKER_RULES_DIALOG_TITLE
	add_child(poker_rules_popup)
	var rules_font := load(CREDITS_FONT_PATH)

	var content := Control.new()
	content.custom_minimum_size = CREDITS_POPUP_SIZE
	poker_rules_popup.add_child(content)

	var background := TextureRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.texture = load(CREDITS_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.025, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(shade)

	var text_layout := VBoxContainer.new()
	text_layout.offset_left = 220
	text_layout.offset_top = 42
	text_layout.offset_right = CREDITS_POPUP_SIZE.x - 220
	text_layout.offset_bottom = CREDITS_POPUP_SIZE.y - 42
	text_layout.add_theme_constant_override("separation", 18)
	content.add_child(text_layout)

	var title_label := Label.new()
	title_label.text = POKER_RULES_DIALOG_TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", rules_font)
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.87, 0.52))
	text_layout.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_layout.add_child(scroll)

	var rules_label := Label.new()
	rules_label.text = POKER_RULES_DIALOG_TEXT
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_label.add_theme_font_override("font", rules_font)
	rules_label.add_theme_font_size_override("font_size", 28)
	rules_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	scroll.add_child(rules_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.offset_left = CREDITS_POPUP_SIZE.x - 60
	close_button.offset_top = 16
	close_button.offset_right = CREDITS_POPUP_SIZE.x - 16
	close_button.offset_bottom = 60
	close_button.add_theme_font_override("font", rules_font)
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(func() -> void: poker_rules_popup.hide())
	content.add_child(close_button)


func _connect_buttons() -> void:
	start_button.pressed.connect(_start_game)
	poker_rules_button.pressed.connect(_open_poker_rules)
	credits_button.pressed.connect(_open_credits)
	exit_button.pressed.connect(_exit_game)


func _style_menu_buttons() -> void:
	for button in [
		start_button,
		poker_rules_button,
		credits_button,
		exit_button,
	]:
		_style_casino_button(button)


func _style_casino_button(button: Button) -> void:
	button.custom_minimum_size = MENU_BUTTON_MIN_SIZE
	button.add_theme_font_size_override("font_size", MENU_BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", Color(0.98, 0.91, 0.67))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.42))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.48, 0.42))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.05, 0.06), Color(0.76, 0.56, 0.22), 2))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.2, 0.07, 0.08), Color(0.98, 0.76, 0.34), 2))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.07, 0.03, 0.04), Color(1.0, 0.66, 0.22), 3))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _start_game() -> void:
	if resume_mode:
		start_button.release_focus()
		resume_requested.emit()
		return

	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func set_resume_mode(enabled: bool) -> void:
	resume_mode = enabled
	if start_button != null:
		_update_start_button_text()


func _update_start_button_text() -> void:
	start_button.text = "RESUME" if resume_mode else "PLAY"


func _open_credits() -> void:
	credits_button.release_focus()
	credits_popup.popup_centered(CREDITS_POPUP_SIZE)


func _open_poker_rules() -> void:
	poker_rules_button.release_focus()
	poker_rules_popup.popup_centered(CREDITS_POPUP_SIZE)


func _exit_game() -> void:
	get_tree().quit()
