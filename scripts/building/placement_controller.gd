class_name PlacementController
extends Node3D
## Modo de construção: seleção de peça, prévia, encaixe, rotação, confirmar e remover (GDD 011).
##
## A mira é o centro da câmera. O mesmo controle serve ao PC e ao toque: só muda
## quem chama [method enter], [method select], [method confirm], [method rotate_step]...
##
## Entrada (PC): B alterna o modo; 1–6 escolhem a peça; roda do mouse alterna o
## encaixe; R gira objetos livres e fundações soltas; clique esquerdo confirma;
## X remove a peça mirada; clique direito ou Esc cancela.
## Este nó fica DEPOIS do Player na cena principal: recebe a entrada antes da câmera,
## então o Esc do modo de construção não libera o mouse (risco R-BL-03).

signal build_mode_changed(active: bool)
signal selection_changed(index: int, definition: BuildingPieceDefinition)
signal preview_changed(state: int, reason: String)
signal action_result(ok: bool, message: String)

enum State { NONE, VALID, INVALID, MISSING_RESOURCES }

const RAY_LENGTH := 20.0
const ROTATION_STEP_DEGREES := 15.0

@export var catalog: BuildingCatalog
@export var manager: BuildingManager
@export var inventory: Inventory
@export var player: Node3D
@export var camera: Camera3D
@export var health: HealthComponent
## Conhecimentos aprendidos; null = sem requisito (testes antigos e ferramentas).
@export var knowledge: KnowledgeManager
## Usada só para dizer em que nível um conhecimento é liberado.
@export var level_curve: LevelCurve
## Alcance máximo a partir do jogador, em metros.
@export var reach: float = 8.0
## Distância máxima entre a linha de mira e um encaixe para ele ser candidato.
@export var snap_radius: float = 1.5
@export var max_foundation_height_diff: float = 0.5

var active := false
var selected_index := 0
var rotation_steps := 0
var snap_cycle := 0
var last_state: int = State.NONE
var last_reason := ""
var last_transform := Transform3D.IDENTITY
var last_support: BuildingPiece = null

var _preview: BuildingPiece = null
var _preview_definition: BuildingPieceDefinition = null
var _materials := {}


func _ready() -> void:
	set_as_top_level(true)
	for state in [State.VALID, State.INVALID, State.MISSING_RESOURCES]:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = {State.VALID: Color(0.3, 0.95, 0.4, 0.45), State.INVALID: Color(0.95, 0.25, 0.25, 0.45),
			State.MISSING_RESOURCES: Color(0.98, 0.85, 0.2, 0.45)}[state]
		_materials[state] = mat
	if health != null:
		health.died.connect(func(_c): exit())


func _physics_process(_delta: float) -> void:
	if active and camera != null:
		update_preview(camera.global_position, -camera.global_transform.basis.z)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	var handled := true
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"build_cancel"):
		exit()
	elif event.is_action_pressed(&"build_confirm"):
		# Com o mouse solto, o clique é da câmera (recapturar), não da construção.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			confirm()
		else:
			handled = false
	elif event.is_action_pressed(&"build_rotate"):
		rotate_step(1)
	elif event.is_action_pressed(&"build_cycle_snap"):
		snap_cycle += 1
	elif event.is_action_pressed(&"build_remove"):
		remove_aimed()
	else:
		handled = false
		for i in 6:
			if event.is_action_pressed(StringName("build_piece_%d" % (i + 1))):
				select(i)
				handled = true
	if handled:
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if active:
		exit()
	else:
		enter()


func enter() -> bool:
	if active or catalog == null or catalog.pieces.is_empty():
		return false
	if health != null and health.is_dead():
		return false
	active = true
	select(selected_index)
	build_mode_changed.emit(true)
	return true


func exit() -> void:
	if not active:
		return
	active = false
	_clear_preview()
	last_state = State.NONE
	build_mode_changed.emit(false)


func select(index: int) -> void:
	if catalog == null or index < 0 or index >= catalog.pieces.size():
		return
	selected_index = index
	snap_cycle = 0
	if active:
		_ensure_preview(get_selected())
	selection_changed.emit(index, get_selected())


