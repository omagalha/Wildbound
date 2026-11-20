class_name ChestMenu
extends CanvasLayer
## Painel do baú: mochila de um lado, baú do outro.
##
## Abre quando o jogador interage com um StorageChest (escuta o
## InteractionDetector). Clique esquerdo move o monte inteiro; direito move 1.
## "Guardar materiais" manda tudo que não está na hotbar; "Pegar tudo" traz
## tudo de volta. Fecha com [E], [Esc] ou se o jogador se afastar.

const COLUMNS := 5
const CARD_SIZE := Vector2(64, 64)

@export var inventory: Inventory
@export var interaction: InteractionDetector
@export var equipment: PlayerEquipment
@export var player: Node3D
@export var hud: SurvivalHUD
## Distância em que o painel fecha sozinho.
@export var close_distance: float = 3.5

var chest: StorageChest
var is_open := false
var _blocker: ColorRect
var _panel: PanelContainer
var _player_grid: GridContainer
var _chest_grid: GridContainer
var _player_title: Label
var _chest_title: Label
var _feedback: Label
var _just_opened := false


func _ready() -> void:
	layer = 5
	_build()
	_close_visuals()
	if interaction != null:
		interaction.interacted.connect(_on_interacted)


func _process(_delta: float) -> void:
	if not is_open:
		return
	if chest == null or not is_instance_valid(chest):
		close()
		return
	if player != null and player.global_position.distance_to(chest.global_position) > close_distance:
		close()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or (event.is_action_pressed(&"interact") and not _just_opened):
		close()
		get_viewport().set_input_as_handled()


## Abre o painel para [param target]. Devolve true se abriu.
func open(target: StorageChest) -> bool:
	if target == null:
		return false
	if is_open and chest != target:
		close()
	chest = target
	is_open = true
	chest.set_open(true)
	if not chest.storage.changed.is_connected(refresh):
		chest.storage.changed.connect(refresh)
	if inventory != null and not inventory.changed.is_connected(refresh):
		inventory.changed.connect(refresh)
	_panel.visible = true
	_blocker.visible = true
	_feedback.text = ""
	refresh()
	_just_opened = true
	_clear_just_opened.call_deferred()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	if chest != null and is_instance_valid(chest):
		chest.set_open(false)
		if chest.storage.changed.is_connected(refresh):
			chest.storage.changed.disconnect(refresh)
	chest = null
	_close_visuals()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Guarda [param amount] (-1 = tudo) de um item no baú. Devolve quanto foi.
func store(id: StringName, amount: int = -1) -> int:
	if chest == null:
		return 0
	var moved := StorageChest.transfer(inventory, chest.storage, id, inventory.count(id) if amount < 0 else amount)
	if moved <= 0:
		_say("Baú cheio")
	return moved


## Pega [param amount] (-1 = tudo) de um item do baú. Devolve quanto veio.
func take(id: StringName, amount: int = -1) -> int:
	if chest == null:
		return 0
	var moved := StorageChest.transfer(chest.storage, inventory, id, chest.storage.count(id) if amount < 0 else amount)
	if moved <= 0:
		_say("Mochila cheia")
	return moved


## Guarda tudo que não está na hotbar (materiais). Devolve quantas unidades.
func store_materials() -> int:
	var total := 0
	for id in inventory.get_all().keys():
		if equipment != null and equipment.slot_of(id) >= 0:
			continue
		total += store(id)
	_say("Guardou %d itens" % total if total > 0 else "Nada para guardar")
	return total


## Traz tudo o que couber. Devolve quantas unidades.
func take_all() -> int:
	var total := 0
	for id in chest.storage.get_all().keys():
		total += take(id)
	_say("Pegou %d itens" % total if total > 0 else "Nada coube na mochila")
	return total


func refresh() -> void:
	if not is_open or chest == null:
		return
	_fill(_player_grid, inventory, true)
	_fill(_chest_grid, chest.storage, false)
	_player_title.text = "Mochila  %d/%d" % [inventory.used_slots(), inventory.capacity]
	_chest_title.text = "Baú  %d/%d" % [chest.storage.used_slots(), chest.storage.capacity]


func get_player_card_count() -> int:
	return _player_grid.get_child_count()


func get_chest_card_count() -> int:
	return _chest_grid.get_child_count()


# ---------- interno ----------

func _on_interacted(target: Node, result: Dictionary) -> void:
	if result.get("open_chest", false) and target is StorageChest:
		open(target)


func _clear_just_opened() -> void:
	await get_tree().process_frame
	_just_opened = false


func _close_visuals() -> void:
	_panel.visible = false
	_blocker.visible = false


func _say(text: String) -> void:
	_feedback.text = text
	if hud != null and text != "":
		hud.show_message(text)


func _fill(grid: GridContainer, source: Inventory, from_player: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var all := source.get_all()
	var ids := all.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	for id in ids:
		grid.add_child(_card(id, int(all[id]), from_player))


func _card(id: StringName, count: int, from_player: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	var item := inventory.catalog.get_item(id) if inventory.catalog != null else null
	button.tooltip_text = "%s ×%d\nClique: mover tudo · Botão direito: mover 1" % [item.display_name if item != null else String(id), count]
	var icon := ItemIcon.new()
	icon.item_id = id
	icon.position = Vector2(10, 6)
	icon.size = CARD_SIZE - Vector2(20, 20)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var label := Label.new()
	label.text = str(count)
	label.position = Vector2(CARD_SIZE.x - 30, CARD_SIZE.y - 22)
	label.size = Vector2(26, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.gui_input.connect(func(event: InputEvent):
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		var amount := 1 if mb.button_index == MOUSE_BUTTON_RIGHT else -1
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		if from_player:
			store(id, amount)
		else:
			take(id, amount)
	)
	return button


func _build() -> void:
	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0.3)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.92)
	style.border_color = Color(0.75, 0.55, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Baú"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Clique: mover tudo · Botão direito: mover 1 · [E] ou [Esc] fecha"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.8, 0.8, 0.8)
	box.add_child(hint)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	box.add_child(columns)
	var left := _column("Mochila")
	_player_title = left[0]
	_player_grid = left[1]
	columns.add_child(left[2])
	var arrows := Label.new()
	arrows.text = "⇄"
	arrows.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrows.add_theme_font_size_override("font_size", 28)
	arrows.modulate = Color(1, 0.85, 0.55)
	columns.add_child(arrows)
	var right := _column("Baú")
	_chest_title = right[0]
	_chest_grid = right[1]
	columns.add_child(right[2])

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	for spec in [["Guardar materiais", store_materials], ["Pegar tudo", take_all], ["Fechar", close]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(150, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		actions.add_child(b)
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.modulate = Color(1, 0.9, 0.6)
	box.add_child(_feedback)


## [título, grade, raiz] de uma coluna.
func _column(name: String) -> Array:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = name
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85))
	col.add_child(label)
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.03, 0.03, 0.6)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", st)
	frame.custom_minimum_size = Vector2(COLUMNS * (CARD_SIZE.x + 6) + 10, 4 * (CARD_SIZE.y + 6) + 10)
	col.add_child(frame)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	frame.add_child(grid)
	return [label, grid, col]
