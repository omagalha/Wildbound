class_name AbilityController
extends Node
## Habilidades ancestrais: 2 espaços ([Q] e [R]), energia compartilhada e
## recarga por habilidade (ANCESTRAL_POWERS.md 5–6).
##
## Ordem de validação: espaço com habilidade, desbloqueada, viva, recarga,
## energia, condição própria (Pulso Vital pede vida abaixo do máximo). Recusa
## nunca gasta energia nem inicia recarga. Desbloqueios ficam no
## KnowledgeManager como "ability_<id>" (então vão para o save sozinhos).
## Também desenha a barra de energia e os dois espaços no canto da tela.

signal ability_used(id: StringName)
signal ability_failed(id: StringName, reason: StringName)
signal ability_unlocked(id: StringName)

const READY := &"ok"
const EMPTY := &"empty"
const LOCKED := &"locked"
const DEAD := &"dead"
const COOLDOWN := &"cooldown"
const NO_ENERGY := &"no_energy"
const FULL_HEALTH := &"full_health"
const BUSY := &"busy"
const SLOT_COUNT := 2
const ACTIONS := [&"ability_1", &"ability_2"]
const KEYS := ["Q", "R"]
const FAIL_TEXT := {
	&"locked": "Habilidade ainda não desbloqueada",
	&"empty": "Nenhuma habilidade neste espaço",
	&"cooldown": "Recarregando",
	&"no_energy": "Sem energia",
	&"full_health": "Vida cheia",
}

@export var definitions: Array[AbilityDefinition] = []
@export var energy: EnergyComponent
@export var player: CharacterBody3D
@export var health: HealthComponent
@export var knowledge: KnowledgeManager
@export var camera: Camera3D
@export var animator: CharacterAnimator
@export var placement: PlacementController
@export var save_manager: SaveManager
@export var hud: SurvivalHUD
@export var respawn: SimpleRespawn
@export var show_bar: bool = true

var slots: Array[StringName] = [&"vital_pulse", &""]
var cooldowns := {}  # id -> segundos restantes
var last_projectile: SparkProjectile

var _ui_slots: Array[Dictionary] = []
var _energy_bar: ProgressBar
var _energy_label: Label


func _ready() -> void:
	if knowledge != null:
		knowledge.knowledge_learned.connect(func(_id, _o): sync_slots())
	if save_manager != null:
		save_manager.load_status.connect(func(_s): sync_slots())
	if show_bar:
		_build_ui()
	if energy != null:
		energy.energy_changed.connect(func(_c, _m): _refresh_ui())
	if respawn != null and energy != null:
		respawn.player_respawned.connect(func(): energy.refill(0.75); cooldowns.clear())
	sync_slots()


func _physics_process(delta: float) -> void:
	for id in cooldowns.keys():
		cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	for i in SLOT_COUNT:
		if event.is_action_pressed(ACTIONS[i]):
			if placement != null and placement.active:
				return  # [R] gira a peça no modo de construção
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
				return  # com menu aberto
			use_slot(i)
			get_viewport().set_input_as_handled()
			return


func get_definition(id: StringName) -> AbilityDefinition:
	for def in definitions:
		if def != null and def.id == id:
			return def
	return null


func is_unlocked(id: StringName) -> bool:
	var def := get_definition(id)
	if def == null:
		return false
	return def.starts_unlocked or (knowledge != null and knowledge.is_known(StringName("ability_" + String(id))))


## Libera uma habilidade para sempre e a coloca no primeiro espaço livre.
func unlock(id: StringName) -> bool:
	if get_definition(id) == null or is_unlocked(id):
		return false
	if knowledge != null:
		knowledge.learn(StringName("ability_" + String(id)), &"challenge")
	sync_slots()
	ability_unlocked.emit(id)
	return true


## Habilidades liberadas e fora dos espaços entram nos espaços livres.
func sync_slots() -> void:
	for def in definitions:
		if def != null and is_unlocked(def.id) and not slots.has(def.id):
			var free := slots.find(&"")
			if free >= 0:
				slots[free] = def.id
	_refresh_ui()


## Motivo pelo qual o espaço pode (READY) ou não pode ser usado agora.
func status(slot: int) -> StringName:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot] == &"":
		return EMPTY
	var def := get_definition(slots[slot])
	if def == null or not is_unlocked(def.id):
		return LOCKED
	if health != null and health.is_dead():
		return DEAD
	if cooldowns.get(def.id, 0.0) > 0.0:
		return COOLDOWN
	if energy == null or not energy.has(def.energy_cost):
		return NO_ENERGY
	if def.effect == &"heal" and health != null and health.current_health >= health.max_health:
		return FULL_HEALTH
	return READY


## Usa o espaço. Devolve o motivo (READY se usou).
func use_slot(slot: int) -> StringName:
	var reason := status(slot)
	var id: StringName = slots[slot] if slot >= 0 and slot < SLOT_COUNT else &""
	if reason != READY:
		ability_failed.emit(id, reason)
		if hud != null and FAIL_TEXT.has(reason):
			hud.show_message(FAIL_TEXT[reason], 1.2)
		return reason
	var def := get_definition(id)
	energy.spend(def.energy_cost)
	cooldowns[id] = def.cooldown
	match def.effect:
		&"heal":
			_cast_heal(def)
		&"projectile":
			_cast_projectile(def)
	if animator != null:
		animator.play_cast()
	ability_used.emit(id)
	return READY


