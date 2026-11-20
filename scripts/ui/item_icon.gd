@tool
class_name ItemIcon
extends Control
## Ícone vetorial de um item, desenhado em código (sem imagens externas).
## Mude [member item_id] e o desenho se atualiza. Ids desconhecidos viram um
## losango com a cor padrão.

@export var item_id: StringName = &"":
	set(value):
		item_id = value
		queue_redraw()
## Esmaecido (item que você não tem).
@export var dimmed: bool = false:
	set(value):
		dimmed = value
		queue_redraw()

const WOOD := Color("a9784a")
const WOOD_DARK := Color("6e4a2c")
const STONE := Color("a7adb0")
const STONE_DARK := Color("6d7477")
const LEAF := Color("7daa67")
const FIRE := Color("ffb340")
const FIRE_CORE := Color("fff1a8")
const MEAT := Color("c0605a")
const MEAT_COOKED := Color("b8743e")
const BONE := Color("efe6d4")
const CLOTH := Color("ece2cc")
const BERRY := Color("c8445f")
const FLINT := Color("33405a")
const IRON := Color("c3c8d0")
const OUTLINE := Color(0.05, 0.05, 0.05, 0.9)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	draw_set_transform(o, 0.0, Vector2(s, s) / 64.0)  # desenha num quadro de 64×64
	match item_id:
		&"wood": _log()
		&"stone": _stone()
		&"fiber": _fiber()
		&"wild_berries": _berries()
		&"stone_axe": _axe(STONE)
		&"stone_pickaxe": _pickaxe(STONE)
		&"flint_axe": _axe(FLINT)
		&"flint_pickaxe": _pickaxe(FLINT)
		&"flint": _flint()
		&"iron_axe": _axe(IRON)
		&"iron_pickaxe": _pickaxe(IRON)
		&"iron_sword": _sword()
		&"iron_ore": _ore()
		&"iron_ingot": _ingot()
		&"stone_spear": _spear()
		&"improvised_club": _club()
		&"torch": _torch()
		&"bandage": _bandage()
		&"raw_meat": _meat(MEAT)
		&"cooked_meat": _meat(MEAT_COOKED)
		&"": pass
		_: _poly([Vector2(32, 8), Vector2(56, 32), Vector2(32, 56), Vector2(8, 32)], Color(0.6, 0.65, 0.58))
	draw_set_transform(Vector2.ZERO)


func _tint(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * 0.28) if dimmed else c


func _poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array(points)
	draw_colored_polygon(packed, _tint(color))
	packed.append(points[0])
	draw_polyline(packed, _tint(OUTLINE), 2.0, true)


func _stick(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, _tint(OUTLINE), width + 3.0, true)
	draw_line(a, b, _tint(color), width, true)


func _circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius + 1.5, _tint(OUTLINE))
	draw_circle(center, radius, _tint(color))


# ---------- desenhos ----------

func _log() -> void:
	_poly([Vector2(10, 24), Vector2(46, 14), Vector2(54, 38), Vector2(18, 48)], WOOD)
	_circle(Vector2(50, 26), 12.0, Color("d9b07a"))
	draw_arc(Vector2(50, 26), 6.0, 0, TAU, 16, _tint(WOOD_DARK), 2.0, true)


func _stone() -> void:
	_poly([Vector2(12, 40), Vector2(20, 20), Vector2(38, 12), Vector2(54, 24), Vector2(52, 46), Vector2(30, 54)], STONE)
	_poly([Vector2(22, 24), Vector2(36, 18), Vector2(40, 30), Vector2(26, 34)], Color("c8cdd0"))


func _fiber() -> void:
	for i in 5:
		var x := 18.0 + i * 7.0
		draw_line(Vector2(32, 56), Vector2(x, 10 + absf(i - 2) * 6.0), _tint(OUTLINE), 5.0, true)
		draw_line(Vector2(32, 56), Vector2(x, 10 + absf(i - 2) * 6.0), _tint(LEAF.lightened(i * 0.05)), 3.0, true)
	_stick(Vector2(24, 44), Vector2(40, 44), 4.0, Color("c9b07b"))


func _berries() -> void:
	_stick(Vector2(32, 10), Vector2(32, 22), 3.0, LEAF)
	_poly([Vector2(32, 14), Vector2(46, 8), Vector2(42, 18)], LEAF)
	for c in [Vector2(22, 34), Vector2(42, 34), Vector2(32, 46), Vector2(32, 26)]:
		_circle(c, 9.0, BERRY)
		draw_circle(c + Vector2(-3, -3), 2.5, _tint(Color(1, 1, 1, 0.6)))


