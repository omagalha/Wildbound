class_name DayNightCycle
extends Node
## Ciclo de dia e noite: gira o sol, troca para a lua à noite, ajusta céu,
## luz ambiente e névoa, e mostra o relógio no canto da tela.
##
## O tempo corre só com o jogo rodando (não com a árvore pausada) e é salvo
## pelo SaveManager (dia e hora).

signal day_started(day: int)
signal night_started(day: int)

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
## Segundos reais por dia completo de 24 h.
@export var day_length: float = 900.0
@export_range(0.0, 24.0) var start_hour: float = 8.0
## Mostra o relógio na tela.
@export var show_clock: bool = true

var day: int = 1
var hour: float = 8.0

const DAWN := 6.0
const DUSK := 19.0

var _was_night := false
var _clock: Label
var _clock_layer: CanvasLayer
var _sky: ProceduralSkyMaterial

# Paletas: [topo do céu, horizonte, cor da luz, energia da luz, energia ambiente, névoa]
const PALETTE_NIGHT := [Color(0.03, 0.05, 0.13), Color(0.10, 0.13, 0.24), Color(0.55, 0.65, 1.0), 0.22, 0.28, Color(0.08, 0.10, 0.18)]
const PALETTE_DAWN := [Color(0.30, 0.38, 0.62), Color(0.95, 0.62, 0.42), Color(1.0, 0.72, 0.5), 0.65, 0.45, Color(0.85, 0.65, 0.55)]
const PALETTE_DAY := [Color(0.30, 0.54, 0.86), Color(0.72, 0.84, 0.93), Color(1.0, 0.97, 0.9), 1.0, 0.6, Color(0.72, 0.82, 0.9)]


func _ready() -> void:
	hour = start_hour
	if world_environment != null and world_environment.environment != null:
		var sky := world_environment.environment.sky
		if sky != null and sky.sky_material is ProceduralSkyMaterial:
			# Cópia própria para não alterar o recurso compartilhado do arquivo.
			_sky = (sky.sky_material as ProceduralSkyMaterial).duplicate()
			sky.sky_material = _sky
	if show_clock and DisplayServer.get_name() != "headless":
		_build_clock()
	_was_night = is_night()
	apply_lighting()


func _process(delta: float) -> void:
	advance(delta)


## Avança o relógio em [param seconds] reais.
func advance(seconds: float) -> void:
	if day_length <= 0.0:
		return
	hour += seconds * 24.0 / day_length
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	var night := is_night()
	if night != _was_night:
		_was_night = night
		if night:
			night_started.emit(day)
		else:
			day_started.emit(day)
	apply_lighting()


func is_night() -> bool:
	return hour < DAWN or hour >= DUSK


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "Dia %d · %02d:%02d %s" % [day, h, m, "☾" if is_night() else "☀"]


func get_save_data() -> Dictionary:
	return {"day": day, "hour": hour}


func apply_save_data(data: Dictionary) -> void:
	day = maxi(int(data.get("day", 1)), 1)
	hour = clampf(float(data.get("hour", start_hour)), 0.0, 23.999)
	_was_night = is_night()
	apply_lighting()


## Permite que um HUD composto substitua o relógio legado sem recriá-lo.
func set_builtin_clock_visible(visible: bool) -> void:
	show_clock = visible
	if _clock_layer != null:
		_clock_layer.visible = visible


## Altura do sol de -1 (meia-noite) a 1 (meio-dia).
func sun_height() -> float:
	return sin((hour - 6.0) / 24.0 * TAU)


func apply_lighting() -> void:
	var palette := _palette()
	if sun != null:
		var h := sun_height()
		# À noite a mesma luz vira a lua, do lado oposto do céu.
		var elevation := asin(clampf(absf(h), 0.0, 1.0))
		elevation = maxf(elevation, deg_to_rad(12.0))
		var azimuth := (hour / 24.0) * TAU + (PI if h < 0.0 else 0.0)
		sun.rotation = Vector3(-elevation, azimuth, 0.0)
		sun.light_color = palette[2]
		sun.light_energy = palette[3]
	if _sky != null:
		_sky.sky_top_color = palette[0]
		_sky.sky_horizon_color = palette[1]
		_sky.ground_horizon_color = palette[1]
		_sky.ground_bottom_color = (palette[0] as Color).darkened(0.5)
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.ambient_light_energy = palette[4]
		env.fog_light_color = palette[5]
	if _clock != null:
		_clock.text = clock_text()


## Mistura as paletas conforme a hora: noite → aurora → dia → crepúsculo → noite.
func _palette() -> Array:
	if hour < 5.0 or hour >= 20.5:
		return PALETTE_NIGHT
	if hour < 6.5:
		return _mix(PALETTE_NIGHT, PALETTE_DAWN, (hour - 5.0) / 1.5)
	if hour < 8.0:
		return _mix(PALETTE_DAWN, PALETTE_DAY, (hour - 6.5) / 1.5)
	if hour < 17.5:
		return PALETTE_DAY
	if hour < 19.0:
		return _mix(PALETTE_DAY, PALETTE_DAWN, (hour - 17.5) / 1.5)
	return _mix(PALETTE_DAWN, PALETTE_NIGHT, (hour - 19.0) / 1.5)


func _mix(a: Array, b: Array, t: float) -> Array:
	t = smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
	var out := []
	for i in a.size():
		if a[i] is Color:
			out.append((a[i] as Color).lerp(b[i], t))
		else:
			out.append(lerpf(a[i], b[i], t))
	return out


func _build_clock() -> void:
	_clock_layer = CanvasLayer.new()
	_clock_layer.layer = 1
	add_child(_clock_layer)
	_clock = Label.new()
	_clock.anchor_left = 0.5
	_clock.anchor_right = 0.5
	_clock.offset_left = -150.0
	_clock.offset_right = 150.0
	_clock.offset_top = 16.0
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock.add_theme_constant_override("outline_size", 5)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_layer.add_child(_clock)
