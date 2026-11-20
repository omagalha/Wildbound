class_name ForestGenerator
extends Node3D
## Floresta procedural determinística ao redor da área de teste.
##
## Gera árvores (pinheiros, frondosas e outonais), rochas, arbustos, grama,
## flores e uma cadeia de montanhas no horizonte. Visual em MultiMesh por
## pedaços do mapa (com distância de visibilidade); colisão só em troncos e
## rochas grandes, com formas compartilhadas.
##
## Mesma semente = mesma floresta, então o save não precisa guardar nada daqui.
## A geração roda adiada (fim do quadro) para enxergar as fontes de recurso e
## as zonas já criadas e não plantar árvores em cima delas.

@export var world_seed: int = 1337
## Metade do lado da área jogável (o mundo vai de -half_size a +half_size).
@export var half_size: float = 145.0
## Raio ao redor da origem sem nada com colisão (área de teste e início).
@export var keep_clear_radius: float = 42.0
## Raio ao redor da origem sem grama/flores (onde o jogador costuma construir).
@export var grass_clear_radius: float = 14.0
@export var tree_count: int = 700
@export var rock_count: int = 140
@export var bush_count: int = 420
## Tufos de grama (cada um com 3 a 5 folhas).
@export var grass_count: int = 8000
@export var flower_count: int = 1600
@export var mountain_count: int = 0
## Vegetação das regiões da ilha (usa o IslandTerrain da cena, se houver).
@export var island_tree_count: int = 7000
@export var island_rock_count: int = 1400
@export var island_grass_count: int = 16000
## Lado de cada pedaço de MultiMesh.
@export var chunk_size: float = 40.0
## Distância de visibilidade da grama e flores.
@export var detail_view_distance: float = 75.0
## Distância de visibilidade de árvores, rochas e arbustos.
@export var tree_view_distance: float = 260.0
## Gerar na entrada da cena. Desligado, só gera ao chamar [method generate].
@export var generate_on_ready: bool = true

const FOLIAGE_SHADER := preload("res://resources/shaders/foliage.gdshader")

var generated := false
## Altura do chão e tinta usadas pelos "ajudantes" de plantio (ilha).
var _ground_y := 0.0
var _leaf_tint := Color.WHITE
var tree_bodies: Array[StaticBody3D] = []

var _rng := RandomNumberGenerator.new()
var _batches := {}  # "kind|cx|cz" -> {"kind", "transforms": [], "colors": []}
var _meshes := {}   # kind -> Mesh
var _view := {}     # kind -> distância de visibilidade
var _blockers: Array[Vector4] = []  # (x, z, raio, 0) onde nada com colisão entra
var _placed: Array[Vector3] = []    # (x, z, raio) de troncos/rochas já colocados
var _trunk_shape: CylinderShape3D
var _bodies_root: Node3D
var _visual_root: Node3D


func _ready() -> void:
	if generate_on_ready:
		generate.call_deferred()


func generate() -> void:
	if generated:
		return
	generated = true
	_rng.seed = world_seed
	_build_meshes()
	_collect_blockers()
	_bodies_root = Node3D.new()
	_bodies_root.name = "Colliders"
	add_child(_bodies_root)
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	_trunk_shape = CylinderShape3D.new()
	_trunk_shape.radius = 0.32
	_trunk_shape.height = 3.0

	for i in tree_count:
		_try_tree()
	for i in rock_count:
		_try_rock()
	for i in bush_count:
		_scatter_bush()
	for i in grass_count:
		_scatter_grass()
	for i in flower_count:
		_scatter_flower()
	_build_mountains()
	_scatter_island()
	_flush_batches()


## Árvores com colisão a menos de [param radius] de [param point] (para testes).
func trees_near(point: Vector3, radius: float) -> int:
	var count := 0
	for body in tree_bodies:
		var d := body.global_position - point
		d.y = 0.0
		if d.length() <= radius:
			count += 1
	return count


