class_name IslandTerrain
extends Node3D
## A ilha: relevo, regiões, praias e mar, gerados de forma determinística.
##
## Uma ilha de ~1,2 km de diâmetro num quadrado de 1,5 km cercado de mar.
## O centro (raio [member flat_radius]) é a Floresta Primordial, plana em
## y = 0, onde fica tudo o que já existia. Para fora, quatro regiões em
## setores: norte Montanhas Geladas, leste Terras Rochosas, sul Região
## Vulcânica (com um vulcão), oeste Planícies Douradas (com um lago).
##
## Qualquer sistema pode perguntar [method height_at] e [method biome_at]
## (pelo grupo "island_terrain" ou por [method find]). A malha é dividida em
## pedaços com distância de visibilidade; a colisão é um HeightMapShape3D.

signal generated

const GROUP := &"island_terrain"

enum Biome { FOREST, SNOW, ROCKY, VOLCANIC, PLAINS, BEACH, WATER }
const BIOME_NAMES := ["Floresta Primordial", "Montanhas Geladas", "Terras Rochosas", "Região Vulcânica", "Planícies Douradas", "Praia", "Água"]
## Nível de perigo sugerido por região (1 = início).
const BIOME_DANGER := [1, 3, 2, 4, 2, 1, 1]
## Direção central de cada setor (N = -Z).
const SECTORS := {Biome.SNOW: Vector2(0, -1), Biome.ROCKY: Vector2(1, 0), Biome.VOLCANIC: Vector2(0, 1), Biome.PLAINS: Vector2(-1, 0)}

const TERRAIN_SHADER := preload("res://resources/shaders/terrain.gdshader")
const WATER_SHADER := preload("res://resources/shaders/water.gdshader")

@export var world_seed: int = 2026
## Metade do lado do mundo (o mar vai até aqui).
@export var half_size: float = 750.0
## Tamanho de cada célula da grade de altura.
@export var cell: float = 4.0
@export var coast_radius: float = 590.0
## Centro plano em y = 0 (todo o conteúdo inicial fica aqui).
@export var flat_radius: float = 225.0
## Onde o relevo das regiões atinge força total.
@export var blend_radius: float = 340.0
@export var sea_level: float = -1.5
@export var volcano_center: Vector2 = Vector2(30, 470)
@export var lake_center: Vector2 = Vector2(-430, 40)
@export var chunk_cells: int = 25
@export var view_distance: float = 1100.0
@export var generate_on_ready: bool = true

var generated_ok := false
var grid_size := 0
var heights := PackedFloat32Array()

var _coast := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _angle := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _noise_ready := false


func _ready() -> void:
	add_to_group(GROUP)
	_setup_noise()
	if generate_on_ready:
		generate()


## O terreno da cena atual (ou null).
static func find(tree: SceneTree) -> IslandTerrain:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as IslandTerrain


# ---------- consultas ----------

## Altura do chão em (x, z). Determinística e barata (sem consultar física).
func height_at(x: float, z: float) -> float:
	_setup_noise()
	var r := Vector2(x, z).length()
	var outer := smoothstep(flat_radius, blend_radius, r)
	var weights := sector_weights(x, z)
	var hills := _hills.get_noise_2d(x, z) * 0.5 + 0.5
	var base := 2.5 + hills * 13.0 + (_detail.get_noise_2d(x, z) * 0.5 + 0.5) * 2.5
	# Planícies: mais suaves.
	base *= 1.0 - 0.55 * float(weights[Biome.PLAINS])
	# Montanhas Geladas: cristas altas, crescendo para o norte.
	var ridge := 1.0 - absf(_ridge.get_noise_2d(x * 0.8, z * 0.8))
	var snow: float = weights[Biome.SNOW] * smoothstep(260.0, 470.0, r) * (25.0 + ridge * ridge * 115.0)
	# Terras Rochosas: platôs em degraus.
	var mesa := (_hills.get_noise_2d(x * 1.7 + 300.0, z * 1.7) * 0.5 + 0.5) * 48.0
	var stepped := floorf(mesa / 9.0) * 9.0 + smoothstep(0.75, 1.0, fmod(mesa, 9.0) / 9.0) * 9.0
	var rocky: float = weights[Biome.ROCKY] * smoothstep(260.0, 420.0, r) * stepped
	var land: float = (base + snow + rocky) * outer
	# Vulcão com cratera.
	var vd := Vector2(x, z).distance_to(volcano_center)
	land += 125.0 * pow(maxf(0.0, 1.0 - vd / 190.0), 1.7) - 40.0 * pow(maxf(0.0, 1.0 - vd / 32.0), 1.4)
	# Lago nas planícies.
	var ld := Vector2(x, z).distance_to(lake_center)
	land -= 9.0 * smoothstep(75.0, 20.0, ld)
	# Costa irregular: abaixo do mar fora da ilha.
	var coast := coast_radius + _coast.get_noise_2d(cos(atan2(z, x)) * 200.0, sin(atan2(z, x)) * 200.0) * 75.0
	var mask := 1.0 - smoothstep(coast - 110.0, coast + 25.0, r)
	var sea_floor := sea_level - 4.0 - smoothstep(coast, coast + 140.0, r) * 14.0
	return lerpf(sea_floor, land, mask)


