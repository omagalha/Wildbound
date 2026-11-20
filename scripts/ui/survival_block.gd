class_name SurvivalBlock
extends Control
## Bloco de sobrevivência do canto superior esquerdo: retrato do personagem
## (em moldura redonda) e duas barras empilhadas, vida em cima e fome embaixo,
## com ícone, valor e porcentagem.
##
## O retrato é uma "foto": uma cópia do personagem, com a roupa atual, num
## estúdio separado (mundo próprio, luz fixa), fotografada só quando a roupa
## muda. Não acompanha o movimento nem a luz do dia.
##
## Só mostra dados: o SurvivalHUD chama set_health/set_hunger com os mesmos
## sinais que já usava. O tamanho acompanha a altura da tela (base 720 px).

const BASE_SIZE := Vector2(300, 104)
const HEALTH_COLOR := Color(0.9, 0.22, 0.24)
const HEALTH_LOW := Color(1.0, 0.45, 0.35)
const HUNGER_COLOR := Color(0.96, 0.63, 0.18)
const HUNGER_LOW := Color(1.0, 0.36, 0.24)
const FRAME := Color(0.85, 0.7, 0.38)
const PANEL_BG := Color(0.03, 0.05, 0.045, 0.78)
const PORTRAIT_SHADER := """
shader_type canvas_item;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	if (r > 1.0) { discard; }
	vec4 c = texture(TEXTURE, UV);
	vec3 bg = mix(vec3(0.16, 0.24, 0.2), vec3(0.06, 0.1, 0.09), UV.y);
	COLOR = vec4(mix(bg, c.rgb, c.a), 1.0);
}
"""

@export var player: Node3D
@export var animator: CharacterAnimator
@export var low_ratio: float = 0.25

var ui_scale := 1.0
var health_ratio := 1.0
var hunger_ratio := 1.0
var _health_bar: ProgressBar
var _hunger_bar: ProgressBar
var _health_value: Label
var _hunger_value: Label
var _health_fill: StyleBoxFlat
var _hunger_fill: StyleBoxFlat
var _portrait: TextureRect
var _portrait_frame: Panel
var _viewport: SubViewport
var _camera: Camera3D
var _footer: VBoxContainer
var _flash := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()
	if animator != null:
		animator.outfit_changed.connect(func(): refresh_portrait.call_deferred())
	refresh_portrait.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.0, 0.0)
	var low_pulse := 0.0
	if health_ratio <= low_ratio:
		low_pulse = (sin(_time * 6.0) * 0.5 + 0.5) * 0.35
	_portrait.modulate = Color.WHITE.lerp(Color(1.0, 0.35, 0.3), maxf(_flash, low_pulse))
	if hunger_ratio <= low_ratio:
		_hunger_bar.modulate.a = 0.75 + (sin(_time * 5.0) * 0.5 + 0.5) * 0.25
	else:
		_hunger_bar.modulate.a = 1.0


func set_health(current: float, maximum: float) -> void:
	var ratio := current / maxf(maximum, 1.0)
	if ratio < health_ratio - 0.001:
		_flash = 1.0
	health_ratio = ratio
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_value.text = "%d/%d  ·  %d%%" % [ceili(current), int(maximum), roundi(ratio * 100.0)]
	_health_fill.bg_color = HEALTH_LOW if ratio <= low_ratio else HEALTH_COLOR


func set_hunger(current: float, maximum: float) -> void:
	var ratio := current / maxf(maximum, 1.0)
	hunger_ratio = ratio
	_hunger_bar.max_value = maximum
	_hunger_bar.value = current
	_hunger_value.text = "%d/%d  ·  %d%%" % [int(current), int(maximum), roundi(ratio * 100.0)]
	_hunger_fill.bg_color = HUNGER_LOW if ratio <= low_ratio else HUNGER_COLOR


## Põe rótulos já existentes (mochila, mochila de morte) no rodapé do bloco.
func adopt_footer(labels: Array) -> void:
	for node in labels:
		var label := node as Label
		if label == null:
			continue
		label.get_parent().remove_child(label)
		label.add_theme_font_size_override("font_size", 11)
		_footer.add_child(label)


func get_health_text() -> String:
	return _health_value.text


func get_hunger_text() -> String:
	return _hunger_value.text


func has_portrait() -> bool:
	return _viewport != null and _camera != null


# ---------- interno ----------

func _apply_scale() -> void:
	var screen := get_viewport().get_visible_rect().size
	ui_scale = clampf(screen.y / 720.0, 0.8, 1.8)
	# Espaço à esquerda do relógio (centralizado, ~380 px de largura).
	var room := screen.x * 0.5 - 190.0 * ui_scale - 24.0 * ui_scale
	ui_scale = clampf(minf(ui_scale, room / BASE_SIZE.x), 0.7, 1.8)
	custom_minimum_size = BASE_SIZE * ui_scale
	size = custom_minimum_size
	# Os filhos são posicionados à mão (proporcionais ao tamanho).
	var s := ui_scale
	var portrait_d := 88.0 * s
	_portrait_frame.position = Vector2(8, 8) * s
	_portrait_frame.size = Vector2(portrait_d, portrait_d)
	_portrait.position = _portrait_frame.position + Vector2(3, 3) * s
	_portrait.size = Vector2(portrait_d, portrait_d) - Vector2(6, 6) * s
	_viewport.size = Vector2i(int(128 * s), int(128 * s))
	var left := _portrait_frame.position.x + portrait_d + 10.0 * s
	var width := size.x - left - 12.0 * s
	_layout_row(_health_bar, _health_value, left, 14.0 * s, width, s)
	_layout_row(_hunger_bar, _hunger_value, left, 50.0 * s, width, s)
	_footer.position = Vector2(left, 84.0 * s)
	_footer.size = Vector2(width, 18.0 * s)