# ---------- posicionamento ----------

func _collect_blockers() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.root.find_children("*", "ResourceNode", true, false):
		var p := (node as Node3D).global_position
		_blockers.append(Vector4(p.x, p.z, 2.2, 0))
	for node in tree.get_nodes_in_group(&"forest_clearing"):
		var clearing := node as Node3D
		var cr := float(clearing.get("clear_radius")) if clearing.get("clear_radius") != null else 10.0
		_blockers.append(Vector4(clearing.global_position.x, clearing.global_position.z, cr, 0))
	for node in tree.get_nodes_in_group(&"territory_zones"):
		var zone := node as Node3D
		var p := zone.global_position
		var r := float(zone.get("radius")) if zone.get("radius") != null else 10.0
		# Zonas seguras ficam abertas; territórios só têm o ninho livre.
		var is_safe: bool = int(zone.get("level")) == 0
		_blockers.append(Vector4(p.x, p.z, r if is_safe else minf(r * 0.55, 8.0), 0))
	for node in tree.root.find_children("*", "Marker3D", true, false):
		var p := (node as Node3D).global_position
		_blockers.append(Vector4(p.x, p.z, 6.0, 0))


func _random_point(min_radius: float) -> Vector2:
	for attempt in 12:
		var p := Vector2(_rng.randf_range(-half_size, half_size), _rng.randf_range(-half_size, half_size))
		if p.length() >= min_radius:
			return p
	return Vector2(half_size * 0.9, half_size * 0.9)


func _is_free(p: Vector2, radius: float) -> bool:
	if p.length() < keep_clear_radius + radius:
		return false
	for b in _blockers:
		if p.distance_to(Vector2(b.x, b.y)) < b.z + radius:
			return false
	for o in _placed:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + radius:
			return false
	return true


## Floresta mais densa longe do centro e em "manchas", com clareiras naturais.
func _density(p: Vector2) -> float:
	var ring := clampf((p.length() - keep_clear_radius) / 40.0, 0.25, 1.0)
	var patch := 0.5 + 0.5 * sin(p.x * 0.045 + 1.3) * cos(p.y * 0.038 - 0.7)
	return ring * (0.35 + 0.65 * patch)


# ---------- árvores ----------

func _try_tree() -> void:
	for attempt in 6:
		var p := _random_point(keep_clear_radius)
		if _rng.randf() > _density(p):
			continue
		if not _is_free(p, 1.6):
			continue
		var roll := _rng.randf()
		if roll < 0.5:
			_add_pine(p)
		elif roll < 0.88:
			_add_broadleaf(p, false)
		else:
			_add_broadleaf(p, true)
		_placed.append(Vector3(p.x, p.y, 1.6))
		_add_trunk_body(p)
		return


func _add_pine(p: Vector2) -> void:
	var s := _rng.randf_range(0.8, 1.45)
	var yaw := _rng.randf() * TAU
	var base := Vector3(p.x, _ground_y, p.y)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	_push("pine_trunk", p, Transform3D(basis, base + Vector3(0, 0.9 * s, 0)), Color(0.42, 0.29, 0.19))
	var green := Color.from_hsv(_rng.randf_range(0.27, 0.33), _rng.randf_range(0.5, 0.66), _rng.randf_range(0.46, 0.6))
	var layers := [[1.9, 1.0], [2.9, 0.78], [3.75, 0.55]]
	for layer in layers:
		var ls: float = layer[1]
		var lb := Basis(Vector3.UP, yaw + ls).scaled(Vector3(s * ls, s * ls, s * ls))
		_push("pine_layer", p, Transform3D(lb, base + Vector3(0, layer[0] * s, 0)), green.lightened((1.0 - ls) * 0.25) * _leaf_tint)