## Pesos (0–1) de cada setor em (x, z); bordas onduladas por ruído.
func sector_weights(x: float, z: float) -> Dictionary:
	_setup_noise()
	var r := Vector2(x, z).length()
	var out := {Biome.SNOW: 0.0, Biome.ROCKY: 0.0, Biome.VOLCANIC: 0.0, Biome.PLAINS: 0.0}
	if r < 1.0:
		return out
	var angle := atan2(z, x) + _angle.get_noise_2d(x, z) * 0.45
	var dir := Vector2(cos(angle), sin(angle))
	var total := 0.0
	for b in SECTORS:
		var w := pow(maxf(0.0, dir.dot(SECTORS[b])), 3.0)
		out[b] = w
		total += w
	if total > 0.0:
		for b in out:
			out[b] /= total
	return out


func biome_at(x: float, z: float) -> int:
	var h := height_at(x, z)
	if h < sea_level:
		return Biome.WATER
	var r := Vector2(x, z).length()
	if h < sea_level + 3.0 and r > flat_radius + 60.0 and Vector2(x, z).distance_to(lake_center) > 90.0:
		return Biome.BEACH
	if Vector2(x, z).distance_to(volcano_center) < 210.0:
		return Biome.VOLCANIC
	if r < (flat_radius + blend_radius) * 0.5:
		return Biome.FOREST
	var weights := sector_weights(x, z)
	var best := Biome.FOREST
	var best_w := 0.0
	for b in weights:
		if weights[b] > best_w:
			best = b
			best_w = weights[b]
	return best


func biome_name_at(x: float, z: float) -> String:
	return BIOME_NAMES[biome_at(x, z)]


func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < sea_level


# ---------- geração ----------

func generate() -> void:
	if generated_ok:
		return
	_setup_noise()
	grid_size = int(round(half_size * 2.0 / cell)) + 1
	heights.resize(grid_size * grid_size)
	for iz in grid_size:
		var z := -half_size + iz * cell
		for ix in grid_size:
			heights[iz * grid_size + ix] = height_at(-half_size + ix * cell, z)
	_build_collision()
	_build_chunks()
	_build_water()
	_build_volcano()
	generated_ok = true
	generated.emit()


func _setup_noise() -> void:
	if _noise_ready:
		return
	_noise_ready = true
	for pair in [[_coast, 0.012, 3], [_hills, 0.006, 4], [_ridge, 0.005, 5], [_angle, 0.002, 2], [_detail, 0.03, 2]]:
		var n: FastNoiseLite = pair[0]
		n.seed = world_seed + int(pair[1] * 10000.0)
		n.frequency = pair[1]
		n.fractal_octaves = pair[2]
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = grid_size
	hm.map_depth = grid_size
	hm.map_data = heights
	shape.shape = hm
	shape.scale = Vector3(cell, 1.0, cell)
	body.add_child(shape)
	add_child(body)


func _grid_h(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, grid_size - 1)
	iz = clampi(iz, 0, grid_size - 1)
	return heights[iz * grid_size + ix]


func _build_chunks() -> void:
	var root := Node3D.new()
	root.name = "Chunks"
	add_child(root)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("sea_level", sea_level)
	var cells := grid_size - 1
	var chunk := chunk_cells
	for cz in range(0, cells, chunk):
		for cx in range(0, cells, chunk):
			var mesh := _chunk_mesh(cx, cz, mini(chunk, cells - cx), mini(chunk, cells - cz))
			if mesh == null:
				continue
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.visibility_range_end = view_distance
			root.add_child(mi)


