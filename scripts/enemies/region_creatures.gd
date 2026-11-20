class_name RegionCreatures
extends Node3D
## Criaturas das regiões da ilha, em tocas (zonas de atenção) espalhadas por
## região, com sorteio fixo pela semente. Cada espécie tem modelo, cores,
## força e saque próprios (mais fortes nas regiões mais perigosas).
##
## Desempenho: criaturas longe do jogador ficam dormindo (sem física) até ele
## chegar perto. Os multiplicadores do preset de dificuldade valem para todas.

const BASE_SCENE := "res://scenes/enemies/shadow_wolf.tscn"

## Espécies por região. "biome" usa IslandTerrain.Biome.
const SPECIES := [
	{
		"id": &"snow_wolf", "name": "Lobo das Neves", "biome": 1, "nest": "Toca do Lobo das Neves",
		"model": "res://assets/creatures/Wolf.gltf", "length": 1.75, "box": Vector3(0.7, 0.9, 1.5),
		"colors": {"Main": Color(0.88, 0.9, 0.95), "Main_Light": Color(0.98, 0.99, 1.0), "Nose": Color(0.1, 0.1, 0.12)},
		"glow": {"Eyes_Black": Color(0.4, 0.8, 1.0)}, "tint": Color.WHITE, "emission": Color.BLACK,
		"clips": {},
		"stats": {"max_health": 70.0, "chase_speed": 6.5, "charge_speed": 11.0, "charge_damage": 16.0, "bite_damage": 12.0, "perception_radius": 24.0, "leash_radius": 45.0, "telegraph_time": 0.6},
		"loot": {&"raw_meat": 2, &"ice_crystal": 1, &"hide": 2}, "pack": [2, 3], "nests": 4,
	},
	{
		"id": &"rock_bull", "name": "Touro das Rochas", "biome": 2, "nest": "Pasto do Touro das Rochas",
		"model": "res://assets/creatures/Bull.gltf", "length": 2.6, "box": Vector3(1.1, 1.5, 2.2),
		"colors": {"Main": Color(0.42, 0.22, 0.14), "Main_Light": Color(0.55, 0.33, 0.2)},
		"glow": {}, "tint": Color.WHITE, "emission": Color.BLACK,
		"clips": {"attack": "Attack_Headbutt", "alert": "Idle_Headlow"},
		"stats": {"max_health": 150.0, "wander_speed": 1.3, "chase_speed": 5.0, "charge_speed": 13.0, "charge_damage": 28.0, "charge_hit_radius": 1.7, "bite_range": 2.6, "bite_damage": 14.0, "perception_radius": 20.0, "leash_radius": 40.0, "telegraph_time": 1.0, "recover_time": 1.6},
		"loot": {&"raw_meat": 4, &"clay": 2, &"hide": 3}, "pack": [1, 2], "nests": 4,
	},
	{
		"id": &"ember_hound", "name": "Cão de Brasa", "biome": 3, "nest": "Covil dos Cães de Brasa",
		"model": "res://assets/creatures/Husky.gltf", "length": 1.5, "box": Vector3(0.6, 0.8, 1.3),
		"colors": {}, "glow": {}, "tint": Color(0.22, 0.12, 0.1), "emission": Color(1.0, 0.3, 0.05),
		"clips": {},
		"stats": {"max_health": 85.0, "chase_speed": 7.2, "charge_speed": 12.0, "charge_damage": 20.0, "bite_damage": 15.0, "perception_radius": 26.0, "leash_radius": 50.0, "telegraph_time": 0.5},
		"loot": {&"sulfur": 2, &"raw_meat": 1}, "pack": [2, 3], "nests": 4,
	},
	{
		"id": &"horned_stag", "name": "Cervo Chifrudo", "biome": 4, "nest": "Campo do Cervo Chifrudo",
		"model": "res://assets/creatures/Stag.gltf", "length": 2.3, "box": Vector3(0.8, 1.6, 1.8),
		"colors": {}, "glow": {}, "tint": Color(1.05, 0.95, 0.85), "emission": Color.BLACK,
		"clips": {"attack": "Attack_Headbutt", "alert": "Idle_Headlow"},
		"stats": {"max_health": 90.0, "wander_speed": 1.8, "chase_speed": 6.5, "charge_speed": 12.5, "charge_damage": 22.0, "bite_range": 2.4, "bite_damage": 12.0, "perception_radius": 18.0, "leash_radius": 40.0},
		"loot": {&"raw_meat": 3, &"fiber": 2, &"hide": 2}, "pack": [1, 2], "nests": 4,
	},
]

@export var world_seed: int = 77
@export var player: CharacterBody3D
@export var difficulty: DifficultyManager
## Criaturas mais longe que isso dormem.
@export var active_distance: float = 140.0
@export var spawn_on_ready: bool = true

var creatures: Array[HostileCreature] = []
var nests: Array[TerritoryZone] = []
var _sleep_check := 0.0


func _ready() -> void:
	if difficulty != null:
		difficulty.settings_applied.connect(func(_s): _apply_difficulty())
	if spawn_on_ready:
		spawn_all.call_deferred()