func _add_broadleaf(p: Vector2, autumn: bool) -> void:
	var s := _rng.randf_range(0.85, 1.35)
	var yaw := _rng.randf() * TAU
	var base := Vector3(p.x, _ground_y, p.y)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	_push("oak_trunk", p, Transform3D(basis, base + Vector3(0, 1.1 * s, 0)), Color(0.40, 0.30, 0.21))
	var crown: Color
	if autumn:
		crown = Color.from_hsv(_rng.randf_range(0.03, 0.12), _rng.randf_range(0.65, 0.85), _rng.randf_range(0.65, 0.85))
	else:
		crown = Color.from_hsv(_rng.randf_range(0.2, 0.29), _rng.randf_range(0.5, 0.7), _rng.randf_range(0.42, 0.58))
	var main := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * _rng.randf_range(0.85, 1.1), s))
	_push("oak_crown", p, Transform3D(main, base + Vector3(0, 2.9 * s, 0)), crown)
	var side_dir := Vector3(cos(yaw), 0, sin(yaw)) * 0.8 * s
	var side := Basis(Vector3.UP, yaw + 1.0).scaled(Vector3.ONE * s * 0.62)
	_push("oak_crown", p, Transform3D(side, base + side_dir + Vector3(0, 2.4 * s, 0)), crown.darkened(0.08))


func _add_trunk_body(p: Vector2) -> void:
	var body := ForestTree.new()
	body.name = "Tree%04d" % tree_bodies.size()
	# Camada 1 (mundo) + camada 3 (interativos: cortar com machado).
	body.collision_layer = 1 | 4
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = _trunk_shape
	shape.position = Vector3(0, 1.5, 0)
	body.add_child(shape)
	_bodies_root.add_child(body)
	body.position = Vector3(p.x, _ground_y, p.y)
	tree_bodies.append(body)


# ---------- rochas, arbustos, grama, flores ----------

func _try_rock() -> void:
	for attempt in 6:
		var p := _random_point(keep_clear_radius * 0.6)
		var big := _rng.randf() < 0.4
		var radius := _rng.randf_range(1.0, 2.2) if big else _rng.randf_range(0.25, 0.6)
		if big and not _is_free(p, radius):
			continue
		var scale := Vector3(radius * _rng.randf_range(0.9, 1.3), radius * _rng.randf_range(0.55, 0.9), radius * _rng.randf_range(0.9, 1.3))
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.25, 0.25))).scaled(scale)
		var grey := _rng.randf_range(0.5, 0.66)
		var tint := Color(grey * 1.04, grey, grey * 0.94)  # cinza quente
		if _rng.randf() < 0.3:
			tint = tint.lerp(Color(0.4, 0.52, 0.3), 0.35)  # musgo
		_push("rock", p, Transform3D(basis, Vector3(p.x, scale.y * 0.25, p.y)), tint)
		if big:
			_placed.append(Vector3(p.x, p.y, radius))
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = radius * 0.9
			shape.shape = sphere
			shape.position = Vector3(0, scale.y * 0.1, 0)
			body.add_child(shape)
			_bodies_root.add_child(body)
			body.position = Vector3(p.x, 0, p.y)
		return


func _scatter_bush() -> void:
	var p := _random_point(keep_clear_radius * 0.5)
	if _rng.randf() > _density(p) + 0.25:
		return
	var s := _rng.randf_range(0.6, 1.2)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.2, s * 0.75, s * 1.2))
	var c := Color.from_hsv(_rng.randf_range(0.24, 0.34), _rng.randf_range(0.5, 0.7), _rng.randf_range(0.32, 0.48))
	_push("bush", p, Transform3D(basis, Vector3(p.x, 0.3 * s, p.y)), c)


