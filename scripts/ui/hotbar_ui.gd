class_name HotbarUI
extends VBoxContainer
## Hotbar na parte de baixo da tela: 9 espaços com ícone, número da tecla e
## quantidade. O espaço do item na mão fica dourado e maior; a tocha acesa
## brilha. Ao trocar de item, o nome aparece por um instante acima da barra.
## Só mostra o estado do PlayerEquipment; nunca muda nada.

const SLOT_SIZE := Vector2(60, 60)
const COLOR_SLOT := Color(0.05, 0.065, 0.055, 0.92)
const COLOR_BORDER := Color(0.42, 0.55, 0.36, 0.7)
const COLOR_SELECTED := Color(1.0, 0.82, 0.34, 1.0)
const COLOR_LIT := Color(1.0, 0.55, 0.15, 1.0)

var equipment: PlayerEquipment
var _slots: Array[Dictionary] = []  # {panel, style, icon, key, count}
var _name_label: Label
var _name_tween: Tween
var _last_selected := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	_build()


func bind_equipment(value: PlayerEquipment) -> void:
	equipment = value
	if equipment == null:
		return
	equipment.hotbar_changed.connect(refresh)
	equipment.held_changed.connect(func(_id): _flash_name())
	if equipment.inventory != null:
		equipment.inventory.changed.connect(refresh)
	refresh()


func get_slot_count() -> int:
	return _slots.size()


## "1 improvised_club" etc. (para testes).
func get_slot_item(index: int) -> StringName:
	return (_slots[index]["icon"] as ItemIcon).item_id if index >= 0 and index < _slots.size() else &""


func get_selected_index() -> int:
	return equipment.selected if equipment != null else -1


func get_name_text() -> String:
	return _name_label.text


func refresh() -> void:
	if equipment == null:
		return
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var id: StringName = equipment.slots[i] if i < equipment.slots.size() else &""
		var icon := slot["icon"] as ItemIcon
		icon.item_id = id
		var count := 0
		if id != &"" and id != PlayerEquipment.CLUB and equipment.inventory != null:
			count = equipment.inventory.count(id)
		(slot["count"] as Label).text = str(count) if count > 1 else ""
		var is_selected := i == equipment.selected
		var lit := id == PlayerEquipment.TORCH and equipment.torch_lit
		var style := slot["style"] as StyleBoxFlat
		style.border_color = COLOR_SELECTED if is_selected else (COLOR_LIT if lit else COLOR_BORDER)
		style.set_border_width_all(3 if is_selected or lit else 1)
		style.bg_color = COLOR_SLOT.lightened(0.12) if is_selected else COLOR_SLOT
		var panel := slot["panel"] as Control
		panel.scale = Vector2.ONE * (1.12 if is_selected else 1.0)
		panel.modulate = Color.WHITE if id != &"" else Color(1, 1, 1, 0.55)
		(slot["key"] as Label).add_theme_color_override("font_color", COLOR_SELECTED if is_selected else Color(0.85, 0.88, 0.8))
	if equipment.selected != _last_selected:
		_last_selected = equipment.selected


func _flash_name() -> void:
	if equipment == null:
		return
	_name_label.text = equipment.item_name(equipment.held_item)
	_name_label.modulate.a = 1.0
	if _name_tween != null and _name_tween.is_valid():
		_name_tween.kill()
	_name_tween = create_tween()
	_name_tween.tween_interval(1.4)
	_name_tween.tween_property(_name_label, "modulate:a", 0.0, 0.5)
	var panel := _slots[equipment.selected]["panel"] as Control
	var pop := create_tween()
	panel.scale = Vector2.ONE * 1.25
	pop.tween_property(panel, "scale", Vector2.ONE * 1.12, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", COLOR_SELECTED)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 5)
	_name_label.modulate.a = 0.0
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.02, 0.03, 0.025, 0.82)
	frame_style.border_color = Color(0.48, 0.61, 0.4, 0.75)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(10)
	frame_style.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", frame_style)
	center.add_child(frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	frame.add_child(row)

	for i in PlayerEquipment.SLOT_COUNT:
		var panel := Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.pivot_offset = SLOT_SIZE * 0.5
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_SLOT
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		var icon := ItemIcon.new()
		icon.position = Vector2(8, 8)
		icon.size = SLOT_SIZE - Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var key := Label.new()
		key.text = str(i + 1)
		key.position = Vector2(5, 1)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_outline_color", Color.BLACK)
		key.add_theme_constant_override("outline_size", 4)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(key)
		var count := Label.new()
		count.position = Vector2(SLOT_SIZE.x - 26, SLOT_SIZE.y - 22)
		count.size = Vector2(22, 20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 13)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)
		_slots.append({"panel": panel, "style": style, "icon": icon, "key": key, "count": count})

	var hint := Label.new()
	hint.text = "[1-9] item  ·  [I] inventário  ·  [C] fabricar  ·  [B] construir  ·  [F] comer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.8, 0.85))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
