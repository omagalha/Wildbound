class_name InteractionDetector
extends Node3D
## Encontra o objeto interativo mais próximo do jogador e o aciona com "interact".
##
## Contrato de um interativo (por duck typing, sem classe base obrigatória):
##   func get_interaction_prompt() -> String
##   func can_interact(interactor: InteractionDetector) -> bool
##   func interact(interactor: InteractionDetector) -> Dictionary  # {"ok": bool, "message": String}
##
## O detector é passado como "interactor" e expõe as referências que os
## interativos precisam (ex.: [member inventory]); assim nenhum interativo
## depende do script do jogador.
##
## A busca é uma consulta de física na camada de interativos, feita poucas vezes
## por segundo — nunca uma varredura do mundo a cada quadro.

signal focus_changed(target: Node, prompt: String)
signal interacted(target: Node, result: Dictionary)

const ACTION_INTERACT := &"interact"

## Distância máxima de interação, em metros.
@export var interaction_range: float = 2.5
## Camada de física dos interativos (camada 3 = "resources").
@export_flags_3d_physics var interactable_mask: int = 4
## Consultas por segundo para atualizar o foco.
@export var scan_rate_hz: float = 5.0
## Inventário do jogador, entregue aos interativos.
@export var inventory: Inventory
## Se false, não procura nem aciona nada (ex.: jogador morto).
@export var enabled: bool = true

var _focused: Node = null
var _scan_timer: float = 0.0
var _last_prompt := ""


func _physics_process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 1.0 / maxf(scan_rate_hz, 0.1)
		refresh_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_INTERACT):
		if try_interact().get("handled", false):
			get_viewport().set_input_as_handled()


func get_focused() -> Node:
	return _focused


## Atualiza o alvo em foco imediatamente.
func refresh_focus() -> void:
	var target: Node = find_nearest() if enabled else null
	var prompt := ""
	if target != null:
		prompt = target.get_interaction_prompt()
	if target != _focused or prompt != _last_prompt:
		_focused = target
		_last_prompt = prompt
		focus_changed.emit(target, prompt)


## Interage com o alvo mais próximo. Devolve {"handled": bool, "ok": bool, "message": String}.
func try_interact() -> Dictionary:
	if not enabled:
		return {"handled": false}
	refresh_focus()
	if _focused == null:
		return {"handled": false}
	var result: Dictionary = _focused.interact(self)
	result["handled"] = true
	interacted.emit(_focused, result)
	refresh_focus()
	return result


## Interativo mais próximo dentro do alcance, ou null.
func find_nearest() -> Node:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = interaction_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = interactable_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var best: Node = null
	var best_distance := INF
	for hit in space.intersect_shape(query, 16):
		var node: Node = hit.get("collider")
		if node == null or not node.has_method("interact") or not node.has_method("can_interact"):
			continue
		if not node.can_interact(self):
			continue
		var distance := global_position.distance_to((node as Node3D).global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best