func _scatter_grass() -> void:
	var p := Vector2(_rng.randf_range(-half_size, half_size), _rng.randf_range(-half_size, half_size))
	if p.length() < grass_clear_radius:
		return
	var c := Color.from_hsv(_rng.randf_range(0.2, 0.27), _rng.randf_range(0.6, 0.8), _rng.randf_range(0.48, 0.62))
	var s := _rng.randf_range(0.7, 1.3)
	for blade in _rng.randi_range(3, 5):
		var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 0.14)
		var tilt := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf() * TAU, _rng.randf_range(-0.35, 0.35))
		var basis := Basis.from_euler(tilt).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.2), s))
		var q := p + offset
		_push("grass", p, Transform3D(basis, Vector3(q.x, 0, q.y)), c.lightened(_rng.randf_range(0.0, 0.12)))


func _scatter_flower() -> void:
	var p := Vector2(_rng.randf_range(-half_size, half_size), _rng.randf_range(-half_size, half_size))
	if p.length() < grass_clear_radius:
		return
	var palette := [Color(0.95, 0.95, 0.9), Color(1.0, 0.85, 0.3), Color(0.75, 0.5, 0.95), Color(1.0, 0.5, 0.55), Color(0.5, 0.7, 1.0)]
	# Flores agrupadas por cor em cada região.
	var idx := int(absf(floorf(p.x / 23.0) * 7.0 + floorf(p.y / 19.0) * 3.0)) % palette.size()
	if _rng.randf() < 0.25:
		idx = _rng.randi() % palette.size()
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3))
	_push("flower_stem", p, Transform3D(basis, Vector3(p.x, 0, p.y)), Color(0.3, 0.55, 0.25))
	_push("flower", p, Transform3D(basis, Vector3(p.x, 0.26, p.y)), palette[idx])
	_push("flower_center", p, Transform3D(basis, Vector3(p.x, 0.285, p.y)), Color(1.0, 0.85, 0.25))


# ---------- horizonte ----------

func _build_mountains() -> void:
	var root := Node3D.new()
	root.name = "Mountains"
	_visual_root.add_child(root)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.roughness = 1.0
	for i in mountain_count:
		var angle := TAU * i / mountain_count + _rng.randf_range(-0.08, 0.08)
		var dist := _rng.randf_range(half_size + 45.0, half_size + 110.0)
		var height := _rng.randf_range(35.0, 85.0)
		var radius := height * _rng.randf_range(0.7, 1.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = radius
		cone.height = height
		cone.radial_segments = 6
		cone.rings = 1
		var mat := StandardMaterial3D.new()
		mat.roughness = 1.0
		var shade := _rng.randf_range(0.0, 0.08)
		mat.albedo_color = Color(0.36 + shade, 0.42 + shade, 0.40 + shade)
		cone.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(angle) * dist, height * 0.5 - 2.0, sin(angle) * dist)
		mi.rotation.y = _rng.randf() * TAU
		root.add_child(mi)
		if height > 55.0:
			var cap := CylinderMesh.new()
			cap.top_radius = 0.0
			cap.bottom_radius = radius * 0.32
			cap.height = height * 0.32
			cap.radial_segments = 6
			cap.rings = 0
			var snow := StandardMaterial3D.new()
			snow.albedo_color = Color(0.93, 0.95, 0.98)
			snow.roughness = 1.0
			cap.material = snow
			var cap_mi := MeshInstance3D.new()
			cap_mi.mesh = cap
			cap_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cap_mi.position = Vector3(0, height * 0.5 - height * 0.16 + 0.05, 0)
			mi.add_child(cap_mi)


# ---------- malhas e lotes ----------