func cooldown_left(id: StringName) -> float:
	return cooldowns.get(id, 0.0)


# ---------- efeitos ----------

func _cast_heal(def: AbilityDefinition) -> void:
	var healed := health.heal(def.power) if health != null else 0.0
	if hud != null:
		hud.show_message("%s: +%d de vida" % [def.display_name, roundi(healed)], 1.5)
	if player != null:
		_spawn_ring(player.global_position + Vector3(0, 0.1, 0), def.color)


func _cast_projectile(def: AbilityDefinition) -> void:
	if player == null:
		return
	var dir := aim_direction(def.projectile_range)
	var visual := player.get("visual") as Node3D
	if visual != null:
		visual.rotation.y = atan2(-dir.x, -dir.z)
	var spark := SparkProjectile.new()
	spark.direction = dir
	spark.speed = def.projectile_speed
	spark.max_range = def.projectile_range
	spark.damage = def.power
	spark.color = def.color
	spark.source = player
	player.get_parent().add_child(spark)
	spark.global_position = player.global_position + Vector3(0, 1.3, 0) + dir * 0.6
	last_projectile = spark


## Direção do disparo: para onde a câmera olha (no plano), com ajuda de mira
## para a criatura hostil mais próxima num cone de 15°.
func aim_direction(max_range: float) -> Vector3:
	var forward := Vector3.FORWARD
	if camera != null:
		forward = -camera.global_transform.basis.z
	elif player != null and player.get("visual") != null:
		forward = -(player.get("visual") as Node3D).global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"hostiles"):
		var enemy := node as Node3D
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var to := enemy.global_position - player.global_position
		to.y = 0.0
		if to.length() > max_range or to.length() < 0.5:
			continue
		if rad_to_deg(forward.angle_to(to.normalized())) <= 15.0 and to.length() < best_d:
			best = enemy
			best_d = to.length()
	if best != null:
		var to := best.global_position + Vector3(0, 0.5, 0) - (player.global_position + Vector3(0, 1.3, 0))
		return to.normalized()
	return forward


func _spawn_ring(at: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	torus.rings = 24
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	ring.mesh = torus
	ring.material_override = mat
	player.get_parent().add_child(ring)
	ring.global_position = at
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(ring.queue_free)


# ---------- interface ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var root := VBoxContainer.new()
	root.anchor_left = 1.0
	root.anchor_right = 1.0
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -190.0
	root.offset_right = -24.0
	root.offset_top = -132.0
	root.offset_bottom = -24.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	layer.add_child(root)
	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", 12)
	_energy_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_energy_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_energy_label.add_theme_constant_override("outline_size", 4)
	root.add_child(_energy_label)
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(166, 10)
	_energy_bar.show_percentage = false
	_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.6, 1.0)
	fill.set_corner_radius_all(4)
	_energy_bar.add_theme_stylebox_override("background", bg)
	_energy_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(_energy_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for i in SLOT_COUNT:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(64, 64)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.06, 0.08, 0.9)
		style.border_color = Color(0.4, 0.5, 0.7, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(32)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		var icon := AbilityIcon.new()
		icon.position = Vector2(10, 10)
		icon.size = Vector2(44, 44)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.6)
		shade.position = Vector2(6, 6)
		shade.size = Vector2(52, 0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(shade)
		var timer := Label.new()
		timer.position = Vector2(0, 20)
		timer.size = Vector2(64, 24)
		timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer.add_theme_font_size_override("font_size", 16)
		timer.add_theme_color_override("font_outline_color", Color.BLACK)
		timer.add_theme_constant_override("outline_size", 5)
		timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(timer)
		var key := Label.new()
		key.text = KEYS[i]
		key.position = Vector2(46, 44)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		key.add_theme_color_override("font_outline_color", Color.BLACK)
		key.add_theme_constant_override("outline_size", 4)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(key)
		_ui_slots.append({"style": style, "icon": icon, "shade": shade, "timer": timer})


func _refresh_ui() -> void:
	if _energy_bar == null or energy == null:
		return
	_energy_bar.max_value = energy.max_energy
	_energy_bar.value = energy.current_energy
	_energy_label.text = "ENERGIA  %d/%d" % [roundi(energy.current_energy), roundi(energy.max_energy)]
	for i in _ui_slots.size():
		var ui: Dictionary = _ui_slots[i]
		var id := slots[i]
		var def := get_definition(id)
		(ui["icon"] as AbilityIcon).ability_id = id if def != null and is_unlocked(id) else &""
		var left := cooldown_left(id)
		var ratio := clampf(left / def.cooldown, 0.0, 1.0) if def != null and def.cooldown > 0.0 else 0.0
		(ui["shade"] as ColorRect).size.y = 52.0 * ratio
		(ui["shade"] as ColorRect).position.y = 6.0 + 52.0 * (1.0 - ratio)
		(ui["timer"] as Label).text = str(ceili(left)) if left > 0.0 else ("?" if def == null or not is_unlocked(id) else "")
		var style := ui["style"] as StyleBoxFlat
		if def == null or not is_unlocked(id):
			style.border_color = Color(0.3, 0.3, 0.3, 0.7)
		elif not energy.has(def.energy_cost):
			style.border_color = Color(0.9, 0.3, 0.3, 0.9)
		elif left <= 0.0:
			style.border_color = def.color
		else:
			style.border_color = Color(0.4, 0.5, 0.7, 0.8)
