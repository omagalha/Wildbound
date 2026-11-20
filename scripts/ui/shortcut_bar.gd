class_name ShortcutBar
extends PanelContainer
## Barra de atalhos do PC. Exibe somente ações que já existem no InputMap.

const SHORTCUTS := [
	{"key": "M1", "label": "ATACAR", "action": &"attack"},
	{"key": "E", "label": "INTERAGIR", "action": &"interact"},
	{"key": "F", "label": "COMER", "action": &"eat"},
	{"key": "B", "label": "CONSTRUIR", "action": &"build_mode"},
	{"key": "C", "label": "FABRICAR", "action": &"crafting_menu"},
	{"key": "T", "label": "TOCHA", "action": &"toggle_torch"},
	{"key": "H", "label": "ATADURA", "action": &"use_bandage"},
]

const COLOR_SLOT := Color(0.075, 0.095, 0.08, 0.96)
const COLOR_SLOT_ACTIVE := Color(0.24, 0.34, 0.19, 0.98)
const COLOR_BORDER := Color(0.42, 0.55, 0.36, 0.8)
const COLOR_BORDER_ACTIVE := Color(1.0, 0.82, 0.34, 0.98)

@onready var _row: HBoxContainer = %ShortcutRow
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()


func _process(_delta: float) -> void:
	for i in _slots.size():
		var action: StringName = SHORTCUTS[i]["action"]
		var pressed := InputMap.has_action(action) and Input.is_action_pressed(action)
		var style := _slot_styles[i]
		style.bg_color = COLOR_SLOT_ACTIVE if pressed else COLOR_SLOT
		style.border_color = COLOR_BORDER_ACTIVE if pressed else COLOR_BORDER


func get_shortcut_count() -> int:
	return SHORTCUTS.size()


func get_shortcut_text(index: int) -> String:
	if index < 0 or index >= SHORTCUTS.size():
		return ""
	return "%s %s" % [SHORTCUTS[index]["key"], SHORTCUTS[index]["label"]]


func _build_slots() -> void:
	for child in _row.get_children():
		child.queue_free()
	_slots.clear()
	_slot_styles.clear()
	for shortcut in SHORTCUTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(94.0, 52.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_SLOT
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(6.0)
		slot.add_theme_stylebox_override("panel", style)
		_row.add_child(slot)
		_slots.append(slot)
		_slot_styles.append(style)

		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 1)
		slot.add_child(content)

		var key_label := Label.new()
		key_label.text = shortcut["key"]
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 15)
		key_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
		content.add_child(key_label)

		var action_label := Label.new()
		action_label.text = shortcut["label"]
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_label.add_theme_font_size_override("font_size", 10)
		action_label.add_theme_color_override("font_color", Color(0.82, 0.87, 0.78))
		content.add_child(action_label)