func _build_meshes() -> void:
	var pine_trunk := CylinderMesh.new()
	pine_trunk.top_radius = 0.12
	pine_trunk.bottom_radius = 0.22
	pine_trunk.height = 1.8
	pine_trunk.radial_segments = 6
	pine_trunk.rings = 0
	_register("pine_trunk", pine_trunk, _solid_material(), tree_view_distance)

	var pine_layer := CylinderMesh.new()
	pine_layer.top_radius = 0.0
	pine_layer.bottom_radius = 1.35
	pine_layer.height = 1.9
	pine_layer.radial_segments = 7
	pine_layer.rings = 0
	_register("pine_layer", pine_layer, _foliage_material(0.05, -0.95, 1.9), tree_view_distance)

	var oak_trunk := CylinderMesh.new()
	oak_trunk.top_radius = 0.17
	oak_trunk.bottom_radius = 0.28
	oak_trunk.height = 2.2
	oak_trunk.radial_segments = 6
	oak_trunk.rings = 0
	_register("oak_trunk", oak_trunk, _solid_material(), tree_view_distance)

	var oak_crown := SphereMesh.new()
	oak_crown.radius = 1.55
	oak_crown.height = 2.6
	oak_crown.radial_segments = 7
	oak_crown.rings = 3
	_register("oak_crown", oak_crown, _foliage_material(0.07, -1.3, 2.6), tree_view_distance)

	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.6
	rock.radial_segments = 6
	rock.rings = 3
	_register("rock", rock, _solid_material(), tree_view_distance)

	var bush := SphereMesh.new()
	bush.radius = 0.6
	bush.height = 1.0
	bush.radial_segments = 6
	bush.rings = 3
	_register("bush", bush, _foliage_material(0.04, -0.5, 1.0), tree_view_distance * 0.6)

	var grass := CylinderMesh.new()
	grass.top_radius = 0.0
	grass.bottom_radius = 0.035
	grass.height = 0.32
	grass.radial_segments = 3
	grass.rings = 0
	# Origem na base: desloca a malha para cima pela metade da altura.
	var grass_mat := _foliage_material(0.07, 0.0, 0.32)
	grass_mat.set_shader_parameter("base_darkness", 0.3)
	grass_mat.set_shader_parameter("normal_up_blend", 0.75)
	grass_mat.set_shader_parameter("tip_lightness", 0.08)
	grass_mat.set_shader_parameter("rim_strength", 0.0)
	_register("grass", _lifted(grass, 0.16), grass_mat, detail_view_distance)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.018
	stem.height = 0.26
	stem.radial_segments = 3
	stem.rings = 0
	var stem_mat := _foliage_material(0.05, 0.0, 0.26)
	stem_mat.set_shader_parameter("normal_up_blend", 1.0)
	stem_mat.set_shader_parameter("rim_strength", 0.0)
	_register("flower_stem", _lifted(stem, 0.13), stem_mat, detail_view_distance)

	var flower := CylinderMesh.new()  # corola: disco de 5 pétalas
	flower.top_radius = 0.11
	flower.bottom_radius = 0.06
	flower.height = 0.035
	flower.radial_segments = 5
	flower.rings = 0
	var flower_mat := _foliage_material(0.05, -0.3, 0.3)
	flower_mat.set_shader_parameter("base_darkness", 0.1)
	flower_mat.set_shader_parameter("normal_up_blend", 0.8)
	flower_mat.set_shader_parameter("rim_strength", 0.0)
	_register("flower", flower, flower_mat, detail_view_distance)
	var center := SphereMesh.new()
	center.radius = 0.035
	center.height = 0.05
	center.radial_segments = 5
	center.rings = 2
	var center_mat := _foliage_material(0.05, -0.3, 0.3)
	center_mat.set_shader_parameter("base_darkness", 0.0)
	_register("flower_center", center, center_mat, detail_view_distance)


