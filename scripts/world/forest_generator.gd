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
@export var grass_count: int = 6000
@export var flower_count: int = 1600
@export var mountain_count: int = 28
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
	var base := Vector3(p.x, 0, p.y)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	_push("pine_trunk", p, Transform3D(basis, base + Vector3(0, 0.9 * s, 0)), Color(0.42, 0.29, 0.19))
	var green := Color.from_hsv(_rng.randf_range(0.30, 0.38), _rng.randf_range(0.45, 0.62), _rng.randf_range(0.30, 0.42))
	var layers := [[1.9, 1.0], [2.9, 0.78], [3.75, 0.55]]
	for layer in layers:
		var ls: float = layer[1]
		var lb := Basis(Vector3.UP, yaw + ls).scaled(Vector3(s * ls, s * ls, s * ls))
		_push("pine_layer", p, Transform3D(lb, base + Vector3(0, layer[0] * s, 0)), green.lightened((1.0 - ls) * 0.25))


func _add_broadleaf(p: Vector2, autumn: bool) -> void:
	var s := _rng.randf_range(0.85, 1.35)
	var yaw := _rng.randf() * TAU
	var base := Vector3(p.x, 0, p.y)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	_push("oak_trunk", p, Transform3D(basis, base + Vector3(0, 1.1 * s, 0)), Color(0.40, 0.30, 0.21))
	var crown: Color
	if autumn:
		crown = Color.from_hsv(_rng.randf_range(0.03, 0.12), _rng.randf_range(0.65, 0.85), _rng.randf_range(0.65, 0.85))
	else:
		crown = Color.from_hsv(_rng.randf_range(0.22, 0.32), _rng.randf_range(0.45, 0.65), _rng.randf_range(0.38, 0.55))
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
	body.position = Vector3(p.x, 0, p.y)
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
		var grey := _rng.randf_range(0.45, 0.62)
		var tint := Color(grey, grey * 1.01, grey * 1.04)
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
	var c := Color.from_hsv(_rng.randf_range(0.22, 0.30), _rng.randf_range(0.45, 0.65), _rng.randf_range(0.42, 0.6))
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
	_register("grass", _lifted(grass, 0.16), _foliage_material(0.07, 0.0, 0.32), detail_view_distance)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.018
	stem.height = 0.26
	stem.radial_segments = 3
	stem.rings = 0
	_register("flower_stem", _lifted(stem, 0.13), _foliage_material(0.05, 0.0, 0.26), detail_view_distance)

	var flower := SphereMesh.new()
	flower.radius = 0.07
	flower.height = 0.09
	flower.radial_segments = 5
	flower.rings = 2
	_register("flower", flower, _foliage_material(0.05, -0.3, 0.3), detail_view_distance)


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
		if kind in ["grass", "flower", "flower_stem", "bush"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_root.add_child(mmi)
	_batches.clear()
