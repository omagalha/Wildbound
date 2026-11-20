class_name ExperienceComponent
extends Node
## XP do jogador (GDD 009/010): recebe eventos dos sistemas e aplica as regras
## anti-repetição. Nenhum sistema de gameplay chama este nó diretamente; ele ouve
## sinais (interação, construção).
##
## Nunca dá XP por tempo parado, fome ou repetição: coleta tem limite por janela,
## construção e outras "primeiras vezes" contam uma vez por id (salvo no save).

signal xp_changed(total: int)
signal xp_awarded(source: StringName, amount: int)
signal xp_capped(source: StringName)

@export var rules: XPRules
@export var interaction: InteractionDetector
@export var building_manager: BuildingManager

var total_xp: int = 0
var game_time := 0.0
var _firsts: Dictionary = {}  # categoria -> {id: true}
var _collect_windows: Dictionary = {}  # item_id -> [inicio, xp_na_janela]


func _ready() -> void:
	if interaction != null:
		interaction.interacted.connect(_on_interacted)
	if building_manager != null:
		building_manager.piece_built.connect(_on_piece_built)


func _physics_process(delta: float) -> void:
	game_time += delta


## XP de coleta com limite por tipo e janela. Devolve o XP concedido.
func award_collect(item_id: StringName, amount: int) -> int:
	if rules == null or amount <= 0:
		return 0
	var window: Array = _collect_windows.get(item_id, [game_time, 0])
	if game_time - float(window[0]) >= rules.collect_window_seconds:
		window = [game_time, 0]
	var room := rules.collect_cap_per_type - int(window[1])
	var xp := mini(amount * rules.collect_xp_per_unit, maxi(room, 0))
	window[1] = int(window[1]) + xp
	_collect_windows[item_id] = window
	if xp <= 0:
		xp_capped.emit(&"collect")
		return 0
	_add(&"collect", xp)
	return xp


## XP de marco que só conta uma vez por (categoria, id). Devolve o XP concedido.
func award_first(category: StringName, id: StringName, xp: int) -> int:
	if xp <= 0 or has_first(category, id):
		return 0
	if not _firsts.has(category):
		_firsts[category] = {}
	_firsts[category][id] = true
	_add(category, xp)
	return xp


func has_first(category: StringName, id: StringName) -> bool:
	return _firsts.has(category) and _firsts[category].has(id)


func get_save_data() -> Dictionary:
	var firsts := {}
	for category in _firsts:
		firsts[String(category)] = _firsts[category].keys().map(func(k): return String(k))
	return {"total_xp": total_xp, "firsts": firsts}


func restore(data: Dictionary) -> void:
	total_xp = maxi(int(data.get("total_xp", 0)), 0)
	_firsts.clear()
	var firsts: Dictionary = data.get("firsts", {})
	for category in firsts:
		_firsts[StringName(category)] = {}
		for id in firsts[category]:
			_firsts[StringName(category)][StringName(id)] = true
	_collect_windows.clear()
	xp_changed.emit(total_xp)


func _add(source: StringName, xp: int) -> void:
	total_xp += xp
	xp_awarded.emit(source, xp)
	xp_changed.emit(total_xp)


func _on_interacted(_target: Node, result: Dictionary) -> void:
	if result.get("ok", false) and result.has("item_id"):
		award_collect(StringName(result["item_id"]), int(result.get("amount", 0)))


func _on_piece_built(piece: BuildingPiece) -> void:
	if rules != null and piece != null and piece.definition != null:
		award_first(&"structure", piece.definition.id, rules.first_build_xp)