func _build_island_meshes() -> void:
	if _meshes.has("palm_trunk"):
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.2
	trunk.height = 4.5
	trunk.radial_segments = 6
	trunk.rings = 3
	_register("palm_trunk", trunk, _solid_material(), tree_view_distance)
	var frond := PrismMesh.new()  # folha comprida e caída
	frond.size = Vector3(0.6, 0.08, 2.4)
	var frond_mat := _foliage_material(0.12, -0.2, 0.3)
	frond_mat.set_shader_parameter("base_darkness", 0.2)
	_register("palm_frond", frond, frond_mat, tree_view_distance)
	var dead := CylinderMesh.new()
	dead.top_radius = 0.05
	dead.bottom_radius = 0.22
	dead.height = 3.2
	dead.radial_segments = 5
	dead.rings = 0
	_register("dead_trunk", dead, _solid_material(), tree_view_distance)
	var branch := CylinderMesh.new()
	branch.top_radius = 0.02
	branch.bottom_radius = 0.07
	branch.height = 1.3
	branch.radial_segments = 4
	branch.rings = 0
	_register("dead_branch", branch, _solid_material(), tree_view_distance)
	var lava := SphereMesh.new()
	lava.radius = 1.0
	lava.height = 1.4
	lava.radial_segments = 6
	lava.rings = 3
	var lava_mat := StandardMaterial3D.new()
	lava_mat.vertex_color_use_as_albedo = true
	lava_mat.vertex_color_is_srgb = true
	lava_mat.roughness = 0.9
	lava_mat.emission_enabled = true
	lava_mat.emission = Color(1.0, 0.3, 0.05)
	lava_mat.emission_energy_multiplier = 0.9
	_register("lava_rock", lava, lava_mat, tree_view_distance)
	var cactus := CylinderMesh.new()
	cactus.top_radius = 0.22
	cactus.bottom_radius = 0.26
	cactus.height = 2.0
	cactus.radial_segments = 7
	cactus.rings = 1
	_register("cactus", cactus, _solid_material(), tree_view_distance)


# ---------- regiões da ilha ----------