func _physics_process(delta: float) -> void:
	_sleep_check -= delta
	if _sleep_check > 0.0:
		return
	_sleep_check = 0.5
	update_sleep()


func spawn_all() -> void:
	if not creatures.is_empty():
		return
	var terrain := IslandTerrain.find(get_tree())
	if terrain == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for spec in SPECIES:
		for n in int(spec["nests"]):
			var p := _nest_point(terrain, rng, int(spec["biome"]))
			if p == Vector2.INF:
				continue
			var nest := TerritoryZone.new()
			nest.name = "%s_nest%d" % [spec["id"], n]
			nest.zone_name = spec["nest"]
			nest.level = TerritoryZone.Level.ATTENTION
			nest.radius = 16.0
			nest.description = "%s guardam esta área" % spec["name"]
			add_child(nest)
			nest.global_position = Vector3(p.x, terrain.height_at(p.x, p.y), p.y)
			nests.append(nest)
			var count := rng.randi_range(int(spec["pack"][0]), int(spec["pack"][1]))
			for i in count:
				var offset := Vector2.from_angle(TAU * i / count) * 2.5
				var q := p + offset
				spawn_creature(spec, Vector3(q.x, terrain.height_at(q.x, q.y) + 0.3, q.y), rng.randi())
	_apply_difficulty()
	update_sleep()


## Cria uma criatura da espécie [param spec] em [param at].
func spawn_creature(spec: Dictionary, at: Vector3, seed_value: int = 0) -> HostileCreature:
	var creature := (load(BASE_SCENE) as PackedScene).instantiate() as HostileCreature
	var def := (creature.definition as EnemyDefinition).duplicate() as EnemyDefinition
	def.species_id = spec["id"]
	def.display_name = spec["name"]
	def.fears_light = false
	def.respawns = true
	def.respawn_time = 180.0
	def.loot = spec["loot"].duplicate()
	for key in spec["stats"]:
		def.set(key, spec["stats"][key])
	creature.definition = def
	creature.player = player
	creature.rng_seed = seed_value if seed_value != 0 else 1
	creature.name = "%s_%d" % [spec["id"], creatures.size()]
	# Remove o modelo do lobo noturno e põe o da espécie.
	var old_model := creature.get_node_or_null("CreatureModel")
	if old_model != null:
		creature.remove_child(old_model)
		old_model.free()
	var model := CreatureModel.new()
	model.name = "CreatureModel"
	model.model_scene = load(spec["model"])
	model.target_length = spec["length"]
	model.color_overrides = spec["colors"]
	model.glow_overrides = spec["glow"]
	model.tint = spec["tint"]
	model.emission_tint = spec["emission"]
	var clips := model.clips.duplicate()
	for k in spec["clips"]:
		clips[k] = spec["clips"][k]
	model.clips = clips
	creature.add_child(model)
	var shape_node := creature.get_node("CollisionShape3D") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = spec["box"]
	shape_node.shape = box
	shape_node.position.y = box.size.y * 0.5 + 0.05
	add_child(creature)
	creature.global_position = at
	creature.home = at
	(creature.health as HealthComponent).max_health = def.max_health
	creature.health.current_health = def.max_health
	creatures.append(creature)
	return creature


## Criaturas longe do jogador (e sem caçar) dormem; perto, acordam.
func update_sleep() -> void:
	if player == null:
		return
	for c in creatures:
		if not is_instance_valid(c):
			continue
		var d := Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length()
		var awake := d <= active_distance or c.state != HostileCreature.State.IDLE
		c.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED


func awake_count() -> int:
	var n := 0
	for c in creatures:
		if is_instance_valid(c) and c.process_mode != Node.PROCESS_MODE_DISABLED:
			n += 1
	return n


func species_of(id: StringName) -> Array[HostileCreature]:
	var out: Array[HostileCreature] = []
	for c in creatures:
		if is_instance_valid(c) and c.definition.species_id == id:
			out.append(c)
	return out


func _apply_difficulty() -> void:
	if difficulty == null or difficulty.current == null:
		return
	for c in creatures:
		if is_instance_valid(c):
			c.apply_multipliers(difficulty.current.enemy_damage_multiplier, difficulty.current.enemy_health_multiplier)


func _nest_point(terrain: IslandTerrain, rng: RandomNumberGenerator, biome: int) -> Vector2:
	for attempt in 120:
		var a := rng.randf() * TAU
		var r := rng.randf_range(terrain.flat_radius + 50.0, terrain.coast_radius)
		var p := Vector2(cos(a), sin(a)) * r
		if terrain.biome_at(p.x, p.y) != biome:
			continue
		var slope := absf(terrain.height_at(p.x + 3.0, p.y) - terrain.height_at(p.x - 3.0, p.y)) + absf(terrain.height_at(p.x, p.y + 3.0) - terrain.height_at(p.x, p.y - 3.0))
		if slope > 3.5:
			continue
		var far := true
		for nest in nests:
			if Vector2(nest.global_position.x, nest.global_position.z).distance_to(p) < 60.0:
				far = false
				break
		if far:
			return p
	return Vector2.INF
