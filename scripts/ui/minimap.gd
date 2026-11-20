class_name WildboundMinimap
extends Control
## Minimapa redondo com o desenho da ilha.
##
## A imagem da ilha é "assada" uma vez a partir do IslandTerrain (cores das
## regiões, sombra do relevo, mar raso/fundo e praias) e recortada num círculo
## centrado no jogador por um shader. Por cima: zonas, acampamentos, ruína,
## tocas, sua base e a seta do jogador. Sem segunda câmera 3D (leve para o
## celular). Norte para cima.

@export var player: Node3D
## Metros do centro até a borda do círculo.
@export_range(40.0, 400.0, 5.0) var view_radius: float = 130.0
@export_range(0.05, 1.0, 0.05) var refresh_interval: float = 0.1
## Tamanho de cada pixel da imagem da ilha, em metros.
@export var bake_meters_per_pixel: float = 6.0

const SHADER := preload("res://resources/shaders/minimap.gdshader")
const COLOR_FRAME := Color(0.85, 0.7, 0.38, 1.0)
const COLOR_FRAME_DARK := Color(0.2, 0.15, 0.08, 1.0)
const COLOR_PLAYER := Color(1.0, 0.86, 0.36, 1.0)
const COLOR_TEXT := Color(0.92, 0.94, 0.86, 1.0)
const COLOR_SAFE := Color(0.35, 0.9, 0.5, 0.18)
const COLOR_SAFE_EDGE := Color(0.5, 1.0, 0.62, 0.6)
const COLOR_DANGER := Color(0.95, 0.35, 0.25, 0.16)
const COLOR_DANGER_EDGE := Color(1.0, 0.45, 0.32, 0.65)
const LABEL_HEIGHT := 34.0
## Diâmetro do círculo numa tela de 720 px de altura; escala com a altura.
const BASE_DIAMETER := 160.0

var _view: TextureRect
var _overlay: Control
var _material: ShaderMaterial
var _terrain: IslandTerrain
var _world_half := 750.0
var _refresh_left := 0.0
var _poi_left := 0.0
var _zones: Array[TerritoryZone] = []
var _camps: Array = []
var _ruins: Array = []
var _base_points: Array[Vector3] = []
var ui_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_apply_scale()
	get_viewport().size_changed.connect(_apply_scale)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_view = TextureRect.new()
	_view.name = "MapView"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.material = _material
	add_child(_view)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(_layout)
	_layout()
	_bake.call_deferred()


func _process(delta: float) -> void:
	_refresh_left -= delta
	_poi_left -= delta
	if _poi_left <= 0.0:
		_poi_left = 2.0
		_refresh_points()
	if _refresh_left <= 0.0:
		_refresh_left = refresh_interval
		_update_view()
		_overlay.queue_redraw()


# ---------- API (testes e HUD) ----------

## Diâmetro do círculo para a tela atual.
func diameter() -> float:
	return BASE_DIAMETER * ui_scale


func _apply_scale() -> void:
	var h := get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
	ui_scale = clampf(h / 720.0, 0.8, 1.8)
	custom_minimum_size = Vector2(diameter() + 16.0 * ui_scale, diameter() + 12.0 * ui_scale + LABEL_HEIGHT * ui_scale)
	size = custom_minimum_size
	if _view != null:
		_layout()


## Quadrado que contém o círculo do mapa.
func get_map_rect() -> Rect2:
	var d := diameter()
	return Rect2(Vector2((size.x - d) * 0.5, 10.0 * ui_scale), Vector2(d, d))


func world_to_map(world_position: Vector3) -> Vector2:
	var area := get_map_rect()
	var mpp := (view_radius * 2.0) / area.size.x
	var offset := Vector2(world_position.x, world_position.z) - _center_world()
	return area.get_center() + offset / mpp


func is_world_position_visible(world_position: Vector3) -> bool:
	var area := get_map_rect()
	return world_to_map(world_position).distance_to(area.get_center()) <= area.size.x * 0.5


func has_terrain_image() -> bool:
	return _view.texture != null


# ---------- interno ----------

func _layout() -> void:
	var area := get_map_rect()
	_view.position = area.position
	_view.size = area.size


func _center_world() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	return Vector2(player.global_position.x, player.global_position.z)


func _update_view() -> void:
	var c := _center_world()
	_material.set_shader_parameter("center_uv", (c + Vector2(_world_half, _world_half)) / (_world_half * 2.0))
	_material.set_shader_parameter("radius_uv", view_radius / (_world_half * 2.0))