func _scatter_island() -> void:
	var terrain := IslandTerrain.find(get_tree())
	if terrain == null:
		return
	_build_island_meshes()
	var B := IslandTerrain.Biome
	var limit := terrain.coast_radius + 60.0
	var inner := minf(half_size, terrain.flat_radius) - 5.0
	# Árvores (com colisão; as que dão madeira continuam sendo ForestTree).
	for i in island_tree_count:
		var p := _island_point(limit, inner)
		var h := terrain.height_at(p.x, p.y)
		var biome := terrain.biome_at(p.x, p.y)
		if biome == B.WATER or not _is_free(p, 1.6):
			continue
		if _steep(terrain, p) > 0.55:
			continue
		_ground_y = h
		_leaf_tint = Color.WHITE
		match biome:
			B.FOREST:
				if _rng.randf() > 0.75:
					continue
				if _rng.randf() < 0.5: _add_pine(p)
				else: _add_broadleaf(p, _rng.randf() < 0.15)
			B.SNOW:
				if h > 70.0 or _rng.randf() > 0.6:
					continue
				_leaf_tint = Color(1.25, 1.3, 1.35).lerp(Color.WHITE, 0.4)
				_add_pine(p)
			B.PLAINS:
				if _rng.randf() > 0.18:
					continue
				_add_broadleaf(p, _rng.randf() < 0.55)
			B.ROCKY:
				if _rng.randf() > 0.12:
					continue
				_add_cactus(p)
				continue  # cacto não dá madeira
			B.VOLCANIC:
				if _rng.randf() > 0.35:
					continue
				_add_dead_tree(p)
				continue
			B.BEACH:
				if _rng.randf() > 0.35:
					continue
				_add_palm(p)
			_:
				continue
		_placed.append(Vector3(p.x, p.y, 1.6))
		_add_trunk_body(p)
	_ground_y = 0.0
	_leaf_tint = Color.WHITE
	# Rochas por região.
	for i in island_rock_count:
		var p := _island_point(limit, inner)
		var biome := terrain.biome_at(p.x, p.y)
		if biome == B.WATER:
			continue
		var h := terrain.height_at(p.x, p.y)
		var big := _rng.randf() < 0.35
		var radius := _rng.randf_range(1.2, 3.2) if big else _rng.randf_range(0.3, 0.8)
		var color := Color(0.55, 0.53, 0.5)
		var kind := "rock"
		match biome:
			B.SNOW: color = Color(0.82, 0.86, 0.92) if h > 45.0 else Color(0.58, 0.6, 0.64)
			B.ROCKY: color = Color(0.72, 0.5, 0.34); radius *= 1.3
			B.VOLCANIC:
				color = Color(0.16, 0.14, 0.14)
				if _rng.randf() < 0.18:
					kind = "lava_rock"
					color = Color(0.25, 0.12, 0.08)
			B.BEACH: color = Color(0.7, 0.66, 0.58)
			B.PLAINS:
				if _rng.randf() > 0.4:
					continue
		if big and not _is_free(p, radius):
			continue
		var scale := Vector3(radius * _rng.randf_range(0.9, 1.3), radius * _rng.randf_range(0.5, 0.85), radius * _rng.randf_range(0.9, 1.3))
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))).scaled(scale)
		_push(kind, p, Transform3D(basis, Vector3(p.x, h - scale.y * 0.2, p.y)), color)
		if big:
			_placed.append(Vector3(p.x, p.y, radius))
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = radius * 0.85
			shape.shape = sphere
			body.add_child(shape)
			_bodies_root.add_child(body)
			body.position = Vector3(p.x, h, p.y)
	# Grama: verde na floresta e no gelo baixo, dourada e alta nas planícies.
	for i in island_grass_count:
		var p := _island_point(limit, inner)
		var biome := terrain.biome_at(p.x, p.y)
		var h := terrain.height_at(p.x, p.y)
		var c: Color
		var s := _rng.randf_range(0.8, 1.4)
		match biome:
			B.FOREST: c = Color.from_hsv(_rng.randf_range(0.2, 0.27), _rng.randf_range(0.6, 0.8), _rng.randf_range(0.48, 0.62))
			B.PLAINS:
				c = Color.from_hsv(_rng.randf_range(0.1, 0.15), _rng.randf_range(0.55, 0.75), _rng.randf_range(0.7, 0.85))
				s *= 1.8
			B.SNOW:
				if h > 40.0 or _rng.randf() > 0.4:
					continue
				c = Color.from_hsv(0.25, 0.25, 0.6)
			B.ROCKY:
				if _rng.randf() > 0.15:
					continue
				c = Color.from_hsv(0.11, 0.5, 0.6)
			_:
				continue
		for blade in _rng.randi_range(3, 5):
			var off := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 0.16)
			var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf() * TAU, _rng.randf_range(-0.35, 0.35))).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.2), s))
			_push("grass", p, Transform3D(basis, Vector3(p.x + off.x, h, p.y + off.y)), c.lightened(_rng.randf_range(0.0, 0.1)))


func _island_point(limit: float, inner: float) -> Vector2:
	for attempt in 8:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf_range(inner * inner, limit * limit))
		var p := Vector2(cos(a), sin(a)) * r
		if absf(p.x) > half_size or absf(p.y) > half_size or p.length() > inner:
			return p
	return Vector2(limit, 0)


func _steep(terrain: IslandTerrain, p: Vector2) -> float:
	var hx := terrain.height_at(p.x + 1.5, p.y) - terrain.height_at(p.x - 1.5, p.y)
	var hz := terrain.height_at(p.x, p.y + 1.5) - terrain.height_at(p.x, p.y - 1.5)
	return Vector2(hx, hz).length() / 3.0


