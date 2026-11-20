class_name AbilityIcon
extends Control
## Ícone vetorial de habilidade: chama (Centelha) ou folha com cruz (Pulso Vital).

@export var ability_id: StringName = &"":
	set(value):
		if ability_id == value:
			return
		ability_id = value
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	draw_set_transform((size - Vector2(s, s)) * 0.5, 0.0, Vector2(s, s) / 64.0)
	match ability_id:
		&"ancestral_spark":
			var outer := PackedVector2Array([Vector2(32, 4), Vector2(48, 26), Vector2(50, 42), Vector2(40, 58), Vector2(24, 58), Vector2(14, 42), Vector2(16, 26), Vector2(26, 30)])
			draw_colored_polygon(outer, Color("ff8a2a"))
			var inner := PackedVector2Array([Vector2(32, 22), Vector2(40, 36), Vector2(38, 50), Vector2(26, 50), Vector2(24, 38)])
			draw_colored_polygon(inner, Color("ffe08a"))
		&"vital_pulse":
			var leaf := PackedVector2Array([Vector2(32, 6), Vector2(52, 26), Vector2(48, 48), Vector2(32, 58), Vector2(16, 48), Vector2(12, 26)])
			draw_colored_polygon(leaf, Color("4fd16a"))
			draw_rect(Rect2(28, 20, 8, 26), Color(1, 1, 1, 0.95))
			draw_rect(Rect2(19, 29, 26, 8), Color(1, 1, 1, 0.95))
		_:
			draw_circle(Vector2(32, 32), 14, Color(0.4, 0.4, 0.4, 0.6))
	draw_set_transform(Vector2.ZERO)
