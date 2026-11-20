class_name HudToastFeed
extends VBoxContainer
## Fila curta de feedback do HUD, com prioridade e deduplicação.

enum Kind { INFO, SUCCESS, WARNING, DANGER, CRITICAL }

const MAX_VISIBLE := 3
const COLORS := {
	Kind.INFO: Color(0.48, 0.7, 0.78),
	Kind.SUCCESS: Color(0.4, 0.82, 0.48),
	Kind.WARNING: Color(0.95, 0.68, 0.24),
	Kind.DANGER: Color(0.94, 0.34, 0.27),
	Kind.CRITICAL: Color(0.82, 0.12, 0.12),
}

var _entries: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	for entry in _entries.duplicate():
		if entry["kind"] == Kind.CRITICAL:
			continue
		entry["left"] = float(entry["left"]) - delta
		if entry["left"] <= 0.0:
			_remove_entry(entry)


func push_message(text: String, duration: float = 2.5, kind: Kind = Kind.INFO) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	if kind != Kind.CRITICAL and _has_critical():
		return
	for entry in _entries:
		if entry["text"] == text:
			entry["left"] = duration
			_pulse(entry["panel"] as PanelContainer)
			return
	if kind == Kind.CRITICAL:
		clear_all()
	var panel := _make_toast(text, kind)
	add_child(panel)
	move_child(panel, 0)
	_entries.push_front({"text": text, "kind": kind, "left": duration, "panel": panel})
	while _entries.size() > MAX_VISIBLE:
		_remove_entry(_entries.back())
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)


func clear_all() -> void:
	for entry in _entries:
		(entry["panel"] as PanelContainer).queue_free()
	_entries.clear()


func get_visible_count() -> int:
	return _entries.size()


func get_primary_text() -> String:
	return String(_entries[0]["text"]) if not _entries.is_empty() else ""


func _has_critical() -> bool:
	for entry in _entries:
		if entry["kind"] == Kind.CRITICAL:
			return true
	return false


func _make_toast(text: String, kind: Kind) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 31.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.03, 0.94)
	style.border_color = COLORS[kind]
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _remove_entry(entry: Dictionary) -> void:
	if not _entries.has(entry):
		return
	_entries.erase(entry)
	var panel := entry["panel"] as PanelContainer
	if is_instance_valid(panel):
		panel.queue_free()


func _pulse(panel: PanelContainer) -> void:
	panel.modulate = Color(1.2, 1.2, 0.9, 1.0)
	panel.create_tween().tween_property(panel, "modulate", Color.WHITE, 0.2)