func _add_palm(p: Vector2) -> void:
	var s := _rng.randf_range(0.9, 1.3)
	var lean := Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25))
	var base := Vector3(p.x, _ground_y, p.y)
	var trunk_basis := Basis.from_euler(lean).scaled(Vector3.ONE * s)
	_push("palm_trunk", p, Transform3D(trunk_basis, base + trunk_basis.y * 2.25), Color(0.55, 0.42, 0.28))
	var top := base + trunk_basis.y * 4.5
	for i in 7:
		var yaw := TAU * i / 7.0 + _rng.randf_range(-0.2, 0.2)
		var fb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.45)
		fb = fb.scaled(Vector3.ONE * s)
		_push("palm_frond", p, Transform3D(fb, top + fb.z * -1.0), Color.from_hsv(_rng.randf_range(0.24, 0.3), 0.7, 0.55))


func _add_dead_tree(p: Vector2) -> void:
	var s := _rng.randf_range(0.8, 1.5)
	var base := Vector3(p.x, _ground_y, p.y)
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
	var dark := Color(0.13, 0.11, 0.1)
	_push("dead_trunk", p, Transform3D(b, base + Vector3(0, 1.6 * s, 0)), dark)
	for i in 3:
		var bb := Basis(Vector3.UP, TAU * i / 3.0 + _rng.randf()) * Basis(Vector3.RIGHT, 0.9)
		bb = bb.scaled(Vector3.ONE * s)
		_push("dead_branch", p, Transform3D(bb, base + Vector3(0, (1.6 + i * 0.5) * s, 0) + bb.y * 0.6), dark)


func _add_cactus(p: Vector2) -> void:
	var s := _rng.randf_range(0.8, 1.6)
	var base := Vector3(p.x, _ground_y, p.y)
	var green := Color(0.36, 0.52, 0.22)
	_push("cactus", p, Transform3D(Basis().scaled(Vector3(s, s, s)), base + Vector3(0, s, 0)), green)
	for side in [-1.0, 1.0]:
		if _rng.randf() < 0.7:
			var arm := Basis().scaled(Vector3(s * 0.6, s * 0.45, s * 0.6))
			_push("cactus", p, Transform3D(arm, base + Vector3(side * 0.45 * s, s * 1.25, 0)), green.lightened(0.05))


func _register(kind: String, mesh: Mesh, material: Material, view_distance: float) -> void:
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	elif mesh is ArrayMesh:
		(mesh as ArrayMesh).surface_set_material(0, material)
	_meshes[kind] = mesh
	_view[kind] = view_distance


## Cópia da malha com os vértices deslocados em Y (para origem na base).
func _lifted(mesh: PrimitiveMesh, dy: float) -> ArrayMesh:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y += dy
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _solid_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # cores das instâncias estão em sRGB
	mat.roughness = 1.0
	return mat


func _foliage_material(strength: float, base: float, height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FOLIAGE_SHADER
	mat.set_shader_parameter("sway_strength", strength)
	mat.set_shader_parameter("base_height", base)
	mat.set_shader_parameter("sway_height", height)
	return mat


func _push(kind: String, p: Vector2, xform: Transform3D, color: Color) -> void:
	var key := "%s|%d|%d" % [kind, floori(p.x / chunk_size), floori(p.y / chunk_size)]
	if not _batches.has(key):
		_batches[key] = {"kind": kind, "transforms": [], "colors": []}
	_batches[key]["transforms"].append(xform)
	_batches[key]["colors"].append(color)


func _flush_batches() -> void:
	for key in _batches:
		var batch: Dictionary = _batches[key]
		var kind: String = batch["kind"]
		var transforms: Array = batch["transforms"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[kind]
		mm.instance_count = transforms.size()
		var center := Vector3.ZERO
		for i in transforms.size():
			center += (transforms[i] as Transform3D).origin
		center /= maxf(transforms.size(), 1)
		center.y = 0.0
		for i in transforms.size():
			var t: Transform3D = transforms[i]
			t.origin -= center
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, batch["colors"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		mmi.multimesh = mm
		mmi.position = center
		mmi.visibility_range_end = _view[kind]
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if kind in ["grass", "flower", "flower_stem", "flower_center", "bush"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_root.add_child(mmi)
	_batches.clear()