func _axe(head: Color) -> void:
	_stick(Vector2(18, 56), Vector2(42, 10), 5.0, WOOD)
	_poly([Vector2(34, 10), Vector2(56, 8), Vector2(58, 30), Vector2(40, 24)], head)
	_stick(Vector2(36, 18), Vector2(44, 20), 3.0, Color("c9b07b"))


func _pickaxe(head: Color) -> void:
	_stick(Vector2(16, 56), Vector2(40, 16), 5.0, WOOD)
	_poly([Vector2(10, 22), Vector2(34, 8), Vector2(58, 18), Vector2(56, 24), Vector2(36, 16), Vector2(14, 28)], head)
	_stick(Vector2(34, 14), Vector2(40, 20), 3.0, Color("c9b07b"))


func _spear() -> void:
	_stick(Vector2(10, 58), Vector2(46, 20), 4.0, WOOD)
	_poly([Vector2(42, 18), Vector2(56, 6), Vector2(50, 24)], STONE)
	_stick(Vector2(40, 22), Vector2(46, 26), 3.0, Color("c9b07b"))


func _club() -> void:
	_stick(Vector2(16, 56), Vector2(38, 24), 6.0, WOOD)
	_circle(Vector2(42, 20), 12.0, WOOD_DARK.lightened(0.15))
	draw_circle(Vector2(38, 16), 3.0, _tint(Color(1, 1, 1, 0.25)))


func _torch() -> void:
	_stick(Vector2(32, 58), Vector2(32, 28), 6.0, WOOD)
	_poly([Vector2(26, 30), Vector2(38, 30), Vector2(36, 24), Vector2(28, 24)], Color("8a6a40"))
	_poly([Vector2(32, 4), Vector2(42, 18), Vector2(38, 26), Vector2(26, 26), Vector2(22, 18)], FIRE)
	draw_colored_polygon(PackedVector2Array([Vector2(32, 12), Vector2(37, 20), Vector2(32, 25), Vector2(27, 20)]), _tint(FIRE_CORE))


func _bandage() -> void:
	_poly([Vector2(14, 22), Vector2(50, 22), Vector2(50, 42), Vector2(14, 42)], CLOTH)
	_poly([Vector2(28, 14), Vector2(36, 14), Vector2(36, 50), Vector2(28, 50)], CLOTH)
	draw_rect(Rect2(29, 26, 6, 12), _tint(Color("d0453f")))
	draw_rect(Rect2(26, 29, 12, 6), _tint(Color("d0453f")))


func _meat(color: Color) -> void:
	_stick(Vector2(12, 52), Vector2(26, 38), 5.0, BONE)
	_circle(Vector2(11, 54), 4.0, BONE)
	_poly([Vector2(22, 34), Vector2(30, 14), Vector2(50, 10), Vector2(58, 28), Vector2(48, 46), Vector2(30, 46)], color)
	draw_circle(Vector2(44, 22), 4.0, _tint(color.lightened(0.3)))


func _flint() -> void:
	_poly([Vector2(14, 44), Vector2(26, 10), Vector2(36, 22), Vector2(30, 52)], FLINT)
	_poly([Vector2(32, 50), Vector2(42, 14), Vector2(54, 40), Vector2(44, 56)], FLINT.lightened(0.15))
	draw_line(Vector2(26, 16), Vector2(24, 40), _tint(Color(0.6, 0.75, 1.0, 0.7)), 2.0, true)
	draw_line(Vector2(42, 20), Vector2(46, 44), _tint(Color(0.6, 0.75, 1.0, 0.7)), 2.0, true)


func _sword() -> void:
	_poly([Vector2(36, 8), Vector2(42, 6), Vector2(44, 12), Vector2(22, 40), Vector2(18, 36)], IRON)
	_stick(Vector2(14, 30), Vector2(28, 44), 4.0, Color("8a6a40"))
	_stick(Vector2(20, 42), Vector2(10, 54), 4.0, WOOD_DARK)


func _ore() -> void:
	_poly([Vector2(10, 42), Vector2(18, 18), Vector2(40, 10), Vector2(56, 28), Vector2(50, 50), Vector2(26, 56)], Color("4f4844"))
	for c in [Vector2(26, 26), Vector2(40, 36), Vector2(28, 44)]:
		_circle(c, 5.0, Color("c47a45"))


func _ingot() -> void:
	_poly([Vector2(8, 42), Vector2(18, 28), Vector2(56, 28), Vector2(46, 42)], IRON.darkened(0.15))
	_poly([Vector2(8, 42), Vector2(46, 42), Vector2(46, 50), Vector2(8, 50)], IRON.darkened(0.35))
	_poly([Vector2(46, 42), Vector2(56, 28), Vector2(56, 36), Vector2(46, 50)], IRON.darkened(0.45))
	draw_line(Vector2(20, 32), Vector2(40, 32), _tint(Color(1, 1, 1, 0.6)), 2.0, true)
