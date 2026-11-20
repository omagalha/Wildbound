class_name ResourceScatter
extends Node3D
## Espalha fontes de recurso extras pela floresta, em grupos, de forma determinística.
##
## Fica na raiz do ResourceField. Os nós criados têm nomes estáveis
## ("Wilds/W000_berry"...), então o SaveManager encontra os mesmos caminhos ao
## carregar. Roda no _ready, antes do SaveManager e do DifficultyManager (que
## vêm depois na árvore da cena principal).

@export var world_seed: int = 4242
## Grupos não aparecem a menos disso da origem (a área inicial já tem os seus).
@export var inner_radius: float = 50.0
@export var half_size: float = 138.0
@export var cluster_count: int = 34
@export var berry_scene: PackedScene
@export var fiber_scene: PackedScene
@export var stone_scene: PackedScene
@export var wood_scene: PackedScene
## Afloramentos de sílex (pedem picareta). Gerados numa segunda passada com
## semente própria, para não mudar a posição dos grupos já existentes nos saves.
@export var flint_scene: PackedScene
@export var flint_count: int = 12
## Veios de ferro: raros, só longe do início (incentivo para explorar).
@export var iron_scene: PackedScene
@export var iron_count: int = 10
@export var iron_min_distance: float = 95.0
## Recursos das regiões da ilha: [cena, região (IslandTerrain.Biome), grupos].
## Gerados numa passada própria (semente + 3), sem mexer nos anteriores.
@export var region_scenes: Array[PackedScene] = []
@export var region_biomes: PackedInt32Array = PackedInt32Array()
@export var region_clusters: PackedInt32Array = PackedInt32Array()
## Peso relativo de cada tipo nos grupos: frutas, fibra, pedra, madeira.
@export var weights: Vector4 = Vector4(0.3, 0.25, 0.22, 0.23)

var spawned: Array[ResourceNode] = []


func _ready() -> void:
	spawn_all()


func spawn_all() -> void:
	if not spawned.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var root := Node3D.new()
	root.name = "Wilds"
	add_child(root)
	var kinds := [["berry", berry_scene], ["fiber", fiber_scene], ["stone", stone_scene], ["wood", wood_scene]]
	var centers: Array[Vector2] = []
	var index := 0
	for c in cluster_count:
		var center := Vector2.ZERO
		for attempt in 20:
			center = Vector2(rng.randf_range(-half_size, half_size), rng.randf_range(-half_size, half_size))
			if center.length() < inner_radius:
				continue
			var ok := true
			for other in centers:
				if other.distance_to(center) < 16.0:
					ok = false
					break
			if ok:
				break
		centers.append(center)
		var kind := _pick(rng)
		var scene: PackedScene = kinds[kind][1]
		if scene == null:
			continue
		var amount := rng.randi_range(2, 5)
		for i in amount:
			var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.5, 5.0)
			var node := scene.instantiate() as ResourceNode
			node.name = "W%03d_%s" % [index, kinds[kind][0]]
			index += 1
			root.add_child(node)
			node.position = Vector3(center.x + offset.x, 0, center.y + offset.y)
			node.rotation.y = rng.randf() * TAU
			spawned.append(node)
	_spawn_flint(root, centers)
	_spawn_iron(root, centers)
	_spawn_regions(root)


func _spawn_flint(root: Node3D, avoid: Array[Vector2]) -> void:
	if flint_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1
	var placed: Array[Vector2] = []
	for i in flint_count:
		var p := Vector2.ZERO
		for attempt in 30:
			p = Vector2(rng.randf_range(-half_size, half_size), rng.randf_range(-half_size, half_size))
			if p.length() < inner_radius + 10.0:
				continue
			var ok := true
			for other in avoid + placed:
				if other.distance_to(p) < 9.0:
					ok = false
					break
			if ok:
				break
		placed.append(p)
		var node := flint_scene.instantiate() as ResourceNode
		node.name = "F%03d_flint" % i
		root.add_child(node)
		node.position = Vector3(p.x, 0, p.y)
		node.rotation.y = rng.randf() * TAU
		spawned.append(node)


func _pick(rng: RandomNumberGenerator) -> int:
	var total := weights.x + weights.y + weights.z + weights.w
	var r := rng.randf() * total
	var values := [weights.x, weights.y, weights.z, weights.w]
	for i in values.size():
		r -= values[i]
		if r <= 0.0:
			return i
	return 3


func _spawn_iron(root: Node3D, avoid: Array[Vector2]) -> void:
	if iron_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 2
	var placed: Array[Vector2] = []
	for i in iron_count:
		var p := Vector2.ZERO
		for attempt in 40:
			var angle := rng.randf() * TAU
			var dist := rng.randf_range(iron_min_distance, half_size * 1.35)
			p = Vector2(cos(angle), sin(angle)) * dist
			p.x = clampf(p.x, -half_size, half_size)
			p.y = clampf(p.y, -half_size, half_size)
			var ok := p.length() >= iron_min_distance
			for other in avoid + placed:
				if other.distance_to(p) < 10.0:
					ok = false
					break
			if ok:
				break
		placed.append(p)
		var node := iron_scene.instantiate() as ResourceNode
		node.name = "I%03d_iron" % i
		root.add_child(node)
		node.position = Vector3(p.x, 0, p.y)
		node.rotation.y = rng.randf() * TAU
		spawned.append(node)


func _spawn_regions(root: Node3D) -> void:
	var terrain := IslandTerrain.find(get_tree())
	if terrain == null or region_scenes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 3
	var index := 0
	for k in region_scenes.size():
		var scene := region_scenes[k]
		var biome: int = region_biomes[k] if k < region_biomes.size() else -1
		var clusters: int = region_clusters[k] if k < region_clusters.size() else 6
		for c in clusters:
			var center := _region_point(terrain, rng, biome)
			if center == Vector2.INF:
				continue
			for i in rng.randi_range(2, 4):
				var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.5, 5.0)
				var p := center + offset
				if terrain.biome_at(p.x, p.y) == IslandTerrain.Biome.WATER:
					continue
				var node := scene.instantiate() as ResourceNode
				node.name = "B%03d_region" % index
				index += 1
				root.add_child(node)
				node.position = Vector3(p.x, terrain.height_at(p.x, p.y), p.y)
				node.rotation.y = rng.randf() * TAU
				spawned.append(node)


## Ponto da região pedida, fora do centro e sem encosta forte (INF se não achou).
func _region_point(terrain: IslandTerrain, rng: RandomNumberGenerator, biome: int) -> Vector2:
	for attempt in 80:
		var a := rng.randf() * TAU
		var r := rng.randf_range(terrain.flat_radius + 30.0, terrain.coast_radius + 40.0)
		var p := Vector2(cos(a), sin(a)) * r
		if terrain.biome_at(p.x, p.y) != biome:
			continue
		var slope := absf(terrain.height_at(p.x + 2.0, p.y) - terrain.height_at(p.x - 2.0, p.y)) + absf(terrain.height_at(p.x, p.y + 2.0) - terrain.height_at(p.x, p.y - 2.0))
		if slope > 3.0:
			continue
		return p
	return Vector2.INF
