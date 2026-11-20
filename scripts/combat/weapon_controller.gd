class_name WeaponController
extends Node3D
## Golpe corpo a corpo do jogador (WLD-013). Fica dentro de Player/Visual, então a clava
## acompanha para onde o personagem olha (o modelo olha para -Z).
##
## O golpe é uma consulta de forma no instante ativo, nunca uma área permanente.
## A ação "attack" é lida por evento (_unhandled_input): o clique que recaptura o
## mouse não golpeia (risco R-PW-01).

signal swung
signal hit(target: Node, damage: float)
## Golpe de ferramenta acertou uma árvore ou pedra (machado, picareta).
signal tool_struck(target: Node, result: Dictionary)

const ACTION_ATTACK := &"attack"
const CAUSE_PREFIX := "player:"

@export var definition: WeaponDefinition
@export var player: CharacterBody3D
@export var health: HealthComponent
@export_flags_3d_physics var enemy_mask: int = 8
## Quem coleta (inventário e item na mão) nos golpes de ferramenta.
@export var interaction: InteractionDetector
## Camada das árvores e fontes de recurso.
@export_flags_3d_physics var resource_mask: int = 4

@onready var club: Node3D = $Club

var cooldown_left := 0.0
var _phase := 0  # 0 parado, 1 preparação, 2 ativo, 3 recuperação
var _phase_left := 0.0
var _hit_this_swing: Array = []
## Para testes e ferramentas: ignora a checagem de mouse capturado.
var require_captured_mouse := true
## Gira a clava no código durante o golpe. Falso quando um personagem animado
## segura a arma (a animação faz o movimento).
var procedural_swing := true


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _phase == 0:
		return
	_phase_left -= delta
	match _phase:
		1:
			if procedural_swing:
				club.rotation.x = lerpf(club.rotation.x, 1.2, 0.5)
			if _phase_left <= 0.0:
				_phase = 2
				_phase_left = definition.active_time
				strike()
		2:
			if procedural_swing:
				club.rotation.x = lerpf(club.rotation.x, -1.3, 0.6)
			if _phase_left <= 0.0:
				_phase = 3
				_phase_left = maxf(definition.interval - definition.windup - definition.active_time, 0.05)
		3:
			if procedural_swing:
				club.rotation.x = lerpf(club.rotation.x, 0.0, 0.25)
			if _phase_left <= 0.0:
				_phase = 0
				if procedural_swing:
					club.rotation.x = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_ATTACK):
		return
	if require_captured_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return  # o clique é da câmera (recapturar o mouse)
	if try_attack():
		get_viewport().set_input_as_handled()


func is_swinging() -> bool:
	return _phase != 0


## Começa um golpe se puder. Devolve false se em recarga, morto ou sem arma.
func try_attack() -> bool:
	if definition == null or cooldown_left > 0.0 or _phase != 0:
		return false
	if health != null and health.is_dead():
		return false
	cooldown_left = definition.interval
	_assist_aim()
	_phase = 1
	_phase_left = definition.windup
	_hit_this_swing.clear()
	swung.emit()
	return true


## Instante ativo: acerta todo alvo no arco à frente, até o alcance. Devolve quantos acertou.
func strike() -> int:
	var count := 0
	for target in targets_in_arc(definition.reach, definition.arc_degrees):
		if _hit_this_swing.has(target):
			continue
		_hit_this_swing.append(target)
		var info := DamageInfo.create(definition.damage, StringName(CAUSE_PREFIX + String(definition.id)), &"physical", player)
		var applied: float = target.receive_damage(info)
		if applied > 0.0:
			count += 1
			if target.has_method("apply_knockback"):
				target.apply_knockback(forward() * definition.knockback)
			hit.emit(target, applied)
	if count == 0:
		tool_strike()
	return count


