class_name InventorySummary
extends PanelContainer
## Resumo fixo do inventário: os 11 tipos sempre ocupam a mesma posição.
## O painel apenas escuta Inventory.changed; não altera itens nem regras.

const ITEM_VISUALS := {
	&"wood": {"code": "MAD", "color": Color("a9784a")},
	&"stone": {"code": "PED", "color": Color("9ba2a2")},
	&"fiber": {"code": "FIB", "color": Color("7daa67")},
	&"wild_berries": {"code": "FRU", "color": Color("c85b78")},
	&"stone_axe": {"code": "MAC", "color": Color("a6b0b5")},
	&"stone_pickaxe": {"code": "PIC", "color": Color("8099aa")},
	&"stone_spear": {"code": "LAN", "color": Color("c9b07b")},
	&"torch": {"code": "TOC", "color": Color("e7a23b")},
	&"bandage": {"code": "ATA", "color": Color("e8dcc5")},
	&"raw_meat": {"code": "CRU", "color": Color("b85b55")},
	&"cooked_meat": {"code": "ASS", "color": Color("c67a42")},
	&"flint": {"code": "SIL", "color": Color("6f86b8")},
	&"flint_axe": {"code": "MCS", "color": Color("6f86b8")},
	&"flint_pickaxe": {"code": "PCS", "color": Color("6f86b8")},
	&"iron_ore": {"code": "MIN", "color": Color("c47a45")},
	&"iron_ingot": {"code": "LIN", "color": Color("c3c8d0")},
	&"iron_axe": {"code": "MCF", "color": Color("c3c8d0")},
	&"iron_pickaxe": {"code": "PCF", "color": Color("c3c8d0")},
	&"iron_sword": {"code": "ESP", "color": Color("c3c8d0")},
	&"ice_crystal": {"code": "CRI", "color": Color("8fe6ff")},
	&"clay": {"code": "ARG", "color": Color("b8683f")},
	&"obsidian": {"code": "OBS", "color": Color("6a4a8a")},
	&"sulfur": {"code": "ENX", "color": Color("f2d33a")},
	&"golden_berries": {"code": "DOU", "color": Color("ffc928")},
	&"coconut": {"code": "COC", "color": Color("8a6a40")},
	&"golden_stew": {"code": "ENS", "color": Color("e09a3a")},
	&"frost_elixir": {"code": "ELX", "color": Color("6fd8ff")},
	&"obsidian_sword": {"code": "ESO", "color": Color("6a4a8a")},
}

@export var inventory: Inventory

@onready var _grid: GridContainer = %ItemGrid
@onready var _header_count: Label = %HeaderCount

var _cards: Dictionary = {} # id -> {panel, code, amount, style}
var _snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if inventory != null:
		bind_inventory(inventory)


func bind_inventory(value: Inventory) -> void:
	if inventory != null and inventory.changed.is_connected(_refresh):
		inventory.changed.disconnect(_refresh)
	inventory = value
	if inventory != null and not inventory.changed.is_connected(_refresh):
		inventory.changed.connect(_refresh)
	_build_cards()
	_refresh(false)


func get_item_card_count() -> int:
	return _cards.size()


func get_card_text(id: StringName) -> String:
	if not _cards.has(id):
		return ""
	var card: Dictionary = _cards[id]
	return "%s %s" % [(card["code"] as Label).text, (card["amount"] as Label).text]


func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	if inventory == null or inventory.catalog == null:
		return
	for item in inventory.catalog.items:
		if item == null:
			continue
		var visual: Dictionary = ITEM_VISUALS.get(item.id, {
			"code": item.display_name.left(3).to_upper(),
			"color": Color(0.6, 0.65, 0.58),
		})
		_add_card(item, visual)


func _add_card(item: ItemDefinition, visual: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(53.0, 40.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.tooltip_text = item.display_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.06, 0.94)
	style.border_color = visual["color"]
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(5)
	style.content_margin_left = 5.0
	style.content_margin_right = 4.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", style)
	_grid.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := ItemIcon.new()
	icon.item_id = item.id
	icon.custom_minimum_size = Vector2(26, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var code := Label.new()
	code.text = visual["code"]
	code.visible = false  # o ícone substitui a sigla; fica para consulta
	row.add_child(code)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var amount := Label.new()
	amount.text = "—"
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_font_size_override("font_size", 14)
	amount.add_theme_color_override("font_color", Color(0.9, 0.93, 0.86))
	row.add_child(amount)
	_cards[item.id] = {"panel": panel, "code": code, "amount": amount, "style": style, "icon": icon}


func _refresh(animate_changes: bool = true) -> void:
	if inventory == null:
		_header_count.text = ""
		return
	_header_count.text = "%d/%d" % [inventory.used_slots(), inventory.capacity]
	for id in _cards:
		var quantity := inventory.count(id)
		var old_quantity := int(_snapshot.get(id, 0))
		var card: Dictionary = _cards[id]
		(card["amount"] as Label).text = str(quantity) if quantity > 0 else "—"
		(card["panel"] as PanelContainer).modulate = Color.WHITE if quantity > 0 else Color(1, 1, 1, 0.34)
		(card["panel"] as PanelContainer).visible = quantity > 0  # só o que você tem
		if card.has("icon"):
			(card["icon"] as ItemIcon).dimmed = quantity <= 0
		if animate_changes and quantity != old_quantity:
			var target := Color.WHITE if quantity > 0 else Color(1, 1, 1, 0.34)
			_pulse_card(card["panel"] as PanelContainer, target)
	_snapshot = inventory.get_all()


func _pulse_card(card: PanelContainer, target: Color) -> void:
	card.modulate = Color(1.2, 1.2, 0.85, 1.0)
	var tween := card.create_tween()
	tween.tween_property(card, "modulate", target, 0.28)
