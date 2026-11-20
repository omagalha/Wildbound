class_name TemperatureComponent
extends Node
## Frio e calor.
##
## Temperatura do lugar: depende da região, da altura (montanha esfria), da
## distância da cratera (vulcão esquenta) e da hora (noite esfria 8 °C).
## Fogo por perto aquece, água esfria. Roupa vestida protege (Casaco de pele
## contra frio, Manto refrescante contra calor). A temperatura do corpo segue
## a do ambiente aos poucos.
##   Com frio / Com calor   -> fome cai mais rápido.
##   Congelando / Queimando -> perde vida a cada 2 s (pode matar).
## Mostra um termômetro e tinge a borda da tela (azul/laranja).

signal status_changed(status: StringName)

const COMFORT := Vector2(8.0, 32.0)
const FREEZING := -2.0
const BURNING := 44.0
const CAUSE_COLD := &"cold"
const CAUSE_HEAT := &"heat"
const STATUS_TEXT := {
	&"freezing": "Congelando!", &"cold": "Com frio", &"comfort": "Confortável",
	&"hot": "Com calor", &"burning": "Queimando!",
}

@export var player: CharacterBody3D
@export var health: HealthComponent
@export var hunger: HungerComponent
@export var equipment: PlayerEquipment
@export var day_night: DayNightCycle
@export var damage_per_tick: float = 3.0
@export var damage_interval: float = 2.0
## Velocidade com que o corpo acompanha o ambiente (°C/s).
@export var adapt_rate: float = 1.5
@export var show_ui: bool = true

var body_temp := 20.0
var status: StringName = &"comfort"
var _check_left := 0.0
var _damage_left := 0.0
var _label: Label
var _status_label: Label
var _icon: Label
var _vignette: TextureRect
var _vignette_gradient: Gradient


func _ready() -> void:
	if show_ui:
		_build_ui()
	body_temp = ambient_temperature() if player != null else 20.0


func _physics_process(delta: float) -> void:
	tick(delta)


## Avança o clima do corpo (separado para testes).
func tick(delta: float) -> void:
	if player == null or health == null or health.is_dead():
		return
	var target := effective_temperature()
	body_temp = move_toward(body_temp, target, adapt_rate * delta * maxf(1.0, absf(target - body_temp) / 10.0))
	var new_status := status_for(body_temp)
	if new_status != status:
		status = new_status
		status_changed.emit(status)
	if hunger != null:
		hunger.debug_multiplier = 1.6 if status in [&"cold", &"freezing"] else (1.3 if status in [&"hot", &"burning"] else 1.0)
	if status == &"freezing" or status == &"burning":
		_damage_left -= delta
		if _damage_left <= 0.0:
			_damage_left = damage_interval
			if health.accepts_damage:
				health.apply_damage(DamageInfo.create(damage_per_tick, CAUSE_COLD if status == &"freezing" else CAUSE_HEAT))
	else:
		_damage_left = damage_interval
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.25
		_refresh_ui()


## Temperatura do lugar onde o jogador está (sem roupa nem fogo).
func ambient_temperature() -> float:
	return ambient_at(player.global_position)


func ambient_at(pos: Vector3) -> float:
	var terrain := IslandTerrain.find(get_tree())
	var t := 20.0
	if terrain != null:
		var B := IslandTerrain.Biome
		var biome := terrain.biome_at(pos.x, pos.z)
		match biome:
			B.SNOW: t = 4.0 - maxf(pos.y - 20.0, 0.0) * 0.18
			B.ROCKY: t = 29.0
			B.PLAINS: t = 24.0
			B.BEACH: t = 25.0
			B.VOLCANIC: t = 34.0
			B.WATER: t = 18.0
		var vd := Vector2(pos.x, pos.z).distance_to(terrain.volcano_center)
		var heat := clampf(1.0 - vd / 200.0, 0.0, 1.0)
		t += 32.0 * heat * heat
	if day_night != null and day_night.is_night():
		t -= 8.0
	return t


## Ambiente + fogo + água + roupa.
func effective_temperature() -> float:
	var t := ambient_temperature()
	if t < 22.0 and FireLight.is_point_lit(get_tree(), player.global_position, 2.0):
		t = minf(t + 22.0, 22.0)  # fogo aquece até ficar agradável
	if player.has_method("is_swimming") and player.is_swimming():
		t -= 10.0
	var protection := worn_protection()
	if t < COMFORT.x:
		t = minf(t + protection.x, maxf(t, 20.0))
	elif t > COMFORT.y:
		t = maxf(t - protection.y, minf(t, 20.0))
	return t


## (proteção contra frio, contra calor) da roupa vestida.
func worn_protection() -> Vector2:
	if equipment == null:
		return Vector2.ZERO
	return equipment.worn_protection()


static func status_for(temp: float) -> StringName:
	if temp < FREEZING:
		return &"freezing"
	if temp < COMFORT.x:
		return &"cold"
	if temp > BURNING:
		return &"burning"
	if temp > COMFORT.y:
		return &"hot"
	return &"comfort"


func status_text() -> String:
	return STATUS_TEXT.get(status, "")


# ---------- interface ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	# Borda da tela tingida (gradiente radial transparente no centro).
	_vignette_gradient = Gradient.new()
	_vignette_gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_vignette_gradient.offsets = PackedFloat32Array([0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = _vignette_gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_vignette)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 226)
	panel.custom_minimum_size = Vector2(190, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.06, 0.82)
	style.border_color = Color(0.45, 0.55, 0.5, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_icon = Label.new()
	_icon.add_theme_font_size_override("font_size", 24)
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	col.add_child(_status_label)


func _refresh_ui() -> void:
	if _label == null:
		return
	var icons := {&"freezing": "❄", &"cold": "❄", &"comfort": "☼", &"hot": "☀", &"burning": "🔥"}
	var colors := {&"freezing": Color(0.45, 0.8, 1.0), &"cold": Color(0.65, 0.88, 1.0), &"comfort": Color(0.75, 1.0, 0.7), &"hot": Color(1.0, 0.75, 0.35), &"burning": Color(1.0, 0.4, 0.2)}
	var c: Color = colors.get(status, Color.WHITE)
	_icon.text = icons.get(status, "☼")
	_icon.add_theme_color_override("font_color", c)
	_label.text = "%d °C" % roundi(body_temp)
	var worn := ""
	if equipment != null and equipment.worn_item != &"":
		worn = " · " + equipment.item_name(equipment.worn_item)
	_status_label.text = status_text() + worn
	_status_label.add_theme_color_override("font_color", c)
	var edge := Color(0, 0, 0, 0)
	match status:
		&"cold": edge = Color(0.6, 0.85, 1.0, 0.22)
		&"freezing": edge = Color(0.75, 0.92, 1.0, 0.5)
		&"hot": edge = Color(1.0, 0.6, 0.2, 0.18)
		&"burning": edge = Color(1.0, 0.35, 0.1, 0.45)
	_vignette_gradient.set_color(1, edge)