## Machado ou picareta na mão: acerta a árvore/pedra à frente. Devolve o resultado.
func tool_strike() -> Dictionary:
	if definition == null or (definition.chop_power <= 0 and definition.mine_power <= 0):
		return {}
	var target := tool_target()
	if target == null:
		return {}
	var result: Dictionary = target.tool_strike(interaction, definition)
	tool_struck.emit(target, result)
	if interaction != null and result.get("message", "") != "":
		interaction.interacted.emit(target, result)  # HUD, XP e animação reagem como numa coleta
	if result.get("ok", false):
		_spawn_chips(target, result.get("item_id", &"") == &"stone" or target.get("category") == &"stone")
	return result


## A árvore ou fonte de recurso mais próxima à frente que aceita a ferramenta na mão.
func tool_target() -> Node3D:
	var origin := _origin()
	var shape := SphereShape3D.new()
	shape.radius = definition.reach + 0.8
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = resource_mask
	var best: Node3D = null
	var best_distance := INF
	var fwd := forward()
	for hit_data in get_world_3d().direct_space_state.intersect_shape(params, 24):
		var node := hit_data["collider"] as Node3D
		if node == null or not node.has_method("tool_strike") or not node.accepts_tool(definition):
			continue
		var to := node.global_position - origin
		to.y = 0.0
		if to.length() - 0.45 > definition.reach:
			continue
		if to.length() > 0.3 and rad_to_deg(fwd.angle_to(to.normalized())) > 60.0:
			continue
		if to.length() < best_distance:
			best = node
			best_distance = to.length()
	return best


func _spawn_chips(target: Node3D, stone: bool) -> void:
	var chips := CPUParticles3D.new()
	chips.one_shot = true
	chips.emitting = false
	chips.amount = 14
	chips.lifetime = 0.7
	chips.explosiveness = 0.95
	chips.direction = Vector3(0, 1, 0)
	chips.spread = 70.0
	chips.initial_velocity_min = 2.0
	chips.initial_velocity_max = 4.5
	chips.gravity = Vector3(0, -12, 0)
	chips.scale_amount_min = 0.05
	chips.scale_amount_max = 0.11
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.62, 0.65) if stone else Color(0.72, 0.52, 0.3)
	mesh.material = mat
	chips.mesh = mesh
	var holder: Node = get_tree().current_scene if get_tree().current_scene != null else target.get_parent()
	holder.add_child(chips)
	var toward := (_origin() - target.global_position)
	toward.y = 0.0
	chips.global_position = target.global_position + toward.normalized() * 0.4 + Vector3(0, 1.0, 0)
	chips.emitting = true
	get_tree().create_timer(1.2).timeout.connect(chips.queue_free)


## Direção para onde o personagem olha (plano horizontal).
func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


## Alvos atingíveis (com receive_damage) dentro do alcance e do arco à frente.
func targets_in_arc(reach: float, arc_degrees: float) -> Array:
	var origin := _origin()
	var shape := SphereShape3D.new()
	shape.radius = reach + 0.6  # margem para o corpo do alvo
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = enemy_mask
	var result := []
	var fwd := forward()
	for hit_data in get_world_3d().direct_space_state.intersect_shape(params, 16):
		var node: Node = hit_data["collider"]
		if node == null or not node.has_method("receive_damage") or result.has(node):
			continue
		var to: Vector3 = (node as Node3D).global_position - origin
		to.y = 0.0
		var radius: float = node.body_radius() if node.has_method("body_radius") else 0.5
		if to.length() - radius > reach:
			continue
		if to.length() > 0.3 and rad_to_deg(fwd.angle_to(to.normalized())) > arc_degrees * 0.5:
			continue
		result.append(node)
	return result


func _assist_aim() -> void:
	var best: Node3D = null
	var best_distance := INF
	for node in targets_in_arc(definition.assist_distance, definition.assist_cone_degrees):
		var d := _origin().distance_to((node as Node3D).global_position)
		if d < best_distance:
			best = node
			best_distance = d
	if best == null:
		return
	var to := best.global_position - _origin()
	var visual := get_parent() as Node3D
	if visual != null and Vector2(to.x, to.z).length() > 0.05:
		visual.rotation.y = atan2(-to.x, -to.z)


func _origin() -> Vector3:
	var p := player.global_position if player != null else global_position
	return Vector3(p.x, p.y, p.z)