func _chunk_mesh(cx: int, cz: int, w: int, d: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var any_land := false
	for iz in d + 1:
		for ix in w + 1:
			var gx := cx + ix
			var gz := cz + iz
			var x := -half_size + gx * cell
			var z := -half_size + gz * cell
			var h := _grid_h(gx, gz)
			if h > sea_level - 6.0:
				any_land = true
			verts.append(Vector3(x, h, z))
			var n := Vector3(_grid_h(gx - 1, gz) - _grid_h(gx + 1, gz), 2.0 * cell, _grid_h(gx, gz - 1) - _grid_h(gx, gz + 1)).normalized()
			normals.append(n)
			colors.append(_vertex_color(x, z, h, n))
	if not any_land:
		return null  # fundo do mar distante: o plano da água cobre
	var row := w + 1
	for iz in d:
		for ix in w:
			var a := iz * row + ix
			indices.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Cor do chão por região, altura e inclinação. O alfa diz quanto do visual
## "floresta" (o shader antigo do chão) usar.
func _vertex_color(x: float, z: float, h: float, n: Vector3) -> Color:
	var r := Vector2(x, z).length()
	var forest_amount := 1.0 - smoothstep(flat_radius, blend_radius, r)
	var weights := sector_weights(x, z)
	var c := Color(0.33, 0.5, 0.24) * (1.0 - 0.0)
	var snow_c := Color(0.42, 0.5, 0.36).lerp(Color(0.95, 0.97, 1.0), smoothstep(38.0, 62.0, h))
	var rocky_c := Color(0.62, 0.45, 0.3).lerp(Color(0.74, 0.58, 0.4), smoothstep(10.0, 40.0, h))
	var plains_c := Color(0.62, 0.62, 0.3)
	var volcanic_c := Color(0.2, 0.18, 0.17).lerp(Color(0.35, 0.16, 0.1), smoothstep(60.0, 110.0, h))
	var sector := c * 0.0
	sector += snow_c * weights[Biome.SNOW]
	sector += rocky_c * weights[Biome.ROCKY]
	sector += volcanic_c * weights[Biome.VOLCANIC]
	sector += plains_c * weights[Biome.PLAINS]
	var vd := Vector2(x, z).distance_to(volcano_center)
	c = c.lerp(sector, smoothstep(flat_radius, blend_radius, r))
	# O vulcão escurece o chão em volta, mesmo perto da floresta.
	c = c.lerp(volcanic_c, smoothstep(240.0, 150.0, vd))
	# Encostas íngremes viram rocha; perto do mar, areia; debaixo d'água, areia molhada.
	var steep := 1.0 - n.y
	var rock := Color(0.45, 0.43, 0.4) if vd > 230.0 else Color(0.16, 0.14, 0.14)
	c = c.lerp(rock, smoothstep(0.25, 0.5, steep))
	if r > flat_radius + 60.0:
		c = c.lerp(Color(0.86, 0.78, 0.56), smoothstep(sea_level + 3.5, sea_level + 1.0, h))
	c = c.lerp(Color(0.55, 0.5, 0.38), smoothstep(sea_level, sea_level - 3.0, h))
	c.a = forest_amount * smoothstep(150.0, 240.0, vd)
	return c


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_size * 6.0, half_size * 6.0)
	plane.subdivide_width = 200
	plane.subdivide_depth = 200
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	plane.material = mat
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position.y = sea_level
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_volcano() -> void:
	var crater_y := height_at(volcano_center.x, volcano_center.y)
	var lava_mat := StandardMaterial3D.new()
	lava_mat.albedo_color = Color(1.0, 0.4, 0.08)
	lava_mat.emission_enabled = true
	lava_mat.emission = Color(1.0, 0.35, 0.05)
	lava_mat.emission_energy_multiplier = 3.0
	lava_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pool := CylinderMesh.new()
	pool.top_radius = 22.0
	pool.bottom_radius = 22.0
	pool.height = 0.4
	pool.radial_segments = 16
	pool.rings = 0
	pool.material = lava_mat
	var mi := MeshInstance3D.new()
	mi.name = "Lava"
	mi.mesh = pool
	mi.position = Vector3(volcano_center.x, crater_y + 3.0, volcano_center.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 6.0
	light.omni_range = 60.0
	light.position = mi.position + Vector3(0, 10, 0)
	add_child(light)
	var smoke := CPUParticles3D.new()
	smoke.name = "VolcanoSmoke"
	smoke.amount = 40
	smoke.lifetime = 14.0
	smoke.preprocess = 14.0
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 4.0
	smoke.initial_velocity_max = 7.0
	smoke.gravity = Vector3(1.2, 0.3, 0.4)
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 12.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 12.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.3, 0.28, 0.27, 0.7), Color(0.55, 0.53, 0.52, 0.0)])
	smoke.color_ramp = ramp
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 6
	puff.rings = 3
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = smoke_mat
	smoke.mesh = puff
	smoke.position = mi.position + Vector3(0, 6, 0)
	add_child(smoke)
