class_name AncestralRuin
extends Node3D
## Ruína do Primeiro Fogo (ANCESTRAL_ESSENCES.md 5): três marcas ancestrais,
## em qualquer ordem, despertam o altar; tocar o altar desperto concede a
## Centelha Ancestral uma única vez.
##
## Todo o progresso fica no KnowledgeManager ("<ruin_id>_discovered",
## "<ruin_id>_mark_N", "ability_<recompensa>"), então vai para o save sem
## código extra e nunca volta atrás. Monta o próprio visual em código.

signal discovered
signal mark_activated(index: int, total: int)
signal awakened
signal completed

@export var ruin_id: StringName = &"ruin_first_fire"
@export var ruin_name: String = "Ruína do Primeiro Fogo"
@export var reward_ability: StringName = &"ancestral_spark"
@export var required_marks: int = 3
## Posições das marcas em relação ao altar (até 20 m, sem pulo nem combate).
@export var mark_offsets: Array[Vector3] = [Vector3(10, 0, -7), Vector3(-13, 0, 3), Vector3(4, 0, 15)]
@export var discovery_radius: float = 15.0
## Raio sem árvores ao redor (a floresta procedural respeita).
@export var clear_radius: float = 24.0
@export var knowledge: KnowledgeManager
@export var experience: ExperienceComponent
@export var abilities: AbilityController
@export var player: Node3D
@export var hud: SurvivalHUD

var marks: Array[RuinMark] = []
var altar: RuinAltar
var _check_left := 0.0


func _ready() -> void:
	add_to_group(&"forest_clearing")
	_build_ruin()
	if knowledge != null:
		knowledge.knowledge_learned.connect(func(_id, _o): refresh())
	refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.5
	if player != null and not is_discovered():
		var d := player.global_position - global_position
		d.y = 0.0
		if d.length() <= discovery_radius:
			discover()
	refresh()  # o save pode ter restaurado o progresso


# ---------- estado ----------

func is_discovered() -> bool:
	return _known("discovered")


func is_mark_active(index: int) -> bool:
	return _known("mark_%d" % index)


func active_marks() -> int:
	var n := 0
	for i in marks.size():
		if is_mark_active(i):
			n += 1
	return n


func is_awake() -> bool:
	return active_marks() >= mini(required_marks, marks.size())


func is_completed() -> bool:
	return abilities != null and abilities.is_unlocked(reward_ability) or _known("completed")


## Registra a descoberta (uma vez): aviso e XP de descoberta.
func discover() -> void:
	if is_discovered():
		return
	_learn("discovered")
	if experience != null and experience.rules != null:
		experience.award_first(&"discovery", ruin_id, experience.rules.discovery_xp)
	_say("Você encontrou: %s. Procure as %d marcas ancestrais." % [ruin_name, required_marks], 5.0)
	discovered.emit()


func activate_mark(index: int) -> Dictionary:
	if index < 0 or index >= marks.size():
		return {"ok": false, "message": ""}
	if is_mark_active(index):
		return {"ok": false, "message": ""}  # sem erro: já acesa
	discover()
	_learn("mark_%d" % index)
	var n := active_marks()
	mark_activated.emit(index, n)
	refresh()
	if is_awake():
		awakened.emit()
		return {"ok": true, "message": "Marca ancestral desperta (%d/%d). O altar despertou!" % [n, required_marks]}
	return {"ok": true, "message": "Marca ancestral desperta (%d/%d)" % [n, required_marks]}


func use_altar() -> Dictionary:
	if is_completed():
		return {"ok": false, "message": "O Primeiro Fogo queima em silêncio."}
	if not is_awake():
		var left := required_marks - active_marks()
		return {"ok": false, "message": "Faltam %d marca%s ancestra%s" % [left, "s" if left > 1 else "", "is" if left > 1 else "l"]}
	_learn("completed")
	if abilities != null:
		abilities.unlock(reward_ability)
	if experience != null and experience.rules != null:
		experience.award_first(&"challenge", ruin_id, experience.rules.challenge_xp)
	refresh()
	completed.emit()
	var ability_name := "Centelha Ancestral"
	if abilities != null and abilities.get_definition(reward_ability) != null:
		ability_name = abilities.get_definition(reward_ability).display_name
	var message := "O calor do Primeiro Fogo corre pelas suas mãos. %s desbloqueada! [R] para lançar" % ability_name
	_say(message, 6.0)
	return {"ok": true, "message": message}


func refresh() -> void:
	for i in marks.size():
		marks[i].set_active(is_mark_active(i))
	if altar != null:
		altar.set_state(is_awake(), is_completed())


func _known(suffix: String) -> bool:
	return knowledge != null and knowledge.is_known(StringName("%s_%s" % [ruin_id, suffix]))


func _learn(suffix: String) -> void:
	if knowledge != null:
		knowledge.learn(StringName("%s_%s" % [ruin_id, suffix]), &"challenge")


func _say(text: String, duration: float = 3.0) -> void:
	if hud != null:
		hud.show_message(text, duration)


# ---------- visual ----------

func _build_ruin() -> void:
	var stone := _mat(Color(0.52, 0.5, 0.46))
	var moss := _mat(Color(0.36, 0.5, 0.3))
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 6.0
	floor_mesh.bottom_radius = 6.3
	floor_mesh.height = 0.25
	floor_mesh.radial_segments = 10
	floor_mesh.rings = 0
	floor_mesh.material = stone
	_static(floor_mesh, Vector3(0, 0.12, 0), Vector3.ZERO, true)
	# Anel de colunas quebradas (algumas tombadas), com musgo.
	for i in 8:
		var angle := TAU * i / 8.0
		var height: float = [3.2, 1.4, 2.6, 0.9, 3.0, 1.8, 2.2, 1.1][i]
		var pillar := BoxMesh.new()
		pillar.size = Vector3(0.7, height, 0.7)
		pillar.material = stone if i % 3 != 0 else moss
		var pos := Vector3(cos(angle) * 5.2, 0.25 + height * 0.5, sin(angle) * 5.2)
		_static(pillar, pos, Vector3(0, angle + 0.3, (0.08 if i % 2 == 0 else -0.06)), true)
	var fallen := BoxMesh.new()
	fallen.size = Vector3(0.7, 0.7, 2.6)
	fallen.material = moss
	_static(fallen, Vector3(-2.8, 0.6, -6.6), Vector3(0, 0.6, 0.1), true)
	# Altar no centro.
	altar = RuinAltar.new()
	altar.ruin = self
	altar.name = "Altar"
	add_child(altar)
	for i in mark_offsets.size():
		var mark := RuinMark.new()
		mark.ruin = self
		mark.index = i
		mark.name = "Mark%d" % i
		add_child(mark)
		mark.position = mark_offsets[i]
		mark.rotation.y = atan2(mark_offsets[i].x, mark_offsets[i].z)
		marks.append(mark)


func _static(mesh: Mesh, pos: Vector3, rot: Vector3, collide: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.position = pos
	body.rotation = rot
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	if collide:
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_convex_shape()
		body.add_child(shape)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