## Desenha a ilha numa imagem (uma vez).
func _bake() -> void:
	_terrain = IslandTerrain.find(get_tree()) if is_inside_tree() else null
	var px: int
	var img: Image
	if _terrain == null:
		img = Image.create(8, 8, false, Image.FORMAT_RGB8)
		img.fill(Color(0.2, 0.36, 0.2))
		_world_half = 160.0
	else:
		_world_half = _terrain.half_size
		px = int(_world_half * 2.0 / bake_meters_per_pixel)
		img = Image.create(px, px, false, Image.FORMAT_RGB8)
		var step := bake_meters_per_pixel
		var light := Vector3(-0.5, 0.75, -0.45).normalized()
		for iy in px:
			var z := -_world_half + (iy + 0.5) * step
			for ix in px:
				var x := -_world_half + (ix + 0.5) * step
				var h := _terrain.height_at(x, z)
				var col := _pixel_color(x, z, h)
				if h >= _terrain.sea_level:
					var hx := _terrain.height_at(x + step, z) - h
					var hz := _terrain.height_at(x, z + step) - h
					var n := Vector3(-hx, step, -hz).normalized()
					col = col * clampf(0.55 + n.dot(light) * 0.6, 0.6, 1.2)
				img.set_pixel(ix, iy, col)
	_view.texture = ImageTexture.create_from_image(img)
	_material.set_shader_parameter("map_tex", _view.texture)
	_update_view()


func _pixel_color(x: float, z: float, h: float) -> Color:
	var sea := _terrain.sea_level
	if h < sea:
		var depth := clampf((sea - h) / 14.0, 0.0, 1.0)
		return Color(0.25, 0.62, 0.68).lerp(Color(0.06, 0.24, 0.38), depth)
	var B := IslandTerrain.Biome
	match _terrain.biome_at(x, z):
		B.BEACH: return Color(0.9, 0.82, 0.58)
		B.SNOW: return Color(0.42, 0.55, 0.38).lerp(Color(0.96, 0.97, 1.0), smoothstep(30.0, 60.0, h))
		B.ROCKY: return Color(0.78, 0.5, 0.32)
		B.VOLCANIC:
			var vd := Vector2(x, z).distance_to(_terrain.volcano_center)
			return Color(1.0, 0.45, 0.1) if vd < 24.0 else Color(0.24, 0.2, 0.2)
		B.PLAINS: return Color(0.78, 0.74, 0.36)
	return Color(0.3, 0.55, 0.26)


func _refresh_points() -> void:
	if not is_inside_tree():
		return
	_zones.clear()
	for node in get_tree().get_nodes_in_group(&"territory_zones"):
		if node is TerritoryZone:
			_zones.append(node)
	_camps = get_tree().get_nodes_in_group(&"abandoned_camps")
	if _ruins.is_empty():
		_ruins = get_tree().root.find_children("*", "AncestralRuin", true, false)
	_base_points.clear()
	for node in get_tree().root.find_children("*", "BuildingPiece", true, false):
		var piece := node as BuildingPiece
		if piece.piece_id == &"" or String(piece.piece_id).begins_with("camp_"):
			continue
		if piece is SurvivalBed or piece is StorageChest or piece is Furnace or (piece.definition != null and piece.definition.id == &"building_campfire_primitive"):
			_base_points.append(piece.global_position)


