class_name CreatureController
extends CharacterBody3D
## Criatura domável: estados selvagens (vagar, alerta, fuga, comendo) e de companheiro
## (vínculo, seguir, ficar). Movimento direto, sem navegação (terreno plano do MVP).
##
## É um interativo (camada 3): selvagem → oferecer comida; companheiro → Seguir/Ficar.

signal state_changed(state: int)
signal order_changed(following: bool)
signal emote(text: String)

enum State { IDLE, ALERT, SCARED, EATING, BONDED, FOLLOWING, STAYING }

const STATE_NAMES := ["Vagando", "Atento", "Assustado", "Comendo", "Vinculado", "Seguindo", "Parado"]

@export var definition: CreatureDefinition
@export var player: CharacterBody3D
@export var knowledge: KnowledgeManager
@export var experience: ExperienceComponent
@export var respawn: SimpleRespawn
## Semente fixa deixa o passeio reproduzível nos testes; 0 = aleatório.
@export var rng_seed: int = 0

@onready var taming: TamingComponent = $Taming
@onready var visual: Node3D = $Visual
@onready var emote_label: Label3D = $Emote

var state: int = State.IDLE
var home := Vector3.ZERO
var _target := Vector3.ZERO
var _has_target := false
var _state_time := 0.0
var _pause_left := 0.0
var _emote_left := 0.0
var _far_time := 0.0
var _stuck_time := 0.0
var _stuck_from := Vector3.ZERO
var _bob := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	home = global_position
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	taming.profile = definition.taming
	taming.scared.connect(_on_scared)
	taming.fed.connect(_on_fed)
	taming.feed_rejected.connect(_on_feed_rejected)
	taming.bond_completed.connect(_on_bond_completed)
	if respawn != null:
		respawn.player_respawned.connect(_on_player_respawned)
	emote_label.text = ""