func get_selected() -> BuildingPieceDefinition:
	if catalog == null or catalog.pieces.is_empty():
		return null
	return catalog.pieces[clampi(selected_index, 0, catalog.pieces.size() - 1)]


func rotate_step(direction: int) -> void:
	rotation_steps = posmod(rotation_steps + direction, int(360.0 / ROTATION_STEP_DEGREES))


func rotation_degrees_y() -> float:
	return rotation_steps * ROTATION_STEP_DEGREES


## Calcula a prévia para uma linha de mira. Devolve o estado.
func update_preview(origin: Vector3, direction: Vector3) -> int:
	var definition := get_selected()
	if not active or definition == null:
		return State.NONE
	var result := evaluate(definition, origin, direction.normalized())
	last_state = result["state"]
	last_reason = result["reason"]
	last_transform = result["transform"]
	last_support = result["support"]
	_ensure_preview(definition)
	_preview.global_transform = last_transform
	_preview.visible = result["has_transform"]
	_preview.set_preview_material(_materials[last_state])
	preview_changed.emit(last_state, last_reason)
	return last_state


## Avaliação completa de uma posição. Não altera nada.
func evaluate(definition: BuildingPieceDefinition, origin: Vector3, direction: Vector3) -> Dictionary:
	var out := {"state": State.INVALID, "reason": "", "transform": Transform3D.IDENTITY, "support": null, "has_transform": false}
	var space := get_world_3d().direct_space_state
	var validator := PlacementValidator.new(space)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, PlacementValidator.WORLD_MASK)
	var hit := space.intersect_ray(ray)
	var yaw := Basis(Vector3.UP, deg_to_rad(rotation_degrees_y()))
	var support: BuildingPiece = null
	var transform := Transform3D.IDENTITY
	var snapped := false

	if definition.is_structural():
		var candidates := snap_candidates(definition, origin, direction)
		if not candidates.is_empty():
			var snap: SnapPoint = candidates[snap_cycle % candidates.size()]
			transform = snap.global_transform
			snapped = true
			# Fundações se apoiam no chão, não na vizinha: só paredes e telhados ganham suporte.
			if definition.snap_type != &"foundation":
				support = snap.owner as BuildingPiece if snap.owner is BuildingPiece else snap.get_parent() as BuildingPiece
		elif definition.allows_free_ground_placement and not hit.is_empty() and not (hit["collider"] is BuildingPiece):
			transform = Transform3D(yaw, hit["position"])
		else:
			if not hit.is_empty():
				out["transform"] = Transform3D(yaw, hit["position"])
				out["has_transform"] = true
			out["reason"] = "Mire num encaixe livre"
			return out
	else:
		if hit.is_empty():
			out["reason"] = "Mire no chão ou numa fundação"
			return out
		var collider: Object = hit["collider"]
		transform = Transform3D(yaw, hit["position"])
		out["transform"] = transform
		out["has_transform"] = true
		if collider is BuildingPiece:
			if (collider as BuildingPiece).definition.snap_type != &"foundation" or (hit["normal"] as Vector3).y < 0.9:
				out["reason"] = "Só no chão ou sobre fundações"
				return out
			support = collider
		elif (hit["normal"] as Vector3).y < cos(deg_to_rad(definition.max_slope_degrees)):
			out["reason"] = "Terreno inclinado demais"
			return out

	out["transform"] = transform
	out["support"] = support
	out["has_transform"] = true

	if not is_unlocked(definition):
		out["state"] = State.MISSING_RESOURCES
		out["reason"] = "Requer " + requirement_text(definition)
		return out
	if player != null and transform.origin.distance_to(player.global_position) > reach:
		out["reason"] = "Fora do alcance"
		return out
	if validator.overlaps(definition, transform):
		out["reason"] = "Bloqueado por outro objeto"
		return out
	if definition.is_structural() and support == null:
		var ground := validator.check_ground_corners(transform, definition.validation_size.x * 0.5, max_foundation_height_diff, definition.max_slope_degrees)
		if ground != "":
			out["reason"] = ground
			return out
	if not definition.is_structural():
		var free_support := validator.check_free_support(definition, transform)
		if free_support != "":
			out["reason"] = free_support
			return out
	if definition.needs_wall_support and not _has_wall(support):
		out["reason"] = "O telhado precisa de pelo menos uma parede"
		return out
	if inventory == null or not inventory.has_all(definition.cost):
		out["state"] = State.MISSING_RESOURCES
		out["reason"] = "Faltam recursos: " + _missing_text(definition)
		return out
	out["state"] = State.VALID
	out["reason"] = "Encaixe disponível" if snapped else "Posição válida"
	return out