func _draw_overlay() -> void:
	var area := get_map_rect()
	var center := area.get_center()
	var radius := area.size.x * 0.5
	var mpp := (view_radius * 2.0) / area.size.x
	var font := ThemeDB.fallback_font
	# Zonas (seguras e de perigo), recortadas pelo círculo.
	for zone in _zones:
		if not is_instance_valid(zone):
			continue
		var p := world_to_map(zone.global_position)
		var rp := zone.radius / mpp
		if p.distance_to(center) - rp > radius:
			continue
		var safe := zone.level == TerritoryZone.Level.SAFE
		_overlay.draw_circle(p, rp, COLOR_SAFE if safe else COLOR_DANGER)
		_overlay.draw_arc(p, rp, 0.0, TAU, 32, COLOR_SAFE_EDGE if safe else COLOR_DANGER_EDGE, 1.2, true)
		if not safe and rp < 9.0:
			_draw_paw(p)
	# Acampamentos (tenda), ruína (losango) e base (casinha).
	for camp in _camps:
		if is_instance_valid(camp):
			_draw_icon(camp.global_position, "camp", bool(camp.get("is_discovered")))
	for ruin in _ruins:
		if is_instance_valid(ruin):
			_draw_icon(ruin.global_position, "ruin", ruin.is_completed())
	var drawn_base := false
	for p in _base_points:
		if not drawn_base or p.distance_to(_base_points[0]) > 30.0:
			_draw_icon(p, "base", true)
			drawn_base = true
	# Moldura dourada com sombra e marcas dos pontos cardeais.
	_overlay.draw_arc(center, radius + 3.0, 0.0, TAU, 64, COLOR_FRAME_DARK, 6.0, true)
	_overlay.draw_arc(center, radius + 1.5, 0.0, TAU, 64, COLOR_FRAME, 2.5, true)
	for i in 4:
		var a := -PI * 0.5 + i * PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		_overlay.draw_line(center + dir * (radius - 5.0), center + dir * (radius + 3.0), COLOR_FRAME, 2.0, true)
	var n_pos := center + Vector2(0, -radius - 2.0)
	_overlay.draw_circle(n_pos, 8.0 * ui_scale, COLOR_FRAME_DARK)
	_overlay.draw_circle(n_pos, 7.0 * ui_scale, COLOR_FRAME)
	_overlay.draw_string(font, n_pos + Vector2(-4.0, 4.5) * ui_scale, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * ui_scale), COLOR_FRAME_DARK)
	_draw_player(center)
	# Região e coordenadas embaixo.
	var region := "Floresta"
	if _terrain != null and player != null:
		region = _terrain.biome_name_at(player.global_position.x, player.global_position.z)
	var c := _center_world()
	var k := ui_scale
	var label_y := area.end.y + 16.0 * k
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.03, 0.05, 0.04, 0.82)
	pill.border_color = COLOR_FRAME.darkened(0.3)
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(9)
	var pill_w := maxf(font.get_string_size(region, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k)).x + 24.0 * k, 104.0 * k)
	pill.draw(_overlay.get_canvas_item(), Rect2((size.x - pill_w) * 0.5, label_y - 12.0 * k, pill_w, 28.0 * k))
	_overlay.draw_string(font, Vector2(0, label_y), region, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(12 * k), COLOR_TEXT)
	_overlay.draw_string(font, Vector2(0, label_y + 12.0 * k), "X %d · Z %d" % [roundi(c.x), roundi(c.y)], HORIZONTAL_ALIGNMENT_CENTER, size.x, int(10 * k), COLOR_TEXT.darkened(0.25))


func _draw_icon(world: Vector3, kind: String, active: bool) -> void:
	var area := get_map_rect()
	var p := world_to_map(world)
	var radius := area.size.x * 0.5 - 8.0
	var off := p - area.get_center()
	var outside := off.length() > radius
	if outside:
		if kind == "camp" and not active:
			return  # acampamentos não descobertos não aparecem fora do alcance
		p = area.get_center() + off.normalized() * radius  # preso na borda, apontando a direção
	var dark := Color(0.08, 0.06, 0.04, 0.95)
	match kind:
		"camp":
			var col := Color(1.0, 0.82, 0.4) if active else Color(0.85, 0.85, 0.85, 0.75)
			var tri := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 5), p + Vector2(-7, 5)])
			_overlay.draw_colored_polygon(tri, dark)
			_overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 4), p + Vector2(-5, 4)]), col)
		"ruin":
			var col := Color(1.0, 0.55, 0.15) if not active else Color(1.0, 0.85, 0.4)
			var dia := PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, 0), p + Vector2(0, 8), p + Vector2(-7, 0)])
			_overlay.draw_colored_polygon(dia, dark)
			_overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)]), col)
		"base":
			var col := Color(0.45, 0.85, 1.0)
			_overlay.draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 9)), dark)
			_overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(8, -1), p + Vector2(-8, -1)]), dark)
			_overlay.draw_rect(Rect2(p + Vector2(-4.5, -1), Vector2(9, 6.5)), col)
			_overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, -1.5), p + Vector2(-6, -1.5)]), col)


func _draw_paw(p: Vector2) -> void:
	var col := Color(1.0, 0.4, 0.3, 0.9)
	_overlay.draw_circle(p + Vector2(0, 1.5), 2.6, col)
	for o in [Vector2(-3, -2.5), Vector2(0, -3.8), Vector2(3, -2.5)]:
		_overlay.draw_circle(p + o, 1.3, col)


func _draw_player(center: Vector2) -> void:
	var yaw := 0.0
	if player != null and is_instance_valid(player):
		var visual := player.get_node_or_null("Visual") as Node3D
		yaw = visual.global_rotation.y if visual != null else player.global_rotation.y
	var k := ui_scale * 0.85
	var forward := Vector2(-sin(yaw), -cos(yaw)) * k
	var right := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center + forward * 10.0,
		center - forward * 6.0 + right * 6.0,
		center - forward * 2.5,
		center - forward * 6.0 - right * 6.0,
	])
	_overlay.draw_circle(center, 12.0 * k, Color(0, 0, 0, 0.25))
	_overlay.draw_colored_polygon(points, COLOR_PLAYER)
	_overlay.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.15, 0.1, 0.03, 1.0), 1.6, true)
