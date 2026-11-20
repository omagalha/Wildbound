class_name HostileCreature
extends CharacterBody3D
## Criatura hostil do MVP (Javali Espinhoso). Vive num ninho dentro de uma zona de atenção;
## vê o jogador a 18 m, bufa (aviso), investe em linha reta e fica atordoado depois —
## é a janela para revidar. Perto, morde. Nunca entra em zona segura nem ataca construções.

signal state_changed(state: int)
signal attacked_player(damage: float, kind: StringName)
signal died_enemy(enemy: HostileCreature)
signal respawned

enum State { IDLE, CHASE, TELEGRAPH, CHARGE, BITE, RECOVER, RETURN, DEAD }

const STATE_NAMES := ["Vagando", "Perseguindo", "Bufando", "Investindo", "Mordendo", "Atordoado", "Voltando", "Morto"]

@export var definition: EnemyDefinition
@export var player: CharacterBody3D
## Multiplicadores do preset de dificuldade (aplicados pelo DifficultyManager).
@export var damage_multiplier: float = 1.0
@export var health_multiplier: float = 1.0
## Segundos ignorando o jogador depois de entrar na cena (carregamento — TR08).
@export var startup_grace: float = 1.5
@export var rng_seed: int = 0

@onready var health: HealthComponent = $Health
@onready var visual: Node3D = $Visual
@onready var label: Label3D = $Label
@onready var _collision: CollisionShape3D = $CollisionShape3D

var state: int = State.IDLE
var home := Vector3.ZERO
var _state_time := 0.0
var _target := Vector3.ZERO
var _has_target := false
var _pause_left := 0.0
var _charge_dir := Vector3.ZERO
var _charge_duration := 0.0
var _hit_done := false
var _recover_duration := 0.0
var _lost_time := 0.0
var _grace_left := 0.0
var _knockback := Vector3.ZERO
var _label_left := 0.0
var _flash_left := 0.0
var _respawn_left := 0.0
var _rng := RandomNumberGenerator.new()
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []


func _ready() -> void:
	home = global_position
	_grace_left = startup_grace
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	apply_multipliers(damage_multiplier, health_multiplier)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		var m := (mesh as MeshInstance3D).mesh
		if m != null and m.surface_get_material(0) is StandardMaterial3D:
			var mat := (m.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			(mesh as MeshInstance3D).material_override = mat
			_materials.append(mat)
			_base_colors.append(mat.albedo_color)
	label.text = ""


## Vida e dano conforme a dificuldade. Mantém a proporção de vida atual.
func apply_multipliers(damage_mult: float, health_mult: float) -> void:
	damage_multiplier = damage_mult
	health_multiplier = health_mult
	if health == null or definition == null:
		return
	var ratio := health.ratio() if health.current_health > 0.0 else 1.0
	health.max_health = definition.max_health * health_mult
	if not health.is_dead():
		health.current_health = maxf(health.max_health * ratio, 1.0)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_grace_left = maxf(_grace_left - delta, 0.0)
	_tick_feedback(delta)
	if state == State.DEAD:
		_do_dead(delta)
		return
	match state:
		State.IDLE: _do_idle(delta)
		State.CHASE: _do_chase(delta)
		State.TELEGRAPH: _do_telegraph()
		State.CHARGE: _do_charge()
		State.BITE: _do_bite()
		State.RECOVER: _do_recover()
		State.RETURN: _do_return()
	if _knockback.length() > 0.05:
		velocity.x += _knockback.x
		velocity.z += _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
	move_and_slide()


# ---------- consultas ----------

func state_name() -> String:
	return STATE_NAMES[state]


func is_dead() -> bool:
	return state == State.DEAD


func body_radius() -> float:
	return 0.6


func distance_to_player() -> float:
	return _flat(player.global_position - global_position).length() if player != null else INF


## O jogador pode ser perseguido agora? (vivo, fora de zona segura, perto do ninho)
func player_huntable() -> bool:
	if player == null or _grace_left > 0.0:
		return false
	var player_health := player.get_node_or_null("Health") as HealthComponent
	if player_health != null and (player_health.is_dead() or not player_health.accepts_damage):
		return false
	if TerritoryZone.is_safe(get_tree(), player.global_position):
		return false
	return _flat(player.global_position - home).length() <= definition.leash_radius


func can_see_player() -> bool:
	return player_huntable() and distance_to_player() <= definition.perception_radius


# ---------- dano recebido ----------

## Entrada do pacote de dano (contrato usado pela arma e pelas habilidades).
func receive_damage(info: DamageInfo) -> float:
	if state == State.DEAD:
		return 0.0
	return health.apply_damage(info)


func apply_knockback(impulse: Vector3) -> void:
	if state != State.DEAD:
		_knockback = _flat(impulse)


func _on_damaged(info: DamageInfo) -> void:
	_flash_left = 0.15
	_show_label("-%d" % roundi(info.amount), 0.8)
	# Provocado: reage mesmo que não tenha visto o jogador.
	if state in [State.IDLE, State.RETURN] and player != null and not TerritoryZone.is_safe(get_tree(), player.global_position):
		_set_state(State.TELEGRAPH)


func _on_died(_cause: StringName) -> void:
	_set_state(State.DEAD)
	_respawn_left = definition.respawn_time
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_show_label("✖", 2.0)
	_drop_loot()
	died_enemy.emit(self)


## Deixa os itens da definição no chão, onde morreu (carne do javali).
func _drop_loot() -> void:
	if definition == null or definition.loot.is_empty() or not is_inside_tree():
		return
	var drop := LootDrop.new()
	drop.items = definition.loot.duplicate()
	drop.label = "%s abatido" % definition.display_name
	# Fora do nó de inimigos: o limite de hostis ativos conta os filhos dele.
	var holder := get_parent().get_parent() if get_parent().get_parent() != null else get_parent()
	holder.add_child(drop)
	drop.global_position = global_position


## Volta ao ninho com vida cheia (fim do tempo de reaparecimento, ou testes).
func respawn_now() -> void:
	global_position = home
	velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	visual.visible = true
	_collision.set_deferred("disabled", false)
	health.revive(health.max_health)
	_grace_left = startup_grace
	_set_state(State.IDLE)
	respawned.emit()


# ---------- estados ----------

func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	_state_time = 0.0
	_has_target = false
	_hit_done = false
	match state:
		State.TELEGRAPH: _show_label("!", definition.telegraph_time)
		State.BITE: _show_label("!", definition.bite_windup)
	state_changed.emit(state)


func _do_idle(delta: float) -> void:
	if can_see_player():
		_lost_time = 0.0
		_set_state(State.TELEGRAPH if distance_to_player() <= 12.0 else State.CHASE)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_brake()
		return
	if not _has_target:
		var angle := _rng.randf() * TAU
		_target = home + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(1.0, definition.home_radius)
		_has_target = true
	if _move_towards(_target, definition.wander_speed, 0.5) or is_on_wall():
		_has_target = false
		_pause_left = _rng.randf_range(2.0, 5.0)


func _do_chase(delta: float) -> void:
	if not _keep_hunting(delta):
		return
	var d := distance_to_player()
	if d <= 10.0:
		_set_state(State.BITE if d <= definition.bite_range else State.TELEGRAPH)
		return
	_move_towards(player.global_position, definition.chase_speed, 0.5)


func _do_telegraph() -> void:
	_brake()
	if player != null:
		_face(player.global_position, 0.35)
	# Raspa o chão: tremidinha no visual.
	visual.position.x = sin(_state_time * 60.0) * 0.03
	if _state_time < definition.telegraph_time:
		return
	visual.position.x = 0.0
	if not player_huntable():
		_set_state(State.RETURN)
		return
	var d := distance_to_player()
	if d <= definition.bite_range:
		_set_state(State.BITE)
		return
	_charge_dir = _flat(player.global_position - global_position).normalized()
	_charge_duration = minf(d / definition.charge_speed + 0.35, definition.charge_max_time)
	_set_state(State.CHARGE)


func _do_charge() -> void:
	velocity.x = _charge_dir.x * definition.charge_speed
	velocity.z = _charge_dir.z * definition.charge_speed
	_face(global_position + _charge_dir, 1.0)
	if not _hit_done and player != null and distance_to_player() <= definition.charge_hit_radius:
		_hit_done = true
		_hurt_player(definition.charge_damage, &"charge")
		_recover(definition.recover_time)
		return
	if is_on_wall() and _state_time > 0.1:
		_show_label("✶", definition.wall_stun_time)
		_recover(definition.wall_stun_time)
		return
	if _state_time >= _charge_duration:
		_recover(definition.recover_time)


func _do_bite() -> void:
	_brake()
	if player != null:
		_face(player.global_position, 0.3)
	if _state_time < definition.bite_windup:
		return
	if player_huntable() and distance_to_player() <= definition.bite_range:
		var to := _flat(player.global_position - global_position).normalized()
		if _facing().angle_to(to) <= deg_to_rad(70.0):
			_hurt_player(definition.bite_damage, &"bite")
	_recover(0.6)


func _do_recover() -> void:
	_brake()
	visual.rotation.z = sin(_state_time * 8.0) * 0.08
	if _state_time < _recover_duration:
		return
	visual.rotation.z = 0.0
	if player_huntable() and distance_to_player() <= definition.perception_radius * 1.5:
		_lost_time = 0.0
		var d := distance_to_player()
		_set_state(State.BITE if d <= definition.bite_range else (State.TELEGRAPH if d <= 12.0 else State.CHASE))
	else:
		_set_state(State.RETURN)


func _do_return() -> void:
	if can_see_player() and _flat(global_position - home).length() < definition.leash_radius * 0.8:
		_set_state(State.TELEGRAPH)
		return
	if _move_towards(home, definition.chase_speed * 0.7, 0.8):
		health.heal(health.max_health)  # esquece a briga ao voltar ao ninho
		_set_state(State.IDLE)


func _do_dead(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	visual.rotation.z = lerpf(visual.rotation.z, PI * 0.5, 0.15)
	if _state_time > 3.0:
		visual.visible = false
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		respawn_now()
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()


## Continua caçando? Senão, volta ao ninho.
func _keep_hunting(delta: float) -> bool:
	if not player_huntable() or _flat(global_position - home).length() > definition.leash_radius:
		_set_state(State.RETURN)
		return false
	if distance_to_player() > definition.perception_radius * 1.5:
		_lost_time += delta
		if _lost_time >= definition.forget_time:
			_set_state(State.RETURN)
			return false
	else:
		_lost_time = 0.0
	return true


func _recover(duration: float) -> void:
	_recover_duration = duration
	_set_state(State.RECOVER)


func _hurt_player(amount: float, kind: StringName) -> void:
	var player_health := player.get_node_or_null("Health") as HealthComponent
	if player_health == null:
		return
	var info := DamageInfo.create(amount * damage_multiplier, StringName("enemy:" + String(definition.species_id)), &"physical", self)
	var applied := player_health.apply_damage(info)
	if applied > 0.0:
		attacked_player.emit(applied, kind)


# ---------- movimento e efeitos ----------

func _move_towards(point: Vector3, speed: float, arrive_radius: float) -> bool:
	var to := _flat(point - global_position)
	if to.length() <= arrive_radius:
		_brake()
		return true
	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(global_position + dir, 0.2)
	return false


func _brake() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1.0)
	velocity.z = move_toward(velocity.z, 0.0, 1.0)


## O modelo olha para +Z.
func _face(point: Vector3, weight: float) -> void:
	var to := _flat(point - global_position)
	if to.length() < 0.05:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), weight)


func _facing() -> Vector3:
	return Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))


func _tick_feedback(delta: float) -> void:
	if _label_left > 0.0:
		_label_left -= delta
		if _label_left <= 0.0:
			label.text = ""
	if _flash_left > 0.0:
		_flash_left -= delta
		for i in _materials.size():
			_materials[i].albedo_color = Color(1, 1, 1) if _flash_left > 0.0 else _base_colors[i]


func _show_label(text: String, duration: float) -> void:
	label.text = text
	_label_left = duration


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
