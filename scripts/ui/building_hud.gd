class_name BuildingHUD
extends CanvasLayer
## HUD do modo de construção: lista de peças com custo, estado da prévia e resultado.
##
## O estado nunca é mostrado só por cor: sempre há ícone e texto (GDD 011, 3.4).
## Só escuta sinais; nunca altera o estado do jogo.

@export var controller: PlacementController
@export var inventory: Inventory

const STATE_TEXT := {
	PlacementController.State.VALID: "✓ ",
	PlacementController.State.INVALID: "✕ ",
	PlacementController.State.MISSING_RESOURCES: "! ",
}
const STATE_COLOR := {
	PlacementController.State.VALID: Color(0.55, 1.0, 0.6),
	PlacementController.State.INVALID: Color(1.0, 0.5, 0.45),
	PlacementController.State.MISSING_RESOURCES: Color(1.0, 0.88, 0.4),
}

@onready var _panel: Control = %BuildPanel
@onready var _pieces_label: Label = %PiecesLabel
@onready var _status_label: Label = %StatusLabel
@onready var _result_label: Label = %ResultLabel
@onready var _hint_label: Label = %HintLabel

var _result_left := 0.0


func _ready() -> void:
	if controller != null:
		controller.build_mode_changed.connect(_on_mode_changed)
		controller.selection_changed.connect(func(_i, _d): _refresh_pieces())
		controller.preview_changed.connect(_on_preview_changed)
		controller.action_result.connect(_on_action_result)
	if inventory != null:
		inventory.changed.connect(_refresh_pieces)
	if controller != null and controller.knowledge != null:
		controller.knowledge.knowledge_learned.connect(func(_id, _o): _refresh_pieces())
	_on_mode_changed(controller != null and controller.active)


func _process(delta: float) -> void:
	if _result_left > 0.0:
		_result_left -= delta
		if _result_left <= 0.0:
			_result_label.text = ""


func get_status_text() -> String:
	return _status_label.text


func get_pieces_text() -> String:
	return _pieces_label.text


func is_panel_visible() -> bool:
	return _panel.visible


func _on_mode_changed(active: bool) -> void:
	_panel.visible = active
	_hint_label.visible = not active
	_status_label.text = ""
	_refresh_pieces()


func _refresh_pieces() -> void:
	if controller == null or controller.catalog == null:
		return
	var lines: PackedStringArray = []
	for i in controller.catalog.pieces.size():
		var piece := controller.catalog.pieces[i]
		var marker := "▶ " if i == controller.selected_index else "   "
		var affordable := inventory != null and inventory.has_all(piece.cost)
		var cost := piece.cost_text(inventory.catalog if inventory != null else null)
		var note := "" if affordable else "  (faltam itens)"
		if not controller.is_unlocked(piece):
			note = "  🔒 " + controller.requirement_text(piece)
		lines.append("%s%d  %s — %s%s" % [marker, i + 1, piece.display_name, cost, note])
	_pieces_label.text = "\n".join(lines)


func _on_preview_changed(state: int, reason: String) -> void:
	_status_label.text = STATE_TEXT.get(state, "") + reason
	_status_label.modulate = STATE_COLOR.get(state, Color.WHITE)


func _on_action_result(ok: bool, message: String) -> void:
	_result_label.text = message
	_result_label.modulate = Color(0.6, 1.0, 0.65) if ok else Color(1.0, 0.6, 0.55)
	_result_left = 2.5
