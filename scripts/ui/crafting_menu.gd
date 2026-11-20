class_name CraftingMenu
extends CanvasLayer
## Menu de fabricação: [C] abre e fecha, clique numa receita para fabricar.
##
## Com o menu aberto o mouse fica livre (a câmera para de girar e o clique
## não ataca); ao fechar, o mouse volta a ser capturado. Esc também fecha.
## Só mostra dados do CraftingManager; nenhuma regra mora aqui.

const ACTION_TOGGLE := &"crafting_menu"

@export var manager: CraftingManager
## Não abre durante o modo de construção.
@export var placement: PlacementController
@export var hud: SurvivalHUD

var is_open := false
var _panel: PanelContainer
var _blocker: Control
var _list: VBoxContainer
var _feedback: Label
var _rows := {}  # recipe id -> {"button": Button, "info": Label}
var _refresh_left := 0.0


func _ready() -> void:
	layer = 5
	_build()
	_panel.visible = false
	if manager != null and manager.inventory != null:
		manager.inventory.changed.connect(_refresh)


func _process(delta: float) -> void:
	if not is_open:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.4  # a distância da fogueira muda enquanto o jogador anda
		_refresh()


func _input(event: InputEvent) -> void:
	# Antes da câmera: Esc fecha o menu em vez de só soltar o mouse.
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TOGGLE):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> bool:
	if is_open:
		return true
	if placement != null and placement.active:
		_say("Saia do modo de construção para fabricar")
		return false
	if manager != null and manager.health != null and manager.health.is_dead():
		return false
	is_open = true
	_panel.visible = true
	_blocker.visible = true
	_feedback.text = ""
	_refresh()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	_blocker.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Fabrica pelo menu (o mesmo caminho do clique). Devolve o resultado do manager.
func craft_by_id(id: StringName) -> Dictionary:
	var recipe := manager.get_recipe(id) if manager != null else null
	if recipe == null:
		return {"ok": false}
	var result := manager.craft(recipe)
	_feedback.text = result.get("message", "")
	_feedback.modulate = Color(0.6, 1, 0.6) if result.get("ok", false) else Color(1, 0.65, 0.5)
	if result.get("ok", false):
		_say(result["message"])
	_refresh()
	return result


func row_text(id: StringName) -> String:
	if not _rows.has(id):
		return ""
	return "%s | %s" % [_rows[id]["button"].text, _rows[id]["info"].text]


func _refresh() -> void:
	if manager == null:
		return
	for recipe in manager.recipes:
		if recipe == null or not _rows.has(recipe.id):
			continue
		var row: Dictionary = _rows[recipe.id]
		var status := manager.status(recipe)
		var button: Button = row["button"]
		var info: Label = row["info"]
		button.disabled = status != CraftingManager.READY
		var station := "  ·  na fogueira" if recipe.station != &"" else ""
		info.text = "%s%s\n%s — %s" % [manager.cost_text(recipe), station, recipe.description, manager.reason_text(recipe, status)]
		info.modulate = Color(0.75, 1, 0.75) if status == CraftingManager.READY else (Color(0.65, 0.65, 0.65) if status == CraftingManager.LOCKED else Color(1, 0.85, 0.7))


func _say(text: String) -> void:
	if hud != null:
		hud.show_message(text)


func _build() -> void:
	# Fundo que engole cliques fora do painel (senão a câmera recaptura o mouse).
	var root := ColorRect.new()
	root.color = Color(0, 0, 0, 0.25)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	_blocker = root
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.08, 0.88)
	style.border_color = Color(0.85, 0.7, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Fabricação"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Clique para fabricar · [C] ou [Esc] fecha"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.8, 0.8, 0.8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	if manager != null:
		for recipe in manager.recipes:
			if recipe != null:
				_add_row(recipe)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_feedback)


func _add_row(recipe: CraftingRecipe) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_list.add_child(row)
	var button := Button.new()
	button.text = recipe.display_name
	button.custom_minimum_size = Vector2(180, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(craft_by_id.bind(recipe.id))
	row.add_child(button)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	_rows[recipe.id] = {"button": button, "info": info}
