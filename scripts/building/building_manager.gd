class_name BuildingManager
extends Node3D
## Dono das peças construídas (GDD 011). Colocar e remover são operações únicas:
## validar → mexer no inventário → criar/apagar a peça → registrar.
##
## As peças ficam como filhas deste nó. Nenhuma peça é criada sem consumir o
## custo, e nenhuma devolução passa do custo (regra de conservação).

signal piece_built(piece: BuildingPiece)
## Peça recriada a partir do save (sem custo).
signal piece_restored(piece: BuildingPiece)
signal piece_removed(piece_id: StringName, refund: Dictionary)
signal removal_blocked(piece: BuildingPiece, reason: String, dependents: Array)

## Janela de correção com devolução integral, em segundos de jogo.
@export var full_refund_window: float = 10.0
## Fração devolvida depois da janela (arredondada para baixo por item).
@export_range(0.0, 1.0) var late_refund_ratio: float = 0.75
## Peças conhecidas (para recriar peças ao carregar).
@export var catalog: BuildingCatalog

var game_time := 0.0
var _next_id := 1
var _pieces: Dictionary = {}  # StringName -> BuildingPiece


func _physics_process(delta: float) -> void:
	game_time += delta


func get_pieces() -> Array[BuildingPiece]:
	var list: Array[BuildingPiece] = []
	for piece in _pieces.values():
		if is_instance_valid(piece):
			list.append(piece)
	return list


func get_piece(piece_id: StringName) -> BuildingPiece:
	var piece: BuildingPiece = _pieces.get(piece_id)
	return piece if is_instance_valid(piece) else null


func get_definition(id: StringName) -> BuildingPieceDefinition:
	return catalog.get_piece(id) if catalog != null else null


## Peça do tipo informado já ocupando (quase) esta posição.
func find_piece_at(position: Vector3, snap_type: StringName, tolerance: float = 0.1) -> BuildingPiece:
	for piece in get_pieces():
		if piece.definition.snap_type == snap_type and piece.global_position.distance_to(position) <= tolerance:
			return piece
	return null


## Coloca a peça consumindo o custo do inventário. Devolve a peça ou null.
func place(definition: BuildingPieceDefinition, transform: Transform3D, inventory: Inventory, support: BuildingPiece = null) -> BuildingPiece:
	if definition == null or definition.scene == null or inventory == null:
		return null
	if not inventory.has_all(definition.cost):
		return null
	var piece := definition.scene.instantiate() as BuildingPiece
	if piece == null:
		push_error("BuildingManager: a cena de '%s' não tem BuildingPiece na raiz." % definition.id)
		return null
	if not inventory.remove_all(definition.cost):
		piece.free()
		return null
	_register(piece, definition, transform, support.piece_id if support != null else &"", _generate_id())
	piece.placed_at = game_time
	piece_built.emit(piece)
	return piece


## Peças que dependem desta (bloqueiam a remoção).
func get_dependents(piece: BuildingPiece) -> Array[BuildingPiece]:
	var dependents: Array[BuildingPiece] = []
	for other in get_pieces():
		if other != piece and other.support_id == piece.piece_id:
			dependents.append(other)
	# A última parede de uma fundação com telhado também é suporte do telhado.
	if piece.definition.snap_type == &"wall" and piece.support_id != &"":
		var walls := 0
		var roofs: Array[BuildingPiece] = []
		for other in get_pieces():
			if other.support_id == piece.support_id:
				if other.definition.snap_type == &"wall":
					walls += 1
				elif other.definition.snap_type == &"roof":
					roofs.append(other)
		if walls <= 1:
			dependents.append_array(roofs)
	return dependents


## Quanto seria devolvido ao remover agora.
func refund_for(piece: BuildingPiece) -> Dictionary:
	var full := game_time - piece.placed_at <= full_refund_window
	var refund := {}
	for item_id in piece.definition.cost:
		var amount := int(piece.definition.cost[item_id])
		refund[item_id] = amount if full else int(floor(amount * late_refund_ratio))
	return refund


## Remove a peça e devolve recursos. Devolve {"ok": bool, "message": String}.
func remove(piece: BuildingPiece, inventory: Inventory) -> Dictionary:
	if piece == null or not _pieces.has(piece.piece_id):
		return {"ok": false, "message": "Nada para remover"}
	var dependents := get_dependents(piece)
	if not dependents.is_empty():
		removal_blocked.emit(piece, "dependents", dependents)
		return {"ok": false, "message": "Remova antes as peças apoiadas nesta (%d)" % dependents.size()}
	if piece.has_method("blocks_removal") and piece.blocks_removal():
		removal_blocked.emit(piece, "not_empty", [])
		return {"ok": false, "message": "Esvazie antes de remover"}
	var refund := refund_for(piece)
	if inventory == null or not inventory.can_add_all(refund):
		removal_blocked.emit(piece, "inventory_full", [])
		return {"ok": false, "message": "Inventário sem espaço para a devolução"}
	inventory.add_all(refund)
	var id := piece.piece_id
	_pieces.erase(id)
	piece.queue_free()
	piece_removed.emit(id, refund)
	return {"ok": true, "message": "Peça removida", "refund": refund}


## Recria uma peça salva (sem custo). Usado pelo save.
func restore_piece(definition: BuildingPieceDefinition, transform: Transform3D, piece_id: StringName, support_id: StringName) -> BuildingPiece:
	if definition == null or definition.scene == null or _pieces.has(piece_id):
		return null
	var piece := definition.scene.instantiate() as BuildingPiece
	_register(piece, definition, transform, support_id, piece_id)
	# Depois de carregar, a janela de 10 s não vale mais (BUILDING.md 8.2.5).
	piece.placed_at = -INF
	var number := String(piece_id).get_slice("_", 1).to_int()
	_next_id = maxi(_next_id, number + 1)
	piece_restored.emit(piece)
	return piece


## Remove todas as peças sem devolução (usado antes de carregar um save).
func clear_all() -> void:
	for piece in get_pieces():
		piece.queue_free()
	_pieces.clear()
	_next_id = 1


func _register(piece: BuildingPiece, definition: BuildingPieceDefinition, transform: Transform3D, support_id: StringName, piece_id: StringName) -> void:
	piece.definition = definition
	piece.piece_id = piece_id
	piece.support_id = support_id
	piece.name = String(piece_id)
	add_child(piece)
	piece.global_transform = transform
	_pieces[piece_id] = piece


func _generate_id() -> StringName:
	var id := StringName("piece_%d" % _next_id)
	_next_id += 1
	return id
