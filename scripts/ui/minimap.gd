class_name WildboundMinimap
extends Control
## Minimapa 2D leve, desenhado pelas coordenadas X/Z do mundo.
##
## Não usa uma segunda câmera 3D: isso evita renderizar a floresta novamente e
## mantém o componente adequado ao futuro alvo mobile. Recursos e inimigos não
## aparecem, preservando a exploração e a habilidade do Lumaru.

@export var player: Node3D
## Metros visíveis do centro até a borda vertical do mapa.
@export_range(20.0, 120.0, 1.0) var view_radius: float = 55.0
## Intervalo entre redesenhos. Dez atualizações por segundo são suficientes.
@export_range(0.05, 1.0, 0.05) var refresh_interval: float = 0.1
@export_range(5.0, 50.0, 5.0) var grid_step: float = 20.0

const COLOR_FRAME := Color(0.55, 0.68, 0.48, 0.9)
const COLOR_BACKGROUND := Color(0.035, 0.075, 0.065, 0.94)
const COLOR_INNER := Color(0.075, 0.13, 0.105, 0.96)
const COLOR_GRID := Color(0.55, 0.68, 0.55, 0.12)
const COLOR_SAFE := Color(0.28, 0.72, 0.43, 0.20)
const COLOR_SAFE_EDGE := Color(0.45, 0.9, 0.58, 0.48)
const COLOR_DANGER := Color(0.9, 0.38, 0.25, 0.18)
const COLOR_DANGER_EDGE := Color(1.0, 0.5, 0.34, 0.52)
const COLOR_PLAYER := Color(1.0, 0.83, 0.36, 1.0)
const COLOR_TEXT := Color(0.88, 0.93, 0.82, 1.0)

var _refresh_left := 0.0
var _zones: Array[TerritoryZone] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	_refresh_zones()
	queue_redraw()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = refresh_interval
		if _zones.is_empty():
			_refresh_zones()
		queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, COLOR_BACKGROUND, true)
	draw_rect(full.grow(-1.0), COLOR_FRAME, false, 2.0)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12.0, 19.0), "MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, COLOR_TEXT)
	draw_string(font, Vector2(size.x - 27.0, 19.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, COLOR_PLAYER)

	var area := get_map_rect()
	draw_rect(area, COLOR_INNER, true)
	_draw_grid(area)
	_draw_zones(area)
	_draw_player(area)
	draw_rect(area, COLOR_FRAME.darkened(0.2), false, 1.0)

	var position_text := "X %d  Z %d" % [roundi(_center_world().x), roundi(_center_world().y)]
	draw_string(font, Vector2(12.0, size.y - 7.0), position_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COLOR_TEXT.darkened(0.12))


func get_map_rect() -> Rect2:
	return Rect2(10.0, 26.0, maxf(size.x - 20.0, 1.0), maxf(size.y - 45.0, 1.0))


## Converte uma posição 3D em coordenada local do minimapa.
func world_to_map(world_position: Vector3) -> Vector2:
	var area := get_map_rect()
	var meters_per_pixel := (view_radius * 2.0) / maxf(area.size.y, 1.0)
	var center := _center_world()
	var offset := Vector2(world_position.x, world_position.z) - center
	return area.get_center() + offset / meters_per_pixel


func is_world_position_visible(world_position: Vector3) -> bool:
	return get_map_rect().has_point(world_to_map(world_position))


func _center_world() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	return Vector2(player.global_position.x, player.global_position.z)


func _refresh_zones() -> void:
	_zones.clear()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"territory_zones"):
		var zone := node as TerritoryZone
		if zone != null:
			_zones.append(zone)


func _draw_grid(area: Rect2) -> void:
	var meters_per_pixel := (view_radius * 2.0) / maxf(area.size.y, 1.0)
	var horizontal_radius := area.size.x * meters_per_pixel * 0.5
	var center := _center_world()
	var first_x := floorf((center.x - horizontal_radius) / grid_step) * grid_step
	var last_x := center.x + horizontal_radius
	var x := first_x
	while x <= last_x:
		var px := world_to_map(Vector3(x, 0.0, center.y)).x
		draw_line(Vector2(px, area.position.y), Vector2(px, area.end.y), COLOR_GRID, 1.0)
		x += grid_step
	var first_z := floorf((center.y - view_radius) / grid_step) * grid_step
	var last_z := center.y + view_radius
	var z := first_z
	while z <= last_z:
		var py := world_to_map(Vector3(center.x, 0.0, z)).y
		draw_line(Vector2(area.position.x, py), Vector2(area.end.x, py), COLOR_GRID, 1.0)
		z += grid_step


func _draw_zones(area: Rect2) -> void:
	var meters_per_pixel := (view_radius * 2.0) / maxf(area.size.y, 1.0)
	for zone in _zones:
		if not is_instance_valid(zone):
			continue
		var center := world_to_map(zone.global_position)
		var radius_pixels := zone.radius / meters_per_pixel
		if center.x + radius_pixels < area.position.x or center.x - radius_pixels > area.end.x:
			continue
		if center.y + radius_pixels < area.position.y or center.y - radius_pixels > area.end.y:
			continue
		var fill := COLOR_SAFE if zone.level == TerritoryZone.Level.SAFE else COLOR_DANGER
		var edge := COLOR_SAFE_EDGE if zone.level == TerritoryZone.Level.SAFE else COLOR_DANGER_EDGE
		draw_circle(center, radius_pixels, fill)
		draw_arc(center, radius_pixels, 0.0, TAU, 40, edge, 1.25, true)


func _draw_player(area: Rect2) -> void:
	var center := area.get_center()
	var yaw := 0.0
	if player != null and is_instance_valid(player):
		var visual := player.get_node_or_null("Visual") as Node3D
		yaw = visual.global_rotation.y if visual != null else player.global_rotation.y
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center + forward * 9.0,
		center - forward * 6.0 + right * 5.0,
		center - forward * 3.0,
		center - forward * 6.0 - right * 5.0,
	])
	draw_colored_polygon(points, COLOR_PLAYER)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
		Color(0.12, 0.1, 0.04, 1.0), 1.5, true)