func _physics_process(delta: float) -> void:
	_state_time += delta
	if _emote_left > 0.0:
		_emote_left -= delta
		if _emote_left <= 0.0:
			emote_label.text = ""
	if is_wild():
		taming.tick(delta, is_player_aggressive())
	_update_state(delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
	move_and_slide()
	_animate(delta)


# ---------- consultas ----------

func is_wild() -> bool:
	return state <= State.EATING


func is_companion() -> bool:
	return state >= State.BONDED


func is_following() -> bool:
	return state == State.FOLLOWING


func state_name() -> String:
	return STATE_NAMES[state]


func distance_to_player() -> float:
	return global_position.distance_to(player.global_position) if player != null else INF


## Jogador correndo (acima da caminhada) dentro do raio de alerta.
func is_player_aggressive() -> bool:
	if player == null or definition.taming == null:
		return false
	if distance_to_player() > definition.taming.alert_radius:
		return false
	var walk: float = player.get("walk_speed") if player.get("walk_speed") != null else 5.0
	return Vector2(player.velocity.x, player.velocity.z).length() > walk + 0.5


func requirements_ok() -> bool:
	return knowledge == null or knowledge.is_known(definition.required_knowledge)


# ---------- contrato de interativo ----------

func get_interaction_prompt() -> String:
	if is_companion():
		return "%s: %s" % [definition.display_name, "Ficar aqui" if state != State.STAYING else "Me seguir"]
	var food := taming.food_in(player.get_node_or_null("Inventory") if player != null else null)
	var label := "frutas" if food == &"" or food == &"wild_berries" else String(food)
	return "Oferecer %s ao %s (%d%%)" % [label, definition.display_name, roundi(taming.trust)]


func can_interact(_interactor: InteractionDetector) -> bool:
	return state != State.BONDED


func interact(interactor: InteractionDetector) -> Dictionary:
	if is_companion():
		set_following(state == State.STAYING)
		var text := "%s vai te seguir" % definition.display_name if is_following() else "%s vai ficar aqui" % definition.display_name
		return {"ok": true, "message": text}
	var inventory: Inventory = interactor.inventory if interactor != null else null
	var distance := global_position.distance_to(interactor.global_position) - _body_radius() if interactor != null else INF
	var result := taming.try_feed(inventory, maxf(distance, 0.0), requirements_ok())
	if result["ok"]:
		if result.get("bonded", false):
			result["message"] = "%s confia em você!" % definition.display_name
		else:
			result["message"] = "%s comeu! Confiança %d%%" % [definition.display_name, roundi(taming.trust)]
	else:
		result["message"] = reject_message(result["reason"])
	return result


func reject_message(reason: StringName) -> String:
	match reason:
		TamingComponent.REASON_NO_ITEM: return "%s gosta de frutas silvestres" % definition.display_name
		TamingComponent.REASON_COOLDOWN: return "Ainda está mastigando… espere um pouco"
		TamingComponent.REASON_SCARED: return "Está assustado — fique parado ou ande devagar"
		TamingComponent.REASON_TOO_FAR: return "Chegue mais perto"
		TamingComponent.REASON_REQUIREMENTS: return "Você ainda não sabe criar vínculos"
	return "Não aceitou"


# ---------- ordens de companheiro ----------

func set_following(follow: bool) -> void:
	if not is_companion():
		return
	_set_state(State.FOLLOWING if follow else State.STAYING)
	order_changed.emit(follow)


## Reposiciona 3–5 m atrás do jogador, num ponto com chão.
func recover_to_player() -> void:
	if player == null:
		return
	var back := player.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	for dist in [4.0, 3.0, 5.0]:
		for angle in [0.0, 0.6, -0.6, 1.2, -1.2]:
			var spot: Vector3 = player.global_position + back.rotated(Vector3.UP, angle) * dist
			var ground: Variant = _ground_at(spot)
			if ground != null:
				_teleport(ground)
				return
	_teleport(player.global_position + back * 3.0)


# ---------- estados ----------

func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	_state_time = 0.0
	_has_target = false
	_far_time = 0.0
	_stuck_time = 0.0
	_stuck_from = global_position
	match state:
		State.ALERT: show_emote("?", 1.2)
		State.SCARED: show_emote("!", 2.0)
	state_changed.emit(state)


func _update_state(delta: float) -> void:
	match state:
		State.IDLE: _do_idle(delta)
		State.ALERT: _do_alert()
		State.SCARED: _do_scared()
		State.EATING: _do_eating()
		State.BONDED: _do_bonded()
		State.FOLLOWING: _do_following(delta)
		State.STAYING: _stop()


func _do_idle(delta: float) -> void:
	if taming.is_fleeing():
		_set_state(State.SCARED)
		return
	if distance_to_player() <= definition.taming.alert_radius:
		_set_state(State.ALERT)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_stop()
		return
	if not _has_target:
		var angle := _rng.randf() * TAU
		_target = home + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(1.0, definition.home_radius)
		_has_target = true
	if _move_towards(_target, definition.walk_speed, 0.4) or is_on_wall():
		_has_target = false
		_pause_left = _rng.randf_range(1.5, 4.0)


func _do_alert() -> void:
	if taming.is_fleeing():
		_set_state(State.SCARED)
		return
	if distance_to_player() > definition.taming.alert_radius + 1.0:
		_set_state(State.IDLE)
		return
	_stop()
	_face(player.global_position)


func _do_scared() -> void:
	if not _has_target:
		var away := global_position - player.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		var spot := global_position + away * definition.flee_distance
		var from_home := spot - home
		from_home.y = 0.0
		if from_home.length() > definition.flee_max_from_home:
			spot = home + from_home.normalized() * definition.flee_max_from_home
		_target = Vector3(spot.x, global_position.y, spot.z)
		_has_target = true
	var arrived := _move_towards(_target, definition.flee_speed, 0.6) or (is_on_wall() and _state_time > 0.5)
	if arrived:
		_stop()
		if not taming.is_fleeing():
			_set_state(State.IDLE)


func _do_eating() -> void:
	_stop()
	if _state_time >= 1.5:
		_set_state(State.BONDED if taming.bonded else State.ALERT)


func _do_bonded() -> void:
	_stop()
	if player != null:
		_face(player.global_position)
	if _state_time >= 1.5:
		_set_state(State.FOLLOWING)
		order_changed.emit(true)


func _do_following(delta: float) -> void:
	if player == null:
		return
	var distance := distance_to_player()
	if distance > definition.recover_distance:
		_far_time += delta
		if _far_time >= 2.0:
			recover_to_player()
			return
	else:
		_far_time = 0.0
	var walk: float = player.get("walk_speed") if player.get("walk_speed") != null else 5.0
	var sprint: float = player.get("sprint_speed") if player.get("sprint_speed") != null else 8.5
	var moving := distance > definition.follow_start_distance or (_has_target and distance > definition.follow_stop_distance)
	if moving:
		_has_target = true
		var speed := sprint * 1.1 if distance > 6.0 else walk
		_move_towards(player.global_position, speed, definition.follow_stop_distance)
		# Preso: tentando seguir e quase sem sair do lugar por 3 s.
		_stuck_time += delta
		if _stuck_time >= 3.0:
			if global_position.distance_to(_stuck_from) < 0.5:
				recover_to_player()
			_stuck_time = 0.0
			_stuck_from = global_position
	else:
		_has_target = false
		_stuck_time = 0.0
		_stuck_from = global_position
		_stop()
		_face(player.global_position)


# ---------- reações ----------

func _on_scared() -> void:
	if is_wild():
		_set_state(State.SCARED)


func _on_fed(_food: StringName, _gain: float) -> void:
	_set_state(State.EATING)
	show_emote("♥", 1.5)


func _on_feed_rejected(reason: StringName) -> void:
	if reason == TamingComponent.REASON_SCARED:
		show_emote("!", 1.0)
	elif reason == TamingComponent.REASON_COOLDOWN:
		show_emote("…", 1.0)


func _on_bond_completed() -> void:
	show_emote("♥ ♥ ♥", 2.5)
	if experience != null and experience.rules != null:
		experience.award_first(&"tame", definition.species_id, experience.rules.tame_species_xp)


func _on_player_respawned() -> void:
	if is_following():
		recover_to_player()


func show_emote(text: String, duration: float) -> void:
	emote_label.text = text
	_emote_left = duration
	emote.emit(text)


# ---------- save ----------

## Só companheiros guardam estado (selvagens recomeçam do zero no MVP).
func get_save_data() -> Dictionary:
	if not is_companion():
		return {}
	var p := global_position
	return {"species": String(definition.species_id), "following": state != State.STAYING, "position": [p.x, p.y, p.z]}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	taming.force_bonded()
	var p: Array = data.get("position", [])
	if p.size() == 3:
		_teleport(Vector3(float(p[0]), float(p[1]), float(p[2])))
	_set_state(State.FOLLOWING if data.get("following", true) else State.STAYING)


# ---------- movimento ----------

func _move_towards(point: Vector3, speed: float, arrive_radius: float) -> bool:
	var to := point - global_position
	to.y = 0.0
	if to.length() <= arrive_radius:
		_stop()
		return true
	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(global_position + dir)
	return false


func _stop() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.5)
	velocity.z = move_toward(velocity.z, 0.0, 0.5)


func _face(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var target_yaw := atan2(to.x, to.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 0.2)


## Animação pedida ao CreatureModel.
func get_anim_state() -> String:
	var speed := Vector2(velocity.x, velocity.z).length()
	match state:
		State.EATING: return "eat"
		State.SCARED: return "run"
		State.ALERT: return "alert"
		State.BONDED: return "happy"
	if speed > 3.0:
		return "run"
	return "walk" if speed > 0.2 else "idle"


func _animate(delta: float) -> void:
	if visual.has_node("Model"):
		return  # o modelo animado cuida disso
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.2:
		_bob += delta * (8.0 + speed * 1.5)
		visual.position.y = absf(sin(_bob)) * 0.12
	elif state == State.EATING or state == State.BONDED:
		_bob += delta * 10.0
		visual.position.y = absf(sin(_bob)) * 0.08
	else:
		visual.position.y = move_toward(visual.position.y, 0.0, delta)


func _teleport(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	_stuck_from = point
	_far_time = 0.0


func _ground_at(point: Vector3) -> Variant:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point + Vector3.DOWN * 4.0, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"] + Vector3.UP * 0.05


func _body_radius() -> float:
	return 0.45