## Encaixes livres e compatíveis perto da linha de mira, do mais próximo ao mais distante.
func snap_candidates(definition: BuildingPieceDefinition, origin: Vector3, direction: Vector3) -> Array[SnapPoint]:
	var scored: Array = []
	if manager == null:
		return []
	for piece in manager.get_pieces():
		for snap in piece.get_snap_points():
			if snap.accepts != definition.snap_type:
				continue
			var point := snap.global_position
			if manager.find_piece_at(point, definition.snap_type) != null:
				continue
			var t := (point - origin).dot(direction)
			if t <= 0.0:
				continue
			var distance := (origin + direction * t).distance_to(point)
			if distance <= snap_radius:
				scored.append([distance, snap])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var result: Array[SnapPoint] = []
	for entry in scored:
		result.append(entry[1])
	return result


## Confirma a última prévia válida. Recursos só são gastos aqui.
func confirm() -> bool:
	if not active or last_state != State.VALID:
		action_result.emit(false, last_reason if last_reason != "" else "Nada para construir")
		return false
	var piece := manager.place(get_selected(), last_transform, inventory, last_support)
	if piece == null:
		action_result.emit(false, "Não foi possível construir")
		return false
	action_result.emit(true, "%s construída" % get_selected().display_name)
	return true


## Remove a peça mirada pela câmera.
func remove_aimed() -> Dictionary:
	if camera == null:
		return {"ok": false}
	return remove_along(camera.global_position, -camera.global_transform.basis.z)


func remove_along(origin: Vector3, direction: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * RAY_LENGTH, PlacementValidator.WORLD_MASK))
	var piece: BuildingPiece = hit.get("collider") as BuildingPiece if not hit.is_empty() else null
	var result: Dictionary
	if piece == null:
		result = {"ok": false, "message": "Mire numa peça construída"}
	elif player != null and piece.global_position.distance_to(player.global_position) > reach + 2.0:
		result = {"ok": false, "message": "Fora do alcance"}
	else:
		result = manager.remove(piece, inventory)
	action_result.emit(result.get("ok", false), result.get("message", ""))
	return result


func is_unlocked(definition: BuildingPieceDefinition) -> bool:
	return knowledge == null or knowledge.is_known(definition.required_knowledge)


## Ex.: "nível 2 (Abrigo Primitivo (fundação, parede, entrada))".
func requirement_text(definition: BuildingPieceDefinition) -> String:
	var id := definition.required_knowledge
	if level_curve == null:
		return String(id)
	var level := level_curve.level_unlocking(id)
	var name := level_curve.knowledge_name(id)
	return "nível %d (%s)" % [level, name] if level > 0 else name


func _has_wall(foundation: BuildingPiece) -> bool:
	if foundation == null or manager == null:
		return false
	for piece in manager.get_pieces():
		if piece.support_id == foundation.piece_id and piece.definition.snap_type == &"wall":
			return true
	return false


func _missing_text(definition: BuildingPieceDefinition) -> String:
	var parts: PackedStringArray = []
	for item_id in definition.cost:
		var missing := int(definition.cost[item_id]) - (inventory.count(item_id) if inventory != null else 0)
		if missing > 0:
			var item := inventory.catalog.get_item(item_id) if inventory != null and inventory.catalog != null else null
			parts.append("%d %s" % [missing, item.display_name if item != null else String(item_id)])
	return ", ".join(parts)


func _ensure_preview(definition: BuildingPieceDefinition) -> void:
	if _preview != null and _preview_definition == definition:
		return
	_clear_preview()
	if definition == null or definition.scene == null:
		return
	_preview = definition.scene.instantiate() as BuildingPiece
	_preview_definition = definition
	add_child(_preview)
	_preview.make_preview(_materials[State.INVALID])
	_preview.visible = false


func _clear_preview() -> void:
	if _preview != null:
		_preview.queue_free()
	_preview = null
	_preview_definition = null
