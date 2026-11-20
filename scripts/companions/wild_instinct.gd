class_name WildInstinct
extends Node3D
## Instinto Selvagem (Wild Companions 4): com o companheiro Seguindo, sinaliza sozinho o
## recurso válido mais próximo (12 m) por 3 s; depois 20 s de recarga. Não coleta nada.

signal signaled(target: Node3D)

@export var creature: CreatureController
@export var categories: Array[StringName] = [&"wood", &"stone", &"fruit"]
@export var radius: float = 12.0
@export var marker_duration: float = 3.0
@export var cooldown: float = 20.0
## Um recurso sinalizado não é escolhido de novo por este tempo.
@export var memory_seconds: float = 60.0
@export var scan_rate_hz: float = 2.0
@export_flags_3d_physics var resource_mask: int = 4

@onready var marker: Node3D = $Marker

var cooldown_left := 0.0
var current_target: Node3D = null
var game_time := 0.0
var _marker_left := 0.0
var _scan_left := 0.0
var _memory: Dictionary = {}  # instance_id -> tempo em que foi sinalizado


func _ready() -> void:
	marker.top_level = true
	marker.visible = false


func _physics_process(delta: float) -> void:
	game_time += delta
	cooldown_left = maxf(cooldown_left - delta, 0.0)  # a recarga corre em qualquer estado
	if _marker_left > 0.0:
		_marker_left -= delta
		if _marker_left <= 0.0 or not _target_valid(current_target):
			_hide_marker()
		else:
			marker.global_position = current_target.global_position + Vector3.UP * 2.2
			marker.rotation.y += delta * 3.0
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = 1.0 / scan_rate_hz
		try_signal()


func is_ready_to_signal() -> bool:
	return cooldown_left <= 0.0 and creature != null and creature.is_following()


## Procura e sinaliza um alvo, se puder. Devolve o alvo ou null.
func try_signal() -> Node3D:
	if not is_ready_to_signal():
		return null
	var target := find_target()
	if target == null:
		return null  # sem alvo, sem recarga
	current_target = target
	_memory[target.get_instance_id()] = game_time
	cooldown_left = cooldown
	_marker_left = marker_duration
	marker.visible = true
	marker.global_position = target.global_position + Vector3.UP * 2.2
	if target.has_signal("depleted") and not target.is_connected("depleted", _on_target_depleted):
		target.connect("depleted", _on_target_depleted.bind(target), CONNECT_ONE_SHOT)
	creature.show_emote("✦", 1.5)
	signaled.emit(target)
	return target


## Recurso válido mais próximo do companheiro, ou null. Desempate pelo menor id.
func find_target() -> Node3D:
	var origin := creature.global_position
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = resource_mask
	params.collide_with_areas = false
	var best: Node3D = null
	var best_distance := INF
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 64):
		var node := hit["collider"] as Node3D
		if not _target_valid(node) or not categories.has(node.get_resource_category()):
			continue
		var seen: float = _memory.get(node.get_instance_id(), -INF)
		if game_time - seen < memory_seconds:
			continue
		var distance := origin.distance_to(node.global_position)
		if distance > radius:
			continue
		if distance < best_distance - 0.1 or (absf(distance - best_distance) < 0.1 and best != null and node.get_instance_id() < best.get_instance_id()):
			best = node
			best_distance = distance
	return best


func _target_valid(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("get_resource_category") \
		and not (node.has_method("is_depleted") and node.is_depleted())


func _on_target_depleted(target: Node3D) -> void:
	_memory.erase(target.get_instance_id())
	if target == current_target:
		_hide_marker()


func _hide_marker() -> void:
	_marker_left = 0.0
	marker.visible = false
	current_target = null