func _layout_row(bar: ProgressBar, value: Label, left: float, top: float, width: float, s: float) -> void:
	var icon := bar.get_meta(&"icon") as Label
	var name_label := bar.get_meta(&"name") as Label
	icon.position = Vector2(left, top - 2.0 * s)
	icon.add_theme_font_size_override("font_size", int(18 * s))
	name_label.position = Vector2(left + 24.0 * s, top - 1.0 * s)
	name_label.add_theme_font_size_override("font_size", int(11 * s))
	value.position = Vector2(left + 24.0 * s, top - 1.0 * s)
	value.size = Vector2(width - 24.0 * s, 16.0 * s)
	value.add_theme_font_size_override("font_size", int(12 * s))
	bar.position = Vector2(left + 24.0 * s, top + 15.0 * s)
	bar.size = Vector2(width - 24.0 * s, 11.0 * s)


func _build() -> void:
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = PANEL_BG
	bg_style.border_color = Color(FRAME.r, FRAME.g, FRAME.b, 0.45)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(14)
	bg_style.corner_radius_top_left = 52
	bg_style.corner_radius_bottom_left = 52
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)
	# Retrato: SubViewport no mesmo mundo, câmera presa ao rosto.
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true  # estúdio: não vê nem é afetado pelo mundo
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.near = 0.05
	_camera.far = 4.0
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_camera.environment = env
	_viewport.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 30, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.75, 0.85, 1.0)
	_viewport.add_child(fill)
	_portrait_frame = Panel.new()
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	ring.border_color = FRAME
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(64)
	_portrait_frame.add_theme_stylebox_override("panel", ring)
	add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.texture = _viewport.get_texture()
	var shader := Shader.new()
	shader.code = PORTRAIT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_portrait.material = mat
	add_child(_portrait)
	var health := _make_row("❤", "VIDA", HEALTH_COLOR)
	_health_bar = health[0]
	_health_value = health[1]
	_health_fill = health[2]
	var hunger := _make_row("🍖", "FOME", HUNGER_COLOR)
	_hunger_bar = hunger[0]
	_hunger_value = hunger[1]
	_hunger_fill = hunger[2]
	_footer = VBoxContainer.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_theme_constant_override("separation", 0)
	add_child(_footer)


## [barra, rótulo do valor, estilo do preenchimento]
func _make_row(icon_text: String, title: String, color: Color) -> Array:
	var icon := Label.new()
	icon.text = icon_text
	icon.add_theme_color_override("font_color", color)
	icon.add_theme_color_override("font_outline_color", Color.BLACK)
	icon.add_theme_constant_override("outline_size", 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_color_override("font_color", color.lightened(0.35))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	value.add_theme_color_override("font_outline_color", Color.BLACK)
	value.add_theme_constant_override("outline_size", 3)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.value = 100.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.border_color = Color(1, 1, 1, 0.08)
	back.set_border_width_all(1)
	back.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	fill.border_color = color.lightened(0.35)
	fill.border_width_top = 2  # brilho no topo: leitura de "barra cheia"
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta(&"icon", icon)
	bar.set_meta(&"name", name_label)
	add_child(bar)
	return [bar, value, fill]


var _studio_model: Node3D
var portrait_version := 0


## Refaz a foto: copia o modelo do personagem (com a roupa e a cor atuais),
## põe na pose parada e fotografa o rosto uma vez.
func refresh_portrait() -> void:
	if animator == null or animator.model == null or _viewport == null:
		return
	if _studio_model != null:
		_studio_model.queue_free()
	_studio_model = animator.model.duplicate() as Node3D
	# Tira acessórios presos às mãos (apontam para fora do estúdio).
	for node in _studio_model.find_children("*", "BoneAttachment3D", true, false):
		node.free()
	_studio_model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	_viewport.add_child(_studio_model)
	var anim := _studio_model.find_children("*", "AnimationPlayer", true, false)
	if not anim.is_empty():
		var player_node := anim[0] as AnimationPlayer
		var clip := "Idle" if player_node.has_animation("Idle") else ""
		if clip != "":
			player_node.play(clip)
			player_node.seek(0.4, true)
			player_node.pause()
	await get_tree().process_frame
	if not is_instance_valid(_studio_model):
		return
	var head := Vector3(0, 1.62, 0)
	var skeleton := _studio_model.find_children("*", "Skeleton3D", true, false)
	if not skeleton.is_empty():
		var sk := skeleton[0] as Skeleton3D
		var bone := sk.find_bone("Head")
		if bone >= 0:
			head = (sk.global_transform * sk.get_bone_global_pose(bone)).origin + Vector3(0, 0.1, 0)
	# O modelo do jogador olha para -Z; a câmera fica na frente, um pouco de lado.
	_camera.global_position = head + Vector3(0.2, 0.03, -0.75)
	_camera.look_at(head, Vector3.UP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	portrait_version += 1
